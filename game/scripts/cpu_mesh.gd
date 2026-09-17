extends RefCounted
## CPU copies of procedural world meshes. On Metal, reading geometry back from a
## mesh (surface_get_arrays, get_faces, create_trimesh_shape) blocks for about
## 0.3 ms per mesh, and cell batching used to read back about 6,000 of them.
## World modules commit through here so the arrays SurfaceTool already built are
## kept until the city is batched; release() drops whatever batching did not use.

const WELD_SNAP := Vector3(0.0001, 0.0001, 0.0001)

static var _arrays: Dictionary = {}
static var _unit_box: Array = []


static func commit(surface: SurfaceTool) -> ArrayMesh:
	var arrays := surface.commit_to_arrays()
	# commit() keeps SurfaceTool's own material and flags on the uploaded mesh.
	var mesh := surface.commit()
	if mesh.get_surface_count() == 1: _arrays[mesh] = [arrays]
	return mesh


## Surface arrays without a GPU readback when the mesh was committed here or is a
## plain BoxMesh; anything else falls back to the renderer copy.
static func surface_arrays(mesh: Mesh) -> Array:
	if _is_known(mesh): return _arrays[mesh]
	if _is_plain_box(mesh): return [_box_arrays(mesh.size)]
	var result := []
	for index in mesh.get_surface_count(): result.append(mesh.surface_get_arrays(index))
	return result


static func has_cpu_arrays(mesh: Mesh) -> bool:
	return _is_known(mesh) or _is_plain_box(mesh)


static func _is_known(mesh: Mesh) -> bool:
	# A mesh edited after commit (cleared or given more surfaces) uses the renderer copy.
	if not _arrays.has(mesh): return false
	var arrays: Array = _arrays[mesh]
	return mesh.get_surface_count() == arrays.size() and mesh.surface_get_array_len(0) == arrays[0][Mesh.ARRAY_VERTEX].size()


static func trimesh_shape(mesh: Mesh) -> ConcavePolygonShape3D:
	if not has_cpu_arrays(mesh): return mesh.create_trimesh_shape()
	# Mesh.create_trimesh_shape() welds through TriangleMesh, which snaps every
	# position to 0.1 mm. Snapping the same way keeps colliders bit-identical.
	var faces := PackedVector3Array()
	for arrays: Array in surface_arrays(mesh):
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := vertices.size() if indices.is_empty() else indices.size()
		var at := faces.size()
		faces.resize(at + count)
		for i in count: faces[at + i] = (vertices[i] if indices.is_empty() else vertices[indices[i]]).snapped(WELD_SNAP)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	return shape


static func release() -> void:
	_arrays.clear()


static func _is_plain_box(mesh: Mesh) -> bool:
	return mesh is BoxMesh and mesh.subdivide_width == 0 and mesh.subdivide_height == 0 and mesh.subdivide_depth == 0 and not mesh.flip_faces and not mesh.add_uv2


static func _box_arrays(size: Vector3) -> Array:
	# BoxMesh positions scale linearly with size; normals, UVs and indices do not.
	if _unit_box.is_empty(): _unit_box = BoxMesh.new().surface_get_arrays(0)
	var arrays := _unit_box.duplicate()
	arrays[Mesh.ARRAY_VERTEX] = Transform3D(Basis.from_scale(size), Vector3.ZERO) * _unit_box[Mesh.ARRAY_VERTEX]
	return arrays
