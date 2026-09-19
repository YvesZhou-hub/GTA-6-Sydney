extends SceneTree
## Roads you can drive on have ground under them, across the whole mapped city,
## and the retained land and bridge deck points still hold a player up.
##
## The first version of this probe checked that an old procedural road across a
## cove had been removed, by treating anything outside the procedural north-shore
## outline as water. The city now comes from mapped data and that outline no
## longer marks the coast, so the probe checks the road network directly.
func _initialize(): call_deferred("run")

var failures := 0

func check(title: String, passed: bool, detail: Dictionary = {}) -> void:
	print("WORLD_ROAD ", "PASS " if passed else "FAIL ", title, " ", JSON.stringify(detail))
	if not passed: failures += 1

func run():
	var world = load("res://scripts/harbor_world.gd").new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var space = world.get_world_3d().direct_space_state
	var walk_only: Array = preload("res://scripts/street_life.gd").WALK_ONLY
	var rules: Array = world.road_rules
	check("every mapped road segment carries its road rules", rules.size() == world.road_segments.size(), {"segments": world.road_segments.size(), "rules": rules.size()})
	var sampled := 0
	var floating: Array = []
	var service_over_water := {}
	var walkways_over_water := 0
	for i in world.road_segments.size():
		var segment: Array = world.road_segments[i]
		var drivable: bool = i >= rules.size() or not str(rules[i][0]) in walk_only
		for t in [0.25, 0.5, 0.75]:
			var p: Vector2 = segment[0].lerp(segment[1], t)
			var from := Vector3(p.x, world.GROUND + 3.0, p.y)
			var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * 8.0))
			if not drivable:
				# Waterfront boardwalks and steps are drawn without a pier under
				# them; people walk them, cars never do. Counted, not failed.
				if hit.is_empty(): walkways_over_water += 1
				continue
			sampled += 1
			if not hit.is_empty(): continue
			var kind: String = str(rules[i][0]) if i < rules.size() else "road"
			# Service ways include slipways and wharf aprons that run into the
			# water on purpose (boat ramps at Cremorne and Manly in the map data).
			if kind == "service": service_over_water[i] = [snappedf(p.x, 0.1), snappedf(p.y, 0.1)]
			else: floating.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1), kind])
	check("every public street has ground under it", floating.is_empty() and sampled > 10000, {"samples": sampled, "floating": floating.size(), "first": floating.slice(0, 20)})
	check("only a few service ways (slipways, wharf aprons) reach the water", service_over_water.size() <= 8, {"segments": service_over_water.size(), "where": service_over_water.values().slice(0, 8)})
	print("WORLD_ROAD walkway samples without ground (not a failure): ", walkways_over_water)
	for p in [Vector3(-320,5,-170),Vector3(-210,5,-175),Vector3(70,5,165),Vector3(302,5,-1218),Vector3(370,5,-1580),Vector3(33,54.5,-886)]:
		var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*1,p-Vector3.UP*4))
		check("retained land or bridge deck holds at %s" % p, not hit.is_empty())
	print("WORLD_ROAD_COMPLETE drivable_samples=", sampled, " failures=", failures, " buildings=", world._building_count, " components=", world.structures.size())
	quit(1 if failures > 0 else 0)
