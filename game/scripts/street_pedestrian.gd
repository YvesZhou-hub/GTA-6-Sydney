extends CharacterBody3D
## A crowd pedestrian: walks a stretch of footpath, steps aside for traffic and
## runs from Nailong. Lighter than the named residents in harbor_npc.gd, which
## keep dialogue, jobs and memories.

const Visual = preload("res://scripts/character_visual.gd")

var route: Array = []
var route_index := 0
var walk_speed := 1.35
var flee_time := 0.0
var _visual: Visual


func setup(model_key: String, points: Array, speed: float) -> void:
	route = points
	walk_speed = speed
	collision_layer = 8
	collision_mask = 1
	floor_snap_length = 0.5
	add_to_group("street_pedestrians")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	_visual = Visual.new()
	add_child(_visual)
	_visual.setup(model_key, 1.78)


## Danger makes people run for a while, even after the cause has gone.
func alarm(seconds: float) -> void:
	flee_time = maxf(flee_time, seconds)


func step(delta: float, threat: Vector3, has_threat: bool) -> bool:
	if route.size() < 2: return false
	flee_time = maxf(0.0, flee_time - delta)
	var direction := Vector3.ZERO
	var speed := walk_speed
	if has_threat and global_position.distance_to(threat) < 18.0:
		alarm(3.0)
	if flee_time > 0.0 and has_threat:
		direction = global_position - threat
		direction.y = 0.0
		direction = direction.normalized()
		speed = walk_speed * 2.4
	else:
		var target: Vector3 = route[route_index]
		direction = target - global_position
		direction.y = 0.0
		if direction.length() < 1.2:
			route_index += 1
			if route_index >= route.size(): return false
			direction = Vector3.ZERO
		else:
			direction = direction.normalized()
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 6.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 6.0)
	velocity.y = -0.4 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	if direction.length_squared() > 0.01: _visual.face(direction, delta, 7.0)
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar < 0.15: _visual.set_state("idle")
	elif planar > 2.2: _visual.set_state("run", clampf(planar / 3.2, 0.7, 1.4))
	else: _visual.set_state("walk", clampf(planar / 1.35, 0.7, 1.5))
	return global_position.y > -5.0
