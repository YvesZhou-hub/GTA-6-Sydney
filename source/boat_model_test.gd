extends SceneTree
## Isolated production-factory test. -- --visual adds native model views.
const Factory=preload("res://scripts/vehicle_factory.gd")
var checks:=0
var failures:=0
var scene:Node3D
var boats:Dictionary={}
var report:Dictionary={}

func _init():call_deferred("run")
func check(ok:bool,message:String):
	checks+=1
	if ok:print("PASS ",message)
	else:failures+=1;push_error("FAIL "+message)

func hull_checks(mesh:Mesh)->Dictionary:
	var a:PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var edges:Dictionary={}
	var volume:=0.0
	for i in range(0,a.size(),3):
		volume-=a[i].dot(a[i+1].cross(a[i+2]))/6.0
		for j in 3:
			var p:=str(a[i+j].snapped(Vector3.ONE*.00001));var q:=str(a[i+(j+1)%3].snapped(Vector3.ONE*.00001))
			var key:=p+"/"+q if p<q else q+"/"+p
			edges[key]=int(edges.get(key,0))+1
	var closed:=true
	for uses in edges.values():closed=closed and uses==2
	return {"closed":closed,"volume":volume}

func run():
	scene=Node3D.new();root.add_child(scene)
	for kind in ["speedboat","yacht"]:
		var body:=RigidBody3D.new();body.freeze=true;body.name=kind
		scene.add_child(body);body.position=Vector3(0,.9,0) if kind=="speedboat" else Vector3(60,.9,0)
		Factory.build(body,kind)
		boats[kind]=body
		var closed:=hull_checks(body.get_node("ClosedHull").mesh)
		check(closed.closed,kind+" hull is watertight: every geometric edge has two triangle faces")
		check(closed.volume>20,kind+" closed hull winding points outward and encloses positive volume")
	await process_frame;await physics_frame;await physics_frame
	for kind:String in boats:
		var body:RigidBody3D=boats[kind]
		var bounds:=AABB();var first:=true;var triangles:=0;var meshes:=0;var invalid:=0;var bad_normals:=0;var colliders:=0
		for c in body.get_children():
			if c is CollisionShape3D:colliders+=1;check(c.shape is ConvexPolygonShape3D or c.shape is BoxShape3D,kind+" direct convex body collider")
			if not c is MeshInstance3D:continue
			meshes+=1
			bounds=c.transform*c.mesh.get_aabb() if first else bounds.merge(c.transform*c.mesh.get_aabb());first=false
			for surface in c.mesh.get_surface_count():
				var a:Array=c.mesh.surface_get_arrays(surface)
				var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
				var indices:PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				var count:=indices.size() if not indices.is_empty() else vertices.size();triangles+=count/3
				for p in vertices:if not p.is_finite():invalid+=1
				for i in range(0,count,3):
					var x:=indices[i] if not indices.is_empty() else i;var y:=indices[i+1] if not indices.is_empty() else i+1;var z:=indices[i+2] if not indices.is_empty() else i+2
					if (vertices[y]-vertices[x]).cross(vertices[z]-vertices[x]).dot(normals[x]+normals[y]+normals[z])>.00001:bad_normals+=1
		var profile:Dictionary=body.get_meta("boat_profile");var spec:Dictionary=body.get_meta("boat_spec")
		check(invalid==0 and bad_normals==0,kind+" finite triangles with consistent clockwise normals")
		check(absf(bounds.size.z-spec.length)<.10 and absf(bounds.size.x-spec.beam)<.1,kind+" full visible dimensions match official length and beam")
		check(absf(bounds.position.y-(-.9-spec.draft))<.02,kind+" keel matches declared draft and local -0.9m waterline")
		check(meshes<20 and triangles<85000,kind+" details material-batched within scene budget")
		check(profile.camera_height<4 and profile.float_height==.9,kind+" camera aims at boat and float origin uses agreed waterline")
		var exit:Vector3=profile.exit
		var exit_hit:=ray(body,exit+Vector3.UP*.5,exit-Vector3.UP*.8)
		check(not exit_hit.is_empty() and exit_hit.collider==body,kind+" exit stands over supported swim platform")
		report[kind]={"bounds":str(bounds),"meshes":meshes,"triangles":triangles,"colliders":colliders,"boat_profile":str(profile)}
	var yacht:RigidBody3D=boats.yacht
	var supported:=true
	for x in [-2.48,0,2.48]:
		for z in [8.01,9.1,10.2]:
			var hit:=ray(yacht,Vector3(x,2.4,z),Vector3(x,1.2,z))
			supported=supported and not hit.is_empty() and hit.collider==yacht and absf((hit.position-yacht.position).y-1.46)<.02
	check(supported,"5m by 2.27m transverse car envelope has nine supported flat aft deck probes")
	var car_clear:=true
	for x in [-2.48,0,2.48]:
		for z in [8.01,9.1,10.2]:
			car_clear=car_clear and ray(yacht,Vector3(x,1.49,z),Vector3(x,2.7,z)).is_empty()
	check(car_clear,"transverse car envelope clears port stair and all cabin/roof collisions")
	var stair_clear:=true
	for i in 9:
		var t:float=float(i)/8
		var foot:=Vector3(-2.62,lerpf(1.46,4.42,t),lerpf(7.96,5.04,t))
		stair_clear=stair_clear and ray(yacht,foot+Vector3.UP*.22,foot+Vector3.UP*1.94).is_empty()
	check(stair_clear,"flybridge stair has a real open upper deck and 1.94m head clearance along its run")
	var stern_supported:=true
	for side in [-1,1]:
		for i in 9:
			var t:float=float(i)/8
			var foot:=Vector3(side*2.66,lerpf(-.08,1.46,t),lerpf(12.68,10.55,t))
			var hit:=ray(yacht,foot+Vector3.UP*.2,foot-Vector3.UP*.24)
			stern_supported=stern_supported and not hit.is_empty() and hit.collider==yacht
	check(stern_supported,"both swim-platform stairs have continuous physical support across all nine samples")
	if "--visual" in OS.get_cmdline_user_args():await capture()
	report.checks=checks;report.failures=failures
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../reports/boat-models"))
	var file:=FileAccess.open("res://../reports/boat-models/model-report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("BOAT MODEL COMPLETE checks=",checks," failures=",failures)
	quit(failures)

func ray(body:Node3D,a:Vector3,b:Vector3)->Dictionary:
	return scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(body.to_global(a),body.to_global(b)))

func capture():
	root.size=Vector2i(1600,1000)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("9db9c9")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("d5e3ed");environment.environment.ambient_light_energy=.7
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	scene.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-39,-38,0);sun.light_energy=1.5;sun.shadow_enabled=true;scene.add_child(sun)
	Factory._box(scene,Vector3(300,.08,300),Vector3(30,-.045,0),Factory.material(Color("297b8d"),.3,.27))
	var camera:=Camera3D.new();camera.fov=48;camera.far=500;scene.add_child(camera);camera.make_current()
	var views:Array=[
		["speedboat_bow","speedboat",Vector3(10,6,-12),Vector3(0,.45,0)],
		["speedboat_stern","speedboat",Vector3(-9,5,11),Vector3(0,.3,1)],
		["speedboat_cockpit","speedboat",Vector3(-4,4,4),Vector3(.2,.9,-.3)],
		["yacht_bow","yacht",Vector3(26,14,-29),Vector3(0,2.5,0)],
		["yacht_stern","yacht",Vector3(-23,12,28),Vector3(0,2.5,2)],
		["yacht_flybridge","yacht",Vector3(11,13,13),Vector3(0,4.5,1)],
		["yacht_cargo","yacht",Vector3(5,6,15),Vector3(0,1.5,8.5)]]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../reports/boat-models"))
	for view in views:
		for kind in boats:boats[kind].visible=kind==view[1]
		var boat:Node3D=boats[view[1]]
		camera.position=boat.to_global(view[2]);camera.look_at(boat.to_global(view[3]),Vector3.UP)
		for i in 5:await process_frame
		RenderingServer.force_draw(false)
		var path:String="res://../reports/boat-models/"+view[0]+".png"
		var error:=root.get_texture().get_image().save_png(path)
		check(error==OK,"native screenshot "+view[0])
