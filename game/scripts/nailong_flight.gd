extends RefCounted
## Bounded local air steering. CharacterBody3D still performs every movement and
## collision; this never teleports a creature through buildings or into a target.

static func destination(enemy) -> Vector3:
	var target: Node3D = enemy.target
	var at: Vector3 = target.global_position
	var flat_distance := Vector2(at.x-enemy.global_position.x,at.z-enemy.global_position.z).length()
	var goal: Vector3
	if str(enemy.spec.get("attack_mode","")) == "dive" and flat_distance<20.0:
		goal = enemy.target_surface_point()-Vector3.UP*.2
	else:
		goal = at+Vector3.UP*float(enemy.spec.get("cruise_height",8.0))
	# Stay above water and terrain. The short probe never confuses a roof far
	# below a high-flying target with a surface the creature should descend onto.
	var query := PhysicsRayQueryParameters3D.create(enemy.global_position+Vector3.UP*.5,enemy.global_position-Vector3.UP*8.0,1,[enemy.get_rid()])
	var hit: Dictionary = enemy.get_world_3d().direct_space_state.intersect_ray(query)
	var floor_y := 1.4
	if not hit.is_empty(): floor_y=maxf(floor_y,float(hit.position.y)+.65)
	goal.y=maxf(goal.y,floor_y)
	return goal

static func steer(enemy, wanted: Vector3) -> Vector3:
	if wanted.length_squared()<.01: return Vector3.ZERO
	var look_ahead := maxf(2.0,float(enemy.spec.speed)*.32)
	var collision := KinematicCollision3D.new()
	var direct_probe := look_ahead*1.35 if enemy._detour_direction.length_squared()>.01 else look_ahead
	if not enemy.test_move(enemy.global_transform,wanted*direct_probe,collision):
		enemy._detour_direction=Vector3.ZERO
		return wanted
	if enemy._detour_direction.length_squared()<.01:
		var normal: Vector3=collision.get_normal()
		var tangent:=normal.cross(Vector3.UP)*float(enemy._avoid_side)
		if tangent.length_squared()<.01:tangent=wanted.rotated(Vector3.UP,PI*.5*float(enemy._avoid_side))
		enemy._detour_direction=(tangent+Vector3.UP*.55).normalized()
	var options: Array[Vector3]=[]
	for angle in [0.0,.6,-.6,1.2,-1.2,1.9,-1.9,PI]:
		options.append(enemy._detour_direction.rotated(Vector3.UP,angle).normalized())
	options.append(Vector3.UP)
	options.append((wanted+Vector3.UP*1.5).normalized())
	options.append((wanted-Vector3.UP*1.2).normalized())
	var best:=-INF
	var result:=Vector3.ZERO
	for candidate in options:
		if enemy.global_position.y+candidate.y*look_ahead<1.4:continue
		if enemy.test_move(enemy.global_transform,candidate*look_ahead):continue
		var score:float=candidate.dot(enemy._detour_direction)*1.8+candidate.dot(wanted)+maxf(0.0,candidate.y)*.2
		if score>best:best=score;result=candidate
	if result.length_squared()>.01:enemy._detour_direction=result
	return result

static func move(enemy, movement: Vector3, delta: float) -> void:
	var desired: Vector3=movement*float(enemy.spec.speed)
	enemy.velocity=enemy.velocity.move_toward(desired,delta*float(enemy.spec.get("acceleration",18.0)))
	enemy.move_and_slide()
