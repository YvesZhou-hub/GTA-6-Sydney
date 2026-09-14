extends Node3D
## One reusable current-vehicle mount and eight swept, finite-speed support bolts.
## The heavy tank cannon and fighter rockets remain separate manual weapons.
const CAPACITY := 8
const HIT_CAPACITY := 8
const Modules = preload("res://scripts/weapon_modules.gd")
const KINDS := ["car", "motorcycle", "hoverboard", "speedboat", "yacht", "helicopter", "glider", "paraglider", "airliner", "tank", "fighter"]
const AIR_KINDS := ["helicopter", "glider", "paraglider", "airliner", "fighter"]
const MOUNTS := {
	"car":Vector3(0, .53, -.15), "motorcycle":Vector3(0, .52, -.65),
	"hoverboard":Vector3(0, .24, -.75), "speedboat":Vector3(0, .83, -3.2),
	"yacht":Vector3(0, 7.01, -.8), "helicopter":Vector3(.7, -.98, -3.5),
	"glider":Vector3(0, -.70, -1.6), "paraglider":Vector3(.4, -.3, -.45),
	"airliner":Vector3(0, -3.18, -20.0), "tank":Vector3(1.1, 1.93, -.4),
	"fighter":Vector3(0, -.76, -3.8)
}
var enabled := true
var game: Node3D
var _properties: Dictionary = {}
var _mount: Node3D
var _head: Node3D
var _muzzle: Marker3D
var _vehicle_ref: WeakRef
var _target_ref: WeakRef
var _shots: Array[Dictionary] = []
var _hits: Array[Dictionary] = []
var _reload := 0.0
var _scan := 0.0
var _fired := 0
var _landed := 0
var _blocked := 0
var _expired := 0
var _active_time := 0.0
var modules: Node3D

static func profile_for(kind: String, upgrade: int = 0) -> Dictionary:
	if not KINDS.has(kind): return {}
	var heavy := kind in ["tank", "fighter"]
	var airborne := AIR_KINDS.has(kind)
	var level := clampi(upgrade, 0, 3) if heavy else 0
	return {"damage":(12.0 if heavy else 16.0) * (1.0 + level * .10),
		"cooldown":(.65 if heavy else .60) * (1.0 - level * .05),
		"range":220.0 if airborne else 75.0, "speed":260.0 if airborne else 110.0,
		"life":3.0, "ammo_cost":0, "level":level}

func setup(host: Node3D) -> void:
	game = host
	_properties.clear()
	for info: Dictionary in game.get_property_list(): _properties[str(info.name)] = true
	_prepare()
	if not is_instance_valid(modules):
		modules = Modules.new(); modules.name = "OptionalWeaponModules"; add_child(modules)
	modules.setup(self)
	clear()

func _material(color: Color, emission := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color; result.metallic = .45; result.roughness = .28
	if emission:
		result.emission_enabled = true; result.emission = color; result.emission_energy_multiplier = 2.3
	return result

func _part(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var view := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size
	view.mesh = mesh; view.material_override = material; view.position = at
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
	return view

func _prepare() -> void:
	if is_instance_valid(_mount): return
	var dark := _material(Color("203744"))
	var metal := _material(Color("759799"))
	var glow := _material(Color("63e8ec"), true)
	_mount = Node3D.new(); _mount.name = "CurrentVehicleSupportMount"; add_child(_mount)
	_part(_mount, Vector3.ZERO, Vector3(.52, .14, .56), dark)
	_head = Node3D.new(); _head.position.y = .17; _mount.add_child(_head)
	_part(_head, Vector3.ZERO, Vector3(.36, .26, .38), metal)
	_part(_head, Vector3(-.13, 0, -.30), Vector3(.09, .11, .42), dark)
	_part(_head, Vector3(.13, 0, -.30), Vector3(.09, .11, .42), dark)
	_part(_head, Vector3(0, .11, -.15), Vector3(.15, .04, .19), glow)
	_muzzle = Marker3D.new(); _muzzle.position.z = -.55; _head.add_child(_muzzle)
	var bolt_mesh := SphereMesh.new(); bolt_mesh.radius = .085; bolt_mesh.height = .17
	bolt_mesh.radial_segments = 8; bolt_mesh.rings = 4
	for index in CAPACITY:
		var view := MeshInstance3D.new(); view.name = "PooledSupportBolt_%02d" % index
		view.mesh = bolt_mesh; view.material_override = glow; view.visible = false
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(view)
		_shots.append({"active":false, "view":view, "point":Vector3.ZERO, "direction":Vector3.FORWARD,
			"profile":{}, "target":null, "source":null, "life":0.0, "exclude":[]})
	for index in HIT_CAPACITY:
		var view := MeshInstance3D.new(); view.name = "PooledSupportHit_%02d" % index
		view.mesh = bolt_mesh; view.material_override = glow; view.visible = false
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(view)
		_hits.append({"view":view, "left":0.0})

func _game_flag(name: String, fallback := false) -> bool:
	return bool(game.get(name)) if is_instance_valid(game) and _properties.has(name) else fallback

func _director() -> Node3D:
	if not is_instance_valid(game) or not _properties.has("survival"): return null
	var value = game.get("survival")
	return value if is_instance_valid(value) and value is Node3D else null

func _current_vehicle() -> RigidBody3D:
	if not is_instance_valid(game) or not _properties.has("current_vehicle"): return null
	var value = game.get("current_vehicle")
	return value if is_instance_valid(value) and value is RigidBody3D else null

func _valid_enemy(value) -> bool:
	return is_instance_valid(value) and not value.is_queued_for_deletion() and value is CollisionObject3D and value.is_in_group("nailong_enemies") and float(value.get("health")) > 0.0 and not bool(value.get("dead"))

func _target() -> Node3D:
	var value = _target_ref.get_ref() if _target_ref is WeakRef else null
	return value if _valid_enemy(value) else null

func _allowed(vehicle: RigidBody3D) -> bool:
	var director := _director()
	if not enabled or not is_instance_valid(director) or not bool(director.get("enabled")): return false
	if not is_instance_valid(vehicle) or vehicle.is_queued_for_deletion() or not KINDS.has(str(vehicle.get("kind"))): return false
	if not bool(vehicle.get("occupied")) or float(vehicle.get("health")) <= 0.0: return false
	if not _game_flag("active", true) or _game_flag("paused"): return false
	if game.has_method("can_auto_fire_weapon"): return bool(game.call("can_auto_fire_weapon"))
	# Older fixtures do not expose modal gates; production always does.
	for key in ["modal", "map_panel"]:
		if _properties.has(key):
			var control = game.get(key)
			if is_instance_valid(control) and bool(control.get("visible")): return false
	return true

func _profile(vehicle: RigidBody3D) -> Dictionary:
	var saved: Variant = vehicle.get("weapon_upgrade")
	var upgrade := int(clampf(float(saved), 0.0, 3.0)) if (saved is int or saved is float) and is_finite(float(saved)) else 0
	return profile_for(str(vehicle.get("kind")), upgrade)

func _collect_exclusions(node: Node, output: Array[RID]) -> void:
	if node is CollisionObject3D: output.append(node.get_rid())
	for child: Node in node.get_children(): _collect_exclusions(child, output)

func _exclusions(vehicle: RigidBody3D) -> Array[RID]:
	var output: Array[RID] = []
	_collect_exclusions(vehicle, output)
	if _properties.has("player"):
		var player = game.get("player")
		if is_instance_valid(player): _collect_exclusions(player, output)
	return output

func _ray(from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	if from.distance_squared_to(to) < .000001: return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, 31, exclude)
	query.hit_from_inside = true; query.hit_back_faces = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _aim_point(enemy: Node3D) -> Vector3:
	return enemy.global_position + Vector3.UP * (1.2 * float(enemy.get_meta("enemy_body_scale", enemy.get_meta("support_body_scale", 1.0))))

func _can_reach(enemy: Node3D, vehicle: RigidBody3D, profile: Dictionary, exclude: Array[RID]) -> bool:
	if not _valid_enemy(enemy): return false
	var aim := _aim_point(enemy)
	var difference := aim - _muzzle.global_position
	if difference.length() > float(profile.range): return false
	# A traversing turret covers a wide forward arc and close flank attackers.
	if difference.length() > 14.0 and difference.normalized().dot(-vehicle.global_basis.z.normalized()) < -.65: return false
	# A mount outside the hull must not tunnel through an intervening wall.
	var chamber := _ray(_mount.global_position, _muzzle.global_position, exclude)
	if not chamber.is_empty(): return false
	var hit := _ray(_muzzle.global_position, aim, exclude)
	return hit.is_empty() or hit.get("collider") == enemy

func _acquire(vehicle: RigidBody3D, profile: Dictionary) -> void:
	var director := _director()
	if not is_instance_valid(director): _target_ref = null; return
	var values = director.get("enemies")
	if not values is Array: _target_ref = null; return
	var exclude := _exclusions(vehicle)
	var nearest: Node3D
	var distance := INF
	for candidate in values:
		if not _valid_enemy(candidate): continue
		var squared := _muzzle.global_position.distance_squared_to(_aim_point(candidate))
		if squared >= distance or not _can_reach(candidate, vehicle, profile, exclude): continue
		nearest = candidate; distance = squared
	_target_ref = weakref(nearest) if nearest != null else null

func set_enabled(value: bool) -> void:
	enabled = value
	if not value: clear()

func _update_mount(vehicle: RigidBody3D, delta: float) -> void:
	_mount.visible = true
	_mount.global_transform = vehicle.global_transform * Transform3D(Basis.IDENTITY, MOUNTS[str(vehicle.get("kind"))])
	var enemy := _target()
	if enemy != null:
		var direction := _aim_point(enemy) - _head.global_position
		if direction.length_squared() > .01:
			var up := Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > .98 else Vector3.UP
			_head.global_basis = _head.global_basis.slerp(Basis.looking_at(direction, up), minf(1.0, delta * 12.0)).orthonormalized()

func _fire(vehicle: RigidBody3D, profile: Dictionary) -> bool:
	var enemy := _target()
	if enemy == null or _reload > 0.0: return false
	var exclude := _exclusions(vehicle)
	if not _can_reach(enemy, vehicle, profile, exclude): _target_ref = null; return false
	var direction := (_aim_point(enemy) - _muzzle.global_position).normalized()
	if direction.dot(-_head.global_basis.z) < .88: return false
	for shot: Dictionary in _shots:
		if shot.active: continue
		shot.active = true; shot.point = _muzzle.global_position; shot.direction = direction
		shot.profile = profile.duplicate(); shot.life = float(profile.life)
		shot.target = weakref(enemy); shot.source = weakref(vehicle); shot.exclude = exclude
		shot.view.visible = true; shot.view.global_position = shot.point
		_reload = float(profile.cooldown); _fired += 1
		return true
	return false

func _end_shot(shot: Dictionary) -> void:
	shot.active = false; shot.view.visible = false; shot.target = null; shot.source = null; shot.exclude = []

func _spark(at: Vector3) -> void:
	var selected: Dictionary = _hits[0]
	for hit: Dictionary in _hits:
		if hit.left <= 0.0: selected = hit; break
	selected.left = .18; selected.view.visible = true; selected.view.global_position = at
	selected.view.scale = Vector3.ONE * 3.0

func _tick_shots(delta: float) -> void:
	for shot: Dictionary in _shots:
		if not shot.active: continue
		var enemy = shot.target.get_ref() if shot.target is WeakRef else null
		var source = shot.source.get_ref() if shot.source is WeakRef else null
		if not _valid_enemy(enemy) or not is_instance_valid(source) or source.is_queued_for_deletion() or float(source.get("health")) <= 0.0:
			_end_shot(shot); continue
		var dt := minf(delta, float(shot.life))
		var difference: Vector3 = _aim_point(enemy) - shot.point
		if difference.length_squared() > .001:
			shot.direction = shot.direction.slerp(difference.normalized(), minf(1.0, dt * 9.0)).normalized()
		var from: Vector3 = shot.point
		var to: Vector3 = from + shot.direction * float(shot.profile.speed) * dt
		var exclude: Array[RID] = []
		for rid: RID in shot.exclude: exclude.append(rid)
		var impact := _ray(from, to, exclude)
		if not impact.is_empty():
			var collider = impact.get("collider")
			# An enemy body must be the first physical hit. No proximity damage
			# shortcut can carry a pulse through a wall or across another vehicle.
			if _valid_enemy(collider):
				collider.set_meta("damage_style", "support")
				if float(collider.call("take_damage", float(shot.profile.damage), impact.position)) > 0.0: _landed += 1
			else: _blocked += 1
			_spark(impact.position); _end_shot(shot); continue
		shot.point = to; shot.life -= dt
		if shot.life <= 0.0 or not to.is_finite(): _expired += 1; _end_shot(shot); continue
		shot.view.global_position = to
		var up := Vector3.RIGHT if absf(shot.direction.y) > .98 else Vector3.UP
		shot.view.global_basis = Basis.looking_at(shot.direction, up).scaled_local(Vector3(1.0, 1.0, 5.0))
	for hit: Dictionary in _hits:
		if hit.left <= 0.0: continue
		hit.left = maxf(0.0, hit.left - delta); hit.view.visible = hit.left > 0.0
		hit.view.scale = Vector3.ONE * maxf(.01, hit.left / .18 * 3.0)

func tick(delta: float) -> void:
	if not is_instance_valid(game) or not _game_flag("active", true) or _game_flag("paused"): return
	var vehicle := _current_vehicle()
	if not _allowed(vehicle): clear(); return
	var previous = _vehicle_ref.get_ref() if _vehicle_ref is WeakRef else null
	if previous != vehicle:
		clear(); _vehicle_ref = weakref(vehicle); _reload = .25
	var dt := clampf(delta, 0.0, .1)
	_active_time += dt
	_reload = maxf(0.0, _reload - dt); _scan -= dt
	_update_mount(vehicle, dt)
	var profile := _profile(vehicle)
	if _scan <= 0.0:
		_acquire(vehicle, profile); _scan = .18
	_update_mount(vehicle, dt)
	_tick_shots(dt)
	_fire(vehicle, profile)
	if is_instance_valid(modules): modules.tick(vehicle, dt)

func clear() -> void:
	if is_instance_valid(modules): modules.clear()
	_target_ref = null; _vehicle_ref = null; _reload = 0.0; _scan = 0.0
	if is_instance_valid(_mount): _mount.visible = false
	for shot: Dictionary in _shots: _end_shot(shot)
	for hit: Dictionary in _hits: hit.left = 0.0; hit.view.visible = false

func status() -> Dictionary:
	var vehicle := _current_vehicle()
	var enemy := _target()
	var available := _allowed(vehicle)
	var profile := _profile(vehicle) if is_instance_valid(vehicle) and KINDS.has(str(vehicle.get("kind"))) else {}
	var active := 0
	for shot: Dictionary in _shots:
		if shot.active: active += 1
	return {"enabled":enabled, "available":available, "locked":enemy != null and available,
		"state":"关闭" if not enabled else ("锁定" if enemy != null and available else ("搜索目标" if available else "待命")),
		"target_id":enemy.get_instance_id() if enemy != null else 0,
		"target_distance":_muzzle.global_position.distance_to(_aim_point(enemy)) if enemy != null else 0.0,
		"reload_remaining":_reload, "profile":profile, "ammo_cost":0,
		"projectile_capacity":CAPACITY, "active_projectiles":active,
		"projectiles_allocated":_shots.size(), "mount_count":1 if is_instance_valid(_mount) else 0,
		"fired":_fired, "hits":_landed, "blocked":_blocked, "expired":_expired, "simulation_seconds":_active_time,
		"modules":modules.status() if is_instance_valid(modules) else {}}
