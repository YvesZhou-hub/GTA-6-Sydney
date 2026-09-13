extends Node
## Full production-city integration runner. QA starts before any player-save read.
## Actor poses and projectile time steps are controlled; this is not an FPS test.
var game
var checks: Array[Dictionary] = []
var screenshots: Array[Dictionary] = []
var native := false
var source_start: Dictionary = {}
var spawn_records: Array[Dictionary] = []
var performance_sample: Dictionary = {}
const SOURCES := ["main", "audio_shutdown", "harbor_survival", "nailong_enemy", "nailong_model", "survival_hud", "harbor_vehicle", "harbor_player", "vehicle_weapons", "vehicle_support_weapons", "survival_validation"]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(title: String, passed: bool, detail: Dictionary = {}):
	checks.append({"name": title, "passed": passed, "detail": detail})
	print("SURVIVAL_QA ", "PASS " if passed else "FAIL ", title, " ", JSON.stringify(detail))

func vector(point: Vector3) -> Array: return [point.x, point.y, point.z]

func sources() -> Dictionary:
	var hashes := {}
	for item in SOURCES:
		var path: String = "res://scripts/" + item + ".gd"
		if FileAccess.file_exists(path):
			hashes[path] = {"representation": "readable_source", "sha256": FileAccess.get_sha256(path)}
		else:
			# Release exports compile/remap GDScript. A resolvable resource is not
			# proof of byte identity; the outside runner must hash the final App/PCK.
			hashes[path] = {"representation": "compiled_resource", "loadable": ResourceLoader.exists(path)}
	return hashes

func raw_hashes(evidence: Dictionary) -> Dictionary:
	var hashes := {}
	for path in evidence:
		if evidence[path].get("representation") == "readable_source": hashes[path] = evidence[path].sha256
	return hashes

func freeze_fleet():
	for vehicle in game.vehicles:
		vehicle.freeze = true
		vehicle.linear_velocity = Vector3.ZERO
		vehicle.angular_velocity = Vector3.ZERO

func floor_at(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 8.0, point - Vector3.UP * 12.0, 1, [game.player.get_rid()])
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < 0.88 or hit.position.y < 1.0 or hit.collider.has_meta("damage_id"): return {}
	return hit

func clear_enemy_shape(enemy) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = enemy._collision.shape
	query.transform = enemy._collision.global_transform
	# Clearance above the supporting floor, including the largest boss capsule.
	query.transform.origin.y += 0.08
	query.collision_mask = 1 | 4
	query.exclude = [enemy.get_rid(), game.player.get_rid()]
	return game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func refresh_hud():
	game.update_hud()
	game.survival_hud.update_state(game.survival.hud_state())
	game.update_navigation(0.1)
	game.update_spawn_marker()
	game.update_combat_reticle(0.1)

func capture(name: String, eye: Vector3, target: Vector3, detail: Dictionary = {}):
	if not native: return
	game.camera.global_position = eye
	game.camera.look_at(target)
	check("city facade stream ready: " + name, await game.world.prepare_view(eye))
	refresh_hud()
	for index in 3:
		RenderingServer.force_draw(false)
		await get_tree().process_frame
	var image: Image = get_tree().root.get_texture().get_image()
	var path := "user://survival-qa/" + name + ".png"
	var saved := image.save_png(path) == OK
	screenshots.append({"file": name + ".png", "saved": saved, "sha256": FileAccess.get_sha256(path) if saved else "", "eye": vector(eye), "target": vector(target), "resolution": [image.get_width(), image.get_height()], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "detail": detail})
	check("native Metal image: " + name, saved)

func stage_cast(cast: Array) -> Dictionary:
	# Find a photo location with real floor and unobstructed camera-to-actor rays.
	# No city geometry is removed to manufacture a clear view.
	for center in [Vector3(414, 5, -145), Vector3(475, 5, -150), Vector3(500, 5, -175), Vector3(446, 5, -123)]:
		var eye: Vector3 = center + Vector3(0, 5, 24)
		if floor_at(eye).is_empty(): continue
		var positions: Array[Vector3] = []
		for index in cast.size():
			var support := floor_at(center + Vector3((index - 2) * 5.0, 0, 0))
			if support.is_empty(): break
			var point: Vector3 = support.position + Vector3.UP * 0.05
			var probe := PhysicsShapeQueryParameters3D.new()
			probe.shape = cast[index]._collision.shape
			probe.transform.origin = point + cast[index]._collision.position + Vector3.UP * 0.08
			probe.collision_mask = 1 | 4
			probe.exclude = [game.player.get_rid()]
			if not game.get_world_3d().direct_space_state.intersect_shape(probe, 1).is_empty(): break
			var ray := PhysicsRayQueryParameters3D.create(eye, point + Vector3.UP * 2.0, 1 | 4, [game.player.get_rid()])
			if not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): break
			positions.append(point)
		if positions.size() != cast.size(): continue
		for index in cast.size():
			cast[index].global_position = positions[index]
			cast[index].rotation.y = PI
			cast[index].reset_physics_interpolation()
		return {"eye": eye, "target": center + Vector3(-5, 2.5, 0), "positions": positions}
	return {}

func sample_native_frames(cast: Array):
	if not native: return
	# A live window swaps frames normally; active AI approaches the stationary player.
	# The 25-second grace prevents this short diagnostic from spending health/kits.
	game.survival.grace = 25.0
	game.survival.set_physics_process(true)
	for enemy in cast:
		enemy.set_target(game.player)
		enemy.set_physics_process(true)
	RenderingServer.render_loop_enabled = true
	for frame in 20: await get_tree().process_frame
	var intervals: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in 90:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		intervals.append(float(now - previous) / 1000.0)
		previous = now
	var sorted := intervals.duplicate()
	sorted.sort()
	var total := 0.0
	for interval in intervals: total += interval
	performance_sample = {"frames": 90, "resolution": vector2(get_tree().root.size), "mean_ms": total / 90.0, "median_ms": (sorted[44] + sorted[45]) * 0.5, "p95_ms": sorted[85], "worst_ms": sorted[89], "draw_calls_last": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives_last": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "enemies": cast.size(), "frame_intervals_ms": intervals, "scope": "Native Metal window with normal buffer swaps; 5 active real enemy AIs, full city and fixed camera. No driving, streaming traversal, sustained balance or isolated GPU measurement. First 20 frames warm up before 90 process-frame intervals."}
	print("SURVIVAL_QA_NATIVE_FRAMES ", JSON.stringify(performance_sample))
	RenderingServer.render_loop_enabled = false
	game.survival.set_physics_process(false)
	game.survival.grace = 0.0
	for enemy in cast:
		enemy.set_target(null)
		enemy.set_physics_process(false)

func vector2(point: Vector2i) -> Array: return [point.x, point.y]

func key_press(code: Key):
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func find_button(fragment: String) -> Button:
	for child in game.modal_content.get_children():
		if child is Button and fragment in child.text: return child
	return null

func run():
	game = get_parent()
	native = DisplayServer.get_name() != "headless"
	source_start = sources()
	DirAccess.make_dir_recursive_absolute("user://survival-qa")
	if not game.qa_running:
		check("QA save-isolation guard present before setup", false)
		await finish(); return
	game.active = false
	game.new_world("life", "Survival QA isolated unsaved world", false)
	game.world_id = "qa_survival_unsaved"
	game.set_process(false)
	game.player.enabled = false
	game.weapons.set_physics_process(false)
	# This validator isolates the aimed main shell and exact reward accounting.
	# Natural automatic support is covered separately by --encounter-qa.
	game.weapons.set_auto_enabled(false)
	game.survival.auto_spawn = false
	game.survival.set_physics_process(false)
	game.survival.grace = 0.0
	game.survival._rng.seed = 20260913
	freeze_fleet()
	if native: RenderingServer.render_loop_enabled = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("full existing Sydney city and airport ready", game.world._ready_complete and is_instance_valid(game.airport) and game.world.structures.size() > 10000, {"structure_components": game.world.structures.size()})
	check("unsaved survival starts with 120 health, 3 medkits and $50000", game.player.health == 120.0 and game.survival.medkits == 3 and game.life.money == 50000 and game.survival.enabled)
	# Use the real Bennelong Point forecourt, with existing city-floor collision.
	var floor := floor_at(Vector3(400, 5, -95))
	check("Bennelong forecourt has existing walkable city collision", not floor.is_empty())
	if floor.is_empty(): await finish(); return
	game.player.global_position = floor.position + Vector3.UP * 0.05
	game.player.last_safe = game.player.global_position
	game.player.reset_physics_interpolation()
	game.camera.global_position = game.player.global_position + Vector3(0, 5, 20)
	game.camera.look_at(game.player.global_position + Vector3(0, 1, -25))
	game.city_clock.set_hour(16.5)
	var cast: Array = []
	for kind in ["roamer", "runner", "brute", "spitter", "alpha"]:
		var point: Vector3 = game.survival.find_spawn_position()
		check("production spawn finds safe real-city floor: " + kind, point.is_finite(), {"point": vector(point) if point.is_finite() else []})
		if not point.is_finite(): continue
		var enemy = game.survival.spawn_enemy(kind, point)
		enemy.set_target(null)
		cast.append(enemy)
		spawn_records.append({"kind": kind, "initial": vector(point)})
	for frame in 40: await get_tree().physics_frame
	for index in cast.size():
		var enemy = cast[index]
		var support := floor_at(enemy.global_position)
		var grounded: bool = enemy.is_on_floor() and not support.is_empty() and absf(enemy.global_position.y - support.position.y) < 0.2
		spawn_records[index]["settled"] = vector(enemy.global_position)
		check("spawn settles on floor without wall overlap: " + enemy.enemy_type, grounded and clear_enemy_shape(enemy), {"on_floor": enemy.is_on_floor(), "clear_capsule": clear_enemy_shape(enemy), "point": vector(enemy.global_position)})
	check("all five production enemy identities spawned", cast.size() == 5)
	# Pose the five real actors for legibility after their natural spawn is tested.
	var stage := stage_cast(cast)
	check("all five photo positions have clear city-floor capsules and sightlines", not stage.is_empty())
	if stage.is_empty(): await finish(); return
	game.player.global_position = floor_at(stage.eye).position + Vector3.UP * 0.05
	game.player.reset_physics_interpolation()
	for frame in 12: await get_tree().physics_frame
	for enemy in cast: enemy.set_target(game.player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for enemy in cast: enemy.set_physics_process(false)
	await capture("five-nailong-city-hud", stage.eye, stage.target, {"five_actual_enemy_models": true, "posed_for_capture_after_spawn_test": true})
	await sample_native_frames(cast)
	if cast.is_empty(): await finish(); return
	# Only the nearby roamer attacks; its production windup and signal do damage.
	var attacker = cast[0]
	attacker.global_position = game.player.global_position + Vector3(1.65, 0.03, 0)
	attacker.reset_physics_interpolation()
	attacker.set_target(game.player)
	attacker.set_physics_process(true)
	var before_hp: float = game.player.health
	var saw_windup := false
	var attack_frames := 0
	for frame in 180:
		await get_tree().physics_frame
		attack_frames += 1
		if attacker.state == "windup": saw_windup = true
		if game.player.health < before_hp: break
	attacker.set_target(null)
	attacker.set_physics_process(false)
	check("real nearby enemy winds up then hurts player without instant kill", saw_windup and game.player.health < before_hp and game.player.health > 0.0 and attack_frames > 10, {"before": before_hp, "after": game.player.health, "physics_frames": attack_frames, "saw_windup": saw_windup})
	var injured: float = game.player.health
	var medical_before: int = game.survival.medkits
	await key_press(KEY_H)
	check("physical H routes through main input to heal and consume one kit", game.player.health == minf(120.0, injured + 60.0) and game.survival.medkits == medical_before - 1 and game.survival.heal_cooldown > 11.0)
	await key_press(KEY_H)
	check("repeat H cannot spend another kit during cooldown", game.survival.medkits == medical_before - 1)
	await key_press(KEY_B)
	check("physical B opens paused service menu with free pointer", game.active_panel == "survival" and game.paused and get_tree().paused and game.modal.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	var medicine := find_button("补充医疗包")
	check("nearby combat allows medical supplies while full repair stays blocked", is_instance_valid(medicine) and not medicine.disabled and not game.hud.visible and not game.survival.service_block_reason().is_empty())
	await capture("services-during-combat-blocked", stage.eye, stage.target, {"physical_B": true, "full_repair_blocked_near_enemy": true, "medical_supplies_available": true})
	game.close_panel()
	game.survival.clear_enemies()
	for frame in 2: await get_tree().physics_frame
	# The actual production vehicle spawn chooses a clear nearby surface and enters.
	var tank = game.request_vehicle("tank")
	check("production free tank spawn immediately seats player", is_instance_valid(tank) and game.current_vehicle == tank and tank.occupied and tank.survival_enabled)
	if not is_instance_valid(tank): await finish(); return
	freeze_fleet()
	game.player.enabled = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	var shot_floor: Dictionary = {}
	for step in 16:
		var angle := float(step) * TAU / 16.0
		var at := floor_at(tank.global_position + Vector3(sin(angle), 0, cos(angle)) * 30.0)
		if at.is_empty(): continue
		var sight := PhysicsRayQueryParameters3D.create(tank._moving.barrel.global_position, at.position + Vector3.UP * 1.2, 1 | 4, [tank.get_rid(), game.player.get_rid()])
		if game.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
			shot_floor = at; break
	check("tank target uses open line of sight over existing city floor", not shot_floor.is_empty())
	if shot_floor.is_empty(): await finish(); return
	var target = game.survival.spawn_enemy("roamer", shot_floor.position + Vector3.UP * 0.05)
	target.set_target(null)
	for frame in 10: await get_tree().physics_frame
	target.set_physics_process(false)
	tank.set_meta("weapon_aim_offsets", {})
	game.camera.global_position = tank._moving.barrel.global_position
	game.camera.look_at(target.global_position + Vector3.UP * 1.2)
	game.weapons.clear()
	for step in 180: game.weapons.update_aim(1.0 / 60.0)
	var money_before: int = game.life.money
	var kills_before: int = game.survival.kills
	var fired_before: int = game.weapons.stats().fired
	game.fire_button.pressed.emit()
	check("production fire button launches occupied tank projectile", game.weapons.stats().fired == fired_before + 1)
	for step in 180:
		game.weapons._physics_process(1.0 / 120.0)
		await get_tree().physics_frame
		if game.survival.kills > kills_before or game.weapons.stats().active_projectiles == 0: break
	check("actual tank blast kills real enemy and credits reward once", game.survival.kills == kills_before + 1 and game.life.money == money_before + 120, {"kills_before": kills_before, "kills_after": game.survival.kills, "money_before": money_before, "money_after": game.life.money, "weapon_stats": game.weapons.stats()})
	# Street-level lens stays below the real tree crowns around this spawn area.
	var tank_eye: Vector3 = tank.global_position + Vector3(12, 2.8, 14)
	await capture("tank-survival-impact-hud", tank_eye, tank.global_position + Vector3.UP * 1.3, {"production_projectile": true, "fixed_step_seconds": 1.0 / 120.0, "frozen_tank_pose": true})
	# Let the director's actual combat timeout elapse with encounters disabled.
	game.survival.set_physics_process(true)
	for frame in 510:
		await get_tree().physics_frame
		if game.survival._hurt_clock <= 0.0: break
	game.survival.set_physics_process(false)
	check("eight-second combat timeout clears while exploration runs", game.survival._hurt_clock <= 0.0)
	var health_before: float = tank.health
	var damage: float = tank.take_combat_damage(150.0)
	game.survival.sync_fleet()
	check("survival tank armor permits damage and records shared durability", damage > 0.0 and tank.health < health_before and is_equal_approx(float(game.survival.fleet_health.tank), tank.health), {"damage_after_armor": damage, "health": tank.health})
	freeze_fleet()
	await key_press(KEY_B)
	var price: int = game.survival.repair_cost("tank")
	var repair := find_button(game.VEHICLE_NAMES.tank.split(" · ")[1] + " ·")
	check("safe B menu offers enabled paid repair", game.paused and get_tree().paused and is_instance_valid(repair) and not repair.disabled and price > 0 and game.survival.service_block_reason().is_empty(), {"cost": price, "reason": game.survival.service_block_reason()})
	await capture("services-paid-repair", tank_eye, tank.global_position + Vector3.UP * 1.3, {"cost": price, "actual_menu": true})
	money_before = game.life.money
	if is_instance_valid(repair) and not repair.disabled:
		repair.pressed.emit()
		await get_tree().process_frame
	check("real repair menu callback deducts price and restores shared fleet", tank.health == 100.0 and float(game.survival.fleet_health.get("tank", 0)) == 100.0 and game.life.money == money_before - price and game.paused, {"before": money_before, "after": game.life.money, "cost": price, "tank_health": tank.health})
	game.close_panel()
	check("leaving services resumes gameplay", not game.paused and not get_tree().paused)
	if native: check("native camera pointer is captured after services", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	await finish()

func finish():
	game.weapons.set_auto_enabled(true)
	var source_end := sources()
	var raw: Dictionary = raw_hashes(source_end)
	var readable: bool = raw.size() == SOURCES.size()
	if readable:
		check("tested source files remained unchanged during native run", source_start == source_end and raw.values().all(func(value): return not str(value).is_empty()))
	else:
		check("compiled script resources resolve; external App/PCK hashes must bind this run", source_end.values().all(func(value): return value.get("loadable", false) or not str(value.get("sha256", "")).is_empty()))
	if native: check("four intended full-city screenshots saved", screenshots.size() == 4 and screenshots.all(func(item): return item.saved))
	var passed := checks.all(func(item): return item.passed)
	var report := {"passed": passed, "count": checks.size(), "checks": checks, "screenshots": screenshots, "performance_sample": performance_sample, "native": native, "display_driver": DisplayServer.get_name(), "world_ready": game.world._ready_complete, "spawns": spawn_records, "source_sha256": raw, "source_evidence": source_end, "source_evidence_start": source_start, "source_verification": "readable source SHA256" if readable else "Compiled resources resolve only; use external final App executable/PCK SHA256 evidence to identify this tested build", "user_saves_touched": false, "save_written": false, "scope": "Full main, existing Sydney city and airport. Production spawn queries, real enemy physics/windup/damage, actual H/B input, tank projectile collision/reward and paid repair UI callback. Initial actor/camera poses frozen for reproducible native captures; fixed projectile step. Separate native 90-frame sample with active enemy AI; not a player-drive or sustained balance test."}
	FileAccess.open("user://survival-qa/report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("SURVIVAL_QA_COMPLETE ", checks.size(), " passed=", passed, " report=", ProjectSettings.globalize_path("user://survival-qa/report.json"))
	game.active = false
	game.finish_quit(0 if passed else 1)
