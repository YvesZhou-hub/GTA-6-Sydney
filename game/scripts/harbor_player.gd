extends CharacterBody3D

var enabled = false
var yaw = 0.0
var swimming = false
var visual: Node3D
var limbs: Array[Node3D] = []
var cycle = 0.0
var last_safe = Vector3.ZERO
var stamina = 100.0
var foot_clock = 0.0
signal footstep(water: bool)
signal landed(speed: float)

func _ready():
	name = "Resident"
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.78
	var shape = CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	var jacket = material(Color("bb714b"))
	var denim = material(Color("243e4e"))
	var skin = material(Color("d6aa84"))
	var shoe = material(Color("e2dfd1"))
	body(Vector3(0,1.19,0),Vector3(0.53,0.63,0.28),jacket,visual)
	body(Vector3(0,1.71,-0.015),Vector3(0.28,0.32,0.28),skin,visual,true)
	body(Vector3(0,1.86,0.015),Vector3(0.29,0.13,0.28),material(Color("332c29")),visual,true)
	for side in [-1,1]:
		var leg = Node3D.new()
		leg.position = Vector3(side*0.16,0.91,0)
		visual.add_child(leg)
		body(Vector3(0,-0.35,0),Vector3(0.19,0.7,0.22),denim,leg)
		body(Vector3(0,-0.8,-0.055),Vector3(0.23,0.14,0.36),shoe,leg)
		limbs.append(leg)
		var arm = Node3D.new()
		arm.position = Vector3(side*0.35,1.43,0)
		visual.add_child(arm)
		body(Vector3(0,-0.25,0),Vector3(0.17,0.5,0.21),jacket,arm)
		body(Vector3(0,-0.54,0),Vector3(0.14,0.15,0.17),skin,arm,true)
		limbs.append(arm)
	body(Vector3(0,1.31,-0.15),Vector3(0.022,0.38,0.018),material(Color("dacba5")),visual)
	body(Vector3(0,0.95,-0.01),Vector3(0.51,0.07,0.29),denim,visual)
	for eye_x in [-0.062,0.062]:
		body(Vector3(eye_x,1.75,-0.147),Vector3(0.032,0.023,0.022),material(Color("272c2d")),visual,true)
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(48)

func material(color: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m

func body(pos: Vector3,size: Vector3,mat: Material,parent:Node3D,round_form=false):
	var mesh = MeshInstance3D.new()
	if round_form:
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1
		s.radial_segments = 16
		s.rings = 8
		mesh.mesh = s
	else:
		mesh.mesh = rounded_box()
	mesh.scale = size
	mesh.position = pos
	mesh.material_override = mat
	parent.add_child(mesh)

func _physics_process(delta):
	if not enabled: return
	var direction = Input.get_vector("left","right","forward","back")
	var move = Vector3(direction.x,0,direction.y).rotated(Vector3.UP,yaw)
	swimming = global_position.y < 0.65 and not is_on_floor() and not preload("res://scripts/metro_entrances.gd").contains_dry_volume(global_position)
	var sprint = Input.is_action_pressed("sprint") and stamina > 1 and not swimming
	var target = move * (9.0 if sprint else (3.2 if swimming else 5.2))
	stamina = clampf(stamina + (-17.0 if sprint and move.length()>0 else 14.0)*delta,0,100)
	velocity.x = move_toward(velocity.x,target.x,22*delta)
	velocity.z = move_toward(velocity.z,target.z,22*delta)
	if swimming:
		velocity.y += (0.2-global_position.y)*16*delta - velocity.y*3*delta
		if Input.is_action_pressed("jump"): velocity.y = 3.8
	else:
		velocity.y -= 22*delta
		if is_on_floor():
			last_safe = global_position
			if Input.is_action_just_pressed("jump"): velocity.y = 7.5
	if is_on_floor() and move.length()>0.1 and test_move(global_transform,move.normalized()*0.38):
		var raised=global_transform
		raised.origin.y+=0.42
		if not test_move(raised,move.normalized()*0.42):
			global_position.y+=0.42
	var before = velocity.y
	move_and_slide()
	if is_on_floor() and before < -9: landed.emit(-before)
	for i in get_slide_collision_count():
		var hit = get_slide_collision(i)
		var other = hit.get_collider()
		if other is RigidBody3D:
			other.apply_central_impulse(-hit.get_normal()*minf(60,other.mass*0.35))
	if move.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y,atan2(-move.x,-move.z),delta*12)
	cycle += delta*velocity.length()*1.9
	for i in limbs.size():
		limbs[i].rotation.x = sin(cycle + (PI if i==1 or i==2 else 0))*minf(velocity.length()/13,0.65)
	visual.rotation.x = lerpf(visual.rotation.x,-0.8 if swimming else 0,delta*4)
	if move.length()>0.1 and (is_on_floor() or swimming):
		foot_clock += delta
		if foot_clock>(0.28 if sprint else 0.43):
			foot_clock=0
			footstep.emit(swimming)
	if global_position.y < -80: recover()

func recover():
	global_position = last_safe + Vector3.UP*2
	reset_physics_interpolation()
	velocity = Vector3.ZERO

func rounded_box() -> ArrayMesh:
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:
		var u=face.cross(Vector3.UP).normalized() if absf(face.y)<0.9 else Vector3.RIGHT
		var v=face.cross(u).normalized()
		for x in 5:
			for y in 5:
				var points=[]
				for corner in [Vector2(x,y),Vector2(x+1,y),Vector2(x+1,y+1),Vector2(x,y+1)]:
					points.append(face*0.5+u*(corner.x/5-0.5)+v*(corner.y/5-0.5))
				for index in [0,2,1,0,3,2]:
					var p:Vector3=points[index]
					var core=p.clamp(Vector3.ONE*-0.41,Vector3.ONE*0.41)
					var normal=(p-core).normalized()
					st.set_normal(normal)
					st.add_vertex(core+normal*0.09)
	return st.commit()
