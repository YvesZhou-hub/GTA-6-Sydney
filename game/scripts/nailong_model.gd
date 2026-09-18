extends RefCounted
## Shared, rounded yellow creature geometry, including two articulated air forms.
static var _recipes: Dictionary = {}
static var _materials: Dictionary = {}
static var _sphere: SphereMesh
static var _ring: TorusMesh

static func _material(key: String) -> StandardMaterial3D:
	if _materials.has(key): return _materials[key]
	var colors := {"yellow":Color("ffcf35"),"belly":Color("ffeaa1"),"white":Color("fffdf1"),"black":Color("202a2a"),"orange":Color("e99a25"),"strap":Color("5c4632"),"warning":Color(1.0,.19,.06,.82),"health":Color("72ebae"),"bar":Color("253932"),"hurt":Color("fff9dc"),"membrane":Color("ffdc84"),"storm":Color("789cca"),"electric":Color("b6edff")}
	var result := StandardMaterial3D.new()
	result.albedo_color = colors[key]
	result.roughness = .57 if key in ["yellow","belly"] else .72
	if key in ["warning","health","bar"]:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		result.no_depth_test = false
	if key == "warning":
		result.emission_enabled = true
		result.emission = Color(1,.2,.04)
		result.emission_energy_multiplier = 1.5
	if key in ["membrane","storm"]:result.cull_mode=BaseMaterial3D.CULL_DISABLED
	if key=="electric":
		result.emission_enabled=true
		result.emission=Color("78cdf5")
		result.emission_energy_multiplier=.85
	_materials[key] = result
	return result

static func _ball() -> SphereMesh:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 1.0
		_sphere.height = 2.0
		_sphere.radial_segments = 20
		_sphere.rings = 10
	return _sphere

static func _part(parts: Array, at: Vector3, size: Vector3, material: String, tilt: float = 0.0) -> void:
	parts.append({"at":at,"size":size,"material":material,"tilt":tilt})

static func _merge(parts: Array) -> Array:
	var builders: Dictionary = {}
	for part: Dictionary in parts:
		var key: String = part.material
		if not builders.has(key):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			builders[key] = surface
		var pose := Transform3D(Basis(Vector3.FORWARD,float(part.tilt)).scaled(part.size),part.at)
		builders[key].append_from(_ball(),0,pose)
	var result: Array = []
	for key: String in builders:
		builders[key].index()
		result.append({"mesh":builders[key].commit(),"material":_material(key)})
	return result

static func _recipe(kind: String) -> Dictionary:
	if _recipes.has(kind): return _recipes[kind]
	var torso: Array = []
	_part(torso,Vector3(0,1.03,.05),Vector3(.70,.87,.53),"yellow")
	_part(torso,Vector3(0,.99,-.43),Vector3(.49,.59,.11),"belly")
	var head: Array = []
	_part(head,Vector3.ZERO,Vector3(.69,.60,.57),"yellow")
	_part(head,Vector3(0,-.24,-.45),Vector3(.47,.24,.25),"yellow")
	for side in [-1.0,1.0]:
		_part(head,Vector3(side*.225,.05,-.52),Vector3(.20,.23,.10),"white")
		_part(head,Vector3(side*.195,.025,-.608),Vector3(.082,.107,.028),"black")
		_part(head,Vector3(side*.174,.062,-.632),Vector3(.024,.029,.013),"white")
		_part(head,Vector3(side*.16,-.20,-.673),Vector3(.027,.017,.012),"orange")
	_part(head,Vector3(0,-.34,-.647),Vector3(.155,.025,.012),"black")
	var tail: Array = []
	for i in 4:
		var t := float(i)/3.0
		_part(tail,Vector3(0,-t*.20,t*.85),Vector3(.25-t*.055,.27-t*.061,.36-t*.045),"yellow")
	var arm: Array = []
	_part(arm,Vector3(0,-.18,-.08),Vector3(.17,.30,.19),"yellow")
	_part(arm,Vector3(0,-.39,-.12),Vector3(.18,.14,.20),"yellow")
	var foot: Array = []
	_part(foot,Vector3(0,.15,-.12),Vector3(.27,.22,.36),"yellow")
	for toe in [-1,0,1]: _part(foot,Vector3(toe*.10,.12,-.39),Vector3(.06,.065,.09),"belly")
	match kind:
		"runner":
			# Slim red-orange scarf and backwards ribbons retain the yellow body.
			_part(torso,Vector3(0,1.58,0),Vector3(.51,.105,.43),"orange")
			_part(torso,Vector3(.36,1.45,.45),Vector3(.11,.33,.09),"orange",-.5)
			_part(torso,Vector3(.52,1.38,.51),Vector3(.09,.28,.08),"orange",-.7)
		"brute":
			for side in [-1.0,1.0]:
				_part(torso,Vector3(side*.66,1.31,.03),Vector3(.30,.27,.31),"strap")
				_part(torso,Vector3(side*.67,1.46,.02),Vector3(.20,.10,.22),"orange")
				_part(head,Vector3(side*.23,.285,-.53),Vector3(.24,.072,.08),"orange",side*.18)
		"spitter":
			for side in [-1.0,1.0]: _part(head,Vector3(side*.47,-.20,-.40),Vector3(.25,.23,.22),"yellow")
			_part(head,Vector3(0,-.32,-.668),Vector3(.115,.095,.053),"orange")
			_part(head,Vector3(0,-.32,-.716),Vector3(.061,.052,.011),"black")
			_part(torso,Vector3(0,1.40,-.37),Vector3(.25,.18,.18),"orange")
		"leaper":
			# Spring pads on the knees and a crouched headband mark the jumper.
			_part(head,Vector3(0,.30,.0),Vector3(.72,.085,.6),"strap")
			for side in [-1.0,1.0]:
				_part(torso,Vector3(side*.28,.42,-.18),Vector3(.2,.16,.2),"orange")
				_part(head,Vector3(side*.36,.34,-.12),Vector3(.12,.2,.1),"orange",side*.35)
		"alpha":
			_part(head,Vector3(0,.51,.02),Vector3(.49,.115,.36),"orange")
			for i in [-1,0,1]: _part(head,Vector3(i*.32,.66,.02),Vector3(.09,.23 if i==0 else .17,.10),"orange")
			for i in 4: _part(torso,Vector3(0,.65+i*.28,.49),Vector3(.12,.18,.15),"orange")
			for side in [-1.0,1.0]: _part(head,Vector3(side*.24,.295,-.53),Vector3(.24,.065,.08),"orange",side*.18)
		"winglet":
			_part(torso,Vector3(0,1.55,.02),Vector3(.5,.08,.43),"orange")
			for side in [-1.0,1.0]:_part(head,Vector3(side*.41,.48,.1),Vector3(.1,.26,.11),"orange",side*-.4)
		"stormwing":
			for side in [-1.0,1.0]:
				_part(torso,Vector3(side*.62,1.37,.08),Vector3(.28,.23,.3),"storm")
				_part(head,Vector3(side*.4,.45,.05),Vector3(.13,.33,.14),"storm",side*-.4)
				_part(head,Vector3(side*.4,.66,.05),Vector3(.07,.12,.08),"electric",side*-.4)
			_part(torso,Vector3(0,1.38,-.43),Vector3(.22,.24,.12),"electric")
	var recipe := {"torso":_merge(torso),"head":_merge(head),"tail":_merge(tail),"arm":_merge(arm),"foot":_merge(foot)}
	if kind in ["winglet","stormwing"]:recipe["wing"]=_wing(kind)
	_recipes[kind] = recipe
	return recipe

static func _wing(kind: String) -> Array:
	var rim: Array=[]
	_part(rim,Vector3(1.1,.1,.06),Vector3(1.24,.065,.075),"yellow")
	_part(rim,Vector3(1.7,.12,.38),Vector3(.78,.05,.06),"orange")
	_part(rim,Vector3(.82,-.02,.5),Vector3(.72,.045,.07),"orange")
	_part(rim,Vector3(2.38,.12,.16),Vector3(.22,.07,.12),"electric" if kind=="stormwing" else "belly")
	var result:=_merge(rim)
	var outline:=PackedVector2Array([Vector2(0,0),Vector2(1.05,-.14),Vector2(2.15,-.03),Vector2(2.65,.2),Vector2(2.15,.7),Vector2(1.48,.45),Vector2(1.02,.88),Vector2(.54,.52),Vector2(0,.5)])
	var indices:=Geometry2D.triangulate_polygon(outline)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		var point:Vector2=outline[index]
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(point.x,.07-point.y*.13,point.y))
	surface.index()
	result.append({"mesh":surface.commit(),"material":_material("storm" if kind=="stormwing" else "membrane")})
	return result

static func _node(parent: Node3D, label: String, at: Vector3, recipe: Array) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = at
	parent.add_child(pivot)
	for entry: Dictionary in recipe:
		var mesh := MeshInstance3D.new()
		mesh.mesh = entry.mesh
		mesh.material_override = entry.material
		mesh.set_meta("rest_material",entry.material)
		pivot.add_child(mesh)
	return pivot

static func build(parent: Node3D, kind: String) -> Dictionary:
	var recipe := _recipe(kind)
	var visual := Node3D.new()
	visual.name = "NailongVisual"
	parent.add_child(visual)
	var body := _node(visual,"Belly",Vector3.ZERO,recipe.torso)
	var head := _node(visual,"Head",Vector3(0,1.91,-.025),recipe.head)
	var tail := _node(visual,"Tail",Vector3(0,.48,.43),recipe.tail)
	var arms: Array[Node3D] = []
	var feet: Array[Node3D] = []
	var wings: Array[Node3D] = []
	for side in [-1.0,1.0]:
		arms.append(_node(visual,"Arm",Vector3(side*.65,1.35,-.05),recipe.arm))
		feet.append(_node(visual,"Foot",Vector3(side*.34,.02,-.005),recipe.foot))
		if recipe.has("wing"):
			var wing:=_node(visual,"Wing",Vector3(side*.5,1.55,.2),recipe.wing)
			wing.scale.x=side
			wings.append(wing)
	return {"root":visual,"body":body,"head":head,"tail":tail,"arms":arms,"feet":feet,"wings":wings,"kind":kind}

static func animate(parts: Dictionary, stride: float, movement: float, windup: float, hurt: float, death: float) -> void:
	if parts.is_empty(): return
	var visual: Node3D = parts.root
	var gait := sin(stride)*minf(movement/3.0,1.0)
	var heavy: bool = str(parts.get("kind",""))=="alpha"
	var airborne: bool = not parts.get("wings",[]).is_empty()
	visual.position.y = absf(gait)*.065-death*.65-(.22*windup if heavy else 0.0)
	visual.rotation.x = (-.28 if heavy else -.16)*windup+.10*hurt
	parts.head.rotation.x = -.28*windup
	parts.head.rotation.z = sin(stride*.38)*.045*(1.0-windup)
	parts.tail.rotation.y = sin(stride*.55)*.22
	# Overrides belong to instances; never tint a shared yellow material globally.
	for mesh: MeshInstance3D in parts.body.get_children():
		mesh.material_override = _material("hurt") if hurt>.35 else mesh.get_meta("rest_material")
	for index in 2:
		var side := -1.0 if index==0 else 1.0
		parts.feet[index].rotation.x = gait*side*.40
		parts.arms[index].rotation.x = -gait*side*.24-windup*(2.5 if heavy else 1.3)
		parts.arms[index].rotation.z = side*windup*.28
		if airborne:
			parts.wings[index].rotation.z=side*(sin(stride)*.52*(1.0-windup)+.24*windup)
			parts.feet[index].rotation.x=.4
			parts.arms[index].rotation.x=-.45-windup*.5
	if airborne:
		visual.position.y+=sin(stride)*.055
		visual.rotation.x=-minf(movement/12.0,1.0)*.22-windup*.12
	visual.scale = Vector3.ONE*(1.0-death*.85)

static func warning_ring(parent: Node3D) -> MeshInstance3D:
	if _ring == null:
		_ring = TorusMesh.new()
		_ring.inner_radius = .94
		_ring.outer_radius = 1.0
		_ring.rings = 32
		_ring.ring_segments = 5
	var result := MeshInstance3D.new()
	result.name = "AttackWarning"
	result.mesh = _ring
	result.material_override = _material("warning")
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	result.position.y = .085
	result.visible = false
	parent.add_child(result)
	return result

static func bar_material(health: bool) -> Material:
	return _material("health" if health else "bar")

static func cache_snapshot() -> Dictionary:
	return {"types":_recipes.keys(),"materials":_materials.size(),"shared":true}
