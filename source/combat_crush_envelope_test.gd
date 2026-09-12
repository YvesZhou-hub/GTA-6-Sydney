extends SceneTree
## Actual Jolt regressions: authored physical hull, not cached gun/antenna AABB.
const Factory=preload("res://scripts/vehicle_factory.gd")
const Spawn=preload("res://scripts/vehicle_spawn.gd")
const Impact=preload("res://scripts/arcade_impact.gd")
class ContactGame extends Node3D:
	var broken:Array=[]
	func break_combat_contact(_source:RigidBody3D,other:Object,_point:Vector3) -> bool:
		broken.append(str(other.name));return true
	func combat_ram_feedback(_source:RigidBody3D,_point:Vector3,_count:int) -> void:pass
var stage:ContactGame
var checks:Array=[]
var failures:=0
func _initialize():call_deferred("run")
func verify(name:String,ok:bool,evidence:Dictionary={}) -> void:
	checks.append({"name":name,"passed":ok,"evidence":evidence});print("PASS " if ok else "FAIL ",name," ",JSON.stringify(evidence))
	if not ok:failures+=1
func wall(at:Vector3,size:Vector3,id:String) -> void:
	var b:=StaticBody3D.new();b.name=id;b.position=at;b.set_meta("damage_id",id)
	var c:=CollisionShape3D.new();var s:=BoxShape3D.new();s.size=size;c.shape=s;b.add_child(c);stage.add_child(b)
func fixture() -> RigidBody3D:
	if is_instance_valid(stage):stage.queue_free();await process_frame
	stage=ContactGame.new();root.add_child(stage)
	var tank:=Factory.make("tank","tank_ram");tank.freeze=true;tank.position=Vector3(0,2,0);stage.add_child(tank);tank.set_physics_process(false);tank.occupied=true
	# This matches production: spawn envelope is cached before aiming changes.
	Spawn.envelope(tank);tank._moving.turret.rotation.y=PI*.5;tank.linear_velocity=Vector3(0,0,-3)
	await process_frame
	return tank
func physical_bounds(body:Node3D) -> AABB:
	var result:=AABB();var first:=true
	for c in body.get_children():
		if c is CollisionShape3D and not c.disabled:
			var box:AABB=c.transform*c.shape.get_debug_mesh().get_aabb()
			result=box if first else result.merge(box);first=false
	return result
func run() -> void:
	var tank:=await fixture()
	var bounds:=physical_bounds(tank)
	verify("physical hull has no forward barrel collider",bounds.position.z> -3.81 and Spawn.envelope(tank).position.z< -6.4,{"physical_front_z":bounds.position.z,"cached_visual_front_z":Spawn.envelope(tank).position.z})
	wall(Vector3(0,2,-6),Vector3(2,3,.2),"clear_ahead_wall")
	for i in 3:await physics_frame
	var sweep:=Impact.new();sweep.tick(tank,stage,1.0/60.0)
	verify("turning turret sideways does not crush a wall2m ahead of physical hull",stage.broken.is_empty(),{"unexpected_contacts":stage.broken.duplicate(),"physical_gap_m":5.9+float(bounds.position.z),"sweep_motion_m":3.0/60.0*1.25})
	sweep.clear(tank)
	tank=await fixture();wall(Vector3(0,2,-3.94),Vector3(2,3,.2),"actual_front_wall")
	for i in 3:await physics_frame
	sweep=Impact.new();sweep.tick(tank,stage,.05)
	verify("forward sweep still crushes a wall reached by the actual hull",stage.broken.has("actual_front_wall"),{"contacts":stage.broken.duplicate()});sweep.clear(tank)
	tank=await fixture();wall(Vector3(0,4.6,0),Vector3(3,.1,3),"clear_overhead_slab")
	for i in 3:await physics_frame
	sweep=Impact.new();sweep.tick(tank,stage,1.0/60.0)
	verify("antenna visual height does not crush a physically clear overhead slab",stage.broken.is_empty(),{"unexpected_contacts":stage.broken.duplicate(),"physical_top_y":2+physical_bounds(tank).end.y,"slab_bottom_y":4.55});sweep.clear(tank)
	for degrees in [0.0,25.0]:
		tank=await fixture();var incline:=deg_to_rad(degrees);tank.rotation.x=incline;tank.linear_velocity=-tank.global_basis.z*3.0
		var deck:=StaticBody3D.new();deck.name="load_bearing_deck";deck.set_meta("damage_id","bridge/deck/fixture")
		var dc:=CollisionShape3D.new();var ds:=BoxShape3D.new();ds.size=Vector3(20,.2,30);dc.shape=ds;deck.add_child(dc)
		deck.rotation.x=incline;deck.position.y=2.0-(.96+.1)/cos(incline);stage.add_child(deck)
		for i in 3:await physics_frame
		sweep=Impact.new();sweep.tick(tank,stage,1.0/60.0)
		verify("tank preserves a"+str(degrees)+"degree destructible supporting deck",stage.broken.is_empty(),{"unexpected_contacts":stage.broken.duplicate()});sweep.clear(tank)
	var report:={"passed":failures==0,"count":checks.size(),"failures":failures,"checks":checks,"hashes":{}}
	for p in ["res://scripts/arcade_impact.gd","res://scripts/vehicle_spawn.gd","res://scripts/harbor_vehicle.gd","res://scripts/tank_models.gd","res://../source/combat_crush_envelope_test.gd"]:report.hashes[p]=FileAccess.get_sha256(p)
	var directory:=ProjectSettings.globalize_path("res://../reports/tank");DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory+"/crush-envelope-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("COMBAT_CRUSH_ENVELOPE_COMPLETE checks=",checks.size()," failures=",failures)
	stage.queue_free();await process_frame;quit(1 if failures else 0)
