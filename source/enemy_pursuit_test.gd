extends SceneTree
## Production enemy motion against actual Jolt collision; no city/save mutation.
const Enemy = preload("res://scripts/nailong_enemy.gd")
var stage: Node3D
var checks: Array = []

func _initialize() -> void: call_deferred("run")
func check(title: String, passed: bool, detail: Dictionary = {}) -> void:
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("ENEMY_PURSUIT ","PASS " if passed else "FAIL ",title," ",JSON.stringify(detail))
func steps(count: int) -> void:
	for index in count: await physics_frame
func solid(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position=at; body.collision_layer=1
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new()
	shape.size=size; collision.shape=shape; body.add_child(collision); stage.add_child(body)
	return body
func creature(kind: String, at: Vector3):
	var enemy = Enemy.new(); enemy.configure(kind); enemy.position=at; stage.add_child(enemy)
	return enemy
func goal(at: Vector3) -> Node3D:
	var target := Node3D.new(); target.position=at; stage.add_child(target); return target

func run() -> void:
	stage=Node3D.new(); root.add_child(stage)
	solid(Vector3(0,-1,0),Vector3(1000,2,1000))
	var wall := solid(Vector3(0,4,-8),Vector3(30,8,2))
	var target := goal(Vector3(0,0,-25))
	var enemy = creature("roamer",Vector3.ZERO)
	enemy.set_target(target)
	var most_lateral := 0.0
	var entered_wall := false
	var biggest_step := 0.0
	var hits: Array = []
	enemy.attack_requested.connect(func(e,_d,_r): hits.append(e.has_line_of_sight()))
	for index in 1320:
		var before: Vector3=enemy.global_position
		await physics_frame
		most_lateral=maxf(most_lateral,absf(enemy.position.x))
		biggest_step=maxf(biggest_step,Vector2(enemy.position.x-before.x,enemy.position.z-before.z).length())
		entered_wall=entered_wall or (absf(enemy.position.x)<15.0 and enemy.position.z< -7.0 and enemy.position.z> -9.0)
	check("persistent pursuit routes around a thirty metre facade",enemy.position.z< -20.0 and most_lateral>15.5,{"position":enemy.position,"detour_width":most_lateral})
	check("detour uses bounded physical movement without wall penetration",not entered_wall and biggest_step<.06,{"largest_step":biggest_step,"entered_wall":entered_wall})
	check("facade detour eventually reaches target and attacks with sight",not hits.is_empty() and hits.all(func(clear): return clear),{"hits":hits.size(),"position":enemy.position})
	check("successful pursuit clears stale obstruction and stuck diagnostics",float(enemy.pursuit_status().blocked_seconds)<.1 and float(enemy.pursuit_status().stuck_seconds)<.1,enemy.pursuit_status())
	wall.queue_free(); enemy.queue_free(); target.queue_free(); await steps(2)

	# A corner is approached from its obstructed side, not the easy open end.
	var front := solid(Vector3(80,3,-8),Vector3(20,6,1))
	var side := solid(Vector3(90,3,-14),Vector3(1,6,13))
	var corner = creature("runner",Vector3(80,0,0)); corner._avoid_side=-1.0
	corner.set_target(goal(Vector3(80,0,-29)))
	await steps(840)
	check("pursuit turns a building corner instead of oscillating",corner.position.z< -24 and corner.distance_to_target_surface()<6,{"position":corner.position,"status":corner.pursuit_status()})
	front.queue_free(); side.queue_free(); corner.queue_free(); await steps(2)

	# Finite platform stands alone outside the large fixture's floor.
	solid(Vector3(700,-1,0),Vector3(24,2,24))
	var quay = creature("runner",Vector3(700,0,0)); quay.set_target(goal(Vector3(700,0,-40)))
	var lowest_y := 0.0
	for index in 900:
		await physics_frame
		lowest_y=minf(lowest_y,quay.position.y)
	check("ground pursuer respects quay edge with unreachable offshore target",lowest_y> -.1 and quay.is_on_floor(),{"position":quay.position,"lowest_y":lowest_y})
	check("edge avoidance does not invent an attack across the gap",quay.distance_to_target_surface()>20 and quay.state!="windup",quay.snapshot())
	quay.queue_free(); await steps(2)

	var trapped = creature("roamer",Vector3(160,0,0))
	solid(Vector3(160,2,-1.1),Vector3(4,4,.3))
	solid(Vector3(160,2,1.1),Vector3(4,4,.3))
	solid(Vector3(158.9,2,0),Vector3(.3,4,4))
	solid(Vector3(161.1,2,0),Vector3(.3,4,4))
	trapped.set_target(goal(Vector3(160,0,-30)))
	var trapped_hits: Array=[]; trapped.attack_requested.connect(func(_e,_d,_r): trapped_hits.append(1))
	await steps(420)
	var diagnostic: Dictionary=trapped.pursuit_status()
	check("trapped pursuit exposes real blocked and stationary duration",float(diagnostic.stuck_seconds)>5 and float(diagnostic.blocked_seconds)>6 and float(diagnostic.pursuit_seconds)>6,diagnostic)
	check("unreachable target never receives damage through enclosing walls",trapped_hits.is_empty() and absf(trapped.position.x-160)<.6 and absf(trapped.position.z)<.6,trapped.snapshot())
	trapped.queue_free(); await steps(2)

	var attacker = creature("spitter",Vector3(220,0,0))
	var old_target := goal(Vector3(220,0,-10)); attacker.set_target(old_target)
	var switch_hits: Array=[]; attacker.attack_requested.connect(func(_e,_d,_r): switch_hits.append(1))
	await steps(65)
	check("target switch fixture reaches a real attack windup",attacker.state=="windup" and attacker._windup_left>0)
	var vehicle := RigidBody3D.new(); vehicle.freeze=true; vehicle.collision_layer=4; vehicle.position=Vector3(220,1,-12)
	var hull := CollisionShape3D.new(); var hull_box := BoxShape3D.new(); hull_box.size=Vector3(3,2,5); hull.shape=hull_box; vehicle.add_child(hull); stage.add_child(vehicle)
	attacker.set_target(vehicle)
	check("entering a vehicle clears old windup and warning immediately",attacker._windup_left==0 and not attacker._warning.visible and attacker.state=="idle",attacker.pursuit_status())
	await steps(30)
	check("new target receives its own complete attack telegraph",switch_hits.is_empty() and attacker.state=="windup" and attacker._warning.visible,attacker.snapshot())
	await steps(40)
	check("fresh windup can attack the actual new vehicle hull",switch_hits.size()==1 and attacker.has_line_of_sight(vehicle),{"hits":switch_hits.size()})
	var remaining: float=attacker._cooldown
	attacker.set_target(vehicle)
	check("setting unchanged target is idempotent and retains cooldown",is_equal_approx(attacker._cooldown,remaining) and attacker.target==vehicle)
	attacker.set_target(null); await steps(5)
	check("leaving pursuit clears diagnostic state safely",attacker.state=="idle" and attacker.pursuit_status().pursuit_seconds==0.0 and attacker._windup_left==0,attacker.pursuit_status())
	var passed: bool=checks.all(func(c): return c.passed)
	var report := {"passed":passed,"count":checks.size(),"checks":checks,"physics":ProjectSettings.get_setting("physics/3d/physics_engine"),"physics_hz":Engine.physics_ticks_per_second}
	var output := FileAccess.open("res://../reports/enemy-pursuit.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")); output.close()
	stage.queue_free(); await process_frame; await process_frame
	quit(0 if passed else 1)
