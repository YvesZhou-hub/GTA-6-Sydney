extends RefCounted
## Original procedural reconstructions from manufacturer dimensions and images.
## Forward -Z, metres. No reference photograph pixels or third-party models.

class Panels:
	var parent: Node3D
	var materials: Dictionary
	var surfaces := {}
	var smooth_keys := []
	func _init(node: Node3D, mats: Dictionary):
		parent = node
		materials = mats
	func triangle(key: String, a: Vector3, b: Vector3, c: Vector3, outward: Vector3 = Vector3.ZERO):
		var cross := (b-a).cross(c-a)
		if cross.length_squared() < 0.000000000001: return
		if not surfaces.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[key] = tool
		var normal := cross.normalized()
		if outward != Vector3.ZERO and normal.dot(outward) < 0:
			var swap := b
			b = c
			c = swap
			normal = -normal
		# Godot front faces are clockwise; normals are explicit and point out.
		for point: Vector3 in [a,c,b]:
			surfaces[key].set_normal(normal)
			surfaces[key].add_vertex(point)
	func quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3 = Vector3.ZERO):
		triangle(key,a,b,c,outward)
		triangle(key,a,c,d,outward)
	func polygon(key: String, points: Array, outward: Vector3):
		for i in range(1,points.size()-1): triangle(key,points[0],points[i],points[i+1],outward)
	func finish():
		for key: String in surfaces:
			var node := MeshInstance3D.new()
			node.name = "Sculpted_" + key
			if key in smooth_keys: surfaces[key].generate_normals()
			node.mesh = surfaces[key].commit()
			node.material_override = materials[key]
			parent.add_child(node)

static func build(body: Node3D, kind: String, mats: Dictionary, moving: Dictionary, factory: Script) -> void:
	mats["carbon"] = factory.material(Color("161a1e"),0.32,0.56)
	mats["brake"] = factory.material(Color("686e74"),0.9,0.4)
	mats["gold"] = factory.material(Color("b5a075"),0.85,0.26)
	match kind:
		"car": _supercar(body,mats,moving,factory)
		"motorcycle": _superbike(body,mats,moving,factory)
		"airliner": _dreamliner(body,mats,moving,factory)

static func _convex(body: Node3D, points: Array):
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array(points)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)

static func _wheel(body: Node3D, center: Vector3, radius: float, width: float, mats: Dictionary, moving: Dictionary, f: Script, spokes: int = 10):
	var pivot := Node3D.new()
	pivot.name = "Detailed_wheel_%02d" % moving.wheels.size()
	pivot.position = center
	pivot.set_meta("radius",radius)
	body.add_child(pivot)
	var p := Panels.new(pivot,mats)
	# Rounded tread, bevelled shoulder and real open rim, rather than solid discs.
	var profile := [[-0.50,0.64],[-0.50,0.83],[-0.46,0.95],[-0.31,1.0],[0.31,1.0],[0.46,0.95],[0.50,0.83],[0.50,0.64]]
	for j in profile.size()-1:
		for i in 40:
			var a := TAU*i/40
			var b := TAU*(i+1)/40
			p.quad("rubber",Vector3(profile[j][0]*width,sin(a)*profile[j][1]*radius,cos(a)*profile[j][1]*radius),Vector3(profile[j+1][0]*width,sin(a)*profile[j+1][1]*radius,cos(a)*profile[j+1][1]*radius),Vector3(profile[j+1][0]*width,sin(b)*profile[j+1][1]*radius,cos(b)*profile[j+1][1]*radius),Vector3(profile[j][0]*width,sin(b)*profile[j][1]*radius,cos(b)*profile[j][1]*radius),Vector3(0,sin((a+b)/2),cos((a+b)/2)))
	for side: int in [-1,1]:
		var x := side*(width*0.5+0.004)
		for i in 40:
			var a := TAU*i/40
			var b := TAU*(i+1)/40
			p.quad("metal",Vector3(x,sin(a)*radius*.68,cos(a)*radius*.68),Vector3(x,sin(a)*radius*.76,cos(a)*radius*.76),Vector3(x,sin(b)*radius*.76,cos(b)*radius*.76),Vector3(x,sin(b)*radius*.68,cos(b)*radius*.68),Vector3(side,0,0))
		f._cylinder(pivot,radius*.54,.012,Vector3(side*width*.38,0,0),mats.brake,Vector3(0,0,PI/2))
		for i in spokes:
			var a := TAU*i/spokes
			var d := .095
			p.quad("gold",Vector3(x,sin(a-d)*radius*.15,cos(a-d)*radius*.15),Vector3(x,sin(a+d)*radius*.15,cos(a+d)*radius*.15),Vector3(x,sin(a+.23+d)*radius*.7,cos(a+.23+d)*radius*.7),Vector3(x,sin(a+.23-d)*radius*.7,cos(a+.23-d)*radius*.7),Vector3(side,0,0))
		f._cylinder(pivot,radius*.16,.014,Vector3(x+side*.006,0,0),mats.carbon,Vector3(0,0,PI/2))
		for i in 14:
			var a := TAU*i/14
			var hole := Vector3(side*width*.405,sin(a)*radius*.45,cos(a)*radius*.45)
			for j in 8:
				var angle := TAU*j/8
				var next := TAU*(j+1)/8
				p.triangle("dark",hole,hole+Vector3(0,sin(angle)*radius*.022,cos(angle)*radius*.022),hole+Vector3(0,sin(next)*radius*.022,cos(next)*radius*.022),Vector3(side,0,0))
		# Caliper stays on chassis as wheel rotates.
		f._box(body,Vector3(.045,radius*.33,radius*.18),center+Vector3(side*width*.40,0,radius*.43),mats.red)
	p.finish()
	moving.wheels.append(pivot)
	f._sphere_collision(body,radius,center)

static func _supercar(b: Node3D, m: Dictionary, v: Dictionary, f: Script):
	m.teal = f.material(Color("83bd30"),.45,.31)
	v.material = m.teal
	var p := Panels.new(b,m)
	m["fender"] = m.teal
	m["bonnet"] = m.teal
	m["front_paint"] = m.teal
	p.smooth_keys = ["fender","bonnet","front_paint"]
	var front_z := -1.43
	var rear_z := front_z+2.779
	var sections := [[-2.4735,.94,-.08],[-2.19,.98,-.04],[-1.8,1.00,.01],[-1.43,1.0165,.06],[-.96,.98,.07],[-.40,.91,.08],[.55,.92,.09],[1.349,1.0165,.11],[1.95,1.01,.04],[2.4735,.91,-.04]]
	var smooth_sections := []
	for i in sections.size()-1:
		var count := int(ceil((sections[i+1][0]-sections[i][0])/.09))
		for j in count:
			var t := float(j)/count
			smooth_sections.append([lerpf(sections[i][0],sections[i+1][0],t),lerpf(sections[i][1],sections[i+1][1],t),lerpf(sections[i][2],sections[i+1][2],t)])
	smooth_sections.append(sections.back())
	sections = smooth_sections
	for i in sections.size()-1:
		var a: Array = sections[i]
		var c: Array = sections[i+1]
		# Faceted shoulder / centre creases carry the actual wedge silhouette.
		for side: int in [-1,1]:
			p.quad("bonnet",_car_hood(0,a[2]+.018,a[0]),_car_hood(side*.68,a[2],a[0]),_car_hood(side*.68,c[2],c[0]),_car_hood(0,c[2]+.018,c[0]),Vector3.UP)
			# Wheel cutouts: outer skins stop at the actual circular arch.
			var y1 := _arch_floor(float(a[0]),front_z,rear_z)
			var y2 := _arch_floor(float(c[0]),front_z,rear_z)
			var shoulder1 := maxf(a[2]-.015,y1+.024)
			var shoulder2 := maxf(c[2]-.015,y2+.024)
			p.quad("fender",_car_hood(side*.68,a[2],a[0]),_car_hood(side*a[1],shoulder1,a[0]),_car_hood(side*c[1],shoulder2,c[0]),_car_hood(side*.68,c[2],c[0]),Vector3(side,1,0))
			p.quad("fender",_car_hood(side*a[1],shoulder1,a[0]),_car_hood(side*a[1],y1,a[0]),_car_hood(side*c[1],y2,c[0]),_car_hood(side*c[1],shoulder2,c[0]),Vector3(side,0,0))
	# Central belly leaves the tyre wells physically and visually open.
	f._box(b,Vector3(1.37,.16,4.31),Vector3(0,-.45,0),m.carbon)
	for side: int in [-1,1]:
		for axle in [[front_z,.351,.86],[rear_z,.3705,.8505]]:
			_wheel(b,Vector3(side*axle[2],-.68+axle[1],axle[0]),axle[1],.265 if axle[0]==front_z else .33,m,v,f)
			for i in 18:
				var a := PI*float(i)/18
				var d := PI*float(i+1)/18
				var center := Vector3(side*1.0165,-.68+axle[1],axle[0])
				var inner_radius: float = axle[1]+.026
				var outer_radius: float = axle[1]+.061
				p.quad("fender",center+Vector3(0,sin(a)*inner_radius,cos(a)*inner_radius),center+Vector3(0,sin(a)*outer_radius,cos(a)*outer_radius),center+Vector3(0,sin(d)*outer_radius,cos(d)*outer_radius),center+Vector3(0,sin(d)*inner_radius,cos(d)*inner_radius),Vector3(side,0,0))
		# Huge dark side intake, canted sill and angular door skin.
		p.polygon("carbon",[Vector3(side*.955,-.37,-.02),Vector3(side*1.009,.10,.66),Vector3(side*1.014,.08,.99),Vector3(side*.999,-.45,.82)],Vector3(side,0,0))
		p.polygon("teal",[Vector3(side*.971,-.37,-.99),Vector3(side*.94,.05,-.72),Vector3(side*.88,.1,.57),Vector3(side*.955,-.37,-.02)],Vector3(side,0,0))
		p.quad("carbon",Vector3(side*.98,-.50,-.94),Vector3(side*1.016,-.48,-.85),Vector3(side*1.016,-.46,.92),Vector3(side*.95,-.49,.94),Vector3(side,1,0))
		# Polygonal side glazing, roof pillar and mirror on a narrow stalk.
		p.polygon("glass",[Vector3(side*.77,.10,-.80),Vector3(side*.635,.445,-.27),Vector3(side*.65,.45,.41),Vector3(side*.825,.11,.87)],Vector3(side,1,0))
		f._rod(b,Vector3(side*.78,.08,-.82),Vector3(side*.638,.455,-.25),.026,m.teal)
		f._rod(b,Vector3(side*.65,.45,.41),Vector3(side*.83,.11,.9),.035,m.teal)
		f._rod(b,Vector3(side*.79,.17,-.58),Vector3(side*1.026,.21,-.57),.018,m.carbon)
		f._ellipsoid(b,Vector3(.107,.048,.12),Vector3(side*1.026,.225,-.59),m.carbon)
		# Three-dimensional apertures follow the curved bumper and wrap around its corners.
		_front_patch(p,"front_paint",side,[[0,-.062],[.34,-.082],[.31,-.25],[0,-.22]])
		_front_patch(p,"carbon",side,[[0,-.22],[.31,-.25],[.40,-.48],[0,-.49]],.02)
		_front_patch(p,"front_paint",side,[[.32,-.25],[.40,-.27],[.52,-.495],[.40,-.49]])
		_front_patch(p,"front_paint",side,[[.34,-.08],[.94,-.095],[.91,-.127],[.36,-.14]])
		_front_patch(p,"carbon",side,[[.36,-.14],[.91,-.127],[.89,-.275],[.43,-.278]],.01)
		_front_patch(p,"carbon",side,[[.43,-.278],[.89,-.275],[.91,-.47],[.52,-.48]],.04)
		_front_patch(p,"front_paint",side,[[.91,-.127],[.964,-.11],[.97,-.495],[.91,-.47]])
		_front_patch(p,"front_paint",side,[[.40,-.49],[.97,-.495],[.96,-.535],[.39,-.52]])
		_front_patch(p,"carbon",side,[[0,-.49],[.97,-.53],[.94,-.56],[0,-.525]])
		# Dark individual projector chamber plus broad, continuous three-branch LED.
		for x in [.49,.59,.69]:
			f._ellipsoid(b,Vector3(.041,.022,.022),_car_front(side*x,-.18,.0),m.glass)
		var joint := _car_front(side*.79,-.25,-.014)
		for end in [_car_front(side*.405,-.247,-.014),_car_front(side*.89,-.139,-.014),_car_front(side*.89,-.422,-.014)]:
			f._rod(b,joint,end,.012,m.light)
		for i in 8:
			var x := side*(.56+i*.039)
			f._rod(b,_car_front(x,-.435,.029),_car_front(x,-.31,.029),.006,m.metal)
		# Raised exhausts and Y-shaped rear lighting above the diffuser.
		for end in [Vector3(side*.80,-.14,2.47),Vector3(side*.76,-.255,2.47),Vector3(side*.45,-.205,2.478)]: f._rod(b,Vector3(side*.67,-.205,2.477),end,.012,m.red)
		f._cylinder(b,.103,.10,Vector3(side*.20,-.185,2.436),m.metal,Vector3(PI/2,0,0))
		f._cylinder(b,.080,.105,Vector3(side*.20,-.185,2.441),m.carbon,Vector3(PI/2,0,0))
	p.quad("carbon",Vector3(-.91,-.075,2.474),Vector3(.91,-.075,2.474),Vector3(.88,-.43,2.474),Vector3(-.88,-.43,2.474),Vector3(0,0,1))
	p.quad("teal",Vector3(-.91,-.36,2.479),Vector3(.91,-.36,2.479),Vector3(.85,-.42,2.479),Vector3(-.85,-.42,2.479),Vector3(0,0,1))
	p.quad("glass",Vector3(-.77,.105,-.825),Vector3(.77,.105,-.825),Vector3(.635,.455,-.27),Vector3(-.635,.455,-.27),Vector3(0,1,-1))
	p.quad("teal",Vector3(-.635,.48,-.25),Vector3(.635,.48,-.25),Vector3(.66,.465,.45),Vector3(-.66,.465,.45),Vector3.UP)
	p.quad("glass",Vector3(-.66,.448,.47),Vector3(.66,.448,.47),Vector3(.65,.13,1.10),Vector3(-.65,.13,1.10),Vector3(0,1,1))
	p.quad("carbon",Vector3(-.62,.136,1.12),Vector3(.62,.136,1.12),Vector3(.57,.067,1.96),Vector3(-.57,.067,1.96),Vector3.UP)
	for i in 9: f._box(b,Vector3(1.03,.022,.028),Vector3(0,.132-i*.0065,1.18+i*.088),m.metal)
	for x in [-.72,-.36,0,.36,.72]: f._box(b,Vector3(.025,.13,.5),Vector3(x,-.43,2.15),m.carbon)
	p.finish()
	f._box_collision(b,Vector3(1.70,.43,4.64),Vector3(0,-.27,0))
	_convex(b,[Vector3(-.76,.09,-.83),Vector3(.76,.09,-.83),Vector3(-.63,.48,-.25),Vector3(.63,.48,-.25),Vector3(-.66,.47,.45),Vector3(.66,.47,.45),Vector3(-.81,.1,.94),Vector3(.81,.1,.94)])
	b.set_meta("vehicle_model",{"reference":"Revuelto proportions","length":4.947,"width":2.033,"mirror_width":2.266,"height":1.16,"wheelbase":2.779,"ground":-.68,"wheel_centers":[Vector3(-.86,-.329,front_z),Vector3(.86,-.329,front_z),Vector3(-.8505,-.3095,rear_z),Vector3(.8505,-.3095,rear_z)],"features":["sculpted_panels","open_wheel_arches","Y_lights","side_intakes","raised_twin_exhaust","open_spoke_wheels"]})

static func _car_hood(x: float, y: float, z: float) -> Vector3:
	var wrap := .20*pow(absf(x)/.96,2)*clampf((-2.15-z)/.3235,0,1)
	return Vector3(x,y,z+wrap)

static func _car_front(x: float, y: float, depth: float = .0) -> Vector3:
	return Vector3(x,y,-2.4735+.20*pow(absf(x)/.96,2)+.06*pow(clampf((-y-.08)/.48,0,1),2)+depth)

static func _front_patch(p: Panels, key: String, side: int, corners: Array, depth: float = .0):
	for i in 8:
		for j in 3:
			var vertices := []
			for pair in [[i,j],[i+1,j],[i+1,j+1],[i,j+1]]:
				var u := float(pair[0])/8
				var w := float(pair[1])/3
				var top := Vector2(corners[0][0],corners[0][1]).lerp(Vector2(corners[1][0],corners[1][1]),u)
				var bottom := Vector2(corners[3][0],corners[3][1]).lerp(Vector2(corners[2][0],corners[2][1]),u)
				var point := top.lerp(bottom,w)
				vertices.append(_car_front(side*point.x,point.y,depth))
			p.quad(key,vertices[0],vertices[1],vertices[2],vertices[3],Vector3(side*.15,0,-1))

static func _arch_floor(z: float, front: float, rear: float) -> float:
	for axle in [[front,.351],[rear,.3705]]:
		var d := absf(z-float(axle[0]))
		var radius := float(axle[1])+.034
		if d < radius: return -.68+float(axle[1])+sqrt(radius*radius-d*d)
	return -.45

const BIKE_FAIRING := [[-.942,.19,.05,.215,.22,.196],[-.76,.22,-.12,.19,.25,.14],[-.56,.285,-.36,.22,.30,.16],[-.25,.215,-.52,.215,.295,.165],[.05,.105,-.54,.195,.265,.165],[.30,-.14,-.38,.14,.205,.15]]

static func _bike_skin(z: float, t: float, side: int, offset: float = .0) -> Vector3:
	for i in BIKE_FAIRING.size()-1:
		var a: Array = BIKE_FAIRING[i]
		var c: Array = BIKE_FAIRING[i+1]
		if z >= a[0] and z <= c[0]:
			var u := inverse_lerp(a[0],c[0],z)
			var top := lerpf(a[1],c[1],u)
			var bottom := lerpf(a[2],c[2],u)
			var x_top := lerpf(a[3],c[3],u)
			var x_mid := lerpf(a[4],c[4],u)
			var x_bottom := lerpf(a[5],c[5],u)
			var x := lerpf(x_top,x_bottom,t)+sin(PI*t)*(x_mid-(x_top+x_bottom)*.5)
			return _bike_wrap(Vector3(side*(x+offset),lerpf(top,bottom,t),z))
	return Vector3.ZERO

static func _bike_wrap(point: Vector3) -> Vector3:
	point.z += .075*pow(absf(point.x)/.22,2)*clampf((-.76-point.z)/.184,0,1)
	return point

static func _bike_face(p: Panels,key: String,corners: Array):
	for i in 12:
		for j in 4:
			var vertices := []
			for pair in [[i,j],[i+1,j],[i+1,j+1],[i,j+1]]:
				var u := float(pair[0])/12
				var w := float(pair[1])/4
				vertices.append(_bike_wrap(corners[0].lerp(corners[1],u).lerp(corners[3].lerp(corners[2],u),w)))
			p.quad(key,vertices[0],vertices[1],vertices[2],vertices[3],Vector3(0,0,-1))

static func _bike_patch(p: Panels,key: String,side: int,z0: float,z1: float,t0: float,t1: float,offset: float = .0):
	var stations := [z0]
	for station: Array in BIKE_FAIRING:
		if station[0]>z0 and station[0]<z1: stations.append(station[0])
	stations.append(z1)
	for interval in stations.size()-1:
		var steps := maxi(2,ceili((stations[interval+1]-stations[interval])/.022))
		for i in steps:
			for j in 8:
				var vertices := []
				for pair in [[i,j],[i+1,j],[i+1,j+1],[i,j+1]]:
					vertices.append(_bike_skin(lerpf(stations[interval],stations[interval+1],float(pair[0])/steps),lerpf(t0,t1,float(pair[1])/8),side,offset))
				p.quad(key,vertices[0],vertices[1],vertices[2],vertices[3],Vector3(side,0,0))

static func _superbike(b: Node3D, m: Dictionary, v: Dictionary, f: Script):
	v.material = m.white
	m["screen"] = f.material(Color("668a98"),.15,.19)
	m["fairing"] = m.white
	m.screen.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.screen.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.screen.albedo_color.a = .56
	var p := Panels.new(b,m)
	p.smooth_keys = ["screen","fairing"]
	_wheel(b,Vector3(0,-.42,-.7285),.30,.12,m,v,f,7)
	_wheel(b,Vector3(0,-.40,.7285),.32,.19,m,v,f,7)
	# Tapered tank and raised short tail; no rectangular motorcycle body.
	f._hull(b,[[-.38,.07,.045,.14],[-.23,.24,.13,.18],[.10,.22,.12,.19],[.32,.12,.04,.13]],m.white,20)
	f._hull(b,[[.43,.15,.025,.17],[.64,.16,.08,.22],[.95,.05,.026,.28]],m.white,12)
	f._ellipsoid(b,Vector3(.16,.036,.24),Vector3(0,.113,.30),m.rubber)
	f._cylinder(b,.08,.012,Vector3(0,.31,-.04),m.metal)
	f._ellipsoid(b,Vector3(.17,.20,.23),Vector3(0,-.26,.05),m.dark)
	for side: int in [-1,1]:
		var s := float(side)
		for i in BIKE_FAIRING.size()-1:
			_bike_patch(p,"fairing",side,BIKE_FAIRING[i][0],BIKE_FAIRING[i+1][0],0,.77)
			_bike_patch(p,"carbon",side,BIKE_FAIRING[i][0],BIKE_FAIRING[i+1][0],.77,1)
		# Painted bands and small vents stay on the curved skin, with no floating flat signs.
		_bike_patch(p,"blue",side,-.68,.12,.13,.31,.008)
		_bike_patch(p,"red",side,-.64,-.08,.13,.19,.012)
		for i in 3:
			var z := -.36+i*.13
			_bike_patch(p,"carbon",side,z,z+.043,.45,.70,.007)
		p.quad("white",Vector3(s*.22,.065,-.71),Vector3(s*.37,.008,-.58),Vector3(s*.35,-.035,-.32),Vector3(s*.26,.0,-.36),Vector3(0,1,0))
		f._rod(b,Vector3(s*.105,-.42,-.7285),Vector3(s*.105,.17,-.44),.024,m.gold)
		f._rod(b,Vector3(s*.13,-.39,.7285),Vector3(s*.16,-.22,.10),.035,m.metal)
		f._rod(b,Vector3(s*.18,-.13,-.18),Vector3(s*.15,.12,.56),.035,m.metal)
		f._rod(b,Vector3(s*.16,.245,-.48),Vector3(s*.32,.20,-.41),.025,m.dark)
		f._rod(b,_bike_skin(-.67,.10,side),Vector3(s*.385,.39,-.70),.012,m.carbon)
		f._ellipsoid(b,Vector3(.039,.035,.065),Vector3(s*.385,.4,-.71),m.glass)
		# Separate angular LED optics, rather than round protruding headlight bulbs.
		_bike_face(p,"carbon",[Vector3(s*.06,.181,-.949),Vector3(s*.216,.182,-.949),Vector3(s*.203,.108,-.949),Vector3(s*.088,.099,-.949)])
		_bike_face(p,"light",[Vector3(s*.074,.157,-.953),Vector3(s*.204,.165,-.953),Vector3(s*.190,.139,-.953),Vector3(s*.094,.132,-.953)])
		_bike_face(p,"glass",[Vector3(s*.098,.121,-.953),Vector3(s*.188,.129,-.953),Vector3(s*.184,.113,-.953),Vector3(s*.108,.110,-.953)])
		f._rod(b,Vector3(s*.17,-.31,.28),Vector3(s*.25,-.32,.29),.02,m.metal)
	_bike_face(p,"fairing",[Vector3(-.219,.192,-.943),Vector3(.219,.192,-.943),Vector3(.205,.058,-.943),Vector3(-.205,.058,-.943)])
	# Rounded nose brow wraps over twin headlights into the windscreen rim.
	for side: int in [-1,1]:
		var nose_rows := [[-.944,.198,.215],[-.86,.228,.219],[-.76,.24,.16],[-.65,.29,.185],[-.52,.35,.19]]
		for i in nose_rows.size()-1:
			for j in 10:
				var vertices := []
				for pair in [[i,j],[i,j+1],[i+1,j+1],[i+1,j]]:
					var row: Array = nose_rows[pair[0]]
					var t := float(pair[1])/10
					vertices.append(_bike_wrap(Vector3(side*t*row[2],row[1]-.035*t*t,row[0]+.025*t*t)))
				p.quad("fairing",vertices[0],vertices[1],vertices[2],vertices[3],Vector3(side*.2,1,-1))
		p.polygon("fairing",[Vector3(side*.06,.045,-.912),Vector3(side*.22,.045,-.848),Vector3(side*.23,.083,-.826),Vector3(side*.064,.084,-.93)],Vector3(0,0,-1))
		p.quad("fairing",Vector3(side*.19,.315,-.52),Vector3(side*.16,.205,-.76),Vector3(side*.23,.22,-.60),Vector3(side*.235,.275,-.49),Vector3(side,1,0))
	var screen_sections := [[-.755,.241,.14],[-.705,.318,.151],[-.625,.385,.146],[-.525,.448,.120],[-.455,.480,.073],[-.435,.485,.015]]
	for i in screen_sections.size()-1:
		for j in 16:
			var points := []
			for pair in [[i,j],[i,j+1],[i+1,j+1],[i+1,j]]:
				var section: Array = screen_sections[pair[0]]
				var t := float(pair[1])/8-1.0
				points.append(Vector3(t*section[2],section[1]-.035*t*t,section[0]+.06*t*t))
			p.quad("screen",points[0],points[1],points[2],points[3],Vector3(0,1,-1))
	# Curved wheel mudguards give the fairing a complete, connected front.
	for i in 20:
		var a := PI*(.18+.64*i/20)
		var d := PI*(.18+.64*(i+1)/20)
		p.quad("white",Vector3(-.078,-.42+sin(a)*.333,-.7285+cos(a)*.333),Vector3(.078,-.42+sin(a)*.333,-.7285+cos(a)*.333),Vector3(.078,-.42+sin(d)*.333,-.7285+cos(d)*.333),Vector3(-.078,-.42+sin(d)*.333,-.7285+cos(d)*.333),Vector3(0,sin((a+d)/2),cos((a+d)/2)))
	_bike_face(p,"carbon",[Vector3(-.048,.15,-.951),Vector3(.048,.15,-.951),Vector3(.032,.059,-.951),Vector3(-.032,.059,-.951)])
	f._box(b,Vector3(.17,.018,.1),Vector3(0,.244,-.45),m.glass,Vector3(-.35,0,0))
	f._rod(b,Vector3(.16,-.48,-.25),Vector3(.24,-.32,.62),.065,m.metal)
	f._cylinder(b,.062,.17,Vector3(.24,-.3,.7),m.carbon,Vector3(PI/2,0,0))
	f._rod(b,Vector3(-.114,-.30,.08),Vector3(-.114,-.31,.73),.011,m.gold)
	f._rod(b,Vector3(-.114,-.42,.08),Vector3(-.114,-.49,.73),.011,m.gold)
	f._box(b,Vector3(.13,.025,.023),Vector3(0,.273,.952),m.red)
	p.finish()
	f._box_collision(b,Vector3(.48,.65,1.16),Vector3(0,-.08,-.10))
	b.set_meta("vehicle_model",{"reference":"BMW S 1000 RR proportions","length":2.073,"width":.848,"height":1.205,"wheelbase":1.457,"ground":-.72,"wheel_centers":[Vector3(0,-.42,-.7285),Vector3(0,-.40,.7285)],"features":["sport_fairing","shark_gills","winglets","rounded_screen","twin_LED_headlights","short_tail","chain_drive","brake_discs"]})

const FUSELAGE := [[-31.4,.012,.02,-.40],[-30.7,.72,.70,-.22],[-29.4,1.55,1.50,-.03],[-27.5,2.4,2.26,0.0],[-24.0,2.885,2.95,0.0],[-18.0,2.885,2.95,0.0],[15.8,2.885,2.95,0.0],[21.0,2.35,2.45,.30],[26.0,1.28,1.41,.85],[29.8,.35,.44,1.35],[31.4,.012,.02,1.55]]

static func _skin(z: float, y: float, side: int, offset: float = .02) -> Vector3:
	for i in FUSELAGE.size()-1:
		var a: Array = FUSELAGE[i]
		var c: Array = FUSELAGE[i+1]
		if z >= a[0] and z <= c[0]:
			var t := inverse_lerp(a[0],c[0],z)
			var rx := lerpf(a[1],c[1],t)
			var ry := lerpf(a[2],c[2],t)
			var cy := lerpf(a[3],c[3],t)
			var x := rx*sqrt(maxf(.0,1.0-pow((y-cy)/ry,2)))
			return Vector3(side*(x+offset),y,z)
	return Vector3(0,y,z)

static func _skin_panel(p: Panels, key: String, side: int, z0: float, z1: float, y0: float, y1: float, offset: float, slope: float = 0.0):
	# A large flat polygon would cut through a curved fuselage and disappear.
	# Subdivide the visible glazing/door surface and project every vertex.
	for i in 6:
		for j in 8:
			var points := []
			for pair in [[i,j],[i+1,j],[i+1,j+1],[i,j+1]]:
				var u := float(pair[0])/6
				var w := float(pair[1])/8
				points.append(_skin(lerpf(z0,z1,u),lerpf(y0,y1,w)+u*slope,side,offset))
			p.quad(key,points[0],points[1],points[2],points[3],Vector3(side,0,0))

static func _wing(p: Panels, side: int, sections: Array, key: String, b: Node3D):
	var ts := [0.0,.025,.075,.16,.30,.50,.72,.90,1.0]
	var hull: Array = []
	for i in sections.size()-1:
		var a: Array = sections[i]
		var c: Array = sections[i+1]
		for face: int in [-1,1]:
			for j in ts.size()-1:
				var quad: Array = []
				for pair in [[a,ts[j]],[a,ts[j+1]],[c,ts[j+1]],[c,ts[j]]]:
					var s: Array = pair[0]
					var t: float = pair[1]
					var y: float = s[1]+sin(PI*sqrt(t))*s[4]*(.60 if face==1 else -.40)
					quad.append(Vector3(side*s[0],y,lerpf(s[2],s[3],t)))
				p.quad(key,quad[0],quad[1],quad[2],quad[3],Vector3(0,face,0))
				for pt: Vector3 in quad: hull.append(pt)
	_convex(b,hull)

static func _dreamliner(b: Node3D, m: Dictionary, v: Dictionary, f: Script):
	v.material = m.teal
	var p := Panels.new(b,m)
	f._hull(b,FUSELAGE,m.white,64,true)
	for side: int in [-1,1]:
		var s := float(side)
		_wing(p,side,[[2.3,-.35,-7.0,8.7,1.05],[8.0,.05,-4.1,9.6,.72],[16.0,1.0,.5,10.6,.36],[24.0,2.2,5.8,11.5,.19],[28.3,3.2,9.1,12.0,.1],[30.05,3.9,11.9,12.65,.035]],"white",b)
		_wing(p,side,[[1.1,1.2,21.2,27.7,.4],[5.0,2.0,24.0,29.5,.22],[9.9,2.9,27.8,30.8,.06]],"white",b)
		# Flap lines and track fairings follow sweep; no false vertical winglets.
		for x in [6,11,17,22]:
			f._ellipsoid(b,Vector3(.17,.18,1.3),Vector3(s*x,.05+x*.052,7.4+x*.135),m.metal)
			f._rod(b,Vector3(s*(x-1.8),.45+x*.055,6.6+x*.135),Vector3(s*(x+1.8),.45+x*.065,7.4+x*.135),.025,m.brake)
		f._ellipsoid(b,Vector3(.045,.08,.14),Vector3(s*29.99,3.91,12.13),m.red if side<0 else m.light)
		# Oval windows and four pairs of passenger doors projected to curved skin.
		for i in 65:
			var z := -23.0+i*.68
			var skip := false
			for door_z in [-23.0,-8.0,10.5,20.3]:
				if absf(z-door_z)<.65: skip=true
			if skip: continue
			var center := _skin(z,.73,side,.028)
			for j in 14:
				var a := TAU*j/14
				var d := TAU*(j+1)/14
				p.triangle("glass",center,_skin(z+cos(a)*.145,.73+sin(a)*.255,side,.029),_skin(z+cos(d)*.145,.73+sin(d)*.255,side,.029),Vector3(s,0,0))
		for z in [-23.0,-8.0,10.5,20.3]:
			_skin_panel(p,"metal",side,z-.48,z+.48,-.65,1.48,.035)
			_skin_panel(p,"white",side,z-.43,z+.43,-.60,1.43,.051)
			f._rod(b,_skin(z-.24,.03,side,.06),_skin(z+.09,.03,side,.06),.025,m.dark)
		# Three cockpit panes each side, hugging the compound-curved nose.
		for section in [[-29.45,-28.83,.55,1.19],[-28.77,-28.02,.77,1.70],[-27.96,-27.1,.94,1.94]]:
			_skin_panel(p,"glass",side,section[0],section[1],section[2],section[3]-.12,.075,.12)
		for z in range(-22,21,2): p.quad("teal",_skin(z,-.77,side,.026),_skin(z+2,-.77,side,.026),_skin(z+2,-.58,side,.026),_skin(z,-.58,side,.026),Vector3(s,0,0))
		_engine(b,Vector3(s*8.5,-1.78,-4.35),m,v,f)
		f._rod(b,Vector3(s*8.5,-1.0,-3.2),Vector3(s*8.3,.0,-.8),.34,m.metal)
		for x in [3.12,3.70]:
			for z in [1.0,2.45]: _wheel(b,Vector3(s*x,-3.63,z),.61,.36,m,v,f,8)
		f._rod(b,Vector3(s*3.41,-3.30,1.73),Vector3(s*3.28,-.60,1.73),.13,m.metal)
		f._rod(b,Vector3(s*3.41,-2.15,1.73),Vector3(s*2.85,-.80,.55),.09,m.metal)
		f._box(b,Vector3(.14,1.68,1.60),Vector3(s*3.12,-1.4,1.7),m.white)
	for side: int in [-1,1]: _wheel(b,Vector3(side*.29,-3.79,-23.1),.45,.24,m,v,f,8)
	f._rod(b,Vector3(0,-3.68,-23.1),Vector3(0,-1.42,-23.1),.12,m.metal)
	f._rod(b,Vector3(0,-3.3,-23.1),Vector3(0,-1.1,-21.9),.085,m.metal)
	var fin := [Vector3(-.20,1.2,18.0),Vector3(-.09,12.76,26.65),Vector3(-.07,12.76,29.65),Vector3(-.18,1.3,28.1),Vector3(.20,1.2,18.0),Vector3(.09,12.76,26.65),Vector3(.07,12.76,29.65),Vector3(.18,1.3,28.1)]
	for face in [[0,1,2,3],[4,7,6,5],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]]:
		var center: Vector3 = (fin[face[0]]+fin[face[1]]+fin[face[2]]+fin[face[3]])*.25
		p.quad("teal",fin[face[0]],fin[face[1]],fin[face[2]],fin[face[3]],center-Vector3(0,6,25))
	_convex(b,fin)
	for side: int in [-1,1]:
		p.polygon("white",[Vector3(side*.145,5.6,22.6),Vector3(side*.112,9.8,26.9),Vector3(side*.116,8.9,27.4),Vector3(side*.15,5.3,24.2)],Vector3(side,0,0))
	p.finish()
	b.set_meta("vehicle_model",{"reference":"Boeing 787-9 proportions","length":62.8,"width":60.1,"height":17.0,"ground":-4.24,"main_wheel_x":[-3.7,-3.12,3.12,3.7],"main_wheel_z":[1.0,2.45],"nose_wheel_z":-23.1,"features":["six_cockpit_panes","raked_flexed_wings","oval_windows","eight_passenger_doors","two_chevron_nacelles","animated_fans","ten_gear_wheels","swept_fin"]})

static func _engine(body: Node3D, center: Vector3, m: Dictionary, moving: Dictionary, f: Script):
	var engine := Node3D.new()
	engine.position = center
	body.add_child(engine)
	var p := Panels.new(engine,m)
	var rings := [[-3.0,1.38],[-2.76,1.48],[-2.0,1.52],[.0,1.48],[1.50,1.28],[2.4,1.08]]
	for j in rings.size()-1:
		for i in 48:
			var a := TAU*i/48
			var d := TAU*(i+1)/48
			p.quad("white",Vector3(cos(a)*rings[j][1],sin(a)*rings[j][1],rings[j][0]),Vector3(cos(d)*rings[j][1],sin(d)*rings[j][1],rings[j][0]),Vector3(cos(d)*rings[j+1][1],sin(d)*rings[j+1][1],rings[j+1][0]),Vector3(cos(a)*rings[j+1][1],sin(a)*rings[j+1][1],rings[j+1][0]),Vector3(cos((a+d)/2),sin((a+d)/2),0))
	for i in 48:
		var a := TAU*i/48
		var d := TAU*(i+1)/48
		p.quad("metal",Vector3(cos(a)*1.38,sin(a)*1.38,-3),Vector3(cos(a)*1.20,sin(a)*1.20,-2.93),Vector3(cos(d)*1.20,sin(d)*1.20,-2.93),Vector3(cos(d)*1.38,sin(d)*1.38,-3),Vector3(0,0,-1))
		p.quad("dark",Vector3(cos(a)*1.20,sin(a)*1.20,-2.93),Vector3(cos(a)*1.16,sin(a)*1.16,-2.48),Vector3(cos(d)*1.16,sin(d)*1.16,-2.48),Vector3(cos(d)*1.20,sin(d)*1.20,-2.93),Vector3(-cos(a),-sin(a),0))
	for i in 18:
		var a := TAU*i/18
		var d := TAU*(i+1)/18
		var mid := (a+d)/2
		p.triangle("white",Vector3(cos(a)*1.08,sin(a)*1.08,2.4),Vector3(cos(d)*1.08,sin(d)*1.08,2.4),Vector3(cos(mid)*.96,sin(mid)*.96,2.82),Vector3(cos(mid),sin(mid),0))
	f._cylinder(engine,.62,1.12,Vector3(0,0,2.10),m.brake,Vector3(PI/2,0,0),.43)
	f._cylinder(engine,.40,.62,Vector3(0,0,2.55),m.carbon,Vector3(PI/2,0,0),.04)
	var fan := Node3D.new()
	fan.position.z = -2.54
	engine.add_child(fan)
	var blades := Panels.new(fan,m)
	for i in 22:
		var a := TAU*i/22
		var pts := []
		for pair in [[.28,a],[.38,a+.20],[1.14,a+.32],[1.14,a+.18]]: pts.append(Vector3(cos(pair[1])*pair[0],sin(pair[1])*pair[0],0))
		blades.polygon("metal",pts,Vector3(0,0,-1))
	blades.finish()
	f._cylinder(fan,.25,.40,Vector3(0,0,-.10),m.dark,Vector3(PI/2,0,0),.03)
	moving.propellers.append(fan)
	p.finish()
	f._sphere_collision(body,1.5,center)
