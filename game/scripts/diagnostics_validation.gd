extends Node
## Production UI events. Only the caller starts this isolated QA run.
## Native captures document appearance; this does not claim physical OS input.
const OUTPUT := "user://diagnostics-qa"
var game: Node
var checks: Array=[]
var screenshots: Array=[]
var native:=false
var pointer:=Vector2(700,430)
var routed_events:=0
var _started:=false
var spawn_profiles: Array=[]

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS

func check(title: String, okay: bool, detail: Dictionary={}) -> void:
	checks.append({"name":title,"passed":okay,"detail":detail})
	print("DIAGNOSTICS_QA ","PASS " if okay else "FAIL ",title)

func key(code: int, pressed:=true, echo_event:=false) -> void:
	var event:=InputEventKey.new()
	event.keycode=code;event.physical_keycode=code;event.pressed=pressed;event.echo=echo_event
	get_tree().root.push_input(event,true)

func tap(code: int) -> void:
	key(code,true);key(code,false)
	await frames(2)

func frames(count: int=2) -> void:
	for _i in count: await get_tree().process_frame

func motion(point: Vector2, dragging:=false) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=point;event.global_position=point;event.relative=point-pointer
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if dragging else 0
	get_tree().root.push_input(event,true);pointer=point

func mouse(point: Vector2, pressed: bool, button: int=MOUSE_BUTTON_LEFT) -> void:
	var event:=InputEventMouseButton.new()
	event.position=point;event.global_position=point;event.button_index=button;event.pressed=pressed
	get_tree().root.push_input(event,true)

func reveal(control: Control) -> bool:
	if not is_instance_valid(control): return false
	await frames(3)
	var parent: Node=control.get_parent()
	while parent!=null and not parent is ScrollContainer: parent=parent.get_parent()
	if parent==null: return control.is_visible_in_tree()
	var scroll: ScrollContainer=parent
	# Use real GUI wheel events to reveal clipped controls, never assigning scroll offsets.
	for _i in 90:
		# The first row legitimately touches the viewport's top edge. Requiring
		# an inset made it impossible to reveal its fully visible close button.
		var clip:=scroll.get_global_rect()
		var box:=control.get_global_rect()
		if box.position.y>=clip.position.y-.5 and box.end.y<=clip.end.y+.5: return true
		var button:=MOUSE_BUTTON_WHEEL_DOWN if box.end.y>clip.end.y else MOUSE_BUTTON_WHEEL_UP
		# The content center may contain a scrollable HSlider. Aim at the actual
		# vertical bar so revealing another control cannot change a lighting value.
		var aim:=scroll.get_v_scroll_bar().get_global_rect().get_center()
		motion(aim);mouse(aim,true,button);mouse(aim,false,button)
		await frames(1)
	return false

func click(control: Control) -> bool:
	if not await reveal(control): return false
	var point:=control.get_global_rect().get_center()
	motion(point);mouse(point,true);mouse(point,false)
	await frames(3)
	return true

func drag(slider: HSlider, fraction: float) -> bool:
	if not await reveal(slider) or not slider.editable: return false
	var rect:=slider.get_global_rect()
	var initial:=Vector2(rect.position.x+rect.size.x*.32,rect.get_center().y)
	var destination:=Vector2(rect.position.x+rect.size.x*clampf(fraction,.05,.95),rect.get_center().y)
	motion(initial);mouse(initial,true)
	for step in range(1,6): motion(initial.lerp(destination,step/5.0),true)
	mouse(destination,false)
	await frames(3)
	return true

func capture(label: String) -> void:
	if not native: return
	if game.world.has_method("prepare_view"):
		var settled: bool=await game.world.prepare_view(game.camera.global_position)
		check("Facade stream settled for "+label,settled)
	await frames(3)
	# A single readback is intentional in the QA fixture only, never the diagnostics module.
	await RenderingServer.frame_post_draw
	var picture:=get_tree().root.get_texture().get_image()
	var filename:=label+".png"
	var error:=picture.save_png(OUTPUT+"/"+filename)
	screenshots.append({"file":filename,"saved":error==OK,"sha256":FileAccess.get_sha256(OUTPUT+"/"+filename) if error==OK else "","resolution":[picture.get_width(),picture.get_height()]})

func pipeline_counters() -> Dictionary:
	return {"pipeline_draw":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),"pipeline_mesh":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),"pipeline_surface":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)}

func profile_tank_requests(original: RigidBody3D) -> void:
	if not native: return
	for iteration in 2:
		await frames(6)
		var before:=pipeline_counters()
		var before_tick:=Time.get_ticks_usec()
		var spawned: Variant=game.request_vehicle("tank")
		var returned_tick:=Time.get_ticks_usec()
		var phase: Dictionary=game.get_meta("last_spawn_profile",{}).duplicate(true)
		if is_instance_valid(spawned): spawned.freeze=true
		await frames(6)
		var after:=pipeline_counters()
		var difference: Dictionary={}
		for counter in before: difference[counter]=float(after[counter])-float(before[counter])
		spawn_profiles.append({"request":iteration+1,"kind":"tank","profile":phase,"request_wall_ms":(returned_tick-before_tick)/1000.0,"counters_before":before,"counters_after_six_render_frames":after,"counter_delta":difference,"sample_start_usec":before_tick,"sample_end_usec":Time.get_ticks_usec()})
		check("Native production tank request profile "+str(iteration+1),is_instance_valid(spawned) and phase.get("ready",false) and phase.has("model_ms") and phase.has("occupancy_cache_ms") and phase.has("placement_ms") and phase.has("total_ms"),spawn_profiles[-1])
		if is_instance_valid(spawned): game.exit_vehicle()
		game.enter_vehicle(original);original.freeze=true
		await frames(2)

func run(owner_game: Node=null) -> void:
	if _started: return
	_started=true;game=owner_game if owner_game!=null else get_parent()
	native=DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	# new_world may save an existing active world. Refuse that situation instead.
	if not game.qa_running or game.active:
		check("QA starts isolated before any active player world",false)
		await finish();return
	if not is_instance_valid(game.world) or not game.world._ready_complete:
		check("Production world completed construction before any UI checks",false)
		await finish();return
	check("Production world completed construction before any UI checks",true)
	get_tree().root.notify_mouse_entered()
	game.new_world("sandbox","Diagnostics UI QA",false)
	game.world_id="qa_diagnostics_"+str(Time.get_ticks_usec())
	game.player.enabled=false
	for vehicle in game.vehicles: vehicle.freeze=true
	var tanks: Array=game.vehicles.filter(func(v): return v.kind=="tank")
	check("Complete production world and an actual armed vehicle exist",game.world._ready_complete and not tanks.is_empty())
	if not game.world._ready_complete or tanks.is_empty(): await finish();return
	var tank: RigidBody3D=tanks[0]
	game.enter_vehicle(tank);tank.freeze=true
	await profile_tank_requests(tank)
	await frames(3)
	var diagnostics: Node=get_node("/root/RuntimeDiagnostics")
	var panel: Control=game.diagnostics_panel
	var env: Environment=game.environment.environment
	var clock: Node=game.city_clock
	var fleet_size: int=game.vehicles.size()
	var identity: String=tank.vehicle_id
	var original_pose: Transform3D=tank.global_transform
	var original_money: int=game.life.money
	var fired: int=game.weapons.stats().fired
	var flags_before: Dictionary=diagnostics.snapshot().render.enabled_flags
	var glass_profiles_before: Dictionary=game.world.material_roles.stats().current_overrides.duplicate(true)
	check("Gameplay initially owns the camera and weapon input",game.camera_accepts_mouse() and game.can_fire_weapon() and not get_tree().paused)
	await tap(KEY_F3)
	check("F3 opens real panel and pauses physics with visible cursor",panel.visible and panel.is_processing() and game.paused and get_tree().paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	check("F3 blocks weapon firing and hides targeting overlays",not game.can_fire_weapon() and not game.fire_button.visible and not game.combat_reticle.visible)
	var yaw_before: float=game.yaw
	motion(Vector2(745,422));await tap(KEY_X)
	check("Panel mouse motion and weapon key do not rotate or fire",is_equal_approx(game.yaw,yaw_before) and int(game.weapons.stats().fired)==fired)
	key(KEY_F3,true,true);key(KEY_F3,false)
	check("Held F3 key repeat does not close the panel",panel.visible)
	await capture("01-f3-live-counters")
	var exposure: HSlider=panel.find_child("DiagnosticsSlider_exposure",true,false)
	var ambient: HSlider=panel.find_child("DiagnosticsSlider_ambient",true,false)
	var glass: HSlider=panel.find_child("DiagnosticsSlider_glass_roughness",true,false)
	for control in [exposure,ambient,glass]:
		control.gui_input.connect(func(_event): routed_events+=1)
	var old_exposure: float=env.tonemap_exposure
	var dragged:=await drag(exposure,.42)
	check("Actual F3 pointer drag changes live exposure",dragged and absf(env.tonemap_exposure-old_exposure)>.03 and is_equal_approx(env.tonemap_exposure,float(exposure.value)))
	dragged=await drag(ambient,.45)
	check("Ambient slider changes actual environment light",dragged and is_equal_approx(env.ambient_light_energy,float(ambient.value)))
	var ratios: Dictionary=env.get_meta("cycle_tuning_multipliers",{}).duplicate()
	check("F3 stores proportional cycle settings separately",ratios.has("exposure") and ratios.has("ambient") and game.settings.cycle_tuning==ratios and not game.settings.render_tuning.has("ambient"))
	dragged=await drag(glass,.35)
	var glass_stats: Dictionary=game.world.material_roles.stats()
	check("Actual glass slider reaches registered city and landmark materials",dragged and glass_stats.covered_shader_count>0 and is_equal_approx(float(glass_stats.current_overrides.glass.roughness),float(glass.value)))
	check("Control GUI received routed pointer events",routed_events>=10,{"events":routed_events})
	check("Tuning preserves all live render feature flags",diagnostics.snapshot().render.enabled_flags==flags_before)
	await capture("02-f3-material-tuning")
	await tap(KEY_F3)
	check("F3 closes with a focused slider and resumes camera and weapon control",not panel.visible and not panel.is_processing() and not game.paused and not get_tree().paused and game.camera_accepts_mouse() and game.can_fire_weapon())
	await tap(KEY_T)
	check("T opens time controls, pauses gameplay and releases pointer",game.active_panel=="time" and game.modal.visible and game.paused and get_tree().paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	var sky_before: int=env.get_meta("cycle_sky_updates",0)
	dragged=await drag(game.time_slider,.65)
	check("Real time-slider drag immediately seeks current clock",dragged and absf(float(clock.hour)-float(game.time_slider.value))<.018)
	check("Paused time seek updates actual sky rather than waiting for game ticks",int(env.get_meta("cycle_sky_updates",0))>sky_before and is_equal_approx(float(env.get_meta("cycle_sky_hour")),float(clock.hour)))
	var sunset: Button=game.modal_content.find_child("Jump_sunset",true,false)
	var clicked:=await click(sunset)
	check("Sunset preset button uses the real Sydney cycle baseline",clicked and absf(float(clock.hour)-float(clock.baseline.sunset_hour))<.001)
	var base: Dictionary=env.get_meta("cycle_base_values")
	check("Earlier F3 adjustments survive T sunset seek",is_equal_approx(env.ambient_light_energy,clampf(float(base.ambient)*float(ratios.ambient),0,2)) and is_equal_approx(env.tonemap_exposure,clampf(float(base.exposure)*float(ratios.exposure),.1,3)))
	await capture("03-time-sunset")
	await tap(KEY_F3)
	check("F3 can inspect paused time controls without losing their state",panel.visible and game.active_panel=="time" and game.modal.visible and game.paused)
	var reset: Button=panel.find_child("DiagnosticsReset",true,false)
	clicked=await click(reset)
	base=env.get_meta("cycle_base_values")
	check("Real reset button clears multipliers and restores current sunset light",clicked and env.get_meta("cycle_tuning_multipliers").is_empty() and game.settings.cycle_tuning.is_empty() and is_equal_approx(env.tonemap_exposure,float(base.exposure)) and is_equal_approx(env.ambient_light_energy,float(base.ambient)) and is_equal_approx(game.sun.light_energy,float(base.sun_energy)))
	check("Reset restores heterogeneous glass profile without structural changes",game.world.material_roles.stats().current_overrides==glass_profiles_before and diagnostics.snapshot().render.enabled_flags==flags_before)
	await tap(KEY_ESCAPE)
	check("Closing F3 over T preserves original pause and visible pointer",not panel.visible and game.active_panel=="time" and game.modal.visible and game.paused and get_tree().paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	var running_before: bool=clock.running
	clicked=await click(game.time_running)
	check("Cycle checkbox changes actual running state",clicked and bool(clock.running)!=running_before and bool(game.time_running.button_pressed)==bool(clock.running))
	var speed: OptionButton=game.time_speed
	clicked=await click(speed)
	var popup: PopupMenu=speed.get_popup()
	check("Speed selector opens a real GUI popup",clicked and popup.visible)
	if popup.visible:
		# Root routes embedded-window events through Window input first. Calling
		# popup.push_input directly would bypass PopupMenu's actual key handling.
		check("Popup uses the production embedded-window input route",popup.is_embedded())
		var desired: int=speed.get_item_index(60)
		for _i in speed.item_count+1:
			var focused:=popup.get_focused_item()
			if focused==desired: break
			await tap(KEY_DOWN if focused<desired else KEY_UP)
		await tap(KEY_ENTER)
	check("Popup keyboard selection sets real cycle speed to 60x",is_equal_approx(float(clock.speed),60.0) and speed.get_selected_id()==60)
	var stopped_hour: float=clock.hour
	await tap(KEY_T)
	check("T closes with focused time controls and restores camera",game.active_panel.is_empty() and not game.modal.visible and not game.paused and not get_tree().paused and game.camera_accepts_mouse())
	clock._process(.25) # QA disables automatic clock ticks; exercise a controlled real update.
	check("Disabled cycle stays at selected time after gameplay resumes",not clock.running and is_equal_approx(float(clock.hour),stopped_hour))
	await tap(KEY_T)
	clicked=await click(game.time_running)
	check("Cycle can be resumed through its visible checkbox",clicked and clock.running)
	var night: Button=game.modal_content.find_child("Jump_night",true,false)
	clicked=await click(night)
	check("Night preset seeks 22:00 and removes direct sunlight",clicked and is_equal_approx(float(clock.hour),22.0) and is_zero_approx(game.sun.light_energy))
	await tap(KEY_F3)
	var sun: HSlider=panel.find_child("DiagnosticsSlider_sun_energy",true,false)
	check("Night F3 correctly disables zero-baseline sunlight slider",not sun.editable and sun.tooltip_text.contains("基础亮度为零"))
	await tap(KEY_ESCAPE)
	await capture("04-time-night")
	var resume_hour: float=clock.hour
	await tap(KEY_ESCAPE)
	clock._process(.25)
	check("Esc resumes running cycle and the camera",not game.paused and game.camera_accepts_mouse() and float(clock.hour)>resume_hour)
	await tap(KEY_F3)
	var closing: Button=panel.find_child("DiagnosticsClose",true,false)
	clicked=await click(closing)
	check("Visible F3 close button also restores gameplay",clicked and not panel.visible and not game.paused and game.camera_accepts_mouse(),{"click_injected":clicked,"panel_visible":panel.visible,"game_paused":game.paused,"tree_paused":get_tree().paused,"mouse_mode":Input.mouse_mode,"camera_accepts_mouse":game.camera_accepts_mouse(),"button_rect":str(closing.get_global_rect())})
	check("All GUI actions preserve vehicle identity, pose, fleet and money",game.current_vehicle==tank and tank.occupied and tank.vehicle_id==identity and tank.global_transform.is_equal_approx(original_pose) and game.vehicles.size()==fleet_size and game.life.money==original_money)
	check("No slider, popup or preset action fires a projectile",int(game.weapons.stats().fired)==fired,{"before":fired,"after":game.weapons.stats().fired})
	if native: check("All requested native screenshots saved",screenshots.size()==4 and screenshots.all(func(item):return item.saved))
	await finish()

func finish() -> void:
	var passed:=checks.all(func(item):return item.passed)
	var hashes: Dictionary={}
	for filename in ["diagnostics_validation.gd","runtime_diagnostics.gd","diagnostics_panel.gd","time_panel.gd","city_clock.gd","daylight_environment.gd","material_roles.gd","main.gd"]:
		hashes[filename]=FileAccess.get_sha256("res://scripts/"+filename)
	var report: Dictionary={"passed":passed,"count":checks.size(),"checks":checks,"native":native,"screenshots":screenshots,"spawn_profiles":spawn_profiles,"source_sha256":hashes,"scope":"Production world and controls. Viewport.push_input routes keys, pointer drags, wheel scrolling and embedded PopupMenu navigation through actual GUI; no direct menu handlers, value setters or signal emission for UI assertions. Native runs first profile two direct production tank requests, sampling actual phase times and cumulative pipeline counters after six render frames; these are observations, not an attribution to shaders or an FPS benchmark. QA disables automatic city-clock updates; two controlled 0.25-second clock._process updates verify stopped/resumed behavior. Native screenshots are visual evidence only; not an OS hardware input claim.","user_saves_touched":false,"settings_files_written":false}
	FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("DIAGNOSTICS_QA_COMPLETE ",checks.size()," passed=",passed)
	game.active=false;get_tree().paused=false
	game.finish_quit(0 if passed else 1)
