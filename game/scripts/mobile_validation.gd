extends Node
## Production-city integration via injected touch events. This is not a physical
## physical input, sustained frame-rate, memory-pressure or thermal certification.
const Profile = preload("res://scripts/mobile_profile.gd")
const SOURCES := ["main","mobile_profile","mobile_controls","mobile_ui","mobile_validation","game_settings","harbor_map","facade_stream","daylight_environment","vehicle_weapons","character_visual","harbor_survival"]
const REPORT_ROOT := "user://qa/mobile-integration"
var game: Node
var checks: Array[Dictionary] = []
var screenshots: Array[Dictionary] = []
var native := false
var native_ios := false
var keep_open := false
var output_dir := ""
var saves_before: Dictionary = {}
var touch_events := 0
var map_touch_events := 0
var map_mouse_events := 0
var _started := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func check(title: String, passed: bool, detail: Dictionary = {}) -> void:
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("MOBILE_QA ","PASS " if passed else "FAIL ",title," ",JSON.stringify(detail))

func frames(count: int = 3) -> void:
	for index in count: await get_tree().process_frame

func physics_frames(count: int) -> void:
	for index in count: await get_tree().physics_frame

func vector(point: Vector3) -> Array:
	return [point.x,point.y,point.z]

func rect_data(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

static func instantaneous_performance() -> Dictionary:
	return {"fps":Performance.get_monitor(Performance.TIME_FPS),
		"static_memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)) if OS.is_debug_build() else null,
		"static_memory_available":OS.is_debug_build(),
		"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects":int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"primitives":int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"snapshot_only":true,
		"scope":"Single final-frame monitor snapshot, not sustained FPS. Static memory is Godot's tracked allocation counter, not total process or GPU memory. Headless render counters do not measure a GPU."}

func saved_files() -> Dictionary:
	var result := {}
	if DirAccess.dir_exists_absolute("user://worlds"):
		for filename: String in DirAccess.get_files_at("user://worlds"):
			result["worlds/"+filename] = FileAccess.get_sha256("user://worlds/"+filename)
	for filename in ["settings.json","settings_mobile.json"]:
		if FileAccess.file_exists("user://"+filename):
			result[filename] = FileAccess.get_sha256("user://"+filename)
	return result

## Input performs its normal touch-to-mouse emulation for GUI. Gameplay touches
## are claimed by MobileControls before an emulated mouse can fire a second shot.
func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = get_viewport().get_final_transform() * point
	event.pressed = pressed
	Input.parse_input_event(event)
	touch_events += 1

func drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = get_viewport().get_final_transform() * point
	event.relative = get_viewport().get_final_transform().basis_xform(relative)
	Input.parse_input_event(event)
	touch_events += 1

func tap_at(point: Vector2, index: int = 0) -> void:
	touch(index,point,true)
	await frames(1)
	touch(index,point,false)
	await frames(3)

func tap_control(action: String, index: int = 0) -> void:
	var button: Dictionary = game.mobile_controls._buttons.get(action,{})
	if button.is_empty():
		check("touch control exists: "+action,false)
		return
	await tap_at(button.rect.get_center(),index)

func first_button(fragment: String) -> Button:
	for child in game.modal_content.get_children():
		if child is Button and fragment in child.text: return child
	return null

func capture(title: String) -> void:
	if not native: return
	await frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path := output_dir.path_join(title+".png")
	var saved := image.save_png(path)==OK
	screenshots.append({"name":title,"path":path,"saved":saved,"sha256":FileAccess.get_sha256(path) if saved else "","resolution":[image.get_width(),image.get_height()],"profile":Profile.status(game)})
	check("native screenshot: "+title,saved)

func modal_fits(label: String) -> void:
	var safe: Rect2 = game.mobile_controls.safe_area_rect()
	var modal: Rect2 = game.modal.get_global_rect()
	check(label,safe.grow(1).encloses(modal),{"safe":rect_data(safe),"modal":rect_data(modal)})

func check_held_weapon(label: String) -> void:
	var gun: Node3D = game.survival._gun
	if not is_instance_valid(gun):
		check(label,false,{"reason":"held weapon missing"})
		return
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in gun.find_children("*","MeshInstance3D",true,false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var hand: Node3D = gun.get_parent()
	var hand_distance := gun.global_position.distance_to(hand.global_position)
	check(label,not first and gun.is_visible_in_tree() and bounds.size.is_finite()
		and bounds.size.length()>0.4 and bounds.size.length()<1.35
		and gun.global_basis.get_scale().distance_to(Vector3.ONE)<0.01 and hand_distance<0.3,
		{"world_size_metres":vector(bounds.size),"distance_from_hand_metres":hand_distance})

## Optional native image review around the reported oversized hand-weapon bug.
## Uses the real follow camera, character animation and input path, without saves.
func capture_held_weapon_route() -> void:
	var original_yaw: float = game.yaw
	for angle in [0,45,90,135,180,225,270,315]:
		game.yaw = deg_to_rad(float(angle))
		game.reset_follow_camera()
		await frames(8)
		check_held_weapon("held weapon scale while looking %03d"%angle)
		await capture("visual-orbit-%03d"%angle)
	# Face out into the open forecourt instead of continuing into the home wall.
	game.yaw = PI
	game.reset_follow_camera()
	var stick: Vector2 = game.mobile_controls._stick_center
	var forward: Vector2 = stick-Vector2(0,game.mobile_controls._stick_radius*.9)
	touch(0,stick,true)
	drag(0,forward,forward-stick)
	var walk_from: Vector3 = game.player.global_position
	await physics_frames(12)
	var walk_speed: float = Vector2(game.player.velocity.x,game.player.velocity.z).length()
	check("visual route actually walks",game.player.global_position.distance_to(walk_from)>0.1 and walk_speed>1.0)
	check_held_weapon("held weapon scale while walking")
	await capture("visual-walking")
	touch(1,game.mobile_controls._buttons.boost.rect.get_center(),true)
	var sprint_from: Vector3 = game.player.global_position
	await physics_frames(12)
	var sprint_speed: float = Vector2(game.player.velocity.x,game.player.velocity.z).length()
	check("visual route actually sprints",Input.is_action_pressed("sprint") and game.player.global_position.distance_to(sprint_from)>0.1 and sprint_speed>walk_speed)
	check_held_weapon("held weapon scale while sprinting")
	await capture("visual-sprinting")
	touch(1,game.mobile_controls._buttons.boost.rect.get_center(),false)
	touch(0,forward,false)
	await frames(3)
	touch(2,game.mobile_controls._buttons.fire.rect.get_center(),true)
	var saw_shot := false
	for sample in 12:
		await frames(1)
		for beam: Dictionary in game.survival._beams:
			saw_shot = saw_shot or (beam.time>0.0 and beam.view.is_visible_in_tree())
	check("visual route fires the production blaster",saw_shot)
	check_held_weapon("held weapon scale while firing")
	await capture("visual-firing")
	touch(2,game.mobile_controls._buttons.fire.rect.get_center(),false)
	game.yaw = original_yaw
	game.reset_follow_camera()
	await frames(3)

func run(owner_game: Node) -> void:
	game = owner_game
	_started = Time.get_ticks_msec()
	native = DisplayServer.get_name()!="headless"
	native_ios = OS.get_name()=="iOS" or OS.has_feature("ios")
	keep_open = "--mobile-qa-keep-open" in OS.get_cmdline_user_args()
	var device := "tablet" if Profile.current().tablet else "phone"
	# Exported iOS app resources are read-only. Screenshots and reports belong in
	# the application container, which devicectl can copy after a device run.
	output_dir = ProjectSettings.globalize_path(REPORT_ROOT+"/"+device+("-native" if native else "-headless"))
	var directory_error:=DirAccess.make_dir_recursive_absolute(output_dir)
	saves_before = saved_files()
	check("QA artifact directory is writable",directory_error==OK,{"directory":output_dir,"error":directory_error})
	check("QA guard and explicit mobile profile are active",game.qa_running and Profile.is_mobile())
	if not game.qa_running or not Profile.is_mobile():
		await finish()
		return
	# A preview flag accidentally retained in an iOS launch must never turn into
	# a desktop window request or override the device's native safe-area layout.
	if Profile.current().preview and not Profile.current().native_mobile:
		get_tree().root.content_scale_size=Vector2i(1280,720)
		get_tree().root.size=Vector2i(1280,960) if Profile.current().tablet else Vector2i(1560,720)
	await frames(6)
	check("full world, airport and mobile UI are assembled",game.world._ready_complete and is_instance_valid(game.airport) and is_instance_valid(game.mobile_ui) and game.mobile_ui.enabled and game.mobile_controls.enabled,{"base_structures":game.world.structures.size(),"renderer":RenderingServer.get_current_rendering_method()})
	check("title menu keeps the pointer visible and gameplay touch hidden",game.active_panel=="main" and game.modal.visible and not game.mobile_controls.visible and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	modal_fits("title menu fits the current safe area")
	var profile:=Profile.status(game)
	check("full world uses the mobile frame, render and streaming budgets",Engine.max_fps==30 and is_equal_approx(get_viewport().scaling_3d_scale,float(profile.render_scale)) and not get_viewport().use_taa and get_viewport().scaling_3d_mode==Viewport.SCALING_3D_MODE_BILINEAR and profile.streaming.limit==profile.facade_limit,{"profile":profile})
	await capture("01-main-menu")
	# Never invoke title-menu buttons: production new_world defaults to saving.
	game.active=false
	game.new_world("life","Mobile QA isolated unsaved world",false)
	game.world_id="qa_mobile_unsaved_"+str(Time.get_ticks_usec())
	# Keep real enemy AI and game systems active, but preserve test health while
	# native shader compilation or map screenshots extend this scripted route.
	game.survival.grace=120.0
	await physics_frames(30)
	await frames(4)
	check("new life world enables real player and touch controls",game.active and game.mode=="life" and game.survival.enabled and game.player.enabled and game.mobile_controls.is_gameplay_enabled() and game.mobile_controls.visible and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	var safe:Rect2=game.mobile_controls.safe_area_rect()
	var inside:=true
	for rect:Rect2 in game.mobile_controls.reserved_rects():inside=inside and safe.grow(1).encloses(rect)
	check("all visible touch controls remain inside the safe area",inside,{"safe":rect_data(safe)})
	check("mobile health HUD replaces obstructing desktop panels",game.mobile_ui.health_panel.is_visible_in_tree() and not game.hint_panel.visible and not game.survival_hud.visible and not game.fire_button.visible)
	var start:Vector3=game.player.global_position
	var stick:Vector2=game.mobile_controls._stick_center
	var forward:Vector2=stick-Vector2(0,game.mobile_controls._stick_radius*.9)
	touch(0,stick,true)
	drag(0,forward,forward-stick)
	await frames(2)
	check("injected joystick drag reaches the live Input action",Input.get_action_strength("forward")>.7)
	await physics_frames(48)
	touch(0,forward,false)
	await frames(3)
	var moved:=Vector2(game.player.global_position.x-start.x,game.player.global_position.z-start.z).length()
	check("real CharacterBody walks through the city from touch input",moved>1.0 and not Input.is_action_pressed("forward"),{"metres":moved,"from":vector(start),"to":vector(game.player.global_position)})
	var yaw_before:float=game.yaw
	var look:Vector2=game.mobile_controls._look_region().position+Vector2(60,90)
	touch(1,look,true)
	drag(1,look+Vector2(60,0),Vector2(60,0))
	touch(1,look+Vector2(60,0),false)
	await frames(3)
	check("right-side touch drag turns the live follow camera",absf(game.yaw-yaw_before)>.05,{"yaw_before":yaw_before,"yaw_after":game.yaw})
	await capture("02-on-foot")
	check_held_weapon("held weapon uses metre scale in the production city")
	if "--mobile-visual-qa" in OS.get_cmdline_user_args():
		await capture_held_weapon_route()
	await tap_control("map")
	check("touch map toolbar opens the production paused map",game.active_panel=="map" and game.map_panel.visible and game.paused and get_tree().paused and not game.mobile_controls.visible)
	if game.map_panel.visible:
		modal_fits("map destination list fits the safe area")
		check("map canvas and accessible close button fit the safe area",safe.grow(1).encloses(game.map_panel.get_global_rect()) and safe.grow(1).encloses(game.map_panel._close_button.get_global_rect()),{"map":rect_data(game.map_panel.get_global_rect())})
		game.map_panel.gui_input.connect(func(event:InputEvent):
			if event is InputEventScreenTouch:map_touch_events+=1
			if event is InputEventMouseButton:map_mouse_events+=1)
		var point:Vector2=game.map_panel.map_rect().position+game.map_panel.map_rect().size*Vector2(.36,.57)
		var position_before:Vector3=game.player.global_position
		await tap_at(game.map_panel.global_position+point)
		check("touch selects a destination through the map GUI",not game.landmark_target_key.is_empty() and game.map_panel.visible and game.paused and game.player.global_position.is_equal_approx(position_before),{"key":game.landmark_target_key,"touch_events":map_touch_events,"emulated_mouse_events":map_mouse_events})
		await capture("03-map")
		await tap_at(game.map_panel._close_button.get_global_rect().get_center())
	check("touch close button resumes gameplay and leaves pointer visible",not game.map_panel.visible and not game.paused and game.mobile_controls.is_gameplay_enabled() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	if game.paused:game.close_panel();await frames(3)
	touch(0,forward,true)
	touch(1,game.mobile_controls._buttons.boost.rect.get_center(),true)
	await frames(2)
	check("joystick and boost can be held by separate fingers",Input.is_action_pressed("forward") and Input.is_action_pressed("sprint"))
	await tap_control("pause",2)
	check("pause releases every held action and stops gameplay touch",game.paused and game.modal.visible and not Input.is_action_pressed("forward") and not Input.is_action_pressed("sprint") and not Input.is_action_pressed("boost") and game.mobile_controls._touches.is_empty() and not game.mobile_controls.visible)
	var resume:=first_button("继续游玩")
	if is_instance_valid(resume):await tap_at(resume.get_global_rect().get_center())
	check("touch Continue returns to the live game",not game.paused and game.mobile_controls.is_gameplay_enabled())
	if game.paused:game.close_panel();await frames(3)
	var count_before:int=game.vehicles.size()
	var tank:Variant=game.request_vehicle("tank")
	check("production spawn places and seats a new tank",is_instance_valid(tank) and game.current_vehicle==tank and tank.kind=="tank" and tank.occupied and game.vehicles.size()==count_before+1 and bool(game.get_meta("last_spawn_profile",{}).get("ready",false)))
	if is_instance_valid(tank):
		await physics_frames(12)
		await frames(3)
		check("tank touch controls expose pitch controls",game.mobile_controls._kind=="tank" and game.mobile_controls._button_visible("rise") and game.mobile_controls._button_visible("fall"))
		var fire:Vector2=game.mobile_controls._buttons.fire.rect.get_center()
		var fired_before:int=game.weapons.stats().fired
		touch(0,fire,true)
		await frames(2)
		touch(0,fire,false)
		var fired_after:Dictionary=game.weapons.stats()
		var aim:Dictionary=game.weapons.aim_status()
		var launched:=false
		for slot:Dictionary in game.weapons._projectiles:
			if slot.source!=null and slot.source.get_ref()==tank and not slot.profile.is_empty():launched=true
		check("touch fire launches exactly one real pooled tank projectile",fired_after.fired==fired_before+1 and launched and (fired_after.active_projectiles>0 or fired_after.hits>0),{"before":fired_before,"after":fired_after,"cooldown_remaining":aim.get("cooldown_remaining",0)})
		touch(0,fire,true)
		await frames(2)
		touch(0,fire,false)
		check("rapid second touch cannot bypass the production reload",game.weapons.stats().fired==fired_before+1 and game.weapons.aim_status().cooldown_remaining>0,{"fired":game.weapons.stats().fired,"aim":game.weapons.aim_status()})
		await capture("04-tank")
		touch(0,forward,true)
		await frames(1)
		game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		game.mobile_controls.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		await frames(2)
		check("application suspension releases touch without writing a QA save",not Input.is_action_pressed("forward") and not Input.is_action_pressed("fire") and game.mobile_controls._touches.is_empty() and saved_files()==saves_before)
		game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		game.mobile_controls.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await finish()

func finish() -> void:
	if is_instance_valid(game.mobile_controls):game.mobile_controls.release_all()
	var continuing:bool=keep_open and game.qa_running and game.active and str(game.world_id).begins_with("qa_mobile_unsaved_")
	if continuing:
		# qa_running prevents autosave/background saves. An empty ID additionally
		# makes production save_world reject explicit menu/keyboard save requests.
		game.world_id=""
		game.close_panel()
		check("continued QA world rejects explicit saves",not game.save_world() and saved_files()==saves_before)
	check("player saves and settings remain byte-identical",saved_files()==saves_before,{"files_checked":saves_before.size()})
	var report_file:=FileAccess.open(output_dir.path_join("report.json"),FileAccess.WRITE)
	check("device report file can be opened",report_file!=null,{"path":output_dir.path_join("report.json"),"error":FileAccess.get_open_error()})
	var latest_path:=ProjectSettings.globalize_path(REPORT_ROOT+"/report.json")
	var latest_file:=FileAccess.open(latest_path,FileAccess.WRITE)
	check("latest report file can be opened",latest_file!=null,{"path":latest_path,"error":FileAccess.get_open_error()})
	var passed:=checks.all(func(item:Dictionary):return item.passed)
	var sources:Dictionary={}
	for filename:String in SOURCES:
		var path:="res://scripts/"+filename+".gd"
		if FileAccess.file_exists(path):sources[path]=FileAccess.get_sha256(path)
	var report:={"passed":passed,"count":checks.size(),"checks":checks,"screenshots":screenshots,"native_rendering":native,"renderer":RenderingServer.get_current_rendering_method(),"platform":OS.get_name(),"device_model":OS.get_model_name(),"native_ios_runtime_tested":native_ios and native,"physical_touch_hardware_tested":false,"profile":Profile.status(game),"elapsed_seconds":(Time.get_ticks_msec()-_started)/1000.0,"touch_events_injected":touch_events,"map_touch_events":map_touch_events,"map_emulated_mouse_events":map_mouse_events,"user_saves_touched":saved_files()!=saves_before,"sustained_performance_tested":false,"keep_open_requested":keep_open,"continuing_unsaved_world":continuing,"source_sha256":sources,"scope":"Complete production city. Engine-injected ScreenTouch/ScreenDrag with normal Godot touch-to-mouse GUI emulation; actual CharacterBody physics and pooled tank weapon. One unsaved life-mode world with 120-second damage grace. Spawn uses the production request_vehicle method. Native iOS execution is identified by platform; device hardware versus simulator identity must also be established by the launch host. This does not prove physical touch input, sustained frame rate, thermal stability or device memory safety."}
	report.instantaneous_performance=instantaneous_performance()
	var serialized:=JSON.stringify(report,"\t")
	for file:FileAccess in [report_file,latest_file]:
		if file!=null:
			file.store_string(serialized)
			file.flush()
			file.close()
	# Keep each console record short: some iOS log transports truncate long lines.
	print("MOBILE_QA_REPORT_BEGIN")
	for line:String in serialized.split("\n"):print(line)
	print("MOBILE_QA_REPORT_END")
	print("MOBILE_QA_PERFORMANCE_SNAPSHOT ",JSON.stringify(report.instantaneous_performance))
	print("MOBILE_QA_COMPLETE checks=",checks.size()," passed=",passed," report=",output_dir.path_join("report.json"))
	if continuing:
		game.notify("移动验收完成 · 临时试玩世界不会保存\n关闭应用结束测试",false)
		game.set_meta("mobile_qa_keep_open",true)
		print("MOBILE_QA_KEEP_OPEN active=",game.active," qa_running=",game.qa_running," saving_disabled=",game.world_id=="")
		return
	game.active=false
	get_tree().paused=false
	game.finish_quit(0 if passed else 1)
