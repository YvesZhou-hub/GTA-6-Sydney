class_name AirportWorld
extends Node3D
## Sydney airport at real geographic separation from the harbour.
## Runway axes use public-domain OurAirports endpoint data; exact dimensions
## use Sydney Airport's published values. Buildings and connecting terrain are
## original, explicitly simplified game geometry rather than surveyed replicas.

signal structure_damaged(object_id: String, severity: float)
const ORIGIN_LAT := -33.86
const ORIGIN_LON := 151.2105
const METRES_LAT := 111320.0
const AIRFIELD_Y := 6.4
# Every connected physical airside paving top shares this datum.
# Raised paint remains visual-only; even small collider steps damage fast aircraft.
const PAVEMENT_TOP := AIRFIELD_Y + 0.06
const SIMPLIFIED_TERRAIN := [
	{"id":"Simplified_City_Corridor","outline":[[-7800,1900],[2600,1900],[2900,5000],[1400,7200],[-1100,8000],[-5100,8600],[-7800,8200]],"elevation":4.35,"material":"scrub"},
	{"id":"Airport_North_Land","outline":[[-5300,7000],[-2200,7000],[-900,8600],[-1100,9430],[-2050,9920],[-3570,9600],[-4450,9770],[-5450,9100]],"elevation":6.25},
	{"id":"Airport_West_Coast","outline":[[-7800,8200],[-5450,8200],[-4400,9470],[-4150,10700],[-4500,12900],[-4850,14700],[-7800,14800]],"elevation":4.8},
	{"id":"Main_Runway_Peninsula","outline":[[-3650,9240],[-2980,9000],[-2500,11570],[-2590,11890],[-2870,11940],[-3020,11780]],"elevation":6.25},
	{"id":"Parallel_Runway_Peninsula","outline":[[-2350,9550],[-1660,9410],[-1190,12180],[-1290,12620],[-1710,12710],[-1820,12330]],"elevation":6.25}
]
# The detailed city ends at latitude -33.892 (z=3562.24). This public road
# continues slightly beyond that query edge because complete OSM ways are kept.
# Only this joining endpoint is real; everything south of it below is an
# explicitly simplified game connection, NOT a Sydney airport driving route.
const CONNECTOR_SOURCE := {
	"way":"way/3770421", "node":"node/18802172", "name":"George Street (Redfern)",
	"lat":-33.8925376, "lon":151.2021819, "snapshot":"2026-09-10T10:26:34Z",
	"source":"https://www.openstreetmap.org/way/3770421",
	"city_south_z":3562.24, "width_m":7.0
}
const CONNECTOR_ENTRY := Vector3(-768.592,4.5,3622.086)
const CONNECTOR_PREVIOUS := Vector3(-767.437,4.5,3613.124)

const RUNWAY_SPECS := [
	{"id": "16R_34L", "a": [-33.92940139770508,151.1719970703125], "b": [-33.964298248291016,151.18099975585938], "length": 3962.0, "width": 45.0, "a_name": "16R", "b_name": "34L"},
	{"id": "16L_34R", "a": [-33.94960021972656,151.18800354003906], "b": [-33.971099853515625,151.19400024414062], "length": 2438.0, "width": 45.0, "a_name": "16L", "b_name": "34R"},
	{"id": "07_25", "a": [-33.94369888305664,151.16400146484375], "b": [-33.9375,151.19000244140625], "length": 2530.0, "width": 45.0, "a_name": "07", "b_name": "25"}]

var anchors: Dictionary = {}
var runway_heading: float = 0.0
var runway_data: Array = []
var damaged: Dictionary = {}
var _panels: Dictionary = {}
var _fragments: Array[RigidBody3D] = []
var _materials: Dictionary = {}
var _built: bool = false

func setup() -> void:
	if _built:
		return
	_built = true
	name = "Sydney_Airport"
	_init_materials()
	_build_terrain()
	for spec in RUNWAY_SPECS:
		_build_runway(spec)
	_build_taxiways()
	_build_terminals()
	_build_hangar()
	_build_control_tower()
	_build_connector()
	var main: Dictionary = runway_data[0]
	var direction: Vector3 = (main.a - main.b).normalized()
	runway_heading = atan2(-direction.x, -direction.z)
	anchors["airport"] = geo(-33.946111, 151.177222, AIRFIELD_Y)
	anchors["runway_start"] = main.b + direction * 115.0 + Vector3.UP * 0.06
	anchors["runway_end"] = main.a - direction * 110.0 + Vector3.UP * 0.06
	anchors["airport_approach"] = main.b - direction * 2600.0 + Vector3.UP * 210.0
	anchors["airport_departure"] = main.a + direction * 800.0 + Vector3.UP * 280.0
	anchors["airport_runway_heading"] = runway_heading
	anchors["airport_connector"] = connector_route()
	set_meta("airport_connector_geography", CONNECTOR_SOURCE.merged({"simplified_after":CONNECTOR_ENTRY,"scope":"Real OSM street endpoint; unmeasured game road and grade south to the airport"}))

func geo(lat: float, lon: float, elevation: float = AIRFIELD_Y) -> Vector3:
	return Vector3((lon - ORIGIN_LON) * METRES_LAT * cos(deg_to_rad(ORIGIN_LAT)), elevation, (ORIGIN_LAT - lat) * METRES_LAT)

func _init_materials() -> void:
	_materials["asphalt"] = _mat(Color("343b3d"), 0.95)
	_materials["taxi"] = _mat(Color("464c4b"), 0.9)
	_materials["shoulder"] = _mat(Color("868579"), 0.93)
	_materials["grass"] = _mat(Color("667361"), 1.0)
	# The simplified corridor shares the city's world-space ground material;
	# a flat, differently shaded patch looked like a huge wall in aerial views.
	var scrub:=ShaderMaterial.new()
	scrub.shader=preload("res://shaders/world_landcover.gdshader")
	_materials["scrub"] = scrub
	_materials["concrete"] = _mat(Color("a6aaa4"), 0.88)
	_materials["white"] = _mat(Color("e8e5d5"), 0.72)
	_materials["yellow"] = _mat(Color("dbc56b"), 0.65)
	_materials["dark"] = _mat(Color("2d4149"), 0.6)
	_materials["glass"] = _mat(Color("5b8592"), 0.2, 0.5)
	_materials["steel"] = _mat(Color("9ea8a8"), 0.45, 0.6)
	_materials["roof"] = _mat(Color("ced0c6"), 0.7, 0.3)
	_materials["red"] = _mat(Color("9d3e35"), 0.7)
	_materials["amber_light"] = _mat(Color("ffdc9a"), 0.3, 0.0, 2.5)
	_materials["blue_light"] = _mat(Color("658fdf"), 0.3, 0.0, 2.0)
	_materials["green_light"] = _mat(Color("77d9b2"), 0.3, 0.0, 2.0)

func _mat(color: Color, roughness: float, metallic: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.metallic = metallic
	if glow > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = glow
	return result

func _box(parent: Node3D, id: String, at: Vector3, size: Vector3, material: String, collide: bool = false) -> Node3D:
	var node: Node3D = StaticBody3D.new() if collide else Node3D.new()
	node.name = id
	node.position = at
	parent.add_child(node)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _materials[material]
	node.add_child(mesh)
	if collide:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		node.add_child(collision)
	return node

func _line(parent: Node3D, id: String, a: Vector3, b: Vector3, width: float, thick: float, material: String, collide: bool = false) -> Node3D:
	var delta := b - a
	var node := _box(parent, id, (a + b) * 0.5, Vector3(width, thick, delta.length()), material, collide)
	# Local Z spans the segment; signs do not affect symmetric road geometry.
	node.rotation.y = atan2(delta.x, delta.z)
	if absf(delta.y) > 0.001:
		node.rotation.x = -asin(delta.y / delta.length())
	return node

func _land(id: String, points: Array, elevation: float, material: String = "grass") -> void:
	var polygon := PackedVector2Array()
	for point in points:
		polygon.append(Vector2(float(point[0]), float(point[1])))
	var indices := Geometry2D.triangulate_polygon(polygon)
	var vertices := PackedVector3Array()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in range(0, indices.size(), 3):
		var tri := [polygon[indices[n]],polygon[indices[n+1]],polygon[indices[n+2]]]
		var va := Vector3(tri[0].x,elevation,tri[0].y)
		var vb := Vector3(tri[1].x,elevation,tri[1].y)
		var vc := Vector3(tri[2].x,elevation,tri[2].y)
		# Godot front faces use clockwise winding (opposite the math cross).
		if (vb-va).cross(vc-va).y > 0.0:
			var hold := vb
			vb = vc
			vc = hold
		for vertex in [va,vb,vc]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(vertex.x,vertex.z) / 35.0)
			surface.add_vertex(vertex)
			vertices.append(vertex)
	var body := StaticBody3D.new()
	body.name = id
	add_child(body)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = _materials[material]
	body.add_child(instance)
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(vertices)
	collision.shape = shape
	body.add_child(collision)
	# A sloped stone seawall gives the shore real thickness and contact.
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		_line(self, id + "_edge_%d" % i, Vector3(a.x,elevation*0.5,a.y),Vector3(b.x,elevation*0.5,b.y), 3.5, elevation, "shoulder", true)

func _build_terrain() -> void:
	# This deliberately empty continuous land corridor is a game adjustment.
	# Botany Bay stays open south/east of the two runway peninsulas.
	for patch in SIMPLIFIED_TERRAIN:
		_land(patch.id,patch.outline,patch.elevation,patch.get("material","grass"))

func _build_runway(spec: Dictionary) -> void:
	var source_a := geo(float(spec.a[0]), float(spec.a[1]))
	var source_b := geo(float(spec.b[0]), float(spec.b[1]))
	var direction := (source_b - source_a).normalized()
	var centre := (source_a + source_b) * 0.5
	var length := float(spec.length)
	var a := centre - direction * length * 0.5
	var b := centre + direction * length * 0.5
	var right := Vector3(direction.z, 0, -direction.x)
	var runway := Node3D.new()
	runway.name = "Runway_" + str(spec.id)
	add_child(runway)
	_line(runway,"Shoulder",a-Vector3.UP*0.06,b-Vector3.UP*0.06,59.0,0.16,"shoulder",true)
	_line(runway,"Asphalt",a,b,float(spec.width),0.12,"asphalt",true)
	for side in [-1,1]:
		_line(runway,"Edge_%d" % side,a + right*21.5*side + Vector3.UP*0.072,b + right*21.5*side + Vector3.UP*0.072,0.55,0.018,"white")
	var stripe_positions: Array[Transform3D] = []
	var light_positions: Array[Transform3D] = []
	var yaw := atan2(direction.x,direction.z)
	for d in range(180,int(length)-180,60):
		stripe_positions.append(Transform3D(Basis(Vector3.UP,yaw),a + direction*d + Vector3.UP*0.075))
	for d in range(0,int(length)+1,60):
		for side in [-1,1]:
			light_positions.append(Transform3D(Basis.IDENTITY,a+direction*d+right*24.0*side+Vector3.UP*0.3))
	_instances(runway,"Centreline",Vector3(0.75,0.02,30),"white",stripe_positions)
	_instances(runway,"Runway_Edge_Lights",Vector3(0.3,0.2,0.3),"amber_light",light_positions)
	for end in [0,1]:
		var threshold := a if end == 0 else b
		var forward := direction if end == 0 else -direction
		var lateral := right if end == 0 else -right
		for side in [-1,1]:
			for n in 6:
				var x: float = (3.0+float(n)*2.4)*float(side)
				_line(runway,"Threshold_%d_%d_%d" % [end,side,n],threshold+forward*10+lateral*x+Vector3.UP*0.085,threshold+forward*42+lateral*x+Vector3.UP*0.085,1.6,0.018,"white")
			_line(runway,"Aim_%d_%d" % [end,side],threshold+forward*280+lateral*12+Vector3.UP*0.09,threshold+forward*325+lateral*12+Vector3.UP*0.09,6.0,0.02,"white")
		var mark := Label3D.new()
		mark.name = "Runway_Designator"
		mark.text = str(spec.a_name if end==0 else spec.b_name)
		mark.font_size = 160
		mark.pixel_size = 0.15
		mark.outline_size = 0
		mark.modulate = Color("efead6")
		mark.position = threshold + forward*95 + Vector3.UP*0.10
		mark.rotation = Vector3(-PI/2.0,atan2(-forward.x,-forward.z),0)
		runway.add_child(mark)
		var approach: Array[Transform3D] = []
		for distance in range(30,451,30):
			approach.append(Transform3D(Basis.IDENTITY,threshold-forward*distance+Vector3.UP*0.4))
			if distance == 300:
				for x in range(-15,16,3):
					approach.append(Transform3D(Basis.IDENTITY,threshold-forward*distance+lateral*x+Vector3.UP*0.4))
		_instances(runway,"Approach_%d" % end,Vector3(0.45,0.3,0.45),"amber_light",approach)
		var greens: Array[Transform3D] = []
		for x in range(-21,22,3):
			greens.append(Transform3D(Basis.IDENTITY,threshold+lateral*x+Vector3.UP*0.2))
		_instances(runway,"Threshold_Lights_%d" % end,Vector3(0.35,0.22,0.35),"green_light",greens)
	runway_data.append({"id":spec.id,"a":a,"b":b,"length":length,"width":45.0,"direction":direction,"right":right})

func _instances(parent: Node3D, id: String, size: Vector3, material: String, transforms: Array[Transform3D]) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _materials[material]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i,transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = id
	instance.multimesh = multi
	parent.add_child(instance)

func _taxi(id: String, points: Array, width: float = 24.0) -> void:
	for i in points.size()-1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i+1]
		a.y = PAVEMENT_TOP - 0.06
		b.y = PAVEMENT_TOP - 0.06
		_line(self,id+"_pavement_%d"%i,a,b,width,0.12,"taxi",true)
		_line(self,id+"_centre_%d"%i,a+Vector3.UP*0.072,b+Vector3.UP*0.072,0.3,0.018,"yellow")
		var axis := (b-a).normalized()
		var right := Vector3(axis.z,0,-axis.x)
		var lights: Array[Transform3D] = []
		for d in range(0,int(a.distance_to(b)),60):
			for side in [-1,1]:
				lights.append(Transform3D(Basis.IDENTITY,a+axis*d+right*(width*0.5+0.5)*side+Vector3.UP*0.15))
		_instances(self,id+"_blue_%d"%i,Vector3(0.22,0.15,0.22),"blue_light",lights)

func _build_taxiways() -> void:
	for i in runway_data.size():
		var runway: Dictionary = runway_data[i]
		var right: Vector3 = runway.right
		var sign_side := -1.0 if i < 2 else 1.0
		var offset := right * sign_side * 115.0
		_taxi("Taxi_"+str(runway.id),[runway.a+offset,runway.b+offset])
		for progress in [0.035,0.26,0.51,0.76,0.965]:
			var runway_point: Vector3 = runway.a.lerp(runway.b,progress)
			_taxi("Exit_%d_%d"%[i,int(progress*100)],[runway_point,runway_point+offset],27.0)
			var hold := runway_point+offset*0.64
			_line(self,"Hold_%d_%d"%[i,int(progress*100)],hold-right*11+Vector3.UP*0.15,hold+right*11+Vector3.UP*0.15,0.5,0.02,"yellow")
	# International apron and the Alpha connection are large enough for a
	# 60 metre wide aircraft to move without intersecting terminal geometry.
	_box(self,"International_Apron",Vector3(-4040,PAVEMENT_TOP-0.075,8510),Vector3(630,0.15,780),"concrete",true)
	_box(self,"Domestic_Apron",Vector3(-2930,PAVEMENT_TOP-0.075,8130),Vector3(570,0.15,730),"concrete",true)
	_taxi("International_Link",[Vector3(-4020,6.4,8530),Vector3(-3680,6.4,8520),runway_data[0].a.lerp(runway_data[0].b,0.27)-runway_data[0].right*115])
	_taxi("Domestic_Link",[Vector3(-2850,6.4,8350),Vector3(-3080,6.4,8570),runway_data[0].a.lerp(runway_data[0].b,0.30)],28.0)
	_taxi("Parallel_Link",[runway_data[1].a-runway_data[1].right*115,Vector3(-2270,6.4,9520),Vector3(-2930,6.4,9150),runway_data[0].a.lerp(runway_data[0].b,0.37)],30.0)

func _wall(parent: Node3D, id: String, at: Vector3, size: Vector3, material: String) -> void:
	var node := _box(parent,id,at,size,material,true)
	node.set_meta("airport_damage_id",id)
	_panels[id] = {"node":node,"size":size,"material":material}

func _terminal(id: String, at: Vector3, width: float, depth: float, text: String) -> Node3D:
	var hall := Node3D.new()
	hall.name = id
	hall.position = at
	add_child(hall)
	_box(hall,"Floor",Vector3(0,PAVEMENT_TOP-at.y-0.125,0),Vector3(width,0.25,depth),"concrete",true)
	_box(hall,"Roof",Vector3(0,9.2,0),Vector3(width+4,0.6,depth+4),"roof",true)
	for z in [-depth*0.5,depth*0.5]:
		for i in int(width/12.0):
			var x := -width*0.5+6.0+i*12.0
			if absf(x) > 13.0:
				_wall(hall,id+"_facade_%d_%d"%[int(z),i],Vector3(x,4.0,z),Vector3(11.7,7.5,0.38),"glass")
			_box(hall,"Mullion",Vector3(x-6,4.5,z),Vector3(0.3,9,0.6),"steel",true)
		_box(hall,"Canopy",Vector3(0,6.4,z+signf(z)*4),Vector3(28,0.45,9),"roof",true)
	for x in [-width*0.5,width*0.5]:
		_wall(hall,id+"_end_%d"%int(x),Vector3(x,4.5,0),Vector3(0.5,8.8,depth),"concrete")
	for x in range(-int(width*0.5)+12,int(width*0.5),24):
		for z in [-depth*0.27,depth*0.27]:
			_box(hall,"Column",Vector3(x,4.4,z),Vector3(0.7,8.8,0.7),"concrete",true)
			_box(hall,"Bench",Vector3(x,0.65,z+3),Vector3(5.4,0.35,0.9),"dark",true)
	for x in range(-int(width*0.5)+12,int(width*0.5),12):
		_box(hall,"Roof_Rib",Vector3(x,9.65,0),Vector3(0.22,0.8,depth+5),"white")
	var sign_node := Label3D.new()
	sign_node.text = text + "\nSYDNEY / YSSY"
	sign_node.position = Vector3(0,7.5,depth*0.5+0.8)
	sign_node.font_size = 70
	sign_node.pixel_size = 0.04
	sign_node.outline_size = 0
	sign_node.modulate = Color("244753")
	hall.add_child(sign_node)
	return hall

func _build_terminals() -> void:
	var international_at := Vector3(-4310,AIRFIELD_Y+0.2,8460)
	var international := _terminal("International_Terminal",international_at,210,54,"INTERNATIONAL HALL")
	international.rotation.y = PI/2.0
	_terminal("Domestic_Terminal",Vector3(-2700,AIRFIELD_Y+0.2,7990),230,65,"DOMESTIC HALL")
	anchors["terminal"] = international_at + Vector3(36,0.4,0)
	anchors["airport_terminal"] = anchors.terminal
	for i in 6:
		var z := 8200.0 + i*88.0
		# Freestanding piers and articulated boarding bridges, original geometry.
		var gate := Node3D.new()
		gate.name = "International_Gate_%02d" % (i+1)
		gate.position = Vector3(-4240,AIRFIELD_Y,z)
		add_child(gate)
		_box(gate,"Concourse",Vector3(45,4.5,0),Vector3(100,8.2,15),"glass",true)
		_box(gate,"Concourse_Roof",Vector3(45,8.8,0),Vector3(103,0.5,18),"roof",true)
		_box(gate,"Bridge",Vector3(102,3.9,8),Vector3(27,3.0,4.5),"steel",true)
		_box(gate,"Bridge_Window",Vector3(102,4.1,10.3),Vector3(25,1.3,0.15),"glass")
		for x in [18,64,106]:
			_box(gate,"Pier",Vector3(x,1.8,0),Vector3(1.0,3.6,1.0),"concrete",true)
		_line(self,"Gate_Stand_%d"%i,Vector3(-4070,6.7,z),Vector3(-3940,6.7,z),0.28,0.03,"yellow")
		var number := Label3D.new()
		number.text = "G%02d"%(i+1)
		number.position = Vector3(-4050,6.72,z+12)
		number.rotation.x = -PI/2.0
		number.pixel_size = 0.15
		number.font_size = 60
		number.modulate = Color("e0c767")
		number.outline_size = 0
		add_child(number)

func _build_hangar() -> void:
	var at := Vector3(-4510,AIRFIELD_Y+0.2,9040)
	var hangar := Node3D.new()
	hangar.name = "Harbour_Aviation_Hangar"
	hangar.position = at
	add_child(hangar)
	_box(hangar,"Floor",Vector3(0,PAVEMENT_TOP-at.y-0.15,0),Vector3(88,0.3,96),"concrete",true)
	_box(hangar,"Roof",Vector3(0,24,0),Vector3(92,0.8,98),"roof",true)
	for x in [-44,44]:
		for z in range(-40,41,10):
			_wall(hangar,"hangar_wall_%d_%d"%[x,z],Vector3(x,12,z),Vector3(0.8,24,9.9),"steel")
	for x in range(-38,39,12):
		_wall(hangar,"hangar_rear_%d"%x,Vector3(x,12,48),Vector3(11.8,24,0.8),"concrete")
	# Clear 82 m x 23 m open entrance accommodates the widebody's whole span.
	for x in [-42,42]:
		_box(hangar,"Entrance_Frame",Vector3(x,11.5,-47),Vector3(1.4,23,1.2),"dark",true)
	for z in range(-40,41,16):
		_box(hangar,"Roof_Truss",Vector3(0,22.6,z),Vector3(87,0.45,0.45),"dark")
	for i in 4:
		_box(hangar,"Workshop_Cabinet",Vector3(-39,1.6,10+i*8),Vector3(3,3.2,5),"dark",true)
	var sign_node := Label3D.new()
	sign_node.text = "HARBOUR AVIATION\nSERVICE HANGAR"
	sign_node.position = Vector3(0,20,-48.2)
	sign_node.rotation.y = PI
	sign_node.font_size = 70
	sign_node.pixel_size = 0.08
	sign_node.outline_size = 0
	sign_node.modulate = Color("203d46")
	hangar.add_child(sign_node)
	anchors["hangar"] = at + Vector3(0,0.5,-15)
	anchors["airport_hangar"] = anchors.hangar
	_box(self,"Hangar_Apron",Vector3(at.x,PAVEMENT_TOP-0.1,at.z-125),Vector3(145,0.2,165),"concrete",true)
	_taxi("Hangar_Access",[at+Vector3(0,0,-95),Vector3(-4230,6.4,8885),Vector3(-4020,6.4,8810)],32)

func _build_control_tower() -> void:
	var at := geo(-33.9397,151.1717)
	var tower := Node3D.new()
	tower.name = "Original_Control_Tower"
	tower.position = at
	add_child(tower)
	_box(tower,"Tower_Core",Vector3(0,25,0),Vector3(8,50,8),"concrete",true)
	for side in [-1,1]:
		_box(tower,"Tower_Recess",Vector3(side*4.03,27,0),Vector3(0.1,43,4),"dark")
	var cab := _box(tower,"Control_Cab",Vector3(0,51.6,0),Vector3(20,5.8,20),"glass",true)
	cab.rotation.y = PI/4
	var roof := _box(tower,"Control_Cab_Roof",Vector3(0,54.8,0),Vector3(23,0.9,23),"roof",true)
	roof.rotation.y = PI/4
	_box(tower,"Radar_Mast",Vector3(0,59,0),Vector3(0.4,8,0.4),"steel")
	_box(tower,"Beacon",Vector3(0,63.2,0),Vector3(0.5,0.5,0.5),"amber_light")
	_box(tower,"Radar_Aerial",Vector3(0,61,0),Vector3(7,1.7,0.6),"red")
	anchors["airport_tower"] = at

static func connector_sections() -> Array:
	var tangent := (CONNECTOR_ENTRY-CONNECTOR_PREVIOUS).normalized()
	# Start at the exact rendered residential-road end, retaining its 7m width.
	# Expand only beyond the mapped city, away from the parallel cycleway.
	return [
		{"point":CONNECTOR_ENTRY,"width":7.0,"visual_lift":0.085},
		{"point":CONNECTOR_ENTRY+tangent*80.0+Vector3.UP*0.085,"width":7.0,"visual_lift":0.0},
		{"point":Vector3(-860,4.67,3900),"width":12.0,"visual_lift":0.0},
		{"point":Vector3(-1200,4.8,4180),"width":25.0,"visual_lift":0.0},
		{"point":Vector3(-1900,4.925,4500),"width":25.0,"visual_lift":0.0},
		{"point":Vector3(-2600,4.925,4600),"width":25.0,"visual_lift":0.0},
		{"point":Vector3(-4200,4.925,6400),"width":25.0,"visual_lift":0.0},
		# Reach the existing raised airport land before its northern edge z=7000.
		{"point":Vector3(-4261.9355,PAVEMENT_TOP,6800),"width":25.0,"visual_lift":0.0},
		{"point":Vector3(-4440,PAVEMENT_TOP,7950),"width":25.0,"visual_lift":0.0},
		{"point":Vector3(-4400,PAVEMENT_TOP,8460),"width":25.0,"visual_lift":0.0}
	]

static func connector_route() -> Array[Vector3]:
	var route:Array[Vector3]=[]
	for section in connector_sections():route.append(section.point)
	return route

static func connector_edges(sections:Array) -> Array:
	var edges:Array=[]
	for i in sections.size():
		var at:Vector3=sections[i].point
		var incoming:Vector3=(at-sections[maxi(0,i-1)].point) if i>0 else (sections[1].point-at)
		var outgoing:Vector3=(sections[mini(i+1,sections.size()-1)].point-at) if i<sections.size()-1 else incoming
		incoming.y=0;outgoing.y=0
		incoming=incoming.normalized();outgoing=outgoing.normalized()
		var previous_side:=Vector3(-incoming.z,0,incoming.x)
		var next_side:=Vector3(-outgoing.z,0,outgoing.x)
		var bisector:Vector3=(previous_side+next_side).normalized()
		var side:Vector3=bisector*(float(sections[i].width)*0.5/maxf(0.5,bisector.dot(next_side)))
		edges.append([at+side,at-side])
	return edges

static func _connector_mesh(sections:Array,visible_surface:bool) -> ArrayMesh:
	# A single indexed ribbon avoids internal box-end collision faces at joins.
	# First contact follows the city terrain datum (4.5); its visual-only 8.5cm
	# lift tapers to zero, matching the existing OSM road rendering at the join.
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges:=connector_edges(sections)
	for i in range(sections.size()-1):
		var a:Vector3=edges[i][0];var b:Vector3=edges[i+1][0]
		var c:Vector3=edges[i+1][1];var d:Vector3=edges[i][1]
		if visible_surface:
			a.y+=sections[i].visual_lift;d.y+=sections[i].visual_lift
			b.y+=sections[i+1].visual_lift;c.y+=sections[i+1].visual_lift
		for triangle in [[a,b,c],[a,c,d]]:
			var normal:Vector3=(triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
			if normal.y>0:
				var swap:Vector3=triangle[1];triangle[1]=triangle[2];triangle[2]=swap
			else:normal=-normal
			for vertex:Vector3 in triangle:
				surface.set_normal(normal);surface.set_uv(Vector2(vertex.x,vertex.z)*.05);surface.add_vertex(vertex)
	surface.index()
	return surface.commit()

func _build_connector() -> void:
	var sections:=connector_sections()
	var body:=StaticBody3D.new();body.name="Connector_Road"
	body.set_meta("geography",CONNECTOR_SOURCE)
	add_child(body)
	var view:=MeshInstance3D.new();view.mesh=_connector_mesh(sections,true);view.material_override=_materials.asphalt;body.add_child(view)
	var collision:=CollisionShape3D.new();collision.shape=_connector_mesh(sections,false).create_trimesh_shape();body.add_child(collision)
	for i in range(sections.size()-1):
		var a:Vector3=sections[i].point;var b:Vector3=sections[i+1].point
		# Keep the source residential road's unmarked narrow continuation.
		if i>=2:_line(self,"Connector_Centre_%d"%i,a+Vector3.UP*.014,b+Vector3.UP*.014,.35,.02,"white")
		var forward:Vector3=(b-a).normalized();var side:=Vector3(forward.z,0,-forward.x)
		for distance in range(50,int(a.distance_to(b)),160):
			var p:Vector3=a+forward*distance
			var half_width:float=lerpf(sections[i].width,sections[i+1].width,float(distance)/a.distance_to(b))*.5
			_box(self,"Roadside_Pole",p+side*(half_width+1.5)+Vector3.UP*4,Vector3(.18,8,.18),"steel")
			_box(self,"Roadside_Lamp",p+side*(half_width-.5)+Vector3.UP*8,Vector3(4,.2,.6),"white")
	# The old 4.4m-high floating development label in Tumbalong is removed.
	# This route's approximation belongs in map/reference metadata, not a plaza.

	# Distant scrub trees give movement scale, with a single draw per mesh.
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var random := RandomNumberGenerator.new()
	random.seed = 909016
	for i in 280:
		var at := Vector3(random.randf_range(-6500,700),4.5,random.randf_range(2300,7000))
		trunks.append(Transform3D(Basis.IDENTITY,at+Vector3.UP*2.3))
		crowns.append(Transform3D(Basis.IDENTITY,at+Vector3.UP*5.2))
	_tree_instances(trunks,crowns)

func _tree_instances(trunks: Array[Transform3D], crowns: Array[Transform3D]) -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.27
	trunk_mesh.height = 4.6
	trunk_mesh.radial_segments = 6
	trunk_mesh.material = _materials["shoulder"]
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 2.8
	crown_mesh.height = 4.3
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 5
	crown_mesh.material = _materials["grass"]
	for collection in [[trunk_mesh,trunks,"Corridor_Trunks"],[crown_mesh,crowns,"Corridor_Canopy"]]:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = collection[0]
		multi.instance_count = collection[1].size()
		for i in collection[1].size():
			multi.set_instance_transform(i,collection[1][i])
		var instance := MultiMeshInstance3D.new()
		instance.name = collection[2]
		instance.multimesh = multi
		add_child(instance)

func apply_impact(at: Vector3, severity: float) -> int:
	if severity < 15.0:
		return 0
	var radius := clampf(severity*0.13,3.0,45.0)
	var hits := 0
	for id in _panels:
		if damaged.has(id):
			continue
		var panel: Dictionary = _panels[id]
		var node: Node3D = panel.node
		if node.global_position.distance_to(at) <= radius + minf(panel.size.length()*0.25,8.0):
			_break_panel(id,true)
			hits += 1
	return hits

func _break_panel(id: String, fragments: bool) -> void:
	if not _panels.has(id) or damaged.has(id):
		return
	var data: Dictionary = _panels[id]
	var node: Node3D = data.node
	damaged[id] = true
	node.visible = false
	for child in node.get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled",true)
	if fragments and _fragments.size() < 45:
		var body := RigidBody3D.new()
		body.name = "airport_fragment_"+id
		body.mass = 130
		body.position = node.global_position+Vector3.UP*0.3
		body.rotation = node.global_rotation
		add_child(body)
		var size: Vector3 = data.size*Vector3(0.45,0.35,1.0)
		size.x = minf(size.x,5)
		size.y = minf(size.y,4)
		size.z = minf(size.z,5)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		mesh.material_override = _materials[data.material]
		body.add_child(mesh)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		body.angular_velocity = Vector3(0.5,0.2,0.9)
		body.set_meta("fragment_material",str(data.material))
		body.set_meta("fragment_size",size)
		_fragments.append(body)
	structure_damaged.emit(id,1.0)

func get_state() -> Dictionary:
	var pieces: Array = []
	for piece in _fragments:
		if is_instance_valid(piece) and piece.global_position.y > -100.0:
			pieces.append({"id":str(piece.name),"position":_pack(piece.global_position),"rotation":_pack(piece.rotation),
				"velocity":_pack(piece.linear_velocity),"angular_velocity":_pack(piece.angular_velocity),
				"size":_pack(piece.get_meta("fragment_size",Vector3.ONE)),"material":piece.get_meta("fragment_material","concrete")})
	return {"version":2,"damaged":damaged.keys(),"fragments":pieces}

func _pack(vector: Vector3) -> Array:
	return [vector.x,vector.y,vector.z]

func _unpack(value: Variant) -> Vector3:
	if value is Array and value.size()==3:
		return Vector3(float(value[0]),float(value[1]),float(value[2]))
	return Vector3.ZERO

func _restore_fragment(data: Dictionary) -> void:
	var material := str(data.get("material","concrete"))
	if not _materials.has(material):
		material = "concrete"
	var size := _unpack(data.get("size",[1,1,1]))
	size = size.clamp(Vector3.ONE*0.1,Vector3.ONE*10.0)
	var body := RigidBody3D.new()
	body.name = str(data.get("id","airport_fragment"))
	body.mass = 130
	add_child(body)
	body.global_position = _unpack(data.get("position",[0,10,0]))
	body.rotation = _unpack(data.get("rotation",[0,0,0]))
	body.linear_velocity = _unpack(data.get("velocity",[0,0,0]))
	body.angular_velocity = _unpack(data.get("angular_velocity",[0,0,0]))
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _materials[material]
	body.add_child(instance)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.set_meta("fragment_material",material)
	body.set_meta("fragment_size",size)
	_fragments.append(body)

func repair_all() -> int:
	var count := damaged.size()
	apply_state({})
	return count

func apply_state(state: Dictionary) -> void:
	# Restore intact geometry as well when a different local world is loaded.
	for id in _panels:
		var node: Node3D = _panels[id].node
		node.visible = true
		for child in node.get_children():
			if child is CollisionShape3D:
				child.set_deferred("disabled",false)
	damaged.clear()
	for fragment in _fragments:
		if is_instance_valid(fragment):
			fragment.queue_free()
	_fragments.clear()
	for id in state.get("damaged",[]):
		_break_panel(str(id),false)
	for fragment in state.get("fragments",[]):
		if fragment is Dictionary and _fragments.size()<45:
			_restore_fragment(fragment)
