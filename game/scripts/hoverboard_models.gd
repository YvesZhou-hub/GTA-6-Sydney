extends RefCounted
## Original fictional Aether X1, with standing operator and four induction pods.
static func build(body: Node3D, m: Dictionary, moving: Dictionary, f: Script) -> void:
	var alloy: StandardMaterial3D = f.material(Color("c2ced3"),0.78,0.23)
	var carbon: StandardMaterial3D = f.material(Color("12222e"),0.55,0.32)
	var grip: StandardMaterial3D = f.material(Color("252d34"),0.0,0.9)
	var glow: StandardMaterial3D = f.material(Color("6bfff0"),0.25,0.2)
	glow.emission_enabled=true
	glow.emission=Color("1cd5d2")
	glow.emission_energy_multiplier=2.3
	var shell: Array[Vector3] = [Vector3(-0.35,0,-0.79),Vector3(0.35,0,-0.79),Vector3(0.56,0,-0.48),Vector3(0.56,0,0.53),Vector3(0.30,0,0.77),Vector3(-0.30,0,0.77),Vector3(-0.56,0,0.53),Vector3(-0.56,0,-0.48)]
	f._prism(body,shell,0.17,alloy)
	var inner: Array[Vector3]=[]
	for p in shell: inner.append(p*Vector3(0.9,1.0,0.9)+Vector3.UP*.10)
	f._prism(body,inner,0.06,carbon)
	for side in [-1.0,1.0]:
		f._box(body,Vector3(.30,.032,.86),Vector3(side*.27,.16,.04),grip)
		for z in 12:
			f._box(body,Vector3(.25,.012,.014),Vector3(side*.27,.185,-.34+z*.067),alloy)
		f._box(body,Vector3(.025,.028,.84),Vector3(side*.47,.12,.01),glow)
		for z in [-.49,.47]:
			var pod:=Vector3(side*.43,-.105,z)
			f._cylinder(body,.20,.18,pod,carbon)
			f._cylinder(body,.158,.018,pod-Vector3.UP*.097,glow)
			f._cylinder(body,.096,.022,pod-Vector3.UP*.11,alloy)
			for spoke in 6:
				var a:=spoke*TAU/6
				f._rod(body,pod+Vector3(sin(a)*.10,-.11,cos(a)*.10),pod+Vector3(sin(a)*.18,-.11,cos(a)*.18),.011,carbon)
	f._box(body,Vector3(.47,.045,.024),Vector3(0,.1,-.795),glow)
	f._box(body,Vector3(.33,.035,.018),Vector3(0,.07,.778),m.red)
	# A tiny status display on the central spine is visible from the follow camera.
	f._box(body,Vector3(.12,.033,.24),Vector3(0,.17,-.48),m.glass)
	for i in 4: f._box(body,Vector3(.07,.01,.012),Vector3(0,.19,-.56+i*.044),glow)
	f._box_collision(body,Vector3(1.09,.32,1.55),Vector3(0,-.015,0))
	# One standing capsule keeps low beams and doorways physically meaningful.
	var col:=CollisionShape3D.new()
	var shape:=CapsuleShape3D.new()
	shape.radius=.26;shape.height=1.62
	col.shape=shape;col.position=Vector3(0,1.02,.08);body.add_child(col)
	var rider:=Node3D.new()
	rider.name="Standing_operator"
	rider.visible=false
	body.add_child(rider)
	for side in [-1.0,1.0]:
		var ankle:=Vector3(side*.27,.28,.12)
		var knee:=Vector3(side*.23,.64,-.02)
		var hip:=Vector3(side*.15,.99,.1)
		f._ellipsoid(rider,Vector3(.12,.08,.21),Vector3(side*.27,.24,.045),m.rubber)
		f._rod(rider,ankle,knee,.088,carbon)
		f._rod(rider,knee,hip,.10,carbon)
		var shoulder:=Vector3(side*.22,1.43,.08)
		var elbow:=Vector3(side*.34,1.20,-.02)
		var hand:=Vector3(side*.34,1.02,-.15)
		f._rod(rider,shoulder,elbow,.074,m.teal)
		f._rod(rider,elbow,hand,.064,m.teal)
		f._ellipsoid(rider,Vector3(.065,.08,.07),hand,carbon)
	f._ellipsoid(rider,Vector3(.25,.30,.16),Vector3(0,1.23,.08),m.teal)
	f._ellipsoid(rider,Vector3(.21,.16,.16),Vector3(0,.99,.10),carbon)
	f._ellipsoid(rider,Vector3(.185,.215,.195),Vector3(0,1.76,.06),alloy)
	f._ellipsoid(rider,Vector3(.17,.092,.058),Vector3(0,1.78,-.113),m.glass)
	f._box(rider,Vector3(.13,.018,.025),Vector3(0,1.69,-.137),glow)
	moving.rider=rider
	moving.material=m.teal
	body.set_meta("model_reference","Original fictional antigravity design; no real vehicle counterpart")
