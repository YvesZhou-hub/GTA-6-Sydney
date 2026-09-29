extends SceneTree
## Isolated authored vehicles only: never loads the world or player save files.
const Factory = preload("res://scripts/vehicle_factory.gd")
const Vehicle = preload("res://scripts/harbor_vehicle.gd")
const LEGACY_MERGE = """static func _merge_static_meshes(parent: Node3D, excluded: Array) -> void:
	# Keep authored detail while batching static geometry to one draw per material.
	var meshes: Array = []
	_gather_static_meshes(parent, excluded, meshes)
	_build_profile["source_meshes"]=int(_build_profile.get("source_meshes",0))+meshes.size()
	var groups: Dictionary = {}
	for node in meshes:
		var relative: Transform3D = parent.global_transform.affine_inverse()*node.global_transform
		for surface_index in node.mesh.get_surface_count():
			_build_profile["source_surfaces"]=int(_build_profile.get("source_surfaces",0))+1
			var mat: Material = node.material_override
			if mat == null: mat = node.mesh.surface_get_material(surface_index)
			var key: int = mat.get_instance_id() if mat else 0
			if not groups.has(key):
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"surface":builder,"material":mat}
			var indexed_source := SurfaceTool.new()
			var sample:=Time.get_ticks_usec()
			indexed_source.create_from(node.mesh,surface_index)
			_build_profile["extract_ms"]=float(_build_profile.get("extract_ms",0.0))+(Time.get_ticks_usec()-sample)/1000.0
			sample=Time.get_ticks_usec()
			indexed_source.index()
			_build_profile["index_ms"]=float(_build_profile.get("index_ms",0.0))+(Time.get_ticks_usec()-sample)/1000.0
			sample=Time.get_ticks_usec()
			var temporary_mesh:=indexed_source.commit()
			_build_profile["temporary_commit_ms"]=float(_build_profile.get("temporary_commit_ms",0.0))+(Time.get_ticks_usec()-sample)/1000.0
			_build_profile["temporary_mesh_commits"]=int(_build_profile.get("temporary_mesh_commits",0))+1
			sample=Time.get_ticks_usec()
			groups[key].surface.append_from(temporary_mesh,0,relative)
			_build_profile["append_ms"]=float(_build_profile.get("append_ms",0.0))+(Time.get_ticks_usec()-sample)/1000.0
		node.queue_free()
	for key in groups:
		var combined := MeshInstance3D.new()
		var sample:=Time.get_ticks_usec()
		combined.mesh = groups[key].surface.commit()
		_build_profile["final_commit_ms"]=float(_build_profile.get("final_commit_ms",0.0))+(Time.get_ticks_usec()-sample)/1000.0
		_build_profile["merged_meshes"]=int(_build_profile.get("merged_meshes",0))+1
		combined.material_override = groups[key].material
		parent.add_child(combined)
"""
var failures := 0
var checks: Array = []
var profiles: Dictionary = {}
var space: Node3D
var legacy: GDScript

func _init(): call_deferred("run")
func check(label: String, passed: bool, detail: Dictionary = {}) -> void:
	checks.append({"name":label,"passed":passed,"detail":detail})
	if not passed: failures += 1
	print("FACTORY_CPU ", "PASS " if passed else "FAIL ", label, " ", JSON.stringify(detail))

func nodes(parent: Node, result: Array[Node]) -> Array[Node]:
	for child: Node in parent.get_children():
		if child.is_queued_for_deletion(): continue
		result.append(child)
		nodes(child, result)
	return result

func resource_signature(resource: Resource) -> Dictionary:
	var result: Dictionary = {"class":resource.get_class()}
	for property: Dictionary in resource.get_property_list():
		var key: String = property.name
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or key in ["script","resource_name","resource_local_to_scene"]: continue
		var value: Variant = resource.get(key)
		if not value is Object: result[key] = value
	return result

func structure(body: Node3D) -> Array:
	var result: Array = []
	var list := nodes(body, [])
	for node: Node3D in list:
		var record: Dictionary = {"class":node.get_class(),"pose":node.transform,"visible":node.visible,"parent":list.find(node.get_parent())}
		if not str(node.name).begins_with("@"): record["name"] = node.name
		if node is MeshInstance3D:
			record["material"] = resource_signature(node.material_override) if node.material_override != null else {}
			record["flags"] = [node.cast_shadow,node.layers,node.extra_cull_margin,node.gi_mode]
		if node is CollisionShape3D:
			record["shape"] = resource_signature(node.shape)
			record["disabled"] = node.disabled
		result.append(record)
	return result

func moving_signature(value: Variant, body: Node3D) -> Variant:
	if value is Node:
		var list := nodes(body, [])
		return {"node":list.find(value)}
	if value is Resource: return resource_signature(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = moving_signature(value[key], body)
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(moving_signature(item, body))
		return result
	return value

func meshes(body: Node3D) -> Array:
	return nodes(body, []).filter(func(node): return node is MeshInstance3D)

func compare_arrays(a: Array, b: Array, errors: Dictionary) -> bool:
	var ai: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var bi: PackedInt32Array = b[Mesh.ARRAY_INDEX] if b[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count: int = ai.size() if not ai.is_empty() else a[Mesh.ARRAY_VERTEX].size()
	var other_count: int = bi.size() if not bi.is_empty() else b[Mesh.ARRAY_VERTEX].size()
	if count != other_count: return false
	errors["triangle_corners"] += count
	for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
		if (a[slot] == null) != (b[slot] == null): return false
		if a[slot] == null: continue
		for i in count:
			var x: int = ai[i] if not ai.is_empty() else i
			var y: int = bi[i] if not bi.is_empty() else i
			var error := 0.0
			if slot == Mesh.ARRAY_TANGENT:
				for component in 4: error = maxf(error, absf(a[slot][x * 4 + component] - b[slot][y * 4 + component]))
			elif slot == Mesh.ARRAY_COLOR:
				for component in 4: error = maxf(error, absf(a[slot][x][component] - b[slot][y][component]))
			else: error = a[slot][x].distance_to(b[slot][y])
			errors[str(slot)] = maxf(errors.get(str(slot), 0.0), error)
			# The old temporary GPU commit quantized normals/tangents a second time.
			var tolerance := 0.001 if slot in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT] else 0.0001
			if error > tolerance: return false
	return true

func compare_geometry(a: Node3D, b: Node3D) -> Dictionary:
	var left := meshes(a)
	var right := meshes(b)
	var errors: Dictionary = {"triangle_corners":0,"equal":true}
	if left.size() != right.size(): errors.equal = false; return errors
	for i in left.size():
		var x: Mesh = left[i].mesh
		var y: Mesh = right[i].mesh
		if x.get_surface_count() != y.get_surface_count(): errors.equal = false; return errors
		if not x.get_aabb().is_equal_approx(y.get_aabb()): errors.equal = false; errors["aabb"] = i; return errors
		for surface in x.get_surface_count():
			if not compare_arrays(x.surface_get_arrays(surface), y.surface_get_arrays(surface), errors):
				errors.equal = false
				errors["mesh"] = i
				return errors
	return errors

func build(script: GDScript, kind: String) -> Dictionary:
	var body := Node3D.new()
	space.add_child(body)
	var moving: Dictionary = script.build(body, kind)
	return {"body":body,"moving":moving}

func synthetic_fixture() -> Node3D:
	var body := Node3D.new()
	space.add_child(body)
	var mat := StandardMaterial3D.new()
	for variant in 3:
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		for point: Vector3 in [Vector3.ZERO,Vector3.RIGHT,Vector3.FORWARD]:
			s.set_normal(Vector3.UP)
			if variant == 1:
				s.set_color(Color(.2,.4,.6,.8))
				s.set_uv(Vector2(point.x,point.z))
				s.set_uv2(Vector2(point.x + .1,point.z + .2))
				s.set_tangent(Plane(1,0,0,-1))
			s.add_vertex(point)
		if variant == 2: s.index()
		var node := MeshInstance3D.new()
		node.mesh = s.commit()
		node.material_override = mat
		node.transform = Transform3D(Basis.from_euler(Vector3(.2,.5,.7)).scaled(Vector3(-1.2,.8,1.4)),Vector3(variant,2,-3))
		body.add_child(node)
	return body

func run() -> void:
	legacy = GDScript.new()
	legacy.source_code = FileAccess.get_file_as_string("res://scripts/vehicle_factory.gd").replace("static func _merge_static_meshes(", "static func _unused_cpu_merge(") + "\n" + LEGACY_MERGE
	check("Legacy comparison script compiles", legacy.reload() == OK)
	if failures: quit(1); return
	space = Node3D.new()
	root.add_child(space)
	space.transform = Transform3D(Basis.from_euler(Vector3(.13,.41,-.09)),Vector3(145,320,-880))
	Factory.clear_geometry_cache()
	legacy.clear_geometry_cache()
	for kind: String in Vehicle.NAMES:
		var before := build(legacy, kind)
		var after := build(Factory, kind)
		check(kind + " preserves node hierarchy, materials, colliders, animation pivots and render settings", structure(before.body) == structure(after.body) and moving_signature(before.moving,before.body) == moving_signature(after.moving,after.body))
		var geometry := compare_geometry(before.body, after.body)
		check(kind + " preserves every ordered triangle and all vertex attributes", geometry.equal, geometry)
		var profile: Dictionary = after.body.get_meta("vehicle_factory_profile")
		profiles[kind] = {"legacy":before.body.get_meta("vehicle_factory_profile"),"cpu":profile}
		check(kind + " merges all sources with zero temporary GPU meshes", profile.temporary_mesh_commits == 0 and profile.unmerged_unsupported_meshes == 0 and profile.source_surfaces > 0 and profile.gpu_readback_surfaces < profile.source_surfaces, profile)
		check(kind + " releases temporary CPU copies after caching", Factory._source_arrays.is_empty() and Factory._primitive_arrays.is_empty())
		before.body.free()
		after.body.free()
	var old_fixture := synthetic_fixture()
	var new_fixture := synthetic_fixture()
	legacy._merge_static_meshes(old_fixture, [])
	Factory._merge_static_meshes(new_fixture, [])
	var geometry := compare_geometry(old_fixture, new_fixture)
	check("Mixed indexed/unindexed sources, optional attributes and reflected nonuniform transforms", geometry.equal, geometry)
	old_fixture.free(); new_fixture.free()
	var unsupported := Node3D.new()
	space.add_child(unsupported)
	var line := MeshInstance3D.new()
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO,Vector3.ONE])
	var line_mesh := ArrayMesh.new(); line_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	line.mesh = line_mesh; unsupported.add_child(line)
	Factory._merge_static_meshes(unsupported, [])
	check("Unsupported primitive remains visible with its original geometry", not line.is_queued_for_deletion() and line.mesh == line_mesh)
	unsupported.free()
	var directory := ProjectSettings.globalize_path("res://../reports/vehicle-factory-cpu-merge")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures == 0,"checks":checks,"profiles":profiles,"native_ios":false,"method":"isolated headless geometry comparison with the previous SurfaceTool merger"},"  "))
	file.close()
	Factory.clear_geometry_cache(); legacy.clear_geometry_cache()
	space.free()
	print("FACTORY_CPU_COMPLETE ", checks.size(), " passed=", failures == 0)
	quit(1 if failures else 0)
