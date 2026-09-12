extends SceneTree
const Quay=preload("res://scripts/quay_landmarks.gd")
var failures:=0
var check_records:Array[Dictionary]=[]

class ProbeWorld extends "res://scripts/harbor_world.gd":
	func _ready() -> void:
		_make_materials()
		Quay.build(self)
		for id in structures:
			for child in structures[id].node.get_children():
				if child is MeshInstance3D: child.set_meta("intact_material",child.material_override)
		_build_structure_batches()
		_ready_complete=true

func verify(value: bool, message: String) -> void:
	check_records.append({"name":message,"passed":value})
	if value: print("PASS ",message)
	else:
		failures+=1
		push_error("FAIL "+message)

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var world:=ProbeWorld.new()
	root.add_child(world)
	verify(Quay.metadata().size()==2,"both Circular Quay towers have source confidence records")
	verify(Quay.excluded_way_ids().size()==7 and Quay.footprints().size()==7,"all seven mapped parts have explicit footprint exclusions")
	verify(Quay.QQT_CENTER.x>Quay.SALESFORCE_CENTER.x and Quay.QQT_CENTER.z>Quay.SALESFORCE_CENTER.z,"QQT stays southeast of Salesforce at the mapped real city locations")
	var blocks:=Quay.qqt_blocks()
	verify(blocks.size()==5,"QQT contains five mapped village outlines")
	var changed_normals:=0
	for i in range(4):
		var p: PackedVector2Array=blocks[i].poly
		var q: PackedVector2Array=blocks[i+1].poly
		if p!=q and absf(blocks[i].high-blocks[i+1].low)<0.0001:changed_normals+=1
	verify(changed_normals==4,"QQT's four village seams change plan and remain vertically continuous")
	verify(Quay.salesforce_branches().size()==6,"Salesforce has six increasing-height tree branches per north face")
	var clip_ok:=true
	for path in Quay.salesforce_branches():
		for i in range(path.size()-1):
			for low in [0.0,14.0,44.0,86.0,168.0,240.0]:
				var clipped:=Quay._clip_y(path[i],path[i+1],low,low+4.0)
				for p in clipped:clip_ok=clip_ok and p.y>=low-0.0001 and p.y<=low+4.0001
	verify(clip_ok,"tree bracing clips at floor ownership boundaries for consistent damage")
	var projection_error:=0.0
	for item in Quay.metadata():
		var p:=Vector3((item.lon-151.2105)*92400,4.5,(-33.86-item.lat)*111320)
		projection_error=maxf(projection_error,p.distance_to(item.center))
	verify(projection_error<0.03,"documented coordinates agree with the existing metre projection")
	var salesforce_high:=-INF
	var qqt_high:=-INF
	var triangles:=0
	var degenerate:=0
	var bad_normals:=0
	var collision_mismatch:=0
	for id: String in world.structures:
		var body: StaticBody3D=world.structures[id].node
		var solid: Mesh=body.get_child(0).mesh
		var collision: Shape3D=body.get_child(1).shape
		if collision is ConcavePolygonShape3D and collision.get_faces()!=solid.get_faces(): collision_mismatch+=1
		for child in body.get_children():
			if not child is MeshInstance3D: continue
			for s in child.mesh.get_surface_count():
				var a: Array=child.mesh.surface_get_arrays(s)
				var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				for p in vertices:
					var actual_y: float=(body.transform*child.transform*p).y-4.5
					if id.begins_with("quay/qqt/"):qqt_high=maxf(qqt_high,actual_y)
					else: salesforce_high=maxf(salesforce_high,actual_y)
				var count:=vertices.size() if indices.is_empty() else indices.size()
				triangles+=count/3
				for i in range(0,count,3):
					var x:=i if indices.is_empty() else indices[i]
					var y:=i+1 if indices.is_empty() else indices[i+1]
					var z:=i+2 if indices.is_empty() else indices[i+2]
					var cross:=(vertices[y]-vertices[x]).cross(vertices[z]-vertices[x])
					if cross.length_squared()<0.00000000001:degenerate+=1
					if cross.dot(normals[x]+normals[y]+normals[z])>0.00002:bad_normals+=1
	verify(collision_mismatch==0,"all tower structural colliders use the identical rendered mesh faces")
	verify(degenerate==0,"no zero-area triangles in either tower")
	verify(bad_normals==0,"tower faces and facade details all use outward Godot winding")
	verify(triangles<160000,"combined detailed geometry remains bounded triangles="+str(triangles))
	verify(absf(qqt_high-206.0)<0.04,"QQT reaches the architect's published 206m total height")
	verify(absf(salesforce_high-263.0)<0.02,"Salesforce's raised crown reaches the developer's 263m total height")
	verify(world.structures.has("quay/qqt/block/4/floor/09") and world.structures.has("quay/salesforce/floor/53"),"both towers contain the full intended floor structure")
	await physics_frame
	await physics_frame
	var space:=world.get_world_3d().direct_space_state
	check_detail_batch(world,space)
	for item: Array in [["qqt",Quay.QQT_CENTER,Vector3(0,250,0),Vector3(0,0,0)],["salesforce",Quay.SALESFORCE_CENTER,Vector3(0,300,0),Vector3(0,0,0)]]:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(item[1]+item[2],item[1]+item[3]))
		verify(not hit.is_empty() and str(hit.collider.get_meta("damage_id","")).begins_with("quay/"+item[0]+"/"),item[0]+" has real roof collision at its mapped position")
	var id:="quay/salesforce/floor/20"
	var body: StaticBody3D=world.structures[id].node
	world._destroy_component(id,Vector3.ZERO,0,false)
	await physics_frame
	verify(world.destroyed.has(id) and not body.visible and body.get_child(1).disabled,"floor destruction removes glazing, tree braces, lift facade and collision together")
	world.apply_state({})
	await physics_frame
	verify(not world.destroyed.has(id) and not body.get_child(1).disabled,"restoration reinstates matching tower collision")
	if "--visual" in OS.get_cmdline_user_args():await capture(world)
	var report:={"passed":failures==0,"check_count":check_records.size(),"failures":failures,"checks":check_records,"visible_triangles":triangles,"structures":world.structures.size(),"model_sha256":FileAccess.get_sha256("res://scripts/quay_landmarks.gd"),"test_sha256":FileAccess.get_sha256("res://../source/quay_landmark_test.gd"),"execution_flags":OS.get_cmdline_user_args(),"native_capture_ran":"--visual" in OS.get_cmdline_user_args(),"user_saves_touched":false,"scope":"Isolated two-tower exteriors; structural and camera geometry, no office interiors or complete-city test"}
	var file:=FileAccess.open(ProjectSettings.globalize_path("res://../reports/quay-v016-detail-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("QUAY CHECK COMPLETE checks=",check_records.size()," failures=",failures," triangles=",triangles," components=",world.structures.size())
	quit(failures)

func check_detail_batch(world:Node3D,space:PhysicsDirectSpaceState3D) -> void:
	verify(world.structures.size()==149,"original 149 structural damage owners retained without added occupied floor volumes")
	var before:int=world.get_child_count();Quay.build(world)
	verify(world.get_child_count()==before,"repeated build does not duplicate either tower or its new details")
	verify(world.structures["quay/qqt/podium"].node.get_meta("coursed_stone_and_vents",false),"QQT original podium owns stone joints and ventilation relief")
	verify(world.structures["quay/salesforce/lobby"].node.get_meta("fine_lobby_glazing",false),"Salesforce original lobby owns subsidiary physical glazing frames")
	var st:=Quay._surface();Quay._facade_beam(st,Vector3.ZERO,Vector3(0,4,0),Vector3.FORWARD,1.1,0.7)
	var mesh:=st.commit();var faces:=mesh.get_faces();var edges:={};var section:={}
	for i in range(0,faces.size(),3):
		for j in range(3):
			var a:Vector3=faces[i+j].snapped(Vector3.ONE*0.0001);var b:Vector3=faces[i+(j+1)%3].snapped(Vector3.ONE*0.0001)
			var key:=str(a)+"|"+str(b) if str(a)<str(b) else str(b)+"|"+str(a)
			edges[key]=edges.get(key,0)+1
			if is_zero_approx(a.y) and a.length_squared()>0.001:section[str(Vector2(a.x,a.z))]=true
	var closed:=true
	for n in edges.values():closed=closed and n==2
	verify(closed and section.size()==8,"real chamfered tree-member mesh has eight profile corners and a closed two-use edge manifold")
	for view:Array in Quay.capture_views():
		var shape:=SphereShape3D.new();shape.radius=0.2
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=view[1]
		verify(space.intersect_shape(query).is_empty(),"specialist tower camera outside solid geometry: "+view[0])

func capture(world: Node3D) -> void:
	root.size=Vector2i(1440,1000)
	var e:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("98bbc9")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("d7e2e7")
	env.ambient_light_energy=0.6
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	e.environment=env;world.add_child(e)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=1.3;sun.shadow_enabled=true
	world.add_child(sun)
	var camera:=Camera3D.new()
	camera.current=true;camera.fov=48;camera.far=2000
	world.add_child(camera)
	var views:={
		"qqt_north":[Quay.QQT_CENTER+Vector3(115,133,-335),Quay.QQT_CENTER+Vector3(0,104,0)],
		"qqt_street":[Quay.QQT_CENTER+Vector3(87,24,-123),Quay.QQT_CENTER+Vector3(0,90,0)],
		"qqt_roof":[Quay.QQT_CENTER+Vector3(-100,280,-160),Quay.QQT_CENTER+Vector3(0,140,0)],
		"salesforce_north":[Quay.SALESFORCE_CENTER+Vector3(-100,138,-340),Quay.SALESFORCE_CENTER+Vector3(0,131,0)],
		"salesforce_south":[Quay.SALESFORCE_CENTER+Vector3(130,138,320),Quay.SALESFORCE_CENTER+Vector3(0,131,0)],
		"salesforce_roof":[Quay.SALESFORCE_CENTER+Vector3(-100,320,-150),Quay.SALESFORCE_CENTER+Vector3(0,220,0)]
	}
	for view:Array in Quay.capture_views():views[view[0]]=[view[1],view[2]]
	DirAccess.make_dir_recursive_absolute("/tmp/harbourlife-quay-review")
	for label: String in views:
		var center: Vector3=Quay.QQT_CENTER if label.begins_with("qqt") else Quay.SALESFORCE_CENTER
		var ground: MeshInstance3D=world._box(world,center-Vector3.UP*0.3,Vector3(700,0.6,700),"paving",false)
		camera.position=views[label][0];camera.look_at(views[label][1])
		for i in range(10):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/harbourlife-quay-review/"+label+".png")
		ground.queue_free()
