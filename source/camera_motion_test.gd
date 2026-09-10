extends SceneTree
## Native frame sampling of the production follow camera at deliberately mismatched rates.
var game
var samples: Array = []
var failures: Array = []

func _initialize(): call_deferred("run")

func run():
	Engine.max_fps=120
	Engine.physics_ticks_per_second=20
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.qa_running=true
	game.new_world("sandbox","Camera regression - no save",false)
	var runway: Dictionary=game.airport.runway_data[0]
	var start: Vector3=runway.a.lerp(runway.b,0.45)
	# The old city test rectangle became an actual mapped building. Keep a
	# controlled, unobstructed ground path on the airport runway for this test.
	game.player.global_position=start+Vector3.UP*0.4
	game.player.reset_physics_interpolation()
	game.yaw=game.airport.runway_heading
	game.pitch=-0.15
	if game.has_method("reset_follow_camera"): game.reset_follow_camera()
	Input.action_press("forward")
	Input.action_press("sprint")
	await sample("walk",5.0)
	Input.action_release("forward")
	Input.action_release("sprint")
	var car=game.vehicles[0]
	car.freeze=true
	car.global_position=runway.a.lerp(runway.b,0.50)+Vector3.UP*1.4
	car.rotation=Vector3(0,game.airport.runway_heading,0)
	car.linear_velocity=Vector3.ZERO
	car.angular_velocity=Vector3.ZERO
	car.reset_physics_interpolation()
	await physics_frame
	game.enter_vehicle(car)
	Input.action_press("forward")
	await sample("car",5.0)
	Input.action_release("forward")
	var baseline="--baseline" in OS.get_cmdline_user_args()
	var result={"physics_hz":20,"render_cap":120,"route":"controlled airport ground path; old before/after pair used pre-city open ground","interpolation":ProjectSettings.get_setting("physics/common/physics_interpolation",false),"scenarios":samples}
	if not baseline:
		if not result.interpolation: failures.append("physics interpolation disabled")
		for scenario in samples:
			if scenario.frames<100: failures.append(scenario.stage+": insufficient native frames")
			if scenario.interpolated_stationary_frames>scenario.frames*0.05: failures.append(scenario.stage+": render target still steps at physics rate")
			if scenario.mean_pitch_velocity_jump>0.01: failures.append(scenario.stage+": camera pitch jitter")
	result["failures"]=failures
	var folder=ProjectSettings.globalize_path("res://../reports")
	var file=FileAccess.open(folder+"/camera-"+("city-before" if baseline else "city-final")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("CAMERA_MOTION ",JSON.stringify(result))
	game.active=false
	quit(0 if failures.is_empty() else 1)

func sample(stage:String,seconds:float):
	var start=Time.get_ticks_usec()
	var previous=0
	var rows:Array=[]
	while float(Time.get_ticks_usec()-start)/1000000.0<seconds:
		await process_frame
		RenderingServer.force_draw(false)
		var now=Time.get_ticks_usec()
		var body:Node3D=game.current_vehicle if is_instance_valid(game.current_vehicle) else game.player
		var elapsed=float(now-start)/1000000.0
		if elapsed>1.5:
			rows.append({"t":float(now)/1000000.0,"x":game.camera.global_position.x,"pitch":game.camera.global_rotation.x,"actor_x":body.global_position.x,"render_x":body.get_global_transform_interpolated().origin.x})
		previous=now
	var velocities:Array=[]
	var angular:Array=[]
	var raw_steps=0
	var render_steps=0
	for i in range(1,rows.size()):
		var dt:float=rows[i].t-rows[i-1].t
		velocities.append((rows[i].x-rows[i-1].x)/dt)
		angular.append((rows[i].pitch-rows[i-1].pitch)/dt)
		if absf(rows[i].actor_x-rows[i-1].actor_x)<0.00001: raw_steps+=1
		if absf(rows[i].render_x-rows[i-1].render_x)<0.00001: render_steps+=1
	var pitch_roughness=0.0
	for i in range(1,angular.size()): pitch_roughness+=absf(angular[i]-angular[i-1])
	samples.append({"stage":stage,"frames":rows.size(),"raw_stationary_frames":raw_steps,"interpolated_stationary_frames":render_steps,"mean_pitch_velocity_jump":pitch_roughness/maxi(1,angular.size()-1),"camera_speed_std":std(velocities),"camera_mean_speed":mean(velocities)})

func mean(values:Array) -> float:
	var total=0.0
	for v in values: total+=v
	return total/maxi(1,values.size())

func std(values:Array) -> float:
	var avg=mean(values)
	var total=0.0
	for v in values: total+=(v-avg)*(v-avg)
	return sqrt(total/maxi(1,values.size()))
