extends RefCounted
## ASTER F-27: original fictional twin-engine aircraft, metres, +Y up/-Z forward.
## Public manufacturer photographs inform broad aircraft forms, not a CAD replica.
const Detail = preload("res://scripts/vehicle_refinement.gd")
const Air = preload("res://scripts/air_vehicle_models.gd")
const GROUND_CONTACT_Y := -2.05
const MUZZLE_POSITION := Vector3(0,-0.08,-9.8)

static func build(body: Node3D, mats: Dictionary, moving: Dictionary, factory: Script) -> void:
	var m := mats.duplicate()
	m["skin"] = factory.material(Color("778993"),0.42,0.43)
	m["edge"] = factory.material(Color("a9b9bd"),0.50,0.34)
	m["belly"] = factory.material(Color("455a68"),0.35,0.46)
	m["carbon"] = factory.material(Color("121b24"),0.3,0.45)
	m["brake"] = factory.material(Color("7c8a91"),0.8,0.4)
	m["gold"] = factory.material(Color("adbfca"),0.8,0.27)
	m["canopy"] = factory.material(Color(0.36,0.59,0.65,0.43),0.45,0.16)
	m.canopy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m["heat"] = factory.material(Color("665344"),0.80,0.38)
	m["glow"] = factory.material(Color("70b8ff"),0.25,0.2)
	m.glow.emission_enabled = true
	m.glow.emission = Color("319ee0")
	m.glow.emission_energy_multiplier = 2.0
	moving.material = m.skin
	# The pointed, blended body is an original asymmetric section loft.
	_loft(body,m,[[-9.4,.025,.035,-.08],[-8.5,.32,.30,-.04],[-7.3,.60,.47,0],[-5.5,.76,.57,.10],[-3.8,.95,.67,.16],[-1.5,1.45,.67,.10],[1.8,1.68,.61,.02],[4.6,1.62,.50,-.05],[7.0,1.28,.39,-.10],[8.4,.48,.24,-.10],[9.1,.06,.10,-.10]],Vector3.ZERO,"skin",true)
	# Cockpit blister, dark coaming, visible seat/pilot and canopy frames.
	factory._box(body,Vector3(.76,.50,.85),Vector3(0,.72,-4.2),m.carbon)
	factory._ellipsoid(body,Vector3(.26,.30,.20),Vector3(0,1.03,-4.25),m.dark)
	factory._ellipsoid(body,Vector3(.22,.21,.24),Vector3(0,1.38,-4.35),m.white)
	factory._ellipsoid(body,Vector3(.21,.10,.12),Vector3(0,1.40,-4.52),m.glass)
	_loft(body,m,[[-6.5,.03,.04,.59],[-6.0,.44,.38,.66],[-5.15,.62,.84,.72],[-4.15,.61,.94,.74],[-3.25,.48,.65,.73],[-2.65,.02,.05,.70]],Vector3.ZERO,"canopy",false)
	for z: float in [-6.0,-3.25]:
		var width: float = .44 if z < -5 else .48
		var height: float = .38 if z < -5 else .65
		var bottom: float = .66 if z < -5 else .73
		var last := Vector3(-width,bottom,z)
		for i in range(1,17):
			var angle: float = PI-i*PI/16.
			var next := Vector3(cos(angle)*width,bottom+sin(angle)*height,z)
			factory._rod(body,last,next,.025,m.edge)
			last = next
	for side: int in [-1,1]:
		factory._rod(body,Vector3(side*.44,.66,-6.0),Vector3(side*.48,.73,-3.25),.035,m.edge)
		# Broad swept lifting wing and separate horizontal stabiliser; each foil
		# has a rounded leading edge, closed top/bottom and matching convex shape.
		Air._wing(body,m,[[.80,.05,-3.15,7.65,.23],[2.5,.07,-2.1,6.35,.18],[5.55,.17,1.45,2.28,.10],[6.8,.24,3.02,.70,.045]],side,"skin",true)
		Air._wing(body,m,[[1.1,.17,5.5,3.4,.12],[2.55,.15,6.0,3.06,.095],[4.25,.08,7.75,1.15,.04]],side,"belly",true)
		# Distinct leading root strake with a pale edge strip.
		Air._wing(body,m,[[.58,.30,-6.0,3.35,.075],[1.55,.20,-3.95,2.65,.06],[2.30,.13,-2.34,.60,.025]],side,"edge",false)
		_intake(body,m,factory,side)
		_loft(body,m,[[-.5,.71,.66,-.16],[2.5,.76,.71,-.17],[5.4,.74,.67,-.16],[7.55,.60,.57,-.13]],Vector3(side*1.05,0,0),"belly",true)
		_nozzle(body,m,factory,side)
		_tail(body,m,side)
		# Clearly modelled control-surface boundaries, navigation lamps, gear
		# doors and struts; their positions are original, not surveyed hardware.
		factory._rod(body,Vector3(side*2.6,.23,3.82),Vector3(side*5.60,.28,3.59),.018,m.carbon)
		factory._rod(body,Vector3(side*1.65,.20,7.76),Vector3(side*3.8,.14,8.77),.018,m.carbon)
		factory._ellipsoid(body,Vector3(.09,.07,.13),Vector3(side*6.70,.28,3.29),m.red if side<0 else m.light)
		factory._box(body,Vector3(.34,.04,1.28),Vector3(side*1.48,-.91,1.30),m.edge)
		factory._rod(body,Vector3(side*1.48,-.49,1.18),Vector3(side*1.92,-1.60,1.65),.10,m.metal)
		factory._rod(body,Vector3(side*1.22,-.61,.75),Vector3(side*1.92,-1.51,1.65),.057,m.metal)
		Detail._wheel(body,Vector3(side*1.92,-1.60,1.65),.45,.24,m,moving,factory,9)
		# Flush upper access hatches / original orange recognition markings.
		factory._box(body,Vector3(.46,.018,.78),Vector3(side*1.02,.69,.1),m.belly)
		Air._wing(body,m,[[4.85,.245,1.78,.22,.009],[5.9,.29,2.49,.19,.008]],side,"orange",false)
	factory._rod(body,Vector3(0,-.35,-5.7),Vector3(0,-1.72,-5.62),.075,m.metal)
	factory._rod(body,Vector3(0,-.54,-4.90),Vector3(0,-1.45,-5.60),.046,m.metal)
	Detail._wheel(body,Vector3(0,-1.72,-5.62),.33,.18,m,moving,factory,8)
	factory._box(body,Vector3(.34,.03,1.22),Vector3(0,-.59,-5.19),m.edge)
	var muzzle := Marker3D.new()
	muzzle.name = "Fighter_weapon_muzzle"
	muzzle.position = MUZZLE_POSITION
	body.add_child(muzzle)
	moving["weapon_muzzle"] = muzzle
	moving["exhaust"] = []
	for side: int in [-1,1]:
		var marker := Marker3D.new()
		marker.position = Vector3(side*1.05,-.13,8.44)
		body.add_child(marker)
		moving.exhaust.append(marker)
	body.set_meta("fighter_design","ASTER F-27 • original fictional twin-engine aircraft")

static func _loft(body: Node3D, m: Dictionary, sections: Array, offset: Vector3, key: String, collision: bool) -> void:
	var p = Detail.Panels.new(body,m)
	p.smooth_keys = [key]
	for j in sections.size()-1:
		var hull := []
		for i in 40:
			var a: float = TAU*i/40.
			var c: float = TAU*(i+1)/40.
			var one: Vector3 = Air._point(sections[j],a)+offset
			var two: Vector3 = Air._point(sections[j+1],a)+offset
			var three: Vector3 = Air._point(sections[j+1],c)+offset
			var four: Vector3 = Air._point(sections[j],c)+offset
			p.quad(key,one,two,three,four,Vector3(cos((a+c)/2),sin((a+c)/2),0))
			hull.append_array([one,two,three,four])
		if collision: Detail._convex(body,hull)
	for index: int in [0,sections.size()-1]:
		var section: Array = sections[index]
		var center := Vector3(0,float(section[3]),float(section[0]))+offset
		for i in 40:
			p.triangle(key,center,Air._point(section,TAU*i/40.)+offset,Air._point(section,TAU*(i+1)/40.)+offset,Vector3.FORWARD if index==0 else Vector3.BACK)
	p.finish()

static func _intake(body: Node3D, m: Dictionary, f: Script, side: int) -> void:
	var p = Detail.Panels.new(body,m)
	var outer := [Vector2(-.58,.42),Vector2(.45,.43),Vector2(.68,.13),Vector2(.58,-.65),Vector2(-.44,-.76),Vector2(-.59,-.50)]
	var center := Vector3(side*1.08,-.06,-2.82)
	for i in outer.size():
		var a: Vector2 = outer[i]
		var c: Vector2 = outer[(i+1)%outer.size()]
		var one := center+Vector3(side*a.x,a.y,0)
		var two := center+Vector3(side*c.x,c.y,0)
		var inner_one := center+Vector3(side*a.x*.86,a.y*.85,.08)
		var inner_two := center+Vector3(side*c.x*.86,c.y*.85,.08)
		p.quad("edge",one,two,inner_two,inner_one,Vector3.FORWARD)
		p.quad("belly",inner_one,inner_two,inner_two+Vector3(0,0,.75),inner_one+Vector3(0,0,.75),-Vector3(side*(a.x+c.x)/2,(a.y+c.y)/2,0))
		p.quad("skin",one,two,two+Vector3(0,0,2.1),one+Vector3(0,0,2.1),Vector3(side*(a.x+c.x)/2,(a.y+c.y)/2,0))
	var face := []
	for point: Vector2 in outer: face.append(center+Vector3(side*point.x*.86,point.y*.85,.83))
	p.polygon("carbon",face,Vector3.FORWARD)
	p.finish()
	f._rod(body,center+Vector3(-side*.16,.35,.12),center+Vector3(-side*.16,-.61,.12),.025,m.metal)

static func _nozzle(body: Node3D, m: Dictionary, f: Script, side: int) -> void:
	var p = Detail.Panels.new(body,m)
	var center := Vector3(side*1.05,-.13,7.53)
	for i in 24:
		var a: float = TAU*i/24.
		var c: float = TAU*(i+1)/24.
		var one := Vector3(cos(a)*.60,sin(a)*.57,0)+center
		var two := Vector3(cos(c)*.60,sin(c)*.57,0)+center
		var three := Vector3(cos(c)*.48,sin(c)*.47,.87)+center
		var four := Vector3(cos(a)*.48,sin(a)*.47,.87)+center
		p.quad("heat" if i%2==0 else "metal",one,two,three,four,Vector3(cos(a),sin(a),0))
		p.quad("carbon",four,three,three+Vector3(-cos(c)*.07,-sin(c)*.07,-.45),four+Vector3(-cos(a)*.07,-sin(a)*.07,-.45),-Vector3(cos(a),sin(a),0))
		f._rod(body,one,four,.013,m.carbon)
	p.finish()
	f._cylinder(body,.38,.04,center+Vector3(0,0,.34),m.glow,Vector3(PI/2,0,0))

static func _tail(body: Node3D, m: Dictionary, side: int) -> void:
	var p = Detail.Panels.new(body,m)
	var outline := [Vector3(side*1.27,.32,4.4),Vector3(side*2.56,4.23,6.54),Vector3(side*2.63,4.28,7.61),Vector3(side*1.38,.39,8.22)]
	var vertices := []
	for face_side: int in [-1,1]:
		var points := []
		for point: Vector3 in outline:
			var v := point+Vector3(face_side*.055,0,0)
			points.append(v);vertices.append(v)
		p.polygon("skin" if face_side==side else "belly",points,Vector3(face_side,0,0))
	for i in outline.size():
		var a: Vector3 = outline[i]
		var c: Vector3 = outline[(i+1)%outline.size()]
		p.quad("edge",a+Vector3(.055,0,0),c+Vector3(.055,0,0),c-Vector3(.055,0,0),a-Vector3(.055,0,0))
	# Original rectangular identification panel; no copied insignia or texture.
	var stripe := [Vector3(side*2.15,3.0,6.18),Vector3(side*2.26,3.34,6.45),Vector3(side*2.27,3.34,7.5),Vector3(side*2.17,3.0,7.54)]
	for i in stripe.size(): stripe[i] += Vector3(side*.058,0,0)
	p.polygon("orange",stripe,Vector3(side,0,0))
	p.finish()
	Detail._convex(body,vertices)
