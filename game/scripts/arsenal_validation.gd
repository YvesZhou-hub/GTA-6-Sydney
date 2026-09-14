extends Node
## Full-city combat integration. Initial poses and an in-memory veteran save are
## explicit fixtures; purchases, shots, enemy attacks and evasion use production.
const Modules = preload("res://scripts/weapon_modules.gd")
const Store = preload("res://scripts/save_store.gd")
const SOURCES := ["main", "audio_shutdown", "harbor_survival", "vehicle_armory", "combat_progression", "encounter_spawn", "nailong_enemy", "nailong_model", "nailong_flight", "combat_feedback", "survival_hud", "vehicle_weapons", "vehicle_support_weapons", "weapon_modules", "save_store", "arsenal_validation"]
const REQUIRED := ["complete production Sydney city and airport loaded", "physical B opens armory and hides combat feedback", "actual armory buttons buy three modules with exact coin costs", "fourth module remains stored until a slot is freed", "paid module upgrade improves stats without changing existing enemy HP", "real tank shell produces stronger centre than edge damage", "actual damage feedback matches each blast victim", "production winglet dive damages the real player", "production stormwing strike damages the real player", "moving out of the marked strike avoids damage", "real wall blocks released aerial strike damage", "three purchased modules damage airborne enemies with free ammunition", "version 7 in-memory restore preserves purchased equipment and enemy level", "veteran level six continuously spawns real reinforcements", "equipment pressure increases one level only after the gradual interval"]
var game
var checks: Array[Dictionary] = []
var screenshots: Array[Dictionary] = []
var scenarios: Dictionary = {}
var source_start: Dictionary = {}
var native := false
var simulation_seconds := 0.0
var stage_origin := Vector3.ZERO
var tank: RigidBody3D
var purchase_balance := 0
var saved_equipment: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")


func check(title: String, passed: bool, detail: Dictionary = {}) -> void:
	checks.append({"name":title, "passed":passed, "detail":detail})
	print("ARSENAL_QA ", "PASS " if passed else "FAIL ", title, " ", JSON.stringify(detail))


static func damage_feedback_matches(hits: Array, feedback: Dictionary) -> bool:
	if hits.is_empty(): return false
	var seen := {}
	var total := 0.0
	for hit: Dictionary in hits:
		var id := int(hit.get("id", 0))
		var actual := float(hit.get("actual", 0))
		if id <= 0 or seen.has(id) or not is_finite(actual) or actual <= 0: return false
		seen[id] = true
		var shown := 0.0
		for number: Dictionary in feedback.get("floating", []):
			if int(number.get("id", 0)) == id and number.get("kind") == "damage": shown += float(number.get("amount", 0))
		if not is_finite(shown) or not is_equal_approx(shown, actual): return false
		total += actual
	return is_equal_approx(total, float(feedback.get("actual_damage", -1)))


static func required_checks_pass(rows: Array, required: Array) -> bool:
	if rows.is_empty() or required.is_empty(): return false
	var names := {}
	for row: Dictionary in rows:
		var title := str(row.get("name", ""))
		if title.is_empty() or names.has(title) or typeof(row.get("passed")) != TYPE_BOOL or not bool(row.get("passed")): return false
		names[title] = true
	return required.all(func(title): return names.has(title))


func sources() -> Dictionary:
	var result := {}
	for name: String in SOURCES:
		var path := "res://scripts/" + name + ".gd"
		result[path] = {"representation":"readable_source", "sha256":FileAccess.get_sha256(path)} if FileAccess.file_exists(path) else {"representation":"compiled_resource", "loadable":ResourceLoader.exists(path)}
	return result


func vec(point: Vector3) -> Array: return [point.x, point.y, point.z]


func step(count := 1) -> void:
	for i: int in count:
		await get_tree().physics_frame
		simulation_seconds += 1.0 / Engine.physics_ticks_per_second
		game.combat_feedback._process(1.0 / Engine.physics_ticks_per_second)


func release_input() -> void:
	for action: String in ["forward", "back", "left", "right", "sprint", "fire", "rise", "fall", "jump"]: Input.action_release(action)


func floor_at(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 8, point - Vector3.UP * 12, 1, [game.player.get_rid()])
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < 0.88 or hit.position.y < 1.0 or hit.collider.has_meta("damage_id"): return {}
	return hit


func freeze_fleet() -> void:
	for vehicle in game.vehicles:
		vehicle.freeze = true
		vehicle.linear_velocity = Vector3.ZERO
		vehicle.angular_velocity = Vector3.ZERO


func pose_player(at: Vector3) -> void:
	if is_instance_valid(game.current_vehicle): game.exit_vehicle()
	game.player.global_position = at + Vector3.UP * 0.04
	game.player.last_safe = game.player.global_position
	game.player.velocity = Vector3.ZERO
	game.player.enabled = true
	game.player.visible = true
	game.player.reset_physics_interpolation()
	game.camera.global_position = at + Vector3(0, 5, 20)
	game.camera.look_at(at + Vector3(0, 2, -20))


func key_press(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code; event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new(); event.physical_keycode = code; event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func find_button(fragment: String) -> Button:
	for child: Node in game.modal_content.get_children():
		if child is Button and fragment in child.text: return child
	return null


func module_button(id: String, action: String) -> Button:
	var label: String = Modules.CATALOG[id].label
	if action == "unequip": return find_button(label + " " )
	if action == "equip": return find_button("免费装配 " + label)
	var in_section := false
	for child: Node in game.modal_content.get_children():
		if child is Label:
			for other: String in Modules.CATALOG:
				if child.text.begins_with(str(Modules.CATALOG[other].label) + " · "): in_section = other == id
		if in_section and child is Button and (child.text.begins_with("购买") or child.text.begins_with("升级")): return child
	return null


func press_module(id: String, action: String) -> bool:
	var button := module_button(id, action)
	if not is_instance_valid(button) or button.disabled: return false
	button.pressed.emit()
	await get_tree().process_frame
	return true


func refresh() -> void:
	game.toast_time = 0.0; game.toast_label.modulate.a = 0.0
	game.update_hud()
	game.survival_hud.update_state(game.survival.hud_state())
	game.update_navigation(0.1)
	game.update_combat_reticle(0.1)
	game.combat_feedback._scan_left = 0.0
	game.combat_feedback._process(0.0)


func capture(label: String, eye: Vector3, target: Vector3, detail: Dictionary = {}) -> void:
	if not native: return
	game.camera.global_position = eye
	game.camera.look_at(target)
	check("city facade stream ready: " + label, await game.world.prepare_view(eye))
	refresh()
	for i: int in 3:
		RenderingServer.force_draw(false)
		await get_tree().process_frame
	var image: Image = get_tree().root.get_texture().get_image()
	var path := "user://arsenal-qa/" + label + ".png"
	var saved := image.save_png(path) == OK
	screenshots.append({"file":label + ".png", "saved":saved, "sha256":FileAccess.get_sha256(path) if saved else "", "resolution":[image.get_width(),image.get_height()], "eye":vec(eye), "target":vec(target), "detail":detail, "feedback":game.combat_feedback.snapshot()})
	check("native Metal image: " + label, saved and not image.is_empty())


func posed_enemy(kind: String, at: Vector3, level := 1):
	var enemy = game.survival.spawn_enemy(kind, at, -1.0, level)
	if is_instance_valid(enemy): enemy.set_target(null); enemy.set_physics_process(false)
	return enemy


func early_natural_flyer() -> void:
	game.survival.auto_spawn = true
	game.survival.set_physics_process(true)
	var found := false
	var records: Array = []
	for frame: int in 12 * Engine.physics_ticks_per_second:
		await step()
		for enemy in game.survival.enemies:
			if enemy.enemy_type == "winglet": found = true
		if found: break
	for enemy in game.survival.enemies: records.append({"type":enemy.enemy_type,"level":enemy.level,"position":vec(enemy.global_position)})
	check("production early reinforcements include a flying winglet", found, {"observed":records})
	game.survival.auto_spawn = false
	game.survival.set_physics_process(false)
	game.survival.clear_enemies()
	await step(2)


func purchase_scenario() -> void:
	var witness = posed_enemy("brute", stage_origin + Vector3(6, 0.04, -18))
	var hp: float = witness.health
	await key_press(KEY_B)
	var entry := find_button("选装武器")
	var opened_services: bool = game.active_panel == "survival" and game.paused and get_tree().paused and is_instance_valid(entry)
	if opened_services: entry.pressed.emit()
	await get_tree().process_frame
	refresh()
	check("physical B opens armory and hides combat feedback", opened_services and game.active_panel == "armory" and game.paused and get_tree().paused and game.modal.visible and not game.combat_feedback.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	var money: int = game.life.money
	var all_bought := true
	for id: String in ["rotary", "micro", "laser"]:
		all_bought = await press_module(id, "buy") and all_bought
	check("actual armory buttons buy three modules with exact coin costs", all_bought and game.survival.weapon_loadout("tank").size() == 3 and game.life.money == money - 17500, {"before":money, "after":game.life.money, "loadout":game.survival.weapon_loadout("tank")})
	var bought: bool = await press_module("tesla", "buy")
	var equip := module_button("tesla", "equip")
	check("fourth module remains stored until a slot is freed", bought and game.survival.armory.level("tank", "tesla") == 1 and not game.survival.armory.is_equipped("tank", "tesla") and game.survival.weapon_loadout("tank").size() == 3 and is_instance_valid(equip) and equip.disabled and game.life.money == money - 26000)
	await capture("armory-three-slots", game.camera.global_position, witness.global_position + Vector3.UP, {"real_B_and_button_callbacks":true})
	var before_upgrade := Modules.spec("rotary", 1)
	var upgraded: bool = await press_module("rotary", "buy")
	var after_upgrade := Modules.spec("rotary", game.survival.armory.level("tank", "rotary"))
	check("paid module upgrade improves stats without changing existing enemy HP", upgraded and game.life.money == money - 35000 and after_upgrade.damage > before_upgrade.damage and after_upgrade.cooldown < before_upgrade.cooldown and witness.health == hp)
	var balance: int = game.life.money
	var removed: bool = await press_module("micro", "unequip")
	var fitted: bool = await press_module("tesla", "equip")
	check("free loadout replacement preserves owned tiers and exact balance", removed and fitted and game.survival.weapon_loadout("tank").size() == 3 and game.survival.armory.level("tank", "micro") == 1 and game.survival.armory.is_equipped("tank", "tesla") and game.life.money == balance)
	purchase_balance = game.life.money
	saved_equipment = game.survival.armory.snapshot()
	game.close_panel(); refresh()
	check("closing armory restores combat feedback and same occupied tank", not game.paused and not get_tree().paused and game.current_vehicle == tank and game.combat_feedback.visible)
	# The production clock runs for a complete authored interval, with the old
	# enemy held still. No difficulty jump, replacement health or forced kills.
	game.survival.grace = 0.0
	game.survival.set_physics_process(true)
	var level: int = game.survival.encounter_level()
	await step(17 * Engine.physics_ticks_per_second)
	var early: int = game.survival.encounter_level()
	await step(2 * Engine.physics_ticks_per_second)
	check("equipment pressure increases one level only after the gradual interval", early == level and game.survival.encounter_level() == level + 1 and witness.health == hp, {"initial":level, "at_17_seconds":early, "at_19_seconds":game.survival.encounter_level(), "target":game.survival.target_encounter_level(), "old_enemy_health":witness.health})
	game.survival.set_physics_process(false)
	game.survival.clear_enemies()
	await step(2)


func shell_scenario() -> void:
	var targets: Array = []
	var stage := {}
	for i: int in 32:
		var angle := float(i) * TAU / 32.0
		var direction := Vector3(sin(angle), 0, cos(angle))
		var side := Vector3(direction.z, 0, -direction.x)
		var point: Vector3 = tank.global_position + direction * 30.0
		var sites: Array[Vector3] = []
		for offset: float in [0.0, 10.5, 22.0]:
			var support := floor_at(point + side * offset)
			if support.is_empty(): break
			var at: Vector3 = support.position + Vector3.UP * 0.04
			var ray := PhysicsRayQueryParameters3D.create(tank._moving.barrel.global_position, at + Vector3.UP * 1.5, 1 | 4, [tank.get_rid(), game.player.get_rid()])
			if not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): break
			sites.append(at)
		if sites.size() == 3:
			stage = {"sites":sites, "side":side, "direction":direction}; break
	check("main shell targets have real city floor and open sightlines", not stage.is_empty())
	if stage.is_empty(): return
	for at: Vector3 in stage.sites: targets.append(posed_enemy("brute", at))
	await step(2)
	game.camera.global_position = tank._moving.barrel.global_position
	game.camera.look_at(targets[0].global_position + Vector3.UP * 1.2)
	game.weapons.clear()
	for i: int in 180: game.weapons.update_aim(1.0 / 60.0)
	var fired: int = game.weapons.stats().fired
	game.fire_button.pressed.emit()
	for i: int in 240:
		game.weapons._physics_process(1.0 / 120.0)
		await step()
		if game.weapons.stats().active_projectiles == 0: break
	var loss: Array = targets.map(func(e):return e.max_health - e.health)
	check("real tank shell produces stronger centre than edge damage", game.weapons.stats().fired == fired + 1 and loss[0] > loss[1] and loss[1] > 0.0 and loss[2] == 0.0, {"loss":loss, "blast":game.survival._last_blast, "positions":stage.sites.map(func(p):return vec(p))})
	var snapshot: Dictionary = game.combat_feedback.snapshot()
	check("actual damage feedback matches each blast victim", damage_feedback_matches(game.survival._last_blast.get("hits", []), snapshot), {"feedback":snapshot, "blast":game.survival._last_blast})
	var center: Vector3 = targets[0].global_position + stage.side * 5.0
	await capture("cannon-centre-and-edge", center - stage.direction * 19 + Vector3.UP * 5.0, center + Vector3.UP * 2.0, {"three_real_enemies":true, "main_shell_not_direct_HP_write":true, "loss":loss})
	game.weapons.clear()
	game.survival.clear_enemies()
	await step(2)


func air_attack_scenario(kind: String, mode: String) -> void:
	game.survival.clear_enemies()
	pose_player(stage_origin)
	game.survival.grace = 0.0
	game.survival.set_physics_process(true)
	var at := stage_origin + (Vector3(0, 12.5, -34) if kind == "winglet" else Vector3(0, 6, -24))
	var enemy = game.survival.spawn_enemy(kind, at)
	var before: float = game.player.health
	var windup := false
	var marked := false
	var wall: StaticBody3D
	var point := Vector3.ZERO
	var early_damage := false
	for frame: int in 900:
		await step()
		windup = windup or enemy.state == "windup"
		if not windup and game.player.health < before: early_damage = true
		if kind == "stormwing" and not marked and not game.survival._hazards.is_empty():
			marked = true
			var hazard: Dictionary = game.survival._hazards[0]
			point = hazard.at
			enemy.set_target(null); enemy.set_physics_process(false)
			if mode == "dodge":
				game.yaw = 0.0
				Input.action_press("right"); Input.action_press("sprint")
			elif mode == "wall":
				wall = StaticBody3D.new(); wall.collision_layer = 1
				var shape := BoxShape3D.new(); shape.size = Vector3(24, 18, 0.5)
				var collision := CollisionShape3D.new(); collision.shape = shape; wall.add_child(collision)
				game.add_child(wall)
				wall.global_position = stage_origin + Vector3(0, 6, -8)
				await step(2)
			elif mode == "hit":
				game.survival.set_physics_process(false)
				await capture("stormwing-marked-strike", stage_origin + Vector3(14, 7, 18), at + Vector3(0, -2, 4), {"actual_released_hazard":true})
				game.survival.set_physics_process(true)
		if game.player.health < before or (marked and game.survival._hazards.is_empty()): break
	release_input()
	game.survival.set_physics_process(false)
	var after: float = game.player.health
	var detail := {"health_before":before, "health_after":after, "windup_seen":windup, "marked":marked, "early_damage":early_damage, "player":vec(game.player.global_position), "mark":vec(point), "enemy":enemy.snapshot(), "test_wall_added_after_release":mode == "wall"}
	scenarios[kind + "_" + mode] = detail
	if kind == "winglet": check("production winglet dive damages the real player", windup and not early_damage and after < before, detail)
	elif mode == "hit": check("production stormwing strike damages the real player", windup and marked and not early_damage and after < before, detail)
	elif mode == "dodge": check("moving out of the marked strike avoids damage", marked and after == before and game.player.global_position.distance_to(point) >= 3.4, detail)
	elif mode == "wall": check("real wall blocks released aerial strike damage", marked and is_instance_valid(wall) and after == before, detail)
	if is_instance_valid(wall): wall.queue_free()
	game.survival.clear_enemies()
	await step(2)


func module_scenario() -> void:
	game.enter_vehicle(tank)
	freeze_fleet()
	game.player.enabled = false
	game.weapons.set_auto_enabled(true)
	var forward := -tank.global_basis.z.normalized()
	var side := tank.global_basis.x.normalized()
	var targets: Array = []
	for index: int in 3:
		# Authored high-level health keeps all beams observable without healing.
		targets.append(posed_enemy("stormwing", tank.global_position + forward * (30 + index * 3) + side * index * 3 + Vector3.UP * (8 + index), 12))
	await step(2)
	var before: int = game.life.money
	var stats_before: Dictionary = game.weapons.auto_status().modules
	var captured := false
	for frame: int in 180:
		game.weapons._physics_process(1.0 / 60.0)
		await step()
		var stats: Dictionary = game.weapons.auto_status().modules
		if not captured and int(stats.hits.get("laser", 0)) > int(stats_before.hits.get("laser", 0)) and int(stats.hits.get("tesla", 0)) > int(stats_before.hits.get("tesla", 0)):
			captured = true
			await capture("laser-lightning-airborne-targets", tank.global_position + forward * 12 + side * 13 + Vector3.UP * 9, targets[0].global_position + Vector3.UP * 2, {"production_module_effects":true, "posed_airborne_targets":true})
	var stats: Dictionary = game.weapons.auto_status().modules
	var all_hit := true
	for id: String in ["rotary", "laser", "tesla"]: all_hit = all_hit and int(stats.hits.get(id, 0)) > int(stats_before.hits.get(id, 0))
	check("three purchased modules damage airborne enemies with free ammunition", all_hit and targets.all(func(e):return e.health < e.max_health) and game.life.money == before and before == purchase_balance, {"before":stats_before, "after":stats, "health":targets.map(func(e):return [e.health,e.max_health]), "money_before":before, "money_after":game.life.money})
	check("multiple weapon hits appear as true per-enemy damage totals", game.combat_feedback.snapshot().actual_damage > 0 and game.combat_feedback.snapshot().damage_events > 3, game.combat_feedback.snapshot())
	game.weapons.clear(); game.weapons.set_auto_enabled(false)
	game.survival.clear_enemies()
	await step(2)


func veteran_scenario() -> void:
	var memory: Dictionary = game.survival.get_state()
	memory.cleared = 10
	memory.adaptive_level = 6
	memory.enemies = [{"type":"winglet", "level":12, "health":90, "position":vec(tank.global_position + Vector3(0, 14, -30))}]
	memory.armory = saved_equipment
	game.survival.apply_state(memory)
	var restored: Dictionary = game.survival.armory.snapshot()
	var equipment_matches := true
	for kind: String in saved_equipment.owned:
		equipment_matches = equipment_matches and restored.owned.get(kind, {}) == saved_equipment.owned[kind] and restored.equipped.get(kind, []) == saved_equipment.equipped.get(kind, [])
	check("version 7 in-memory restore preserves purchased equipment and enemy level", Store.VERSION == 7 and equipment_matches and game.survival.enemies.size() == 1 and game.survival.enemies[0].enemy_type == "winglet" and game.survival.enemies[0].level == 12 and game.survival.enemies[0].health == 90, {"save_version":Store.VERSION, "memory_only_no_save_io":true, "restored_equipment":restored})
	game.survival.clear_enemies()
	game.survival.auto_spawn = true
	game.survival.set_physics_process(true)
	var initial_sequence: int = game.survival._spawn_sequence
	var observed := {}
	var rest_zero := true
	for frame: int in 18 * Engine.physics_ticks_per_second:
		await step()
		rest_zero = rest_zero and game.survival.rest == 0.0
		for enemy in game.survival.enemies:
			if not observed.has(enemy.get_instance_id()): observed[enemy.get_instance_id()] = {"type":enemy.enemy_type,"level":enemy.level,"position":vec(enemy.global_position)}
		if observed.size() >= 6 and observed.values().any(func(row):return row.type == "stormwing"): break
	check("veteran level six continuously spawns real reinforcements", game.survival.encounter_level() >= 6 and observed.size() >= 5 and observed.values().all(func(row):return row.level >= 6) and rest_zero and game.survival._spawn_sequence > initial_sequence, {"observed":observed.values(), "spawn_sequence":game.survival._spawn_sequence, "rest":game.survival.rest})
	check("production veteran reinforcement includes a flying stormwing", observed.values().any(func(row):return row.type == "stormwing"), {"observed":observed.values()})
	game.survival.set_physics_process(false)
	for enemy in game.survival.enemies: enemy.set_physics_process(false)
	await capture("veteran-natural-reinforcements", tank.global_position + Vector3(12, 6, 18), tank.global_position + Vector3(0, 3, -20), {"all_enemies_naturally_spawned":true,"starting_veteran_progress_is_in_memory_fixture":true})


func run() -> void:
	game = get_parent()
	native = DisplayServer.get_name() != "headless"
	source_start = sources()
	DirAccess.make_dir_recursive_absolute("user://arsenal-qa")
	if not game.qa_running: check("QA save isolation is active before world setup", false); await finish(); return
	game.active = false
	game.new_world("life", "Arsenal QA isolated unsaved world", false)
	game.world_id = "qa_arsenal_unsaved"
	game.set_process(false)
	game.combat_feedback.set_process(false)
	game.survival.auto_spawn = false
	game.survival.set_physics_process(false)
	game.weapons.set_physics_process(false)
	game.weapons.set_auto_enabled(false)
	game.city_clock.set_hour(14.5)
	if native: RenderingServer.render_loop_enabled = false
	freeze_fleet()
	await step(2)
	check("complete production Sydney city and airport loaded", game.world._ready_complete and is_instance_valid(game.airport) and game.world.structures.size() > 10000)
	var floor := floor_at(Vector3(475, 5, -150))
	check("arsenal fixture uses existing Bennelong city surface", not floor.is_empty())
	if floor.is_empty(): await finish(); return
	stage_origin = floor.position
	pose_player(stage_origin)
	await step(3)
	tank = game.request_vehicle("tank")
	check("production tank spawn seats the player for paid weapon fitting", is_instance_valid(tank) and game.current_vehicle == tank and tank.occupied)
	if not is_instance_valid(tank): await finish(); return
	freeze_fleet()
	game.player.enabled = false
	await step(3)
	await early_natural_flyer()
	await purchase_scenario()
	await shell_scenario()
	for pair: Array in [["winglet", "hit"], ["stormwing", "hit"], ["stormwing", "dodge"], ["stormwing", "wall"]]: await air_attack_scenario(pair[0], pair[1])
	await module_scenario()
	await veteran_scenario()
	await finish()


func finish() -> void:
	release_input()
	if game.paused: game.close_panel()
	game.survival.set_physics_process(false)
	game.weapons.clear()
	var ending := sources()
	var raw := {}
	for path: String in ending:
		if ending[path].get("representation") == "readable_source": raw[path] = ending[path].sha256
	var readable := raw.size() == SOURCES.size()
	if readable: check("tested arsenal sources stayed unchanged during the run", source_start == ending and raw.values().all(func(value):return not str(value).is_empty()))
	else: check("compiled arsenal scripts resolve for external App binding", ending.values().all(func(row):return row.get("loadable",false) or not str(row.get("sha256","")).is_empty()))
	check("all required arsenal scenarios passed without missing or duplicate checks", required_checks_pass(checks, REQUIRED))
	var passed: bool = checks.all(func(row):return row.passed)
	var report := {"passed":passed,"count":checks.size(),"checks":checks,"screenshots":screenshots,"scenarios":scenarios,"simulation_seconds":simulation_seconds,"native":native,"display_driver":DisplayServer.get_name(),"world_ready":game.world._ready_complete,"qa_running":game.qa_running,"physics_hz":Engine.physics_ticks_per_second,"source_sha256":raw,"source_evidence":ending,"source_evidence_start":source_start,"user_saves_touched":false,"save_written":false,"scope":"Actual full Sydney city, B/button purchases, real tank shell falloff and feedback, real enemy windup/strike, player input evasion and purchased modules. Actor/camera poses, one explicit temporary strike-blocking wall, paused actors for photographs and veteran progress loaded from an in-memory fixture are controlled setup. No player save reads/writes, fake damage or forced kill credit. Correctness, not sustained FPS or broad balance research."}
	var output := FileAccess.open("user://arsenal-qa/report.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")); output.close()
	print("ARSENAL_QA_COMPLETE checks=",checks.size()," passed=",passed)
	game.active = false
	game.finish_quit(0 if passed else 1)
