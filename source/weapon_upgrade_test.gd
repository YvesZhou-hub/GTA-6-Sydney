extends SceneTree
## Real projectile impacts plus production blast LOS/falloff in a small Jolt space.
const Weapons = preload("res://scripts/vehicle_weapons.gd")
const Director = preload("res://scripts/harbor_survival.gd")

class Vehicle extends RigidBody3D:
	var kind := "tank"
	var occupied := true
	var health := 100.0
	var weapon_upgrade: Variant = 0
	var _moving: Dictionary = {}
	func take_combat_damage(amount: float) -> float:
		health = maxf(0.0, health - amount)
		return amount

class Enemy extends CharacterBody3D:
	var health := 1000.0
	var hits := 0
	func take_damage(amount: float, _point: Vector3) -> float:
		health -= amount; hits += 1
		return amount

class Game extends Node3D:
	var active := true
	var paused := false
	var current_vehicle: RigidBody3D
	var player: CharacterBody3D
	var camera: Camera3D
	var money := 0
	var impacts: Array[Dictionary] = []
	func can_fire_weapon() -> bool: return true
	func apply_combat_blast(point: Vector3, energy: float, radius: float, owner: RigidBody3D) -> void:
		impacts.append({"point":point, "radius":radius, "energy":energy, "owner":owner})

var game: Game
var weapons: Node3D
var director: Node3D
var checks: Array[Dictionary] = []
var emitted: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")
func check(title: String, passed: bool, detail: Dictionary = {}) -> void:
	checks.append({"name":title, "passed":passed, "detail":detail})
	print("WEAPON_UPGRADE ", "PASS " if passed else "FAIL ", title, " ", JSON.stringify(detail))

func box(parent: CollisionObject3D, size: Vector3) -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = size; collider.shape = shape
	parent.add_child(collider)

func wall(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new(); body.position = at
	box(body, size); game.add_child(body)

func enemy(at: Vector3) -> Enemy:
	var body := Enemy.new(); body.position = at; body.collision_layer = 16; body.collision_mask = 0
	box(body, Vector3(.6, 1.8, .6)); game.add_child(body)
	director.enemies.append(body)
	return body

func run() -> void:
	check("real Jolt backend", ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics")
	for kind in ["tank", "fighter"]:
		var previous: Dictionary = Weapons.profile_for(kind)
		for level in range(4):
			var stats := Weapons.upgrade_stats(kind, level)
			check(kind + " tier " + str(level) + " preview uses exact gameplay profiles",
				stats.current == Weapons.profile_for(kind, level) and stats.base == Weapons.profile_for(kind) and stats.level == level and stats.ammo_cost == 0)
			check(kind + " tier " + str(level) + " next tier and cap are explicit",
				(stats.next == Weapons.profile_for(kind, level + 1) and not stats.at_max) if level < 3 else (stats.next.is_empty() and stats.at_max))
			if level > 0:
				check(kind + " tier " + str(level) + " expands real coverage and reduces reload",
					stats.current.radius > previous.radius and stats.current.damage > previous.damage and stats.current.cooldown < previous.cooldown and stats.current.cooldown > 0 and stats.current.effect <= 2.5)
			previous = stats.current
		check(kind + " invalid tier clamps to saved tier bounds", Weapons.profile_for(kind, -10) == Weapons.profile_for(kind, 0) and Weapons.profile_for(kind, 900) == Weapons.profile_for(kind, 3))
		check(kind + " UI mutation cannot alter shared base or next shell", _preview_is_detached(kind))
	check("unsupported vehicles cannot expose paid fire control", Weapons.upgrade_stats("car", 3).is_empty() and Weapons.profile_for("car", 3).is_empty())
	var max_tank := Weapons.profile_for("tank", 3)
	check("tank maximum upgrade covers 2.56 times area with 0.805 second reload", is_equal_approx(pow(max_tank.radius / Weapons.PROFILES.tank.radius, 2), 2.56) and is_equal_approx(max_tank.cooldown, .805))
	game = Game.new(); root.add_child(game)
	game.player = CharacterBody3D.new(); game.player.position = Vector3(1000, 30, 0); game.add_child(game.player)
	var tank := Vehicle.new(); tank.freeze = true; tank.position = Vector3(0, 30, 0); tank.collision_layer = 4
	box(tank, Vector3(3, 2, 4)); game.add_child(tank); game.current_vehicle = tank
	var barrel := Node3D.new(); tank.add_child(barrel)
	var muzzle := Marker3D.new(); muzzle.position.z = -5; barrel.add_child(muzzle)
	tank._moving = {"barrel":barrel, "muzzle":muzzle}
	weapons = Weapons.new(); game.add_child(weapons); weapons.setup(game); weapons.set_physics_process(false)
	director = Director.new(); director.game = game; director.enabled = true; director.auto_spawn = false
	game.add_child(director); director.set_physics_process(false); director.set_process(false)
	weapons.blast_hit.connect(director.damage_blast)
	weapons.blast_hit.connect(func(point, radius, damage, owner): emitted.append({"point":point, "radius":radius, "damage":damage, "owner":owner}))
	wall(Vector3(0, 30, -80), Vector3(4, 8, .025))
	wall(Vector3(-10, 30, -79), Vector3(1, 8, 8))
	var exposed := enemy(Vector3(20, 29.1, -79))
	var shielded := enemy(Vector3(-20, 29.1, -79))
	var distant := enemy(Vector3(28, 29.1, -79))
	await physics_frame; await physics_frame
	for corrupt in [NAN, INF, "invalid", null]:
		tank.weapon_upgrade = corrupt
		check("corrupt vehicle tier falls back without corrupting projectile stats " + str(corrupt), weapons.weapon_profile(tank) == Weapons.profile_for("tank", 0))
	tank.weapon_upgrade = 0
	check("zero-wallet tank fires for free", game.money == 0 and weapons.fire_current() and game.money == 0)
	var shell: Dictionary = weapons._projectiles.filter(func(slot): return slot.active)[0]
	tank.weapon_upgrade = 3
	check("midflight upgrade leaves original projectile snapshot intact", shell.profile.level == 0 and shell.profile.radius == 16.0 and shell.profile.damage == 90.0)
	check("midflight upgrade does not bypass already started reload", not weapons.fire_current() and is_equal_approx(weapons.aim_status().cooldown_remaining, 1.15))
	weapons._physics_process(.2)
	check("base shell cannot hit enemies outside original 16m radius", emitted.size() == 1 and emitted[0].radius == 16.0 and exposed.hits == 0 and shielded.hits == 0)
	check("blast is centered on actual thin-wall impact", game.impacts.size() == 1 and absf(game.impacts[0].point.z + 79.9875) < .03 and emitted[0].point == game.impacts[0].point)
	weapons._physics_process(.95)
	check("fully upgraded shot remains free and still gates repeat fire", weapons.fire_current() and not weapons.fire_current() and game.money == 0)
	shell = weapons._projectiles.filter(func(slot): return slot.active)[0]
	tank.weapon_upgrade = 0
	check("changing vehicle tier cannot downgrade already launched shell", shell.profile.level == 3 and is_equal_approx(shell.profile.radius, 25.6) and is_equal_approx(shell.profile.damage, 157.5))
	weapons._physics_process(.2)
	check("upgraded projectile emits actual 25.6m world and enemy payload", game.impacts.size() == 2 and emitted.size() == 2 and is_equal_approx(game.impacts[-1].radius, 25.6) and is_equal_approx(emitted[-1].radius, 25.6) and emitted[-1].damage == 157.5)
	check("upgrade reaches enemy between original and upgraded radius", exposed.hits == 1 and exposed.health < 1000.0, {"remaining_health":exposed.health})
	var distance: float = emitted[-1].point.distance_to(exposed.global_position + Vector3.UP)
	check("expanded coverage retains production distance damage falloff", is_equal_approx(1000.0 - exposed.health, 157.5 * lerpf(1.0, .3, distance / 25.6)))
	check("intact wall still blocks upgraded blast damage", shielded.hits == 0 and shielded.health == 1000.0)
	check("enemy beyond upgraded edge is unharmed", distant.hits == 0 and distant.health == 1000.0)
	check("expanded blast effect matches launched radius multiplier", is_equal_approx(weapons.effects._slots[1].scale, 1.6))
	check("upgrades keep original fixed projectile and effects capacities", weapons.stats().projectiles_allocated == 32 and weapons.stats().effects.allocated == 12)
	var passed := checks.all(func(record): return record.passed)
	var report := {"passed":passed, "count":checks.size(), "checks":checks, "engine":Engine.get_version_info().string,
		"headless":DisplayServer.get_name() == "headless", "scope":"Production weapon launch, impact, blast coverage and LOS fixture; no city, native visuals or user save access.", "user_saves_touched":false, "source_sha256":{}}
	for path in ["res://scripts/vehicle_weapons.gd", "res://scripts/harbor_survival.gd", "res://../source/weapon_upgrade_test.gd"]:
		report.source_sha256[path] = FileAccess.get_sha256(path)
	FileAccess.open("res://../reports/weapon-upgrade.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	weapons.clear(); game.queue_free(); await process_frame; await process_frame
	print("WEAPON_UPGRADE_COMPLETE ", checks.size(), " passed=", passed)
	quit(0 if passed else 1)

func _preview_is_detached(kind: String) -> bool:
	var stats := Weapons.upgrade_stats(kind, 1)
	stats.current.radius = 999.0; stats.base.damage = 1.0; stats.next.cooldown = 0.0
	return Weapons.PROFILES[kind].radius < 999.0 and Weapons.PROFILES[kind].damage > 1.0 and Weapons.profile_for(kind, 2).cooldown > 0.0 and Weapons.profile_for(kind, 1).radius < 999.0
