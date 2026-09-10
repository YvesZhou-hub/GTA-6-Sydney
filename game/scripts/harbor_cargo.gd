class_name HarborCargo
extends RigidBody3D
## Persistent physical freight. A carried item is an explicit assisted load;
## releasing it restores the same rigid body and its momentum.

var stable_id: String = ""
var cargo_kind: String = "salvage"
var stored: bool = false
var carried: bool = false
var integrity: float = 1.0
var _label: Label3D
var _last_velocity := Vector3.ZERO
var _impact_cooldown: float = 0.0

func configure(object_id: String, at: Vector3, kind: String = "salvage") -> void:
	stable_id = object_id
	cargo_kind = kind
	name = object_id
	position = at
	mass = 32.0
	collision_mask = 15
	linear_damp = 0.24
	angular_damp = 0.8
	contact_monitor = true
	max_contacts_reported = 6
	continuous_cd = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.78
	physics_material_override.bounce = 0.06
	var body := BoxMesh.new()
	body.size = Vector3(0.86, 0.68, 0.7)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("85715a")
	wood.roughness = 0.86
	var mesh := MeshInstance3D.new()
	mesh.mesh = body
	mesh.material_override = wood
	add_child(mesh)
	var shape := BoxShape3D.new()
	shape.size = body.size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	var band_material := StandardMaterial3D.new()
	band_material.albedo_color = Color("263f42")
	band_material.metallic = 0.6
	band_material.roughness = 0.47
	for x in [-0.3, 0.3]:
		var band := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.055, 0.7, 0.72)
		band.mesh = box
		band.position.x = x
		band.material_override = band_material
		add_child(band)
	var decal := Label3D.new()
	decal.text = "H / L\nRECOVERY"
	decal.font_size = 32
	decal.pixel_size = 0.005
	decal.modulate = Color("e3dac2")
	decal.position = Vector3(0, 0, 0.356)
	add_child(decal)
	_label = Label3D.new()
	_label.text = "SALVAGE • 32 kg"
	_label.font_size = 24
	_label.pixel_size = 0.009
	_label.outline_size = 6
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 0.9
	_label.modulate = Color("e9ca8b")
	_label.no_depth_test = false
	add_child(_label)

func set_carried(value: bool) -> void:
	carried = value
	stored = false
	freeze = value
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	collision_layer = 0 if value else 1
	collision_mask = 0 if value else 15
	if value:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	else:
		sleeping = false

func stow(at: Vector3) -> void:
	set_carried(false)
	stored = true
	freeze = true
	global_position = at
	rotation = Vector3.ZERO

func update_visibility(player_pos: Vector3) -> void:
	if is_instance_valid(_label):
		_label.visible = not carried and global_position.distance_to(player_pos) < 15.0

func _physics_process(delta: float) -> void:
	if freeze:
		return
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	if get_contact_count() > 0 and _impact_cooldown <= 0.0:
		var impact := (_last_velocity - linear_velocity).length()
		if impact > 6.0:
			integrity = maxf(0.15, integrity - (impact - 6.0) * 0.008)
			_impact_cooldown = 0.5
	_last_velocity = linear_velocity
	# The porous timber crate floats with its centre just below the sea surface.
	if global_position.y < 0.35:
		var submersion := clampf((0.35 - global_position.y) / 0.7, 0.0, 1.0)
		apply_central_force(Vector3.UP * mass * 9.81 * submersion * 1.9)
		apply_central_force(-linear_velocity * mass * submersion * 1.1)
		apply_torque(-angular_velocity * mass * submersion * 0.7)
	# Lost items have a recoverable state; never silently destroy them.
	if global_position.y < -100.0:
		freeze = true

func get_state() -> Dictionary:
	return {"id": stable_id, "kind": cargo_kind, "position": _vec(global_position),
		"rotation": _vec(rotation), "velocity": _vec(linear_velocity),
		"angular_velocity": _vec(angular_velocity), "integrity": integrity,
		"stored": stored, "carried": carried}

func apply_state(state: Dictionary) -> void:
	global_position = _read_vec(state.get("position", []), global_position)
	rotation = _read_vec(state.get("rotation", []), Vector3.ZERO)
	linear_velocity = _read_vec(state.get("velocity", []), Vector3.ZERO)
	angular_velocity = _read_vec(state.get("angular_velocity", []), Vector3.ZERO)
	integrity = clampf(float(state.get("integrity", 1.0)), 0.15, 1.0)
	stored = bool(state.get("stored", false))
	carried = bool(state.get("carried", false))
	freeze = stored or carried
	collision_layer = 0 if carried else 1
	collision_mask = 0 if carried else 15

func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _read_vec(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback
