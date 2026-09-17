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
	await settle(5.0)
	var busy: Dictionary = street.stats()
	check("the 热闹 setting adds more", int(busy.cars) > 18 and int(busy.pedestrians) > 26, busy)
	# Frame cost of a busy street, for the record rather than as a hard limit.
	await frames(10)
	var started := Time.get_ticks_usec()
	var first := Engine.get_frames_drawn()
	await settle(3.0)
	var drawn: int = Engine.get_frames_drawn() - first
	var average := ((Time.get_ticks_usec() - started) / 1000.0) / maxf(1.0, float(drawn))
	check("a busy street still draws frames", drawn > 20 and average < 60.0, {"frames": drawn, "average_frame_ms": snappedf(average, 0.01), "cars": busy.cars, "pedestrians": busy.pedestrians})
	await capture("street-busy")
	finish()

func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(row: Dictionary): return row.passed)
	var file := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"passed": passed, "native": native, "checks": checks}, "\t"))
	print("STREET_QA COMPLETE checks=%d failures=%d" % [checks.size(), checks.filter(func(row: Dictionary): return not row.passed).size()])
	game.active = false
	game.finish_quit(0 if passed else 1)
