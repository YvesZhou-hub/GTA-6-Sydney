extends RefCounted
## Placement uses the complete authored visual + collision envelope, not a point ray.
## A summon reserves a new body. Existing bodies are never relocated or recycled.

static func envelope(body: Node3D) -> AABB:
	if body.has_meta("spawn_envelope"): return body.get_meta("spawn_envelope")
	var result := AABB()
	var initialized := false
	for node in body.find_children("*", "Node3D", true, false):
		if node.top_level: continue # World-space wake particles are not vehicle geometry.
		var bounds := AABB()
		if node is MeshInstance3D and node.mesh != null:
			bounds = node.mesh.get_aabb()
		elif node is CollisionShape3D and node.shape != null:
			bounds = node.shape.get_debug_mesh().get_aabb()
		else: continue
		bounds = (body.global_transform.affine_inverse()*node.global_transform)*bounds
		result = result.merge(bounds) if initialized else bounds
		initialized = true
	body.set_meta("spawn_envelope", result)
	return result

static func _excluded(game: Node3D, body: RigidBody3D) -> Array[RID]:
	return [body.get_rid(), game.player.get_rid()]

static func clear_envelope(game: Node3D, body: RigidBody3D, pose: Transform3D, margin := 0.6) -> bool:
	var bounds := envelope(body)
	var shape := BoxShape3D.new()
	# Only horizontal padding: the lowest wheel remains a measured 12 cm above support.
	shape.size = bounds.size+Vector3(margin*2,0.05,margin*2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = pose*Transform3D(Basis.IDENTITY,bounds.get_center())
	query.collision_mask = 15
	query.exclude = _excluded(game,body)
	if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	# Bodies added during this same UI event may not yet be registered in the physics server.
	var reserved: AABB = pose*bounds.grow(margin)
	# Distant skyline meshes deliberately have no physics; still never create inside them.
	for plot_list in [game.world._building_plots,game.world._distant_visual_plots]:
		for plot in plot_list:
			if reserved.intersects(plot.grow(margin)): return false
	# A custom tower can enclose a waiting wing without any triangle wall
	# crossing the query shape. Reuse closed-solid containment, including
	# destroyed components and open ground under raised architecture.
	var migration=load("res://scripts/map_migration.gd")
	if migration._overlaps_custom(game.world,reserved,migration._geometry(game.world).custom): return false
	for other in game.vehicles:
		if other == body or not is_instance_valid(other): continue
		if reserved.intersects(other.global_transform*envelope(other).grow(margin)): return false
	var player_point: Vector3 = game.current_vehicle.global_position if is_instance_valid(game.current_vehicle) else game.player.global_position
	if reserved.grow(1.2).has_point(player_point): return false
	return true

static func _ground_allowed(hit: Dictionary) -> bool:
	if hit.is_empty() or hit.normal.y < 0.985 or hit.position.y < 0.5: return false
	var collider = hit.collider
	if collider is RigidBody3D or collider is CharacterBody3D: return false
	if collider.has_meta("airport_damage_id"): return false
	var ancestor: Node = collider
	while ancestor != null:
		var surface_name := str(ancestor.name).to_lower()
		if "roof" in surface_name or "canopy" in surface_name or "concourse" in surface_name: return false
		if surface_name.ends_with("_terminal") or surface_name=="harbour_aviation_hangar": return false
		ancestor=ancestor.get_parent()
	if collider.has_meta("damage_id"):
		var id := str(collider.get_meta("damage_id"))
		return ("deck" in id or "approach" in id or "bridge/ramp" in id or "pavement" in id or "terrace" in id or "pier" in id) and not "rail" in id
	# Anonymous tall boxes are walls/furniture, not designated parking surfaces.
	for shape_node in collider.get_children():
		if shape_node is CollisionShape3D and shape_node.shape is BoxShape3D and shape_node.shape.size.y>1.5: return false
	return true

static func _ground_pose(game: Node3D, body: RigidBody3D, at: Vector3, heading: float) -> Dictionary:
	var bounds := envelope(body)
	var basis := Basis(Vector3.UP, heading)
	var samples := [Vector3.ZERO]
	# Check the whole footprint, including wing/rotor clearance and edges of land or piers.
	for x in [-0.48,0.0,0.48]:
		for z in [-0.48,0.0,0.48]:
			samples.append(Vector3(bounds.get_center().x+bounds.size.x*x,0,bounds.get_center().z+bounds.size.z*z))
	var lowest := INF
	var highest := -INF
	for local in samples:
		var p: Vector3 = at+basis*local
		var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*65,p-Vector3.UP*95,15,_excluded(game,body))
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		if not _ground_allowed(hit): return {}
		lowest = minf(lowest,hit.position.y)
		highest = maxf(highest,hit.position.y)
	if highest-lowest > 0.2: return {}
	var pose := Transform3D(basis,Vector3(at.x,highest-bounds.position.y+0.12,at.z))
	if not clear_envelope(game,body,pose): return {}
	return {"transform":pose,"airborne":false,"description":"附近的平坦空地"}

static func _water_pose(game: Node3D, body: RigidBody3D, at: Vector3, heading: float) -> Dictionary:
	var bounds := envelope(body)
	var basis := Basis(Vector3.UP,heading)
	for x in [-0.6,0.0,0.6]:
		for z in [-0.6,0.0,0.6]:
			var p := Vector3(at.x,0,at.z)+basis*Vector3(bounds.size.x*x,0,bounds.size.z*z)
			var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*100,p-Vector3.UP*3.0,15,_excluded(game,body))
			if not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return {}
	var pose := Transform3D(basis,Vector3(at.x,0.95,at.z))
	if not clear_envelope(game,body,pose,1.5): return {}
	return {"transform":pose,"airborne":false,"description":"附近的开阔水面"}

static func find_spawn(game: Node3D, body: RigidBody3D, runway_start := false) -> Dictionary:
	var origin: Vector3 = game.current_vehicle.global_position if is_instance_valid(game.current_vehicle) else game.player.global_position
	var forward := Vector3.FORWARD.rotated(Vector3.UP,game.yaw)
	var bounds := envelope(body)
	var radius := maxf(bounds.size.x,bounds.size.z)*0.6+6.0
	if body.kind == "airliner":
		if not runway_start:
			for ring in range(3):
				for angle in [0.0,0.6,-0.6,1.2,-1.2,2.0,-2.0,PI]:
					var at := origin+forward.rotated(Vector3.UP,angle)*(radius+ring*radius)
					var nearby := _ground_pose(game,body,at,game.yaw)
					if not nearby.is_empty(): return nearby
		var airport = game.airport
		if not is_instance_valid(airport): return {}
		var candidates: Array = []
		if runway_start:
			var start: Vector3 = airport.anchors.runway_start
			var direction := Vector3.FORWARD.rotated(Vector3.UP,airport.runway_heading)
			for n in 24: candidates.append({"at":start+direction*n*90.0,"heading":airport.runway_heading})
		else:
			for runway in airport.runway_data:
				var direction: Vector3 = (runway.a-runway.b).normalized()
				for distance in range(120,int(runway.length)-100,90):
					candidates.append({"at":runway.b+direction*distance,"heading":atan2(-direction.x,-direction.z)})
			for x in range(-4260,-3770,82):
				for z in range(8240,8820,82): candidates.append({"at":Vector3(x,7,z),"heading":airport.runway_heading})
			candidates.sort_custom(func(a,b): return origin.distance_squared_to(a.at)<origin.distance_squared_to(b.at))
		for candidate in candidates:
			var found := _ground_pose(game,body,candidate.at,candidate.heading)
			if not found.is_empty():
				found.description = "悉尼机场的空闲跑道 / 机坪"
				return found
		# No instance limit: expand into remaining airport land when marked parking is full.
		# Real available space and collision checks, rather than a fleet counter, determine success.
		if not runway_start:
			for x in range(-4480,-1900,85):
				for z in range(8050,11850,85):
					var found := _ground_pose(game,body,Vector3(x,7,z),airport.runway_heading)
					if not found.is_empty():
						found.description = "机场附近的开阔空地"
						return found
		return {}
	if body.kind in ["glider","paraglider"]:
		# Unpowered wings wait in clear air until the player explicitly chooses to board.
		# Never teleport on summon; the persistent marker and garage boarding action explain access.
		for ring in range(1,maxi(20,ceili(sqrt(game.vehicles.size()))+10)):
			for angle in [0.0,0.5,-0.5,1.0,-1.0,2.0,-2.0,PI]:
				var at := origin+forward.rotated(Vector3.UP,angle)*(radius+ring*10)
				at.y = maxf(origin.y+15.0,85.0)+floori(ring/8.0)*30.0
				var pose := Transform3D(Basis(Vector3.UP,game.yaw),at)
				if clear_envelope(game,body,pose,2.0): return {"transform":pose,"airborne":true,"description":"视野附近的空中待飞点"}
		return {}
	for ring in range(0,maxi(12,ceili(sqrt(game.vehicles.size()))+5)):
		for angle in [0.0,0.4,-0.4,0.8,-0.8,1.3,-1.3,2.0,-2.0,PI]:
			var at := origin+forward.rotated(Vector3.UP,angle)*(radius+ring*maxf(radius*0.65,7.0))
			var found := _water_pose(game,body,at,game.yaw) if body.kind == "yacht" else _ground_pose(game,body,at,game.yaw)
			if not found.is_empty(): return found
	# Search real mapped road segments when the immediate neighborhood is obstructed.
	if body.kind != "yacht":
		var road_candidates: Array = []
		for road in game.world.road_segments:
			var midpoint: Vector2 = (road[0]+road[1])*0.5
			road_candidates.append(Vector3(midpoint.x,5.0,midpoint.y))
		road_candidates.sort_custom(func(a,b): return origin.distance_squared_to(a)<origin.distance_squared_to(b))
		for at in road_candidates:
			var found := _ground_pose(game,body,at,game.yaw)
			if not found.is_empty():
				found.description = "有足够空间的道路附近"
				return found
	else:
		var marina: Vector3 = game.world.anchors.get("marina",Vector3(-240,1,-330))
		for ring in range(1,45):
			for angle in [0.0,0.6,-0.6,1.2,-1.2,2.0,-2.0,PI]:
				var found := _water_pose(game,body,marina+Vector3.FORWARD.rotated(Vector3.UP,angle)*ring*20.0,game.yaw)
				if not found.is_empty(): return found
	return {}
