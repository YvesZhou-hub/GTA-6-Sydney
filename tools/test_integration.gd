extends SceneTree
## Headless integration checks; uses fresh qa_integration_* save files and retains them for inspection.
## Run: Godot --headless --path game --script "$PWD/tools/test_integration.gd"
const Store = preload("res://scripts/save_store.gd")
var failures := 0
var checks := 0
var app
var fixture_ids: Array[String] = []
var qa_prefix:="qa_integration_"+str(Time.get_ticks_usec())+"_"
var started: int

func _init() -> void:
	call_deferred("run")

func check(title: String, okay: bool, detail: String = "") -> void:
	checks += 1
	print("INTEGRATION ",title," ","PASS" if okay else "FAIL", " "+detail if not detail.is_empty() else "")
	if not okay:
		failures += 1

func set_qa_id(index: int) -> void:
	app.world_id = qa_prefix+str(index)
	if not app.world_id in fixture_ids:
		fixture_ids.append(app.world_id)

func run() -> void:
	started = Time.get_ticks_msec()
	app = load("res://scripts/main.gd").new()
	root.add_child(app)
	app.qa_running = true
	app.set_process(false)
	app.set_physics_process(false)
	app.new_world("life","Integration QA",false)
	set_qa_id(0)
	app.player.enabled = false
	var life = app.life
	var count: int = life.get_child_count()
	var cargo_count: int = life.cargo.size()
	var npc_count: int = life.npcs.size()
	check("initial_life_economy",life.money==50000 and not life.sandbox)
	for cycle in 4:
		life.money = 87
		life.completed_jobs["photo"] = 9
		life.owned_assets["qa_fake_asset"] = true
		life.start_job("race")
		life.npcs[0].memories["accidents"] = 5
		var next_mode := "sandbox" if cycle%2==0 else "life"
		app.new_world(next_mode,"Integration QA",false)
		set_qa_id(cycle+1)
		app.player.enabled = false
		check("mode_reset_%d"%cycle,life.money==50000 and life.active_job.is_empty() and life.completed_jobs.is_empty() and not life.owned_assets.has("qa_fake_asset") and int(life.npcs[0].memories.accidents)==0)
		check("stable_population_%d"%cycle,life.get_child_count()==count and life.cargo.size()==cargo_count and life.npcs.size()==npc_count)
		await process_frame
	# Actual translated catalog IDs must still drive mode-specific spatial jobs.
	for definition in life.job_catalog():
		var id: String = definition.id
		life.start_job(id)
		check("start_"+id,life.active_job.get("id","")==id)
		if id == "salvage":
			var crate = life._find_cargo(life.active_job.cargo_id)
			life.tick_context(crate.global_position,"",0,0.1)
			life.toggle_carry(crate.global_position)
			life.tick_context(life._delivery(),"yacht",0,0.1)
			life.interact(life._delivery())
		else:
			var route: Array = life._job_route(id)
			var wrong_position: Vector3 = route[0]
			life.tick_context(wrong_position,"car" if id!="race" else "",0,0.2)
			if id=="photo": life.interact(wrong_position)
			check("wrong_context_rejected_"+id,int(life.active_job.stage)==0)
			for waypoint in route:
				match id:
					"photo":
						life.tick_context(waypoint,"",0,0.1)
						life.interact(waypoint)
					"harbor": life.tick_context(waypoint,"yacht",1,2.1)
					"air": life.tick_context(waypoint,"helicopter",16,0.2)
					"race": life.tick_context(waypoint,"motorcycle",10,0.1)
		check("complete_"+id,life.active_job.is_empty() and int(life.completed_jobs.get(id,0))==1)
		life.start_job(id)
		check("repeat_"+id,life.active_job.get("id","")==id)
		life.cancel_job()
		check("cancel_"+id,life.active_job.is_empty())
	# Deliver a loose physical case rather than relying on the carried flag.
	life.start_job("salvage")
	var loose = life._find_cargo(life.active_job.cargo_id)
	loose.global_position = life._delivery()+Vector3.UP*0.5
	loose.linear_velocity = Vector3.ZERO
	life.tick_context(life._delivery(),"",0,0.1)
	var hint: String = life.available_actions(life._delivery())
	var reply: String = life.interact(life._delivery())
	check("loose_salvage_interact",life.active_job.is_empty(),"hint="+hint+" response="+reply)
	life.cancel_job()
	# Changing worlds while seated must restore the walking collision filter.
	app.owned = app.VEHICLE_NAMES.keys()
	app.enter_vehicle(app.vehicles[0])
	check("vehicle_entry_disables_player_collider",app.player.collision_mask==0 and app.player.collision_layer==0)
	app.new_world("life","Integration QA",false)
	set_qa_id(8)
	app.player.enabled = false
	check("new_world_restores_walking_collision",app.player.collision_layer==1 and app.player.collision_mask==15,"layer=%d mask=%d"%[app.player.collision_layer,app.player.collision_mask])
	# Repeat through persisted on-foot state, starting from an occupied vehicle.
	var saved_id := qa_prefix+"saved_on_foot"
	fixture_ids.append(saved_id)
	Store.write(saved_id,{"name":"Integration QA","mode":"life","player":[-335,6,-13],"life":life.get_state(),"world":{},"airport":{},"vehicles":[],"owned":["car"],"vehicle":""})
	app.enter_vehicle(app.vehicles[0])
	app.load_world(saved_id)
	app.player.enabled = false
	check("load_on_foot_restores_walking_collision",app.player.collision_layer==1 and app.player.collision_mask==15 and not is_instance_valid(app.current_vehicle))
	# NPC/mission geography is read from the actual assembled world.
	await physics_frame
	await physics_frame
	var space = app.get_world_3d().direct_space_state
	var all_photos_supported := true
	for point in life._job_route("photo"):
		var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*10)
		query.collision_mask = 1
		var hit = space.intersect_ray(query)
		print("PHOTO_GROUND ",point," ",hit.get("position","none"))
		if hit.is_empty(): all_photos_supported=false
	check("photo_waypoints_have_ground",all_photos_supported)
	var all_boats_water := true
	for point in life._job_route("harbor"):
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x,7,point.z),Vector3(point.x,-1,point.z))
		query.collision_mask = 1
		var hit = space.intersect_ray(query)
		print("HARBOR_STATION ",point," ",hit.get("position","open_water"))
		if not hit.is_empty(): all_boats_water=false
	check("harbor_waypoints_are_open_water",all_boats_water)
	# A layer-4 deck isolates cargo/vehicle contact independently of mutual masks.
	var deck := StaticBody3D.new()
	deck.collision_layer = 4
	deck.collision_mask = 0
	deck.position = Vector3(-9000,25,17000)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(15,0.5,15)
	collider.shape = box
	deck.add_child(collider)
	root.add_child(deck)
	var fresh = load("res://scripts/harbor_cargo.gd").new()
	fresh.configure("qa_deck_fresh",deck.global_position+Vector3(-3,3,0))
	root.add_child(fresh)
	fresh.set_carried(true)
	fresh.set_carried(false)
	check("released_cargo_vehicle_mask",(fresh.collision_mask&4)!=0)
	var restored = load("res://scripts/harbor_cargo.gd").new()
	restored.configure("qa_deck_loaded",deck.global_position+Vector3(3,3,0))
	root.add_child(restored)
	var cargo_state: Dictionary = fresh.get_state()
	cargo_state.position=[deck.position.x+3,deck.position.y+3,deck.position.z]
	restored.apply_state(JSON.parse_string(JSON.stringify(cargo_state)))
	check("loaded_cargo_vehicle_mask",(restored.collision_mask&4)!=0,"mask=%d"%restored.collision_mask)
	for frame in 120:
		await physics_frame
	check("released_cargo_supported_on_boat_layer",fresh.global_position.y>25,"height=%.2f"%fresh.global_position.y)
	check("loaded_cargo_supported_on_boat_layer",restored.global_position.y>25,"height=%.2f"%restored.global_position.y)
	app.active=false
	print("INTEGRATION COMPLETE checks=",checks," failures=",failures," elapsed_ms=",Time.get_ticks_msec()-started)
	quit(failures)
