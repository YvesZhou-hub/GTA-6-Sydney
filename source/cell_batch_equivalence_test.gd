extends SceneTree
## Indexed visual-cell batches must draw the same triangles as the previous
## SurfaceTool path, which expanded every index into its own vertex.
const World=preload("res://scripts/harbor_world.gd")
var checks:Array=[]

func check(title:String,okay:bool,detail:Dictionary={}):
	checks.append({"name":title,"passed":okay,"detail":detail})
	print("CELL_BATCH ","PASS " if okay else "FAIL ",title," ",JSON.stringify(detail))

func legacy_cell(world:Node3D,ids:Array) -> Dictionary:
	# Verbatim merge from the previous _rebuild_visual_cell / _append_cached_arrays.
	var target:Dictionary={}
	for id in ids:
		var node:Node3D=world.structures[id]["node"]
		for cpu_surface in world.structures[id].get("surfaces",[]):
			var arrays:Array=cpu_surface.arrays
			var material:Material=cpu_surface.material
			var key:int=material.get_instance_id()
			if not target.has(key):
				var surface:=SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				surface.set_material(material)
				target[key]=surface
			var vertices:PackedVector3Array=node.transform*arrays[Mesh.ARRAY_VERTEX]
			var normals:PackedVector3Array=Transform3D(node.basis,Vector3.ZERO)*arrays[Mesh.ARRAY_NORMAL]
			var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			var uv2:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2]!=null else PackedVector2Array()
			for index in arrays[Mesh.ARRAY_INDEX]:
				target[key].set_normal(normals[index])
				target[key].set_uv(uv[index])
				target[key].set_uv2(uv2[index] if not uv2.is_empty() else Vector2.ZERO)
				target[key].add_vertex(vertices[index])
		for child in node.get_children():
			if not child is MeshInstance3D: continue
			var material:Material=child.material_override
			var key:int=material.get_instance_id()
			if not target.has(key):
				var surface:=SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				surface.set_material(material)
				target[key]=surface
			for arrays in world._mesh_array_cache[child.mesh]:
				var pose:Transform3D=node.transform*child.transform
				var vertices:PackedVector3Array=pose*arrays[Mesh.ARRAY_VERTEX]
				var normal_basis:=pose.basis.inverse().transposed()
				var normals:PackedVector3Array=Transform3D(normal_basis,Vector3.ZERO)*arrays[Mesh.ARRAY_NORMAL]
				var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
				var uv2:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2]!=null else PackedVector2Array()
				var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				for cursor in (vertices.size() if indices.is_empty() else indices.size()):
					var index:int=cursor if indices.is_empty() else indices[cursor]
					target[key].set_normal(normals[index].normalized())
					target[key].set_uv(uv[index] if not uv.is_empty() else Vector2.ZERO)
					target[key].set_uv2(uv2[index] if not uv2.is_empty() else Vector2.ZERO)
					target[key].add_vertex(vertices[index])
	var result:={}
	for key in target: result[key]=target[key].commit_to_arrays()
	return result

func current_cell(world:Node3D,ids:Array) -> Dictionary:
	var groups:={}
	for id in ids:
		var node:Node3D=world.structures[id]["node"]
		for cpu_surface in world.structures[id].get("surfaces",[]):
			world._append_cell_arrays(world._cell_group(groups,cpu_surface.material),cpu_surface.arrays,node.transform,node.basis)
		for child in node.get_children():
			if not child is MeshInstance3D: continue
			for arrays in world._mesh_array_cache[child.mesh]:
				world._append_cached_arrays(world._cell_group(groups,child.material_override),arrays,node.transform*child.transform)
	return groups

func compare(legacy:Array,group) -> Dictionary:
	var worst:={"position":0.0,"normal":0.0,"uv":0.0,"uv2":0.0}
	var expanded:int=group.indices.size()
	if expanded!=legacy[Mesh.ARRAY_VERTEX].size(): return {"count_mismatch":[legacy[Mesh.ARRAY_VERTEX].size(),expanded]}
	for i in expanded:
		var index:int=group.indices[i]
		worst.position=maxf(worst.position,legacy[Mesh.ARRAY_VERTEX][i].distance_to(group.vertices[index]))
		worst.normal=maxf(worst.normal,legacy[Mesh.ARRAY_NORMAL][i].distance_to(group.normals[index]))
		worst.uv=maxf(worst.uv,legacy[Mesh.ARRAY_TEX_UV][i].distance_to(group.uv[index]))
		worst.uv2=maxf(worst.uv2,legacy[Mesh.ARRAY_TEX_UV2][i].distance_to(group.uv2[index]))
	worst["corners"]=expanded
	worst["indexed_vertices"]=group.vertices.size()
	return worst

func arrays_from(mesh:PrimitiveMesh,with_uv2:bool,keep_index:bool) -> Array:
	var tool:=SurfaceTool.new()
	tool.create_from(mesh,0)
	if not keep_index: tool.deindex()
	var arrays:=tool.commit_to_arrays()
	arrays[Mesh.ARRAY_TANGENT]=null
	if with_uv2:
		var uv2:=PackedVector2Array()
		for i in arrays[Mesh.ARRAY_VERTEX].size(): uv2.append(Vector2(i%7,0.25*(i%3)))
		arrays[Mesh.ARRAY_TEX_UV2]=uv2
	return arrays

func _initialize():
	var world:Node3D=World.new()
	var stone:=StandardMaterial3D.new()
	var glass:=StandardMaterial3D.new()
	var steel:=StandardMaterial3D.new()
	var prism:=PrismMesh.new();prism.size=Vector3(8,5,3)
	var cylinder:=CylinderMesh.new();cylinder.radial_segments=9;cylinder.rings=2
	var cases:=[
		{"id":"a","pose":Transform3D(Basis.IDENTITY,Vector3(10,0,-4)),"surfaces":[[arrays_from(prism,true,true),stone],[arrays_from(BoxMesh.new(),false,true),glass]]},
		{"id":"b","pose":Transform3D(Basis(Vector3.UP,0.7),Vector3(-30,2,12)),"surfaces":[[arrays_from(cylinder,true,true),stone]],
			"children":[[BoxMesh.new(),steel,Transform3D(Basis(Vector3(1,0.2,0).normalized(),0.4),Vector3(0,3,0))],
				[cylinder,glass,Transform3D(Basis.IDENTITY.scaled(Vector3(2.5,2.5,2.5)),Vector3(1,0,1))]]},
		{"id":"c","pose":Transform3D(Basis(Vector3(0.3,1,0.1).normalized(),-1.9),Vector3(400,7,-900)),"surfaces":[],
			"children":[[prism,steel,Transform3D(Basis.IDENTITY.scaled(Vector3(0.2,6,1.5)),Vector3(-2,0,4))],
				[BoxMesh.new(),stone,Transform3D(Basis(Vector3.RIGHT,1.1)*Basis.IDENTITY.scaled(Vector3(3,0.5,0.8)),Vector3(5,1,0))]]},
	]
	var ids:=[]
	for item:Dictionary in cases:
		var node:=StaticBody3D.new()
		node.transform=item.pose
		var surfaces:=[]
		for pair:Array in item.surfaces: surfaces.append({"arrays":pair[0],"material":pair[1],"near":false})
		for row:Array in item.get("children",[]):
			var child:=MeshInstance3D.new()
			child.mesh=row[0]
			child.material_override=row[1]
			child.transform=row[2]
			node.add_child(child)
			# Non-indexed and indexed readbacks both occur in production caches.
			world._mesh_array_cache[row[0]]=[arrays_from(row[0],false,row[0] is BoxMesh)]
		world.structures[item.id]={"node":node,"surfaces":surfaces}
		ids.append(item.id)
	var legacy:=legacy_cell(world,ids)
	var current:=current_cell(world,ids)
	check("same materials in the same order",legacy.keys()==current.keys(),{"legacy":legacy.size(),"current":current.size()})
	var fewer:=true
	for key in legacy:
		var result:=compare(legacy[key],current[key])
		var ok:bool=not result.has("count_mismatch") and result.position<0.0001 and result.normal<0.0001 and result.uv<0.00001 and result.uv2<0.00001
		check("material %d draws identical corners" % legacy.keys().find(key),ok,result)
		fewer=fewer and result.get("indexed_vertices",INF)<=result.get("corners",0)
	check("indexed batches never upload more vertices than the expanded path",fewer)
	# Full rebuild: one ArrayMesh surface per material with the right material.
	world._visual_cells[Vector2i.ZERO]={"ids":ids,"instance":MeshInstance3D.new(),"detail":MeshInstance3D.new(),"has_near":false}
	world._rebuild_visual_cell(Vector2i.ZERO)
	var mesh:ArrayMesh=world._visual_cells[Vector2i.ZERO].instance.mesh
	var materials_in_order:=[]
	var index_total:=0
	for i in mesh.get_surface_count():
		materials_in_order.append(mesh.surface_get_material(i).get_instance_id())
		index_total+=mesh.surface_get_array_index_len(i)
	var legacy_total:=0
	for key in legacy: legacy_total+=legacy[key][Mesh.ARRAY_VERTEX].size()
	check("rebuilt cell mesh has one surface per material in legacy order",materials_in_order==legacy.keys())
	check("rebuilt cell mesh draws the same number of corners",index_total==legacy_total,{"indexed":index_total,"legacy":legacy_total})
	check("cells without near geometry leave the detail mesh empty",world._visual_cells[Vector2i.ZERO].detail.mesh==null)
	for item in world.structures.values(): item.node.free()
	for cell in world._visual_cells.values():
		cell.instance.free()
		cell.detail.free()
	world.free()
	var passed:=checks.all(func(item):return item.passed)
	print("CELL_BATCH COMPLETE checks=%d failures=%d" % [checks.size(),checks.filter(func(item):return not item.passed).size()])
	quit(0 if passed else 1)
