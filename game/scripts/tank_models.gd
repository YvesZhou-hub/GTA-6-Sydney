extends RefCounted
## Original Harbour Bastion heavy tracked game vehicle. +Y up, -Z forward.
## Public tank photographs inform mechanical layout; no third-party assets.
const HULL_LENGTH := 7.6
const WIDTH := 4.1
const GROUND_OFFSET := .96
const TURRET_POSITION := Vector3(0,.82,-.1)
const BARREL_POSITION := Vector3(0,.64,-1.55)
const MUZZLE_POSITION := Vector3(0,0,-4.8)

static func _triangle(s:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,n:Vector3) -> void:
	var points:=[a,b,c] if (b-a).cross(c-a).dot(n)<0 else [a,c,b]
	for p:Vector3 in points:s.set_normal(n);s.set_uv(Vector2(p.x,p.z));s.add_vertex(p)

static func _solid(parent:Node3D,points:Array[Vector3],faces:Array,mat:Material,collision:bool=false) -> MeshInstance3D:
	var centre:=Vector3.ZERO
	for p in points:centre+=p
	centre/=points.size()
	var s:=SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face:Array in faces:
		var a:Vector3=points[face[0]];var b:Vector3=points[face[1]];var c:Vector3=points[face[2]]
		var n:Vector3=(b-a).cross(c-a).normalized()
		if n.dot((a+b+c)/3.0-centre)<0:n=-n
		for i in range(1,face.size()-1):_triangle(s,a,points[face[i]],points[face[i+1]],n)
	var view:=MeshInstance3D.new();view.mesh=s.commit();view.material_override=mat;parent.add_child(view)
	if collision:
		var shape:=ConvexPolygonShape3D.new();shape.points=PackedVector3Array(points)
		var col:=CollisionShape3D.new();col.shape=shape;parent.add_child(col)
	return view

static func _profile(parent:Node3D,profile:Array[Vector2],half_width:float,mat:Material,collision:bool=false) -> void:
	var points:Array[Vector3]=[];var faces:Array=[];var count:=profile.size()
	for side in [-1.0,1.0]:
		for p in profile:points.append(Vector3(side*half_width,p.y,p.x))
	var left:Array=[];var right:Array=[]
	for i in count:left.append(i);right.append(i+count);faces.append([i,(i+1)%count,(i+1)%count+count,i+count])
	faces.append(left);faces.append(right);_solid(parent,points,faces,mat,collision)

static func _cylinder(f:Script,parent:Node3D,radius:float,length:float,p:Vector3,mat:Material,rotation:=Vector3.ZERO,top:float=-1) -> MeshInstance3D:
	var node:MeshInstance3D=f._cylinder(parent,radius,length,p,mat,rotation,top)
	node.mesh.radial_segments=20 if radius>.25 else 12;node.mesh.rings=1
	return node

static func _track_point(distance:float) -> Vector2:
	var straight:=6.1;var radius:=.515;var arc:=PI*radius
	var d:=fposmod(distance,2.0*(straight+arc))
	if d<straight:return Vector2(-3.05+d,.15)
	d-=straight
	if d<arc:
		var a:=d/radius;return Vector2(3.05+sin(a)*radius,-.365+cos(a)*radius)
	d-=arc
	if d<straight:return Vector2(3.05-d,-.88)
	var a:=PI+(d-straight)/radius
	return Vector2(-3.05+sin(a)*radius,-.365+cos(a)*radius)

static func build(body:Node3D,m:Dictionary,moving:Dictionary,f:Script) -> void:
	var armour:StandardMaterial3D=f.material(Color("68715c"),.27,.72)
	var edge:StandardMaterial3D=f.material(Color("8e947e"),.34,.57)
	var recess:StandardMaterial3D=f.material(Color("26312d"),.42,.65)
	var track:StandardMaterial3D=f.material(Color("353a37"),.7,.62)
	var tread:StandardMaterial3D=f.material(Color("171c1b"),.08,.93)
	var lens:StandardMaterial3D=f.material(Color("295765"),.65,.12)
	moving.material=armour
	if not moving.has("wheels"):moving.wheels=[]
	_profile(body,[Vector2(-3.8,-.20),Vector2(-2.95,-.55),Vector2(3.55,-.55),Vector2(3.8,.12),Vector2(3.48,.73),Vector2(-2.45,.80),Vector2(-3.75,.16)],1.51,armour,true)
	# Separate upper glacis, rear engine deck and non-uniform plate seams.
	f._box(body,Vector3(3.24,.15,4.65),Vector3(0,.72,.34),armour)
	f._box(body,Vector3(2.75,.04,1.44),Vector3(0,.81,2.49),recess)
	for i in 14:f._box(body,Vector3(2.6,.032,.055),Vector3(0,.85,1.91+i*.088),edge)
	for side in [-1.0,1.0]:
		var x:float=side*1.60
		# Two long rounded rigid contacts stand in for the track shoe chain.
		var col:=CollisionShape3D.new();var shape:=CapsuleShape3D.new()
		shape.radius=.46;shape.height=7.2;col.shape=shape;col.rotation.x=PI*.5;col.position=Vector3(side*1.48,-.50,0);body.add_child(col)
		var circumference:=2.0*(6.1+PI*.515)
		for i in 72:
			var p:=_track_point(circumference*i/72.0);var q:=_track_point(circumference*(i+.30)/72.0)
			var tangent:=Vector3(0,q.y-p.y,q.x-p.x).normalized()
			var normal:=Vector3(0,tangent.z,-tangent.y)
			var shoe:MeshInstance3D=f._box(body,Vector3(.64,.11,circumference/72.0*.94),Vector3(x,p.y,p.x),track)
			shoe.basis=Basis.looking_at(tangent,normal)
			var pad:MeshInstance3D=f._box(body,Vector3(.47,.033,.13),Vector3(x,p.y,p.x)+normal*.067,tread)
			pad.basis=shoe.basis
		for i in 9:
			var z:float=-2.28+i*.76 if i<7 else (-3.05 if i==7 else 3.05)
			var radius:float=.37 if i<7 else .39
			var pivot:=Node3D.new();pivot.name=("RoadWheel_" if i<7 else "Idler_" if i==7 else "Sprocket_")+str(int(side))+"_"+str(i)
			pivot.position=Vector3(x,-.45 if i<7 else -.39,z);body.add_child(pivot)
			pivot.set_meta("tank_side",side);pivot.set_meta("radius",radius);pivot.set_meta("tank_radius",radius);moving.wheels.append(pivot)
			_cylinder(f,pivot,radius,.46,Vector3.ZERO,tread,Vector3(0,0,PI*.5))
			for face in [-1.0,1.0]:
				_cylinder(f,pivot,radius*.84,.033,Vector3(face*.247,0,0),armour,Vector3(0,0,PI*.5))
				_cylinder(f,pivot,.12,.047,Vector3(face*.27,0,0),edge,Vector3(0,0,PI*.5))
				for bolt in 8:
					var a:=TAU*bolt/8;f._box(pivot,Vector3(.033,.033,.033),Vector3(face*.275,sin(a)*radius*.62,cos(a)*radius*.62),m.metal)
			if i==8:
				for tooth in 14:
					var a:=TAU*tooth/14;f._box(pivot,Vector3(.52,.075,.09),Vector3(0,sin(a)*.475,cos(a)*.475),edge,Vector3(-a,0,0))
		# Articulated skirts retain visible lower road wheels and individual joins.
		for section in 6:
			f._box(body,Vector3(.13,.65,.91),Vector3(side*1.94,.34,-2.66+section*1.06),armour,Vector3(0,0,side*.075))
			f._box(body,Vector3(.16,.055,.81),Vector3(side*1.94,.67,-2.66+section*1.06),edge)
			for dz in [-.30,.30]:f._box(body,Vector3(.035,.045,.045),Vector3(side*2.015,.49,-2.66+section*1.06+dz),m.metal)
		f._box(body,Vector3(.30,.30,.15),Vector3(side*1.21,.32,-3.68),recess)
		f._box(body,Vector3(.22,.16,.06),Vector3(side*1.21,.33,-3.78),m.light)
		f._box(body,Vector3(.24,.12,.07),Vector3(side*1.21,.25,3.77),m.red)
		for end in [-1.0,1.0]:f._rod(body,Vector3(side*.92,-.20,end*3.71),Vector3(side*1.17,-.20,end*3.71),.09,track)
	# Turret and barrel are explicit nested pivots preserved by the factory.
	var turret:=Node3D.new();turret.name="TankTurretYaw";turret.position=TURRET_POSITION;body.add_child(turret);moving.turret=turret
	_cylinder(f,turret,1.33,.20,Vector3.ZERO,recess)
	var outline:=[Vector2(-1.5,-1.42),Vector2(-.78,-2.00),Vector2(.78,-2.00),Vector2(1.5,-1.42),Vector2(1.42,1.50),Vector2(.82,1.94),Vector2(-.82,1.94),Vector2(-1.42,1.50)]
	var points:Array[Vector3]=[];var faces:Array=[]
	for p:Vector2 in outline:points.append(Vector3(p.x,.06,p.y))
	for p:Vector2 in outline:points.append(Vector3(p.x*.82,1.03,p.y*.72+.13))
	faces.append([0,1,2,3,4,5,6,7]);faces.append([8,9,10,11,12,13,14,15])
	for i in 8:faces.append([i,(i+1)%8,(i+1)%8+8,i+8])
	_solid(turret,points,faces,armour)
	for side in [-1.0,1.0]:
		f._box(turret,Vector3(.09,.64,1.45),Vector3(side*1.40,.49,.63),edge,Vector3(0,side*.05,side*.20))
		f._box(turret,Vector3(.73,.58,.29),Vector3(side*.76,.48,-1.67),edge,Vector3(-.14,side*.26,0))
		for i in 3:_cylinder(f,turret,.075,.28,Vector3(side*1.38,.74,-.88+i*.21),recess,Vector3(.50,0,side*.9))
		f._box(turret,Vector3(.45,.52,1.15),Vector3(side*1.45,.51,1.43),recess)
		for i in 4:f._rod(turret,Vector3(side*1.73,.29,1.0+i*.27),Vector3(side*1.73,.76,1.0+i*.27),.027,edge)
		f._rod(turret,Vector3(side*.96,1.06,1.33),Vector3(side*1.03,2.15,1.37),.016,recess)
	# Hatch lids, handles, panoramic optic and protected driver's vision blocks.
	for x in [-.65,.60]:
		_cylinder(f,turret,.35,.08,Vector3(x,1.08,.38),edge)
		f._rod(turret,Vector3(x-.13,1.15,.4),Vector3(x+.13,1.15,.4),.025,recess)
		for i in 3:f._box(turret,Vector3(.15,.12,.16),Vector3(x-.22+i*.22,1.16,-.02),lens)
	_cylinder(f,turret,.25,.33,Vector3(-.68,1.33,-.55),recess)
	f._box(turret,Vector3(.47,.34,.41),Vector3(-.68,1.57,-.55),edge)
	f._box(turret,Vector3(.34,.22,.025),Vector3(-.68,1.57,-.768),lens)
	f._box(body,Vector3(.62,.09,.46),Vector3(0,.84,-2.27),edge)
	for i in 3:f._box(body,Vector3(.17,.10,.19),Vector3(-.21+i*.21,.93,-2.51),lens)
	var barrel:=Node3D.new();barrel.name="TankBarrelPitch";barrel.position=BARREL_POSITION;turret.add_child(barrel);moving.barrel=barrel
	f._box(barrel,Vector3(.72,.65,.58),Vector3(0,0,-.08),recess)
	_cylinder(f,barrel,.19,3.91,Vector3(0,0,-2.1),edge,Vector3(PI*.5,0,0),.15)
	_cylinder(f,barrel,.27,.57,Vector3(0,0,-1.83),armour,Vector3(PI*.5,0,0))
	for z in [-.54,-1.49,-2.21,-3.1,-3.90]:_cylinder(f,barrel,.205,.055,Vector3(0,0,z),recess,Vector3(PI*.5,0,0))
	f._box(barrel,Vector3(.46,.33,.65),Vector3(0,0,-4.40),edge)
	# Visible dark muzzle bore and side recesses are decorative game geometry.
	_cylinder(f,barrel,.124,.035,Vector3(0,0,-4.742),recess,Vector3(PI*.5,0,0))
	for side in [-1.0,1.0]:
		for z in [-4.27,-4.50]:f._box(barrel,Vector3(.015,.16,.13),Vector3(side*.238,0,z),recess)
	var muzzle:=Marker3D.new();muzzle.name="TankMuzzle";muzzle.position=MUZZLE_POSITION;barrel.add_child(muzzle);moving.muzzle=muzzle
	# Conservative stationary turret envelope; aiming geometry remains visual.
	var turret_col:=CollisionShape3D.new();var turret_shape:=CylinderShape3D.new()
	turret_shape.radius=1.62;turret_shape.height=1.14;turret_col.shape=turret_shape;turret_col.position=Vector3(0,1.35,-.10);body.add_child(turret_col)
	body.set_meta("model_reference","Original Harbour Bastion game tank; public Australian Army Abrams photographs inform layout, not a replica")
	body.set_meta("tank_ground_offset",GROUND_OFFSET)
