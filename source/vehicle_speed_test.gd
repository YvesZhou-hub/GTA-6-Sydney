extends SceneTree
## Real input acceleration from rest; no velocity/transform writes after activation.
const Vehicle=preload("res://scripts/harbor_vehicle.gd")
var scene:Node3D
var results:=[]
var failure:=0
func _init():call_deferred("run")
func check(label:String,pass_value:bool,metrics:Dictionary):
	results.append({"name":label,"pass":pass_value,"metrics":metrics})
	print(("PASS " if pass_value else "FAIL ")+label+" "+JSON.stringify(metrics))
	if not pass_value:failure+=1
func frames(count:int):
	for i in count:await physics_frame
func clear_input():
	for action in ["forward","back","left","right","rise","fall","brake"]:Input.action_release(action)
func run():
	for action in ["forward","back","left","right","rise","fall","brake"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	for kind in ["car","motorcycle","helicopter","airliner"]:
		scene=Node3D.new();root.add_child(scene)
		var ground:=StaticBody3D.new();scene.add_child(ground)
		ground.position.y=-1
		var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(10000,2,90000);collision.shape=shape;ground.add_child(collision)
		var body:=Vehicle.new();body.configure(kind,"top_speed_"+kind);body.position=Vector3(0,4.36 if kind=="airliner" else 1.50 if kind=="helicopter" else .76,0);scene.add_child(body)
		await frames(120)
		check(kind+" begins at rest",body.linear_velocity.length()<.5,{"speed_mps":body.linear_velocity.length(),"height":body.position.y})
		body.occupied=true
		if kind=="helicopter":
			Input.action_press("rise")
			await frames(1200)
			Input.action_release("rise")
		Input.action_press("forward")
		var duration:=180 if kind=="airliner" else 60
		var max_speed:=0.0
		var max_roll:=0.0
		var minimum_height:=INF
		for i in duration*60:
			await physics_frame
			max_speed=maxf(max_speed,body.linear_velocity.length()*3.6)
			max_roll=maxf(max_roll,absf(body.rotation.z))
			minimum_height=minf(minimum_height,body.position.y)
			if i%1800==1799:print("SPEED_SAMPLE ",kind," ",JSON.stringify({"seconds":(i+1)/60.,"kmh":body.linear_velocity.length()*3.6,"height":body.position.y,"throttle":body.throttle,"health":body.health}))
		var cruise:=body.linear_velocity.length()*3.6
		var required:float=Vehicle.TOP_SPEED_KMH[kind]
		check(kind+" reaches requested speed through engine forces",cruise>=required*.99 and cruise<=required*1.015 and body.health>99.9 and max_roll<.15,{"required_kmh":required,"actual_kmh":cruise,"maximum_kmh":max_speed,"seconds":duration,"travel_m":-body.position.z,"height_m":body.position.y,"health":body.health,"max_roll":max_roll})
		var before_turn:=body.rotation.y
		Input.action_press("right",.5)
		await frames(600)
		Input.action_release("right")
		check(kind+" steering is stable at top speed",absf(wrapf(body.rotation.y-before_turn,-PI,PI))>.15 and body.health>99.9 and absf(body.rotation.z)<.65 and body.linear_velocity.is_finite(),{"turn_rad":absf(wrapf(body.rotation.y-before_turn,-PI,PI)),"roll":body.rotation.z,"speed_kmh":body.linear_velocity.length()*3.6,"health":body.health,"height":body.position.y})
		clear_input()
		if kind=="airliner":Input.action_press("back")
		if kind!="helicopter":Input.action_press("brake")
		await frames(900)
		var stop_limit:=required*.55 if kind=="airliner" else 2.0
		check(kind+" controlled braking after top speed",body.linear_velocity.length()*3.6<stop_limit and body.health>99.9,{"speed_kmh":body.linear_velocity.length()*3.6,"limit_kmh":stop_limit,"height":body.position.y,"health":body.health})
		clear_input();scene.queue_free();await process_frame
	var report={"engine":Engine.get_version_info().string,"backend":ProjectSettings.get_setting("physics/3d/physics_engine"),"physics_hz":Engine.physics_ticks_per_second,"scope":"Actual production vehicles, flat deterministic test surface, no velocity or position writes after initial placement; not real-world certified maximum speeds","checks":results,"failures":failure}
	var file:=FileAccess.open("res://../reports/vehicle-speed.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	quit(failure)
