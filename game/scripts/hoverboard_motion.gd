extends RefCounted
## Fictional surface-following propulsion. Real rigid-body contacts remain enabled.
const TOP_SPEED := 200.0 / 3.6
const CLEARANCE := 1.0
const MAX_LIFT := 180.0
const SUPPORT_DEPTH := MAX_LIFT + 64.0

static func setup(body: RigidBody3D) -> void:
	body.mass = 155.0
	body.inertia = body.mass * Vector3(0.55,0.65,0.40)
	body.center_of_mass = Vector3(0,-0.12,0)
	body.linear_damp = 0.0
	body.physics_material_override.friction = 0.05
	body.physics_material_override.bounce = 0.0
	body.controls_hint = "W/S drive • A/D turn • R/F lift • Space stop • 200 km/h"

static func _surface(body: RigidBody3D, point: Vector3, upper: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x,upper,point.z),Vector3(point.x,point.y-SUPPORT_DEPTH,point.z),15,[body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.normal.y > 0.45: return hit
	# The harbour water is a surface for this fictional craft, without adding a
	# solid sea floor that would change boats, swimming or the rest of the world.
	if not preload("res://scripts/metro_entrances.gd").contains_dry_volume(point):
		return {"position":Vector3(point.x,0.0,point.z),"normal":Vector3.UP}
	return {}

static func tick(body: RigidBody3D, delta: float, f: Vector3, _r: Vector3, u: Vector3, power: float, steer: float, pitch: float, brake: bool) -> void:
	var position := body.global_position
	var flat_forward := Vector3(f.x,0.0,f.z).normalized()
	var horizontal := Vector3(body.linear_velocity.x,0.0,body.linear_velocity.z)
	var speed := horizontal.length()
	var underneath := _surface(body,position,position.y+0.12)
	var support := float(underneath.position.y) if not underneath.is_empty() else position.y-CLEARANCE
	var target_height := support + CLEARANCE
	# Probe far enough ahead to raise over a flight of stairs before the deck
	# touches the risers. The support ray cannot select a remote skyscraper roof.
	var direction := horizontal.normalized() if speed>1.5 else flat_forward*signf(power)
	var look_ahead := clampf(speed*0.72+1.8,1.8,42.0)
	for fraction in [0.3,0.65,1.0]:
		var sample := _surface(body,position+direction*look_ahead*fraction,position.y+7.0)
		if not sample.is_empty() and sample.position.y-support<8.0:
			target_height = maxf(target_height,float(sample.position.y)+CLEARANCE)
	# R lifts continuously; release holds this extra clearance. F lowers it
	# again. Surface following remains a minimum even with F held down.
	var extra := float(body.get_meta("hover_lift_offset",0.0))
	if body.occupied: extra = clampf(extra+pitch*delta*10.0,0.0,MAX_LIFT)
	else: extra = move_toward(extra,0.0,delta*3.0)
	body.set_meta("hover_lift_offset",extra)
	target_height += extra
	var wanted_vertical := clampf((target_height-position.y)*5.0,-12.0,24.0)
	# Ceiling clearance: cancel upward drive instead of forcing the rider into
	# an overhead deck. The full vehicle envelope is still checked at creation.
	if wanted_vertical>0.0:
		var ceiling_query := PhysicsRayQueryParameters3D.create(position+Vector3.UP*1.8,position+Vector3.UP*(2.2+wanted_vertical*0.15),15,[body.get_rid()])
		if not body.get_world_3d().direct_space_state.intersect_ray(ceiling_query).is_empty(): wanted_vertical=0.0
	var vertical_accel := clampf((wanted_vertical-body.linear_velocity.y)*7.0,-45.0,65.0)
	body.apply_central_force(Vector3.UP*body.mass*(9.8+vertical_accel))
	body.grounded = absf(position.y-support-CLEARANCE)<1.5
	body.stalled = false
	body.throttle = move_toward(body.throttle,power,delta*3.5)
	var desired: Vector3 = flat_forward*body.throttle*(TOP_SPEED if body.throttle>=0.0 else 12.0)
	if brake or not body.occupied: desired=Vector3.ZERO
	# Predict braking distance in metres. Stair tops are traversable; a wall
	# without a reachable top triggers braking before the physical contact.
	var obstacle:=false
	var stop_distance:=speed*speed/80.0+3.5
	for lateral in [-0.40,0.0,0.40]:
		var start:Vector3=position+Vector3.UP*.7+body.global_basis.x*lateral
		var ray:=PhysicsRayQueryParameters3D.create(start,start+direction*stop_distance,15,[body.get_rid()])
		var wall:=body.get_world_3d().direct_space_state.intersect_ray(ray)
		if wall.is_empty() or wall.normal.y>.45:continue
		var behind:Vector3=wall.position+direction*.65
		var top_ray:=PhysicsRayQueryParameters3D.create(Vector3(behind.x,position.y+6.0,behind.z),Vector3(behind.x,position.y-2,behind.z),15,[body.get_rid()])
		top_ray.hit_from_inside=true
		var top:=body.get_world_3d().direct_space_state.intersect_ray(top_ray)
		if top.is_empty() or top.normal.y<.45:obstacle=true;break
	if obstacle:desired=Vector3.ZERO
	var acceleration: Vector3 = (desired-horizontal)*2.8
	acceleration = acceleration.limit_length(45.0 if brake or obstacle else 20.0)
	body.apply_central_force(acceleration*body.mass)
	var yaw_rate := -steer*lerpf(1.7,0.58,clampf(speed/TOP_SPEED,0.0,1.0))
	var desired_up: Vector3 = (Vector3.UP-flat_forward*body.throttle*0.045+body.global_basis.x*steer*0.10).normalized()
	body._torque_accel(u.cross(desired_up)*20.0-Vector3(body.angular_velocity.x,0.0,body.angular_velocity.z)*7.0+Vector3.UP*(yaw_rate-body.angular_velocity.y)*8.0)
	body._engine_target = -40.0+clampf(speed/TOP_SPEED,0.0,1.0)*8.0 if body.occupied else -60.0
	body.set_meta("hover_support_height",support)
	body.set_meta("hover_target_height",target_height)
