extends SceneTree
## Real Jolt motion, production HarborVehicle + shared main damage callbacks.
class TestGame extends "res://scripts/main.gd":
	var ram_events:=0
	func _ready(): setup_input()
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func combat_ram_feedback(_source:RigidBody3D,_point:Vector3,_count:int): ram_events+=1
class TestWorld extends "res://scripts/harbor_world.gd":
	func _ready():
		_make_materials()
		_ready_complete=true
var checks:Array=[]
var failures:=0
var game:Node3D
func _initialize(): call_deferred("run")
func verify(title:String,passed:bool,evidence:Dictionary={}):
	checks.append({"name":title,"passed":passed,"evidence":evidence})
	print("PASS " if passed else "FAIL ",title," ",JSON.stringify(evidence))
	if not passed: failures+=1
func frames(count:int):
	for i in count: await physics_frame
func reset():
	if is_instance_valid(game): game.queue_free(); await process_frame
	game=TestGame.new();root.add_child(game)
	game.world=TestWorld.new();game.add_child(game.world)
	var ground:=StaticBody3D.new();var col:=CollisionShape3D.new();var shape:=BoxShape3D.new()
	shape.size=Vector3(2000,2,2000);col.shape=shape;ground.position.y=-1
	ground.add_child(col);game.add_child(ground)
	await frames(2)
func vehicle(kind:String,at:Vector3,velocity:Vector3) -> RigidBody3D:
	var body=load("res://scripts/harbor_vehicle.gd").new()
	body.configure(kind,"crush_"+kind);body.combat_owner=game
	game.add_child(body);body.global_position=at
	body.apply_state({"position":[at.x,at.y,at.z],"velocity":[velocity.x,velocity.y,velocity.z],"throttle":1.0})
	body.occupied=true;game.current_vehicle=body
	return body
func run():
	Engine.max_fps=0
	await reset()
	game.world._structure_box("test/tank_wall",Vector3(0,2.5,-13),Vector3(7,5,.02),"concrete",1e30)
	await frames(2)
	var tank:=vehicle("tank",Vector3(0,1,0),Vector3(0,0,-20))
	Input.action_press("forward")
	await frames(50)
	Input.action_release("forward")
	verify("tank crushes extremely strong wall through actual swept contact",game.world.destroyed.has("test/tank_wall"),{"position":str(tank.position),"hits":tank._arcade_impact.hits})
	verify("tank physically traverses wall without losing health",tank.position.z< -14 and tank.health==100 and tank.fuel==100,{"position":str(tank.position),"health":tank.health})
	verify("tank retains ground contact and collision mask",tank.position.y>.85 and tank.position.y<1.4 and tank.collision_mask==15,{"height":tank.position.y})
	var saved:Dictionary=game.world.get_state()
	tank.occupied=false;tank.freeze=true;tank.position=Vector3(50,1,50)
	game.world.repair_all();await frames(2)
	verify("repair restores the destroyed wall collider",not game.world.destroyed.has("test/tank_wall") and not game.world.structures["test/tank_wall"].node.get_child(1).disabled)
	game.world.apply_state(saved);await frames(2)
	verify("world save reload restores actual destroyed mesh and collider",game.world.destroyed.has("test/tank_wall") and not game.world.structures["test/tank_wall"].node.visible and game.world.structures["test/tank_wall"].node.get_child(1).disabled)
	await reset()
	game.world._structure_box("test/wing_only_wall",Vector3(6,25,-18),Vector3(.3,8,.02),"concrete",1e30)
	game.world._structure_box("test/second_wall",Vector3(0,25,-27),Vector3(15,8,.02),"concrete",1e30)
	await frames(2)
	var fighter:=vehicle("fighter",Vector3(0,25,0),Vector3(0,0,-555.5556))
	await frames(7)
	verify("2000 km/h sweep destroys thin wall struck by wing outside centre ray",game.world.destroyed.has("test/wing_only_wall"),{"hits":fighter._arcade_impact.hits})
	verify("same high speed traversal hits subsequent thin wall",game.world.destroyed.has("test/second_wall") and fighter.position.z< -40,{"position":str(fighter.position),"speed_kmh":fighter.linear_velocity.length()*3.6})
	verify("fighter remains physical and invincible after building traversal",fighter.health==100 and fighter.fuel==100 and fighter.collision_mask==15 and fighter.linear_velocity.length()>500)
	await frames(3)
	verify("temporary exceptions clear after deferred collision removal",fighter.get_collision_exceptions().is_empty(),{"count":fighter.get_collision_exceptions().size()})
	await reset()
	game.world._structure_box("test/overlap",Vector3(1.5,25,-2),Vector3(.2,2,.02),"concrete",1e30)
	await frames(2)
	var overlap:=vehicle("fighter",Vector3(0,25,0),Vector3(0,0,-140))
	await frames(3)
	verify("initial shape overlap is handled before cast_motion",game.world.destroyed.has("test/overlap"),{"hits":overlap._arcade_impact.hits})
	game.queue_free();await process_frame
	DirAccess.make_dir_recursive_absolute("res://../reports/combat-crush")
	FileAccess.open("res://../reports/combat-crush/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures==0,"checks":checks},"\t"))
	print("COMBAT_CRUSH_COMPLETE ",checks.size()," passed=",failures==0)
	quit(failures)
