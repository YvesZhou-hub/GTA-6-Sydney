extends Node
## Presentation/input only. setup() runs after controls and combat_feedback exist.
## Godot reports handheld angular velocity in radians/second. Its mobile backend
## already rotates sensor vectors into the current screen orientation, including
## both landscape directions; applying another 90-degree turn here is incorrect.
const Profile = preload("res://scripts/mobile_profile.gd")
const MAX_SAMPLE_DELTA := 0.08
const MAX_ANGLE_RATE := 4.0
const QUIET_RATE := 0.012
const SMOOTH_SECONDS := 0.035
const HAPTIC_INTERVAL_MS := 140

var host: Node
var controls: Node
var enabled := false
var _native_handheld := false
var _focused := true
var _tracking := false
var _gyro_mode := "off"
var _orientation := -1
var _last_sample_usec := 0
var _smoothed_rate := Vector2.ZERO
var _player: Node
var _feedback: Node
var _player_health := NAN
var _vehicle_id := 0
var _vehicle_health := NAN
var _pending_haptic := 0
var _next_haptic_msec := 0


func setup(game: Node, touch_controls: Node) -> void:
	_disconnect_events()
	host = game
	controls = touch_controls
	enabled = Profile.is_mobile()
	# Never vibrate desktop hardware, even with --mobile-preview or a QA profile.
	_native_handheld = OS.get_name() in ["iOS", "Android"]
	name = "MobileSensors"
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Update the shared look angles before main positions the camera this frame.
	process_priority = -5
	set_process(enabled)
	reset()
	if not enabled or not is_instance_valid(host) or not is_instance_valid(controls): return
	_player = host.get("player")
	_feedback = host.get("combat_feedback")
	if controls.has_signal("weapon_fired"): controls.connect("weapon_fired", feedback_fire)
	if is_instance_valid(_player) and _player.has_signal("health_changed"):
		_player_health = float(_player.get("health"))
		_player.connect("health_changed", _on_player_health_changed)
	if is_instance_valid(_feedback) and _feedback.has_signal("damage_confirmed"):
		_feedback.connect("damage_confirmed", feedback_hit)


func _disconnect_events() -> void:
	if is_instance_valid(controls) and controls.has_signal("weapon_fired") and controls.is_connected("weapon_fired", feedback_fire):
		controls.disconnect("weapon_fired", feedback_fire)
	if is_instance_valid(_player) and _player.has_signal("health_changed") and _player.is_connected("health_changed", _on_player_health_changed):
		_player.disconnect("health_changed", _on_player_health_changed)
	if is_instance_valid(_feedback) and _feedback.has_signal("damage_confirmed") and _feedback.is_connected("damage_confirmed", feedback_hit):
		_feedback.disconnect("damage_confirmed", feedback_hit)
	_player = null
	_feedback = null


func _playing() -> bool:
	return enabled and _focused and is_instance_valid(host) and is_instance_valid(controls) and bool(controls.call("is_gameplay_enabled"))


func reset() -> void:
	reset_motion()
	_player_health = NAN
	_vehicle_id = 0
	_vehicle_health = NAN
	_pending_haptic = 0
	_next_haptic_msec = 0


func reset_motion() -> void:
	_tracking = false
	_last_sample_usec = 0
	_smoothed_rate = Vector2.ZERO
	_orientation = -1


func _process(delta: float) -> void:
	if not _playing():
		reset()
		return
	if is_instance_valid(_player) and not is_finite(_player_health): _player_health = float(_player.get("health"))
	_check_vehicle_health()
	_flush_haptic()
	var settings: Dictionary = host.get("settings")
	var mode := str(settings.get("mobile_gyro_mode", "off"))
	if mode != _gyro_mode:
		reset_motion()
		_gyro_mode = mode
	if mode != "always" and (mode != "firing" or not bool(controls.call("is_firing"))):
		reset_motion()
		return
	var orientation := DisplayServer.screen_get_orientation() if _native_handheld else DisplayServer.SCREEN_LANDSCAPE
	var now := Time.get_ticks_usec()
	# Engine delta can be clamped across a stall/resume. Also reject a long actual
	# sample gap, and discard the first sample after pause, rotation or activation.
	if not is_finite(delta) or delta <= 0.0 or delta > MAX_SAMPLE_DELTA:
		reset_motion()
		return
	if not _tracking or orientation != _orientation or now - _last_sample_usec > 250000:
		_tracking = true
		_orientation = orientation
		_last_sample_usec = now
		_smoothed_rate = Vector2.ZERO
		return
	_last_sample_usec = now
	var rotation_rate := Input.get_gyroscope()
	var gravity := Input.get_gravity()
	if not rotation_rate.is_finite() or not gravity.is_finite():
		reset_motion()
		return
	# Gravity supplies world-up yaw when the screen is tilted towards the lap.
	# Screen-right remains pitch. Zero gravity (no sensor/preview) has a safe fallback.
	var yaw_rate := -rotation_rate.dot(gravity.normalized()) if gravity.length_squared() > 0.01 else rotation_rate.y
	var rate := Vector2(yaw_rate, rotation_rate.x)
	var sensitivity := float(settings.get("mobile_gyro_sensitivity", 1.0))
	if not is_finite(sensitivity): sensitivity = 1.0
	rate = (rate * clampf(sensitivity, 0.2, 3.0)).limit_length(MAX_ANGLE_RATE)
	if rate.length() < QUIET_RATE: rate = Vector2.ZERO
	_smoothed_rate = _smoothed_rate.lerp(rate, 1.0 - exp(-delta / SMOOTH_SECONDS))
	var turn := _smoothed_rate * delta
	var yaw := float(host.get("yaw"))
	var pitch := float(host.get("pitch"))
	if not is_finite(yaw) or not is_finite(pitch): return
	host.set("yaw", yaw + turn.x)
	host.set("pitch", clampf(pitch + turn.y * (-1.0 if bool(settings.get("invert", false)) else 1.0), -1.05, 0.65))


func _on_player_health_changed(current: float, _maximum: float) -> void:
	if is_finite(current) and is_finite(_player_health) and current < _player_health:
		_queue_haptic(3)
	_player_health = current


func _check_vehicle_health() -> void:
	# Switching vehicles/starting a world establishes a baseline, not a damage event.
	var vehicle: Variant = host.get("current_vehicle")
	if not is_instance_valid(vehicle):
		_vehicle_id = 0
		_vehicle_health = NAN
		return
	var id: int = vehicle.get_instance_id()
	var current := float(vehicle.get("health"))
	if id == _vehicle_id and is_finite(current) and is_finite(_vehicle_health) and current < _vehicle_health:
		_queue_haptic(3)
	_vehicle_id = id
	_vehicle_health = current


func feedback_fire() -> void:
	_queue_haptic(1)


func feedback_hit(actual: float) -> void:
	if is_finite(actual) and actual > 0.0: _queue_haptic(2)


func _queue_haptic(priority: int) -> void:
	if not _native_handheld or not _playing(): return
	var settings: Dictionary = host.get("settings")
	if not bool(settings.get("mobile_haptics", true)): return
	# Coalesce same-frame feedback; damage/hits take precedence over muzzle pulses.
	# Drop excess bursts instead of queuing delayed vibrations after combat stops.
	if Time.get_ticks_msec() < _next_haptic_msec: return
	_pending_haptic = maxi(_pending_haptic, priority)


func _flush_haptic() -> void:
	var priority := _pending_haptic
	_pending_haptic = 0
	if priority == 0 or not _native_handheld or not _playing(): return
	var settings: Dictionary = host.get("settings")
	if not bool(settings.get("mobile_haptics", true)): return
	_next_haptic_msec = Time.get_ticks_msec() + HAPTIC_INTERVAL_MS
	Input.vibrate_handheld(28 if priority == 3 else 18 if priority == 2 else 12, 0.32 if priority == 3 else 0.24 if priority == 2 else 0.16)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_focused = false
		reset()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		_focused = true
		reset()


func _exit_tree() -> void:
	_disconnect_events()
	reset()
