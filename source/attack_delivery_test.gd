extends SceneTree
## End to end: a real Nailong attacks a real player through the survival
## director, and the check is how much health the player actually lost. The
## enemy tests only add up what an attack asks for; this measures what lands,
## after the player's hit protection, the crowd damage limit and the projectile
## travel time have all had their say.
const Director = preload("res://scripts/harbor_survival.gd")
const Player = preload("res://scripts/harbor_player.gd")
const Enemy = preload("res://scripts/nailong_enemy.gd")
const Weapons = preload("res://scripts/vehicle_weapons.gd")
const Life = preload("res://scripts/harbor_life.gd")

class FixtureWorld extends Node3D:
	var anchors := {"home":Vector3(0,4.5,0)}
class FixtureGame extends Node3D:
	var active := true
	var paused := false
	var current_vehicle: RigidBody3D
	var player: CharacterBody3D
	var camera: Camera3D
	var weapons: Node3D
	var life: Node3D
	var world: Node3D
	var vehicles: Array = []
	func notify(_message: String, _sound: bool = true) -> void: pass
	func camera_accepts_mouse() -> bool: return true
	func can_fire_weapon() -> bool: return true
	func apply_combat_blast(_point: Vector3, _energy: float, _radius: float, _source: RigidBody3D) -> void: pass
	func break_combat_contact(_source: RigidBody3D, _collider: Object, _point: Vector3) -> bool: return false
	func combat_ram_feedback(_source: RigidBody3D, _point: Vector3, _count: int) -> void: pass
	func reset_follow_camera() -> void: pass
	func close_panel() -> void: pass
	func exit_vehicle() -> void: current_vehicle = null

var game: FixtureGame
var director: Node3D
var checks: Array = []
var losses: Array = []
var _last_health := 0.0

func _initialize() -> void: call_deferred("run")

func check(title: String, passed: bool, detail: Dictionary = {}) -> void:
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("ATTACK_DELIVERY ","PASS " if passed else "FAIL ",title," ",JSON.stringify(detail))

func steps(count: int) -> void:
	for index in count: await physics_frame

func _on_health(current: float, _maximum: float) -> void:
	if current < _last_health: losses.append(snappedf(_last_health - current, 0.01))
	_last_health = current

## One attack cycle from a single enemy standing still at `offset` from the
## player; returns the separate health drops the player took.
func attack_once(kind: String, offset: Vector3, frames: int) -> Array:
	director.clear_enemies()
	await steps(2)
	game.player.reset_health()
	_last_health = game.player.health
	director._incoming_budget = 18.0
	director.grace = 0.0
	losses = []
	var enemy = director.spawn_enemy(kind, game.player.global_position + offset)
	# Standing still keeps the geometry of the test fixed; the attack itself
	# (windup, burst, projectiles, protection, crowd limit) is all production.
	enemy.spec.speed = 0.0
	enemy._cooldown = 0.0
	await steps(frames)
	director.clear_enemies()
	return losses.duplicate()

func total(values: Array) -> float:
	return values.reduce(func(sum: float, value: float): return sum + value, 0.0)

func run() -> void:
	for action in ["fire","forward","back","left","right","rise","fall","brake","boost","drift","sprint","jump"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_release(action)
	game = FixtureGame.new(); root.add_child(game)
	game.world = FixtureWorld.new(); game.add_child(game.world)
	var floor_body := StaticBody3D.new(); floor_body.position = Vector3(0,3.5,0)
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(600,2,600)
	shape.shape = box; floor_body.add_child(shape); game.world.add_child(floor_body)
	game.player = Player.new(); game.add_child(game.player); game.player.position = Vector3(0,4.65,0)
	game.player.enabled = false
	game.player.health_changed.connect(_on_health)
	game.camera = Camera3D.new(); game.add_child(game.camera); game.camera.position = Vector3(0,7,8); game.camera.look_at(game.player.position + Vector3.UP)
	game.life = Life.new(); game.add_child(game.life)
	game.weapons = Weapons.new(); game.add_child(game.weapons); game.weapons.setup(game); game.weapons.set_physics_process(false)
	director = Director.new(); game.add_child(director); director.setup(game); director.auto_spawn = false
	await steps(10)
	var hz := float(Engine.physics_ticks_per_second)

	# A single hit is the baseline: what the table says is what the player loses.
	var roamer := await attack_once("roamer", Vector3(0,0,-1.6), int(hz * 1.6))
	check("a roamer's single hit takes exactly its damage", roamer.size() >= 1 and is_equal_approx(float(roamer[0]), 8.0), {"losses":roamer})

	# The spitter's three spits each land, and together they are the whole attack.
	var spits := await attack_once("spitter", Vector3(0,0,-10.0), int(hz * 3.6))
	check("all three spits of a volley hurt the player", spits.size() == 3, {"losses":spits})
	check("a volley takes the spitter's full 12 damage", is_equal_approx(total(spits), 12.0), {"losses":spits,"total":total(spits)})

	# The alpha's two strikes both land. Its 28 is above the crowd limit (18 at
	# once, refilling 4 a second), which capped the old single slam at 18; the
	# split attack must never deliver less than that.
	var slams := await attack_once("alpha", Vector3(0,0,-3.0), int(hz * 3.2))
	check("both of the alpha's strikes hurt the player", slams.size() == 2, {"losses":slams})
	check("the alpha's first strike lands in full", slams.size() >= 1 and is_equal_approx(float(slams[0]), 14.0), {"losses":slams})
	check("the split slam delivers at least what one capped slam did", total(slams) >= 18.0, {"losses":slams,"total":total(slams)})

	# A leaper's landing goes through the same path and hurts once.
	var leap := await attack_once("leaper", Vector3(0,0,-6.0), int(hz * 2.4))
	check("a leaper that lands on the player takes 14", leap.size() == 1 and is_equal_approx(float(leap[0]), 14.0), {"losses":leap})

	# Protection still does its job: two enemies striking together are one hit.
	director.clear_enemies()
	await steps(2)
	game.player.reset_health(); _last_health = game.player.health; losses = []
	director._incoming_budget = 18.0
	var first = director.spawn_enemy("roamer", game.player.global_position + Vector3(0,0,-1.6))
	var second = director.spawn_enemy("roamer", game.player.global_position + Vector3(1.6,0,0))
	for enemy in [first, second]:
		enemy.spec.speed = 0.0; enemy._cooldown = 0.0
	await steps(int(hz * 1.1))
	check("two strikes in the same instant still count once", losses.size() == 1 and is_equal_approx(float(losses[0]), 8.0), {"losses":losses})
	director.clear_enemies()

	var passed: bool = checks.all(func(c): return c.passed)
	print("ATTACK_DELIVERY_COMPLETE ", checks.size(), " passed=", passed)
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if passed else 1)
