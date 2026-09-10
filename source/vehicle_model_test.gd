extends SceneTree
## Local model-only fixture. -- --visual captures authored models without city startup.
const Factory = preload("res://scripts/vehicle_factory.gd")
var checks := 0
var failures := 0
var models := {}
var measurements := {}
var scene: Node3D

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String):
	checks += 1
	if value: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)

func visible_meshes(node: Node3D, result: Array):
	for child in node.get_children():
		if child.is_queued_for_deletion() or not child is Node3D: continue
		if not child.visible: continue
		if child is MeshInstance3D: result.append(child)
		visible_meshes(child,result)

func measure(body: Node3D) -> Dictionary:
	var meshes: Array = []
	visible_meshes(body,meshes)
	var bounds := AABB()
	var first := true
	var triangles := 0
	var invalid := 0
	var bad_normals := 0
	for mesh: MeshInstance3D in meshes:
		var relative := body.global_transform.affine_inverse()*mesh.global_transform
		var box := relative*mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := indices.size() if not indices.is_empty() else vertices.size()
			triangles += count/3
			for point: Vector3 in vertices:
				if not point.is_finite(): invalid += 1
			for i in range(0,count,3):
				var a := indices[i] if not indices.is_empty() else i
				var c := indices[i+1] if not indices.is_empty() else i+1
				var d := indices[i+2] if not indices.is_empty() else i+2
				if a >= vertices.size() or c >= vertices.size() or d >= vertices.size(): invalid += 1
				elif (vertices[c]-vertices[a]).cross(vertices[d]-vertices[a]).dot(normals[a]+normals[c]+normals[d]) > .000001: bad_normals += 1
	var collision_low := INF
	var colliders := 0
	for child in body.get_children():
		if child is CollisionShape3D:
			colliders += 1
			var shape_bounds: AABB = child.transform*child.shape.get_debug_mesh().get_aabb()
			collision_low = minf(collision_low,shape_bounds.position.y)
	return {"bounds":bounds,"meshes":meshes.size(),"triangles":triangles,"invalid":invalid,"bad_normals":bad_normals,"collision_low":collision_low,"colliders":colliders}

func run() -> void:
	scene = Node3D.new()
	root.add_child(scene)
	for kind: String in ["car","motorcycle","airliner"]:
		var body := RigidBody3D.new()
		body.freeze = true
		body.name = "Model_"+kind
		scene.add_child(body)
		var moving := Factory.build(body,kind)
		models[kind] = {"body":body,"moving":moving}
	await process_frame
	await process_frame
	for kind: String in models:
		var body: Node3D = models[kind].body
		var moving: Dictionary = models[kind].moving
		var info: Dictionary = body.get_meta("vehicle_model",{})
		var metrics := measure(body)
		measurements[kind] = metrics
		check(not info.is_empty() and info.features.size() >= 6,kind+" has documented distinct silhouette/detail features")
		check(metrics.invalid == 0,kind+" has finite mesh vertices and valid triangle indices")
		check(metrics.bad_normals == 0,kind+" triangle winding agrees with exterior normals")
		check(absf(metrics.collision_low-float(info.ground))<.006,kind+" actual physics contacts retain original save ground plane")
		check(absf(metrics.bounds.position.y-float(info.ground))<.008,kind+" visible tyres meet the same ground plane")
		var expected_length := 62.8 if kind=="airliner" else 4.947 if kind=="car" else 2.077
		check(absf(metrics.bounds.size.z-expected_length)<.04,kind+" measured visual length follows manufacturer proportions")
		check(metrics.meshes<=85 and metrics.triangles<110000,kind+" static details stay within mesh/triangle budget")
		var expected_wheels := 10 if kind=="airliner" else 4 if kind=="car" else 2
		check(moving.wheels.size()==expected_wheels,kind+" has correct independently animated tyre count")
		var wheels_on_ground := true
		for wheel: Node3D in moving.wheels:
			wheels_on_ground = wheels_on_ground and absf(wheel.position.y-float(wheel.get_meta("radius"))-float(info.ground))<.001
		check(wheels_on_ground,kind+" all wheel radii and positions agree on contact height")
		print("MODEL_METRICS ",kind," ",metrics)
	var car: Dictionary = measurements.car
	check(absf(car.bounds.size.x-2.266)<.025 and absf(car.bounds.end.y-.48)<.012,"supercar mirror width and low 1.16m roof match reference")
	var motorcycle: Dictionary = measurements.motorcycle
	check(absf(motorcycle.bounds.end.y-.485)<.008 and motorcycle.bounds.size.x<=.85,"superbike tall screen and narrow motorcycle silhouette match reference")
	check(models.motorcycle.moving.rider.position==Vector3(0,.12,.40),"seated rider matches new real-scale seat rather than hovering over tank")
	var air: Dictionary = measurements.airliner
	check(absf(air.bounds.size.x-60.1)<.06 and absf(air.bounds.end.y-12.76)<.008,"787-9 has measured 60.1m span and17m ground-to-fin height")
	check(models.airliner.moving.propellers.size()==2,"787 has two independent visible fan assemblies")
	var frozen_body: Node3D = models.car.body
	var old_transform := frozen_body.transform
	models.car.moving.wheels[0].rotate_x(.8)
	check(frozen_body.transform==old_transform and models.car.moving.wheels[1].rotation.is_zero_approx(),"spinning one wheel does not transform chassis or other tyres")
	models.car.moving.wheels[0].rotation=Vector3.ZERO
	if "--visual" in OS.get_cmdline_user_args(): await capture()
	print("VEHICLE MODEL COMPLETE checks=",checks," failures=",failures)
	quit(failures)

func capture() -> void:
	root.size=Vector2i(1600,1000)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("8dabbc")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("d5e3ed")
	env.ambient_light_energy=.72
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env_node.environment=env
	scene.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-37,-38,0)
	sun.light_energy=1.4
	sun.shadow_enabled=true
	scene.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size=Vector2(180,180)
	floor_mesh.mesh=plane
	floor_mesh.material_override=Factory.material(Color("879092"),0,.93)
	scene.add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.current=true
	camera.fov=48
	camera.far=500
	scene.add_child(camera)
	var directory := ProjectSettings.globalize_path("res://../reports/vehicle-refinement")
	DirAccess.make_dir_recursive_absolute(directory)
	for shot in [["car-front","car",Vector3(5.0,1.7,-5.7),Vector3(0,-.12,0)],["car-rear","car",Vector3(-4.6,1.5,5.4),Vector3(0,-.1,.1)],["car-low-front","car",Vector3(4.4,.65,-5.9),Vector3(0,-.12,-.2)],["motorcycle","motorcycle",Vector3(2.3,1.05,-2.4),Vector3(0,-.15,0)],["motorcycle-side","motorcycle",Vector3(3.3,.6,.15),Vector3(0,-.15,0)],["motorcycle-rear","motorcycle",Vector3(-2.1,.7,2.5),Vector3(0,-.15,0)],["motorcycle-low-front","motorcycle",Vector3(1.4,.4,-2.6),Vector3(0,-.08,-.1)],["airliner-front","airliner",Vector3(69,29,-77),Vector3(0,1,0)],["airliner-rear","airliner",Vector3(-62,26,75),Vector3(0,3,1)],["airliner-engine","airliner",Vector3(18,1,-16),Vector3(8.5,-1.4,-4.5)],["airliner-cockpit","airliner",Vector3(8,4,-35),Vector3(0,.4,-28.0)]]:
		for kind: String in models: models[kind].body.visible=kind==shot[1]
		floor_mesh.position.y=float(models[shot[1]].body.get_meta("vehicle_model").ground)-.02
		camera.position=shot[2]
		camera.look_at(shot[3])
		for frame in 20: await process_frame
		await RenderingServer.frame_post_draw
		var path := directory.path_join(str(shot[0])+".png")
		root.get_texture().get_image().save_png(path)
		print("MODEL_CAPTURE ",shot[0])
