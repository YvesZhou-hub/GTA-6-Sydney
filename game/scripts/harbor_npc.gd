class_name HarborNPC
extends CharacterBody3D
## Small deterministic pedestrian with local collision avoidance and persistent
## memory. The model and its clips are CC0 by Quaternius; see
## assets/thirdparty/SOURCES.md.
const Visual = preload("res://scripts/character_visual.gd")

var stable_id: String = ""
var display_name: String = ""
var occupation: String = ""
var job_id: String = ""
var route: Array[Vector3] = []
var route_index: int = 0
var memories: Dictionary = {"greeted": 0, "accidents": 0, "jobs_completed": 0}
var mood: String = "walking"
var _player_pos := Vector3.ZERO
var _player_speed: float = 0.0
var _player_vehicle: String = ""
var _danger_time: float = 0.0
var _greeting_time: float = 0.0
var _blocked_time: float = 0.0
var _rest_time: float = 0.0
var _body: Visual
var _label: Label3D
var _base_speed: float = 1.35

func configure(object_id: String, person_name: String, role: String, points: Array, hue: float, assignment: String = "") -> void:
	stable_id = object_id
	display_name = person_name
	occupation = role
	job_id = assignment
	name = object_id
	for point in points:
		if point is Vector3:
			route.append(point)
	if route.is_empty():
		route.append(Vector3(0, 4.6, 0))
	position = route[0]
	_base_speed = 1.1 + fposmod(hue * 7.0, 0.55)
	collision_layer = 8
	collision_mask = 1
	floor_snap_length = 0.5
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.75
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.875
	add_child(collision)
	_build_person(hue)
	_label = Label3D.new()
	_label.text = display_name + "\n" + occupation
	_label.position.y = 2.2
	_label.font_size = 26
	_label.pixel_size = 0.01
	_label.outline_size = 7
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color("f1eee1")
	add_child(_label)

## Every resident uses one of the shared models, chosen from their own hue so a
## saved world keeps the same faces.
func _build_person(hue: float) -> void:
	_body = Visual.new()
	add_child(_body)
	var keys: Array = Visual.model_keys()
	_body.setup(str(keys[int(fposmod(hue * keys.size() * 7.0, keys.size()))]), 1.78)

func update_context(player_pos: Vector3, player_vehicle: String, player_speed: float) -> void:
	_player_pos = player_pos
	_player_vehicle = player_vehicle
	_player_speed = player_speed

func witness_incident(at: Vector3, severity: float) -> void:
	if global_position.distance_to(at) < 100.0 + severity * 0.5:
		memories["accidents"] = int(memories.get("accidents", 0)) + 1
		_danger_time = maxf(_danger_time, clampf(severity * 0.18, 4.0, 18.0))
		mood = "alarmed"

func talk(active_job: Dictionary, completed: Dictionary) -> String:
	memories["greeted"] = int(memories.get("greeted", 0)) + 1
	_greeting_time = 5.0
	if _danger_time > 0.0:
		return "%s: Give us some room! I'll be here when the waterfront is safe." % display_name
	if int(memories.get("accidents", 0)) > 0 and int(memories["greeted"]) % 3 == 0:
		return "%s: I remember that crash. The workshop can repair vehicles; the damage stays until someone fixes it." % display_name
	if not active_job.is_empty():
		if str(active_job.get("id", "")) == job_id:
			return "%s: %s" % [display_name, str(active_job.get("hint", "Your activity is under way. Follow the amber marker."))]
		return "%s: Finish your current activity, then come back. There's always another shift." % display_name
	if int(completed.get(job_id, 0)) > 0:
		return "%s: Welcome back. Your last shift helped. There is another %s available at the exchange." % [display_name, occupation.to_lower()]
	match job_id:
		"photo": return "%s: The harbour looks different on foot. Three viewpoints, three photographs. Use E at each amber marker." % display_name
		"salvage": return "%s: There is a loose timber case at the recovery point. Carry it with G, bring any vehicle, then unload it at the workshop." % display_name
		"harbor": return "%s: Our wharf sensors need a close inspection. Visit each station in a boat and slow below 3 metres per second." % display_name
		"air": return "%s: The aerial survey needs three clear observation passes. A helicopter, glider or aircraft will do; keep above the water." % display_name
		"race": return "%s: A timed harbour drive. The next gate appears in amber. Stay on the road; repairs come out of your earnings." % display_name
	return "%s: %s" % [display_name, ["The steps lead up to the bridge walk. The view is worth it.", "You can keep recovered things in your waterfront workshop.", "The harbour is busy. Slow down near the wharves.", "A sunset crossing is my favourite part of this city."][int(memories["greeted"]) % 4]]

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	var distance := global_position.distance_to(_player_pos)
	_label.visible = distance < 17.0
	if distance > 380.0:
		visible = false
		return
	visible = true
	_danger_time = maxf(0.0, _danger_time - delta)
	_greeting_time = maxf(0.0, _greeting_time - delta)
	_rest_time = maxf(0.0, _rest_time - delta)
	var dangerous := not _player_vehicle.is_empty() and _player_vehicle != "foot" and _player_speed > 6.0 and distance < 16.0
	if dangerous:
		_danger_time = maxf(_danger_time, 2.0)
	var direction := Vector3.ZERO
	var walk_speed := _base_speed
	if _danger_time > 0.0:
		mood = "alarmed"
		direction = global_position - _player_pos
		direction.y = 0
		direction = direction.normalized()
		walk_speed = 3.3 if dangerous else 1.7
		_label.text = display_name + "\nCareful!"
	elif _greeting_time > 0.0 or distance < 1.7:
		mood = "talking"
		_label.text = display_name + "\n" + occupation
		var face := _player_pos - global_position
		face.y = 0
		if face.length_squared() > 0.05: _body.face(face, delta, 5.0)
	elif _rest_time > 0.0:
		mood = "resting"
	else:
		mood = "walking"
		_label.text = display_name + "\n" + occupation
		direction = route[route_index] - global_position
		direction.y = 0
		if direction.length() < 1.0:
			route_index = (route_index + 1) % route.size()
			_rest_time = 2.5
			direction = Vector3.ZERO
		else:
			direction = direction.normalized()
		# Side-step a stationary obstruction instead of pushing indefinitely.
		if distance < 3.0 and distance > 1.7:
			var away := global_position - _player_pos
			away.y = 0
			direction = (direction + away.normalized() * 1.5).normalized()
	if _blocked_time > 1.1:
		direction = direction.rotated(Vector3.UP, 1.25)
		mood = "avoiding obstruction"
	if direction.length_squared() > 0.01: _body.face(direction, delta, 6.0)
	velocity.x = move_toward(velocity.x, direction.x * walk_speed, delta * 4.0)
	velocity.z = move_toward(velocity.z, direction.z * walk_speed, delta * 4.0)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.3
	var before := global_position
	move_and_slide()
	if direction.length_squared() > 0.1 and (global_position - before).length() < delta * 0.2:
		_blocked_time += delta
	else:
		_blocked_time = maxf(0.0, _blocked_time - delta * 0.5)
	if _blocked_time > 5.0:
		route_index = (route_index + 1) % route.size()
		_blocked_time = 0.0
	_animate(Vector2(velocity.x, velocity.z).length())
	# A pedestrian who falls into a damaged quay swims toward their route start;
	# recovery is announced by their next dialogue and does not block a job forever.
	if global_position.y < -3.0:
		global_position = route[0] + Vector3.UP * 0.4
		velocity = Vector3.ZERO
		memories["accidents"] = int(memories.get("accidents", 0)) + 1
		_danger_time = 5.0

## Walking, hurrying away from traffic, greeting or standing still.
func _animate(planar: float) -> void:
	if _greeting_time > 3.0:
		_body.set_state("wave")
	elif planar < 0.15:
		_body.set_state("idle")
	elif planar > 2.4 or _danger_time > 0.0:
		_body.set_state("run", clampf(planar / 3.3, 0.7, 1.4))
	else:
		_body.set_state("walk", clampf(planar / 1.35, 0.7, 1.5))


func get_state() -> Dictionary:
	return {"id": stable_id, "position": [global_position.x, global_position.y, global_position.z],
		"route_index": route_index, "memories": memories.duplicate(true)}

func apply_state(state: Dictionary) -> void:
	var p: Variant = state.get("position", [])
	if p is Array and p.size() == 3:
		global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	route_index = clampi(int(state.get("route_index", 0)), 0, route.size() - 1)
	memories = state.get("memories", memories).duplicate(true)
