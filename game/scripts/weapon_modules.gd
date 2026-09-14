extends Node3D
## Optional paid modules. Purchases belong to the director; firing never spends money.
const MAX_SLOTS := 3
const MAX_LEVEL := 3
const SHOT_CAPACITY := 24
const LINE_CAPACITY := 48
const BURST_CAPACITY := 12
const CATALOG := {
	"rotary":{"label":"机关枪", "description":"密集曳光弹，持续压制单体；弹丸会被实体遮挡。", "costs":[4000, 9000, 18000]},
	"micro":{"label":"微型范围炮", "description":"慢节奏范围爆炸，中心伤害高；墙体阻挡冲击。", "costs":[6500, 12500, 22000]},
	"laser":{"label":"激光", "description":"远距离精准光束，快速命中一个可见目标。", "costs":[7000, 14000, 24000]},
	"tesla":{"label":"连锁闪电", "description":"在附近敌人之间跳跃，逐跳衰减；每段都检查遮挡。", "costs":[8500, 16000, 28000]}
}
const COLORS := {"rotary":Color("ffca67"), "micro":Color("ff794b"), "laser":Color("56e9ff"), "tesla":Color("c191ff")}
var support: Node3D
var _pods: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _lines: Array[Dictionary] = []
var _bursts: Array[Dictionary] = []
var _materials: Dictionary = {}
var _reloads: Dictionary = {}
var _loadout: Array[Dictionary] = []
var _targets: Dictionary = {}
var _fired: Dictionary = {}
var _hits: Dictionary = {}
var _blocked := 0
var _time := 0.0
var _scan := 0.0

static func _level(value: Variant, minimum := 0) -> int:
	if not (value is int or value is float) or not is_finite(float(value)): return minimum
	return clampi(int(value), minimum, MAX_LEVEL)

static func spec(id: String, level: int = 1) -> Dictionary:
	if not CATALOG.has(id): return {}
	var tier := clampi(level, 1, MAX_LEVEL)
	var n := tier - 1
	var result := {"id":id, "label":CATALOG[id].label, "level":tier, "ammo_cost":0,
		"damage":0.0, "cooldown":1.0, "range":100.0, "speed":0.0, "radius":0.0, "chain_count":1, "chain_range":0.0, "chain_falloff":.72}
	match id:
		"rotary": result.merge({"damage":7.0 + 2.0 * n, "cooldown":.16 - .015 * n, "range":115.0, "speed":340.0}, true)
		"micro": result.merge({"damage":40.0 + 12.0 * n, "cooldown":2.4 - .24 * n, "range":125.0, "speed":105.0, "radius":5.0 + n}, true)
		"laser": result.merge({"damage":13.0 + 4.0 * n, "cooldown":.55 - .06 * n, "range":220.0}, true)
		"tesla": result.merge({"damage":16.0 + 4.0 * n, "cooldown":.95 - .08 * n, "range":90.0, "chain_count":3 + n, "chain_range":7.0 + 1.5 * n}, true)
	return result

static func cost(id: String, owned_level: int) -> int:
	if not CATALOG.has(id) or owned_level >= MAX_LEVEL: return 0
	return int(CATALOG[id].costs[maxi(0, owned_level)])

static func power_loadout(loadout: Array, owned: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used := {}
	for entry: Variant in loadout:
		var id := str(entry.get("id", "")) if entry is Dictionary else str(entry)
		var level := _level(owned.get(id, 0))
		if not CATALOG.has(id) or level == 0 or used.has(id): continue
		result.append({"id":id, "level":level}); used[id] = true
		if result.size() == MAX_SLOTS: break
	return result

static func normalized_runtime_loadout(value: Variant) -> Array[Dictionary]:
	if not value is Array: return []
	var owned := {}
	for entry: Variant in value:
		if entry is Dictionary:
			var id := str(entry.get("id", ""))
			if not owned.has(id): owned[id] = _level(entry.get("level", 0))
	return power_loadout(value, owned)

func setup(owner_support: Node3D) -> void:
	support = owner_support
	_prepare()
	clear()
	_reloads.clear()

func _view(parent: Node3D, mesh: Mesh, material: Material, at := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.mesh = mesh; node.material_override = material; node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(node)
	return node

func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new(); mesh.size = size; return mesh

func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new(); mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height; mesh.radial_segments = 8
	return mesh

func _prepare() -> void:
	if not _pods.is_empty(): return
	var metal := StandardMaterial3D.new(); metal.albedo_color = Color("314754"); metal.metallic = .65; metal.roughness = .3
	for id: String in CATALOG:
		var mat := StandardMaterial3D.new(); mat.albedo_color = COLORS[id]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true; mat.emission = COLORS[id]; mat.emission_energy_multiplier = 2.7
		_materials[id] = mat
	for index in MAX_SLOTS:
		var node := Node3D.new(); node.name = "ModuleSlot%d" % index; add_child(node)
		_view(node, _box(Vector3(.24, .08, .30)), metal)
		var variants := {}
		for id: String in CATALOG:
			var head := Node3D.new(); head.name = id; node.add_child(head); variants[id] = head
			match id:
				"rotary":
					for barrel in 3:
						var angle := float(barrel) * TAU / 3.0
						var tube := _view(head, _cylinder(.035, .42), metal, Vector3(cos(angle)*.075, .12+sin(angle)*.075, -.22)); tube.rotation.x = PI/2
					_view(head, _box(Vector3(.12, .05, .06)), _materials[id], Vector3(0, .12, -.45))
				"micro":
					var tube := _view(head, _cylinder(.11, .33), metal, Vector3(0, .15, -.13)); tube.rotation.x = PI/2
					_view(head, _box(Vector3(.15, .13, .045)), _materials[id], Vector3(0, .15, -.31))
				"laser":
					_view(head, _box(Vector3(.12, .12, .5)), metal, Vector3(0, .12, -.19))
					for side in [-1, 1]: _view(head, _box(Vector3(.035, .20, .28)), _materials[id], Vector3(side*.09, .12, -.18))
				"tesla":
					for side in [-1, 1]:
						_view(head, _cylinder(.04, .27), metal, Vector3(side*.08, .18, -.12))
						_view(head, _cylinder(.075, .035), _materials[id], Vector3(side*.08, .31, -.12))
		_pods.append({"node":node, "variants":variants}); node.visible = false
	var bolt_mesh := SphereMesh.new(); bolt_mesh.radius = .08; bolt_mesh.height = .16; bolt_mesh.radial_segments = 8; bolt_mesh.rings = 4
	for index in SHOT_CAPACITY:
		var view := _view(self, bolt_mesh, _materials.rotary); view.visible = false
		_shots.append({"active":false, "view":view, "point":Vector3.ZERO, "direction":Vector3.FORWARD, "profile":{}, "remaining":0.0, "source":null, "target":null, "exclude":[]})
	for index in LINE_CAPACITY:
		var view := _view(self, _box(Vector3.ONE), _materials.laser); view.visible = false
		_lines.append({"view":view, "left":0.0, "duration":.1})
	for index in BURST_CAPACITY:
		var view := _view(self, bolt_mesh, _materials.micro); view.visible = false
		_bursts.append({"view":view, "left":0.0, "duration":.3, "radius":1.0})

func _enemies() -> Array:
	var director: Node3D = support._director()
	if not is_instance_valid(director): return []
	var value: Variant = director.get("enemies")
	# A lethal take_damage synchronously removes the actor from the director.
	# Iterate a snapshot so one blast cannot skip the next actor after that erase.
	return value.duplicate() if value is Array else []

func _sync_loadout(vehicle: RigidBody3D) -> void:
	var director: Node3D = support._director()
	var raw: Variant = director.call("weapon_loadout", str(vehicle.get("kind"))) if is_instance_valid(director) and director.has_method("weapon_loadout") else []
	var current := normalized_runtime_loadout(raw)
	if current != _loadout:
		var active_ids := current.map(func(entry): return entry.id)
		for shot: Dictionary in _shots:
			if shot.active and not active_ids.has(shot.profile.id): _end_shot(shot)
		for id: String in _targets.keys():
			if not active_ids.has(id): _targets.erase(id)
		# Upgrade payloads are snapshots: a shell already in flight keeps its tier.
		# Removing equipment cannot reset the per-module firing cooldown either.
		_loadout = current
		_scan = 0.0

func _visible(from: Vector3, enemy: Node3D, exclude: Array[RID]) -> bool:
	var hit: Dictionary = support._ray(from, support._aim_point(enemy), exclude)
	return hit.is_empty() or hit.get("collider") == enemy

func _acquire(from: Vector3, vehicle: RigidBody3D, profile: Dictionary, exclude: Array[RID]) -> Node3D:
	var result: Node3D; var nearest := INF
	for enemy: Variant in _enemies():
		if not support._valid_enemy(enemy): continue
		var delta: Vector3 = support._aim_point(enemy) - from
		var distance := delta.length()
		if distance > float(profile.range) or distance >= nearest: continue
		if distance > 14.0 and delta.normalized().dot(-vehicle.global_basis.z.normalized()) < -.65: continue
		if not _visible(from, enemy, exclude): continue
		result = enemy; nearest = distance
	return result

func _damage(enemy: Node3D, amount: float, position: Vector3, id: String) -> void:
	if not support._valid_enemy(enemy): return
	enemy.set_meta("damage_style", id)
	var actual: float = enemy.call("take_damage", amount, position)
	if actual > 0.0: _hits[id] = int(_hits.get(id, 0)) + 1

func _line(from: Vector3, to: Vector3, id: String, width: float, duration: float) -> void:
	var distance := from.distance_to(to)
	if distance < .001: return
	var slot: Dictionary = _lines[0]
	for item: Dictionary in _lines:
		if item.left <= 0.0: slot = item; break
		if item.left < slot.left: slot = item
	slot.left = duration; slot.duration = duration; slot.view.visible = true; slot.view.transparency = 0.0; slot.view.material_override = _materials[id]
	var direction := (to-from).normalized(); var up := Vector3.RIGHT if absf(direction.y) > .98 else Vector3.UP
	slot.view.global_transform = Transform3D(Basis.looking_at(direction, up).scaled_local(Vector3(width, width, distance)), (from+to)*.5)

func _burst(at: Vector3, id: String, radius: float, duration: float) -> void:
	var slot: Dictionary = _bursts[0]
	for item: Dictionary in _bursts:
		if item.left <= 0.0: slot = item; break
		if item.left < slot.left: slot = item
	slot.left = duration; slot.duration = duration; slot.radius = radius
	slot.view.visible = true; slot.view.global_position = at; slot.view.scale = Vector3.ONE * .5; slot.view.transparency = 0.0; slot.view.material_override = _materials[id]

func _lightning(from: Vector3, to: Vector3) -> void:
	var direction := to-from; var side := direction.normalized().cross(Vector3.UP)
	if side.length_squared() < .01: side = Vector3.RIGHT
	side = side.normalized()
	var previous := from
	for index in 5:
		var next := from + direction * float(index+1)/5.0
		if index < 4: next += side * (.19 if index%2 == 0 else -.19) + Vector3.UP * sin(_time*37.0+index)*.10
		_line(previous, next, "tesla", .055, .18); previous = next

func _chain(from: Vector3, first: Node3D, profile: Dictionary, exclude: Array[RID]) -> void:
	var hit_ids := {}; var victim := first; var origin := from
	for jump in int(profile.chain_count):
		if not support._valid_enemy(victim) or not _visible(origin, victim, exclude): break
		var point: Vector3 = support._aim_point(victim)
		_lightning(origin, point); _burst(point, "tesla", .32, .22)
		hit_ids[victim.get_instance_id()] = true
		# The next segment begins inside the previous enemy, so omit that body.
		exclude.append(victim.get_rid())
		_damage(victim, float(profile.damage)*pow(float(profile.chain_falloff), jump), point, "tesla")
		origin = point; victim = null; var nearest: float = profile.chain_range
		for candidate: Variant in _enemies():
			if not support._valid_enemy(candidate) or hit_ids.has(candidate.get_instance_id()): continue
			var distance: float = origin.distance_to(support._aim_point(candidate))
			if distance >= nearest or not _visible(origin, candidate, exclude): continue
			nearest = distance; victim = candidate

func _explode(at: Vector3, normal: Vector3, profile: Dictionary, exclude: Array[RID]) -> void:
	var center := at + normal * .10
	_burst(at, "micro", float(profile.radius), .38)
	for enemy: Variant in _enemies():
		if not support._valid_enemy(enemy): continue
		var distance: float = center.distance_to(support._aim_point(enemy))
		if distance > float(profile.radius) or not _visible(center, enemy, exclude): continue
		var falloff := lerpf(1.0, .25, clampf(distance/float(profile.radius), 0.0, 1.0))
		_damage(enemy, float(profile.damage)*falloff, center, "micro")

func _intercept(from: Vector3, target: Node3D, profile: Dictionary) -> Vector3:
	var aim: Vector3 = support._aim_point(target)
	if not target is CharacterBody3D or float(profile.speed) <= 0.0: return aim
	var motion: Vector3 = target.velocity
	var relative := aim-from
	var a: float = motion.length_squared()-float(profile.speed)*float(profile.speed)
	var b := 2.0*relative.dot(motion); var c := relative.length_squared()
	var travel := -1.0
	if absf(a)<.001:
		if absf(b)>.001: travel = -c/b
	else:
		var discriminant := b*b-4.0*a*c
		if discriminant >= 0.0:
			var first := (-b-sqrt(discriminant))/(2.0*a)
			var second := (-b+sqrt(discriminant))/(2.0*a)
			if first>0.0: travel=first
			if second>0.0 and (travel<0.0 or second<travel): travel=second
	if travel>0.0 and travel<=float(profile.range)/float(profile.speed): return aim+motion*travel
	return aim

func _fire(from: Vector3, target: Node3D, vehicle: RigidBody3D, profile: Dictionary, exclude: Array[RID]) -> bool:
	var id: String = profile.id
	var aim: Vector3 = support._aim_point(target)
	if id == "laser":
		var hit: Dictionary = support._ray(from, aim, exclude)
		if not hit.is_empty() and hit.get("collider") != target: return false
		var point: Vector3 = hit.get("position", aim)
		_line(from, point, id, .065, .15); _burst(point, id, .28, .20)
		_damage(target, float(profile.damage), point, id)
	elif id == "tesla": _chain(from, target, profile, exclude)
	else:
		var slot: Dictionary = {}
		for candidate: Dictionary in _shots:
			if not candidate.active: slot = candidate; break
		if slot.is_empty(): return false
		slot.active = true; slot.point = from; slot.direction = (_intercept(from,target,profile)-from).normalized(); slot.profile = profile.duplicate()
		slot.remaining = float(profile.range); slot.source = weakref(vehicle); slot.target = weakref(target); slot.exclude = exclude.duplicate()
		slot.view.material_override = _materials[id]; slot.view.visible = true; slot.view.global_position = from
		slot.view.scale = Vector3.ONE * (1.5 if id == "micro" else .6)
		_burst(from, id, .22 if id == "rotary" else .36, .06)
	_fired[id] = int(_fired.get(id, 0)) + 1
	return true

func _end_shot(shot: Dictionary) -> void:
	shot.active = false; shot.view.visible = false; shot.source = null; shot.target = null; shot.exclude = []

func _tick_effects(delta: float) -> void:
	for shot: Dictionary in _shots:
		if not shot.active: continue
		var source: Variant = shot.source.get_ref() if shot.source is WeakRef else null
		var target: Variant = shot.target.get_ref() if shot.target is WeakRef else null
		if not is_instance_valid(source) or source.is_queued_for_deletion() or float(source.get("health")) <= 0.0 or not support._valid_enemy(target):
			_end_shot(shot); continue
		var step := minf(float(shot.remaining), float(shot.profile.speed)*delta)
		var to: Vector3 = shot.point + shot.direction * step
		var exclude: Array[RID] = []; exclude.assign(shot.exclude)
		var hit: Dictionary = support._ray(shot.point, to, exclude)
		if not hit.is_empty():
			if shot.profile.id == "micro": _explode(hit.position, hit.get("normal", Vector3.UP), shot.profile, exclude)
			elif support._valid_enemy(hit.get("collider")):
				_damage(hit.collider, float(shot.profile.damage), hit.position, "rotary"); _burst(hit.position, "rotary", .18, .1)
			else: _blocked += 1
			_end_shot(shot); continue
		if shot.profile.id == "rotary": _line(shot.point, to, "rotary", .025, .055)
		else: _line(shot.point, to, "micro", .09, .14)
		shot.point = to; shot.remaining -= step; shot.view.global_position = to
		if shot.remaining <= 0.0: _end_shot(shot)
	for slot: Dictionary in _lines:
		slot.left = maxf(0.0, slot.left-delta); slot.view.visible = slot.left > 0.0
		slot.view.transparency = 1.0 - float(slot.left)/float(slot.duration)
	for slot: Dictionary in _bursts:
		slot.left = maxf(0.0, slot.left-delta); slot.view.visible = slot.left > 0.0
		var progress := 1.0 - float(slot.left)/float(slot.duration)
		slot.view.scale = Vector3.ONE * maxf(.01, float(slot.radius)*12.5*progress)
		slot.view.transparency = minf(1.0, .35 + progress*.65)

func tick(vehicle: RigidBody3D, delta: float) -> void:
	# Parent support owns active/paused/modal/health gates and current-vehicle identity.
	_time += delta
	for id: String in _reloads: _reloads[id] = maxf(0.0, float(_reloads[id])-delta)
	_sync_loadout(vehicle)
	_tick_effects(delta)
	_scan -= delta
	var rescan := _scan <= 0.0
	if rescan: _scan = .16 # At most one 24-enemy search per module per sensing tick.
	var exclude: Array[RID] = support._exclusions(vehicle)
	for index in MAX_SLOTS:
		var pod: Dictionary = _pods[index]; pod.node.visible = index < _loadout.size()
		if index >= _loadout.size(): continue
		var entry: Dictionary = _loadout[index]; var profile := spec(entry.id, entry.level)
		for id: String in pod.variants: pod.variants[id].visible = id == entry.id
		pod.node.global_transform = support._mount.global_transform * Transform3D(Basis.IDENTITY, Vector3((index-1)*.35, .38, .38))
		var origin: Vector3 = pod.node.global_position
		var target: Variant = _targets[entry.id].get_ref() if _targets.get(entry.id) is WeakRef else null
		if rescan:
			target = _acquire(origin, vehicle, profile, exclude)
			if target != null: _targets[entry.id] = weakref(target)
			else: _targets.erase(entry.id)
		if not support._valid_enemy(target): continue
		var direction: Vector3 = support._aim_point(target)-origin
		if direction.length() > float(profile.range): continue
		var up := Vector3.RIGHT if absf(direction.normalized().y) > .98 else Vector3.UP
		pod.node.global_basis = Basis.looking_at(direction, up)
		if float(_reloads.get(entry.id, .25)) > 0.0:
			if not _reloads.has(entry.id): _reloads[entry.id] = .25
			continue
		var muzzle: Vector3 = origin + direction.normalized()*.50
		if not support._ray(origin, muzzle, exclude).is_empty() or not _visible(muzzle, target, exclude): continue
		if _fire(muzzle, target, vehicle, profile, exclude): _reloads[entry.id] = float(profile.cooldown)

func clear() -> void:
	_loadout.clear(); _targets.clear(); _scan = 0.0
	for shot: Dictionary in _shots: _end_shot(shot)
	for pod: Dictionary in _pods: pod.node.visible = false
	for line: Dictionary in _lines: line.left = 0.0; line.view.visible = false
	for burst: Dictionary in _bursts: burst.left = 0.0; burst.view.visible = false

func status() -> Dictionary:
	var locks := {}
	for id: String in _targets:
		var target: Variant = _targets[id].get_ref()
		if support._valid_enemy(target): locks[id] = target.get_instance_id()
	return {"loadout":_loadout.duplicate(true), "locks":locks, "fired":_fired.duplicate(), "hits":_hits.duplicate(),
		"reloads":_reloads.duplicate(), "blocked":_blocked, "simulation_seconds":_time, "ammo_cost":0,
		"projectile_capacity":SHOT_CAPACITY, "active_projectiles":_shots.filter(func(s): return s.active).size(),
		"line_capacity":LINE_CAPACITY, "burst_capacity":BURST_CAPACITY, "mount_capacity":MAX_SLOTS}
