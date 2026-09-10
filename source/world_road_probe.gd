extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var world = load("res://scripts/harbor_world.gd").new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var space = world.get_world_3d().direct_space_state
	var checked := 0
	var failures := 0
	for seg in world.road_segments:
		if checked>=8: break
		for t in [0.25,0.5,0.75]:
			var p: Vector2 = seg[0].lerp(seg[1],t)
			if p.y> -1000 or p.y< -1760 or p.x>900: continue
			if Geometry2D.is_point_in_polygon(p,world.north_polygon): continue
			if world._distance_segment(p,Vector2(149,-1109),Vector2(340,-1510))<75: continue
			var near_coast := false
			for i in range(world.north_polygon.size()-1):
				if world._distance_segment(p,world.north_polygon[i],world.north_polygon[i+1])<12: near_coast = true
			if near_coast: continue
			var from := Vector3(p.x,8,p.y)
			var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(from,from-Vector3.UP*20))
			var clear: bool = hit.is_empty()
			print("WORLD_ROAD former_cove_ribbon ",p," water_clear=",clear)
			if not clear: failures += 1
			checked += 1
			if checked>=8: break
	for p in [Vector3(-320,5,-170),Vector3(-210,5,-175),Vector3(70,5,165),Vector3(302,5,-1218),Vector3(370,5,-1580),Vector3(33,54.5,-886)]:
		var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*1,p-Vector3.UP*4))
		var supported: bool = not hit.is_empty()
		print("WORLD_ROAD retained_land_or_bridge ",p," supported=",supported)
		if not supported: failures += 1
	print("WORLD_ROAD_COMPLETE water_samples=",checked," failures=",failures," buildings=",world._building_count," components=",world.structures.size())
	quit(failures)
