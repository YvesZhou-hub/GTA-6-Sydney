extends SceneTree
## Production director/armory/weapons and real vehicles; isolated Jolt world.
const Director = preload("res://scripts/harbor_survival.gd")
const Armory = preload("res://scripts/vehicle_armory.gd")
const Progression = preload("res://scripts/combat_progression.gd")
const Modules = preload("res://scripts/weapon_modules.gd")
const Player = preload("res://scripts/harbor_player.gd")
const Vehicle = preload("res://scripts/harbor_vehicle.gd")
const Weapons = preload("res://scripts/vehicle_weapons.gd")
const Life = preload("res://scripts/harbor_life.gd")
class World extends Node3D:
	var anchors := {"home":Vector3(0,4.5,0)}
class Game extends Node3D:
	const VEHICLE_NAMES = Vehicle.NAMES
	var active := true
	var paused := false
	var permitted := true
	var current_vehicle: RigidBody3D
	var player: CharacterBody3D
	var camera: Camera3D
	var weapons: Node3D
	var survival: Node3D
	var life: Node3D
	var world: Node3D
	var city_clock: Node
	var vehicles: Array = []
	var notices: Array = []
	func notify(message: String, _sound := true) -> void: notices.append(message)
	func camera_accepts_mouse() -> bool: return true
	func can_fire_weapon() -> bool: return permitted
	func can_auto_fire_weapon() -> bool: return permitted
	func apply_combat_blast(_point: Vector3, _energy: float, _radius: float, _source: RigidBody3D) -> void: pass
	func break_combat_contact(_source: RigidBody3D, _collider: Object, _point: Vector3) -> bool: return false
	func combat_ram_feedback(_source: RigidBody3D, _point: Vector3, _count: int) -> void: pass
	func reset_follow_camera() -> void: pass
	func close_panel() -> void: pass
	func exit_vehicle() -> void:
		if is_instance_valid(current_vehicle): current_vehicle.occupied = false
		current_vehicle = null
var game: Game
var director: Node3D
var tank: RigidBody3D
var twin: RigidBody3D
var car: RigidBody3D
var checks: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")
func check(title: String, passed: bool, detail: Dictionary = {}) -> void:
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("ARMORY_PROGRESSION ","PASS " if passed else "FAIL ",title," ",JSON.stringify(detail))
func steps(count: int) -> void:
	for index in count: await physics_frame
func vehicle(kind: String, at: Vector3) -> RigidBody3D:
	var body := Vehicle.new(); body.configure(kind,"armory_fixture_%d"%game.vehicles.size()); body.survival_enabled = true
	body.freeze = true; body.position = at; game.add_child(body); game.vehicles.append(body)
	if is_instance_valid(director): director.apply_fleet_to(body)
	return body
func board(body: RigidBody3D) -> void:
	for member in game.vehicles: member.occupied = member == body
	game.current_vehicle = body
func reset_case() -> void:
	director.set_physics_process(false); game.weapons.set_physics_process(false); game.weapons.clear()
	director.reset_mode(true); director.auto_spawn = false; director.grace = 0.0
	game.active = true; game.paused = false; game.permitted = true; game.life.money = 50000
	for member in game.vehicles: member.repair(); member.weapon_upgrade = 0; member.linear_velocity = Vector3.ZERO
	board(tank); game.player.position = Vector3(0,4.65,0)
	await steps(3)
func advance(frames: int) -> void:
	director.set_physics_process(true); await steps(frames); director.set_physics_process(false)
func weapon_steps(frames: int) -> void:
	for frame in frames:
		game.weapons.support._reload=1000.0
		game.weapons._physics_process(1.0/60.0)
		await steps(1)
func buy_all_max() -> void:
	game.life.money = 1000000
	for id in ["rotary","micro","laser"]:
		for level in 3: director.transact_module("buy",id)
	tank.weapon_upgrade = 3; director.sync_fleet()

func run() -> void:
	for action in ["fire","forward","back","left","right","rise","fall","brake","boost","drift","sprint","jump"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_release(action)
	game = Game.new(); root.add_child(game)
	game.world = World.new(); game.add_child(game.world)
	var floor_body := StaticBody3D.new(); floor_body.position = Vector3(0,3.5,0); floor_body.collision_layer = 1
	var collision := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(1600,2,1600); collision.shape = box
	floor_body.add_child(collision); game.world.add_child(floor_body)
	game.player = Player.new(); game.add_child(game.player); game.player.enabled = false; game.player.position = Vector3(0,4.65,0)
	game.camera = Camera3D.new(); game.add_child(game.camera); game.camera.position = Vector3(0,8,12); game.camera.look_at(game.player.position+Vector3.UP)
	game.life = Life.new(); game.add_child(game.life)
	game.weapons = Weapons.new(); game.add_child(game.weapons)
	director = Director.new(); game.survival = director; game.add_child(director)
	game.weapons.setup(game); game.weapons.set_physics_process(false); director.setup(game); director.set_physics_process(false)
	tank = vehicle("tank",Vector3(0,5.6,0)); twin = vehicle("tank",Vector3(70,5.6,0)); car = vehicle("car",Vector3(120,5.5,0))
	await reset_case()
	check("production armory director vehicles and Jolt are integrated",director.armory.get_script()==Armory and game.weapons.get_script()==Weapons and tank.get_script()==Vehicle and ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics")
	check("new vehicle types start with no paid modules",director.weapon_loadout("tank").is_empty() and director.weapon_loadout("car").is_empty())
	var snapshot:Dictionary=director.armory.snapshot(); game.life.money=Modules.cost("rotary",0)-1
	var result:Dictionary=director.transact_module("buy","rotary")
	check("insufficient funds preserve wallet ownership and fitting",not result.ok and game.life.money==3999 and director.armory.snapshot()==snapshot)
	game.life.money=4000; result=director.transact_module("buy","rotary")
	check("exact purchase charges coins once and equips level one",result.ok and game.life.money==0 and director.armory.level("tank","rotary")==1 and director.weapon_loadout("tank")==[{"id":"rotary","level":1}])
	game.life.money=100000
	var balance:int=game.life.money
	result=director.transact_module("buy","rotary")
	check("second purchase upgrades same module rather than duplicating it",result.ok and game.life.money==balance-9000 and director.weapon_loadout("tank")==[{"id":"rotary","level":2}])
	director.transact_module("buy","rotary"); balance=game.life.money; snapshot=director.armory.snapshot()
	result=director.transact_module("buy","rotary")
	check("max tier rejects purchase without charging or altering ownership",not result.ok and game.life.money==balance and director.armory.snapshot()==snapshot)
	result=director.transact_module("equip","rotary")
	check("duplicate equip cannot consume a second slot",not result.ok and game.life.money==balance and director.weapon_loadout("tank").size()==1)
	director.transact_module("buy","micro"); director.transact_module("buy","laser"); balance=game.life.money
	result=director.transact_module("buy","tesla")
	check("fourth purchase unlocks storage while respecting three fitted slots",result.ok and game.life.money==balance-8500 and director.armory.level("tank","tesla")==1 and director.weapon_loadout("tank").size()==3 and not director.armory.is_equipped("tank","tesla"))
	balance=game.life.money; result=director.transact_module("equip","tesla")
	check("full slots block fitting without charging",not result.ok and game.life.money==balance and director.weapon_loadout("tank").size()==3)
	result=director.transact_module("unequip","rotary")
	check("removing a module is free and preserves its paid tier",result.ok and game.life.money==balance and director.armory.level("tank","rotary")==3 and not director.armory.is_equipped("tank","rotary"))
	result=director.transact_module("equip","tesla")
	check("free replacement fits once space becomes available",result.ok and game.life.money==balance and director.armory.is_equipped("tank","tesla"))
	board(twin)
	check("same-kind physical vehicle reads identical ownership and fitting",director.weapon_loadout(twin.kind)==director.weapon_loadout(tank.kind) and director.armory.level(twin.kind,"rotary")==3)
	board(car); snapshot=director.armory.snapshot(); result=director.transact_module("equip","rotary")
	check("another kind cannot equip the tanks unlocked module",not result.ok and director.armory.snapshot()==snapshot and director.weapon_loadout("car").is_empty())
	director.transact_module("buy","rotary")
	check("buying car module does not alter tank tier or fitting",director.armory.level("car","rotary")==1 and director.armory.level("tank","rotary")==3 and director.armory.is_equipped("tank","tesla"))
	var new_tank:=vehicle("tank",Vector3(180,5.6,0)); var new_boat:=vehicle("speedboat",Vector3(250,1,0))
	check("new copies inherit same-kind purchase without unlocking other kinds",director.weapon_loadout(new_tank.kind)==director.weapon_loadout("tank") and director.weapon_loadout(new_boat.kind).is_empty())
	for action in ["wrong","buy","equip","unequip"]:
		balance=game.life.money; snapshot=director.armory.snapshot(); result=director.transact_module(action,"unknown")
		check("unknown module request is inert "+action,not result.ok and game.life.money==balance and director.armory.snapshot()==snapshot)
	balance=game.life.money; snapshot=director.armory.snapshot(); result=director.transact_module("wrong","rotary")
	check("unknown action cannot mutate wallet or ownership",not result.ok and game.life.money==balance and director.armory.snapshot()==snapshot)
	game.exit_vehicle(); result=director.transact_module("buy","rotary")
	check("unboarded purchase preserves wallet",not result.ok and game.life.money==balance)
	board(car); car.health=0; result=director.transact_module("buy","rotary")
	check("destroyed vehicle rejects new purchase without charging",not result.ok and game.life.money==balance)
	car.repair(); game.paused=true; result=director.transact_module("buy","rotary")
	check("paused B panel may buy exactly one real upgrade",result.ok and game.life.money==balance-9000 and director.armory.level("car","rotary")==2)
	game.paused=false; board(tank)
	director._adaptive_level=6; director._difficulty_clock=9.75
	var saved:Dictionary=JSON.parse_string(JSON.stringify(director.get_state()))
	check("director emits revision three with paid armory and difficulty",saved.revision==3 and saved.has("armory") and saved.adaptive_level==6 and saved.difficulty_clock==9.75)
	director.reset_mode(true); director.apply_state(saved)
	check("JSON roundtrip restores independent kinds slots and paid levels",director.armory.level("tank","rotary")==3 and director.armory.level("car","rotary")==2 and director.weapon_loadout("tank").size()==3 and director.armory.is_equipped("tank","tesla") and not director.armory.is_equipped("tank","rotary"))
	check("JSON roundtrip retains partial gradual difficulty clock",director._adaptive_level==6 and is_equal_approx(director._difficulty_clock,9.75))
	var detached:Dictionary=director.armory.snapshot(); detached.owned.tank.rotary=1
	check("snapshot editing cannot mutate live ownership",director.armory.level("tank","rotary")==3)
	for malformed in [null,[],"bad",{"owned":[]},{"owned":{"tank":["rotary"]}},{"owned":{"unknown":{"rotary":3}}}]:
		director.armory.restore(malformed)
		check("malformed armory is safely empty "+str(malformed),director.weapon_loadout("tank").is_empty())
	director.armory.restore({"owned":{"tank":{"rotary":99,"micro":-1,"laser":NAN,"tesla":"3"}},"equipped":{"tank":["rotary","rotary","micro","laser","tesla",{},null]}})
	check("malformed tiers cap finite numbers and reject unowned duplicate entries",director.weapon_loadout("tank")==[{"id":"rotary","level":3}])
	director.armory.restore({"owned":{"tank":{"rotary":1,"micro":2,"laser":3,"tesla":1}},"equipped":{"tank":["rotary","micro","laser","tesla"]}})
	check("restored loadout cannot exceed three slots",director.weapon_loadout("tank").size()==3)
	director.apply_state({"revision":2,"health":87,"kills":12,"cleared":3,"fleet_health":{"tank":62}})
	check("old survival state does not grant free paid modules",director.armory.owned.values().all(func(items):return items.is_empty()) and director.weapon_loadout("tank").is_empty() and director.kills==12 and director.cleared==3 and game.player.health==87)
	# Runtime consumes the director contract, not a separate test-only loadout.
	await reset_case(); director.transact_module("buy","laser")
	var victim=director.spawn_enemy("winglet",Vector3(0,16,-38)); victim.set_physics_process(false)
	await steps(2); game.weapons.set_auto_enabled(true)
	var hp:float=victim.health; balance=game.life.money
	for frame in 100:
		game.weapons.support._reload=1000; game.weapons._physics_process(1.0/60.0); await steps(1)
	check("purchased director module drives real runtime damage without ammo fees",victim.health<hp and game.weapons.auto_status().modules.fired.get("laser",0)>0 and game.life.money==balance)
	await module_cooldown_controls()
	await reset_case(); buy_all_max(); director.grace=0.0
	var current_goal:int=director.target_encounter_level()
	var unchanged=director.spawn_enemy("roamer",Vector3(0,4.65,-34),-1,1); unchanged.set_physics_process(false)
	var unchanged_hp:float=unchanged.health; var unchanged_max:float=unchanged.max_health
	check("strong loadout raises future difficulty goal above level one",current_goal>1 and director.encounter_level()==1)
	await advance(1070)
	check("difficulty does not jump before eighteen seconds",director._adaptive_level==1 and director._difficulty_clock<18)
	await advance(12)
	check("eighteen seconds advances by exactly one level",director._adaptive_level==2 and director.encounter_level()==2)
	check("equipment progression never rewrites existing enemy hp or level",unchanged.health==unchanged_hp and unchanged.max_health==unchanged_max and unchanged.level==1)
	tank.health=30; director.sync_fleet(); await advance(1200)
	check("low durability stops equipment difficulty ramp",director._adaptive_level==2 and director._difficulty_clock==0)
	tank.repair(); twin.repair(); new_tank.repair(); director.fleet_health.tank=100; director.sync_fleet()
	director.grace=12; await advance(600)
	check("entry protection does not secretly accrue difficulty time",director._adaptive_level==2 and director._difficulty_clock==0)
	director.grace=0; game.paused=true; await advance(1200)
	check("paused world cannot advance equipment difficulty",director._adaptive_level==2 and director._difficulty_clock==0)
	game.paused=false
	for id in ["rotary","micro","laser"]: director.transact_module("unequip",id)
	tank.weapon_upgrade=0; twin.weapon_upgrade=0; new_tank.weapon_upgrade=0; director.fleet_upgrades.tank=0
	await advance(2)
	check("removing loadout lowers future adaptive target immediately",director.target_encounter_level()==1 and director._adaptive_level==1)
	buy_all_max(); director._adaptive_level=6; game.exit_vehicle(); await advance(2)
	check("switching to foot drops equipment pressure without changing existing enemy",director._adaptive_level==1 and director.target_encounter_level()==1 and unchanged.level==1 and unchanged.max_health==unchanged_max)
	check("veteran progression extends to bounded level thirty",Progression.target_level(1000,3,[],true)==30 and Progression.target_level(10,0,[],false)==6)
	# Natural production spawning still works above the old level cap.
	await reset_case(); game.exit_vehicle(); director.cleared=10; director.auto_spawn=true; director.grace=12; director.wave_spawned=director.quota()
	# Leave parked fixture hulls behind; an unboarded player inside a tank is not
	# an admissible spawn route and must not be used as the ground control.
	game.player.position=Vector3(330,4.65,330); game.camera.position=Vector3(330,8,342); game.camera.look_at(game.player.position+Vector3.UP)
	await steps(2)
	await advance(420)
	var born: Array=director.enemies.duplicate(); var old_ids:=born.map(func(e):return e.get_instance_id()); var spawn_before:int=director._spawn_sequence
	check("level six production director naturally spawns despite a full old quota",not born.is_empty() and born.all(func(e):return e.level==6) and director.rest==0,{"count":born.size(),"types":born.map(func(e):return e.enemy_type)})
	game.player.position=Vector3(420,4.65,330); game.camera.position=Vector3(420,8,342); await advance(360)
	check("level six moving districts continues reinforcement without clearing old enemies",director._spawn_sequence>spawn_before and director.enemies.any(func(e):return not old_ids.has(e.get_instance_id())) and director.kills==0 and director.rest==0 and director.enemies.size()<=Director.ENEMY_LIMIT)
	var high_state:Dictionary=director.get_state(); high_state.enemies=[{"type":"stormwing","level":26,"health":200,"position":[420,14,310]}]
	director.apply_state(JSON.parse_string(JSON.stringify(high_state)))
	check("save restoration preserves an enemy level above ten",director.enemies.size()==1 and director.enemies[0].level==26 and director.enemies[0].health==200)
	await low_hover_reinforcements()
	await finish()

func low_hover_reinforcements() -> void:
	await reset_case()
	var hover := vehicle("hoverboard", Vector3(330,14.5,330))
	board(hover)
	game.camera.position = Vector3(330,19.5,343); game.camera.look_at(hover.position)
	var ground_ids: Array = []
	for offset in [Vector3(2,0,0),Vector3(-2,0,0),Vector3(0,0,2),Vector3(0,0,-2)]:
		var enemy = director.spawn_enemy("roamer",Vector3(330,4.58,330)+offset)
		ground_ids.append(enemy.get_instance_id())
	director.auto_spawn=true; director.grace=0.0
	var wallet: int = game.life.money
	await advance(60*16)
	var flyers: Array = director.enemies.filter(func(e):return e.is_flying())
	check("ten metre hover receives flying reinforcements despite surviving ground melee",director._air_context and not flyers.is_empty() and ground_ids.all(func(id):return director.enemies.any(func(e):return e.get_instance_id()==id)),{"nearby":director.nearby_enemies(),"types":director.enemies.map(func(e):return e.enemy_type)})
	check("new flying pursuit reaches low hovering player without free kill credit",hover.health<100.0 and hover.health>0.0 and director.kills==0 and game.life.money==wallet,{"health":hover.health,"wallet":game.life.money})
	# Capacity must be recoverable even when all old melee actors are closer
	# than the previous 14 m release guard. Keep a visible actor and live flyer.
	await reset_case(); board(hover); hover.position=Vector3(330,14.5,330)
	game.camera.position=hover.position; game.camera.look_at(hover.position+Vector3.FORWARD*30)
	var visible_ground = director.spawn_enemy("roamer",Vector3(330,4.58,308))
	var original_flyer = director.spawn_enemy("winglet",hover.position+Vector3(0,7,-17))
	for index in 22:
		var angle := float(index)*TAU/22.0
		director.spawn_enemy("roamer",Vector3(330,4.58,330)+Vector3(cos(angle),0,sin(angle))*(3.0+float(index%3)))
	await steps(2)
	director._air_context=Director.Spawn.target_ground(game).is_empty()
	var full_ids: Array=director.enemies.map(func(e):return e.get_instance_id())
	var hidden_ids: Array=director.enemies.filter(func(e):return director._enemy_offscreen(e) and not e.is_flying()).map(func(e):return e.get_instance_id())
	check("full low hover fixture has twenty four actors including visible ground and active flyer",director.enemies.size()==24 and not director._enemy_offscreen(visible_ground) and not hidden_ids.is_empty() and director.nearby_enemies()==1,{"hidden":hidden_ids.size(),"nearby":director.nearby_enemies()})
	wallet=game.life.money
	director._recycle_unreachable()
	var survivors: Array=director.enemies.map(func(e):return e.get_instance_id())
	var removed: Array=full_ids.filter(func(id):return not survivors.has(id))
	check("full hover capacity releases exactly one hidden unreachable ground actor without reward",director.enemies.size()==23 and removed.size()==1 and hidden_ids.has(removed[0]) and game.life.money==wallet and director.kills==0,{"released":removed.size(),"remaining":director.enemies.size()})
	check("capacity recovery preserves visible enemy and current flying pursuer",director.enemies.has(visible_ground) and director.enemies.has(original_flyer) and not visible_ground.is_queued_for_deletion() and not original_flyer.is_queued_for_deletion())
	var pursuit_before: float=original_flyer.pursuit_status().pursuit_seconds
	director.auto_spawn=true; director.grace=0.0; await advance(300)
	check("recovered hover slot fills with aerial support while original flyer keeps chasing",director.enemies.size()<=24 and director.enemies.filter(func(e):return e.is_flying()).size()>=2 and is_instance_valid(original_flyer) and director.enemies.has(original_flyer) and original_flyer.target==hover and original_flyer.pursuit_status().pursuit_seconds>pursuit_before and director.kills==0 and game.life.money==wallet,{"total":director.enemies.size(),"flyers":director.enemies.filter(func(e):return e.is_flying()).size()})
	# Existing ranged enemies which can reach the craft remain real pressure.
	director.clear_enemies(); await steps(2)
	var reachable_ranged=director.spawn_enemy("spitter",hover.position+Vector3(0,-10,-15))
	await steps(1)
	check("ranged ground attacker within reach still counts toward airborne pressure",director.nearby_enemies()==1 and reachable_ranged.distance_to_target_surface(hover)<float(reachable_ranged.spec.range))

func module_cooldown_controls() -> void:
	await reset_case()
	board(car); director.transact_module("buy","micro")
	board(tank); director.transact_module("buy","micro")
	for body in [tank,twin,car]:
		var enemy=director.spawn_enemy("brute",body.position+Vector3(0,0,-38));enemy.set_physics_process(false)
	await steps(2)
	var initial_fired:int=game.weapons.auto_status().modules.fired.get("micro",0)
	for frame in 90:
		await weapon_steps(1)
		if game.weapons.auto_status().modules.fired.get("micro",0)>initial_fired:break
	var baseline:Dictionary=game.weapons.auto_status().modules
	var fired:int=baseline.fired.get("micro",0)
	var start_clock:float=baseline.simulation_seconds
	check("cooldown control starts with one purchased physical micro shell",fired==initial_fired+1 and baseline.active_projectiles>0 and baseline.reloads.micro>2.35)
	for attempt in 10:
		game.weapons.set_auto_enabled(false);await weapon_steps(1)
		game.weapons.set_auto_enabled(true);await weapon_steps(1)
	var state:Dictionary=game.weapons.auto_status().modules
	check("ten rapid V off-on cycles preserve paid reload and cannot refire",state.fired.micro==fired and state.reloads.micro>2.1)
	for attempt in 5:
		for body in [twin,car,tank]:board(body);await weapon_steps(1)
	state=game.weapons.auto_status().modules
	check("rapid same-kind and different-kind swaps cannot bypass module reload",state.fired.micro==fired and state.reloads.micro>1.8)
	var wallet:int=game.life.money;var successful:=true
	for attempt in 8:
		game.paused=true;successful=successful and director.transact_module("unequip","micro").ok;await weapon_steps(1)
		game.paused=false;await weapon_steps(1)
		game.paused=true;successful=successful and director.transact_module("equip","micro").ok;await weapon_steps(1)
		game.paused=false;await weapon_steps(1)
	state=game.weapons.auto_status().modules
	check("real armory remove-refit transactions preserve reload and wallet",successful and game.life.money==wallet and state.fired.micro==fired and state.reloads.micro>1.5)
	game.paused=true;var held:float=state.reloads.micro;await weapon_steps(120)
	check("reopening a paused armory does not recharge paid modules",is_equal_approx(game.weapons.auto_status().modules.reloads.micro,held))
	game.paused=false
	while float(game.weapons.auto_status().modules.reloads.micro)>.04:await weapon_steps(1)
	check("paid cannon cannot fire before its remaining physical cooldown expires",game.weapons.auto_status().modules.fired.micro==fired)
	await weapon_steps(5);state=game.weapons.auto_status().modules
	check("paid cannon resumes once only after full active reload elapsed",state.fired.micro==fired+1 and state.simulation_seconds-start_clock>=2.4,{"active_elapsed":state.simulation_seconds-start_clock,"new_shots":state.fired.micro-fired})

func finish() -> void:
	var passed:=checks.all(func(c):return c.passed)
	var report:={"passed":passed,"count":checks.size(),"checks":checks,"engine":Engine.get_version_info().string,"user_saves_touched":false,"scope":"Actual production director, armory, weapons, vehicle and enemy scripts in isolated Jolt fixtures. JSON state roundtrip without real user slots. No native window.","source_sha256":{}}
	for path in ["res://scripts/harbor_survival.gd","res://scripts/vehicle_armory.gd","res://scripts/combat_progression.gd","res://scripts/weapon_modules.gd","res://../source/armory_progression_test.gd"]: report.source_sha256[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://../reports/armory-progression.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	director.set_physics_process(false); director.clear_enemies(); game.weapons.clear(); game.queue_free(); await process_frame; await process_frame
	print("ARMORY_PROGRESSION_COMPLETE ",checks.size()," passed=",passed)
	quit(0 if passed else 1)
