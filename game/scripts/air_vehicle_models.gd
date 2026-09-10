extends RefCounted
## Original procedural models. Manufacturer images establish silhouettes; documented
## dimensions establish scale. Fine sections/materials are approximations, not CAD.
const Detail=preload("res://scripts/vehicle_refinement.gd")

static func build(b:Node3D,kind:String,m:Dictionary,v:Dictionary,f:Script):
	m["fabric"]=f.material(Color("f38938"),0,.82)
	m["ivory"]=f.material(Color("f6f3e8"),.08,.42)
	m["rib"]=f.material(Color("efe9dc"),0,.9)
	m["carbon"]=f.material(Color("17232b"),.30,.37)
	m["brake"]=f.material(Color("788187"),.85,.32)
	m["gold"]=f.material(Color("bbc6cd"),.8,.22)
	match kind:
		"glider":_sailplane(b,m,v,f)
		"paraglider":_paraglider(b,m,v,f)
		"helicopter":_helicopter(b,m,v,f)

static func _point(station:Array,a:float)->Vector3:
	return Vector3(float(station[1])*cos(a),float(station[3])+float(station[2])*sin(a),float(station[0]))

static func _loft(b:Node3D,m:Dictionary,stations:Array,style:String,collision:bool=true):
	var p=Detail.Panels.new(b,m)
	p.smooth_keys=["white","glass","teal","ivory"]
	var points:=[]
	for j in stations.size()-1:
		var z:float=(float(stations[j][0])+float(stations[j+1][0]))*.5
		for i in 48:
			var a:=TAU*i/48.;var c:=TAU*(i+1)/48.
			var normal:=Vector3(cos((a+c)/2),sin((a+c)/2),0)
			var key:="white"
			if style=="sailplane":
				if z>-2.72 and z<-.7 and normal.y>.08:key="glass"
				elif normal.y>-.28 and normal.y<-.02 and z<1.2:key="teal"
			elif style=="helicopter":
				if z>-4.32 and z<-1.60 and normal.y>.02 and normal.y<.965:key="glass"
				elif z>-.95 and z<1.50 and normal.y>.08 and normal.y<.92:key="glass"
				elif normal.y<-.42:key="teal"
			p.quad(key,_point(stations[j],a),_point(stations[j+1],a),_point(stations[j+1],c),_point(stations[j],c),normal)
			if collision:
				points.append(_point(stations[j],a));points.append(_point(stations[j+1],a))
	for end_index in [0,stations.size()-1]:
		var station:Array=stations[end_index]
		for i in 48:p.triangle("white",Vector3(0,float(station[3]),float(station[0])),_point(station,TAU*i/48.),_point(station,TAU*(i+1)/48.),Vector3.FORWARD if end_index==0 else Vector3.BACK)
	p.finish()
	if collision:Detail._convex(b,points)

static func _foil_point(st:Array,t:float,side:int,upper:bool)->Vector3:
	var thickness:=float(st[4])*(.2969*sqrt(t)-.126*t-.3516*t*t+.2843*t*t*t-.1036*t*t*t*t)*5.
	var camber:=float(st[4])*.10*sin(PI*t)
	return Vector3(float(st[0])*side,float(st[1])+camber+(thickness if upper else -thickness),float(st[2])+float(st[3])*t)

static func _wing(b:Node3D,m:Dictionary,stations:Array,side:int,key:String,collision:bool=true):
	var p=Detail.Panels.new(b,m);p.smooth_keys=[key]
	for j in stations.size()-1:
		var hull:=[]
		for k in 20:
			# Cosine spacing gives a rounded leading edge and a thin trailing edge.
			var t:float=(1-cos(PI*k/20.))*.5;var next:float=(1-cos(PI*(k+1)/20.))*.5
			for upper in [true,false]:
				var a:=_foil_point(stations[j],t,side,upper);var c:=_foil_point(stations[j+1],t,side,upper);var d:=_foil_point(stations[j+1],next,side,upper);var e:=_foil_point(stations[j],next,side,upper)
				p.quad(key,a,c,d,e,Vector3.UP if upper else Vector3.DOWN)
				hull.append(a);hull.append(c)
		if collision:Detail._convex(b,hull)
	for index in [0,stations.size()-1]:
		for k in 20:
			var t:=k/20.;var next:=(k+1)/20.
			p.quad(key,_foil_point(stations[index],t,side,true),_foil_point(stations[index],next,side,true),_foil_point(stations[index],next,side,false),_foil_point(stations[index],t,side,false),Vector3(side,0,0))
	p.finish()

static func _vertical(b:Node3D,m:Dictionary,outline:Array,half_width:float,key:String,collision:bool=true):
	var p=Detail.Panels.new(b,m);var vertices:=[]
	for side:int in [-1,1]:
		var face:=[]
		for point:Vector2 in outline:
			var vertex:=Vector3(side*half_width,point.x,point.y);face.append(vertex);vertices.append(vertex)
		p.polygon(key,face,Vector3(side,0,0))
	for i in outline.size():
		var a:Vector2=outline[i];var c:Vector2=outline[(i+1)%outline.size()]
		p.quad(key,Vector3(-half_width,a.x,a.y),Vector3(half_width,a.x,a.y),Vector3(half_width,c.x,c.y),Vector3(-half_width,c.x,c.y),Vector3(0,c.y-a.y,a.x-c.x))
	p.finish()
	if collision:Detail._convex(b,vertices)

static func _sailplane(b:Node3D,m:Dictionary,v:Dictionary,f:Script):
	m.glass=f.material(Color(.13,.28,.34,.28),.05,.15)
	m.glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	m.glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	b.set_meta("vehicle_model",{"reference":"Alexander Schleicher AS 33 (18 m configuration)","ground":-.67,"length":6.85,"span":18.0,"features":["18m tapered airfoil wing","raised winglets","long bubble glazing","slender compound fuselage","high T tail","central retractable wheel","tailwheel","airbrakes and split aileron seams"]})
	_loft(b,m,[[-3.15,.018,.025,-.03],[-3.02,.17,.16,.03],[-2.72,.285,.29,.08],[-2.30,.35,.43,.10],[-1.8,.36,.51,.10],[-1.18,.35,.50,.10],[-.70,.33,.43,.03],[.05,.31,.32,-.05],[.8,.23,.235,-.04],[1.8,.15,.15,.025],[2.8,.08,.10,.10],[3.62,.042,.055,.12],[3.70,.008,.008,.12]],"sailplane")
	for side:int in [-1,1]:
		_wing(b,m,[[.30,.08,-.5,1.12,.105],[2.5,.13,-.51,.98,.085],[4.8,.22,-.50,.72,.065],[6.7,.35,-.42,.46,.048],[8.35,.54,-.27,.28,.032],[8.78,.66,-.15,.19,.023],[9.,1.23,-.01,.11,.015]],side,"white")
		_wing(b,m,[[.06,1.77,2.78,.79,.064],[.65,1.80,2.88,.53,.048],[1.2,1.86,3.10,.29,.030]],side,"white")
		# Real panel boundaries are thin dark curves, not raised steel bars.
		f._rod(b,Vector3(side*.40,.149,.435),Vector3(side*7.70,.483,.077),.0035,m.dark)
		f._box(b,Vector3(1.16,.014,.115),Vector3(side*2.07,.185,-.13),m.metal,Vector3(0,0,side*.025))
		for z in [-2.72,-.70]:
			var rx:=.285 if z<-2 else .33;var ry:=.29 if z<-2 else .43;var cy:=.08 if z<-2 else .03
			for i in 15:
				var a:=PI*i/15.;var c:=PI*(i+1)/15.
				f._rod(b,Vector3(rx*cos(a),cy+ry*sin(a),z),Vector3(rx*cos(c),cy+ry*sin(c),z),.007,m.white)
	_vertical(b,m,[Vector2(.06,2.53),Vector2(1.69,2.92),Vector2(1.83,3.19),Vector2(1.79,3.64),Vector2(.09,3.64)],.055,"white")
	# Control hinges and canopy release handle.
	f._rod(b,Vector3(-.059,.15,3.44),Vector3(-.059,1.75,3.44),.004,m.teal)
	f._box(b,Vector3(.025,.027,.16),Vector3(-.350,.11,-1.05),m.metal)
	Detail._wheel(b,Vector3(0,-.43,-.23),.24,.105,m,v,f,8)
	Detail._wheel(b,Vector3(0,-.57,3.31),.10,.065,m,v,f,6)
	f._rod(b,Vector3(0,-.25,-.23),Vector3(0,-.43,-.23),.045,m.metal)
	f._rod(b,Vector3(0,.11,3.31),Vector3(0,-.57,3.31),.024,m.metal)
	f._ellipsoid(b,Vector3(.075,.20,.15),Vector3(0,-.19,3.31),m.white)
	# Visible reclined cockpit: cushion, instrument panel, stick and pilot.
	f._ellipsoid(b,Vector3(.24,.11,.61),Vector3(0,-.22,-1.58),m.carbon)
	f._ellipsoid(b,Vector3(.27,.17,.095),Vector3(0,-.01,-2.18),m.carbon)
	for x in [-.15,0,.15]:
		f._cylinder(b,.053,.009,Vector3(x,.03,-2.079),m.metal,Vector3(PI/2,0,0))
		f._cylinder(b,.044,.011,Vector3(x,.03,-2.073),m.dark,Vector3(PI/2,0,0))
		f._rod(b,Vector3(x,.03,-2.063),Vector3(x+.02,.05,-2.063),.002,m.light)
	f._rod(b,Vector3(0,-.24,-1.81),Vector3(0,.02,-1.86),.012,m.dark)
	var pilot:=Node3D.new();pilot.name="Reclined_glider_pilot";pilot.visible=false;b.add_child(pilot)
	f._ellipsoid(pilot,Vector3(.18,.22,.13),Vector3(0,.02,-1.23),m.blue)
	f._ellipsoid(pilot,Vector3(.125,.145,.135),Vector3(0,.34,-1.09),m.ivory)
	f._ellipsoid(pilot,Vector3(.11,.06,.025),Vector3(0,.36,-1.216),m.dark)
	for side:int in [-1,1]:
		f._rod(pilot,Vector3(side*.10,-.13,-1.35),Vector3(side*.10,-.24,-1.94),.064,m.dark)
		f._rod(pilot,Vector3(side*.16,.10,-1.29),Vector3(side*.10,-.02,-1.72),.049,m.blue)
	v.rider=pilot

static func _canopy_point(t:float,chord:float,upper:bool)->Vector3:
	var angle:=t*1.25
	var radius:=4.95
	var x:=sin(angle)*radius
	var center_y:=7.0-(1-cos(angle))*radius
	var length:=lerpf(2.99,1.85,pow(absf(t),1.65))
	var thickness:=.29*sin(PI*pow(chord,.62))
	var cell_bulge:=sin(PI*fposmod((t+1)*24,1.0))*.040*sin(PI*chord)
	return Vector3(x,center_y+(thickness+cell_bulge if upper else -thickness*.31),-.95+absf(t)*.54+length*chord)

static func _paraglider(b:Node3D,m:Dictionary,v:Dictionary,f:Script):
	b.set_meta("vehicle_model",{"reference":"Ozone Buzz Z7 L","ground":-.63,"span":9.40,"flat_span":12.21,"cells":48,"features":["48 inflated cells","arched elliptic canopy","rounded airfoil nose","open intake slots","cascading suspension lines","left and right risers","padded seated harness","separate occupied pilot"]})
	var p=Detail.Panels.new(b,m);p.smooth_keys=["fabric","ivory","teal"]
	for cell in 48:
		for across in 3:
			var t0:float=-1+(cell+across/3.)/24.;var t1:float=-1+(cell+(across+1)/3.)/24.
			for j in 22:
				var q0:float=(1-cos(PI*j/22.))*.5;var q1:float=(1-cos(PI*(j+1)/22.))*.5
				var key:="fabric"
				if q0>.68 or (absf(t0)>.87 and q0>.20):key="teal"
				elif q0>.55:key="ivory"
				for upper in [true,false]:
					if not upper and j<2:continue # Separate leading-edge open cells.
					p.quad(key,_canopy_point(t0,q0,upper),_canopy_point(t1,q0,upper),_canopy_point(t1,q1,upper),_canopy_point(t0,q1,upper),Vector3(t0*.45,1,0)*(1 if upper else -1))
		# Thin interior dividers and dark recessed intake are visible across the nose.
		var t0:float=-1+cell/24.;var t1:float=-1+(cell+1)/24.
		p.quad("dark",_canopy_point(t0,.028,true),_canopy_point(t1,.028,true),_canopy_point(t1,.028,false),_canopy_point(t0,.028,false),Vector3.FORWARD)
		var t:float=-1+cell/24.
		for j in 6:
			var q0:=j/6.;var q1:=(j+1)/6.
			p.quad("rib",_canopy_point(t,q0,true),_canopy_point(t,q1,true),_canopy_point(t,q1,false),_canopy_point(t,q0,false),Vector3.RIGHT)
	p.finish()
	# Three suspension rows, split into a main riser and branching upper lines.
	for side:int in [-1,1]:
		var riser:=Vector3(side*.39,.71,-.10)
		f._rod(b,Vector3(side*.26,.14,.02),riser,.018,m.carbon)
		for row in 3:
			for branch in 4:
				var t:float=side*(.12+branch*.225)
				var fork:=riser.lerp(_canopy_point(t,.13+row*.31,false),.51)
				f._rod(b,riser,fork,.0045,m.ivory)
				for delta in [-.070,.0,.070]:
					f._rod(b,fork,_canopy_point(clampf(t+delta,-.97,.97),.13+row*.31,false),.003,m.ivory)
		f._rod(b,Vector3(side*.43,.72,-.09),_canopy_point(side*.72,.95,false),.004,m.red)
	f._ellipsoid(b,Vector3(.30,.24,.30),Vector3(0,-.05,.10),m.carbon)
	f._ellipsoid(b,Vector3(.29,.38,.15),Vector3(0,.20,.30),m.fabric)
	f._box(b,Vector3(.40,.035,.32),Vector3(0,-.18,.04),m.dark)
	f._rod(b,Vector3(-.27,.15,-.04),Vector3(.27,.15,-.04),.023,m.dark)
	f._sphere_collision(b,.63,Vector3.ZERO)

static func _fenestron(b:Node3D,m:Dictionary,v:Dictionary,f:Script):
	var center:=Vector3(0,1.65,7.48)
	var p=Detail.Panels.new(b,m);p.smooth_keys=["white","carbon"]
	for i in 64:
		var a:=TAU*i/64.;var c:=TAU*(i+1)/64.
		for side:int in [-1,1]:
			var x:=side*.17
			p.quad("white",center+Vector3(x,sin(a)*1.26,cos(a)*1.26),center+Vector3(x,sin(c)*1.26,cos(c)*1.26),center+Vector3(x,sin(c)*.92,cos(c)*.92),center+Vector3(x,sin(a)*.92,cos(a)*.92),Vector3(side,0,0))
		p.quad("carbon",center+Vector3(-.17,sin(a)*.92,cos(a)*.92),center+Vector3(.17,sin(a)*.92,cos(a)*.92),center+Vector3(.17,sin(c)*.92,cos(c)*.92),center+Vector3(-.17,sin(c)*.92,cos(c)*.92),Vector3(0,-sin(a),-cos(a)))
		p.quad("white",center+Vector3(-.17,sin(a)*1.26,cos(a)*1.26),center+Vector3(.17,sin(a)*1.26,cos(a)*1.26),center+Vector3(.17,sin(c)*1.26,cos(c)*1.26),center+Vector3(-.17,sin(c)*1.26,cos(c)*1.26),Vector3(0,sin(a),cos(a)))
	p.finish()
	var fan:=Node3D.new();fan.name="Fenestron_ten_blade_rotor";fan.position=center;b.add_child(fan)
	for i in 10:
		var a:=TAU*i/10+.012*sin(i*1.7)
		f._box(fan,Vector3(.045,.77,.12),Vector3(0,sin(a)*.48,cos(a)*.48),m.dark,Vector3(PI/2-a,0,0))
	f._cylinder(fan,.18,.34,Vector3.ZERO,m.metal,Vector3(0,0,PI/2))
	v.propellers.append(fan)
	# Real ring aperture stays open; four small perimeter convex sections collide.
	for i in 8:
		var vertices:=[]
		for offset in range(5):
			var a:=TAU*(i+offset/4.)/8.
			for x in [-.17,.17]:
				for radius in [.92,1.26]:vertices.append(center+Vector3(x,sin(a)*radius,cos(a)*radius))
		Detail._convex(b,vertices)

static func _helicopter(b:Node3D,m:Dictionary,v:Dictionary,f:Script):
	b.set_meta("vehicle_model",{"reference":"Airbus H160","ground":-1.425,"rotor_diameter":13.4,"overall_length":15.67,"features":["five swept Blue Edge inspired blades","enclosed ten-blade Fenestron","compound glazed cockpit","cabin sliding door seams","twin engine fairings","biplane stabilizer","wheeled tricycle gear","visible rotor head and pitch links"]})
	_loft(b,m,[[-4.5,.025,.035,-.10],[-4.30,.39,.38,-.05],[-3.85,.79,.74,.13],[-3.15,1.10,1.04,.31],[-2.35,1.17,1.16,.32],[-1.6,1.22,1.17,.32],[-.95,1.24,1.17,.32],[.18,1.25,1.16,.32],[1.50,1.12,1.08,.35],[2.23,.87,.84,.43],[2.95,.46,.47,.53],[3.35,.28,.29,.57]],"helicopter")
	_loft(b,m,[[2.7,.46,.41,.68],[3.5,.32,.34,.85],[5.2,.20,.22,1.16],[6.4,.12,.15,1.37],[7.4,.055,.075,1.46]],"")
	for side:int in [-1,1]:
		# Curved engine shoulders and actual open-looking exhaust throats.
		f._ellipsoid(b,Vector3(.48,.44,1.45),Vector3(side*.58,1.58,.65),m.white)
		f._cylinder(b,.33,.57,Vector3(side*.60,1.76,1.94),m.metal,Vector3(PI/2,0,0))
		f._cylinder(b,.264,.02,Vector3(side*.60,1.76,2.235),m.dark,Vector3(PI/2,0,0))
		for frame in [[-2.35,1.17,1.16,.32],[-.95,1.24,1.17,.32],[.18,1.25,1.16,.32],[1.50,1.12,1.08,.35]]:
			for i in 9:
				var a:=.025+1.12*i/9.;var c:=.025+1.12*(i+1)/9.
				var point_a:=_point(frame,a);var point_c:=_point(frame,c)
				point_a.x*=side;point_c.x*=side
				point_a+=Vector3(side*cos(a),sin(a),0)*.014;point_c+=Vector3(side*cos(c),sin(c),0)*.014
				f._rod(b,point_a,point_c,.028,m.white)
		# Passenger door sill, handle and recessed running board.
		f._rod(b,Vector3(side*1.22,.11,-1.05),Vector3(side*1.22,.11,1.44),.025,m.white)
		f._rod(b,Vector3(side*1.12,-.37,-1.05),Vector3(side*1.12,-.37,1.44),.017,m.dark)
		f._box(b,Vector3(.035,.055,.24),Vector3(side*1.24,.13,.81),m.metal)
		f._box(b,Vector3(.27,.06,1.6),Vector3(side*1.22,-.76,.18),m.carbon)
		# Main wheel outriggers meet the retained original contact plane.
		f._rod(b,Vector3(side*.83,-.42,1.64),Vector3(side*1.54,-1.095,1.64),.10,m.metal)
		Detail._wheel(b,Vector3(side*1.54,-1.095,1.64),.33,.18,m,v,f,8)
		Detail._wheel(b,Vector3(side*.14,-1.165,-3.10),.26,.13,m,v,f,8)
		_wing(b,m,[[.14,1.06,4.39,1.1,.10],[1.32,1.03,4.48,.93,.08],[1.66,1.0,4.65,.67,.06]],side,"white")
		_wing(b,m,[[.14,1.52,4.70,.83,.08],[1.14,1.49,4.77,.65,.06],[1.45,1.47,4.88,.48,.04]],side,"teal")
	f._rod(b,Vector3(0,-.39,-3.1),Vector3(0,-1.165,-3.1),.075,m.metal)
	# Windshield center frame follows curved nose rather than a rectangular slab.
	f._rod(b,Vector3(0,.50,-4.03),Vector3(0,1.31,-2.98),.031,m.white)
	f._ellipsoid(b,Vector3(.64,.47,.93),Vector3(0,2.10,-.23),m.white)
	f._cylinder(b,.24,.42,Vector3(0,2.62,-.23),m.dark)
	f._cylinder(b,.095,.80,Vector3(0,2.73,-.23),m.metal)
	var rotor:=Node3D.new();rotor.name="Five_swept_rotor_blades";rotor.position=Vector3(0,3.22,-.23);b.add_child(rotor)
	var p=Detail.Panels.new(rotor,m);p.smooth_keys=["carbon"]
	for i in 5:
		var basis:=Basis(Vector3.UP,PI/2+TAU*i/5.)
		var stations:=[[.42,0,0,.23],[1.10,.005,0,.48],[4.9,.04,-.08,.38],[5.70,.045,-.03,.32],[6.15,.05,.20,.28],[6.7,.04,.11,.15]]
		for j in stations.size()-1:
			var a:Array=stations[j];var c:Array=stations[j+1]
			for top in [true,false]:
				var y:=.024 if top else -.024
				p.quad("carbon",basis*Vector3(a[0],a[1]+y,a[2]-a[3]*.5),basis*Vector3(c[0],c[1]+y,c[2]-c[3]*.5),basis*Vector3(c[0],c[1]+y,c[2]+c[3]*.5),basis*Vector3(a[0],a[1]+y,a[2]+a[3]*.5),Vector3.UP if top else Vector3.DOWN)
		f._rod(rotor,Vector3.ZERO,basis*Vector3(.95,.04,0),.053,m.metal)
		f._rod(b,Vector3(0,2.74,-.23),Vector3(0,3.22,-.23)+basis*Vector3(.42,0,0),.017,m.metal)
	p.finish();v.rotors.append(rotor)
	var disk:=CollisionShape3D.new();disk.name="Swept_rotor_collision"
	var disk_shape:=CylinderShape3D.new();disk_shape.radius=6.7;disk_shape.height=.10
	disk.shape=disk_shape;disk.position=rotor.position+Vector3.UP*.04;b.add_child(disk)
	f._ellipsoid(rotor,Vector3(.28,.11,.28),Vector3.ZERO,m.metal)
	_vertical(b,m,[Vector2(2.58,6.93),Vector2(3.26,7.77),Vector2(3.485,8.40),Vector2(3.43,8.71),Vector2(2.58,8.50)],.11,"teal")
	_fenestron(b,m,v,f)
	f._ellipsoid(b,Vector3(.115,.075,.12),Vector3(0,3.48,8.46),m.red)
	f._ellipsoid(b,Vector3(.13,.13,.12),Vector3(0,-.28,-4.31),m.light)
