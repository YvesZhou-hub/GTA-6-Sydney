extends SceneTree
## Production director, enemies and damage running in real Jolt scenes. This
## suite never opens a user save or replaces the world in the shipped game.
const Director = preload("res://scripts/harbor_survival.gd")
const Player = preload("res://scripts/harbor_player.gd")
const Vehicle = preload("res://scripts/harbor_vehicle.gd")
const Weapons = preload("res://scripts/vehicle_weapons.gd")
const Life = preload("res://scripts/harbor_life.gd")

class FixtureWorld extends Node3D:
	var anchors := {"home":Vector3(0,4.5,0)}
class FixtureGame extends Node3D:
	const VEHICLE_NAMES = Vehicle.NAMES
	var active := true
	var paused := false
	var current_vehicle: RigidBody3D
	var player: CharacterBody3D
	var camera: Camera3D
	var weapons: Node3D
	var life: Node3D
	var world: Node3D
	var city_clock: Node
	var vehicles: Array = []
	var notices: Array = []
	func notify(message: String, _sound: bool = true) -> void: notices.append(message)
	func camera_accepts_mouse() -> bool: return true
	func can_fire_weapon() -> bool: return true
	func apply_combat_blast(_point: Vector3, _energy: float, _radius: float, _source: RigidBody3D) -> void: pass
	func break_combat_contact(_source: RigidBody3D, _collider: Object, _point: Vector3) -> bool: return false
	func combat_ram_feedback(_source: RigidBody3D, _point: Vector3, _count: int) -> void: pass
	func reset_follow_camera() -> void: pass
	func close_panel() -> void: pass
	func exit_vehicle() -> void:
		if is_instance_valid(current_vehicle): current_vehicle.occupied=false
		current_vehicle=null

var game: FixtureGame
var director: Node3D
var checks: Array=[]
var frame_index:=0
var passive_measurement: Dictionary={}

func _initialize() -> void: call_deferred("run")
func check(title: String, passed: bool, detail: Dictionary={}) -> void:
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("ENCOUNTER_DIRECTOR ","PASS " if passed else "FAIL ",title," ",JSON.stringify(detail))
func steps(count: int) -> void:
	for index in count:
		await physics_frame
		frame_index+=1
func solid(at: Vector3, size: Vector3, damage_id: String="") -> StaticBody3D:
	var body:=StaticBody3D.new(); body.position=at; body.collision_layer=1
	if not damage_id.is_empty(): body.set_meta("damage_id",damage_id)
	var collision:=CollisionShape3D.new(); var box:=BoxShape3D.new()
	box.size=size; collision.shape=box; body.add_child(collision); game.world.add_child(body)
	return body
func stop_encounter() -> void:
	director.set_physics_process(false); director.auto_spawn=false; director.clear_enemies()
	game.exit_vehicle(); game.player.reset_health(); game.player.position=Vector3(0,4.65,0)
	game.camera.position=Vector3(0,7,8); game.camera.look_at(game.player.position+Vector3.UP)
	director.reset_mode(true); director.grace=0.0
	await steps(3)
func configure_floor(size: Vector3=Vector3(220,2,220), at: Vector3=Vector3(0,3.5,0), damage_id: String="") -> StaticBody3D:
	for child in game.world.get_children(): child.queue_free()
	await steps(2)
	var floor_body:=solid(at,size,damage_id)
	await steps(2)
	return floor_body
func vehicle(kind: String, at: Vector3) -> RigidBody3D:
	var body:=Vehicle.new(); body.configure(kind,"encounter_fixture_"+kind)
	body.survival_enabled=true; body.freeze=true; body.position=at
	game.add_child(body); game.vehicles.append(body)
	return body

func run() -> void:
	for action in ["fire","forward","back","left","right","rise","fall","brake","boost","drift","sprint","jump"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_release(action)
	game=FixtureGame.new(); root.add_child(game)
	game.world=FixtureWorld.new(); game.add_child(game.world)
	game.player=Player.new(); game.add_child(game.player); game.player.position=Vector3(0,4.65,0); game.player.enabled=false
	game.camera=Camera3D.new(); game.add_child(game.camera); game.camera.position=Vector3(0,7,8); game.camera.look_at(game.player.position+Vector3.UP)
	game.life=Life.new(); game.add_child(game.life)
	game.weapons=Weapons.new(); game.add_child(game.weapons); game.weapons.setup(game); game.weapons.set_physics_process(false)
	director=Director.new(); game.add_child(director); director.setup(game); director.set_physics_process(false)
	await configure_floor()
	check("encounter fixture uses production scripts and Jolt",ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics" and director.get_script()==Director and game.player.get_script()==Player)
	check("director exposes adaptive concurrent encounter budget",director.has_method("desired_enemies"))
	if not director.has_method("desired_enemies"):
		await finish(); return

	# Let the engine tick the director: no manual spawn or direct clock tick.
	director.reset_mode(true); director._rng.seed=90213; director.auto_spawn=true
	var initial_grace: float=director.grace
	director.set_physics_process(true)
	var first_spawn_frame:=-1
	for index in 300:
		await steps(1)
		if director.enemies.size()>0:
			first_spawn_frame=index+1; break
	check("automatic first encounter arrives while entry damage grace is active",first_spawn_frame>0 and first_spawn_frame<=300 and director.grace>0, {"first_spawn_seconds":float(first_spawn_frame)/60.0,"grace_remaining":director.grace,"initial_grace":initial_grace})
	var first_enemy=director.enemies[0] if director.enemies.size()>0 else null
	var initial_distance: float=first_enemy.distance_to_target_surface() if is_instance_valid(first_enemy) else INF
	check("first automatic enemy has a real nearby supported position",is_instance_valid(first_enemy) and initial_distance>=16.0 and initial_distance<=60.0 and first_enemy.global_position.y>0.45,{"distance":initial_distance})
	await steps(180)
	check("automatically spawned enemy actively approaches the player",is_instance_valid(first_enemy) and first_enemy.distance_to_target_surface()<initial_distance-3.0,{"initial_distance":initial_distance,"current_distance":first_enemy.distance_to_target_surface() if is_instance_valid(first_enemy) else -1.0})
	check("entry grace allows encounters without draining player health",game.player.health==game.player.max_health and director.grace>0,{"health":game.player.health,"grace":director.grace,"enemies":director.enemies.size()})
	await stop_encounter()
	director.reset_mode(true); director.auto_spawn=true; director.set_physics_process(true)
	await steps(300)
	var old_enemies: Array=director.enemies.duplicate()
	var old_count: int=old_enemies.size()
	director.wave_kills=director.quota()-1; director.kills=director.wave_kills; director.wave_spawned=director.quota()
	var moving_wallet: int=game.life.money
	game.player.position.x=70.0
	game.camera.position=Vector3(70,7,8); game.camera.look_at(game.player.position+Vector3.UP)
	await steps(180)
	var surviving_old: int=old_enemies.filter(func(e): return is_instance_valid(e) and director.enemies.has(e)).size()
	var new_local: int=director.enemies.filter(func(e): return not old_enemies.has(e) and e.distance_to_target_surface()<48.0).size()
	check("moving to another street spawns new threats before clearing old enemies",old_count>0 and surviving_old>0 and new_local>0 and game.life.money==moving_wallet,{"old_count":old_count,"surviving_old":surviving_old,"new_local":new_local,"total":director.enemies.size(),"reward_progress":director.wave_kills,"reward_quota":director.quota()})
	check("reward milestone cannot lock a partially uncleared map region",director.wave_spawned>=director.quota() and new_local>0 and director.cleared==0,{"spawned_counter":director.wave_spawned,"reward_quota":director.quota()})
	await stop_encounter()

	# Relative budgets encode adaptation without coupling the fixture to a clock.
	var foot_budget: int=director.desired_enemies()
	game.player.health=25.0
	var low_health_budget: int=director.desired_enemies()
	game.player.reset_health()
	var tank:=vehicle("tank",Vector3(0,7,0)); tank.occupied=true; game.current_vehicle=tank
	var vehicle_budget: int=director.desired_enemies()
	director.cleared=100
	var veteran_vehicle_budget: int=director.desired_enemies()
	game.exit_vehicle()
	var veteran_foot_budget: int=director.desired_enemies()
	check("low health reduces incoming pressure while keeping encounters",low_health_budget>=1 and low_health_budget<foot_budget,{"healthy":foot_budget,"low_health":low_health_budget})
	check("vehicle combat receives more concurrent targets than early walking",vehicle_budget>foot_budget and vehicle_budget<Director.ENEMY_LIMIT,{"foot":foot_budget,"vehicle":vehicle_budget})
	check("progression budgets stay bounded below global enemy limit",veteran_foot_budget>=foot_budget and veteran_foot_budget<=10 and veteran_vehicle_budget>=vehicle_budget and veteran_vehicle_budget<=12,{"foot":veteran_foot_budget,"vehicle":veteran_vehicle_budget})
	game.current_vehicle=tank; tank.occupied=true
	director.reset_mode(true); director.auto_spawn=true; director.set_physics_process(true)
	await steps(600)
	director.set_physics_process(false)
	check("vehicle encounter autonomously fills its bounded target budget",director.enemies.size()==vehicle_budget and director.enemies.all(func(e): return e.target==tank),{"actual":director.enemies.size(),"budget":vehicle_budget,"grace":director.grace})
	check("vehicle spawn group stays outside the actual hull",director.enemies.all(func(e): return e.distance_to_target_surface(tank)>.55),{"enemies":director.enemies.size()})
	tank.queue_free(); game.vehicles.clear(); await stop_encounter()

	var successes:=0
	var safe_distances:=true
	for search_index in 20:
		var at: Vector3=director.find_spawn_position()
		if at.is_finite():
			successes+=1
			safe_distances=safe_distances and at.distance_to(game.player.global_position)>=16.0 and at.distance_to(game.player.global_position)<=60.0
	check("open ground produces reliable bounded placement across search bearings",successes==20 and safe_distances,{"successes":successes,"attempts":20})
	var platform:=await configure_floor(Vector3(160,.5,160),Vector3(0,4.25,0),"fixture_walkable_podium")
	var platform_at: Vector3=director.find_spawn_position()
	check("thin walkable podium is usable despite destructible metadata",platform_at.is_finite() and absf(platform_at.y-4.65)<.4,{"point":platform_at,"floor_top":4.5})
	await configure_floor(Vector3(160,12,160),Vector3(0,0.5,0),"fixture_building_roof")
	var roof_at: Vector3=director.find_spawn_position()
	check("building roof is rejected even within vertical spawn window",not roof_at.is_finite(),{"point":roof_at})
	await configure_floor(Vector3(160,2,160),Vector3(0,-1,0))
	game.player.position.y=.15
	check("sea level and submerged placement never creates a ground enemy",not director.find_spawn_position().is_finite())
	game.player.position.y=80.0
	check("high airborne player does not summon unsupported enemies",not director.find_spawn_position().is_finite())
	game.player.position=Vector3(0,4.65,0)
	await configure_floor()
	solid(Vector3(0,10,10),Vector3(22,20,1)); solid(Vector3(0,10,-10),Vector3(22,20,1))
	solid(Vector3(10,10,0),Vector3(1,20,22)); solid(Vector3(-10,10,0),Vector3(1,20,22))
	await steps(2)
	check("enclosed player has no disconnected exterior spawn",not director.find_spawn_position().is_finite())
	await configure_floor(); await stop_encounter()

	var wallet: int=game.life.money; var earnings: int=game.life.lifetime_earnings
	director.wave_spawned=director.quota(); director.wave_kills=0
	director._retarget()
	check("stale full quota reconciles against zero live enemies",director.wave_spawned==0 and director.wave_kills==0)
	var remote=director.spawn_enemy("roamer",Vector3(0,4.65,350)); director.wave_spawned=1
	director._retarget()
	check("departed enemies release encounter capacity without a kill",director.enemies.is_empty() and director.wave_spawned==0 and director.kills==0 and game.life.money==wallet and game.life.lifetime_earnings==earnings)
	remote.defeated.emit(remote,120)
	check("recycled enemy cannot deliver a delayed duplicate reward",game.life.money==wallet and director.kills==0)
	await steps(2)
	var freed=director.spawn_enemy("runner",Vector3(0,4.65,30)); director.wave_spawned=1
	freed.queue_free(); director._retarget()
	check("queued deletion also frees quota without awarding coins",director.enemies.is_empty() and director.wave_spawned==0 and game.life.money==wallet)
	await steps(2)

	var trapped=director.spawn_enemy("roamer",Vector3(0,4.65,40)); director.wave_spawned=1
	solid(Vector3(0,6.5,38.9),Vector3(4,4,.3)); solid(Vector3(0,6.5,41.1),Vector3(4,4,.3))
	solid(Vector3(-1.1,6.5,40),Vector3(.3,4,4)); solid(Vector3(1.1,6.5,40),Vector3(.3,4,4))
	var status: Dictionary={}
	for index in 20:
		await steps(60)
		if not is_instance_valid(trapped): break
		status=trapped.pursuit_status()
		director._recycle_unreachable()
		if not director.enemies.has(trapped): break
	check("physically trapped offscreen pursuer is safely recycled",not director.enemies.has(trapped) and director.wave_spawned==0 and game.life.money==wallet,{"status":status})
	await configure_floor(); await stop_encounter()
	# Valid older saves can fill all resident slots with still-pursuing enemies
	# just outside the local district. Their motion must not starve nearby spawns.
	var previous_district: Array=[]
	for index in Director.ENEMY_LIMIT:
		previous_district.append({"type":"roamer","health":80.0,"position":[float(index%6-3)*3.0,4.65,80.0+float(index/6)*3.0]})
	director.apply_state({"enemies":previous_district,"grace":0.0})
	var original_ids: Array=[]
	for enemy in director.enemies: original_ids.append(enemy.get_instance_id())
	wallet=game.life.money
	director.auto_spawn=true; director.set_physics_process(true)
	var replacement_seconds:=-1.0
	var within_cap:=true
	for index in 360:
		await steps(1)
		within_cap=within_cap and director.enemies.size()<=Director.ENEMY_LIMIT
		if replacement_seconds<0 and director.enemies.any(func(e): return not original_ids.has(e.get_instance_id())):
			replacement_seconds=float(index+1)/60.0
	director.set_physics_process(false)
	check("full resident population outside district leaves room for prompt nearby reinforcement",replacement_seconds>0 and replacement_seconds<=6.0 and director.nearby_enemies()>0,{"replacement_seconds":replacement_seconds,"nearby":director.nearby_enemies(),"total":director.enemies.size()})
	check("capacity recovery retains old pursuers without overcap or false rewards",director.enemies.any(func(e): return original_ids.has(e.get_instance_id())) and within_cap and game.life.money==wallet and director.kills==0)
	await stop_encounter()
	var protected_population: Array=previous_district.duplicate(true)
	protected_population[0].position=[0.0,4.65,-80.0] # Visible distant pursuer.
	protected_population[1].position=[0.0,4.65,30.0] # Hidden but already local.
	director.apply_state({"enemies":protected_population,"grace":0.0})
	var visible_pursuer=director.enemies[0]
	var nearby_pursuer=director.enemies[1]
	var before_capacity: Array=director.enemies.duplicate()
	wallet=game.life.money
	director._recycle_unreachable()
	check("capacity recovery preserves visible distant and hidden nearby pursuers",director.enemies.has(visible_pursuer) and director.enemies.has(nearby_pursuer))
	check("capacity recovery releases exactly the missing local slots",director.enemies.size()==21 and director.nearby_enemies()==1 and game.life.money==wallet and director.kills==0,{"resident":director.enemies.size(),"local":director.nearby_enemies(),"desired":director.desired_enemies()})
	var closest_removed:=INF
	var farthest_retained:=0.0
	for enemy in before_capacity:
		if enemy==visible_pursuer or enemy==nearby_pursuer: continue
		var distance: float=enemy.distance_to_target_surface()
		if director.enemies.has(enemy): farthest_retained=maxf(farthest_retained,distance)
		else: closest_removed=minf(closest_removed,distance)
	check("capacity recovery selects farthest eligible hidden actors first",closest_removed>=farthest_retained-.001,{"closest_removed":closest_removed,"farthest_retained":farthest_retained})
	await stop_encounter()
	director.apply_state({"enemies":previous_district.slice(0,20),"grace":0.0})
	director._recycle_unreachable()
	check("available resident slots prevent unnecessary capacity recycling",director.enemies.size()==20 and director.nearby_enemies()==0)
	await stop_encounter()
	var visible_population: Array=previous_district.duplicate(true)
	for record in visible_population: record.position[2]= -float(record.position[2])
	director.apply_state({"enemies":visible_population,"grace":0.0})
	director._recycle_unreachable()
	check("full visible resident population is never removed for spawn pressure",director.enemies.size()==Director.ENEMY_LIMIT and director.nearby_enemies()==0)
	await stop_encounter()

	var quota_before: int=director.quota()
	for index in quota_before:
		var victim=director.spawn_enemy("roamer",Vector3(0,4.65,22))
		director.wave_spawned+=1
		victim.take_damage(9999.0)
	check("wave completion grants progress without a forced rest",director.cleared==1 and director.rest==0.0 and director.wave_kills==0)
	director.auto_spawn=true; director.set_physics_process(true)
	var replacement_frame:=-1
	for index in 300:
		await steps(1)
		if director.enemies.size()>0: replacement_frame=index+1; break
	check("next wave replenishes promptly without an eighteen or thirty second gap",replacement_frame>0 and replacement_frame<=300,{"replenishment_seconds":float(replacement_frame)/60.0})
	await stop_encounter()
	director.apply_state({"rest":30.0,"grace":0.0,"wave_spawned":18,"wave_kills":0,"enemies":[]})
	check("legacy rest and vanished saved enemies cannot stall loaded play",director.rest==0.0 and director.wave_spawned==0 and director.grace>0.0,{"rest":director.rest,"grace":director.grace,"spawned":director.wave_spawned})
	await stop_encounter()

	# Observe a real first-minute encounter, not simulated direct damage. A passive
	# player should be threatened, but the first contact must leave reaction time.
	director.reset_mode(true); director._rng.seed=314159; director.auto_spawn=true
	var first_damage: Array=[-1]
	var defeated_frame: Array=[-1]
	var damage_count: Array=[0]
	var health_observer=func(hp,_maximum):
		if hp<game.player.max_health:
			damage_count[0]+=1
			if first_damage[0]<0: first_damage[0]=frame_index
	var defeat_observer=func(): defeated_frame[0]=frame_index
	game.player.health_changed.connect(health_observer); game.player.defeated.connect(defeat_observer)
	var began:=frame_index
	director.set_physics_process(true)
	for index in 3600:
		await steps(1)
		if defeated_frame[0]>=0: break
	director.set_physics_process(false)
	game.player.health_changed.disconnect(health_observer); game.player.defeated.disconnect(defeat_observer)
	var first_contact_seconds: float=float(first_damage[0]-began)/60.0 if first_damage[0]>=0 else -1.0
	var contact_survival_seconds: float=float(defeated_frame[0]-first_damage[0])/60.0 if defeated_frame[0]>=0 else (float(frame_index-first_damage[0])/60.0 if first_damage[0]>=0 else -1.0)
	passive_measurement={"first_damage_seconds":first_contact_seconds,"survival_after_first_damage_seconds":contact_survival_seconds,"defeated":defeated_frame[0]>=0,"damage_events":damage_count[0],"duration_seconds":float(frame_index-began)/60.0}
	check("automatic first minute creates actual damage pressure",first_damage[0]>=0 and damage_count[0]>=2,passive_measurement)
	check("initial damage grace expires before enemies can hurt player",first_contact_seconds>=initial_grace-.1,passive_measurement)
	check("first contact leaves at least twenty two seconds of passive reaction time",first_damage[0]>=0 and contact_survival_seconds>=22.0,passive_measurement)
	await finish()

func finish() -> void:
	var passed: bool=checks.all(func(c): return c.passed)
	var report: Dictionary={"passed":passed,"count":checks.size(),"checks":checks,"passive_encounter":passive_measurement,"physics":ProjectSettings.get_setting("physics/3d/physics_engine"),"physics_hz":Engine.physics_ticks_per_second}
	var output:=FileAccess.open("res://../reports/encounter-director.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")); output.close()
	game.queue_free(); await process_frame; await process_frame
	quit(0 if passed else 1)
