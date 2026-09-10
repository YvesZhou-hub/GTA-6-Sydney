extends SceneTree
## Full bridge and both approaches driven with normal throttle/steering/brake inputs.
var game
var results: Array=[]

func _initialize(): call_deferred("run")

func run():
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.qa_running=true
	game.new_world("sandbox","Bridge drive regression - no save",false)
	var bridge=load("res://scripts/bridge_landmark.gd")
	var points:Array[Vector3]=[bridge.SOUTH_ENTRY,bridge.pos(0),bridge.pos(bridge.SPAN),bridge.NORTH_ENTRY]
	for reverse in [false,true]:
		var route=points.duplicate()
		if reverse: route.reverse()
		await drive(route,reverse)
	var passed=true
	for result in results:
		if not result.passed: passed=false
	var report={"passed":passed,"scope":"Inputs-only driving after controlled test starting pose; full original game scene and physical vehicle","runs":results}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../reports/bridge-drive.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("BRIDGE_DRIVE ",JSON.stringify(report))
	game.active=false
	quit(0 if passed else 1)

func drive(route:Array,reverse:bool):
	var car=game.vehicles[0]
	if is_instance_valid(game.current_vehicle): game.exit_vehicle()
	car.freeze=true
	car.repair()
	var start_dir:Vector3=(route[1]-route[0]).normalized()
	var right:=Vector3(-start_dir.z,0,start_dir.x)
	car.global_position=route[0]+right*2.15+Vector3.UP*1.3+start_dir*2.0
	car.rotation=Vector3(0,atan2(-start_dir.x,-start_dir.z),0)
	car.linear_velocity=Vector3.ZERO
	car.angular_velocity=Vector3.ZERO
	car.reset_physics_interpolation()
	await physics_frame
	game.enter_vehicle(car)
	var section=0
	var time=0.0
	var minimum_health=100.0
	var maximum_deviation=0.0
	var done=false
	var impact_log: Array=[]
	var last_health:float=car.health
	while time<180.0:
		await physics_frame
		time+=1.0/Engine.physics_ticks_per_second
		var a:Vector3=route[section]
		var b:Vector3=route[section+1]
		var d:Vector3=(b-a).normalized()
		var flat_d:=Vector3(d.x,0,d.z).normalized()
		var lateral:=Vector3(-flat_d.z,0,flat_d.x)
		var along:float=(car.global_position-a).dot(d)
		var target:Vector3=a+d*minf(along+16.0,a.distance_to(b))+lateral*2.15
		var toward:Vector3=target-car.global_position
		var wanted:float=atan2(-toward.x,-toward.z)
		var error:float=wrapf(wanted-car.rotation.y,-PI,PI)
		var steering:float=clampf(-error*2.1+car.angular_velocity.y*0.35,-0.75,0.75)
		Input.action_release("left")
		Input.action_release("right")
		Input.action_press("right" if steering>0.0 else "left",absf(steering))
		var distance_to_end:float=Vector2(car.global_position.x-b.x,car.global_position.z-b.z).length()
		var stopping=section==route.size()-2 and distance_to_end<12.0
		var speed:float=car.linear_velocity.length()
		Input.action_release("forward")
		Input.action_release("brake")
		if stopping:
			Input.action_press("brake")
			if speed<0.3:
				done=true
				break
		elif speed<19.0: Input.action_press("forward",clampf((19.0-speed)*0.4,0.0,1.0))
		elif speed>22.0: Input.action_press("brake",0.25)
		if car.health<last_health:
			var event=car.last_impact_info.duplicate(true)
			event["time_s"]=time
			impact_log.append(event)
			print("BRIDGE_CONTACT ",JSON.stringify(event))
		last_health=car.health
		minimum_health=minf(minimum_health,car.health)
		maximum_deviation=maxf(maximum_deviation,absf((car.global_position-a).dot(lateral)-2.15))
		if section<route.size()-2 and along>a.distance_to(b)-6.0: section+=1
		if car.health<99.0 or car.global_position.y<1.0: break
	for action in ["forward","left","right","brake"]: Input.action_release(action)
	results.append({"direction":"north_to_south" if reverse else "south_to_north","passed":done and minimum_health>=99.0,"elapsed_s":time,"minimum_health":minimum_health,"maximum_lateral_error_m":maximum_deviation,"section":section,"end":[car.global_position.x,car.global_position.y,car.global_position.z],"impacts":impact_log})
