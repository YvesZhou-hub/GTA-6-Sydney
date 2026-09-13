extends Node
## Integration checks run production vehicles and Jolt on an isolated flat road.
## Initial placement is the only transform write. Driving is entirely Input actions.
const Vehicle = preload("res://scripts/harbor_vehicle.gd")
const ACTIONS := ["forward", "back", "left", "right", "rise", "fall", "brake", "drift", "boost"]
var results: Array = []
var failure := 0
var _scene: Node3D
var _native := false
var _packaged := false
var _camera: Camera3D
var _caption: Label
var _screenshots: Array = []

func _ready() -> void:
	if "--driving-qa" in OS.get_cmdline_user_args(): call_deferred("_run_packaged")

func _run_packaged() -> void:
	_packaged = true
	_native = DisplayServer.get_name() != "headless"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var game = get_parent()
	if not game.qa_running:
		printerr("Driving validation requires the main QA save guard")
		game.finish_quit(2)
		return
	game.active = false
	game.new_world("sandbox", "Driving QA isolated unsaved world", false)
	game.world_id = "qa_driving_unsaved"
	game.set_process(false)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.player.enabled = false
	game.canvas.hide()
	game.weapons.set_physics_process(false)
	for vehicle in game.vehicles:
		vehicle.occupied = false
		vehicle.freeze = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.make_dir_recursive_absolute("user://driving-qa")
	if _native:
		RenderingServer.render_loop_enabled = false
		_camera = Camera3D.new()
		_camera.far = 1000.0
		add_child(_camera)
		_camera.current = true
		var layer := CanvasLayer.new()
		layer.layer = 50
		add_child(layer)
		_caption = Label.new()
		_caption.position = Vector2(40, 260)
		_caption.add_theme_font_size_override("font_size", 30)
		_caption.add_theme_color_override("font_shadow_color", Color.BLACK)
		_caption.add_theme_constant_override("shadow_offset_x", 2)
		_caption.add_theme_constant_override("shadow_offset_y", 2)
		layer.add_child(_caption)
	var report: Dictionary = await run()
	report["native"] = _native
	report["screenshots"] = _screenshots
	report["user_saves_touched"] = false
	report["save_written"] = false
	report["source_sha256"] = {}
	for path in ["res://scripts/harbor_vehicle.gd", "res://scripts/road_motion.gd", "res://scripts/driving_validation.gd", "res://scripts/main.gd"]:
		report.source_sha256[path] = FileAccess.get_sha256(path)
	FileAccess.open("user://driving-qa/report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("DRIVING_QA_COMPLETE ", results.size(), " passed=", failure == 0)
	game.finish_quit(0 if failure == 0 else 1)

func _capture(body: RigidBody3D, label: String) -> void:
	if not _native: return
	_caption.text = "DRIVING VALIDATION | " + label + "\n" + body.kind + "  " + str(roundi(body.linear_velocity.length() * 3.6)) + " km/h | slip " + str(snappedf(_slip(body), 0.1)) + " degrees\nCtrl + A/D drift | Space emergency brake | Shift boost"
	for _i in 4:
		_camera.global_position = body.global_position + body.global_basis * Vector3(6.0, 3.5, 7.0)
		_camera.look_at(body.global_position + Vector3.UP * 0.5)
		RenderingServer.force_draw(false)
		await get_tree().process_frame
	var screenshot := get_viewport().get_texture().get_image()
	var path := "user://driving-qa/" + label + ".png"
	var saved := screenshot.save_png(path) == OK
	_screenshots.append({"file":label+".png", "saved":saved, "sha256":FileAccess.get_sha256(path) if saved else "", "vehicle":body.kind, "speed_kmh":body.linear_velocity.length()*3.6, "slip_degrees":_slip(body), "vehicle_frozen":false})
	_check("native capture " + label, saved)

func _check(label: String, passed: bool, metrics: Dictionary = {}) -> void:
	results.append({"name":label, "pass":passed, "passed":passed, "metrics":metrics})
	if not passed: failure += 1
	print(("PASS " if passed else "FAIL ") + label + " " + JSON.stringify(metrics))

func _frames(count: int) -> void:
	for _i in count: await get_tree().physics_frame

func _clear_input() -> void:
	for action in ACTIONS: Input.action_release(action)

func _remove_scene() -> void:
	_clear_input()
	if is_instance_valid(_scene):
		_scene.queue_free()
		await get_tree().process_frame

func _spawn(kind: String, height: float = 0.76) -> RigidBody3D:
	var body := Vehicle.new()
	body.configure(kind, "driving_qa_" + kind + "_" + str(_scene.get_child_count()))
	body.position = Vector3(0.0, height, 0.0)
	_scene.add_child(body)
	return body

func _fresh(kind: String) -> RigidBody3D:
	await _remove_scene()
	_scene = Node3D.new()
	add_child(_scene)
	if _packaged: _scene.position.y = 4000.0
	var road := StaticBody3D.new()
	road.position.y = -1.0
	var shape := BoxShape3D.new()
	shape.size = Vector3(20000.0, 2.0, 160000.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	road.add_child(collision)
	if _native:
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = shape.size
		visual.mesh = mesh
		var asphalt := StandardMaterial3D.new()
		asphalt.albedo_color = Color("404c51")
		asphalt.roughness = 0.94
		visual.material_override = asphalt
		road.add_child(visual)
		var line_material := StandardMaterial3D.new()
		line_material.albedo_color = Color("e4dbaa")
		for index in range(-60, 25):
			var stripe := MeshInstance3D.new()
			var stripe_mesh := BoxMesh.new()
			stripe_mesh.size = Vector3(0.16, 0.015, 3.0)
			stripe.mesh = stripe_mesh
			stripe.material_override = line_material
			stripe.position = Vector3(2.5, 0.009, index * 8.0)
			_scene.add_child(stripe)
	_scene.add_child(road)
	var body := _spawn(kind)
	await _frames(90)
	body.occupied = true
	await _frames(2)
	return body

func _accelerate_to(body: RigidBody3D, kmh: float, max_frames: int = 900) -> bool:
	Input.action_press("forward")
	for _i in max_frames:
		await get_tree().physics_frame
		if body.linear_velocity.length() * 3.6 >= kmh: return true
	return false

func _slip(body: RigidBody3D) -> float:
	return float(body.get_meta("road_handling", {}).get("slip_angle_degrees", 0.0))

func _braking(kind: String) -> void:
	var body := await _fresh(kind)
	var reached := await _accelerate_to(body, 100.0)
	_check(kind + " accelerates from rest to 100 km/h", reached, {"speed_kmh":body.linear_velocity.length() * 3.6})
	var start_position := body.position
	Input.action_press("brake")
	var elapsed := 0.0
	var stopped := false
	var engine_cut := true
	for i in 210:
		await get_tree().physics_frame
		if i > 1: engine_cut = engine_cut and absf(float(body.get_meta("road_handling", {}).get("drive_accel", INF))) < 0.001
		if not stopped and body.linear_velocity.length() < 0.55:
			elapsed = float(i + 1) / Engine.physics_ticks_per_second
			stopped = true
	_check(kind + " emergency brake beats held throttle", stopped and elapsed <= 3.1 and engine_cut and body.linear_velocity.length() < 0.55, {"stop_seconds":elapsed, "stop_distance_m":body.position.distance_to(start_position), "remaining_kmh":body.linear_velocity.length() * 3.6, "engine_cut":engine_cut})
	_check(kind + " braking keeps chassis stable", body.global_basis.y.dot(Vector3.UP) > 0.96 and body.health > 99.0, {"up_dot":body.global_basis.y.dot(Vector3.UP), "health":body.health})
	await _capture(body, kind + "-emergency-stop")

func _drifting(kind: String) -> void:
	var body := await _fresh(kind)
	await _accelerate_to(body, 100.0)
	Input.action_release("forward")
	Input.action_press("right", 0.8)
	Input.action_press("drift")
	var max_slip := 0.0
	var max_roll := 0.0
	var max_acceleration := 0.0
	var prior_velocity := body.linear_velocity
	for _i in 120:
		await get_tree().physics_frame
		max_slip = maxf(max_slip, absf(_slip(body)))
		max_roll = maxf(max_roll, absf(body.rotation.z))
		max_acceleration = maxf(max_acceleration, body.linear_velocity.distance_to(prior_velocity) * Engine.physics_ticks_per_second)
		prior_velocity = body.linear_velocity
	var drift_speed := body.linear_velocity.length() * 3.6
	_check(kind + " Ctrl turn creates controlled lateral drift", max_slip > (9.0 if kind == "motorcycle" else 14.0) and max_slip < 60.0 and drift_speed > 35.0 and max_roll < 0.65, {"max_slip_degrees":max_slip, "end_kmh":drift_speed, "max_roll":max_roll})
	_check(kind + " drift changes velocity through continuous forces", max_acceleration < 70.0 and body.health > 99.0, {"max_frame_acceleration_mps2":max_acceleration, "health":body.health})
	await _capture(body, kind + "-controlled-drift")
	Input.action_release("right")
	Input.action_release("drift")
	await _frames(210)
	_check(kind + " release restores grip and straight tracking", absf(_slip(body)) < 4.0 and absf(body.angular_velocity.y) < 0.12 and body.global_basis.y.dot(Vector3.UP) > 0.96, {"slip_degrees":_slip(body), "yaw_mps":body.angular_velocity.y, "up_dot":body.global_basis.y.dot(Vector3.UP)})
	# Countersteer while drift is held should reverse yaw without an unstable spin.
	Input.action_press("forward")
	await _frames(75)
	Input.action_press("right", 0.8)
	Input.action_press("drift")
	await _frames(80)
	Input.action_release("right")
	Input.action_press("left", 0.8)
	await _frames(100)
	_check(kind + " countersteer remains responsive", body.angular_velocity.y > 0.08 and absf(_slip(body)) < 60.0 and body.global_basis.y.dot(Vector3.UP) > 0.90 and body.health > 99.0, {"yaw_mps":body.angular_velocity.y, "slip_degrees":_slip(body), "health":body.health, "up_dot":body.global_basis.y.dot(Vector3.UP)})
	Input.action_press("brake")
	await _frames(2)
	_check(kind + " emergency braking overrides active drift", not bool(body.get_meta("road_handling", {}).get("drift_active", true)) and float(body.get_meta("road_handling", {}).get("drive_accel", INF)) == 0.0, body.get_meta("road_handling", {}))

func _bike_turns() -> void:
	var turn_values := []
	for action in ["left", "right"]:
		var body := await _fresh("motorcycle")
		await _accelerate_to(body, 35.0)
		Input.action_release("forward")
		var initial_heading := body.rotation.y
		Input.action_press(action)
		await _frames(75)
		var turn := wrapf(body.rotation.y - initial_heading, -PI, PI)
		turn_values.append(absf(turn))
		_check("motorcycle city turn " + action + " responds within 1.25 seconds", absf(turn) > 0.55 and turn * (1.0 if action == "left" else -1.0) > 0.0 and body.global_basis.y.dot(Vector3.UP) > 0.90 and body.health > 99.0, {"heading_change_degrees":rad_to_deg(turn), "roll":body.rotation.z, "speed_kmh":body.linear_velocity.length() * 3.6, "health":body.health})
	_check("motorcycle left and right have comparable authority", absf(turn_values[0] - turn_values[1]) < 0.12, {"left_radians":turn_values[0], "right_radians":turn_values[1]})

func _boost(kind: String) -> void:
	var body := await _fresh(kind)
	var base: float = Vehicle.TOP_SPEED_KMH[kind]
	Input.action_press("forward")
	Input.action_press("boost")
	var peak := 0.0
	for _i in 2700:
		await get_tree().physics_frame
		peak = maxf(peak, body.linear_velocity.length() * 3.6)
	var achieved := body.linear_velocity.length() * 3.6
	_check(kind + " Shift reaches triple speed through acceleration", achieved >= base * 2.96 and peak < base * 3.04 and body.health > 99.0, {"base_kmh":base, "achieved_kmh":achieved, "peak_kmh":peak, "health":body.health})
	await _capture(body, kind + "-triple-speed")
	var initial_yaw := body.rotation.y
	Input.action_press("right", 0.5)
	await _frames(360)
	_check(kind + " boost steering stays stable", absf(wrapf(body.rotation.y - initial_yaw, -PI, PI)) > 0.05 and body.global_basis.y.dot(Vector3.UP) > 0.90 and body.health > 99.0 and body.linear_velocity.is_finite(), {"turn_radians":wrapf(body.rotation.y - initial_yaw, -PI, PI), "up_dot":body.global_basis.y.dot(Vector3.UP), "health":body.health})
	Input.action_press("right")
	Input.action_press("drift")
	var boost_drift_peak := 0.0
	for _i in 600:
		await get_tree().physics_frame
		boost_drift_peak = maxf(boost_drift_peak, body.linear_velocity.length() * 3.6)
	_check(kind + " combined Ctrl and Shift respects total speed ceiling", boost_drift_peak <= base * 3.04 and body.global_basis.y.dot(Vector3.UP) > 0.90 and body.health > 99.0, {"total_peak_kmh":boost_drift_peak, "limit_kmh":base * 3.0, "slip_degrees":_slip(body), "up_dot":body.global_basis.y.dot(Vector3.UP), "health":body.health})
	Input.action_release("right")
	Input.action_release("drift")
	Input.action_release("boost")
	var first_release_speed := body.linear_velocity.length() * 3.6
	await _frames(1)
	var release_drop := first_release_speed - body.linear_velocity.length() * 3.6
	await _frames(1500)
	var normal_speed := body.linear_velocity.length() * 3.6
	_check(kind + " release boost smoothly restores normal maximum", normal_speed >= base * 0.985 and normal_speed <= base * 1.02 and release_drop < 5.0, {"base_kmh":base, "remaining_kmh":normal_speed, "first_frame_speed_drop_kmh":release_drop})
	Input.action_press("boost")
	Input.action_press("brake")
	await _frames(600)
	_check(kind + " Space stops despite held Shift and W", body.linear_velocity.length() < 0.55 and float(body.get_meta("road_handling", {}).get("drive_accel", INF)) == 0.0 and body.health > 99.0, {"remaining_kmh":body.linear_velocity.length() * 3.6, "drive_accel":body.get_meta("road_handling", {}).get("drive_accel"), "health":body.health})

func _edge_cases() -> void:
	var body := await _fresh("car")
	Input.action_press("right")
	Input.action_press("drift")
	await _frames(120)
	_check("stationary drift input does not spin or launch a car", body.linear_velocity.length() < 0.5 and absf(body.rotation.y) < 0.02, {"speed_mps":body.linear_velocity.length(), "heading":body.rotation.y})
	_clear_input()
	await _accelerate_to(body, 80.0)
	Input.action_press("right")
	Input.action_press("drift")
	await _frames(60)
	# Instantiate another unoccupied vehicle while the first one is drifting.
	var parked := _spawn("car")
	await _frames(90)
	var first_info: Dictionary = body.get_meta("road_handling", {})
	var other_info: Dictionary = parked.get_meta("road_handling", {})
	_check("separate vehicles do not share steering or drift state", absf(float(first_info.get("steering", 0.0))) > 0.5 and absf(float(other_info.get("steering", INF))) < 0.001 and float(other_info.get("drift_blend", INF)) == 0.0 and parked.linear_velocity.length() < 0.5, {"driving":first_info, "parked":other_info, "parked_speed":parked.linear_velocity.length()})
	await _remove_scene()
	_scene = Node3D.new()
	add_child(_scene)
	if _packaged: _scene.position.y = 4000.0
	var flying := _spawn("motorcycle", 100.0)
	flying.occupied = true
	Input.action_press("forward")
	Input.action_press("right")
	Input.action_press("drift")
	Input.action_press("boost")
	await _frames(45)
	_check("airborne road controls create no artificial thrust or yaw", not flying.grounded and Vector2(flying.linear_velocity.x, flying.linear_velocity.z).length() < 0.05 and absf(flying.angular_velocity.y) < 0.01 and flying.linear_velocity.y < -4.0, {"velocity":[flying.linear_velocity.x,flying.linear_velocity.y,flying.linear_velocity.z], "yaw_mps":flying.angular_velocity.y, "grounded":flying.grounded})
	await _remove_scene()

func run() -> Dictionary:
	results.clear()
	failure = 0
	for action in ACTIONS:
		if not InputMap.has_action(action): InputMap.add_action(action)
	for kind in ["car", "motorcycle"]:
		await _braking(kind)
		await _drifting(kind)
	await _bike_turns()
	for kind in ["car", "motorcycle"]: await _boost(kind)
	await _edge_cases()
	_clear_input()
	if _native: _check("all six moving-production-vehicle images captured", _screenshots.size() == 6 and _screenshots.all(func(item): return item.saved))
	return {"engine":Engine.get_version_info().string, "backend":ProjectSettings.get_setting("physics/3d/physics_engine"), "physics_hz":Engine.physics_ticks_per_second, "scope":"Actual production HarborVehicle and input actions on an isolated flat road. No velocity or transform writes after initial placement. This validates arcade controls, not real-world handling or display rendering.", "checks":results, "count":results.size(), "failures":failure, "passed":failure == 0}
