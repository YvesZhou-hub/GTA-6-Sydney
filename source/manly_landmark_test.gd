extends SceneTree
const MANLY = preload("res://scripts/manly_landmarks.gd")
const MIGRATION = preload("res://scripts/map_migration.gd")
class NavigationGame extends Node3D:
	var world:Node3D
	var player:CharacterBody3D
	var vehicles:Array=[]
	var yaw:float=0.0
class PalmWorld:
	extends "res://scripts/harbor_world.gd"
	func _ready() -> void:
		_make_materials()
		load("res://scripts/manly_landmarks.gd")._materials(self)
class LocalManly:
	extends "res://scripts/harbor_world.gd"
	func _ready() -> void:
		_make_materials()
		map_snapshot=CityMap.data()
		map_snapshot.buildings=map_snapshot.buildings.filter(func(item): return Vector2(item.center[0]-7084,item.center[1]+6936).length()<1000)
		map_snapshot.roads=map_snapshot.roads.filter(func(item):
			for p in item.points:
				if Vector2(p[0]-7084,p[1]+6936).length()<1200:return true
			return false)
		var sea:=MeshInstance3D.new()
		var plane:=PlaneMesh.new();plane.size=Vector2(12000,12000)
		sea.mesh=plane;sea.position=Vector3(7084,0,-6936)
		var water_material:=ShaderMaterial.new();water_material.shader=WATER;sea.material_override=water_material
		add_child(sea)
		CityMap.build_terrain(self,map_snapshot)
		CityMap.build_roads(self,map_snapshot)
		CityMap.build_buildings(self,map_snapshot)
		load("res://scripts/manly_landmarks.gd").build(self)
		_flush_batches()
		_build_structure_batches()
		_ready_complete=true

var failures := 0
var checks:Array=[]
var route_records:Array=[]
var navigation_records:Array=[]
var floor_records:Array=[]
func verify(value: bool, message: String) -> void:
	checks.append({"name":message,"passed":value})
	if value: print("PASS ",message)
	else:
		failures+=1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	await check_palm_geometry()
	if "--palm-only" in OS.get_cmdline_user_args():
		quit(failures)
		return
	var world=load("res://scripts/harbor_world.gd").new() if "--full-world" in OS.get_cmdline_user_args() else LocalManly.new()
	root.add_child(world)
	if not world.has_meta("manly_landmarks"):
		MANLY.build(world)
		world._flush_batches()
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	verify(world.get_meta("manly_landmarks",[]).size()==4,"four canonical Manly navigation destinations integrated")
	verify(world.get_meta("manly_mapped_trees",0)>40,"real OSM Manly tree points populated")
	var courtyard := MANLY.HOTEL_CENTER+Vector3(-5,20,-8)
	var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(courtyard,courtyard-Vector3.UP*18))
	verify(hit.is_empty(),"Hotel Steyne real courtyard stays open through roof and storeys")
	var pavement := MANLY.geo(-33.7977726,151.2870193,4.6)
	hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(pavement+Vector3.UP,pavement-Vector3.UP))
	verify(not hit.is_empty(),"The Corso has actual supporting pavement")
	var blocked:=0
	var a:=MANLY.geo(MANLY.CORSO_ROUTE[0][0],MANLY.CORSO_ROUTE[0][1],4.61)
	var b:=MANLY.geo(MANLY.CORSO_ROUTE[-1][0],MANLY.CORSO_ROUTE[-1][1],4.61)
	var shape:=BoxShape3D.new();shape.size=Vector3(1.2,2.0,1.2)
	for i in range(0,int(a.distance_to(b)),2):
		var p:=a+(b-a).normalized()*i
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=shape;query.transform.origin=p+Vector3.UP*1.07
		if not space.intersect_shape(query).is_empty():blocked+=1
	verify(blocked==0,"The Corso central pedestrian route is unobstructed: %s"%blocked)
	var entry:=MANLY.WHARF_CENTER+Vector3(-10,1.2,-40)
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=entry
	verify(space.intersect_shape(query).is_empty(),"Manly Wharf north entrance concourse remains open")
	var roofid: String="manly/steyne/roof"
	verify(world.structures.has(roofid),"landmarks participate in persistent structural damage")
	await check_navigation(world)
	await check_wharf_floor(world)
	await check_details_and_walk(world)
	if "--capture" in OS.get_cmdline_user_args(): await capture(world)
	var triangles:=0;var components:=0
	for id:String in world.structures:
		if not id.begins_with("manly/"):continue
		components+=1
		for child in world.structures[id].node.get_children():
			if child is MeshInstance3D:triangles+=child.mesh.get_faces().size()/3
	DirAccess.make_dir_recursive_absolute("res://../reports/manly-v017")
	FileAccess.open("res://../reports/manly-v017/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures==0,"checks":checks,"failures":failures,"headless":DisplayServer.get_name()=="headless","routes":route_records,"navigation":navigation_records,"wharf_floor":floor_records,"manly_structure_triangles":triangles,"manly_components":components,"scope":"Manly local context with production mapped terrain/roads/buildings and production Player. Canonical geography registry, actual capsule/support, settled arrivals, temporary legacy-height migration and closed curved palm crown geometry are checked. No user saves read or written. Structural triangles exclude separate instanced trees and street furniture. Full native App visual acceptance is separate.","sha256":{"game/scripts/manly_landmarks.gd":FileAccess.get_sha256("res://scripts/manly_landmarks.gd"),"source/manly_landmark_test.gd":FileAccess.get_sha256("res://../source/manly_landmark_test.gd"),"game/assets/landmark_geography.json":FileAccess.get_sha256("res://assets/landmark_geography.json"),"game/scripts/map_migration.gd":FileAccess.get_sha256("res://scripts/map_migration.gd")}},"\t"))
	print("MANLY CHECK COMPLETE failures=",failures," checks=",checks.size()," triangles=",triangles," components=",components)
	quit(failures)
func capture(world: Node3D) -> void:
	root.size=Vector2i(1440,900)
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("9bb7c6")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("c6d6dd")
	environment.ambient_light_energy=0.6
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var env:=WorldEnvironment.new();env.environment=environment;world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-35,0);sun.light_energy=1.5;sun.shadow_enabled=true;world.add_child(sun)
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.far=2500
	var views: Array = [
		["wharf",MANLY.WHARF_CENTER+Vector3(40,38,-125),MANLY.WHARF_CENTER+Vector3(-10,6,-20)],
		["corso",MANLY.CORSO_CENTER+Vector3(80,3,-49),MANLY.CORSO_CENTER+Vector3(-40,5,33)],
		["steyne",MANLY.HOTEL_CENTER+Vector3(32,6.5,40),MANLY.HOTEL_CENTER+Vector3(7,5,12)],
		["manly_overview",MANLY.CORSO_CENTER+Vector3(260,240,170),MANLY.CORSO_CENTER+Vector3(0,0,0)]
	]
	views.append_array(MANLY.capture_views())
	var folder:=ProjectSettings.globalize_path("res://../reports/manly-refinement")
	DirAccess.make_dir_recursive_absolute(folder)
	for view: Array in views:
		camera.global_position=view[1];camera.look_at(view[2])
		for i in range(5):await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(folder+"/"+view[0]+".png")
		print("MANLY FRAME ",view[0])

func check_details_and_walk(world:Node3D):
	verify(world.has_meta("manly_public_hall"),"photo-informed public wharf waiting/information hall built")
	verify(MANLY.capture_views().size()==5,"five explicit exterior/interior review views")
	verify(world.structures.has("manly/wharf/public/wayfinding") and world.structures.has("manly/wharf/public/information"),"public hall has direction panels and information-side display")
	for id in [1638701005,1638695147,1638694159]:verify(world.structures.has("manly/corso/bubbler/%s"%id),"actual mapped Corso drinking node "+str(id))
	var collision_mismatch:=0;var degenerate:=0
	for id:String in world.structures:
		if not id.begins_with("manly/"):continue
		var body:StaticBody3D=world.structures[id].node
		var mesh:Mesh=body.get_child(0).mesh;var shape:Shape3D=body.get_child(1).shape
		if shape is ConcavePolygonShape3D and shape.get_faces()!=mesh.get_faces():collision_mismatch+=1
		var faces:PackedVector3Array=mesh.get_faces()
		for i in range(0,faces.size(),3):
			if (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length_squared()<.00000000001:degenerate+=1
	verify(collision_mismatch==0,"all Manly structural mesh faces match their collision shells")
	verify(degenerate==0,"no degenerate Manly structural triangles")
	var mapped_bubblers:Dictionary={1638701005:MANLY.geo(-33.798233,151.2860878,4.595),1638695147:MANLY.geo(-33.7976369,151.2872951,4.595),1638694159:MANLY.geo(-33.7972054,151.2878537,4.595)}
	var position_error:=0.0
	for node_id in mapped_bubblers:
		position_error=maxf(position_error,world.structures["manly/corso/bubbler/%s"%node_id].node.position.distance_to(mapped_bubblers[node_id]+Vector3.UP*.52))
	verify(position_error<.002,"three bubbler structure positions retain mapped nodes without street relocation")
	var id:="manly/wharf/public/seat/-1/-21"
	var body:StaticBody3D=world.structures[id].node
	world._destroy_component(id,Vector3.ZERO,0,false);await physics_frame
	verify(not body.visible and body.get_child(1).disabled,"new waiting seat and collision disappear together on damage")
	world.apply_state({});await physics_frame
	verify(body.visible and not body.get_child(1).disabled,"new waiting seat restores after repair")
	for action in ["forward","back","left","right","sprint","jump"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	for route:Dictionary in MANLY.walk_routes():
		var player=load("res://scripts/harbor_player.gd").new();world.add_child(player)
		player.global_position=route.points[0]+Vector3.UP*.12;player.last_safe=player.global_position;player.enabled=true;player.reset_physics_interpolation()
		for frame in 20:await physics_frame
		var segments:Array=[];var passed:=true;var total_frames:=0
		for target:Vector3 in route.points.slice(1):
			var frames:=0
			while frames<2400:
				var delta:Vector3=target-player.global_position
				if Vector2(delta.x,delta.z).length()<.25:break
				player.yaw=atan2(-delta.x,-delta.z);Input.action_press("forward")
				await physics_frame;frames+=1
			Input.action_release("forward")
			for frame in 4:await physics_frame
			var distance:float=Vector2(target.x-player.position.x,target.z-player.position.z).length()
			var ok:bool=distance<.50 and absf(target.y-player.position.y)<.30
			segments.append({"target":[target.x,target.y,target.z],"actual":[player.position.x,player.position.y,player.position.z],"frames":frames,"passed":ok});total_frames+=frames
			if not ok:passed=false;break
		verify(passed,route.name+" production Player completes the continuous route without intermediate teleport")
		route_records.append({"name":route.name,"passed":passed,"segments":segments,"physics_frames":total_frames,"physics_hz":Engine.physics_ticks_per_second})
		player.queue_free();await physics_frame

func check_navigation(world:Node3D) -> void:
	for action in ["forward","back","left","right","sprint","jump"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	var original_centroids:Dictionary={
		"manly_wharf":Vector3(6827.12007,4.5,-6676.8296),
		"hotel_steyne":Vector3(7127.76613,4.5,-7016.6439),
		"manly_corso":Vector3(7070.38332,4.5,-6927.15417),
		"manly_beach":Vector3(7194.29172,4.5,-7007.66079)}
	var original_arrivals:Dictionary={
		"manly_wharf":Vector3(6809.88,4.5,-6753.7844),
		"hotel_steyne":Vector3(7157.304,4.5,-6999.8016),
		"manly_corso":Vector3(7070.38332,4.5,-6927.15417),
		"manly_beach":Vector3(7194.29172,4.5,-7007.66079)}
	var before:Array[Dictionary]=MANLY.metadata()
	var unique:Dictionary={}
	for item:Dictionary in before:unique[item.id]=true
	verify(unique.size()==4 and not unique.has("the_corso") and unique.has_all(original_centroids.keys()),"Manly has four unique canonical IDs and no duplicate Corso icon record")
	world._register_landmark_geography()
	var catalog:Dictionary=world.get_meta("landmark_geography")
	verify(catalog.the_corso.id=="manly_corso" and catalog.the_corso==catalog.manly_corso and world.anchors.the_corso==world.anchors.manly_corso,"legacy the_corso alias resolves to the canonical manly_corso destination")
	var facade:=NavigationGame.new();root.add_child(facade);facade.world=world
	var player=load("res://scripts/harbor_player.gd").new();facade.add_child(player);facade.player=player
	var capsule:CollisionShape3D=player.get_child(0)
	var space:PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	await physics_frame
	for item:Dictionary in before:
		var at:Vector3=item.arrival
		var old:Vector3=original_arrivals[item.id]
		var corrected:bool=item.id in ["manly_corso","hotel_steyne"]
		verify(item.map_position==original_centroids[item.id] and at.x==old.x and at.z==old.z and is_equal_approx(at.y,4.595 if corrected else old.y),item.id+" retains mapped centroid and horizontal public arrival; only required paving height changes")
		var integrated:Dictionary={}
		for entry:Dictionary in world.get_meta("manly_landmarks"):
			if entry.id==item.id:integrated=entry;break
		verify(catalog[item.id].map_position==item.map_position and catalog[item.id].arrival==at and integrated.map_position==item.map_position and integrated.arrival==at and world.anchors[item.id]==at,item.id+" metadata, world registration and anchor share canonical navigation geometry")
		player.position=at;player.enabled=false
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule.shape;query.transform=capsule.global_transform;query.margin=0.0;query.exclude=[player.get_rid()];query.collision_mask=15
		var hits:Array=space.intersect_shape(query,20)
		var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.12,at-Vector3.UP*.25,15,[player.get_rid()]))
		var supported:bool=not hit.is_empty() and hit.normal.y>.99 and absf(hit.position.y-at.y)<.002
		verify(supported and hits.is_empty(),item.id+" public foot arrival has supporting pavement and zero-margin production capsule clearance")
		verify(not MIGRATION._player_needs_relocation(facade,at) and MIGRATION.apply(facade)==0 and player.position==at,item.id+" clear legacy-save stance survives production migration without relocation")
		player.enabled=true;player.velocity=Vector3.ZERO
		for frame in 30:await physics_frame
		player.enabled=false
		var settled:Vector3=player.global_position
		verify(player.is_on_floor() and settled.distance_to(at)<.025 and not MIGRATION._player_needs_relocation(facade,settled),item.id+" settles on its public support and remains migration-safe")
		var row:Dictionary={"id":item.id,"arrival":[at.x,at.y,at.z],"map_position":[item.map_position.x,item.map_position.y,item.map_position.z],"support_id":str(hit.collider.get_meta("damage_id",hit.collider.name)) if not hit.is_empty() else "none","support_y":hit.position.y if not hit.is_empty() else null,"capsule_hits":hits.size(),"settled":[settled.x,settled.y,settled.z]}
		if corrected:
			player.global_position=old
			var blocked:bool=MIGRATION._player_needs_relocation(facade,old)
			var relocated:int=MIGRATION.apply(facade)
			var repaired:Vector3=player.global_position
			verify(blocked and relocated==1 and Vector2(repaired.x-old.x,repaired.z-old.z).length()<.01 and repaired.y>old.y and repaired.y-old.y<.2 and not MIGRATION._player_needs_relocation(facade,repaired),item.id+" old below-paving save repairs locally without changing its horizontal location")
			row["legacy_floor_repair"]={"moved":relocated,"position":[repaired.x,repaired.y,repaired.z]}
		navigation_records.append(row)
	var paving_at:Vector3=catalog.manly_corso.arrival
	var floor_hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(paving_at+Vector3.UP*.3,paving_at-Vector3.UP*.3,15,[player.get_rid()]))
	verify(not floor_hit.is_empty() and MIGRATION._player_ground_allowed(facade,floor_hit),"registered live Corso paving is a valid player recovery support")
	world._destroy_component("manly/corso/paving",Vector3.ZERO,0,false);await physics_frame
	verify(not floor_hit.is_empty() and not MIGRATION._player_ground_allowed(facade,floor_hit),"destroyed Corso paving is rejected even with a stale support hit")
	world.apply_state({});await physics_frame;await physics_frame
	var information:StaticBody3D=world.structures["manly/wharf/public/information"].node
	var obstacle_hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(information.position+Vector3.UP*2,information.position,15,[player.get_rid()]))
	verify(not obstacle_hit.is_empty() and obstacle_hit.collider==information and not MIGRATION._player_ground_allowed(facade,obstacle_hit),"actual information-wall top is not accepted as a public recovery floor")
	facade.queue_free();await physics_frame

func check_palm_geometry() -> void:
	var world:=PalmWorld.new();root.add_child(world)
	var result:Dictionary=MANLY.palm_crown_geometry(11.0)
	var profiles:Array=result.profiles
	verify(profiles.size()==34,"palm crown has 24 green split-fan leaves and 10 hanging old leaves")
	var degenerate:=0;var bad_normal:=0;var bad_edge:=0;var triangles:=0
	var bounds:AABB=result.green.get_aabb().merge(result.old.get_aabb())
	var mesh_rows:Array=[]
	for key:String in ["green","old"]:
		var mesh:ArrayMesh=result[key]
		var array:Array=mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=array[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=array[Mesh.ARRAY_NORMAL]
		var faces:PackedVector3Array=mesh.get_faces()
		var edges:Dictionary={}
		for normal:Vector3 in normals:
			if not normal.is_finite() or absf(normal.length()-1.0)>.001:bad_normal+=1
		for i in range(0,faces.size(),3):
			var area:Vector3=(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i])
			if area.length_squared()<1e-12:degenerate+=1
			if area.dot(normals[i])>=-1e-8:bad_normal+=1
			for j in 3:
				var a:Vector3=faces[i+j];var b:Vector3=faces[i+(j+1)%3]
				var ka:String="%s,%s,%s"%[roundi(a.x*1000000),roundi(a.y*1000000),roundi(a.z*1000000)]
				var kb:String="%s,%s,%s"%[roundi(b.x*1000000),roundi(b.y*1000000),roundi(b.z*1000000)]
				var edge:String=ka+"|"+kb if ka<kb else kb+"|"+ka
				edges[edge]=int(edges.get(edge,0))+1
		for count:int in edges.values():
			if count!=2:bad_edge+=1
		triangles+=faces.size()/3
		mesh_rows.append({"material":key,"triangles":faces.size()/3,"vertices":vertices.size(),"closed_edge_count":edges.size()})
	verify(degenerate==0,"folded leaf strips and curved stems have no degenerate triangles")
	verify(bad_edge==0,"all leaf lobes and stems have closed surfaces with two incident faces per edge")
	verify(bad_normal==0,"all crown surface normals are finite, normalized and agree with front-face winding")
	verify(bounds.position.y>7.0 and bounds.end.y<15.0 and maxf(absf(bounds.position.x),absf(bounds.end.x))<4.2 and maxf(absf(bounds.position.z),absf(bounds.end.z))<4.2,"new crown stays above pedestrians and within the bounded radial canopy")
	var old_droops:=0;var curved_stems:=0;var fan_min:=INF;var fan_max:=-INF
	for profile:Dictionary in profiles:
		var middle:Vector3=profile.stalk[3]
		if middle.distance_to(profile.start.lerp(profile.fan_start,.5))>.10:curved_stems+=1
		verify(profile.tips.size()==13,"frond %s has thirteen individual split leaf lobes"%profiles.find(profile))
		for tip:Vector3 in profile.tips:
			fan_min=minf(fan_min,tip.y);fan_max=maxf(fan_max,tip.y)
		if profile.tier==2 and profile.tips[6].y<profile.start.y-1.2:old_droops+=1
	verify(curved_stems==34 and old_droops==10,"all stalks arch and the ten old central fan tips visibly droop")
	verify(fan_max-fan_min>3.0,"leaf tips span multiple crown heights instead of a coplanar umbrella")
	var strip:=SurfaceTool.new();strip.begin(Mesh.PRIMITIVE_TRIANGLES)
	MANLY._palm_strip(strip,PackedVector3Array([Vector3.ZERO,Vector3(0,.2,.4),Vector3(0,.3,.8),Vector3(0,.1,1.2),Vector3(0,-.2,1.6),Vector3(0,-.5,1.8)]),Vector3.RIGHT,Vector3.UP,.13)
	var sample:ArrayMesh=MANLY._finish(strip)
	var sample_vertices:PackedVector3Array=sample.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var upper:=false;var lower:=false;var right:=false;var left:=false
	for vertex:Vector3 in sample_vertices:
		if vertex.distance_to(Vector3(0,.3,.8))<.15:
			if vertex.y>.32:upper=true
			if vertex.y<.29:lower=true
			if vertex.x>.10:right=true
			if vertex.x<-.10:left=true
	verify(upper and lower and right and left,"actual leaf section has a raised folded ridge, underside and two lateral edges")
	var points:Array[Vector3]=[]
	var poly:=MANLY.polygon(MANLY.CORSO_POINTS)
	for item:Dictionary in world.CityMap.data().trees:
		var point:=Vector2(item.point[0],item.point[1])
		if Geometry2D.is_point_in_polygon(point-Vector2(MANLY.CORSO_CENTER.x,MANLY.CORSO_CENTER.z),poly):points.append(Vector3(point.x,4.595,point.y))
	verify(points.size()>0,"crown fixture uses existing actual mapped Corso tree points")
	for point:Vector3 in points:MANLY._palm(world,point,11.0)
	var instance_count:=0;var bad_instance:=0;var colliders:=0
	for child in world.get_children():
		if child is CollisionObject3D:colliders+=1
		if child is MeshInstance3D and child.get_meta("manly_palm_crown",false):
			instance_count+=1
			if child.position not in points or (child.mesh!=result.green and child.mesh!=result.old):bad_instance+=1
	verify(instance_count==points.size()*2 and bad_instance==0,"all generated crowns retain exact source tree positions and share two cached meshes")
	verify(colliders==0 and world.structures.is_empty(),"visual crown refinement creates no collision or persistent building components")
	var report:Dictionary={"passed":failures==0,"checks":checks,"failures":failures,"headless":DisplayServer.get_name()=="headless","crown_triangles_per_tree":triangles,"meshes":mesh_rows,"crown_bounds":{"position":[bounds.position.x,bounds.position.y,bounds.position.z],"size":[bounds.size.x,bounds.size.y,bounds.size.z]},"mapped_corso_points":points.size(),"instances":instance_count,"leaf_sections":{"lobes_per_frond":13,"fold_above_center_m":[.018,.043],"underside_below_center_m":.018,"stem_radii_m":[.070,.027]},"scope":"Only visual palm crown geometry changed. Tree positions, 11m estimated trunks, other tree species, buildings, roads, collision and navigation unchanged. No continuous routes rerun: their previous 47-check evidence remains separate. Native visual acceptance is pending the parent App review.","sha256":{"game/scripts/manly_landmarks.gd":FileAccess.get_sha256("res://scripts/manly_landmarks.gd"),"source/manly_landmark_test.gd":FileAccess.get_sha256("res://../source/manly_landmark_test.gd")}}
	DirAccess.make_dir_recursive_absolute("res://../reports/manly-palm")
	FileAccess.open("res://../reports/manly-palm/checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MANLY PALM COMPLETE checks=",checks.size()," failures=",failures," triangles=",triangles," bounds=",bounds)
	world.queue_free();await process_frame

func check_wharf_floor(world:Node3D) -> void:
	var platform:StaticBody3D=world.structures["manly/wharf/platform"].node
	var mesh:MeshInstance3D=platform.get_child(0)
	var collision:CollisionShape3D=platform.get_child(1)
	check_floor_mesh_dimensions(mesh,collision)
	var facade:=NavigationGame.new();root.add_child(facade);facade.world=world
	var player=load("res://scripts/harbor_player.gd").new();facade.add_child(player);facade.player=player
	var capsule:CollisionShape3D=player.get_child(0)
	var space:PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	var land:MeshInstance3D=world.get_node("OSM_Land_0").get_child(0)
	await physics_frame
	for local:Vector3 in [Vector3(-4,0,-6),Vector3(-4,0,-31),Vector3(-10,0,-21),Vector3(3,0,-22)]:
		var old:Vector3=MANLY.WHARF_CENTER+local
		var at:Vector3=old+Vector3.UP*MANLY.WHARF_FLOOR
		var top:float=surface_height_at(mesh,at)
		var terrain_top:float=surface_height_at(land,at)
		var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.2,at-Vector3.UP*.2,15,[player.get_rid()]))
		verify(is_equal_approx(top,4.54) and is_equal_approx(terrain_top,4.5) and not hit.is_empty() and hit.collider==platform and absf(hit.position.y-top)<.001,"wharf floor %s render and collision agree 4cm above the proven coincident terrain"%local)
		player.global_position=at
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule.shape;query.transform=capsule.global_transform;query.margin=0;query.exclude=[player.get_rid()];query.collision_mask=15
		verify(space.intersect_shape(query,1).is_empty() and not MIGRATION._player_needs_relocation(facade,at) and MIGRATION.apply(facade)==0 and player.position==at,"wharf floor %s valid current stance remains unchanged"%local)
		player.global_position=old
		var old_blocked:bool=MIGRATION._player_needs_relocation(facade,old)
		var shifted:int=MIGRATION.apply(facade)
		var migrated:Vector3=player.global_position
		verify(old_blocked and shifted==1 and migrated.x==old.x and migrated.z==old.z and absf(migrated.y-4.58)<.002 and not MIGRATION._player_needs_relocation(facade,migrated),"wharf floor %s old ground-height save is raised in place without horizontal teleport"%local)
		floor_records.append({"local":[local.x,local.y,local.z],"visible_top":top,"terrain_top":terrain_top,"physical_top":hit.position.y if not hit.is_empty() else null,"legacy_repaired":[migrated.x,migrated.y,migrated.z]})
	var occupied:Vector3=MANLY.WHARF_CENTER+Vector3(-12,MANLY.WHARF_FLOOR,-21)
	player.global_position=occupied
	var blocked_query:=PhysicsShapeQueryParameters3D.new();blocked_query.shape=capsule.shape;blocked_query.transform=capsule.global_transform;blocked_query.exclude=[player.get_rid()];blocked_query.margin=0
	var seat_hits:Array=space.intersect_shape(blocked_query,8)
	verify(seat_hits.any(func(hit):return str(hit.collider.get_meta("damage_id","")).begins_with("manly/wharf/public/seat/")) and MIGRATION._player_needs_relocation(facade,occupied),"new floor support never exempts an actual overlapping public bench")
	var sample:Vector3=MANLY.WHARF_CENTER+Vector3(-4,0,-6)
	var floor_hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(sample+Vector3.UP*.3,sample-Vector3.UP*.2,15,[player.get_rid()]))
	world._destroy_component("manly/wharf/platform",Vector3.ZERO,0,false);await physics_frame;await physics_frame
	verify(not MIGRATION._player_ground_allowed(facade,floor_hit) and not platform.visible and collision.disabled,"destroyed wharf platform rejects stale recovery support and hides/disables matching surfaces")
	world.apply_state({});await physics_frame;await physics_frame
	verify(platform.visible and not collision.disabled and MIGRATION._player_ground_allowed(facade,floor_hit),"repair restores the same wharf platform support and visual surface")
	facade.queue_free();await physics_frame

func surface_height_at(view:MeshInstance3D,at:Vector3) -> float:
	var local:Vector3=view.global_transform.affine_inverse()*at
	var result:float=-INF
	var faces:PackedVector3Array=view.mesh.get_faces()
	for i in range(0,faces.size(),3):
		var hit=Geometry3D.segment_intersects_triangle(local+Vector3.UP*.5,local-Vector3.UP*.5,faces[i],faces[i+1],faces[i+2])
		if hit is Vector3:result=maxf(result,(view.global_transform*hit).y)
	return result

func check_floor_mesh_dimensions(mesh:MeshInstance3D,collision:CollisionShape3D) -> void:
	var aabb:AABB=mesh.mesh.get_aabb()
	var poly:PackedVector2Array=MANLY.polygon(MANLY.WHARF_POINTS)
	var outline:=Rect2(poly[0],Vector2.ZERO)
	for point:Vector2 in poly:outline=outline.expand(point)
	verify(absf(aabb.position.x-outline.position.x)<.001 and absf(aabb.position.z-outline.position.y)<.001 and absf(aabb.end.x-outline.end.x)<.001 and absf(aabb.end.z-outline.end.y)<.001 and is_equal_approx(aabb.position.y,-1.0) and is_equal_approx(aabb.end.y,.04),"wharf platform retains mapped XZ and original bottom, only top moves 4cm")
	verify(collision.shape is ConcavePolygonShape3D and collision.shape.get_faces()==mesh.mesh.get_faces(),"wharf raised top uses exactly the same visible and physical triangle faces")
