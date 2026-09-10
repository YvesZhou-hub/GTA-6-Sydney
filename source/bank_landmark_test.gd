extends SceneTree
const Bank=preload("res://scripts/bank_landmarks.gd")
var failures:=0

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
	verify(Bank.excluded_way_ids().size()==8,"all eight custom footprint parts have explicit OSM exclusions")
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
	verify(collision_mismatch==0,"every detailed structural collider uses the identical rendered solid faces")
	verify(degenerate==0,"no zero-area triangles in the bank geometry")
	verify(bad_normals==0,"all faces have outward Godot triangle winding")
	verify(triangles<120000,"combined bank geometry remains bounded triangles="+str(triangles))
	verify(absf(westpac_high-166.0)<0.02,"Westpac's beacon reaches the published 166m architectural height")
	verify(roof_high>=43.1 and roof_high<43.5,"both CBA roofs retain explicitly estimated 43.2m curved envelopes")
	verify(world.structures.has("bank/westpac/west/30") and world.structures.has("bank/westpac/east/32"),"Westpac massing contains two offset towers with distinct floor counts")
	verify(world.structures.has("bank/cba_south/vaulted_roof") and world.structures.has("bank/cba_north/vaulted_roof"),"both low-rise campus buildings have curved structural roof meshes")
	await physics_frame
	await physics_frame
	var space:=world.get_world_3d().direct_space_state
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
	if "--visual" in OS.get_cmdline_user_args():await capture(world)
	print("BANK CHECK COMPLETE failures=",failures," triangles=",triangles," components=",world.structures.size())
	quit(failures)

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
	DirAccess.make_dir_recursive_absolute("/tmp/harbourlife-bank-review")
	for label: String in views:
		var center: Vector3=Bank.WESTPAC_PODIUM_CENTER if label.begins_with("westpac") else Bank.CBA_SOUTH_CENTER
		var ground: MeshInstance3D=world._box(world,center-Vector3.UP*0.3,Vector3(700,0.6,700),"paving",false)
		camera.position=views[label][0];camera.look_at(views[label][1])
		for i in range(10):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/harbourlife-bank-review/"+label+".png")
		ground.queue_free()
