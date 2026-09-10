extends Node
## Explicit --flight-qa validation of the actual airport, harbour and production jet.
## After airport_start the aircraft is controlled exclusively by the normal input actions.
## Camera composition is adjusted for documentation, without moving the aircraft.

var host: Node
var jet: RigidBody3D
var elapsed := 0.0
var active := false
var waypoint := 0
var next_sample := 0.0
var route: Array[Vector3] = []
var route_names := ["departure", "harbour_south", "opera_east", "bridge_north", "downwind", "base", "approach_gate", "final"]
var runway_start := Vector3.ZERO
var runway_forward := Vector3.FORWARD
var runway_right := Vector3.RIGHT
var runway_length := 3900.0
var runway_y := 6.9
var report: Dictionary = {"scope":"Actual delivery scene, airport runway to Sydney harbour and back; inputs only after airport_start","samples":[],"screenshots":[],"stages":[],"passed":false}
var captured: Dictionary = {}
var frame_times: Array[float] = []
var previous_frame_usec: int = 0
var max_altitude := 0.0
var min_health := 100.0
var closest_opera := INF
var closest_bridge := INF
var travelled := 0.0
var previous_position := Vector3.ZERO
var lifted := false
var touched := false
var output_dir := "user://flight-qa"
var movie_path := ""
var movie_fps := 0.0
var manual_render := false
var manual_draw_count := 0
var capture_busy := false
var capture_completed: Dictionary = {}
var focus_name := ""
var focus_started := 0.0
var focus_point := Vector3.ZERO
var bridge_point := Vector3.ZERO
var initial_process_frame := 0
var initial_physics_frame := 0
var smoke_capture := false
var landmark_smoke := false
var documentation_camera_position := Vector3.ZERO

func run() -> void:
	host=get_parent()
	if not host.world._ready_complete:
		push_error("FLIGHT_QA requires the complete assembled world")
		get_tree().quit(1)
		return
	process_priority=1000 # Camera composition and explicit capture draw follow the host's camera update.
	movie_path=Engine.get_write_movie_path()
	manual_render=DisplayServer.get_name()!="headless" and not movie_path.is_empty()
	landmark_smoke=OS.get_cmdline_user_args().has("--flight-qa-landmark-smoke") or OS.get_cmdline_args().has("--flight-qa-landmark-smoke")
	smoke_capture=OS.get_cmdline_user_args().has("--flight-qa-capture-smoke") or OS.get_cmdline_args().has("--flight-qa-capture-smoke")
	if manual_render:
		# Documented render-loop override: MovieWriter still appends once after each process iteration.
		# Calling force_draw here avoids macOS occlusion-dependent automatic draw skipping.
		RenderingServer.render_loop_enabled=false
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true)
		DisplayServer.window_move_to_foreground()
	if not is_instance_valid(host.airport):
		push_error("FLIGHT_QA requires the actual airport node")
		return
	host.qa_running=true
	host.new_world("sandbox","Flight validation",false)
	host.world_id="qa_flight_validation_"+str(Time.get_ticks_usec())
	# New fleet placement queries the physics world. Allow freshly constructed
	# terrain and rigid bodies to synchronize before requesting a runway copy.
	await get_tree().physics_frame
	await get_tree().physics_frame
	host.airport_start()
	jet=host.current_vehicle
	if not is_instance_valid(jet) or jet.kind!="airliner":
		push_error("FLIGHT_QA could not enter the production airliner")
		get_tree().quit(1)
		return
	report.impacts=[]
	jet.impacted.connect(func(_point:Vector3,_energy:float):
		var details:Dictionary=jet.last_impact_info.duplicate(true)
		details.time_s=elapsed
		report.impacts.append(details)
		print("FLIGHT_QA_IMPACT ",JSON.stringify(details))
	)
	runway_start=host.airport.anchors.runway_start
	runway_y=runway_start.y
	runway_forward=Vector3.FORWARD.rotated(Vector3.UP,host.airport.runway_heading)
	runway_right=Vector3.RIGHT.rotated(Vector3.UP,host.airport.runway_heading)
	runway_length=runway_start.distance_to(host.airport.anchors.runway_end)
	var opera:Vector3=host.world.anchors.opera
	var north:Vector3=host.world.anchors.north
	bridge_point=host.world.call("_bridge_pos",251.5,90.0) if host.world.has_method("_bridge_pos") else north+Vector3.UP*75.0
	route=[
		Vector3(host.airport.anchors.airport_departure.x,340,host.airport.anchors.airport_departure.z),
		Vector3(opera.x,440,opera.z+1400),
		Vector3(opera.x+750,440,opera.z-750),
		Vector3(north.x-1000,440,north.z-350),
		at_height(runway_start+runway_right*2200-runway_forward*500,340),
		at_height(runway_start-runway_forward*5500,220),
		at_height(runway_start-runway_forward*3200,180),
		at_height(runway_start+runway_forward*500,runway_y+4.4)]
	report.engine=Engine.get_version_info().string
	report.started_utc=Time.get_datetime_string_from_system(true)
	report.world_ready=host.world._ready_complete
	report.world_structure_components=host.world.structures.size()
	report.map_counts=host.world.map_snapshot.get("counts",{})
	report.custom_venues=[]
	for group in ["city_landmarks","bank_landmarks","quay_landmarks","cyber_landmarks","icc_landmarks"]:
		for record in host.world.get_meta(group,[]):report.custom_venues.append(record.id)
	var args:=OS.get_cmdline_args()
	var fixed_index:=args.find("--fixed-fps")
	report.fixed_simulation_fps=int(args[fixed_index+1]) if fixed_index>=0 and fixed_index+1<args.size() else 0
	# Godot consumes recognized engine switches before exposing command-line args.
	# The validation launcher repeats its pacing in a user argument for the report.
	for user_arg in OS.get_cmdline_user_args():
		if user_arg.begins_with("--qa-fixed-fps="):
			report.fixed_simulation_fps=int(user_arg.get_slice("=",1))
			report.pacing_source="launcher-declared user argument; compare recorded launch command"
	report.rendered = DisplayServer.get_name() != "headless"
	report.capture_mode="movie_writer_fixed_step" if not movie_path.is_empty() else ("headless_physics" if not report.rendered else "native_fixed_step" if report.fixed_simulation_fps>0 else "realtime_rendered")
	report.performance_note="Fixed simulation pacing or MovieWriter capture; wall-clock intervals are not a real-time gameplay benchmark." if not movie_path.is_empty() or report.fixed_simulation_fps>0 else ("Headless physics does not measure rendering performance." if not report.rendered else "Real-time wall-clock process frame intervals, with automatic rendering.")
	report.movie_writer_active=not movie_path.is_empty()
	report.manual_render_each_process=manual_render
	report.movie_path=movie_path
	report.frame_index_note="movie_frame_index is the zero-based global process iteration being drawn; MovieWriter appends that image after process. Validate final encoded frame count independently."
	read_movie_header()
	report.renderer=ProjectSettings.get_setting("rendering/renderer/rendering_method")
	report.gpu=RenderingServer.get_video_adapter_name()
	report.canvas_logical_resolution=[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y]
	report.resolution=[] # Filled from the actual captured Image pixel dimensions.
	report.runway_heading=host.airport.runway_heading
	report.runway_length_m=runway_length
	report.start_position=[jet.global_position.x,jet.global_position.y,jet.global_position.z]
	report.route=[]
	for point in route: report.route.append([point.x,point.y,point.z])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	for i in 45: await get_tree().physics_frame
	previous_position=jet.global_position
	report.parked_speed_mps=jet.linear_velocity.length()
	await capture("01_runway_parked")
	initial_process_frame=Engine.get_process_frames()
	initial_physics_frame=Engine.get_physics_frames()
	report.active_start_frame=initial_process_frame
	report.active_start_physics_frame=initial_physics_frame
	active=true
	print("FLIGHT_QA started from Sydney runway; output=",ProjectSettings.globalize_path(output_dir))

func at_height(point:Vector3,height:float) -> Vector3:
	return Vector3(point.x,height,point.z)

func axis(negative:String,positive:String,value:float) -> void:
	Input.action_release(negative)
	Input.action_release(positive)
	if absf(value)>0.025: Input.action_press(positive if value>0 else negative,clampf(absf(value),0.0,1.0))

func _process(delta:float) -> void:
	var now_usec := Time.get_ticks_usec()
	if active and previous_frame_usec > 0:
		frame_times.append(float(now_usec-previous_frame_usec)/1000.0)
	previous_frame_usec = now_usec
	if manual_render and movie_fps<=0.0 and delta>0.0:
		movie_fps=roundf(1.0/delta)
		report.movie_fps=movie_fps
		report.movie_fps_source="fixed process delta"
	if is_instance_valid(jet) and active and not focus_name.is_empty():
		compose_documentation_camera(delta)
	if manual_render:
		manual_draw_count+=1
		RenderingServer.force_draw(true,delta)

func _physics_process(delta:float) -> void:
	if not active or not is_instance_valid(jet): return
	elapsed+=delta
	var position:Vector3=jet.global_position
	travelled+=position.distance_to(previous_position)
	previous_position=position
	max_altitude=maxf(max_altitude,position.y)
	min_health=minf(min_health,jet.health)
	var opera:Vector3=host.world.anchors.opera
	var bridge:Vector3=bridge_point
	closest_opera=minf(closest_opera,Vector2(position.x-opera.x,position.z-opera.z).length())
	closest_bridge=minf(closest_bridge,Vector2(position.x-bridge.x,position.z-bridge.z).length())
	var progress:float=(position-runway_start).dot(runway_forward)
	var lateral:float=(position-runway_start).dot(runway_right)
	var speed:float=jet.linear_velocity.length()
	if not lifted and position.y>runway_y+8.0 and not jet.grounded:
		lifted=true
		report.takeoff_run_m=progress
		report.liftoff_time_s=elapsed
		capture("02_takeoff")
	var opera_distance:=Vector2(position.x-opera.x,position.z-opera.z).length()
	var bridge_distance:=Vector2(position.x-bridge.x,position.z-bridge.z).length()
	# Current distances, completion timestamps and a serial capture gate prevent stale minima
	# from queuing two different landmarks into the same later rendered frame.
	if waypoint==2 and opera_distance<1400.0 and not captured.has("03_harbour"):
		set_focus("opera",opera+Vector3.UP*38.0)
		if opera_distance<850.0 and elapsed-focus_started>2.0 and not capture_busy:
			capture("03_harbour")
	elif waypoint>=3 and waypoint<=4 and bridge_distance<1350.0 and capture_completed.has("03_harbour") and elapsed-float(capture_completed["03_harbour"])>14.0 and not captured.has("04_bridge"):
		set_focus("bridge",bridge)
		if elapsed-focus_started>2.0 and not capture_busy:
			capture("04_bridge")
	elif not focus_name.is_empty():
		var focus_stage:="03_harbour" if focus_name=="opera" else "04_bridge"
		if capture_completed.has(focus_stage) and elapsed-float(capture_completed[focus_stage])>7.0:
			focus_name=""
	var target:Vector3=route[waypoint]
	var offset:Vector3=target-position
	var distance:=Vector2(offset.x,offset.z).length()
	if waypoint<route.size()-1 and distance<380.0 and position.y>90.0:
		report.stages.append({"name":route_names[waypoint],"elapsed_s":elapsed,"position":[position.x,position.y,position.z],"health":jet.health})
		waypoint+=1
		target=route[waypoint]
		offset=target-position
		print("FLIGHT_QA waypoint=",route_names[waypoint]," t=",snappedf(elapsed,0.1)," health=",jet.health)
		if waypoint==6: capture("05_approach")
	var target_speed:=84.0
	var target_height:=target.y
	if waypoint==7:
		offset=runway_forward*1000.0-runway_right*lateral
		target_speed=72.0
		target_height=runway_y+4.4+maxf(0.0,500.0-progress)*0.042
	var heading:=atan2(-offset.x,-offset.z)
	var heading_error:=wrapf(heading-jet.rotation.y,-PI,PI)
	axis("left","right",-heading_error*2.6)
	if jet.grounded and elapsed<70.0:
		axis("back","forward",1.0)
		axis("fall","rise",1.0 if speed>68.0 else 0.0)
	else:
		axis("back","forward",clampf((target_speed-speed)*0.4,-1.0,1.0))
		var desired_vertical:=clampf((target_height-position.y)*0.055,-7.0,11.0)
		var pitch_command:=clampf(asin(clampf(desired_vertical/maxf(speed,20.0),-0.4,0.4))+(desired_vertical-jet.linear_velocity.y)*0.035+0.015,-0.21,0.21)
		axis("fall","rise",(pitch_command-0.015)/0.22)
	if waypoint==7 and (position.y<runway_y+5.5 or touched):
		axis("back","forward",-1.0)
		Input.action_press("brake")
		axis("fall","rise",0.0)
		if jet.grounded and not touched:
			touched=true
			report.touchdown_progress_m=progress
			report.touchdown_cross_track_m=lateral
			report.touchdown_speed_mps=speed
			capture("06_touchdown")
	host.yaw=lerp_angle(host.yaw,jet.rotation.y,delta*0.8)
	host.pitch=-0.12
	if elapsed>=next_sample:
		next_sample+=10.0
		var row:Dictionary={"time_s":elapsed,"stage":route_names[waypoint],"position":[position.x,position.y,position.z],"speed_mps":speed,"throttle":jet.throttle,"health":jet.health,"fps":Performance.get_monitor(Performance.TIME_FPS),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"engine_process_frame":Engine.get_process_frames(),"engine_physics_frame":Engine.get_physics_frames(),"engine_drawn_frames":Engine.get_frames_drawn(),"manual_draw_count":manual_draw_count,"movie_time_s":float(Engine.get_process_frames())/movie_fps if movie_fps>0 else null}
		report.samples.append(row)
		write_report()
	if landmark_smoke and capture_completed.has("04_bridge"):
		active=false
		report.passed=false
		report.smoke_capture_only=true
		call_deferred("finish","landmark_capture_smoke_only")
	elif smoke_capture and elapsed>=15.0:
		active=false
		report.passed=false
		report.smoke_capture_only=true
		call_deferred("finish","capture_smoke_only")
	elif touched and jet.grounded and speed<0.20:
		active=false
		report.passed=jet.health>95.0 and absf(lateral)<22.5 and progress>0.0 and progress<runway_length and max_altitude>300.0 and closest_opera<1600.0 and closest_bridge<1500.0
		call_deferred("finish","completed")
	elif elapsed>760.0 or position.y< -8.0 or jet.health<=0.0:
		active=false
		report.passed=false
		call_deferred("finish","timeout_or_impact")

func set_focus(landmark_name:String,point:Vector3) -> void:
	if focus_name!=landmark_name:
		focus_name=landmark_name
		focus_started=elapsed
		documentation_camera_position=host.camera.global_position
	focus_point=point

func compose_documentation_camera(delta:float) -> void:
	var aircraft_position:Vector3=jet.global_position
	var toward:=focus_point-aircraft_position
	toward.y=0.0
	if toward.length()<1.0: return
	toward=toward.normalized()
	var side:=toward.cross(Vector3.UP).normalized()
	var desired:Vector3=aircraft_position-toward*155.0+side*85.0+Vector3.UP*90.0
	var camera:Camera3D=host.camera
	documentation_camera_position=documentation_camera_position.lerp(desired,1.0-exp(-delta*4.5))
	camera.global_position=documentation_camera_position
	camera.look_at(aircraft_position.lerp(focus_point,0.44))
	# Reported camera changes are documentation-only; aircraft controls and route are untouched.
	host.yaw=camera.rotation.y

func read_movie_header() -> void:
	if movie_path.is_empty() or not movie_path.to_lower().ends_with(".avi"): return
	var path:=ProjectSettings.globalize_path(movie_path) if movie_path.begins_with("res://") or movie_path.begins_with("user://") else movie_path
	if not path.is_absolute_path(): path=ProjectSettings.globalize_path("res://").path_join(path)
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null: return
	var header:=file.get_buffer(mini(file.get_length(),65536))
	file.close()
	for i in range(maxi(0,header.size()-48)):
		if header[i]==97 and header[i+1]==118 and header[i+2]==105 and header[i+3]==104:
			var frame_microseconds:=header.decode_u32(i+8)
			if frame_microseconds>0:
				movie_fps=roundf(1000000.0/float(frame_microseconds))
				report.movie_fps=movie_fps
				report.movie_fps_source="encoded AVI avih header"
			report.movie_resolution=[header.decode_u32(i+40),header.decode_u32(i+44)]
			return

func capture(stage_name:String) -> void:
	if captured.has(stage_name) or capture_busy: return
	captured[stage_name]=true
	capture_busy=true
	var requested_elapsed:=elapsed
	if DisplayServer.get_name()=="headless":
		report.screenshots.append({"stage":stage_name,"status":"not_rendered_headless","request_time_s":requested_elapsed,"time_s":elapsed,"engine_process_frame":Engine.get_process_frames(),"engine_physics_frame":Engine.get_physics_frames()})
		capture_completed[stage_name]=elapsed
		capture_busy=false
		return
	await RenderingServer.frame_post_draw
	var path:=output_dir.path_join(stage_name+".png")
	var image:=get_viewport().get_texture().get_image()
	var error:=image.save_png(path)
	var pixels:=image.get_size()
	report.resolution=[pixels.x,pixels.y]
	report.screenshot_resolution=[pixels.x,pixels.y]
	read_movie_header()
	var frame_index:=Engine.get_process_frames()
	var row:Dictionary={"stage":stage_name,"path":ProjectSettings.globalize_path(path),"error":error,"request_time_s":requested_elapsed,"time_s":elapsed,"pixel_resolution":[pixels.x,pixels.y],"engine_process_frame":frame_index,"engine_physics_frame":Engine.get_physics_frames(),"engine_drawn_frames":Engine.get_frames_drawn(),"manual_draw_count":manual_draw_count,"movie_frame_index":frame_index if not movie_path.is_empty() else null,"movie_time_s":float(frame_index)/movie_fps if movie_fps>0 else null,"camera_position":[host.camera.global_position.x,host.camera.global_position.y,host.camera.global_position.z],"aircraft_position":[jet.global_position.x,jet.global_position.y,jet.global_position.z]}
	if not focus_name.is_empty():
		row.landmark=focus_name
		row.landmark_in_frustum=host.camera.is_position_in_frustum(focus_point)
		var canvas_point:Vector2=host.camera.unproject_position(focus_point)
		var logical_size:Vector2=get_viewport().get_visible_rect().size
		row.landmark_image_pixel=[canvas_point.x*pixels.x/logical_size.x,canvas_point.y*pixels.y/logical_size.y]
	report.screenshots.append(row)
	capture_completed[stage_name]=elapsed
	capture_busy=false
	write_report()

func write_report() -> void:
	var file:=FileAccess.open(output_dir.path_join("flight-report.json"),FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()

func finish(reason:String) -> void:
	for action in ["forward","back","left","right","rise","fall","brake"]: Input.action_release(action)
	report.reason=reason
	report.elapsed_s=elapsed
	report.travelled_m=travelled
	report.max_altitude_m=max_altitude
	report.minimum_health=min_health
	report.closest_opera_m=closest_opera
	report.closest_bridge_m=closest_bridge
	report.active_process_frames=Engine.get_process_frames()-initial_process_frame
	report.active_physics_frames=Engine.get_physics_frames()-initial_physics_frame
	report.engine_process_frame_at_finish=Engine.get_process_frames()
	report.engine_drawn_frames_at_finish=Engine.get_frames_drawn()
	report.manual_draw_count_at_finish=manual_draw_count
	report.movie_active_duration_from_process_frames_s=float(report.active_process_frames)/movie_fps if movie_fps>0 else null
	report.simulation_to_movie_time_ratio=elapsed/float(report.movie_active_duration_from_process_frames_s) if movie_fps>0 and float(report.movie_active_duration_from_process_frames_s)>0.0 else null
	frame_times.sort()
	if not frame_times.is_empty():
		report.frame_time_median_ms=frame_times[frame_times.size()/2]
		report.frame_time_p95_ms=frame_times[int((frame_times.size()-1)*0.95)]
		report.frame_time_worst_ms=frame_times.back()
	await capture("07_stopped" if report.passed else ("07_diagnostic" if smoke_capture or landmark_smoke else "07_failed"))
	write_report()
	print("FLIGHT_QA_FINISHED ",JSON.stringify({"pass":report.passed,"reason":reason,"seconds":elapsed,"distance_m":travelled,"health":min_health,"report":ProjectSettings.globalize_path(output_dir.path_join("flight-report.json"))}))
	host.notify("机场—海港—返航验证完成" if report.passed else "试飞验证记录了失败，请查看报告",report.passed)
	# MovieWriter's dummy audio driver releases stopped WAV playback on a subsequent mix.
	# Stop before the final drain frames, rather than waiting until SceneTree teardown.
	for audio_class in ["AudioStreamPlayer","AudioStreamPlayer2D","AudioStreamPlayer3D"]:
		for voice in host.find_children("*",audio_class,true,false):
			voice.stop()
			voice.stream=null
	for i in 30: await get_tree().process_frame
	get_tree().quit(0 if report.passed or smoke_capture or landmark_smoke else 1)


func _exit_tree() -> void:
	if manual_render:
		RenderingServer.render_loop_enabled=true
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,false)
