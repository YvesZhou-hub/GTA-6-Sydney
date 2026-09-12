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
var map_snapshot: Dictionary = {}
var south_polygon: PackedVector2Array
var north_polygon: PackedVector2Array
var road_segments: Array = []
var _batch_boxes: Dictionary = {}
var _batch_cylinders: Dictionary = {}
var _batch_foliage: Dictionary = {}
var _visual_cells: Dictionary = {}
var _dirty_cells: Dictionary = {}
var _visual_refresh_queued := false
var _bridge_collision_pending := false
var _rng := RandomNumberGenerator.new()
var _building_count := 0
var _ready_complete := false
var _material_cache: Dictionary = {}
var _building_plots: Array[AABB] = []
var _distant_visual_plots: Array[AABB] = []
const GROUND := 4.5
const HELIPAD_TREE_CLEAR_RADIUS := 55.0
const MAX_RUBBLE := 96
var BRIDGE_CORRIDOR: Array[Vector2] = preload("res://scripts/bridge_landmark.gd").corridor_points()
const CityMap = preload("res://scripts/city_map.gd")
const LANDMARK_MODELS = [
	preload("res://scripts/city_landmarks.gd"),
	preload("res://scripts/manly_landmarks.gd"),
	preload("res://scripts/bank_landmarks.gd"),
	preload("res://scripts/metro_entrances.gd"),
	preload("res://scripts/darling_square_frontages.gd"),
	preload("res://scripts/darling_square_detail.gd"),
	preload("res://scripts/quay_landmarks.gd"),
	preload("res://scripts/circular_quay_detail.gd"),
	preload("res://scripts/cyber_landmarks.gd"),
	preload("res://scripts/icc_landmarks.gd"),
	preload("res://scripts/sydney_tower_landmark.gd"),
	preload("res://scripts/qvb_public.gd")
]
const FACADE = preload("res://assets/world_facade.gdshader")
const WATER = preload("res://shaders/water.gdshader")
const LANDCOVER = preload("res://shaders/world_landcover.gdshader")
var _box_meshes: Dictionary={}
var _mesh_array_cache: Dictionary={}
var facade_stream:RefCounted
var material_roles=preload("res://scripts/material_roles.gd").new()

func _ready() -> void:
	var build_started:=Time.get_ticks_msec()
	var timings:Dictionary={}
	_rng.seed = 940219
	_make_materials()
	geography = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world_geography.json"))
	map_snapshot = CityMap.data()
	_build_land()
	_build_water()
	_build_streets()
	_build_bridge()
	_build_opera()
	_build_quay()
	_build_home()
	timings["terrain_and_harbour_ms"]=Time.get_ticks_msec()-build_started
	CityMap.build_buildings(self,map_snapshot)
	CityMap.build_places(self,map_snapshot)
	timings["mapped_city_ms"]=Time.get_ticks_msec()-build_started
	for model in LANDMARK_MODELS:
		model.build(self)
		if model.has_method("metadata"):
			for item in model.metadata():
				if item.has("center") and not anchors.has(item.id): anchors[item.id]=item.get("arrival",item.center)
	_register_landmark_geography()
	CityMap.build_vegetation(self,map_snapshot)
	_build_observatory()
	_build_helipad()
	timings["custom_landmarks_ms"]=Time.get_ticks_msec()-build_started
	_flush_batches()
	for id in structures:
		for child in structures[id]["node"].get_children():
			if child is MeshInstance3D: child.set_meta("intact_material",child.material_override)
	_build_structure_batches()
	for key:String in materials:
		if materials[key] is Material:material_roles.register_key(materials[key],key)
	for key in _material_cache:
		# Some landmark modules keep reusable meshes beside their materials.
		if _material_cache[key] is Material:material_roles.register_key(_material_cache[key],str(key))
	timings["complete_ms"]=Time.get_ticks_msec()-build_started
	set_meta("build_timings",timings)
	print("CITY_BUILD_TIMINGS ",JSON.stringify(timings))
	_ready_complete = true
	print("HARBOR_WORLD_READY buildings=%s structure_components=%s" % [_building_count, structures.size()])

func _register_landmark_geography() -> void:
	# Map icons describe the landmark itself; navigation uses a separately checked
	# public approach. Never infer an entrance by dropping the player at a centroid.
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/landmark_geography.json"))
	for group in ["sydney_tower_landmark","circular_quay_detail","darling_square_detail","opera_interiors","darling_public_facilities","darling_precinct_businesses","manowar_detail","qvb_public"]:
		for record:Dictionary in get_meta(group,[]):
			if not record.has("map_position") or not record.has("arrival"):continue
			var entry:=record.duplicate(true)
			entry["group"]=group
			source.landmarks.append(entry)
	var catalog: Dictionary = {}
	for record: Dictionary in source.get("landmarks", []):
		var item := record.duplicate(true)
		for field in ["map_position", "arrival", "model_reference"]:
			if item.has(field): item[field] = Vector3(item[field][0], item[field][1], item[field][2])
		catalog[item.id] = item
		anchors[item.id] = item.arrival
		for alias: String in item.get("aliases", []):
			catalog[alias] = item
			anchors[alias] = item.arrival
		var group: String = item.get("group", "")
		if not group.is_empty() and has_meta(group):
			var entries: Array = get_meta(group)
			for entry: Dictionary in entries:
				if entry.get("id", "") == item.id or entry.get("id", "") in item.get("aliases", []):
					entry["map_position"] = item.map_position
					entry["arrival"] = item.arrival
			set_meta(group, entries)
	set_meta("landmark_geography", catalog)

func _mat(key: String, color: Color, roughness: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metal
	materials[key] = m
	material_roles.register_key(m,key)
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
	if not _box_meshes.has(size):
		var cube:=BoxMesh.new()
		cube.size=size
		_box_meshes[size]=cube
	var mesh: BoxMesh=_box_meshes[size]
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
	if get_meta("stream_details",false):
		facade_stream=preload("res://scripts/facade_stream.gd").new()
		facade_stream.setup(self)
	for id in structures:
		var p: Vector3 = structures[id]["position"]
		var cell := Vector2i(floori(p.x/160.0),floori(p.z/160.0))
		structures[id]["cell"] = cell
		if not _visual_cells.has(cell):
			var instance := MeshInstance3D.new()
			instance.name = "Architecture_%s_%s"%[cell.x,cell.y]
			add_child(instance)
			var detail := MeshInstance3D.new()
			detail.name="FacadeDetail_%s_%s"%[cell.x,cell.y]
			detail.visibility_range_end=320.0
			detail.visibility_range_end_margin=60.0
			detail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(detail)
			_visual_cells[cell] = {"ids":[],"instance":instance,"detail":detail,"has_near":false}
		_visual_cells[cell]["ids"].append(id)
		for surface:Dictionary in structures[id].get("surfaces",[]):
			if surface.get("near",false): _visual_cells[cell].has_near=true
		for child in structures[id]["node"].get_children():
			if child is MeshInstance3D:
				child.visible = false
				if child.get_meta("near_facade",false): _visual_cells[cell].has_near=true
	for cell in _visual_cells: _rebuild_visual_cell(cell,is_instance_valid(facade_stream))

func _rebuild_visual_cell(cell: Vector2i,base_only:=false,detail_only:=false) -> void:
	if is_instance_valid(facade_stream) and not detail_only:
		base_only=true
		facade_stream.invalidate(cell)
	var groups: Dictionary = {false:{},true:{}}
	var data: Dictionary = _visual_cells[cell]
	for id in data["ids"]:
		if destroyed.has(id): continue
		var node: Node3D = structures[id]["node"]
		for cpu_surface in structures[id].get("surfaces",[]):
			var near:bool=cpu_surface.get("near",false)
			if (base_only and near) or (detail_only and not near) or not cpu_surface.has("arrays"):continue
			var arrays: Array=cpu_surface.arrays
			if arrays.size()!=Mesh.ARRAY_MAX or arrays[Mesh.ARRAY_VERTEX]==null or arrays[Mesh.ARRAY_VERTEX].is_empty():continue
			var target: Dictionary=groups[near]
			var material: Material=materials.rubble if float(partial_damage.get(id,0.0))>0.22 else cpu_surface.material
			var key: int=material.get_instance_id()
			if not target.has(key):
				var surface:=SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				surface.set_material(material)
				target[key]=surface
			var vertices: PackedVector3Array=node.transform*arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=Transform3D(node.basis,Vector3.ZERO)*arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			var uv2:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2]!=null else PackedVector2Array()
			for index in arrays[Mesh.ARRAY_INDEX]:
				target[key].set_normal(normals[index])
				target[key].set_uv(uv[index])
				target[key].set_uv2(uv2[index] if not uv2.is_empty() else Vector2.ZERO)
				target[key].add_vertex(vertices[index])
		for child in node.get_children():
			if not child is MeshInstance3D or child.get_meta("collision_only",false): continue
			var near:bool=child.get_meta("near_facade",false)
			if (base_only and near) or (detail_only and not near):continue
			var target: Dictionary=groups[near]
			var material: Material = child.material_override
			var key: int = material.get_instance_id()
			if not target.has(key):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				surface.set_material(material)
				target[key] = surface
			if not _mesh_array_cache.has(child.mesh):
				var cached:Array=[]
				for surface_index in child.mesh.get_surface_count(): cached.append(child.mesh.surface_get_arrays(surface_index))
				_mesh_array_cache[child.mesh]=cached
			for arrays in _mesh_array_cache[child.mesh]:
				_append_cached_arrays(target[key],arrays,node.transform*child.transform)
	for near in [false,true]:
		if (base_only and near) or (detail_only and not near):continue
		var mesh := ArrayMesh.new()
		for key in groups[near]: groups[near][key].commit(mesh)
		data["detail" if near else "instance"].mesh = mesh if groups[near].size()>0 else null

func _append_cached_arrays(surface: SurfaceTool, arrays: Array, pose: Transform3D) -> void:
	# Native Metal readback is paid once per source mesh, including the thousands
	# of repeated mullions/treads. Damage rebuilds reuse the same CPU geometry.
	var vertices: PackedVector3Array=pose*arrays[Mesh.ARRAY_VERTEX]
	var normal_basis:=pose.basis.inverse().transposed()
	var normals: PackedVector3Array=Transform3D(normal_basis,Vector3.ZERO)*arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
	var uv2:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2]!=null else PackedVector2Array()
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	for cursor in (vertices.size() if indices.is_empty() else indices.size()):
		var index:int=cursor if indices.is_empty() else indices[cursor]
		surface.set_normal(normals[index].normalized())
		surface.set_uv(uv[index] if not uv.is_empty() else Vector2.ZERO)
		surface.set_uv2(uv2[index] if not uv2.is_empty() else Vector2.ZERO)
		surface.add_vertex(vertices[index])

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

func _structure_arrays(id: String, arrays: Array, pos: Vector3, key: String, strength: float) -> StaticBody3D:
	# Ordinary mapped buildings retain CPU geometry and independent physics.
	# Only the final spatial cell mesh is uploaded to Metal, avoiding tens of
	# thousands of create-mesh/readback/upload cycles during native startup.
	var body:=StaticBody3D.new()
	body.name=id.replace("/","_")
	body.position=pos
	body.add_to_group("world_structure")
	body.set_meta("damage_id",id)
	add_child(body)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var faces:=PackedVector3Array()
	for index in arrays[Mesh.ARRAY_INDEX]: faces.append(vertices[index])
	var shape:=ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision:=CollisionShape3D.new()
	collision.shape=shape
	body.add_child(collision)
	var bounds:=AABB(vertices[0],Vector3.ZERO)
	for vertex in vertices: bounds=bounds.expand(vertex)
	structures[id]={"node":body,"position":pos+bounds.get_center(),"half":bounds.size*0.5,"basis":Basis.IDENTITY,"strength":strength,"color":key,"surfaces":[{"arrays":arrays,"material":materials[key],"near":false}]}
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
	CityMap.build_terrain(self,map_snapshot)
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
	var exclusions:=preload("res://scripts/metro_entrances.gd").water_exclusion_rects()
	water_mat.set_shader_parameter("dry_rect_a",exclusions[0])
	water_mat.set_shader_parameter("dry_rect_b",exclusions[1])
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
	CityMap.build_roads(self,map_snapshot)


func _bridge_pos(t: float, y: float = 54.0, across: float = 0.0) -> Vector3:
	return preload("res://scripts/bridge_landmark.gd").pos(t,y,across)

func _build_bridge() -> void:
	preload("res://scripts/bridge_landmark.gd").build(self)

func _destruct_beam(id: String, a: Vector3, b: Vector3, width: float, strength: float) -> void:
	var d := b-a
	var basis := Basis.looking_at(d.normalized(),Vector3.UP if absf(d.normalized().y)<0.98 else Vector3.RIGHT)
	_structure_box(id,(a+b)*0.5,Vector3(width,width,d.length()+0.12),"steel",strength,basis)

func _build_opera() -> void:
	preload("res://scripts/opera_landmark.gd").build(self)
	preload("res://scripts/opera_interiors.gd").build(self)

func _local_beam(parent: Node3D, a: Vector3, b: Vector3, width: float, key: String) -> void:
	var d := b-a
	var mesh := _box(parent,(a+b)*0.5,Vector3(width,width,d.length()),key)
	mesh.basis = Basis.looking_at(d.normalized(),Vector3.UP if absf(d.normalized().y)<0.98 else Vector3.RIGHT)

func _build_quay() -> void:
	preload("res://scripts/circular_quay_detail.gd").build(self)
	preload("res://scripts/manowar_detail.gd").build(self)
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
	# Apply to every generator, including fixed landmarks such as the former north hotel.
	# The entire footprint must clear the carriageway and footways, not just its centre.
	if _in_bridge_corridor(Vector2(p.x,p.z),Vector2(width,depth).length()*0.5): return
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

func _visual_lawn(boundary: PackedVector2Array, coast: PackedVector2Array) -> void:
	for patch in Geometry2D.intersect_polygons(coast,boundary):
		var lawn := MeshInstance3D.new()
		lawn.mesh = _land_mesh(patch)
		lawn.position.y = 0.026
		lawn.material_override = materials["north_landcover"]
		add_child(lawn)

func _visual_plot_clear(p: Vector2, margin: float) -> bool:
	if _in_bridge_corridor(p,margin): return false
	for collection in [_building_plots,_distant_visual_plots]:
		for box in collection:
			var rect := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(margin)
			if rect.has_point(p): return false
	for anchor in anchors.values():
		if p.distance_to(Vector2(anchor.x,anchor.z))<18: return false
	return true

func _hill_height(x: float, z: float) -> float:
	var radial := pow((x+547.947)/72.0,2.0)+pow((z+47.452)/113.0,2.0)
	return GROUND+19.0*pow(maxf(0.0,1.0-radial),1.3)

func _build_observatory() -> void:
	# A game-scaled raised sandstone/garden headland restores vertical variety without claiming a terrain survey.
	var vertices := PackedVector3Array()
	var ix := PackedInt32Array()
	for ring in range(17):
		var t := float(ring)/16.0
		for sector in range(49):
			var a := float(sector)/48.0*TAU
			var x := -547.947+cos(a)*72*t
			var z := -47.452+sin(a)*113*t
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
		var x := -547.947+cos(a)*72*r
		var z := -47.452+sin(a)*113*r
		var a2 := lerpf(0.2,4.5,minf(t+1.0/29.0,1.0))
		var r2 := lerpf(0.94,0.15,minf(t+1.0/29.0,1.0))
		var x2 := -547.947+cos(a2)*72*r2
		var z2 := -47.452+sin(a2)*113*r2
		_road(Vector3(x,_hill_height(x,z)+0.17,z),Vector3(x2,_hill_height(x2,z2)+0.17,z2),3.8,false,false)
	_building("observatory/lodge",Vector3(-547.947,23.5,-47.452),24,20,8,5)
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
	_structure_mesh("observatory/dome",_array_mesh(dome_vertices,dome_ix),Vector3(-547.947,32,-47.452),"copper",320000)
	for a in range(0,360,35):
		var x := -547.947+cos(deg_to_rad(a))*62
		var z := -47.452+sin(deg_to_rad(a))*97
		_tree(Vector3(x,_hill_height(x,z),z),0.8)
	_sign(Vector3(-522.947,8,37.548),"OBSERVATORY GARDEN",0,Color("3e554d"))

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

func _tree_crowns(p: Vector3, scale: float) -> Array[Transform3D]:
	var crowns:Array[Transform3D]=[]
	for part in range(3):
		var origin:=p+Vector3((part-1)*2.1*scale,(7.0+abs(part-1)*-0.7)*scale,sin(float(part)*3.0)*1.4*scale)
		crowns.append(Transform3D(Basis.IDENTITY.scaled(Vector3(3.0,2.6,3.1)*scale),origin))
	return crowns

func _tree_canopy_intersects_helipad(p: Vector3, scale: float) -> bool:
	# This authored game helipad is already excluded from ordinary buildings.
	# Keep the same 55 m operation area clear of the complete rendered crowns,
	# including crowns on trees whose trunks are outside the boundary.
	var pad:Vector3=anchors["helipad"]
	for crown in _tree_crowns(p,scale):
		var bounds:AABB=crown*AABB(-Vector3.ONE,Vector3.ONE*2)
		var nearest:=Vector2(clampf(pad.x,bounds.position.x,bounds.end.x),clampf(pad.z,bounds.position.z,bounds.end.z))
		if nearest.distance_to(Vector2(pad.x,pad.z))<=HELIPAD_TREE_CLEAR_RADIUS:return true
	return false

func _tree(p: Vector3, scale: float = 1.0) -> bool:
	if _tree_canopy_intersects_helipad(p,scale): return false
	if p.y<GROUND+1.0 and _in_bridge_corridor(Vector2(p.x,p.z),5.0*scale): return false
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
	var crowns:=_tree_crowns(p,scale)
	for part in range(3):
		var key := "tree_light" if part==1 else "tree"
		if not _batch_foliage.has(key): _batch_foliage[key] = []
		_batch_foliage[key].append(crowns[part])
		# Preserve only the small nearby set of exact renderer inputs for
		# clearance diagnostics; headless MultiMesh readback has no transforms.
		var bounds:AABB=crowns[part]*AABB(-Vector3.ONE,Vector3.ONE*2)
		var pad:Vector3=anchors["helipad"]
		var nearest:=Vector2(clampf(pad.x,bounds.position.x,bounds.end.x),clampf(pad.z,bounds.position.z,bounds.end.z))
		if nearest.distance_to(Vector2(pad.x,pad.z))<=HELIPAD_TREE_CLEAR_RADIUS+20:
			var retained:Array=get_meta("helipad_retained_crown_bounds",[])
			retained.append(bounds)
			set_meta("helipad_retained_crown_bounds",retained)
	return true

func _lamp(p: Vector3) -> void:
	if p.y<GROUND+1.0 and _in_bridge_corridor(Vector2(p.x,p.z),0.5): return
	_batch_cylinder(p+Vector3(0,3.1,0),0.11,6.2,"steel")
	_batch_cylinder(p+Vector3(0,0.2,0),0.34,0.4,"darksteel")
	_batch_box(p+Vector3(0.6,6.1,0),Vector3(1.4,0.12,0.15),"steel")
	_batch_box(p+Vector3(1.2,5.95,0),Vector3(0.9,0.18,0.55),"lamp")

func _bench(p: Vector3, angle: float) -> void:
	if p.y<GROUND+1.0 and _in_bridge_corridor(Vector2(p.x,p.z),2.0): return
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

func _in_bridge_corridor(p: Vector2, margin: float = 0.0) -> bool:
	for i in range(BRIDGE_CORRIDOR.size()-1):
		if _distance_segment(p,BRIDGE_CORRIDOR[i],BRIDGE_CORRIDOR[i+1])<32.0+margin:
			return true
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
	if id.begins_with("bridge/deck/") or id.begins_with("bridge/ramp/"):
		_queue_bridge_collision_refresh()
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

func _queue_bridge_collision_refresh() -> void:
	if _bridge_collision_pending: return
	_bridge_collision_pending=true
	call_deferred("_refresh_bridge_collision")

func _refresh_bridge_collision() -> void:
	_bridge_collision_pending=false
	preload("res://scripts/bridge_landmark.gd").refresh_drive_collision(self)

func apply_state(data: Dictionary) -> void:
	repair_all()
	for id in data.get("destroyed",[]):
		if structures.has(id): _destroy_component(id,Vector3.ZERO,0,false)
		else: destroyed[id]=true # Keep retired component IDs when geometry changes between releases.
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
	_queue_bridge_collision_refresh()

func stream_view(position:Vector3,velocity:Vector3,delta:float):
	if is_instance_valid(facade_stream):facade_stream.tick(position,velocity,delta)

func streaming_stats() -> Dictionary:
	return facade_stream.stats() if is_instance_valid(facade_stream) else {"enabled":false,"scope":"all_detail_resident","resident":_visual_cells.size()}

func prepare_view(position:Vector3,timeout_seconds:=15.0) -> bool:
	# Capture validators disable the main follow-camera process. Exercise the same
	# stream queue explicitly before photographing an unmoving view.
	if not is_instance_valid(facade_stream):return true
	var started:=Time.get_ticks_msec()
	while (Time.get_ticks_msec()-started)/1000.0<timeout_seconds:
		stream_view(position,Vector3.ZERO,.16)
		var ready:bool=facade_stream._task<0
		for cell:Vector2i in facade_stream.wanted:
			if not facade_stream.resident.has(cell):ready=false
		if ready:return true
		await get_tree().process_frame
	return false

func _exit_tree():
	if is_instance_valid(facade_stream):facade_stream.close()
