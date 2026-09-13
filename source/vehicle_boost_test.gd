extends SceneTree
## Production vehicles + native Jolt forces. Initial cruise motion is fixture
## setup only; no position, rotation, or velocity writes occur during phases.
const Vehicle = preload("res://scripts/harbor_vehicle.gd")
const ACTIONS := ["forward", "back", "left", "right", "rise", "fall", "brake", "drift", "boost"]
const KINDS := ["car", "motorcycle", "hoverboard", "tank", "fighter", "airliner", "helicopter", "speedboat", "yacht", "glider", "paraglider"]
const BOOST_SECONDS := {"car": 65, "motorcycle": 65, "hoverboard": 55, "tank": 65, "fighter": 65, "airliner": 180, "helicopter": 90, "speedboat": 90, "yacht": 90, "glider": 65, "paraglider": 65}
var checks: Array = []
var samples: Array = []
var stage: Node3D
var body: RigidBody3D

func _initialize() -> void:
	call_deferred("run")

func check(label: String, passed: bool, metrics: Dictionary = {}) -> void:
	checks.append({"name": label, "passed": passed, "metrics": metrics})
	print("PASS " if passed else "FAIL ", label, " ", JSON.stringify(metrics))

func clear_input() -> void:
	for action in ACTIONS:
		Input.action_release(action)

func ground() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "ContinuousFlatTestSurface"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2000, 2, 220000)
	collision.shape = shape
	floor_body.add_child(collision)
	floor_body.position = Vector3(0, -1, -100000)
	stage.add_child(floor_body)

func fixture(kind: String) -> void:
	clear_input()
	if is_instance_valid(stage):
		stage.queue_free()
		await process_frame
	stage = Node3D.new()
	stage.name = "BoostFixture_" + kind
	root.add_child(stage)
	if kind in ["car", "motorcycle", "tank", "hoverboard"]:
		ground()
	body = Vehicle.new()
	body.configure(kind, "boost_probe_" + kind)
	stage.add_child(body)
	var altitude := 5000.0
	if kind in ["car", "motorcycle"]: altitude = 0.76
	if kind == "tank": altitude = 0.86
	if kind == "hoverboard": altitude = 1.0
	if kind in ["speedboat", "yacht"]: altitude = float(body.boat_profile.get("float_height", 0.9))
	var base: float = body.base_top_speed_kmh() / 3.6
	body.apply_state({"position": [0, altitude, 0], "quaternion": [0, 0, 0, 1], "velocity": [0, 0, -base], "angular_velocity": [0, 0, 0], "health": 100, "fuel": 100, "throttle": 1.0, "frozen": false})
	body.occupied = true
	Input.action_press("forward")
	for frame in 120: await physics_frame

func phase(kind: String, label: String, seconds: float) -> Dictionary:
	var previous: Vector3 = body.linear_velocity
	var first_change := 0.0
	var max_change := 0.0
	var peak := 0.0
	var minimum_altitude := body.global_position.y
	var max_roll := 0.0
	var finite := true
	var tail_total := 0.0
	var tail_count := 0
	var count := int(seconds * 60.0)
	for frame in count:
		await physics_frame
		var current: Vector3 = body.linear_velocity
		var delta_speed := current.distance_to(previous)
		if frame == 0: first_change = delta_speed
		max_change = maxf(max_change, delta_speed)
		previous = current
		finite = finite and current.is_finite() and body.global_position.is_finite()
		peak = maxf(peak, current.length() * 3.6)
		minimum_altitude = minf(minimum_altitude, body.global_position.y)
		max_roll = maxf(max_roll, absf(body.rotation.z))
		if frame >= count - 300:
			tail_total += current.length() * 3.6
			tail_count += 1
	var metric := {"kind": kind, "phase": label, "seconds": seconds, "last_kmh": body.linear_velocity.length() * 3.6, "tail_mean_kmh": tail_total / maxf(1.0, tail_count), "peak_kmh": peak, "first_frame_velocity_change_mps": first_change, "max_frame_velocity_change_mps": max_change, "minimum_altitude_m": minimum_altitude, "last_altitude_m": body.global_position.y, "max_roll_rad": max_roll, "health": body.health, "fuel": body.fuel, "finite": finite}
	samples.append(metric)
	print("BOOST_SAMPLE ", JSON.stringify(metric))
	return metric

func run() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var selected: Array = KINDS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kinds="):
			selected = Array(arg.trim_prefix("--kinds=").split(","))
	check("native Jolt fixed 60 Hz physics", ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics" and Engine.physics_ticks_per_second == 60, {"backend": ProjectSettings.get_setting("physics/3d/physics_engine"), "physics_hz": Engine.physics_ticks_per_second})
	for kind: String in selected:
		await fixture(kind)
		var base: float = body.base_top_speed_kmh()
		var target := base * 3.0
		var wing := kind in ["glider", "paraglider"]
		var water := kind in ["speedboat", "yacht"]
		var step_limit := maxf(6.0, base / 3.6 * 0.08)
		Input.action_press("boost")
		check(kind + " Shift selects triple speed while occupied", body.is_boosting() and is_equal_approx(body.effective_top_speed_kmh(), target), {"base_kmh": base, "boost_target_kmh": body.effective_top_speed_kmh()})
		var boost: Dictionary = await phase(kind, "boost", float(BOOST_SECONDS[kind]))
		var minimum_ratio := 0.82 if wing else 0.90 if water else 0.92
		var maximum_ratio := 1.015 if wing else 1.10
		check(kind + " reaches triple speed through physical forces", boost.tail_mean_kmh >= target * minimum_ratio and boost.tail_mean_kmh <= target * maximum_ratio and boost.peak_kmh <= target * maximum_ratio, {"target_kmh": target, "actual_kmh": boost.tail_mean_kmh, "peak_kmh": boost.peak_kmh, "maximum_allowed_kmh": target * maximum_ratio})
		check(kind + " boost has no velocity teleport or invalid state", boost.finite and boost.max_frame_velocity_change_mps <= step_limit and boost.health >= 99.9, {"max_frame_change_mps": boost.max_frame_velocity_change_mps, "limit_mps": step_limit, "health": boost.health})
		Input.action_release("boost")
		check(kind + " releasing Shift restores base target immediately", not body.is_boosting() and is_equal_approx(body.effective_top_speed_kmh(), base))
		var released: Dictionary = await phase(kind, "release_with_full_throttle", 120.0 if wing or kind == "airliner" else 90.0)
		check(kind + " release smoothly returns toward normal cruise", released.tail_mean_kmh >= base * (0.70 if wing else 0.85) and released.tail_mean_kmh <= base * (1.30 if wing else 1.12) and released.max_frame_velocity_change_mps <= step_limit, {"base_kmh": base, "actual_kmh": released.tail_mean_kmh, "first_frame_change_mps": released.first_frame_velocity_change_mps, "max_frame_change_mps": released.max_frame_velocity_change_mps, "limit_mps": step_limit})
		Input.action_press("boost")
		await phase(kind, "boost_before_braking", 90.0 if kind == "airliner" else 35.0)
		var before_brake := body.linear_velocity.length() * 3.6
		Input.action_press("brake")
		check(kind + " Space overrides held Shift", not body.is_boosting() and is_equal_approx(body.speed_multiplier(), 1.0))
		var brake_phase := "space_blocks_boost_with_forward_held" if kind == "helicopter" else "brake_with_shift_and_throttle_held"
		var braked: Dictionary = await phase(kind, brake_phase, 14.0)
		var brake_label := " Space cancels boosted flight while W keeps normal rotor drive" if kind == "helicopter" else " actual braking overpowers held boost and throttle"
		check(kind + brake_label, braked.last_kmh < before_brake * 0.65 and braked.finite, {"before_kmh": before_brake, "after_kmh": braked.last_kmh})
		Input.action_release("brake")
		body.occupied = false
		check(kind + " unoccupied vehicle cannot boost", not body.is_boosting() and is_equal_approx(body.effective_top_speed_kmh(), base))
		await phase(kind, "unoccupied_shift_held", 1.0)
		check(kind + " unoccupied motion remains finite", body.linear_velocity.is_finite() and not body.is_boosting())
	clear_input()
	var passed := true
	for result in checks:
		if not result.passed: passed = false
	var report := {"passed": passed, "engine": Engine.get_version_info().string, "backend": ProjectSettings.get_setting("physics/3d/physics_engine"), "checks": checks, "samples": samples, "scope": "Production HarborVehicle and Jolt on controlled open-road, water and airborne fixtures. Initial transform and base cruise velocity establish each fixture; phases use real Input actions and native forces only. Not native GPU or public-road gameplay verification."}
	var suffix := "" if selected.size() == KINDS.size() else "-" + "-".join(selected)
	var file := FileAccess.open("res://../reports/vehicle-boost" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("VEHICLE_BOOST ", JSON.stringify({"passed": passed, "checks": checks.size(), "kinds": selected}))
	stage.queue_free()
	await process_frame
	quit(0 if passed else 1)
