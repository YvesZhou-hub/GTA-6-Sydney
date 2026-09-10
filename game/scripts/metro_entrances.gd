extends RefCounted
## Mapped surface entrances with actual walkable underground landing halls.
## Exterior and height estimates are documented in docs/METRO_REFERENCE.md.

const BAR_TOP := Vector3(-751.1658,4.5,-91.738812)
const BAR_BOTTOM := Vector3(-750.4266,-4.5,-74.272704)
const ROUTES := {"barangaroo":[{"osm_way":1246220574,"top":[-752.72736,4.5,-91.638624],"bottom":[-751.86804,-4.5,-74.150252]},{"osm_way":1246220575,"top":[-751.1658,4.5,-91.738812],"bottom":[-750.4266,-4.5,-74.272704]},{"osm_way":1246220576,"top":[-749.57652,4.5,-91.794472],"bottom":[-748.7172,-4.5,-74.406288]}],"martin_place":[{"osm_way":1251022021,"top":[-21.95424,4.5,733.98842],"bottom":[-24.59688,-7.5,757.788636]},{"osm_way":1251022022,"top":[-20.59596,4.5,734.09974],"bottom":[-23.27556,-7.5,757.888824]},{"osm_way":1251022023,"top":[-12.82512,4.5,734.567284],"bottom":[-15.51396,-7.5,758.567876]},{"osm_way":1251022024,"top":[-11.49456,4.5,734.622944],"bottom":[-14.26656,-7.5,758.6458]},{"osm_way":1251022035,"top":[-23.40492,4.5,733.921628],"bottom":[-26.07528,-7.5,757.710712]},{"osm_way":1251022036,"top":[-24.75396,4.5,733.810308],"bottom":[-27.40584,-7.5,757.610524]},{"osm_way":1251022045,"top":[-9.96072,4.5,734.834452],"bottom":[-12.60336,-7.5,758.634668]},{"osm_way":1251022046,"top":[-8.60244,4.5,734.956904],"bottom":[-11.2728,-7.5,758.734856]}]}
const MARTIN_OUTLINE := [[-31.42524,710.66688],[-33.2178,712.21423],[-35.27832,713.99535],[-42.504,773.82985],[-42.8736,779.18434],[0.44352,787.23278],[0.693,778.62774],[5.59944,717.27929],[3.8808,715.66515],[2.16216,714.06214]]

const MARTIN_HOLE := [[-25.72999,732.33004],[-7.44486,734.38286],[-10.8027,764.29231],[-29.08783,762.23949]]
const MARTIN_FLOOR_TRIANGLES := [[[-33.2178,712.21423],[-25.72999,732.33004],[-31.42524,710.66688]],[[-35.27832,713.99535],[-25.72999,732.33004],[-33.2178,712.21423]],[[-25.72999,732.33004],[-35.27832,713.99535],[-42.504,773.82985]],[[-10.8027,764.29231],[0.44352,787.23278],[0.693,778.62774]],[[-7.44486,734.38286],[5.59944,717.27929],[3.8808,715.66515]],[[-25.72999,732.33004],[2.16216,714.06214],[-31.42524,710.66688]],[[2.16216,714.06214],[-25.72999,732.33004],[-7.44486,734.38286]],[[-25.72999,732.33004],[-42.504,773.82985],[-29.08783,762.23949]],[[0.44352,787.23278],[-10.8027,764.29231],[-42.8736,779.18434]],[[2.16216,714.06214],[-7.44486,734.38286],[3.8808,715.66515]],[[-42.8736,779.18434],[-29.08783,762.23949],[-42.504,773.82985]],[[5.59944,717.27929],[-7.44486,734.38286],[0.693,778.62774]],[[-29.08783,762.23949],[-42.8736,779.18434],[-10.8027,764.29231]],[[0.693,778.62774],[-7.44486,734.38286],[-10.8027,764.29231]]]

static func v(data: Array) -> Vector3: return Vector3(data[0],data[1],data[2])

static func _frame(name: String) -> Dictionary:
	var a:=Vector3.ZERO
	var b:=Vector3.ZERO
	for row: Dictionary in ROUTES[name]: a+=v(row.top); b+=v(row.bottom)
	a/=ROUTES[name].size(); b/=ROUTES[name].size()
	if name=="barangaroo": a=BAR_TOP; b=BAR_BOTTOM
	var forward:=Vector3(b.x-a.x,0,b.z-a.z).normalized()
	var right:=Vector3(forward.z,0,-forward.x)
	return {"a":a,"b":b,"forward":forward,"right":right,"length":Vector2(b.x-a.x,b.z-a.z).length(),"basis":Basis(right,Vector3.UP,forward)}

static func excavation_polygons() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	for name: String in ["barangaroo","martin_place"]:
		var f:=_frame(name)
		var left: float=-3.55 if name=="barangaroo" else -9.2
		var right: float=3.55 if name=="barangaroo" else 9.2
		var poly:=PackedVector2Array()
		for point: Vector2 in [Vector2(left,-0.12 if name=="barangaroo" else -1.0),Vector2(right,-0.12 if name=="barangaroo" else -1.0),Vector2(right,f.length+5.1),Vector2(left,f.length+5.1)]:
			var p: Vector3=f.a+f.right*point.x+f.forward*point.y
			poly.append(Vector2(p.x,p.z))
		result.append(poly)
	return result

static func dry_volumes() -> Array[AABB]:
	var result: Array[AABB]=[]
	for poly: PackedVector2Array in excavation_polygons():
		var box:=AABB(Vector3(poly[0].x,-9.0,poly[0].y),Vector3(0,20.0,0))
		for p: Vector2 in poly: box=box.expand(Vector3(p.x,-9.0,p.y))
		result.append(box.grow(0.7))
	return result

static func contains_dry_volume(point: Vector3) -> bool:
	for box: AABB in dry_volumes():
		if box.has_point(point): return true
	return false

static func water_exclusion_rects() -> Array[Vector4]:
	var result: Array[Vector4]=[]
	for box: AABB in dry_volumes(): result.append(Vector4(box.position.x,box.position.z,box.end.x,box.end.z))
	return result

static func metadata() -> Array[Dictionary]:
	return [{"id":"barangaroo_metro","name":"Barangaroo · Hickson Road","entrance_osm":11445399049,"entrance":Vector3(-751.17504,4.5,-94.187852),"ground_y":4.5,"landing_y":-4.5,"height_confidence":"9m descent estimated; horizontal escalator runs are OSM mapped","scope":"ground canopy, three stationary walkable escalators and lower landing; no operating metro or full platforms"},{"id":"martin_place_metro","name":"Martin Place · Hunter Street","entrance_osm":[11553917358,11553917357],"entrance":Vector3(-33.2178,4.5,712.214228),"ground_y":4.5,"landing_y":-7.5,"height_confidence":"12m descent estimated; map shows eight northern escalator runs","scope":"two surface entries, northern atrium and first landing; no operating metro or full platforms"}]

static func build(world: Node3D) -> void:
	_materials(world)
	_barangaroo(world)
	_martin_place(world)
	world.set_meta("metro_entrances",metadata())
	world.anchors["barangaroo_metro"]=Vector3(-751.17504,4.5,-97.0)
	world.anchors["martin_place_metro"]=Vector3(-33.2178,4.5,707.5)

static func _materials(world: Node3D) -> void:
	for item: Array in [["metro_silver","969fa1"],["metro_dark","283c43"],["metro_timber","c6ac7d"],["metro_stone","9b9b94"],["metro_teal","08637a"],["metro_tread","626e70"],["metro_light","eee9d6"]]:
		world._mat(item[0],Color(item[1]),0.45 if item[0] in ["metro_silver","metro_tread"] else 0.82,0.55 if item[0]=="metro_silver" else 0.0)
	var glass: StandardMaterial3D=world._mat("metro_glass",Color(0.57,0.73,0.76,0.22),0.18,0.1)
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	var light: StandardMaterial3D=world.materials.metro_light
	light.emission_enabled=true;light.emission=Color("eee9d6");light.emission_energy_multiplier=0.45

static func _local_box(world: Node3D, parent: Node3D, pos: Vector3, size: Vector3, key: String, basis: Basis=Basis.IDENTITY) -> void:
	var view: MeshInstance3D=world._box(parent,pos,size,key)
	view.basis=basis

static func _label(parent: Node3D, text_value: String, position: Vector3, size: float, basis: Basis=Basis.IDENTITY, color: Color=Color("f0efe6")) -> void:
	var label:=Label3D.new()
	label.text=text_value;label.position=position;label.basis=basis
	label.font_size=48;label.pixel_size=size;label.outline_size=0
	label.modulate=color;label.visibility_range_end=160
	parent.add_child(label)

static func _escalator(world: Node3D, id: String, a: Vector3, b: Vector3) -> void:
	var z: Vector3=(b-a).normalized()
	var x:=Vector3(z.z,0,-z.x).normalized()
	var basis:=Basis(x,z.cross(x).normalized(),z)
	var length:=a.distance_to(b)
	var support: StaticBody3D=world._structure_box(id+"/support",(a+b)*0.5-basis.y*0.18,Vector3(1.13,0.36,length+0.08),"metro_tread",280000,basis)
	var horizontal:=Basis(x,Vector3.UP,Vector3(b.x-a.x,0,b.z-a.z).normalized())
	var run:=Vector2(b.x-a.x,b.z-a.z).length()
	var steps:=ceili(absf(b.y-a.y)/0.175)
	var rise:=absf(b.y-a.y)/steps
	for step in steps:
		var t: float=(step+0.5)/steps
		var point:=a.lerp(b,t)-Vector3.UP*(rise*0.5-0.025)
		_local_box(world,support,support.to_local(point),Vector3(1.05,rise,run/steps+0.012),"metro_tread",support.basis.inverse()*horizontal)
		# Contrasting nosings and fine grooves make actual treads legible.
		var nose:=point+horizontal.z*(run/steps*0.46)+Vector3.UP*(rise*0.5+0.004)
		_local_box(world,support,support.to_local(nose),Vector3(1.02,0.009,0.025),"yellow",support.basis.inverse()*horizontal)
		for groove in range(9):
			var g:=point+horizontal.x*(groove-4)*0.10+Vector3.UP*(rise*0.5+0.005)
			_local_box(world,support,support.to_local(g),Vector3(0.014,0.008,run/steps*0.86),"metro_dark",support.basis.inverse()*horizontal)
	for side in [-1,1]:
		var ga: Vector3=a+x*side*0.65+Vector3.UP*0.57
		var gb: Vector3=b+x*side*0.65+Vector3.UP*0.57
		world._structure_box(id+"/balustrade/%s"%side,(ga+gb)*0.5,Vector3(0.08,0.77,length+0.20),"metro_glass",65000,basis)
		world._structure_box(id+"/handrail/%s"%side,(ga+gb)*0.5+Vector3.UP*0.43,Vector3(0.13,0.13,length+0.22),"metro_dark",70000,basis)
		world._structure_box(id+"/skirt/%s"%side,(a+b)*0.5+x*side*0.66-Vector3.UP*0.2,Vector3(0.16,0.55,length+0.1),"metro_silver",120000,basis)
	for point: Vector3 in [a,b]:
		var landing: StaticBody3D=world._structure_box(id+"/comb/"+("upper" if point==a else "lower"),point-horizontal.z*(0.72 if point==a else -0.24)-Vector3.UP*0.055,Vector3(1.13,0.11,1.60 if point==a else 0.56),"metro_silver",100000,horizontal)
		_local_box(world,landing,Vector3(0,0.061,0),Vector3(1.0,0.01,0.05),"yellow")

static func _well(world: Node3D, name: String, width: float) -> void:
	var f:=_frame(name)
	var basis: Basis=f.basis
	var a: Vector3=f.a
	var b: Vector3=f.b
	var depth: float=a.y-b.y
	for side in [-1,1]:
		world._structure_box("metro/"+name+"/retaining/%s"%side,a+f.forward*(f.length+5.1)*0.5+f.right*side*(width*0.5+0.18)-Vector3.UP*(depth*0.5-0.5),Vector3(0.35,depth+1.0,f.length+5.1),"metro_stone",900000,basis)
	world._structure_box("metro/"+name+"/landing",b+f.forward*2.5-Vector3.UP*0.20,Vector3(width,0.40,5.15),"paving",650000,basis)
	world._structure_box("metro/"+name+"/lower_back",b+f.forward*5.2+Vector3.UP*(depth*0.5),Vector3(width+0.7,depth,0.4),"metro_stone",550000,basis)
	# Closed far wall represents the current model extent, with a clear way back.
	var panel: StaticBody3D=world._structure_box("metro/"+name+"/landing_sign",b+f.forward*5.0+Vector3.UP*2.15,Vector3(minf(width-0.5,5.3),0.6,0.14),"metro_teal",45000,basis)
	_label(panel,"↑  Street exit",Vector3(0,0,-0.08),0.012,Basis(Vector3.UP,PI))
	var lamp:=OmniLight3D.new()
	lamp.position=b+f.forward*2.5+Vector3.UP*3.0;lamp.omni_range=12.0;lamp.light_energy=1.4;lamp.light_color=Color("e4ded0")
	world.add_child(lamp)

static func _rounded_outline(width: float, length: float, radius: float, center_z: float) -> Array:
	var points: Array=[]
	for corner in range(4):
		var cx: float=(width*0.5-radius)*(1 if corner in [0,1] else -1)
		var cz: float=(length*0.5-radius)*(-1 if corner in [0,3] else 1)+center_z
		for i in range(9):
			var angle: float=(-PI*0.5+corner*PI*0.5)+i*PI/16.0
			points.append([cx+cos(angle)*radius,cz+sin(angle)*radius])
	return points

static func _barangaroo(world: Node3D) -> void:
	var f:=_frame("barangaroo")
	var a: Vector3=f.a
	var basis: Basis=f.basis
	for i in ROUTES.barangaroo.size():
		var row: Dictionary=ROUTES.barangaroo[i]
		_escalator(world,"metro/barangaroo/escalator/%s"%row.osm_way,v(row.top),v(row.bottom))
	_well(world,"barangaroo",7.1)
	var front_floor: StaticBody3D=world._structure_box("metro/barangaroo/front_landing",a-f.forward*2.8-Vector3.UP*0.06,Vector3(8.2,0.12,5.6),"paving",650000,basis)
	# Keep the physical floor at the mapped datum while separating its finish
	# from the city's coplanar land mesh so that it cannot flicker over grass.
	front_floor.get_child(0).position.y=0.025
	var outline:=_rounded_outline(12.6,29.0,3.0,8.8)
	var geom=load("res://scripts/manly_landmarks.gd")
	var canopy: StaticBody3D=world._structure_mesh("metro/barangaroo/canopy",geom.prism(outline,4.9,5.22),a,"metro_silver",500000,basis)
	var ceiling:=MeshInstance3D.new();ceiling.mesh=geom.prism(outline,4.85,4.91);ceiling.material_override=world.materials.metro_timber;canopy.add_child(ceiling)
	# Slim timber-look slats form a warm, continuous soffit below the silver lip.
	for x in range(-25,26):
		_local_box(world,canopy,Vector3(x*0.22,4.835,8.8),Vector3(0.028,0.02,23.0),"metro_stone")
	for side in [-1,1]:
		for station in [0.3,5.9,11.5,17.1]:
			world._structure_box("metro/barangaroo/pier/%s/%s"%[side,station],a+basis*Vector3(side*4.5,2.42,station),Vector3(0.46,4.85,1.25),"metro_stone",200000,basis)
		world._structure_box("metro/barangaroo/side_glass/%s"%side,a+basis*Vector3(side*4.47,2.45,9.0),Vector3(0.07,4.75,21.0),"metro_glass",130000,basis)
	var sign: StaticBody3D=world._structure_box("metro/barangaroo/entrance_sign",a+basis*Vector3(0,3.8,-1.2),Vector3(6.8,0.55,0.16),"metro_teal",85000,basis)
	_label(sign,"Barangaroo",Vector3(0,0,-0.085),0.010,Basis(Vector3.UP,PI))
	_marker(world,a+basis*Vector3(-6.8,0,-5.6),"Barangaroo",basis)

static func _marker(world: Node3D, p: Vector3, name: String, basis: Basis) -> void:
	world._batch_cylinder(p+Vector3.UP*1.65,0.085,3.3,"metro_silver")
	var post: StaticBody3D=world._structure_box("metro/sign/"+name,p+Vector3.UP*3.3,Vector3(0.85,0.85,0.18),"metro_teal",50000,basis)
	var sign_view: MeshInstance3D=post.get_child(0)
	var disc:=CylinderMesh.new()
	disc.top_radius=0.425;disc.bottom_radius=0.425;disc.height=0.18;disc.radial_segments=32
	sign_view.mesh=disc;sign_view.rotation.x=PI*0.5
	_label(post,"M",Vector3(0,0,-0.10),0.013,Basis(Vector3.UP,PI))

static func _martin_place(world: Node3D) -> void:
	var f:=_frame("martin_place")
	var geom=load("res://scripts/manly_landmarks.gd")
	# The original mapped 1 Elizabeth footprint contains the public atrium.
	# The shared map builder begins its ordinary tower above this 40m podium.
	var floor_body: StaticBody3D=world._structure_mesh("metro/martin_place/atrium_floor",geom.prism(MARTIN_OUTLINE,-0.18,0.0,MARTIN_HOLE,MARTIN_FLOOR_TRIANGLES),Vector3(0,4.5,0),"paving",1800000)
	floor_body.get_child(0).position.y=0.025
	var top: StaticBody3D=world._structure_mesh("metro/martin_place/transfer_roof",geom.prism(MARTIN_OUTLINE,39.4,40.0),Vector3(0,4.5,0),"metro_stone",1600000)
	for row: Dictionary in ROUTES.martin_place:
		_escalator(world,"metro/martin_place/escalator/%s"%row.osm_way,v(row.top),v(row.bottom))
	_well(world,"martin_place",18.4)
	for i in MARTIN_OUTLINE.size():
		var a:=Vector2(MARTIN_OUTLINE[i][0],MARTIN_OUTLINE[i][1])
		var b:=Vector2(MARTIN_OUTLINE[(i+1)%MARTIN_OUTLINE.size()][0],MARTIN_OUTLINE[(i+1)%MARTIN_OUTLINE.size()][1])
		var delta:=Vector3(b.x-a.x,0,b.y-a.y)
		var edge:=Basis(delta.normalized(),Vector3.UP,delta.normalized().cross(Vector3.UP))
		var mid:=Vector3((a.x+b.x)*0.5,4.5,(a.y+b.y)*0.5)
		var length:=delta.length()
		var entry:=i in [0,1,7,8]
		var bottom:=5.0 if entry else 0.0
		world._structure_box("metro/martin_place/glazing/%s"%i,mid+Vector3.UP*(bottom+40)*0.5,Vector3(length,40-bottom,0.09),"metro_glass",230000,edge)
		for level in range(1,9):
			world._batch_box(mid+Vector3.UP*level*4.8,Vector3(length,0.20,0.20),"metro_silver",edge)
		for bay in range(maxi(1,int(length/3.2))):
			var p:=a.lerp(b,(bay+0.5)/maxi(1,int(length/3.2)))
			world._batch_box(Vector3(p.x,4.5+(40+bottom)*0.5,p.y),Vector3(0.16,40-bottom,0.16),"metro_silver")
		if length>10:
			# Giant white circular columns flank, rather than fill, the doorways.
			var body: StaticBody3D=world._structure_box("metro/martin_place/column/%s"%i,Vector3(a.x,24.5,a.y),Vector3(1.6,40,1.6),"metro_light",650000)
			var old: MeshInstance3D=body.get_child(0);body.remove_child(old);old.free()
			var view:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=0.8;cylinder.bottom_radius=0.8;cylinder.height=40;cylinder.radial_segments=20;view.mesh=cylinder;view.material_override=world.materials.metro_light;body.add_child(view)
	# The planted terrace separates the two mapped four-escalator banks. Its
	# boundaries and facade details are reconstructions, not a complete station survey.
	for step in range(7):
		var t: float=(step+0.5)/7.0
		var p: Vector3=f.a.lerp(f.b,t)
		var planter: StaticBody3D=world._structure_box("metro/martin_place/terrace/%s"%step,p-Vector3.UP*0.5,Vector3(3.4,1.0,f.length/7.0+0.02),"metro_stone",180000,f.basis)
		_local_box(world,planter,Vector3(0,0.56,0),Vector3(3.1,0.12,f.length/7.0-0.15),"grass")
		for shrub in [-1,1]:world._batch_cylinder(p+f.right*shrub*0.7+Vector3.UP*0.3,0.40,0.65,"tree")
	# Two corner openings follow the exact entrance nodes on Hunter Street.
	for item: Array in [[Vector3(-33.2178,4.5,712.214228),"Hunter Street west"],[Vector3(3.8808,4.5,715.665148),"Hunter Street east"]]:
		var p: Vector3=item[0]
		var sign: StaticBody3D=world._structure_box("metro/martin_place/entry_sign/"+item[1],p+Vector3.UP*3.9,Vector3(3.4,0.55,0.16),"metro_teal",80000,Basis(Vector3.UP,-0.10))
		_label(sign,"Martin Place",Vector3(0,0,-0.09),0.010,Basis(Vector3.UP,PI))
		_marker(world,p+Vector3(-1.1,0,-2.0),"Martin Place "+item[1],Basis(Vector3.UP,-0.10))
		# Open glass canopy with visible supporting ribs and round downlights.
		var canopy: StaticBody3D=world._structure_box("metro/martin_place/entry_canopy/"+item[1],p+Vector3(0,4.65,-1.0),Vector3(5.4,0.18,4.2),"metro_glass",130000,Basis(Vector3.UP,-0.10))
		for rib in [-2,-1,0,1,2]:_local_box(world,canopy,Vector3(rib*1.15,-0.15,0),Vector3(0.09,0.20,4.2),"metro_silver")
		for side in [-1,1]:_local_box(world,canopy,Vector3(side*1.75,-0.23,-1.1),Vector3(0.25,0.09,0.25),"metro_light")
	var atrium_light:=OmniLight3D.new();atrium_light.position=f.a+Vector3.UP*8;atrium_light.omni_range=43;atrium_light.light_energy=2.0;atrium_light.light_color=Color("e9e0cb");world.add_child(atrium_light)
