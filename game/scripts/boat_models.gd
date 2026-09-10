extends RefCounted
## Original photo-informed metre-scale hulls. Forward -Z; waterline local Y=-0.9.
const SPECS={"speedboat":{"length":11.88,"beam":3.5,"draft":1.2},"yacht":{"length":27.1,"beam":7.16,"draft":1.94}}

static func build(body:Node3D,kind:String,materials:Dictionary,moving:Dictionary,factory:Script):
	var m:=materials.duplicate()
	m.navy=factory.material(Color("173647"),0.72,0.2)
	m.cream=factory.material(Color("eee5d1"),0.04,0.65)
	m.teak=factory.material(Color("ad764a"),0.05,0.65)
	m.seam=factory.material(Color("4b3e2e"),0.02,0.87)
	m.window=factory.material(Color("244857"),0.35,0.2)
	m.windshield=m.window.duplicate()
	m.windshield.cull_mode=BaseMaterial3D.CULL_DISABLED
	m.windshield.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.windshield.albedo_color=Color(.15,.32,.4,.72)
	m.screen=factory.material(Color("4e9dac"),0.25,0.25)
	if kind=="speedboat": _speedboat(body,m,moving,factory)
	else: _yacht(body,m,moving,factory)
	body.set_meta("boat_spec",SPECS[kind])
	body.set_meta("model_reference","Riva Rivamare" if kind=="speedboat" else "Sunseeker 90 Ocean")
	body.set_meta("model_confidence","Official length/beam; original photo-informed hull and deck layout, not builder CAD")

static func _triangle(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3):
	var normal:Vector3=(c-a).cross(b-a).normalized()
	for p in [a,b,c]:
		st.set_normal(normal)
		st.add_vertex(p)

static func _quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3):
	_triangle(st,a,b,c);_triangle(st,a,c,d)

static func _surface(parent:Node3D,st:SurfaceTool,mat:Material,name:String,collision:=false) -> MeshInstance3D:
	var instance:=MeshInstance3D.new()
	instance.name=name
	instance.mesh=st.commit()
	instance.material_override=mat
	parent.add_child(instance)
	if collision:
		var shape:=CollisionShape3D.new()
		shape.name=name+"_collision"
		shape.shape=instance.mesh.create_convex_shape()
		parent.add_child(shape)
	return instance

static func _hull(parent:Node3D,stations:Array,mat:Material) -> Array:
	var ring:Array=[]
	for row in stations:
		var z:float=row[0];var w:float=row[1];var top:float=row[2];var keel:float=row[3]
		ring.append([Vector3(w,top,z),Vector3(w*.96,-0.85,z),Vector3(w*.74,keel+.28,z),Vector3(0,keel,z),Vector3(-w*.74,keel+.28,z),Vector3(-w*.96,-0.85,z),Vector3(-w,top,z)])
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(ring.size()-1):
		for j in 7:
			var k: int=(j+1)%7
			_quad(st,ring[i][j],ring[i][k],ring[i+1][k],ring[i+1][j])
	# Closed stem and transom; convex collision follows the actual hull envelope.
	for i in range(1,6):
		_triangle(st,ring[0][0],ring[0][i+1],ring[0][i])
		_triangle(st,ring[-1][0],ring[-1][i],ring[-1][i+1])
	_surface(parent,st,mat,"ClosedHull",true)
	return ring

static func _deck_outline(stations:Array,y:float) -> Array[Vector3]:
	var outline:Array[Vector3]=[]
	for row in stations:outline.append(Vector3(row[1]*.95,y,row[0]))
	for i in range(stations.size()-1,-1,-1):outline.append(Vector3(-stations[i][1]*.95,y,stations[i][0]))
	return outline

static func _deck(b:Node3D,f:Script,outline:Array[Vector3],mat:Material,thickness:=0.12,collision:=true):
	f._prism(b,outline,thickness,mat,collision)

static func _teak_rectangle(b:Node3D,f:Script,m:Dictionary,center:Vector3,size:Vector2,collision:=false):
	f._box(b,Vector3(size.x,.10,size.y),center-Vector3.UP*.05,m.teak)
	if collision:f._box_collision(b,Vector3(size.x,.1,size.y),center-Vector3.UP*.05)
	for i in range(int(size.x/.115)):
		var x:float=center.x-size.x*.5+.08+i*.115
		f._box(b,Vector3(.007,.003,size.y-.07),Vector3(x,center.y+.003,center.z),m.seam)
	for edge in [-1,1]:f._box(b,Vector3(.024,.004,size.y),center+Vector3(edge*(size.x*.5-.04),.003,0),m.cream)

static func _rail(b:Node3D,f:Script,m:Dictionary,points:Array[Vector3],height:=.82):
	for i in range(points.size()-1):
		f._rod(b,points[i]+Vector3.UP*height,points[i+1]+Vector3.UP*height,.026,m.metal)
		f._rod(b,points[i]+Vector3.UP*height*.48,points[i+1]+Vector3.UP*height*.48,.013,m.metal)
		var pieces:=maxi(1,int(ceil(points[i].distance_to(points[i+1])/1.35)))
		for j in pieces:
			var p:Vector3=points[i].lerp(points[i+1],float(j)/pieces)
			f._rod(b,p,p+Vector3.UP*height,.022,m.metal)
	if not points.is_empty():f._rod(b,points[-1],points[-1]+Vector3.UP*height,.022,m.metal)

static func _cushion(b:Node3D,size:Vector3,at:Vector3,mat:Material,yaw:=0.0):
	var radius:float=minf(size.x,size.z)*.23
	var bevel:float=minf(size.y*.24,radius*.6)
	var rings:Array=[]
	for layer in 4:
		var inset:float=bevel if layer in [0,3] else 0.0
		var y:float=[-size.y*.5,-size.y*.5+bevel,size.y*.5-bevel,size.y*.5][layer]
		var ring:Array[Vector3]=[]
		for corner in 4:
			var angle:float=corner*PI*.5
			var center:=Vector2((size.x*.5-radius)*(1 if corner in [0,3] else -1),(size.z*.5-radius)*(1 if corner in [0,1] else -1))
			for step in 6:
				var theta:=angle+step*PI*.5/5
				ring.append(Vector3(center.x+cos(theta)*(radius-inset),y,center.y+sin(theta)*(radius-inset)))
		rings.append(ring)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in 3:
		for i in 24:
			var j: int=(i+1)%24
			_quad(st,rings[layer][i],rings[layer][j],rings[layer+1][j],rings[layer+1][i])
	for i in 24:
		var j: int=(i+1)%24
		_triangle(st,Vector3(0,size.y*.5,0),rings[3][i],rings[3][j])
		_triangle(st,Vector3(0,-size.y*.5,0),rings[0][j],rings[0][i])
	var mesh:=_surface(b,st,mat,"RoundedUpholstery")
	mesh.position=at;mesh.rotation.y=yaw

static func _sofa(b:Node3D,f:Script,m:Dictionary,at:Vector3,width:float,depth:=.72,rotation_y:=0.0):
	var basis:=Basis(Vector3.UP,rotation_y)
	f._box(b,Vector3(width,.25,depth),at+basis*Vector3(0,.125,0),m.white,Vector3(0,rotation_y,0))
	_cushion(b,Vector3(width-.06,.16,depth-.06),at+basis*Vector3(0,.34,-.025),m.cream,rotation_y)
	_cushion(b,Vector3(width,.56,.18),at+basis*Vector3(0,.5,depth*.5-.09),m.cream,rotation_y)
	for side in [-1,1]:_cushion(b,Vector3(.13,.4,depth),at+basis*Vector3(side*(width*.5-.065),.45,0),m.cream,rotation_y)
	for split in range(1,maxi(2,int(width/.55))):
		var x:float=-width*.5+width*split/maxi(2,int(width/.55))
		f._box(b,Vector3(.01,.006,depth-.15),at+basis*Vector3(x,.425,-.03),m.teak,Vector3(0,rotation_y,0))

static func _helm(b:Node3D,f:Script,m:Dictionary,at:Vector3,width:=1.15):
	f._box(b,Vector3(width,.67,.53),at+Vector3(0,.335,0),m.navy)
	f._box(b,Vector3(width+.12,.14,.68),at+Vector3(0,.73,-.04),m.cream,Vector3(-.18,0,0))
	for x in [-.28,.28]:
		f._box(b,Vector3(.42,.035,.28),at+Vector3(x,.82,-.16),m.window,Vector3(-.25,0,0))
		f._box(b,Vector3(.36,.012,.23),at+Vector3(x,.842,-.16),m.screen,Vector3(-.25,0,0))
		for k in 3:f._box(b,Vector3(.008,.013,.09),at+Vector3(x-.1+k*.09,.858,-.16),m.light,Vector3(-.25,0,0))
	var wheel:=at+Vector3(0,.87,.41)
	for i in 28:
		var a:=wheel+Vector3(cos(TAU*i/28)*.18,sin(TAU*i/28)*.18,0)
		var c:=wheel+Vector3(cos(TAU*(i+1)/28)*.18,sin(TAU*(i+1)/28)*.18,0)
		f._rod(b,a,c,.016,m.dark)
	for i in 3:f._rod(b,wheel,wheel+Vector3(cos(TAU*i/3)*.17,sin(TAU*i/3)*.17,0),.012,m.metal)
	f._rod(b,at+Vector3(.48,.7,.1),at+Vector3(.48,1.0,.05),.025,m.metal)

static func _window_strip(b:Node3D,f:Script,m:Dictionary,stations:Array,z0:float,z1:float,low:float,high:float):
	for side in [-1,1]:
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(stations.size()-1):
			var a:Array=stations[i];var c:Array=stations[i+1]
			if a[0]<z0 or c[0]>z1:continue
			var pa:=Vector3(side*(lerpf(a[1]*.96,a[1],(high+.85)/(a[2]+.85))+.014),high,a[0])
			var pc:=Vector3(side*(lerpf(c[1]*.96,c[1],(high+.85)/(c[2]+.85))+.014),high,c[0])
			var pb:=Vector3(side*(lerpf(a[1]*.96,a[1],(low+.85)/(a[2]+.85))+.014),low,a[0])
			var pd:=Vector3(side*(lerpf(c[1]*.96,c[1],(low+.85)/(c[2]+.85))+.014),low,c[0])
			if side>0:_quad(st,pc,pa,pb,pd)
			else:_quad(st,pa,pc,pd,pb)
		_surface(b,st,m.window,"HullWindows")

static func _speedboat(b:Node3D,m:Dictionary,v:Dictionary,f:Script):
	var stations:Array=[[-5.94,.018,.78,-1.05],[-5.3,.55,.73,-1.6],[-4.4,1.12,.68,-1.88],[-3.3,1.5,.59,-2.04],[-2,1.68,.48,-2.1],[0,1.75,.38,-2.05],[1.7,1.72,.34,-1.97],[3.4,1.64,.34,-1.83],[4.8,1.52,.31,-1.55],[5.35,1.43,.26,-1.3]]
	_hull(b,stations,m.navy)
	_deck(b,f,_deck_outline(stations,.4),m.navy,.08,false)
	# Long warm foredeck, following the tapered bow outline.
	var bow:Array=stations.slice(0,5)
	_deck(b,f,_deck_outline(bow,.72),m.teak,.07,false)
	for i in range(-11,12):
		var x:=i*.112
		var zmin:float=-5.7+pow(absf(x)/1.5,1.8)*2.1
		f._box(b,Vector3(.007,.004,-2.05-zmin),Vector3(x,.759,(zmin-2.05)*.5),m.seam)
	_teak_rectangle(b,f,m,Vector3(0,.46,1.15),Vector2(2.65,5.05),true)
	_teak_rectangle(b,f,m,Vector3(0,-.09,5.56),Vector2(2.7,.76),true)
	# Cockpit is open: a swept continuous curved windshield, no roof blob.
	var glass:=SurfaceTool.new();glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim:Array[Vector3]=[]
	for i in 33:
		var angle:float=-PI*.5+PI*i/32
		var base:=Vector3(sin(angle)*1.48,.76,-.3-cos(angle)*1.7)
		var top:=base+Vector3(0,.76,.36)
		rim.append(top)
		if i>0:
			var previous:float=-PI*.5+PI*(i-1)/32
			var pbase:=Vector3(sin(previous)*1.48,.76,-.3-cos(previous)*1.7)
			_quad(glass,pbase,base,top,pbase+Vector3(0,.76,.36))
	_surface(b,glass,m.windshield,"CurvedWindshield")
	for i in 32:f._rod(b,rim[i],rim[i+1],.026,m.metal)
	for side in [-1,1]:
		var trim:Array[Vector3]=[]
		for row in stations:trim.append(Vector3(side*row[1],row[2]+.10,row[0]))
		for i in range(trim.size()-1):f._rod(b,trim[i],trim[i+1],.024,m.metal)
		_sofa(b,f,m,Vector3(side*.67,.47,.36),1.0,.64)
		f._box(b,Vector3(.18,.62,2.6),Vector3(side*1.32,.72,2.2),m.cream)
		for k in 11:f._box(b,Vector3(.024,.12,.48),Vector3(side*1.61,.52,3.3+k*.085),m.metal,Vector3(0,0,side*.16))
	_sofa(b,f,m,Vector3(0,.47,2.75),2.2,.65)
	_helm(b,f,m,Vector3(.62,.46,-.74),.95)
	_cushion(b,Vector3(2.55,.23,1.52),Vector3(0,.84,4.05),m.cream)
	for x in [-.8,0,.8]:f._box(b,Vector3(.013,.005,1.44),Vector3(x,.96,4.05),m.teak)
	f._box(b,Vector3(.7,.05,.62),Vector3(0,.765,-3.32),m.window)
	_window_strip(b,f,m,stations,-4.4,1.7,-.03,.24)
	for side in [-1,1]:
		f._box(b,Vector3(.1,.055,.26),Vector3(side*1.28,.8,-2.8),m.metal)
		f._box(b,Vector3(.16,.08,.24),Vector3(side*1.54,.46,1.8),m.light if side<0 else m.red)
		f._box(b,Vector3(.14,.22,.2),Vector3(side*.54,-1.45,5.28),m.metal)
		f._cylinder(b,.19,.12,Vector3(side*.54,-1.55,5.43),m.metal,Vector3(PI*.5,0,0))
	b.set_meta("boat_profile",{"buoyancy_x":1.1,"buoyancy_z":3.6,"float_height":.9,"wake_z":5.55,"exit":Vector3(0,.15,5.53),"camera_distance":18.0,"camera_height":1.1,"cargo_position":Vector3(0,.49,1.6),"cargo_bounds":AABB(Vector3(-.45,.46,1.1),Vector3(.9,.3,.8))})
	v.material=m.navy

static func _yacht(b:Node3D,m:Dictionary,v:Dictionary,f:Script):
	var stations:Array=[[-13.55,.035,1.8,-.8],[-12.8,.8,1.8,-1.85],[-11.5,1.78,1.75,-2.35],[-9.5,2.72,1.7,-2.72],[-7,3.3,1.4,-2.84],[-4,3.53,1.15,-2.84],[0,3.58,1.15,-2.8],[4,3.56,1.15,-2.65],[8,3.49,1.13,-2.42],[10.65,3.34,1.08,-2.05],[11.5,3.21,.72,-1.58]]
	_hull(b,stations,m.white)
	_deck(b,f,_deck_outline(stations,1.28),m.white,.16,false)
	_teak_rectangle(b,f,m,Vector3(0,1.46,7.68),Vector2(6.3,6.0),true)
	_teak_rectangle(b,f,m,Vector3(0,-.08,12.38),Vector2(6.2,2.34),true)
	# Foredeck follows the hull; the raised bow carries seating and a sunpad.
	_deck(b,f,_deck_outline(stations.slice(0,5),1.92),m.teak,.13,true)
	for i in range(-24,25):
		var x:=i*.115
		var start:float=-13.45
		for j in range(4):
			if absf(x)>stations[j][1]*.95 and absf(x)<=stations[j+1][1]*.95:
				start=lerpf(stations[j][0],stations[j+1][0],(absf(x)-stations[j][1]*.95)/((stations[j+1][1]-stations[j][1])*.95))+.07
		if start < -7.1:f._box(b,Vector3(.006,.003,-7.08-start),Vector3(x,1.989,(start-7.08)*.5),m.seam)
	for side in [-1,1]:
		_teak_rectangle(b,f,m,Vector3(side*3.15,1.46,-.55),Vector2(.48,12.0),true)
		var rail:Array[Vector3]=[]
		for row in stations.slice(0,9):rail.append(Vector3(side*row[1]*.96,1.92 if row[0]<-7 else 1.46,row[0]))
		_rail(b,f,m,rail)
		# Nine tread stern stairs join the real aft deck and beach platform.
		for i in 9:
			var y:float=-.08+(i+1)*1.54/9
			var z:float=12.55-i*.25
			f._box(b,Vector3(.94,.18,.26),Vector3(side*2.66,y-.09,z),m.white)
			f._box(b,Vector3(.87,.015,.22),Vector3(side*2.66,y+.008,z),m.teak)
		# One continuous inclined contact under the visual treads.
		var a:=Vector3(side*2.66,-.08,12.68);var c:=Vector3(side*2.66,1.46,10.55)
		var angle:float=atan2(c.y-a.y,a.z-c.z)
		f._box_collision(b,Vector3(.94,.16,a.distance_to(c)),(a+c)*.5-Vector3.UP*.08,Vector3(angle,0,0))
		_rail(b,f,m,[Vector3(side*3.13,-.08,12.68),Vector3(side*3.13,1.46,10.55),Vector3(side*3.13,1.46,5.1)])
	_window_strip(b,f,m,stations,-9.5,8,-.54,.35)
	# Main saloon: continuous dark ribbon, pale roof, raked forward windshield.
	var cabin:Array[Vector3]=[Vector3(-2.7,4.06,-6.4),Vector3(2.7,4.06,-6.4),Vector3(3.04,4.06,4.5),Vector3(-3.04,4.06,4.5)]
	_deck(b,f,cabin,m.white,.25,true)
	for side in [-1,1]:
		f._box(b,Vector3(.12,2.38,9.4),Vector3(side*2.87,2.77,-.3),m.window)
		f._box_collision(b,Vector3(.14,2.38,9.4),Vector3(side*2.87,2.77,-.3))
		for z in [-4.7,-1.8,1.2,3.85]:f._box(b,Vector3(.15,2.43,.1),Vector3(side*2.9,2.76,z),m.metal)
		# Photographed diagonal white cheek sweeps upward toward the bow.
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var x:float=side*3.31
		var cheek:Array[Vector3]=[Vector3(x,1.5,4.7),Vector3(x,1.5,-7.0),Vector3(x,2.65,-5.8),Vector3(x,1.86,2.8)]
		if side>0:cheek.reverse()
		_quad(st,cheek[0],cheek[1],cheek[2],cheek[3])
		_surface(b,st,m.white,"SweptSideCheek")
	f._box(b,Vector3(5.3,2.45,.13),Vector3(0,2.77,-5.78),m.window,Vector3(-.24,0,0))
	f._box_collision(b,Vector3(5.3,2.45,.13),Vector3(0,2.77,-5.78),Vector3(-.24,0,0))
	f._box(b,Vector3(5.72,2.4,.13),Vector3(0,2.78,4.45),m.window)
	f._box_collision(b,Vector3(5.72,2.4,.13),Vector3(0,2.78,4.45))
	for x in [-1.85,0,1.85]:f._box(b,Vector3(.08,2.5,.2),Vector3(x,2.78,4.49),m.metal)
	_sofa(b,f,m,Vector3(0,1.48,5.1),3.6,.75,PI)
	_sofa(b,f,m,Vector3(0,1.94,-7.5),3.7,.86)
	_cushion(b,Vector3(2.8,.23,2.1),Vector3(0,2.06,-10.0),m.cream)
	# Flybridge deck projects over the aft lounge; open sides under a carbon roof.
	var fly:Array[Vector3]=[Vector3(-2.1,4.4,-4.1),Vector3(2.5,4.4,-4.1),Vector3(3.1,4.4,-1.2),Vector3(3.1,4.4,8),Vector3(-2.1,4.4,8),Vector3(-2.1,4.4,-1.2)]
	_deck(b,f,fly,m.white,.2,true)
	_deck(b,f,[Vector3(-3.1,4.4,-1.2),Vector3(-2.1,4.4,-1.2),Vector3(-2.1,4.4,4.65),Vector3(-3.1,4.4,4.65)],m.white,.2,true)
	_deck(b,f,[Vector3(-2.5,4.4,-4.1),Vector3(-2.1,4.4,-4.1),Vector3(-2.1,4.4,-1.2),Vector3(-3.1,4.4,-1.2)],m.white,.2,true)
	_teak_rectangle(b,f,m,Vector3(.37,4.505,2.2),Vector2(4.78,10.6))
	_teak_rectangle(b,f,m,Vector3(-2.6,4.505,1.66),Vector2(.87,5.82))
	for side in [-1,1]:
		if side>0:_rail(b,f,m,[Vector3(2.85,4.43,-3.0),Vector3(2.98,4.43,7.65),Vector3(.55,4.43,7.65)])
		else:
			_rail(b,f,m,[Vector3(-2.85,4.43,-3.0),Vector3(-2.98,4.43,4.55)])
			_rail(b,f,m,[Vector3(-2.08,4.43,4.7),Vector3(-2.08,4.43,7.65),Vector3(-.55,4.43,7.65)])
		# Swept flying buttresses in the real side silhouette.
		f._box(b,Vector3(.38,3.1,.62),Vector3(side*2.8,5.72,.05),m.white,Vector3(-.72,0,0))
		f._rod(b,Vector3(side*2.5,4.5,-3),Vector3(side*2.8,6.75,-2.35),.055,m.metal)
		_sofa(b,f,m,Vector3(side*1.57,4.45,3.3),2.1,.77,side*PI*.5)
		f._cylinder(b,.35,.65,Vector3(side*1.9,7.43,2.65),m.dark)
		f._ellipsoid(b,Vector3(.36,.28,.36),Vector3(side*1.9,7.78,2.65),m.dark)
	_helm(b,f,m,Vector3(.9,4.44,-2.6),1.2)
	_sofa(b,f,m,Vector3(.9,4.44,-1.15),1.2,.8)
	_teak_rectangle(b,f,m,Vector3(0,5.14,3.4),Vector2(1.1,2.25))
	f._cylinder(b,.13,.73,Vector3(0,4.78,3.4),m.metal)
	_sofa(b,f,m,Vector3(0,4.44,6.9),3.5,.9)
	var roof:Array[Vector3]=[Vector3(-2.8,6.85,-3.25),Vector3(2.8,6.85,-3.25),Vector3(3.03,6.85,4.6),Vector3(-3.03,6.85,4.6)]
	_deck(b,f,roof,m.dark,.18,true)
	f._rod(b,Vector3(0,7.0,2.5),Vector3(0,9.1,3.2),.085,m.dark)
	for y in [7.9,8.45,8.85]:f._rod(b,Vector3(-.55,y,2.9),Vector3(.55,y,2.9),.035,m.white)
	f._rod(b,Vector3(1.9,7.8,2.65),Vector3(1.9,9.0,2.65),.012,m.metal)
	# External port stair rises from aft deck to flybridge, outside cargo bay.
	for i in 15:
		var at:=Vector3(-2.62,1.47+(i+1)*2.95/15,7.8-i*.19)
		f._box(b,Vector3(.82,.12,.22),at-Vector3.UP*.06,m.teak)
	var stair_a:=Vector3(-2.62,1.46,7.96);var stair_b:=Vector3(-2.62,4.42,5.04)
	f._box_collision(b,Vector3(.84,.16,stair_a.distance_to(stair_b)),(stair_a+stair_b)*.5-Vector3.UP*.08,Vector3(atan2(2.96,2.92),0,0))
	_rail(b,f,m,[stair_a+Vector3(.45,0,0),stair_b+Vector3(.45,0,0)])
	b.set_meta("boat_profile",{"buoyancy_x":2.35,"buoyancy_z":8.2,"float_height":.9,"wake_z":13.5,"exit":Vector3(0,.16,12.65),"camera_distance":39.0,"camera_height":3.8,"cargo_position":Vector3(.35,1.49,8.55),"cargo_bounds":AABB(Vector3(-1.9,1.46,6.05),Vector3(4.65,.35,4.7)),"car_position":Vector3(0,1.46,9.1),"car_heading":PI*.5,"car_bounds":AABB(Vector3(-2.8,1.46,7.97),Vector3(5.6,.2,2.27))})
	v.material=m.white
