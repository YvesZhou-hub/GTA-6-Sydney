extends Node
## Native iOS sustained route. Scripted production actions, never physical touch.
## main.gd must set qa_running before startup settings/save handling, then run(self).
const Profile = preload("res://scripts/mobile_profile.gd")
const REPORT_PATH := "user://qa/mobile-stress/report.json"
const LOCATION_SECONDS := 15.0
const MAX_TANK_SECONDS := 45.0
const TANK_SHOTS := 10
const ROUTE := [
	{"anchor":"home", "vehicle":"car"},
	{"anchor":"quay", "vehicle":"tank"},
	{"anchor":"opera", "vehicle":"hoverboard"},
	{"anchor":"exchange_haidilao", "vehicle":"helicopter"},
	{"anchor":"airport", "vehicle":"tank"},
	{"anchor":"manly_wharf", "vehicle":"car"},
]
var game: Node
var report: Dictionary = {}
var checks: Array[Dictionary] = []
var phases: Array[Dictionary] = []
var saves_before: Dictionary = {}
var all_frame_ms: Array[float] = []
var _last_frame_us := 0
var _route_started_us := 0
var _route_finished_us := 0
var _peak_enemies := 0
var _peak_street_cars := 0
var _peak_pedestrians := 0
var _manual_shots := 0
var _rise_held := false
var _location_seconds := LOCATION_SECONDS

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _check(title: String, passed: bool, detail: Dictionary = {}) -> void:
	checks.append({"name":title, "passed":passed, "detail":detail})
	print("MOBILE_STRESS ", "PASS " if passed else "FAIL ", title, " ", JSON.stringify(detail))

func _saved_files() -> Dictionary:
	var result := {}
	if DirAccess.dir_exists_absolute("user://worlds"):
		for filename: String in DirAccess.get_files_at("user://worlds"):
			result["worlds/" + filename] = FileAccess.get_sha256("user://worlds/" + filename)
	for filename in ["settings.json","settings_mobile.json"]:
		if FileAccess.file_exists("user://"+filename):
			result[filename] = FileAccess.get_sha256("user://"+filename)
	return result

static func _percentile(sorted: Array[float], quantile: float) -> float:
	if sorted.is_empty(): return 0.0
	var position := (sorted.size() - 1) * quantile
	var low := floori(position)
	return lerpf(sorted[low], sorted[mini(low + 1, sorted.size() - 1)], position - low)

static func frame_summary(intervals: Array[float], duration_seconds: float) -> Dictionary:
	var ordered := intervals.duplicate()
	ordered.sort()
	var sum_ms := 0.0
	var over_50 := 0
	var over_100 := 0
	var over_1000 := 0
	for interval in intervals:
		sum_ms += interval
		if interval > 50: over_50 += 1
		if interval > 100: over_100 += 1
		if interval > 1000: over_1000 += 1
	return {"measured_seconds":duration_seconds, "frames":intervals.size(),
		"effective_fps":intervals.size() / maxf(duration_seconds, 0.000001),
		"frame_ms_median":_percentile(ordered, 0.5), "frame_ms_p95":_percentile(ordered, 0.95),
		"frame_ms_p99":_percentile(ordered, 0.99), "frame_ms_worst":ordered.back() if not ordered.is_empty() else 0.0,
		"interval_sum_seconds":sum_ms / 1000.0, "frames_over_50ms":over_50,
		"frames_over_100ms":over_100, "frames_over_1000ms":over_1000,
		"quantile_method":"linear interpolation over sorted actual frame intervals",
		"excluded_stall_samples":0}

func _snapshot() -> Dictionary:
	var debug_monitor := OS.is_debug_build()
	return {"engine_fps_snapshot":Engine.get_frames_per_second(),
		"fps_monitor_snapshot":Performance.get_monitor(Performance.TIME_FPS),
		"process_cpu_seconds_snapshot":Performance.get_monitor(Performance.TIME_PROCESS),
		"physics_cpu_seconds_snapshot":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
		"fps_snapshot_note":"Godot's current FPS snapshot on the running OS, not an iOS display-link counter or sustained FPS",
		"godot_static_memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)) if debug_monitor else null,
		"godot_static_memory_max_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)) if debug_monitor else null,
		"godot_static_memory_available":debug_monitor,
		"memory_note":"Godot allocation counter only, not process resident/GPU memory. Unavailable in Release builds; null does not mean zero memory.",
		"draw_calls_snapshot":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects_snapshot":int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"primitives_snapshot":int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))}

func _persist(status: String) -> bool:
	report.status = status
	report.updated_unix_seconds = Time.get_unix_time_from_system()
	report.locations = phases
	report.completed_locations = phases.size()
	report.checks = checks
	report.peak_enemy_count = _peak_enemies
	report.peak_street_cars = _peak_street_cars
	report.peak_pedestrians = _peak_pedestrians
	report.scripted_cannon_shots = _manual_shots
	# A completed checkpoint survives a kill during the next write.
	var temporary := REPORT_PATH + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("MOBILE_STRESS report open failed: " + str(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(report, "\t"))
	file.flush()
	file.close()
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(REPORT_PATH))
	if error != OK: push_error("MOBILE_STRESS checkpoint rename failed: " + str(error))
	return error == OK

func run(owner_game: Node) -> void:
	game = owner_game
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mobile-stress-seconds="):
			_location_seconds = clampf(argument.get_slice("=",1).to_float(), LOCATION_SECONDS, 120.0)
	var native_ios := OS.get_name() == "iOS" or OS.has_feature("ios")
	var native_renderer := DisplayServer.get_name() != "headless"
	saves_before = _saved_files()
	report = {"format_version":1, "status":"starting", "started_unix_seconds":Time.get_unix_time_from_system(),
		"platform":OS.get_name(), "device_model":OS.get_model_name(), "engine":Engine.get_version_info().string,
		"renderer":RenderingServer.get_current_rendering_method(), "native_ios":native_ios,
		"native_rendering":native_renderer, "physical_touch_hardware_tested":false,
		"hardware_vs_simulator_note":"The launch host must independently identify physical hardware; OS iOS alone also covers a simulator.",
		"profile":Profile.status(game), "minimum_route_seconds":ROUTE.size() * _location_seconds,
		"scope":"Complete production city, six anchors, production vehicle spawning, normal enemies and automatic weapons. 60-second damage grace at each anchor. Camera orbit and helicopter rise are scripted; no real fingers tested. No world geometry, spawn budgets or render profile are reduced by this test.",
		"timing_scope":"Consecutive SceneTree process_frame timestamps from Time.get_ticks_usec. Includes route transitions, vehicle creation, between-location checkpoint IO, real stalls, rendering waits and simulation. Initial world setup, final report serialization and optional final screenshot are outside the measured route. No sample trimming.",
		"performance_pass_threshold":null, "performance_note":"Functional completion is separate from the reported sustained frame rate; no FPS threshold is silently treated as passed.",
		"source_sha256":FileAccess.get_sha256("res://scripts/mobile_stress_validation.gd"),
		"saves_before":saves_before, "crash_free_for_completed_route":false}
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	_check("native iOS renderer, explicit QA save guard and mobile profile", native_ios and native_renderer and game.qa_running and Profile.is_mobile())
	_check("checkpoint directory writable", directory_error == OK, {"error":directory_error})
	_check("start at inactive title menu before making an unsaved world", not game.active)
	_check("complete production world and airport exist", game.world._ready_complete and is_instance_valid(game.airport), {"structures":game.world.structures.size()})
	for location: Dictionary in ROUTE:
		_check("verified anchor exists: " + location.anchor, game.world.anchors.has(location.anchor) and game.world.anchors[location.anchor] is Vector3)
	if checks.any(func(item: Dictionary): return not item.passed):
		await _finish(false)
		return
	game.new_world("life", "iOS sustained unsaved QA", false)
	# In addition to qa_running's autosave guard, explicit save requests fail.
	game.world_id = ""
	game.survival.grace = 60.0
	# Ordinary QA suppresses ambient traffic. A sustained load test explicitly
	# restores the configured production density and the normal city clock.
	if is_instance_valid(game.street): game.street.force_enabled = true
	if is_instance_valid(game.city_clock): game.city_clock.set_process(true)
	report.street_life = game.street.stats() if is_instance_valid(game.street) else {}
	_check("production encounters and automatic spawning remain enabled", game.active and game.survival.enabled and game.survival.auto_spawn)
	_check("ambient traffic uses the configured production density", is_instance_valid(game.street) and game.street.force_enabled and game.street.density() == int(game.settings.get("street_life", 1)))
	_check("initial checkpoint saved", _persist("running"))
	_route_started_us = Time.get_ticks_usec()
	_last_frame_us = _route_started_us
	for location: Dictionary in ROUTE: await _run_location(location)
	_route_finished_us = _last_frame_us
	await _finish(true)

func _run_location(location: Dictionary) -> void:
	var started_us := _last_frame_us
	report.active_location = location.duplicate()
	report.active_location.started_unix_seconds = Time.get_unix_time_from_system()
	_check("location-start checkpoint: " + location.anchor, _persist("running"))
	if is_instance_valid(game.mobile_controls): game.mobile_controls.release_all()
	_release_rise()
	game.close_panel()
	if is_instance_valid(game.current_vehicle): game.exit_vehicle()
	var anchor: Vector3 = game.world.anchors[location.anchor]
	game.player.global_position = anchor + Vector3.UP * 2.0
	game.player.last_safe = game.player.global_position
	game.player.velocity = Vector3.ZERO
	game.player.reset_physics_interpolation()
	game.reset_follow_camera()
	game.survival.grace = maxf(game.survival.grace, 60.0)
	var vehicle: Variant = game.request_vehicle(location.vehicle)
	var spawned: bool = is_instance_valid(vehicle) and game.current_vehicle == vehicle and vehicle.occupied
	_check("production spawn at " + location.anchor, spawned, {"kind":location.vehicle, "profile":game.get_meta("last_spawn_profile", {})})
	var initial_height: float = vehicle.global_position.y if spawned else anchor.y
	var spawn_position: Vector3 = vehicle.global_position if spawned else game.player.global_position
	var highest_height := initial_height
	var frames_ms: Array[float] = []
	var accepted := 0
	var attempts := 0
	var peak_enemies := 0
	var peak_street_cars := 0
	var peak_pedestrians := 0
	var fired_before: int = game.weapons.stats().fired
	var needs_shots: bool = location.vehicle == "tank" and spawned
	while true:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var interval_ms := (now - _last_frame_us) / 1000.0
		_last_frame_us = now
		frames_ms.append(interval_ms)
		all_frame_ms.append(interval_ms)
		var elapsed := (now - started_us) / 1000000.0
		var enemy_count: int = game.survival.enemies.size()
		peak_enemies = maxi(peak_enemies, enemy_count)
		_peak_enemies = maxi(_peak_enemies, enemy_count)
		if is_instance_valid(game.street):
			peak_street_cars = maxi(peak_street_cars, game.street.cars.size())
			peak_pedestrians = maxi(peak_pedestrians, game.street.pedestrians.size())
			_peak_street_cars = maxi(_peak_street_cars, peak_street_cars)
			_peak_pedestrians = maxi(_peak_pedestrians, peak_pedestrians)
		game.yaw += interval_ms * 0.00008
		if spawned and is_instance_valid(vehicle): highest_height = maxf(highest_height, vehicle.global_position.y)
		if location.vehicle == "helicopter" and spawned and is_instance_valid(vehicle) and elapsed < 8.0:
			Input.action_press("rise")
			_rise_held = true
		else: _release_rise()
		if needs_shots and accepted < TANK_SHOTS and game.can_fire_weapon():
			var aim: Dictionary = game.weapons.aim_status()
			if bool(aim.get("ready", false)) and float(aim.get("cooldown_remaining", 1.0)) <= 0:
				attempts += 1
				if game.weapons.fire_current():
					accepted += 1
					_manual_shots += 1
		if elapsed >= _location_seconds and (not needs_shots or accepted >= TANK_SHOTS or elapsed >= MAX_TANK_SECONDS): break
	_release_rise()
	var duration := (_last_frame_us - started_us) / 1000000.0
	var summary := frame_summary(frames_ms, duration)
	summary.merge({"anchor":location.anchor, "requested_vehicle":location.vehicle,
		"anchor_position":[anchor.x, anchor.y, anchor.z], "spawn_succeeded":spawned,
		"spawn_position":[spawn_position.x, spawn_position.y, spawn_position.z], "spawn_distance_from_anchor":spawn_position.distance_to(anchor),
		"spawn_profile":game.get_meta("last_spawn_profile", {}), "peak_enemy_count":peak_enemies,
		"peak_street_cars":peak_street_cars, "peak_pedestrians":peak_pedestrians,
		"street_life_at_end":game.street.stats() if is_instance_valid(game.street) else {},
		"enemies_at_end":game.survival.enemies.size(), "cannon_attempts":attempts, "accepted_cannon_shots":accepted,
		"weapon_fired_delta":int(game.weapons.stats().fired) - fired_before,
		"highest_vehicle_height":highest_height, "vehicle_rise_metres":highest_height - initial_height,
		"player_health_at_end":game.player.health, "snapshot":_snapshot(),
		"world_streaming":game.world.streaming_stats() if game.world.has_method("streaming_stats") else {}})
	phases.append(summary)
	_check("configured sustained duration: " + location.anchor, duration >= _location_seconds, {"seconds":duration, "effective_fps":summary.effective_fps})
	if location.vehicle == "tank": _check("ten cooldown-respecting cannon shots: " + location.anchor, accepted == TANK_SHOTS, {"attempts":attempts, "accepted":accepted})
	if location.vehicle == "helicopter": _check("production helicopter rises using normal flight input", highest_height - initial_height > 5.0, {"rise_metres":highest_height - initial_height})
	_check("user saves/settings unchanged after " + location.anchor, _saved_files() == saves_before)
	report.last_completed_anchor = location.anchor
	_check("completed-location checkpoint: " + location.anchor, _persist("running"))
	print("MOBILE_STRESS_LOCATION ", JSON.stringify(summary))

func _release_rise() -> void:
	if _rise_held:
		Input.action_release("rise")
		_rise_held = false

func _finish(completed: bool) -> void:
	_release_rise()
	if is_instance_valid(game.mobile_controls): game.mobile_controls.release_all()
	var duration := (_route_finished_us - _route_started_us) / 1000000.0 if completed else 0.0
	if completed:
		_check("six locations and configured measured duration completed", phases.size() == ROUTE.size() and duration >= ROUTE.size() * _location_seconds)
		_check("all actual frame intervals cover the measured route", absf(float(frame_summary(all_frame_ms, duration).interval_sum_seconds) - duration) < 0.01)
	_check("player saves and settings remain byte-identical", _saved_files() == saves_before)
	report.route_completed = completed
	report.crash_free_for_completed_route = completed
	report.overall = frame_summary(all_frame_ms, duration)
	report.weapon_totals = game.weapons.stats() if is_instance_valid(game.weapons) else {}
	report.final_snapshot = _snapshot()
	report.saves_after = _saved_files()
	report.user_saves_touched = report.saves_after != saves_before
	report.passed = completed and checks.all(func(item: Dictionary): return item.passed)
	report.optional_screenshot = {"requested":false, "captured":false}
	report.keep_open_requested = "--mobile-stress-keep-open" in OS.get_cmdline_user_args()
	report.continuing_unsaved_paused_world = completed and report.keep_open_requested and game.qa_running
	if completed and "--mobile-stress-screenshot" in OS.get_cmdline_user_args():
		report.optional_screenshot.requested = true
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var path := REPORT_PATH.get_base_dir().path_join("final.png")
		report.optional_screenshot.captured = image.save_png(path) == OK
		report.optional_screenshot.path = path
		image = null
	if report.continuing_unsaved_paused_world:
		# Preserve the complete resident world for a host-side phys_footprint probe,
		# with gameplay/AI paused and both implicit and explicit saves disabled.
		game.world_id = ""
		game.pause_menu()
		game.set_meta("mobile_stress_keep_open", true)
	var written := _persist("complete" if completed else "failed")
	print("MOBILE_STRESS_REPORT_BEGIN")
	for line: String in JSON.stringify(report, "\t").split("\n"): print(line)
	print("MOBILE_STRESS_REPORT_END")
	print("MOBILE_STRESS_COMPLETE passed=", report.passed, " locations=", phases.size(), " seconds=", duration, " report=", REPORT_PATH, " written=", written)
	if report.continuing_unsaved_paused_world:
		print("MOBILE_STRESS_KEEP_OPEN active=", game.active, " paused=", game.paused, " saving_disabled=", game.world_id == "")
		return
	game.active = false
	get_tree().paused = false
	if game.has_method("finish_quit"): game.finish_quit(0 if report.passed and written else 1)
	else: get_tree().quit(0 if report.passed and written else 1)
