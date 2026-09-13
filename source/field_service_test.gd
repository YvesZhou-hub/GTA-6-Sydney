extends SceneTree
## Actual service transactions, vehicle damage and director physics clocks.
const Director = preload("res://scripts/harbor_survival.gd")
const Player = preload("res://scripts/harbor_player.gd")
const Vehicle = preload("res://scripts/harbor_vehicle.gd")
const Weapons = preload("res://scripts/vehicle_weapons.gd")
const Life = preload("res://scripts/harbor_life.gd")

class FixtureWorld extends Node3D:
	var anchors := {"home":Vector3(0,4.5,0)}
class FixtureGame extends Node3D:
	const VEHICLE_NAMES = Vehicle.NAMES
	var active:=true
	var paused:=false
	var current_vehicle: RigidBody3D
	var player: CharacterBody3D
	var camera: Camera3D
	var weapons: Node3D
	var life: Node3D
	var world: Node3D
	var city_clock: Node
	var vehicles: Array=[]
	var notices: Array=[]
	func notify(message: String, _sound: bool=true) -> void: notices.append(message)
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
var tank: RigidBody3D
var twin: RigidBody3D
var checks: Array=[]
func _initialize() -> void: call_deferred("run")
func check(title: String, passed: bool, detail: Dictionary={}) -> void:
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("FIELD_SERVICE ","PASS " if passed else "FAIL ",title," ",JSON.stringify(detail))
func steps(count: int) -> void:
	for index in count: await physics_frame
func vehicle(kind: String, position: Vector3) -> RigidBody3D:
	var body:=Vehicle.new(); body.configure(kind,"field_fixture_"+str(game.vehicles.size()))
	body.survival_enabled=true; body.freeze=true; body.position=position
	game.add_child(body); game.vehicles.append(body)
	return body
func prepare(health: float) -> void:
	director.set_physics_process(false); director.auto_spawn=false
	for member in game.vehicles:
		member.repair(); member.occupied=false; member.linear_velocity=Vector3.ZERO
	game.current_vehicle=tank; tank.occupied=true; game.paused=false
	director.reset_mode(true)
	tank.take_combat_damage((100.0-health)*tank.armor_divisor())
	director.sync_fleet(); director.grace=0.0
	game.life.money=50000
	await steps(2)
func advance_clock(frames: int) -> void:
	director.set_physics_process(true)
	await steps(frames)
	director.set_physics_process(false)

func run() -> void:
	for action in ["fire","forward","back","left","right","rise","fall","brake","boost","drift","sprint","jump"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_release(action)
	game=FixtureGame.new(); root.add_child(game)
	game.world=FixtureWorld.new(); game.add_child(game.world)
	var floor_body:=StaticBody3D.new(); floor_body.position=Vector3(0,3.5,0); floor_body.collision_layer=1
	var collision:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(2000,2,2000)
	collision.shape=box; floor_body.add_child(collision); game.world.add_child(floor_body)
	game.player=Player.new(); game.add_child(game.player); game.player.position=Vector3(0,4.65,0); game.player.enabled=false
	game.camera=Camera3D.new(); game.add_child(game.camera); game.camera.position=Vector3(0,7,8); game.camera.look_at(game.player.position+Vector3.UP)
	game.life=Life.new(); game.add_child(game.life)
	game.weapons=Weapons.new(); game.add_child(game.weapons); game.weapons.setup(game); game.weapons.set_physics_process(false)
	director=Director.new(); game.add_child(director); director.setup(game); director.set_physics_process(false); director.auto_spawn=false
	tank=vehicle("tank",Vector3(50,7,0)); twin=vehicle("tank",Vector3(80,7,0))
	await prepare(40.0)
	check("field service fixture uses actual damage armor and fleet propagation",tank.health==40.0 and twin.health==40.0 and director.fleet_health.tank==40.0 and ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics")
	tank.fuel=30.0; twin.fuel=60.0; tank.linear_velocity=Vector3(20,0,0)
	var enemy=director.spawn_enemy("roamer",tank.position+Vector3(0,-2,8)); enemy.set_physics_process(false)
	director._hurt_clock=8.0
	var money: int=game.life.money
	var result: Dictionary=director.transact("repair")
	check("moving combat full repair remains blocked on a damaged tank",not result.ok and tank.health==40.0 and game.life.money==money)
	result=director.transact("field_repair")
	check("moving surrounded tank can buy exactly25HP for1125 coins",result.ok and tank.health==65.0 and twin.health==65.0 and game.life.money==money-1125 and director.fleet_health.tank==65.0,result)
	check("field repair restores durability without free energy",tank.fuel==30.0 and twin.fuel==60.0)
	check("successful field repair starts a twelve second shared cooldown",is_equal_approx(director.field_repair_cooldown,12.0))
	money=game.life.money; var held_hp: float=tank.health
	result=director.transact("field_repair")
	check("repeated field repair cannot drain money or bypass cooldown",not result.ok and game.life.money==money and tank.health==held_hp and result.message.contains("冷却"))
	var quick: String=director.quick_recovery()
	check("H shortcut shares the same paid repair cooldown",quick.contains("冷却") and game.life.money==money and tank.health==held_hp)
	var car:=vehicle("car",Vector3(120,7,0)); car.take_combat_damage(50.0)
	game.current_vehicle=car
	result=director.transact("field_repair")
	check("switching vehicle kind cannot bypass the global field cooldown",not result.ok and car.health==50.0 and game.life.money==money)
	game.current_vehicle=tank; tank.linear_velocity=Vector3.ZERO
	await advance_clock(711)
	result=director.transact("field_repair")
	check("physical clock keeps field repair blocked just before twelve seconds",not result.ok and director.field_repair_cooldown>0 and game.life.money==money,{"remaining":director.field_repair_cooldown})
	await advance_clock(10)
	result=director.transact("field_repair")
	check("physical clock unlocks paid field repair after twelve seconds",result.ok and tank.health==90.0 and twin.health==90.0 and game.life.money==money-1125)
	await advance_clock(721)
	money=game.life.money
	result=director.transact("field_repair")
	check("partial field repair charges only missing ten HP",result.ok and tank.health==100.0 and twin.health==100.0 and game.life.money==money-450,result)
	await advance_clock(721)
	money=game.life.money
	result=director.transact("field_repair")
	check("full durability preserves money and cooldown",not result.ok and game.life.money==money and director.field_repair_cooldown==0.0)
	await prepare(99.75); money=game.life.money
	result=director.transact("field_repair")
	check("fractional missing durability rounds its actual price up once",result.ok and tank.health==100.0 and twin.health==100.0 and game.life.money==money-12,result)

	await prepare(40.0)
	game.life.money=1124; var kits: int=director.medkits
	result=director.transact("field_repair")
	check("insufficient funds preserve fleet money cooldown and medical kits",not result.ok and game.life.money==1124 and tank.health==40.0 and twin.health==40.0 and director.field_repair_cooldown==0.0 and director.medkits==kits)
	game.life.money=1125
	result=director.transact("field_repair")
	check("exact repair funds succeed without a negative wallet",result.ok and game.life.money==0 and tank.health==65.0)
	var saved: Dictionary=JSON.parse_string(JSON.stringify(director.get_state()))
	check("field repair cooldown is serialized with fleet durability",saved.field_repair_cooldown==12.0 and saved.fleet_health.tank==65.0)
	director.reset_mode(true); director.apply_state(saved); game.life.money=5000
	result=director.transact("field_repair")
	check("save reload retains repair cooldown and prevents instant repeat",not result.ok and director.field_repair_cooldown==12.0 and tank.health==65.0 and game.life.money==5000)
	for invalid in [-5.0,INF,NAN,999.0]:
		director.apply_state({"field_repair_cooldown":invalid})
		var expected:=12.0 if invalid==999.0 else 0.0
		check("invalid field cooldown clamps safely "+str(invalid),director.field_repair_cooldown==expected and is_finite(director.field_repair_cooldown))

	await prepare(60.0)
	tank.position.y= -4.0; money=game.life.money
	result=director.transact("field_repair")
	check("occupied submerged tank rejects field repair without charge",not result.ok and result.message.contains("落水") and tank.health==60.0 and game.life.money==money and director.field_repair_cooldown==0.0)
	tank.fuel=0.0; result=director.transact("refuel")
	check("occupied submerged tank also rejects refuel",not result.ok and tank.fuel==0.0 and game.life.money==money)
	tank.position.y=7.0
	director._hurt_clock=8.0; tank.linear_velocity=Vector3(18,0,0); director.medkits=0
	result=director.transact("medkit")
	check("portable medkit is purchasable during moving recent combat",result.ok and director.medkits==1 and game.life.money==money-300)
	money=game.life.money; result=director.transact("upgrade")
	check("tank fire control can upgrade during moving recent combat",result.ok and tank.weapon_upgrade==1 and twin.weapon_upgrade==1 and game.life.money==money-8000,result)
	tank.fuel=35.0; held_hp=tank.health; money=game.life.money
	result=director.transact("refuel")
	check("moving combat refuel charges only energy without repair",result.ok and game.life.money==money-195 and tank.fuel==100.0 and tank.health==held_hp)

	await prepare(50.0)
	game.player.take_damage(50.0); game.current_vehicle=null; money=game.life.money; kits=director.medkits
	quick=director.quick_recovery()
	check("on foot H consumes one medkit and heals without charging coins",game.player.health==120.0 and director.medkits==kits-1 and game.life.money==money and director.heal_cooldown==12.0 and quick.contains("医疗包"))
	game.player.damage_cooldown=0.0; game.player.take_damage(60.0); game.current_vehicle=tank; kits=director.medkits
	quick=director.quick_recovery()
	check("inside vehicle H repairs vehicle and leaves player health and medkits unchanged",tank.health==75.0 and game.player.health==60.0 and director.medkits==kits and game.life.money==money-1125 and quick.contains("快修"))
	money=game.life.money; game.paused=true
	quick=director.quick_recovery()
	check("paused game cannot trigger a paid keyboard recovery",quick.is_empty() and game.life.money==money and tank.health==75.0)
	game.paused=false; game.current_vehicle=null
	result=director.transact("field_repair")
	check("unboarded field repair cannot charge the player",not result.ok and game.life.money==money)

	# A real same-type damage event immediately before purchase must be included,
	# not erased merely because the director's periodic sync has not run yet.
	await prepare(80.0)
	twin.take_combat_damage(240.0); money=game.life.money
	var quoted: int=director.field_repair_cost()
	check("repair quote sees fresh shared damage without mutating durability",quoted==1125 and tank.health==80.0 and twin.health==40.0 and game.life.money==money,{"quoted":quoted})
	result=director.transact("field_repair")
	check("field transaction includes newer same-type damage before pricing",result.ok and tank.health==65.0 and twin.health==65.0 and game.life.money==money-1125,{"tank_health":tank.health,"other_health":twin.health,"paid":money-game.life.money})

	await prepare(40.0)
	var wreck:=vehicle("tank",Vector3(200,-12,0)); wreck.take_combat_damage(10000.0)
	director.sync_fleet(); money=game.life.money
	result=director.transact("field_repair")
	check("field repair recovers paid durability and removes submerged abandoned twin",result.ok and tank.health==25.0 and twin.health==25.0 and game.life.money==money-1125 and not game.vehicles.has(wreck) and wreck.is_queued_for_deletion())
	var replacement:=vehicle("tank",Vector3(200,7,0)); director.apply_fleet_to(replacement)
	await advance_clock(120); director.sync_fleet()
	check("recovered underwater wreck cannot redamage a fresh shared fleet copy",replacement.health==25.0 and tank.health==25.0 and director.fleet_health.tank==25.0)
	money=game.life.money; kits=director.medkits
	result=director.transact("not_a_service")
	check("unknown service leaves wallet and resources unchanged",not result.ok and game.life.money==money and director.medkits==kits)
	var passed: bool=checks.all(func(c): return c.passed)
	var report: Dictionary={"passed":passed,"count":checks.size(),"checks":checks,"physics":ProjectSettings.get_setting("physics/3d/physics_engine"),"user_saves_touched":false}
	var output:=FileAccess.open("res://../reports/field-service.json",FileAccess.WRITE); output.store_string(JSON.stringify(report,"\t")); output.close()
	print("FIELD_SERVICE_COMPLETE ",checks.size()," passed=",passed)
	director.clear_enemies(); game.queue_free(); await process_frame; await process_frame
	quit(0 if passed else 1)
