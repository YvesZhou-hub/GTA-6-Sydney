extends RefCounted
## Original, metre-scale vehicle assets. All geometry is authored procedurally here.
## Local forward = -Z, local up = +Y. No external textures, brands, or models.

static func make(kind: String, id: String) -> RigidBody3D:
	var body: RigidBody3D = load("res://scripts/harbor_vehicle.gd").new()
	body.configure(kind, id)
	return body

static func material(color: Color, metal: float = 0.0, roughness: float = 0.45) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = roughness
	return m

static func build(body: Node3D, kind: String) -> Dictionary:
	var mats := {
		"white": material(Color("e6e9e1"), 0.35, 0.26),
		"dark": material(Color("14212c"), 0.50, 0.32),
		"rubber": material(Color("11161c"), 0.0, 0.92),
		"metal": material(Color("9cabb6"), 0.83, 0.24),
		"glass": material(Color("1c495e"), 0.62, 0.13),
		"orange": material(Color("ef874b"), 0.3, 0.3),
		"teal": material(Color("287b89"), 0.47, 0.26),
		"red": material(Color("d94f46"), 0.20, 0.32),
		"wood": material(Color("ba9162"), 0.0, 0.74),
		"light": material(Color("e8f3db"), 0.1, 0.18),
		"blue": material(Color("456884"), 0.42, 0.3),
		"cloth": material(Color("e49b51"), 0.0, 0.83),
	}
	mats.light.emission_enabled = true
	mats.light.emission = Color("dfefc0")
	mats.light.emission_energy_multiplier = 1.5
	var moving: Dictionary = {"wheels": [], "rotors": [], "propellers": [], "rider": null, "material": mats.teal}
	match kind:
		"car": _car(body, mats, moving)
		"motorcycle": _motorcycle(body, mats, moving)
		"yacht": _yacht(body, mats, moving)
		"paraglider": _paraglider(body, mats, moving)
		"glider": _glider(body, mats, moving)
		"helicopter": _helicopter(body, mats, moving)
		"airliner": _airliner(body, mats, moving)
	if kind in ["motorcycle", "paraglider"]:
		moving.rider = _seated_rider(body, mats, kind)
	var animated: Array = moving.wheels + moving.rotors + moving.propellers
	if moving.rider != null: animated.append(moving.rider)
	for pivot in animated:
		_merge_static_meshes(pivot, [])
	_merge_static_meshes(body, animated)
	return moving

static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.rotation = rot
	parent.add_child(node)
	return node

static func _ellipsoid(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	node.mesh = mesh
	node.material_override = mat
	node.scale = size
	node.position = pos
	parent.add_child(node)
	return node

static func _cylinder(parent: Node3D, radius: float, length: float, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, top_radius: float = -1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 24
	node.mesh = mesh
	node.position = pos
	node.rotation = rot
	node.material_override = mat
	parent.add_child(node)
	return node

static func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var rod := _cylinder(parent, radius, a.distance_to(b), (a+b)*0.5, mat)
	rod.quaternion = Quaternion(Vector3.UP, (b-a).normalized())
	return rod

static func _box_collision(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = pos
	collision.rotation = rot
	parent.add_child(collision)

static func _sphere_collision(parent: Node3D, radius: float, pos: Vector3) -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = pos
	parent.add_child(collision)

static func _hull(parent: Node3D, stations: Array, mat: Material, segments: int = 24, collision: bool = false) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	var points: Array[Vector3] = []
	for s in stations:
		for j in segments:
			var angle: float = float(j) / segments * TAU
			points.append(Vector3(cos(angle)*s[1], sin(angle)*s[2]+s[3], s[0]))
	for i in stations.size()-1:
		for j in segments:
			var a: int = i*segments+j
			var b: int = i*segments+(j+1)%segments
			var c: int = (i+1)*segments+j
			var d: int = (i+1)*segments+(j+1)%segments
			for idx in [a,c,b,b,c,d]:
				surface.add_vertex(points[idx])
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = mat
	parent.add_child(node)
	if collision:
		var cshape := CollisionShape3D.new()
		var convex := ConvexPolygonShape3D.new()
		convex.points = PackedVector3Array(points)
		cshape.shape = convex
		parent.add_child(cshape)
	return node

static func _prism(parent: Node3D, outline: Array[Vector3], thickness: float, mat: Material, collision: bool = false) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := PackedVector3Array()
	for point in outline:
		points.append(point + Vector3.UP*thickness*0.5)
	for point in outline:
		points.append(point - Vector3.UP*thickness*0.5)
	var n: int = outline.size()
	for i in range(1,n-1):
		for idx in [0,i,i+1,n,n+i+1,n+i]:
			surface.add_vertex(points[idx])
	for i in n:
		var j := (i+1)%n
		for idx in [i,n+i,j,j,n+i,n+j]:
			surface.add_vertex(points[idx])
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = mat
	parent.add_child(node)
	if collision:
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var col := CollisionShape3D.new()
		col.shape = shape
		parent.add_child(col)
	return node

static func _wheel(parent: Node3D, pos: Vector3, radius: float, width: float, m: Dictionary, moving: Dictionary, collision: bool = true) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	_cylinder(pivot,radius,width,Vector3.ZERO,m.rubber,Vector3(0,0,PI/2))
	for side in [-1,1]:
		_cylinder(pivot,radius*0.63,0.024,Vector3(side*(width/2+0.005),0,0),m.metal,Vector3(0,0,PI/2))
		_cylinder(pivot,radius*0.20,0.03,Vector3(side*(width/2+0.02),0,0),m.dark,Vector3(0,0,PI/2))
		for i in 6:
			var angle := i*TAU/6
			_rod(pivot,Vector3(side*(width/2+0.027),0,0),Vector3(side*(width/2+0.027),sin(angle)*radius*0.57,cos(angle)*radius*0.57),0.025,m.dark)
	moving.wheels.append(pivot)
	if collision:
		_sphere_collision(parent,radius*0.95,pos)

static func _car(b: Node3D,m:Dictionary,v:Dictionary) -> void:
	_hull(b,[[-2.4,0.5,0.15,0],[-2.05,0.91,0.32,0],[1.95,0.94,0.32,0],[2.3,0.55,0.22,0]],m.teal,16)
	_box(b,Vector3(1.94,0.29,4.25),Vector3(0,-0.08,0),m.teal)
	_hull(b,[[-1.19,0.79,0.01,0.25],[-0.65,0.70,0.50,0.37],[0.8,0.72,0.48,0.37],[1.42,0.83,0.03,0.25]],m.glass,12)
	_box(b,Vector3(1.44,0.07,1.4),Vector3(0,0.87,0.12),m.teal)
	for s in [-1,1]:
		for z in [-0.62,0.79]:
			_rod(b,Vector3(s*0.74,0.83,z),Vector3(s*0.88,0.2,z*1.45),0.045,m.teal)
		_box(b,Vector3(0.035,0.58,0.07),Vector3(s*0.80,0.50,0.15),m.dark)
		_box(b,Vector3(0.03,0.055,0.3),Vector3(s*0.98,0.2,0.53),m.metal)
		_box(b,Vector3(0.24,0.14,0.28),Vector3(s*1.02,0.42,-0.69),m.teal)
		_box(b,Vector3(0.58,0.105,0.07),Vector3(s*0.55,0.1,-2.21),m.light)
		_box(b,Vector3(0.6,0.1,0.07),Vector3(s*0.56,0.15,2.19),m.red)
		for z in [-1.47,1.42]:
			_wheel(b,Vector3(s*0.98,-0.30,z),0.40,0.26,m,v)
		_box(b,Vector3(0.12,0.10,3.8),Vector3(s*0.98,-0.22,0),m.dark)
	_box(b,Vector3(1.3,0.19,0.08),Vector3(0,-0.12,-2.28),m.dark)
	for x in 9:
		_box(b,Vector3(0.025,0.15,0.035),Vector3((x-4)*0.13,-0.12,-2.33),m.metal)
	_box(b,Vector3(1.78,0.055,0.3),Vector3(0,0.37,2.03),m.dark)
	_box_collision(b,Vector3(1.85,0.55,4.35),Vector3(0,0,0))
	_box_collision(b,Vector3(1.42,0.6,1.78),Vector3(0,0.57,0.05))

static func _motorcycle(b:Node3D,m:Dictionary,v:Dictionary) -> void:
	for z in [-1.05,1.0]:
		_wheel(b,Vector3(0,-0.34,z),0.40,0.22,m,v)
		for x in [-0.16,0.16]:
			_rod(b,Vector3(x,-0.34,z),Vector3(x,0.46,z*0.57),0.048,m.metal)
	_rod(b,Vector3(0,-0.15,-0.65),Vector3(0,0.44,0.55),0.095,m.dark)
	_rod(b,Vector3(0,-0.15,0.68),Vector3(0,0.43,-0.45),0.075,m.teal)
	_ellipsoid(b,Vector3(0.3,0.25,0.44),Vector3(0,0.37,-0.22),m.orange)
	_box(b,Vector3(0.42,0.12,0.72),Vector3(0,0.46,0.40),m.rubber)
	_box(b,Vector3(0.4,0.32,0.47),Vector3(0,-0.01,0.02),m.metal)
	for y in 5:
		_box(b,Vector3(0.46,0.018,0.43),Vector3(0,-0.13+y*0.058,0.02),m.dark)
	_rod(b,Vector3(-0.40,0.68,-0.68),Vector3(0.4,0.68,-0.68),0.04,m.dark)
	_cylinder(b,0.16,0.13,Vector3(0,0.52,-0.92),m.light,Vector3(PI/2,0,0))
	_box(b,Vector3(0.16,0.07,0.05),Vector3(0,0.4,0.93),m.red)
	_rod(b,Vector3(0.28,-0.17,0),Vector3(0.28,-0.13,0.90),0.09,m.metal)
	for side in [-1,1]:
		_rod(b,Vector3(side*0.3,0.66,-0.68),Vector3(side*0.39,0.97,-0.72),0.018,m.metal)
		_ellipsoid(b,Vector3(0.11,0.07,0.03),Vector3(side*0.39,0.98,-0.72),m.glass)
	_box_collision(b,Vector3(0.55,0.85,1.9),Vector3(0,0.18,0))

static func _yacht(b:Node3D,m:Dictionary,v:Dictionary) -> void:
	_hull(b,[[-7.3,0.03,0.25,0.0],[-5.5,1.75,0.95,-0.08],[-1.8,2.65,1.04,-0.18],[5.8,2.65,0.84,-0.13],[6.5,2.38,0.52,0.0]],m.white,24,true)
	_box(b,Vector3(5.06,0.14,10.4),Vector3(0,0.72,0.4),m.wood)
	for i in 16:
		_box(b,Vector3(0.028,0.012,10.3),Vector3((i-7.5)*0.3,0.80,0.4),m.dark)
	_box(b,Vector3(3.48,1.72,4.2),Vector3(0,1.66,-1.5),m.white)
	_box(b,Vector3(3.58,0.75,3.45),Vector3(0,2.00,-1.74),m.glass)
	_box(b,Vector3(3.9,0.19,4.4),Vector3(0,2.65,-1.50),m.white)
	_box(b,Vector3(1.4,0.09,1.4),Vector3(0,2.80,-1.4),m.dark)
	_box(b,Vector3(4.2,0.3,1.15),Vector3(0,1.0,4.75),m.white)
	for s in [-1,1]:
		_box(b,Vector3(0.61,0.51,2.45),Vector3(s*1.95,1.06,2.55),m.white)
		_box(b,Vector3(0.64,0.18,2.48),Vector3(s*1.95,1.40,2.55),m.blue)
		for z in [-4.7,-3,-1,1,3,5.6]:
			_rod(b,Vector3(s*2.5,0.80,z),Vector3(s*2.5,1.6,z),0.035,m.metal)
		_rod(b,Vector3(s*2.5,1.6,-4.7),Vector3(s*2.5,1.6,5.6),0.045,m.metal)
		_rod(b,Vector3(s*2.5,1.6,-4.7),Vector3(0,1.8,-6.9),0.045,m.metal)
		for z in [-4.2,-3,-1.8,-0.6,0.6]:
			_cylinder(b,0.19,0.04,Vector3(s*2.57,-0.12,z),m.glass,Vector3(0,0,PI/2))
		_cylinder(b,0.16,0.56,Vector3(s*2.58,0.54,4.8),m.dark)
	_rod(b,Vector3(0,2.8,-0.6),Vector3(0,4.2,-0.6),0.07,m.metal)
	_box(b,Vector3(1.5,0.16,0.23),Vector3(0,4.02,-0.6),m.white)
	_box(b,Vector3(4.8,0.22,1.0),Vector3(0,0.37,6.6),m.wood)
	_box_collision(b,Vector3(5.05,0.24,10.9),Vector3(0,0.71,0.2))
	_box_collision(b,Vector3(3.55,1.9,4.3),Vector3(0,1.75,-1.5))
	_box_collision(b,Vector3(4.8,0.22,1.0),Vector3(0,0.37,6.6))

static func _paraglider(b:Node3D,m:Dictionary,v:Dictionary) -> void:
	for i in 18:
		var x: float = (i-8.5)*0.46
		var y: float = 3.9 - pow(absf(x)/4.6,2)*1.85
		var z: float = pow(absf(x)/4.6,2)*0.55
		var panel := _ellipsoid(b,Vector3(0.29,0.18,1.35),Vector3(x,y,z),m.cloth if i%4<2 else m.white)
		panel.rotation.z = -x*0.12
		if i%3 == 0:
			for fore in [-0.75,0.75]:
				_rod(b,Vector3(x,y-0.05,z+fore),Vector3(signf(x)*0.3,0.2,0.2),0.012,m.dark)
	_box(b,Vector3(0.56,0.5,0.65),Vector3(0,-0.1,0.16),m.dark)
	_box(b,Vector3(0.6,0.2,0.35),Vector3(0,-0.4,-0.25),m.orange)
	for side in [-1,1]:
		_rod(b,Vector3(side*0.3,0,0.2),Vector3(side*0.55,0.67,-0.32),0.034,m.metal)
	_sphere_collision(b,0.48,Vector3(0,-0.15,0))

static func _glider(b:Node3D,m:Dictionary,v:Dictionary) -> void:
	_hull(b,[[-3.8,0.02,0.02,0],[-2.7,0.47,0.51,0.03],[-0.7,0.44,0.48,0.03],[3.8,0.11,0.16,0.03],[4.5,0.04,0.07,0.08]],m.white,24,true)
	_ellipsoid(b,Vector3(0.40,0.36,1.04),Vector3(0,0.39,-1.79),m.glass)
	for side in [-1,1]:
		var s: float = side
		_prism(b,[Vector3(s*0.35,0.0,-0.4),Vector3(s*8.0,0.32,0.15),Vector3(s*8.9,0.65,0.65),Vector3(s*8.25,0.35,0.88),Vector3(s*0.35,0.0,0.95)],0.10,m.white,true)
		_box(b,Vector3(1.4,0.018,0.09),Vector3(s*6.9,0.34,0.53),m.teal)
		_prism(b,[Vector3(s*0.05,0.54,3.35),Vector3(s*1.8,0.58,4.15),Vector3(s*1.75,0.58,4.55),Vector3(s*0.05,0.54,4.1)],0.075,m.teal)
	_box(b,Vector3(0.10,1.42,1.04),Vector3(0,0.60,3.78),m.teal,Vector3(-0.3,0,0))
	_wheel(b,Vector3(0,-0.46,-0.25),0.21,0.16,m,v)

static func _helicopter(b:Node3D,m:Dictionary,v:Dictionary) -> void:
	_hull(b,[[-3.1,0.03,0.1,0],[-2.3,0.93,0.85,0],[0.65,1.13,1.08,0],[1.75,0.61,0.57,0.12],[6.5,0.13,0.16,0.63]],m.orange,24,true)
	_ellipsoid(b,Vector3(0.89,0.76,1.00),Vector3(0,-0.02,-1.94),m.glass)
	for side in [-1,1]:
		_box(b,Vector3(0.045,0.81,1.22),Vector3(side*1.04,0.22,-0.30),m.glass)
		_box(b,Vector3(0.06,0.52,1.34),Vector3(side*1.00,-0.49,-0.3),m.orange)
		_box(b,Vector3(0.045,0.065,0.26),Vector3(side*1.07,-0.16,-0.28),m.metal)
		_rod(b,Vector3(side*0.68,-0.61,-1.32),Vector3(side*1.39,-1.32,-1.32),0.07,m.metal)
		_rod(b,Vector3(side*0.68,-0.61,0.94),Vector3(side*1.39,-1.32,0.94),0.07,m.metal)
		_rod(b,Vector3(side*1.39,-1.32,-2.01),Vector3(side*1.39,-1.32,1.83),0.105,m.dark)
		_box_collision(b,Vector3(0.20,0.18,3.7),Vector3(side*1.39,-1.32,0))
	_cylinder(b,0.44,0.63,Vector3(0,1.08,0.25),m.dark)
	_cylinder(b,0.13,0.77,Vector3(0,1.58,0.25),m.metal)
	var rotor := Node3D.new()
	rotor.position = Vector3(0,1.97,0.25)
	b.add_child(rotor)
	for i in 4:
		var blade := _box(rotor,Vector3(5.4,0.065,0.32),Vector3.ZERO,m.dark)
		blade.rotation.y = i*TAU/4
		blade.position = Vector3(cos(i*TAU/4)*2.5,0,sin(i*TAU/4)*2.5)
	v.rotors.append(rotor)
	_box(b,Vector3(0.13,1.95,1.32),Vector3(0,1.23,5.80),m.orange,Vector3(-0.3,0,0))
	_box(b,Vector3(2.5,0.075,0.52),Vector3(0,0.72,4.8),m.white)
	var tail := Node3D.new()
	tail.position = Vector3(-0.3,1.02,5.87)
	b.add_child(tail)
	for i in 3:
		_box(tail,Vector3(0.05,2.08,0.13),Vector3.ZERO,m.dark,Vector3(i*PI/3,0,0))
	v.propellers.append(tail)

static func _airliner(b:Node3D,m:Dictionary,v:Dictionary) -> void:
	_hull(b,[[-30.5,0.06,0.08,0],[-28.6,1.4,1.30,0.14],[-24.5,2.75,2.73,0],[-18.0,2.9,2.95,0],[15.8,2.9,2.95,0],[23.0,1.55,1.75,0.40],[29.0,0.20,0.33,1.35],[30.0,0.04,0.04,1.55]],m.white,40,true)
	for side in [-1,1]:
		var s: float = side
		_prism(b,[Vector3(s*2.1,-0.2,-6.8),Vector3(s*25.7,1.05,5.8),Vector3(s*29.8,3.28,10.2),Vector3(s*26.2,1.25,11.4),Vector3(s*2.1,-0.1,7.6)],0.48,m.white,true)
		_prism(b,[Vector3(s*4.0,0.14,4.9),Vector3(s*22.5,1.05,9.0),Vector3(s*23.4,1.07,10.25),Vector3(s*4.0,0.14,7.2)],0.08,m.metal)
		_prism(b,[Vector3(s*1.3,1.2,21.3),Vector3(s*10.8,2.5,25.5),Vector3(s*11.0,2.5,28.0),Vector3(s*1.3,1.2,25.2)],0.25,m.white,true)
		_box(b,Vector3(0.25,2.45,0.18),Vector3(s*28.6,2.62,9.54),m.teal,Vector3(0,0,s*0.72))
		# 787-class scale, independently designed twin underwing turbofans.
		var engine := Node3D.new()
		engine.position = Vector3(s*8.35,-2.03,-3.22)
		b.add_child(engine)
		_hull(engine,[[-3.2,1.18,1.18,0],[-2.8,1.56,1.56,0],[1.1,1.52,1.52,0],[2.9,0.87,0.87,0]],m.white,32)
		_cylinder(engine,1.24,0.15,Vector3(0,0,-3.19),m.dark,Vector3(PI/2,0,0))
		_cylinder(engine,0.99,0.09,Vector3(0,0,-3.30),m.metal,Vector3(PI/2,0,0))
		_cylinder(engine,0.30,0.36,Vector3(0,0,-3.41),m.dark,Vector3(PI/2,0,0),0.03)
		var fan := Node3D.new()
		fan.position = Vector3(0,0,-3.37)
		engine.add_child(fan)
		for i in 18:
			_box(fan,Vector3(0.85,0.065,0.045),Vector3(cos(i*TAU/18)*0.66,sin(i*TAU/18)*0.66,0),m.dark,Vector3(0,0,i*TAU/18+0.45))
		v.propellers.append(fan)
		_box(b,Vector3(0.56,2.6,3.1),Vector3(s*8.35,-0.78,-0.4),m.metal,Vector3(-0.25,0,0))
		_sphere_collision(b,1.5,Vector3(s*8.35,-2.03,-3.2))
		for i in 42:
			var z := -21.6 + i*0.86
			_box(b,Vector3(0.038,0.46,0.26),Vector3(s*2.87,0.75,z),m.glass)
		for z in [-20.4,-6.4,9.8,17.8]:
			_box(b,Vector3(0.075,1.9,0.90),Vector3(s*2.89,0.2,z),m.metal)
			_box(b,Vector3(0.081,1.73,0.72),Vector3(s*2.90,0.2,z),m.white)
			_box(b,Vector3(0.086,0.38,0.23),Vector3(s*2.91,0.62,z),m.glass)
		_box(b,Vector3(0.040,0.17,33.4),Vector3(s*2.85,-0.71,-3.9),m.teal)
		for z in [1.0,2.5]:
			_wheel(b,Vector3(s*3.5,-3.63,z),0.61,0.41,m,v)
		_rod(b,Vector3(s*3.5,-3.5,1.8),Vector3(s*3.3,-0.7,1.8),0.17,m.metal)
		_box(b,Vector3(0.19,0.13,0.22),Vector3(s*29.45,3.0,10.0),m.red if side<0 else m.light)
	# Swept vertical fin is a proper volume with its own collision.
	var fin_mesh := SurfaceTool.new()
	fin_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fin_points := [Vector3(-0.18,1.0,17.0),Vector3(-0.12,12.1,25.0),Vector3(-0.10,12.1,28.9),Vector3(-0.18,1.0,27.1),Vector3(0.18,1.0,17.0),Vector3(0.12,12.1,25.0),Vector3(0.10,12.1,28.9),Vector3(0.18,1.0,27.1)]
	for idx in [0,1,2,0,2,3,4,6,5,4,7,6,0,4,5,0,5,1,1,5,6,1,6,2,2,6,7,2,7,3,3,7,4,3,4,0]:
		fin_mesh.add_vertex(fin_points[idx])
	fin_mesh.generate_normals()
	var tail := MeshInstance3D.new()
	tail.mesh = fin_mesh.commit()
	tail.material_override = m.teal
	b.add_child(tail)
	var fc := CollisionShape3D.new()
	var fs := ConvexPolygonShape3D.new()
	fs.points = PackedVector3Array(fin_points)
	fc.shape = fs
	b.add_child(fc)
	for side in [-1,1]:
		_box(b,Vector3(0.06,1.0,2.2),Vector3(side*1.70,1.31,-27.3),m.glass,Vector3(0,side*0.42,0))
		_wheel(b,Vector3(side*0.36,-3.53,-20.4),0.49,0.3,m,v)
	_rod(b,Vector3(0,-3.3,-20.4),Vector3(0,-1.4,-20.4),0.15,m.metal)
	_box(b,Vector3(2.9,0.08,1.85),Vector3(0,2.70,-23.7),m.glass)


static func _gather_static_meshes(node: Node3D, excluded: Array, result: Array) -> void:
	for child in node.get_children():
		if excluded.has(child) or child.is_queued_for_deletion():
			continue
		if child is MeshInstance3D:
			result.append(child)
		elif child is Node3D:
			_gather_static_meshes(child, excluded, result)

static func _merge_static_meshes(parent: Node3D, excluded: Array) -> void:
	# Keep authored detail while batching static geometry to one draw per material.
	var meshes: Array = []
	_gather_static_meshes(parent, excluded, meshes)
	var groups: Dictionary = {}
	for node in meshes:
		var relative: Transform3D = parent.global_transform.affine_inverse()*node.global_transform
		for surface_index in node.mesh.get_surface_count():
			var mat: Material = node.material_override
			if mat == null: mat = node.mesh.surface_get_material(surface_index)
			var key: int = mat.get_instance_id() if mat else 0
			if not groups.has(key):
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"surface":builder,"material":mat}
			var indexed_source := SurfaceTool.new()
			indexed_source.create_from(node.mesh,surface_index)
			indexed_source.index()
			groups[key].surface.append_from(indexed_source.commit(),0,relative)
		node.queue_free()
	for key in groups:
		var combined := MeshInstance3D.new()
		combined.mesh = groups[key].surface.commit()
		combined.material_override = groups[key].material
		parent.add_child(combined)


static func _seated_rider(body:Node3D,m:Dictionary,kind:String) -> Node3D:
	var rider:=Node3D.new()
	rider.name="Seated_operator"
	rider.position=Vector3(0,0.61,0.32) if kind=="motorcycle" else Vector3(0,0.04,0.08)
	rider.visible=false
	body.add_child(rider)
	_ellipsoid(rider,Vector3(0.235,0.32,0.16),Vector3(0,0.30,-0.11),m.blue)
	_ellipsoid(rider,Vector3(0.20,0.19,0.16),Vector3(0,0.04,0),m.dark)
	_ellipsoid(rider,Vector3(0.19,0.21,0.20),Vector3(0,0.77,-0.22),m.white)
	_ellipsoid(rider,Vector3(0.175,0.09,0.06),Vector3(0,0.79,-0.395),m.glass)
	_box(rider,Vector3(0.085,0.06,0.07),Vector3(0,0.66,-0.37),m.dark)
	for side in [-1,1]:
		var s:float=side
		var elbow:=Vector3(s*0.31,0.22,-0.49)
		var hand:=Vector3(s*0.32,0.08,-0.96)
		if kind=="paraglider":
			elbow=Vector3(s*0.39,0.38,-0.15)
			hand=Vector3(s*0.43,0.69,-0.17)
		_rod(rider,Vector3(s*0.2,0.48,-0.11),elbow,0.075,m.blue)
		_rod(rider,elbow,hand,0.060,m.blue)
		_ellipsoid(rider,Vector3(0.07,0.08,0.08),hand,m.dark)
		var knee:=Vector3(s*0.27,-0.21,-0.33)
		var foot:=Vector3(s*0.30,-0.53,-0.07)
		_rod(rider,Vector3(s*0.14,0.04,0),knee,0.10,m.dark)
		_rod(rider,knee,foot,0.085,m.dark)
		_ellipsoid(rider,Vector3(0.10,0.07,0.19),foot+Vector3(0,0,-0.08),m.rubber)
	return rider
