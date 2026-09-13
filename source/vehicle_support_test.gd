extends SceneTree
## Actual vehicle support projectiles versus production Nailong health/colliders.
const Weapons = preload("res://scripts/vehicle_weapons.gd")
const Support = preload("res://scripts/vehicle_support_weapons.gd")
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
class Game extends Node3D:
	var active := true
	var paused := false
	var permitted := true
	var current_vehicle: RigidBody3D
	var survival: Node3D
	var player: CharacterBody3D
	var camera: Camera3D
	var money := 0
	var rewards := 0
	func can_auto_fire_weapon() -> bool: return permitted
	func can_fire_weapon() -> bool: return permitted
var game: Game
var weapons: Node3D
var checks: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")
func check(title: String, passed: bool, detail: Dictionary = {}) -> void:
	checks.append({"name":title, "passed":passed, "detail":detail})
	print("VEHICLE_SUPPORT ", "PASS " if passed else "FAIL ", title, " ", JSON.stringify(detail))
func shape(body: CollisionObject3D, size: Vector3) -> void:
	var collider := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = size; collider.shape = box; body.add_child(collider)
func vehicle(kind: String, at: Vector3) -> RigidBody3D:
	var body := Vehicle.new(); body.kind = kind; body.freeze = true; body.position = at; body.collision_layer = 4
	shape(body, Vector3(2, 1.5, 3)); game.add_child(body)
	return body
func enemy(at: Vector3, type := "roamer") -> CharacterBody3D:
	var body := Nailong.new(); body.configure(type); body.position = at; game.add_child(body); body.set_physics_process(false)
	body.defeated.connect(func(_enemy, reward): game.money += reward; game.rewards += 1)
	game.survival.enemies.append(body)
	return body
func wall(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.position = at; shape(body, size); game.add_child(body); return body
func steps(count: int) -> void:
	for index in count:
		weapons._physics_process(1.0 / 60.0)
		await physics_frame
func settle() -> void: await physics_frame; await physics_frame
func reset_encounter() -> void:
	weapons.clear()
	for target in game.survival.enemies:
		if is_instance_valid(target): target.queue_free()
	game.survival.enemies.clear()
	await settle()

func run() -> void:
	check("actual Jolt backend", ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics")
	for kind in Support.KINDS:
		var stats := Support.profile_for(kind, 3)
		check(kind + " has free finite-speed bounded support", stats.ammo_cost == 0 and stats.damage > 0 and stats.damage < 20 and stats.cooldown >= .5 and stats.speed <= 260 and stats.life == 3.0 and stats.range <= 220)
	check("unknown craft cannot silently receive a weapon", Support.profile_for("unknown").is_empty())
	game = Game.new(); root.add_child(game)
	game.survival = Director.new(); game.add_child(game.survival)
	game.player = CharacterBody3D.new(); game.player.position = Vector3(2000, 50, 0); game.add_child(game.player)
	weapons = Weapons.new(); game.add_child(weapons); weapons.setup(game); weapons.set_physics_process(false)
	var car := vehicle("car", Vector3(0, 30, 0)); game.current_vehicle = car
	var nearest := enemy(Vector3(0, 30, -35), "brute")
	var farther := enemy(Vector3(8, 30, -50), "brute")
	await settle(); await steps(10)
	check("automatic support defaults on with a short mounting delay", weapons.auto_enabled() and weapons.auto_status().fired == 0 and weapons.auto_status().mount_count == 1)
	check("nearest visible forward enemy is locked automatically", weapons.auto_status().locked and weapons.auto_status().target_id == nearest.get_instance_id())
	await steps(8)
	check("bolt has finite flight time instead of instant hitscan", weapons.auto_status().active_projectiles == 1 and nearest.health == nearest.max_health)
	var bolt: Dictionary = weapons.support._shots.filter(func(shot): return shot.active)[0]
	var previous: Vector3 = bolt.point
	await steps(1)
	check("one physics step advances pulse by its configured speed", is_equal_approx(previous.distance_to(bolt.point), 110.0 / 60.0))
	await steps(30)
	check("automatic pulse damages actual enemy while player keeps driving", nearest.health < nearest.max_health and farther.health == farther.max_health and weapons.auto_status().hits > 0)
	check("support firing never spends coins or launches a heavy main shell", game.money == 0 and weapons.stats().fired == 0)
	var timer: float = weapons.auto_status().simulation_seconds
	var fired: int = weapons.auto_status().fired
	game.paused = true; await steps(60)
	check("pause freezes support clocks and prevents more fire", weapons.auto_status().simulation_seconds == timer and weapons.auto_status().fired == fired)
	game.paused = false
	weapons.set_auto_enabled(false)
	await steps(60)
	check("V off cancels lock and airborne support bolts", not weapons.auto_enabled() and not weapons.auto_status().locked and weapons.auto_status().active_projectiles == 0 and weapons.auto_status().fired == fired)
	weapons.set_auto_enabled(true); game.permitted = false; await steps(60)
	check("production modal gate blocks automatic support", not weapons.auto_status().available and weapons.auto_status().fired == fired)
	game.permitted = true; game.survival.enabled = false; await steps(60)
	check("sightseeing mode never auto-attacks", not weapons.auto_status().available and weapons.auto_status().fired == fired)
	game.survival.enabled = true; car.health = 0.0; await steps(60)
	check("destroyed current vehicle cannot lock or fire", not weapons.auto_status().available and weapons.auto_status().fired == fired)
	car.health = 100.0; car.occupied = false; await steps(60)
	check("unoccupied vehicle cannot attack by itself", weapons.auto_status().fired == fired)
	car.occupied = true
	await reset_encounter()
	var blocked_enemy := enemy(Vector3(0, 30, -35))
	var shield := wall(Vector3(0, 31, -15), Vector3(12, 8, .025))
	await settle(); fired = weapons.auto_status().fired; await steps(90)
	check("thin wall blocks acquisition and shots", not weapons.auto_status().locked and weapons.auto_status().fired == fired and blocked_enemy.health == 80.0)
	shield.queue_free(); await settle(); await steps(18)
	check("target becomes available when obstruction is removed", weapons.auto_status().locked and weapons.auto_status().active_projectiles == 1)
	shield = wall(Vector3(0, 31, -24), Vector3(12, 8, .025))
	await settle(); await steps(35)
	check("wall introduced during flight intercepts swept bolt before damage", blocked_enemy.health == 80.0 and weapons.auto_status().blocked >= 1)
	shield.queue_free(); await reset_encounter()
	var moving := enemy(Vector3(0, 30, -45), "brute")
	await settle(); await steps(18)
	var initial_direction: Vector3 = weapons.support._shots.filter(func(shot): return shot.active)[0].direction
	for index in 50:
		moving.position.x += .075
		await steps(1)
	check("finite-speed homing follows a moving enemy", moving.health < moving.max_health and moving.position.x > 3.0, {"health":moving.health, "movement":moving.position.x, "initial_direction":str(initial_direction)})
	var boat := vehicle("speedboat", Vector3(220, 30, 0))
	var boat_enemy := enemy(Vector3(220, 30, -30), "brute")
	game.current_vehicle = boat; car.occupied = false
	await settle(); await steps(1)
	check("changing vehicle removes old bolts and retargets from new mount", weapons.auto_status().active_projectiles == 0 and weapons.auto_status().target_id == boat_enemy.get_instance_id() and weapons.support._mount.global_position.distance_to(boat.global_position) < 5.0)
	await steps(45)
	check("boat automatically fights using same single mount", boat_enemy.health < boat_enemy.max_health and weapons.auto_status().mount_count == 1)
	await reset_encounter()
	game.current_vehicle = car; car.occupied = true; boat.occupied = false
	var disposable := enemy(Vector3(0, 30, -35))
	await settle(); await steps(18)
	disposable.queue_free(); await settle(); await steps(30)
	check("freed target safely cancels bolts and lock", weapons.auto_status().active_projectiles == 0 and not weapons.auto_status().locked)
	await reset_encounter()
	var kill_target := enemy(Vector3(0, 30, -25))
	await settle(); await steps(240)
	check("production enemy dies once and delivers one normal coin reward", kill_target.dead and game.money == 120 and game.rewards == 1)
	check("dead enemy cannot retain a lock or receive duplicate rewards", not weapons.auto_status().locked and weapons.auto_status().active_projectiles == 0 and weapons.auto_status().hits >= 5)
	for index in Support.KINDS.size():
		await reset_encounter()
		var kind: String = Support.KINDS[index]
		var origin := Vector3(500 + index * 90, 60, 0)
		var craft := vehicle(kind, origin); craft.weapon_upgrade = 3
		game.current_vehicle = craft
		var victim := enemy(origin + Vector3(0, 0, -32), "brute")
		await settle(); await steps(45)
		var expected: float = Support.profile_for(kind, 3).damage
		check(kind + " physically fires its free auxiliary weapon", is_equal_approx(victim.max_health - victim.health, expected) and weapons.stats().fired == 0,
			{"damage":victim.max_health - victim.health, "expected":expected, "manual_main_shells":weapons.stats().fired})
	await reset_encounter()
	var allocations: int = weapons.support.get_child_count()
	for index in 40:
		game.current_vehicle = car if index % 2 == 0 else boat
		car.occupied = game.current_vehicle == car; boat.occupied = game.current_vehicle == boat
		await steps(1)
	check("forty vehicle switches never duplicate mount or projectile nodes", weapons.support.get_child_count() == allocations and weapons.auto_status().projectiles_allocated == 8 and weapons.auto_status().mount_count == 1)
	weapons.setup(game)
	check("repeated setup preserves support pool allocation", weapons.support.get_child_count() == allocations and weapons.auto_status().projectiles_allocated == 8)
	var passed := checks.all(func(record): return record.passed)
	var report := {"passed":passed, "count":checks.size(), "checks":checks, "engine":Engine.get_version_info().string,
		"headless":DisplayServer.get_name() == "headless", "scope":"Production vehicle support controller and actual Nailong damage/reward lifecycle in isolated Jolt space. No city, user saves or native visuals.",
		"user_saves_touched":false, "source_sha256":{}}
	for path in ["res://scripts/vehicle_weapons.gd", "res://scripts/vehicle_support_weapons.gd", "res://scripts/nailong_enemy.gd", "res://../source/vehicle_support_test.gd"]:
		report.source_sha256[path] = FileAccess.get_sha256(path)
	FileAccess.open("res://../reports/vehicle-support.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	weapons.clear(); game.queue_free(); await process_frame; await process_frame
	print("VEHICLE_SUPPORT_COMPLETE ", checks.size(), " passed=", passed)
	quit(0 if passed else 1)
