extends SceneTree
## Production-world parked H160 clearance includes rendered foliage, not only physics bodies.
const Spawn=preload("res://scripts/vehicle_spawn.gd")
var checks:Array=[]
var details:Dictionary={}
func _initialize():call_deferred("run")
func check(name:String,passed:bool):
	checks.append({"name":name,"passed":passed});print(("PASS " if passed else "FAIL ")+name)
func horizontal_distance(bounds:AABB,point:Vector3)->float:
	return Vector2(clampf(point.x,bounds.position.x,bounds.end.x),clampf(point.z,bounds.position.z,bounds.end.z)).distance_to(Vector2(point.x,point.z))
func physics_obstructions(game,body)->Array:
	var bounds:AABB=Spawn.envelope(body)
	var shape:=BoxShape3D.new();shape.size=bounds.size
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape
	query.transform=body.global_transform*Transform3D(Basis.IDENTITY,bounds.get_center())
	query.exclude=[body.get_rid(),game.player.get_rid()]
	var blockers:Array=[]
	for hit in game.get_world_3d().direct_space_state.intersect_shape(query,64):
		# Wheel/ground contact is expected. A support entirely below the real
		# helipad collision top is allowed; a wall/tree/body is not.
		var support_only:bool=hit.collider is StaticBody3D
		for node in hit.collider.get_children():
			if node is CollisionShape3D and not node.disabled:
				var contact_bounds:AABB=node.global_transform*node.shape.get_debug_mesh().get_aabb()
				support_only=support_only and contact_bounds.end.y<=game.world.anchors.helipad.y-.2+.01
		if not support_only:blockers.append(str(hit.collider.get_meta("damage_id",hit.collider.name)))
	return blockers
func separated(axis:Vector3,a:Vector3,b:Vector3,c:Vector3,half:Vector3)->bool:
	if axis.length_squared()<.0000000001:return false
	var aa:=axis.dot(a);var bb:=axis.dot(b);var cc:=axis.dot(c);var radius:=half.dot(axis.abs())
	return minf(aa,minf(bb,cc))>radius+.00001 or maxf(aa,maxf(bb,cc)) < -radius-.00001
func triangle_box(a:Vector3,b:Vector3,c:Vector3,box:AABB)->bool:
	var half:=box.size*.5;var center:=box.get_center();a-=center;b-=center;c-=center
	if separated(Vector3.RIGHT,a,b,c,half) or separated(Vector3.UP,a,b,c,half) or separated(Vector3.BACK,a,b,c,half):return false
	var edges:Array[Vector3]=[b-a,c-b,a-c]
	if separated(edges[0].cross(edges[1]),a,b,c,half):return false
	for edge in edges:
		for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
			if separated(edge.cross(axis),a,b,c,half):return false
	return true
func default_airliner(game)->Dictionary:
	var plane=game.vehicles.filter(func(v):return v.kind=="airliner")[0]
	var query:=PhysicsShapeQueryParameters3D.new();query.exclude=[plane.get_rid(),game.player.get_rid()];query.margin=.001;query.collision_mask=15
	var shape:=BoxShape3D.new();var envelope:AABB=Spawn.envelope(plane);shape.size=envelope.size
	query.shape=shape;query.transform=plane.global_transform*Transform3D(Basis.IDENTITY,envelope.get_center())
	var broad:Array=game.get_world_3d().direct_space_state.intersect_shape(query,128)
	var physical_hits:Array=[]
	for node in plane.find_children("*","CollisionShape3D",true,false):
		if node.disabled:continue
		query.shape=node.shape;query.transform=node.global_transform
		for hit in game.get_world_3d().direct_space_state.intersect_shape(query,128):physical_hits.append(str(hit.collider.get_path()))
	check("default 787 original parking has no physical shape intersections",physical_hits.is_empty())
	var triangles:Array=[]
	for node in plane.find_children("*","MeshInstance3D",true,false):
		if node.top_level or node.mesh==null:continue
		for surface in node.mesh.get_surface_count():
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var count:=indices.size() if not indices.is_empty() else points.size()
			for i in range(0,count,3):
				var tri:Array[Vector3]=[]
				for j in 3:tri.append(node.global_transform*points[indices[i+j] if not indices.is_empty() else i+j])
				triangles.append(tri)
	var candidates:Array=[];var intersections:=0
	for hit in broad:
		var collider:CollisionObject3D=hit.collider
		var node=collider.shape_owner_get_owner(collider.shape_find_owner(hit.shape))
		var box:AABB=node.shape.get_debug_mesh().get_aabb()
		var inverse:Transform3D=node.global_transform.affine_inverse()
		var crossings:=0
		for triangle in triangles:
			if triangle_box(inverse*triangle[0],inverse*triangle[1],inverse*triangle[2],box):crossings+=1
		intersections+=crossings
		candidates.append({"collider":str(game.get_path_to(collider)),"shape_type":node.shape.get_class(),"tested_visual_triangles":triangles.size(),"visual_triangle_intersections":crossings})
	check("default 787 full visible mesh clears every broad-envelope building candidate",intersections==0)
	var unit:=AABB(-Vector3.ONE,Vector3.ONE*2)
	check("triangle-box check distinguishes crossing inside and outside triangles",triangle_box(Vector3.ZERO,Vector3(.5,0,0),Vector3(0,.5,0),unit) and triangle_box(Vector3(-2,0,0),Vector3(2,0,0),Vector3(0,2,0),unit) and not triangle_box(Vector3(-3,0,0),Vector3(-2,0,0),Vector3(-2,1,0),unit))
	return {"position":[plane.position.x,plane.position.y,plane.position.z],"heading":plane.rotation.y,"physical_intersections":physical_hits,"visual_triangle_count":triangles.size(),"broad_envelope_candidates":candidates,"visual_triangle_intersections":intersections}
func run():
	var game=load("res://scripts/main.gd").new();game.qa_running=true;root.add_child(game)
	game.new_world("sandbox","QA Helipad Crown Clearance",false);game.set_process(false);game.player.enabled=false
	var world=game.world;var pad:Vector3=world.anchors.helipad
	var heli
	for body in game.vehicles:
		if body.kind=="helicopter":heli=body
		else:body.freeze=true
	check("default production H160 starts at authored helipad",heli!=null and Vector2(heli.position.x,heli.position.z).distance_to(Vector2(pad.x,pad.z))<.01)
	if heli==null:quit(1);return
	check("tree trunk outside 55 m still rejected when crown crosses boundary",world._tree_canopy_intersects_helipad(pad+Vector3(59,0,0),1))
	check("complete crown beyond boundary is retained",not world._tree_canopy_intersects_helipad(pad+Vector3(61,0,0),1))
	check("large mapped crown uses its actual scale",world._tree_canopy_intersects_helipad(pad+Vector3(64,0,0),2))
	var before_batches:int=world._batch_foliage.size()
	check("authored tree entry point also refuses helipad vegetation",not world._tree(pad,1) and world._batch_foliage.size()==before_batches)
	await physics_frame;await physics_frame
	var vehicle_bounds:AABB=heli.global_transform*Spawn.envelope(heli)
	var near_count:=0;var overlap_count:=0;var crown_count:=0;var minimum:=INF;var nearest_origin:=Vector3.ZERO
	# The headless rendering backend returns zero MultiMesh transforms. Inspect
	# the exact nearby crown bounds recorded when the production renderer batch
	# receives each transform, and require nonzero positions as a readback guard.
	for bounds:AABB in world.get_meta("helipad_retained_crown_bounds",[]):
		crown_count+=1
		var distance:=horizontal_distance(bounds,pad)
		if distance<minimum:minimum=distance;nearest_origin=bounds.get_center()
		if distance<=55:near_count+=1
		if bounds.intersects(vehicle_bounds):overlap_count+=1
	check("actual nearby crown render inputs remain outside 55 m operation area",crown_count>0 and near_count==0 and minimum<75 and nearest_origin.length()>10)
	check("complete helicopter visual and collision envelope has no tree-crown overlap",overlap_count==0)
	var plots_clear:=true
	for list in [world._building_plots,world._distant_visual_plots]:
		for plot in list:plots_clear=plots_clear and not vehicle_bounds.intersects(plot)
	check("complete helicopter envelope is clear of mapped building volumes",plots_clear)
	var adjustment:Dictionary=world.get_meta("helipad_vegetation_adjustment")
	check("game-only foliage omissions retain source node IDs",adjustment.omitted_mapped_trees.size()>0 and adjustment.omitted_mapped_trees.all(func(t):return str(t.id).begins_with("node/")))
	await physics_frame;await physics_frame
	var initial_blockers:=physics_obstructions(game,heli)
	check("production full envelope has no non-support physics obstruction",initial_blockers.is_empty())
	var minimum_health:float=heli.health
	for i in 360:
		await physics_frame
		minimum_health=minf(minimum_health,heli.health)
	check("default helicopter settles six seconds with 100 health",is_equal_approx(minimum_health,100.0) and is_equal_approx(heli.health,100.0))
	check("settled helicopter has no impact event",heli.last_impact_info.is_empty())
	var final_blockers:=physics_obstructions(game,heli)
	check("settled full envelope remains clear except wheel support",final_blockers.is_empty())
	var airliner:Dictionary=default_airliner(game)
	details={"nearby_crown_render_inputs_examined":crown_count,"tree_bounds_source":"Exact production foliage batch inputs within 75 m; headless MultiMesh readback is intentionally not used.","nearest_crown_bound_to_pad_m":minimum,"nearest_crown_origin":[nearest_origin.x,nearest_origin.y,nearest_origin.z],"heli_envelope_position":[vehicle_bounds.position.x,vehicle_bounds.position.y,vehicle_bounds.position.z],"heli_envelope_size":[vehicle_bounds.size.x,vehicle_bounds.size.y,vehicle_bounds.size.z],"initial_physics_obstructions":initial_blockers,"final_physics_obstructions":final_blockers,"minimum_health":minimum_health,"final_health":heli.health,"vegetation_adjustment":adjustment,"default_airliner":airliner}
	var okay:bool=checks.all(func(c):return c.passed)
	FileAccess.open("res://../reports/helipad-clearance-v013.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":okay,"checks":checks,"details":details,"user_saves_touched":false},"  "))
	print("HELIPAD_CLEARANCE checks=",checks.size()," passed=",okay," details=",JSON.stringify(details))
	game.active=false;game.queue_free();await process_frame;quit(0 if okay else 1)
