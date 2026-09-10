extends SceneTree
## Full bridge and both approaches driven with normal throttle/steering/brake inputs.
var game
var results: Array=[]
var race_result: Dictionary={}

func _initialize(): call_deferred("run")

func run():
	print("BRIDGE_PHYSICS_BACKEND ",ProjectSettings.get_setting("physics/3d/physics_engine","DEFAULT")," enhanced_internal_edges=",ProjectSettings.get_setting("physics/jolt_physics_3d/simulation/use_enhanced_internal_edge_removal",false))
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.qa_running=true
	game.new_world("sandbox","Bridge drive regression - no save",false)
	var bridge=load("res://scripts/bridge_landmark.gd")
	var points:Array[Vector3]=bridge.drive_route()
	for reverse in [false,true]:
		var route=points.duplicate()
		if reverse: route.reverse()
		await drive(route,reverse)
	var passed=bool(race_result.get("passed",false))
	for result in results:
		if not result.passed: passed=false
	var report={"passed":passed,"scope":"Inputs-only driving after controlled test starting pose; full original game scene and physical vehicle","runs":results,"race":race_result}
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
	car.global_position=route[0]+right*2.15+Vector3.UP*1.0+start_dir*2.0
	car.rotation=Vector3(0,atan2(-start_dir.x,-start_dir.z),0)
	car.linear_velocity=Vector3.ZERO
	car.angular_velocity=Vector3.ZERO
	car.reset_physics_interpolation()
	await physics_frame
	game.enter_vehicle(car)
	var money_before:int=game.life.money
	var earnings_before:int=game.life.lifetime_earnings
	var completions_before:int=game.life.completed_jobs.get("race",0)
	var race_stage=0
	var race_checkpoints:Array=[]
	var race_started=false
	var race_base_reward=0
	var race_state:Dictionary={}
	if not reverse:
		# The production physics loop supplies player context and advances gates.
		# Only start the real job; never tick its context or place at checkpoints.
		var response:String=game.life.start_job("race")
		race_started=game.life.active_job.get("id","")=="race"
		race_base_reward=int(game.life.active_job.get("reward",0))
		# Keep a read-only reference to this job dictionary. Completion replaces
		# life.active_job, leaving the finished elapsed/incidents values readable.
		race_state=game.life.active_job
		print("BRIDGE_RACE_STARTED ",response)
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
		if not reverse and race_started:
			var current_stage:int=int(game.life.active_job.get("stage",race_stage))
			if int(game.life.completed_jobs.get("race",0))==completions_before+1:
				current_stage=game.world.anchors.get("race_route",[]).size()
			if current_stage!=race_stage:
				race_checkpoints.append({"checkpoint":current_stage,"time_s":time,"vehicle_position":[car.global_position.x,car.global_position.y,car.global_position.z]})
				print("BRIDGE_RACE_CHECKPOINT ",current_stage," at ",time,"s")
				race_stage=current_stage
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
	if not reverse:
		var money_delta:int=game.life.money-money_before
		var earnings_delta:int=game.life.lifetime_earnings-earnings_before
		var completions_delta:int=int(game.life.completed_jobs.get("race",0))-completions_before
		var completion_elapsed:float=float(race_state.get("elapsed",0.0))
		var race_incidents:int=int(race_state.get("incidents",0))
		var expected_bonus:int=maxi(0,int((240.0-completion_elapsed)*1.5))
		var paid_bonus:int=money_delta-race_base_reward
		var full_clean_bonus:bool=completion_elapsed>0.0 and race_incidents==0 and impact_log.is_empty() and abs(paid_bonus-expected_bonus)<=1
		var sequential=true
		for i in range(race_checkpoints.size()):
			if int(race_checkpoints[i].checkpoint)!=i+1: sequential=false
		race_result={"passed":race_started and sequential and race_checkpoints.size()==8 and completions_delta==1 and money_delta>race_base_reward and race_base_reward==2000 and full_clean_bonus and int(race_state.get("stage",0))==8 and earnings_delta==money_delta and game.life.active_job.is_empty(),"started":race_started,"expected_checkpoints":8,"observed_checkpoints":race_checkpoints,"completed_count_delta":completions_delta,"base_reward":race_base_reward,"money_delta":money_delta,"time_bonus_paid":paid_bonus,"time_bonus_expected":expected_bonus,"completion_elapsed_s":completion_elapsed,"race_incidents":race_incidents,"full_clean_bonus_paid":full_clean_bonus,"lifetime_earnings_delta":earnings_delta,"completion_text":game.life.status_text,"scope":"Production life job; checkpoints advanced only by main physics context while the real vehicle was driven with ordinary inputs"}
		print("BRIDGE_RACE_COMPLETE ",JSON.stringify(race_result))
	else:
		var no_repeat=game.life.money==money_before and int(game.life.completed_jobs.get("race",0))==completions_before
		race_result["return_drive_does_not_repeat_reward"]=no_repeat
		race_result["passed"]=race_result.get("passed",false) and no_repeat
	results.append({"direction":"north_to_south" if reverse else "south_to_north","passed":done and minimum_health>=99.0,"elapsed_s":time,"minimum_health":minimum_health,"maximum_lateral_error_m":maximum_deviation,"section":section,"end":[car.global_position.x,car.global_position.y,car.global_position.z],"impacts":impact_log})
