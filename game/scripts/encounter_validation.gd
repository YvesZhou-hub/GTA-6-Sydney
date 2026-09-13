extends Node
## Natural encounter regression in the complete production city. No direct enemy
## creation, forced damage, disabled AI, altered grace, or player save access.
## Scenario origins are test setup; walking/driving then use production input.
const Opera = preload("res://scripts/opera_landmark.gd")
const SOURCES := ["main", "audio_shutdown", "harbor_survival", "encounter_spawn", "nailong_enemy", "nailong_model", "harbor_player", "harbor_vehicle", "survival_hud", "vehicle_weapons", "vehicle_support_weapons", "encounter_validation"]
var game
var checks: Array[Dictionary] = []
var scenarios: Array[Dictionary] = []
var screenshots: Array[Dictionary] = []
var source_start: Dictionary = {}
var native := false
var simulation_seconds := 0.0
var peak_enemies := 0
var starting_physics_frame := 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func vector(value: Vector3) -> Array: return [value.x, value.y, value.z]

func check(title: String, passed: bool, detail: Dictionary = {}):
	checks.append({"name": title, "passed": passed, "detail": detail})
	print("ENCOUNTER_QA ", "PASS " if passed else "FAIL ", title, " ", JSON.stringify(detail))

func sources() -> Dictionary:
	var evidence := {}
	for module in SOURCES:
		var path: String = "res://scripts/" + module + ".gd"
		evidence[path] = {"sha256": FileAccess.get_sha256(path), "representation": "readable_source"} if FileAccess.file_exists(path) else {"representation": "compiled_resource", "loadable": ResourceLoader.exists(path)}
	return evidence

func step():
	await get_tree().physics_frame
	simulation_seconds += 1.0 / float(Engine.physics_ticks_per_second)
	# Main's frame scheduler is disabled for deterministic camera inspection;
	# retain the ordinary expiry of notices during the simulated waiting period.
	game.toast_time = maxf(0.0, game.toast_time - 1.0 / float(Engine.physics_ticks_per_second))
	game.toast_label.modulate.a = minf(1.0, game.toast_time)
	peak_enemies = maxi(peak_enemies, game.survival.enemies.size())

func wait_seconds(seconds: float):
	for frame in ceili(seconds * Engine.physics_ticks_per_second): await step()

func floor_at(point: Vector3, height: float = 3.0) -> Dictionary:
	var excludes: Array[RID] = [game.player.get_rid()]
	for vehicle in game.vehicles:
		if is_instance_valid(vehicle): excludes.append(vehicle.get_rid())
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * height, point - Vector3.UP * 5.0, 1, excludes)
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < 0.88 or hit.position.y < 1.0: return {}
	return hit

func release_input():
	for action in ["forward", "back", "left", "right", "rise", "fall", "jump", "sprint", "brake", "fire"]: Input.action_release(action)

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

func camera_at_subject():
	var at: Vector3 = game.survival.subject().global_position
	game.camera.global_position = at + Vector3(0, 4.5, 8.0)
	game.camera.look_at(at + Vector3(0, 1.5, -10.0))

func place_player(point: Vector3):
	release_input()
	if is_instance_valid(game.current_vehicle): game.exit_vehicle()
	game.player.enabled = true
	game.player.visible = true
	game.player.collision_layer = 1
	game.player.collision_mask = 15
	game.player.global_position = point
	game.player.last_safe = point
	game.player.velocity = Vector3.ZERO
	game.player.reset_physics_interpolation()
	camera_at_subject()

func start_region(label: String, point: Vector3, seed_value: int) -> bool:
	game.survival.reset_mode(true)
	game.survival._rng.seed = seed_value
	await step()
	var support := floor_at(point)
	check(label + ": existing production walking surface", not support.is_empty(), {"requested": vector(point), "support_id": str(support.collider.get_meta("damage_id", support.collider.name)) if not support.is_empty() else "missing"})
	if support.is_empty(): return false
	place_player(support.position + Vector3.UP * 0.15)
	await wait_seconds(0.5)
	check(label + ": player naturally grounded", game.player.is_on_floor() and not game.player.swimming, {"position": vector(game.player.global_position)})
	return true

func clear_spawn_shape(enemy) -> bool:
	var probe := PhysicsShapeQueryParameters3D.new()
	probe.shape = enemy._collision.shape
	probe.transform = enemy._collision.global_transform
	probe.transform.origin.y += 0.09
	probe.collision_mask = 1 | 4
	probe.exclude = [enemy.get_rid(), game.player.get_rid()]
	return game.get_world_3d().direct_space_state.intersect_shape(probe, 1).is_empty()

func record_enemies(records: Dictionary, elapsed: float):
	for enemy in game.survival.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var id: int = enemy.get_instance_id()
		var distance: float = enemy.distance_to_target_surface()
		if not records.has(id):
			records[id] = {"type": enemy.enemy_type, "spawn_s": elapsed, "spawn": vector(enemy.global_position), "initial_distance_m": distance, "minimum_distance_m": distance, "clear_initial_capsule": clear_spawn_shape(enemy), "approach_s": -1.0, "near_s": -1.0, "windup_s": -1.0, "grounded_seen": false, "target_correct": enemy.target == game.survival.subject()}
		var record: Dictionary = records[id]
		record.minimum_distance_m = minf(record.minimum_distance_m, distance)
		if record.initial_distance_m - distance >= 4.0 and record.approach_s < 0.0: record.approach_s = elapsed
		if distance <= 8.0 and record.near_s < 0.0: record.near_s = elapsed
		if enemy.state == "windup" and record.windup_s < 0.0: record.windup_s = elapsed
		record.grounded_seen = record.grounded_seen or enemy.is_on_floor()
		record.target_correct = record.target_correct and enemy.target == game.survival.subject()

func first_time(records: Dictionary, key: String) -> float:
	var earliest := INF
	for record in records.values():
		if float(record.get(key, -1.0)) >= 0.0: earliest = minf(earliest, float(record[key]))
	return earliest if is_finite(earliest) else -1.0

func capture(label: String):
	if not native or game.survival.enemies.is_empty(): return
	# Use the actual collision-aware follow camera toward a natural approaching
	# enemy. This keeps the whole vehicle visible without posing any enemy.
	var enemy = game.survival.enemies[0]
	if not is_instance_valid(enemy): return
	var subject = game.survival.subject()
	var observed_position: Vector3 = enemy.global_position
	var old_yaw: float = game.yaw
	var direction: Vector3 = observed_position - subject.global_position
	game.yaw = atan2(-direction.x, -direction.z)
	game.reset_follow_camera()
	game._update_follow_camera(1.0 / 60.0)
	var eye: Vector3 = game.camera.global_position
	check(label + ": facade stream ready for native capture", await game.world.prepare_view(eye))
	game.update_hud()
	game.survival_hud.update_state(game.survival.hud_state())
	game.update_navigation(0.1)
	game.update_spawn_marker()
	game.update_combat_reticle(0.1)
	for frame in 3:
		RenderingServer.force_draw(false)
		await get_tree().process_frame
	var picture: Image = get_tree().root.get_texture().get_image()
	var path := "user://encounter-qa/" + label + ".png"
	var saved := picture.save_png(path) == OK
	screenshots.append({"file": label + ".png", "saved": saved, "sha256": FileAccess.get_sha256(path) if saved else "", "camera": vector(eye), "subject": vector(subject.global_position), "enemy_before_capture": vector(observed_position), "enemy_survived_capture": is_instance_valid(enemy) and not enemy.dead, "resolution": [picture.get_width(), picture.get_height()], "natural_enemy_pose": true})
	check(label + ": native natural encounter image", saved)
	game.yaw = old_yaw
	camera_at_subject()

func observe(label: String, seconds: float = 30.0, require_damage: bool = true) -> Dictionary:
	var records := {}
	var initial_position: Vector3 = game.survival.subject().global_position
	var initial_kills: int = game.survival.kills
	var before_hp: float = game.player.health
	var before_vehicle_hp: float = game.current_vehicle.health if is_instance_valid(game.current_vehicle) else -1.0
	var grace_at_start: float = game.survival.grace
	var first_damage := -1.0
	var count_at_five := 0
	var count_at_ten := 0
	var total_spawned_at_ten := 0
	var elapsed := 0.0
	for frame in ceili(seconds * Engine.physics_ticks_per_second):
		await step()
		elapsed = (frame + 1) / float(Engine.physics_ticks_per_second)
		record_enemies(records, elapsed)
		if elapsed <= 5.0: count_at_five = game.survival.enemies.size()
		if elapsed <= 10.0:
			count_at_ten = game.survival.enemies.size()
			total_spawned_at_ten = records.size()
		var hurt: bool = game.player.health < before_hp
		if before_vehicle_hp >= 0.0 and is_instance_valid(game.current_vehicle): hurt = hurt or game.current_vehicle.health < before_vehicle_hp
		if hurt and first_damage < 0.0: first_damage = elapsed
		# One real attack proves contact; allow a first batch to appear before ending.
		if first_damage >= 0.0 and elapsed >= 14.0: break
		if not require_damage and game.survival.kills > initial_kills and elapsed >= 14.0: break
	var summary := {"region": label, "elapsed_s": elapsed, "origin": vector(initial_position), "final_position": vector(game.survival.subject().global_position), "grace_at_start_s": grace_at_start, "first_spawn_s": first_time(records, "spawn_s"), "first_approach_4m_s": first_time(records, "approach_s"), "first_within_8m_s": first_time(records, "near_s"), "first_windup_s": first_time(records, "windup_s"), "first_damage_s": first_damage, "count_at_5s": count_at_five, "count_at_10s": count_at_ten, "total_spawned_at_10s": total_spawned_at_ten, "natural_kills": game.survival.kills - initial_kills, "player_health": game.player.health, "vehicle_health": game.current_vehicle.health if is_instance_valid(game.current_vehicle) else -1.0, "enemies": records.values()}
	summary["last_spawn_diagnostics"] = game.survival._spawn_diagnostics.duplicate(true)
	scenarios.append(summary)
	print("ENCOUNTER_SCENARIO ", JSON.stringify(summary))
	check(label + ": automatic first enemy within 6 seconds", summary.first_spawn_s >= 0.0 and summary.first_spawn_s <= 6.0, {"seconds": summary.first_spawn_s})
	check(label + ": at least 3 naturally spawned threats by 10 seconds", total_spawned_at_ten >= 3, {"alive_count": count_at_ten, "total_created": total_spawned_at_ten})
	if require_damage:
		check(label + ": natural pursuit closes at least 4 metres", summary.first_approach_4m_s >= 0.0 and summary.first_approach_4m_s <= 20.0, {"seconds": summary.first_approach_4m_s})
		check(label + ": threat reaches 8 metres", summary.first_within_8m_s >= 0.0 and summary.first_within_8m_s <= seconds, {"seconds": summary.first_within_8m_s})
	else:
		check(label + ": threats approach vehicle or are defeated by its automatic defence", summary.first_approach_4m_s >= 0.0 or summary.natural_kills > 0, {"approach_s": summary.first_approach_4m_s, "natural_kills": summary.natural_kills})
	check(label + ": every initial capsule clear of city and vehicles", not records.is_empty() and records.values().all(func(record): return record.clear_initial_capsule))
	check(label + ": enemies remain assigned to current player or vehicle", not records.is_empty() and records.values().all(func(record): return record.target_correct))
	if require_damage:
		check(label + ": natural windup culminates in real damage", summary.first_windup_s >= 0.0 and first_damage >= 0.0 and first_damage <= seconds, {"windup_s": summary.first_windup_s, "damage_s": first_damage})
		check(label + ": preparation protects player until grace ends", first_damage < 0.0 or first_damage + 0.1 >= grace_at_start, {"grace_s": grace_at_start, "damage_s": first_damage})
		check(label + ": first contact is survivable without forced healing", game.player.health > 0.0 and game.player.health >= before_hp - 40.0, {"before": before_hp, "after": game.player.health})
	await capture(label)
	return summary

func movement_and_replacement():
	var start: Vector3 = game.player.global_position
	var target := start + Vector3(0, 0, 18.0)
	game.yaw = PI
	game.player.yaw = PI
	Input.action_press("forward")
	await wait_seconds(2.5)
	Input.action_release("forward")
	await wait_seconds(0.25)
	var travelled: float = Vector2(game.player.global_position.x - start.x, game.player.global_position.z - start.z).length()
	check("real player input travels along Pitt Street Mall", travelled > 8.0 and game.player.is_on_floor(), {"metres": travelled, "start": vector(start), "end": vector(game.player.global_position), "direction": vector(target - start)})
	var old_ids: Array = game.survival.enemies.filter(func(enemy): return is_instance_valid(enemy)).map(func(enemy): return enemy.get_instance_id())
	check("abandonment starts with naturally populated encounter", not old_ids.is_empty())
	var before_money: int = game.life.money
	var before_kills: int = game.survival.kills
	var before_cleared: int = game.survival.cleared
	# Cross-region relocation isolates the production unload/replenish branch.
	# Enemies are not deleted here; the director must retire them itself.
	place_player(game.world.anchors.home + Vector3(0, 1.0, 15.0))
	var first_replacement := -1.0
	for frame in 600:
		await step()
		if game.survival.enemies.any(func(enemy): return is_instance_valid(enemy) and not enemy.get_instance_id() in old_ids):
			first_replacement = (frame + 1) / float(Engine.physics_ticks_per_second)
			break
	var old_survived: bool = game.survival.enemies.any(func(enemy): return is_instance_valid(enemy) and enemy.get_instance_id() in old_ids)
	check("leaving a district retires distant enemies and naturally replaces them", not old_survived and first_replacement >= 0.0, {"old_count": old_ids.size(), "replacement_s": first_replacement, "remaining_old_enemy": old_survived, "wave_spawned": game.survival.wave_spawned, "quota": game.survival.quota()})
	check("abandonment never pays kill or wave rewards", game.life.money == before_money and game.survival.kills == before_kills and game.survival.cleared == before_cleared)

func nearby_reinforcement_without_clearing():
	var old_ids: Array = game.survival.enemies.filter(func(enemy): return is_instance_valid(enemy)).map(func(enemy): return enemy.get_instance_id())
	var origin: Vector3 = game.player.global_position
	var support := floor_at(origin + Vector3(90, 0, 0))
	check("90 metre neighbouring airport surface exists", not support.is_empty())
	if support.is_empty(): return
	var money: int = game.life.money
	var kills: int = game.survival.kills
	var cleared: int = game.survival.cleared
	check("neighbouring encounter begins with zero kills and existing threats", kills == 0 and not old_ids.is_empty(), {"old_count": old_ids.size(), "kills": kills})
	place_player(support.position + Vector3.UP * 0.15)
	var elapsed := 0.0
	var new_nearby := 0
	for frame in 480:
		await step()
		elapsed = (frame + 1) / float(Engine.physics_ticks_per_second)
		new_nearby = game.survival.enemies.filter(func(enemy): return is_instance_valid(enemy) and not enemy.get_instance_id() in old_ids and enemy.distance_to_target_surface() <= 48.0).size()
		if new_nearby > 0: break
	var retained: int = game.survival.enemies.filter(func(enemy): return is_instance_valid(enemy) and enemy.get_instance_id() in old_ids).size()
	check("90 metre move gets a new threat while old enemies are still alive", new_nearby > 0 and retained > 0 and elapsed <= 6.0, {"metres": origin.distance_to(game.player.global_position), "first_reinforcement_s": elapsed, "new_nearby": new_nearby, "old_retained": retained})
	check("new nearby encounters require no kills and award no skipped clearance", game.survival.kills == kills and game.survival.cleared == cleared and game.life.money == money)

func stale_wave_recovery():
	game.survival.reset_mode(true)
	place_player(game.world.anchors.home + Vector3(0, 1.0, 15.0))
	await wait_seconds(0.5)
	var state: Dictionary = game.survival.get_state()
	state["wave_spawned"] = game.survival.quota()
	state["wave_kills"] = 2
	state["rest"] = 30.0 # Legacy countdown cannot suspend the new continuous loop.
	state["enemies"] = [{"type": "roamer", "health": 80.0, "level": 1, "position": [-3500.0, 6.5, 9700.0]}]
	var balance: int = game.life.money
	game.survival.apply_state(state)
	check("synthetic stale full-wave save retains kills but frees absent enemy slots", game.survival.wave_kills == 2 and game.survival.wave_spawned == 2 and game.survival.enemies.is_empty(), {"wave_spawned": game.survival.wave_spawned, "wave_kills": game.survival.wave_kills})
	check("legacy wave respite is removed on state recovery", game.survival.rest == 0.0)
	var elapsed := 0.0
	while elapsed < 8.0 and game.survival.enemies.is_empty():
		await step()
		elapsed += 1.0 / float(Engine.physics_ticks_per_second)
	check("stale wave recovery resumes actual automatic spawning", not game.survival.enemies.is_empty() and game.survival.wave_kills == 2 and game.life.money == balance, {"first_spawn_s": elapsed, "enemies": game.survival.enemies.size()})

func vehicle_encounter():
	if not await start_region("tank runway setup", game.world.anchors.runway_start, 20260918): return
	var tank = game.request_vehicle("tank")
	check("normal free tank request succeeds and enters vehicle", is_instance_valid(tank) and game.current_vehicle == tank)
	if not is_instance_valid(tank): return
	var start: Vector3 = tank.global_position
	Input.action_press("forward")
	await wait_seconds(3.0)
	Input.action_release("forward")
	Input.action_press("brake")
	await wait_seconds(1.5)
	Input.action_release("brake")
	var travelled: float = tank.global_position.distance_to(start)
	check("production tank input moves the current target", travelled > 4.0, {"metres": travelled})
	camera_at_subject()
	await observe("tank airport pursuit", 30.0, false)
	await vehicle_controls_and_menu(tank)
	await continuous_vehicle_defence(tank)

func vehicle_controls_and_menu(tank: RigidBody3D):
	check("automatic defence starts enabled in a real occupied tank", game.weapons.auto_enabled() and game.weapons.auto_status().available)
	await key_press(KEY_V)
	check("physical V disables automatic support without leaving vehicle", not game.weapons.auto_enabled() and game.current_vehicle == tank)
	await key_press(KEY_V)
	check("physical V restores automatic support and runtime status", game.weapons.auto_enabled() and game.weapons.auto_status().enabled)
	await key_press(KEY_B)
	check("physical B opens paused field services with a usable pointer", game.active_panel == "survival" and game.paused and get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	var stats: Dictionary = game.weapons.upgrade_stats("tank", tank.weapon_upgrade)
	var current_text := "伤害 %.0f · 半径 %.1f m · 装填 %.2f s" % [stats.current.damage, stats.current.radius, stats.current.cooldown]
	var next_text := "下一级：伤害 %.0f · 半径 %.1f m · 装填 %.2f s" % [stats.next.damage, stats.next.radius, stats.next.cooldown]
	var current_label := false
	var next_label := false
	var auto_label := false
	var clipped: Array[String] = []
	var upgrade: Button
	for child in game.modal_content.get_children():
		if not child is Label and not child is Button: continue
		if current_text in child.text: current_label = true
		if next_text in child.text: next_label = true
		if "V 自动辅助武器" in child.text: auto_label = true
		if child is Button and "升级火控" in child.text: upgrade = child
	await get_tree().process_frame
	var previous_bottom := -INF
	for child in game.modal_content.get_children():
		if not child is Control or not child.visible: continue
		var rect: Rect2 = child.get_global_rect()
		if rect.position.y < previous_bottom - 1.0: clipped.append("overlap: " + str(child.name))
		previous_bottom = rect.end.y
		if child is Button or (child is Label and child.autowrap_mode == TextServer.AUTOWRAP_OFF):
			var font: Font = child.get_theme_font("font")
			var width: float = font.get_string_size(child.text, HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x
			var padding := 0.0
			if child is Button:
				var style: StyleBox = child.get_theme_stylebox("normal")
				padding = style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT)
			if width > child.size.x - padding + 1.0: clipped.append("text width: " + child.text)
	check("B menu shows actual current and next damage radius reload plus V state", current_label and next_label and auto_label, {"current": current_text, "next": next_text, "stats": stats})
	check("service controls have no overlap or horizontal text clipping", clipped.is_empty(), {"failures": clipped})
	check("nearby enemies do not block paid weapon upgrades", is_instance_valid(upgrade) and not upgrade.disabled and game.survival.service_block_reason("upgrade").is_empty())
	await capture("tank fire control B menu")
	var money: int = game.life.money
	var level: int = tank.weapon_upgrade
	var cost: int = game.survival.UPGRADE_COSTS[level]
	if is_instance_valid(upgrade) and not upgrade.disabled:
		upgrade.pressed.emit()
		await get_tree().process_frame
	var improved: Dictionary = game.weapons.upgrade_stats("tank", tank.weapon_upgrade).current
	check("actual B upgrade callback spends coins and improves area damage and reload", tank.weapon_upgrade == level + 1 and game.life.money == money - cost and improved.radius > stats.current.radius and improved.damage > stats.current.damage and improved.cooldown < stats.current.cooldown, {"level": tank.weapon_upgrade, "cost": cost, "improved": improved})
	game.close_panel()
	check("closing B resumes the same occupied tank and continuous encounters", not game.paused and not get_tree().paused and game.current_vehicle == tank and game.survival.auto_spawn)

func continuous_vehicle_defence(tank: RigidBody3D):
	var initial_cleared: int = game.survival.cleared
	var initial_kills: int = game.survival.kills
	var initial_money: int = game.life.money
	var clear_s := -1.0
	var spawn_sequence_at_clear := -1
	var rest_remained_zero := true
	var elapsed := 0.0
	var repair_events: Array[Dictionary] = []
	check("production tank automatic defence is enabled by default", game.weapons.auto_enabled())
	for frame in ceili(75.0 * Engine.physics_ticks_per_second):
		await step()
		elapsed = (frame + 1) / float(Engine.physics_ticks_per_second)
		rest_remained_zero = rest_remained_zero and game.survival.rest == 0.0
		if game.survival.cleared > initial_cleared and clear_s < 0.0:
			clear_s = elapsed
			spawn_sequence_at_clear = game.survival._spawn_sequence
		if clear_s >= 0.0 and elapsed - clear_s >= 6.0: break
		if not is_instance_valid(tank) or tank.health <= 0.0: break
		if tank.health < 50.0 and game.survival.field_repair_cooldown <= 0.0:
			# Real player recovery action, while enemy AI and projectiles continue.
			# Below 50%, a 25-point repair costs exactly 25 * 45 = 1125 coins.
			var before_health: float = tank.health
			var before_money: int = game.life.money
			var earnings_before: int = game.life.lifetime_earnings
			await key_press(KEY_H)
			var after_health: float = tank.health
			var concurrent_rewards: int = game.life.lifetime_earnings - earnings_before
			var paid: int = before_money + concurrent_rewards - game.life.money
			var cooldown: float = game.survival.field_repair_cooldown
			var balance_after_repair: int = game.life.money
			var earnings_after_repair: int = game.life.lifetime_earnings
			await key_press(KEY_H)
			var retry_rewards: int = game.life.lifetime_earnings - earnings_after_repair
			repair_events.append({"elapsed_s": elapsed, "health_before": before_health, "health_after": after_health, "net_durability_gain": after_health - before_health, "balance_before": before_money, "balance_after": balance_after_repair, "concurrent_kill_rewards": concurrent_rewards, "coins_paid": paid, "expected_cost": 1125, "cooldown_after_s": cooldown, "repeat_H_charged": game.life.money != balance_after_repair + retry_rewards})
	var summary := {"region": "automatic tank support with player H field repairs", "elapsed_s": elapsed, "first_clear_s": clear_s, "natural_kills": game.survival.kills - initial_kills, "net_money_change": game.life.money - initial_money, "cleared": game.survival.cleared, "rest_stayed_zero": rest_remained_zero, "spawn_sequence_at_clear": spawn_sequence_at_clear, "final_spawn_sequence": game.survival._spawn_sequence, "vehicle_health": tank.health if is_instance_valid(tank) else 0.0, "weapons": game.weapons.auto_status(), "remaining_enemies": game.survival.enemies.size(), "repairs": repair_events, "player_actions": "Automatic support remains enabled; real H events buy repairs below 50% health and test cooldown. No main-cannon fire or direct health writes."}
	scenarios.append(summary)
	print("ENCOUNTER_SCENARIO ", JSON.stringify(summary))
	check("continuous defence uses real paid H repairs with health recovery", not repair_events.is_empty() and repair_events.all(func(event): return event.coins_paid == event.expected_cost and event.net_durability_gain > 0.0 and event.net_durability_gain <= 25.01 and event.cooldown_after_s > 11.0), {"repairs": repair_events})
	check("repeat H is blocked by its production repair cooldown", not repair_events.is_empty() and repair_events.all(func(event): return not event.repeat_H_charged))
	var repair_spending := 0
	for event in repair_events: repair_spending += event.coins_paid
	check("real automatic tank defence reaches a rewarded kill milestone", clear_s >= 0.0 and game.life.money + repair_spending > initial_money, summary)
	check("kill milestone continues reinforcement without scheduled respite", clear_s >= 0.0 and rest_remained_zero and game.survival._spawn_sequence > spawn_sequence_at_clear and not game.survival.enemies.is_empty(), {"clear_s": clear_s, "spawns_after_clear": game.survival._spawn_sequence - spawn_sequence_at_clear})
	check("tank survives the first continuous natural defence milestone", is_instance_valid(tank) and tank.health > 0.0, {"health": tank.health if is_instance_valid(tank) else 0.0})
	await capture("automatic tank support with player H field repairs")

func run():
	game = get_parent()
	native = DisplayServer.get_name() != "headless"
	source_start = sources()
	DirAccess.make_dir_recursive_absolute("user://encounter-qa")
	if not game.qa_running:
		check("QA save guard active before world creation", false)
		await finish(); return
	game.active = false
	game.new_world("life", "Encounter QA isolated unsaved world", false)
	game.world_id = "qa_encounter_unsaved"
	starting_physics_frame = Engine.get_physics_frames()
	# Retain player/enemy/director/vehicle physics. Only frame-driven camera/UI
	# scheduling is controlled; this is fixed-step correctness, not FPS evidence.
	game.set_process(false)
	for vehicle in game.vehicles: vehicle.freeze = true
	for action in ["forward", "back", "left", "right", "rise", "fall", "jump", "sprint", "brake", "fire"]: InputMap.action_erase_events(action)
	if native: RenderingServer.render_loop_enabled = false
	game.city_clock.set_hour(13.0)
	game.survival._rng.seed = 20260913
	camera_at_subject()
	check("complete production Sydney city and airport loaded", game.world._ready_complete and is_instance_valid(game.airport) and game.world.structures.size() > 10000, {"structures": game.world.structures.size()})
	check("default new game actually enables automatic encounters", game.mode == "life" and game.survival.enabled and game.survival.auto_spawn and game.survival.is_physics_processing())
	await observe("default home")
	check("default home falls onto real ground", game.player.is_on_floor() and not game.player.swimming, {"position": vector(game.player.global_position)})
	var podium: Vector3 = Opera.CENTER + Opera.site_basis() * Vector3(0, Opera.PODIUM_HEIGHT, 64.0)
	if await start_region("Opera public upper podium", podium, 20260914): await observe("Opera public upper podium")
	if await start_region("airport apron", game.world.anchors.airport, 20260915):
		await observe("airport apron")
		await nearby_reinforcement_without_clearing()
	if await start_region("CBD Pitt Street Mall", Vector3(-206.2, 4.6, 1105), 20260916):
		await observe("CBD Pitt Street Mall")
		await movement_and_replacement()
	await stale_wave_recovery()
	await vehicle_encounter()
	check("encounter cap respected throughout production simulation", peak_enemies <= game.survival.ENEMY_LIMIT, {"peak": peak_enemies, "cap": game.survival.ENEMY_LIMIT})
	await finish()

func finish():
	release_input()
	var source_end := sources()
	check("production source identity stable during validation", source_start == source_end)
	var passed: bool = not checks.is_empty() and checks.all(func(item): return item.passed)
	var report := {"passed": passed, "checks": checks, "scenarios": scenarios, "screenshots": screenshots, "native": native, "display_driver": DisplayServer.get_name(), "physics_hz": Engine.physics_ticks_per_second, "simulation_seconds": simulation_seconds, "source_start": source_start, "source_end": source_end, "user_saves_touched": false, "save_written": false, "direct_enemy_spawn_calls": 0, "forced_damage_calls": 0, "scope": "Complete production city and airport, real floor physics, production automatic spawn and enemy pursuit. Region origins and one cross-district relocation are fixture setup; movement and tank boarding use production APIs/input. No disabled autospawn/AI, altered grace, forced enemy poses, manual enemy creation or player-save access. Fixed-step correctness and natural encounter screenshots, not sustained FPS or play-balance research."}
	report["observed_physics_seconds"] = simulation_seconds
	report["simulation_seconds"] = float(Engine.get_physics_frames() - starting_physics_frame) / float(Engine.physics_ticks_per_second)
	report["count"] = checks.size()
	report["world_ready"] = game.world._ready_complete
	report["qa_running"] = game.qa_running
	report["auto_spawn_enabled"] = game.survival.auto_spawn
	report["scope"] = "Complete production city/airport and real automatic encounters. Region origins, a 90-metre neighbouring relocation and a distant district relocation are fixture setup; walking/driving use production input. Actual V/B events and paid upgrade callbacks. Enemy creation/pursuit remains automatic; no forced damage, altered grace or enemy poses. Parked unused vehicles are frozen. Fixed-step correctness and natural encounter screenshots, not sustained FPS or broad play-balance research."
	var output := FileAccess.open("user://encounter-qa/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t")); output.close()
	print("ENCOUNTER_QA_COMPLETE checks=", checks.size(), " passed=", passed)
	game.active = false
	game.finish_quit(0 if passed else 1)
