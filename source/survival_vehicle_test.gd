extends SceneTree
## Isolated production player, vehicles and weapon rays; no city or user saves.
const Vehicle = preload("res://scripts/harbor_vehicle.gd")
const Player = preload("res://scripts/harbor_player.gd")
const Weapons = preload("res://scripts/vehicle_weapons.gd")
const ACTIONS := ["forward","back","left","right","rise","fall","brake","drift","boost","sprint","jump"]
var checks: Array = []
var stage: Node3D

class CombatFixture extends Node3D:
	var active := true
	var paused := false
	var current_vehicle: RigidBody3D
	var player: CharacterBody3D
	var camera: Camera3D
	var building_blasts := 0
	func can_fire_weapon() -> bool: return true
	func apply_combat_blast(_point: Vector3, _energy: float, _radius: float, _source: RigidBody3D) -> void:
		building_blasts += 1
	func break_combat_contact(_source: RigidBody3D, _collider: Object, _point: Vector3) -> bool: return false
	func combat_ram_feedback(_source: RigidBody3D, _point: Vector3, _count: int) -> void: pass

func _initialize() -> void: call_deferred("run")
func check(title: String, passed: bool, detail: Dictionary = {}) -> void:
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("SURVIVAL ","PASS " if passed else "FAIL ",title," ",JSON.stringify(detail))
func steps(count: int) -> void:
	for index in count: await physics_frame
func make(kind: String, survival: bool = true) -> RigidBody3D:
	var body := Vehicle.new()
	body.configure(kind,"survival_fixture_"+kind)
	body.survival_enabled = survival
	body.position = Vector3(0,4000,0)
	stage.add_child(body)
	body.freeze = true
	return body
func release(body: Node) -> void:
	body.queue_free()
	await process_frame
	await process_frame

func run() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_release(action)
	stage = Node3D.new(); root.add_child(stage)
	check("actual Jolt backend",ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics")
	var player := Player.new(); stage.add_child(player)
	var deaths: Array = []; var changes: Array = []
	player.defeated.connect(func(): deaths.append(true))
	player.health_changed.connect(func(current,maximum): changes.append([current,maximum]))
	var original: Vector3 = player.position
	check("player starts with 120 HP",player.health==120.0 and player.max_health==120.0)
	check("first hit removes health and stores source",player.take_damage(30.0,Vector3(1,2,3))==30.0 and player.health==90.0 and player.last_damage_origin==Vector3(1,2,3))
	check("same-frame crowd hits cannot bypass protection",player.take_damage(90.0)==0.0 and player.health==90.0)
	await steps(20)
	check("protection lasts at least a third of a second",player.take_damage(90.0)==0.0 and player.health==90.0)
	await steps(20)
	check("protection expires on physics clock",player.take_damage(10.0)==10.0 and player.health==80.0)
	check("healing clamps to max and returns actual amount",player.heal(999)==40.0 and player.health==120.0)
	player.reset_health(); player.take_damage(1000.0)
	check("defeat is one signal without teleporting",player.health==0.0 and deaths.size()==1 and player.position==original and player.take_damage(10)==0.0)
	check("ordinary heal cannot resurrect",player.heal(999)==0.0 and player.health==0.0)
	player.reset_health()
	check("reset restores player and clears protection",player.health==120.0 and player.damage_cooldown==0 and changes.back()==[120.0,120.0])
	check("invalid damage cannot corrupt player health",player.take_damage(NAN)==0.0 and player.take_damage(-10)==0.0 and player.health==120.0)
	await release(player)
	for kind: String in Vehicle.NAMES:
		var body := make(kind)
		var factor: float = {"tank":6.0,"fighter":3.0,"airliner":3.0,"yacht":4.0}.get(kind,1.0)
		check(kind+" is vulnerable with expected armor",not body.is_damage_immune() and not body.is_invincible() and is_equal_approx(body.take_combat_damage(12),12.0/factor),{"health":body.health,"armor":factor})
		body.fuel=38.0; body.weapon_upgrade=2
		var saved: Dictionary = JSON.parse_string(JSON.stringify(body.get_state()))
		body.apply_state(saved)
		await steps(3)
		check(kind+" damage and upgrade survive load and physics ticks",is_equal_approx(body.health,100.0-12.0/factor) and body.fuel==38.0 and body.weapon_upgrade==2)
		body.weapon_upgrade=9
		check(kind+" upgrade is bounded",body.weapon_upgrade==3)
		body.apply_state({"health":-10.0,"fuel":400.0,"weapon_upgrade":-5,"frozen":true,"position":[0,4000,0]})
		check(kind+" old zero-health save stays destroyed in survival",body.health==0.0 and body.fuel==100.0 and body.weapon_upgrade==0 and not body.can_crush_buildings())
		body.occupied=true; Input.action_press("boost")
		check(kind+" destroyed boost is disabled",not body.is_boosting())
		Input.action_release("boost")
		check(kind+" partial repair reports actual gain",body.repair(25)==25 and body.health==25.0)
		body.repair()
		check(kind+" full repair remains backwards compatible",body.health==100.0 and body.fuel==100.0)
		body.apply_state({"health":NAN,"fuel":INF,"weapon_upgrade":"invalid","frozen":true,"position":[0,4000,0]})
		check(kind+" corrupt survival numbers recover finite defaults",body.health==100.0 and body.fuel==100.0 and body.weapon_upgrade==0)
		await release(body)
	for kind in ["tank","fighter","hoverboard"]:
		var classic := make(kind,false)
		classic.apply_state({"health":0,"fuel":42,"frozen":true,"position":[0,4000,0]})
		check(kind+" classic fixture immunity is unchanged",classic.health==100.0 and classic.is_damage_immune() and classic.take_combat_damage(1000)==0)
		await release(classic)
		var wreck := make(kind)
		wreck.occupied=true; wreck.health=1.0; wreck.fuel=42.0
		wreck.freeze=false; wreck._was_occupied=true; wreck.linear_velocity=Vector3(0,0,-50)
		wreck.take_combat_damage(100000)
		var altitude: float = wreck.position.y
		Input.action_press("forward"); Input.action_press("rise"); Input.action_press("boost")
		await steps(60)
		check(kind+" destroyed craft falls without freeze or resurrection",wreck.health==0.0 and wreck.fuel==42.0 and not wreck.freeze and wreck.position.y<altitude-3.0 and wreck.linear_velocity.y < -5.0 and absf(wreck.linear_velocity.z)<50.1 and wreck.throttle==0.0,{"velocity":str(wreck.linear_velocity),"drop":altitude-wreck.position.y})
		for action in ACTIONS: Input.action_release(action)
		await release(wreck)
	for kind in ["fighter","airliner","hoverboard"]:
		var empty := make(kind)
		empty.fuel=0.0; empty.occupied=true; empty.freeze=false
		empty.prepare_for_boarding(true)
		Input.action_press("forward"); Input.action_press("boost")
		await steps(6)
		check(kind+" empty fuel cannot trigger boarding launch or boost",not empty._launch_pending and absf(empty.linear_velocity.z)<.1 and not empty.is_boosting() and empty.fuel==0.0)
		for action in ACTIONS: Input.action_release(action)
		await release(empty)
	# Crash a survival hoverboard into a real static wall at 40 m/s. Its old
	# policy helper says immune; the survival contact path must override that.
	var wall := StaticBody3D.new(); wall.position=Vector3(0,4000,-10)
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size=Vector3(20,20,1); shape.shape=box; wall.add_child(shape); stage.add_child(wall)
	var crash := make("hoverboard"); crash.freeze=false; crash._was_occupied=true
	crash.linear_velocity=Vector3(0,0,-40); crash.set_physics_process(false)
	await steps(30)
	check("real survival contact damages formerly immune hoverboard",crash.health<100.0 and not crash.last_impact_info.is_empty(),{"health":crash.health,"impact":crash.last_impact_info})
	await release(crash); await release(wall)
	# Fire actual pooled weapon through layer 16 and check its signal independently
	# of world destruction; this target intentionally has no damage_id.
	var game := CombatFixture.new(); stage.add_child(game)
	var tank := make("tank"); tank.position=Vector3(0,100,0); tank.occupied=true; tank.weapon_upgrade=3
	game.current_vehicle=tank; game.camera=Camera3D.new(); stage.add_child(game.camera)
	game.camera.position=Vector3(0,101,4)
	var weapon := Weapons.new(); stage.add_child(weapon); weapon.setup(game); weapon.set_physics_process(false)
	var hits: Array = []
	weapon.blast_hit.connect(func(point,radius,damage,owner): hits.append({"point":point,"radius":radius,"damage":damage,"owner":owner}))
	var muzzle: Node3D = tank._moving.muzzle
	var enemy := StaticBody3D.new(); enemy.collision_layer=16; enemy.collision_mask=0
	enemy.position=muzzle.global_position-muzzle.global_basis.z*12.0
	var target_shape := CollisionShape3D.new(); var target_box := BoxShape3D.new(); target_box.size=Vector3(10,10,2)
	target_shape.shape=target_box; enemy.add_child(target_shape); stage.add_child(enemy)
	await steps(3)
	var profile: Dictionary = weapon.weapon_profile(tank)
	check("upgrade changes damage and cooldown without mutating base profile",profile.damage==157.5 and is_equal_approx(profile.cooldown,.805) and Weapons.PROFILES.tank.damage==90.0 and Weapons.PROFILES.tank.cooldown==1.15)
	check("healthy tank fires once and respects cooldown",weapon.fire_current() and not weapon.fire_current())
	weapon._physics_process(.05)
	check("layer 16 target produces typed gameplay blast independently",hits.size()==1 and hits[0].owner==tank and hits[0].damage==157.5 and hits[0].radius==16.0 and game.building_blasts==1,{"hits":hits.size()})
	tank.take_combat_damage(100000); weapon._physics_process(2.0)
	check("destroyed tank cannot fire",not weapon.fire_current())
	await release(weapon); await release(tank); await release(enemy); await release(game)
	var passed := checks.all(func(item): return item.passed)
	var file := FileAccess.open("res://../reports/survival-vehicle.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"count":checks.size(),"checks":checks},"\t")); file.close()
	stage.queue_free(); await process_frame; await process_frame
	quit(0 if passed else 1)
