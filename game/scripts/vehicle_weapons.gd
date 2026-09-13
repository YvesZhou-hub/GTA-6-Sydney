extends Node3D
## Fictional sandbox fire control. Swept physics rays, not camera-only hitscan.
signal blast_hit(point: Vector3, radius: float, damage: float, owner: RigidBody3D)
const Effects = preload("res://scripts/combat_effects.gd")
const Support = preload("res://scripts/vehicle_support_weapons.gd")
const PROJECTILE_CAPACITY := 32
const MAX_UPGRADE := 3
const PROFILES := {
	"tank":{"speed":440.0, "gravity":9.8, "energy":1.0e9, "damage":90.0, "radius":16.0, "cooldown":1.15, "life":10.0, "effect":1.0},
	"fighter":{"speed":1350.0, "gravity":0.0, "energy":1.2e9, "damage":70.0, "radius":22.0, "cooldown":0.35, "life":7.0, "effect":1.35}
}
const MIN_ELEVATION := deg_to_rad(-12.0)
const MAX_ELEVATION := deg_to_rad(70.0)
const RECOIL_CAPACITY := 16
const RECOIL_DURATION := 0.46
var game: Node
var effects: Node3D
var support: Node3D
var _game_properties: Dictionary = {}
var _projectiles: Array[Dictionary] = []
var _cooldowns: Dictionary = {}
var _clock := 0.0
var _current_aim_id := 0
var _yaw_offset := 0.0
var _pitch_offset := 0.0
var _fired := 0
var _hits := 0
var _expired := 0
var _pool_rejections := 0
var _muzzle_overlap := SphereShape3D.new()
var _recoils: Array[Dictionary] = []

func setup(owner_game: Node) -> void:
	clear()
	game = owner_game
	_game_properties.clear()
	for info: Dictionary in game.get_property_list(): _game_properties[str(info.name)] = true
	if not is_instance_valid(support):
		support = Support.new(); support.name = "VehicleSupportWeapons"; add_child(support)
	support.setup(game)
	_muzzle_overlap.radius = 0.12
	if not is_instance_valid(effects):
		effects = Effects.new()
		effects.name = "CombatEffectsPool"
		add_child(effects)
		effects.prepare()
	if _projectiles.is_empty():
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.10, 0.10, 1.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1, 0.76, 0.35)
		material.emission_enabled = true
		material.emission = Color(1, 0.38, 0.08)
		material.emission_energy_multiplier = 4.0
		for index in PROJECTILE_CAPACITY:
			var view := MeshInstance3D.new()
			view.name = "PooledProjectile_%02d" % index
			view.mesh = mesh
			view.material_override = material
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			view.visible = false
			add_child(view)
			_projectiles.append({"active":false, "view":view, "position":Vector3.ZERO, "velocity":Vector3.ZERO,
				"life":0.0, "profile":{}, "source":null, "exclude":[]})

func _game_flag(key: String, fallback: bool = false) -> bool:
	return bool(game.get(key)) if is_instance_valid(game) and _game_properties.has(key) else fallback

func _simulation_running() -> bool:
	return is_instance_valid(game) and _game_flag("active", true) and not _game_flag("paused")

func _vehicle() -> RigidBody3D:
	if not is_instance_valid(game): return null
	var vehicle = game.get("current_vehicle")
	return vehicle if is_instance_valid(vehicle) and vehicle is RigidBody3D else null

func _eligible(vehicle: RigidBody3D) -> bool:
	if not _simulation_running() or not is_instance_valid(vehicle): return false
	if not PROFILES.has(str(vehicle.get("kind"))) or not bool(vehicle.get("occupied")): return false
	if float(vehicle.get("health")) <= 0: return false
	if game.has_method("can_fire_weapon") and not bool(game.call("can_fire_weapon")): return false
	return true

func _moving(vehicle: RigidBody3D) -> Dictionary:
	var moving = vehicle.get("_moving")
	return moving if moving is Dictionary else {}

func _muzzle(vehicle: RigidBody3D) -> Node3D:
	var moving := _moving(vehicle)
	var key := "muzzle" if str(vehicle.get("kind")) == "tank" else "weapon_muzzle"
	var marker = moving.get(key)
	return marker if is_instance_valid(marker) and marker is Node3D else null

func _exclude_tree(node: Node, result: Array[RID]) -> void:
	if not is_instance_valid(node): return
	if node is CollisionObject3D: result.append(node.get_rid())
	for child: Node in node.get_children(): _exclude_tree(child, result)

func _exclusions(vehicle: RigidBody3D) -> Array[RID]:
	var result: Array[RID] = []
	_exclude_tree(vehicle, result)
	if _game_properties.has("player"):
		var player = game.get("player")
		if is_instance_valid(player) and player is Node: _exclude_tree(player, result)
	return result

func _ray(from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	if from.distance_squared_to(to) < 0.000001: return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, 31, exclude)
	query.hit_from_inside = true
	query.hit_back_faces = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _action_axis(negative: String, positive: String) -> float:
	return Input.get_axis(negative, positive) if InputMap.has_action(negative) and InputMap.has_action(positive) else 0.0

func _turn_toward(value: float, target: float, max_step: float) -> float:
	return wrapf(value + clampf(angle_difference(value, target), -max_step, max_step), -PI, PI)

func _initial_obstruction(vehicle: RigidBody3D, marker: Node3D, exclude: Array[RID]) -> Dictionary:
	var moving := _moving(vehicle)
	var chamber: Node3D = moving.get("barrel", vehicle) if str(vehicle.get("kind")) == "tank" else vehicle
	if not is_instance_valid(chamber): return {"position":marker.global_position}
	var obstruction := _ray(chamber.global_position, marker.global_position - marker.global_basis.z.normalized() * .12, exclude)
	if obstruction.is_empty():
		var overlap := PhysicsShapeQueryParameters3D.new()
		overlap.shape = _muzzle_overlap
		overlap.transform = Transform3D(Basis.IDENTITY, marker.global_position)
		overlap.exclude = exclude
		overlap.collision_mask = 31
		if not get_world_3d().direct_space_state.intersect_shape(overlap, 1).is_empty(): obstruction = {"position":marker.global_position}
	return obstruction

static func profile_for(kind: String, level: int = 0) -> Dictionary:
	if not PROFILES.has(kind): return {}
	var upgrade := clampi(level, 0, MAX_UPGRADE)
	var profile: Dictionary = PROFILES[kind].duplicate()
	profile.level = upgrade
	profile.ammo_cost = 0
	profile.damage *= 1.0 + upgrade * .25
	profile.radius *= 1.0 + upgrade * .20
	profile.cooldown *= 1.0 - upgrade * .10
	# Radius affects real blast damage and world destruction. Presentation uses
	# the same multiplier while retaining the existing fixed particle pools.
	profile.effect *= 1.0 + upgrade * .20
	return profile

static func upgrade_stats(kind: String, level: int = 0) -> Dictionary:
	if not PROFILES.has(kind): return {}
	var upgrade := clampi(level, 0, MAX_UPGRADE)
	return {"level":upgrade, "max_level":MAX_UPGRADE, "ammo_cost":0,
		"at_max":upgrade == MAX_UPGRADE, "base":profile_for(kind),
		"current":profile_for(kind, upgrade),
		"next":profile_for(kind, upgrade + 1) if upgrade < MAX_UPGRADE else {}}

func weapon_profile(vehicle: RigidBody3D) -> Dictionary:
	if not is_instance_valid(vehicle): return {}
	var saved_upgrade: Variant = vehicle.get("weapon_upgrade")
	var upgrade := 0
	if (saved_upgrade is int or saved_upgrade is float) and is_finite(float(saved_upgrade)):
		upgrade = int(clampf(float(saved_upgrade),0.0,float(MAX_UPGRADE)))
	return profile_for(str(vehicle.get("kind")), upgrade)

func aim_point() -> Vector3:
	# A bounded prediction of this muzzle's trajectory, independent of the
	# camera. Main caches this at 10Hz. It is not homing or aim assistance.
	var vehicle := _vehicle()
	if not is_instance_valid(vehicle) or not PROFILES.has(str(vehicle.get("kind"))): return Vector3.ZERO
	var marker := _muzzle(vehicle)
	if not is_instance_valid(marker): return vehicle.global_position
	var profile := weapon_profile(vehicle)
	var exclude := _exclusions(vehicle)
	var from := marker.global_position
	var obstruction := _initial_obstruction(vehicle, marker, exclude)
	if not obstruction.is_empty(): return obstruction.position
	var origin := from
	var velocity := -marker.global_basis.z.normalized() * float(profile.speed) + vehicle.linear_velocity
	var acceleration := Vector3.DOWN * float(profile.gravity)
	for index in 31:
		var elapsed := float(profile.life) * float(index + 1) / 31.0
		var to := origin + velocity * elapsed + acceleration * (.5 * elapsed * elapsed)
		var hit := _ray(from, to, exclude)
		if not hit.is_empty(): return hit.position
		from = to
	return from

func update_aim(delta: float) -> void:
	var vehicle := _vehicle()
	if not _eligible(vehicle) or str(vehicle.get("kind")) != "tank": return
	var moving := _moving(vehicle)
	var turret: Node3D = moving.get("turret")
	var barrel: Node3D = moving.get("barrel")
	if not is_instance_valid(turret) or not is_instance_valid(barrel): return
	var camera: Camera3D = game.get("camera")
	if not is_instance_valid(camera): return
	var direction := -camera.global_basis.z.normalized()
	var target := camera.global_position + direction * 4000.0
	var hit := _ray(camera.global_position, target, _exclusions(vehicle))
	if not hit.is_empty(): target = hit.position
	var local := vehicle.global_basis.inverse() * (target - barrel.global_position).normalized()
	var base_yaw := atan2(-local.x, -local.z)
	var base_pitch := atan2(local.y, Vector2(local.x, local.z).length())
	if _current_aim_id != vehicle.get_instance_id() or bool(vehicle.get_meta("combat_restore_pose", false)):
		_current_aim_id = vehicle.get_instance_id()
		var offsets: Dictionary = vehicle.get_meta("weapon_aim_offsets", {})
		_yaw_offset = float(offsets.get("yaw_offset", 0.0))
		_pitch_offset = float(offsets.get("pitch_offset", 0.0))
		if bool(vehicle.get_meta("combat_restore_pose", false)):
			# The saved camera can be restored after the vehicle. Rebase once on
			# first active control, keeping the loaded physical aim unchanged.
			_yaw_offset = angle_difference(base_yaw, turret.rotation.y)
			_pitch_offset = barrel.rotation.x - base_pitch
			vehicle.remove_meta("combat_restore_pose")
	_yaw_offset = wrapf(_yaw_offset - _action_axis("combat_yaw_left", "combat_yaw_right") * delta * 1.1, -PI, PI)
	_pitch_offset = clampf(_pitch_offset + _action_axis("combat_lower", "combat_raise") * delta * 0.7, -PI, PI)
	vehicle.set_meta("weapon_aim_offsets", {"yaw_offset":_yaw_offset,"pitch_offset":_pitch_offset})
	var wanted_yaw := base_yaw + _yaw_offset
	var elevation := clampf(base_pitch + _pitch_offset, MIN_ELEVATION, MAX_ELEVATION)
	turret.rotation.y = _turn_toward(turret.rotation.y, wanted_yaw, delta * 2.8)
	barrel.rotation.x = move_toward(barrel.rotation.x, elevation, delta * 1.6)

func fire_current() -> bool:
	var vehicle := _vehicle()
	if not _eligible(vehicle): return false
	var marker := _muzzle(vehicle)
	if not is_instance_valid(marker): return false
	var id := vehicle.get_instance_id()
	if _cooldowns.has(id) and _clock < float(_cooldowns[id].until): return false
	var slot: Dictionary = {}
	for candidate: Dictionary in _projectiles:
		if not candidate.active:
			slot = candidate
			break
	if slot.is_empty():
		_pool_rejections += 1
		return false
	var profile := weapon_profile(vehicle)
	var from := marker.global_position
	var direction := -marker.global_basis.z.normalized()
	if not from.is_finite() or not direction.is_finite() or direction.length_squared() < 0.9: return false
	var exclude := _exclusions(vehicle)
	_cooldowns[id] = {"until":_clock + float(profile.cooldown), "source":weakref(vehicle)}
	slot.active = true
	slot.position = from
	slot.velocity = direction * float(profile.speed) + vehicle.linear_velocity
	# Snapshot at launch: upgrades purchased in flight affect the next shell,
	# never enlarge an already airborne shell or shorten its active reload.
	slot.profile = profile
	slot.life = float(profile.life)
	slot.source = weakref(vehicle)
	slot.exclude = exclude
	slot.view.visible = true
	_fired += 1
	# Presentation starts only after a shot is accepted. The logical chamber,
	# muzzle and saved aim never recoil; only this vehicle's mesh nodes move.
	effects.emit_muzzle(from, direction, str(vehicle.get("kind")))
	if str(vehicle.get("kind")) == "tank": _begin_recoil(vehicle)
	# Check the gun chamber-to-muzzle path as well: a long barrel penetrating a
	# thin wall cannot teleport the shot to the far side of that wall.
	var obstruction := _initial_obstruction(vehicle, marker, exclude)
	if not obstruction.is_empty(): _impact(slot, obstruction.position, obstruction.get("normal", Vector3.UP))
	else: _show_projectile(slot, 0.01)
	return true

func _show_projectile(slot: Dictionary, delta: float) -> void:
	var speed: float = slot.velocity.length()
	var direction: Vector3 = slot.velocity / maxf(speed, 0.001)
	var view: MeshInstance3D = slot.view
	var up := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
	view.global_transform = Transform3D(Basis.looking_at(direction, up).scaled_local(Vector3(1, 1, clampf(speed * delta * 0.5, 0.6, 12))), slot.position)

func _impact(slot: Dictionary, point: Vector3, normal: Vector3 = Vector3.UP) -> void:
	if not slot.active: return
	slot.active = false
	slot.view.visible = false
	_hits += 1
	var source = slot.source.get_ref() if slot.source is WeakRef else null
	if is_instance_valid(game) and game.has_method("apply_combat_blast"):
		game.call("apply_combat_blast", point, float(slot.profile.energy), float(slot.profile.radius), source)
	blast_hit.emit(point,float(slot.profile.radius),float(slot.profile.damage),source)
	impact_effect(point, float(slot.profile.effect), normal)

func impact_effect(point: Vector3, size: float = 1.0, normal: Vector3 = Vector3.UP) -> void:
	if is_instance_valid(effects): effects.emit_blast(point, size, normal)

func _restore_recoil(record: Dictionary) -> void:
	for item: Dictionary in record.meshes:
		var mesh = item.ref.get_ref()
		if is_instance_valid(mesh) and not mesh.is_queued_for_deletion(): mesh.position = item.origin

func _begin_recoil(vehicle: RigidBody3D) -> void:
	var barrel: Node3D = _moving(vehicle).get("barrel")
	if not is_instance_valid(barrel): return
	for index in range(_recoils.size()-1, -1, -1):
		if _recoils[index].id == vehicle.get_instance_id():
			_restore_recoil(_recoils[index]); _recoils.remove_at(index)
	if _recoils.size() >= RECOIL_CAPACITY: _restore_recoil(_recoils.pop_front())
	var meshes: Array[Dictionary] = []
	for node: Node in barrel.get_children():
		if node is MeshInstance3D and not node.is_queued_for_deletion():
			meshes.append({"ref":weakref(node),"origin":node.position})
	if not meshes.is_empty(): _recoils.append({"id":vehicle.get_instance_id(),"age":0.0,"meshes":meshes})

func _tick_recoil(delta: float) -> void:
	for index in range(_recoils.size()-1, -1, -1):
		var record: Dictionary = _recoils[index]
		record.age += delta
		if record.age >= RECOIL_DURATION:
			_restore_recoil(record); _recoils.remove_at(index); continue
		var attack := minf(1.0, record.age / .028)
		var recovery := 1.0 - smoothstep(.065, RECOIL_DURATION, record.age)
		for item: Dictionary in record.meshes:
			var mesh = item.ref.get_ref()
			if is_instance_valid(mesh) and not mesh.is_queued_for_deletion():
				mesh.position = item.origin + Vector3.BACK * (.30 * attack * recovery)

func _physics_process(delta: float) -> void:
	if not _simulation_running(): return
	if is_instance_valid(support): support.tick(delta)
	_clock += delta
	update_aim(delta)
	_tick_recoil(delta)
	for slot: Dictionary in _projectiles:
		if not slot.active: continue
		var dt := minf(delta, slot.life)
		var from: Vector3 = slot.position
		var acceleration := Vector3.DOWN * float(slot.profile.gravity)
		var to: Vector3 = from + slot.velocity * dt + acceleration * (0.5 * dt * dt)
		var exclude: Array[RID] = []
		for rid: RID in slot.exclude: exclude.append(rid)
		var hit := _ray(from, to, exclude)
		if not hit.is_empty():
			_impact(slot, hit.position, hit.get("normal", Vector3.UP))
			continue
		slot.position = to
		slot.velocity += acceleration * dt
		slot.life -= dt
		if slot.life <= 0.0 or not to.is_finite():
			slot.active = false
			slot.view.visible = false
			_expired += 1
		else: _show_projectile(slot, delta)
	if is_instance_valid(effects): effects.tick(delta)
	for id in _cooldowns.keys():
		if _cooldowns[id].source.get_ref() == null: _cooldowns.erase(id)

func clear() -> void:
	if is_instance_valid(support): support.clear()
	for record: Dictionary in _recoils: _restore_recoil(record)
	_recoils.clear()
	for slot: Dictionary in _projectiles:
		slot.active = false
		if is_instance_valid(slot.view): slot.view.visible = false
		# Do not retain a RID/reference belonging to a freed or replaced world.
		slot.exclude = []
		slot.source = null
	_cooldowns.clear()
	_current_aim_id = 0
	_yaw_offset = 0.0
	_pitch_offset = 0.0
	if is_instance_valid(effects): effects.clear()

func set_auto_enabled(value: bool) -> void:
	if is_instance_valid(support): support.set_enabled(value)

func auto_enabled() -> bool:
	return bool(support.enabled) if is_instance_valid(support) else true

func auto_status() -> Dictionary:
	return support.status() if is_instance_valid(support) else {"enabled":true, "available":false, "locked":false, "state":"待命", "ammo_cost":0}

func aim_status() -> Dictionary:
	var vehicle := _vehicle()
	if not is_instance_valid(vehicle) or not PROFILES.has(str(vehicle.get("kind"))): return {}
	var id := vehicle.get_instance_id()
	var remaining := maxf(0, float(_cooldowns[id].until) - _clock) if _cooldowns.has(id) else 0.0
	var moving := _moving(vehicle)
	var barrel: Node3D = moving.get("barrel")
	var turret: Node3D = moving.get("turret")
	var profile := weapon_profile(vehicle)
	return {"kind":str(vehicle.get("kind")), "ready":_eligible(vehicle) and remaining <= 0,
		"cooldown_remaining":remaining,
		"weapon_level":int(profile.level), "blast_radius":float(profile.radius),
		"damage":float(profile.damage), "reload_seconds":float(profile.cooldown), "ammo_cost":0,
		"yaw_deg":rad_to_deg(turret.rotation.y) if is_instance_valid(turret) else 0.0,
		"elevation_deg":rad_to_deg(barrel.rotation.x) if is_instance_valid(barrel) else 0.0}

func stats() -> Dictionary:
	var active := 0
	for slot: Dictionary in _projectiles:
		if slot.active: active += 1
	return {"projectile_capacity":PROJECTILE_CAPACITY, "projectiles_allocated":_projectiles.size(),
		"active_projectiles":active, "fired":_fired, "hits":_hits, "expired":_expired,
		"active_recoils":_recoils.size(), "recoil_capacity":RECOIL_CAPACITY,
		"pool_rejections":_pool_rejections, "effects":effects.stats() if is_instance_valid(effects) else {}}
