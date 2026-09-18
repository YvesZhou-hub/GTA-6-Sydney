extends SceneTree
## Actual survival director, player, vehicles, enemies, weapons and economy in a
## small Jolt scene. Only the city/UI host is replaced; no user saves are opened.
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
var checks: Array = []

func _initialize() -> void: call_deferred("run")
func check(title: String, passed: bool, detail: Dictionary = {}) -> void:
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("SURVIVAL_LOOP ","PASS " if passed else "FAIL ",title," ",JSON.stringify(detail))
func steps(count: int) -> void:
	for index in count: await physics_frame
func solid(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.position=at; body.collision_layer=1
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size=size
	shape.shape=box; body.add_child(shape); game.world.add_child(body)
	return body
func vehicle(kind: String) -> RigidBody3D:
	var body := Vehicle.new(); body.configure(kind,"loop_"+kind+"_"+str(game.vehicles.size()))
	body.survival_enabled=true; body.freeze=true; body.position=Vector3(60+game.vehicles.size()*50,6,0)
	game.add_child(body); game.vehicles.append(body)
	return body
func clear_enemies() -> void:
	director.clear_enemies()
	await process_frame
	await process_frame
func safe_transactions() -> void:
	director._hurt_clock=0.0
	for body in game.vehicles: body.linear_velocity=Vector3.ZERO

func run() -> void:
	for action in ["fire","forward","back","left","right","rise","fall","brake","boost","drift","sprint","jump"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_release(action)
	game=FixtureGame.new(); root.add_child(game)
	game.world=FixtureWorld.new(); game.add_child(game.world)
	solid(Vector3(0,3.5,0),Vector3(2000,2,2000))
	game.player=Player.new(); game.add_child(game.player); game.player.position=Vector3(0,4.65,0)
	game.player.enabled=false
	game.camera=Camera3D.new(); game.add_child(game.camera); game.camera.position=Vector3(0,7,8); game.camera.look_at(game.player.position+Vector3.UP)
	game.life=Life.new(); game.add_child(game.life)
	game.weapons=Weapons.new(); game.add_child(game.weapons); game.weapons.setup(game); game.weapons.set_physics_process(false)
	director=Director.new(); game.add_child(director); director.setup(game); director.auto_spawn=false; director.set_physics_process(false); director.grace=0.0
	await steps(3)
	check("fixture runs actual Jolt and production scripts",ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics" and director.get_script()==Director and game.player.get_script()==Player and game.life.get_script()==Life)
	var money_before: int=game.life.money
	var earnings_before: int=game.life.lifetime_earnings
	var victim=director.spawn_enemy("roamer",Vector3(0,4.6,-10))
	check("director creates real enemy with layer16 and lifecycle signals",victim!=null and victim.is_in_group("nailong_enemies") and victim.collision_layer==16 and director.enemies.has(victim))
	victim.take_damage(999.0,Vector3.ZERO)
	victim.take_damage(999.0,Vector3.ZERO)
	victim.defeated.emit(victim,120)
	check("kill reward and lifetime earnings are credited exactly once",game.life.money==money_before+120 and game.life.lifetime_earnings==earnings_before+120 and director.kills==1 and director.wave_kills==1 and not director.enemies.has(victim))
	await steps(60)
	check("dead enemy leaves the scene without a second reward",not is_instance_valid(victim) and game.life.money==money_before+120)
	var stronger=director.spawn_enemy("roamer",Vector3(0,4.6,-10),-1.0,5)
	money_before=game.life.money; earnings_before=game.life.lifetime_earnings
	stronger.take_damage(9999.0); stronger.take_damage(9999.0)
	check("higher level kill pays increased gold exactly once",game.life.money==money_before+312 and game.life.lifetime_earnings==earnings_before+312 and director.kills==2 and director._reward_text.contains("Lv.5") and director._reward_text.contains("312"))
	for cleared_count in [0,1,2,4,18,100]:
		director.cleared=cleared_count
		var expected_level:=clampi(1+floori(cleared_count/2.0),1,30)
		check("clearance"+str(cleared_count)+" selects encounter level",director.encounter_level()==expected_level)
	director.cleared=4; director.wave_spawned=0; director.wave_kills=0; director.grace=0.0; director.rest=0.0; director._spawn_clock=0.0
	director.auto_spawn=true; director._rng.seed=62964; director._physics_process(.02); director.auto_spawn=false
	check("automatic street spawn uses actual encounter level",director.enemies.size()==1 and director.enemies[0].level==3 and director.enemies[0].spec.reward==216)
	await clear_enemies(); director.cleared=0; director.wave_spawned=0; director.wave_kills=0
	game.paused=true; director._shot_cooldown=0.0; director.heal_cooldown=3.0; director._hurt_clock=4.0; director.trigger_released=false
	Input.action_press("fire"); director._physics_process(10.0)
	check("pause holds medical combat and firing clocks",director.heal_cooldown==3.0 and director._hurt_clock==4.0 and director._shot_cooldown==0.0)
	game.paused=false; director._physics_process(.01)
	check("held menu click cannot become a gameplay shot",director._shot_cooldown==0.0 and not director.trigger_released)
	Input.action_release("fire"); director._physics_process(.01)
	Input.action_press("fire"); director._physics_process(.01)
	check("release then new press restores blaster fire",director._shot_cooldown>0.0 and director._beams.size()==1)
	Input.action_release("fire"); director._hurt_clock=0.0
	director.medkits=3; director.heal_cooldown=0.0; game.player.reset_health()
	director.heal_player()
	check("full health preserves medkit and cooldown",director.medkits==3 and director.heal_cooldown==0.0 and game.player.health==120.0)
	game.player.take_damage(70.0)
	director.heal_player()
	check("medical action heals60 spends one kit and starts12s cooldown",game.player.health==110.0 and director.medkits==2 and director.heal_cooldown==12.0)
	director.heal_player()
	check("medical repeat cannot bypass cooldown",game.player.health==110.0 and director.medkits==2)
	director._physics_process(11.9); director.heal_player()
	check("medical cooldown blocks until full12 seconds",director.medkits==2 and game.player.health==110.0)
	director._physics_process(.11); director.heal_player()
	check("partial heal clamps to120 and consumes only one kit",game.player.health==120.0 and director.medkits==1 and director.heal_cooldown==12.0)
	# Test the deferred rescue window without allowing a new reset to mask use of
	# a kit on a player whose ordinary heal method intentionally cannot resurrect.
	game.player.health=0.0; director.heal_cooldown=0.0
	director.heal_player()
	check("defeated player cannot waste a medical kit",game.player.health==0.0 and director.medkits==1 and director.heal_cooldown==0.0)
	game.player.reset_health(); director.medkits=0; game.player.take_damage(30.0)
	director.heal_player()
	check("empty medical inventory cannot heal",game.player.health==90.0 and director.medkits==0 and director.heal_cooldown==0.0)
	game.player.reset_health(); safe_transactions()
	game.life.money=1000
	var purchase: Dictionary=director.transact("medkit")
	check("medical supply purchase charges300 once",purchase.ok and game.life.money==700 and director.medkits==1)
	game.life.money=100; var kits_before: int=director.medkits
	purchase=director.transact("medkit")
	check("insufficient funds preserve money and inventory",not purchase.ok and game.life.money==100 and director.medkits==kits_before)
	game.life.money=50000
	var first:=vehicle("tank"); var second:=vehicle("tank"); first.take_combat_damage(120.0)
	director.sync_fleet()
	check("same type copies share worst fleet durability",first.health==80.0 and second.health==80.0 and director.fleet_health.tank==80.0)
	var summoned:=vehicle("tank"); director.apply_fleet_to(summoned)
	check("new free copy cannot erase existing fleet damage",summoned.health==80.0)
	game.current_vehicle=summoned; summoned.occupied=true
	var fee_before: int=game.life.money
	purchase=director.transact("repair")
	check("repair chargesmissing HP times30 and repairs all same type",purchase.ok and game.life.money==fee_before-600 and first.health==100.0 and second.health==100.0 and summoned.health==100.0 and director.fleet_health.tank==100.0)
	fee_before=game.life.money; purchase=director.transact("repair")
	check("undamaged fleet cannot be charged for repair",not purchase.ok and game.life.money==fee_before)
	for level in 3:
		fee_before=game.life.money
		var expected_cost: int=Director.UPGRADE_COSTS[level]
		if game.life.money<expected_cost: game.life.money=expected_cost+1000; fee_before=game.life.money
		purchase=director.transact("upgrade","car") if level==0 else director.transact("upgrade")
		check("upgrade"+str(level+1)+" charges configured amount and propagates",purchase.ok and game.life.money==fee_before-expected_cost and first.weapon_upgrade==level+1 and second.weapon_upgrade==level+1 and summoned.weapon_upgrade==level+1 and director.fleet_upgrades.tank==level+1)
	fee_before=game.life.money; purchase=director.transact("upgrade")
	check("levelIII cap prevents extra upgrade payment",not purchase.ok and game.life.money==fee_before)
	var inherited:=vehicle("tank"); director.apply_fleet_to(inherited)
	check("future copy inherits bought fire control level",inherited.weapon_upgrade==3)
	var board:=vehicle("hoverboard"); game.current_vehicle=board
	fee_before=game.life.money; purchase=director.transact("upgrade")
	check("nonweapon craft cannot buy tank upgrades",not purchase.ok and game.life.money==fee_before and board.weapon_upgrade==0)
	board.health=100.0; board.fuel=0.0; game.life.money=1000
	purchase=director.transact("refuel")
	check("healthy empty vehicle can refuel for300 coins",purchase.ok and game.life.money==700 and board.health==100.0 and board.fuel==100.0)
	fee_before=game.life.money; purchase=director.transact("refuel")
	check("full energy rejects refuel without charging",not purchase.ok and game.life.money==fee_before and board.fuel==100.0)
	board.fuel=0.0; game.life.money=100
	purchase=director.transact("refuel")
	check("insufficient refuel funds preserve money energy and health",not purchase.ok and game.life.money==100 and board.fuel==0.0 and board.health==100.0)
	board.health=66.0; board.fuel=25.0; first.fuel=40.0; game.life.money=1000
	purchase=director.transact("refuel")
	check("refuel only restores current energy without healing or filling others",purchase.ok and game.life.money==775 and board.fuel==100.0 and board.health==66.0 and first.fuel==40.0)
	board.health=100.0; first.fuel=100.0; game.life.money=5000
	game.current_vehicle=null
	var nearby=director.spawn_enemy("roamer",game.player.position+Vector3(19,0,0)); nearby.set_physics_process(false)
	director.medkits=0; fee_before=game.life.money
	purchase=director.transact("medkit")
	check("enemy inside20m permits portable medical supply",purchase.ok and game.life.money==fee_before-300 and director.medkits==1)
	first.take_combat_damage(60.0); director.sync_fleet(); fee_before=game.life.money
	purchase=director.transact("repair","tank")
	check("enemy inside20m still blocks damaged fleet full repair",not purchase.ok and game.life.money==fee_before and first.health==90.0)
	nearby.position=game.player.position+Vector3(20.1,0,0)
	purchase=director.transact("repair","tank")
	check("enemy outside20m permits paid damaged fleet full repair",purchase.ok and game.life.money==fee_before-300 and first.health==100.0)
	await clear_enemies()
	var large:=vehicle("airliner"); game.current_vehicle=large
	var nose_enemy=director.spawn_enemy("roamer",large.position+Vector3(0,-1.35,-50)); nose_enemy.set_physics_process(false)
	var outside_center:=false
	for reach in range(50,20,-1):
		nose_enemy.position=large.position+Vector3(0,-1.35,-float(reach))
		if nose_enemy.distance_to_target_surface(large)<3.0:
			outside_center=true
			break
	large.take_combat_damage(30.0); director.sync_fleet()
	fee_before=game.life.money; purchase=director.transact("repair")
	check("enemy at large aircraft nose blocks full repair despite distant center",outside_center and not purchase.ok and game.life.money==fee_before and large.health==90.0,{"surface_distance":nose_enemy.distance_to_target_surface(large),"center_distance":nose_enemy.position.distance_to(large.position)})
	game.current_vehicle=null; await clear_enemies()
	director.grace=0.0; game.player.reset_health()
	var hit: float=director._hurt_target(8.0,game.player.position+Vector3.FORWARD*3)
	check("director routes damage into real player and startscombat gate",hit==8.0 and game.player.health==112.0 and director._hurt_clock==8.0)
	fee_before=game.life.money; purchase=director.transact("medkit")
	check("recent damage does not block a purchased medical response",purchase.ok and game.life.money==fee_before-300 and director._hurt_clock==8.0)
	fee_before=game.life.money; purchase=director.transact("repair","airliner")
	check("recent damage still blocks damaged full repair for8 seconds",not purchase.ok and game.life.money==fee_before and large.health==90.0)
	director._physics_process(7.9); purchase=director.transact("repair","airliner")
	check("7.9 seconds is not enough for full repair after combat",not purchase.ok and game.life.money==fee_before and large.health==90.0)
	director._physics_process(.11); purchase=director.transact("repair","airliner")
	check("8 second repair gate expires through production clock",purchase.ok and game.life.money==fee_before-300 and large.health==100.0)
	game.current_vehicle=board; board.linear_velocity=Vector3(2,0,0); fee_before=game.life.money
	purchase=director.transact("medkit")
	check("moving vehicle permits portable supply purchases",purchase.ok and game.life.money==fee_before-300)
	board.take_combat_damage(10.0); director.sync_fleet(); fee_before=game.life.money
	purchase=director.transact("repair")
	check("moving damaged vehicle still blocks full repair",not purchase.ok and game.life.money==fee_before and board.health<100.0)
	board.linear_velocity=Vector3.ZERO; game.current_vehicle=null
	# Remote repair is needed after a destroyed aircraft has fallen beyond reach.
	var remote:=vehicle("fighter"); remote.position=Vector3(900,-12,0); remote.freeze=false; remote.take_combat_damage(10000.0); director.sync_fleet()
	game.life.money=10000; fee_before=game.life.money
	purchase=director.call("transact","repair","fighter")
	check("remote destroyed aircraft repair is payable without boarding",purchase.ok and game.life.money==fee_before-3000 and (not is_instance_valid(remote) or remote.is_queued_for_deletion() or remote.health==100.0) and director.fleet_health.fighter==100.0 and game.current_vehicle==null)
	var replacement:=vehicle("fighter"); director.apply_fleet_to(replacement)
	await steps(120); director.sync_fleet()
	check("repaired submerged wreck cannot damage newly summoned same type",replacement.health==100.0 and director.fleet_health.fighter==100.0,{"new_fighter_health":replacement.health,"fleet_health":director.fleet_health.fighter})
	# Stop any faulty retained wreck before subsequent unrelated assertions.
	if is_instance_valid(remote): remote.freeze=true; remote.set_physics_process(false)
	# The enemy must still perform its real sensing/windup/attack, then use the
	# connected manager and player's damage protection rather than direct calls.
	game.player.reset_health(); director.grace=0.0; director._hurt_clock=0.0
	var attacker=director.spawn_enemy("roamer",game.player.position+Vector3(0,0,-1.4))
	await steps(125)
	check("real enemy windup signal damages player through director",game.player.health<120.0 and director._hurt_clock>0.0 and attacker.target==game.player,{"health":game.player.health,"state":attacker.state})
	await clear_enemies(); safe_transactions()
	game.player.reset_health(); game.player.take_damage(35.0)
	director.medkits=4; director.heal_cooldown=6.5; director._hurt_clock=4.2; director.kills=7; director.cleared=1; director.wave_kills=2
	summoned.take_combat_damage(120.0); director.sync_fleet()
	var saved_enemy=director.spawn_enemy("brute",game.player.position+Vector3(40,0,0),-1.0,5); saved_enemy.take_damage(50.0)
	var saved: Dictionary=JSON.parse_string(JSON.stringify(director.get_state()))
	check("survival schema records player fleet resources enemy level and combat timer",saved.revision==3 and saved.health==85.0 and saved.medkits==4 and saved.heal_cooldown==6.5 and saved.combat_cooldown==4.2 and saved.fleet_health.tank==80.0 and saved.fleet_upgrades.tank==3 and saved.enemies.size()==1 and is_equal_approx(saved.enemies[0].health,569.2) and saved.enemies[0].level==5)
	director.reset_mode(true)
	director.apply_state(saved)
	check("JSON roundtrip restores actual player inventory fleet and enemy",game.player.health==85.0 and director.medkits==4 and director.heal_cooldown==6.5 and director.kills==7 and director.cleared==1 and director.wave_kills==2 and summoned.health==80.0 and summoned.weapon_upgrade==3 and director.enemies.size()==1 and is_equal_approx(director.enemies[0].health,569.2) and director.enemies[0].level==5 and director.enemies[0].spec.reward==1248)
	fee_before=game.life.money; purchase=director.transact("repair","tank")
	check("save and reload cannot erase combat full repair cooldown",director._hurt_clock==4.2 and not purchase.ok and game.life.money==fee_before and summoned.health==80.0)
	game.life.money=8765; game.life.lifetime_earnings=4321
	var packed_save: Dictionary=JSON.parse_string(JSON.stringify({"version":preload("res://scripts/save_store.gd").VERSION,"life":game.life.get_state(),"survival":director.get_state()}))
	for repeat_index in 3:
		game.life.money=50000; game.player.reset_health()
		game.life.apply_state(packed_save.life); director.apply_state(packed_save.survival)
	check("v7 repeated section restoration cannot mint money or full health",packed_save.version==7 and game.life.money==8765 and game.life.lifetime_earnings==4321 and game.player.health==85.0 and director.fleet_health.tank==80.0 and director._hurt_clock==4.2)
	director.reset_mode(true); director.apply_state({})
	check("legacy save without survival section keeps damaged physical fleet",game.player.health==120.0 and director.fleet_health.tank==80.0 and summoned.health==80.0 and director.fleet_upgrades.tank==3)
	# Remove the physical fleet to isolate dictionary replacement semantics when
	# a subsequent world save does not contain the previous world's vehicle kind.
	game.current_vehicle=null
	for member in game.vehicles: member.queue_free()
	game.vehicles.clear(); await process_frame; await process_frame
	director.apply_state({"health":50.0,"fleet_health":{"car":30.0},"fleet_upgrades":{"car":0},"enemies":[]})
	check("loading another world does not retain previous fleet dictionaries",director.fleet_health.size()==1 and director.fleet_health.car==30.0 and director.fleet_upgrades.size()==1 and not director.fleet_health.has("tank"))
	director.apply_state({"health":NAN,"medkits":999,"heal_cooldown":-5,"kills":-10,"cleared":INF,"wave_kills":999,"wave_spawned":-3,"grace":-50,"rest":500,"fleet_health":{"car":-50,"tank":NAN,"invalid":42},"fleet_upgrades":{"tank":99,"fighter":-5,"invalid":2},"enemies":"invalid"})
	check("invalid numeric schema stays finite and within gameplay bounds",game.player.health==120.0 and director.medkits==5 and director.heal_cooldown==0.0 and director.kills==0 and director.cleared==0 and director.wave_kills==director.quota()-1 and director.wave_spawned==director.wave_kills and director.grace>=5.0 and director.rest==0.0 and director.fleet_health.car==0.0 and director.fleet_health.tank==100.0 and director.fleet_upgrades.tank==3 and director.fleet_upgrades.fighter==0 and not director.fleet_health.has("invalid") and director.enemies.is_empty())
	director.reset_mode(true)
	var bounded: Array=[]
	for index in 30: bounded.append({"type":"roamer","health":99999,"position":[100+index,4.7,100]})
	director.apply_state({"enemies":bounded})
	check("restored enemies respect count and per-type HP caps",director.enemies.size()==24 and director.enemies.all(func(enemy):return enemy.health<=enemy.max_health and enemy.health>0.0))
	var passed:=checks.all(func(item):return item.passed)
	var report:={"passed":passed,"count":checks.size(),"checks":checks,"engine":Engine.get_version_info().string,"scope":"Real survival director, player, vehicle, enemy, weapon and economy scripts in an isolated Jolt world; only the city/UI host is a fixture. No user saves or complete city launched.","user_saves_touched":false}
	var file:=FileAccess.open("res://../reports/survival-loop.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("SURVIVAL_LOOP_COMPLETE ",checks.size()," passed=",passed)
	director.clear_enemies(); game.queue_free(); await process_frame; await process_frame
	quit(0 if passed else 1)
