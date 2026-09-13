extends RefCounted
## Arcade road handling uses tyre forces and angular acceleration. Each vehicle owns
## its own controller; transient steering/slip state is never shared or saved.
var _steering := 0.0
var _drift_blend := 0.0
var _slip_target := 0.0
var _info: Dictionary = {}

func reset() -> void:
	_steering = 0.0
	_drift_blend = 0.0
	_slip_target = 0.0
	_info.clear()

func debug_info() -> Dictionary:
	return _info.duplicate(true)

func tick(v: RigidBody3D, delta: float, f: Vector3, _r: Vector3, u: Vector3, power: float, steer: float, brake: bool, drift: bool, boost: bool = false) -> void:
	var bike: bool = v.kind == "motorcycle"
	var probe: Dictionary = v._ground_probe()
	v.grounded = not probe.is_empty()
	var speed: float = v.linear_velocity.length()
	# Brakes cut engine force in this same tick, including when W is still held.
	var drive_input := 0.0 if brake else power
	v.throttle = move_toward(v.throttle, drive_input, delta * (8.0 if brake else 3.5))
	var steering_response := lerpf(12.0 if bike else 8.0, 5.0, clampf(speed / 90.0, 0.0, 1.0))
	_steering = lerpf(_steering, steer, 1.0 - exp(-steering_response * delta))
	var active_drift: bool = drift and not brake and v.occupied and v.grounded and speed > 8.0 and absf(steer) > 0.08
	_drift_blend = move_toward(_drift_blend, 1.0 if active_drift else 0.0, delta * (3.8 if active_drift else 2.2))
	var slip_angle := 0.0
	var yaw_rate := 0.0
	var drive := 0.0
	var braking_accel := 0.0
	if v.grounded:
		var normal: Vector3 = probe.normal.normalized()
		# Leaning a bike must not turn lateral tyre grip into a vertical force.
		var forward := f.slide(normal).normalized()
		if forward.length_squared() < 0.5:
			forward = -v.global_basis.z
		var right := forward.cross(normal).normalized()
		var deck_velocity := Vector3.ZERO
		if probe.collider is RigidBody3D:
			deck_velocity = probe.collider.linear_velocity
		var relative: Vector3 = (v.linear_velocity - deck_velocity).slide(normal)
		var forward_speed := relative.dot(forward)
		var lateral_speed := relative.dot(right)
		var planar_speed := relative.length()
		slip_angle = atan2(lateral_speed, maxf(absf(forward_speed), 1.0))
		var resistance := forward_speed * 0.032 + forward_speed * absf(forward_speed) * 0.00018
		var downforce := minf(forward_speed * forward_speed * 0.00025, 3.8) if v.occupied else 0.0
		var acceleration := (16.0 if bike else 14.0) * (4.0 if boost else 1.0)
		var target_speed: float = v.throttle * (float(v.TOP_SPEED_KMH[v.kind]) * (3.0 if boost else 1.0) / 3.6 if v.throttle >= 0.0 else 16.0)
		if not brake and absf(v.throttle) > 0.01:
			var rolling: float = (v.G + downforce) * 0.07 * signf(forward_speed)
			# Govern total road speed: ignoring lateral motion lets a held drift
			# gain extra speed beyond the advertised limit, especially with boost.
			var governed_speed := planar_speed * (-1.0 if forward_speed < 0.0 else 1.0)
			drive = clampf((target_speed - governed_speed) * 0.85 + resistance + rolling, -acceleration, acceleration)
			v.apply_central_force(forward * v.mass * drive)
		v.apply_central_force(-forward * v.mass * resistance)
		v.apply_central_force(-normal * v.mass * downforce)
		if brake:
			# Stop the entire ground-plane velocity, so emergency braking still works
			# while sideways. Linear taper prevents oscillation across zero speed.
			braking_accel = minf(16.0 if bike else 17.0, planar_speed * 9.0)
			if planar_speed > 0.001:
				v.apply_central_force(-relative / planar_speed * v.mass * braking_accel)
		var grip := lerpf(9.5 if bike else 8.5, 1.15 if bike else 0.85, _drift_blend)
		var grip_limit := lerpf(12.5 if bike else 11.5, 4.8 if bike else 4.1, _drift_blend)
		var lateral_accel := clampf(lateral_speed * grip, -grip_limit, grip_limit)
		v.apply_central_force(-right * v.mass * lateral_accel)
		# Faster parking/city turn-in, followed by a lateral-acceleration limit at
		# speed. Countersteer never rotates the body instantaneously.
		var yaw_limit := minf(1.8 if bike else 1.2, (11.2 if bike else 9.6) / maxf(absf(forward_speed), 1.0))
		var speed_authority := clampf(forward_speed / (4.0 if bike else 6.0), -1.0, 1.0)
		var normal_yaw := -_steering * speed_authority * yaw_limit
		var desired_slip := -_steering * (0.39 if bike else 0.50) * signf(forward_speed) if active_drift else 0.0
		_slip_target = lerpf(_slip_target, desired_slip, 1.0 - exp(-5.0 * delta))
		var drift_limit := minf(1.65, 18.0 / maxf(planar_speed, 1.0))
		var drift_yaw := clampf(_slip_target * 0.85 + (_slip_target - slip_angle) * 2.4, -drift_limit, drift_limit)
		yaw_rate = lerpf(normal_yaw, drift_yaw, _drift_blend)
		if brake:
			yaw_rate *= clampf(planar_speed / 12.0, 0.0, 0.65)
		var desired_up := normal
		if bike:
			var lean := clampf(-yaw_rate * absf(forward_speed) / 27.0, -0.30, 0.30)
			desired_up = (normal + right * lean).normalized()
		var yaw_velocity: float = v.angular_velocity.dot(normal)
		var tilt_velocity: Vector3 = v.angular_velocity - normal * yaw_velocity
		v._torque_accel(u.cross(desired_up) * (28.0 if bike else 20.0) - tilt_velocity * (8.0 if bike else 6.0) + normal * (yaw_rate - yaw_velocity) * (9.0 if bike else 7.0))
	else:
		# Road controls must not give airborne cars engine thrust or air steering.
		_drift_blend = move_toward(_drift_blend, 0.0, delta * 4.0)
		_slip_target = move_toward(_slip_target, 0.0, delta * 2.0)
		v._torque_accel(-v.angular_velocity * 0.10)
	if v.occupied and absf(v.throttle) > 0.05 and not brake:
		v.fuel = maxf(0.0, v.fuel - delta * absf(v.throttle) * 0.006)
	v._engine_target = -22.0 + absf(v.throttle) * 9.0 if v.occupied and v.health > 0.0 else -60.0
	_info = {"grounded":v.grounded, "steering":_steering, "drift_requested":drift, "drift_active":active_drift, "drifting":active_drift or _drift_blend > 0.15, "drift_blend":_drift_blend, "slip_angle_degrees":rad_to_deg(slip_angle), "target_slip_degrees":rad_to_deg(_slip_target), "yaw_rate":yaw_rate, "brake":brake, "boost":boost, "drive_accel":drive, "braking_accel":braking_accel}
	v.set_meta("road_handling", _info)
