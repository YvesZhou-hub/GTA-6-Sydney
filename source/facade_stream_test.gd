extends SceneTree
const City=preload("res://scripts/city_map.gd")
class FixtureWorld:
	extends "res://scripts/harbor_world.gd"
	func _ready() -> void:pass
var checks:Array=[]
var failures:=0
var worlds:Array=[]
func _initialize():call_deferred("run")
func verify(label:String,ok:bool,evidence:Dictionary={}) -> void:
	checks.append({"name":label,"passed":ok,"evidence":evidence});print("PASS " if ok else "FAIL ",label," ",JSON.stringify(evidence))
	if not ok:failures+=1
func record(id:String,point:Vector2,usage:String="office",half:float=6.0) -> Dictionary:
	var outline:Array=[[-half,-half],[half,-half],[half,half],[-half,half]]
	return {"id":id,"center":[point.x,point.y],"outline":outline,"roof":[outline[0],outline[1],outline[2],outline[0],outline[2],outline[3]],"holes":[],"height":15.0,"base":0.0,"height_source":"bounded streaming test prism, not map data","tags":{"building":usage}}
func build_world(records:Array):
	var world:=FixtureWorld.new();root.add_child(world);worlds.append(world)
	world.set_meta("stream_details",true)
	for key in ["steel","lightstone","rubble","sandstone"]:world._mat(key,Color(.5,.5,.5))
	City.build_buildings(world,{"buildings":records});world._build_structure_batches();world._ready_complete=true
	return world
func cell_for(world,id:String) -> Vector2i:return world.structures[id].cell
func id_for(item:Dictionary) -> String:return "osm/%s/storey_group/0"%item.id
func cell_point(cell:Vector2i) -> Vector3:return Vector3((cell.x+.5)*160,15,(cell.y+.5)*160)
func descriptors_only(world) -> bool:
	for structure:Dictionary in world.structures.values():
		for surface:Dictionary in structure.surfaces:
			if surface.get("near",false) and surface.has("arrays"):return false
	return true
func drain_at(world,point:Vector3,max_frames:int=1600) -> bool:
	for i in max_frames:
		world.stream_view(point,Vector3.ZERO,.16)
		var stream=world.facade_stream
		var complete:bool=stream._task<0
		for cell:Vector2i in stream.wanted:complete=complete and stream.resident.has(cell)
		if complete:return true
		await process_frame
	return false
func finish_current(stream) -> bool:
	for i in 1600:
		if stream._task<0:return true
		if WorkerThreadPool.is_task_completed(stream._task):stream._commit_ready();return stream._task<0
		await process_frame
	return false
func collision(world,id:String) -> CollisionShape3D:
	for child in world.structures[id].node.get_children():
		if child is CollisionShape3D:return child
	return null
func ray(world,position:Vector3) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(position+Vector3.UP*30,position-Vector3.UP*2)
	return world.get_world_3d().direct_space_state.intersect_ray(query)
func mesh_vertices(mesh:Mesh) -> int:
	if mesh==null:return 0
	var count:=0
	for i in mesh.get_surface_count():count+=mesh.surface_get_array_len(i)
	return count
func run() -> void:
	var first:=record("way/990010001",Vector2(4080,4080),"office")
	var second:=record("way/990010002",Vector2(4110,4080),"apartments")
	var far:=record("way/990010003",Vector2(8080,4080),"warehouse")
	var real_small:Dictionary={}
	for item:Dictionary in City.data().buildings:
		if item.id=="way/556844015":real_small=item;break
	verify("known real tiny footprint is present in current city source",not real_small.is_empty())
	if real_small.is_empty():real_small=record("way/990010004",Vector2(1068,1616),"office",.5)
	var world=build_world([first,second,far,real_small]);var stream=world.facade_stream
	await physics_frame;await physics_frame
	var first_id:=id_for(first);var second_id:=id_for(second);var far_id:=id_for(far);var small_id:=id_for(real_small)
	var first_cell:=cell_for(world,first_id);var far_cell:=cell_for(world,far_id);var small_cell:=cell_for(world,small_id)
	var base:Mesh=world._visual_cells[first_cell].instance.mesh;var base_id:=base.get_instance_id()
	var shape:CollisionShape3D=collision(world,first_id);var shape_id:=shape.shape.get_instance_id();var node_id:int=world.structures[first_id].node.get_instance_id()
	var initial_clear:=true
	for cell:Vector2i in world._visual_cells:initial_clear=initial_clear and world._visual_cells[cell].detail.mesh==null
	verify("initial city build stores deferred descriptors without generating near arrays",initial_clear and descriptors_only(world) and stream.resident.is_empty() and stream._task<0)
	verify("base facade mesh collision and stable damage IDs already exist",base!=null and shape!=null and not shape.disabled and world.structures.has(first_id) and world.structures[first_id].node.get_meta("damage_id")==first_id)
	var uv2_seen:Dictionary={};var uv2_valid:=true
	for i in base.get_surface_count():
		var arrays:Array=base.surface_get_arrays(i);var uv2:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
		uv2_valid=uv2_valid and uv2.size()==arrays[Mesh.ARRAY_VERTEX].size()
		for value in uv2:uv2_seen["%s/%s"%[roundi(value.x*10000),roundi(value.y)]]=true
	var a_key:="%s/0"%posmod(str(first.id).hash(),10000);var b_key:="%s/1"%posmod(str(second.id).hash(),10000)
	verify("same-material batching retains distinct immutable OSM UV2 IDs and usage",uv2_valid and uv2_seen.has(a_key) and uv2_seen.has(b_key) and uv2_seen.size()==2,{"observed":uv2_seen.keys()})
	var first_hit:=ray(world,Vector3(4080,4.5,4080))
	verify("real production physics hits the base shell before detail streaming",not first_hit.is_empty() and first_hit.collider==world.structures[first_id].node)
	var loaded:bool=await drain_at(world,cell_point(first_cell))
	verify("distance tick builds nearby relief using a real worker and combined mesh",loaded and stream.resident.has(first_cell) and mesh_vertices(world._visual_cells[first_cell].detail.mesh)>0 and stream.builds>0,stream.stats())
	verify("distant cells keep detail unloaded",not stream.resident.has(far_cell) and world._visual_cells[far_cell].detail.mesh==null)
	verify("completed uploads release CPU near arrays but retain source descriptors",descriptors_only(world) and world.structures[first_id].surfaces[1].has("deferred_facade"))
	var detail_vertices:=mesh_vertices(world._visual_cells[first_cell].detail.mesh)
	var away:bool=await drain_at(world,cell_point(far_cell))
	verify("moving beyond retain radius unloads old relief and loads destination",away and not stream.resident.has(first_cell) and world._visual_cells[first_cell].detail.mesh==null and stream.resident.has(far_cell))
	verify("detail eviction preserves exact base mesh collider resource and structure ID",world._visual_cells[first_cell].instance.mesh.get_instance_id()==base_id and collision(world,first_id).shape.get_instance_id()==shape_id and world.structures[first_id].node.get_instance_id()==node_id and not shape.disabled)
	verify("evicted base shell still supports actual physics queries",not ray(world,Vector3(4080,4.5,4080)).is_empty())
	var back:bool=await drain_at(world,cell_point(first_cell))
	verify("returning regenerates the same combined relief geometry",back and mesh_vertices(world._visual_cells[first_cell].detail.mesh)==detail_vertices)
	world._destroy_component(first_id,Vector3(4080,10,4080),1000000,false)
	await process_frame;await physics_frame
	verify("production destruction immediately invalidates resident detail and collision",world.destroyed.has(first_id) and not stream.resident.has(first_cell) and shape.disabled)
	await drain_at(world,cell_point(far_cell));await drain_at(world,cell_point(first_cell))
	var reduced:=mesh_vertices(world._visual_cells[first_cell].detail.mesh)
	verify("destroyed component stays absent after unload and reload while intact neighbor remains",world.destroyed.has(first_id) and not world.structures[first_id].node.visible and shape.disabled and reduced>0 and reduced<detail_vertices and not collision(world,second_id).disabled,{"before_vertices":detail_vertices,"after_vertices":reduced})
	verify("destroyed base shell does not reappear in physics",ray(world,Vector3(4080,4.5,4080)).is_empty())
	var empty_arrays:=City._facade_relief(real_small,real_small.base,real_small.get("wall_height",real_small.height))
	verify("real narrow footprint returns genuinely empty relief arrays",empty_arrays[Mesh.ARRAY_VERTEX]==null or empty_arrays[Mesh.ARRAY_VERTEX].is_empty(),{"source_id":real_small.id})
	var tiny:bool=await drain_at(world,cell_point(small_cell))
	verify("empty worker result completes cleanly without uploading an empty mesh",tiny and stream.resident.has(small_cell) and world._visual_cells[small_cell].detail.mesh==null and world._visual_cells[small_cell].instance.mesh!=null)
	var after_empty:int=stream.builds
	for i in 8:world.stream_view(cell_point(small_cell),Vector3.ZERO,.16)
	verify("empty relief is remembered so the same cell is not rebuilt every frame",stream.builds==after_empty and stream._task<0)
	# A request is dispatched, then planning jumps before _commit_ready runs.
	world.stream_view(cell_point(far_cell),Vector3.ZERO,.16)
	verify("fast-jump regression starts with a real pending worker",stream._task>=0 and stream._task_cell==far_cell)
	world.stream_view(cell_point(first_cell),Vector3.ZERO,.16)
	var jump:bool=await drain_at(world,cell_point(first_cell))
	verify("completed old worker cannot commit after a fast camera jump",jump and not stream.resident.has(far_cell) and world._visual_cells[far_cell].detail.mesh==null and stream.resident.has(first_cell))
	await drain_at(world,Vector3(4080,950,4080))
	verify("high altitude evicts all near detail while base shell and IDs remain",stream.resident.is_empty() and stream.wanted.is_empty() and world._visual_cells[first_cell].instance.mesh!=null and world.structures.has(second_id))
	world.stream_view(cell_point(far_cell),Vector3.ZERO,.16);var pending_before:int=stream._task
	stream.close()
	verify("close safely joins a pending worker and releases world/output references",pending_before>=0 and stream._task<0 and stream._output.is_empty() and stream.world==null)
	world.free();worlds.erase(world)
	await capacity_checks()
	var folder:=ProjectSettings.globalize_path("res://../reports/facade-stream");DirAccess.make_dir_recursive_absolute(folder)
	var report:={"passed":failures==0,"count":checks.size(),"failures":failures,"checks":checks,"gpu_run":false,"full_city_run":false,"actual_worker_thread_pool":true,"actual_city_builder":true,"hashes":{}}
	for path in ["res://scripts/facade_stream.gd","res://scripts/city_map.gd","res://scripts/harbor_world.gd","res://../source/facade_stream_test.gd"]:report.hashes[path]=FileAccess.get_sha256(path)
	FileAccess.open(folder+"/checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	for remaining in worlds:if is_instance_valid(remaining):remaining.free()
	print("FACADE_STREAM_COMPLETE checks=",checks.size()," failures=",failures);quit(1 if failures else 0)

func capacity_checks() -> void:
	var records:Array=[]
	for i in 66:records.append(record("way/%s"%(990020000+i),Vector2(16080+i*160,8080)))
	var world=build_world(records);var stream=world.facade_stream
	var cells:Array[Vector2i]=[]
	for item:Dictionary in records:cells.append(cell_for(world,id_for(item)))
	# Upload 64 actual generated cell meshes. Suppress the next 150ms planning
	# pass to reproduce a full retained cache immediately before a commit.
	var complete:=true;var maximum:=0
	for cell:Vector2i in cells.slice(0,64):
		stream.wanted.assign([cell]);stream._clock=1.0
		stream.tick(cell_point(cell),Vector3.ZERO,0.0)
		complete=complete and await finish_current(stream)
		maximum=maxi(maximum,stream.resident.size())
	verify("64-cell retained cache uses real uploaded worker meshes",complete and stream.resident.size()==64 and maximum==64,{"resident":stream.resident.size(),"maximum":maximum})
	var replacement:Vector2i=cells[64]
	stream.wanted.assign([replacement]);stream._clock=1.0;stream.tick(cell_point(replacement),Vector3.ZERO,0.0)
	var replaced:bool=await finish_current(stream)
	verify("new commit evicts an unneeded cell before exceeding the hard 64 limit",replaced and stream.resident.size()==64 and stream.resident.has(replacement) and stream.evictions>0,{"resident":stream.resident.size(),"evictions":stream.evictions})
	var mesh_count:=0
	for cell:Vector2i in cells:mesh_count+=int(world._visual_cells[cell].detail.mesh!=null)
	verify("hard cache limit counts actual live detail meshes as well as dictionary entries",mesh_count==64,{"actual_detail_meshes":mesh_count})
	# All 64 live entries are wanted: reject an extra completed job instead of
	# silently replacing one of those wanted entries or growing the cache.
	stream.wanted.assign(stream.resident.keys());var extra:Vector2i=cells[65];stream.wanted.append(extra)
	var rid:=id_for(records[65]);var descriptor:Dictionary=world.structures[rid].surfaces[1]
	stream._task_cell=extra
	stream._task=WorkerThreadPool.add_task(stream._produce.bind([{"id":rid,"index":1,"item":descriptor.deferred_facade,"bottom":descriptor.bottom,"top":descriptor.top}]),false,"Adversarial full facade cache")
	await finish_current(stream)
	verify("completed job is rejected when every resident slot is still wanted",stream.resident.size()==64 and not stream.resident.has(extra) and world._visual_cells[extra].detail.mesh==null and stream._output.is_empty())
	verify("capacity rejection does not retain uploaded CPU arrays",descriptors_only(world))
	stream.close();world.free();worlds.erase(world)
