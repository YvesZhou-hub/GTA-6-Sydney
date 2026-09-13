extends SceneTree
## Real Opera podium/stair meshes, player capsule, enemy and damage director.
## Both avoidance handednesses must hold an attack position through entry grace.
const Opera = preload("res://scripts/opera_landmark.gd")
const Director = preload("res://scripts/harbor_survival.gd")
const Player = preload("res://scripts/harbor_player.gd")
const Weapons = preload("res://scripts/vehicle_weapons.gd")
const Life = preload("res://scripts/harbor_life.gd")

class PodiumWorld extends "res://scripts/harbor_world.gd":
	func _ready() -> void:
		_make_materials()
		_mat("opera_granite",Color("b5a18b"),.86)
		_mat("opera_edge",Color("d4cbbb"),.72)
		Opera._build_podium(self,Opera.site_basis())

class FixtureGame extends Node3D:
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
	func notify(_message: String, _sound: bool=true) -> void: pass
	func camera_accepts_mouse() -> bool: return true
	func can_fire_weapon() -> bool: return false

var game: FixtureGame
var director: Node3D
var checks: Array=[]
var traces: Array=[]

func _initialize() -> void: call_deferred("run")
func check(title: String, passed: bool, detail: Dictionary={}) -> void:
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("OPERA_ENCOUNTER ","PASS " if passed else "FAIL ",title," ",JSON.stringify(detail))
func steps(count: int) -> void:
	for index in count: await physics_frame
func site(point: Vector3) -> Vector3: return Opera.CENTER+Opera.site_basis()*point
func reset_case() -> void:
	director.reset_mode(true);director.auto_spawn=false
	game.player.reset_health();game.player.position=site(Vector3(0,Opera.PODIUM_HEIGHT,64))
	game.camera.position=game.player.position+Vector3(0,5,8);game.camera.look_at(game.player.position+Vector3.UP)
	await steps(2)

func run() -> void:
	for action in ["fire","forward","back","left","right","rise","fall","brake","boost","drift","sprint","jump"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_release(action)
	game=FixtureGame.new();root.add_child(game)
	game.world=PodiumWorld.new();game.add_child(game.world)
	var ground:=StaticBody3D.new();ground.position=Opera.CENTER-Vector3.UP
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(400,2,400)
	collision.shape=box;ground.add_child(collision);game.world.add_child(ground)
	game.player=Player.new();game.add_child(game.player);game.player.enabled=false
	game.camera=Camera3D.new();game.add_child(game.camera)
	game.life=Life.new();game.add_child(game.life)
	game.weapons=Weapons.new();game.add_child(game.weapons);game.weapons.setup(game);game.weapons.set_physics_process(false)
	director=Director.new();game.add_child(director);director.setup(game)
	check("fixture uses production podium stairs, player collision and Jolt",ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics" and game.world.structures.has("opera/steps/foundation/0") and game.player.get_child(0) is CollisionShape3D)
	for side in [-1.0,1.0]:
		for close in [true,false]:
			await reset_case()
			var suffix:=" side=%s close=%s"%[side,close]
			var enemy=director.spawn_enemy("roamer",site(Vector3(-1.8,11.22,64) if close else Vector3(-21,11.28,58)))
			enemy._avoid_side=side
			var samples: Array=[];var attacks: Array=[];var clock: Array=[0.0]
			enemy.attack_requested.connect(func(e,_damage,_range): attacks.append({"time":clock[0],"distance":e.distance_to_target_surface(),"health":game.player.health,"grace":director.grace}))
			var target_probe:=false;var grace_safe:=true;var first_damage:=-1.0
			var close_lowest:=INF;var stable_distance:=0.0
			for index in 1800:
				clock[0]=float(index+1)/60.0
				await physics_frame
				if director.grace>0.0 and game.player.health<game.player.max_health: grace_safe=false
				if first_damage<0.0 and game.player.health<game.player.max_health: first_damage=clock[0]
				var wanted:Vector3=game.player.position-enemy.position;wanted.y=0.0
				var move_hit:=KinematicCollision3D.new()
				if enemy.test_move(enemy.global_transform,wanted.normalized()*1.1,move_hit) and move_hit.get_collider()==game.player: target_probe=true
				if clock[0]>10.0:
					close_lowest=minf(close_lowest,enemy.position.y)
					stable_distance=maxf(stable_distance,enemy.distance_to_target_surface())
				if index%60==0:samples.append({"seconds":clock[0],"position":enemy.position,"state":enemy.state,"distance":enemy.distance_to_target_surface(),"cooldown":enemy._cooldown,"health":game.player.health})
			check("actual player capsule triggers forward obstruction probe"+suffix,target_probe)
			check("entry grace protects health but expiry leads to natural damage"+suffix,grace_safe and first_damage>=11.9 and first_damage<15.0,{"first_damage_seconds":first_damage,"health_after_30_seconds":game.player.health})
			check("cooldown holds legal melee station above Opera stairs"+suffix,close_lowest>15.6 and stable_distance<=2.0 and enemy.is_on_floor(),{"lowest_after_contact":close_lowest,"furthest_after_contact":stable_distance,"position":enemy.position})
			var damage_attacks: Array=attacks.filter(func(a): return a.grace<=0.0)
			var intervals_safe:=true
			for index in range(1,damage_attacks.size()):
				intervals_safe=intervals_safe and damage_attacks[index].time-damage_attacks[index-1].time>=float(enemy.spec.windup)+float(enemy.spec.cooldown)-.05
			check("repeated attacks retain full telegraph and cooldown"+suffix,damage_attacks.size()>=6 and intervals_safe and game.player.health>0.0,{"post_grace_attacks":damage_attacks.size(),"health":game.player.health})
			traces.append({"side":side,"close":close,"attacks":attacks,"samples":samples})
			game.player.position=site(Vector3(0,Opera.PODIUM_HEIGHT,50))
			var retreat_distance:float=enemy.distance_to_target_surface()
			await steps(180)
			check("moving target releases cooldown station and resumes pursuit"+suffix,enemy.distance_to_target_surface()<retreat_distance-4.0,{"initial":retreat_distance,"after_three_seconds":enemy.distance_to_target_surface()})

	# Insert an actual physical wall during a real windup. Holding melee distance
	# cannot preserve damage when sight is broken, including at the release frame.
	await reset_case();director.grace=0.0
	game.player.position=site(Vector3(0,Opera.PODIUM_HEIGHT,60))
	var attacker=director.spawn_enemy("roamer",site(Vector3(-1.8,Opera.PODIUM_HEIGHT+.02,60)))
	for index in 100:
		await physics_frame
		if attacker.state=="windup": break
	check("wall cancellation begins from a natural close-range windup",attacker.state=="windup")
	var barrier:=StaticBody3D.new();barrier.transform=Transform3D(Opera.site_basis(),site(Vector3(-.9,Opera.PODIUM_HEIGHT+2.0,60)))
	var barrier_collision:=CollisionShape3D.new();var barrier_box:=BoxShape3D.new();barrier_box.size=Vector3(.15,4,20);barrier_collision.shape=barrier_box;barrier.add_child(barrier_collision);game.world.add_child(barrier)
	var health_before:float=game.player.health
	await steps(90)
	check("new wall cancels windup damage without freezing pursuit",is_equal_approx(game.player.health,health_before) and not attacker.has_line_of_sight() and attacker.state=="chase",{"health_before":health_before,"health_after":game.player.health,"state":attacker.state})
	var passed:bool=checks.all(func(c): return c.passed)
	var report={"passed":passed,"count":checks.size(),"checks":checks,"traces":traces,"source_sha256":FileAccess.get_sha256("res://scripts/nailong_enemy.gd"),"physics":ProjectSettings.get_setting("physics/3d/physics_engine")}
	var output:=FileAccess.open("res://../reports/opera-encounter.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"  "));output.close()
	game.queue_free();await process_frame;await process_frame
	quit(0 if passed else 1)
