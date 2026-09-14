extends SceneTree
const Enemy = preload("res://scripts/nailong_enemy.gd")
const Model = preload("res://scripts/nailong_model.gd")
var stage: Node3D
var checks: Array = []

func _initialize(): call_deferred("run")
func check(title: String, passed: bool, detail: Dictionary = {}):
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("NAILONG_ENEMY ","PASS " if passed else "FAIL ",title," ",detail)
func steps(count: int):
	for i in count: await physics_frame
func solid(at: Vector3, size: Vector3) -> StaticBody3D:
	var result := StaticBody3D.new()
	result.position = at
	result.collision_layer = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	result.add_child(col)
	stage.add_child(result)
	return result
func creature(type: String, at: Vector3, level: int = 1):
	var result = Enemy.new()
	result.configure(type,level)
	result.position = at
	stage.add_child(result)
	return result
func goal(at: Vector3) -> Node3D:
	var result := Node3D.new()
	result.position = at
	stage.add_child(result)
	return result

func run():
	stage = Node3D.new()
	root.add_child(stage)
	solid(Vector3(0,-1,0),Vector3(1000,2,1000))
	var specimens: Array = []
	for index in Enemy.TYPES.keys().size():
		var type: String = Enemy.TYPES.keys()[index]
		var instance = creature(type,Vector3(index*9,6,80))
		specimens.append(instance)
		check(type+" config health and collision contract",instance.health==float(Enemy.TYPES[type].hp) and instance.collision_layer==16 and instance.collision_mask==5 and instance.is_in_group("nailong_enemies") and instance.get_meta("enemy"),instance.snapshot())
	await steps(160)
	if "--nailong-preview" in OS.get_cmdline_user_args():
		await preview(specimens)
		return
	var ground_specimens := specimens.filter(func(e):return not e.is_flying())
	check("all five ground archetypes land on physical ground",ground_specimens.size()==5 and ground_specimens.all(func(e): return e.is_on_floor() and absf(e.position.y)<.1))
	check("seven silhouettes reuse shared mesh and material cache",Model.cache_snapshot().types.size()==7 and Model.cache_snapshot().materials<=12,Model.cache_snapshot())
	var twin = creature("roamer",Vector3(-10,0,80))
	check("instances share geometry without sharing mutable health",twin._parts.head.get_child(0).mesh==specimens[0]._parts.head.get_child(0).mesh and twin._parts.root!=specimens[0]._parts.root)
	var invalid = creature("unknown",Vector3(-20,0,80))
	check("unknown type falls back to roamer",invalid.enemy_type=="roamer" and invalid.health==80)
	invalid.queue_free()
	var walker = creature("roamer",Vector3(0,0,0))
	var running = creature("runner",Vector3(20,0,0))
	walker.set_target(goal(Vector3(0,0,-70)))
	running.set_target(goal(Vector3(20,0,-70)))
	await steps(150)
	check("grounded chase advances toward target",walker.position.z < -5 and walker.is_on_floor(),{"position":walker.position})
	check("runner is physically faster than roamer",-running.position.z > -walker.position.z*1.7,{"roamer_distance":-walker.position.z,"runner_distance":-running.position.z})
	walker.queue_free(); running.queue_free()
	var attacker = creature("roamer",Vector3(-40,0,0))
	var victim := goal(Vector3(-40,0,-1.75))
	var attacks: Array = []
	attacker.attack_requested.connect(func(enemy,damage,attack_range): attacks.append({"enemy":enemy.get_instance_id(),"damage":damage,"range":attack_range}))
	await steps(90)
	attacker.set_target(victim)
	await steps(25)
	check("attack has visible windup before any damage request",attacks.is_empty() and attacker.state=="windup" and attacker._warning.visible,attacker.snapshot())
	await steps(35)
	check("completed windup requests one configured attack",attacks.size()==1 and attacks[0].damage==8 and attacks[0].range==2,{"attacks":attacks.size()})
	await steps(60)
	check("cooldown prevents per-frame attacks",attacks.size()==1,{"attacks":attacks.size()})
	await steps(38)
	victim.position.z = -40
	await steps(70)
	check("moving target outside range cancels pending hit",attacks.size()==1,{"attacks":attacks.size()})
	attacker.queue_free()
	var blocked = creature("spitter",Vector3(60,0,0))
	var blocked_target := goal(Vector3(60,0,-12))
	var wall := solid(Vector3(60,4,-5),Vector3(120,8,1))
	var blocked_attacks: Array = []
	blocked.attack_requested.connect(func(_e,_d,_r): blocked_attacks.append(1))
	blocked.set_target(blocked_target)
	await steps(240)
	check("solid wall blocks line of sight and ranged damage",not blocked.has_line_of_sight() and blocked_attacks.is_empty(),blocked.snapshot())
	check("enemy never moves through blocking wall",blocked.position.z > -4.5+.50,{"z":blocked.position.z})
	wall.queue_free()
	await steps(160)
	check("removing obstruction restores ranged attack",blocked.has_line_of_sight() and not blocked_attacks.is_empty(),blocked.snapshot())
	blocked.queue_free()
	# Insert a wall during an already active windup, not only before sensing.
	var interruptible = creature("spitter",Vector3(-90,0,0))
	interruptible.set_target(goal(Vector3(-90,0,-10)))
	var pending_hits: Array = []
	interruptible.attack_requested.connect(func(_e,_d,_r): pending_hits.append(1))
	await steps(55)
	check("ranged windup starts before obstruction",interruptible.state=="windup")
	var inserted := solid(Vector3(-90,4,-5),Vector3(40,8,1))
	await steps(100)
	check("new wall cancels attack at release time",pending_hits.is_empty(),interruptible.snapshot())
	inserted.queue_free(); interruptible.queue_free()
	var doomed = creature("brute",Vector3(110,0,0))
	var rewards: Array = []
	var death_attacks: Array = []
	doomed.defeated.connect(func(enemy,reward): rewards.append(reward); enemy.take_damage(100))
	doomed.attack_requested.connect(func(_e,_d,_r): death_attacks.append(1))
	doomed.set_target(goal(Vector3(110,0,-2.5)))
	await steps(60)
	check("damage returns actual amount without accepting invalid input",doomed.take_damage(-8)==0 and doomed.take_damage(NAN)==0 and doomed.take_damage(25)==25 and doomed.health==335)
	check("health belongs to each enemy instance",specimens[2].health==360)
	check("lethal damage is clamped to remaining health",doomed.take_damage(10000)==335)
	check("death emits reward exactly once even with reentrant damage",doomed.dead and rewards==[480] and doomed.take_damage(100)==0 and doomed.collision_layer==0 and doomed.collision_mask==0)
	check("death hides attack warning health and name immediately",not doomed._warning.visible and not doomed._bar.visible and not doomed._label.visible)
	var dead_id := doomed.get_instance_id()
	await steps(60)
	check("dead enemy expires and never attacks",not is_instance_id_valid(dead_id) and death_attacks.is_empty())
	# Local steering can move around a finite obstacle instead of tunneling.
	var detour = creature("roamer",Vector3(170,0,0))
	detour.set_target(goal(Vector3(170,0,-12)))
	var obstacle := solid(Vector3(170,2,-4),Vector3(3,4,1))
	await steps(450)
	check("local obstacle steering passes finite wall",detour.position.z < -6,{"position":detour.position})
	detour.queue_free(); obstacle.queue_free()
	var abandoned = creature("roamer",Vector3(210,0,0))
	var transient := goal(Vector3(210,0,-3))
	abandoned.set_target(transient)
	await steps(30)
	transient.queue_free()
	await steps(20)
	check("freed target returns to grounded idle safely",abandoned.state=="idle" and abandoned.is_on_floor())
	var large_vehicle := RigidBody3D.new()
	large_vehicle.freeze = true
	large_vehicle.collision_layer = 4
	large_vehicle.position = Vector3(250,1.2,0)
	var hull := CollisionShape3D.new()
	var hull_shape := BoxShape3D.new()
	hull_shape.size = Vector3(8,2.4,20)
	hull.shape = hull_shape
	large_vehicle.add_child(hull)
	stage.add_child(large_vehicle)
	var hull_attacker = creature("roamer",Vector3(250,0,14))
	hull_attacker.set_target(large_vehicle)
	check("large vehicle range uses nearest collision surface",absf(hull_attacker.distance_to_target_surface()-4.0)<.01,{"surface_distance":hull_attacker.distance_to_target_surface()})
	large_vehicle.rotation.y = PI*.5
	check("nearest hull distance respects vehicle rotation",absf(hull_attacker.distance_to_target_surface()-10.0)<.01,{"surface_distance":hull_attacker.distance_to_target_surface()})
	large_vehicle.rotation.y = 0.0
	var hull_hits: Array = []
	hull_attacker.attack_requested.connect(func(_e,_d,_r): hull_hits.append(1))
	await steps(250)
	check("large hull receives real melee after surface approach",not hull_hits.is_empty() and hull_attacker.distance_to_target_surface()<2.0 and hull_attacker.position.distance_to(large_vehicle.position)>10,{"hits":hull_hits.size(),"surface_distance":hull_attacker.distance_to_target_surface(),"center_distance":hull_attacker.position.distance_to(large_vehicle.position)})
	check("enemy attacks hull without entering vehicle collider",hull_attacker.position.z>=10.0+.58,{"z":hull_attacker.position.z})
	for type: String in Enemy.TYPES:
		var last_reward := 0
		var last_health := 0.0
		var last_damage := 0.0
		var monotonic := true
		var speed_fixed := true
		for rank in range(1,11):
			var ranked = creature(type,Vector3(300,0,rank*10),rank)
			monotonic = monotonic and ranked.health>last_health and float(ranked.spec.damage)>last_damage and int(ranked.spec.reward)>last_reward
			speed_fixed = speed_fixed and float(ranked.spec.speed)==float(Enemy.TYPES[type].speed)
			last_reward = int(ranked.spec.reward)
			last_health = ranked.health
			last_damage = float(ranked.spec.damage)
			ranked.queue_free()
		check(type+" level 1 to 10 health damage and reward strictly increase",monotonic,{"max_health":last_health,"max_damage":last_damage,"max_reward":last_reward})
		check(type+" speed remains unchanged across levels",speed_fixed)
	var low = creature("roamer",Vector3(320,0,0),-8)
	var high = creature("roamer",Vector3(330,0,0),10)
	var capped = creature("roamer",Vector3(330,0,20),999)
	var original = Enemy.new()
	original.configure("roamer")
	stage.add_child(original)
	check("missing level remains backward compatible at level one",original.level==1 and original.health==80 and original.spec.damage==8 and original.spec.reward==120)
	check("invalid levels clamp to one and thirty",low.level==1 and capped.level==30)
	check("level thirty extends health and rewards with gentle damage scaling",is_equal_approx(capped.health,593.6) and is_equal_approx(float(capped.spec.damage),14.72) and capped.spec.reward==1752,capped.snapshot())
	check("level ten scaled stats use requested formulas",is_equal_approx(high.health,209.6) and is_equal_approx(float(high.spec.damage),12.32) and high.spec.reward==552,high.snapshot())
	check("overhead label includes level type and integer coins",high._label.text.contains("Lv.10 游荡奶龙") and high._label.text.contains("击败 +552 金币"))
	var encoded: Dictionary = JSON.parse_string(JSON.stringify(high.snapshot()))
	check("snapshot survives JSON with explicit level and reward",int(encoded.level)==10 and int(encoded.reward)==552 and is_equal_approx(float(encoded.max_health),209.6))
	var reconstructed = creature(str(encoded.type),Vector3(340,0,0),int(encoded.get("level",1)))
	check("snapshot level recreates matching rank and stats",reconstructed.level==10 and reconstructed.max_health==high.max_health and reconstructed.spec.reward==high.spec.reward)
	var legacy_record := {"type":"runner"}
	var legacy = creature(str(legacy_record.type),Vector3(350,0,0),int(legacy_record.get("level",1)))
	check("record without level recreates level one",legacy.level==1 and legacy.health==60 and legacy.spec.reward==160)
	var ranked_rewards: Array = []
	high.defeated.connect(func(enemy,reward): ranked_rewards.append(reward); enemy.take_damage(500))
	high.take_damage(1000)
	high.take_damage(1000)
	check("ranked death awards scaled coins once with reentrant damage",ranked_rewards==[552])
	var boss = creature("alpha",Vector3(380,0,0),3)
	var boss_hits: Array = []
	boss.attack_requested.connect(func(_e,d,_r): boss_hits.append(d))
	boss.set_target(goal(Vector3(380,0,-3.5)))
	await steps(100)
	check("boss heavy windup raises both arms with red full range warning",boss.state=="windup" and boss._warning.visible and boss._warning.scale.x>3.6 and boss._parts.arms[0].rotation.x< -1.4 and boss._parts.arms[1].rotation.x< -1.4 and boss._label.text.contains("重击蓄力") and boss_hits.is_empty(),boss.snapshot())
	await steps(45)
	check("boss attack signal carries level scaled damage",boss_hits.size()==1 and is_equal_approx(float(boss_hits[0]),31.36),{"hits":boss_hits})
	var passed: bool = checks.all(func(c): return c.passed)
	var report := {"passed":passed,"count":checks.size(),"checks":checks,"physics":ProjectSettings.get_setting("physics/3d/physics_engine"),"physics_hz":Engine.physics_ticks_per_second}
	var output := FileAccess.open("res://../reports/nailong-enemies.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")); output.close()
	stage.queue_free()
	await process_frame
	await process_frame
	quit(0 if passed else 1)

func preview(specimens: Array):
	root.size = Vector2i(1600,850)
	for index in specimens.size():
		var enemy = specimens[index]
		enemy.set_physics_process(false)
		enemy.position.x = (index-2)*5.0
		enemy.reset_physics_interpolation()
		enemy._model_holder.rotation.y = -.28
		enemy._label.visible = true
		enemy._label.font_size = 40
		enemy._label.pixel_size = .012
		enemy._bar.visible = false
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0,7,58)
	camera.look_at(Vector3(0,2.1,80))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23.5
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-30,0)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	stage.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("183340")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("ccdce8")
	environment.environment.ambient_light_energy = .6
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	stage.add_child(environment)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(150,150)
	ground.mesh = plane
	ground.position = Vector3(18,-.02,80)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("31515c")
	mat.roughness = .85
	ground.material_override = mat
	stage.add_child(ground)
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://../reports/nailong-preview.png")
	print("NAILONG_PREVIEW reports/nailong-preview.png")
	stage.queue_free()
	await process_frame
	quit(0)
