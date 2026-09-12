extends SceneTree
const Facilities=preload("res://scripts/darling_public_facilities.gd")
const Businesses=preload("res://scripts/darling_precinct_businesses.gd")
const Square=preload("res://scripts/darling_square_detail.gd")
const Fronts=preload("res://scripts/darling_square_frontages.gd")
class LocalWorld:
	extends "res://scripts/harbor_world.gd"
	func _ready():
		_make_materials()
		map_snapshot=CityMap.data().duplicate()
		map_snapshot.buildings=map_snapshot.buildings.filter(func(b):return b.center[0]>-960 and b.center[0]<-630 and b.center[1]>1480 and b.center[1]<2180)
		map_snapshot.roads=map_snapshot.roads.filter(func(b):
			for p in b.points:
				if p[0]>-990 and p[0]<-590 and p[1]>1450 and p[1]<2200:return true
			return false)
		CityMap.build_terrain(self,map_snapshot)
		CityMap.build_roads(self,map_snapshot)
		CityMap.build_buildings(self,map_snapshot)
		load("res://scripts/city_landmarks.gd")._materials(self)
		load("res://scripts/city_landmarks.gd")._exchange(self)
		Fronts.build(self);Square.build(self)
		_flush_batches()
		_ready_complete=true
var world:Node3D
var checks:Array=[]
var blocked:Array=[]
var mesh_index_records:Array=[]
var capsule:=CapsuleShape3D.new()
var output_dir:="res://../reports/darling-v014"
func _initialize():call_deferred("run")
func check(name:String,passed:bool,detail=""):
	checks.append({"name":name,"passed":passed,"detail":detail})
	print("PASS " if passed else "FAIL ",name," ",detail if not passed else "")
func clear(p:Vector3)->bool:
	var q:=PhysicsShapeQueryParameters3D.new();q.shape=capsule;q.transform.origin=p+Vector3.UP*1.10
	var result=world.get_world_3d().direct_space_state.intersect_shape(q)
	if not result.is_empty():blocked.append({"point":[p.x,p.y,p.z],"colliders":result.map(func(h):return str(h.collider.get_meta("damage_id",h.collider.name)))})
	return result.is_empty()
func supported(p:Vector3)->bool:
	return not world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.35,p-Vector3.UP*.30)).is_empty()
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-dir="):output_dir=arg.trim_prefix("--report-dir=")
	capsule.radius=.30;capsule.height=1.8
	world=LocalWorld.new();root.add_child(world)
	await physics_frame;await physics_frame
	check("Local precinct reaches READY",world._ready_complete)
	check("71 official directory records retained",Businesses.directory().tenants.size()==71)
	var counts:Dictionary=Businesses.directory().coverage_counts
	check("All records classified without claiming 71 exact facades",counts.existing_researched_frontage==15 and counts.mapped_inferred_frontage==23 and counts.exchange_building_directory==14 and counts.directory_only_unresolved==18 and counts.directory_conflict_unresolved==1)
	check("23 new mapped street facades",Businesses.frontages().size()==23)
	check_photo_frontages()
	check("18 mapped playground elements retained",Facilities.data().equipment.size()+Facilities.data().areas.size()==18)
	check("Square and Quarter geographically distinct",Facilities.point("node/10590136162").distance_to(Vector3(-770,4.5,2020))>350)
	var before:int=world.structures.size();Facilities.build(world);Businesses.build(world)
	check("New modules are idempotent",before==world.structures.size())
	for m in Facilities.metadata()+Businesses.metadata():
		check(m.id+" supported clear public arrival",clear(m.arrival) and supported(m.arrival),str(m.arrival))
		check(m.id+" anchor uses arrival, not interior centre",world.anchors[m.id].is_equal_approx(m.arrival))
	for route in Facilities.walk_routes():
		if route.id=="darling_wide_slide_stairs":continue # non-linear stair/slope heights tested with the real player below
		var good:=true;var count:=0
		for i in route.points.size()-1:
			var a:Vector3=route.points[i];var b:Vector3=route.points[i+1]
			var steps:=ceili(a.distance_to(b)/.30)
			for step in steps+1:
				var p:Vector3=a.lerp(b,step/float(steps));count+=1
				if not clear(p) or not supported(p):good=false
		check(route.id+" continuous capsule and ground sweep",good,str(count)+" samples")
	mesh_index_checks()
	await walk_slide()
	var faces:=0;var bad:=0;var details:=0
	for id in world.structures:
		if not str(id).begins_with("darling_detail/"):continue
		var body:Node3D=world.structures[id].node
		details+=int(body.get_meta("detail_elements",0))
		for child in body.get_children():
			if not child is MeshInstance3D:continue
			for s in child.mesh.get_surface_count():
				var arr=child.mesh.surface_get_arrays(s);var v=arr[Mesh.ARRAY_VERTEX];var n=arr[Mesh.ARRAY_NORMAL];var ix=arr[Mesh.ARRAY_INDEX]
				for i in range(0,ix.size() if ix!=null and not ix.is_empty() else v.size(),3):
					var a:int=ix[i] if ix!=null and not ix.is_empty() else i;var b:int=ix[i+1] if ix!=null and not ix.is_empty() else i+1;var c:int=ix[i+2] if ix!=null and not ix.is_empty() else i+2
					faces+=1
					if not v[a].is_finite() or (v[b]-v[a]).cross(v[c]-v[a]).dot(n[a])>.0001:bad+=1
	check("Original facility meshes finite and outward facing",bad==0,str(bad)+" bad of "+str(faces))
	var wide:Dictionary=world.structures["darling_detail/playground/slide/wide"]
	check("Wide slide has full-width collision and a stair approach",wide.half.x*2>7.5 and wide.half.z*2>8.0,str(wide.half))
	var net:Dictionary=world.structures["darling_detail/playground/octanet"]
	check("Octanet damage bounds cover documented 11m mast",net.half.y*2>=10.95 and net.half.x*2>14.5,str(net.half))
	for id in ["darling_detail/waterplay/channels","darling_detail/waterplay/pump","darling_detail/waterplay/archimedes_screw","darling_detail/shelter/door/1241018457","darling_detail/playground/octanet","darling_detail/waterplay/wheel","darling_detail/fountain/730089774","darling_square/darling_business_bendigo_bank/frontage"]:
		var item:Dictionary=world.structures[id];var node:Node3D=item.node;var original:Array=[]
		for child in node.get_children():
			if child is MeshInstance3D:original.append(child.material_override)
		world._destroy_component(id,item.position,300000,false)
		await physics_frame;await physics_frame
		var disabled:=not node.visible
		for child in node.get_children():
			if child is CollisionShape3D and not child.disabled:disabled=false
		check(id+" damage disables all attached collisions",disabled)
		world.repair_all();await physics_frame;await physics_frame
		var good:=node.visible;var index:=0
		for child in node.get_children():
			if child is CollisionShape3D and child.disabled:good=false
			if child is MeshInstance3D:
				if child.material_override!=original[index]:good=false
				index+=1
		check(id+" repair restores materials and collisions",good)
	if "--capture" in OS.get_cmdline_user_args():await capture()
	var passed:bool=checks.all(func(c):return c.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	FileAccess.open(output_dir+"/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"blocked":blocked,"headless":DisplayServer.get_name()=="headless","counts":counts,"mesh_index_records":mesh_index_records,"sha256":{"game/scripts/darling_public_facilities.gd":FileAccess.get_sha256("res://scripts/darling_public_facilities.gd"),"game/scripts/city_landmarks.gd":FileAccess.get_sha256("res://scripts/city_landmarks.gd"),"source/darling_public_facilities_test.gd":FileAccess.get_sha256("res://../source/darling_public_facilities_test.gd")},"scope":"Mapped local city context; capsule sweeps are geometry checks, not a complete production-player walk or surveyed facsimile"},"\t"))
	print("DARLING_COMPONENT_TEST ",checks.size()," checks; ","PASS" if passed else "FAIL")
	quit(0 if passed else 1)
func check_photo_frontages():
	var records:Array=Businesses.frontages().filter(func(r):return r.has("photo_refinement"))
	check("Four branch-specific refinements with four review cameras",records.size()==4 and Businesses.photo_capture_views().size()==4)
	var original:Dictionary={"haven_specialty_coffee":[-671.5217,2045.6267,6.5],"pancakes_on_the_rocks":[-786.9897,2069.4807,8.0],"bengongs_tea":[-666.3727,2093.9352,5.0],"sushi_sei":[-706.1884,2072.7404,5.6]}
	for item in records:
		var key:String=item.id.trim_prefix("darling_business_")
		var body:Node3D=world.structures["darling_square/"+item.id+"/frontage"].node
		var base:Array=original[key]
		check(key+" mapped wall and width unchanged",is_equal_approx(item.front[0],base[0]) and is_equal_approx(item.front[1],base[1]) and is_equal_approx(item.width,base[2]))
		check(key+" inspected image provenance retained",item.photo_urls.size()>0 and item.photo_checked=="2026-09-12" and body.get_meta("photo_features",[]).size()>=4)
		var faces:=0;var invalid:=0;var max_depth:=0.0;var min_y:=10.0;var max_y:=0.0
		for child in body.get_children():
			if not child is MeshInstance3D:continue
			for surface in child.mesh.get_surface_count():
				var arr:Array=child.mesh.surface_get_arrays(surface)
				var verts:PackedVector3Array=arr[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arr[Mesh.ARRAY_NORMAL];var ids=arr[Mesh.ARRAY_INDEX]
				for v in verts:
					max_depth=maxf(max_depth,v.z);min_y=minf(min_y,v.y+2.2);max_y=maxf(max_y,v.y+2.2)
				for i in range(0,ids.size() if ids!=null and not ids.is_empty() else verts.size(),3):
					var a:int=ids[i] if ids!=null and not ids.is_empty() else i;var b:int=ids[i+1] if ids!=null and not ids.is_empty() else i+1;var c:int=ids[i+2] if ids!=null and not ids.is_empty() else i+2
					faces+=1
					if not verts[a].is_finite() or (verts[b]-verts[a]).cross(verts[c]-verts[a]).dot(normals[a])>.0001:invalid+=1
		check(key+" visible surfaces finite and correctly wound",invalid==0 and faces>500,str(faces)+" triangles; "+str(invalid)+" invalid")
		check(key+" shallow frontage stays within public-side allowance",max_depth<=1.36 and min_y>=-.01 and max_y<=4.5,str([min_y,max_y,max_depth]))
		var recorded:Dictionary=item.get("model_mesh_bounds_m",{})
		check(key+" published model bounds match generated mesh",absf(float(recorded.get("max_outward_from_backing",-1))-max_depth)<.0006 and absf(float(recorded.get("max_height_above_ground",-1))-max_y)<.0006,str({"depth":max_depth,"height":max_y}))
		if key in ["pancakes_on_the_rocks","bengongs_tea","sushi_sei"]:
			check_frontage_lettering(key,body)
		var n:=Vector3(item.normal[0],0,item.normal[1]);var p:=Vector3(item.front[0],4.5,item.front[1]);var side:=Vector3.UP.cross(n)
		var passable:=true
		for sample in 17:
			var q:Vector3=p+n*2.15+side*((sample/16.0-.5)*(item.width+.4))
			if not clear(q) or not supported(q):passable=false
		check(key+" continuous public path in front stays clear",passable)
	check("Sushi Sei room photo does not claim a verified exterior",records.filter(func(r):return r.id=="darling_business_sushi_sei")[0].model_status=="mapped_photo_informed_display")

func check_frontage_lettering(key:String,body:Node3D):
	var text:String={"pancakes_on_the_rocks":"PANCAKES ON THE ROCKS","bengongs_tea":"ORIENTAL\nTEACRAFT","sushi_sei":"by KUON"}[key]
	var label:Label3D
	for child in body.get_children():
		if child is Label3D and child.text==text:label=child;break
	if label==null:
		check(key+" lettering clear of actual frame meshes",false,"missing label");return
	var bounds:AABB=label.get_aabb()
	var now:Dictionary=lettering_occlusion(body,bounds,label.position)
	# The same mesh sampler must detect the reviewed defect at its previous
	# lettering position/size. No collision bodies or production labels are moved.
	var previous:Dictionary={"pancakes_on_the_rocks":[Vector3(0,3.58-2.2,.33),.19/.17],"bengongs_tea":[Vector3(1.0,2.61-2.2,.32),.17/.125],"sushi_sei":[Vector3(0,3.30-2.2,.35),.075/.065]}
	var old:Array=previous[key]
	var before:Dictionary=lettering_occlusion(body,AABB(bounds.position*float(old[1]),bounds.size*float(old[1])),old[0])
	check(key+" lettering clear of actual frame meshes",now.samples>=800 and now.occluded==0 and before.occluded>0,JSON.stringify({"current":now,"old_layout_control":before}))

func lettering_occlusion(body:Node3D,bounds:AABB,offset:Vector3)->Dictionary:
	if bounds.size.x<=0 or bounds.size.y<=0:return {"samples":0,"occluded":0,"error":"empty label bounds"}
	var triangles:PackedVector3Array=[]
	# Meshes are tested directly because most frame/awning details deliberately
	# have no physics collider. Cull only triangles outside the sampled volume.
	for child in body.get_children():
		if not child is MeshInstance3D:continue
		var faces:PackedVector3Array=child.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var a:Vector3=child.transform*faces[i];var b:Vector3=child.transform*faces[i+1];var c:Vector3=child.transform*faces[i+2]
			if maxf(a.z,maxf(b.z,c.z))<offset.z+.001:continue
			if maxf(a.x,maxf(b.x,c.x))<offset.x+bounds.position.x-.26 or minf(a.x,minf(b.x,c.x))>offset.x+bounds.end.x+.26:continue
			if maxf(a.y,maxf(b.y,c.y))<offset.y+bounds.position.y or minf(a.y,minf(b.y,c.y))>offset.y+bounds.end.y:continue
			triangles.append_array([a,b,c])
	var samples:=0;var occluded:=0
	for side in [-.25,0.0,.25]:
		for row in 9:
			for col in 33:
				var end:Vector3=offset+Vector3(bounds.position.x+bounds.size.x*(.01+.98*col/32.0),bounds.position.y+bounds.size.y*(.01+.98*row/8.0),.001)
				var start:Vector3=end+Vector3(side,0,1.0)
				samples+=1
				for i in range(0,triangles.size(),3):
					if Geometry3D.segment_intersects_triangle(start,end,triangles[i],triangles[i+1],triangles[i+2])!=null:
						occluded+=1;break
	return {"samples":samples,"occluded":occluded,"label_width":bounds.size.x,"label_height":bounds.size.y}

func walk_slide():
	for action in ["forward","back","left","right","sprint","jump"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	var player=load("res://scripts/harbor_player.gd").new()
	world.add_child(player)
	var route:Dictionary=Facilities.walk_routes()[-1]
	player.global_position=route.points[0]+Vector3.UP*.1;player.last_safe=player.global_position;player.enabled=true
	for i in 20:await physics_frame
	var records:Array=[];var good:=true
	for target:Vector3 in route.points.slice(1):
		var frames:=0
		while frames<360:
			var delta:Vector3=target-player.global_position
			if Vector2(delta.x,delta.z).length()<.25:break
			player.yaw=atan2(-delta.x,-delta.z)
			Input.action_press("forward");await physics_frame;frames+=1
		Input.action_release("forward")
		for i in 10:await physics_frame
		var distance:float=Vector2(target.x-player.position.x,target.z-player.position.z).length()
		var reached:bool=distance<.8 and absf(target.y-player.position.y)<.5
		records.append({"target":[target.x,target.y,target.z],"actual":[player.position.x,player.position.y,player.position.z],"frames":frames,"reached":reached})
		if not reached:good=false;break
	check("Production player walks up visible slide steps and down slope",good,JSON.stringify(records))
	player.queue_free();await physics_frame
func capture():
	root.size=Vector2i(1440,900)
	world._build_structure_batches()
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("b8cfda");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("e4ebea");env.ambient_light_energy=.8;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var we:=WorldEnvironment.new();we.environment=env;world.add_child(we)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-25,0);sun.light_energy=1.4;sun.shadow_enabled=true;world.add_child(sun)
	var camera:=Camera3D.new();camera.current=true;camera.far=800;camera.fov=65;world.add_child(camera)
	DirAccess.make_dir_recursive_absolute(output_dir)
	for v in Facilities.capture_views()+Businesses.capture_views():
		camera.position=v[1];camera.look_at(v[2]);await process_frame;await process_frame;RenderingServer.force_draw(false);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_dir+"/"+v[0]+".png")

func mesh_index_checks():
	# Expected faces are the sum of the original manual boxes and primitive
	# triangles; the shape coordinates and collision definitions are unchanged.
	var expected:Dictionary={"darling_detail/waterplay/channels":948,"darling_detail/waterplay/pump":1008,"darling_detail/waterplay/archimedes_screw":2088,"darling_detail/shelter/door/1241018457":204}
	for id:String in expected:
		var body:Node3D=world.structures[id].node
		var visible:=PackedVector3Array();var omitted:=0;var records:Array=[]
		for child in body.get_children():
			if not child is MeshInstance3D:continue
			for surface in child.mesh.get_surface_count():
				var arrays:Array=child.mesh.surface_get_arrays(surface)
				var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var indices=arrays[Mesh.ARRAY_INDEX]
				var unused:=0
				if indices!=null and not indices.is_empty():
					var used:Dictionary={}
					for index in indices:used[index]=true
					unused=vertices.size()-used.size()
				omitted+=unused
				records.append({"vertices":vertices.size(),"indices":indices.size() if indices!=null else 0,"omitted":unused})
			for vertex:Vector3 in child.mesh.get_faces():visible.append(child.transform*vertex)
		check(id+" all originally authored triangles survive mixed primitive append",visible.size()/3==expected[id] and omitted==0,str({"actual_faces":visible.size()/3,"expected_faces":expected[id],"unused_vertices":omitted}))
		var samples:=0;var misses:=0;var collision:Array=[]
		for child in body.get_children():
			if not child is CollisionShape3D:continue
			var locations:Array[Vector3]=[];var normals:Array[Vector3]=[]
			if child.shape is BoxShape3D:
				for n in [Vector3.LEFT,Vector3.RIGHT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:locations.append(n*child.shape.size*.5);normals.append(n)
				collision.append({"kind":"box","size":str(child.shape.size),"pose":str(child.transform)})
			elif child.shape is CylinderShape3D:
				for n in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:locations.append(n*child.shape.radius);normals.append(n)
				locations.append_array([Vector3.UP*child.shape.height*.5,Vector3.DOWN*child.shape.height*.5]);normals.append_array([Vector3.UP,Vector3.DOWN])
				collision.append({"kind":"cylinder","radius":child.shape.radius,"height":child.shape.height,"pose":str(child.transform)})
			for i in locations.size():
				var at:Vector3=child.transform*locations[i];var normal:Vector3=child.basis*normals[i]
				var found:=false;samples+=1
				for triangle in range(0,visible.size(),3):
					if Geometry3D.segment_intersects_triangle(at+normal*.015,at-normal*.015,visible[triangle],visible[triangle+1],visible[triangle+2])!=null:found=true;break
				if not found:misses+=1
		check(id+" physical support faces have matching rendered surfaces",samples>=6 and misses==0,str({"samples":samples,"missing_visible_faces":misses}))
		mesh_index_records.append({"id":id,"visible_triangles":visible.size()/3,"expected_triangles":expected[id],"surfaces":records,"collision_face_samples":samples,"missing_visible_faces":misses,"collision_signature":collision})
	for order in ["box-cylinder-box","cylinder-box-cylinder"]:
		var fixture=Facilities.Part.new(world,"qa/append_"+order,Vector3(-1200,4.5,2300))
		var cylinder:=CylinderMesh.new();cylinder.top_radius=.4;cylinder.bottom_radius=.4;cylinder.height=1.0;cylinder.radial_segments=12;cylinder.rings=1
		var expected_faces:=0;var step:=0
		for primitive in order.split("-"):
			if primitive=="box":fixture.box(Vector3(step*2,1,0),Vector3.ONE,"steel");expected_faces+=12
			else:fixture.append(cylinder,Transform3D(Basis(Vector3.UP,.31),Vector3(step*2,1.07,0)),"steel");expected_faces+=cylinder.get_faces().size()/3
			step+=1
		fixture.finish()
		var actual:=0;var uv_count:=0;var vertex_count:=0
		for child in fixture.body.get_children():
			if child is MeshInstance3D and child.get_index()>=2:
				actual+=child.mesh.get_faces().size()/3
				var arrays:Array=child.mesh.surface_get_arrays(0)
				vertex_count+=arrays[Mesh.ARRAY_VERTEX].size()
				if arrays[Mesh.ARRAY_TEX_UV]!=null:uv_count+=arrays[Mesh.ARRAY_TEX_UV].size()
		check("Part mixed order "+order+" keeps every triangle and consistent UV format",actual==expected_faces and uv_count==vertex_count,str({"actual":actual,"expected":expected_faces,"uv":uv_count,"vertices":vertex_count}))
		world.structures.erase(fixture.body.get_meta("damage_id"));fixture.body.queue_free()
