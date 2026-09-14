extends SceneTree
## Real Jolt contacts and production enemy damage; no user saves or native window.
const Weapons = preload("res://scripts/vehicle_weapons.gd")
const Support = preload("res://scripts/vehicle_support_weapons.gd")
const Modules = preload("res://scripts/weapon_modules.gd")
const Nailong = preload("res://scripts/nailong_enemy.gd")
class Vehicle extends RigidBody3D:
	var kind := "car"
	var occupied := true
	var health := 100.0
	var weapon_upgrade := 0
	var _moving: Dictionary = {}
class Director extends Node3D:
	var enabled := true
	var enemies: Array = []
	var equipped: Array = []
	func weapon_loadout(_kind: String) -> Array: return equipped.duplicate(true)
class Game extends Node3D:
	var active := true
	var paused := false
	var permitted := true
	var current_vehicle: RigidBody3D
	var survival: Node3D
	var player: CharacterBody3D
	var money := 0
	var rewards := 0
	func can_auto_fire_weapon() -> bool: return permitted
	func can_fire_weapon() -> bool: return permitted
var game: Game
var weapons: Node3D
var car: RigidBody3D
var fixtures: Array[Node] = []
var checks: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")
func check(title: String, passed: bool, detail: Dictionary = {}) -> void:
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("WEAPON_MODULES ", "PASS " if passed else "FAIL ", title, " ", JSON.stringify(detail))
func shape(body: CollisionObject3D, size: Vector3) -> void:
	var node := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = size; node.shape = box; body.add_child(node)
func vehicle(kind: String, at: Vector3) -> RigidBody3D:
	var body := Vehicle.new(); body.kind = kind; body.freeze = true; body.position = at; body.collision_layer = 4
	shape(body, Vector3(2,1.5,3)); game.add_child(body); return body
func enemy(at: Vector3, hp := 1000.0, type := "roamer") -> CharacterBody3D:
	var body := Nailong.new(); body.configure(type); body.position = at; game.add_child(body); body.set_physics_process(false)
	body.max_health = hp; body.health = hp
	body.defeated.connect(func(dead_enemy, reward):
		game.survival.enemies.erase(dead_enemy)
		game.money += reward; game.rewards += 1)
	game.survival.enemies.append(body); fixtures.append(body); return body
func wall(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.position = at; shape(body, size); game.add_child(body); fixtures.append(body); return body
func settle() -> void: await physics_frame; await physics_frame
func steps(count: int, allow_free := false) -> void:
	for index in count:
		# Isolate purchased module damage; the separate baseline fixture validates free fire.
		if not allow_free: weapons.support._reload = 1000.0
		weapons._physics_process(1.0/60.0)
		await physics_frame
func reset_case(equipped: Array) -> void:
	weapons.clear(); weapons.support.modules._reloads.clear()
	for node in fixtures:
		if is_instance_valid(node): node.queue_free()
	fixtures.clear(); game.survival.enemies.clear(); game.survival.equipped = equipped
	game.current_vehicle = car; car.occupied = true; car.health = 100.0
	game.active = true; game.paused = false; game.permitted = true; game.survival.enabled = true
	weapons.set_auto_enabled(true); game.money = 0; game.rewards = 0
	await settle()
func count_fired(id: String) -> int: return int(weapons.auto_status().modules.fired.get(id,0))
func stats() -> Dictionary: return weapons.auto_status().modules

func run() -> void:
	check("actual Jolt backend", ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics")
	check("four selectable module identities", Modules.CATALOG.keys() == ["rotary","micro","laser","tesla"])
	for id: String in Modules.CATALOG:
		var first := Modules.spec(id,1); var third := Modules.spec(id,3)
		check(id+" upgrades real damage and firing rate with free ammunition", third.damage > first.damage and third.cooldown < first.cooldown and first.ammo_cost == 0 and third.ammo_cost == 0)
		check(id+" has exactly three increasing purchase costs and a cap", Modules.cost(id,0)>0 and Modules.cost(id,1)>Modules.cost(id,0) and Modules.cost(id,2)>Modules.cost(id,1) and Modules.cost(id,3)==0 and Modules.cost(id,99)==0)
	check("unknown module cannot produce a spec or charge", Modules.spec("bad",1).is_empty() and Modules.cost("bad",0)==0)
	var owned := {"rotary":2,"micro":1,"laser":3,"tesla":1}
	var powered := Modules.power_loadout(["rotary","rotary",{"id":"micro","level":99},"bad","laser","tesla"],owned)
	check("loadout deduplicates caps three slots and reads owned levels only", powered == [{"id":"rotary","level":2},{"id":"micro","level":1},{"id":"laser","level":3}])
	check("locked modules and malformed ownership cannot become equipped", Modules.power_loadout(["rotary","micro","laser","tesla"],{"rotary":0,"micro":-1,"laser":NAN,"tesla":"3"}).is_empty())
	check("untrusted runtime entries clamp tiers deduplicate and cap slots", Modules.normalized_runtime_loadout([{"id":"rotary","level":99},{"id":"rotary","level":1},{"id":"micro","level":2},{"id":"laser","level":1},{"id":"tesla","level":1}]).size()==3 and Modules.normalized_runtime_loadout([{"id":"rotary","level":99}])[0].level==3)
	game = Game.new(); root.add_child(game)
	game.survival = Director.new(); game.add_child(game.survival)
	game.player = CharacterBody3D.new(); game.player.position = Vector3(2000,50,0); game.add_child(game.player)
	weapons = Weapons.new(); game.add_child(weapons); weapons.setup(game); weapons.set_physics_process(false)
	car = vehicle("car",Vector3(0,30,0)); game.current_vehicle = car
	for id: String in Modules.CATALOG:
		await reset_case([{"id":id,"level":1}])
		var victim := enemy(Vector3(0,30,-32)); await settle()
		var start := count_fired(id); await steps(100)
		check(id+" physically damages production enemy with its damage style", victim.health < victim.max_health and str(victim.get_meta("damage_style",""))==id and count_fired(id)>start,{"damage":victim.max_health-victim.health,"shots":count_fired(id)-start})
		check(id+" keeps wallet unchanged without firing main cannon", game.money==0 and weapons.stats().fired==0)
		check(id+" uses its own visible model and shared bounded effects", weapons.support.modules._pods[0].variants[id].visible and Modules.COLORS[id] != Color.BLACK and stats().active_projectiles <= Modules.SHOT_CAPACITY)
	# Compare one physical hit per upgrade tier, not just catalogue numbers.
	for id: String in Modules.CATALOG:
		var damage_by_level: Array[float] = []
		for level in [1,3]:
			await reset_case([{"id":id,"level":level}])
			var victim := enemy(Vector3(0,30,-30)); await settle()
			for frame in 90:
				await steps(1)
				if victim.health < victim.max_health: break
			damage_by_level.append(victim.max_health-victim.health)
		check(id+" level three increases actual first hit damage", damage_by_level[1]>damage_by_level[0] and damage_by_level[0]>0,{"levels":damage_by_level})
	for id: String in Modules.CATALOG:
		var fire_counts: Array[int] = []
		for level in [1,3]:
			await reset_case([{"id":id,"level":level}]); enemy(Vector3(0,30,-30),10000.0); await settle()
			var before:=count_fired(id); await steps(300); fire_counts.append(count_fired(id)-before)
		check(id+" higher tier fires more shots over five physical seconds",fire_counts[1]>fire_counts[0],{"shots":fire_counts})
	# Physical bullets have flight time and cannot tunnel through a new thin wall.
	for id in ["rotary","micro"]:
		await reset_case([{"id":id,"level":1}])
		var victim := enemy(Vector3(0,30,-65)); await settle()
		for frame in 60:
			await steps(1)
			if stats().active_projectiles > 0: break
		check(id+" projectile exists before target takes damage", stats().active_projectiles>0 and victim.health==victim.max_health)
		var shot: Dictionary = weapons.support.modules._shots.filter(func(s):return s.active)[0]
		var previous: Vector3 = shot.point; await steps(1)
		check(id+" projectile travels at finite authored speed", is_equal_approx(previous.distance_to(shot.point),float(Modules.spec(id,1).speed)/60.0))
		wall(Vector3(0,32,-35),Vector3(18,12,.025)); await settle(); await steps(90)
		check(id+" thin wall introduced in flight prevents enemy damage", victim.health==victim.max_health)
	for id in ["rotary","micro"]:
		await reset_case([{"id":id,"level":1}])
		var moving:=enemy(Vector3(0,38,-50)); moving.velocity=Vector3(8,0,0); await settle()
		for frame in 100:
			moving.position+=moving.velocity/60.0
			await steps(1)
		check(id+" leads and physically hits a moving elevated target",moving.health<1000 and moving.position.x>12.0,{"damage":1000-moving.health,"travelled":moving.position.x})
	for id: String in Modules.CATALOG:
		await reset_case([{"id":id,"level":3}])
		var victim := enemy(Vector3(0,30,-35)); wall(Vector3(0,32,-17),Vector3(18,12,.025)); await settle()
		var before := count_fired(id); await steps(160)
		check(id+" cannot acquire or fire through an existing wall", victim.health==victim.max_health and count_fired(id)==before)
	# Micro shells fan out with falloff, and a side wall protects its far side.
	await reset_case([{"id":"micro","level":1}])
	var center := enemy(Vector3(0,30,-30)); var edge := enemy(Vector3(3.9,30,-30)); var hidden := enemy(Vector3(-3.4,30,-30)); var outside := enemy(Vector3(7,30,-30))
	wall(Vector3(-1.8,32,-30),Vector3(.025,8,8)); await settle(); await steps(100)
	check("micro cannon damages multiple targets with stronger centre falloff", center.health<center.max_health and edge.health<edge.max_health and center.max_health-center.health>edge.max_health-edge.health,{"center":1000-center.health,"edge":1000-edge.health})
	check("micro blast cannot hurt a target behind a wall or beyond radius", hidden.health==hidden.max_health and outside.health==outside.max_health)
	await reset_case([{"id":"micro","level":1}])
	var fragile: Array[Node3D] = [enemy(Vector3(0,30,-30),5.0),enemy(Vector3(2.5,30,-30),5.0),enemy(Vector3(-2.5,30,-30),5.0)]
	await settle(); await steps(80)
	check("one lethal blast processes all neighbours despite director removal",fragile.all(func(e):return e.dead) and game.rewards==3 and game.money==360)
	# Chain segments independently test LOS. First shot cannot reach the hidden branch.
	await reset_case([{"id":"tesla","level":1}])
	var chain_first := enemy(Vector3(0,30,-30)); var chain_next := enemy(Vector3(4,30,-32)); var chain_third := enemy(Vector3(7,30,-36)); var chain_hidden := enemy(Vector3(-4,30,-32))
	wall(Vector3(-2,32,-32),Vector3(.025,8,9)); await settle(); await steps(35)
	check("tesla links three distinct targets with decreasing damage", chain_first.health<1000 and chain_next.health>chain_first.health and chain_next.health<1000 and chain_third.health>chain_next.health and chain_third.health<1000,{"damage":[1000-chain_first.health,1000-chain_next.health,1000-chain_third.health]})
	check("each lightning link is blocked by its own wall", chain_hidden.health==1000)
	var linked_counts: Array[int] = []
	for level in [1,3]:
		await reset_case([{"id":"tesla","level":level}])
		var crowd: Array[Node3D] = []
		for index in 5: crowd.append(enemy(Vector3(index*3,30,-30-index*3)))
		await settle(); await steps(35)
		linked_counts.append(crowd.filter(func(e):return e.health<1000).size())
	check("upgraded lightning expands from three to five real chained targets",linked_counts==[3,5],{"hit_counts":linked_counts})
	# All three slots run independently; laser long-range hit is immediate after firing.
	await reset_case([{"id":"rotary","level":1},{"id":"laser","level":1},{"id":"tesla","level":1}])
	enemy(Vector3(0,30,-30)); await settle(); var before_all: Dictionary=stats().fired; await steps(120)
	check("three equipped modules fire concurrently with distinct cadences", count_fired("rotary")-int(before_all.get("rotary",0)) > count_fired("laser")-int(before_all.get("laser",0)) and count_fired("tesla")>int(before_all.get("tesla",0)))
	var before_gate: Dictionary=stats().fired; var before_time:float=stats().simulation_seconds
	game.paused=true; await steps(120)
	check("pause freezes all module clocks and attacks", stats().fired==before_gate and stats().simulation_seconds==before_time)
	game.paused=false; weapons.set_auto_enabled(false); await steps(100)
	check("V off clears module shots locks models and attack counts", stats().fired==before_gate and stats().active_projectiles==0 and stats().locks.is_empty() and stats().loadout.is_empty())
	weapons.set_auto_enabled(true); game.permitted=false; await steps(100)
	check("modal gate suppresses all paid modules", stats().fired==before_gate)
	game.permitted=true; game.survival.enabled=false; await steps(100)
	check("sightseeing gate suppresses all paid modules", stats().fired==before_gate)
	game.survival.enabled=true; car.health=0; await steps(100)
	check("wrecks cannot keep firing paid modules", stats().fired==before_gate)
	car.health=100; car.occupied=false; await steps(100)
	check("unoccupied copies cannot farm module rewards", stats().fired==before_gate and game.money==0)
	# Changed equipment cannot reset a long reload and rapidly replay a micro shell.
	await reset_case([{"id":"micro","level":1}]); enemy(Vector3(0,30,-30)); await settle(); await steps(20)
	var before_micro:=count_fired("micro"); game.survival.equipped=[]; await steps(1); game.survival.equipped=[{"id":"micro","level":1}]; await steps(30)
	check("free removal and re-equipping cannot reset reload", count_fired("micro")==before_micro)
	await reset_case([{"id":"micro","level":1}]); enemy(Vector3(0,30,-65)); await settle(); await steps(20)
	var old_shell:Dictionary=weapons.support.modules._shots.filter(func(s):return s.active)[0]
	game.survival.equipped=[{"id":"micro","level":3}]; await steps(1)
	check("upgrading preserves an airborne shell with its original damage and radius",old_shell.active and old_shell.profile.level==1 and old_shell.profile.damage==40.0 and old_shell.profile.radius==5.0)
	var other:=vehicle("motorcycle",Vector3(180,30,0)); var new_enemy:=enemy(Vector3(180,30,-35)); game.current_vehicle=other
	await settle(); await steps(1)
	check("switching vehicles clears old shots and binds only the new vehicle target",stats().active_projectiles==0 and stats().locks.get("micro",0)==new_enemy.get_instance_id())
	other.queue_free()
	# Each real mount position supports an elevated enemy for every vehicle type.
	for index in Support.KINDS.size():
		var kind: String=Support.KINDS[index]
		await reset_case([{"id":"laser","level":1}])
		var at:=Vector3(index*80+500,60,0); var craft:=vehicle(kind,at); game.current_vehicle=craft
		var victim:=enemy(at+Vector3(0,12,-40)); await settle(); await steps(50)
		check(kind+" module mount attacks a real elevated target", victim.health<1000 and str(victim.get_meta("damage_style",""))=="laser")
		craft.queue_free()
	for type in ["winglet","stormwing"]:
		for id: String in Modules.CATALOG:
			await reset_case([{"id":id,"level":1}])
			var flying:=enemy(Vector3(0,44,-38),1000.0,type); await settle(); await steps(100)
			check(id+" physically hits production "+type+" flight collider",flying.is_flying() and flying.health<1000 and str(flying.get_meta("damage_style",""))==id,{"actual_damage":1000-flying.health,"body_scale":flying.get_meta("enemy_body_scale")})
	await reset_case([{"id":"rotary","level":3},{"id":"micro","level":3},{"id":"laser","level":3}])
	var reward_target:=enemy(Vector3(0,30,-24),8.0); await settle(); await steps(100)
	check("overlapping module fire awards one real enemy kill only", reward_target.dead and game.rewards==1 and game.money==120)
	await reset_case([{"id":"micro","level":1}]); var removed:=enemy(Vector3(0,30,-65)); await settle(); await steps(20)
	removed.queue_free(); await settle(); await steps(20)
	check("freed target safely releases paid projectile lock", stats().active_projectiles==0 and stats().locks.is_empty())
	var before_nodes:int=weapons.support.modules.get_child_count()
	for index in 40:
		game.survival.equipped=[{"id":Modules.CATALOG.keys()[index%4],"level":3}]
		await steps(1)
	check("repeated loadout edits preserve fixed node and effect allocations", weapons.support.modules.get_child_count()==before_nodes and weapons.support.modules._shots.size()==Modules.SHOT_CAPACITY and weapons.support.modules._lines.size()==Modules.LINE_CAPACITY)
	weapons.setup(game)
	check("repeated setup never duplicates module mount or pools", weapons.support.modules.get_child_count()==before_nodes)
	var passed:=checks.all(func(c):return c.passed)
	var report:={"passed":passed,"count":checks.size(),"checks":checks,"engine":Engine.get_version_info().string,"scope":"Production optional modules, Nailong damage lifecycle and actual Jolt collision. Isolated fixtures, no native window or user saves.","source_sha256":{}}
	for path in ["res://scripts/weapon_modules.gd","res://scripts/vehicle_support_weapons.gd","res://scripts/nailong_enemy.gd","res://../source/weapon_modules_test.gd"]:report.source_sha256[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://../reports/weapon-modules.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	weapons.clear(); game.queue_free(); await process_frame; await process_frame
	print("WEAPON_MODULES_COMPLETE ",checks.size()," passed=",passed)
	quit(0 if passed else 1)
