extends CharacterBody3D
## Enemy intent lives here; the director owns target damage, rewards and wave state.
signal defeated(enemy, reward: int)
signal attack_requested(enemy, damage: float, attack_range: float)

const Model = preload("res://scripts/nailong_model.gd")
const FontSet = preload("res://scripts/ui_fonts.gd")
const TYPES := {
	"roamer":{"label":"游荡奶龙","hp":80.0,"speed":2.8,"damage":8.0,"range":2.0,"cooldown":1.5,"windup":.65,"reward":120,"scale":1.0},
	"runner":{"label":"疾跑奶龙","hp":60.0,"speed":6.2,"damage":7.0,"range":2.0,"cooldown":1.3,"windup":.65,"reward":160,"scale":.85},
	"brute":{"label":"重装奶龙","hp":360.0,"speed":2.2,"damage":22.0,"range":3.0,"cooldown":2.2,"windup":1.3,"reward":480,"scale":1.45},
	"spitter":{"label":"喷吐奶龙","hp":110.0,"speed":2.7,"damage":12.0,"range":22.0,"cooldown":2.5,"windup":1.0,"reward":240,"scale":1.0},
	"alpha":{"label":"首领奶龙","hp":700.0,"speed":3.5,"damage":28.0,"range":4.0,"cooldown":2.5,"windup":1.5,"reward":1200,"scale":1.9}
}
var enemy_type: String = "roamer"
var level: int = 1
var health: float = 80.0
var max_health: float = 80.0
var dead: bool = false
var target: Node3D
var state: String = "idle"
var spec: Dictionary = {}
var _configured := false
var _parts: Dictionary = {}
var _model_holder: Node3D
var _collision: CollisionShape3D
var _label: Label3D
var _bar: Node3D
var _bar_fill: MeshInstance3D
var _warning: MeshInstance3D
var _cooldown := .7
var _windup_left := 0.0
var _sensing_left := 0.0
var _hurt_left := 0.0
var _death_left := .65
var _stride := 0.0
var _line_clear := false
var _steering := Vector3.ZERO
var _avoid_side := 1.0
var _body_scale := 1.0
var _shape_target_id: int = 0
var _target_shapes: Array[CollisionShape3D] = []
var _shape_bounds: Dictionary = {}

func configure(type: String, level: int = 1) -> void:
	# A configured enemy has one identity and one health/reward lifecycle.
	if _configured: return
	enemy_type = type if TYPES.has(type) else "roamer"
	self.level = clampi(level,1,10)
	spec = TYPES[enemy_type].duplicate()
	var progression := float(self.level-1)
	spec.hp = float(spec.hp)*(1.0+.18*progression)
	spec.damage = float(spec.damage)*(1.0+.06*progression)
	spec.reward = roundi(float(spec.reward)*(1.0+.4*progression))
	health = float(spec.hp)
	max_health = health
	_body_scale = float(spec.scale)
	_configured = true
	collision_layer = 16
	collision_mask = 1|4
	floor_snap_length = .65
	floor_max_angle = deg_to_rad(48)
	set_meta("enemy",true)
	set_meta("enemy_type",enemy_type)
	set_meta("enemy_level",self.level)
	_collision = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .59*_body_scale
	capsule.height = 2.43*_body_scale
	_collision.shape = capsule
	_collision.position.y = capsule.height*.5
	add_child(_collision)
	_model_holder = Node3D.new()
	_model_holder.scale = Vector3.ONE*_body_scale
	add_child(_model_holder)
	_parts = Model.build(_model_holder,enemy_type)
	_warning = Model.warning_ring(self)
	_label = Label3D.new()
	_label.name = "EnemyName"
	_label.text = _label_text()
	_label.font = FontSet.regular()
	_label.font_size = 32
	_label.outline_size = 7
	_label.pixel_size = .009
	_label.position.y = 2.9*_body_scale+.24
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color("fff2c6")
	add_child(_label)
	_bar = Node3D.new()
	_bar.position.y = 2.67*_body_scale
	add_child(_bar)
	for is_health in [false,true]:
		var part := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.15 if is_health else 1.22,.08 if is_health else .12,.035 if is_health else .03)
		part.mesh = box
		part.material_override = Model.bar_material(is_health)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if is_health: part.position.z = -.022; _bar_fill = part
		_bar.add_child(part)

func _label_text() -> String:
	var action := " · 重击蓄力" if enemy_type=="alpha" and state=="windup" else ""
	return "Lv.%d %s%s\n击败 +%d 金币" % [level,str(spec.label),action,int(spec.reward)]

func _ready() -> void:
	if not _configured: configure("roamer")
	add_to_group("nailong_enemies")
	_avoid_side = 1.0 if get_instance_id()%2==0 else -1.0
	_sensing_left = float(get_instance_id()%13)*.015

func set_target(value: Node3D) -> void:
	target = value
	_shape_target_id = 0
	_target_shapes.clear()
	_sensing_left = 0.0
	_line_clear = false
	if not is_instance_valid(target):
		_windup_left = 0.0
		state = "idle"

func take_damage(amount: float, hit_position: Vector3 = Vector3.ZERO) -> float:
	if dead or not is_finite(amount) or amount<=0.0: return 0.0
	var actual := minf(health,amount)
	health -= actual
	_hurt_left = .18
	set_meta("last_hit_position",hit_position)
	if health<=0.0:
		dead = true
		state = "dead"
		_windup_left = 0.0
		velocity = Vector3.ZERO
		collision_layer = 0
		collision_mask = 0
		_collision.set_deferred("disabled",true)
		_warning.visible = false
		_label.visible = false
		_bar.visible = false
		# Set dead before signaling: synchronous listeners cannot award twice.
		defeated.emit(self,int(spec.reward))
	return actual

func _collect_target_shapes(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CollisionShape3D:
			_target_shapes.append(child)
		elif not child is CollisionObject3D:
			_collect_target_shapes(child)

func _nearest_shape_point(shape: Shape3D, point: Vector3) -> Vector3:
	if shape is BoxShape3D:
		var half: Vector3 = shape.size*.5
		return point.clamp(-half,half)
	if shape is SphereShape3D:
		return point.limit_length(shape.radius)
	if shape is CapsuleShape3D:
		var segment_half: float = maxf(0.0,shape.height*.5-shape.radius)
		var center := Vector3(0,clampf(point.y,-segment_half,segment_half),0)
		return center+(point-center).limit_length(shape.radius)
	if shape is CylinderShape3D:
		var circle := Vector2(point.x,point.z).limit_length(shape.radius)
		return Vector3(circle.x,clampf(point.y,-shape.height*.5,shape.height*.5),circle.y)
	var id := shape.get_instance_id()
	if not _shape_bounds.has(id): _shape_bounds[id] = shape.get_debug_mesh().get_aabb()
	var bounds: AABB = _shape_bounds[id]
	return point.clamp(bounds.position,bounds.end)

func target_surface_point(value: Node3D = null) -> Vector3:
	var destination := value if is_instance_valid(value) else target
	if not is_instance_valid(destination): return global_position
	var aim := destination.global_position+Vector3.UP*.85
	if not destination is RigidBody3D: return aim
	if _shape_target_id!=destination.get_instance_id():
		_shape_target_id = destination.get_instance_id()
		_target_shapes.clear()
		_collect_target_shapes(destination)
	var eye := global_position+Vector3.UP*(1.65*_body_scale)
	var best_distance := INF
	for collision: CollisionShape3D in _target_shapes:
		if not is_instance_valid(collision) or collision.disabled or collision.shape==null: continue
		var candidate := collision.to_global(_nearest_shape_point(collision.shape,collision.to_local(eye)))
		var distance := eye.distance_squared_to(candidate)
		if distance<best_distance:
			best_distance = distance
			aim = candidate
	return aim

func distance_to_target_surface(value: Node3D = null) -> float:
	var destination := value if is_instance_valid(value) else target
	if not is_instance_valid(destination): return INF
	if not destination is RigidBody3D: return global_position.distance_to(destination.global_position)
	return (global_position+Vector3.UP*(1.65*_body_scale)).distance_to(target_surface_point(destination))

func has_line_of_sight(value: Node3D = null) -> bool:
	var destination := value if is_instance_valid(value) else target
	if not is_inside_tree() or not is_instance_valid(destination) or not destination.is_inside_tree(): return false
	var eye := global_position+Vector3.UP*(1.65*_body_scale)
	var aim := target_surface_point(destination)
	var query := PhysicsRayQueryParameters3D.create(eye,aim,1|4,[get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return true
	var collider: Object = hit.collider
	return collider==destination or (collider is Node and destination.is_ancestor_of(collider))

func _choose_direction(wanted: Vector3) -> Vector3:
	if wanted.length_squared()<.01: return Vector3.ZERO
	var look_ahead := maxf(1.1,float(spec.speed)*.38)
	if not test_move(global_transform,wanted*look_ahead): return wanted
	var result := Vector3.ZERO
	var best := -10.0
	for angle in [.65,1.15,1.57,2.1,2.7]:
		for side in [_avoid_side,-_avoid_side]:
			var candidate := wanted.rotated(Vector3.UP,angle*side)
			if test_move(global_transform,candidate*look_ahead): continue
			var score := candidate.dot(wanted)+(.12 if side==_avoid_side else 0.0)
			if score>best: best=score; result=candidate
	return result

func _attack_allowed(distance: float) -> bool:
	return distance<=float(spec.range) and _line_clear and is_on_floor()

func _physics_process(delta: float) -> void:
	if not _configured: return
	if dead:
		_death_left = maxf(0.0,_death_left-delta)
		Model.animate(_parts,_stride,0,0,0,1.0-_death_left/.65)
		if _death_left<=0.0: queue_free()
		return
	_hurt_left = maxf(0,_hurt_left-delta)
	_cooldown = maxf(0,_cooldown-delta)
	_sensing_left -= delta
	var has_target := is_instance_valid(target) and target.is_inside_tree()
	var offset := target.global_position-global_position if has_target else Vector3.ZERO
	var distance := distance_to_target_surface() if has_target else INF
	var flat := Vector3(offset.x,0,offset.z)
	var wanted := flat.normalized() if flat.length_squared()>.01 else Vector3.ZERO
	if has_target and distance<260.0:
		if _sensing_left<=0.0:
			_sensing_left = .19
			_line_clear = has_line_of_sight()
			_steering = _choose_direction(wanted)
		if wanted.length_squared()>.01:
			_model_holder.rotation.y = lerp_angle(_model_holder.rotation.y,atan2(-wanted.x,-wanted.z),minf(1.0,delta*6.0))
		if _windup_left>0.0:
			state = "windup"
			_windup_left = maxf(0.0,_windup_left-delta)
			if _windup_left<=0.0:
				_cooldown = float(spec.cooldown)
				# A moved target or newly inserted wall cancels the strike.
				_line_clear = has_line_of_sight()
				if _attack_allowed(distance): attack_requested.emit(self,float(spec.damage),float(spec.range))
				if dead: return
		elif _cooldown<=0.0 and _attack_allowed(distance):
			_windup_left = float(spec.windup)
			state = "windup"
		else:
			state = "chase"
	else:
		state = "idle"
		_steering = Vector3.ZERO
		_windup_left = 0.0
	var movement := _steering if state=="chase" else Vector3.ZERO
	if enemy_type=="spitter" and _line_clear and distance<16.0: movement=Vector3.ZERO
	if distance<float(spec.range)*.84 and _line_clear: movement=Vector3.ZERO
	velocity.x = move_toward(velocity.x,movement.x*float(spec.speed),delta*15)
	velocity.z = move_toward(velocity.z,movement.z*float(spec.speed),delta*15)
	velocity.y = -.5 if is_on_floor() else maxf(-45.0,velocity.y-22.0*delta)
	move_and_slide()
	# A tiny stair is climbed only after physical clearance and floor probes succeed.
	if state=="chase" and is_on_floor() and get_slide_collision_count()>0 and movement.length_squared()>.01:
		var raised := global_transform
		raised.origin.y += .30
		if test_move(global_transform,movement*.18) and not test_move(global_transform,Vector3.UP*.30) and not test_move(raised,movement*.28):
			var landing := raised
			landing.origin += movement*.25
			if test_move(landing,Vector3.DOWN*.36):
				global_position.y += .30
				reset_physics_interpolation()
	var planar := Vector2(velocity.x,velocity.z).length()
	_stride += delta*planar*4.0
	var windup := 1.0-_windup_left/float(spec.windup) if _windup_left>0 else 0.0
	Model.animate(_parts,_stride,planar,windup,_hurt_left/.18,0)
	_warning.visible = _windup_left>0.0
	var warning_range: float = float(spec.range) if enemy_type=="alpha" else minf(float(spec.range),3.6)
	var radius := warning_range*(.82+.18*windup)
	_warning.scale = Vector3(radius,1,radius)
	_label.visible = distance<45.0
	_bar.visible = distance<45.0
	_label.modulate = Color("ff8062") if state=="windup" else Color("fff2c6")
	var text := _label_text()
	if _label.text!=text: _label.text=text
	_bar_fill.scale.x = maxf(.001,health/max_health)
	_bar_fill.position.x = -.575*(1.0-health/max_health)
	var camera := get_viewport().get_camera_3d()
	if camera!=null:
		_bar.rotation.y = atan2(camera.global_position.x-global_position.x,camera.global_position.z-global_position.z)

func snapshot() -> Dictionary:
	return {"type":enemy_type,"level":level,"label":str(spec.get("label","游荡奶龙")),"health":health,"max_health":max_health,"damage":float(spec.get("damage",8.0)),"speed":float(spec.get("speed",2.8)),"dead":dead,"state":state,"attack_range":float(spec.get("range",2.0)),"reward":int(spec.get("reward",120)),"position":[global_position.x,global_position.y,global_position.z],"windup_remaining":_windup_left,"cooldown_remaining":_cooldown,"line_of_sight":_line_clear}
