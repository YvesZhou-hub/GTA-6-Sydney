extends Node3D
## Street encounters use the existing city's physical surfaces. No replacement map.
const Enemy = preload("res://scripts/nailong_enemy.gd")
const Spawn = preload("res://scripts/encounter_spawn.gd")
const Armory = preload("res://scripts/vehicle_armory.gd")
const Progression = preload("res://scripts/combat_progression.gd")
const ENEMY_LIMIT := 24
const MEDKIT_LIMIT := 5
const REPAIR_RATE := 30
const UPGRADE_COSTS := [8000, 16000, 28000]
var game: Node3D
var enabled := true
var auto_spawn := true
var enemies: Array = []
var kills := 0
var cleared := 0
var wave_spawned := 0
var wave_kills := 0
var medkits := 3
var heal_cooldown := 0.0
var grace := 12.0
var rest := 0.0
var fleet_health: Dictionary = {}
var fleet_upgrades: Dictionary = {}
var armory := Armory.new()
var _adaptive_level := 1
var _difficulty_clock := 0.0
var _air_context := false
var _last_blast: Dictionary = {}
var _spawn_clock := 1.0
var _spawn_sequence := 0
var _spawn_failures := 0
var _spawn_reason := "奶龙正在集结"
var _spawn_diagnostics: Dictionary = {}
var _recycle_clock := 0.0
var _incoming_budget := 18.0
var field_repair_cooldown := 0.0
var _fleet_clock := 0.0
var _hurt_clock := 0.0
var _hurt_flash := 0.0
var _hit_flash := 0.0
var _hurt_direction := ""
var _shot_cooldown := 0.0
var trigger_released := true
var _ram_clock := 0.0
var _rescue_pending := false
var _hazards: Array = []
var _beams: Array = []
var _gun: Node3D
var _reward_text := ""
var _reward_clock := 0.0
var _last_ram_vehicle: RigidBody3D
var _last_ram_position := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

func setup(host: Node3D) -> void:
	game = host
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	game.player.defeated.connect(_request_rescue)
	game.player.landed.connect(_landed)
	game.weapons.blast_hit.connect(damage_blast)
	_build_blaster()

func reset_mode(with_encounters: bool) -> void:
	clear_enemies()
	enabled = with_encounters
	kills = 0; cleared = 0; wave_spawned = 0; wave_kills = 0
	medkits = 3; heal_cooldown = 0.0; grace = 12.0; rest = 0.0
	_spawn_clock = 1.0; _spawn_sequence = 0; _spawn_failures = 0
	_spawn_reason = "奶龙正在集结"; _spawn_diagnostics.clear()
	_incoming_budget = 18.0; field_repair_cooldown = 0.0; _recycle_clock = 0.0
	_hurt_clock = 0.0; _hurt_flash = 0.0; _rescue_pending = false
	_reward_clock = 0.0; _shot_cooldown = 0.0; _last_ram_vehicle = null
	fleet_health.clear(); fleet_upgrades.clear()
	armory.clear()
	_adaptive_level = 1; _difficulty_clock = 0.0; _air_context = false
	_last_blast.clear()
	game.player.reset_health()

func clear_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)
			enemy.queue_free()
	enemies.clear()
	if is_instance_valid(game) and game.has_method("reset_combat_feedback"): game.reset_combat_feedback()
	for hazard in _hazards:
		if is_instance_valid(hazard.view): hazard.view.queue_free()
		if is_instance_valid(hazard.orb): hazard.orb.queue_free()
	_hazards.clear()

func _running() -> bool:
	return is_instance_valid(game) and game.active and not game.paused

func subject() -> Node3D:
	return game.current_vehicle if is_instance_valid(game.current_vehicle) else game.player

func quota() -> int:
	return mini(18, 8 + cleared * 2)

func desired_enemies() -> int:
	var vehicle := is_instance_valid(game.current_vehicle)
	var target := subject()
	var health_ratio: float = target.health / (100.0 if vehicle else target.max_health)
	if health_ratio <= 0.30: return 2
	if _air_context: return Progression.allowed_air_count(encounter_level(), false, true)
	return mini(12 if vehicle else 10, (6 if vehicle else 4) + mini(cleared, 5) + (1 if night_factor() > 0.5 else 0))

func nearby_enemies() -> int:
	var count := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): continue
		var distance: float = enemy.distance_to_target_surface(subject())
		if distance <= 48.0 and _counts_toward_local_budget(enemy, distance): count += 1
	return count

func _counts_toward_local_budget(enemy: Node3D, distance: float) -> bool:
	# Melee actors below a hovering craft cannot fill its aerial encounter budget.
	# Keep nearby ranged attackers relevant when they can still reach the hull.
	return not _air_context or enemy.is_flying() or distance <= float(enemy.spec.range) + .15

func encounter_level() -> int:
	return clampi(maxi(1 + int(cleared / 2.0), _adaptive_level), 1, Progression.MAX_LEVEL)

func weapon_loadout(kind: String) -> Array[Dictionary]:
	return armory.loadout(kind)

func target_encounter_level() -> int:
	var vehicle = game.current_vehicle
	return Progression.target_level(cleared, vehicle.weapon_upgrade if is_instance_valid(vehicle) else 0, weapon_loadout(vehicle.kind) if is_instance_valid(vehicle) else [], is_instance_valid(vehicle))

func _tick_difficulty(delta: float) -> void:
	var goal := target_encounter_level()
	if _adaptive_level > goal: _adaptive_level = goal; _difficulty_clock = 0.0
	var target := subject()
	var healthy: bool = target.health / (100.0 if target is RigidBody3D else target.max_health) > .30
	if goal <= _adaptive_level or not healthy or grace > 0.0:
		_difficulty_clock = 0.0
		return
	_difficulty_clock += delta
	if _difficulty_clock >= Progression.RAMP_SECONDS:
		_adaptive_level += 1
		_difficulty_clock = 0.0

func night_factor() -> float:
	return float(game.city_clock.solar_state().get("night_factor", 0.0)) if is_instance_valid(game.city_clock) else 0.0

func _physics_process(delta: float) -> void:
	if not _running(): return
	grace = maxf(0.0, grace - delta)
	_tick_difficulty(delta)
	rest = 0.0 # Clearance rewards never suspend the next encounter.
	_incoming_budget = minf(18.0, _incoming_budget + delta * 4.0)
	field_repair_cooldown = maxf(0.0, field_repair_cooldown - delta)
	heal_cooldown = maxf(0.0, heal_cooldown - delta)
	_hurt_clock = maxf(0.0, _hurt_clock - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 2.0)
	_hit_flash = maxf(0.0, _hit_flash - delta * 4.0)
	_reward_clock = maxf(0.0, _reward_clock - delta)
	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	_gun.visible = enabled and not is_instance_valid(game.current_vehicle)
	_tick_beams(delta)
	_tick_hazards(delta)
	_fleet_clock -= delta
	if _fleet_clock <= 0.0:
		_fleet_clock = 0.15
		sync_fleet()
		_retarget()
		_air_context = Spawn.target_ground(game).is_empty()
	if not enabled: return
	if not Input.is_action_pressed("fire"): trigger_released = true
	if trigger_released and Input.is_action_pressed("fire") and not is_instance_valid(game.current_vehicle):
		if game.camera_accepts_mouse() or Input.is_physical_key_pressed(KEY_X): fire_blaster()
	_ram_clock -= delta
	if _ram_clock <= 0.0:
		_ram_clock = 0.15
		_ram_enemies()
	if not auto_spawn: return
	_recycle_clock -= delta
	if _recycle_clock <= 0.0:
		_recycle_clock = 1.0
		_recycle_unreachable()
	_spawn_clock -= delta
	if _spawn_clock <= 0.0:
		var nearby := nearby_enemies()
		_spawn_clock = 1.2 if nearby < 2 or grace > 0.0 else lerpf(2.8, 2.1, night_factor())
		# Spawn pressure follows the player. Kill milestones only award bonuses;
		# survivors in another street never lock the next district's reinforcement.
		if enemies.size() < ENEMY_LIMIT and nearby < desired_enemies():
			var kind := _next_type()
			var point := find_spawn_position(kind)
			if point.is_finite():
				spawn_enemy(kind, point, -1.0, encounter_level())
				wave_spawned += 1
			else: _spawn_clock = 0.8

func _next_type() -> String:
	var airborne_count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_flying(): airborne_count += 1
	var health_ratio: float = subject().health / (100.0 if subject() is RigidBody3D else subject().max_health)
	var air_limit := Progression.allowed_air_count(encounter_level(), health_ratio <= .30, _air_context)
	if _air_context or (airborne_count < air_limit and _spawn_sequence % 6 == 4):
		var air_variant := _spawn_sequence % 2 if _air_context else int(_spawn_sequence / 6) % 2
		return "stormwing" if encounter_level() >= 4 and air_variant == 1 else "winglet"
	if cleared >= 2 and _spawn_sequence % 10 == 9:
		if not enemies.any(func(enemy): return is_instance_valid(enemy) and enemy.enemy_type == "alpha"):
			return "alpha"
	var sequence := ["roamer", "roamer", "runner", "spitter", "brute", "runner"]
	return sequence[_spawn_sequence % sequence.size()]

func find_spawn_position(kind: String = "roamer") -> Vector3:
	var started := Time.get_ticks_usec()
	_spawn_diagnostics = Spawn.find(game, kind, _spawn_sequence, _spawn_failures)
	_spawn_diagnostics["elapsed_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	_spawn_sequence += 1
	_spawn_reason = _spawn_diagnostics.reason
	var point: Vector3 = _spawn_diagnostics.position
	_spawn_failures = 0 if point.is_finite() else _spawn_failures + 1
	return point

func spawn_enemy(kind: String, at: Vector3, hp: float = -1.0, level: int = 1):
	if enemies.size() >= ENEMY_LIMIT or not at.is_finite(): return null
	var enemy = Enemy.new()
	enemy.configure(kind, level)
	add_child(enemy)
	enemy.global_position = at
	enemy.reset_physics_interpolation()
	enemy.set_target(subject())
	enemy.set_meta("encounter_age", 0.0)
	enemy.defeated.connect(_enemy_defeated)
	enemy.attack_requested.connect(_enemy_attack)
	if hp >= 0.0: enemy.health = clampf(hp, 1.0, enemy.max_health)
	enemies.append(enemy)
	if game.has_method("register_combat_enemy"): game.register_combat_enemy(enemy)
	return enemy

func _retarget() -> void:
	for index in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[index]
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			enemies.remove_at(index); continue
		if enemy.global_position.distance_to(subject().global_position) > 160.0:
			enemy.queue_free(); enemies.remove_at(index)
		elif enemy.target != subject(): enemy.set_target(subject())
	# Reconcile from live actors, including stale saves and externally freed bodies.
	wave_spawned = wave_kills + enemies.size()

func _recycle_unreachable() -> void:
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy): continue
		var age: float = float(enemy.get_meta("encounter_age", 0.0)) + 1.0
		enemy.set_meta("encounter_age", age)
		var distance: float = enemy.distance_to_target_surface(subject())
		var pursuit: Dictionary = enemy.pursuit_status()
		var hidden := _enemy_offscreen(enemy)
		var abandoned: bool = distance > 95.0 or (not enemy.is_flying() and absf(enemy.global_position.y - subject().global_position.y) > 20.0)
		var unreachable: bool = age > 15.0 and (pursuit.stuck_seconds > 10.0 or pursuit.blocked_seconds > 18.0)
		if (abandoned or unreachable) and distance > 14.0 and hidden:
			enemies.erase(enemy); enemy.queue_free() # No kill or coin credit.
	# Old districts and unreachable melee actors below a low hover can occupy
	# every slot. Release only the missing local capacity, never visible actors
	# or flying pursuers already able to engage the current craft.
	var needed := maxi(0, desired_enemies() - nearby_enemies())
	var release_count := maxi(0, needed - (ENEMY_LIMIT - enemies.size()))
	if release_count > 0:
		var distant: Array[Dictionary] = []
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion(): continue
			var distance: float = enemy.distance_to_target_surface(subject())
			var unable_to_engage := not _counts_toward_local_budget(enemy, distance)
			if (distance > 48.0 or unable_to_engage) and _enemy_offscreen(enemy): distant.append({"enemy": enemy, "distance": distance})
		distant.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.distance) > float(b.distance))
		for candidate in distant.slice(0, release_count):
			enemies.erase(candidate.enemy)
			candidate.enemy.queue_free() # Capacity recovery grants no combat reward.
	wave_spawned = wave_kills + enemies.size()

func _enemy_offscreen(enemy: Node3D) -> bool:
	var point := enemy.global_position + Vector3.UP
	if game.camera.is_position_behind(point): return true
	var screen: Vector2 = game.camera.unproject_position(point)
	return not get_viewport().get_visible_rect().grow(60.0).has_point(screen)

func _enemy_defeated(enemy, reward: int) -> void:
	if not enemies.has(enemy): return
	enemies.erase(enemy)
	kills += 1; wave_kills += 1
	_credit(reward)
	_reward_text = "击败 Lv.%d %s · +%d 金币" % [enemy.level, enemy.spec.label, reward]
	_reward_clock = 3.0
	if _rng.randf() < 0.2: medkits = mini(MEDKIT_LIMIT, medkits + 1)
	if wave_kills >= quota():
		cleared += 1; wave_kills = 0; wave_spawned = enemies.size(); rest = 0.0
		_spawn_clock = minf(_spawn_clock, 0.6)
		_credit(800 + mini(cleared, 6) * 150)
		medkits = mini(MEDKIT_LIMIT, medkits + 1)
		game.notify("清理奖金到账 · 医疗包 +1 · 下一批奶龙正在赶来\nH 急救 / 战地快修 · B 整备升级 · 持续反击")

func _credit(amount: int) -> void:
	game.life.money += maxi(amount, 0)
	game.life.lifetime_earnings += maxi(amount, 0)
	game.life.money_changed.emit(game.life.money)

func _clear_line(from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4, exclude)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _enemy_attack(enemy, damage: float, attack_range: float) -> void:
	if not _running() or not enabled or grace > 0.0 or not enemies.has(enemy): return
	var target := subject()
	if enemy.distance_to_target_surface(target) > attack_range + 0.15: return
	var exclude: Array[RID] = [enemy.get_rid(), game.player.get_rid()]
	if target is RigidBody3D: exclude.append(target.get_rid())
	if not _clear_line(enemy.global_position + Vector3.UP * 1.2, enemy.target_surface_point(target), exclude): return
	if str(enemy.enemy_type) == "spitter":
		_add_hazard(enemy.global_position + Vector3.UP * 1.6, enemy.target_surface_point(target), damage, 3.2)
	elif str(enemy.enemy_type) == "stormwing":
		_add_hazard(enemy.global_position + Vector3.UP * 1.6, enemy.target_surface_point(target), damage, 3.4, false, true)
	elif str(enemy.enemy_type) == "alpha":
		_add_hazard(enemy.global_position + Vector3.UP, enemy.global_position, damage, 4.0, true)
	else: _hurt_target(damage, enemy.global_position)

func _hurt_target(damage: float, origin: Vector3, limit_crowd: bool = true) -> float:
	if grace > 0.0 or _rescue_pending: return 0.0
	var target := subject()
	if limit_crowd:
		var armor: float = target.armor_divisor() if target is RigidBody3D else 1.0
		damage = minf(damage, _incoming_budget * armor)
	var actual: float = target.take_combat_damage(damage) if target is RigidBody3D else target.take_damage(damage, origin)
	if actual <= 0.0: return 0.0
	if limit_crowd: _incoming_budget = maxf(0.0, _incoming_budget - actual)
	_hurt_clock = 8.0; _hurt_flash = 1.0
	var direction: Vector3 = (origin - target.global_position).normalized()
	var side := direction.dot(game.camera.global_basis.x)
	var front := direction.dot(-game.camera.global_basis.z)
	_hurt_direction = ("右侧" if side > 0 else "左侧") if absf(side) > absf(front) else ("前方" if front > 0 else "后方")
	if target is RigidBody3D:
		fleet_health[target.kind] = minf(float(fleet_health.get(target.kind, 100.0)), target.health)
		if target.health <= 0.0: game.notify("载具已失去动力 · E 离舱反击，或 Home 呼叫救援", false)
	return actual

func _add_hazard(from: Vector3, at: Vector3, damage: float, radius: float, shockwave: bool = false, electric: bool = false) -> void:
	if _hazards.size() >= 12: return
	var view := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.10; mesh.outer_radius = radius
	mesh.rings = 24; mesh.ring_segments = 8
	view.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("bb91ff") if electric else Color("ff704d"); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	view.material_override = mat
	add_child(view); view.global_position = at + Vector3.UP * 0.1
	var orb := MeshInstance3D.new()
	var orb_mesh := SphereMesh.new(); orb_mesh.radius = 0.28; orb_mesh.height = 0.56
	orb.mesh = orb_mesh; orb.material_override = mat
	add_child(orb); orb.global_position = from; orb.visible = not shockwave
	var duration := 1.15 if electric else .85
	_hazards.append({"view": view, "orb": orb, "at": at, "origin": from, "damage": damage, "radius": radius, "time": duration, "duration":duration})

func _distance_to_body(point: Vector3, target: Node3D) -> float:
	if target is RigidBody3D:
		var box: AABB = preload("res://scripts/vehicle_spawn.gd").envelope(target)
		var local := target.to_local(point)
		var nearest := Vector3(clampf(local.x, box.position.x, box.end.x), clampf(local.y, box.position.y, box.end.y), clampf(local.z, box.position.z, box.end.z))
		return point.distance_to(target.to_global(nearest))
	return point.distance_to(target.global_position)

func _tick_hazards(delta: float) -> void:
	for index in range(_hazards.size() - 1, -1, -1):
		var hazard: Dictionary = _hazards[index]
		hazard.time -= delta
		if hazard.time > 0.0:
			hazard.view.scale = Vector3.ONE * (1.0 + sin(hazard.time * 20.0) * 0.05)
			var t: float = 1.0 - hazard.time / float(hazard.get("duration", .85))
			hazard.orb.global_position = hazard.origin.lerp(hazard.at, t) + Vector3.UP * sin(t * PI) * 2.0
			continue
		var target := subject()
		var exclude: Array[RID] = [game.player.get_rid()]
		if target is RigidBody3D: exclude.append(target.get_rid())
		if _distance_to_body(hazard.at, target) < hazard.radius and _clear_line(hazard.origin, target.global_position + Vector3.UP, exclude):
			_hurt_target(hazard.damage, hazard.origin)
		hazard.view.queue_free(); hazard.orb.queue_free(); _hazards.remove_at(index)

func damage_blast(point: Vector3, radius: float, damage: float, owner: RigidBody3D) -> void:
	if not enabled: return
	_last_blast = {"hits":[], "total":0.0, "radius":radius, "center_damage":damage}
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy): continue
		var distance := point.distance_to(enemy.global_position + Vector3.UP)
		if distance > radius: continue
		var exclude: Array[RID] = [enemy.get_rid(), game.player.get_rid()]
		if is_instance_valid(owner): exclude.append(owner.get_rid())
		if _clear_line(point + Vector3.UP * 0.25, enemy.global_position + Vector3.UP, exclude):
			enemy.set_meta("damage_style", "cannon" if distance < radius * .3 else "splash")
			var actual: float = enemy.take_damage(damage * lerpf(1.0, 0.3, distance / maxf(1.0, radius)), point)
			if actual > 0.0:
				_last_blast.hits.append({"id":enemy.get_instance_id(), "distance":distance, "actual":actual})
				_last_blast.total += actual
	# Friendly splash requires care near your own vehicle, with a modest ceiling.
	if is_instance_valid(owner) and point.distance_to(owner.global_position) < radius * 0.45:
		owner.take_combat_damage(minf(35.0, damage * 0.12))

func _ram_enemies() -> void:
	if not is_instance_valid(game.current_vehicle):
		_last_ram_vehicle = null
		return
	var vehicle: RigidBody3D = game.current_vehicle
	var from := _last_ram_position if _last_ram_vehicle == vehicle else vehicle.global_position
	_last_ram_vehicle = vehicle; _last_ram_position = vehicle.global_position
	if vehicle.health <= 0.0 or vehicle.linear_velocity.length() < 3.5: return
	var box: AABB = preload("res://scripts/vehicle_spawn.gd").envelope(vehicle).grow(0.75)
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy): continue
		var relative: Vector3 = vehicle.to_local(enemy.global_position + Vector3.UP)
		var previous: Vector3 = relative + vehicle.global_basis.inverse() * (vehicle.global_position - from)
		# Sweep the hull over its actual recent movement, including boosted speed.
		if not box.has_point(relative) and not box.has_point(previous) and box.intersects_segment(previous, relative) == null: continue
		enemy.set_meta("damage_style", "ram")
		enemy.take_damage(minf(280.0, vehicle.linear_velocity.length() * 8.0), vehicle.global_position)
		vehicle.take_combat_damage(6.0 if vehicle.kind == "tank" else 12.0)

func fire_blaster() -> bool:
	if not _running() or not enabled or _shot_cooldown > 0.0 or game.player.health <= 0.0 or is_instance_valid(game.current_vehicle): return false
	_shot_cooldown = 0.24
	var camera: Camera3D = game.camera
	var center := get_viewport().get_visible_rect().size * 0.5
	var ray_from := camera.project_ray_origin(center)
	var aim := ray_from + camera.project_ray_normal(center) * 85.0
	var exclude: Array[RID] = [game.player.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(ray_from, aim, 1 | 4 | 16, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): aim = hit.position
	var muzzle: Vector3 = game.player.global_position + Vector3.UP * 1.35
	query = PhysicsRayQueryParameters3D.create(muzzle, aim, 1 | 4 | 16, exclude)
	var close_hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not close_hit.is_empty(): hit = close_hit; aim = hit.position
	if not hit.is_empty() and is_instance_valid(hit.collider) and hit.collider.is_in_group("nailong_enemies"):
		hit.collider.set_meta("damage_style", "blaster")
		if hit.collider.take_damage(28.0, aim) > 0.0: _hit_flash = 1.0
	_draw_beam(muzzle, aim)
	return true

func _build_blaster() -> void:
	_gun = Node3D.new()
	_gun.name = "PulseBlaster"
	game.player.visual.add_child(_gun)
	_gun.position = Vector3(0.34, 1.17, -0.27)
	for spec in [[Vector3.ZERO, Vector3(0.18, 0.20, 0.48), Color("234654")], [Vector3(0, 0.01, -0.34), Vector3(0.11, 0.11, 0.29), Color("93efd6")], [Vector3(0, -0.16, 0.08), Vector3(0.11, 0.26, 0.12), Color("172a31")]]:
		var view := MeshInstance3D.new()
		var mesh := BoxMesh.new(); mesh.size = spec[1]
		view.mesh = mesh; view.position = spec[0]
		var mat := StandardMaterial3D.new(); mat.albedo_color = spec[2]
		view.material_override = mat; _gun.add_child(view)

func _draw_beam(from: Vector3, to: Vector3) -> void:
	var record: Dictionary = {}
	for beam in _beams:
		if beam.time <= 0.0: record = beam; break
	if record.is_empty():
		if _beams.size() >= 8: return
		var view := MeshInstance3D.new(); view.mesh = BoxMesh.new()
		var mat := StandardMaterial3D.new(); mat.albedo_color = Color("b0ffe6")
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		view.material_override = mat; add_child(view)
		record = {"view": view, "time": 0.0}; _beams.append(record)
	var direction := to - from
	if direction.length() < 0.01: return
	record.time = 0.07; record.view.visible = true
	record.view.global_transform = Transform3D(Basis.looking_at(direction.normalized(), Vector3.RIGHT if absf(direction.normalized().y) > 0.98 else Vector3.UP).scaled_local(Vector3(0.025, 0.025, direction.length())), (from + to) * 0.5)

func _tick_beams(delta: float) -> void:
	for beam in _beams:
		beam.time -= delta
		beam.view.visible = beam.time > 0.0

func sync_fleet() -> void:
	for vehicle in game.vehicles:
		if not is_instance_valid(vehicle): continue
		fleet_health[vehicle.kind] = minf(float(fleet_health.get(vehicle.kind, 100.0)), vehicle.health)
		fleet_upgrades[vehicle.kind] = maxi(int(fleet_upgrades.get(vehicle.kind, 0)), vehicle.weapon_upgrade)
	for vehicle in game.vehicles:
		if not is_instance_valid(vehicle): continue
		vehicle.health = float(fleet_health[vehicle.kind])
		vehicle.weapon_upgrade = int(fleet_upgrades[vehicle.kind])

func apply_fleet_to(vehicle: RigidBody3D) -> void:
	vehicle.health = float(fleet_health.get(vehicle.kind, 100.0))
	vehicle.weapon_upgrade = int(fleet_upgrades.get(vehicle.kind, 0))

func service_block_reason(action: String = "repair") -> String:
	# Portable supplies and software upgrades remain usable in continuous combat.
	if action in ["medkit", "upgrade"]: return ""
	if subject() is RigidBody3D and subject().kind not in ["yacht", "speedboat"] and subject().global_position.y < 0.0: return "载具已落水 · 先 E 离舱或 Home 救援，再远程维修"
	if action == "field_repair":
		return "快修冷却 %.0f 秒" % ceil(field_repair_cooldown) if field_repair_cooldown > 0.0 else ""
	if action == "refuel": return ""
	if subject() is RigidBody3D and subject().linear_velocity.length() > 1.0: return "先停稳载具，再进行完整维修；H 可随时快修"
	if _hurt_clock > 0.0: return "完整维修需脱战 %.0f 秒；H 快修不受影响" % ceil(_hurt_clock)
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.distance_to_target_surface(subject()) < 20.0: return "附近 20 米内有奶龙 · 先清理或撤到安全位置"
	return ""

func heal_player() -> String:
	if not _running() or not enabled: return ""
	if game.player.health <= 0.0 or _rescue_pending: return "救援正在前往，不会消耗医疗包"
	if game.player.health >= game.player.max_health: return "生命值已满，医疗包已保留"
	if heal_cooldown > 0.0: return "医疗冷却 %.0f 秒" % ceil(heal_cooldown)
	if medkits <= 0: return "医疗包用完 · B 补给，或清理奶龙获取"
	medkits -= 1; heal_cooldown = 12.0
	game.player.heal(60.0)
	return "使用医疗包 · 恢复 60 生命"

func quick_recovery() -> String:
	if not _running() or not enabled: return ""
	if is_instance_valid(game.current_vehicle): return str(transact("field_repair").message)
	return heal_player()

func field_repair_cost() -> int:
	if not is_instance_valid(game.current_vehicle): return 0
	var kind: String = game.current_vehicle.kind
	var lowest: float = minf(game.current_vehicle.health, float(fleet_health.get(kind, 100.0)))
	for member in game.vehicles:
		if is_instance_valid(member) and member.kind == kind: lowest = minf(lowest, member.health)
	return ceili(minf(25.0, 100.0 - lowest) * 45.0)

func repair_cost(kind: String = "") -> int:
	if kind.is_empty():
		if not is_instance_valid(game.current_vehicle): return 0
		kind = game.current_vehicle.kind
	return ceili((100.0 - float(fleet_health.get(kind, 100.0))) * REPAIR_RATE)

func transact(action: String, kind: String = "") -> Dictionary:
	# A fresh collision on another same-kind copy may precede the periodic ledger.
	# Price and apply the purchase from the current lowest durability atomically.
	sync_fleet()
	var reason := service_block_reason(action)
	if not reason.is_empty(): return {"ok": false, "message": reason}
	var vehicle = game.current_vehicle
	if kind.is_empty() and is_instance_valid(vehicle): kind = vehicle.kind
	var cost := 0
	var restored := 0.0
	if action == "medkit":
		if medkits >= MEDKIT_LIMIT: return {"ok": false, "message": "医疗包已满（5 个）"}
		cost = 300
	elif action == "refuel":
		if not is_instance_valid(vehicle): return {"ok": false, "message": "进入要补充能源的载具"}
		cost = ceili((100.0 - vehicle.fuel) * 3.0)
		if cost <= 0: return {"ok": false, "message": "能源已满"}
	elif action == "repair":
		if not game.VEHICLE_NAMES.has(kind): return {"ok": false, "message": "请在车队列表选择要维修的车型"}
		cost = repair_cost(kind)
		if cost <= 0: return {"ok": false, "message": "载具耐久已满"}
	elif action == "field_repair":
		if not enabled or not is_instance_valid(vehicle): return {"ok": false, "message": "进入载具后可使用战地快修"}
		kind = vehicle.kind
		restored = minf(25.0, 100.0 - vehicle.health)
		cost = field_repair_cost()
		if cost <= 0: return {"ok": false, "message": "载具耐久已满，金币已保留"}
	elif action == "upgrade":
		if not is_instance_valid(vehicle) or vehicle.kind not in ["tank", "fighter"]: return {"ok": false, "message": "炮塔升级适用于坦克与战斗机"}
		kind = vehicle.kind
		if vehicle.weapon_upgrade >= 3: return {"ok": false, "message": "火控已达到 III 级"}
		cost = UPGRADE_COSTS[vehicle.weapon_upgrade]
	else: return {"ok": false, "message": "未知服务"}
	if game.life.money < cost: return {"ok": false, "message": "金币不足 · 清理奶龙或 J 接取工作"}
	game.life.money -= cost
	game.life.money_changed.emit(game.life.money)
	if action == "medkit": medkits += 1
	elif action == "refuel": vehicle.fuel = 100.0
	else:
		if action == "repair": fleet_health[kind] = 100.0
		elif action == "field_repair":
			fleet_health[kind] = minf(100.0, vehicle.health + 25.0)
			field_repair_cooldown = 12.0
		else: fleet_upgrades[vehicle.kind] = vehicle.weapon_upgrade + 1
		for member in game.vehicles.duplicate():
			if member.kind != kind: continue
			if action in ["repair", "field_repair"]:
				# Paid recovery retrieves submerged abandoned wrecks; leaving them in
				# the water would immediately drain the repaired shared fleet again.
				if not member.occupied and member.kind not in ["yacht", "speedboat"] and member.global_position.y < 0.0:
					game.vehicles.erase(member)
					member.set_physics_process(false); member.freeze = true; member.queue_free()
				elif action == "repair": member.repair()
				else: member.health = float(fleet_health[kind])
			else: member.weapon_upgrade = int(fleet_upgrades[vehicle.kind])
	var message := {"medkit": "医疗包 +1", "refuel": "当前载具能源已补满", "repair": "同款载具已维修，落水残骸已回收 · Tab 可重新出发", "field_repair": "战地快修 · 同款耐久 +25%，12 秒冷却", "upgrade": "火控升级完成 · 覆盖范围扩大、火力更强、装填更快"}
	if action == "field_repair": message.field_repair = "战地快修 · 同款耐久 +%.0f%%，12 秒冷却" % restored
	if action == "upgrade":
		var stats: Dictionary = game.weapons.upgrade_stats(kind, vehicle.weapon_upgrade).current
		message.upgrade = "火控 %d 级 · 爆炸半径 %.1f m · 装填 %.2f s · 弹药免费" % [vehicle.weapon_upgrade, stats.radius, stats.cooldown]
	return {"ok": true, "message": str(message[action]) + " · $%d" % cost}

func transact_module(action: String, id: String) -> Dictionary:
	if not is_instance_valid(game) or not game.active or _rescue_pending:
		return {"ok":false, "message":"进入游戏后再选装武器"}
	var vehicle = game.current_vehicle
	if not is_instance_valid(vehicle): return {"ok":false, "message":"先进入需要选装武器的载具"}
	if vehicle.health <= 0.0: return {"ok":false, "message":"载具已损毁 · 先维修，再进行选装"}
	var result := armory.transact(vehicle.kind, id, action, game.life.money)
	if result.ok:
		game.life.money = int(result.balance)
		game.life.money_changed.emit(game.life.money)
	return result

func _landed(speed: float) -> void:
	if enabled and _running() and speed > 18.0: _hurt_target(minf(75.0, (speed - 18.0) * 2.2), game.player.global_position - Vector3.UP, false)

func _request_rescue() -> void:
	if _rescue_pending: return
	_rescue_pending = true
	call_deferred("rescue", true)

func rescue(was_defeated: bool = false) -> void:
	if not is_instance_valid(game) or not game.active: return
	var cost := mini(game.life.money, 1000 if was_defeated else 500)
	game.life.money -= cost
	game.life.money_changed.emit(game.life.money)
	if is_instance_valid(game.current_vehicle): game.exit_vehicle()
	clear_enemies()
	wave_spawned = wave_kills
	game.player.reset_health()
	game.player.global_position = game.world.anchors.get("home", Vector3(-140, 6, 150)) + Vector3(0, 2, 15)
	game.player.velocity = Vector3.ZERO
	game.player.last_safe = game.player.global_position
	game.player.reset_physics_interpolation()
	game.reset_follow_camera()
	grace = 12.0; _rescue_pending = false; _hurt_clock = 0.0
	_spawn_clock = 0.6; _incoming_budget = 18.0
	medkits = maxi(1, medkits)
	game.close_panel()
	game.notify("救援完成 · 扣除 $%d，保留升级与金币余额\n生命恢复 · 12 秒保护 · 奶龙继续接近，准备反击" % cost)

func hud_state() -> Dictionary:
	var vehicle = game.current_vehicle
	var phase := "保护" if grace > 0.0 else ("夜间增援" if night_factor() > 0.5 else "持续接战")
	var objective := "清理奖金 %d / %d · 新区域持续刷怪" % [wave_kills, quota()]
	if grace > 0.0: objective = "%.0f 秒保护 · 奶龙已在接近，准备反击" % ceil(grace)
	var nearest = null
	var distance := INF
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		var reach: float = enemy.distance_to_target_surface(subject())
		if reach < distance: nearest = enemy; distance = reach
	var hint: String = _spawn_reason if nearest == null else ""
	if nearest != null:
		var heading: Vector3 = (nearest.global_position - subject().global_position).normalized()
		var right := heading.dot(game.camera.global_basis.x)
		var front := heading.dot(-game.camera.global_basis.z)
		var direction := ("右侧" if right > 0 else "左侧") if absf(right) > absf(front) else ("前方" if front > 0 else "后方")
		hint = "%s · %s %.0f m · %s" % ["空中奶龙" if nearest.is_flying() else "最近奶龙", direction, distance, "攻击蓄力！" if nearest.state == "windup" else "正在追击"]
	var auto: Dictionary = game.weapons.auto_status()
	var support_label := ""
	if is_instance_valid(vehicle):
		support_label = "V 自动武器 · " + (str(auto.state) if auto.enabled else "已关闭")
		if auto.locked: support_label = "V 自动锁定 · %.0f m · 免费弹药" % float(auto.target_distance)
	return {"active": game.active and enabled, "player_health": game.player.health, "max_health": game.player.max_health,
		"vehicle_health": vehicle.health if is_instance_valid(vehicle) else -1.0, "vehicle_name": str(game.VEHICLE_NAMES.get(vehicle.kind, vehicle.kind)).split(" · ")[0] if is_instance_valid(vehicle) else "",
		"enemy_count": nearby_enemies(), "kills": kills, "threat": clampf(nearby_enemies() / 10.0 + night_factor() * 0.2, 0.0, 1.0),
		"encounter_hint": hint, "support_label": support_label, "vehicle_active": is_instance_valid(vehicle), "field_repair_cooldown": field_repair_cooldown, "field_repair_cost": field_repair_cost(), "money": game.life.money,
		"objective": objective, "medkits": medkits, "heal_cooldown": heal_cooldown, "hurt_amount": _hurt_flash, "hurt_direction_label": _hurt_direction,
		"aim_hit": _hit_flash > 0.0, "phase": phase + " Lv.%d" % encounter_level(), "reward_text": _reward_text if _reward_clock > 0.0 else ""}

func get_state() -> Dictionary:
	sync_fleet()
	var records: Array = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.health > 0.0: records.append(enemy.snapshot())
	return {"revision": 3, "health": game.player.health, "medkits": medkits, "heal_cooldown": heal_cooldown, "combat_cooldown": _hurt_clock, "field_repair_cooldown": field_repair_cooldown,
		"kills": kills, "cleared": cleared, "wave_kills": wave_kills, "wave_spawned": wave_spawned, "grace": grace, "rest": rest,
		"fleet_health": fleet_health.duplicate(), "fleet_upgrades": fleet_upgrades.duplicate(), "enemies": records,
		"armory":armory.snapshot(), "adaptive_level":_adaptive_level, "difficulty_clock":_difficulty_clock}

func _number(value, fallback: float, low: float, high: float) -> float:
	return clampf(float(value), low, high) if (value is float or value is int) and is_finite(float(value)) else fallback

func apply_state(data: Dictionary) -> void:
	clear_enemies()
	fleet_health.clear(); fleet_upgrades.clear()
	armory.restore(data.get("armory", {}))
	_adaptive_level = int(_number(data.get("adaptive_level", 1), 1, 1, Progression.MAX_LEVEL))
	_difficulty_clock = _number(data.get("difficulty_clock", 0.0), 0.0, 0.0, Progression.RAMP_SECONDS)
	_air_context = false
	game.player.health = _number(data.get("health", 120.0), 120.0, 1.0, 120.0)
	medkits = int(_number(data.get("medkits", 3), 3, 0, MEDKIT_LIMIT))
	heal_cooldown = _number(data.get("heal_cooldown", 0.0), 0.0, 0.0, 12.0)
	_hurt_clock = _number(data.get("combat_cooldown", 0.0), 0.0, 0.0, 8.0)
	kills = int(_number(data.get("kills", 0), 0, 0, 100000000))
	cleared = int(_number(data.get("cleared", 0), 0, 0, 1000000))
	wave_kills = int(_number(data.get("wave_kills", 0), 0, 0, quota() - 1))
	wave_spawned = int(_number(data.get("wave_spawned", wave_kills), wave_kills, wave_kills, quota()))
	grace = maxf(5.0, _number(data.get("grace", 12.0), 12.0, 0.0, 12.0))
	rest = 0.0
	_spawn_clock = 0.6; _incoming_budget = 18.0
	field_repair_cooldown = _number(data.get("field_repair_cooldown", 0.0), 0.0, 0.0, 12.0)
	for key in ["fleet_health", "fleet_upgrades"]:
		var values = data.get(key, {})
		if not values is Dictionary: continue
		for kind in values:
			if not game.VEHICLE_NAMES.has(kind): continue
			if key == "fleet_health": fleet_health[kind] = _number(values[kind], 100.0, 0.0, 100.0)
			else: fleet_upgrades[kind] = int(_number(values[kind], 0, 0, 3))
	sync_fleet()
	var saved_enemies = data.get("enemies", [])
	if saved_enemies is Array and enabled:
		for record in saved_enemies.slice(0, ENEMY_LIMIT):
			if not record is Dictionary: continue
			var coords = record.get("position", [])
			if not coords is Array or coords.size() != 3: continue
			var at := Vector3(_number(coords[0], 0, -50000, 50000), _number(coords[1], 5, -10, 5000), _number(coords[2], 0, -50000, 50000))
			if at.distance_to(game.player.global_position) <= 240.0: spawn_enemy(str(record.get("type", "roamer")), at, _number(record.get("health", 80), 80, 1, 10000), int(_number(record.get("level", 1), 1, 1, Progression.MAX_LEVEL)))
	wave_spawned = wave_kills + enemies.size()
