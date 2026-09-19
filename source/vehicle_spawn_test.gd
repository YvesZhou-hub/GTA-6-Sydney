extends SceneTree
const Spawn = preload("res://scripts/vehicle_spawn.gd")
const Store = preload("res://scripts/save_store.gd")
var failures := 0
var checks: Array = []
var game
var test_id := "qa_spawn_"+str(Time.get_ticks_usec())
func check(value: bool,message: String):
	checks.append({"name":message,"passed":value})
	if value: print("PASS ",message)
	else:
		failures+=1
		push_error("FAIL "+message)
func _initialize(): call_deferred("run")
func run():
	game=load("res://scripts/main.gd").new()
	game.qa_running=true
	root.add_child(game)
	game.new_world("sandbox","QA Independent Fleet",false)
	game.world_id=test_id
	game.player.global_position=Vector3(-545,5,-170)
	game.player.reset_physics_interpolation()
	game.yaw=0
	await physics_frame
	await physics_frame
	var initial_count: int=game.vehicles.size()
	var originals := {}
	for v in game.vehicles:
		v.freeze=true
		originals[v.vehicle_id]=v.global_transform
	var created: Array=[]
	for kind in ["car","car","car","car","motorcycle","hoverboard","speedboat","yacht","helicopter","glider","paraglider","airliner","airliner","airliner","airliner"]:
		var before: Vector3=game.player.global_position
		var prior_count: int=game.vehicles.size()
		var vehicle=game.request_vehicle(kind)
		check(vehicle!=null,"new independent "+kind+" #"+str(created.size()+1))
		if vehicle==null: continue
		created.append(vehicle)
		check(game.vehicles.size()==prior_count+1,"fleet grows by exactly one "+kind)
		check(game.player.global_position.distance_to(vehicle.global_position)<0.001 and game.current_vehicle==vehicle and vehicle.occupied and not game.player.enabled,"summon immediately boards fresh copy "+kind)
		check(Spawn.clear_envelope(game,vehicle,vehicle.global_transform,0.3),"full geometry clear of walls/vehicles "+kind)
		vehicle.freeze=true
	var unique:={}
	for vehicle in game.vehicles: unique[vehicle.vehicle_id]=true
	check(unique.size()==game.vehicles.size(),"all original and summoned IDs are unique")
	check(game.vehicles.size()==initial_count+15,"same-type copies have no fixed fleet cap")
	var originals_preserved:=true
	for v in game.vehicles:
		if originals.has(v.vehicle_id) and not v.global_transform.is_equal_approx(originals[v.vehicle_id]): originals_preserved=false
	check(originals_preserved,"summoning never relocates an existing instance")
	# Runtime wall test: block the user's entire straight-ahead candidate with a tall wall.
	game.exit_vehicle()
	game.player.enabled=false
	game.player.global_position=Vector3(-545,5,-140)
	game.player.reset_physics_interpolation()
	game.yaw=0
	var wall:=StaticBody3D.new()
	var wall_shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(12,25,8)
	wall_shape.shape=box
	wall.add_child(wall_shape)
	game.add_child(wall)
	wall.global_position=game.player.global_position+Vector3(0,10,-10)
	await physics_frame
	var safe_car=game.request_vehicle("car")
	check(safe_car!=null and safe_car.global_position.y<7 and Spawn.clear_envelope(game,safe_car,safe_car.global_transform),"candidate search avoids full-height wall in front")
	if safe_car!=null: safe_car.freeze=true
	# Summon while driving preserves the driver and old vehicle position.
	game.enter_vehicle(created[0])
	created[0].freeze=true
	var occupied_before=game.current_vehicle
	var occupied_pose:Transform3D=occupied_before.global_transform
	var summon_during_drive=game.request_vehicle("motorcycle")
	check(summon_during_drive!=null and game.current_vehicle==summon_during_drive and summon_during_drive.occupied and not occupied_before.occupied,"summoning while occupied transfers driver into new copy")
	check(occupied_before.global_transform.is_equal_approx(occupied_pose),"summoning does not move occupied vehicle")
	if summon_during_drive!=null: summon_during_drive.freeze=true
	# Runtime ground settling must not create damage/launch impulses.
	var settle=game.request_vehicle("car")
	var settle_height:float=settle.global_position.y if settle!=null else 0
	if settle!=null:
		game.exit_vehicle()
		game.player.enabled=false
		settle.freeze=false
	for i in 180: await physics_frame
	check(settle!=null and settle.health==100 and settle.linear_velocity.length()<0.3 and absf(settle.global_position.y-settle_height)<0.5,"fresh road vehicle settles gently and rests")
	check(settle!=null and settle.sleeping,"unused road copy enters normal physics sleep")
	if settle!=null: settle.freeze=true
	for v in game.vehicles: v.freeze=true
	game.enter_vehicle(created[0])
	created[0].freeze=true
	created[1].health=73.0
	created[2].fuel=42.0
	var expected_states:={}
	for v in game.vehicles: expected_states[v.vehicle_id]=v.get_state()
	# Copies share one durability ledger per vehicle type (docs/SURVIVAL_DESIGN.md,
	# 同款耐久): a fresh copy must not undo damage. Fuel and position stay per copy.
	var type_health:={}
	for v in game.vehicles: type_health[v.kind]=minf(float(type_health.get(v.kind,100.0)),v.health)
	var expected_occupied_id:String=game.current_vehicle.vehicle_id
	var expected_target_id:String=game.spawn_target.vehicle_id
	check(game.save_world(),"dynamic fleet save succeeds")
	# Format 5 introduced the protection; later formats keep it.
	check(Store.read(test_id).get("version")==Store.VERSION and Store.VERSION>=5,"fleet saves in the current format (5+ protects new hoverboards from older app4)")
	var legacy=Store.read(test_id)
	legacy.version=2
	var legacy_file=FileAccess.open(Store.ROOT+test_id+"_legacy.json",FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	check(Store.read(test_id+"_legacy").get("version")==Store.VERSION,"format2 saves migrate without discarding fleet data")
	game.load_world(test_id)
	check(game.vehicles.size()==expected_states.size(),"all dynamic copies survive actual load_world")
	var state_match:=true
	var mismatches:=[]
	for v in game.vehicles:
		if not expected_states.has(v.vehicle_id):
			state_match=false
			mismatches.append({"id":v.vehicle_id,"missing":true})
			continue
		var expected:Dictionary=expected_states[v.vehicle_id]
		var moved:float=v.global_position.distance_to(game.unvec(expected.position))
		if moved>0.001 or absf(v.health-float(type_health[v.kind]))>0.001 or absf(v.fuel-float(expected.fuel))>0.001:
			state_match=false
			mismatches.append({"id":v.vehicle_id,"kind":v.kind,"moved_m":moved,"health":[v.health,type_health[v.kind]],"fuel":[v.fuel,expected.fuel]})
	if not mismatches.is_empty(): print("VEHICLE_SPAWN_MISMATCH ",JSON.stringify(mismatches))
	check(state_match,"copy identities, positions and own fuel restored; health follows the shared per-type ledger")
	var damaged: Array = game.vehicles.filter(func(v): return v.kind==created[1].kind)
	check(damaged.size()>1 and damaged.all(func(v): return is_equal_approx(v.health,73.0)),"damage to one copy is not undone by its same-type copies")
	check(is_instance_valid(game.current_vehicle) and game.current_vehicle.vehicle_id==expected_occupied_id,"original occupied copy restored")
	check(is_instance_valid(game.spawn_target) and game.spawn_target.vehicle_id==expected_target_id,"new-copy waypoint restored")
	var saved_wing=null
	for v in game.vehicles:
		if v.kind=="glider" and v.vehicle_id.begins_with("spawn_"): saved_wing=v; break
	game.enter_vehicle(saved_wing)
	await physics_frame
	await physics_frame
	check(saved_wing!=null and saved_wing.linear_velocity.length()>27,"saved waiting glider retains trim speed after first physics integration")
	# Fresh airport-start remains the explicit teleport/boarding flow.
	game.active=false
	game.new_world("sandbox","QA Runway Spawn",false)
	game.world_id=test_id+"_airport"
	for v in game.vehicles: v.freeze=true
	await physics_frame
	game.airport_start()
	check(is_instance_valid(game.current_vehicle) and game.current_vehicle.kind=="airliner","airport start explicitly boards a fresh plane")
	if is_instance_valid(game.current_vehicle):
		check(Vector2(game.current_vehicle.global_position.x,game.current_vehicle.global_position.z).distance_to(Vector2(game.airport.anchors.runway_start.x,game.airport.anchors.runway_start.z))<0.5,"first airport start uses actual 34L threshold")
	# Repeated explicit airport starts create additional aircraft without moving the earlier one.
	var runway_first=game.current_vehicle
	var runway_pose:Transform3D=runway_first.global_transform
	runway_first.freeze=true
	var before_airport_count:int=game.vehicles.size()
	game.airport_start()
	check(game.vehicles.size()==before_airport_count+1 and game.current_vehicle!=runway_first and runway_first.global_transform.is_equal_approx(runway_pose),"second airport start preserves earlier runway aircraft")
	if is_instance_valid(game.current_vehicle): game.current_vehicle.occupied=false; game.current_vehicle.freeze=true
	game.current_vehicle=null
	game.player.enabled=false
	game.player.global_position=Vector3(0,5,4000)
	var field_before:Vector3=game.player.global_position
	var nearby_plane=game.request_vehicle("airliner")
	check(nearby_plane!=null and nearby_plane.global_position.distance_to(field_before)<250,"large plane uses nearby clear field before distant airport")
	if nearby_plane!=null: nearby_plane.freeze=true
	if is_instance_valid(game.current_vehicle): game.current_vehicle.occupied=false
	game.current_vehicle=null
	game.player.global_position=game.world.anchors.home+Vector3.UP
	var indoors_before:Vector3=game.player.global_position
	var indoor_car=game.request_vehicle("car")
	check(indoor_car!=null and game.current_vehicle==indoor_car and game.player.global_position.is_equal_approx(indoor_car.global_position) and Spawn.clear_envelope(game,indoor_car,indoor_car.global_transform),"indoor summon safely moves player into new outdoor copy")
	var roof_probe=game.make_vehicle("airliner",game.next_vehicle_id("airliner"),Vector3(0,-2000,0))
	roof_probe.freeze=true
	check(Spawn._ground_pose(game,roof_probe,Vector3(-4510,7,9040),0).is_empty(),"hangar roof is never treated as widebody parking")
	var roof_car=game.make_vehicle("car",game.next_vehicle_id("car"),Vector3(0,-2000,0))
	roof_car.freeze=true
	check(Spawn._ground_pose(game,roof_car,Vector3(-2700,7,7990),0).is_empty(),"terminal roof is never treated as car parking")
	game.active=false
	game.get_tree().paused=false
	var report={"checks":checks,"failures":failures,"test_world":test_id,"user_saves_touched":false}
	var report_path="user://vehicle-spawn-report.json"
	var file=FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("VEHICLE_SPAWN_REPORT "+JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
