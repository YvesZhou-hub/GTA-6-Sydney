extends SceneTree
## Isolated real enemy signals, real Jolt occlusion and real Camera3D projection.
## No city build, player save access, fabricated HP loss or economy transactions.
const Feedback = preload("res://scripts/combat_feedback.gd")
const Enemy = preload("res://scripts/nailong_enemy.gd")
const SurvivalHUD = preload("res://scripts/survival_hud.gd")
const Fonts = preload("res://scripts/ui_fonts.gd")
var checks: Array[Dictionary] = []
var host: HostFixture
var feedback: Control
var canvas: CanvasLayer
var report_states: Dictionary = {}
var pictures: Array[String] = []
var enemy_nodes: Array[Node3D] = []

class Director extends Node:
	var enabled := true

class WeaponStatus extends Node:
	var status: Dictionary = {"locked": false, "target_id": 0, "modules": {"locks": {}}}
	func auto_status() -> Dictionary: return status

class HostFixture extends Node3D:
	var active := true
	var paused := false
	var quitting := false
	var camera: Camera3D
	var player: CharacterBody3D
	var current_vehicle: RigidBody3D
	var modal: Control
	var map_panel: Control
	var hud: Control
	var survival: Director
	var weapons: WeaponStatus


func _initialize() -> void:
	call_deferred("run")


func check(label: String, passed: bool, detail: Variant = null) -> void:
	var row := {"name": label, "passed": passed}
	if detail != null: row.detail = detail
	checks.append(row)
	print("PASS " if passed else "FAIL ", label)


func _enemy(type: String, at: Vector3, level := 1) -> Node3D:
	var result := Enemy.new()
	result.configure(type, level)
	host.add_child(result)
	result.position = at
	result.reset_physics_interpolation()
	result.set_physics_process(false)
	enemy_nodes.append(result)
	feedback.register_enemy(result)
	return result


func _step(seconds := 0.016) -> void:
	feedback._scan_left = 0.0
	feedback._process(seconds)


func _reset_enemies() -> void:
	feedback.clear()
	for enemy: Node3D in enemy_nodes:
		if is_instance_valid(enemy): enemy.free()
	enemy_nodes.clear()
	host.weapons.status = {"locked": false, "target_id": 0, "modules": {"locks": {}}}
	feedback.set_reserved_rects([])


func _rect(data: Array) -> Rect2:
	return Rect2(data[0], data[1], data[2], data[3])


func _layout_valid() -> bool:
	var occupied: Array[Rect2] = []
	for view: Dictionary in feedback._bars + feedback._draw_numbers:
		var rect: Rect2 = view.rect
		if not Rect2(Vector2.ZERO, feedback.size).encloses(rect): return false
		for reserved: Rect2 in feedback._reserved:
			if rect.intersects(reserved): return false
		for existing: Rect2 in occupied:
			if rect.intersects(existing): return false
		occupied.append(rect)
	return true


func _box(at: Vector3, dimensions: Vector3, layer := 1) -> StaticBody3D:
	var result := StaticBody3D.new()
	result.collision_layer = layer
	result.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	result.add_child(collision)
	host.add_child(result)
	result.position = at
	return result


func _panel(at: Vector2, dimensions: Vector2, title: String) -> Control:
	var panel := Panel.new()
	panel.position = at
	panel.size = dimensions
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102c34")
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	host.hud.add_child(panel)
	var label := Label.new()
	label.text = title
	label.position = Vector2(14, 12)
	label.theme = Fonts.make_theme(18)
	panel.add_child(label)
	return panel


func _visual_scene() -> void:
	var floor := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(120, 120)
	floor.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("4d6764")
	material.roughness = 0.82
	floor.material_override = material
	host.add_child(floor)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("1c3746")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("9dbfdb")
	environment.environment.ambient_light_energy = 0.65
	host.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -30, 0)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	host.add_child(sun)
	_panel(Vector2(28, 24), Vector2(365, 105), "HARBOURLIFE  /  战斗反馈实测")
	var map := _panel(Vector2(1094, 66), Vector2(318, 230), "导航 / 原生小场景")
	map.name = "MapFixture"
	var bottom := _panel(Vector2(28, 774), Vector2(1384, 102), "W/S 移动  ·  X 主炮  ·  V 自动锁定  ·  H 快修\n血量与浮字来自实际扣血；此场景没有修改金币")
	bottom.name = "BottomFixture"
	var hud := SurvivalHUD.new()
	host.hud.add_child(hud)
	hud.setup(host)
	hud.update_state({"active":true, "player_health":92, "max_health":120, "enemy_count":7,
		"kills":2, "medkits":3, "money":50000, "vehicle_active":true, "vehicle_health":78,
		"vehicle_name":"Harbour Bastion · 坦克", "field_repair_cost":990, "field_repair_cooldown":0,
		"phase":"持续战斗 Lv.12", "objective":"清理街区 · 实際命中反馈"})
	hud.set_process(false)


func _capture() -> void:
	_visual_scene()
	root.title = "Harbourlife Combat Feedback — actual enemy damage"
	for dimensions: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 720)]:
		_reset_enemies()
		root.size = dimensions
		root.content_scale_size = Vector2i.ZERO
		feedback.size = Vector2(dimensions)
		host.hud.size = Vector2(dimensions)
		var map: Control = host.hud.get_node("MapFixture")
		map.position.x = dimensions.x - 346
		var bottom: Control = host.hud.get_node("BottomFixture")
		bottom.position.y = dimensions.y - 126
		bottom.size.x = dimensions.x - 56
		host.camera.position = Vector3(0, 5.5, 18)
		host.camera.look_at(Vector3(0, 2.8, -4))
		var roamer := _enemy("roamer", Vector3(-4, 0, -2), 3)
		var brute := _enemy("brute", Vector3(1.7, 0, -7), 12)
		var alpha := _enemy("alpha", Vector3(8, 0, -12), 16)
		var runner := _enemy("runner", Vector3(-7, 0, -11), 5)
		_enemy("spitter", Vector3(-2, 0, -16), 9)
		var winglet := _enemy("winglet", Vector3(4, 6, -19), 10)
		_enemy("stormwing", Vector3(-7, 8, -26), 15)
		host.weapons.status = {"locked":true, "target_id":brute.get_instance_id(), "modules":{"locks":{"laser":winglet.get_instance_id()}}}
		await process_frame
		await physics_frame
		roamer.set_meta("damage_style", "cannon")
		roamer.take_damage(41.5, roamer.global_position + Vector3.UP * 1.5)
		brute.set_meta("damage_style", "rotary")
		for value: float in [3.25, 6.5, 8.25]: brute.take_damage(value, brute.global_position + Vector3.UP * 2)
		alpha.set_meta("damage_style", "splash")
		alpha.take_damage(86.4, alpha.global_position + Vector3.UP * 3)
		runner.set_meta("damage_style", "cannon")
		runner.take_damage(9999, runner.global_position + Vector3.UP)
		_step(0.03)
		await process_frame
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://../reports/combat-feedback/feedback-%dx%d.png" % [dimensions.x, dimensions.y])
		var saved := screenshot.save_png(path)
		check("native feedback screenshot %s" % dimensions, saved == OK and not screenshot.is_empty())
		check("native HUD and damage overlays do not overlap %s" % dimensions, _layout_valid())
		pictures.append(path)
		report_states[str(dimensions)] = feedback.snapshot()


func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1440, 900)
	host = HostFixture.new()
	root.add_child(host)
	host.survival = Director.new()
	host.add_child(host.survival)
	host.weapons = WeaponStatus.new()
	host.add_child(host.weapons)
	host.camera = Camera3D.new()
	host.add_child(host.camera)
	host.camera.position = Vector3(0, 5, 18)
	host.camera.look_at(Vector3(0, 2.5, 0))
	host.camera.current = true
	canvas = CanvasLayer.new()
	root.add_child(canvas)
	host.hud = Control.new()
	canvas.add_child(host.hud)
	host.hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key: String in ["modal", "map_panel"]:
		var panel := Control.new()
		panel.visible = false
		canvas.add_child(panel)
		host.set(key, panel)
	feedback = Feedback.new()
	canvas.add_child(feedback)
	canvas.move_child(feedback, 0)
	feedback.setup(host)
	feedback.set_process(false)
	await process_frame
	var enemy := _enemy("roamer", Vector3.ZERO)
	await physics_frame
	_step()
	check("active encounter feedback is visible and input-transparent", feedback.visible and feedback.mouse_filter == Control.MOUSE_FILTER_IGNORE and feedback.focus_mode == Control.FOCUS_NONE)
	check("feedback draws below existing HUD", feedback.get_index() < host.hud.get_index())
	check("actual enemy registration creates screen-space health and suppresses 3D labels", feedback.snapshot().bars.size() == 1 and not enemy._label.visible and not enemy._bar.visible)
	feedback.register_enemy(enemy)
	check("duplicate registration cannot duplicate damage callbacks", enemy.get_signal_connection_list("damaged").size() == 1 and feedback.snapshot().registered == 1)
	enemy.set_meta("damage_style", "cannon")
	var actual: float = enemy.take_damage(12.5)
	_step()
	var state: Dictionary = feedback.snapshot()
	check("real fractional cannon damage shows exact HP loss", actual == 12.5 and state.floating[0].text == "−12.5" and state.actual_damage == 12.5)
	check("health bar shows remaining and maximum numeric HP", state.bars[0].health == 67.5 and state.bars[0].maximum == 80 and "Lv.1 游荡奶龙" == state.bars[0].label)
	check("damage trail preserves previous HP briefly", state.bars[0].trail == 80 and state.bars[0].health < state.bars[0].trail)
	check("cannon numbers are larger than automatic rounds", Feedback._number_size("cannon") > Feedback._number_size("rotary"))
	enemy.set_meta("damage_style", "rotary")
	for amount: float in [2.25, 3.4, 3.35]: enemy.take_damage(amount)
	_step()
	state = feedback.snapshot()
	check("continuous fire merges short burst as unrounded actual sum", state.floating.size() == 2 and is_equal_approx(state.floating[1].amount, 9) and state.floating[1].text == "−9" and state.floating[1].hits == 3)
	check("shell and automatic damage remain separate", state.floating[0].style == "cannon" and state.floating[1].style == "rotary")
	_step(0.2)
	enemy.take_damage(0.5)
	check("later burst begins a new number", feedback.snapshot().floating.size() == 3)
	enemy.set_meta("damage_style", "cannon")
	enemy.take_damage(3)
	check("individual shells never merge", feedback.snapshot().floating.filter(func(n): return n.style == "cannon").size() == 2)
	var before: float = enemy.health
	var displayed_before: float = feedback.snapshot().actual_damage
	actual = enemy.take_damage(10000)
	_step()
	state = feedback.snapshot()
	check("overkill only displays HP actually removed", actual == before and is_equal_approx(state.actual_damage - displayed_before, before) and state.floating[-2].amount == before)
	check("fatal damage keeps zero-HP bar briefly", state.bars.size() == 1 and state.bars[0].health == 0)
	check("defeat reward is separate from damage", state.floating[-1].kind == "reward" and state.floating[-1].text == "击败  +120 金币" and state.floating[-1].amount == 0)
	enemy.take_damage(10000)
	enemy.defeated.emit(enemy, 120)
	check("dead hits and repeated defeat cannot duplicate damage or reward", feedback.snapshot().actual_damage == state.actual_damage and feedback.snapshot().reward_events == 1)
	for i: int in 4: _step(0.2)
	check("zero-HP bar expires without hiding surviving damage numbers", feedback.snapshot().bars.is_empty() and not feedback.snapshot().floating.is_empty())
	for i: int in 8: _step(0.2)
	check("floating damage and reward have bounded lifetimes", feedback.snapshot().floating.is_empty())
	check("number formatting keeps whole values clean and necessary decimal", Feedback.format_amount(35.0) == "35" and Feedback.format_amount(12.46) == "12.5" and Feedback.format_amount(NAN) == "0")
	check("positive tiny damage is never shown as zero", Feedback.format_amount(0.0001) == "<0.1" and Feedback.format_amount(0.03) == "<0.1" and Feedback.format_amount(0) == "0")
	_reset_enemies()
	var centre_enemy := _enemy("roamer", Vector3(-4, 0, 0))
	var edge_enemy := _enemy("roamer", Vector3(4, 0, 0))
	centre_enemy.set_meta("damage_style", "cannon")
	edge_enemy.set_meta("damage_style", "splash")
	var common_blast := Vector3(0, 1, 0)
	centre_enemy.take_damage(25, common_blast)
	edge_enemy.take_damage(9, common_blast)
	_step()
	var points: Array = feedback._numbers.map(func(n: Dictionary): return n.point)
	check("shared blast centre keeps damage anchored to separate victims", points.size() == 2 and points[0].distance_to(points[1]) > 7.0 and points[0].distance_to(centre_enemy.global_position) < 2.0 and points[1].distance_to(edge_enemy.global_position) < 2.0)
	check("separate blast victims have separated projected damage", feedback._draw_numbers.size() == 2 and not feedback._draw_numbers[0].rect.intersects(feedback._draw_numbers[1].rect), {"views":feedback._draw_numbers, "bars":feedback.snapshot().bars, "size":feedback.size})
	_reset_enemies()
	enemy = _enemy("alpha", Vector3.ZERO, 10)
	enemy.set_meta("damage_style", "default")
	for i: int in 60: enemy.take_damage(1)
	_step()
	check("dense fire has fixed 48-number memory cap without changing actual totals", feedback.snapshot().floating.size() == 48 and feedback.snapshot().actual_damage == 60 and enemy.max_health - enemy.health == 60)
	var count: int = feedback.snapshot().damage_events
	for invalid: float in [NAN, INF, -2.0, 0.0]: enemy.take_damage(invalid)
	check("invalid and zero damage never generate floating numbers", feedback.snapshot().damage_events == count)
	var paused_clock: float = feedback.snapshot().clock
	for flag: String in ["paused", "quitting"]:
		host.set(flag, true)
		_step(0.2)
		check("%s hides feedback and freezes its presentation time" % flag, not feedback.visible and feedback.snapshot().clock == paused_clock)
		host.set(flag, false)
	var panel_index := 0
	for panel: Control in [host.modal, host.map_panel]:
		panel.show()
		_step()
		check("visible %s hides feedback" % ("menu" if panel_index == 0 else "map"), not feedback.visible)
		panel.hide()
		panel_index += 1
	host.active = false
	_step()
	check("title or loading screen never shows enemies", not feedback.visible)
	host.active = true
	host.survival.enabled = false
	_step()
	check("sightseeing without encounters hides combat feedback", not feedback.visible)
	host.survival.enabled = true
	paused = true
	_step()
	check("SceneTree pause hides feedback even if host flag is false", not feedback.visible)
	paused = false
	_step()
	check("closing overlays restores valid gameplay feedback", feedback.visible)
	_reset_enemies()
	enemy = _enemy("roamer", Vector3.ZERO)
	await physics_frame
	_step()
	check("visible enemy in front of camera has a projected bar", feedback.snapshot().bars.size() == 1)
	var anchor_before: Vector3 = feedback._enemies[enemy.get_instance_id()].anchor
	feedback._scan_left = 0.12
	enemy.position.x += 1.0
	enemy.reset_physics_interpolation()
	feedback._process(0.016)
	var anchor_after: Vector3 = feedback._enemies[enemy.get_instance_id()].anchor
	check("rendered enemy anchor follows movement between throttled LOS scans", anchor_after.x - anchor_before.x > 0.99 and feedback._scan_left > 0.1 and anchor_after == enemy.get_global_transform_interpolated().origin + Vector3.UP * float(enemy.get_meta("enemy_feedback_height")))
	enemy.position.x = 0.0
	enemy.reset_physics_interpolation()
	var wall := _box(Vector3(0, 4, 8), Vector3(15, 10, 1))
	await physics_frame
	_step()
	enemy.take_damage(8)
	_step()
	check("real world wall hides both HP and new damage text", feedback.snapshot().bars.is_empty() and feedback.snapshot().visible_numbers == 0)
	wall.free()
	await physics_frame
	_step()
	check("removing wall restores real line of sight", feedback.snapshot().bars.size() == 1)
	var vehicle_wall := _box(Vector3(0, 4, 8), Vector3(15, 10, 1), 4)
	await physics_frame
	_step()
	check("vehicle collision layer also occludes enemy feedback", feedback.snapshot().bars.is_empty())
	vehicle_wall.free()
	enemy.position = Vector3(0, 0, 35)
	enemy.reset_physics_interpolation()
	_step()
	check("enemies behind the camera never project into view", feedback.snapshot().bars.is_empty())
	enemy.position = Vector3(200, 0, -5)
	enemy.reset_physics_interpolation()
	_step()
	check("off-screen enemies are not clamped onto screen edges", feedback.snapshot().bars.is_empty())
	enemy.position = Vector3(0, 0, -130)
	enemy.reset_physics_interpolation()
	_step()
	# It was recently hit: distant bars are intentionally retained briefly.
	for i: int in 12: _step(0.2)
	check("unengaged distant enemies do not clutter the view", feedback.snapshot().bars.is_empty())
	host.weapons.status = {"locked":true, "target_id":enemy.get_instance_id(), "modules":{"locks":{}}}
	_step()
	check("actual automatic lock promotes distant visible target", feedback.snapshot().bars.size() == 1 and feedback.snapshot().bars[0].locked)
	host.weapons.status = {"locked":false, "modules":{"locks":{"laser":enemy.get_instance_id()}}}
	_step()
	check("module lock is also displayed from actual status", feedback.snapshot().bars.size() == 1 and feedback.snapshot().bars[0].locked)
	host.weapons.status = {}
	feedback.set_locked_target(enemy)
	_step()
	check("optional explicit lock can be supplied by the host", feedback.snapshot().bars.size() == 1 and feedback.snapshot().bars[0].locked)
	feedback.set_locked_target(null)
	_reset_enemies()
	for i: int in 30: _enemy("roamer", Vector3(float(i % 10 - 5) * 0.2, 0, -float(i / 10) * 0.2))
	var promoted: Node3D = enemy_nodes[-1]
	host.weapons.status = {"locked":true, "target_id":promoted.get_instance_id()}
	await physics_frame
	_step()
	state = feedback.snapshot()
	check("crowded layout keeps lock first and caps bars", state.bars.size() > 0 and state.bars.size() <= 24 and state.bars[0].id == promoted.get_instance_id())
	check("crowded enemy bars never overlap each other", _layout_valid())
	check("crowding hides overflow instead of drawing unreadable labels", state.bars.size() < state.registered)
	var first_rect := _rect(state.bars[0].rect)
	_step()
	check("stationary layout is stable between frames", _rect(feedback.snapshot().bars[0].rect) == first_rect)
	feedback.set_reserved_rects([first_rect.grow(3)])
	_step()
	check("custom HUD exclusions displace or hide bars without overlaps", _layout_valid())
	report_states["crowded"] = feedback.snapshot()
	_reset_enemies()
	enemy = _enemy("roamer", Vector3.ZERO)
	_step()
	var nearby_size: Vector2 = feedback._bars[0].rect.size
	enemy.position.z = -45
	enemy.reset_physics_interpolation()
	_step()
	check("screen-space bars keep their pixel size with distance", feedback._bars.size() == 1 and feedback._bars[0].rect.size == nearby_size)
	feedback.unregister_enemy(enemy)
	check("unregister disconnects and restores original 3D feedback", feedback.snapshot().registered == 0 and enemy.get_signal_connection_list("damaged").is_empty() and enemy._label.visible and enemy._bar.visible)
	feedback.register_enemy(enemy)
	enemy.free()
	enemy_nodes.clear()
	_step()
	check("freed enemies leave no retained references", feedback.snapshot().registered == 0)
	_reset_enemies()
	enemy = _enemy("brute", Vector3.ZERO)
	enemy.take_damage(4)
	feedback.reset()
	check("world reset clears damage counters and restores enemy labels", feedback.snapshot().registered == 0 and feedback.snapshot().floating.is_empty() and feedback.snapshot().damage_events == 0 and enemy._label.visible)
	var folder := ProjectSettings.globalize_path("res://../reports/combat-feedback")
	DirAccess.make_dir_recursive_absolute(folder)
	if "--visual" in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless": check("native visual mode requires a real renderer", false)
		else: await _capture()
	var detached := _enemy("winglet", Vector3(0, 6, -10))
	detached.set_target(host.player)
	host.remove_child(detached)
	feedback.unregister_enemy(detached)
	check("feedback teardown hides detached enemy without querying stale transforms", not detached._label.visible and not detached._bar.visible)
	enemy_nodes.erase(detached)
	detached.free()
	var passed: bool = checks.all(func(row: Dictionary): return row.passed)
	var sources := {}
	for path: String in ["res://scripts/combat_feedback.gd", "res://scripts/nailong_enemy.gd", "res://scripts/nailong_model.gd", "res://scripts/nailong_flight.gd", "res://scripts/ui_fonts.gd", "res://scripts/survival_hud.gd", "res://../source/combat_feedback_test.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	var result := {"passed":passed, "count":checks.size(), "checks":checks, "sources":sources,
		"display":DisplayServer.get_name(), "native_rendering":DisplayServer.get_name() != "headless", "snapshots":report_states,
		"screenshots":pictures, "scope":"isolated production feedback, actual enemy damage, Jolt walls and Camera3D projection; no full city or save access"}
	var report := FileAccess.open(folder + ("/native-checks.json" if DisplayServer.get_name() != "headless" else "/checks.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(result, "  "))
	report.close()
	print("COMBAT_FEEDBACK_QA ", JSON.stringify({"passed":passed, "count":checks.size()}))
	_reset_enemies()
	canvas.free()
	host.free()
	quit(0 if passed else 1)
