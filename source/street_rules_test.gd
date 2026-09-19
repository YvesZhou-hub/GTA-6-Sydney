extends SceneTree
## Ambient traffic on a small hand-made network: cars keep off pedestrian
## streets, use one-way streets only in their mapped direction, appear in the
## spawn ring (not beside the player), and face the way they drive; people
## face the way they walk.
const StreetLife = preload("res://scripts/street_life.gd")
const Visual = preload("res://scripts/character_visual.gd")

class FixtureWorld extends Node3D:
	const GROUND := 0.0
	var road_segments: Array = []
	var road_rules: Array = []
class FixtureGame extends Node3D:
	var world: Node3D
	var player: Node3D
	var current_vehicle: Node3D
	var active := false
	var paused := false

var checks: Array = []

func _initialize() -> void: call_deferred("run")

func check(title: String, passed: bool, detail: Dictionary = {}) -> void:
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("STREET_RULES ","PASS " if passed else "FAIL ",title," ",JSON.stringify(detail))

func run() -> void:
	var game := FixtureGame.new(); root.add_child(game)
	var world := FixtureWorld.new(); game.world = world; game.add_child(world)
	game.player = Node3D.new(); game.add_child(game.player)
	# Player at the origin. Junction J at (80, 0).
	var roads := [
		[Vector2(40,0), Vector2(80,0), 10.0, "residential", 0],      # 0 two-way into J
		[Vector2(80,0), Vector2(110,0), 10.0, "residential", 1],     # 1 one-way, away from J only
		[Vector2(80,0), Vector2(80,40), 9.0, "pedestrian", 0],       # 2 pedestrian street off J
		[Vector2(80,-40), Vector2(80,0), 10.0, "residential", 1],    # 3 one-way, into J only
		[Vector2(0,10), Vector2(0,110), 10.0, "residential", 0],     # 4 long road; one end beside the player
		[Vector2(110,0), Vector2(140,0), 10.0, "residential", -1],   # 5 one-way mapped backwards: 140 -> 110 only
	]
	for road: Array in roads:
		world.road_segments.append([road[0], road[1], road[2]])
		world.road_rules.append([road[3], road[4]])
	var street = StreetLife.new()
	game.add_child(street)
	street.setup(game)
	street.set_process(false)
	var here := Vector3.ZERO

	var car_routes: Array = []
	var walk_routes: Array = []
	for i in 400:
		var route: Dictionary = street._route_from(here, 6, true)
		if not route.is_empty(): car_routes.append(route)
		var walk: Dictionary = street._route_from(here, 6, false)
		if not walk.is_empty(): walk_routes.append(walk)
	check("routes are found for cars and people", car_routes.size() > 50 and walk_routes.size() > 50, {"cars":car_routes.size(),"people":walk_routes.size()})

	var on_pedestrian := 0
	var wrong_way := 0
	var near_spawn := 0
	for route: Dictionary in car_routes:
		var points: Array = route.points
		if not street.in_spawn_ring(points[0], here): near_spawn += 1
		for step in route.segments.size():
			var segment: Array = street._segments[int(route.segments[step])]
			if not bool(segment[3]): on_pedestrian += 1
			var start: Vector3 = points[step]
			var from_a: bool = Vector2(start.x, start.z).distance_to(segment[0]) < Vector2(start.x, start.z).distance_to(segment[1])
			if (int(segment[4]) == 1 and not from_a) or (int(segment[4]) == -1 and from_a): wrong_way += 1
	check("cars never drive onto a pedestrian street", on_pedestrian == 0, {"steps_on_pedestrian_ways":on_pedestrian})
	check("cars use one-way streets only in the mapped direction", wrong_way == 0, {"wrong_way_steps":wrong_way})
	check("cars appear in the spawn ring, never beside the player", near_spawn == 0, {"near":near_spawn,"ring":[street.SPAWN_NEAR, street.SPAWN_FAR]})
	var long_road_starts: Array = []
	for route: Dictionary in car_routes:
		if int(route.segments[0]) == 4: long_road_starts.append(snappedf(Vector2(route.points[0].x, route.points[0].z).length(), 0.1))
	check("a long road whose middle is in the ring starts only from its far end", not long_road_starts.is_empty() and long_road_starts.all(func(d): return d >= street.SPAWN_NEAR), {"start_distances":long_road_starts.slice(0, 6)})
	var took_east := 0
	var took_backwards_way := 0
	for route: Dictionary in car_routes:
		var ids: Array = route.segments
		for step in range(1, ids.size()):
			if int(ids[step - 1]) == 0 and int(ids[step]) == 1: took_east += 1
			if int(ids[step]) == 5 and int(ids[step - 1]) == 1: took_backwards_way += 1
	check("at a junction, a car turns only into ways it may enter", took_east > 0 and took_backwards_way == 0, {"into_oneway":took_east,"against_reversed_oneway":took_backwards_way})
	var walked_pedestrian := walk_routes.any(func(route: Dictionary): return route.segments.has(2))
	check("people may walk down the pedestrian street", walked_pedestrian)

	# A spawned car keeps its route ahead of it instead of stopping at the end.
	var car = street._spawn_car(here)
	var extended := false
	if is_instance_valid(car):
		var before: int = car.route.size()
		car.route_index = maxi(0, car.route.size() - 2)
		street._extend(car)
		extended = car.route.size() >= before
	check("a spawned car is given a route and can be extended", is_instance_valid(car) and extended)

	# Facing: the car's front wheels lead in the direction it drives, and a
	# person's face (the model's own +Z) points where they walk.
	var driver = preload("res://scripts/traffic_car.gd").new()
	game.add_child(driver)
	driver.setup(0)
	driver.lane = 0.0
	driver.route = [Vector3(0,0,20), Vector3(0,0,-60)]
	driver.global_position = Vector3(0,0,20)
	for i in 60: driver.advance(1.0 / 30.0, func(_p): return 0.0)
	var travel := Vector3(0,0,-1)
	var front_lead := -INF
	for mesh: MeshInstance3D in driver.find_children("*FrontLeftWheel*", "MeshInstance3D", true, false):
		front_lead = (mesh.global_transform * mesh.get_aabb().get_center() - driver.global_position).dot(travel)
	check("a car's front wheels lead the way it drives", front_lead > 0.5, {"front_wheel_ahead_m":snappedf(front_lead, 0.01)})
	var person := Visual.new()
	game.add_child(person)
	person.setup("casual", 1.8)
	for i in 60: person.face(travel, 1.0 / 30.0)
	var facing: Vector3 = person._model.global_basis.z.normalized()
	check("a person faces the way they walk", facing.dot(travel) > 0.95, {"dot":snappedf(facing.dot(travel), 0.01)})

	var passed: bool = checks.all(func(c): return c.passed)
	print("STREET_RULES_COMPLETE ", checks.size(), " passed=", passed)
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if passed else 1)
