extends RefCounted
## Original arcade tracked propulsion; all movement uses rigid-body forces.
const TOP_SPEED := 110.0 / 3.6
const REVERSE_SPEED := 12.0
const TRACK_HALF_WIDTH := 1.60
const SUPPORT_OFFSETS := [Vector3(-1.50,0,-2.70),Vector3(1.50,0,-2.70),Vector3(-1.50,0,2.70),Vector3(1.50,0,2.70),Vector3.ZERO]

static func setup(v:RigidBody3D) -> void:
	v.mass=58000.0
	v.inertia=v.mass*Vector3(5.2,6.2,1.8)
	v.center_of_mass_mode=RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	v.center_of_mass=Vector3(0,-.42,.10)
	v.linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
	v.angular_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
	v.linear_damp=.015;v.angular_damp=.12
	if v.physics_material_override==null:v.physics_material_override=PhysicsMaterial.new()
	v.physics_material_override.friction=.08
	v.physics_material_override.bounce=0.0
	v.continuous_cd=true
	v.controls_hint="W/S tracks • A/D differential turn • Space brake • 110 km/h"
	v.set_meta("tank_track_left_speed",0.0);v.set_meta("tank_track_right_speed",0.0)

static func _ground(v:RigidBody3D) -> Dictionary:
	var normal:=Vector3.ZERO;var samples:=0;var height:=0.0;var velocity:=Vector3.ZERO
	for local:Vector3 in SUPPORT_OFFSETS:
		var p:=v.global_transform*local
		var ray:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.5,p-Vector3.UP*1.40,15,[v.get_rid()])
		var hit:=v.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y<.48:continue
		normal+=hit.normal; samples+=1;height+=hit.position.y
		if hit.collider is RigidBody3D:velocity+=hit.collider.linear_velocity
	if samples<2:return {}
	return {"normal":normal.normalized(),"samples":samples,"height":height/samples,"velocity":velocity/samples}

static func tick(v:RigidBody3D,delta:float,f:Vector3,r:Vector3,u:Vector3,power:float,steer:float,_pitch:float,brake:bool) -> void:
	var support:=_ground(v)
	v.grounded=not support.is_empty();v.stalled=false
	var active:bool=v.occupied
	v.throttle=move_toward(v.throttle,power if active and not brake else 0.0,delta*2.5)
	var speed:float=v.linear_velocity.dot(f)
	var yaw_rate:=0.0
	if v.grounded:
		var n:Vector3=support.normal
		var along:=f.slide(n).normalized();var across:=r.slide(n).normalized()
		var relative:Vector3=v.linear_velocity-support.velocity
		speed=relative.dot(along)
		var stop:bool=brake or not active
		v.physics_material_override.friction=.88 if stop else .08
		var target:float=v.throttle*(TOP_SPEED if v.throttle>=0.0 else REVERSE_SPEED)
		var climbing:float=-Vector3.DOWN.dot(along)*9.8
		var resistance:float=speed*.03
		# Feed-forward belongs to requested drive, not tiny contact jitter at rest.
		var rolling:float=signf(target)*.9 if absf(target)>.05 else 0.0
		var traction:float=clampf((target-speed)*1.7+climbing+rolling,-10.0,9.0)
		if stop:traction=clampf(-speed*5.0+climbing,-18.0,18.0)
		v.apply_central_force(along*v.mass*(traction-resistance))
		var downhill:float=Vector3.DOWN.dot(across)*9.8
		v.apply_central_force(-across*v.mass*clampf(relative.dot(across)*7.0+downhill,-14.0,14.0))
		# Ground-normal stabilization resists roll without teleporting or fixing
		# the body upright in world space. Inclines remain actual physical slopes.
		yaw_rate=-steer*lerpf(.76,.23,clampf(absf(speed)/TOP_SPEED,0.0,1.0)) if active and not brake else 0.0
		var yaw:float=v.angular_velocity.dot(n)
		var tilt_velocity:Vector3=v.angular_velocity-n*yaw
		v._torque_accel(u.cross(n)*26.0-tilt_velocity*8.5+n*(yaw_rate-yaw)*7.0)
		v.set_meta("tank_support_samples",support.samples)
		v.set_meta("tank_ground_normal",n)
	else:
		# No air driving, artificial levitation, or attraction to distant roofs.
		v._torque_accel(-v.angular_velocity*.65)
		v.set_meta("tank_support_samples",0)
	v.set_meta("tank_track_left_speed",speed-yaw_rate*TRACK_HALF_WIDTH)
	v.set_meta("tank_track_right_speed",speed+yaw_rate*TRACK_HALF_WIDTH)
	v._engine_target=-34.0+absf(v.throttle)*10.0 if active else -60.0
