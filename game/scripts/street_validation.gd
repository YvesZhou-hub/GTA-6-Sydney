extends Node
## Evidence for ambient traffic and pedestrians: they appear on mapped roads
## near the player, drive and walk, react to danger, and are released again.
const OUTPUT := "user://street-qa"
var game: Node
var street: Node3D
var checks: Array[Dictionary] = []
var native := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func check(title: String, okay: bool, detail: Dictionary = {}) -> void:
	checks.append({"name": title, "passed": okay, "detail": detail})
	print("STREET_QA ", "PASS " if okay else "FAIL ", title, " ", JSON.stringify(detail))

func frames(count: int = 3) -> void:
	for _i in count: await get_tree().process_frame

func settle(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	await frames(2)

func capture(name: String) -> void:
	if not native: return
	await frames(3)
	var started := Time.get_ticks_msec()
	var target := Engine.get_frames_drawn() + 1
	while Engine.get_frames_drawn() < target and Time.get_ticks_msec() - started < 30000: await get_tree().process_frame
	get_tree().root.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png"))

## Distance from a point to the nearest mapped centreline, ignoring height.
func road_distance(at: Vector3) -> float:
	var best := INF
	for segment: Array in game.world.road_segments:
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var span := b - a
		var length := span.length()
		if length < 0.01: continue
		var t := clampf((Vector2(at.x, at.z) - a).dot(span) / (length * length), 0.0, 1.0)
		best = minf(best, (a + span * t).distance_to(Vector2(at.x, at.z)))
	return best

func run(host: Node) -> void:
	game = host
	street = game.street
	native = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await frames(3)
	if not game.world._ready_complete:
		check("production world assembled", false)
		return finish()
	game.qa_running = true
	street.force_enabled = true
	game.settings.street_life = 1
	game.new_world("sandbox", "Street QA - no save", false)
	await frames(20)
	var george := Vector3(-33.0, 4.9, 700.0)
	game.player.global_position = george
	await settle(3.0)
	var stats: Dictionary = street.stats()
	check("mapped roads are indexed for traffic", int(stats.segments) > 500, stats)
	check("cars and pedestrians appear in the city", int(stats.cars) >= 6 and int(stats.pedestrians) >= 6, stats)
	var far_cars := 0
	var off_road := 0
	for car in street.cars:
		if car.global_position.distance_to(george) > street.RELEASE: far_cars += 1
		if road_distance(car.global_position) > 9.0: off_road += 1
	check("traffic stays on mapped roads", off_road == 0, {"off_road": off_road, "cars": street.cars.size()})
	check("nothing spawns beyond the release radius", far_cars == 0, {"far": far_cars})
	# The mapped road rules, on the real city: how many ways they close or turn
	# one-way, and whether every car on the street keeps to them.
	var closed := 0
	var one_way := 0
	for segment: Array in street._segments:
		if not bool(segment[3]): closed += 1
		if int(segment[4]) != 0: one_way += 1
	check("the city's pedestrian streets and one-way streets reach the traffic", closed > 50 and one_way > 500, {"pedestrian_ways": closed, "one_way": one_way, "indexed": street._segments.size()})
	var broken := 0
	var close_spawns := 0
	for car in street.cars:
		if not street.in_spawn_ring(car.route[0], george): close_spawns += 1
		for step in car.route_segments.size():
			var segment: Array = street._segments[int(car.route_segments[step])]
			var start: Vector3 = car.route[step]
			var from_a: bool = Vector2(start.x, start.z).distance_to(segment[0]) < Vector2(start.x, start.z).distance_to(segment[1])
			if not bool(segment[3]) or (int(segment[4]) == 1 and not from_a) or (int(segment[4]) == -1 and from_a): broken += 1
	check("every car keeps off pedestrian streets and drives one-way streets the right way", broken == 0, {"broken_steps": broken, "cars": street.cars.size()})
	check("every car appeared in the spawn ring, not beside the player", close_spawns == 0, {"close": close_spawns})
	var backwards := 0
	for car in street.cars:
		var index: int = mini(int(car.route_index) + 1, car.route.size() - 1)
		var travel: Vector3 = car.route[index] - car.route[maxi(0, index - 1)]
		travel.y = 0.0
		if travel.length() < 0.1: continue
		for mesh: MeshInstance3D in car.find_children("*Front*Wheel*", "MeshInstance3D", true, false):
			if (mesh.global_transform * mesh.get_aabb().get_center() - car.global_position).dot(travel.normalized()) < 0.0: backwards += 1
			break
	check("every car faces the way it drives", backwards == 0, {"backwards": backwards, "cars": street.cars.size()})
	var walk_off := 0
	for person in street.pedestrians:
		if road_distance(person.global_position) > 16.0: walk_off += 1
	check("pedestrians keep to the footpaths beside roads", walk_off == 0, {"off": walk_off})
	var before := {}
	for car in street.cars: before[car] = car.global_position
	await settle(1.5)
	var moved := 0
	for car in street.cars:
		if before.has(car) and before[car].distance_to(car.global_position) > 1.0: moved += 1
	check("traffic drives along its route", moved >= maxi(1, street.cars.size() / 2), {"moved": moved, "cars": street.cars.size()})
	# Point the camera down the street so the evidence shot shows the traffic.
	var nearest: Node3D = null
	for car in street.cars:
		if nearest == null or car.global_position.distance_to(game.player.global_position) < nearest.global_position.distance_to(game.player.global_position): nearest = car
	if nearest != null:
		var look: Vector3 = nearest.global_position - game.player.global_position
		game.yaw = atan2(-look.x, -look.z)
		game.pitch = -0.12
		await settle(1.2)
	await capture("street-life")
	var person_positions := {}
	for person in street.pedestrians: person_positions[person] = person.global_position
	for person in street.pedestrians: person.alarm(4.0)
	await settle(1.5)
	var ran := 0
	for person in street.pedestrians:
		if person_positions.has(person) and person_positions[person].distance_to(person.global_position) > 1.5: ran += 1
	check("alarmed pedestrians move away quickly", ran >= 1, {"ran": ran, "people": street.pedestrians.size()})
	game.player.global_position = Vector3(-33.0, 4.9, 700.0) + Vector3(900, 0, 0)
	await settle(1.6)
	var stale := 0
	for car in street.cars:
		if car.global_position.distance_to(game.player.global_position) > street.RELEASE: stale += 1
	for person in street.pedestrians:
		if person.global_position.distance_to(game.player.global_position) > street.RELEASE: stale += 1
	check("street life follows the player and releases what is left behind", stale == 0, {"stale": stale})
	game.settings.street_life = 0
	await settle(1.2)
	check("the 关闭 setting empties the streets", street.cars.is_empty() and street.pedestrians.is_empty(), street.stats())
	game.player.global_position = george
	game.settings.street_life = 2
	await settle(7.0)
	var busy: Dictionary = street.stats()
	# Density also follows the district state, so compare against that expectation.
	var factor: float = game.districts.street_factor(game.player.global_position) if is_instance_valid(game.districts) else 1.0
	var expect_cars := roundi(float(street.DENSITY[2][0]) * factor)
	var expect_people := roundi(float(street.DENSITY[2][1]) * factor)
	# Spawning is gradual and a few are released as they drive away, so the check
	# is that the busy setting gets close to its target, not exactly on it.
	check("the 热闹 setting adds more", float(busy.cars) >= expect_cars * 0.7 and float(busy.pedestrians) >= expect_people * 0.7 and int(busy.cars) > 12,
		{"cars": busy.cars, "pedestrians": busy.pedestrians, "expected": [expect_cars, expect_people], "district_factor": factor})
	# Frame cost of a busy street, for the record rather than as a hard limit.
	# Only a real window draws frames; headless runs (CI) skip this one check.
	if native:
		await frames(10)
		var started := Time.get_ticks_usec()
		var first := Engine.get_frames_drawn()
		await settle(3.0)
		var drawn: int = Engine.get_frames_drawn() - first
		var average := ((Time.get_ticks_usec() - started) / 1000.0) / maxf(1.0, float(drawn))
		check("a busy street still draws frames", drawn > 20 and average < 60.0, {"frames": drawn, "average_frame_ms": snappedf(average, 0.01), "cars": busy.cars, "pedestrians": busy.pedestrians})
	await capture("street-busy")
	# Evening: lamp heads glow and windows light up.
	if is_instance_valid(game.city_clock):
		game.city_clock.set_hour(21.5)
		await settle(2.0)
		var lit: Dictionary = game.street_lights.stats()
		check("street lamps light up at night near the player", int(lit.lit) > 0 and float(lit.night) > 0.5, lit)
		await capture("street-night")
		game.city_clock.set_hour(12.0)
		await settle(1.0)
		check("street lamps switch off in daylight", int(game.street_lights.stats().lit) == 0, game.street_lights.stats())
	finish()

func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(row: Dictionary): return row.passed)
	var file := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"passed": passed, "native": native, "checks": checks}, "\t"))
	print("STREET_QA COMPLETE checks=%d failures=%d" % [checks.size(), checks.filter(func(row: Dictionary): return not row.passed).size()])
	game.active = false
	game.finish_quit(0 if passed else 1)
