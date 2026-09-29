extends SceneTree
const Cpu=preload("res://scripts/cpu_mesh.gd")
const City=preload("res://scripts/city_map.gd")
const Map=preload("res://scripts/harbor_map.gd")
class FixtureWorld:
	extends "res://scripts/harbor_world.gd"
	var bridge_refreshes:=0
	var fail_compression:=false
	func _ready() -> void: pass
	func _encode_source_arrays(arrays:Array) -> Dictionary:
		if fail_compression: return {}
		return super._encode_source_arrays(arrays)
	func _refresh_bridge_collision():
		_bridge_collision_pending=false
		bridge_refreshes+=1
var checks:Array=[]
var failures:=0
func _initialize(): call_deferred("run")
func check(label:String,ok:bool,evidence:Dictionary={}):
	checks.append({"name":label,"passed":ok,"evidence":evidence})
	print("PASS " if ok else "FAIL ",label," ",JSON.stringify(evidence))
	if not ok: failures+=1
func source_mesh() -> ArrayMesh:
	var box:=BoxMesh.new();box.size=Vector3(8,8,8)
	var surface:=SurfaceTool.new();surface.create_from(box,0)
	return Cpu.commit(surface)
func mesh_hash(mesh:Mesh) -> String:
	if mesh==null: return "null"
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	for i in mesh.get_surface_count(): hash.update(var_to_bytes(mesh.surface_get_arrays(i)))
	return hash.finish().hex_encode()
func arrays_hash(arrays:Array) -> String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(arrays))
	return hash.finish().hex_encode()
func view(world,id:String) -> MeshInstance3D:
	for child in world.structures[id].node.get_children():
		if child is MeshInstance3D: return child
	return null
func collision(world,id:String) -> CollisionShape3D:
	for child in world.structures[id].node.get_children():
		if child is CollisionShape3D: return child
	return null
func drain(world,point:Vector3) -> bool:
	for i in 400:
		world.stream_view(point,Vector3.ZERO,.16)
		if world.facade_stream._task<0 and not world.facade_stream.resident.is_empty(): return true
		await process_frame
	return false
func run():
	var world:=FixtureWorld.new();root.add_child(world)
	world.set_meta("stream_details",true)
	for key in ["sandstone","steel","lightstone","rubble"]: world._mat(key,Color(.5,.5,.5))
	var private_source:=source_mesh()
	var future_source:=source_mesh()
	var shared_source:=source_mesh()
	var multi_source:=source_mesh()
	var source_hash:=mesh_hash(private_source)
	var initial_bounds:=private_source.get_aabb()
	world._structure_mesh("test/private",private_source,Vector3(4000,10,4000),"sandstone",50000)
	world._structure_mesh("test/future",future_source,Vector3(4160,10,4000),"sandstone",50000)
	world._structure_mesh("test/shared",shared_source,Vector3(4320,10,4000),"sandstone",50000)
	world._structure_mesh("test/multi",multi_source,Vector3(4480,10,4000),"sandstone",50000)
	world._structure_mesh("bridge/deck/probe",source_mesh(),Vector3(4640,10,4000),"sandstone",50000)
	var outside:=MeshInstance3D.new();outside.mesh=shared_source;root.add_child(outside)
	var outside_multi:=MultiMeshInstance3D.new();outside_multi.multimesh=MultiMesh.new();outside_multi.multimesh.mesh=multi_source;root.add_child(outside_multi)
	var record:={"id":"way/990040001","center":[4800,4000],"outline":[[-6,-6],[6,-6],[6,6],[-6,6]],"roof":[[-6,-6],[6,-6],[6,6],[-6,-6],[6,6],[-6,6]],"holes":[],"height":15.0,"base":0.0,"height_source":"test","tags":{"building":"office"}}
	world.map_snapshot={"buildings":[record],"roads":[],"land":[],"places":[],"parks":[],"beaches":[],"trees":[{"point":[10,20]}],"counts":{"buildings":1},"attribution":"test provenance"}
	City.build_buildings(world,world.map_snapshot)
	for part in world.structures.values():
		for child in part.node.get_children():
			if child is MeshInstance3D: child.set_meta("intact_material",child.material_override)
	world._build_structure_batches()
	check("desktop keeps original source resources by default",view(world,"test/private").mesh==private_source and not world.has_meta("mobile_source_mesh_compaction"))
	var before:={}
	for cell in world._visual_cells: before[cell]=mesh_hash(world._visual_cells[cell].instance.mesh)
	var original_shape:=collision(world,"test/private").shape
	world.set_meta("mobile_memory_test",true)
	var result:=world._compact_mobile_source_meshes()
	check("mobile compacts private source resources",result.enabled and result.replaced==3 and view(world,"test/private").mesh!=private_source,result)
	check("private handles preserve CPU rebuild arrays and custom culling bounds",view(world,"test/private").mesh.get_surface_count()==0 and view(world,"test/private").mesh.custom_aabb==initial_bounds and world._mesh_array_cache.has(view(world,"test/private").mesh))
	check("externally visible Mesh and MultiMesh references are excluded",view(world,"test/shared").mesh==shared_source and view(world,"test/multi").mesh==multi_source and mesh_hash(outside.mesh)==source_hash and mesh_hash(outside_multi.multimesh.mesh)==source_hash)
	check("future library owners retain untouched original mesh geometry",mesh_hash(future_source)==source_hash and mesh_hash(private_source)==source_hash)
	var old_ref:WeakRef=weakref(private_source);private_source=null
	check("unowned original mesh is released after replacing cache key",old_ref.get_ref()==null)
	check("compaction is idempotent",world._compact_mobile_source_meshes().replaced==0)
	var array_hashes:={}
	for source in world._mesh_array_cache: array_hashes[source]=arrays_hash(world._mesh_array_cache[source])
	world.fail_compression=true
	var failed_compression:=world._compress_mobile_source_arrays()
	check("failed compression keeps every original rebuild Array",failed_compression.compressed_entries==0 and failed_compression.retained_entries==array_hashes.size() and world._mesh_array_cache.values().all(func(value):return value is Array))
	world.fail_compression=false
	var compressed:=world._compress_mobile_source_arrays()
	check("mobile cache stores smaller lossless payloads",compressed.compressed_entries==array_hashes.size() and compressed.saved_serialized_bytes>0,compressed)
	var arrays_identical:=true
	for source in world._mesh_array_cache:
		var decoded:={}
		var first:Array=world._mesh_arrays_for_cell(source,decoded)
		var second:Array=world._mesh_arrays_for_cell(source,decoded)
		arrays_identical=arrays_identical and arrays_hash(first)==array_hashes[source] and is_same(first,second) and decoded.size()==1
	check("decoded arrays are byte exact and shared only within a rebuild",arrays_identical)
	check("compressed cache still owns no original source Mesh and leaves protected geometry intact",old_ref.get_ref()==null and mesh_hash(shared_source)==source_hash and mesh_hash(multi_source)==source_hash)
	check("compression is idempotent",world._compress_mobile_source_arrays().compressed_entries==0)
	var identical:=true
	for cell in world._visual_cells:
		world._rebuild_visual_cell(cell,true)
		identical=identical and mesh_hash(world._visual_cells[cell].instance.mesh)==before[cell]
	check("all combined cells rebuild byte for byte from retained CPU arrays",identical)
	check("rebuilt cells never repopulate the global cache with raw Arrays",world._mesh_array_cache.values().all(func(value):return value is Dictionary and value.has("packed")))
	var private_handle:Mesh=view(world,"test/private").mesh
	var private_cell:Vector2i=world.structures["test/private"].cell
	var valid_payload:Dictionary=world._mesh_array_cache[private_handle]
	var invalid_bytes:=var_to_bytes(["not a mesh surface"])
	world._mesh_array_cache[private_handle]={"packed":invalid_bytes.compress(FileAccess.COMPRESSION_ZSTD),"raw_size":invalid_bytes.size(),"surfaces":1}
	var old_base:Mesh=world._visual_cells[private_cell].instance.mesh
	world._visual_cells[private_cell].detail.mesh=old_base
	world.facade_stream.resident[private_cell]=true
	var printed_errors:=Engine.print_error_messages
	Engine.print_error_messages=false # Deliberately exercise the production error fallback.
	world._rebuild_visual_cell(private_cell,true)
	Engine.print_error_messages=printed_errors
	check("invalid decoded geometry preserves both old cell meshes and stream residency",world._visual_cells[private_cell].instance.mesh==old_base and world._visual_cells[private_cell].detail.mesh==old_base and world.facade_stream.resident.has(private_cell))
	world._mesh_array_cache[private_handle]=valid_payload
	world.facade_stream.invalidate(private_cell)
	check("collision resource identity is unchanged",collision(world,"test/private").shape==original_shape)
	check("snapshot release waits for world completion",not world.release_mobile_map_snapshot().released)
	world._ready_complete=true
	check("snapshot release waits for occupancy cache",not world.release_mobile_map_snapshot().released)
	Map._shared_geometry={};Map.source_load_count=0
	var source_alias:Dictionary=world.map_snapshot
	var map:=Map.new();map.map_source=source_alias;root.add_child(map)
	check("injected map builds without parsing JSON and drops source reference",map.data_loaded and map.data_counts.buildings==1 and Map.source_load_count==0 and map.map_source.is_empty())
	var second:=Map.new();second.map_source=source_alias;root.add_child(second)
	check("cached map also drops its injected reference",second.map_source.is_empty() and second._building_mesh==map._building_mesh and Map.source_load_count==0)
	preload("res://scripts/map_migration.gd")._geometry(world)
	var release:=world.release_mobile_map_snapshot()
	check("snapshot compaction preserves counts trees and provenance",release.released and not world.map_snapshot.has("buildings") and not world.map_snapshot.has("roads") and world.map_snapshot.counts.buildings==1 and world.map_snapshot.trees.size()==1 and world.map_snapshot.attribution=="test provenance",release)
	check("snapshot aliases and shared facade recipes are never mutated",source_alias.has("buildings") and source_alias.buildings.size()==1 and world.structures["osm/way/990040001/storey_group/0"].surfaces[1].deferred_facade==record)
	check("occupancy remains usable after original snapshot release",preload("res://scripts/map_migration.gd")._geometry(world).mapped.size()==1)
	check("snapshot compaction is idempotent",not world.release_mobile_map_snapshot().released)
	var point:=Vector3(4800,15,4000)
	var loaded:bool=await drain(world,point)
	var facade_cell:Vector2i=world.structures["osm/way/990040001/storey_group/0"].cell
	check("real facade worker still builds after snapshot compaction",loaded and world._visual_cells[facade_cell].detail.mesh!=null)
	var untouched:=collision(world,"test/shared");untouched.disabled=true
	world.repair_all();await process_frame
	check("fresh-world repair is a strict no-op",untouched.disabled and world.bridge_refreshes==0 and world._dirty_cells.is_empty())
	untouched.disabled=false
	var id:="test/private"
	var cell:Vector2i=world.structures[id].cell
	world._destroy_component(id,Vector3.ZERO,100000,false)
	await process_frame;await physics_frame
	check("destroyed compacted structure leaves mesh and collision",world.destroyed.has(id) and collision(world,id).disabled and mesh_hash(world._visual_cells[cell].instance.mesh)!=before[cell])
	world.repair_all();await process_frame;await physics_frame
	check("repair restores exact compacted geometry and collider",world.destroyed.is_empty() and not collision(world,id).disabled and mesh_hash(world._visual_cells[cell].instance.mesh)==before[cell] and world.bridge_refreshes==0)
	world.apply_state({"destroyed":[id],"partial":{"test/future":.4},"rubble":[]})
	await process_frame;await physics_frame
	check("saved destroyed and partial state applies after compaction",world.destroyed.has(id) and world.partial_damage.has("test/future") and collision(world,id).disabled)
	world.repair_all();await process_frame;await physics_frame
	check("partial and destroyed repair restores both original materials",world.partial_damage.is_empty() and mesh_hash(world._visual_cells[cell].instance.mesh)==before[cell] and view(world,"test/future").material_override==world.materials.sandstone)
	world._destroy_component("bridge/deck/probe",Vector3.ZERO,100000,false)
	await process_frame
	var refreshes:=world.bridge_refreshes
	world.repair_all();await process_frame
	check("repair refreshes bridge physics only when a bridge component was affected",world.bridge_refreshes==refreshes+1)
	var rubble:=Node3D.new();world.add_child(rubble);world.rubble.append(rubble)
	world.repair_all();await process_frame
	check("rubble-only repair clears debris without rebuilding bridge",world.rubble.is_empty() and not is_instance_valid(rubble) and world.bridge_refreshes==refreshes+1)
	var desktop:=FixtureWorld.new();root.add_child(desktop);desktop._ready_complete=true;desktop.set_meta("map_migration_cache",{});desktop.map_snapshot={"buildings":[record]}
	check("desktop keeps the complete snapshot",not desktop.release_mobile_map_snapshot().enabled and desktop.map_snapshot.has("buildings"))
	check("desktop never enables CPU array compression",not desktop._compress_mobile_source_arrays().enabled)
	world.free();desktop.free();map.free();second.free();outside.free();outside_multi.free()
	var path:=ProjectSettings.globalize_path("res://../reports/mobile-world-memory.json")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures==0,"count":checks.size(),"failures":failures,"checks":checks},"\t"))
	print("MOBILE_WORLD_MEMORY_COMPLETE checks=",checks.size()," failures=",failures)
	quit(1 if failures else 0)
