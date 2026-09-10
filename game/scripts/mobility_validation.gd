extends Node3D
## Real production rigid body + Input actions, isolated from player saves.
var stage: Node3D
var vehicle: RigidBody3D
var checks: Array=[]
var captures: Array=[]
var camera: Camera3D
var worst_health:=100.0
var native:=false

func _ready(): call_deferred("run")
func check(label: String, passed: bool, metrics: Dictionary={}):
	checks.append({"name":label,"passed":passed,"metrics":metrics})
	print("MOBILITY ","PASS " if passed else "FAIL ",label," ",JSON.stringify(metrics))
func frames(count: int):
	for i in count:
		await get_tree().physics_frame
		if is_instance_valid(vehicle): worst_health=minf(worst_health,vehicle.health)
func reset_input():
	for action in ["forward","back","left","right","rise","fall","brake"]: Input.action_release(action)
func box(size: Vector3, position3d: Vector3):
	var solid:=StaticBody3D.new()
	var shape:=BoxShape3D.new();shape.size=size
	var collider:=CollisionShape3D.new();collider.shape=shape;solid.add_child(collider)
	var mesh:=MeshInstance3D.new();var cube:=BoxMesh.new();cube.size=size
	mesh.mesh=cube;solid.add_child(mesh)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("859ba6")
	mesh.material_override=mat
	solid.position=position3d;stage.add_child(solid)
	return solid
func fresh(at: Vector3, floor_enabled:=true):
	reset_input()
	if is_instance_valid(stage): stage.queue_free();await get_tree().process_frame
	stage=Node3D.new();add_child(stage)
	if floor_enabled: box(Vector3(1600,2,12000),Vector3(0,3.5,0))
	vehicle=load("res://scripts/harbor_vehicle.gd").new()
	vehicle.configure("hoverboard","qa_aether_"+str(Time.get_ticks_usec()))
	vehicle.position=at;stage.add_child(vehicle);vehicle.occupied=true
	await frames(2)
func capture(label: String, offset:=Vector3(4,2.5,5)):
	if not native:return
	camera.position=vehicle.position+offset
	camera.look_at(vehicle.position+Vector3.UP*.7)
	for i in 4:await get_tree().process_frame
	var screenshot:=get_viewport().get_texture().get_image()
	var path:="user://mobility-qa/"+label+".png"
	var result:=screenshot.save_png(path)
	captures.append({"name":label+".png","saved":result==OK})

func run():
	native=DisplayServer.get_name()!="headless"
	Engine.physics_ticks_per_second=60
	for action in ["forward","back","left","right","rise","fall","brake"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	DirAccess.make_dir_recursive_absolute("user://mobility-qa")
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("aec5d2")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=.65;add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-46,-35,0);sun.light_energy=1.3;sun.shadow_enabled=true;add_child(sun)
	camera=Camera3D.new();camera.far=5000;add_child(camera);camera.current=true
	await fresh(Vector3(0,5.5,0))
	await frames(120)
	check("hover settles at one metre clearance",absf(vehicle.position.y-5.5)<.12 and absf(vehicle.linear_velocity.y)<.1,{"y":vehicle.position.y,"vertical_speed":vehicle.linear_velocity.y})
	await capture("aether-front")
	Input.action_press("forward")
	await frames(600)
	check("200 km/h reached through acceleration",vehicle.speed_kmh>=199.0 and vehicle.speed_kmh<=200.5,{"kmh":vehicle.speed_kmh,"distance_m":-vehicle.position.z,"health":vehicle.health})
	Input.action_release("forward");Input.action_press("brake")
	await frames(180)
	check("emergency brake stops within three seconds",vehicle.linear_velocity.length()<.15,{"kmh":vehicle.speed_kmh})
	reset_input();Input.action_press("forward",.4);Input.action_press("right",.35)
	var start_yaw:=vehicle.rotation.y
	await frames(90)
	check("steering changes course while moving",absf(angle_difference(start_yaw,vehicle.rotation.y))>.25,{"yaw_radians":vehicle.rotation.y,"kmh":vehicle.speed_kmh})
	await fresh(Vector3(0,5.5,12))
	for i in 24: box(Vector3(10,(i+1)*.22,.6),Vector3(0,4.5+(i+1)*.11,-i*.6))
	box(Vector3(12,5.28,80),Vector3(0,7.14,-54.1))
	Input.action_press("forward",.25)
	var stair_captured:=false
	for i in 250:
		await frames(1)
		if native and not stair_captured and vehicle.position.z< -5.5:
			stair_captured=true
			await capture("aether-stairs",Vector3(10,7,13))
	check("climbs 24 physical stair risers",vehicle.position.z< -19 and vehicle.position.y>10.5 and vehicle.health>99.9,{"position":[vehicle.position.x,vehicle.position.y,vehicle.position.z],"health":vehicle.health})
	await fresh(Vector3(0,1,0),false)
	Input.action_press("forward",.6);await frames(180)
	check("crosses water without sinking",vehicle.position.z< -35 and absf(vehicle.position.y-1.0)<.15 and vehicle.health>99.9,{"height":vehicle.position.y,"distance_m":-vehicle.position.z})
	reset_input();Input.action_press("rise");await frames(120);reset_input();await frames(120)
	check("manual lift holds height after release",vehicle.position.y>19 and vehicle.position.y<22 and absf(vehicle.linear_velocity.y)<.1,{"height":vehicle.position.y,"vertical_speed":vehicle.linear_velocity.y})
	var state:Dictionary=vehicle.get_state()
	var clone=load("res://scripts/harbor_vehicle.gd").new();clone.configure("hoverboard","qa_restore_hover")
	clone.apply_state(JSON.parse_string(JSON.stringify(state)));stage.add_child(clone)
	check("save restores hoverboard class pose and lift",clone.kind=="hoverboard" and clone.position.is_equal_approx(vehicle.position) and is_equal_approx(float(clone.get_meta("hover_lift_offset",0.0)),float(vehicle.get_meta("hover_lift_offset",0.0))),{"lift_offset":clone.get_meta("hover_lift_offset",0)})
	clone.queue_free();await get_tree().process_frame
	Input.action_press("fall");await frames(180);reset_input();await frames(60)
	check("lowering stops safely above water",absf(vehicle.position.y-1)<.15 and vehicle.health>99.9,{"height":vehicle.position.y,"health":vehicle.health})
	await fresh(Vector3(0,5.5,0))
	box(Vector3(6,30,1),Vector3(0,19.5,-18))
	Input.action_press("forward",.3);await frames(300)
	check("wall protection brakes before solid wall",vehicle.position.z> -18 and vehicle.position.is_finite() and vehicle.health>99.9,{"z":vehicle.position.z,"health":vehicle.health})
	await fresh(Vector3(0,55,0),false)
	box(Vector3(300,2,300),Vector3(0,53,0))
	await frames(120)
	Input.action_press("rise");await frames(1080);reset_input();await frames(180)
	var low:=INF;var high:=-INF;var vertical_peak:=0.0
	for i in 180:
		await frames(1)
		low=minf(low,vehicle.position.y);high=maxf(high,vehicle.position.y)
		vertical_peak=maxf(vertical_peak,absf(vehicle.linear_velocity.y))
	check("maximum lift above elevated bridge remains stable",absf(vehicle.position.y-235)<.20 and high-low<.10 and vertical_peak<.10 and vehicle.health>99.9,{"height":vehicle.position.y,"expected":235.0,"height_range":high-low,"vertical_peak":vertical_peak,"health":vehicle.health})
	reset_input()
	var sound=load("res://scripts/harbor_audio.gd").new();add_child(sound)
	sound.footstep(false,Vector3.ZERO)
	check("walking no longer plays synthesized step",not sound.step.playing)
	sound.ambient.stop();sound.cue.stop();sound.step.stop()
	sound.ambient.stream=null;sound.cue.stream=null;sound.step.stream=null
	await get_tree().create_timer(.10,true,false,true).timeout
	sound.queue_free()
	var report:={"passed":checks.all(func(c):return c.passed),"engine":Engine.get_version_info().string,"native":native,"physics_hz":60,"input":"Godot production Input actions; no pose or velocity edits after each fixture creation","checks":checks,"screenshots":captures}
	FileAccess.open("user://mobility-qa/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MOBILITY_REPORT ",JSON.stringify(report))
	stage.queue_free();await frames(10)
	get_tree().quit(0 if report.passed else 1)
