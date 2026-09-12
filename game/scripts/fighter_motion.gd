extends RefCounted
## Fictional assisted flight; real Jolt rigid-body contacts remain enabled.
const TOP_SPEED := 2000.0 / 3.6
const LAUNCH_SPEED := 140.0
const MINIMUM_SPAWN_HEIGHT := 90.0
const MINIMUM_FLIGHT_SPEED := 70.0

static func setup(body: RigidBody3D) -> void:
	body.mass = 14500.0
	body.inertia = body.mass * Vector3(28.0,34.0,9.5)
	body.center_of_mass = Vector3(0,-0.12,0.35)
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	if body.physics_material_override == null: body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = 0.025
	body.physics_material_override.bounce = 0.0
	body.throttle = LAUNCH_SPEED / TOP_SPEED
	body.controls_hint = "W/S throttle • A/D turn • R/F pitch • Space airbrake • 2000 km/h"

static func tick(body: RigidBody3D, delta: float, f: Vector3, r: Vector3, u: Vector3, power: float, steer: float, pitch: float, brake: bool) -> void:
	if not body.occupied: return
	body.stalled = false
	body.throttle = clampf(body.throttle+power*delta*0.22,0.0,1.0)
	var target_speed: float = clampf(body.throttle*TOP_SPEED,MINIMUM_FLIGHT_SPEED,TOP_SPEED)
	if brake: target_speed = MINIMUM_FLIGHT_SPEED
	var desired: Vector3 = f*target_speed
	var difference: Vector3 = desired-body.linear_velocity
	# A force-based velocity servo gives this fictional aircraft forgiving lift
	# and coordinated turns. No transform/velocity writes or collision bypass.
	var longitudinal: float = difference.dot(f)
	var acceleration: Vector3 = f*clampf(longitudinal*2.2,-150.0,65.0)
	acceleration += (difference-f*longitudinal).limit_length(90.0)*2.6
	acceleration += Vector3.UP*float(ProjectSettings.get_setting("physics/3d/default_gravity",9.8))
	body.apply_central_force(acceleration*body.mass)
	var speed_ratio: float = clampf(body.linear_velocity.length()/TOP_SPEED,0.0,1.0)
	var desired_pitch: float = pitch*deg_to_rad(58.0)
	var actual_pitch: float = asin(clampf(f.y,-1.0,1.0))
	var pitch_rate: float = clampf((desired_pitch-actual_pitch)*1.8,-0.72,0.72)
	var yaw_rate: float = -steer*lerpf(0.65,0.23,speed_ratio)
	var horizon_right: Vector3 = f.cross(Vector3.UP).normalized()
	if horizon_right.length_squared()<.1: horizon_right=r
	var desired_up: Vector3 = (Vector3.UP+horizon_right*steer*0.60).normalized()
	var roll_error: float = u.cross(desired_up).dot(f)
	# Yaw is about world-up; pitch is about the horizontal right axis. Using
	# body-right here would couple a banked yaw command into an unwanted dive.
	var wanted_angular: Vector3 = Vector3.UP*yaw_rate+horizon_right*pitch_rate+f*roll_error*2.4
	var angular_accel: Vector3 = (wanted_angular-body.angular_velocity)*5.0
	var local: Vector3 = body.global_basis.inverse()*angular_accel
	body.apply_torque(body.global_basis*(local*body.inertia))
	body._engine_target = -28.0+body.throttle*15.0
