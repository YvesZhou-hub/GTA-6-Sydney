extends RigidBody3D
## A car that drives the mapped road network near the player. It is kinematic:
## the street system moves it along the centreline, and Jolt still pushes the
## player's vehicle, enemies and props out of the way. Models are CC0 by
## Quaternius; see assets/thirdparty/SOURCES.md.

const MODELS := ["res://assets/thirdparty/vehicles/car.glb", "res://assets/thirdparty/vehicles/car2.glb",
	"res://assets/thirdparty/vehicles/taxi.glb", "res://assets/thirdparty/vehicles/suv.glb",
	"res://assets/thirdparty/vehicles/sports_car.glb", "res://assets/thirdparty/vehicles/sports_car2.glb",
	"res://assets/thirdparty/vehicles/police_car.glb"]
const BODY_SIZE := Vector3(1.9, 1.4, 4.3)

static var _scenes: Dictionary = {}

var speed := 11.0
var target_speed := 11.0
var route: Array = []
## The street_life segment behind each step of the route, so it can be extended
## and checked against the road rules.
var route_segments: Array = []
var route_index := 0
var progress := 0.0
var lane := 2.2
var blocked := 0.0
var _model: Node3D
var _probe: RayCast3D


static func scene(path: String) -> PackedScene:
	if not _scenes.has(path): _scenes[path] = load(path)
	return _scenes[path]


func setup(model_index: int) -> void:
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	collision_layer = 2
	collision_mask = 1 | 2 | 8
	add_to_group("street_traffic")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BODY_SIZE
	shape.shape = box
	shape.position.y = BODY_SIZE.y * 0.5
	add_child(shape)
	_model = scene(MODELS[model_index % MODELS.size()]).instantiate()
	# The Quaternius cars face +Z (front wheels at +1.2 m); the car drives
	# towards -Z, where its obstacle probe looks.
	_model.rotation.y = PI
	add_child(_model)
	_probe = RayCast3D.new()
	_probe.target_position = Vector3(0, 0, -9.0)
	_probe.position = Vector3(0, 0.7, -BODY_SIZE.z * 0.5)
	_probe.collision_mask = 1 | 2
	_probe.exclude_parent = true
	add_child(_probe)


## Drives to the next point of the route; returns false when the route runs out.
func advance(delta: float, ground: Callable) -> bool:
	if route_index + 1 >= route.size(): return false
	var from: Vector3 = route[route_index]
	var to: Vector3 = route[route_index + 1]
	var span := from.distance_to(to)
	if span < 0.01:
		route_index += 1
		return true
	var direction := (to - from) / span
	var side := Vector3(direction.z, 0.0, -direction.x)
	# Sydney drives on the left, so the lane sits left of the centreline.
	var stop := _probe.is_colliding() and _probe.get_collider() != self
	blocked = maxf(0.0, blocked - delta) if not stop else 1.2
	target_speed = 0.0 if blocked > 0.0 else _cruise(span)
	speed = move_toward(speed, target_speed, delta * (26.0 if target_speed < speed else 7.0))
	progress += speed * delta
	while progress >= span:
		progress -= span
		route_index += 1
		if route_index + 1 >= route.size(): return false
		from = route[route_index]
		to = route[route_index + 1]
		span = maxf(0.01, from.distance_to(to))
		direction = (to - from) / span
		side = Vector3(direction.z, 0.0, -direction.x)
	var at: Vector3 = from + direction * progress + side * lane
	at.y = ground.call(at)
	global_position = at
	var heading := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, heading, clampf(delta * 6.0, 0.0, 1.0))
	return true


func _cruise(span: float) -> float:
	# Short mapped blocks are junctions and laneways; take them slowly.
	return clampf(6.0 + span * 0.35, 6.0, 15.0)
