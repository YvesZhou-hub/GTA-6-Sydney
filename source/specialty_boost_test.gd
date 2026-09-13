extends SceneTree
## Reproducible production-physics boost test. Run from the repository root:
## tools/runtime/godot --headless --path game --fixed-fps 60 --script res://../source/specialty_boost_test.gd
## Isolated fixtures only; does not load or write player saves.
var stage: Node3D
var vehicle: RigidBody3D
var failures := 0
var checks: Array = []
const BOOST_TARGETS := {"tank":330.0,"hoverboard":600.0,"fighter":6000.0}
func _initialize(): call_deferred("run")
func frames(count:int):
	for i in count: await physics_frame
func check(label:String,passed:bool,metrics:Dictionary):
	print("SPECIALTY ","PASS " if passed else "FAIL ",label," ",JSON.stringify(metrics))
	checks.append({"name":label,"passed":passed,"metrics":metrics})
	if not passed: failures+=1
func box(size:Vector3,at:Vector3):
	var solid:=StaticBody3D.new()
	var collider:=CollisionShape3D.new()
	var shape:=BoxShape3D.new(); shape.size=size; collider.shape=shape
	solid.add_child(collider);solid.position=at;stage.add_child(solid)
func fresh(kind:String):
	for action in ["forward","back","left","right","rise","fall","brake","boost"]:
		Input.action_release(action)
	if is_instance_valid(stage): stage.queue_free(); await process_frame
	stage=Node3D.new();root.add_child(stage)
	if kind!="fighter": box(Vector3(100000,2,100000),Vector3(0,3999,0))
	vehicle=load("res://scripts/harbor_vehicle.gd").new()
	vehicle.configure(kind,"qa_specialty_boost_"+kind)
	vehicle.position=Vector3(0,5000 if kind=="fighter" else 4001.0,0)
	stage.add_child(vehicle);vehicle.occupied=true
	await frames(120)
func run():
	Engine.physics_ticks_per_second=60
	for action in ["forward","back","left","right","rise","fall","brake","boost"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	for kind in ["tank","hoverboard","fighter"]:
		await fresh(kind)
		Input.action_press("forward");Input.action_press("boost")
		await frames(900)
		var boosted:=vehicle.linear_velocity.length()*3.6
		var target:float=BOOST_TARGETS[kind]
		check(kind+" reaches boosted target",vehicle.is_boosting() and is_equal_approx(vehicle.effective_top_speed_kmh(),target) and boosted>target*.95 and boosted<target*1.015,{"kmh":boosted,"target":target,"height":vehicle.position.y})
		var heading_before:=vehicle.rotation.y
		Input.action_press("right")
		if kind=="fighter":Input.action_press("rise",.3)
		await frames(120)
		var turn_delta:=absf(wrapf(vehicle.rotation.y-heading_before,-PI,PI))
		check(kind+" retains controlled boosted steering",turn_delta>.03 and vehicle.global_basis.y.dot(Vector3.UP)>.75 and vehicle.linear_velocity.is_finite(),{"heading_change":turn_delta,"up_dot":vehicle.global_basis.y.dot(Vector3.UP),"height":vehicle.position.y,"kmh":vehicle.linear_velocity.length()*3.6})
		Input.action_release("right");Input.action_release("rise")
		Input.action_release("boost")
		var initial_velocity:=vehicle.linear_velocity.length()
		await frames(1)
		var first_step:=vehicle.linear_velocity.length()
		await frames(300)
		check(kind+" releases boost without velocity snap",first_step>initial_velocity*.9 and vehicle.linear_velocity.length()<initial_velocity,{"before_mps":initial_velocity,"after_one_tick":first_step,"after_five_seconds":vehicle.linear_velocity.length()})
		Input.action_press("boost");Input.action_press("brake")
		await frames(720)
		check(kind+" brake overrides held boost",not vehicle.is_boosting() and vehicle.linear_velocity.length()<(72.0 if kind=="fighter" else 1.0),{"kmh":vehicle.linear_velocity.length()*3.6,"boost":vehicle.is_boosting()})
	await fresh("hoverboard")
	Input.action_press("forward");Input.action_press("boost");await frames(600)
	var wall_entry_speed:float=vehicle.linear_velocity.length()*3.6
	var predicted:float=vehicle.get_meta("hover_stopping_distance",0.0)
	var wall_z:float=vehicle.position.z-predicted-25.0
	box(Vector3(100,200,2),Vector3(0,4100,wall_z))
	var start:=vehicle.position.z
	var minimum:=INF
	for i in 900:
		await frames(1)
		minimum=minf(minimum,vehicle.position.z-wall_z)
	check("boosted hoverboard stops before tall wall",wall_entry_speed>590.0 and minimum>1.5,{"entry_kmh":wall_entry_speed,"minimum_distance_from_wall_center":minimum,"predicted_stop_distance":predicted,"travel":start-vehicle.position.z,"health":vehicle.health,"kmh":vehicle.linear_velocity.length()*3.6})
	var report:={"passed":failures==0,"checks":checks,"count":checks.size(),"failures":failures,"engine":Engine.get_version_info().string,"physics_hz":Engine.physics_ticks_per_second,"native":DisplayServer.get_name()!="headless","scope":"Isolated production RigidBody3D and Input actions; no velocity or transform writes after each fixture starts. GPU appearance and whole-city integration are separate.","hashes":{}}
	for path in ["res://project.godot","res://scripts/harbor_vehicle.gd","res://scripts/fighter_motion.gd","res://scripts/tank_motion.gd","res://scripts/hoverboard_motion.gd","res://../source/specialty_boost_test.gd"]:
		report.hashes[path]=FileAccess.get_sha256(path)
	var directory:=ProjectSettings.globalize_path("res://../reports/specialty-boost")
	DirAccess.make_dir_recursive_absolute(directory)
	var output:=FileAccess.open(directory+"/checks.json",FileAccess.WRITE)
	if output: output.store_string(JSON.stringify(report,"\t"))
	else:
		push_error("Cannot write specialty boost report")
		failures+=1
	for action in ["forward","back","left","right","rise","fall","brake","boost"]:Input.action_release(action)
	print("SPECIALTY_COMPLETE checks=",checks.size()," failures=",failures)
	stage.queue_free();await process_frame;quit(1 if failures else 0)
