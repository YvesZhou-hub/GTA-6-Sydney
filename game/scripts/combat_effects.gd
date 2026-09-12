extends Node3D
## Original bounded game effects. No reference pixels, live particle bodies or
## per-shot scene allocation. Debris is visual; world owns persistent damage.
const CAPACITY := 12
const DURATION := 3.4
const SMOKE_COUNT := 16
const SPARK_COUNT := 20
const DEBRIS_COUNT := 12
var _slots: Array[Dictionary] = []
var _cursor := 0
var _sequence := 0

func _ready() -> void:
	prepare()

func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

func _instances(mesh: Mesh, material: Material, count: int, parent: Node3D) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = count
	var view := MultiMeshInstance3D.new()
	view.multimesh = multi
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
	return view

func prepare() -> void:
	if not _slots.is_empty(): return
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var chip := BoxMesh.new()
	chip.size = Vector3.ONE
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	var fire := _material(Color(1.0, 0.57, 0.13), 5.0)
	var shock := _material(Color(1.0, 0.81, 0.49), 1.2)
	var smoke := _material(Color(0.63, 0.57, 0.49))
	var sparks := _material(Color(1.0, 0.49, 0.10), 3.2)
	var debris := _material(Color(0.45, 0.39, 0.30))
	for index in CAPACITY:
		var node := Node3D.new()
		node.name = "PooledBlast_%02d" % index
		add_child(node)
		node.visible = false
		var core := MeshInstance3D.new()
		core.mesh = sphere
		core.material_override = fire
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(core)
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.material_override = shock
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(ring)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.57, 0.23)
		light.shadow_enabled = false
		light.omni_range = 28.0
		light.visible = false
		node.add_child(light)
		_slots.append({"node":node, "age":DURATION, "scale":1.0, "seed":0,
			"core":core, "ring":ring, "light":light,
			"smoke":_instances(sphere, smoke, SMOKE_COUNT, node),
			"sparks":_instances(chip, sparks, SPARK_COUNT, node),
			"debris":_instances(chip, debris, DEBRIS_COUNT, node)})

func emit_blast(point: Vector3, size: float = 1.0) -> void:
	if not point.is_finite(): return
	prepare()
	var slot: Dictionary = _slots[_cursor]
	_cursor = (_cursor + 1) % CAPACITY
	_sequence += 1
	slot.age = 0.0
	slot.scale = clampf(size, 0.25, 2.5)
	slot.seed = _sequence
	slot.node.global_position = point
	slot.node.visible = true
	_render_slot(slot)

func _direction(index: int, seed_value: int) -> Vector3:
	var phase := float(index) * 2.399963 + float(seed_value % 29) * 0.63
	var lift := 0.15 + 0.76 * float((index * 13 + seed_value * 7) % 31) / 30.0
	return Vector3(cos(phase), lift, sin(phase)).normalized()

func _render_slot(slot: Dictionary) -> void:
	var age: float = slot.age
	var size: float = slot.scale
	var core: MeshInstance3D = slot.core
	core.visible = age < 0.27
	core.scale = Vector3.ONE * size * (0.50 + 3.7 * sin(clampf(age / 0.27, 0, 1) * PI * 0.5))
	core.position.y = size * 0.5
	core.transparency = clampf(age / 0.27, 0, 1)
	var light: OmniLight3D = slot.light
	light.visible = age < 0.17
	light.light_energy = 7.0 * pow(maxf(0, 1 - age / 0.17), 2)
	var ring: MeshInstance3D = slot.ring
	ring.visible = age < 0.65
	ring.scale = Vector3(1, 0.12, 1) * size * (1 + age * 24)
	ring.position.y = 0.20
	ring.transparency = clampf(age / 0.65, 0, 1)
	var smoke: MultiMesh = slot.smoke.multimesh
	for index in SMOKE_COUNT:
		var delay := float(index % 4) * 0.045
		var t := maxf(0, age - delay)
		var d := _direction(index, slot.seed)
		var radius := size * (0.38 + t * (1.4 + float(index % 3) * 0.25))
		var p := d * size * (0.3 + 3.2 * (1 - exp(-t * 1.4)))
		p.y += size * (0.5 + t * 1.2)
		var alpha := clampf((age - delay) / 0.18, 0, 1) * pow(maxf(0, 1 - age / DURATION), 1.35) * 0.54
		var shade := 0.72 + float(index % 5) * 0.045
		smoke.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3(radius, radius * 0.83, radius)), p))
		smoke.set_instance_color(index, Color(shade, shade, shade, alpha))
	var sparks: MultiMesh = slot.sparks.multimesh
	for index in SPARK_COUNT:
		var d := _direction(index + 7, slot.seed)
		var speed := 10.0 + float(index % 6) * 2.2
		var p := d * speed * age * size + Vector3.DOWN * 8.0 * age * age
		var stretch := 0.45 + speed * 0.025
		var basis := Basis.looking_at(d, Vector3.UP).scaled(Vector3(0.025, 0.025, stretch) * size)
		sparks.set_instance_transform(index, Transform3D(basis, p))
		sparks.set_instance_color(index, Color(1, 0.82, 0.42, pow(maxf(0, 1 - age / 1.15), 1.2)))
	var debris: MultiMesh = slot.debris.multimesh
	for index in DEBRIS_COUNT:
		var d := _direction(index + 19, slot.seed)
		var p := d * size * (4.0 + index % 5) * age + Vector3.DOWN * 4.9 * age * age
		p.y = maxf(0.08, p.y)
		var extent := size * (0.10 + float(index % 4) * 0.055)
		var basis := Basis.from_euler(Vector3(age * 4, float(index), age * 2.3)).scaled(Vector3(extent, extent * 0.45, extent * 1.3))
		debris.set_instance_transform(index, Transform3D(basis, p))
		debris.set_instance_color(index, Color(1, 1, 1, minf(1, maxf(0, (DURATION - age) / 0.7))))

func tick(delta: float) -> void:
	for slot: Dictionary in _slots:
		if slot.age >= DURATION: continue
		slot.age = minf(DURATION, slot.age + delta)
		if slot.age >= DURATION:
			slot.node.visible = false
			slot.light.visible = false
		else: _render_slot(slot)

func clear() -> void:
	for slot: Dictionary in _slots:
		slot.age = DURATION
		slot.node.visible = false
		slot.light.visible = false

func stats() -> Dictionary:
	var active := 0
	for slot: Dictionary in _slots:
		if slot.age < DURATION: active += 1
	return {"capacity":CAPACITY, "allocated":_slots.size(), "active":active,
		"particle_instances_per_blast":SMOKE_COUNT + SPARK_COUNT + DEBRIS_COUNT,
		"emitted":_sequence, "physical_debris_bodies":0}
