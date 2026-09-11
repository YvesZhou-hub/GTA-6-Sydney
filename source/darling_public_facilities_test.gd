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
var capsule:=CapsuleShape3D.new()
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
	capsule.radius=.30;capsule.height=1.8
	world=LocalWorld.new();root.add_child(world)
	await physics_frame;await physics_frame
	check("Local precinct reaches READY",world._ready_complete)
	check("71 official directory records retained",Businesses.directory().tenants.size()==71)
	var counts:Dictionary=Businesses.directory().coverage_counts
	check("All records classified without claiming 71 exact facades",counts.existing_researched_frontage==15 and counts.mapped_inferred_frontage==23 and counts.exchange_building_directory==14 and counts.directory_only_unresolved==18 and counts.directory_conflict_unresolved==1)
	check("23 new mapped street facades",Businesses.frontages().size()==23)
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
	for id in ["darling_detail/playground/octanet","darling_detail/waterplay/wheel","darling_detail/fountain/730089774","darling_square/darling_business_bendigo_bank/frontage"]:
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
	DirAccess.make_dir_recursive_absolute("res://../reports/darling-v014")
	FileAccess.open("res://../reports/darling-v014/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"blocked":blocked,"headless":DisplayServer.get_name()=="headless","counts":counts,"scope":"Mapped local city context; capsule sweeps are geometry checks, not a complete production-player walk or surveyed facsimile"},"\t"))
	print("DARLING_COMPONENT_TEST ",checks.size()," checks; ","PASS" if passed else "FAIL")
	quit(0 if passed else 1)
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
	DirAccess.make_dir_recursive_absolute("res://../reports/darling-v014")
	for v in Facilities.capture_views()+Businesses.capture_views():
		camera.position=v[1];camera.look_at(v[2]);await process_frame;await process_frame;RenderingServer.force_draw(false);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../reports/darling-v014/"+v[0]+".png")
