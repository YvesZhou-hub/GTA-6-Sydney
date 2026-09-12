extends SceneTree
## Actual complete city/airport and main.request_vehicle. No saves are opened,
## written or deleted. Test origin changes are explicit fixture setup only.
const Spawn=preload("res://scripts/vehicle_spawn.gd")
const Motion=preload("res://scripts/fighter_motion.gd")
var game
var checks: Array=[]
var failures:=0
var summon_times: Array=[]
var new_ids: Array=[]
var source_before: Dictionary={}

func _init(): call_deferred("run")
func check(name: String, passed: bool, metrics: Dictionary={}):
	checks.append({"name":name,"passed":passed,"metrics":metrics})
	print(("PASS " if passed else "FAIL ")+name+" "+JSON.stringify(metrics))
	if not passed: failures+=1
func hashes() -> Dictionary:
	var value: Dictionary={}
	for path: String in ["main.gd","harbor_vehicle.gd","vehicle_factory.gd","vehicle_spawn.gd","fighter_models.gd","fighter_motion.gd","tank_models.gd","tank_motion.gd","harbor_world.gd","map_migration.gd"]:
		value[path]=FileAccess.get_sha256("res://scripts/"+path)
	value["project.godot"]=FileAccess.get_sha256("res://project.godot")
	return value
func frames(count: int):
	for i in count: await physics_frame
func clear_input():
	for action: String in ["forward","back","left","right","rise","fall","brake","fire"]: Input.action_release(action)
func fixture_origin(point: Vector3, heading: float):
	if is_instance_valid(game.current_vehicle):
		game.current_vehicle.occupied=false
		game.current_vehicle.freeze=true
	game.current_vehicle=null
	game.player.enabled=false
	game.player.global_position=point
	game.player.velocity=Vector3.ZERO
	game.player.reset_physics_interpolation()
	game.yaw=heading
	game.reset_follow_camera()
func vehicle_poses() -> Dictionary:
	var value: Dictionary={}
	for old in game.vehicles: value[old.vehicle_id]=old.global_transform
	return value
func request_and_check(kind: String, context: String):
	var previous=game.current_vehicle
	var before_poses:=vehicle_poses()
	var count_before: int=game.vehicles.size()
	var before_money: int=game.life.money
	var origin: Vector3=previous.global_position if is_instance_valid(previous) else game.player.global_position
	var stamp:=Time.get_ticks_usec()
	var body=game.request_vehicle(kind)
	var elapsed_ms: float=(Time.get_ticks_usec()-stamp)/1000.0
	summon_times.append({"kind":kind,"context":context,"milliseconds":elapsed_ms})
	check(context+" creates fresh "+kind,body!=null and game.vehicles.size()==count_before+1,{"milliseconds":elapsed_ms,"count":game.vehicles.size()})
	if body==null: return null
	check(context+" immediately occupies new "+kind,game.current_vehicle==body and body.occupied and not body.freeze and not game.player.enabled and game.player.global_position.distance_to(body.global_position)<.001)
	check(context+" charges no vehicle money",game.life.money==before_money,{"before":before_money,"after":game.life.money})
	var preserved:=true
	for old in game.vehicles:
		if before_poses.has(old.vehicle_id) and not old.global_transform.is_equal_approx(before_poses[old.vehicle_id]): preserved=false
	check(context+" preserves all previous copies and their poses",preserved and (not is_instance_valid(previous) or not previous.occupied))
	check(context+" returns unique independent identity",not new_ids.has(body.vehicle_id) and not before_poses.has(body.vehicle_id),{"id":body.vehicle_id})
	new_ids.append(body.vehicle_id)
	var local_bounds: AABB=Spawn.envelope(body)
	check(context+" entire model and collider envelope starts clear",Spawn.clear_envelope(game,body,body.global_transform,.3),{"bounds":str(local_bounds),"position":body.global_position,"distance_from_origin":body.global_position.distance_to(origin)})
	if kind=="fighter":
		var pose: Transform3D=body.global_transform
		var direction: Vector3=-pose.basis.z
		var clear:=true
		var first_bad: int=-1
		for distance in range(0,421,5):
			var sample:=pose;sample.origin+=direction*distance
			if not Spawn.clear_envelope(game,body,sample,3.0): clear=false;first_bad=distance;break
		# Half the production 10m step; the expanded 18.5m body length overlaps
		# consecutive samples, so the checked swept corridor has no axial gaps.
		check(context+" complete 420m departure corridor remains clear",clear and local_bounds.size.z+6.0>=10.0,{"samples":85,"step_m":5,"first_blocked_m":first_bad})
		check(context+" nearby launch stays above minimum clear altitude",body.global_position.y>=maxf(origin.y+90,160)-.01 and Vector2(body.position.x,body.position.z).distance_to(Vector2(origin.x,origin.z))<100,{"origin":origin,"spawn":body.global_position})
		var immediate_state: Dictionary=body.get_state()
		check(context+" first-frame state contains launch speed",game.unvec(immediate_state.velocity).length()>139.0,{"velocity":immediate_state.velocity})
		await frames(2)
		var start: Vector3=body.global_position
		var minimum_y: float=start.y
		var minimum_speed: float=body.linear_velocity.length()
		var start_impacts: int=body._arcade_impact.hits
		for i in 178:
			await physics_frame
			minimum_y=minf(minimum_y,body.global_position.y)
			minimum_speed=minf(minimum_speed,body.linear_velocity.length())
		check(context+" real three-second departure flies without drop or collision",minimum_y>start.y-.3 and minimum_speed>139 and body.global_position.distance_to(start)>400 and body.health==100 and body._arcade_impact.hits==start_impacts,{"minimum_y":minimum_y,"start_y":start.y,"minimum_speed_mps":minimum_speed,"distance":body.global_position.distance_to(start),"ram_hits":body._arcade_impact.hits-start_impacts})
	else:
		var shape:=BoxShape3D.new();shape.size=local_bounds.size
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape
		query.transform=body.global_transform*Transform3D(Basis.IDENTITY,local_bounds.get_center())
		query.collision_mask=15;query.exclude=[body.get_rid(),game.player.get_rid()]
		check(context+" physical tank starts outside all solid buildings",game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty())
		await frames(120)
		check(context+" tank settles without fall or impact damage",body.health==100 and body.global_position.y>0 and body.linear_velocity.length()<.5,{"position":body.global_position,"speed_mps":body.linear_velocity.length(),"health":body.health})
	body.freeze=true
	return body
func run():
	source_before=hashes()
	game=load("res://scripts/main.gd").new()
	game.qa_running=true
	var build_start:=Time.get_ticks_usec()
	root.add_child(game)
	game.new_world("sandbox","QA combat spawn isolated",false)
	game.world_id="qa_combat_spawn_"+str(Time.get_ticks_usec())
	clear_input()
	for body in game.vehicles: body.freeze=true
	await frames(2)
	check("Complete authored city and airport are live",game.qa_running and is_instance_valid(game.airport) and game.world.structures.size()>5000 and game.airport.anchors.has("runway_start"),{"structures":game.world.structures.size(),"startup_seconds":(Time.get_ticks_usec()-build_start)/1000000.0})
	var base_count: int=game.vehicles.size()
	fixture_origin(Vector3(-545,5,-170),0)
	await request_and_check("tank","city sandbox tank")
	await request_and_check("tank","city duplicate tank")
	await request_and_check("fighter","city occupied tank to fighter")
	await request_and_check("fighter","city duplicate fighter")
	fixture_origin(game.world.anchors.home+Vector3.UP,0)
	await request_and_check("tank","indoor origin tank safe outside")
	game.mode="life";game.life.sandbox=false
	fixture_origin(game.airport.anchors.runway_start+Vector3.UP*2,game.airport.runway_heading)
	await request_and_check("tank","airport life mode tank")
	await request_and_check("fighter","airport life mode fighter")
	await request_and_check("fighter","airport duplicate fighter")
	var ids: Dictionary={}
	for body in game.vehicles: ids[body.vehicle_id]=true
	check("All eight new copies remain with unique IDs",new_ids.size()==8 and game.vehicles.size()==base_count+8 and ids.size()==game.vehicles.size(),{"base":base_count,"final":game.vehicles.size(),"new":new_ids.size()})
	var max_ms:=0.0
	for sample: Dictionary in summon_times: max_ms=maxf(max_ms,float(sample.milliseconds))
	var after:=hashes()
	var report: Dictionary={"passed":failures==0,"checks":checks,"count":checks.size(),"failures":failures,"user_saves_touched":false,"gpu_used":false,"engine":Engine.get_version_info().string,"backend":ProjectSettings.get_setting("physics/3d/physics_engine"),"scope":"Production complete main/world/airport, actual request_vehicle and first3s fighter flight, 8 fresh copies across sandbox/life modes; no save calls","summon_times":summon_times,"maximum_summon_milliseconds":max_ms,"source_hashes_before":source_before,"source_hashes_after":after,"source_unchanged":source_before==after,"test_sha256":FileAccess.get_sha256("res://../source/combat_spawn_test.gd")}
	DirAccess.make_dir_recursive_absolute("res://../reports/combat-spawn")
	var file:=FileAccess.open("res://../reports/combat-spawn/checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("COMBAT_SPAWN_COMPLETE ",checks.size()," passed=",failures==0," max_summon_ms=",max_ms)
	game.active=false
	game.queue_free();await process_frame
	quit(failures)
