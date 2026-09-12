extends SceneTree
## Production factory/HarborVehicle state, including pre-ready restoration.
const Factory=preload("res://scripts/vehicle_factory.gd")
var stage:Node3D
var checks:Array=[]
var failures:=0
func _initialize():call_deferred("run")
func verify(name:String,passed:bool,evidence:Dictionary={}) -> void:
	checks.append({"name":name,"passed":passed,"evidence":evidence})
	print("PASS " if passed else "FAIL ",name," ",JSON.stringify(evidence))
	if not passed:failures+=1
func fresh(kind:String,id:String,state:Dictionary={}) -> RigidBody3D:
	var v:=Factory.make(kind,id);v.position=Vector3(0,1000,0);v.freeze=true
	if not state.is_empty():v.apply_state(state)
	stage.add_child(v);return v
func vector(data:Array) -> Vector3:return Vector3(data[0],data[1],data[2])
func run() -> void:
	stage=Node3D.new();root.add_child(stage)
	var tank=fresh("tank","test_tank")
	await process_frame
	verify("production tank kind and moving hierarchy survive the factory merge",tank.kind=="tank" and tank._moving.turret.get_parent()==tank and tank._moving.barrel.get_parent()==tank._moving.turret and tank._moving.muzzle.get_parent()==tank._moving.barrel and tank._moving.wheels.size()==18)
	var meshes:Array=[];Factory._gather_static_meshes(tank,[],meshes)
	var triangles:=0
	for view:MeshInstance3D in meshes:triangles+=view.mesh.get_faces().size()/3
	verify("production tank retains authored model triangles in88drawmeshes",triangles==23596 and meshes.size()==88,{"triangles":triangles,"meshes":meshes.size()})
	tank.position=Vector3(53,1003,-78);tank.rotation=Vector3(.13,.76,-.09)
	tank._moving.turret.rotation.y=deg_to_rad(143);tank._moving.barrel.rotation.x=deg_to_rad(32)
	tank.linear_velocity=Vector3(3,1,-28);tank.angular_velocity=Vector3(.02,.3,-.01);tank.throttle=.81
	var muzzle_before:Transform3D=tank._moving.muzzle.global_transform
	var saved:Dictionary=JSON.parse_string(JSON.stringify(tank.get_state()))
	verify("tank serialized state carries top-level aim and revision4",saved.model_revision==4 and is_equal_approx(saved.turret_yaw,deg_to_rad(143)) and is_equal_approx(saved.barrel_pitch,deg_to_rad(32)) and saved.kind=="tank" and saved.id=="test_tank")
	var copy=fresh("tank",saved.id,saved)
	verify("pre-ready restore preserves actual muzzle world pose",copy._moving.muzzle.global_transform.is_equal_approx(muzzle_before),{"muzzle_error_m":copy._moving.muzzle.global_position.distance_to(muzzle_before.origin)})
	verify("tank JSON roundtrip retains velocity angular velocity throttle and frozen state",copy.linear_velocity.is_equal_approx(Vector3(3,1,-28)) and copy.angular_velocity.is_equal_approx(Vector3(.02,.3,-.01)) and is_equal_approx(copy.throttle,.81) and copy.freeze)
	var limits:Dictionary=saved.duplicate(true);limits.turret_yaw=TAU*2+.4;limits.barrel_pitch=4.0;limits.health=0;limits.fuel=0
	copy.apply_state(limits)
	verify("tank restore wraps yaw clamps elevation and restores100hp100fuel",is_equal_approx(copy._moving.turret.rotation.y,.4) and is_equal_approx(copy._moving.barrel.rotation.x,deg_to_rad(70)) and copy.health==100 and copy.fuel==100)
	limits.barrel_pitch=-4.0;copy.apply_state(limits)
	verify("tank negative elevation clamps at12degrees depression",is_equal_approx(copy._moving.barrel.rotation.x,deg_to_rad(-12)))
	var legacy:Dictionary=saved.duplicate(true);legacy.erase("turret_yaw");legacy.erase("barrel_pitch");copy.apply_state(legacy)
	verify("state without tank aim fields defaults to neutral aim",copy._moving.turret.rotation.is_zero_approx() and copy._moving.barrel.rotation.is_zero_approx())
	copy.queue_free();tank.queue_free();await process_frame
	var fighter=fresh("fighter","test_fighter")
	await process_frame
	verify("production factory recognises fighter and builds its model",fighter.kind=="fighter" and fighter.get_meta("interaction_name")=="Aster F-27" and fighter.get_child_count()>4)
	var fs:Dictionary=fighter.get_state();fs.velocity=[12.0,2.0,-555.0];fs.angular_velocity=[.02,.06,-.04];fs.position=[200.0,1300.0,-45.0];fs.health=5;fs.fuel=3;fs.throttle=.98
	fighter.apply_state(fs)
	var fsave:Dictionary=JSON.parse_string(JSON.stringify(fighter.get_state()))
	verify("fighter save retains speed above old240mps guard",vector(fsave.velocity).distance_to(Vector3(12,2,-555))<.001 and vector(fsave.velocity).length()>550,{"saved_speed_mps":vector(fsave.velocity).length()})
	var fcopy=fresh("fighter",fsave.id,fsave)
	verify("fighter pre-ready JSON restoration keeps speed throttle identity and100hp100fuel",fcopy.linear_velocity.distance_to(Vector3(12,2,-555))<.001 and is_equal_approx(fcopy.throttle,.98) and fcopy.vehicle_id=="test_fighter" and fcopy.health==100 and fcopy.fuel==100)
	var live:Dictionary=fsave.duplicate(true);live.frozen=false;live.position=[500.0,1500.0,300.0]
	fcopy.apply_state(live);fcopy.set_physics_process(false)
	verify("save taken before physics restoration preserves pending high speed",vector(fcopy.get_state().velocity).distance_to(Vector3(12,2,-555))<.001)
	for i in 3:await physics_frame
	verify("actual rigid-body integration restores fighter high speed",fcopy.linear_velocity.length()>550 and fcopy.position.z<297 and not fcopy._restore_motion_pending,{"speed_mps":fcopy.linear_velocity.length(),"position_z":fcopy.position.z})
	live.velocity=[0.0,0.0,-2000.0];live.frozen=true;fcopy.apply_state(live)
	verify("fighter corrupt excessive speed remains bounded at620mps",is_equal_approx(fcopy.linear_velocity.length(),620.0))
	var car=fresh("car","guard_car");var cs:Dictionary=car.get_state();cs.velocity=[0.0,0.0,-555.0];cs.health=37;cs.fuel=42;car.apply_state(cs)
	verify("ordinary car keeps240mps guard and finite health fuel",is_equal_approx(car.linear_velocity.length(),240.0) and car.health==37 and car.fuel==42)
	# Run the real physics callback to enforce persistent health/fuel behaviour.
	fighter.health=1;fighter.fuel=2;fighter._physics_process(1.0/60.0)
	verify("fighter health and fuel remain100on subsequent production ticks",fighter.health==100 and fighter.fuel==100)
	var ground:=StaticBody3D.new();var col:=CollisionShape3D.new();var floor_shape:=BoxShape3D.new();floor_shape.size=Vector3(100,2,200);col.shape=floor_shape;ground.add_child(col);ground.position.y=-1;stage.add_child(ground)
	for action in ["forward","back","left","right","rise","fall","brake"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	var driving=fresh("tank","production_driving_tank");driving.freeze=false;driving.position=Vector3(0,1.1,50)
	for i in 120:await physics_frame
	driving.occupied=true;driving.health=2;driving.fuel=3;Input.action_press("forward")
	for i in 180:await physics_frame
	Input.action_release("forward")
	verify("actual occupied HarborVehicle dispatch drives tank from Input actions",driving.grounded and driving.speed_kmh>40 and driving.position.z<30 and driving.health==100 and driving.fuel==100,{"speed_kmh":driving.speed_kmh,"position_z":driving.position.z})
	Input.action_press("brake");for i in 180:await physics_frame
	Input.action_release("brake");var wheel_before:float=driving._moving.wheels[0].rotation.x;var heading_before:float=driving.rotation.y;Input.action_press("right")
	for i in 120:await physics_frame
	Input.action_release("right")
	verify("production tank differential drive animates wheels while pivoting",absf(wrapf(driving.rotation.y-heading_before,-PI,PI))>.5 and absf(wrapf(driving._moving.wheels[0].rotation.x-wheel_before,-PI,PI))>.2 and float(driving.get_meta("tank_track_left_speed"))*float(driving.get_meta("tank_track_right_speed"))<0)
	var report:={"passed":failures==0,"count":checks.size(),"failures":failures,"checks":checks,"scope":"Production Factory.make and HarborVehicle get_state/apply_state, JSON roundtrip, real Jolt restoration; no whole-city or GPU run","hashes":{}}
	for path in ["res://scripts/harbor_vehicle.gd","res://scripts/vehicle_factory.gd","res://scripts/tank_models.gd","res://scripts/tank_motion.gd","res://scripts/fighter_models.gd","res://scripts/fighter_motion.gd","res://../source/combat_vehicle_state_test.gd"]:report.hashes[path]=FileAccess.get_sha256(path)
	var directory:=ProjectSettings.globalize_path("res://../reports/tank");DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory+"/combat-vehicle-state-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("COMBAT_VEHICLE_STATE_COMPLETE checks=",checks.size()," failures=",failures)
	stage.queue_free();await process_frame;quit(1 if failures else 0)
