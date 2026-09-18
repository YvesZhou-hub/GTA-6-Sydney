extends Node3D
## A small pool of real lights that follows the player at night. The city has
## about two thousand lamp posts; lighting them all would be thousands of
## sources, so eight lights move to the nearest heads and fade with the clock.
const POOL := 10
const REACH := 95.0

var game: Node
var _lights: Array[OmniLight3D] = []
var _night := 0.0
var _clock := 0.0

func setup(host: Node) -> void:
	game = host
	name = "StreetLights"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for i in POOL:
		var light := OmniLight3D.new()
		light.name = "StreetLamp%d" % i
		light.light_color = Color("ffe0a2")
		light.light_energy = 0.0
		light.omni_range = 19.0
		light.omni_attenuation = 1.6
		light.light_specular = 0.2
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_lights.append(light)

func apply_cycle(state: Dictionary) -> void:
	_night = clampf(float(state.get("night_factor", 0.0)), 0.0, 1.0)

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not game.active: return
	_clock += delta
	if _clock < 0.4: return
	_clock = 0.0
	var here: Vector3 = game.current_vehicle.global_position if is_instance_valid(game.current_vehicle) else game.player.global_position
	if _night < 0.08 or game.world.lamp_positions.is_empty():
		for light in _lights: light.visible = false
		return
	var nearest: Array = []
	for head: Vector3 in game.world.lamp_positions:
		var distance := here.distance_to(head)
		if distance > REACH: continue
		nearest.append([distance, head])
	nearest.sort_custom(func(a: Array, b: Array): return float(a[0]) < float(b[0]))
	for i in _lights.size():
		var light := _lights[i]
		if i >= nearest.size():
			light.visible = false
			continue
		light.global_position = nearest[i][1]
		light.light_energy = 3.4 * _night
		light.visible = true

func stats() -> Dictionary:
	var lit := 0
	for light in _lights:
		if light.visible and light.light_energy > 0.0: lit += 1
	return {"pool": _lights.size(), "lit": lit, "night": snappedf(_night, 0.01)}
