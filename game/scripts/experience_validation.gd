extends Node
## Production UI/controller flow, isolated saves, real physics world and native captures.
const Guidance=preload("res://scripts/navigation_guidance.gd")
const Store=preload("res://scripts/save_store.gd")
const Spawn=preload("res://scripts/vehicle_spawn.gd")
var game
var checks:Array=[]
var screenshots:Array=[]
var test_id:="qa_experience_"+str(Time.get_ticks_usec())
func _ready(): call_deferred("run")
func check(name:String,passed:bool,detail:Dictionary={}):
	checks.append({"name":name,"passed":passed,"detail":detail})
	print("EXPERIENCE ","PASS " if passed else "FAIL ",name)
func capture(name:String):
	if DisplayServer.get_name()=="headless":return
	for i in 4:await get_tree().process_frame
	RenderingServer.force_draw(true,1.0/60)
	DirAccess.make_dir_recursive_absolute("user://experience-qa")
	var image:=get_tree().root.get_texture().get_image()
	var result:=image.save_png("user://experience-qa/"+name+".png")
	screenshots.append({"name":name+".png","saved":result==OK,"resolution":[image.get_width(),image.get_height()]})
func run():
	game=get_parent()
	game.qa_running=true
	game.new_world("life","QA generous Sydney",false)
	game.world_id=test_id
	game.set_process(false)
	game.player.enabled=false
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("complete world before any delivery checks",game.world._ready_complete)
	check("new life starts with generous funds and all classes",game.life.money==50000 and game.owned.size()==game.VEHICLE_NAMES.size())
	game.life.money=0
	game.player.global_position=Vector3(-545,5,-170)
	var preserved:={}
	for v in game.vehicles:v.freeze=true;preserved[v.vehicle_id]=v.global_transform
	var clones:Array=[]
	for kind in game.VEHICLE_NAMES:
		var old=game.current_vehicle
		var old_pose:Transform3D=old.global_transform if is_instance_valid(old) else Transform3D.IDENTITY
		var old_count:int=game.vehicles.size()
		game.vehicles_menu()
		var button_found:Button
		for child in game.modal_content.get_children():
			if child is Button and child.text.begins_with(game.VEHICLE_NAMES[kind]):button_found=child;break
		check("free garage action exists "+kind,is_instance_valid(button_found) and "免费" in button_found.text)
		if not is_instance_valid(button_found):continue
		button_found.pressed.emit()
		var fresh=game.current_vehicle
		var okay:bool=is_instance_valid(fresh) and fresh!=old and fresh.kind==kind
		check("garage immediately seats fresh "+kind,okay and fresh.occupied and not game.player.enabled and not game.player.visible and game.player.collision_layer==0 and game.player.global_position.is_equal_approx(fresh.global_position))
		check("zero-balance creation preserves fleet "+kind,okay and game.life.money==0 and game.vehicles.size()==old_count+1 and not game.paused and not game.modal.visible)
		if is_instance_valid(old):check("previous occupied instance remains "+kind,not old.occupied and old.global_transform.is_equal_approx(old_pose) and old in game.vehicles)
		if okay:clones.append(fresh);fresh.freeze=true
	var last=game.current_vehicle
	var amount:int=game.vehicles.size()
	check("invalid selection leaves current driver untouched",game.request_vehicle("unknown")==null and game.current_vehicle==last and last.occupied and game.vehicles.size()==amount)
	check("all initial instance transforms preserved",game.vehicles.all(func(v):return not preserved.has(v.vehicle_id) or v.global_transform.is_equal_approx(preserved[v.vehicle_id])))
	game.life.start_job("race")
	var other_car=game.vehicles.filter(func(v):return v.kind=="car" and v!=game.current_vehicle)[0]
	other_car.impacted.emit(Vector3(12000,2000,0),9000)
	check("other vehicle collision does not count as player incident",int(game.life.active_job.get("incidents",-1))==0)
	game.current_vehicle.impacted.emit(Vector3(12000,2000,0),9000)
	check("occupied vehicle collision counts one player incident",int(game.life.active_job.get("incidents",-1))==1)
	game.life.cancel_job()
	var before:Vector3=game.player.global_position
	game.set_map_waypoint(Vector3(-440,4.5,1460),"ICC 自选标记")
	check("arbitrary pin sets destination without moving driver",game.landmark_target_key=="map_pin" and game.current_vehicle==last and game.player.global_position.is_equal_approx(before))
	game.update_navigation(1)
	check("minimap and world marker share destination",game.minimap.target_position==game.landmark_target_position and game.navigation_hud.target_key=="map_pin")
	game.map_menu()
	check("pin survives reopening big map",game.map_panel.target_key=="map_pin" and game.map_panel.target_name=="ICC 自选标记")
	game.map_panel.show_preset("core")
	await capture("01-map-pin")
	game.close_panel()
	game.life.money=50000
	check("new fleet navigation save succeeds",game.save_world())
	var occupied_id:String=game.current_vehicle.vehicle_id
	game.load_world(test_id)
	game.set_process(false)
	for v in game.vehicles:v.freeze=true
	check("exact occupied fresh instance restored",is_instance_valid(game.current_vehicle) and game.current_vehicle.vehicle_id==occupied_id)
	check("arbitrary destination restored without reselecting",game.landmark_target_key=="map_pin" and game.landmark_target_position.is_equal_approx(Vector3(-440,4.5,1460)))
	# Two old compact boats can overlap when replaced by the larger yacht model.
	# Loading must preserve both identities and state, move only parked legacy copies,
	# and leave the source file intact until the player's next normal save.
	var legacy:Dictionary=Store.read(test_id)
	var yacht_ids:Array=[]
	for state in legacy.vehicles:
		if state.kind!="yacht":continue
		state["model_revision"]=1
		state.position=[400.0+yacht_ids.size()*2.0,0.9,-1000.0]
		state.quaternion=[0,0,0,1]
		state.velocity=[0,0,0]
		state.angular_velocity=[0,0,0]
		state.health=73
		state.fuel=42
		yacht_ids.append(state.id)
	var legacy_id:=test_id+"_legacy_boats"
	Store.write(legacy_id,legacy)
	var source_text:=FileAccess.get_file_as_string(Store.ROOT+legacy_id+".json")
	game.load_world(legacy_id)
	game.set_process(false)
	var restored_boats:Array=game.vehicles.filter(func(v):return v.vehicle_id in yacht_ids)
	check("larger legacy boats retain identity damage and fuel",restored_boats.size()==2 and restored_boats.all(func(v):return v.health==73 and v.fuel==42))
	if restored_boats.size()==2:
		var first:AABB=restored_boats[0].global_transform*Spawn.envelope(restored_boats[0])
		var second:AABB=restored_boats[1].global_transform*Spawn.envelope(restored_boats[1])
		check("overlapping old berths safely separate new hulls",not first.intersects(second) and game.get_meta("last_vehicle_model_adjustments",[]).size()>0)
	check("legacy load keeps original save bytes",FileAccess.get_file_as_string(Store.ROOT+legacy_id+".json")==source_text)
	check("legacy parking adjustment preserves occupied aircraft",is_instance_valid(game.current_vehicle) and game.current_vehicle.vehicle_id==occupied_id)
	for v in game.vehicles:v.freeze=true
	game.clear_landmark_target()
	check("clear removes all destination indicators",game.landmark_target_key.is_empty() and game.minimap.target_key.is_empty() and game.navigation_hud.target_key.is_empty())
	var services:Array=game.life.service_catalog()
	check("actual mapped city experiences available",services.size()==22)
	for anchor:String in ["auvers","hakatamon","chinta_ria","cq_eastbank","cq_searock","cq_city_extra"]:
		var matches:Array=services.filter(func(s):return s.anchor==anchor)
		game.set_landmark_target(anchor)
		check("new shop service and map share checked entrance "+anchor,matches.size()==1 and game.landmark_target_key==anchor and game.landmark_target_position.is_equal_approx(matches[0].position) and game.world.anchors[anchor].is_equal_approx(matches[0].position))
	if not services.is_empty():
		var service:Dictionary=services[0]
		game.exit_vehicle()
		game.player.enabled=false
		game.player.global_position=service.position
		game.player.stamina=13
		game.life.tick_context(service.position,"",0,0.1)
		game.camera.global_position=service.position+Vector3(16,10,25)
		game.camera.look_at(service.position+Vector3.UP*3)
		game.update_navigation(1)
		game.update_hud()
		game.experiences_menu()
		await capture("02-experiences")
		var service_button:Button
		for child in game.modal_content.get_children():
			if child is Button and child.text.begins_with(service.title):service_button=child;break
		check("nearby service button is present",is_instance_valid(service_button))
		var money:int=game.life.money
		var visits:int=game.life.experience_visits.get(service.id,0)
		if is_instance_valid(service_button):service_button.pressed.emit()
		check("single UI purchase charges once and returns to play",game.life.money==money-int(service.cost) and game.life.experience_visits.get(service.id,0)==visits+1 and not game.paused)
		check("one service signal restores stamina once",game.player.stamina==minf(100,13+float(service.stamina_restore)))
		await capture("03-experience-reward")
		game.player.global_position=service.position+Vector3(float(service.radius)*0.8,float(service.radius)*0.8,0)
		game.experiences_menu()
		for child in game.modal_content.get_children():
			if child is Button and child.text.begins_with(service.title):service_button=child;break
		var distant_balance:int=game.life.money
		service_button.pressed.emit()
		check("out-of-range elevated service guides rather than claiming reachable",game.landmark_target_key=="map_pin" and game.landmark_target_position.is_equal_approx(service.position) and game.life.money==distant_balance and not game.paused)
		game.player.global_position=service.position+Vector3(20,0,30)
		game.camera.global_position=game.player.global_position+Vector3(0,3,5)
		game.camera.look_at(service.position+Vector3.UP*3)
		game.update_navigation(1)
		await capture("04-live-navigation")
	for entry in [[Vector3(0,0,-100),0.0],[Vector3(100,0,0),90.0],[Vector3(0,0,100),180.0],[Vector3(-100,0,0),270.0]]:
		check("compass cardinal "+str(entry[1]),absf(Guidance.compass_bearing(entry[0])-entry[1])<0.001)
	check("flying over target is not an arrival",not Guidance.has_arrived(Vector3(0,400,0),Vector3(0,4.5,0)))
	check("nearby ground destination can arrive",Guidance.has_arrived(Vector3(8,5,8),Vector3(0,4.5,0)))
	var boarding_boat=game.vehicles.filter(func(v):return v.kind=="yacht")[0]
	game.enter_vehicle(boarding_boat)
	boarding_boat.freeze=true
	game.exit_vehicle()
	game.player.enabled=false
	check("aft yacht platform permits immediate E reboarding",game.nearest_vehicle()==boarding_boat)
	var failed:int=checks.filter(func(x):return not x.passed).size()
	var report:={"checks":checks,"failures":failed,"screenshots":screenshots,"world_ready":game.world._ready_complete,"world_components":game.world.structures.size(),"test_world":test_id,"player_saves_touched":false,"save_fixture_retained":true}
	var file:=FileAccess.open("user://experience-flow-report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("EXPERIENCE_REPORT "+JSON.stringify(report))
	game.active=false
	game.finish_quit(1 if failed else 0)
