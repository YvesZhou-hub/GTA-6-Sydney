extends SceneTree
## Small real Jolt space; no city startup, user saves, or native rendering.
const Controller = preload("res://scripts/vehicle_weapons.gd")
class Vehicle extends RigidBody3D:
	var kind := "tank"
	var vehicle_id := "combat-fixture"
	var occupied := true
	var health := 100.0
	var _moving: Dictionary = {}
class Game extends Node3D:
	var active := true
	var paused := false
	var permitted := true
	var current_vehicle: RigidBody3D
	var player: CharacterBody3D
	var camera: Camera3D
	var impacts: Array[Dictionary] = []
	var damage_world: Node3D
	func can_fire_weapon() -> bool: return permitted
	func apply_combat_blast(point: Vector3, energy: float, radius: float, source: RigidBody3D):
		impacts.append({"position":point, "energy":energy, "radius":radius, "source":source})
		if is_instance_valid(damage_world): damage_world.damage_at(point, energy, radius)
class DamageWorld extends "res://scripts/harbor_world.gd":
	func _ready():
		_make_materials()
		_structure_box("combat/fixture/wall", Vector3(200, 30, -20), Vector3(6, 6, .025), "sandstone", 2.0e6)
		_ready_complete = true
var game: Game
var controller: Node3D
var checks: Array[Dictionary] = []

func _initialize(): call_deferred("run")
func check(title: String, passed: bool, detail: Dictionary = {}):
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("COMBAT_WEAPONS ", "PASS " if passed else "FAIL ", title, " ", JSON.stringify(detail) if not detail.is_empty() else "")

func shape(parent: CollisionObject3D, size: Vector3):
	var node := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = size; node.shape = box
	parent.add_child(node)

func vehicle(kind: String, at: Vector3) -> Vehicle:
	var body := Vehicle.new(); body.kind = kind; body.freeze = true
	body.collision_layer = 4; body.collision_mask = 15
	game.add_child(body); body.position = at
	shape(body, Vector3(3, 2, 4))
	if kind == "tank":
		var turret := Node3D.new(); body.add_child(turret)
		var barrel := Node3D.new(); turret.add_child(barrel)
		var muzzle := Marker3D.new(); barrel.add_child(muzzle); muzzle.position.z = -5
		body._moving = {"turret":turret,"barrel":barrel,"muzzle":muzzle}
	else:
		var muzzle := Marker3D.new(); body.add_child(muzzle); muzzle.position.z = -9.8
		body._moving = {"weapon_muzzle":muzzle}
	game.current_vehicle = body
	game.camera.position = at + Vector3(0, 0, 10)
	game.camera.rotation = Vector3.ZERO
	return body

func wall(at: Vector3, size: Vector3 = Vector3(6, 6, .025)) -> StaticBody3D:
	var body := StaticBody3D.new(); game.add_child(body); body.position = at; shape(body, size)
	return body

func settle():
	await physics_frame; await physics_frame

func run():
	game = Game.new(); root.add_child(game)
	game.camera = Camera3D.new(); game.add_child(game.camera)
	game.player = CharacterBody3D.new(); game.add_child(game.player)
	shape(game.player, Vector3(.6, 1.8, .6)); game.player.position = Vector3(0, 30, -7)
	controller = Controller.new(); game.add_child(controller); controller.setup(game); controller.set_physics_process(false)
	var tank := vehicle("tank", Vector3(0, 30, 0))
	wall(Vector3(0, 30, -20)); await settle()
	check("preallocated projectile and effects capacities", controller.stats().projectiles_allocated == 32 and controller.stats().effects.allocated == 12)
	check("occupied tank fires", controller.fire_current())
	check("cooldown prevents immediate repeat", not controller.fire_current())
	controller._physics_process(.05)
	check("swept shell hits 25mm wall beyond excluded player", game.impacts.size() == 1 and absf(game.impacts[0].position.z + 19.9875) < .03)
	check("tank hit attributes source and gameplay energy", game.impacts.size() == 1 and game.impacts[0].source == tank and game.impacts[0].energy == 1.0e9 and game.impacts[0].radius == 16)
	controller._physics_process(.1)
	check("one projectile emits exactly one impact", game.impacts.size() == 1 and controller.stats().active_projectiles == 0)
	var other := vehicle("tank", Vector3(30, 30, 0)); await settle()
	check("new vehicle has independent cooldown", controller.fire_current())
	game.current_vehicle = tank
	check("switch back does not reset previous cooldown", not controller.fire_current())
	controller.clear()
	for field in ["occupied", "health", "kind"]:
		var original = tank.get(field)
		tank.set(field, false if field == "occupied" else (0.0 if field == "health" else "car"))
		check("reject ineligible vehicle " + field, not controller.fire_current())
		tank.set(field, original)
	game.active = false; check("inactive world cannot fire", not controller.fire_current()); game.active = true
	game.paused = true; check("paused world cannot fire", not controller.fire_current()); game.paused = false
	game.permitted = false; check("production modal gate prevents firing", not controller.fire_current()); game.permitted = true
	var marker: Node3D = tank._moving.muzzle; tank._moving.erase("muzzle")
	check("missing muzzle rejects safely", not controller.fire_current()); tank._moving.muzzle = marker
	game.current_vehicle = other
	game.camera.position = other.position + Vector3(0, 0, 10)
	game.camera.rotation = Vector3(0, PI, 0)
	controller.update_aim(3)
	check("tank turret turns behind without turning chassis", absf(absf(other._moving.turret.rotation.y) - PI) < .01 and other.rotation == Vector3.ZERO)
	game.camera.rotation = Vector3(deg_to_rad(85), 0, 0); controller.update_aim(3)
	check("barrel maximum elevation is 70 degrees", absf(other._moving.barrel.rotation.x - Controller.MAX_ELEVATION) < .0001)
	game.camera.rotation = Vector3(deg_to_rad(-85), 0, 0); controller.update_aim(3)
	check("barrel depression limit is minus12 degrees", absf(other._moving.barrel.rotation.x - Controller.MIN_ELEVATION) < .0001)
	for action in ["combat_yaw_left","combat_yaw_right","combat_lower","combat_raise"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	game.camera.rotation = Vector3.ZERO; controller.update_aim(3)
	Input.action_press("combat_yaw_left"); Input.action_press("combat_raise"); controller.update_aim(.5)
	Input.action_release("combat_yaw_left"); Input.action_release("combat_raise")
	check("keyboard actions independently raise and traverse", other._moving.turret.rotation.y > .4 and other._moving.barrel.rotation.x > .2)
	controller.clear()
	var fighter := vehicle("fighter", Vector3(60, 30, 0)); fighter.linear_velocity = Vector3(0, 0, -2000.0 / 3.6)
	wall(Vector3(60, 30, -25)); await settle()
	game.camera.rotation.y = PI * .5
	var before := game.impacts.size()
	check("fighter launches while camera faces sideways", controller.fire_current())
	var launched: Dictionary = controller._projectiles.filter(func(p):return p.active)[0]
	check("rocket follows muzzle and inherits 2000kmh shooter velocity", absf(launched.velocity.z + 1350 + 2000.0/3.6) < .01 and absf(launched.velocity.x) < .001)
	controller._physics_process(1.0/60.0)
	check("2000kmh swept rocket cannot skip 25mm wall", game.impacts.size() == before + 1 and absf(game.impacts[-1].position.z + 24.9875) < .03)
	check("fighter damage callback uses independent profile", game.impacts[-1].source == fighter and game.impacts[-1].energy == 1.2e9 and game.impacts[-1].radius == 22)
	controller.clear()
	var through := vehicle("tank", Vector3(90, 30, 0)); wall(Vector3(90, 30, -3)); await settle(); before = game.impacts.size()
	check("barrel already through wall still fires valid obstruction hit", controller.fire_current())
	check("chamber sweep prevents firing from wall far side", game.impacts.size() == before + 1 and game.impacts[-1].position.z > -3.03 and controller.stats().active_projectiles == 0)
	controller.clear()
	var overlap := vehicle("fighter", Vector3(120, 30, 0)); wall(Vector3(120, 30, -9.8), Vector3(4, 4, 1)); await settle(); before = game.impacts.size()
	check("overlapping muzzle produces immediate single hit", controller.fire_current() and game.impacts.size() == before + 1 and controller.stats().active_projectiles == 0)
	controller.clear()
	vehicle("fighter", Vector3(150, 300, 0)); await settle(); before = game.impacts.size()
	controller.fire_current()
	var initial_clock: float = controller._clock
	game.paused = true; controller._physics_process(20)
	check("pause freezes projectile age and cooldown clock", controller.stats().active_projectiles == 1 and controller._clock == initial_clock)
	game.paused = false; controller._physics_process(8)
	check("miss expires without phantom damage", controller.stats().active_projectiles == 0 and game.impacts.size() == before and controller.stats().expired >= 1)
	var prediction_ship := vehicle("tank", Vector3(3000,3000,0)); await settle()
	var muzzle: Node3D = prediction_ship._moving.muzzle
	var expected: Vector3 = muzzle.global_position + Vector3(0,-490,-4400)
	check("reticle prediction uses cannon gravity and lifetime",controller.aim_point().distance_to(expected)<.01)
	var screen_before: Vector2 = game.camera.unproject_position(controller.aim_point())
	Input.action_press("combat_yaw_right"); controller.update_aim(.5); Input.action_release("combat_yaw_right")
	check("Q Z traverse shifts projected reticle with real muzzle",absf(game.camera.unproject_position(controller.aim_point()).x-screen_before.x)>50 and prediction_ship._moving.turret.rotation.y<-.4)
	var saved_offsets: Dictionary = prediction_ship.get_meta("weapon_aim_offsets").duplicate(true)
	game.current_vehicle = other; controller.update_aim(.1)
	game.current_vehicle = prediction_ship; controller.update_aim(.1)
	check("switching vehicles retains per-vehicle manual aim offsets",prediction_ship.get_meta("weapon_aim_offsets")==saved_offsets)
	prediction_ship._moving.turret.rotation.y = deg_to_rad(143)
	prediction_ship._moving.barrel.rotation.x = deg_to_rad(32)
	prediction_ship.set_meta("combat_restore_pose",true)
	controller.clear()
	for index in 60: controller.update_aim(1.0/60.0)
	check("restored manual aim remains stable for60 controller frames",absf(prediction_ship._moving.turret.rotation.y-deg_to_rad(143))<.0001 and absf(prediction_ship._moving.barrel.rotation.x-deg_to_rad(32))<.0001)
	check("restored pose marker consumed and offsets retained",not prediction_ship.has_meta("combat_restore_pose") and prediction_ship.get_meta("weapon_aim_offsets").has("pitch_offset"))
	game.current_vehicle = fighter
	fighter.linear_velocity = Vector3(0,0,-2000.0/3.6)
	check("prediction agrees with forward thin wall collision",absf(controller.aim_point().z+24.9875)<.03)
	controller.clear()
	var allocated_children := controller.get_child_count()
	var accepted := 0
	for index in 33:
		vehicle("fighter", Vector3(400 + index * 15, 400, 0))
		if controller.fire_current(): accepted += 1
	check("projectile pool admits32 and rejects33 without overwriting", accepted == 32 and controller.stats().active_projectiles == 32 and controller.stats().pool_rejections == 1)
	check("repeated fire never allocates extra scene nodes", controller.get_child_count() == allocated_children)
	before = game.impacts.size()
	for index in 100: controller.impact_effect(Vector3(index, 10, 0))
	check("effect-only API never applies world damage", game.impacts.size() == before)
	check("100 explosions reuse bounded12slot pool", controller.stats().effects.active == 12 and controller.stats().effects.allocated == 12 and controller.effects.get_child_count() == 13)
	controller.effects.tick(.5)
	var fx: Dictionary = controller.effects._slots[0]
	check("smoke persists after short flash and light end", not fx.core.visible and not fx.light.visible and fx.smoke.multimesh.get_instance_color(0).a > .1)
	check("visual debris creates no extra rigid bodies", controller.stats().effects.physical_debris_bodies == 0)
	controller.effects.tick(4)
	check("all effect slots naturally expire", controller.stats().effects.active == 0)
	controller.clear()
	check("clear removes all active shots and transient references", controller.stats().active_projectiles == 0 and controller._projectiles.all(func(p):return p.source == null and p.exclude.is_empty()))
	check("clear resets cooldown and retains reusable capacity", controller._cooldowns.is_empty() and controller.stats().projectiles_allocated == 32)
	var damage_world := DamageWorld.new(); game.add_child(damage_world); game.damage_world = damage_world
	vehicle("fighter", Vector3(200, 30, 0)); await settle()
	check("production fixture initially has collision", not controller._ray(Vector3(200,30,0), Vector3(200,30,-40), controller._exclusions(game.current_vehicle)).is_empty())
	controller.fire_current(); controller._physics_process(.02); await settle()
	var state: Dictionary = damage_world.get_state()
	check("real harbor_world blast destroys registered structure", "combat/fixture/wall" in state.destroyed and not damage_world.structures["combat/fixture/wall"].node.visible)
	check("destroyed wall no longer collides", controller._ray(Vector3(200,30,0), Vector3(200,30,-40), controller._exclusions(game.current_vehicle)).is_empty())
	damage_world.repair_all(); await settle()
	check("explicit repair restores visible structure", damage_world.structures["combat/fixture/wall"].node.visible)
	damage_world.apply_state(state); await settle()
	check("serialized damage restores persistent destruction", "combat/fixture/wall" in damage_world.get_state().destroyed and not damage_world.structures["combat/fixture/wall"].node.visible)
	controller.clear(); controller.setup(game)
	check("repeated setup reuses both pools", controller.get_child_count() == allocated_children and controller.stats().effects.allocated == 12)
	var passed := checks.all(func(c): return c.passed)
	var report := {"passed":passed,"count":checks.size(),"checks":checks,"engine":Engine.get_version_info().string,"headless":DisplayServer.get_name()=="headless", "scope":"Small real Jolt space plus production harbor_world damage/save-state component fixture. No main UI, native visuals, full city or user save accessed.","user_saves_touched":false,"source_sha256":{}}
	for path in ["res://scripts/vehicle_weapons.gd","res://scripts/combat_effects.gd","res://scripts/weapon_audio.gd","res://shaders/combat_cloud.gdshader","res://shaders/combat_pressure.gdshader","res://assets/fx/artillery_smoke.png","res://../source/combat_weapons_test.gd"]: report.source_sha256[path] = FileAccess.get_sha256(path)
	DirAccess.make_dir_recursive_absolute("res://../reports/combat-weapons")
	FileAccess.open("res://../reports/combat-weapons/headless.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("COMBAT_WEAPONS_COMPLETE ", checks.size(), " passed=", passed)
	quit(0 if passed else 1)
