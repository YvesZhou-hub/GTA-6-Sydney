extends SceneTree
const MANLY = preload("res://scripts/manly_landmarks.gd")
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
func verify(value: bool, message: String) -> void:
	if value: print("PASS ",message)
	else:
		failures+=1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world=LocalManly.new() if "--local-context" in OS.get_cmdline_user_args() else load("res://scripts/harbor_world.gd").new()
	root.add_child(world)
	if not world.has_meta("manly_landmarks"):
		MANLY.build(world)
		world._flush_batches()
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	verify(world.get_meta("manly_landmarks",[]).size()==3,"three Manly landmark groups integrated")
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
	if "--capture" in OS.get_cmdline_user_args(): await capture(world)
	print("MANLY CHECK COMPLETE failures=",failures)
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
	var folder:=ProjectSettings.globalize_path("res://../reports/manly-refinement")
	DirAccess.make_dir_recursive_absolute(folder)
	for view: Array in views:
		camera.global_position=view[1];camera.look_at(view[2])
		for i in range(5):await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(folder+"/"+view[0]+".png")
		print("MANLY FRAME ",view[0])
