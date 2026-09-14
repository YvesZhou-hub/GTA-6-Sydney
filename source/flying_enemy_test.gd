extends SceneTree
## Production flyers and spawn queries in deterministic Jolt fixtures. No saves,
## rendered window, direct AI ticks or replacement attack implementations.
const Enemy = preload("res://scripts/nailong_enemy.gd")
const Spawn = preload("res://scripts/encounter_spawn.gd")
const VehicleSpawn = preload("res://scripts/vehicle_spawn.gd")

class FixtureGame extends Node3D:
	var player: CharacterBody3D
	var current_vehicle: RigidBody3D
	var camera: Camera3D

var game: FixtureGame
var arena: Node3D
var checks: Array=[]
var frame:=0

func _initialize():call_deferred("run")
func check(title:String,passed:bool,detail:Dictionary={}):
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("FLYING_ENEMY ","PASS " if passed else "FAIL ",title," ",JSON.stringify(detail))
func steps(count:int):
	for index in count:
		await physics_frame
		frame+=1
func solid(at:Vector3,size:Vector3)->StaticBody3D:
	var body:=StaticBody3D.new();body.position=at;body.collision_layer=1
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new()
	shape.size=size;collision.shape=shape;body.add_child(collision);arena.add_child(body)
	return body
func creature(kind:String,at:Vector3,rank:int=1):
	var enemy=Enemy.new();enemy.configure(kind,rank);enemy.position=at;arena.add_child(enemy)
	return enemy
func hull(at:Vector3,size:Vector3)->RigidBody3D:
	var body:=RigidBody3D.new();body.freeze=true;body.collision_layer=4;body.position=at
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new()
	shape.size=size;collision.shape=shape;body.add_child(collision);arena.add_child(body)
	return body
func reset_arena(at:Vector3=Vector3(0,4.5,0),floor_enabled:bool=true):
	game.current_vehicle=null
	for child in arena.get_children():child.queue_free()
	game.player.position=at
	game.camera.position=at+Vector3(0,3,8);game.camera.look_at(at+Vector3.UP)
	await steps(3)
	if floor_enabled:solid(Vector3(0,3.5,0),Vector3(300,2,300))
	await steps(3)
func first_attack(enemy,max_frames:int)->Dictionary:
	var hits:Array=[]
	enemy.attack_requested.connect(func(e,d,r):hits.append({"frame":frame,"damage":d,"range":r,"los":e.has_line_of_sight(),"distance":e.distance_to_target_surface()}))
	var windup_frame:=-1
	var minimum_y:float=enemy.global_position.y
	var max_step:=0.0
	var previous:Vector3=enemy.global_position
	for index in max_frames:
		await steps(1)
		minimum_y=minf(minimum_y,enemy.global_position.y)
		max_step=maxf(max_step,previous.distance_to(enemy.global_position));previous=enemy.global_position
		if windup_frame<0 and enemy.state=="windup":windup_frame=frame
		if not hits.is_empty():break
	return {"hits":hits,"first_windup":windup_frame,"minimum_y":minimum_y,"max_step":max_step,"last":enemy.snapshot()}

func run():
	game=FixtureGame.new();root.add_child(game)
	arena=Node3D.new();game.add_child(arena)
	game.player=CharacterBody3D.new();game.player.collision_layer=1
	var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new()
	capsule.radius=.32;capsule.height=1.76;collision.shape=capsule;collision.position.y=.88
	game.player.add_child(collision);game.add_child(game.player)
	game.camera=Camera3D.new();game.add_child(game.camera)
	check("fixture uses production enemy and Jolt",ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics")

	await reset_arena(Vector3(0,1.0,0),false)
	for kind in ["winglet","stormwing"]:
		var hover=creature(kind,Vector3(20,30,0))
		var initial_wing:float=hover._parts.wings[0].rotation.z
		await steps(90)
		check(kind+" remains physically suspended with no supporting terrain",hover.is_flying() and not hover.is_on_floor() and absf(hover.position.y-30)<.01 and hover.motion_mode==CharacterBody3D.MOTION_MODE_FLOATING,hover.snapshot())
		check(kind+" has animated paired wings on the shared Nailong body",hover._parts.wings.size()==2 and absf(hover._parts.wings[0].rotation.z-initial_wing)>.01 and hover._parts.has("head") and hover.get_meta("enemy_body_scale")==hover.spec.scale)
		hover.queue_free();await steps(2)

	# A real target capsule must not become an avoidance wall at melee distance.
	# Exercise both deterministic steering choices, as instance IDs differ in App.
	for side in [-1.0,1.0]:
		await reset_arena()
		var light=creature("winglet",Vector3(0,17,-34));light._avoid_side=side
		light.set_target(game.player)
		var result:Dictionary=await first_attack(light,900)
		var hits:Array=result.hits
		check("winglet closes and dives toward physical player side "+str(side),result.first_windup>0 and not hits.is_empty() and light.distance_to_target_surface()<=float(light.spec.range),result)
		check("winglet keeps full visible one second warning before valid contact side "+str(side),not hits.is_empty() and (int(hits[0].frame)-int(result.first_windup))>=59 and bool(hits[0].los) and float(hits[0].distance)<=2.8,result)
		check("winglet reaches ground encounter without tunneling or dropping below surface side "+str(side),float(result.minimum_y)>=4.5 and float(result.max_step)<=.22,result)

	await reset_arena()
	var dodge=creature("winglet",Vector3(0,5.7,-2));dodge.set_target(game.player)
	var dodge_hits:Array=[]
	dodge.attack_requested.connect(func(_e,_d,_r):dodge_hits.append(frame))
	for index in 100:
		await steps(1)
		if dodge.state=="windup":break
	check("dive windup is visibly telegraphed before evasion",dodge.state=="windup" and dodge._warning.visible and dodge._label.text.contains("俯冲预警") and dodge_hits.is_empty(),dodge.snapshot())
	game.player.position.x=16
	await steps(65)
	check("moving clear during dive warning cancels the pending hit",dodge_hits.is_empty(),dodge.snapshot())

	await reset_arena(Vector3(0,210,0),false)
	var plane:=hull(Vector3(0,212,0),Vector3(12,4,18));game.current_vehicle=plane
	var heavy=creature("stormwing",Vector3(0,236,-62));heavy.set_target(plane)
	var ranged:Dictionary=await first_attack(heavy,900)
	check("stormwing pursues a real high altitude vehicle without a floor",not ranged.hits.is_empty() and heavy.position.y>200 and not heavy.is_on_floor(),ranged)
	check("stormwing ranged release waits full warning and respects real hull range",not ranged.hits.is_empty() and int(ranged.hits[0].frame)-int(ranged.first_windup)>=95 and bool(ranged.hits[0].los) and float(ranged.hits[0].distance)<=32,ranged)
	check("air pursuit moves continuously within configured speed",float(ranged.max_step)<=.16,ranged)
	# Vertical progress is real pursuit, not a ground-only 'stuck' condition.
	await reset_arena(Vector3(0,165,0),false)
	var climber=creature("winglet",Vector3(0,80,0));climber.set_target(game.player)
	await steps(240)
	check("vertical pursuit climbs without being reported as stuck",climber.position.y>115 and climber.pursuit_status().stuck_seconds<.5,climber.snapshot())

	await reset_arena(Vector3(0,25,0),false)
	var interrupted=creature("stormwing",Vector3(0,30,-24));interrupted.set_target(game.player)
	var interrupted_hits:Array=[]
	interrupted.attack_requested.connect(func(_e,_d,_r):interrupted_hits.append(frame))
	for index in 100:
		await steps(1)
		if interrupted.state=="windup":break
	check("stormwing has visible warning before an obstruction is inserted",interrupted.state=="windup" and interrupted._warning.visible and interrupted._label.text.contains("雷翼蓄力"),interrupted.snapshot())
	solid(Vector3(0,35,-12),Vector3(100,70,2))
	await steps(100)
	check("real wall inserted during air windup cancels release",interrupted_hits.is_empty() and not interrupted.has_line_of_sight(),interrupted.snapshot())

	await reset_arena(Vector3(0,25,0),false)
	var switcher=creature("stormwing",Vector3(0,30,-24));switcher.set_target(game.player)
	var switch_hits:Array=[]
	switcher.attack_requested.connect(func(e,_d,_r):switch_hits.append({"frame":frame,"target":e.target.get_instance_id()}))
	for index in 100:
		await steps(1)
		if switcher.state=="windup":break
	await steps(70)
	var new_target:=hull(Vector3(8,25,0),Vector3(3,2,6))
	switcher.set_target(new_target)
	check("changing to a vehicle cancels inherited air windup immediately",switcher._windup_left==0 and not switcher._warning.visible and switch_hits.is_empty())
	var switched_at:=frame
	await steps(60)
	check("new aerial target receives its own complete warning",switch_hits.is_empty() and switcher.state=="windup",switcher.snapshot())
	await steps(50)
	check("new vehicle hull receives only its own delayed air attack",switch_hits.size()==1 and int(switch_hits[0].target)==new_target.get_instance_id() and int(switch_hits[0].frame)-switched_at>=96,{"hits":switch_hits,"switched_at":switched_at})

	for side in [-1.0,1.0]:
		await reset_arena()
		var wall:=solid(Vector3(0,10,-16),Vector3(9,11,2))
		var bypass=creature("winglet",Vector3(0,14,-34));bypass._avoid_side=side;bypass.set_target(game.player)
		var crossing:Dictionary=await first_attack(bypass,1500)
		check("air avoidance routes around finite solid wall side "+str(side),not crossing.hits.is_empty() and bypass.position.z> -14 and float(crossing.max_step)<=.22,crossing)
		var overlap:=PhysicsShapeQueryParameters3D.new();overlap.shape=bypass._collision.shape
		overlap.transform=bypass._collision.global_transform;overlap.collision_mask=1
		overlap.exclude=[game.player.get_rid()]
		check("air detour finishes outside the solid obstacle side "+str(side),not game.get_world_3d().direct_space_state.intersect_shape(overlap,8).any(func(hit):return hit.collider==wall))

	# Spawn uses actual cast_motion plus whole-body overlap, with no requirement
	# for a ground support below water or aircraft.
	for altitude in [1.0,230.0]:
		await reset_arena(Vector3(0,altitude,0),false)
		for kind in ["winglet","stormwing"]:
			var placed:=Spawn.find(game,kind,0)
			var point:Vector3=placed.position
			check(kind+" safely spawns in open air at altitude "+str(altitude),point!=Vector3.INF and point.y>=altitude+6 and point.distance_to(game.player.position)>=24 and Spawn.clear_body(game,point,kind) and Spawn.air_approach_clear(game,point,game.player.position,kind),placed)
		var no_land:=Spawn.find(game,"roamer",0)
		check("land enemies still reject unsupported water or flight at altitude "+str(altitude),no_land.position==Vector3.INF,no_land)

	await reset_arena(Vector3(0,230,0),false)
	var airliner:=hull(Vector3(0,230,0),Vector3(65,18,70));airliner.rotation.y=PI*.25;game.current_vehicle=airliner
	await steps(2)
	var large_spawn:=Spawn.find(game,"stormwing",0)
	var envelope:AABB=airliner.global_transform*VehicleSpawn.envelope(airliner)
	check("large rotated aircraft reserves complete hull clearance for air spawn",large_spawn.position!=Vector3.INF and not envelope.grow(3).has_point(large_spawn.position) and large_spawn.position.y>=envelope.end.y+4,large_spawn)

	await reset_arena(Vector3(0,6,0),false)
	solid(Vector3(0,3.5,0),Vector3(14,2,14))
	solid(Vector3(0,12.5,0),Vector3(14,2,14))
	solid(Vector3(-6.5,8,0),Vector3(1,9,14));solid(Vector3(6.5,8,0),Vector3(1,9,14))
	solid(Vector3(0,8,-6.5),Vector3(14,9,1));solid(Vector3(0,8,6.5),Vector3(14,9,1))
	await steps(3)
	for kind in ["winglet","stormwing"]:
		var rejected:=Spawn.find(game,kind,0)
		check(kind+" cannot materialize an air attack into a sealed interior",rejected.position==Vector3.INF and int(rejected.candidates)<=144,rejected)
	check("air full body overlap rejects an occupied building volume",not Spawn.clear_body(game,Vector3(0,12,0),"stormwing"))

	await reset_arena()
	var feedback=creature("stormwing",Vector3(0,12,-20),30);feedback.set_target(game.player)
	var events:Array=[];var rewards:Array=[]
	feedback.damaged.connect(func(e,actual,at,remaining):events.append({"actual":actual,"remaining":remaining,"point":at,"already_dead":e.dead});if remaining==0:e.take_damage(500))
	feedback.defeated.connect(func(_e,reward):rewards.append(reward))
	feedback.set_feedback_managed(true);await steps(100)
	check("managed feedback keeps legacy label and health strip hidden through physics",not feedback._label.visible and not feedback._bar.visible and feedback.feedback_anchor().y>feedback.global_position.y+3)
	feedback.set_feedback_managed(false)
	check("unmanaged nearby feedback restores normal label and strip",feedback._label.visible and feedback._bar.visible)
	game.player.position=Vector3(130,4.5,0);feedback.set_feedback_managed(true);feedback.set_feedback_managed(false)
	check("unmanaged feedback does not reveal distant legacy labels",not feedback._label.visible and not feedback._bar.visible)
	var total:float=feedback.health
	var hit_at:Vector3=feedback.global_position+Vector3.UP
	feedback.take_damage(NAN);feedback.take_damage(-1);feedback.take_damage(0)
	check("invalid attacks emit no damage feedback",events.is_empty())
	var first:float=feedback.take_damage(45,hit_at)
	check("nonlethal damaged event carries exact real damage hit location and remaining HP",first==45 and events.size()==1 and events[0].actual==45 and events[0].point==hit_at and is_equal_approx(events[0].remaining,total-45))
	var last:float=feedback.take_damage(100000,hit_at)
	feedback.take_damage(10000)
	check("lethal feedback caps overkill and remains exactly once under reentrant callbacks",events.size()==2 and is_equal_approx(last,total-45) and events[1].actual==last and events[1].remaining==0 and events[1].already_dead and rewards.size()==1 and not feedback._label.visible and not feedback._bar.visible)
	check("level 30 flyer damage rises gently while HP and rewards keep growing",is_equal_approx(feedback.max_health,260*7.42) and is_equal_approx(float(feedback.spec.damage),15*1.84) and int(feedback.spec.reward)==7592,feedback.snapshot())
	for kind in Enemy.TYPES:
		var monotonic:=true;var last_hp:=0.0;var last_damage:=0.0;var last_reward:=0
		for rank in range(1,31):
			var ranked=creature(kind,Vector3(80,20,rank*5),rank)
			monotonic=monotonic and ranked.health>last_hp and ranked.spec.damage>last_damage and ranked.spec.reward>last_reward
			last_hp=ranked.health;last_damage=float(ranked.spec.damage);last_reward=int(ranked.spec.reward)
			ranked.queue_free()
		check(kind+" grows in health damage and reward through every level 1 to 30",monotonic,{"level30_health":last_hp,"level30_damage":last_damage,"level30_reward":last_reward})

	var passed:bool=checks.all(func(c):return c.passed)
	var report:={"passed":passed,"count":checks.size(),"checks":checks,"physics":ProjectSettings.get_setting("physics/3d/physics_engine"),"physics_hz":Engine.physics_ticks_per_second}
	var file:=FileAccess.open("res://../reports/flying-enemies.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	game.queue_free();await process_frame;await process_frame
	quit(0 if passed else 1)
