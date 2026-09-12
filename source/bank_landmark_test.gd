extends SceneTree
const Bank=preload("res://scripts/bank_landmarks.gd")
const City=preload("res://scripts/city_map.gd")
const Migration=preload("res://scripts/map_migration.gd")
var failures:=0
var checks:Array[Dictionary]=[]
var triangle_components:Dictionary={}
var blocked_samples:Array=[]
var walk_records:Array=[]
var migration_records:Array=[]

class ProbeGame extends Node3D:
	var world:Node3D
	var player:Node3D

class ProbeWorld extends "res://scripts/harbor_world.gd":
	func _ready() -> void:
		_make_materials()
		Bank.build(self)
		for id in structures:
			for child in structures[id].node.get_children():
				if child is MeshInstance3D: child.set_meta("intact_material",child.material_override)
		_build_structure_batches()
		_ready_complete=true

func verify(value: bool, message: String) -> void:
	checks.append({"name":message,"passed":value})
	if value: print("PASS ",message)
	else:
		failures+=1
		push_error("FAIL "+message)

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var world:=ProbeWorld.new()
	root.add_child(world)
	verify(Bank.metadata().size()==3,"Westpac HQ and both CBA campus buildings have separate identity records")
	verify(Bank.excluded_way_ids().size()==9,"all nine custom footprint parts have explicit OSM exclusions")
	verify(Bank.CBA_SOUTH_CENTER.z>Bank.CBA_NORTH_CENTER.z and Bank.CBA_SOUTH_CENTER.x>Bank.CBA_NORTH_CENTER.x,"CBA South remains southeast of its paired North building")
	var projection_error:=0.0
	for item in Bank.metadata():
		if not item.has("lat"): continue
		var p:=Vector3((item.lon-151.2105)*92400,4.5,(-33.86-item.lat)*111320)
		projection_error=maxf(projection_error,p.distance_to(item.center))
	verify(projection_error<0.03,"documented headquarters coordinates agree with the world projection")
	var roof_high:=-INF
	var westpac_high:=-INF
	var triangles:=0
	var degenerate:=0
	var bad_normals:=0
	var collision_mismatch:=0
	for id: String in world.structures:
		var previous_triangles:int=triangles
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
					if id.begins_with("bank/westpac/"):westpac_high=maxf(westpac_high,actual_y)
					else: roof_high=maxf(roof_high,actual_y)
				var count:=vertices.size() if indices.is_empty() else indices.size()
				triangles+=count/3
				for i in range(0,count,3):
					var x:=i if indices.is_empty() else indices[i]
					var y:=i+1 if indices.is_empty() else indices[i+1]
					var z:=i+2 if indices.is_empty() else indices[i+2]
					var cross:=(vertices[y]-vertices[x]).cross(vertices[z]-vertices[x])
					if cross.length_squared()<0.00000000001:degenerate+=1
					if cross.dot(normals[x]+normals[y]+normals[z])>0.00002:bad_normals+=1
		triangle_components[id]=triangles-previous_triangles
	verify(collision_mismatch==0,"every detailed structural collider uses the identical rendered solid faces")
	verify(degenerate==0,"no zero-area triangles in the bank geometry")
	verify(bad_normals==0,"all faces have outward Godot triangle winding")
	# The photographed public-ground and swept canopy details have an explicit
	# additional 60k-triangle budget; hidden blade box faces are not retained.
	verify(triangles<180000,"combined bank geometry stays within 180k public-detail budget triangles="+str(triangles))
	verify(absf(westpac_high-166.0)<0.02,"Westpac's beacon reaches the published 166m architectural height")
	verify(roof_high>=43.1 and roof_high<43.5,"both CBA roofs retain explicitly estimated 43.2m curved envelopes")
	verify(world.structures.has("bank/westpac/west/30") and world.structures.has("bank/westpac/east/32"),"Westpac massing contains two offset towers with distinct floor counts")
	verify(world.structures.has("bank/cba_south/vaulted_roof") and world.structures.has("bank/cba_north/vaulted_roof"),"both low-rise campus buildings have curved structural roof meshes")
	await physics_frame
	await physics_frame
	var space:=world.get_world_3d().direct_space_state
	check_public_details(world)
	await check_sussex_replacement(world)
	for item: Array in [["westpac",Bank.WESTPAC_WEST_CENTER,Vector3(-80,90,0),Vector3(0,90,0)],["cba_south",Bank.CBA_SOUTH_CENTER,Vector3(0,80,0),Vector3(0,0,0)],["cba_north",Bank.CBA_NORTH_CENTER,Vector3(0,80,0),Vector3(0,0,0)]]:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(item[1]+item[2],item[1]+item[3]))
		verify(not hit.is_empty() and str(hit.collider.get_meta("damage_id","")).begins_with("bank/"+item[0]+"/"),item[0]+" has actual collision at its mapped position")
	var id:="bank/cba_south/floor/03"
	var body: StaticBody3D=world.structures[id].node
	world._destroy_component(id,Vector3.ZERO,0,false)
	await physics_frame
	verify(world.destroyed.has(id) and not body.visible and body.get_child(1).disabled,"floor destruction removes glazing, timber trim and collision together")
	world.apply_state({})
	await physics_frame
	verify(not world.destroyed.has(id) and not body.get_child(1).disabled,"restoration reinstates matching bank collision")
	for test_id in ["bank/westpac/podium","bank/cba_south/floor/00","bank/cba_north/floor/00"]:
		var detail_body:StaticBody3D=world.structures[test_id].node
		world._destroy_component(test_id,Vector3.ZERO,0,false);await physics_frame
		verify(not detail_body.visible and detail_body.get_child(1).disabled,test_id+" public details disappear with their damaged parent")
		world.apply_state({});await physics_frame
		verify(detail_body.visible and not detail_body.get_child(1).disabled,test_id+" public details restore with their parent")
	await walk_public_routes(world)
	verify(walk_records.size()==3 and walk_records.all(func(record):return record.passed),"all three production-player route records exist and pass")
	if "--visual" in OS.get_cmdline_user_args():await capture(world)
	print("BANK CHECK COMPLETE failures=",failures," triangles=",triangles," components=",world.structures.size())
	DirAccess.make_dir_recursive_absolute("res://../reports/bank-v016-detail")
	var file:=FileAccess.open("res://../reports/bank-v016-detail/checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"headless":DisplayServer.get_name()=="headless","checks":checks,"failures":failures,"triangles":triangles,"components":world.structures.size(),"triangles_by_component":triangle_components,"blocked_samples":blocked_samples,"continuous_walks":walk_records,"migration_records":migration_records,"scope":"Isolated bank fixture with a flat support plane matching the game's 4.5m ground; production Player receives forward inputs along each complete route, one initial placement per route and no intermediate teleport. The actual mapped way/544300934 is passed through production City._reserved and build_buildings, with migration containment at street and upper-storey positions. Other city buildings/trees are not in this fixture; complete App review remains separate.","sha256":{"game/scripts/bank_landmarks.gd":FileAccess.get_sha256("res://scripts/bank_landmarks.gd"),"source/bank_landmark_test.gd":FileAccess.get_sha256("res://../source/bank_landmark_test.gd"),"game/scripts/city_map.gd":FileAccess.get_sha256("res://scripts/city_map.gd"),"game/scripts/map_migration.gd":FileAccess.get_sha256("res://scripts/map_migration.gd")}},"\t"));file.close()
	quit(failures)

func check_sussex_replacement(world:Node3D):
	var snapshot:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/city_map.json"))
	var mapped:Dictionary={}
	for item:Dictionary in snapshot.buildings:
		if item.id=="way/544300934":mapped=item;break
	verify(not mapped.is_empty(),"western Sussex mass comes from the actual mapped way/544300934")
	if mapped.is_empty():return
	verify(City._reserved(world,mapped),"production City._reserved excludes the replaced western mass")
	verify(544300934 in Bank.excluded_way_ids() and 544300934 in Bank.metadata()[0].osm_ids and Bank.footprints().size()==9,"Westpac identity/exclusions/footprints include its western mass")
	world.map_snapshot={"buildings":[mapped]}
	City.build_buildings(world,world.map_snapshot)
	verify(not world.structures.has("osm/way/544300934/storey_group/0"),"production city builder cannot recreate the old ground-sealing extrusion")
	var retained:=false
	for item:Dictionary in Migration._geometry(world).mapped:
		if item.id=="way/544300934":retained=true
	verify(not retained,"production migration shares the exact generic exclusion")
	var low:=INF;var high:=-INF;var count:=0
	for id:String in world.structures:
		if not id.begins_with("bank/westpac/sussex/"):continue
		var body:StaticBody3D=world.structures[id].node
		var bounds:AABB=body.get_child(0).mesh.get_aabb()
		low=minf(low,bounds.position.y);high=maxf(high,bounds.end.y);count+=1
	verify(count==17 and absf(low-12.0)<.001 and absf(high-float(mapped.height))<.001,"replacement preserves 63m upper mass and raised 12m lower edge in 17 damage bands")
	var facade:=ProbeGame.new();root.add_child(facade);facade.world=world
	var player=load("res://scripts/harbor_player.gd").new();world.add_child(player);player.enabled=false;facade.player=player
	var positions:Array[Vector3]=[Bank.walk_routes()[0].points[0],Vector3(-635.598754882812,4.49087715148926,705.730224609375)]
	for at:Vector3 in positions:
		player.global_position=at
		var needs:bool=Migration._player_needs_relocation(facade,at)
		verify(not needs,"unchanged Westpac public-route standing pose stays valid for migration "+str(at))
		migration_records.append({"foot":[at.x,at.y,at.z],"needs_relocation":needs,"location":"public_colonnade"})
	var upper:Vector3=Bank.WESTPAC_SUSSEX_CENTER+Vector3(-4,21.2,0)
	player.global_position=upper
	verify(Migration._player_needs_relocation(facade,upper),"player fully inside retained upper Sussex solid still requires relocation")
	var upper_bounds:=AABB(upper+Vector3(-.32,0,-.32),Vector3(.64,1.8,.64))
	verify(Migration.overlaps_new_building(world,upper_bounds),"closed upper-storey containment remains effective without shell contact")
	world._destroy_component("bank/westpac/sussex/03",Vector3.ZERO,0,false);await physics_frame
	verify(not Migration.overlaps_new_building(world,upper_bounds),"destroyed Sussex band removes its collision and occupied interior together")
	world.apply_state({});await physics_frame
	verify(Migration.overlaps_new_building(world,upper_bounds),"restoring Sussex band restores its closed-solid occupancy")
	player.queue_free();facade.queue_free();await physics_frame

func check_public_details(world:Node3D):
	verify(Bank.capture_views().size()==6,"three headquarters each provide two public exterior review views")
	var camera_clear:=true
	for view in Bank.capture_views():
		if not capsule_clear(world,view[1]):camera_clear=false
	verify(camera_clear,"six review camera positions are outside physical bank solids")
	var westpac:StaticBody3D=world.structures["bank/westpac/podium"].node
	verify(westpac.get_meta("photo_public_details",[]).size()==3,"Westpac has pictured soffit panels, recessed lights and glazing fittings")
	var narrowest_column:=INF
	var column_count:=0
	for id:String in world.structures:
		if not id.begins_with("bank/westpac/pier/"):continue
		column_count+=1
		var mesh:Mesh=world.structures[id].node.get_child(0).mesh
		var bound:AABB=mesh.get_aabb()
		narrowest_column=minf(narrowest_column,minf(bound.size.x,bound.size.z))
		verify(bound.size.x<=.8001 and bound.size.z<=.8001 and is_equal_approx(bound.size.y,7.5),id+" rounded support preserves the previous column envelope")
	verify(column_count>15 and narrowest_column>.79,"round colonnade supports retain their original scale and IDs")
	for spec:Array in [["cba_south",Bank.CBA_SOUTH_CENTER,Bank.CBA_SOUTH_POINTS],["cba_north",Bank.CBA_NORTH_CENTER,Bank.CBA_NORTH_POINTS]]:
		var lobby:StaticBody3D=world.structures["bank/%s/floor/00"%spec[0]].node
		verify(lobby.get_meta("photo_public_details",[]).size()==3,str(spec[0])+" has swept lattice and partial timber soffit")
		var low:=INF;var high:=-INF;var canopy_faces:=0
		for child in lobby.get_children():
			if not child is MeshInstance3D or child.get_meta("public_detail","")!="cba_canopy":continue
			for point:Vector3 in child.mesh.get_faces():
				var p:Vector3=child.transform*point
				low=minf(low,p.y);high=maxf(high,p.y);canopy_faces+=1
		verify(low>4.0 and high<5.9 and canopy_faces>500,str(spec[0])+" actual curved canopy meshes clear pedestrian heads y="+str([low,high]))
		var sections:Array=Bank.canopy_sections(Bank.Geo.polygon(spec[2]),spec[0])
		var samples:=0;var clear:=true
		for i in range(1,sections.size()):
			if sections[i].first:continue
			var a:Vector3=spec[1]+sections[i-1].position+sections[i-1].outward*1.6
			var b:Vector3=spec[1]+sections[i].position+sections[i].outward*1.6
			var steps:int=maxi(1,ceili(a.distance_to(b)/.25))
			for j in steps+1:
				samples+=1
				if not capsule_clear(world,a.lerp(b,float(j)/steps)+Vector3.UP*1.05):clear=false
		verify(clear and samples>150,str(spec[0])+" continuous 1.8m capsule strip under public canopy remains clear samples="+str(samples))
	for route:Array in [["Westpac open colonnade",Bank.WESTPAC_PODIUM_CENTER+Vector3(-29,1.05,0),Bank.WESTPAC_PODIUM_CENTER+Vector3(-27,1.05,31)],["CBA central public connector",Vector3(-754,5.55,1688),Vector3(-727,5.55,1668)]]:
		var a:Vector3=route[1];var b:Vector3=route[2];var clear:=true
		var count:int=ceili(a.distance_to(b)/.25)
		for i in count+1:
			if not capsule_clear(world,a.lerp(b,float(i)/count)):clear=false
		verify(clear,str(route[0])+" retains a continuous capsule-clear public route")

func capsule_clear(world:Node3D,center:Vector3)->bool:
	var shape:=CapsuleShape3D.new();shape.radius=.30;shape.height=1.8
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=center
	var hits:Array=world.get_world_3d().direct_space_state.intersect_shape(query)
	if not hits.is_empty() and blocked_samples.size()<40:blocked_samples.append({"center":[center.x,center.y,center.z],"colliders":hits.map(func(hit):return str(hit.collider.get_meta("damage_id",hit.collider.name)))})
	return hits.is_empty()

func walk_public_routes(world:Node3D):
	var floor:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new()
	shape.size=Vector3(400,.30,1300);collider.shape=shape;floor.add_child(collider)
	floor.position=Vector3(-700,4.35,1200);world.add_child(floor)
	for action in ["forward","back","left","right","sprint","jump"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	var routes:Array=Bank.walk_routes()
	var valid_routes:bool=routes.size()==3 and routes.all(func(route):return route.get("points",[]).size()>=2)
	verify(valid_routes,"three public walk routes have complete point lists before movement starts")
	if not valid_routes:return
	for route in routes:
		var player=load("res://scripts/harbor_player.gd").new();world.add_child(player)
		player.global_position=route.points[0]+Vector3.UP*.10;player.last_safe=player.global_position;player.enabled=true
		player.reset_physics_interpolation()
		for frame in 20:await physics_frame
		var reached:=true;var segments:Array=[];var elapsed_frames:=0
		for target:Vector3 in route.points.slice(1):
			var frames:=0
			while frames<2400:
				var delta:Vector3=target-player.global_position
				if Vector2(delta.x,delta.z).length()<.25:break
				player.yaw=atan2(-delta.x,-delta.z)
				Input.action_press("forward");await physics_frame;frames+=1
			Input.action_release("forward")
			for frame in 5:await physics_frame
			elapsed_frames+=frames
			var distance:float=Vector2(target.x-player.position.x,target.z-player.position.z).length()
			var segment_ok:bool=distance<.50 and absf(target.y-player.position.y)<.25
			segments.append({"target":[target.x,target.y,target.z],"actual":[player.position.x,player.position.y,player.position.z],"frames":frames,"reached":segment_ok})
			if not segment_ok:reached=false;break
		verify(reached,route.name+" production Player walks the complete public route with no mid-route teleport")
		if route.name=="westpac_public_colonnade":
			var facade:=ProbeGame.new();root.add_child(facade);facade.world=world;facade.player=player
			var needs:bool=Migration._player_needs_relocation(facade,player.global_position)
			verify(not needs,"actual continuous Westpac walk endpoint remains valid for production save migration")
			migration_records.append({"foot":[player.position.x,player.position.y,player.position.z],"needs_relocation":needs,"location":"actual_walk_endpoint"})
			facade.queue_free()
		walk_records.append({"name":route.name,"passed":reached,"physics_frames":elapsed_frames,"physics_hz":Engine.physics_ticks_per_second,"segments":segments})
		player.queue_free();await physics_frame

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
		"westpac":[Bank.WESTPAC_PODIUM_CENTER+Vector3(-180,100,150),Bank.WESTPAC_PODIUM_CENTER+Vector3(0,79,0)],
		"westpac_roof":[Bank.WESTPAC_PODIUM_CENTER+Vector3(120,172,100),Bank.WESTPAC_PODIUM_CENTER+Vector3(0,115,0)],
		"cba_south":[Bank.CBA_SOUTH_CENTER+Vector3(-125,27,30),Bank.CBA_SOUTH_CENTER+Vector3(0,20,0)],
		"cba_campus":[Bank.CBA_SOUTH_CENTER+Vector3(-180,140,-70),Bank.CBA_SOUTH_CENTER+Vector3(-30,18,-35)],
		"cba_roof":[Bank.CBA_SOUTH_CENTER+Vector3(-80,110,80),Bank.CBA_SOUTH_CENTER+Vector3(0,25,0)]
	}
	for view in Bank.capture_views():views[view[0]]=[view[1],view[2]]
	DirAccess.make_dir_recursive_absolute("/tmp/harbourlife-bank-review")
	for label: String in views:
		var center: Vector3=Bank.WESTPAC_PODIUM_CENTER if label.begins_with("westpac") else Bank.CBA_SOUTH_CENTER
		var ground: MeshInstance3D=world._box(world,center-Vector3.UP*0.3,Vector3(700,0.6,700),"paving",false)
		camera.position=views[label][0];camera.look_at(views[label][1])
		for i in range(10):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/harbourlife-bank-review/"+label+".png")
		ground.queue_free()
