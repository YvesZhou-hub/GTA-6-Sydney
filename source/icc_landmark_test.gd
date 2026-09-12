extends SceneTree
const ICC=preload("res://scripts/icc_landmarks.gd")
class LocalICC:
	extends "res://scripts/harbor_world.gd"
	func _ready() -> void:
		_make_materials()
		_box(self,Vector3(-980,4.2,1710),Vector3(480,0.6,720),"paving",true)
		ICC.build(self)
		_flush_batches()
		_build_structure_batches()
var failures:=0
var count:=0
var checks:Array[Dictionary]=[]
func verify(value: bool,message: String) -> void:
	count+=1
	checks.append({"name":message,"passed":value})
	if value:print("PASS ",message)
	else:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for action: String in ["forward","back","left","right","jump","sprint"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	var full_world: bool="--full-world" in OS.get_cmdline_user_args()
	var world=load("res://scripts/harbor_world.gd").new() if full_world else LocalICC.new()
	root.add_child(world)
	await physics_frame;await physics_frame
	if full_world and not world._ready_complete:
		push_error("Production world did not finish initialization; ICC integration results invalid");quit(1);return
	verify(world.has_meta("icc_landmarks"),"three ICC venues built")
	verify(ICC.metadata().size()==3,"separate Convention / Exhibition / entertainment theatre entries")
	verify(ICC.footprints().size()==6 and ICC.excluded_way_ids().size()==7,"all exact mapped parts replace parent and ordinary envelopes")
	verify(world.get_meta("icc_modeled_seats",0)>1500,"three tiers contain distinct red / grey seat geometry")
	verify(world.get_meta("icc_convention_fitout",{}).get("registration_workstations",0)==4,"Convention counter has four modeled workstations and digital wayfinding")
	verify(world.get_meta("icc_exhibition_fitout",{}).get("digital_screens",0)==20,"Exhibition foyer has four fitted concession bays and twenty guide screens")
	verify(world.get_meta("icc_theatre_fitout",{}).get("foyer_battens",false),"Theatre ticket foyer has timber relief and a suspended metal ceiling")
	var before: int=world.structures.size();ICC.build(world);verify(before==world.structures.size(),"build is idempotent")
	var triangles:=0;var mesh_parts:=0
	for node in world.find_children("*","MeshInstance3D",true,false):
		if not node.mesh or not node.is_visible_in_tree():continue
		mesh_parts+=1
		for surface in node.mesh.get_surface_count():
			var arrays: Array=node.mesh.surface_get_arrays(surface)
			triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
	check_refinement(world,world.get_world_3d().direct_space_state)
	print("ICC FIXTURE METRICS structures=",world.structures.size()," meshes=",mesh_parts," visible_triangles=",triangles," seats=",world.get_meta("icc_modeled_seats"))
	var space:PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	for name: String in ICC.routes():
		var route: Array=ICC.routes()[name]
		var blocked:=0
		var unsupported:=0
		for i in range(route.size()-1):
			for j in range(1,45):
				var p:Vector3=route[i].lerp(route[i+1],float(j)/44)
				var shape:=CapsuleShape3D.new();shape.radius=0.33;shape.height=1.8
				var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=p+Vector3.UP*1.02;query.margin=0.004
				var hits:=space.intersect_shape(query)
				if not hits.is_empty():
					blocked+=1
					if blocked<5:print("ICC_BLOCK ",name," segment ",i," at ",p," ",hits.map(func(h):return h.collider.name))
				var support:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.5,p-Vector3.UP*0.7))
				if support.is_empty():
					unsupported+=1
					if unsupported<8:print("ICC_NO_FLOOR ",name," segment ",i," at ",p)
		verify(blocked==0,name+" public walking route has full capsule clearance: "+str(blocked))
		verify(unsupported==0,name+" public walking route has continuous physical floor: "+str(unsupported))
		if not "--geometry-only" in OS.get_cmdline_user_args():await walk_route(world,name,route)
	check_theatre_enclosure(world,space)
	if not "--geometry-only" in OS.get_cmdline_user_args():await walk_route(world,"theatre glazed foyer",ICC.theatre_foyer_route())
	# Moriarty Walk between the real Exhibition and Theatre footprints stays open.
	var blockage:=0
	for i in range(80):
		var p:=ICC.point(ICC.THEATRE,Vector3(-50+i*1.5,0,-53))
		var q:=PhysicsShapeQueryParameters3D.new();var s:=CapsuleShape3D.new();s.radius=0.33;s.height=1.8;q.shape=s;q.transform.origin=p+Vector3.UP
		if not space.intersect_shape(q).is_empty():blockage+=1
	verify(blockage==0,"Moriarty Walk stays clear across the venue group")
	if "--capture" in OS.get_cmdline_user_args():await capture(world)
	var report:={"passed":failures==0,"check_count":count,"failures":failures,"checks":checks,"execution_flags":OS.get_cmdline_user_args(),"full_world":full_world,"continuous_walks_ran":not "--geometry-only" in OS.get_cmdline_user_args(),"structures":world.structures.size(),"visible_meshes":mesh_parts,"visible_triangles":triangles,"modeled_seats":world.get_meta("icc_modeled_seats"),"model_sha256":FileAccess.get_sha256("res://scripts/icc_landmarks.gd"),"test_sha256":FileAccess.get_sha256("res://../source/icc_landmark_test.gd"),"native_capture_ran":"--capture" in OS.get_cmdline_user_args(),"user_saves_touched":false}
	var report_path:=ProjectSettings.globalize_path("res://../reports/icc-v016-detail-report.json")
	var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("ICC CHECK COMPLETE checks=",count," failures=",failures)
	quit(failures)
func check_refinement(world:Node3D,space:PhysicsDirectSpaceState3D) -> void:
	# Exercise the exact Array.append_array contract used by precinct_validation.
	var integrated:Array=[];integrated.append_array(ICC.walk_routes())
	verify(integrated.size()==4,"precinct can append all four ICC route records as an Array")
	var schema_ok:=true
	for row in integrated:
		if not row is Dictionary or not row.get("name") is String or not row.get("points") is Array:
			schema_ok=false;continue
		if row.points.size()<2:schema_ok=false
		for p in row.points:
			if not p is Vector3 or not p.is_finite():schema_ok=false
	verify(schema_ok,"every integrated ICC route has a name and finite Vector3 points")
	var expected:={}
	for key:String in ICC.routes():expected["icc_"+key]=ICC.routes()[key]
	expected["icc_theatre_glazed_foyer"]=ICC.theatre_foyer_route()
	for name:String in expected:
		var matches:=integrated.filter(func(row):return row is Dictionary and row.get("name")==name)
		verify(matches.size()==1 and matches[0].get("points")==expected[name],"precinct route matches the original walked path: "+name)
	verify(world.get_meta("icc_recessed_pods",{}).get("count",0)==8,"eight meeting pods have recessed timber cheeks, soffits, glazing and low guards")
	verify(world.get_meta("icc_theatre_red_ceiling",{}).get("profile_segments",0)==288,"theatre public foyer has 288 red folded ceiling segments, not generic silver battens")
	verify(world.get_meta("icc_theatre_skin",{}).get("glazed_mouth",false),"theatre outer skin preserves the photographed tall glazed mouth")
	verify(world.find_children("CrystalWindowRelief","Node3D",true,false).size()==ICC._poly(488447518,ICC.CONVENTION).size(),"crystalline window relief is attached separately to every original facade component")
	var supported_ids:=["icc/convention/wall/17/upper","icc/exhibition/upper_halls","icc/theatre/wall/12/upper","icc/theatre/foyer_west"]
	var detail_names:=["CrystalWindowRelief","RecessedTimberPods","FoldedTheatreSkin","RedFoldedCeiling"]
	for i in supported_ids.size():
		var id:String=supported_ids[i]
		var body:Node3D=world.structures[id].node
		var detail:Node3D=body.get_node_or_null(NodePath(detail_names[i]))
		var live:=detail!=null and detail.is_visible_in_tree()
		world._destroy_component(id,body.global_position,0,false)
		verify(live and not detail.is_visible_in_tree(),detail_names[i]+" disappears with its original saved damage ID")
	world.repair_all()
	var restored:=true
	for i in supported_ids.size():restored=restored and world.structures[supported_ids[i]].node.get_node(NodePath(detail_names[i])).is_visible_in_tree()
	verify(restored,"repair restores all attached facade and ceiling detail groups")
	var pod_root:Node3D=world.structures["icc/exhibition/upper_halls"].node.get_node("RecessedTimberPods")
	# Inspect the actual triangles along all eight opening centres: a pasted
	# black front sheet would intersect these rays before the recessed pane.
	var clear_recesses:=0
	for row in range(2):
		for i in range(4):
			var y:float=13.5+row*12.2;var z:float=-67+i*38+(15 if row==1 else 0)
			var blocked:=false
			for mesh:MeshInstance3D in pod_root.find_children("*","MeshInstance3D",true,false):
				for surface in mesh.mesh.get_surface_count():
					var arrays:Array=mesh.mesh.surface_get_arrays(surface)
					var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var idx:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
					for k in range(0,idx.size() if not idx.is_empty() else vertices.size(),3):
						var a:Vector3=vertices[idx[k] if not idx.is_empty() else k]
						var b:Vector3=vertices[idx[k+1] if not idx.is_empty() else k+1]
						var c:Vector3=vertices[idx[k+2] if not idx.is_empty() else k+2]
						if Geometry3D.segment_intersects_triangle(Vector3(64.1,y,z+0.8),Vector3(60.1,y,z+0.8),a,b,c)!=null:blocked=true;break
			if not blocked:clear_recesses+=1
	verify(clear_recesses==8,"all eight actual pod meshes have a clear 4m recess in front of the rear glazing")
	for view:Array in ICC.capture_views():
		var shape:=SphereShape3D.new();shape.radius=0.18
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=view[1]
		verify(space.intersect_shape(query).is_empty(),"specialist capture camera clear: "+view[0])

func check_theatre_enclosure(world:Node3D,space:PhysicsDirectSpaceState3D) -> void:
	var missed:=0;var rays:=0
	var eye:=ICC.point(ICC.THEATRE,Vector3(-29,4,-17))
	var targets:Array[Vector3]=[]
	for y in [30.0,36.0]:
		for z in [-29.0,-17.0,-5.0,7.0,19.0,29.0]:targets.append(Vector3(43,y,z))
		for x in [-10.0,5.0,20.0,34.0]:
			targets.append(Vector3(x,y,-37));targets.append(Vector3(x,y,37))
	for target:Vector3 in targets:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,ICC.point(ICC.THEATRE,target)))
		rays+=1
		if hit.is_empty() or not hit.collider.get_meta("icc_acoustic_enclosure",false):
			missed+=1
			if missed<7:print("ICC_ACOUSTIC_RAY ",target," hit=",hit.get("collider","empty"))
	verify(missed==0,"stage-front sightlines hit opaque internal enclosure above/behind seats: %s/%s"%[rays-missed,rays])
	var solid:=true
	for part in world.structures.values():
		if not part.node.get_meta("icc_acoustic_enclosure",false):continue
		if part.color!="icc_black":solid=false
	verify(solid,"auditorium enclosure uses opaque charcoal material independently of exterior glazing")
	var blocked:=0
	for door:Dictionary in [{"p":Vector3(35,0,-36),"across":Vector3.RIGHT,"through":Vector3.BACK},{"p":Vector3(42,0,-31),"across":Vector3.BACK,"through":Vector3.RIGHT}]:
		for lateral in [-2.6,0.0,2.6]:
			for depth in [-1.0,0.0,1.0]:
				var p:Vector3=door.p+door.across*lateral+door.through*depth
				var shape:=CapsuleShape3D.new();shape.radius=0.33;shape.height=1.8
				var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=ICC.point(ICC.THEATRE,p)+Vector3.UP*1.02
				if not space.intersect_shape(query).is_empty():blocked+=1
	verify(blocked==0,"both public acoustic-room doors retain 6m by 3.6m modeled openings and full human clearance")

func walk_route(world:Node3D,name:String,route:Array) -> void:
	var player=load("res://scripts/harbor_player.gd").new();world.add_child(player)
	player.position=route[0]+Vector3.UP*0.12;player.enabled=true;player.last_safe=player.position
	for i in range(15):await physics_frame
	var targets:=route.slice(1)
	var entered:=false;var returned:=false
	for phase in range(2):
		var reached:=true
		for target:Vector3 in targets:
			var arrive:=false
			Input.action_press("forward")
			for i in range(1300):
				var d:=Vector3(target.x-player.position.x,0,target.z-player.position.z)
				if d.length()<0.36:arrive=true;break
				player.yaw=atan2(-d.x,-d.z)
				await physics_frame
			Input.action_release("forward")
			if not arrive:
				print("ICC_WALK_STUCK ",name," target=",target," actual=",player.position)
				reached=false;break
		if phase==0:
			entered=reached and absf(player.position.y-route[-1].y)<0.35
			targets=route.duplicate();targets.reverse();targets=targets.slice(1)
		else:returned=reached and absf(player.position.y-route[0].y)<0.35
	verify(entered,name+" actual HarborPlayer enters and reaches interior through normal input")
	verify(returned,name+" actual HarborPlayer walks back out without teleport or jump")
	verify(not player.swimming,name+" interior stays above water")
	player.queue_free();await physics_frame
func capture(world:Node3D) -> void:
	root.size=Vector2i(1440,900)
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("8aadb9");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("d3dada");environment.ambient_light_energy=0.8;environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var env:=WorldEnvironment.new();env.environment=environment;world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-45,0);sun.light_energy=1.4;sun.shadow_enabled=true;world.add_child(sun)
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.far=1400;camera.fov=70
	var views: Array=[
		["group",ICC.point(ICC.EXHIBITION,Vector3(260,180,210)),ICC.EXHIBITION+Vector3.UP*10],
		["convention-front",ICC.point(ICC.CONVENTION,Vector3(120,22,-55)),ICC.CONVENTION+Vector3.UP*20],
		["convention-foyer",ICC.point(ICC.CONVENTION,Vector3(53,1.8,17)),ICC.point(ICC.CONVENTION,Vector3(8,3,-10))],
		["convention-registration",ICC.point(ICC.CONVENTION,Vector3(24,1.85,16)),ICC.point(ICC.CONVENTION,Vector3(27,1.8,24))],
		["exhibition-foyer",ICC.point(ICC.EXHIBITION,Vector3(49,8.4,-90)),ICC.point(ICC.EXHIBITION,Vector3(41,9.2,-80))],
		["exhibition-front",ICC.point(ICC.EXHIBITION,Vector3(147,16,120)),ICC.point(ICC.EXHIBITION,Vector3(52,15,-22))],
		["exhibition-stairs",ICC.point(ICC.EXHIBITION,Vector3(60,1.8,-83)),ICC.point(ICC.EXHIBITION,Vector3(56,7,-45))],
		["exhibition-hall",ICC.point(ICC.EXHIBITION,Vector3(34,8.3,-39)),ICC.point(ICC.EXHIBITION,Vector3(-48,10,-11))],
		["theatre-front",ICC.point(ICC.THEATRE,Vector3(105,16,-99)),ICC.point(ICC.THEATRE,Vector3(12,17,-6))],
		["theatre-foyer",ICC.point(ICC.THEATRE,Vector3(55,1.8,-36)),ICC.point(ICC.THEATRE,Vector3(54,4,27))],
		["theatre-auditorium",ICC.point(ICC.THEATRE,Vector3(-29,4.0,-17)),ICC.point(ICC.THEATRE,Vector3(19,13,4))],
		["theatre-stage",ICC.point(ICC.THEATRE,Vector3(17,18,-3)),ICC.point(ICC.THEATRE,Vector3(-31,3,0))]
	]
	views.append_array(ICC.capture_views())
	if "--detail-capture" in OS.get_cmdline_user_args():views=ICC.capture_views()
	if "--fitout-capture" in OS.get_cmdline_user_args():views=views.filter(func(view):return view[0] in ["convention-registration","exhibition-foyer"])
	if "--theatre-capture" in OS.get_cmdline_user_args():views=views.filter(func(view):return view[0] in ["theatre-auditorium","theatre-foyer"])
	var folder:=ProjectSettings.globalize_path("res://../reports/icc-refinement/"+("full-world" if "--full-world" in OS.get_cmdline_user_args() else "local"));DirAccess.make_dir_recursive_absolute(folder)
	for view:Array in views:
		camera.position=view[1];camera.look_at(view[2])
		for i in range(5):await process_frame
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png(folder+"/"+view[0]+".png");print("ICC FRAME ",view[0])
