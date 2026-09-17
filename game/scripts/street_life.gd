extends Node3D
## Keeps the streets around the player busy: traffic on the mapped road network
## and pedestrians on the footpaths. Everything is ambient, spawned close to the
## player and released again, so nothing is saved and the count stays bounded.

const Car = preload("res://scripts/traffic_car.gd")
const Pedestrian = preload("res://scripts/street_pedestrian.gd")
const Visual = preload("res://scripts/character_visual.gd")
const CELL := 160.0
const SPAWN_NEAR := 26.0
const SPAWN_FAR := 115.0
const RELEASE := 190.0
## Cars and pedestrians for each 街上人车 setting: 关闭 / 正常 / 热闹.
const DENSITY := [[0, 0], [18, 26], [30, 44]]

var game: Node
var force_enabled := false
var road_y := 4.59
var cars: Array = []
var pedestrians: Array = []
var _segments: Array = []
var _grid: Dictionary = {}
var _joints: Dictionary = {}
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


func setup(host: Node) -> void:
	game = host
	name = "StreetLife"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.seed = 5150
	road_y = float(game.world.GROUND) + 0.09
	_index_roads()


## Mapped centrelines become a lookup grid plus a junction table, so a car can
## keep driving from one way into the next without searching the whole city.
func _index_roads() -> void:
	for segment: Array in game.world.road_segments:
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var width := float(segment[2])
		if a.distance_to(b) < 6.0 or width < 6.0: continue
		var index := _segments.size()
		_segments.append([a, b, width])
		var cell := Vector2i(floori((a.x + b.x) * 0.5 / CELL), floori((a.y + b.y) * 0.5 / CELL))
		if not _grid.has(cell): _grid[cell] = []
		_grid[cell].append(index)
		for point: Vector2 in [a, b]:
			var key := _joint_key(point)
			if not _joints.has(key): _joints[key] = []
			_joints[key].append(index)


func _joint_key(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x * 2.0), roundi(point.y * 2.0))


func density() -> int:
	if not is_instance_valid(game) or not game.settings is Dictionary: return 1
	# QA runs measure production spawning, physics and encounters; ambient traffic
	# would move through those measurements, so it stays off unless asked for.
	if bool(game.qa_running) and not force_enabled: return 0
	return clampi(int(game.settings.get("street_life", 1)), 0, DENSITY.size() - 1)


func anchor() -> Vector3:
	if is_instance_valid(game.current_vehicle): return game.current_vehicle.global_position
	return game.player.global_position


func _process(delta: float) -> void:
	if not is_instance_valid(game) or not game.active or game.paused: return
	var here := anchor()
	var threat := _threat(here)
	var has_threat: bool = threat.is_finite()
	for car in cars.duplicate():
		if not is_instance_valid(car): cars.erase(car); continue
		if not car.advance(delta, _ground) or car.global_position.distance_to(here) > RELEASE: _release(car, cars)
	for person in pedestrians.duplicate():
		if not is_instance_valid(person): pedestrians.erase(person); continue
		if not person.step(delta, threat, has_threat) or person.global_position.distance_to(here) > RELEASE: _release(person, pedestrians)
	_clock += delta
	if _clock < 0.25: return
	_clock = 0.0
	var wanted: Array = DENSITY[density()]
	while cars.size() > int(wanted[0]): _release(cars.back(), cars)
	while pedestrians.size() > int(wanted[1]): _release(pedestrians.back(), pedestrians)
	# A few per tick fills an empty street quickly without a spike on one frame.
	for i in 3:
		if cars.size() < int(wanted[0]): _spawn_car(here)
		if pedestrians.size() < int(wanted[1]): _spawn_pedestrian(here)


func _release(node: Node, list: Array) -> void:
	list.erase(node)
	if is_instance_valid(node): node.queue_free()


func _ground(at: Vector3) -> float:
	return road_y


## The nearest Nailong, or a car being driven at speed, is what people run from.
func _threat(here: Vector3) -> Vector3:
	var nearest := Vector3(INF, INF, INF)
	var best := 40.0
	for enemy: Node3D in get_tree().get_nodes_in_group("nailong_enemies"):
		if not is_instance_valid(enemy): continue
		var distance := enemy.global_position.distance_to(here)
		if distance < best:
			best = distance
			nearest = enemy.global_position
	if nearest.is_finite(): return nearest
	if is_instance_valid(game.current_vehicle) and game.current_vehicle.linear_velocity.length() > 9.0:
		return game.current_vehicle.global_position
	return Vector3(INF, INF, INF)


func _nearby_segments(here: Vector3) -> Array:
	var found := []
	var cell := Vector2i(floori(here.x / CELL), floori(here.z / CELL))
	for x in range(cell.x - 1, cell.x + 2):
		for y in range(cell.y - 1, cell.y + 2):
			var key := Vector2i(x, y)
			if _grid.has(key): found.append_array(_grid[key])
	return found


## Picks a mapped segment in the spawn ring and follows junctions into a route.
## Returns the centreline points and the road width, which sets lanes and paths.
func _route_from(here: Vector3, length: int) -> Dictionary:
	var candidates := _nearby_segments(here)
	if candidates.is_empty(): return {}
	for attempt in 12:
		var index: int = candidates[_rng.randi_range(0, candidates.size() - 1)]
		var segment: Array = _segments[index]
		var middle := Vector3((segment[0].x + segment[1].x) * 0.5, road_y, (segment[0].y + segment[1].y) * 0.5)
		var distance := middle.distance_to(here)
		if distance < SPAWN_NEAR or distance > SPAWN_FAR: continue
		var width := float(segment[2])
		var forward := _rng.randf() < 0.5
		var points: Array = [Vector3(segment[0].x, road_y, segment[0].y), Vector3(segment[1].x, road_y, segment[1].y)]
		if not forward: points.reverse()
		var used := {index: true}
		for step in length:
			var tail: Vector3 = points[points.size() - 1]
			var before: Vector3 = points[points.size() - 2]
			var next := _continue(tail, before, used)
			if next.is_empty(): break
			points.append(next[0])
			used[int(next[1])] = true
		return {"points": points, "width": width} if points.size() >= 2 else {}
	return {}


## Prefers going straight on at a junction, like a car keeping to its road.
func _continue(tail: Vector3, before: Vector3, used: Dictionary) -> Array:
	var key := _joint_key(Vector2(tail.x, tail.z))
	if not _joints.has(key): return []
	var heading := (tail - before).normalized()
	var best: Array = []
	var best_score := -2.0
	for index: int in _joints[key]:
		if used.has(index): continue
		var segment: Array = _segments[index]
		var a := Vector3(segment[0].x, road_y, segment[0].y)
		var b := Vector3(segment[1].x, road_y, segment[1].y)
		var far: Vector3 = b if a.distance_to(tail) < b.distance_to(tail) else a
		if far.distance_to(tail) < 1.0: continue
		var score := heading.dot((far - tail).normalized())
		if score > best_score:
			best_score = score
			best = [far, index]
	return best if best_score > -0.2 else []


func _spawn_car(here: Vector3) -> Node3D:
	var route := _route_from(here, 7)
	if route.is_empty(): return null
	var car: RigidBody3D = Car.new()
	add_child(car)
	car.setup(_rng.randi())
	car.route = route.points
	# Keep left, half a lane in from the kerb, however wide the mapped road is.
	car.lane = clampf(float(route.width) * 0.24, 1.5, 3.4)
	car.speed = 7.0 + _rng.randf() * 4.0
	car.global_position = route.points[0]
	car.advance(0.0, _ground)
	cars.append(car)
	return car


func _spawn_pedestrian(here: Vector3) -> Node3D:
	var found := _route_from(here, 4)
	if found.is_empty(): return null
	var route: Array = found.points
	var footpath := clampf(float(found.width) * 0.5 + 1.7, 4.0, 9.5)
	# Footpaths run beside the carriageway; pick one side and offset the route.
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var walk: Array = []
	for i in route.size():
		var point: Vector3 = route[i]
		var direction: Vector3 = (route[mini(i + 1, route.size() - 1)] - route[maxi(i - 1, 0)])
		if direction.length() < 0.01: direction = Vector3.FORWARD
		direction = direction.normalized()
		var offset := Vector3(direction.z, 0.0, -direction.x) * side * footpath
		walk.append(point + offset + Vector3(0, 0.2, 0))
	var person: CharacterBody3D = Pedestrian.new()
	add_child(person)
	var keys: Array = Visual.model_keys()
	person.setup(str(keys[_rng.randi_range(0, keys.size() - 1)]), walk, 1.1 + _rng.randf() * 0.5)
	person.global_position = walk[0]
	pedestrians.append(person)
	return person


func clear() -> void:
	for car in cars.duplicate(): _release(car, cars)
	for person in pedestrians.duplicate(): _release(person, pedestrians)


func stats() -> Dictionary:
	return {"cars": cars.size(), "pedestrians": pedestrians.size(), "density": density(), "segments": _segments.size()}
