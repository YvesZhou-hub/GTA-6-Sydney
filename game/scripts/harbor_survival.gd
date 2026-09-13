extends Node3D
## Street encounters use the existing city's physical surfaces. No replacement map.
const Enemy = preload("res://scripts/nailong_enemy.gd")
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
var grace := 25.0
var rest := 0.0
var fleet_health: Dictionary = {}
var fleet_upgrades: Dictionary = {}
var _spawn_clock := 1.0
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
	medkits = 3; heal_cooldown = 0.0; grace = 25.0; rest = 0.0
	_hurt_clock = 0.0; _hurt_flash = 0.0; _rescue_pending = false
	_reward_clock = 0.0; _shot_cooldown = 0.0; _last_ram_vehicle = null
	fleet_health.clear(); fleet_upgrades.clear()
	game.player.reset_health()

func clear_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)
			enemy.queue_free()
	enemies.clear()
	for hazard in _hazards:
		if is_instance_valid(hazard.view): hazard.view.queue_free()
		if is_instance_valid(hazard.orb): hazard.orb.queue_free()
	_hazards.clear()

func _running() -> bool:
	return is_instance_valid(game) and game.active and not game.paused

func subject() -> Node3D:
	return game.current_vehicle if is_instance_valid(game.current_vehicle) else game.player

func quota() -> int:
	return mini(16, 6 + cleared * 2)

func encounter_level() -> int:
	return clampi(1 + int(cleared / 2.0), 1, 10)

func night_factor() -> float:
	return float(game.city_clock.solar_state().get("night_factor", 0.0)) if is_instance_valid(game.city_clock) else 0.0

func _physics_process(delta: float) -> void:
	if not _running(): return
	grace = maxf(0.0, grace - delta)
	rest = maxf(0.0, rest - delta)
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
	if not enabled: return
	if not Input.is_action_pressed("fire"): trigger_released = true
	if trigger_released and Input.is_action_pressed("fire") and not is_instance_valid(game.current_vehicle):
		if game.camera_accepts_mouse() or Input.is_physical_key_pressed(KEY_X): fire_blaster()
	_ram_clock -= delta
	if _ram_clock <= 0.0:
		_ram_clock = 0.15
		_ram_enemies()
	if not auto_spawn or grace > 0.0 or rest > 0.0: return
	_spawn_clock -= delta
	if _spawn_clock <= 0.0:
		_spawn_clock = lerpf(4.0, 2.6, night_factor())
		if enemies.size() < ENEMY_LIMIT and wave_spawned < quota():
			var point := find_spawn_position()
			if point.is_finite():
				spawn_enemy(_next_type(), point, -1.0, encounter_level())
				wave_spawned += 1

func _next_type() -> String:
	if cleared >= 2 and wave_spawned == quota() - 1: return "alpha"
	var sequence := ["roamer", "roamer", "runner", "spitter", "brute", "runner"]
	return sequence[wave_spawned % sequence.size()]

func find_spawn_position() -> Vector3:
	var target := subject()
	var center := target.global_position
	if center.y < 1.0: return Vector3.INF
	var exclude: Array[RID] = [game.player.get_rid()]
	if target is RigidBody3D: exclude.append(target.get_rid())
	for attempt in 12:
		var angle := _rng.randf_range(-PI, PI)
		var offset := Vector3(sin(angle), 0, cos(angle)) * _rng.randf_range(28.0, 58.0)
		# Arrive outside the forward view where possible, never touching the player.
		if offset.normalized().dot(-game.camera.global_basis.z) > 0.55: continue
		var candidate := center + offset
		var query := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 6.0, candidate - Vector3.UP * 12.0, 1, exclude)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.normal.y < 0.88 or hit.position.y < 1.0: continue
		if absf(hit.position.y - center.y) > 4.5: continue
		if hit.collider.has_meta("damage_id"): continue # Do not spawn on building roofs.
		var at: Vector3 = hit.position + Vector3.UP * 0.15
		var shape := SphereShape3D.new()
		shape.radius = 1.0
		var check := PhysicsShapeQueryParameters3D.new()
		check.shape = shape; check.collision_mask = 1 | 4 | 16
		check.transform.origin = at + Vector3.UP * 1.3
		check.exclude = exclude
		if get_world_3d().direct_space_state.intersect_shape(check, 1).is_empty(): return at
	return Vector3.INF

func spawn_enemy(kind: String, at: Vector3, hp: float = -1.0, level: int = 1):
	if enemies.size() >= ENEMY_LIMIT or not at.is_finite(): return null
	var enemy = Enemy.new()
	enemy.configure(kind, level)
	add_child(enemy)
	enemy.global_position = at
	enemy.reset_physics_interpolation()
	enemy.set_target(subject())
	enemy.defeated.connect(_enemy_defeated)
	enemy.attack_requested.connect(_enemy_attack)
	if hp >= 0.0: enemy.health = clampf(hp, 1.0, enemy.max_health)
	enemies.append(enemy)
	return enemy

func _retarget() -> void:
	for index in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[index]
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			enemies.remove_at(index); continue
		if enemy.global_position.distance_to(subject().global_position) > 240.0:
			enemy.queue_free(); enemies.remove_at(index)
			wave_spawned = maxi(wave_kills, wave_spawned - 1)
		elif enemy.target != subject(): enemy.set_target(subject())

func _enemy_defeated(enemy, reward: int) -> void:
	if not enemies.has(enemy): return
	enemies.erase(enemy)
	kills += 1; wave_kills += 1
	_credit(reward)
	_reward_text = "击败 Lv.%d %s · +%d 金币" % [enemy.level, enemy.spec.label, reward]
	_reward_clock = 3.0
	if _rng.randf() < 0.2: medkits = mini(MEDKIT_LIMIT, medkits + 1)
	if wave_kills >= quota():
		cleared += 1; wave_kills = 0; wave_spawned = 0; rest = 30.0
		_credit(800 + mini(cleared, 6) * 150)
		medkits = mini(MEDKIT_LIMIT, medkits + 1)
		game.notify("街区清理完成 · 奖金到账，补充 1 个医疗包\n30 秒喘息时间 · B 维修与升级")

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
	elif str(enemy.enemy_type) == "alpha":
		_add_hazard(enemy.global_position + Vector3.UP, enemy.global_position, damage, 4.0, true)
	else: _hurt_target(damage, enemy.global_position)

func _hurt_target(damage: float, origin: Vector3) -> float:
	if grace > 0.0 or _rescue_pending: return 0.0
	var target := subject()
	var actual: float = target.take_combat_damage(damage) if target is RigidBody3D else target.take_damage(damage, origin)
	if actual <= 0.0: return 0.0
	_hurt_clock = 8.0; _hurt_flash = 1.0
	var direction: Vector3 = (origin - target.global_position).normalized()
	var side := direction.dot(game.camera.global_basis.x)
	var front := direction.dot(-game.camera.global_basis.z)
	_hurt_direction = ("右侧" if side > 0 else "左侧") if absf(side) > absf(front) else ("前方" if front > 0 else "后方")
	if target is RigidBody3D:
		fleet_health[target.kind] = minf(float(fleet_health.get(target.kind, 100.0)), target.health)
		if target.health <= 0.0: game.notify("载具已失去动力 · E 离舱反击，或 Home 呼叫救援", false)
	return actual

func _add_hazard(from: Vector3, at: Vector3, damage: float, radius: float, shockwave: bool = false) -> void:
	if _hazards.size() >= 12: return
	var view := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.10; mesh.outer_radius = radius
	mesh.rings = 24; mesh.ring_segments = 8
	view.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ff704d"); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	view.material_override = mat
	add_child(view); view.global_position = at + Vector3.UP * 0.1
	var orb := MeshInstance3D.new()
	var orb_mesh := SphereMesh.new(); orb_mesh.radius = 0.28; orb_mesh.height = 0.56
	orb.mesh = orb_mesh; orb.material_override = mat
	add_child(orb); orb.global_position = from; orb.visible = not shockwave
	_hazards.append({"view": view, "orb": orb, "at": at, "origin": from, "damage": damage, "radius": radius, "time": 0.85})

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
			var t: float = 1.0 - hazard.time / 0.85
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
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy): continue
		var distance := point.distance_to(enemy.global_position + Vector3.UP)
		if distance > radius: continue
		var exclude: Array[RID] = [enemy.get_rid(), game.player.get_rid()]
		if is_instance_valid(owner): exclude.append(owner.get_rid())
		if _clear_line(point + Vector3.UP * 0.25, enemy.global_position + Vector3.UP, exclude):
			enemy.take_damage(damage * lerpf(1.0, 0.3, distance / maxf(1.0, radius)), point)
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

func service_block_reason() -> String:
	if subject() is RigidBody3D and subject().kind not in ["yacht", "speedboat"] and subject().global_position.y < 0.0: return "载具已落水 · 先 E 离舱或 Home 救援，再远程维修"
	if subject() is RigidBody3D and subject().linear_velocity.length() > 1.0: return "先停稳载具，再进行维修或升级"
	if _hurt_clock > 0.0: return "脱离战斗 %.0f 秒后可维修补给" % ceil(_hurt_clock)
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

func repair_cost(kind: String = "") -> int:
	if kind.is_empty():
		if not is_instance_valid(game.current_vehicle): return 0
		kind = game.current_vehicle.kind
	return ceili((100.0 - float(fleet_health.get(kind, 100.0))) * REPAIR_RATE)

func transact(action: String, kind: String = "") -> Dictionary:
	var reason := service_block_reason()
	if not reason.is_empty(): return {"ok": false, "message": reason}
	var vehicle = game.current_vehicle
	if kind.is_empty() and is_instance_valid(vehicle): kind = vehicle.kind
	var cost := 0
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
		else: fleet_upgrades[vehicle.kind] = vehicle.weapon_upgrade + 1
		for member in game.vehicles.duplicate():
			if member.kind != kind: continue
			if action == "repair":
				# Paid recovery retrieves submerged abandoned wrecks; leaving them in
				# the water would immediately drain the repaired shared fleet again.
				if not member.occupied and member.kind not in ["yacht", "speedboat"] and member.global_position.y < 0.0:
					game.vehicles.erase(member)
					member.set_physics_process(false); member.freeze = true; member.queue_free()
				else: member.repair()
			else: member.weapon_upgrade = int(fleet_upgrades[vehicle.kind])
	var message := {"medkit": "医疗包 +1", "refuel": "当前载具能源已补满", "repair": "同款载具已维修，落水残骸已回收 · Tab 可重新出发", "upgrade": "火控升级完成 · 伤害 +25%，装填更快"}
	return {"ok": true, "message": str(message[action]) + " · $%d" % cost}

func _landed(speed: float) -> void:
	if enabled and _running() and speed > 18.0: _hurt_target(minf(75.0, (speed - 18.0) * 2.2), game.player.global_position - Vector3.UP)

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
	grace = 15.0; _rescue_pending = false; _hurt_clock = 0.0
	medkits = maxi(1, medkits)
	game.close_panel()
	game.notify("救援完成 · 扣除 $%d，保留升级与金币余额\n生命已恢复，15 秒整备时间 · 受损载具仍需维修" % cost)

func hud_state() -> Dictionary:
	var vehicle = game.current_vehicle
	var phase := "整备" if grace > 0.0 else ("喘息" if rest > 0.0 else ("夜间威胁" if night_factor() > 0.5 else "街区清理"))
	var objective := "清理周边奶龙 %d / %d · 完成后获得奖金与医疗包" % [wave_kills, quota()]
	if grace > 0.0: objective = "%.0f 秒整备 · 左键脉冲枪 / Tab 载具 · H 治疗" % ceil(grace)
	elif rest > 0.0: objective = "%.0f 秒喘息 · B 维修、补给与火控升级" % ceil(rest)
	return {"active": game.active and enabled, "player_health": game.player.health, "max_health": game.player.max_health,
		"vehicle_health": vehicle.health if is_instance_valid(vehicle) else -1.0, "vehicle_name": str(game.VEHICLE_NAMES.get(vehicle.kind, vehicle.kind)).split(" · ")[0] if is_instance_valid(vehicle) else "",
		"enemy_count": enemies.size(), "kills": kills, "threat": clampf(enemies.size() / 12.0 + night_factor() * 0.2, 0.0, 1.0),
		"objective": objective, "medkits": medkits, "heal_cooldown": heal_cooldown, "hurt_amount": _hurt_flash, "hurt_direction_label": _hurt_direction,
		"aim_hit": _hit_flash > 0.0, "phase": phase + " Lv.%d" % encounter_level(), "reward_text": _reward_text if _reward_clock > 0.0 else ""}

func get_state() -> Dictionary:
	sync_fleet()
	var records: Array = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.health > 0.0: records.append(enemy.snapshot())
	return {"revision": 2, "health": game.player.health, "medkits": medkits, "heal_cooldown": heal_cooldown, "combat_cooldown": _hurt_clock,
		"kills": kills, "cleared": cleared, "wave_kills": wave_kills, "wave_spawned": wave_spawned, "grace": grace, "rest": rest,
		"fleet_health": fleet_health.duplicate(), "fleet_upgrades": fleet_upgrades.duplicate(), "enemies": records}

func _number(value, fallback: float, low: float, high: float) -> float:
	return clampf(float(value), low, high) if (value is float or value is int) and is_finite(float(value)) else fallback

func apply_state(data: Dictionary) -> void:
	clear_enemies()
	fleet_health.clear(); fleet_upgrades.clear()
	game.player.health = _number(data.get("health", 120.0), 120.0, 1.0, 120.0)
	medkits = int(_number(data.get("medkits", 3), 3, 0, MEDKIT_LIMIT))
	heal_cooldown = _number(data.get("heal_cooldown", 0.0), 0.0, 0.0, 12.0)
	_hurt_clock = _number(data.get("combat_cooldown", 0.0), 0.0, 0.0, 8.0)
	kills = int(_number(data.get("kills", 0), 0, 0, 100000000))
	cleared = int(_number(data.get("cleared", 0), 0, 0, 1000000))
	wave_kills = int(_number(data.get("wave_kills", 0), 0, 0, quota() - 1))
	wave_spawned = int(_number(data.get("wave_spawned", wave_kills), wave_kills, wave_kills, quota()))
	grace = maxf(5.0, _number(data.get("grace", 25.0), 25.0, 0.0, 25.0))
	rest = _number(data.get("rest", 0.0), 0.0, 0.0, 30.0)
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
			if at.distance_to(game.player.global_position) <= 240.0: spawn_enemy(str(record.get("type", "roamer")), at, _number(record.get("health", 80), 80, 1, 10000), int(_number(record.get("level", 1), 1, 1, 10)))
	wave_spawned = mini(quota(), wave_kills + enemies.size())
