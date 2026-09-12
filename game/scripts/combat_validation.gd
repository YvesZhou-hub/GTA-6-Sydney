extends Node
## Internal final-App QA: actual main menu spawn, models, input actions, weapon
## controller and existing city components. Never writes or loads a player save.
var game
var checks: Array[Dictionary] = []
var screenshots: Array[Dictionary] = []
var native := false
var original_world: Dictionary = {}
var original_airport: Dictionary = {}
var target_record: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(title: String, passed: bool, detail: Dictionary = {}):
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("COMBAT_QA ", "PASS " if passed else "FAIL ", title)

func vector(p: Vector3) -> Array: return [p.x,p.y,p.z]

func capture(name: String, eye: Vector3, target: Vector3, detail: Dictionary = {}):
	if not native: return
	game.camera.global_position = eye; game.camera.look_at(target)
	check("near facade stream ready for "+name,await game.world.prepare_view(eye))
	game.update_hud()
	for index in 3:
		RenderingServer.force_draw(false)
		await get_tree().process_frame
	var image: Image = get_tree().root.get_texture().get_image()
	var path := "user://combat-qa/" + name + ".png"
	var saved := image.save_png(path) == OK
	screenshots.append({"file":name+".png","saved":saved,"sha256":FileAccess.get_sha256(path) if saved else "", "eye":vector(eye),"target":vector(target),"resolution":[image.get_width(),image.get_height()],"detail":detail})
	check("native image " + name, saved)

func freeze_fleet():
	for vehicle in game.vehicles:
		vehicle.freeze = true
		vehicle.linear_velocity = Vector3.ZERO
		vehicle.angular_velocity = Vector3.ZERO

func visible_target(vehicle: RigidBody3D) -> Dictionary:
	var chamber: Node3D = vehicle._moving.barrel
	var origin := chamber.global_position
	var candidates: Array[Dictionary] = []
	for id: String in game.world.structures:
		if not id.begins_with("osm/") or not "/storey_group/" in id: continue
		var item: Dictionary = game.world.structures[id]
		var point: Vector3 = item.position
		var distance := origin.distance_to(point)
		var horizontal := Vector2(point.x-origin.x,point.z-origin.z).length()
		if distance < 30 or distance > 240 or horizontal < 25 or point.y < origin.y + 1 or point.y > origin.y + 90: continue
		candidates.append({"id":id,"point":point,"distance":distance})
	candidates.sort_custom(func(a,b):return a.distance<b.distance)
	var excluded: Array[RID] = [vehicle.get_rid(),game.player.get_rid()]
	for candidate: Dictionary in candidates:
		var query := PhysicsRayQueryParameters3D.create(origin,candidate.point,15,excluded)
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or not is_instance_valid(hit.collider): continue
		var id := str(hit.collider.get_meta("damage_id",""))
		if id.begins_with("osm/") and game.world.structures.has(id) and origin.distance_to(hit.position)>20:
			return {"id":id,"point":hit.position,"distance":origin.distance_to(hit.position)}
	return {}

func aim_tank(tank: RigidBody3D, point: Vector3):
	# Explicit test sight setup; production preserves each driver's offsets.
	tank.set_meta("weapon_aim_offsets",{})
	game.camera.global_position = tank._moving.barrel.global_position
	game.camera.look_at(point)
	game.weapons.clear()
	# Production aim math sees the actual viewport camera and city ray queries.
	for index in 180: game.weapons.update_aim(1.0/60.0)

func fighter_shot_pose(fighter: RigidBody3D, target: Vector3) -> Dictionary:
	# Validate the whole aircraft, not only a camera ray. The earlier fixed
	# photo offset could lie behind another tall building and impact at once.
	for rise in [60.0,100.0,150.0]:
		for index in 12:
			var angle := float(index)*TAU/12.0
			var origin := target + Vector3(sin(angle)*180,rise,-cos(angle)*180)
			var pose := Transform3D(Basis.looking_at(target-origin),origin)
			if not preload("res://scripts/vehicle_spawn.gd").clear_envelope(game,fighter,pose): continue
			var ray := PhysicsRayQueryParameters3D.create(origin,target,15,[fighter.get_rid(),game.player.get_rid()])
			var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or not is_instance_valid(hit.collider): continue
			var id := str(hit.collider.get_meta("damage_id",""))
			if origin.distance_to(hit.position)>100 and id.begins_with("osm/"):
				return {"pose":pose,"target":hit.position,"id":id,"clear_distance":origin.distance_to(hit.position)}
	return {}

func fire_and_wait(capture_launch: bool = false) -> Dictionary:
	var before: int = game.weapons.stats().hits
	var fired: int = game.weapons.stats().fired
	game.fire_button.pressed.emit()
	check("production fire-button signal dispatches controller", game.weapons.stats().fired == fired + 1)
	# Fixed-step orchestration makes flash/smoke captures repeatable; these are
	# controller integration checks, not a real-time frame-rate measurement.
	for index in 720:
		game.weapons._physics_process(1.0/60.0)
		await get_tree().physics_frame
		if capture_launch and index==0:
			check("fighter has a live forward projectile for launch capture",game.weapons.stats().active_projectiles>0)
		if capture_launch and index==0 and game.weapons.stats().active_projectiles>0:
			var vehicle: RigidBody3D = game.current_vehicle
			await capture("fighter-rocket-in-flight",vehicle.global_position+vehicle.global_basis*Vector3(25,12,18),vehicle.global_position-vehicle.global_basis.z*18,{"fixed_step_seconds":1.0/60.0,"actual_projectile_slot":true})
		if game.weapons.stats().hits > before:
			var effects = game.weapons.effects
			var slot: Dictionary = effects._slots[(effects._cursor-1+effects.CAPACITY)%effects.CAPACITY]
			return {"hit":true,"point":slot.node.global_position,"age":slot.age,"steps":index+1}
		if game.weapons.stats().active_projectiles == 0: break
	return {"hit":false}

func run():
	game = get_parent(); native = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute("user://combat-qa")
	if not game.qa_running:
		check("internal QA guard set before main setup",false)
		await finish(); return
	game.active = false
	game.new_world("sandbox","Combat QA isolated unsaved world",false)
	game.world_id = "qa_combat_unsaved"
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.player.enabled = false
	game.weapons.set_physics_process(false)
	game.canvas.hide()
	freeze_fleet()
	if native: RenderingServer.render_loop_enabled = false
	await get_tree().physics_frame; await get_tree().physics_frame
	check("production city and weapon controller ready",game.world._ready_complete and is_instance_valid(game.weapons))
	original_world = game.world.get_state().duplicate(true)
	if is_instance_valid(game.airport): original_airport = game.airport.get_state().duplicate(true)
	game.player.global_position = game.world.anchors.get("quay",Vector3(50,6,0)) + Vector3(0,1,0)
	game.camera.global_position = game.player.global_position + Vector3(0,5,14)
	game.camera.look_at(game.player.global_position + Vector3(0,0,-25))
	var tank = game.request_vehicle("tank")
	check("main request creates and enters actual tank",is_instance_valid(tank) and game.current_vehicle == tank and tank.occupied)
	if not is_instance_valid(tank): await finish(); return
	freeze_fleet(); game.player.enabled = false
	await get_tree().physics_frame; await get_tree().physics_frame
	check("tank model exposes independent turret barrel and muzzle",tank._moving.get("turret") is Node3D and tank._moving.get("barrel") is Node3D and tank._moving.get("muzzle") is Marker3D)
	check("production gate permits occupied tank",game.can_fire_weapon())
	game.modal.visible = true
	check("modal gate blocks actual controller",not game.can_fire_weapon() and not game.weapons.fire_current())
	game.modal.visible = false; game.map_panel.visible = true
	check("map gate blocks actual controller",not game.can_fire_weapon() and not game.weapons.fire_current())
	game.map_panel.visible = false
	var tank_position: Vector3 = tank.global_position
	aim_tank(tank,tank_position+Vector3(0,200,-60))
	var raised: float = tank._moving.barrel.rotation.x
	check("production tank barrel rises toward camera within limit",raised > deg_to_rad(60) and raised <= deg_to_rad(70)+.001)
	var initial_yaw: float = tank._moving.turret.rotation.y
	var initial_aim: Vector3 = game.weapons.aim_point()
	Input.action_press("combat_yaw_left")
	for index in 45: game.weapons.update_aim(1.0/60.0)
	Input.action_release("combat_yaw_left")
	check("real bound traverse action turns turret independently",absf(angle_difference(initial_yaw,tank._moving.turret.rotation.y))>.5 and tank.global_position.distance_to(tank_position)<.01)
	check("predicted reticle point follows actual traversed barrel",initial_aim.distance_to(game.weapons.aim_point())>10)
	await capture("tank-articulated-cannon",tank_position+Vector3(13,7,17),tank_position+Vector3.UP*2,{"elevation_deg":rad_to_deg(raised),"posed_frozen_for_capture":true})
	target_record = visible_target(tank)
	check("visible target is an existing mapped city structure",not target_record.is_empty(),{"target":target_record.get("id","")})
	if target_record.is_empty(): await finish(); return
	var target: Vector3 = target_record.point
	aim_tank(tank,target)
	await capture("tank-city-target-before",tank_position+Vector3(12,7,15),target,{"target_component":target_record.id})
	# Capture changed the camera, so restore the firing sight without altering geometry.
	aim_tank(tank,target)
	var tank_hit := await fire_and_wait()
	check("tank projectile reaches actual city collision",tank_hit.hit)
	if tank_hit.hit:
		var hit_point: Vector3 = tank_hit.point
		check("tank blast destroys existing world components",game.world.get_state().destroyed.size() > original_world.destroyed.size())
		await capture("tank-impact-flash",hit_point+Vector3(23,12,27),hit_point,{"effect_age_seconds":tank_hit.age,"fixed_step_controller":true})
		game.weapons.effects.tick(.6)
		await capture("tank-impact-smoke",hit_point+Vector3(23,12,27),hit_point,{"effect_age_seconds":tank_hit.age+.6,"persistent_destroyed_components":game.world.get_state().destroyed.size()})
		var damaged: Dictionary = game.world.get_state().duplicate(true)
		game.world.apply_state(damaged)
		check("damage state roundtrip preserves destroyed component IDs",game.world.get_state().destroyed.size()==damaged.destroyed.size() and damaged.destroyed.all(func(id):return game.world.destroyed.has(id)))
	game.world.apply_state(original_world)
	if is_instance_valid(game.airport): game.airport.apply_state(original_airport)
	game.weapons.clear()
	await get_tree().physics_frame; await get_tree().physics_frame
	var fighter = game.request_vehicle("fighter")
	check("main request creates and enters actual fighter",is_instance_valid(fighter) and game.current_vehicle == fighter and fighter.occupied)
	if not is_instance_valid(fighter): await finish(); return
	freeze_fleet()
	# Explicit QA pose provides a clear view of the native model and a finite
	# forward shot. Flight stability is tested by the separate mobility runner.
	var firing_pose := fighter_shot_pose(fighter,target)
	check("fighter photo pose clears full envelope and100m forward path",not firing_pose.is_empty(),{"distance":firing_pose.get("clear_distance",0)})
	if firing_pose.is_empty(): await finish(); return
	fighter.global_transform = firing_pose.pose
	fighter.reset_physics_interpolation()
	await get_tree().physics_frame; await get_tree().physics_frame
	check("fighter forward muzzle exists outside nose",fighter._moving.get("weapon_muzzle") is Marker3D and fighter._moving.weapon_muzzle.position.z < -9)
	await capture("fighter-forward-rocket-model",fighter.global_position+fighter.global_basis*Vector3(22,10,25),fighter.global_position,{"posed_frozen_for_capture":true,"flight_stability_tested_elsewhere":true})
	game.camera.global_position = fighter.global_position+Vector3(0,4,10)
	game.camera.look_at(fighter.global_position+Vector3.RIGHT*200)
	var fighter_hit := await fire_and_wait(true)
	check("fighter forward projectile hits while camera faces elsewhere",fighter_hit.hit)
	if fighter_hit.hit:
		var hit_point: Vector3 = fighter_hit.point
		check("fighter explosion produces persistent city destruction",game.world.get_state().destroyed.size() > original_world.destroyed.size())
		await capture("fighter-impact-flash",hit_point+Vector3(-24,13,29),hit_point,{"effect_age_seconds":fighter_hit.age,"fixed_step_controller":true})
		game.weapons.effects.tick(.8)
		await capture("fighter-impact-smoke",hit_point+Vector3(-24,13,29),hit_point,{"effect_age_seconds":fighter_hit.age+.8})
	check("invulnerable combat vehicles retain health",tank.health==100 and fighter.health==100)
	game.exit_vehicle(); game.player.enabled=false
	check("exiting vehicle disables firing",not game.can_fire_weapon() and not game.weapons.fire_current())
	game.weapons.clear()
	check("leaving clears all projectiles and explosions",game.weapons.stats().active_projectiles==0 and game.weapons.stats().effects.active==0)
	await finish()

func finish():
	for action in ["combat_yaw_left","combat_yaw_right","combat_raise","combat_lower"]: Input.action_release(action)
	if is_instance_valid(game.weapons): game.weapons.clear()
	if not original_world.is_empty():
		game.world.apply_state(original_world)
		check("QA restores original city damage state",game.world.get_state().destroyed == original_world.destroyed)
	if not original_airport.is_empty() and is_instance_valid(game.airport): game.airport.apply_state(original_airport)
	if native: check("all eight intended combat images captured",screenshots.size()==8 and screenshots.all(func(s):return s.saved))
	var passed := checks.all(func(c):return c.passed)
	var source_sha := {}
	for path in ["res://scripts/combat_validation.gd","res://scripts/vehicle_weapons.gd","res://scripts/combat_effects.gd","res://scripts/tank_models.gd","res://scripts/fighter_models.gd","res://scripts/main.gd"]:
		source_sha[path] = FileAccess.get_sha256(path)
	var report := {"passed":passed,"checks":checks,"count":checks.size(),"screenshots":screenshots,"native":native,"world_ready":game.world._ready_complete,"target_component":target_record.get("id",""),"source_sha256":source_sha,"user_saves_touched":false,"save_written":false,"scope":"Full main and existing OSM city collision; production spawn, weapon button and bound traverse action. Vehicles frozen for poses, fixed-step projectile controller for repeatable effect capture; not a driving/flight or frame-rate benchmark."}
	FileAccess.open("user://combat-qa/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("COMBAT_QA_COMPLETE ",checks.size()," passed=",passed)
	game.active=false
	game.finish_quit(0 if passed else 1)
