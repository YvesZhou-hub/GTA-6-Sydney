extends Node
## Capture production-scene landmarks for human visual review, never as a geometry test substitute.
const METRO=preload("res://scripts/metro_entrances.gd")
const ICC=preload("res://scripts/icc_landmarks.gd")
var started_usec:=0
func _ready(): call_deferred("run")
func run():
	if started_usec==0:started_usec=Time.get_ticks_usec()
	get_tree().root.size=Vector2i(1440,900)
	var game=get_parent()
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not game.world._ready_complete:
		push_error("LANDMARK_CAPTURE_ABORT: production world did not reach READY; no valid screenshots captured")
		get_tree().quit(1)
		return
	print("LANDMARK_CAPTURE_READY structures=",game.world.structures.size())
	var startup_ms: float=(Time.get_ticks_usec()-started_usec)/1000.0
	var performance_mode: bool="--performance" in OS.get_cmdline_user_args()
	var release_mode: bool="--release-review" in OS.get_cmdline_user_args()
	var final_mode: bool="--release-final" in OS.get_cmdline_user_args()
	var update_mode: bool="--release-v012" in OS.get_cmdline_user_args()
	var release_capture: bool=release_mode or final_mode or update_mode
	var headless:bool=DisplayServer.get_name()=="headless"
	var manual_render: bool=(performance_mode or release_capture) and not headless
	if release_capture and not game.world.has_meta("icc_landmarks"):
		push_error("RELEASE_CAPTURE_ABORT: ICC production integration is absent")
		get_tree().quit(1)
		return
	if manual_render:RenderingServer.render_loop_enabled=false
	game.qa_running=true
	game.set_process(false)
	game.canvas.hide()
	var shots=[
		["bridge",Vector3(680,175,-630),Vector3(32,72,-893)],
		["bridge_road",game.world._bridge_pos(42,56.5,2.15),game.world._bridge_pos(320,56.5,2.15)],
		["north_approach",Vector3(331,8,-1485),Vector3(362,5.0,-1570)],
		["opera",Vector3(677,96,-100),Vector3(423,31,-327)],
		["opera_ground",Vector3(507,8,-184),Vector3(430,33,-317)],
		["opera_aerial",Vector3(450,290,-275),Vector3(423,15,-327)],
		["city_overview",Vector3(900,690,1850),Vector3(-330,75,760)],
		["george_street",Vector3(-329.08,8,1090),Vector3(-329.08,12,980)],
		["manly_overview",Vector3(8050,370,-6500),Vector3(7110,10,-6830)]
	]
	var f:=METRO._frame("barangaroo")
	var mf:=METRO._frame("martin_place")
	shots.append_array([
		["metro_martin_front",Vector3(-45,10,681),Vector3(-15,15,728)],
		["metro_martin_atrium",Vector3(-21,6.4,731.0),mf.b+Vector3.UP*1.7],
		["metro_barangaroo_front",f.a-f.forward*8+f.right*6+Vector3.UP*2.5,f.a+f.forward*6+Vector3.UP*2],
		["metro_barangaroo_stairs",f.a-f.forward+Vector3.UP*1.6,f.b+Vector3.UP*1.3],
		["metro_barangaroo_landing",f.b+f.forward*2.9+Vector3.UP*1.6,f.a+Vector3.UP*2.2]
	])
	if performance_mode:
		shots=[
			["city_overview",Vector3(900,690,1850),Vector3(-330,75,760)],
			["george_street",Vector3(-329.08,8,1090),Vector3(-329.08,12,980)],
			["darling_square",Vector3(-740,10,1957),Vector3(-796,18,2040)]
		]
	if release_mode:
		shots=[
			["bridge",Vector3(680,175,-630),Vector3(32,72,-893)],
			["opera",Vector3(677,96,-100),Vector3(423,31,-327)],
			["city_overview",Vector3(900,690,1850),Vector3(-330,75,760)],
			["george_street",Vector3(-329.08,8,1090),Vector3(-329.08,12,980)],
			["darling_square",Vector3(-740,10,1957),Vector3(-796,18,2040)],
			["icc_group",ICC.point(ICC.EXHIBITION,Vector3(260,180,210)),ICC.EXHIBITION+Vector3.UP*10],
			["theatre_auditorium",ICC.point(ICC.THEATRE,Vector3(-29,4,-17)),ICC.point(ICC.THEATRE,Vector3(19,13,4))],
			["theatre_stage",ICC.point(ICC.THEATRE,Vector3(17,18,-3)),ICC.point(ICC.THEATRE,Vector3(-31,3,0))],
			["road_fairy_bower",Vector3(7423,6.3,-6380),Vector3(7398,13,-6355)],
			["road_darling",Vector3(-602.278991699219,15.25,1983.01904296875),Vector3(-612.278991699219,8.25,1973.01904296875)]
		]
	if final_mode:
		shots=[
			["city_overview",Vector3(900,690,1850),Vector3(-330,75,760)],
			["icc_group",ICC.point(ICC.EXHIBITION,Vector3(260,180,210)),ICC.EXHIBITION+Vector3.UP*10],
			["theatre_auditorium",ICC.point(ICC.THEATRE,Vector3(-29,4,-17)),ICC.point(ICC.THEATRE,Vector3(19,13,4))],
			["theatre_stage",ICC.point(ICC.THEATRE,Vector3(17,18,-3)),ICC.point(ICC.THEATRE,Vector3(-31,3,0))],
			["darling_square_wide",Vector3(-771,36,2081),Vector3(-773,14,2008)]
		]
	if update_mode:
		game.new_world("sandbox","Update visual QA - no save",false)
		game.player.enabled=false
		game.canvas.hide()
		var bridge=load("res://scripts/bridge_landmark.gd")
		var bend:Vector3=bridge.ramp_position("north",0.67)
		shots=[
			["bridge",Vector3(680,175,-630),Vector3(16,72,-859)],
			["bridge-road",game.world._bridge_pos(42,56.5,2.15),game.world._bridge_pos(320,56.5,2.15)],
			["north-approach",bend+Vector3(60,35,55),bend],
			["opera",Vector3(677,96,-100),Vector3(427,31,-321)],
			["opera-ground",Vector3(507,8,-184),Vector3(430,33,-317)]
		]
		for vehicle in game.vehicles:
			vehicle.freeze=true
			var camera_offset:=Vector3(6,3,-8)
			var focus_offset:=Vector3(0,.1,0)
			match vehicle.kind:
				"car":pass
				"motorcycle":camera_offset=Vector3(3.3,1.5,-4.5)
				"speedboat":
					vehicle.global_position=Vector3(340,.9,-850)
					camera_offset=Vector3(13,7,-16);focus_offset=Vector3.UP
				"yacht":
					vehicle.global_position=Vector3(280,.9,-850)
					camera_offset=Vector3(28,15,32);focus_offset=Vector3.UP*3
				"airliner":camera_offset=Vector3(63,24,-71);focus_offset=Vector3.UP*2
				_:continue
			vehicle.reset_physics_interpolation()
			shots.append([vehicle.kind,vehicle.to_global(camera_offset),vehicle.to_global(focus_offset)])
	var folder=ProjectSettings.globalize_path("user://update-v012-views" if update_mode else "res://../reports/release-final" if final_mode else "res://../reports/release-review" if release_mode else "res://../reports/landmark-review")
	if not get_meta("wrapper_startup",false) and not update_mode:
		folder=ProjectSettings.globalize_path("user://"+("release-final" if final_mode else "release-review" if release_mode else "landmark-review"))
	if headless:folder=folder.path_join("headless-validation")
	DirAccess.make_dir_recursive_absolute(folder)
	var evidence: Array[Dictionary]=[]
	var failures:=0
	for shot in shots:
		if not release_capture and "--wall-probes" in OS.get_cmdline_user_args() and shot[0] not in ["city_overview","opera","george_street"]:continue
		if not release_capture and "--metro-only" in OS.get_cmdline_user_args() and not shot[0].begins_with("metro_"):continue
		game.camera.global_position=shot[1]
		game.camera.look_at(shot[2])
		for i in range(2 if headless else 24):
			if manual_render:RenderingServer.force_draw(false)
			await get_tree().process_frame
		var saved:=false
		if not headless:
			RenderingServer.force_draw(false)
			saved=get_tree().root.get_texture().get_image().save_png(folder+"/"+shot[0]+".png")==OK
			if not saved:failures+=1
		var frame: Dictionary={"view":shot[0],"captured_utc":Time.get_datetime_string_from_system(true),"camera":[shot[1].x,shot[1].y,shot[1].z],"target":[shot[2].x,shot[2].y,shot[2].z],"ready":true,"saved":saved,"startup_ms":startup_ms,"headless_view_validation":headless,"startup_scope":"wrapper launch" if get_meta("wrapper_startup",false) else "validator activation after main assembly","draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
		if not headless and (performance_mode or (release_mode and shot[0] in ["city_overview","george_street","darling_square"]) or (final_mode and shot[0]=="city_overview")):
			frame["startup_ms"]=startup_ms
			frame["performance"]=await _sample_static_frames(game)
			print("STATIC_VIEW_PERFORMANCE ",shot[0]," ",JSON.stringify(frame["performance"]))
			if shot[0]=="city_overview" and not release_capture:frame["visual_wall_candidates"]=_visual_candidates(game,Vector2(60,330))
		if shot[0] in ["city_overview","opera","george_street"]:
			frame["ray_probes"]=_probe_pixels(game,shot[0])
		evidence.append(frame)
		print("LANDMARK_FRAME ",shot[0]," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var evidence_name:="capture-evidence.json" if release_capture else "static-performance.json" if performance_mode else "wall-probe-evidence.json" if "--wall-probes" in OS.get_cmdline_user_args() else "metro-capture-evidence.json" if "--metro-only" in OS.get_cmdline_user_args() else "capture-evidence.json"
	FileAccess.open(folder+"/"+evidence_name,FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t"))
	print("LANDMARK_VIEW_VALIDATION_COMPLETE views=" if headless else "LANDMARK_CAPTURE_COMPLETE frames=",evidence.size()," failures=",failures)
	game.active=false
	game.finish_quit(1 if failures else 0)

func _probe_pixels(game: Node3D, label: String) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var xs: Array=[60,160,280,420,580,720,960,1220]
	var ys: Array=[140,260,380,500,640]
	if label=="george_street":xs=[80,360,720,1080,1360];ys=[180,390,620]
	if "--wall-probes" in OS.get_cmdline_user_args():
		if label=="city_overview":xs=[30,60,100,120,160];ys=[290,310,330,350,370]
		if label=="opera":xs=[30,60,100,150,180];ys=[430,450,470,490]
	var space: PhysicsDirectSpaceState3D=game.world.get_world_3d().direct_space_state
	for y in ys:
		for x in xs:
			var pixel:=Vector2(x,y)
			var origin: Vector3=game.camera.project_ray_origin(pixel)
			var ray: Vector3=game.camera.project_ray_normal(pixel)
			var query:=PhysicsRayQueryParameters3D.create(origin,origin+ray*12000)
			query.hit_from_inside=true
			var hit:=space.intersect_ray(query)
			if hit.is_empty():continue
			var collider: Node=hit.collider
			result.append({"pixel":[x,y],"position":[hit.position.x,hit.position.y,hit.position.z],"node":str(collider.get_path()),"damage_id":collider.get_meta("damage_id",""),"osm_id":collider.get_meta("osm_id",""),"height_source":collider.get_meta("height_source","")})
	return result

func _sample_static_frames(game: Node3D) -> Dictionary:
	# Manual draw, after warm-up. Intervals include engine scheduling/physics
	# and manual rendering, without swapping the window buffer. They are not
	# isolated GPU timings, display FPS or moving-gameplay measurements.
	for i in range(24):
		RenderingServer.force_draw(false)
		await get_tree().process_frame
	var intervals: Array[float]=[]
	var draw_calls: Array[float]=[]
	var previous:=Time.get_ticks_usec()
	for i in range(120):
		RenderingServer.force_draw(false)
		await get_tree().process_frame
		var now:=Time.get_ticks_usec()
		intervals.append((now-previous)/1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		previous=now
	var total:=0.0
	for value in intervals:total+=value
	var sorted:=intervals.duplicate();sorted.sort()
	return {"sample":"static production camera; force_draw(false) + process_frame; no window buffer swap; not display FPS or moving gameplay","frames":120,"resolution":[get_tree().root.size.x,get_tree().root.size.y],"median_ms":(sorted[59]+sorted[60])*0.5,"p95_ms":sorted[113],"worst_ms":sorted[119],"mean_ms":total/120.0,"elapsed_ms":total,"draw_calls_last":draw_calls[119],"frame_intervals_ms":intervals}

func _visual_candidates(game: Node3D, pixel: Vector2) -> Array[Dictionary]:
	var origin: Vector3=game.camera.project_ray_origin(pixel)
	var ray: Vector3=game.camera.project_ray_normal(pixel)
	var candidates: Array[Dictionary]=[]
	for view in game.find_children("*","VisualInstance3D",true,false):
		if not view is MeshInstance3D and not view is MultiMeshInstance3D:continue
		if not view.is_visible_in_tree():continue
		var inverse: Transform3D=view.global_transform.affine_inverse()
		var bounds: AABB=view.get_aabb()
		var hit: Variant=bounds.intersects_segment(inverse*origin,inverse*(origin+ray*12000))
		if hit==null:continue
		var global_hit: Vector3=view.global_transform*hit
		candidates.append({"node":str(view.get_path()),"class":view.get_class(),"distance":origin.distance_to(global_hit),"bounds_position":[bounds.position.x,bounds.position.y,bounds.position.z],"bounds_size":[bounds.size.x,bounds.size.y,bounds.size.z],"world_position":[view.global_position.x,view.global_position.y,view.global_position.z]})
	candidates.sort_custom(func(a,b):return a.distance<b.distance)
	if candidates.size()>24:candidates.resize(24)
	return candidates
