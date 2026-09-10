extends Node3D
## Original reusable harbour environment. Geographic data attribution is in assets/world_geography.json.
## Geometry is meter-scale, +X east, +Z south, Y=0 mean water. Stable component IDs are save keys.

signal structure_damaged(point: Vector3, severity: float)

var anchors: Dictionary = {
	"home": Vector3(-335,5.0,-28), "quay": Vector3(70,5,165),
	"opera": Vector3(414,5,-151), "rocks": Vector3(-210,5,-175),
	"north": Vector3(302,5,-1218), "marina": Vector3(-545,3,-410),
	"helipad": Vector3(-410,5,420)
}
var materials: Dictionary = {}
var structures: Dictionary = {}
var destroyed: Dictionary = {}
var partial_damage: Dictionary = {}
var rubble: Array[Node3D] = []
var geography: Dictionary = {}
var south_polygon: PackedVector2Array
var north_polygon: PackedVector2Array
var road_segments: Array = []
var _batch_boxes: Dictionary = {}
var _batch_cylinders: Dictionary = {}
var _batch_foliage: Dictionary = {}
var _visual_cells: Dictionary = {}
var _dirty_cells: Dictionary = {}
var _visual_refresh_queued := false
var _rng := RandomNumberGenerator.new()
var _building_count := 0
var _ready_complete := false
var _material_cache: Dictionary = {}
var _building_plots: Array[AABB] = []
var _distant_visual_plots: Array[AABB] = []
const GROUND := 4.5
const MAX_RUBBLE := 96
const FACADE = preload("res://assets/world_facade.gdshader")
const WATER = preload("res://shaders/water.gdshader")
const LANDCOVER = preload("res://shaders/world_landcover.gdshader")

func _ready() -> void:
	_rng.seed = 940219
	_make_materials()
	geography = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world_geography.json"))
	_build_land()
	_build_water()
	_build_streets()
	_build_bridge()
	_build_opera()
	_build_quay()
	_build_home()
	_build_neighborhoods()
	_build_north()
	_build_frontages()
	_build_gardens()
	_build_observatory()
	_build_helipad()
	_polish_landscape_visuals()
	_flush_batches()
	for id in structures:
		for child in structures[id]["node"].get_children():
			if child is MeshInstance3D: child.set_meta("intact_material",child.material_override)
	_build_structure_batches()
	_ready_complete = true
	print("HARBOR_WORLD_READY buildings=%s structure_components=%s" % [_building_count, structures.size()])

func _mat(key: String, color: Color, roughness: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metal
	materials[key] = m
	return m

func _make_materials() -> void:
	_mat("sandstone", Color("bc9e78"))
	_mat("paving", Color("c3b7a1"), 0.94)
	_mat("lightstone", Color("dbcfb6"), 0.82)
	_mat("concrete", Color("b8b4a7"), 0.91)
	_mat("road", Color("3f494b"), 0.94)
	_mat("white", Color("efede1"), 0.62)
	_mat("yellow", Color("d4b35c"), 0.72)
	_mat("steel", Color("344b4d"), 0.54, 0.62)
	_mat("darksteel", Color("233537"), 0.49, 0.68)
	_mat("glass", Color("284b52"), 0.16, 0.47)
	_mat("roof", Color("735b4d"), 0.87)
	_mat("slate", Color("4a595b"), 0.85)
	_mat("copper", Color("739284"), 0.68, 0.25)
	_mat("wood", Color("806446"), 0.93)
	_mat("tree", Color("477153"), 0.99)
	_mat("tree_light", Color("6e855a"), 0.99)
	_mat("bark", Color("665342"), 1.0)
	_mat("grass", Color("78866a"), 1.0)
	_mat("hedge", Color("42634d"), 0.99)
	_mat("coral", Color("bd735d"), 0.81)
	_mat("teal", Color("1e6f78"), 0.72)
	_mat("navy", Color("223c50"), 0.77)
	_mat("rubble", Color("8d8270"), 1.0)
	_mat("cloth", Color("d8c8a5"), 0.98)
	var landcover := ShaderMaterial.new()
	landcover.shader = LANDCOVER
	materials["north_landcover"] = landcover
	var glow := _mat("lamp", Color("fff0c2"), 0.4)
	glow.emission_enabled = true
	glow.emission = Color("ffe0a2")
	glow.emission_energy_multiplier = 1.4
	# Original tile/paving textures, generated deterministically; no downloaded imagery.
	for key in ["paving", "sandstone", "lightstone", "concrete", "roof"]:
		var tex := _surface_texture(str(key))
		materials[key].albedo_texture = tex
		materials[key].uv1_triplanar = true
		materials[key].uv1_scale = Vector3(0.35,0.35,0.35)

func _surface_texture(key: String) -> ImageTexture:
	var im := Image.create(128,128,false,Image.FORMAT_RGB8)
	for y in range(128):
		for x in range(128):
			var n: float = float((x*7919+y*7907+x*y*53)%101)/101.0
			var value: float = 0.92+n*0.08
			var yy := y%32
			var xx := (x + (y/32%2)*32)%64
			if key == "roof":
				value = 0.80 + sin(float(x)*0.39)*0.06+n*0.12
				if y%16<2: value *= 0.78
			elif yy < 1 or xx < 1:
				value *= 0.73
			im.set_pixel(x,y,Color(value,value,value))
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)

func _box(parent: Node3D, pos: Vector3, size: Vector3, key: String, collide: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = materials[key]
	n.position = pos
	parent.add_child(n)
	if collide:
		var b := StaticBody3D.new()
		var c := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		c.shape = shape
		b.position = pos
		parent.add_child(b)
		b.add_child(c)
	return n

func _batch_box(pos: Vector3, size: Vector3, key: String, basis: Basis = Basis.IDENTITY) -> void:
	if not _batch_boxes.has(key): _batch_boxes[key] = []
	_batch_boxes[key].append(Transform3D(basis*Basis.from_scale(size),pos))

func _batch_cylinder(pos: Vector3, radius: float, height: float, key: String, basis: Basis = Basis.IDENTITY) -> void:
	if not _batch_cylinders.has(key): _batch_cylinders[key] = []
	_batch_cylinders[key].append(Transform3D(basis*Basis.from_scale(Vector3(radius,height,radius)),pos))

func _flush_batches() -> void:
	for source in [_batch_boxes,_batch_cylinders,_batch_foliage]:
		for key in source:
			# Spatially partitioned MultiMeshes preserve culling; geometry near one quay never forces the entire city to render.
			var cells: Dictionary = {}
			for t in source[key]:
				var cell := Vector2i(floori(t.origin.x/160.0),floori(t.origin.z/160.0))
				if not cells.has(cell): cells[cell] = []
				cells[cell].append(t)
			for cell in cells:
				var multi := MultiMesh.new()
				multi.transform_format = MultiMesh.TRANSFORM_3D
				if source == _batch_boxes:
					var box := BoxMesh.new()
					box.size = Vector3.ONE
					multi.mesh = box
				elif source == _batch_cylinders:
					var cyl := CylinderMesh.new()
					cyl.top_radius = 1.0
					cyl.bottom_radius = 1.0
					cyl.height = 1.0
					cyl.radial_segments = 8
					multi.mesh = cyl
				else:
					var sphere := SphereMesh.new()
					sphere.radius = 1.0
					sphere.height = 2.0
					sphere.radial_segments = 12
					sphere.rings = 6
					multi.mesh = sphere
				multi.instance_count = cells[cell].size()
				for i in range(multi.instance_count): multi.set_instance_transform(i,cells[cell][i])
				var inst := MultiMeshInstance3D.new()
				inst.multimesh = multi
				inst.material_override = materials[key]
				inst.visibility_range_end = 2600.0 if source==_batch_foliage else 1200.0
				inst.visibility_range_end_margin = 120.0
				add_child(inst)
	_batch_boxes.clear()
	_batch_cylinders.clear()
	_batch_foliage.clear()

func _beam(a: Vector3, b: Vector3, width: float, key: String, depth: float = -1.0) -> void:
	var delta := b-a
	var basis := Basis.looking_at(delta.normalized(),Vector3.UP if absf(delta.normalized().y)<0.98 else Vector3.RIGHT)
	_batch_box((a+b)*0.5,Vector3(width,width if depth<0 else depth,delta.length()),key,basis)

func _build_structure_batches() -> void:
	for id in structures:
		var p: Vector3 = structures[id]["position"]
		var cell := Vector2i(floori(p.x/160.0),floori(p.z/160.0))
		structures[id]["cell"] = cell
		if not _visual_cells.has(cell):
			var instance := MeshInstance3D.new()
			instance.name = "Architecture_%s_%s"%[cell.x,cell.y]
			add_child(instance)
			_visual_cells[cell] = {"ids":[],"instance":instance}
		_visual_cells[cell]["ids"].append(id)
		for child in structures[id]["node"].get_children():
			if child is MeshInstance3D: child.visible = false
	for cell in _visual_cells: _rebuild_visual_cell(cell)

func _rebuild_visual_cell(cell: Vector2i) -> void:
	var groups: Dictionary = {}
	var data: Dictionary = _visual_cells[cell]
	for id in data["ids"]:
		if destroyed.has(id): continue
		var node: Node3D = structures[id]["node"]
		for child in node.get_children():
			if not child is MeshInstance3D: continue
			var material: Material = child.material_override
			var key: int = material.get_instance_id()
			if not groups.has(key):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				surface.set_material(material)
				groups[key] = surface
			for surface_index in range(child.mesh.get_surface_count()):
				groups[key].append_from(child.mesh,surface_index,node.transform*child.transform)
	var mesh := ArrayMesh.new()
	for key in groups: groups[key].commit(mesh)
	data["instance"].mesh = mesh if groups.size()>0 else null

func _mark_visual_dirty(id: String) -> void:
	if not structures[id].has("cell"): return
	_dirty_cells[structures[id]["cell"]] = true
	if not _visual_refresh_queued:
		_visual_refresh_queued = true
		call_deferred("_refresh_damage_visuals")

func _refresh_damage_visuals() -> void:
	for cell in _dirty_cells: _rebuild_visual_cell(cell)
	_dirty_cells.clear()
	_visual_refresh_queued = false

func _structure_box(id: String, pos: Vector3, size: Vector3, key: String, strength: float = 95000.0, basis: Basis = Basis.IDENTITY) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = id.replace("/","_")
	body.transform = Transform3D(basis,pos)
	body.add_to_group("world_structure")
	body.set_meta("damage_id",id)
	add_child(body)
	_box(body,Vector3.ZERO,size,key)
	var c := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	c.shape = sh
	body.add_child(c)
	structures[id] = {"node":body,"position":pos,"half":size*0.5,"basis":basis,"strength":strength,"color":key}
	return body

func _extra_box_collision(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = pos
	body.add_child(collision)

func _structure_mesh(id: String, mesh: ArrayMesh, pos: Vector3, key: String, strength: float = 180000.0, basis: Basis = Basis.IDENTITY) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = id.replace("/","_")
	body.transform = Transform3D(basis,pos)
	body.add_to_group("world_structure")
	body.set_meta("damage_id",id)
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = materials[key]
	body.add_child(mi)
	var c := CollisionShape3D.new()
	c.shape = mesh.create_trimesh_shape()
	body.add_child(c)
	var bounds := mesh.get_aabb()
	structures[id] = {"node":body,"position":pos+basis*bounds.get_center(),"half":bounds.size*0.5,"basis":basis,"strength":strength,"color":key}
	return body

func _array_mesh(vertices: PackedVector3Array, indices: PackedInt32Array, uv: PackedVector2Array = PackedVector2Array()) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(vertices.size()):
		st.set_uv(uv[i] if uv.size()==vertices.size() else Vector2(vertices[i].x,vertices[i].z)*0.05)
		st.add_vertex(vertices[i])
	for idx in indices: st.add_index(idx)
	st.generate_normals()
	return st.commit()

func _land_mesh(poly: PackedVector2Array) -> ArrayMesh:
	var tri := Geometry2D.triangulate_polygon(poly)
	var vertices := PackedVector3Array()
	for p in poly: vertices.append(Vector3(p.x,GROUND,p.y))
	# Godot uses clockwise front faces: Geometry2D's counterclockwise XY indices already face upward in XZ.
	return _array_mesh(vertices,tri)

func _build_land() -> void:
	var seawalls := StaticBody3D.new()
	seawalls.name = "ContinuousCoastalRetainingWalls"
	add_child(seawalls)
	for p in geography["south_coast"]: south_polygon.append(Vector2(p[0],p[1]))
	south_polygon.append_array(PackedVector2Array([Vector2(2100,1350),Vector2(-1000,1350),Vector2(-1000,650)]))
	for p in geography["north_coast"]: north_polygon.append(Vector2(p[0],p[1]))
	north_polygon.append_array(PackedVector2Array([Vector2(2200,-2800),Vector2(-1250,-2800),Vector2(-1250,-1710)]))
	for poly in [south_polygon,north_polygon]:
		var mesh := _land_mesh(poly)
		var n := MeshInstance3D.new()
		n.mesh = mesh
		n.material_override = materials["north_landcover"] if poly==north_polygon else materials["paving"]
		add_child(n)
		var body := StaticBody3D.new()
		var c := CollisionShape3D.new()
		c.shape = mesh.create_trimesh_shape()
		body.add_child(c)
		add_child(body)
	for shore in [geography["south_coast"],geography["north_coast"]]:
		for i in range(shore.size()-1):
			var a := Vector3(shore[i][0],1.15,shore[i][1])
			var b := Vector3(shore[i+1][0],1.15,shore[i+1][1])
			var delta := b-a
			if delta.length()>180: continue
			var basis := Basis.looking_at(delta.normalized(),Vector3.UP)
			_batch_box((a+b)*0.5,Vector3(1.5,6.7,delta.length()+0.1),"sandstone",basis)
			var shape := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(1.5,6.7,delta.length()+0.1)
			shape.shape = box_shape
			shape.transform = Transform3D(basis,(a+b)*0.5)
			seawalls.add_child(shape)
			_batch_box((a+b)*0.5+Vector3(0,3.28,0),Vector3(2.8,0.35,delta.length()+0.1),"lightstone",basis)
			for j in range(0,int(delta.length()),5):
				var p := a.lerp(b,float(j)/maxf(delta.length(),1.0))
				_batch_box(p+Vector3(0,1,0),Vector3(1.7,0.12,0.12),"concrete",basis)
	# Deep seabed bounds swimming and supports settled debris without a false blue-ground collision surface.
	_box(self,Vector3(0,-36,0),Vector3(40000,4,40000),"sandstone",true)

func _build_water() -> void:
	var water_mat := ShaderMaterial.new()
	water_mat.shader = WATER
	for x in range(-3,4):
		for z in range(-4,3):
			var plane := PlaneMesh.new()
			plane.size = Vector2(1200,1200)
			plane.subdivide_width = 80
			plane.subdivide_depth = 80
			var n := MeshInstance3D.new()
			n.name = "NavigableWater_%s_%s" % [x,z]
			n.mesh = plane
			n.material_override = water_mat
			n.position = Vector3(x*1200,0,z*1200)
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(n)
	# Lower-density geometric outer water supports the airport flight corridor without duplicating the detailed tile area.
	for region in [[Vector3(0,0,-12700),Vector2(40000,14600)], [Vector3(0,0,11500),Vector2(40000,17000)], [Vector3(-12100,0,-1200),Vector2(15800,8400)], [Vector3(12100,0,-1200),Vector2(15800,8400)]]:
		var plane := PlaneMesh.new()
		plane.size = region[1]
		plane.subdivide_width = 72
		plane.subdivide_depth = 72
		var water := MeshInstance3D.new()
		water.mesh = plane
		water.material_override = water_mat
		water.position = region[0]
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(water)

func _road(a: Vector3, b: Vector3, width: float = 13.0, stripes: bool = true, record: bool = true, clip_visual: bool = true) -> void:
	var d := b-a
	if d.length()<0.1: return
	# Keep the exact original gameplay/layout centerline while clipping only flat painted surfaces to real land.
	if record: road_segments.append([Vector2(a.x,a.z),Vector2(b.x,b.z),width])
	if clip_visual and absf(a.y-GROUND)<0.22 and absf(b.y-GROUND)<0.22:
		var line := PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z)])
		for polygon in [south_polygon,north_polygon]:
			for part in Geometry2D.intersect_polyline_with_polygon(line,polygon):
				for i in range(part.size()-1):
					var ta := line[0].distance_to(part[i])/maxf(line[0].distance_to(line[1]),0.01)
					var tb := line[0].distance_to(part[i+1])/maxf(line[0].distance_to(line[1]),0.01)
					_road(Vector3(part[i].x,lerpf(a.y,b.y,ta),part[i].y),Vector3(part[i+1].x,lerpf(a.y,b.y,tb),part[i+1].y),width,stripes,false,false)
		return
	var basis := Basis.looking_at(d.normalized(),Vector3.UP)
	_batch_box((a+b)*0.5,Vector3(width,0.065,d.length()+0.25),"road",basis)
	for side in [-1,1]:
		_batch_box((a+b)*0.5+basis.x*(width*0.5+0.8)*side+Vector3(0,0.1,0),Vector3(1.6,0.16,d.length()+0.25),"lightstone",basis)
	if stripes:
		for n in range(0,int(d.length()),11):
			_batch_box(a+d.normalized()*(n+2.0)+Vector3(0,0.043,0),Vector3(0.13,0.02,4.0),"white",basis)

func _build_streets() -> void:
	for way in geography["roads"]:
		var points: Array = way["points"]
		for i in range(points.size()-1):
			var a := Vector3(points[i][0],GROUND+0.055,points[i][1])
			var b := Vector3(points[i+1][0],GROUND+0.055,points[i+1][1])
			if a.z < -1760 or a.z>740: continue
			_road(a,b,12.0 if way["name"]!="Hickson Road" else 15.0)
	# Additional connected service streets are intentionally fictional infill, not claimed as surveyed roads.
	for z in [-170,-30,155,310,470,620]:
		_road(Vector3(-800,4.57,z),Vector3(-70 if z<100 else 225,4.57,z),12.0)
	for x in [-800,-630,-465]:
		_road(Vector3(x,4.57,-270),Vector3(x,4.57,690),13.0)
	_road(Vector3(-210,4.57,155),Vector3(230,4.57,205),17)
	_road(Vector3(235,4.57,175),Vector3(292,4.57,-120),12)
	_road(Vector3(-545,4.57,-270),Vector3(-545,4.57,-350),12)
	for z in [-1250,-1400,-1580,-1730]:
		_road(Vector3(25 if z<-1400 else 225,4.57,z),Vector3(685,4.57,z),12)
	for x in [370,530,685]:
		_road(Vector3(x,4.57,-1190),Vector3(x,4.57,-1740),13)
	# Paving accents, lighting and actual street furniture along the primary promenade.
	for z in range(-530,120,35):
		var x: float = -31.0 if z>-300 else -30.0+(z+300)*0.07
		_lamp(Vector3(x-10,GROUND,z))
		if z%70==0: _bench(Vector3(x-17,GROUND,z),-PI*0.5)
	for x in range(-165,220,32):
		_lamp(Vector3(x,GROUND,150))
		if x%2==1: _tree(Vector3(x,GROUND,225),0.7)
	for pos in [Vector3(-210,6.4,-172),Vector3(120,6.4,174),Vector3(310,6.4,-1220),Vector3(-580,6.4,-312)]:
		_sign(pos,"HARBOURLIFE",0.0,Color("d8c69d"))

func _bridge_pos(t: float, y: float = 54.0, across: float = 0.0) -> Vector3:
	var dir := Vector3(232,0,-447).normalized()
	return Vector3(-83,y,-662)+dir*t+Vector3(-dir.z,0,dir.x)*across

func _build_bridge() -> void:
	var dir := Vector3(232,0,-447).normalized()
	var right := Vector3(-dir.z,0,dir.x)
	var basis := Basis(right,Vector3.UP,-dir)
	var length := 503.0
	# 42 independent deck segments keep damage localized and expose a real hole in the crossing.
	for j in range(42):
		var t := (j+0.5)*length/42.0
		var p := _bridge_pos(t,51.5)
		var deck := _structure_box("bridge/deck/%02d"%j,p,Vector3(49,5,length/42.0+0.04),"concrete",2800000,basis)
		_box(deck,Vector3(0,2.54,0),Vector3(38,0.10,length/42.0),"road")
		for side in [-1,1]:
			_box(deck,Vector3(side*22,2.74,0),Vector3(4.2,0.42,length/42.0),"paving")
			_box(deck,Vector3(side*24.2,5.0,0),Vector3(0.22,0.15,length/42.0),"steel")
			for wire in range(6):
				_box(deck,Vector3(side*24.2,2.85+wire*0.4,0),Vector3(0.045,0.04,length/42.0),"steel")
			_extra_box_collision(deck,Vector3(side*24.2,3.8,0),Vector3(0.25,2.4,length/42.0))
			_box(deck,Vector3(side*19.3,3.3,0),Vector3(0.3,1.3,length/42.0),"steel")
			_extra_box_collision(deck,Vector3(side*19.3,3.3,0),Vector3(0.3,1.3,length/42.0))
		for lane in [-14,-7,0,7,14]:
			_box(deck,Vector3(lane,2.61,0),Vector3(0.13,0.025,4.0),"white")
		for side in [-1,1]:
			for railing in [-4.0,0.0,4.0]:
				_box(deck,Vector3(side*24.1,4.2,railing),Vector3(0.12,3,0.12),"darksteel")
	# Two complete polygonal arch trusses, 28 panels each, braced laterally.
	for j in range(28):
		var a := float(j)/28.0
		var b := float(j+1)/28.0
		var lower_a := 18.0 + 101.0*pow(sin(a*PI),0.79)
		var lower_b := 18.0 + 101.0*pow(sin(b*PI),0.79)
		var upper_a := 33.0 + 101.0*pow(sin(a*PI),0.79)
		var upper_b := 33.0 + 101.0*pow(sin(b*PI),0.79)
		for side in [-1,1]:
			var ax: float = side*19.5
			var p1 := _bridge_pos(a*length,lower_a,ax)
			var p2 := _bridge_pos(b*length,lower_b,ax)
			var p3 := _bridge_pos(a*length,upper_a,ax)
			var p4 := _bridge_pos(b*length,upper_b,ax)
			_destruct_beam("bridge/arch/%s/%s/lower"%[side,j],p1,p2,2.4,1200000)
			_destruct_beam("bridge/arch/%s/%s/upper"%[side,j],p3,p4,2.2,1200000)
			_destruct_beam("bridge/arch/%s/%s/diag"%[side,j],p1,p4,1.2,650000)
			_destruct_beam("bridge/arch/%s/%s/upright"%[side,j],p2,p4,1.25,650000)
			if lower_b>56.0:
				_destruct_beam("bridge/hanger/%s/%s"%[side,j],_bridge_pos(b*length,54,ax),p2,0.75,420000)
		_beam(_bridge_pos(a*length,upper_a,-19.5),_bridge_pos(b*length,upper_b,19.5),0.85,"steel")
		_beam(_bridge_pos(a*length,upper_a,19.5),_bridge_pos(b*length,upper_b,-19.5),0.85,"steel")
	# Massive detailed sandstone/granite towers on each end of the arch.
	for end in [0.0,length]:
		for side in [-1,1]:
			var p := _bridge_pos(end,0,side*31.5)
			for tier in range(4):
				var size := Vector3(19-tier*1.8,20,27-tier*1.6)
				var tower := _structure_box("bridge/pylon/%s/%s/%s"%[int(end),side,tier],p+Vector3(0,14+tier*20,0),size,"sandstone",3600000,basis)
				_box(tower,Vector3(0,9.3,0),Vector3(size.x+1.0,1.2,size.z+1.0),"lightstone")
				for f in [-1,1]:
					for slit in [-4.2,0.0,4.2]:
						_box(tower,Vector3(slit,1,f*(size.z*0.5+0.02)),Vector3(1.2,7,0.1),"darksteel")
				for cornice in [-1,1]:
					_box(tower,Vector3(cornice*(size.x*0.5+0.15),0,0),Vector3(0.3,20,size.z),"lightstone")
	# Continuous gently graded road + walkway approaches, independently colliding.
	_bridge_ramp(Vector3(-325,GROUND,-194),_bridge_pos(0,54),"south")
	_bridge_ramp(_bridge_pos(length,54),Vector3(340,GROUND,-1510),"north")
	_road(Vector3(-325,4.59,-194),Vector3(-310,4.59,-170),28)
	_road(Vector3(340,4.59,-1510),Vector3(370,4.59,-1580),28)
	for t in range(30,490,45):
		_lamp(_bridge_pos(t,54,21.5))
	# Ladder-like public maintenance steps and lookout access remain physically explorable.
	for side in [-1,1]:
		var start := _bridge_pos(4,55,side*22.0)
		for step in range(28):
			_box(self,start+dir*(step*1.0)+Vector3(0,step*0.55,0),Vector3(2.7,0.55,1.1),"steel",true)
	_sign(_bridge_pos(245,58,21),"HARBOUR CROSSING",atan2(right.z,right.x),Color("f2e3bc"))

func _destruct_beam(id: String, a: Vector3, b: Vector3, width: float, strength: float) -> void:
	var d := b-a
	var basis := Basis.looking_at(d.normalized(),Vector3.UP if absf(d.normalized().y)<0.98 else Vector3.RIGHT)
	_structure_box(id,(a+b)*0.5,Vector3(width,width,d.length()+0.12),"steel",strength,basis)

func _bridge_ramp(a: Vector3, b: Vector3, id: String) -> void:
	var d := b-a
	var length := d.length()
	var dir := d.normalized()
	var basis := Basis.looking_at(dir,Vector3.UP)
	for i in range(28):
		var p := a.lerp(b,(i+0.5)/28.0)
		var deck := _structure_box("bridge/ramp/%s/%s"%[id,i],p-Vector3(0,1.0,0),Vector3(35,2,length/28.0+0.2),"concrete",2100000,basis)
		_box(deck,Vector3(0,1.055,0),Vector3(27,0.10,length/28.0+0.2),"road")
		for side in [-1,1]:
			_box(deck,Vector3(side*15.5,1.23,0),Vector3(3.2,0.4,length/28.0+0.2),"paving")
			_box(deck,Vector3(side*17.2,1.8,0),Vector3(0.3,1.4,length/28.0+0.2),"steel")
			_extra_box_collision(deck,Vector3(side*17.2,1.8,0),Vector3(0.3,1.4,length/28.0+0.2))
		for lane in [-9,-3,3,9]:
			_box(deck,Vector3(lane,1.125,0),Vector3(0.13,0.025,5.2),"white")
		if i%5==3 and p.y>12:
			for side in [-1,1]:
				_structure_box("bridge/support/%s/%s/%s"%[id,i,side],p+basis.x*side*12-Vector3(0,(p.y-GROUND)*0.5+1,0),Vector3(4,p.y-GROUND-1,5),"sandstone",3200000)

func _build_opera() -> void:
	var center := Vector3(421,GROUND,-326)
	var angle := deg_to_rad(-12.0)
	var basis := Basis(Vector3.UP,angle)
	# A broad layered podium, northern terrace, stepped southern concourse.
	for tier in range(4):
		var size := Vector3(112-tier*2,2.8,166-tier*2)
		_structure_box("opera/podium/%s"%tier,center+Vector3(0,tier*2.8+1.4,0),size,"sandstone",1800000,basis)
	for step in range(18):
		var local := Vector3(0,0.30+step*0.60,103-step*1.12)
		var p := center+basis*local
		_structure_box("opera/steps/%s"%step,p,Vector3(78,0.6,1.25),"lightstone",260000,basis)
	# Two unequal parallel halls. Each sail is a curved original ribbed shell, not a triangular billboard.
	var shells := [
		[-26.0,-51.0,23.0,50.0,45.0],[-26.0,-14.0,24.0,52.0,41.0],[-26.0,23.0,20.0,43.0,32.0],
		[23.0,-41.0,19.0,47.0,35.0],[23.0,-8.0,19.0,45.0,30.0],[23.0,25.0,16.0,36.0,24.0],
		[24.0,63.0,12.0,23.0,14.0]
	]
	for idx in range(shells.size()):
		var s: Array = shells[idx]
		var origin := center+basis*Vector3(s[0],11.2,s[1])
		var width: float = s[2]
		var depth: float = s[3]
		var height: float = s[4]
		# Shell is divided into eight removable curved roof bands. Normal ribs and thin tile seams follow the curvature.
		for panel in range(8):
			var mesh := _sail_mesh(width,depth,height,float(panel)/8.0,float(panel+1)/8.0)
			_structure_mesh("opera/shell/%s/%s"%[idx,panel],mesh,origin,"white",180000,basis)
		for rib in range(0,17):
			var u := float(rib)/16.0
			for k in range(18):
				var p1 := _sail_point(u,float(k)/18.0,width,depth,height)
				var p2 := _sail_point(u,float(k+1)/18.0,width,depth,height)
				# Ribs are children of their matching shell chunk so damage removes them, too.
				var panel := mini(int(u*8.0),7)
				var body: StaticBody3D = structures["opera/shell/%s/%s"%[idx,panel]]["node"]
				_local_beam(body,p1+Vector3(0,0.07,0),p2+Vector3(0,0.07,0),0.13,"lightstone")
		var glass := _opera_glass_mesh(width,height)
		_structure_mesh("opera/glass/%s"%idx,glass,origin+basis*Vector3(0,0,-depth*0.52),"glass",105000,basis)
		for fin in range(-4,5):
			var x := fin*width/4.5
			var ht := height*(1.0-pow(absf(x)/width,1.8))*0.78
			if ht>0:
				_local_beam(structures["opera/glass/%s"%idx]["node"],Vector3(x,0,0),Vector3(x,ht,0),0.3,"darksteel")
	# Broadwalk planters, polished bronze edge, external podium terraces.
	for z in range(-425,-185,22):
		if z<-385: continue
		_lamp(Vector3(485,GROUND,z))
	for x in [357,377,397,437,457,477]:
		_bench(Vector3(x,GROUND,-171),PI)
	_sign(Vector3(415,6.6,-151),"BENNELONG POINT",0.0,Color("3b4c4e"))
	# Accessible seaward viewing gallery tucked beneath the podium's eastern side.
	_box(self,Vector3(475,5.0,-312),Vector3(20,0.8,80),"paving",true)
	for z in range(-348,-270,8):
		_batch_box(Vector3(480,7.2,z),Vector3(0.45,4.4,0.45),"sandstone")
		_batch_box(Vector3(480,9.5,z),Vector3(10,0.4,7.8),"concrete")

func _sail_point(u: float, v: float, width: float, depth: float, height: float) -> Vector3:
	var lateral := (u*2.0-1.0)
	var taper := 0.38 + 0.62*sin(v*PI*0.5)
	var x := lateral*width*taper
	var y := height*pow(maxf(0.0,1.0-lateral*lateral),0.72)*pow(1.0-v,0.55)
	var z := (v-0.52)*depth
	return Vector3(x,y,z)

func _sail_mesh(width: float, depth: float, height: float, from: float, to: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for x in range(5):
		for z in range(21):
			var u := lerpf(from,to,float(x)/4.0)
			var v := float(z)/20.0
			verts.append(_sail_point(u,v,width,depth,height))
			uv.append(Vector2(u*width*0.4,v*depth*0.2))
	for x in range(4):
		for z in range(20):
			var i := x*21+z
			indices.append_array(PackedInt32Array([i,i+21,i+1,i+1,i+21,i+22]))
	var mesh := _array_mesh(verts,indices,uv)
	return mesh

func _opera_glass_mesh(width: float, height: float) -> ArrayMesh:
	var verts := PackedVector3Array([Vector3.ZERO])
	for i in range(25):
		var x := -width*0.38+width*0.76*i/24.0
		verts.append(Vector3(x,height*pow(maxf(0.0,1.0-pow(x/(width*0.38),2.0)),0.72),0))
	var ix := PackedInt32Array()
	for i in range(1,25): ix.append_array(PackedInt32Array([0,i+1,i]))
	return _array_mesh(verts,ix)

func _local_beam(parent: Node3D, a: Vector3, b: Vector3, width: float, key: String) -> void:
	var d := b-a
	var mesh := _box(parent,(a+b)*0.5,Vector3(width,width,d.length()),key)
	mesh.basis = Basis.looking_at(d.normalized(),Vector3.UP if absf(d.normalized().y)<0.98 else Vector3.RIGHT)

func _build_quay() -> void:
	# Five narrow ferry fingers reach north into Sydney Cove. Covered boarding areas stay on one continuous map.
	for i in range(5):
		var x := -47.0+i*43.0
		var z := 64.0+i*0.5
		_structure_box("quay/pier/%s"%i,Vector3(x,2.5,z),Vector3(13,1.2,102),"wood",1600000)
		# Sloped pedestrian gangway from 4.5m quay to 3.1m pontoon.
		_ramp_box(Vector3(x,GROUND,132),Vector3(x,3.1,113),11,"wood")
		for section in range(4):
			var canopy := _structure_box("quay/canopy/%s/%s"%[i,section],Vector3(x,6.8,z-29+section*21),Vector3(10.7,0.35,20.7),"copper",95000)
			for side in [-1,1]:
				_box(canopy,Vector3(side*4.7,-1.85,0),Vector3(0.22,3.7,0.22),"white")
				_box(canopy,Vector3(side*6.0,-2.5,0),Vector3(0.15,1.0,20),"steel")
		for z2 in range(18,110,18):
			_batch_cylinder(Vector3(x-5.8,1,z2),0.33,8,"darksteel")
			_batch_cylinder(Vector3(x+5.8,1,z2),0.33,8,"darksteel")
		_sign(Vector3(x,7.8,116),"0%s"%(i+1),0,Color("254b55"))
	# Circular Quay station / service hall: formal roof, platforms, masonry and glazed entrances.
	_building("quay/transit_hall",Vector3(15,GROUND,202),128,29,13,2)
	for x in range(-40,78,12):
		_batch_box(Vector3(x,5.8,184),Vector3(8,0.16,3.2),"copper")
	# Open moorings at Walsh Bay, including a garage sized slip and low pontoons.
	for x in [-660,-605,-545,-485]:
		_structure_box("marina/pontoon/%s"%x,Vector3(x,2.1,-415),Vector3(7,0.9,114),"wood",600000)
		_ramp_box(Vector3(x,4.5,-345),Vector3(x,2.55,-362),6.5,"wood")
		for z in [-372,-401,-430,-459]:
			_batch_box(Vector3(x+8.3,2.1,z),Vector3(17,0.85,3.3),"wood")
			_batch_cylinder(Vector3(x-3,2,z),0.28,5,"darksteel")
			_batch_cylinder(Vector3(x+15,2,z),0.28,5,"darksteel")
	_building("marina/boathouse",Vector3(-591,GROUND,-308),52,22,13,0)
	_sign(Vector3(-545,7,-349),"WALSH BAY / MARINE WORKS",0,Color("f1ddaf"))

func _ramp_box(a: Vector3, b: Vector3, width: float, key: String) -> void:
	var d := b-a
	var body := _box(self,(a+b)*0.5-Vector3(0,0.15,0),Vector3(width,0.3,d.length()+0.2),key,true)
	body.basis = Basis.looking_at(d.normalized(),Vector3.UP)
	# _box collision is a sibling; rotate that sibling, too.
	var siblings := get_children()
	var index := body.get_index()+1
	if index<siblings.size() and siblings[index] is StaticBody3D: siblings[index].basis = body.basis

func _facade_material(style: int, width: float, height: float) -> ShaderMaterial:
	var cache_key := "%s/%s/%s"%[style,maxi(1,roundi(width/3.4)),maxi(1,roundi(height/3.7))]
	if _material_cache.has(cache_key): return _material_cache[cache_key]
	var m := ShaderMaterial.new()
	m.shader = FACADE
	var colors := [Color("b5906c"),Color("c5b9a4"),Color("a9b1ad"),Color("7b999d"),Color("926b56"),Color("d6c6a8")]
	m.set_shader_parameter("masonry",colors[posmod(style,colors.size())])
	m.set_shader_parameter("modules",Vector2(maxf(1,roundf(width/3.4)),maxf(1,roundf(height/3.7))))
	m.set_shader_parameter("heritage",1.0 if style%3!=0 else 0.0)
	m.set_shader_parameter("window_color",Color("24434b") if style%2==0 else Color("3f4e4e"))
	_material_cache[cache_key] = m
	return m

func _wall_panel(id: String, pos: Vector3, width: float, height: float, style: int, basis: Basis) -> StaticBody3D:
	var body := _structure_box(id,pos,Vector3(width,height,0.65),"sandstone",maxf(45000,width*height*1900.0),basis)
	var mesh: MeshInstance3D = body.get_child(0)
	mesh.material_override = _facade_material(style,width,height)
	# Real protruding cornices, recessed window frames and balcony ledges catch normal gameplay light.
	for level in range(maxi(1,int(height/3.7))):
		var y := -height*0.5+0.25+level*3.7
		_box(body,Vector3(0,y,0.10),Vector3(width+0.16,0.24,1.05),"lightstone")
	if style%3!=0:
		for i in range(maxi(1,int(width/3.4))+1):
			var xx := -width*0.5+float(i)*width/maxi(1,int(width/3.4))
			_box(body,Vector3(xx,0,0.33),Vector3(0.22,height,0.15),"lightstone")
	return body

func _building(id: String, p: Vector3, width: float, depth: float, height: float, style: int) -> void:
	_building_count += 1
	_building_plots.append(AABB(Vector3(p.x-width*0.5,GROUND,p.z-depth*0.5),Vector3(width,maxf(1,height),depth)))
	var stories := maxi(1,int(ceil(height/11.4)))
	var h := height/stories
	# Hollow construction with independently breakable facade bays and floor/roof slabs.
	for level in range(stories):
		var y := p.y+level*h
		var nx := maxi(1,int(ceil(width/13)))
		var nz := maxi(1,int(ceil(depth/13)))
		for side in [-1,1]:
			for i in range(nx):
				var center := p+Vector3(-width*0.5+(i+0.5)*width/nx,level*h+h*0.5,side*depth*0.5)
				_wall_panel("%s/wall/z/%s/%s/%s"%[id,level,side,i],center,width/nx,h,style,Basis(Vector3.UP,PI if side<0 else 0.0))
			for i in range(nz):
				var center := p+Vector3(side*width*0.5,level*h+h*0.5,-depth*0.5+(i+0.5)*depth/nz)
				_wall_panel("%s/wall/x/%s/%s/%s"%[id,level,side,i],center,depth/nz,h,style,Basis(Vector3.UP,PI*0.5*side))
		if level>0:
			for sx in range(2):
				for sz in range(2):
					_structure_box("%s/slab/%s/%s/%s"%[id,level,sx,sz],Vector3(p.x+(sx-0.5)*width*0.5,y,p.z+(sz-0.5)*depth*0.5),Vector3(width*0.5,0.4,depth*0.5),"concrete",height*14000)
	for sx in range(2):
		for sz in range(2):
			var roof := _structure_box("%s/roof/%s/%s"%[id,sx,sz],p+Vector3((sx-0.5)*width*0.5,height+0.25,(sz-0.5)*depth*0.5),Vector3(width*0.5+0.22,0.5,depth*0.5+0.22),"slate",220000)
			if sx==0 and sz==0:
				_box(roof,Vector3(0,0.8,0),Vector3(3,1.1,2.3),"concrete")
				for vent in range(4):
					_box(roof,Vector3(-1.1+vent*0.7,1.36,0),Vector3(0.2,0.05,1.8),"darksteel")
	if style%3!=0 and height<26:
		# Pitched roof using four distinct roof faces, ridge and real thickness collision.
		var verts := PackedVector3Array([Vector3(-width*.52,0,-depth*.52),Vector3(width*.52,0,-depth*.52),Vector3(width*.52,0,depth*.52),Vector3(-width*.52,0,depth*.52),Vector3(-width*.38,3.4,0),Vector3(width*.38,3.4,0)])
		for roof_side in range(4):
			var ixs := [PackedInt32Array([0,5,4,0,1,5]),PackedInt32Array([3,5,2,3,4,5]),PackedInt32Array([0,4,3]),PackedInt32Array([1,2,5])]
			_structure_mesh("%s/pitch/%s"%[id,roof_side],_array_mesh(verts,ixs[roof_side]),p+Vector3(0,height+0.5,0),"roof",190000)
		_structure_box("%s/chimney"%id,p+Vector3(width*0.22,height+3.2,depth*0.17),Vector3(1.8,5,1.4),"sandstone",55000)
	# Street awnings and pilasters are attached to a facade chunk, so no orphan decorations survive damage.
	var front_id := "%s/wall/z/0/1/0"%id
	if structures.has(front_id):
		var front: Node3D = structures[front_id]["node"]
		_box(front,Vector3(0,-h*0.5+3.0,1.2),Vector3(width/ceil(width/13.0),0.2,2.8),"teal" if style%2==0 else "cloth")
		if height<30:
			var names := ["TIDELINE GOODS","QUAY COFFEE","HARBOUR BOOKS","THE BOAT SHOP","CORNER MARKET","SALT & STONE"]
			var shop := Label3D.new()
			shop.text = names[posmod(id.hash(),names.size())]
			shop.font_size = 36
			shop.pixel_size = 0.008
			shop.modulate = Color("f0dfb9")
			shop.outline_size = 0
			shop.position = Vector3(0,-h*0.5+3.28,1.5)
			shop.visibility_range_end = 90
			front.add_child(shop)

func _build_frontages() -> void:
	var index := 0
	for street_z in [-170,-30,155,310,470,620,-1250,-1400,-1580]:
		var north: bool = street_z< -1000
		for street_x in range(275 if north else -765,710 if north else 225,31):
			for side in [-1,1]:
				var p := Vector2(street_x,street_z+side*23.0)
				var poly := north_polygon if north else south_polygon
				var plot := AABB(Vector3(p.x-12,GROUND,p.y-13.5),Vector3(24,20,27))
				var blocked := false
				for corner in [Vector2(-14,-16),Vector2(-14,16),Vector2(14,-16),Vector2(14,16)]:
					if not Geometry2D.is_point_in_polygon(p+corner,poly): blocked = true
				if blocked or _near_road(p,9): continue
				for anchor in anchors.values():
					if p.distance_to(Vector2(anchor.x,anchor.z))<31: blocked = true
				if blocked: continue
				if p.distance_to(Vector2(-335,-28))<27 or p.distance_to(Vector2(-367,-30))<29: continue
				if p.distance_to(Vector2(-410,420))<65: continue
				if pow((p.x+715)/83.0,2)+pow((p.y-74)/122.0,2)<1.0: continue
				if _distance_segment(p,Vector2(-325,-194),Vector2(-83,-662))<43: continue
				if _distance_segment(p,Vector2(149,-1109),Vector2(340,-1510))<43: continue
				for existing in _building_plots:
					if plot.grow(2.0).intersects(existing):
						blocked = true
						break
				if blocked: continue
				_building("frontage/%s_%s_%s"%[street_x,street_z,side],Vector3(p.x,GROUND,p.y),24,27,11.4+(index%3)*3.8,index%6)
				if index%3==0:
					_tree(Vector3(p.x+14,GROUND,street_z+side*11),0.58)
					_lamp(Vector3(p.x-14,GROUND,street_z+side*10))
				if index%4==0: _bench(Vector3(p.x+9,GROUND,street_z+side*9.5),0 if side>0 else PI)
				index += 1

func _build_neighborhoods() -> void:
	var index := 0
	for z in range(-285,725,66):
		for x in range(-770,245,67):
			var p := Vector2(x+_rng.randf_range(-5,5),z+_rng.randf_range(-4,4))
			if not Geometry2D.is_point_in_polygon(p,south_polygon): continue
			if _near_road(p,25): continue
			if p.distance_to(Vector2(-335,-28))<53: continue
			if p.distance_to(Vector2(-410,420))<62: continue
			if pow((p.x+715)/83.0,2)+pow((p.y-74)/122.0,2)<1.0: continue
			if p.y<0 and p.x>-90: continue
			if p.y>155 and p.y<230 and p.x>-70: continue
			if _distance_segment(p,Vector2(-325,-194),Vector2(-83,-662))<40: continue
			var w := _rng.randf_range(23,39)
			var d := _rng.randf_range(25,43)
			var h := _rng.randf_range(11,23) if z<155 or x<-430 else _rng.randf_range(28,89)
			_building("south/building/%s_%s"%[x,z],Vector3(p.x,GROUND,p.y),w,d,h,index%6)
			index += 1
	# Deliberate skyline silhouettes: stepped towers, a cylindrical crown and a slender spire.
	_building("skyline/quay_tower",Vector3(190,GROUND,326),54,48,91,3)
	_building("skyline/quay_tower_upper",Vector3(190,95.5,326),39,34,36,3)
	_building("skyline/west_tower",Vector3(-81,GROUND,402),51,43,125,2)
	_building("skyline/merchant_house",Vector3(-349,GROUND,301),54,44,43,5)
	_building("skyline/east_spire",Vector3(64,GROUND,637),41,43,151,0)
	_destruct_beam("skyline/east_antenna",Vector3(64,155.5,637),Vector3(64,177,637),0.65,120000)
	for z in range(-205,605,66):
		_lamp(Vector3(-448,GROUND,z))
		if z>0: _tree(Vector3(-442,GROUND,z+16),0.6)
	for z in range(-220,590,80):
		_lamp(Vector3(-645,GROUND,z))
		_tree(Vector3(-652,GROUND,z+12),0.6)

func _build_north() -> void:
	var i := 0
	for z in range(-1690,-1150,69):
		for x in range(276,757,68):
			var p := Vector2(x,z)
			if not Geometry2D.is_point_in_polygon(p,north_polygon): continue
			if _near_road(p,25): continue
			if _distance_segment(p,Vector2(149,-1109),Vector2(340,-1510))<40: continue
			_building("north/terrace/%s_%s"%[x,z],Vector3(x,GROUND,z),_rng.randf_range(24,38),32,_rng.randf_range(12,29),i%6)
			i += 1
	for z in range(-1740,-1260,60):
		_tree(Vector3(389,GROUND,z),0.8)
		_lamp(Vector3(353,GROUND,z))
	_building("north/hotel",Vector3(254,GROUND,-1340),51,47,59,3)
	# Milsons Point waterfront park, wharf and an original leisure pavilion.
	for x in range(183,460,27):
		if Geometry2D.is_point_in_polygon(Vector2(x,-1150),north_polygon):
			_tree(Vector3(x,GROUND,-1150),0.72)
			_bench(Vector3(x,GROUND,-1138),0)
	_structure_box("north/wharf",Vector3(277,2.5,-1093),Vector3(16,1,55),"wood",550000)
	_ramp_box(Vector3(277,4.5,-1133),Vector3(277,3,-1118),14,"wood")
	_sign(Vector3(294,7,-1180),"MILSONS POINT",PI,Color("244a52"))
	# Waterfront pavilion frames and accessible skate-scale ramps.
	_building("north/pavilion",Vector3(395,GROUND,-1195),48,24,10,5)
	for pos in [Vector3(438,GROUND,-1235),Vector3(440,GROUND,-1280)]:
		_ramp_box(pos,pos+Vector3(12,3.5,0),9,"concrete")

func _build_home() -> void:
	var p := Vector3(-335,GROUND,-28)
	# Actual walk-in personal studio + workshop, 18 x 18 m, open 4 m front entrance.
	_structure_box("home/floor",p+Vector3(0,0.15,0),Vector3(18,0.3,18),"wood",1800000)
	_structure_box("home/back",p+Vector3(0,2.4,-9),Vector3(18,4.8,0.7),"sandstone",360000)
	for side in [-1,1]:
		var wall := _wall_panel("home/side/%s"%side,p+Vector3(side*9,2.4,0),18,4.8,5,Basis(Vector3.UP,side*PI*0.5))
		_wall_panel("home/front/%s"%side,p+Vector3(side*5.5,2.4,9),7,4.8,5,Basis.IDENTITY)
	_structure_box("home/lintel",p+Vector3(0,4.35,9),Vector3(4,0.9,0.7),"lightstone",180000)
	_structure_box("home/roof",p+Vector3(0,4.95,0),Vector3(19,0.4,19),"copper",260000)
	# Roof terrace access via a side stair, with a collision-smoothed ramp beneath treads.
	_ramp_box(p+Vector3(-12,0,9),p+Vector3(-12,5,-6),3.6,"sandstone")
	for i in range(20):
		_batch_box(p+Vector3(-12,0.125+i*0.25,8.6-i*0.75),Vector3(3.5,0.22,0.76),"lightstone")
	_box(self,p+Vector3(-10,4.95,-6),Vector3(5,0.4,4),"copper",true)
	# Furnished living/storage/work area. Collision leaves the doorway and circulation unobstructed.
	_box(self,p+Vector3(4.8,0.7,-5.5),Vector3(3.4,1,4.3),"wood",true)
	_box(self,p+Vector3(4.8,1.28,-5.5),Vector3(3.5,0.25,4.35),"cloth")
	_box(self,p+Vector3(4.8,1.5,-6.7),Vector3(2.6,0.2,1),"white")
	_box(self,p+Vector3(-5.9,1.1,-4),Vector3(4.6,0.18,2.0),"wood",true)
	for x in [-7.7,-4.1]:
		for z in [-4.6,-3.4]:
			_box(self,p+Vector3(x,0.6,z),Vector3(0.16,1.2,0.16),"darksteel")
	_box(self,p+Vector3(-5.6,1.62,-4.4),Vector3(1.3,0.8,0.14),"navy")
	_box(self,p+Vector3(-5.6,1.65,-4.3),Vector3(1.13,0.62,0.03),"teal")
	_box(self,p+Vector3(-5.6,1.23,-4.05),Vector3(1.4,0.04,0.5),"steel")
	for i in range(3):
		_box(self,p+Vector3(-7.5,0.8,1+i*2.1),Vector3(1.7,1.6,1.65),"wood",true)
		_box(self,p+Vector3(-7.5,1.1,1+i*2.1),Vector3(1.75,0.13,1.7),"steel")
	_box(self,p+Vector3(5.2,0.5,3.1),Vector3(4.4,0.8,1.5),"coral",true)
	_box(self,p+Vector3(5.2,1.1,3.65),Vector3(4.4,1.1,0.3),"coral")
	_box(self,p+Vector3(4.7,0.65,0.5),Vector3(2.8,0.12,1.3),"wood",true)
	for i in range(5):
		_box(self,p+Vector3(1+i*1.3,2.0,-8.7),Vector3(0.85,1.2,0.12),"teal" if i%2 else "cloth")
	_sign(p+Vector3(0,3.9,9.45),"THE QUAYSIDE STUDIO",0,Color("263e43"))
	_sign(p+Vector3(-7.1,2.5,0),"KEEP / REPAIR / EXPLORE",PI*0.5,Color("f6deb0"))
	var light := OmniLight3D.new()
	light.position = p+Vector3(0,3.9,0)
	light.omni_range = 15
	light.light_color = Color("ffd5a0")
	light.light_energy = 1.6
	light.shadow_enabled = false
	add_child(light)
	# Adjacent vehicle maintenance courtyard and open two-bay garage.
	_box(self,p+Vector3(-31,0.035,3),Vector3(28,0.06,25),"road")
	_structure_box("garage/back",p+Vector3(-31,2.8,-11),Vector3(26,5.6,0.7),"sandstone",400000)
	_structure_box("garage/roof",p+Vector3(-31,5.7,-4),Vector3(27,0.5,16),"slate",400000)
	for x in [-44,-31,-18]:
		_structure_box("garage/post/%s"%x,p+Vector3(x,2.8,3.5),Vector3(0.6,5.6,0.6),"steel",200000)
	_sign(p+Vector3(-31,4.3,4),"BAY 01     /     BAY 02",0,Color("edd8af"))

func _build_gardens() -> void:
	# Botanic / Farm Cove side: paths follow the real shoreline, planted in a curated grove pattern.
	var garden_boundary := PackedVector2Array([Vector2(342,-150),Vector2(1110,-150),Vector2(1110,740),Vector2(342,740)])
	for patch in Geometry2D.intersect_polygons(south_polygon,garden_boundary):
		var lawn := MeshInstance3D.new()
		lawn.mesh = _land_mesh(patch)
		lawn.position.y = 0.045
		lawn.material_override = materials["grass"]
		add_child(lawn)
	for z in range(-125,651,40):
		for x in range(363,1020,45):
			var pos := Vector2(x+_rng.randf_range(-13,13),z+_rng.randf_range(-12,12))
			if not Geometry2D.is_point_in_polygon(pos,south_polygon): continue
			if _near_road(pos,16): continue
			if pos.distance_to(Vector2(421,-326))<175: continue
			_tree(Vector3(pos.x,GROUND,pos.y),_rng.randf_range(0.7,1.25))
	for z in range(0,551,66):
		_road(Vector3(425,4.58,z),Vector3(665,4.58,z+35),3.2,false,false)
		_bench(Vector3(445,GROUND,z-6),0)
		_lamp(Vector3(430,GROUND,z-8))
	# Sparse distant ridgelines are fully modelled geometry and explicitly outside detailed core coverage.
	for i in range(80):
		var x := _rng.randf_range(-950,1950)
		var z := _rng.randf_range(-2630,-1800)
		if not Geometry2D.is_point_in_polygon(Vector2(x,z),north_polygon): continue
		var h := _rng.randf_range(10,55)
		var b := _box(self,Vector3(x,GROUND+h*0.5,z),Vector3(_rng.randf_range(25,47),h,35),"concrete",true)
		b.material_override = _facade_material(i%6,35,h)
		_distant_visual_plots.append(AABB(Vector3(x-b.mesh.size.x*0.5,GROUND,z-17.5),Vector3(b.mesh.size.x,h,35)))
		for y in range(5,int(h),4):
			_batch_box(Vector3(x,GROUND+y,z),Vector3(37,0.15,37),"lightstone")
		_tree(Vector3(x+22,GROUND,z+22),1.2)

func _visual_lawn(boundary: PackedVector2Array, coast: PackedVector2Array) -> void:
	for patch in Geometry2D.intersect_polygons(coast,boundary):
		var lawn := MeshInstance3D.new()
		lawn.mesh = _land_mesh(patch)
		lawn.position.y = 0.026
		lawn.material_override = materials["north_landcover"]
		add_child(lawn)

func _visual_plot_clear(p: Vector2, margin: float) -> bool:
	for collection in [_building_plots,_distant_visual_plots]:
		for box in collection:
			var rect := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(margin)
			if rect.has_point(p): return false
	for anchor in anchors.values():
		if p.distance_to(Vector2(anchor.x,anchor.z))<18: return false
	return true

func _polish_landscape_visuals() -> void:
	# Visual-only dressing: uses its own RNG after all gameplay geometry, so saved IDs/colliders/positions do not change.
	var dressing_rng := RandomNumberGenerator.new()
	dressing_rng.seed = 7182046
	_visual_lawn(PackedVector2Array([Vector2(-270,-725),Vector2(-15,-725),Vector2(-15,-440),Vector2(-270,-440)]),south_polygon)
	# Every existing north-shore building receives a paved foot apron, defining street blocks against the green ground.
	for collection in [_building_plots,_distant_visual_plots]:
		for plot in collection:
			var center: Vector3 = plot.get_center()
			if center.z>-950: continue
			_batch_box(Vector3(center.x,GROUND+0.035,center.z),Vector3(plot.size.x+7,0.045,plot.size.z+7),"paving")
			if center.z<-1780:
				# Small garden paving and a common pedestrian network bind the lower-detail lots together.
				var street_z := roundf(center.z/145.0)*145.0
				var a := Vector3(center.x,GROUND+0.06,center.z+plot.size.z*0.5+3.0)
				var b := Vector3(center.x,GROUND+0.06,street_z)
				if Geometry2D.is_point_in_polygon(Vector2(b.x,b.z),north_polygon):
					_road(a,b,3.4,false,false)
	# Shared garden walks connect those visual lot spurs, clipped strictly to the existing land polygon.
	for path_z in [-1740,-1885,-2030,-2175,-2320,-2465,-2610]:
		var ribbon := PackedVector2Array([Vector2(-1120,path_z-2.5),Vector2(2120,path_z-2.5),Vector2(2120,path_z+2.5),Vector2(-1120,path_z+2.5)])
		for patch in Geometry2D.intersect_polygons(north_polygon,ribbon):
			var path := MeshInstance3D.new()
			path.mesh = _land_mesh(patch)
			path.position.y = 0.045
			path.material_override = materials["paving"]
			add_child(path)
	# A clipped promenade follows the retained north coast. Paths remain on the same existing physical ground.
	var shore: Array = geography["north_coast"]
	var last_furniture := Vector2.INF
	for i in range(shore.size()-1):
		var a := Vector2(shore[i][0],shore[i][1])
		var b := Vector2(shore[i+1][0],shore[i+1][1])
		var delta := b-a
		if delta.length()<3 or delta.length()>130: continue
		var inward := Vector2(-delta.y,delta.x).normalized()
		var middle := (a+b)*0.5
		if not Geometry2D.is_point_in_polygon(middle+inward*8,north_polygon): inward = -inward
		var p := middle+inward*8
		if not Geometry2D.is_point_in_polygon(p,north_polygon): continue
		var ribbon := PackedVector2Array([a+inward*4.5,b+inward*4.5,b+inward*10.5,a+inward*10.5])
		for patch in Geometry2D.intersect_polygons(north_polygon,ribbon):
			var path := MeshInstance3D.new()
			path.mesh = _land_mesh(patch)
			path.position.y = 0.04
			path.material_override = materials["paving"]
			add_child(path)
		if p.distance_to(last_furniture)>55 and _visual_plot_clear(p,7) and not _near_road(p,6):
			_bench(Vector3(p.x,GROUND,p.y),atan2(delta.y,delta.x))
			_lamp(Vector3(p.x+inward.x*2,GROUND,p.y+inward.y*2))
			last_furniture = p
	# Loose planted groves avoid roads, buildings and activity anchors; crowns use the existing spatial MultiMesh batches.
	var planted := 0
	for z in range(-2690,-1090,48):
		for x in range(-1090,2080,48):
			var p := Vector2(x+dressing_rng.randf_range(-20,20),z+dressing_rng.randf_range(-20,20))
			if dressing_rng.randf()>0.46: continue
			if not Geometry2D.is_point_in_polygon(p,north_polygon): continue
			if p.y<-1730 and absf(p.y-roundf(p.y/145.0)*145.0)<7: continue
			if not _visual_plot_clear(p,8) or _near_road(p,13): continue
			if _distance_segment(p,Vector2(149,-1109),Vector2(340,-1510))<31: continue
			var grouping := 0.65+0.35*sin(p.x*0.018+p.y*0.007)
			if dressing_rng.randf()>grouping: continue
			_tree(Vector3(p.x,GROUND,p.y),dressing_rng.randf_range(0.95,1.65))
			planted += 1
			if planted>=560: break
		if planted>=560: break
	print("HARBOR_VISUAL_DRESSING trees=",planted," distant_aprons=",_distant_visual_plots.size())

func _hill_height(x: float, z: float) -> float:
	var radial := pow((x+715.0)/72.0,2.0)+pow((z-74.0)/113.0,2.0)
	return GROUND+19.0*pow(maxf(0.0,1.0-radial),1.3)

func _build_observatory() -> void:
	# A game-scaled raised sandstone/garden headland restores vertical variety without claiming a terrain survey.
	var vertices := PackedVector3Array()
	var ix := PackedInt32Array()
	for ring in range(17):
		var t := float(ring)/16.0
		for sector in range(49):
			var a := float(sector)/48.0*TAU
			var x := -715.0+cos(a)*72*t
			var z := 74.0+sin(a)*113*t
			vertices.append(Vector3(x,_hill_height(x,z)+0.05,z))
	for ring in range(16):
		for sector in range(48):
			var i := ring*49+sector
			ix.append_array(PackedInt32Array([i,i+49,i+1,i+1,i+49,i+50]))
	var mesh := _array_mesh(vertices,ix)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = materials["grass"]
	add_child(mi)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)
	for i in range(30):
		var t := i/29.0
		var a := lerpf(0.2,4.5,t)
		var r := lerpf(0.94,0.15,t)
		var x := -715.0+cos(a)*72*r
		var z := 74.0+sin(a)*113*r
		var a2 := lerpf(0.2,4.5,minf(t+1.0/29.0,1.0))
		var r2 := lerpf(0.94,0.15,minf(t+1.0/29.0,1.0))
		var x2 := -715.0+cos(a2)*72*r2
		var z2 := 74.0+sin(a2)*113*r2
		_road(Vector3(x,_hill_height(x,z)+0.17,z),Vector3(x2,_hill_height(x2,z2)+0.17,z2),3.8,false,false)
	_building("observatory/lodge",Vector3(-715,23.5,74),24,20,8,5)
	var dome_vertices := PackedVector3Array()
	var dome_ix := PackedInt32Array()
	for r in range(13):
		for s in range(33):
			var phi := r/12.0*PI*0.5
			var theta := s/32.0*TAU
			dome_vertices.append(Vector3(cos(theta)*cos(phi)*7.5,sin(phi)*7.5,sin(theta)*cos(phi)*7.5))
	for r in range(12):
		for s in range(32):
			var i := r*33+s
			dome_ix.append_array(PackedInt32Array([i,i+1,i+33,i+1,i+34,i+33]))
	_structure_mesh("observatory/dome",_array_mesh(dome_vertices,dome_ix),Vector3(-715,32,74),"copper",320000)
	for a in range(0,360,35):
		var x := -715+cos(deg_to_rad(a))*62
		var z := 74+sin(deg_to_rad(a))*97
		_tree(Vector3(x,_hill_height(x,z),z),0.8)
	_sign(Vector3(-690,8,159),"OBSERVATORY GARDEN",0,Color("3e554d"))

func _build_helipad() -> void:
	var p: Vector3 = anchors["helipad"]
	_box(self,p-Vector3(0,0.45,0),Vector3(62,0.5,62),"concrete",true)
	_box(self,p-Vector3(0,0.18,0),Vector3(44,0.08,44),"teal")
	for side in [-1,1]:
		_batch_box(p+Vector3(side*6,-0.10,0),Vector3(1.4,0.025,17),"white")
	_batch_box(p+Vector3(0,-0.10,0),Vector3(13,0.025,1.4),"white")
	for i in range(32):
		var a := i*TAU/32.0
		var basis := Basis(Vector3.UP,-a)
		_batch_box(p+Vector3(cos(a)*20,-0.08,sin(a)*20),Vector3(0.4,0.04,3.9),"white",basis)
	for x in [-24,24]:
		for z in [-24,24]:
			_batch_cylinder(p+Vector3(x,0,z),0.3,0.3,"lamp")
	_sign(p+Vector3(0,2.5,30),"HARBOUR AIR / LOCAL OPERATIONS",0,Color("eed8b0"))

func _tree(p: Vector3, scale: float = 1.0) -> void:
	_batch_cylinder(p+Vector3(0,3.1*scale,0),0.36*scale,6.2*scale,"bark")
	for branch in [-1,1]:
		_beam(p+Vector3(0,2.5*scale,0),p+Vector3(branch*1.8*scale,5.8*scale,0.4*scale),0.2*scale,"bark")
	# Merged ellipsoidal foliage mesh reused by all trees; no flat billboards in the detailed area.
	var sphere: SphereMesh
	if materials.has("tree_mesh"):
		sphere = materials["tree_mesh"]
	else:
		sphere = SphereMesh.new()
		sphere.radius = 1
		sphere.height = 2
		sphere.radial_segments = 12
		sphere.rings = 6
		materials["tree_mesh"] = sphere
	for part in range(3):
		var key := "tree_light" if part==1 else "tree"
		if not _batch_foliage.has(key): _batch_foliage[key] = []
		var origin := p+Vector3((part-1)*2.1*scale,(7.0+abs(part-1)*-0.7)*scale,sin(float(part)*3.0)*1.4*scale)
		_batch_foliage[key].append(Transform3D(Basis.IDENTITY.scaled(Vector3(3.0,2.6,3.1)*scale),origin))

func _lamp(p: Vector3) -> void:
	_batch_cylinder(p+Vector3(0,3.1,0),0.11,6.2,"steel")
	_batch_cylinder(p+Vector3(0,0.2,0),0.34,0.4,"darksteel")
	_batch_box(p+Vector3(0.6,6.1,0),Vector3(1.4,0.12,0.15),"steel")
	_batch_box(p+Vector3(1.2,5.95,0),Vector3(0.9,0.18,0.55),"lamp")

func _bench(p: Vector3, angle: float) -> void:
	var b := Basis(Vector3.UP,angle)
	for slat in range(4):
		_batch_box(p+b*Vector3(0,0.62,(slat-1.5)*0.14),Vector3(2.7,0.09,0.12),"wood",b)
		_batch_box(p+b*Vector3(0,0.9+slat*0.12,0.32),Vector3(2.7,0.1,0.09),"wood",b)
	for side in [-1,1]:
		_batch_box(p+b*Vector3(side*1.03,0.32,0),Vector3(0.1,0.6,0.5),"steel",b)

func _sign(p: Vector3, text_value: String, angle: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.font_size = 42
	label.pixel_size = 0.014
	label.modulate = color
	label.outline_size = 0
	label.position = p
	label.rotation.y = angle
	label.no_depth_test = false
	label.visibility_range_end = 120
	add_child(label)

func _near_road(p: Vector2, distance: float) -> bool:
	for seg in road_segments:
		if _distance_segment(p,seg[0],seg[1]) < distance+float(seg[2])*0.5: return true
	return false

func _distance_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var d := b-a
	var t := clampf((p-a).dot(d)/maxf(d.length_squared(),0.01),0.0,1.0)
	return p.distance_to(a+d*t)

func damage_at(point: Vector3, energy: float, radius: float = 8.0) -> void:
	if not _ready_complete or energy<2500: return
	var impacted := false
	var effective_radius := clampf(radius,1.5,75.0)
	for id in structures:
		if destroyed.has(id): continue
		var item: Dictionary = structures[id]
		var local: Vector3 = item["basis"].inverse()*(point-item["position"])
		var half: Vector3 = item["half"]
		var nearest := local.clamp(-half,half)
		var distance := local.distance_to(nearest)
		if distance>effective_radius: continue
		var force := energy*pow(1.0-distance/(effective_radius+0.01),2.0)
		var hp: float = item["strength"]
		if force<hp*0.025: continue
		var value: float = partial_damage.get(id,0.0)+force/hp
		partial_damage[id] = minf(value,1.0)
		_mark_visual_dirty(id)
		impacted = true
		if value>=1.0:
			_destroy_component(id,point,force,true)
		elif value>0.22:
			# Persistent surface abrasion is applied locally to the impacted mesh, never as a global texture overlay.
			var node: Node3D = item["node"]
			for child in node.get_children():
				if child is MeshInstance3D:
					var dark := materials["rubble"].duplicate() as StandardMaterial3D
					dark.albedo_color = Color("9d907f").lerp(Color("4a4945"),minf(value,0.75))
					child.material_override = dark
	if impacted: structure_damaged.emit(point,minf(energy/300000.0,1.0))

func _destroy_component(id: String, impact: Vector3, energy: float, spawn_rubble: bool) -> void:
	if destroyed.has(id) or not structures.has(id): return
	destroyed[id] = true
	_mark_visual_dirty(id)
	partial_damage.erase(id)
	var item: Dictionary = structures[id]
	var node: Node3D = item["node"]
	node.visible = false
	for child in node.get_children():
		if child is CollisionShape3D: child.set_deferred("disabled",true)
	if not spawn_rubble: return
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = id.hash()
	var center: Vector3 = item["position"]
	var half: Vector3 = item["half"]
	for i in range(3):
		var size := Vector3(local_rng.randf_range(0.5,1.6),local_rng.randf_range(0.3,0.85),local_rng.randf_range(0.5,1.5))
		var body := RigidBody3D.new()
		body.name = "Rubble_"+str(id.hash())+"_"+str(i)
		body.mass = size.x*size.y*size.z*260.0
		body.position = center+Vector3(local_rng.randf_range(-minf(half.x,3),minf(half.x,3)),local_rng.randf_range(-minf(half.y,2),minf(half.y,2)),local_rng.randf_range(-minf(half.z,3),minf(half.z,3)))
		body.rotation = Vector3(local_rng.randf(),local_rng.randf()*TAU,local_rng.randf())
		body.linear_damp = 0.42
		body.angular_damp = 0.8
		body.can_sleep = true
		add_child(body)
		_box(body,Vector3.ZERO,size,"rubble")
		var c := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		c.shape = sh
		body.add_child(c)
		var push := (body.position-impact).normalized()+Vector3.UP*0.3
		body.linear_velocity = push*clampf(sqrt(energy/body.mass)*0.06,1,12)
		rubble.append(body)
	while rubble.size()>MAX_RUBBLE:
		var old := rubble.pop_front() as Node3D
		if is_instance_valid(old): old.queue_free()

func get_state() -> Dictionary:
	var debris_state: Array = []
	for node in rubble:
		if not is_instance_valid(node): continue
		var mesh: MeshInstance3D = node.get_child(0)
		var size: Vector3 = mesh.mesh.size
		debris_state.append({"p":[node.position.x,node.position.y,node.position.z],"r":[node.rotation.x,node.rotation.y,node.rotation.z],"s":[size.x,size.y,size.z]})
	return {"version":1,"destroyed":destroyed.keys(),"partial":partial_damage.duplicate(),"rubble":debris_state}

func apply_state(data: Dictionary) -> void:
	repair_all()
	for id in data.get("destroyed",[]):
		if structures.has(id): _destroy_component(id,Vector3.ZERO,0,false)
	partial_damage = data.get("partial",{}).duplicate()
	for id in partial_damage:
		if not structures.has(id): continue
		_mark_visual_dirty(id)
		var node: Node3D = structures[id]["node"]
		if float(partial_damage[id])>0.22:
			for child in node.get_children():
				if child is MeshInstance3D: child.material_override = materials["rubble"]
	for saved in data.get("rubble",[]).slice(0,MAX_RUBBLE):
		var p: Array = saved["p"]
		var r: Array = saved["r"]
		var s: Array = saved["s"]
		var body := RigidBody3D.new()
		body.position = Vector3(p[0],p[1],p[2])
		body.rotation = Vector3(r[0],r[1],r[2])
		body.mass = 250
		body.sleeping = true
		add_child(body)
		_box(body,Vector3.ZERO,Vector3(s[0],s[1],s[2]),"rubble")
		var c := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(s[0],s[1],s[2])
		c.shape = sh
		body.add_child(c)
		rubble.append(body)

func repair_all() -> void:
	for id in structures:
		var node: Node3D = structures[id]["node"]
		if destroyed.has(id) or partial_damage.has(id): _mark_visual_dirty(id)
		node.visible = true
		for child in node.get_children():
			if child is CollisionShape3D: child.set_deferred("disabled",false)
			elif child is MeshInstance3D and (destroyed.has(id) or partial_damage.has(id)):
				child.material_override = child.get_meta("intact_material",materials.get(structures[id]["color"],materials["sandstone"]))
	destroyed.clear()
	partial_damage.clear()
	for node in rubble:
		if is_instance_valid(node): node.queue_free()
	rubble.clear()
