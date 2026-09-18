extends Node
## What a fight feels like: the camera kicks when you shoot and shakes when you
## are hit, arcs point at whoever hit you, and the screen edges redden when you
## are nearly down. Numbers stay in harbor_survival; this is only feedback.

const HIT_SECONDS := 1.6
const VIGNETTE_AT := 0.45

var game: Node
var overlay: Control
var trauma := 0.0
var recoil := 0.0
var _hits: Array = []
var _rng := RandomNumberGenerator.new()
var _offset := Vector3.ZERO
var _last_health := 0.0


func setup(host: Node) -> void:
	game = host
	name = "CombatFeel"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.seed = 91117
	overlay = preload("res://scripts/combat_overlay.gd").new()
	overlay.name = "CombatOverlay"
	overlay.feel = self
	game.hud.add_child(overlay)
	if is_instance_valid(game.player):
		_last_health = game.player.health
		game.player.health_changed.connect(_on_player_health)


## Trauma adds up and decays; two hits in a row shake harder than one.
func shake(strength: float) -> void:
	trauma = clampf(trauma + strength, 0.0, 1.0)


## A shot pushes the view up a little and settles back.
func kick(strength: float) -> void:
	recoil = clampf(recoil + strength, 0.0, 0.12)
	shake(strength * 0.9)


## Records where a hit came from, for the arc around the crosshair.
func hit_from(origin: Vector3) -> void:
	if not origin.is_finite() or not is_instance_valid(game.player): return
	var offset: Vector3 = origin - game.player.global_position
	offset.y = 0.0
	if offset.length_squared() < 0.01: return
	_hits.append({"heading": atan2(offset.x, offset.z), "time": HIT_SECONDS})
	if _hits.size() > 6: _hits.pop_front()


## Healing and respawning also change health; only losing it is a hit.
func _on_player_health(current: float, maximum: float) -> void:
	var lost := _last_health - current
	_last_health = current
	if not is_instance_valid(game.player) or lost <= 0.0: return
	if current <= 0.0:
		shake(0.75)
		return
	shake(clampf(0.18 + lost / maxf(1.0, maximum) * 1.4, 0.0, 0.6))
	hit_from(game.player.last_damage_origin)


func health_ratio() -> float:
	if not is_instance_valid(game.player) or game.player.max_health <= 0.0: return 1.0
	return clampf(game.player.health / game.player.max_health, 0.0, 1.0)


func hits() -> Array:
	return _hits


func _process(delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * 1.7)
	recoil = maxf(0.0, recoil - delta * 0.55)
	var changed := false
	for hit: Dictionary in _hits.duplicate():
		hit.time -= delta
		if hit.time <= 0.0:
			_hits.erase(hit)
			changed = true
	if is_instance_valid(overlay) and (changed or trauma > 0.0 or not _hits.is_empty() or health_ratio() < VIGNETTE_AT):
		overlay.queue_redraw()


## Called after the follow camera has been placed, so the shake is an offset and
## never fights the camera's own smoothing.
func apply_camera(camera: Camera3D, delta: float) -> void:
	if not is_instance_valid(camera): return
	var target := Vector3.ZERO
	if trauma > 0.0:
		var power := trauma * trauma
		var time := float(Time.get_ticks_msec()) * 0.001
		target = Vector3(sin(time * 37.0) * 0.5 + _rng.randfn(0.0, 0.25), cos(time * 31.0) * 0.5 + _rng.randfn(0.0, 0.25), 0.0) * power * 0.42
	_offset = _offset.lerp(target, clampf(delta * 22.0, 0.0, 1.0))
	camera.global_position += camera.global_basis * _offset
	if recoil > 0.0: camera.rotate_object_local(Vector3.RIGHT, recoil * 0.35)
