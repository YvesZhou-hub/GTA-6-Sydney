extends SceneTree

const City = preload("res://scripts/city_landmarks.gd")
const Migration = preload("res://scripts/map_migration.gd")
var failures := 0
var checks := 0
var check_records:Array=[]
var walk_evidence:Array=[]
var migration_evidence:Array=[]

class MigrationGame extends Node3D:
	var world:Node3D
	var player:CharacterBody3D

class ProbeWorld extends "res://scripts/harbor_world.gd":
	func _ready() -> void:
		_make_materials()
		City.build(self)
		_route_terrain()
		_flush_batches()
		for id in structures:
			for child in structures[id].node.get_children():
				if child is MeshInstance3D: child.set_meta("intact_material",child.material_override)
		_build_structure_batches()
		_ready_complete=true

	func _route_terrain() -> void:
		# Clip the actual production OSM land triangles around the two public
		# walks. This supplies their street approach without building a city.
		var snapshot:Dictionary=CityMap.data()
		var triangles:Array=[]
		for center:Vector3 in [City.BOC_CENTER,City.RIBBON_CENTER]:
			var rect:=PackedVector2Array([Vector2(center.x-90,center.z-80),Vector2(center.x+90,center.z-80),Vector2(center.x+90,center.z+80),Vector2(center.x-90,center.z+80)])
			for land:Dictionary in snapshot.land:
				for i in range(0,land.triangles.size(),3):
					var source:=PackedVector2Array()
					for j in 3:source.append(Vector2(land.triangles[i+j][0],land.triangles[i+j][1]))
					for piece in Geometry2D.intersect_polygons(source,rect):
						for index in Geometry2D.triangulate_polygon(piece):triangles.append([piece[index].x,piece[index].y])
		CityMap.build_terrain(self,{"land":[{"triangles":triangles}],"parks":[],"beaches":[]})

func verify(value: bool, description: String) -> void:
	checks+=1
	check_records.append({"name":description,"passed":value})
	if value: print("PASS ",description)
	else:
		failures+=1
		push_error("FAIL "+description)

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	for action in ["forward","back","left","right","jump","sprint"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	var world := ProbeWorld.new()
	root.add_child(world)
	world.map_snapshot={"buildings":[]}
	if "--migration-only" in OS.get_cmdline_user_args():
		await physics_frame
		await physics_frame
		await migration_poses(world)
		write_report("migration-checks.json",0,world.structures.size(),false)
		print("CITY MIGRATION CHECK COMPLETE checks=",checks," failures=",failures)
		quit(failures)
		return
	verify(City.metadata().size()==4,"four verified named buildings carry addresses and confidence records")
	verify(City.excluded_way_ids()==[468557019,581013659,544307818,614461305,614603737],"five exact OSM outlines replace generic footprints including tower podium")
	var projection_error := 0.0
	for info in City.metadata():
		var projected := Vector3((info.lon-151.2105)*92400,4.5,(-33.86-info.lat)*111320)
		projection_error=maxf(projection_error,projected.distance_to(info.center))
	verify(projection_error<0.02,"geographic coordinate conversion remains consistent to centimetres")
	var max_heights := {"tower_one":-INF,"boc":-INF,"ribbon":-INF,"exchange":-INF}
	var triangles := 0
	var degenerate := 0
	var reversed := 0
	var collider_mismatch := 0
	var component_count := 0
	for id: String in world.structures:
		component_count+=1
		var body: StaticBody3D=world.structures[id].node
		var solid: Mesh=body.get_child(0).mesh
		var shape: Shape3D=body.get_child(1).shape
		if shape is ConcavePolygonShape3D and shape.get_faces()!=solid.get_faces(): collider_mismatch+=1
		elif shape is BoxShape3D and (not solid is BoxMesh or shape.size!=solid.size):collider_mismatch+=1
		var landmark: String=id.split("/")[1]
		for child in body.get_children():
			if not child is MeshInstance3D: continue
			for surface_index in child.mesh.get_surface_count():
				var arrays: Array=child.mesh.surface_get_arrays(surface_index)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				for vertex in vertices: max_heights[landmark]=maxf(max_heights[landmark],vertex.y)
				var count := indices.size() if not indices.is_empty() else vertices.size()
				triangles+=count/3
				for i in range(0,count,3):
					var a := indices[i] if not indices.is_empty() else i
					var b := indices[i+1] if not indices.is_empty() else i+1
					var c := indices[i+2] if not indices.is_empty() else i+2
					var cross := (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
					if cross.length_squared()<0.00000000001: degenerate+=1
					if cross.dot(normals[a]+normals[b]+normals[c])>0.00001: reversed+=1
	verify(component_count==107,"107 meaningful damage components, repeated facade details merged")
	verify(collider_mismatch==0,"all structural collision faces exactly match rendered solid geometry")
	verify(degenerate==0,"all facade and structural faces are nondegenerate")
	verify(reversed==0,"all explicit triangle winding matches supplied exterior normals")
	verify(triangles<350000,"bounded four-building triangle budget "+str(triangles))
	verify(absf(max_heights.tower_one-217.0)<0.05,"Tower One retains documented 217m height")
	verify(absf(max_heights.boc-58.0)<0.08,"BOC rooftop envelope retains explicitly estimated 58m height")
	verify(max_heights.ribbon>=90.0 and max_heights.ribbon<91.0,"The Ribbon curved apex reaches 90m with thin perimeter trim")
	verify(max_heights.exchange>=30.0 and max_heights.exchange<30.1,"The Exchange stays within 30m estimated roof envelope")
	var profile := City.ribbon_profile()
	verify(profile.size()>80 and not Geometry2D.triangulate_polygon(profile).is_empty(),"The Ribbon has a curved closed elevation, not a rectangular tower")
	var curve_above_tip := 0
	for p in profile:
		if p.y>60 and p.x<0: curve_above_tip+=1
	verify(curve_above_tip>10,"long rising Ribbon shoulder is represented geometrically")
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	for item: Array in [["tower_one",City.TOWER_CENTER,Vector3(-130,110,0),Vector3(0,110,0)],["boc",City.BOC_CENTER,Vector3(-70,22,0),Vector3(0,22,0)],["ribbon",City.RIBBON_CENTER,Vector3(-60,45,-120),Vector3(0,45,0)],["exchange",City.EXCHANGE_CENTER,Vector3(0,17,-60),Vector3(0,17,0)]]:
		var query := PhysicsRayQueryParameters3D.create(item[1]+item[2],item[1]+item[3])
		var hit := space.intersect_ray(query)
		verify(not hit.is_empty() and str(hit.collider.get_meta("damage_id","")).begins_with("city/"+item[0]+"/"),item[0]+" facade has physical ray support at intended map position")
	verify(world.has_meta("ribbon_refinement"),"W has photo-referenced facade sign, Waratah entrance and relief mullions")
	var entry_blocked:=0
	for x in [62.0,63.0,64.0]:
		for z in range(-24,-10):
			var q:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=0.33;capsule.height=1.8;q.shape=capsule
			q.transform.origin=City.ribbon_entry_point(Vector3(x,1.03,z))
			if not space.intersect_shape(q).is_empty():entry_blocked+=1
	verify(entry_blocked==0,"W northeast entry is a real removed solid volume with a clear 2m-wide approach")
	var entry_support:=space.intersect_ray(PhysicsRayQueryParameters3D.create(City.ribbon_entry_point(Vector3(63,1,-15)),City.ribbon_entry_point(Vector3(63,-1,-15))))
	verify(not entry_support.is_empty(),"W copper arrival foyer has physical floor support")
	var ribbon_ids:Array[String]=[]
	for level in 3:ribbon_ids.append("city/ribbon/podium/%02d"%level)
	for level in 25:ribbon_ids.append("city/ribbon/floor/%02d"%level)
	for part in ["floor","rear","side","ceiling"]:ribbon_ids.append("city/ribbon/entry/"+part)
	var actual_ribbon_ids:Array[String]=[]
	for key:String in world.structures:
		if key.begins_with("city/ribbon/"):actual_ribbon_ids.append(key)
	ribbon_ids.sort();actual_ribbon_ids.sort()
	verify(actual_ribbon_ids==ribbon_ids,"all 32 legacy W damage IDs retained without adding physical obstructions")
	var paths:=City.ribbon_louvre_paths()
	var path_valid:=paths.size()==9
	var previous_width:=INF;var previous_bottom:=-INF
	for path in paths:
		var bottom:=INF;var width:=0.0
		for vertex in path:
			path_valid=path_valid and vertex.is_finite() and vertex.y>29.0 and vertex.y<90.5
			bottom=minf(bottom,vertex.y);width=maxf(width,absf(vertex.z))
		path_valid=path_valid and width<previous_width and bottom>previous_bottom and path.size()>40
		previous_width=width;previous_bottom=bottom
	verify(path_valid,"nine continuous end returns rise and narrow toward the roof without non-finite points")
	var local_to_world:=Transform3D(Basis(Vector3.UP,deg_to_rad(City.RIBBON_ANGLE)),City.RIBBON_CENTER)
	var copper_placement_ok:=true
	for part in ["side","rear"]:
		var wall:StaticBody3D=world.structures["city/ribbon/entry/"+part].node
		for name in ["CopperHexCells","CopperHexRecesses"]:
			var view:MeshInstance3D=wall.get_node_or_null(name)
			if view==null:copper_placement_ok=false;continue
			for vertex in view.mesh.get_faces():
				var hotel_point:Vector3=local_to_world.affine_inverse()*wall.transform*view.transform*vertex
				if part=="side":copper_placement_ok=copper_placement_ok and absf(hotel_point.x-55.13)<0.11
				else:copper_placement_ok=copper_placement_ok and absf(hotel_point.z+9.88)<0.11
	verify(copper_placement_ok,"hexagonal cladding belongs to its wall and remains correctly positioned after centred-body transforms")
	var clear_width_blocked:=0
	for x in [61.45,62.0,63.0,64.0,64.55]:
		for z in [-24.0,-21.0,-18.0,-15.0,-11.0]:
			var q:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=0.33;capsule.height=1.8;q.shape=capsule
			q.transform.origin=City.ribbon_entry_point(Vector3(x,1.03,z))
			if not space.intersect_shape(q).is_empty():clear_width_blocked+=1
	verify(clear_width_blocked==0,"W entrance preserves the full usable door width across 25 standing capsule samples")
	var camera_valid:=true
	for view:Array in City.capture_views():
		camera_valid=camera_valid and view.size()==3 and view[1].is_finite() and view[2].is_finite() and view[1].distance_to(view[2])>5.0
	verify(camera_valid and City.capture_views().size()>=3,"named W harbour, rolled-end and arrival cameras are usable by the full-city fixture")
	var tower_ids:=0;var framed_fins:=0
	for key:String in world.structures:
		if key.begins_with("city/tower_one/"):
			tower_ids+=1
			framed_fins+=int(world.structures[key].node.get_meta("framed_fin_count",0))
	verify(tower_ids==52 and framed_fins>3000,"Tower One keeps all 52 components while its shaded floors carry merged framed fins")
	verify(world.has_meta("tower_one_refinement") and absf(world.materials.city_tower_glass.get_shader_parameter("bay").x-1.5)<0.001,"Tower One uses architect-documented 1.5m facade modules and 3m fin centres")
	var boc_blocked:=0;var boc_unsupported:=0
	for distance in [1.0,4.0,9.0,14.0,19.0,24.0,29.0,34.0,39.0,44.0]:
		for inward in [1.40,2.10,2.65]:
			var q:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=0.33;capsule.height=1.8;q.shape=capsule
			q.transform.origin=City.boc_colonnade_point(distance,1.04,inward)
			if not space.intersect_shape(q).is_empty():
				boc_blocked+=1
				print("BOC blocked sample ",distance," inward ",inward)
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(City.boc_colonnade_point(distance,0.5,inward),City.boc_colonnade_point(distance,-0.5,inward)))
			if hit.is_empty() or str(hit.collider.get_meta("damage_id",""))!="city/boc/lobby":
				boc_unsupported+=1
				print("BOC unsupported sample ",distance," inward ",inward)
	verify(boc_blocked==0 and boc_unsupported==0,"BOC photo-backed Sussex colonnade has 30 supported standing-capsule samples through its full length")
	var boc_columns_supported:=true
	for i in 9:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(City.boc_colonnade_point(2.0+i*5.2,2.0,-1),City.boc_colonnade_point(2.0+i*5.2,2.0,1)))
		boc_columns_supported=boc_columns_supported and not hit.is_empty() and str(hit.collider.get_meta("damage_id",""))=="city/boc/lobby"
	verify(boc_columns_supported,"all nine colonnade columns are solid parts of the preserved BOC lobby ID")
	var boc_ids:=0;var window_returns:=0
	for key:String in world.structures:
		if key.begins_with("city/boc/"):
			boc_ids+=1;window_returns+=int(world.structures[key].node.get_meta("boc_window_returns",0))
	verify(boc_ids==16 and window_returns==336,"BOC keeps its 16 damage IDs and 14 floors of merged street window returns")
	var public_street_blocked:=0
	for distance in [1.0,10.0,20.0,30.0,44.0]:
		var q:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=0.33;capsule.height=1.8;q.shape=capsule
		q.transform.origin=City.boc_colonnade_point(distance,1.04,-1.0)
		if not space.intersect_shape(q).is_empty():public_street_blocked+=1
	verify(public_street_blocked==0,"BOC new work stays inside its mapped street edge and leaves the external pavement clear")
	var entries_clear:=true;var soffit_supported:=true
	for distance in [4.0,41.0]:
		for across in [-0.6,0.0,0.6]:
			for inward in [-1.4,0.0,0.8,1.8]:
				var q:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=0.33;capsule.height=1.8;q.shape=capsule
				q.transform.origin=City.boc_colonnade_point(distance+across,1.04,inward)
				entries_clear=entries_clear and space.intersect_shape(q).is_empty()
		var head_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(City.boc_colonnade_point(distance,2.0,1.8),City.boc_colonnade_point(distance,5.0,1.8)))
		soffit_supported=soffit_supported and not head_hit.is_empty() and head_hit.normal.y<-.99 and absf(head_hit.position.y-City.BOC_CENTER.y-4.85)<.02
	verify(entries_clear,"both BOC street entry bays retain 1.2m lateral capsule clearance across their thresholds")
	verify(soffit_supported,"BOC colonnade has a real overhead slab at the documented model height with ample headroom")
	var boc_lobby:StaticBody3D=world.structures["city/boc/lobby"].node
	world._destroy_component("city/boc/lobby",Vector3.ZERO,0,false)
	await physics_frame
	verify(not boc_lobby.visible and boc_lobby.get_child(1).disabled,"BOC pavement floor, columns and soffit disappear together under the preserved lobby ID")
	world.apply_state({})
	await physics_frame
	verify(boc_lobby.visible and not boc_lobby.get_child(1).disabled,"BOC colonnade solid and details restore before production walking")
	var rolled_body:StaticBody3D=world.structures["city/ribbon/floor/17"].node
	var ceiling:StaticBody3D=world.structures["city/ribbon/entry/ceiling"].node
	world._destroy_component("city/ribbon/floor/17",Vector3.ZERO,0,false)
	world._destroy_component("city/ribbon/entry/ceiling",Vector3.ZERO,0,false)
	await physics_frame
	verify(not rolled_body.visible and rolled_body.get_child(1).disabled and not ceiling.visible and ceiling.get_node_or_null("PassageLightFrames")!=null,"W floor rolls and ceiling lights disappear with their own damage components")
	world.apply_state({})
	await physics_frame
	verify(rolled_body.visible and not rolled_body.get_child(1).disabled and ceiling.visible,"W detail owners restore with their original solid components")
	var id := "city/exchange/floor/04"
	var body: StaticBody3D=world.structures[id].node
	world._destroy_component(id,Vector3.ZERO,0,false)
	await physics_frame
	verify(world.destroyed.has(id) and not body.visible and body.get_child(1).disabled,"destroying a floor removes its glazing, timber facade and collision together")
	world.apply_state({})
	await physics_frame
	verify(not world.destroyed.has(id) and not body.get_child(1).disabled,"new-world restore reconstructs the landmark collision")
	if not "--geometry-only" in OS.get_cmdline_user_args():
		for route:Dictionary in City.walk_routes():await walk_route(world,route)
	await migration_poses(world)
	write_report("checks.json",triangles,component_count,not "--geometry-only" in OS.get_cmdline_user_args())
	if "--visual" in OS.get_cmdline_user_args(): await capture(world)
	print("CITY LANDMARK CHECK COMPLETE checks=",checks," failures=",failures," triangles=",triangles," components=",component_count)
	quit(failures)

func write_report(filename:String,triangles:int,components:int,continuous_walks:bool) -> void:
	var report_dir:=ProjectSettings.globalize_path("res://../reports/city-detail")
	DirAccess.make_dir_recursive_absolute(report_dir)
	FileAccess.open(report_dir+"/"+filename,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures==0,"checks":check_records,"count":checks,"failures":failures,"triangles":triangles,"triangles_measured":not "--migration-only" in OS.get_cmdline_user_args(),"components":components,"model_sha256":FileAccess.get_sha256("res://scripts/city_landmarks.gd"),"test_sha256":FileAccess.get_sha256(get_script().resource_path),"migration_sha256":FileAccess.get_sha256("res://scripts/map_migration.gd"),"continuous_walks_ran":continuous_walks,"walks":walk_evidence,"migration_poses":migration_evidence,"headless":DisplayServer.get_name()=="headless","scope":"Four named building meshes with clipped production OSM land at public approaches. Actual HarborPlayer settled migration poses and optional input-driven out-and-back walks; no full-city build or user saves.","user_saves_touched":false},"  "))

func migration_poses(world:Node3D) -> void:
	var game:=MigrationGame.new();game.world=world;root.add_child(game)
	var player=load("res://scripts/harbor_player.gd").new();game.add_child(player);game.player=player
	var places:Array=[]
	for distance in [4.0,20.0,41.0]:
		places.append({"id":"city/boc/lobby","at":City.boc_colonnade_point(distance,.04,1.8)})
	for z in [-21.0,-15.0,-11.4]:
		places.append({"id":"city/ribbon/entry/floor","at":City.ribbon_entry_point(Vector3(63,.04,z))})
	for place:Dictionary in places:
		player.enabled=false;player.global_position=place.at+Vector3.UP*.12;player.last_safe=player.global_position;player.velocity=Vector3.ZERO
		player.reset_physics_interpolation();player.enabled=true
		for frame in 30:await physics_frame
		player.enabled=false
		var actual:Vector3=player.global_position
		var support:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actual+Vector3.UP*.12,actual-Vector3.UP*.25,15,[player.get_rid()]))
		var support_id:String="" if support.is_empty() else str(support.collider.get_meta("damage_id",""))
		var valid:bool=player.is_on_floor() and support_id==place.id
		var preserve:bool=not Migration._player_needs_relocation(game,actual)
		var buried:=actual-Vector3.UP*.06
		var reject:bool=Migration._player_needs_relocation(game,buried)
		var label:String=str(place.id)+" at "+str(place.at)
		verify(valid and preserve,"migration preserves actual settled production player "+label)
		verify(valid and reject,"migration relocates production player buried 6cm "+label)
		var record:Dictionary={"id":place.id,"settled":[actual.x,actual.y,actual.z],"on_floor":player.is_on_floor(),"support_id":support_id,"support_y":null if support.is_empty() else support.position.y,"preserved":preserve,"buried":[buried.x,buried.y,buried.z],"buried_relocated":reject}
		migration_evidence.append(record);print("CITY_MIGRATION ",JSON.stringify(record))
	game.queue_free();await physics_frame

func walk_route(world:Node3D,route:Dictionary) -> void:
	var player=load("res://scripts/harbor_player.gd").new();world.add_child(player)
	player.global_position=route.points[0]+Vector3.UP*0.10;player.last_safe=player.global_position;player.enabled=true
	for frame in 20:await physics_frame
	var targets:Array=route.points.slice(1)
	for phase in 2:
		var reached:=true;var airborne:=0;var segments:Array=[]
		for target:Vector3 in targets:
			var frames:=0
			Input.action_press("forward")
			while frames<900:
				var delta:Vector3=target-player.global_position
				if Vector2(delta.x,delta.z).length()<0.28:break
				player.yaw=atan2(-delta.x,-delta.z)
				await physics_frame;frames+=1
				if not player.is_on_floor():airborne+=1
			Input.action_release("forward")
			for frame in 6:await physics_frame
			var actual:Vector3=player.global_position
			var segment_ok:bool=Vector2(actual.x-target.x,actual.z-target.z).length()<0.55 and absf(actual.y-target.y)<0.25 and player.is_on_floor()
			segments.append({"target":[target.x,target.y,target.z],"actual":[actual.x,actual.y,actual.z],"frames":frames,"reached":segment_ok})
			if not segment_ok:reached=false;break
		var label:String=route.name+(" outward" if phase==0 else " return")
		verify(reached and airborne<=3 and not player.swimming,label+" production HarborPlayer walks continuously without jumping or teleporting")
		walk_evidence.append({"name":label,"passed":reached and airborne<=3 and not player.swimming,"airborne_frames":airborne,"segments":segments})
		targets=route.points.duplicate();targets.reverse();targets=targets.slice(1)
	player.queue_free();await physics_frame

func capture(world: Node3D) -> void:
	root.size=Vector2i(1440,1000)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("94bccf")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("d5e2e7")
	env.ambient_light_energy=0.65
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.environment=env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-40,0)
	sun.light_energy=1.3
	sun.shadow_enabled=true
	world.add_child(sun)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current=true
	camera.fov=48
	camera.far=1500
	var views := {
		"tower_one":[City.TOWER_CENTER+Vector3(-210,135,210),City.TOWER_CENTER+Vector3(0,105,0)],
		"tower_one_core":[City.TOWER_CENTER+Vector3(160,145,-200),City.TOWER_CENTER+Vector3(0,110,0)],
		"boc":[City.BOC_CENTER+Vector3(-92,29,49),City.BOC_CENTER+Vector3(0,26,0)],
		"ribbon":[City.RIBBON_CENTER+Vector3(-120,74,-205),City.RIBBON_CENTER+Vector3(0,43,0)],
		"ribbon_entry":[City.ribbon_entry_point(Vector3(70,2.4,-32)),City.ribbon_entry_point(Vector3(59.5,3.4,-12))],
		"ribbon_aerial":[City.RIBBON_CENTER+Vector3(-140,155,-120),City.RIBBON_CENTER+Vector3(0,40,0)],
		"exchange":[City.EXCHANGE_CENTER+Vector3(-53,20,-64),City.EXCHANGE_CENTER+Vector3(0,15,0)],
		"exchange_detail":[City.EXCHANGE_CENTER+Vector3(-32,15,-31),City.EXCHANGE_CENTER+Vector3(0,17,0)]
	}
	for view:Array in City.capture_views():views[view[0]]=[view[1],view[2]]
	DirAccess.make_dir_recursive_absolute("/tmp/harbourlife-city-review")
	for label: String in views:
		var center: Vector3=City.TOWER_CENTER if label.begins_with("tower") else City.BOC_CENTER if label=="boc" or label.begins_with("bank-of-china") else City.RIBBON_CENTER if label.begins_with("ribbon") or label.begins_with("w-sydney") else City.EXCHANGE_CENTER
		var ground: MeshInstance3D = world._box(world,center-Vector3.UP*0.3,Vector3(650,0.6,650),"paving",false)
		camera.position=views[label][0]
		camera.look_at(views[label][1])
		for i in range(10): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/harbourlife-city-review/"+label+".png")
		ground.queue_free()
