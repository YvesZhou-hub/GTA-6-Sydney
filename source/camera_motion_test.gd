extends SceneTree
## Native frame sampling of the production follow camera at deliberately mismatched rates.
var game
var samples: Array = []
var failures: Array = []
var rows: Array = []
var sampling := false
var sample_start := 0
var manual_draws := 0
var probe: Node
var physics_hz := 20
var sample_seconds := 5.0

class EndOfFrameProbe extends Node:
	var runner
	func _process(delta: float): runner.observe_frame(delta)

func _initialize(): call_deferred("run")

func run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--physics-hz="): physics_hz=int(argument.trim_prefix("--physics-hz="))
		if argument.begins_with("--sample-seconds="): sample_seconds=float(argument.trim_prefix("--sample-seconds="))
	if physics_hz<1 or sample_seconds<=1.5:
		push_error("Physics rate must be positive and sample duration must exceed 1.5s warmup")
		quit(1)
		return
	Engine.max_fps=120
	Engine.physics_ticks_per_second=physics_hz
	OS.low_processor_usage_mode=false
	if DisplayServer.get_name()=="headless":
		push_error("Camera interpolation evidence requires actual native frames")
		quit(1)
		return
	# The former harness rendered twice (force_draw plus the automatic loop).
	# One late process callback renders after the production camera has updated.
	RenderingServer.render_loop_enabled=false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if "--compact" in OS.get_cmdline_user_args(): root.size=Vector2i(960,600)
	DisplayServer.window_move_to_foreground()
	game=load("res://main.tscn").instantiate()
	game.qa_running=true
	root.add_child(game)
	game.qa_manual_render=false
	probe=EndOfFrameProbe.new()
	probe.runner=self
	probe.process_priority=2000
	root.add_child(probe)
	await process_frame
	game.new_world("sandbox","Camera regression - no save",false)
	DisplayServer.window_move_to_foreground()
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
	await sample("walk",sample_seconds)
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
	await sample("car",sample_seconds)
	Input.action_release("forward")
	var baseline="--baseline" in OS.get_cmdline_user_args()
	var result={"physics_hz":physics_hz,"sample_seconds_requested":sample_seconds,"warmup_seconds":1.5,"render_cap":120,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"window_size":[root.size.x,root.size.y],"viewport_size":str(root.get_visible_rect().size),"vsync_mode":DisplayServer.window_get_vsync_mode(),"manual_render_each_process":true,"automatic_render_loop":RenderingServer.render_loop_enabled,"route":"complete production world and camera; controlled airport ground path","performance_note":"Real elapsed time, one native GPU frame per late process callback, no fixed-fps. Focus is recorded: a locked or obscured screen cannot prove visible presentation or normal foreground product performance. An explicit reduced physics rate checks interpolation against the actual render cadence, not a performance pass.","interpolation":ProjectSettings.get_setting("physics/common/physics_interpolation",false),"scenarios":samples}
	if not baseline:
		if not result.interpolation: failures.append("physics interpolation disabled")
		for scenario in samples:
			if scenario.frames<100: failures.append(scenario.stage+": insufficient native frames")
			if scenario.actual_fps<physics_hz*1.25: failures.append(scenario.stage+": native render rate does not sufficiently exceed %sHz physics"%physics_hz)
			if scenario.raw_stationary_frames<10 or scenario.raw_stationary_frames<scenario.frames*0.1: failures.append(scenario.stage+": no adequate repeated raw physics positions to prove mismatched rates")
			if scenario.interpolated_stationary_frames>scenario.frames*0.05: failures.append(scenario.stage+": render target still steps at physics rate")
			if scenario.mean_pitch_velocity_jump>0.01: failures.append(scenario.stage+": camera pitch jitter")
			if scenario.camera_distance_m<1 or scenario.actor_distance_m<1: failures.append(scenario.stage+": camera or subject did not move")
	result["failures"]=failures
	var folder=ProjectSettings.globalize_path("res://../reports")
	var label:="camera-motion-%sx%s-physics%s"%[root.size.x,root.size.y,physics_hz]
	var file=FileAccess.open(folder+"/"+label+("-baseline" if baseline else "")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("CAMERA_MOTION ",JSON.stringify(result))
	game.active=false
	quit(0 if failures.is_empty() else 1)

func sample(stage:String,seconds:float):
	var start=Time.get_ticks_usec()
	sample_start=start
	rows=[]
	sampling=true
	while float(Time.get_ticks_usec()-start)/1000000.0<seconds:
		await process_frame
	sampling=false
	var velocities:Array=[]
	var angular:Array=[]
	var intervals:Array=[]
	var draw_times:Array=[]
	var raw_steps=0
	var render_steps=0
	var duplicate_physics_ticks=0
	var focused_frames=0
	for i in range(1,rows.size()):
		var dt:float=rows[i].t-rows[i-1].t
		intervals.append(dt)
		draw_times.append(rows[i].draw_usec/1000.0)
		velocities.append((rows[i].x-rows[i-1].x)/dt)
		angular.append((rows[i].pitch-rows[i-1].pitch)/dt)
		if rows[i].actor.distance_to(rows[i-1].actor)<0.00001: raw_steps+=1
		if rows[i].render.distance_to(rows[i-1].render)<0.00001: render_steps+=1
		if rows[i].physics_tick==rows[i-1].physics_tick: duplicate_physics_ticks+=1
		if rows[i].focused: focused_frames+=1
	var pitch_roughness=0.0
	for i in range(1,angular.size()): pitch_roughness+=absf(angular[i]-angular[i-1])
	var span:float=rows[-1].t-rows[0].t if rows.size()>1 else 0.0
	var evidence:Array=[]
	# Keep the individual raw/render pairs that demonstrate interpolation between ticks.
	for i in range(1,rows.size()):
		if rows[i].physics_tick==rows[i-1].physics_tick and evidence.size()<12:
			evidence.append({"dt":rows[i].t-rows[i-1].t,"tick":rows[i].physics_tick,"raw_previous":vec(rows[i-1].actor),"raw_current":vec(rows[i].actor),"render_previous":vec(rows[i-1].render),"render_current":vec(rows[i].render)})
	samples.append({"stage":stage,"frames":rows.size(),"sample_seconds":span,"actual_fps":(rows.size()-1)/maxf(span,.00001),"mean_force_draw_ms":mean(draw_times),"max_frame_ms":intervals.max()*1000 if not intervals.is_empty() else 0,"focused_frames":focused_frames,"manual_draws":rows[-1].draw-rows[0].draw+1 if not rows.is_empty() else 0,"engine_drawn_frames":rows[-1].engine_draw-rows[0].engine_draw+1 if not rows.is_empty() else 0,"duplicate_physics_ticks":duplicate_physics_ticks,"raw_stationary_frames":raw_steps,"interpolated_stationary_frames":render_steps,"mean_pitch_velocity_jump":pitch_roughness/maxi(1,angular.size()-1),"camera_speed_std":std(velocities),"camera_mean_speed":mean(velocities),"camera_distance_m":rows[-1].camera.distance_to(rows[0].camera) if rows.size()>1 else 0,"actor_distance_m":rows[-1].actor.distance_to(rows[0].actor) if rows.size()>1 else 0,"interpolation_evidence":evidence})
	print("CAMERA_STAGE ",stage," frames=",rows.size()," fps=",samples[-1].actual_fps," raw_repeated=",raw_steps," interpolated_repeated=",render_steps)

func observe_frame(delta:float):
	var before_draw:=Time.get_ticks_usec()
	RenderingServer.force_draw(true,delta)
	var draw_usec:=Time.get_ticks_usec()-before_draw
	manual_draws+=1
	if not sampling:return
	var now:=Time.get_ticks_usec()
	if float(now-sample_start)/1000000.0<=1.5:return
	var body:Node3D=game.current_vehicle if is_instance_valid(game.current_vehicle) else game.player
	rows.append({"t":float(now)/1000000.0,"x":game.camera.global_position.x,"pitch":game.camera.global_rotation.x,"camera":game.camera.global_position,"actor":body.global_position,"render":body.get_global_transform_interpolated().origin,"physics_tick":Engine.get_physics_frames(),"draw":manual_draws,"draw_usec":draw_usec,"engine_draw":Engine.get_frames_drawn(),"focused":DisplayServer.window_is_focused()})

func vec(v:Vector3)->Array:return [v.x,v.y,v.z]

func mean(values:Array) -> float:
	var total=0.0
	for v in values: total+=v
	return total/maxi(1,values.size())

func std(values:Array) -> float:
	var avg=mean(values)
	var total=0.0
	for v in values: total+=(v-avg)*(v-avg)
	return sqrt(total/maxi(1,values.size()))
