extends SceneTree

const City = preload("res://scripts/city_landmarks.gd")
var failures := 0

class ProbeWorld extends "res://scripts/harbor_world.gd":
	func _ready() -> void:
		_make_materials()
		City.build(self)
		_flush_batches()
		for id in structures:
			for child in structures[id].node.get_children():
				if child is MeshInstance3D: child.set_meta("intact_material",child.material_override)
		_build_structure_batches()
		_ready_complete=true

func verify(value: bool, description: String) -> void:
	if value: print("PASS ",description)
	else:
		failures+=1
		push_error("FAIL "+description)

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var world := ProbeWorld.new()
	root.add_child(world)
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
		var solid: ArrayMesh=body.get_child(0).mesh
		var shape: ConcavePolygonShape3D=body.get_child(1).shape
		if shape.get_faces()!=solid.get_faces(): collider_mismatch+=1
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
	verify(component_count==103,"103 meaningful damage components, repeated facade details merged")
	verify(collider_mismatch==0,"all structural collision faces exactly match rendered solid geometry")
	verify(degenerate==0,"all facade and structural faces are nondegenerate")
	verify(reversed==0,"all explicit triangle winding matches supplied exterior normals")
	verify(triangles<240000,"bounded four-building triangle budget "+str(triangles))
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
	var id := "city/exchange/floor/04"
	var body: StaticBody3D=world.structures[id].node
	world._destroy_component(id,Vector3.ZERO,0,false)
	await physics_frame
	verify(world.destroyed.has(id) and not body.visible and body.get_child(1).disabled,"destroying a floor removes its glazing, timber facade and collision together")
	world.apply_state({})
	await physics_frame
	verify(not world.destroyed.has(id) and not body.get_child(1).disabled,"new-world restore reconstructs the landmark collision")
	if "--visual" in OS.get_cmdline_user_args(): await capture(world)
	print("CITY LANDMARK CHECK COMPLETE failures=",failures," triangles=",triangles," components=",component_count)
	quit(failures)

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
		"ribbon_aerial":[City.RIBBON_CENTER+Vector3(-140,155,-120),City.RIBBON_CENTER+Vector3(0,40,0)],
		"exchange":[City.EXCHANGE_CENTER+Vector3(-53,20,-64),City.EXCHANGE_CENTER+Vector3(0,15,0)],
		"exchange_detail":[City.EXCHANGE_CENTER+Vector3(-32,15,-31),City.EXCHANGE_CENTER+Vector3(0,17,0)]
	}
	DirAccess.make_dir_recursive_absolute("/tmp/harbourlife-city-review")
	for label: String in views:
		var center: Vector3=City.TOWER_CENTER if label.begins_with("tower") else City.BOC_CENTER if label=="boc" else City.RIBBON_CENTER if label.begins_with("ribbon") else City.EXCHANGE_CENTER
		var ground: MeshInstance3D = world._box(world,center-Vector3.UP*0.3,Vector3(650,0.6,650),"paving",false)
		camera.position=views[label][0]
		camera.look_at(views[label][1])
		for i in range(10): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/harbourlife-city-review/"+label+".png")
		ground.queue_free()
