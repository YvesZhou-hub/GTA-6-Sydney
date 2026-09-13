extends RefCounted
## Measured walkable support and a clear approach, including authored public decks.
const Enemy = preload("res://scripts/nailong_enemy.gd")
const VehicleSpawn = preload("res://scripts/vehicle_spawn.gd")

static func exclusions(game: Node3D) -> Array[RID]:
	var result: Array[RID] = [game.player.get_rid()]
	if is_instance_valid(game.current_vehicle): result.append(game.current_vehicle.get_rid())
	return result

static func walkable(hit: Dictionary) -> bool:
	if hit.is_empty() or hit.normal.y < 0.78 or hit.position.y < 0.45: return false
	var body = hit.collider
	if body is RigidBody3D or body is CharacterBody3D: return false
	var identity := str(body.get_meta("damage_id", body.get_meta("airport_damage_id", body.name))).to_lower()
	for forbidden in ["roof", "canopy", "shell", "rail", "wall", "lintel", "furniture"]:
		if forbidden in identity: return false
	if body.has_meta("damage_id") or body.has_meta("airport_damage_id"):
		for surface in ["deck", "approach", "pavement", "terrace", "pier", "platform", "podium", "stair", "step", "floor", "forecourt", "walk", "ramp", "plaza", "road", "path", "apron", "runway", "ground"]:
			if surface in identity: return true
		return false
	return true

static func support(game: Node3D, at: Vector3, up: float = 3.0, down: float = 12.0) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * up, at - Vector3.UP * down, 1, exclusions(game))
	var hit := game.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit if walkable(hit) else {}

static func target_ground(game: Node3D) -> Dictionary:
	var target: Node3D = game.current_vehicle if is_instance_valid(game.current_vehicle) else game.player
	var at := target.global_position
	# Query below the entire craft, but do not summon land enemies under a high flight.
	var bottom := at.y
	if target is RigidBody3D: bottom = (target.global_transform * VehicleSpawn.envelope(target)).position.y
	var hit := support(game, at, 3.0, 80.0 if target is RigidBody3D else 12.0)
	if hit.is_empty() or bottom - hit.position.y > 5.0: return {}
	return hit

static func clear_body(game: Node3D, at: Vector3, kind: String) -> bool:
	var scale: float = Enemy.TYPES.get(kind, Enemy.TYPES.roamer).scale
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.59 * scale + 0.08
	capsule.height = 2.43 * scale + 0.1
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform.origin = at + Vector3.UP * (capsule.height * 0.5 + 0.05)
	query.collision_mask = 1 | 4 | 16
	query.exclude = exclusions(game)
	return game.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

static func approach_clear(game: Node3D, from: Vector3, to: Vector3) -> bool:
	var space := game.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.48
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = from + Vector3.UP * 1.3
	query.motion = to - from
	query.collision_mask = 1 | 4
	query.exclude = exclusions(game)
	var travel := space.cast_motion(query)
	if travel[0] < 0.98: return false
	# A clear ray across a harbour inlet is not a route a walking enemy can use.
	var samples := ceili(from.distance_to(to) / 4.0)
	var previous := from.y
	for index in range(1, samples + 1):
		var point := from.lerp(to, float(index) / float(samples))
		var hit := support(game, point, 2.0, 3.0)
		if hit.is_empty() or absf(hit.position.y - previous) > 2.0: return false
		previous = hit.position.y
	return true

static func find(game: Node3D, kind: String, sequence: int, failures: int = 0) -> Dictionary:
	var ground := target_ground(game)
	if ground.is_empty(): return {"position": Vector3.INF, "reason": "离开地面 · 落地后自动恢复遭遇", "candidates": 0}
	var center: Vector3 = ground.position
	var target: Node3D = game.current_vehicle if is_instance_valid(game.current_vehicle) else game.player
	var hull_padding := 0.0
	if target is RigidBody3D:
		var box := VehicleSpawn.envelope(target)
		hull_padding = maxf(box.size.x, box.size.z) * 0.5
	var forward: Vector3 = -game.camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01: forward = Vector3.FORWARD
	forward = forward.normalized()
	var rotation := float(sequence % 12) * TAU / 12.0
	var count := 0
	# Search the front/sides first so the encounter can be read, then all bearings.
	# Rotating the deterministic fan prevents repeated rejection of the same coast.
	for radius in [22.0, 30.0, 18.0, 38.0]:
		for offset in [0.0, 0.52, -0.52, 1.05, -1.05, 1.57, -1.57, 2.09, -2.09, 2.62, -2.62, PI]:
			count += 1
			var direction := forward.rotated(Vector3.UP, offset + rotation)
			var candidate: Vector3 = center + direction * (float(radius) + hull_padding)
			var hit := support(game, candidate, 3.0, 7.0)
			if hit.is_empty() or absf(hit.position.y - center.y) > 4.0: continue
			var point: Vector3 = hit.position + Vector3.UP * 0.08
			if not clear_body(game, point, kind) or not approach_clear(game, point, center): continue
			return {"position": point, "reason": "奶龙正在接近", "candidates": count}
	# No unverified fallback or forced placement in a wall. The director retries
	# quickly and releases abandoned actors instead of exhausting a wave forever.
	return {"position": Vector3.INF, "reason": "正在寻找通路 · 移向街道或开阔平台", "candidates": count, "failures": failures + 1}
