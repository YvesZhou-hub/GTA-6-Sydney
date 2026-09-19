extends Node3D

const Store = preload("res://scripts/save_store.gd")
const Player = preload("res://scripts/harbor_player.gd")
const Sound = preload("res://scripts/harbor_audio.gd")
const AudioShutdown = preload("res://scripts/audio_shutdown.gd")
const VehicleSpawn = preload("res://scripts/vehicle_spawn.gd")
const GameSettings = preload("res://scripts/game_settings.gd")
const Loading = preload("res://scripts/loading_progress.gd")
const VEHICLE_NAMES = {"car":"Veloce V12 · 超跑","motorcycle":"Apex RR · 超级运动摩托","hoverboard":"Aether X1 · 反重力平衡车","speedboat":"Riviera 39 · 豪华快艇","yacht":"Ocean 90 · 豪华游艇","paraglider":"Thermal 9 · 滑翔伞","glider":"Southern Arc · 滑翔机","helicopter":"Harbour H6 · 直升机","airliner":"Dreamliner 787-9 · 双发客机","tank":"Harbour Bastion · 重装坦克","fighter":"Aster F-27 · 战斗机"}
var survival: Node3D
var survival_hud: Control
var campaign: Node
var districts: Node
var street: Node3D
var street_lights: Node3D
var combat_feel: Node
var combat_feedback: Control
var airport: Node3D
var world: Node3D
var player: CharacterBody3D
var life: Node3D
var audio: Node
var camera: Camera3D
var environment: WorldEnvironment
var sun: DirectionalLight3D
var vehicles: Array = []
var spawn_target: RigidBody3D
var spawn_marker: Label
var spawn_sequence := 0
var landmark_target_key := ""
var landmark_target_name := ""
var landmark_target_position := Vector3.ZERO
var landmark_marker: Label
var current_vehicle: RigidBody3D
var canvas: CanvasLayer
var hud: Control
var modal: PanelContainer
var modal_content: VBoxContainer
var info: Label
var context_hint: Label
var left_column: VBoxContainer
var activity_panel: PanelContainer
var vehicle_panel: PanelContainer
var toast_panel: PanelContainer
var hint_panel: PanelContainer
var toast_label: Label
var activity_label: Label
var region_label: Label
var speed_label: Label
var mode_label: Label
var map_panel: Control
var minimap: Control
var navigation_hud: Control
var _navigation_tick := 0.0
var yaw=0.1
var pitch=-0.16
var camera_distance=7.0
var toast_time=0.0
var autosave=0.0
var elapsed=0.0
var active=false
var paused=false
var world_id=""
var world_name=""
var mode="life"
var owned: Array=["car"]
var settings:Dictionary=GameSettings.DEFAULTS.duplicate(true)
var _using_pad:=false
var _pad_focus_pending:=false
var _rebind_group:=""
var _settings_notice:=""
var active_panel=""
var name_edit: LineEdit
var map_search: LineEdit
var map_results: VBoxContainer
var font: Font
var demo_mode=false
var qa_running=false
var qa_report: Dictionary={}
var qa_profile_stage=""
var qa_frame_times: Array=[]
var qa_frame_stamp=0
var qa_manual_render=false
var qa_render_count=0
var quitting=false
var menu_orbit=0.0
var photo_cooldown=0.0
var save_indicator: Label
var _camera_focus := Vector3.ZERO
var _camera_orbit := Vector3.ZERO
var _camera_boom := 0.0
var _camera_subject_id := 0
var _camera_reset := true
var _cursor_held := false
var weapons: Node3D
var fire_button: Button
var combat_reticle: Label
var _combat_aim_clock:=0.0
var _combat_aim_point:=Vector3.ZERO
var diagnostics_panel:Control
var _diagnostics_previous_pause:=false
var city_clock:Node
var public_lighting:Node3D
var time_slider:HSlider
var time_label:Label
var time_running:CheckButton
var time_speed:OptionButton

func _ready():
	var arguments:=OS.get_cmdline_user_args()
	if "--mobility-qa" in arguments:
		qa_running=true
		setup_input()
		set_process(false)
		set_process_unhandled_input(false)
		add_child(load("res://scripts/mobility_validation.gd").new())
		return
	qa_running=qa_running or "--script" in OS.get_cmdline_args() or ["--qa","--flight-qa","--experience-qa","--air-vehicle-qa","--visual-qa","--interactive-qa","--navigation-input-qa","--precinct-qa","--opera-access-qa","--combat-qa","--diagnostics-qa","--daylight-qa","--trailer-capture","--ui-font-qa","--driving-qa","--survival-qa","--encounter-qa","--arsenal-qa","--hud-qa","--campaign-qa","--street-qa","--district-qa","--feel-qa"].any(func(flag):return flag in arguments)
	get_tree().auto_accept_quit=false
	setup_input()
	setup_environment()
	world=load("res://scripts/harbor_world.gd").new()
	world.set_meta("stream_details",true)
	add_child(world)
	world.process_mode=Node.PROCESS_MODE_PAUSABLE
	Loading.report(0.88,"准备悉尼机场")
	if ResourceLoader.exists("res://scripts/airport_world.gd"):
		airport=load("res://scripts/airport_world.gd").new()
		add_child(airport)
		airport.process_mode=Node.PROCESS_MODE_PAUSABLE
		airport.setup()
		world.anchors.merge(airport.anchors)
	# Measured first summon spent about one second building immutable footprint
	# lookup data. Pay that once behind the existing loading screen.
	Loading.report(0.93,"检查载具停放空间")
	var occupancy_started:=Time.get_ticks_usec()
	preload("res://scripts/map_migration.gd")._geometry(world)
	set_meta("occupancy_preload_ms",(Time.get_ticks_usec()-occupancy_started)/1000.0)
	var bridge=load("res://scripts/bridge_landmark.gd")
	world.anchors["race_route"]=[bridge.SOUTH_ENTRY+Vector3.UP*.7,bridge.ramp_position("south",.5)+Vector3.UP*.7,bridge.pos(0)+Vector3.UP*.7,bridge.pos(251.5)+Vector3.UP*.7,bridge.pos(503)+Vector3.UP*.7,bridge.ramp_position("north",.33)+Vector3.UP*.7,bridge.ramp_position("north",.67)+Vector3.UP*.7,bridge.NORTH_ENTRY+Vector3.UP*.7]
	world.anchors["cargo_delivery"]=Vector3(-330,5,-20)
	world.anchors["salvage"]=Vector3(-545,1,-490)
	player=Player.new()
	add_child(player)
	player.process_mode=Node.PROCESS_MODE_PAUSABLE
	player.collision_mask=15
	player.global_position=world.anchors.get("home",Vector3(-140,6,150))+Vector3(0,1,15)
	player.last_safe=player.global_position
	audio=Sound.new()
	add_child(audio)
	# Walking and swimming no longer trigger the repetitive synthesized footstep.
	player.landed.connect(func(s): if s>16: notify("落地冲击 · 放慢速度，小心高处",false))
	camera=Camera3D.new()
	# The camera samples rendered transforms itself; interpolating it a second time causes jitter.
	camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.far=12000
	camera.near=0.15
	camera.fov=68
	add_child(camera)
	camera.current=true
	life=load("res://scripts/harbor_life.gd").new()
	add_child(life)
	life.process_mode=Node.PROCESS_MODE_PAUSABLE
	life.setup(world.anchors,false)
	life.connect("notification",func(t): notify(t))
	Loading.report(0.97,"准备界面")
	setup_ui()
	weapons=load("res://scripts/vehicle_weapons.gd").new()
	add_child(weapons)
	weapons.setup(self)
	survival=load("res://scripts/harbor_survival.gd").new()
	add_child(survival)
	survival.setup(self)
	survival_hud=load("res://scripts/survival_hud.gd").new()
	hud.add_child(survival_hud)
	survival_hud.setup(self)
	survival_hud.service_requested.connect(survival_menu)
	survival_hud.heal_requested.connect(func(): notify(survival.quick_recovery()))
	combat_feel=load("res://scripts/combat_feel.gd").new()
	add_child(combat_feel)
	combat_feel.setup(self)
	combat_feedback=load("res://scripts/combat_feedback.gd").new()
	canvas.add_child(combat_feedback)
	canvas.move_child(combat_feedback,0)
	combat_feedback.setup(self)
	campaign=load("res://scripts/campaign.gd").new()
	add_child(campaign)
	campaign.setup(self)
	districts=load("res://scripts/districts.gd").new()
	add_child(districts)
	districts.setup(self)
	street=load("res://scripts/street_life.gd").new()
	add_child(street)
	street.setup(self)
	if not qa_running: load_settings()
	else: apply_settings()
	city_clock=load("res://scripts/city_clock.gd").new()
	add_child(city_clock)
	city_clock.setup(self)
	public_lighting=load("res://scripts/public_lighting.gd").new()
	add_child(public_lighting)
	public_lighting.setup(self)
	street_lights=load("res://scripts/street_lights.gd").new()
	add_child(street_lights)
	street_lights.setup(self)
	city_clock.changed.connect(func(_state):
		public_lighting.apply_cycle(city_clock.solar_state())
		street_lights.apply_cycle(city_clock.solar_state()))
	street_lights.apply_cycle(city_clock.solar_state())
	# QA orchestration owns time explicitly, keeping fixed-camera evidence stable.
	city_clock.set_process(not qa_running)
	var diagnostics=get_node("/root/RuntimeDiagnostics")
	diagnostics.setup(self)
	diagnostics_panel=load("res://scripts/diagnostics_panel.gd").new()
	canvas.add_child(diagnostics_panel)
	diagnostics_panel.setup(self,diagnostics)
	diagnostics_panel.toggled.connect(_diagnostics_toggled)
	main_menu()
	if "--qa" in OS.get_cmdline_user_args():
		qa_running=true
		qa_manual_render=DisplayServer.get_name()!="headless"
		if qa_manual_render:
			RenderingServer.render_loop_enabled=false
			process_priority=1000
		call_deferred("run_qa")
	elif "--flight-qa" in OS.get_cmdline_user_args():
		qa_running=true
		var flight=load("res://scripts/flight_validation.gd").new()
		add_child(flight)
		flight.call_deferred("run")
	elif "--experience-qa" in arguments:
		add_child(load("res://scripts/experience_validation.gd").new())
	elif "--air-vehicle-qa" in arguments:
		add_child(load("res://scripts/air_vehicle_validation.gd").new())
	elif "--driving-qa" in arguments:
		add_child(load("res://scripts/driving_validation.gd").new())
	elif "--survival-qa" in arguments:
		add_child(load("res://scripts/survival_validation.gd").new())
	elif "--arsenal-qa" in arguments:
		add_child(load("res://scripts/arsenal_validation.gd").new())
	elif "--encounter-qa" in arguments:
		add_child(load("res://scripts/encounter_validation.gd").new())
	elif "--visual-qa" in arguments:
		add_child(load("res://scripts/landmark_validation.gd").new())
	elif "--interactive-qa" in arguments:
		call_deferred("start_interactive_qa")
	elif "--navigation-input-qa" in arguments:
		add_child(load("res://scripts/navigation_input_validation.gd").new())
	elif "--opera-access-qa" in arguments:
		add_child(load("res://scripts/opera_access_validation.gd").new())
	elif "--combat-qa" in arguments:
		add_child(load("res://scripts/combat_validation.gd").new())
	elif "--diagnostics-qa" in arguments:
		var validation=load("res://scripts/diagnostics_validation.gd").new()
		add_child(validation)
		validation.call_deferred("run",self)
	elif "--daylight-qa" in arguments:
		var validation=load("res://scripts/daylight_validation.gd").new()
		add_child(validation)
		validation.call_deferred("run",self)
	elif "--precinct-qa" in arguments:
		add_child(load("res://scripts/precinct_validation.gd").new())
	elif "--trailer-capture" in arguments:
		var recorder=load("res://scripts/trailer_capture.gd").new()
		add_child(recorder)
		recorder.call_deferred("run",self)
	elif "--hud-qa" in arguments:
		var validation=load("res://scripts/hud_validation.gd").new()
		add_child(validation)
		validation.call_deferred("run",self)
	elif "--campaign-qa" in arguments:
		var campaign_validation=load("res://scripts/campaign_validation.gd").new()
		add_child(campaign_validation)
		campaign_validation.call_deferred("run",self)
	elif "--street-qa" in arguments:
		var street_validation=load("res://scripts/street_validation.gd").new()
		add_child(street_validation)
		street_validation.call_deferred("run",self)
	elif "--district-qa" in arguments:
		var district_validation=load("res://scripts/district_validation.gd").new()
		add_child(district_validation)
		district_validation.call_deferred("run",self)
	elif "--feel-qa" in arguments:
		var feel_validation=load("res://scripts/feel_validation.gd").new()
		add_child(feel_validation)
		feel_validation.call_deferred("run",self)
	elif "--ui-font-qa" in arguments:
		var validation=load("res://scripts/ui_font_validation.gd").new()
		add_child(validation)
		validation.call_deferred("run",self)
	elif "--showcase" in OS.get_cmdline_user_args():
		demo_mode=true
		new_world("sandbox","QA Showcase",false)
		player.global_position=world.anchors.get("quay",Vector3(50,6,0))+Vector3(0,1,15)
		yaw=0.12
		pitch=-0.16

func start_interactive_qa():
	new_world("sandbox","Interactive release QA",false)
	world_id="qa_interactive_"+str(Time.get_ticks_usec())
	print("INTERACTIVE_QA_READY world=",world_id," components=",world.structures.size())

func setup_input():
	for action in {"heal":KEY_H,"survival_services":KEY_B,"auto_support":KEY_V}:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var event=InputEventKey.new()
		event.physical_keycode={"heal":KEY_H,"survival_services":KEY_B,"auto_support":KEY_V}[action]
		if not InputMap.action_has_event(action,event): InputMap.action_add_event(action,event)
	var bindings={"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"rise":[KEY_R],"fall":[KEY_F],"brake":[KEY_SPACE],"jump":[KEY_SPACE],"sprint":[KEY_SHIFT],"boost":[KEY_SHIFT],"drift":[KEY_CTRL],"interact":[KEY_E],"vehicles":[KEY_TAB],"jobs":[KEY_J],"map":[KEY_M],"experiences":[KEY_K],"carry":[KEY_G],"photo":[KEY_P],"save":[KEY_F5],"recover":[KEY_HOME],"fire":[KEY_X],"combat_yaw_left":[KEY_Q],"combat_yaw_right":[KEY_Z],"combat_raise":[KEY_R],"combat_lower":[KEY_F]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var event=InputEventKey.new()
			event.physical_keycode=key
			InputMap.action_add_event(action,event)
	var trigger:=InputEventMouseButton.new()
	trigger.button_index=MOUSE_BUTTON_LEFT
	if not InputMap.action_has_event("fire",trigger): InputMap.action_add_event("fire",trigger)
	if not InputMap.has_action("cursor"): InputMap.add_action("cursor")
	var cursor_key:=InputEventKey.new()
	cursor_key.physical_keycode=KEY_ALT
	if not InputMap.action_has_event("cursor",cursor_key): InputMap.action_add_event("cursor",cursor_key)
	GameSettings.add_gamepad_bindings()
	GameSettings.capture_default_keys()

func setup_environment():
	environment=WorldEnvironment.new()
	environment.environment=preload("res://scripts/daylight_environment.gd").make_environment()
	add_child(environment)
	sun=preload("res://scripts/daylight_environment.gd").make_sun()
	add_child(sun)

func setup_ui():
	canvas=CanvasLayer.new()
	add_child(canvas)
	var theme=preload("res://scripts/ui_theme.gd").build()
	font=theme.default_font
	var root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.theme=theme
	canvas.add_child(root)
	hud=Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	# Status, guidance and the survival card stack in one column so a taller
	# panel pushes the next element down instead of drawing over it.
	left_column=VBoxContainer.new()
	left_column.name="LeftColumn"
	left_column.position=Vector2(28,24)
	left_column.custom_minimum_size.x=365
	left_column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	left_column.add_theme_constant_override("separation",10)
	hud.add_child(left_column)
	var top=PanelContainer.new()
	top.add_theme_stylebox_override("panel",panel_style(Color(0.025,0.09,0.12,0.82),10))
	top.mouse_filter=Control.MOUSE_FILTER_IGNORE
	left_column.add_child(top)
	var topbox=VBoxContainer.new()
	topbox.add_theme_constant_override("separation",5)
	top.add_child(topbox)
	mode_label=label("HARBOURLIFE  /  SYDNEY",14,Color("8ed1c1"))
	topbox.add_child(mode_label)
	region_label=label("Circular Quay · 环形码头",23)
	topbox.add_child(region_label)
	info=label("",15,Color("d0d6c9"))
	topbox.add_child(info)
	activity_panel=PanelContainer.new()
	var activity_style=panel_style(Color(0.025,0.09,0.12,0.72),10)
	activity_style.content_margin_top=11
	activity_style.content_margin_bottom=11
	activity_panel.add_theme_stylebox_override("panel",activity_style)
	activity_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	activity_panel.visible=false
	left_column.add_child(activity_panel)
	activity_label=label("",15,Color("e9eedf"))
	activity_label.custom_minimum_size.x=321
	activity_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	activity_label.max_lines_visible=4
	activity_panel.add_child(activity_label)
	vehicle_panel=PanelContainer.new()
	vehicle_panel.name="VehicleReadout"
	var vehicle_style=panel_style(Color(0.025,0.09,0.12,0.80),10)
	vehicle_style.content_margin_top=12
	vehicle_style.content_margin_bottom=12
	vehicle_panel.add_theme_stylebox_override("panel",vehicle_style)
	vehicle_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	vehicle_panel.anchor_left=1.0
	vehicle_panel.anchor_right=1.0
	vehicle_panel.anchor_top=1.0
	vehicle_panel.anchor_bottom=1.0
	vehicle_panel.grow_horizontal=Control.GROW_DIRECTION_BEGIN
	vehicle_panel.grow_vertical=Control.GROW_DIRECTION_BEGIN
	vehicle_panel.offset_right=-28
	vehicle_panel.offset_left=-28
	vehicle_panel.offset_bottom=-92
	vehicle_panel.offset_top=-92
	vehicle_panel.visible=false
	hud.add_child(vehicle_panel)
	speed_label=label("",19)
	speed_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	vehicle_panel.add_child(speed_label)
	hint_panel=PanelContainer.new()
	hint_panel.name="HintBar"
	hint_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_panel.grow_vertical=Control.GROW_DIRECTION_BEGIN
	hint_panel.offset_left=28
	hint_panel.offset_right=-28
	hint_panel.offset_top=-24
	hint_panel.offset_bottom=-24
	var hint_style=panel_style(Color(0.025,0.09,0.12,0.72),10)
	hint_style.content_margin_top=9
	hint_style.content_margin_bottom=9
	hint_panel.add_theme_stylebox_override("panel",hint_style)
	hint_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(hint_panel)
	hud.resized.connect(_layout_hud)
	var bottom=hint_panel
	context_hint=label("",14,Color("dfe7da"))
	context_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	context_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	context_hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bottom.add_child(context_hint)
	toast_panel=PanelContainer.new()
	toast_panel.name="Toast"
	var toast_style=panel_style(Color(0.02,0.07,0.09,0.78),12)
	toast_style.content_margin_top=12
	toast_style.content_margin_bottom=12
	toast_panel.add_theme_stylebox_override("panel",toast_style)
	toast_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	toast_panel.anchor_left=0.5
	toast_panel.anchor_right=0.5
	toast_panel.grow_horizontal=Control.GROW_DIRECTION_BOTH
	toast_panel.offset_top=104
	toast_panel.offset_bottom=104
	toast_panel.modulate.a=0
	hud.add_child(toast_panel)
	toast_label=label("",19,Color("f5e4b6"))
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	toast_panel.add_child(toast_label)
	save_indicator=label("",14,Color("a6d9c9"))
	save_indicator.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	save_indicator.position=Vector2(-260,30)
	save_indicator.size=Vector2(230,25)
	save_indicator.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(save_indicator)
	modal=PanelContainer.new()
	modal.position=Vector2(44,40)
	modal.size=Vector2(560,820)
	modal.theme_type_variation="ModalPanel"
	root.add_child(modal)
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(500,760)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	modal_content=VBoxContainer.new()
	modal_content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	modal_content.add_theme_constant_override("separation",11)
	scroll.add_child(modal_content)
	map_panel=Control.new()
	map_panel.set_script(load("res://scripts/harbor_map.gd"))
	map_panel.position=Vector2(595,75)
	map_panel.size=Vector2(780,735)
	map_panel.visible=false
	root.add_child(map_panel)
	map_panel.anchors=world.anchors
	map_panel.landmarks=landmark_catalog()
	if is_instance_valid(airport):map_panel.runway_data=airport.runway_data
	minimap=load("res://scripts/harbor_minimap.gd").new()
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.position=Vector2(-318,66)
	minimap.size=Vector2(290,244)
	hud.add_child(minimap)
	minimap.configure(map_panel)
	minimap.clicked.connect(map_menu)
	map_panel.waypoint_selected.connect(set_map_waypoint)
	map_panel.navigation_cleared.connect(clear_landmark_target)
	map_panel.close_requested.connect(close_panel)
	navigation_hud=load("res://scripts/navigation_guidance.gd").new()
	navigation_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(navigation_hud)
	fire_button=Button.new()
	fire_button.text="发射  ·  X / 鼠标左键"
	fire_button.tooltip_text="按住 Option / Alt 可直接点击；松开继续瞄准"
	fire_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	fire_button.position=Vector2(-256,90)
	fire_button.size=Vector2(226,58)
	fire_button.focus_mode=Control.FOCUS_NONE
	fire_button.visible=false
	fire_button.pressed.connect(func(): if can_fire_weapon(): weapons.fire_current())
	hud.add_child(fire_button)
	combat_reticle=label("╋",32,Color("ffe9ae"))
	combat_reticle.mouse_filter=Control.MOUSE_FILTER_IGNORE
	combat_reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	combat_reticle.position=Vector2(-18,-25)
	combat_reticle.size=Vector2(36,50)
	combat_reticle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	combat_reticle.visible=false
	hud.add_child(combat_reticle)
	life.service_completed.connect(on_service_completed)
	_layout_hud()

func _layout_hud():
	# Keep the control strip readable on ultrawide canvases instead of stretching edge to edge.
	if not is_instance_valid(hint_panel): return
	var side:=maxf(28.0,(hud.size.x-1180.0)*0.5)
	hint_panel.offset_left=side
	hint_panel.offset_right=-side

func panel_style(color:Color,radius:int) -> StyleBoxFlat:
	var style=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	style.content_margin_left=22
	style.content_margin_right=22
	style.content_margin_top=19
	style.content_margin_bottom=19
	return style

func label(text_value:String,sz:int=18,col:Color=Color("f1efdf")) -> Label:
	var l=Label.new()
	l.text=text_value
	l.add_theme_font_size_override("font_size",sz)
	l.add_theme_color_override("font_color",col)
	return l

func clear_panel(title:String,subtitle:String=""):
	if is_instance_valid(survival): survival.trigger_released = false
	var scroll:ScrollContainer=modal_content.get_parent()
	scroll.scroll_vertical=0
	for child in modal_content.get_children():
		modal_content.remove_child(child)
		child.queue_free()
	var eyebrow=Label.new()
	eyebrow.text="H A R B O U R L I F E"
	eyebrow.theme_type_variation="SectionLabel"
	modal_content.add_child(eyebrow)
	var heading=Label.new()
	heading.text=title
	heading.theme_type_variation="TitleLabel"
	heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size.x=470
	modal_content.add_child(heading)
	if subtitle!="":
		var sub=Label.new()
		sub.text=subtitle
		sub.theme_type_variation="QuietLabel"
		sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size.x=470
		modal_content.add_child(sub)
	modal_content.add_child(HSeparator.new())
	_pad_focus_pending=true
	modal.visible=true
	hud.visible=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if active:
		paused=true
		get_tree().paused=true
	process_mode=Node.PROCESS_MODE_ALWAYS
	map_panel.visible=false
	if is_instance_valid(minimap): minimap.visible=false
	if is_instance_valid(navigation_hud): navigation_hud.visible=false

func button(text_value:String,action:Callable,variant:String=""):
	var b=Button.new()
	b.text=text_value
	b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	if variant!="": b.theme_type_variation=variant
	b.pressed.connect(action)
	modal_content.add_child(b)
	_focus_for_pad(b)
	return b

func _focus_for_pad(control:Control):
	# Controller players need a focused control; mouse and keyboard players keep the old behaviour.
	if _pad_focus_pending and _using_pad:
		_pad_focus_pending=false
		control.call_deferred("grab_focus")

func main_menu():
	if is_instance_valid(weapons): weapons.clear()
	active_panel="main"
	hud.visible=false
	clear_panel("属于你的海港。","A life by the water. · 悉尼核心海港 · 单人离线世界")
	section("开始新世界")
	name_edit=LineEdit.new()
	name_edit.placeholder_text="为你的世界取个名字"
	name_edit.text="我的悉尼"
	name_edit.custom_minimum_size.y=46
	modal_content.add_child(name_edit)
	button("奶龙危机 · 开始生存  →",func(): new_world("life",name_edit.text),"PrimaryButton")
	button("自由观光 · 无敌人  →",func(): new_world("sandbox",name_edit.text),"PrimaryButton")
	if is_instance_valid(airport): button("机场出发 · 奶龙危机  ↗",airport_start)
	note(GameSettings.keys("奶龙跟随所在街区持续增援 · 免费弹药、免费载具\n{auto_support} 自动锁定 · {heal} 急救 / 快修 · {survival_services} 战地升级 · {map} 地图"))
	var worlds=[] if qa_running else Store.slots()
	if not worlds.is_empty():
		section("继续你的世界")
		for entry in worlds.slice(0,4):
			if entry.mode=="sandbox":
				button(str(entry.name)+" · 继续并开启奶龙危机",func():
					load_world(entry.id)
					if active and world_id==entry.id: enable_encounters())
				button("继续原有观光 · 无敌人 · "+str(entry.name),func(): load_world(entry.id),"GhostButton")
			else: button(str(entry.name)+" · 继续奶龙危机",func(): load_world(entry.id))
	section("其他")
	button("存档与恢复",worlds_menu,"GhostButton")
	button("操作与设置",settings_menu,"GhostButton")
	button("制作与资料来源",credits_menu,"GhostButton")
	button("退出",func(): get_tree().quit(),"GhostButton")
	note("v"+str(ProjectSettings.get_setting("application/config/version"))+" · 离线单人 · 不需要账号")

func close_panel():
	modal.visible=false
	map_panel.visible=false
	hud.visible=active
	if is_instance_valid(minimap): minimap.visible=active
	if is_instance_valid(navigation_hud): navigation_hud.visible=active
	paused=false
	get_tree().paused=false
	active_panel=""
	sync_mouse_capture()
	process_mode=Node.PROCESS_MODE_ALWAYS

func _diagnostics_toggled(opened:bool):
	if opened:
		_diagnostics_previous_pause=paused
		paused=true
		get_tree().paused=true
		_cursor_held=false
		fire_button.visible=false
		combat_reticle.visible=false
	else:
		paused=_diagnostics_previous_pause
		get_tree().paused=paused
	sync_mouse_capture()

func sync_mouse_capture():
	# Menus own the pointer even if opened while a vehicle or a modifier is active.
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if active and not paused and not modal.visible and not map_panel.visible and not _cursor_held else Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(minimap): minimap.cursor_released=_cursor_held

func camera_accepts_mouse() -> bool:
	return active and not paused and not modal.visible and not map_panel.visible and not _cursor_held and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED

func new_world(new_mode:String,new_name:String,save_now=true):
	if active and not save_world(): return
	close_panel()
	world_id="world_"+str(Time.get_unix_time_from_system()).replace(".","_")
	world_name=new_name.strip_edges() if not new_name.strip_edges().is_empty() else "我的悉尼"
	mode=new_mode
	if is_instance_valid(city_clock):city_clock.apply_state({})
	world.repair_all()
	if is_instance_valid(airport) and airport.has_method("repair_all"): airport.repair_all()
	life.setup(world.anchors,mode=="sandbox")
	owned=VEHICLE_NAMES.keys()
	landmark_target_key=""
	landmark_target_name=""
	if is_instance_valid(survival): survival.reset_mode(mode!="sandbox")
	if is_instance_valid(survival) and survival.enabled: life.status_text=GameSettings.keys("奶龙持续增援 · 击败赚金币 · 无需清完上一批\n{heal} 急救 / 快修 · {survival_services} 战地升级 · {auto_support} 自动武器")
	if is_instance_valid(campaign): campaign.start_new()
	if is_instance_valid(districts): districts.reset()
	if is_instance_valid(street): street.clear()
	reset_fleet()
	player.global_position=world.anchors.get("home",Vector3(-140,6,150))+Vector3(0,1,15)
	player.last_safe=player.global_position
	player.velocity=Vector3.ZERO
	player.reset_physics_interpolation()
	reset_follow_camera()
	player.visible=true
	player.enabled=true
	player.collision_layer=1
	player.collision_mask=15
	active=true
	sync_mouse_capture()
	hud.visible=true
	minimap.visible=true
	navigation_hud.visible=true
	yaw=0
	pitch=-0.17
	autosave=0
	notify("$50,000 已到账 · 12 秒保护，奶龙正在接近\n左键反击 / Tab 武装载具 · H 急救 / 快修 · B 升级" if is_instance_valid(survival) and survival.enabled else "自由观光 · 奶龙刷新关闭 · B 可原地开启奶龙危机")
	if save_now: save_world()

func enable_encounters():
	if not active or survival.enabled: return
	mode="life"
	life.sandbox=false
	# Preserve the current world, purse, fleet, health and acquired upgrades.
	survival.enabled=true
	survival.auto_spawn=true
	survival.grace=12.0
	survival._spawn_clock=0.6
	survival.rest=0.0
	life.status_text=GameSettings.keys("奶龙跟随街区持续增援 · 击败赚金币\n{heal} 急救 / 快修 · {survival_services} 升级 · {auto_support} 自动武器")
	close_panel()
	notify("奶龙危机已开启 · 保留当前财富、载具与位置\n12 秒保护，奶龙正在接近 · Tab 新增武装载具")

func reset_fleet(with_defaults: bool = true):
	if is_instance_valid(weapons): weapons.clear()
	current_vehicle=null
	for v in vehicles:
		remove_child(v)
		v.queue_free()
	vehicles.clear()
	spawn_target=null
	if is_instance_valid(spawn_marker): spawn_marker.visible=false
	if not with_defaults: return
	var home=world.anchors.get("home",Vector3(-140,6,150))
	var marina=world.anchors.get("marina",Vector3(-240,1,-330))
	var helipad=world.anchors.get("helipad",Vector3(-280,8,-250))
	var placements={"car":home+Vector3(12,1,6),"motorcycle":home+Vector3(18,1,6),"hoverboard":home+Vector3(22,1,6),"speedboat":Vector3(marina.x-8.5,0.9,marina.z-28),"yacht":Vector3(marina.x-30,0.9,marina.z-64),"helicopter":helipad+Vector3(0,3,0),"paraglider":world.anchors.get("north",Vector3(50,5,-1350))+Vector3(40,90,0),"glider":Vector3(700,230,-1600),"airliner":Vector3(-4180,10.78,8600),"tank":home+Vector3(35,2,6),"fighter":Vector3(680,250,-1600)}
	for kind in VEHICLE_NAMES:
		var v=make_vehicle(kind,"owned_"+kind,placements[kind])
		# Place parked contact geometry just above its authored support surface.
		# The new world has not necessarily flushed its Jolt broad phase yet.
		if kind in ["car","motorcycle","helicopter","tank"]:
			var support:float=helipad.y-.20 if kind=="helicopter" else world.GROUND
			v.position.y=support-VehicleSpawn.envelope(v).position.y+.12
			v.reset_physics_interpolation()
		if kind in ["paraglider","glider","airliner","fighter"]: v.freeze=true
		if kind=="airliner" and is_instance_valid(airport):
			v.rotation.y=airport.runway_heading
			v.throttle=0.0

func make_vehicle(kind:String,id:String,pos:Vector3):
	var v=load("res://scripts/harbor_vehicle.gd").new()
	v.configure(kind,id)
	v.survival_enabled=true
	v.combat_owner=self
	v.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(v)
	v.global_position=pos
	v.reset_physics_interpolation()
	v.impacted.connect(on_impact.bind(v))
	vehicles.append(v)
	if is_instance_valid(survival): survival.apply_fleet_to(v)
	return v

func on_impact(point:Vector3,energy:float,source:RigidBody3D=null):
	world.damage_at(point,energy,clampf(sqrt(energy)*0.005,2,28))
	life.on_incident(point,energy,is_instance_valid(source) and source==current_vehicle)
	if is_instance_valid(airport) and airport.has_method("apply_impact"): airport.apply_impact(point,energy)
	if energy>8000: audio.crash(point)

func can_fire_weapon() -> bool:
	return active and not paused and not modal.visible and not map_panel.visible and is_instance_valid(current_vehicle) and current_vehicle.occupied and current_vehicle.health>0 and current_vehicle.kind in ["tank","fighter"]

func can_auto_fire_weapon() -> bool:
	return active and not paused and not modal.visible and not map_panel.visible and is_instance_valid(survival) and survival.enabled and is_instance_valid(current_vehicle) and current_vehicle.occupied and current_vehicle.health>0

func apply_combat_blast(point:Vector3,energy:float,radius:float,source:RigidBody3D) -> void:
	if is_instance_valid(combat_feel) and is_instance_valid(camera):
		var reach:float=camera.global_position.distance_to(point)
		combat_feel.shake(clampf(radius*0.02*(1.0-clampf(reach/90.0,0.0,1.0)),0.0,0.5))
	world.damage_at(point,energy,radius)
	if is_instance_valid(airport): airport.apply_impact(point,energy)
	_allow_combat_debris_passage(source)
	life.on_incident(point,energy,source==current_vehicle)
	audio.crash(point)

func break_combat_contact(source:RigidBody3D,collider:Object,point:Vector3) -> bool:
	if not is_instance_valid(collider) or not source.can_crush_buildings(): return false
	if collider.has_meta("damage_id"):
		var id:=str(collider.get_meta("damage_id"))
		if not world.structures.has(id): return false
		if world.destroyed.has(id): return true
		world._destroy_component(id,point,maxf(10000000.0,source.mass*source.linear_velocity.length_squared()),true)
		_allow_combat_debris_passage(source)
		return true
	if collider.has_meta("airport_damage_id") and is_instance_valid(airport):
		var id:=str(collider.get_meta("airport_damage_id"))
		if not airport._panels.has(id): return false
		airport._break_panel(id,true)
		_allow_combat_debris_passage(source)
		return true
	# Physical rubble can be pushed aside; terrain and anonymous support remain solid.
	return false

func _allow_combat_debris_passage(source:RigidBody3D) -> void:
	if not is_instance_valid(source) or not source.can_crush_buildings(): return
	# Fresh fragments otherwise spawn inside the moving hull before their first broad phase.
	# These bounded rubble bodies stay physical for other traffic and the player.
	for piece in world.rubble:
		if is_instance_valid(piece): piece.add_collision_exception_with(source)
	if is_instance_valid(airport):
		for piece in airport._fragments:
			if is_instance_valid(piece): piece.add_collision_exception_with(source)

func combat_ram_feedback(source:RigidBody3D,point:Vector3,count:int) -> void:
	if is_instance_valid(source): source.take_combat_damage(minf(24.0, count*3.0))
	if is_instance_valid(weapons): weapons.impact_effect(point,1.0+minf(count,5)*0.12)
	life.on_incident(point,10000000.0,source==current_vehicle)
	audio.crash(point)

func save_world() -> bool:
	if not active or world_id=="": return false
	var data={"name":world_name,"mode":mode,"player":vec(player.global_position),"yaw":yaw,"pitch":pitch,"owned":owned,"world":world.get_state(),"airport":airport.get_state() if is_instance_valid(airport) else {},"life":life.get_state(),"vehicles":[],"settings":settings,"elapsed":elapsed,"vehicle":current_vehicle.vehicle_id if is_instance_valid(current_vehicle) else "","spawn_target":spawn_target.vehicle_id if is_instance_valid(spawn_target) else ""}
	for v in vehicles: data.vehicles.append(v.get_state())
	data["map_revision"]=preload("res://scripts/map_migration.gd").REVISION
	data["navigation"]={"key":landmark_target_key,"title":landmark_target_name,"position":vec(landmark_target_position)}
	if is_instance_valid(city_clock):data["city_clock"]=city_clock.get_state()
	if is_instance_valid(survival): data["survival"]=survival.get_state()
	if is_instance_valid(campaign): data["campaign"]=campaign.get_state()
	if is_instance_valid(districts): data["districts"]=districts.get_state()
	var ok=Store.write(world_id,data)
	save_indicator.text="已保存 · "+Time.get_time_string_from_system() if ok else "保存失败"
	if not ok: notify(Store.last_error,false)
	return ok

func load_world(id:String,backup=false):
	var data=Store.read(id,backup)
	if data.is_empty():
		notify("无法读取世界 · "+Store.last_error,false)
		return
	if active and id!=world_id and not save_world(): return
	active=false
	new_world(str(data.get("mode","life")),str(data.get("name","World")),false)
	world_id=id
	# Every class is available in old and new worlds; saved instances keep their IDs.
	owned=VEHICLE_NAMES.keys()
	world.apply_state(data.get("world",{}))
	if is_instance_valid(airport): airport.apply_state(data.get("airport",{}))
	life.apply_state(data.get("life",{}))
	player.global_position=unvec(data.get("player",vec(player.global_position)))
	player.velocity=Vector3.ZERO
	player.last_safe=player.global_position
	yaw=float(data.get("yaw",0))
	pitch=float(data.get("pitch",-0.17))
	elapsed=float(data.get("elapsed",0))
	if is_instance_valid(city_clock):city_clock.apply_state(data.get("city_clock",{}))
	# Restore the actual fleet, including every independent user-created instance.
	# Saves from the fixed-seven version already include kind/id and need no migration.
	if data.has("vehicles"):
		reset_fleet(false)
		var restored_ids := {}
		for state in data.vehicles:
			var kind := str(state.get("kind","car"))
			if not VEHICLE_NAMES.has(kind): continue
			var id_value := str(state.get("vehicle_id",state.get("id","")))
			if id_value.is_empty() or restored_ids.has(id_value): id_value = next_vehicle_id(kind)
			restored_ids[id_value] = true
			var v = make_vehicle(kind,id_value,unvec(state.position))
			v.apply_state(state)
			v.set_meta("loaded_model_revision",int(state.get("model_revision",0)))
			v.occupied=false
	var occupied_id=str(data.get("vehicle",""))
	var target_id=str(data.get("spawn_target",""))
	var relocated:=0
	if int(data.get("map_revision",0))<preload("res://scripts/map_migration.gd").REVISION:
		relocated=preload("res://scripts/map_migration.gd").apply(self)
		relocated+=preload("res://scripts/map_migration.gd").repair_old_approach(self,occupied_id)
	var model_adjustments:Array=preload("res://scripts/vehicle_model_migration.gd").apply(self,occupied_id)
	if is_instance_valid(survival): survival.apply_state(data.get("survival",{}))
	# Worlds saved before the campaign existed start chapter one from the first step.
	if is_instance_valid(campaign): campaign.apply_state(data.get("campaign",{}))
	if is_instance_valid(districts): districts.apply_state(data.get("districts",{}))
	set_meta("last_vehicle_model_adjustments",model_adjustments)
	for v in vehicles:
		if v.vehicle_id==occupied_id: enter_vehicle(v)
		if v.vehicle_id==target_id: spawn_target=v
	restore_navigation(data.get("navigation",{}))
	player.reset_physics_interpolation()
	reset_follow_camera()
	notify("世界已恢复 · %d 处地图位置、%d 个旧载具停车位已安全调整"%[relocated,model_adjustments.size()] if relocated>0 or not model_adjustments.is_empty() else "世界已恢复 · 载具、目的地与城市足迹已读取")

func vec(value:Vector3) -> Array:
	return [value.x,value.y,value.z]

func unvec(value) -> Vector3:
	if value is Array and value.size()==3: return Vector3(float(value[0]),float(value[1]),float(value[2]))
	return Vector3.ZERO

func worlds_menu():
	active_panel="worlds"
	clear_panel("你的世界","存档自动保留上一次写入的恢复副本。复制后可独立实验。")
	for entry in Store.slots():
		modal_content.add_child(label(str(entry.name)+" · "+str(entry.saved),16))
		button("继续  ·  "+entry.id.right(10),func(): load_world(entry.id))
		button("复制这个世界",func():
			var new_id=Store.duplicate_world(entry.id)
			if new_id!="": worlds_menu()
			else: notify(Store.last_error,false))
		button("读取上一次恢复副本",func(): load_world(entry.id,true))
	button("返回",pause_menu if active else main_menu)

func pause_menu():
	active_panel="pause"
	clear_panel("海港会等你。",world_name+"  /  "+("自由沙盒" if mode=="sandbox" else "生活模式"))
	button("继续游玩",close_panel,"PrimaryButton")
	section("这一趟")
	if is_instance_valid(campaign): button(campaign.menu_label(),objectives_menu)
	button("工作与活动",jobs_menu)
	button("城市体验 · 美食、场馆与海滨",experiences_menu)
	button("我的载具",vehicles_menu)
	button("地图与位置",map_menu)
	button("拍照 · 关闭菜单后拍摄",photo_from_menu)
	section("战斗与世界")
	if is_instance_valid(districts): button(districts_label(),districts_menu)
	if not survival.enabled: button("开启奶龙危机 · 保留当前世界与财富",enable_encounters)
	button("战地补给与武器升级  ·  B",survival_menu)
	button("时间与晚霞  ·  T",time_menu)
	button("保存世界",func():
		if save_world(): notify("世界已保存"))
	section("设置与存档")
	button("设置与操作",settings_menu,"GhostButton")
	button("存档与恢复",worlds_menu,"GhostButton")
	section("卡住了？")
	button("返回个人空间 · 救援",recover_player)
	button("找回遗失货物",func(): notify(life.recover_cargo()))
	button("修复建筑 · "+("免费" if mode=="sandbox" else "$500"),func():
		if mode=="sandbox" or life.spend(500,"世界修缮"):
			world.repair_all()
			airport.repair_all()
			notify("海港与机场建筑已修复"))
	section("离开")
	button("保存并回到标题",func():
		if save_world():
			active=false
			for v in vehicles: v.occupied=false
			player.enabled=false
			get_tree().paused=false
			main_menu())
	button("保存并退出",quit_game,"GhostButton")

func jobs_menu():
	active_panel="jobs"
	clear_panel("今天想做什么？","不同路线、工具和交通方式，都在同一片海港里。")
	modal_content.add_child(label(life.status_text,16,Color("91d1c2")))
	for job in life.job_catalog():
		var desc=label(str(job.get("description","")),15,Color("b9c8c4"))
		desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x=430
		button(str(job.get("title",job.id))+"   $"+str(job.get("reward",0)),func():
			var message=life.start_job(job.id)
			close_panel()
			notify(message))
		modal_content.add_child(desc)
	button("取消当前活动",func(): notify(life.cancel_job()); close_panel())
	button("返回",close_panel)

func experiences_menu():
	active_panel="experiences"
	clear_panel("来悉尼，玩得开心。","口袋里还有 $%d · 载具始终免费。选一个地方去逛逛，留下你的城市足迹。\nK 随时打开体验菜单，M 查看方向与距离。"%life.money)
	var visits:Dictionary=life.get_state().get("experience_visits",{})
	modal_content.add_child(label("已体验 %d 个项目 · 每个项目都可再次参与"%visits.size(),17,Color("a2efe0")))
	var services:Array=life.service_catalog()
	services.sort_custom(func(a,b): return player.global_position.distance_squared_to(a.position)<player.global_position.distance_squared_to(b.position))
	for service in services:
		var distance:float=Vector2(service.position.x-player.global_position.x,service.position.z-player.global_position.z).length()
		var reachable:bool=player.global_position.distance_to(service.position)<=float(service.radius)
		var tag:=" · 已体验" if visits.has(str(service.id)) else ""
		button(str(service.title)+" · $%d"%int(service.cost)+tag,func():
			if reachable:
				var result:Dictionary=life.use_service(str(service.id),player.global_position,not is_instance_valid(current_vehicle))
				if bool(result.get("ok",false)): close_panel()
				elif not str(result.get("message","")).is_empty(): notify(str(result.message),false)
			else: set_map_waypoint(service.position,str(service.title)))
		var detail:=label(("就在附近 · 点击体验" if reachable else (("%.2f km"%(distance/1000)) if distance>=1000 else "%.0f m"%distance)+" · 点击标记前往")+"  /  恢复耐力",14,Color("aac2b9"))
		modal_content.add_child(detail)
	button("可重复的轻松工作 · 赚取旅费",jobs_menu)
	button("继续探索",close_panel)

func on_service_completed(result:Dictionary):
	var effects:Dictionary=result.get("effects",{})
	player.stamina=minf(100.0,player.stamina+float(effects.get("stamina_restore",0)))
	update_hud()

func vehicles_menu():
	active_panel="vehicles"
	clear_panel("新增载具，立即出发。","全部免费 · 点击即生成并入座。\n同款载具共享耐久与火控等级；新增不会洗掉损伤，B 可维修升级。")
	survival.sync_fleet()
	for kind in VEHICLE_NAMES:
		button(VEHICLE_NAMES[kind]+" · 耐久 %d%%"%int(survival.fleet_health.get(kind,100)),func(): request_vehicle(kind))
	if is_instance_valid(current_vehicle):
		button("维修、补给与火控升级  ·  B",survival_menu)
	button("机场跑道起飞",airport_start)
	button("返回",close_panel)

func survival_menu():
	if not active or not is_instance_valid(survival): return
	survival.sync_fleet()
	active_panel="survival"
	clear_panel("战地整备。","金币 $%d · 弹药免费 · 同款载具共享耐久和升级\n补给、升级与快修可在战斗中使用；打开面板暂停战斗。"%life.money)
	if not survival.enabled:
		modal_content.add_child(label("当前为自由观光：奶龙刷新已关闭。",18,Color("f3cb80")))
		button("开启奶龙危机 · 保留财富与当前位置",enable_encounters)
	var blocked:String=survival.service_block_reason()
	if not blocked.is_empty():
		var reason=label(blocked,17,Color("f3cb80"))
		reason.text=GameSettings.keys("完整维修需安全停车；战斗中可用 {heal} 快修。")
		reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		modal_content.add_child(reason)
	modal_content.add_child(label("生命 %d / 120 · 医疗包 %d / 5"%[player.health,survival.medkits],19))
	var medicine=button("补充医疗包  ·  $300  ·  H 恢复 60 生命",func(): _survival_transaction("medkit"))
	medicine.disabled=survival.medkits>=5 or life.money<300
	if is_instance_valid(current_vehicle):
		var fitted:Array=survival.weapon_loadout(current_vehicle.kind)
		button("选装武器 · %d / 3 槽\n机关枪 / 范围炮 / 激光 / 闪电"%fitted.size(),armory_menu)
		var field_cost:int=survival.field_repair_cost()
		var field_reason:String=survival.service_block_reason("field_repair")
		var quick=button("H 快修最多 +25%% 耐久 · $%d · 12 秒冷却"%field_cost,func(): _survival_transaction("field_repair"))
		quick.disabled=not survival.enabled or field_cost<=0 or life.money<field_cost or not field_reason.is_empty()
		if not field_reason.is_empty(): modal_content.add_child(label(field_reason,15,Color("f3cb80")))
		var auto=weapons.auto_status()
		button("V 自动辅助武器 · "+("已开启" if auto.enabled else "已关闭")+" · 免费追踪弹",func():
			weapons.set_auto_enabled(not weapons.auto_enabled())
			survival_menu())
	if is_instance_valid(current_vehicle) and current_vehicle.fuel < 100.0:
		var energy_cost:int=ceili((100.0-current_vehicle.fuel)*3.0)
		var energy=button("当前载具补满能源 · %d%% → 100%% · $%d"%[current_vehicle.fuel,energy_cost],func(): _survival_transaction("refuel"))
		energy.disabled=not survival.service_block_reason("refuel").is_empty() or life.money<energy_cost
	if is_instance_valid(current_vehicle) and current_vehicle.kind in ["tank","fighter"]:
		var level:int=current_vehicle.weapon_upgrade
		var stats:Dictionary=weapons.upgrade_stats(current_vehicle.kind,level)
		modal_content.add_child(label("火控 %s · 伤害 %.0f · 半径 %.1f m · 装填 %.2f s"%[["基础","I","II","III"][level],stats.current.damage,stats.current.radius,stats.current.cooldown],17,Color("96ddc7")))
		if level<3:
			var cost:int=survival.UPGRADE_COSTS[level]
			modal_content.add_child(label("下一级：伤害 %.0f · 半径 %.1f m · 装填 %.2f s"%[stats.next.damage,stats.next.radius,stats.next.cooldown],16))
			var upgrade=button("升级火控到 %s 级  ·  $%d"%[["I","II","III"][level],cost],func(): _survival_transaction("upgrade"))
			upgrade.disabled=life.money<cost
		else: modal_content.add_child(label("已达到最高火控等级",16))
	else: modal_content.add_child(label("进入坦克或战斗机，即可升级火控。",16,Color("a9c0bc")))
	modal_content.add_child(label("车队维修",22))
	var damaged:=false
	for kind in VEHICLE_NAMES:
		var health:float=survival.fleet_health.get(kind,100.0)
		if health>=100.0: continue
		damaged=true
		var cost:int=survival.repair_cost(kind)
		var repair=button("%s · %d%% → 100%% · $%d"%[VEHICLE_NAMES[kind].split(" · ")[1],health,cost],func(): _survival_transaction("repair",kind))
		repair.disabled=not blocked.is_empty() or life.money<cost
	if not damaged: modal_content.add_child(label("所有车型耐久良好",16,Color("96ddc7")))
	var rescue=button("呼叫救援  ·  最多 $500  ·  返回个人空间",func(): survival.rescue())
	rescue.tooltip_text="保留金币余额与火控升级，受损载具不会自动修复"
	button("继续探索  ·  Esc",close_panel)

func _survival_transaction(action:String,kind:String=""):
	var result:Dictionary=survival.transact(action,kind)
	survival_menu()
	notify(str(result.message),bool(result.ok))

func register_combat_enemy(enemy:Node3D):
	if is_instance_valid(combat_feedback): combat_feedback.register_enemy(enemy)

func reset_combat_feedback():
	if is_instance_valid(combat_feedback): combat_feedback.clear()

func armory_menu():
	if not active or not is_instance_valid(current_vehicle): return
	var modules=preload("res://scripts/weapon_modules.gd")
	var kind:String=current_vehicle.kind
	var fitted:Array=survival.weapon_loadout(kind)
	active_panel="armory"
	clear_panel("武器选装。","%s · 金币 $%d\n三个额外槽位 · 同款共享 · 弹药免费 · V 控制全部自动武器"%[VEHICLE_NAMES[kind].split(" · ")[0],life.money])
	modal_content.add_child(label("已装配 %d / 3 · 原有免费副炮不占槽"%fitted.size(),19,Color("96ddc7")))
	for item:Dictionary in fitted:
		button("%s %s · 卸下（保留等级）"%[modules.CATALOG[item.id].label,["I","II","III"][item.level-1]],func(): _module_transaction("unequip",item.id))
	if fitted.is_empty(): modal_content.add_child(label("买第一件模块后会自动装入空槽。",16))
	var threat=label("增援 Lv.%d · 随战斗进度与装配逐步成长；升级不会给场上敌人加血。"%survival.encounter_level(),15,Color("a9c0bc"))
	threat.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	modal_content.add_child(threat)
	for id:String in modules.CATALOG:
		var tier:int=survival.armory.level(kind,id)
		var data:Dictionary=modules.CATALOG[id]
		modal_content.add_child(label(data.label+" · "+(["I","II","III"][tier-1]+" 级" if tier>0 else "未解锁"),23,modules.COLORS[id]))
		var description=label(data.description,16)
		description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		modal_content.add_child(description)
		var stats:Dictionary=modules.spec(id,maxi(1,tier))
		var detail:String="伤害 %.0f · 间隔 %.2f s · 射程 %.0f m"%[stats.damage,stats.cooldown,stats.range]
		if stats.radius>0: detail+=" · 半径 %.0f m"%stats.radius
		if stats.chain_count>1: detail+=" · 连锁 %d 个"%stats.chain_count
		var stat_label=label(detail,15)
		stat_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		modal_content.add_child(stat_label)
		if tier<3:
			var price:int=modules.cost(id,tier)
			var action:String="购买并装配" if fitted.size()<3 else "购买到仓库"
			if tier>0:
				var next:Dictionary=modules.spec(id,tier+1)
				action="升级到 %s · 伤害 %.0f / %.2f s"%[["II","III"][tier-1],next.damage,next.cooldown]
			var buy=button(action+" · $%d"%price,func(): _module_transaction("buy",id))
			buy.disabled=life.money<price or current_vehicle.health<=0.0
		if tier>0 and not survival.armory.is_equipped(kind,id):
			var equip=button("免费装配 "+data.label,func(): _module_transaction("equip",id))
			equip.disabled=fitted.size()>=3 or current_vehicle.health<=0.0
	button("返回战地整备",survival_menu)
	button("继续战斗 · Esc",close_panel)

func _module_transaction(action:String,id:String):
	var result:Dictionary=survival.transact_module(action,id)
	armory_menu()
	notify(str(result.message),bool(result.ok))

func next_vehicle_id(kind:String) -> String:
	spawn_sequence+=1
	return "spawn_%s_%d_%d_%s"%[kind,Time.get_ticks_usec(),spawn_sequence,Crypto.new().generate_random_bytes(6).hex_encode()]

func request_vehicle(kind:String):
	if not VEHICLE_NAMES.has(kind): return null
	survival.sync_fleet()
	if float(survival.fleet_health.get(kind,100.0))<=0.0:
		notify("这款载具已损毁 · B 可远程维修车队，或使用其他车型",false)
		return null
	var request_started:=Time.get_ticks_usec()
	# Placement succeeds before changing the driver. Failure preserves the current ride.
	var v=make_vehicle(kind,next_vehicle_id(kind),Vector3(0,-2000,0))
	v.freeze=true
	v.visible=false
	var model_finished:=Time.get_ticks_usec()
	var geometry_started:=Time.get_ticks_usec()
	preload("res://scripts/map_migration.gd")._geometry(world)
	var geometry_finished:=Time.get_ticks_usec()
	var placement=VehicleSpawn.find_spawn(self,v)
	var placement_finished:=Time.get_ticks_usec()
	set_meta("last_spawn_profile",{"kind":kind,"model_ms":(model_finished-request_started)/1000.0,"occupancy_cache_ms":(geometry_finished-geometry_started)/1000.0,"placement_ms":(placement_finished-geometry_finished)/1000.0,"ready":not placement.is_empty()})
	get_meta("last_spawn_profile")["factory"]=v.get_meta("vehicle_factory_profile",{}).duplicate(true)
	if placement.is_empty():
		vehicles.erase(v)
		remove_child(v)
		v.queue_free()
		notify("附近没有足够的安全空间 · 移到开阔处后重试；现有载具保持原位",false)
		return null
	if not kind in owned: owned.append(kind)
	finish_vehicle_spawn(v,placement)
	yaw=v.rotation.y
	pitch=-0.10 if kind in ["car","motorcycle","hoverboard"] else -0.17
	enter_vehicle(v)
	close_panel()
	get_meta("last_spawn_profile")["total_ms"]=(Time.get_ticks_usec()-request_started)/1000.0
	notify("已免费新增并入座 · %s\n%s · B 整备，E 离舱"%[VEHICLE_NAMES[kind],placement.description])
	return v

func finish_vehicle_spawn(v:RigidBody3D,placement:Dictionary):
	v.global_transform=placement.transform
	v.linear_velocity=Vector3.ZERO
	v.angular_velocity=Vector3.ZERO
	v.throttle=0.0
	v.freeze=bool(placement.get("airborne",false))
	v.sleeping=false
	v.visible=true
	v.reset_physics_interpolation()
	spawn_target=v
	update_spawn_marker()

func update_spawn_marker():
	if not is_instance_valid(spawn_marker):
		spawn_marker=label("",17,Color("ffe58b"))
		spawn_marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
		spawn_marker.add_theme_color_override("font_shadow_color",Color.BLACK)
		spawn_marker.add_theme_constant_override("shadow_offset_x",2)
		spawn_marker.add_theme_constant_override("shadow_offset_y",2)
		hud.add_child(spawn_marker)
	spawn_marker.visible=active and is_instance_valid(spawn_target) and spawn_target!=current_vehicle
	if not spawn_marker.visible: return
	var position3d:Vector3=spawn_target.get_global_transform_interpolated().origin+Vector3.UP*(VehicleSpawn.envelope(spawn_target).end.y+2.5)
	var delta_position:Vector3=spawn_target.global_position-player.global_position
	var distance=delta_position.length()
	var direction="北" if absf(delta_position.z)>absf(delta_position.x) and delta_position.z<0 else ("南" if absf(delta_position.z)>absf(delta_position.x) else ("东" if delta_position.x>0 else "西"))
	spawn_marker.text="◆ %s · %.0f m · %s
靠近 E 再次进入 · Tab 新增载具"%[VEHICLE_NAMES[spawn_target.kind],distance,direction]
	var screen_size=get_viewport().get_visible_rect().size
	var point=Vector2(screen_size.x*0.5,100) if camera.is_position_behind(position3d) else camera.unproject_position(position3d)
	spawn_marker.position=Vector2(clampf(point.x-spawn_marker.size.x*0.5,24,screen_size.x-spawn_marker.size.x-24),clampf(point.y,95,screen_size.y-spawn_marker.size.y-140))

func nearest_vehicle():
	var nearest=null
	var distance=7.0
	for v in vehicles:
		var dist=player.global_position.distance_to(v.global_position)
		var allowed=42.0 if v.kind=="airliner" else (12.0 if v.kind=="yacht" else 7.0)
		if v.kind in ["yacht","speedboat"]:
			allowed=maxf(allowed,v.get_exit_position().distance_to(v.global_position)+2.0)
		if dist<allowed and (nearest==null or dist<distance):
			nearest=v
			distance=dist
	return nearest

func enter_vehicle(v):
	if not is_instance_valid(v): return
	if is_instance_valid(survival): survival.sync_fleet()
	if not v.kind in owned: owned.append(v.kind)
	if is_instance_valid(current_vehicle) and current_vehicle!=v:
		current_vehicle.occupied=false
	current_vehicle=v
	_combat_aim_clock=0.0
	var was_frozen:bool=v.freeze
	v.freeze=false
	v.prepare_for_boarding(was_frozen)
	v.occupied=true
	player.enabled=false
	player.visible=false
	player.collision_layer=0
	player.collision_mask=0
	camera_distance=v.get_camera_distance()
	player.global_position=v.global_position
	player.velocity=Vector3.ZERO
	player.reset_physics_interpolation()
	v.reset_physics_interpolation()
	reset_follow_camera()
	notify("已进入 "+VEHICLE_NAMES[v.kind]+"\n操作见底部 · B 维修升级，E 离舱")

func exit_vehicle():
	if not is_instance_valid(current_vehicle): return
	var v=current_vehicle
	v.occupied=false
	var exit_pos=v.get_exit_position()
	if v.kind in ["yacht","speedboat"]:
		for side in [1,-1]:
			var candidate=v.global_position+v.global_basis.x*side*5.5
			var dock_ray=PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*5,candidate-Vector3.UP*3,1,[v.get_rid(),player.get_rid()])
			var dock=get_world_3d().direct_space_state.intersect_ray(dock_ray)
			if not dock.is_empty() and dock.position.y>1:
				exit_pos=dock.position+Vector3.UP*0.4
				break
	var ray=PhysicsRayQueryParameters3D.create(exit_pos+Vector3.UP*3,exit_pos-Vector3.UP*9)
	ray.exclude=[v.get_rid(),player.get_rid()]
	var hit=get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): exit_pos=hit.position+Vector3.UP*0.25
	player.global_position=exit_pos
	player.velocity=v.linear_velocity.limit_length(18)
	player.enabled=true
	player.visible=true
	player.collision_layer=1
	player.collision_mask=15
	current_vehicle=null
	camera_distance=7
	player.reset_physics_interpolation()
	reset_follow_camera()
	notify("已离开载具 · 高空离舱会自由落体，可 Tab 调用滑翔伞")

func repair_vehicle():
	if is_instance_valid(survival): survival_menu()

func recover_player():
	if is_instance_valid(survival) and survival.enabled:
		survival.rescue()
		return
	if is_instance_valid(current_vehicle): exit_vehicle()
	player.global_position=world.anchors.get("home",Vector3(-140,6,150))+Vector3.UP*2
	player.velocity=Vector3.ZERO
	player.reset_physics_interpolation()
	reset_follow_camera()
	player.last_safe=player.global_position
	close_panel()
	notify("已返回个人空间 · 载具可从车库重新调用")

func landmark_catalog() -> Array:
	var catalog: Array=[]
	var options=[
		[["opera"],"悉尼歌剧院"],
		[["bridge","harbour_bridge"],"悉尼海港大桥"],
		[["quay"],"Circular Quay · 环形码头"],
		[["ribbon","w_sydney","w_hotel","city_w_sydney"],"W Sydney · 达令港"],
		[["tower_one","hsbc","tower_1","hsbc_tower","tower_one_hsbc"],"Tower One · HSBC"],
		[["bank_of_china","boc","boc_140_sussex","bank_of_china_sussex"],"中国银行 · 140 Sussex St"],
		[["exchange_haidilao"],"The Exchange · 海底捞"],
		[["manly_wharf","manly"],"Manly Wharf · 曼利码头"],
		[["manly_corso","the_corso"],"The Corso · 曼利步行街"],
		[["manly_beach"],"Manly Beach · 曼利海滩"],
		[["hotel_steyne"],"Hotel Steyne · 曼利海滨"],
		[["airport"],"Sydney Airport · 悉尼机场"],
		[["home"],"Harbour Studio · 个人空间"],
		[["marina"],"Marina · 游艇码头"]
	]
	for option in options:
		for key in option[0]:
			if world.anchors.has(key) and world.anchors[key] is Vector3:
				catalog.append({"key":key,"title":option[1],"position":world.anchors[key]})
				break
			if key=="bridge" and not world.anchors.has(key):
				var bridge=load("res://scripts/bridge_landmark.gd")
				catalog.append({"key":"bridge","title":option[1],"position":bridge.pos(bridge.SPAN*0.5)})
				break
	# The model modules publish their actual IDs and names. This also keeps
	# new bank/Quay/shop destinations in sync with their verified locations.
	for group in ["bank_landmarks","metro_entrances","quay_landmarks","darling_square_frontages","cyber_landmarks","icc_landmarks","sydney_tower_landmark","circular_quay_detail","darling_square_detail","opera_interiors","darling_public_facilities","darling_precinct_businesses","manowar_detail","qvb_public"]:
		for record in world.get_meta(group,[]):
			var key:String=("shop_" if group=="darling_square_frontages" else "")+str(record.get("id",""))
			if not world.anchors.has(key) or not world.anchors[key] is Vector3: continue
			var title:String=str(record.get("name",key))
			if group=="metro_entrances": title+=" · Metro 入口厅"
			if group=="darling_square_frontages" and record.get("evidence","")=="location_verified": title+=" · 店面待核实"
			catalog.append({"key":key,"title":title,"position":record.get("arrival",world.anchors[key]),"map_position":record.get("map_position",world.anchors[key])})
	var geography:Dictionary=world.get_meta("landmark_geography",{})
	for item in catalog:
		if geography.has(str(item.key)):
			item.map_position=geography[str(item.key)].map_position
			item.position=geography[str(item.key)].arrival
	return catalog

func set_landmark_target(key:String):
	for landmark in landmark_catalog():
		if str(landmark.key)!=key: continue
		set_navigation_target(key,str(landmark.title),landmark.position)
		return

func set_navigation_target(key:String,title:String,position:Vector3,announce:=true):
	if not position.is_finite(): return
	landmark_target_key=key
	landmark_target_name=title.left(100)
	landmark_target_position=position
	map_panel.target_key=key
	map_panel.target_name=landmark_target_name
	map_panel.target_position=position
	map_panel.refresh()
	# Keep the pointer available to adjust or clear a map pin. Services and other
	# menus still return to play when they supply a destination.
	# Objectives re-point quietly; their own completion message is already on screen.
	if announce and active_panel!="map": close_panel()
	update_navigation(1.0)
	update_landmark_marker()
	if announce: notify("目的地已标记 · "+landmark_target_name+"\n跟随黄色标记与小地图；M 更换目的地。")

func set_map_waypoint(position:Vector3,title:String="我的标记"):
	set_navigation_target("map_pin",title,position)

func restore_navigation(data:Dictionary):
	var key:=str(data.get("key",""))
	if key.is_empty(): return
	if key!="map_pin":
		for landmark in landmark_catalog():
			if str(landmark.key)==key:
				landmark_target_key=key
				landmark_target_name=str(landmark.title)
				landmark_target_position=landmark.position
				return
	var point:=unvec(data.get("position",[0,4.5,0]))
	if not point.is_finite(): return
	# Objective markers keep their key so the campaign can clear them after a step.
	landmark_target_key=key if key.begins_with("campaign_") else "map_pin"
	landmark_target_name=str(data.get("title","我的标记")).left(100)
	landmark_target_position=point

func update_navigation(delta:float):
	var subject:Node3D=current_vehicle if is_instance_valid(current_vehicle) else player
	var position:Vector3=subject.get_global_transform_interpolated().origin
	var heading:float=subject.get_global_transform_interpolated().basis.get_euler().y if is_instance_valid(current_vehicle) else yaw
	var snapshot:={"player_position":position,"player_heading":heading,"target_key":landmark_target_key,"target_position":landmark_target_position,"target_name":landmark_target_name,"camera":camera}
	if is_instance_valid(navigation_hud): navigation_hud.sync_navigation(snapshot)
	_navigation_tick+=delta
	if _navigation_tick>=0.08 and is_instance_valid(minimap):
		_navigation_tick=0
		minimap.sync_navigation(snapshot)

func clear_landmark_target(announce:=true):
	landmark_target_key=""
	landmark_target_name=""
	if is_instance_valid(landmark_marker): landmark_marker.visible=false
	map_panel.target_key=""
	map_panel.refresh()
	update_navigation(1.0)
	if announce: notify("地标指引已清除")

func update_landmark_marker():
	if not is_instance_valid(landmark_marker):
		landmark_marker=label("",18,Color("a2efe0"))
		landmark_marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
		landmark_marker.add_theme_color_override("font_shadow_color",Color.BLACK)
		landmark_marker.add_theme_constant_override("shadow_offset_x",2)
		landmark_marker.add_theme_constant_override("shadow_offset_y",2)
		landmark_marker.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		landmark_marker.position=Vector2(38,-160)
		landmark_marker.size=Vector2(680,56)
		hud.add_child(landmark_marker)
	landmark_marker.visible=active and not landmark_target_key.is_empty()
	if not landmark_marker.visible: return
	var offset:Vector3=landmark_target_position-player.global_position
	var distance:float=Vector2(offset.x,offset.z).length()
	var bearing:float=fposmod(rad_to_deg(atan2(offset.x,-offset.z)),360.0)
	var direction:String=["北","东北","东","东南","南","西南","西","西北"][int(roundf(bearing/45.0))%8]
	if distance<25 and absf(offset.y)<12:
		landmark_marker.text="◎ 已到达 · "+landmark_target_name+"\n"+GameSettings.keys("{experiences} 城市体验  ·  {map} 选择下一个目的地")
	else:
		landmark_marker.text="◎ %s · %s · %s\n方向 %03d°  ·  "%[landmark_target_name,("%.2f km"%(distance/1000.0)) if distance>=1000 else ("%.0f m"%distance),direction,int(bearing)]+GameSettings.keys("{map} 地图  ·  {experiences} 城市体验")

func map_menu():
	active_panel="map"
	clear_panel("悉尼 · 地图与目的地","鼠标已释放 · 左键选点，拖动平移，滚轮缩放，右键清除。\nM / Esc 或右上角「返回游戏」关闭地图，继续步行或驾驶。")
	button("海港与城市核心",func(): map_panel.show_preset("core"))
	button("机场 ↔ 海港 ↔ Manly 全图",func(): map_panel.show_preset("all"))
	button("Manly 码头与海滩",func(): map_panel.show_preset("manly"))
	button("定位到我",func(): map_panel.show_preset("player"))
	modal_content.add_child(label("选择目的地 · 开车、飞行或步行前往",20,Color("a2efe0")))
	var catalog=landmark_catalog()
	map_panel.landmarks=catalog
	map_search=LineEdit.new()
	map_search.placeholder_text="搜索地标、商户或公共设施…"
	map_search.custom_minimum_size.y=44
	map_search.clear_button_enabled=true
	modal_content.add_child(map_search)
	map_results=VBoxContainer.new()
	map_results.add_theme_constant_override("separation",8)
	modal_content.add_child(map_results)
	map_search.text_changed.connect(refresh_map_results)
	refresh_map_results("")
	if not landmark_target_key.is_empty(): button("清除当前目的地指引",clear_landmark_target)
	button("回到城市",close_panel)
	map_panel.anchors=world.anchors
	map_panel.landmarks=catalog
	map_panel.player_position=player.global_position
	map_panel.player_heading=current_vehicle.rotation.y if is_instance_valid(current_vehicle) else yaw
	map_panel.target_key=landmark_target_key
	map_panel.target_position=landmark_target_position
	map_panel.target_name=landmark_target_name
	map_panel.has_spawn=is_instance_valid(spawn_target)
	if is_instance_valid(spawn_target): map_panel.spawn_position=spawn_target.global_position
	if is_instance_valid(airport): map_panel.runway_data=airport.runway_data
	if not map_panel.landmark_selected.is_connected(set_landmark_target): map_panel.landmark_selected.connect(set_landmark_target)
	map_panel.visible=true
	map_panel.show_preset("airport" if player.global_position.z>6500 else ("manly" if player.global_position.x>4000 and player.global_position.z< -3500 else "core"))
	map_panel.refresh()

func refresh_map_results(query:String):
	for child in map_results.get_children():
		map_results.remove_child(child)
		child.queue_free()
	var destinations:Array=map_panel.search_destinations(query)
	if destinations.is_empty():
		map_results.add_child(label("没有找到该名称。可在右侧地图直接标点。",15,Color("cbd6c9")))
	for destination:Dictionary in destinations:
		var choice:=Button.new()
		choice.text=destination.title
		choice.custom_minimum_size.y=45
		choice.alignment=HORIZONTAL_ALIGNMENT_LEFT
		choice.clip_text=true
		choice.tooltip_text=destination.title
		choice.pressed.connect(func():
			if destination.landmark: set_landmark_target(destination.key)
			else: set_map_waypoint(destination.position,destination.title)
			map_panel.map_center=Vector2(destination.position.x,destination.position.z)
			map_panel.pixels_per_metre=maxf(map_panel.pixels_per_metre,0.65)
			map_panel.view_name=destination.title.left(22)
			map_panel.refresh()
		)
		map_results.add_child(choice)

func districts_label() -> String:
	var cleared:int=districts.liberated.size()
	return "城市与港区 · 已解放 %d / %d"%[cleared,districts.DISTRICTS.size()]

func districts_menu():
	active_panel="districts"
	clear_panel("城市与港区","奶龙占住了各个港区。在一个港区里击败奶龙、完成工作或城市体验，就能把它夺回来；解放后街上的人和车会回来，并开放下一个港区。")
	for row:Dictionary in districts.summary():
		var state:String="已解放" if row.liberated else ("清剿中 %d / %d"%[row.done,row.need] if row.unlocked else "未开放")
		section(str(row.name)+" · "+state)
		if row.unlocked:
			button("导航到"+str(row.name),func():
				set_navigation_target("district_"+str(row.id),"港区 · "+str(row.name),row.centre)
				close_panel())
		else:
			note("先解放上一个港区。")
	button("返回",pause_menu if active else main_menu,"GhostButton")

func objectives_menu():
	active_panel="objectives"
	campaign.build_menu()

func settings_menu():
	active_panel="settings"
	clear_panel("设置","修改立即生效并自动保存。键盘、鼠标与手柄均可操作菜单。")
	if not _settings_notice.is_empty():
		var notice=label(_settings_notice,15,Color("f3cb80"))
		notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		notice.custom_minimum_size.x=430
		modal_content.add_child(notice)
		_settings_notice=""
	_settings_section("画面")
	var modes:Array=GameSettings.WINDOW_MODES
	_settings_option("显示模式",modes.map(func(row):return row[1]),modes.map(func(row):return row[0]).find(settings.window_mode),func(i): settings.window_mode=modes[i][0]; _settings_changed())
	_settings_toggle("垂直同步",settings.vsync,func(v): settings.vsync=v; _settings_changed())
	_settings_option("帧率上限",GameSettings.FPS_LIMITS.map(func(v):return "不限制" if v==0 else "%d FPS"%v),GameSettings.FPS_LIMITS.find(int(settings.max_fps)),func(i): settings.max_fps=GameSettings.FPS_LIMITS[i]; _settings_changed())
	var scales:Array=GameSettings.RENDER_SCALES
	var scale_index:=0
	for i in scales.size():
		if absf(scales[i]-float(settings.render_scale))<absf(scales[scale_index]-float(settings.render_scale)): scale_index=i
	_settings_option("渲染分辨率",scales.map(func(v):return "100% · 原生" if v>=0.999 else "%d%% · FSR 1 放大"%roundi(v*100)),scale_index,func(i): settings.render_scale=scales[i]; _settings_changed())
	var aa:Array=GameSettings.ANTIALIASING
	_settings_option("抗锯齿",aa.map(func(row):return row[1]),aa.map(func(row):return row[0]).find(settings.antialiasing),func(i): settings.antialiasing=aa[i][0]; _settings_changed())
	_settings_option("画质",["轻盈 · 关闭实时阴影","标准 · 实时阴影","精细 · 更远阴影与反射"],int(settings.quality),func(i): settings.quality=i; _settings_changed())
	_settings_slider("视野",55,95,1,float(settings.fov),func(v):return "%d°"%v,func(v): settings.fov=v; _settings_changed())
	var street_life:Array=GameSettings.STREET_LIFE
	_settings_option("街上人车",street_life.map(func(row):return row[0]+" · "+row[1]),clampi(int(settings.street_life),0,street_life.size()-1),func(i): settings.street_life=i; _settings_changed())
	_settings_section("战斗")
	var difficulty:Array=GameSettings.COMBAT_DIFFICULTY
	_settings_option("战斗难度",difficulty.map(func(row):return row[0]+" · "+row[1]),clampi(int(settings.combat_difficulty),0,difficulty.size()-1),func(i): settings.combat_difficulty=i; _settings_changed())
	_settings_section("声音")
	_settings_slider("主音量",0,1,0.05,float(settings.volume),func(v):return "%d%%"%roundi(v*100),func(v): settings.volume=v; _settings_changed())
	_settings_toggle("切到其他窗口时静音",settings.mute_unfocused,func(v): settings.mute_unfocused=v; _settings_changed())
	_settings_section("操作")
	_settings_slider("鼠标灵敏度",0.001,0.008,0.0005,float(settings.sensitivity),func(v):return "%.1f"%(v*1000),func(v): settings.sensitivity=v; _settings_changed())
	_settings_slider("手柄视角速度",0.8,6.0,0.1,float(settings.pad_sensitivity),func(v):return "%.1f"%v,func(v): settings.pad_sensitivity=v; _settings_changed())
	_settings_toggle("反转垂直视角",settings.invert,func(v): settings.invert=v; _settings_changed())
	_settings_toggle("加大游戏提示文字",settings.large_text,func(v): settings.large_text=v; _settings_changed())
	_settings_section("键盘按键")
	for group:Array in GameSettings.REBINDABLE:
		var row=_settings_row(group[0])
		var rebind=Button.new()
		rebind.text=GameSettings.key_label(group[1][0])
		rebind.custom_minimum_size.x=190
		rebind.pressed.connect(func():
			_rebind_group=group[1][0]
			rebind.text="按下新按键 · Esc 取消")
		row.add_child(rebind)
		_focus_for_pad(rebind)
	button("恢复默认按键",func():
		settings.bindings={}
		_settings_changed()
		_settings_notice="已恢复默认按键。"
		settings_menu())
	_settings_section("手柄（Xbox 布局，PlayStation 与 Steam Deck 按对应位置）")
	var pad_help=label("左摇杆 移动 / 驾驶 · 右摇杆 视角\nA 跳跃 / 刹车 · B 互动 / 上下车 · X 漂移 · Y 载具\nRT 开火 · LT 奔跑 / 3 倍加速 · RB / LB 升降\n十字键 ↑ 地图 · ↓ 急救 · ← 工作 · → 整备\nR3 自动武器 · Back 城市体验 · Start 暂停",14,Color("bbc8c5"))
	pad_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	pad_help.custom_minimum_size.x=430
	modal_content.add_child(pad_help)
	button("返回",pause_menu if active else main_menu)

func _settings_changed():
	settings=GameSettings.sanitized(settings)
	apply_settings()
	save_settings()

func _settings_section(title:String):
	section(title)

func section(title:String):
	var heading=Label.new()
	heading.text=title
	heading.theme_type_variation="SectionLabel"
	heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size.x=470
	modal_content.add_child(heading)

func note(text_value:String):
	var body=Label.new()
	body.text=text_value
	body.theme_type_variation="QuietLabel"
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x=470
	modal_content.add_child(body)

func _settings_row(title:String) -> HBoxContainer:
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	var name_label=label(title,15,Color("e3e8dc"))
	name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name_label)
	modal_content.add_child(row)
	return row

func _settings_option(title:String,items:Array,selected:int,changed:Callable):
	var row=_settings_row(title)
	var option=OptionButton.new()
	for item in items: option.add_item(str(item))
	option.select(maxi(selected,0))
	option.custom_minimum_size.x=240
	option.clip_text=true
	option.item_selected.connect(changed)
	row.add_child(option)
	_focus_for_pad(option)

func _settings_toggle(title:String,value:bool,changed:Callable):
	var row=_settings_row(title)
	var toggle=CheckButton.new()
	toggle.button_pressed=value
	toggle.toggled.connect(changed)
	row.add_child(toggle)
	_focus_for_pad(toggle)

func _settings_slider(title:String,minimum:float,maximum:float,step:float,value:float,format:Callable,changed:Callable):
	var row=_settings_row(title)
	var readout=label(format.call(value),15,Color("f1efdf"))
	readout.custom_minimum_size.x=52
	readout.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var slider=HSlider.new()
	slider.min_value=minimum
	slider.max_value=maximum
	slider.step=step
	slider.value=value
	slider.custom_minimum_size.x=170
	slider.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v):
		readout.text=format.call(v)
		changed.call(v))
	row.add_child(slider)
	row.add_child(readout)
	_focus_for_pad(slider)

func _capture_rebind(event:InputEvent):
	if not event is InputEventKey or not event.pressed: return
	get_viewport().set_input_as_handled()
	var group:=_rebind_group
	_rebind_group=""
	if event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_NONE:
		settings_menu()
		return
	var code:=int(event.physical_keycode)
	var shared:Array=GameSettings.conflicts(settings.bindings,group,code)
	settings.bindings[group]=[code]
	_settings_changed()
	_settings_notice="已绑定 %s。"%GameSettings.key_label(group)+("该按键同时用于：%s。"%"、".join(shared) if not shared.is_empty() else "")
	settings_menu()

func load_settings():
	if FileAccess.file_exists("user://settings.json"):
		var data=JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
		if data is Dictionary: settings=GameSettings.sanitized(data)
	apply_settings()

func apply_settings():
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(float(settings.volume),0.001)))
	GameSettings.apply_bindings(settings.bindings)
	# QA runs size their own windows; only players' settings change the window.
	GameSettings.apply_display(settings,get_viewport(),camera,not qa_running)
	preload("res://scripts/daylight_environment.gd").apply_quality(environment.environment,int(settings.quality))
	sun.shadow_enabled=int(settings.quality)>0
	sun.directional_shadow_max_distance=700 if int(settings.quality)==2 else 350
	context_hint.add_theme_font_size_override("font_size",17 if settings.large_text else 14)
	activity_label.add_theme_font_size_override("font_size",18 if settings.large_text else 15)
	toast_label.add_theme_font_size_override("font_size",22 if settings.large_text else 19)

func save_settings():
	# QA shares the player's user data folder; never overwrite real preferences.
	if qa_running: return
	var file=FileAccess.open("user://settings.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(settings))

func credits_menu():
	active_panel="credits"
	clear_panel("关于这片海港","Harbourlife · 开发预览 "+str(ProjectSettings.get_setting("application/config/version"))+"\n原创程序、建筑重建和合成音效；环境资源来源见下方。")
	var text_value="Godot Engine 4.7.2 · MIT License\nhttps://godotengine.org/license\n\n晴日天空：Rustig Koppie (Pure Sky) · Greg Zaal / Jarod Guest · Poly Haven · CC0\nhttps://polyhaven.com/a/rustig_koppie_puresky\n\n建筑轮廓、道路与岸线：© OpenStreetMap contributors · ODbL 1.0\nhttps://www.openstreetmap.org/copyright\n\n主要地标、总部及所列店面参考建筑师、物业与商户公开资料及真实照片。普通楼体立面、大部分地形高程仍为近似；这不是完整的一比一城市扫描。\n\n各地标依据、数据日期、估算范围与许可附在源码 docs 和 licenses 中。界面字体：Noto Sans CJK、Noto Sans、Noto Sans Arabic、Noto Sans Math · SIL OFL 1.1。字体许可随包附在 licenses 中。"
	var l=label(text_value,17)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x=430
	modal_content.add_child(l)
	button("返回",pause_menu if active else main_menu)

func notify(message:String,sound=true):
	if not is_instance_valid(toast_label): return
	toast_label.text=message
	toast_time=7
	if sound and is_instance_valid(audio): audio.chime()

func time_menu():
	preload("res://scripts/time_panel.gd").build(self)

func _input(event):
	# These shortcuts must run before focused GUI controls and before the paused
	# gameplay guard. Otherwise M cannot close the very map it opened.
	if event is InputEventKey and event.echo: return
	if _rebind_group!="":
		_capture_rebind(event)
		return
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value)>0.5):
		if not _using_pad:
			_using_pad=true
			if modal.visible and get_viewport().gui_get_focus_owner()==null:
				_pad_focus_pending=true
				for child in modal_content.get_children():
					if child is Control and child.focus_mode!=Control.FOCUS_NONE:
						_focus_for_pad(child)
						break
	elif event is InputEventKey or event is InputEventMouseButton:
		_using_pad=false
	if event is InputEventJoypadButton and event.is_action_pressed("pause"):
		if modal.visible and active: close_panel()
		elif active: pause_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B and modal.visible and active:
		close_panel()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_F3:
		if is_instance_valid(diagnostics_panel): diagnostics_panel.toggle()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(diagnostics_panel) and diagnostics_panel.visible:
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
			diagnostics_panel.close()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if modal.visible and active: close_panel()
		elif active: pause_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action("cursor"):
		_cursor_held=event.is_pressed()
		sync_mouse_capture()
		get_viewport().set_input_as_handled()
		return
	if not active: return
	var focus=get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event is InputEventKey and event.pressed and (event.physical_keycode==KEY_T or event.keycode==KEY_T):
		if active_panel=="time":close_panel()
		else:time_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("map"):
		if active_panel=="map": close_panel()
		else: map_menu()
		get_viewport().set_input_as_handled()

func _unhandled_input(event):
	if quitting: return
	if not active or paused: return
	if event.is_action_pressed("heal"):
		notify(survival.quick_recovery())
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("auto_support"):
		weapons.set_auto_enabled(not weapons.auto_enabled())
		notify("自动辅助武器 · "+("开启，自动锁定附近奶龙" if weapons.auto_enabled() else "关闭")+" · V 切换")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("survival_services"):
		survival_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and camera_accepts_mouse():
		yaw-=event.relative.x*float(settings.sensitivity)
		pitch=clampf(pitch-event.relative.y*float(settings.sensitivity)*(-1 if settings.invert else 1),-1.05,0.65)
	if event.is_action_pressed("fire") and can_fire_weapon():
		if not event is InputEventMouseButton or camera_accepts_mouse():
			weapons.fire_current()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		if is_instance_valid(current_vehicle): exit_vehicle()
		else:
			var vehicle=nearest_vehicle()
			if vehicle: enter_vehicle(vehicle)
			else:
				var message=life.interact(player.global_position)
				if message=="OPEN_JOBS": jobs_menu()
				elif message=="OPEN_SERVICES": experiences_menu()
				else: notify(message)
	elif event.is_action_pressed("vehicles"): vehicles_menu()
	elif event.is_action_pressed("jobs"): jobs_menu()
	elif event.is_action_pressed("experiences"): experiences_menu()
	elif event.is_action_pressed("save"):
		if save_world(): notify("世界已保存")
	elif event.is_action_pressed("recover"): recover_player()
	elif event.is_action_pressed("carry"): notify(str(life.toggle_carry(player.global_position)))
	elif event.is_action_pressed("photo"): take_photo()

func take_photo():
	if photo_cooldown>0: return
	photo_cooldown=2
	var path="user://photos/"
	DirAccess.make_dir_recursive_absolute(path)
	var image_path=path+Time.get_datetime_string_from_system().replace(":","-")+".png"
	get_viewport().get_texture().get_image().save_png(image_path)
	notify("照片已保存到本机相册文件夹")
	if is_instance_valid(campaign): campaign.record_photo(current_vehicle.global_position if is_instance_valid(current_vehicle) else player.global_position)
	if life.has_method("take_photo"): life.take_photo(player.global_position)

## Controllers have no spare button for photos, so the pause menu closes itself first.
func photo_from_menu():
	close_panel()
	for i in 3: await get_tree().process_frame
	photo_cooldown=0
	take_photo()

func _physics_process(delta):
	if not active or paused: return
	if is_instance_valid(current_vehicle):
		player.global_position=current_vehicle.global_position
		if current_vehicle.global_position.y < -45:
			notify("载具沉没 · 可离舱游泳或 Home 呼叫救援",false)
	player.yaw=yaw
	life.tick_context(player.global_position,current_vehicle.kind if is_instance_valid(current_vehicle) else "",current_vehicle.linear_velocity.length() if is_instance_valid(current_vehicle) else player.velocity.length(),delta)

func _process(delta):
	if toast_time>0:
		toast_time-=delta
		toast_label.modulate.a=minf(1,toast_time)
	else: toast_label.modulate.a=0
	if is_instance_valid(toast_panel): toast_panel.modulate.a=toast_label.modulate.a if not toast_label.text.is_empty() else 0.0
	if not active:
		menu_orbit+=delta*0.015
		camera.global_position=Vector3(690+sin(menu_orbit)*35,170,-15)
		camera.look_at(Vector3(0,50,-650))
		world.stream_view(camera.global_position,Vector3.ZERO,delta)
		return
	if paused: return
	elapsed+=delta
	autosave+=delta
	photo_cooldown-=delta
	if autosave>60 and not qa_running:
		autosave=0
		save_world()
	var look:=Input.get_vector("look_left","look_right","look_up","look_down")
	if look!=Vector2.ZERO and not modal.visible and not map_panel.visible:
		var turn:float=float(settings.pad_sensitivity)*delta
		yaw-=look.x*turn
		pitch=clampf(pitch-look.y*turn*(-1 if settings.invert else 1),-1.05,0.65)
	_update_follow_camera(delta)
	world.stream_view(camera.global_position,current_vehicle.linear_velocity if is_instance_valid(current_vehicle) else player.velocity,delta)
	update_navigation(delta)
	update_spawn_marker()
	update_landmark_marker()
	update_hud()
	if is_instance_valid(campaign): campaign.tick(delta)
	update_combat_reticle(delta)
	if is_instance_valid(survival_hud): survival_hud.update_state(survival.hud_state())
	if qa_manual_render:
		qa_render_count+=1
		RenderingServer.force_draw(true,delta)
	if qa_profile_stage!="":
		var now=Time.get_ticks_usec()
		if qa_frame_stamp>0: qa_frame_times.append(float(now-qa_frame_stamp)/1000.0)
		qa_frame_stamp=now

func reset_follow_camera():
	_camera_reset=true

func _update_follow_camera(delta: float):
	var subject: Node3D=current_vehicle if is_instance_valid(current_vehicle) else player
	var rendered: Transform3D=subject.get_global_transform_interpolated()
	var height=current_vehicle.get_camera_height() if is_instance_valid(current_vehicle) else 1.45
	var target=rendered.origin+Vector3.UP*height
	if is_instance_valid(current_vehicle) and current_vehicle.kind!="tank" and Input.is_action_pressed("forward") and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw=lerp_angle(yaw,rendered.basis.get_euler().y,1.0-exp(-delta*0.9))
	var orbit=Vector3(0,0,camera_distance).rotated(Vector3.RIGHT,pitch).rotated(Vector3.UP,yaw)+Vector3.UP*1.3
	var snap=_camera_reset or _camera_subject_id!=subject.get_instance_id() or _camera_focus.distance_to(target)>400.0
	if snap:
		_camera_focus=target
		_camera_orbit=orbit
		_camera_boom=orbit.length()
		_camera_reset=false
		_camera_subject_id=subject.get_instance_id()
	else:
		# Smooth the focus and orbit coherently, including discrete stair climbing.
		# Never look at the raw 60 Hz physics position while translating at render rate.
		_camera_focus=_camera_focus.lerp(target,1.0-exp(-delta*14.0))
		_camera_orbit=_camera_orbit.lerp(orbit,1.0-exp(-delta*12.0))
	var direction=_camera_orbit.normalized()
	var allowed=_camera_orbit.length()
	var query=PhysicsRayQueryParameters3D.create(_camera_focus,_camera_focus+_camera_orbit,1)
	query.exclude=[player.get_rid()]
	var hit=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): allowed=maxf(0.35,_camera_focus.distance_to(hit.position)-0.4)
	# Retract immediately before an obstruction; recover outward gradually to avoid popping.
	_camera_boom=allowed if allowed<_camera_boom or snap else lerpf(_camera_boom,allowed,1.0-exp(-delta*7.0))
	camera.global_position=_camera_focus+direction*_camera_boom
	if camera.global_position.distance_to(_camera_focus)>0.1: camera.look_at(_camera_focus)
	# Shake and recoil ride on top of the placed camera, never inside its smoothing.
	if is_instance_valid(combat_feel): combat_feel.apply_camera(camera,delta)

func update_combat_reticle(delta:float):
	if active and not paused and survival.enabled and not is_instance_valid(current_vehicle):
		combat_reticle.visible = camera_accepts_mouse() and player.health > 0.0
		combat_reticle.position = get_viewport().get_visible_rect().size * 0.5 - combat_reticle.size * 0.5
		combat_reticle.modulate = Color("96ddc7") if survival.hud_state().aim_hit else Color.WHITE
		return
	combat_reticle.modulate = Color.WHITE
	if not can_fire_weapon():
		combat_reticle.visible=false
		return
	_combat_aim_clock-=delta
	if _combat_aim_clock<=0.0:
		_combat_aim_clock=0.1
		_combat_aim_point=weapons.aim_point()
	combat_reticle.visible=not _cursor_held and not camera.is_position_behind(_combat_aim_point)
	if combat_reticle.visible:
		combat_reticle.position=camera.unproject_position(_combat_aim_point)-combat_reticle.size*.5
	var status:Dictionary=weapons.aim_status()
	fire_button.disabled=not status.get("ready",false)
	if fire_button.disabled: fire_button.text="装填 %.1f s"%status.get("cooldown_remaining",0.0)
	if current_vehicle.kind=="tank":
		speed_label.text+="\n炮管 %+.0f°"%status.get("elevation_deg",0.0)

func update_hud():
	var combat_active:=can_fire_weapon()
	fire_button.visible=combat_active
	combat_reticle.visible=combat_active and not _cursor_held
	if combat_active:
		fire_button.text="发射炮弹  ·  X / 左键" if current_vehicle.kind=="tank" else "发射火箭  ·  X / 左键"
	mode_label.text="HARBOURLIFE  /  "+("自由观光" if mode=="sandbox" else "奶龙危机")
	info.text="$%s    ·    耐力 %d%%    ·    %s" %[life.money,player.stamina,city_clock.display_time() if is_instance_valid(city_clock) else "16:00"]
	var regions={"quay":"Circular Quay · 环形码头","opera":"Bennelong Point · 歌剧院","rocks":"The Rocks · 岩石区","north":"Milsons Point · 北岸","home":"Harbour Studio · 你的家","marina":"Marina · 海港码头","helipad":"Harbour Air · 停机坪","airport":"Sydney Airport · 悉尼机场","ribbon":"Darling Harbour · 达令港","exchange_haidilao":"Darling Square · 达令广场","icc_convention":"ICC Sydney · 会展中心","icc_exhibition":"ICC Sydney · 展览中心","tiktok_entertainment":"TikTok Entertainment Centre · 演出场馆","tower_one":"Barangaroo · 巴兰加鲁","manly_wharf":"Manly Wharf · 曼利码头","manly_beach":"Manly Beach · 曼利海滩","martin_place_metro":"Martin Place · 马丁广场"}
	var closest="quay"
	var distance=INF
	for key in regions:
		if world.anchors.has(key):
			var delta_position:Vector3=player.global_position-world.anchors[key]
			var d=Vector2(delta_position.x,delta_position.z).length()
			if d<distance: distance=d; closest=key
	var broad:="Port Jackson · 悉尼海港"
	if player.global_position.z>500 and player.global_position.z<3600 and player.global_position.x>-1500 and player.global_position.x<1200:broad="Sydney CBD · 悉尼市区"
	elif player.global_position.z>3600:broad="Sydney · 机场与城市之间"
	elif player.global_position.x>5700 and player.global_position.z< -4500:broad="Manly · 曼利"
	region_label.text=regions[closest] if distance<520 else broad
	if player.global_position.z>7400 and player.global_position.z<12800 and player.global_position.x>-5700 and player.global_position.x<0:
		region_label.text="Sydney Airport · 悉尼机场"
	activity_label.text=life.status_text
	activity_panel.visible=not life.status_text.strip_edges().is_empty()
	if is_instance_valid(current_vehicle):
		speed_label.text="%d km/h  ·  %d m\n%s  %d%%" %[current_vehicle.linear_velocity.length()*3.6,current_vehicle.global_position.y,VEHICLE_NAMES[current_vehicle.kind].split(" · ")[0],current_vehicle.health]
		if current_vehicle.kind=="hoverboard":
			speed_label.text="%d km/h  ·  %d m\nAether X1\n耐久 %d%%" %[current_vehicle.linear_velocity.length()*3.6,current_vehicle.global_position.y,current_vehicle.health]
		elif current_vehicle.kind in ["car","motorcycle"]:
			var handling:Dictionary=current_vehicle.get_meta("road_handling",{})
			if handling.get("drifting",false): speed_label.text+="\n漂移中"
		if current_vehicle.kind=="airliner":
			speed_label.text+="\n推力 %d%% %s" %[current_vehicle.throttle*100,"失速 · 放低机头" if current_vehicle.stalled else ""]
			var forward=-current_vehicle.global_basis.z
			info.text="航向 %03d° · 海港 %.1f km" %[fposmod(rad_to_deg(atan2(forward.x,-forward.z)),360),current_vehicle.global_position.distance_to(world.anchors.opera)/1000]
		if current_vehicle.is_boosting():
			speed_label.text+="\n3倍加速中 · 上限 %d km/h"%current_vehicle.effective_top_speed_kmh()
		context_hint.text=vehicle_help(current_vehicle.kind)+GameSettings.keys(" · {boost} 3倍加速   {interact} 离开   {vehicles} 新增   {map} 地图")+(GameSettings.keys("\n{auto_support} 自动武器   {heal} 战地快修   {survival_services} 补给 / 升级 · 弹药免费") if survival.enabled else "   T 时间")
	else:
		speed_label.text="游泳" if player.swimming else ""
		var near=nearest_vehicle()
		var hint=GameSettings.keys("{interact} 进入 ")+VEHICLE_NAMES[near.kind] if near else life.available_actions(player.global_position)
		# Life actions name their default key first; show the player's binding instead.
		if hint.begins_with("E  "): hint=GameSettings.keys("{interact}")+hint.substr(1)
		elif hint.begins_with("G  "): hint=GameSettings.keys("{carry}")+hint.substr(1)
		context_hint.text=(hint+"   ·   " if hint!="" else "")+(GameSettings.keys("左键 / {fire} 反击 · {heal} 治疗 · {survival_services} 整备 · ") if survival.enabled else "")+GameSettings.keys("{move} 行走   {sprint} 奔跑   {vehicles} 载具   {map} 地图")
	if _using_pad: context_hint.text=GameSettings.pad_hint(current_vehicle.kind if is_instance_valid(current_vehicle) else "",survival.enabled)
	vehicle_panel.visible=not speed_label.text.is_empty()
	# Sit above the control strip, whose height changes with wrapped vehicle hints.
	var readout_bottom:=-(hud.size.y-(hint_panel.get_global_rect().position.y-hud.global_position.y)+12.0)
	if not is_equal_approx(vehicle_panel.offset_bottom,readout_bottom):
		vehicle_panel.offset_bottom=readout_bottom
		vehicle_panel.offset_top=readout_bottom
	if is_instance_valid(landmark_marker) and landmark_marker.visible:
		# Destination text sits above the control strip and beside the survival card,
		# so a two-line hint bar or a taller left column never covers it.
		var marker_left:=38.0
		if is_instance_valid(survival_hud) and survival_hud.is_visible_in_tree():
			marker_left=survival_hud.global_position.x-hud.global_position.x+survival_hud._card_rect.end.x+18.0
		var marker_bottom:=hint_panel.get_global_rect().position.y-hud.global_position.y-10.0
		landmark_marker.size=landmark_marker.get_combined_minimum_size()
		landmark_marker.position=Vector2(marker_left,marker_bottom-landmark_marker.size.y)
	if is_instance_valid(campaign): campaign.update_panel()
	# Placed with the rest of the HUD so a window resize moves it the same frame.
	if is_instance_valid(districts): districts.update_panel()
	if is_instance_valid(survival_hud) and survival_hud.has_method("set_top_limit"):
		survival_hud.set_top_limit(left_column.get_global_rect().end.y-hud.global_position.y+10.0)

func _notification(what):
	# Closing during loading has no world to save yet.
	if what==NOTIFICATION_WM_CLOSE_REQUEST and Loading.active(): get_tree().quit()
	elif what==NOTIFICATION_WM_CLOSE_REQUEST: quit_game()
	elif what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		if bool(settings.get("mute_unfocused",false)): AudioServer.set_bus_mute(0,true)
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		AudioServer.set_bus_mute(0,false)
	elif what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		# The OS may release Option in another app without delivering key-up here.
		_cursor_held=false
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		if is_instance_valid(minimap):minimap.cursor_released=false
	elif what==NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if is_instance_valid(modal) and is_instance_valid(map_panel):sync_mouse_capture()

func quit_game():
	if quitting: return
	if active and not save_world():
		notify("保存失败 · 请在恢复问题后退出",false)
		return
	finish_quit()

func finish_quit(exit_code=0):
	if quitting: return
	quitting=true
	active=false
	# Stop new gameplay audio and drain mixer-owned playback before teardown.
	get_tree().paused=false
	var audio_cleanup: Dictionary = await AudioShutdown.stop_and_drain(self)
	print("AUDIO_SHUTDOWN ",JSON.stringify(audio_cleanup))
	get_tree().quit(exit_code)

func run_qa():
	await get_tree().process_frame
	if not world._ready_complete:
		push_error("Native QA requires the complete assembled world")
		finish_quit(1)
		return
	new_world("sandbox","Automated QA",false)
	world_id="qa_isolated_"+str(Time.get_ticks_usec())
	qa_report={"engine":Engine.get_version_info().string,"os":OS.get_name(),"cpu":OS.get_processor_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":str(get_viewport().get_visible_rect().size),"checks":[],"profiles":[],"manual_render_each_process":qa_manual_render,"performance_note":"Short real-time samples with one explicit render per process to prevent occlusion skipping. Process frame intervals include stalls. No fixed-fps or movie capture; not a sustained benchmark."}
	await get_tree().create_timer(3).timeout
	qa_check("world_has_seven_anchors",world.anchors.size()>=7)
	qa_check("fleet_has_all_categories",vehicles.size()==VEHICLE_NAMES.size())
	qa_check("player_supported",player.is_on_floor())
	qa_check("npc_population",get_tree().get_nodes_in_group("harbor_npc").size()>0 or life.get_child_count()>3)
	await qa_capture("01-home")
	for location in ["quay","opera","north","rocks"]:
		player.global_position=world.anchors[location]+Vector3.UP*3
		player.velocity=Vector3.ZERO
		yaw=0
		pitch=-0.2
		await get_tree().create_timer(1.5).timeout
		qa_check("ground_"+location,player.global_position.y>-1 and player.is_on_floor())
		await qa_capture("02-"+location)
	for v in vehicles:
		if is_instance_valid(current_vehicle): exit_vehicle()
		v.freeze=false
		var start=world.anchors.get("home",Vector3.ZERO)+Vector3(12,2,8)
		if v.kind in ["yacht","speedboat"]: start=Vector3(280 if v.kind=="yacht" else 360,1,-850)
		elif v.kind in ["paraglider","glider","airliner","helicopter"]: start=Vector3(800,220,-1300)
		v.global_position=start
		v.rotation=Vector3.ZERO
		PhysicsServer3D.body_set_state(v.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,v.global_transform)
		v.linear_velocity=Vector3.ZERO
		enter_vehicle(v)
		Input.action_press("forward")
		if v.kind=="helicopter": Input.action_press("rise")
		var samples=[]
		qa_begin_profile(v.kind)
		var drawn_start=qa_render_count if qa_manual_render else Engine.get_frames_drawn()
		for i in 120:
			await get_tree().physics_frame
			samples.append(Performance.get_monitor(Performance.TIME_FPS))
		Input.action_release("forward")
		Input.action_release("rise")
		qa_check("vehicle_moves_"+v.kind,Vector2(v.global_position.x-start.x,v.global_position.z-start.z).length()>0.5 or (v.kind=="helicopter" and v.global_position.y>start.y+0.5))
		qa_check("finite_physics_"+v.kind,v.global_position.is_finite() and v.linear_velocity.is_finite())
		var profile={"scenario":v.kind,"frames":samples.size(),"fps_mean":array_mean(samples),"fps_min":samples.min(),"speed":v.linear_velocity.length(),"position":vec(v.global_position),"drawn_frames":(qa_render_count if qa_manual_render else Engine.get_frames_drawn())-drawn_start}
		profile.merge(qa_end_profile())
		qa_report.profiles.append(profile)
		await qa_capture("03-"+v.kind)
	if is_instance_valid(current_vehicle): exit_vehicle()
	player.global_position=world.anchors.home+Vector3.UP*2
	var before=JSON.stringify(world.get_state())
	var damage_point=Vector3(414,18,-260)
	for component_id in world.structures:
		if str(component_id).begins_with("opera/shell/"):
			damage_point=world.structures[component_id].position
			break
	player.global_position=damage_point+Vector3(30,0,35)
	yaw=0.45
	pitch=-0.15
	await get_tree().create_timer(1).timeout
	qa_begin_profile("localized_destruction")
	var damage_drawn_start=qa_render_count if qa_manual_render else Engine.get_frames_drawn()
	world.damage_at(damage_point,20000000,18)
	var destruction_samples=[]
	for i in 180:
		await get_tree().physics_frame
		destruction_samples.append(Performance.get_monitor(Performance.TIME_FPS))
	var damage_profile={"scenario":"localized_destruction","frames":180,"fps_mean":array_mean(destruction_samples),"fps_min":destruction_samples.min(),"rubble":world.rubble.size(),"destroyed":world.destroyed.size(),"drawn_frames":(qa_render_count if qa_manual_render else Engine.get_frames_drawn())-damage_drawn_start}
	damage_profile.merge(qa_end_profile())
	qa_report.profiles.append(damage_profile)
	var damage_state=world.get_state()
	var damage=JSON.stringify(damage_state)
	qa_check("world_damage_changes_state",before!=damage)
	player.global_position=damage_point+Vector3(30,0,35)
	yaw=0.45
	pitch=-0.15
	await get_tree().create_timer(1).timeout
	await qa_capture("04-damage")
	qa_check("atomic_save",save_world())
	var restored=Store.read(world_id)
	qa_check("save_has_vehicles",restored.get("vehicles",[]).size()==VEHICLE_NAMES.size())
	qa_check("save_has_damage",restored.get("world",{}).get("destroyed",[])==damage_state.get("destroyed",[]))
	world.repair_all()
	world.apply_state(restored.world)
	qa_check("damage_restore",world.get_state().get("destroyed",[])==restored.world.get("destroyed",[]) and world.get_state().get("partial",{})==restored.world.get("partial",{}) and world.get_state().get("rubble",[]).size()==restored.world.get("rubble",[]).size())
	var copy=Store.duplicate_world(world_id)
	qa_check("independent_copy",copy!="" and not Store.read(copy).is_empty())
	var f=FileAccess.open("user://qa-report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(qa_report,"\t"))
	f.close()
	print("HARBOURLIFE_QA "+JSON.stringify(qa_report))
	var failed=false
	for check in qa_report.checks:
		if not check.passed: failed=true
	finish_quit(1 if failed else 0)

func qa_begin_profile(stage:String):
	qa_profile_stage=stage
	qa_frame_times=[]
	qa_frame_stamp=Time.get_ticks_usec()

func qa_end_profile() -> Dictionary:
	qa_profile_stage=""
	qa_frame_times.sort()
	if qa_frame_times.is_empty(): return {"process_frames":0}
	return {"process_frames":qa_frame_times.size(),"frame_ms_median":qa_frame_times[qa_frame_times.size()/2],"frame_ms_p95":qa_frame_times[int((qa_frame_times.size()-1)*0.95)],"frame_ms_worst":qa_frame_times.back()}

func qa_check(test:String,passed:bool):
	qa_report.checks.append({"name":test,"passed":passed})
	print("QA "+test+" "+("PASS" if passed else "FAIL"))

func qa_capture(file_name:String):
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://qa-screenshots")
	get_viewport().get_texture().get_image().save_png("user://qa-screenshots/"+file_name+".png")

func array_mean(values:Array) -> float:
	var total=0.0
	for value in values: total+=float(value)
	return total/maxi(1,values.size())

func airport_start():
	if not is_instance_valid(airport):
		notify("机场正在构建",false)
		return
	if not active: new_world("life","悉尼机场奶龙危机")
	survival.sync_fleet()
	if float(survival.fleet_health.get("airliner",100.0)) <= 0.0:
		notify("客机已损毁 · B 远程维修后再从机场出发",false)
		return
	if not "airliner" in owned: owned.append("airliner")
	var v=make_vehicle("airliner",next_vehicle_id("airliner"),Vector3(0,-2000,0))
	v.freeze=true
	var placement=VehicleSpawn.find_spawn(self,v,true)
	if placement.is_empty():
		vehicles.erase(v)
		remove_child(v)
		v.queue_free()
		notify("跑道已被载具占用 · 请先将已有飞机移到机坪",false)
		return
	finish_vehicle_spawn(v,placement)
	close_panel()
	enter_vehicle(v)
	yaw=airport.runway_heading
	pitch=-0.1
	reset_follow_camera()
	notify("34L 跑道 · 按住 W 加油门，约 250 km/h 时 R 抬头，A/D 转弯。海港约在北偏东 12 km。")

func vehicle_help(kind:String) -> String:
	return GameSettings.keys(_vehicle_help_template(kind))

func _vehicle_help_template(kind:String) -> String:
	match kind:
		"tank": return "{forward}/{back} 履带 · {left}/{right} 转向 · 鼠标瞄准 · {combat_yaw_left}/{combat_yaw_right} 旋塔 · {combat_raise}/{combat_lower} 俯仰 · {fire}/左键 发射 · {survival_services} 维修升级"
		"fighter": return "{forward}/{back} 推力 · {left}/{right} 转弯 · {rise}/{fall} 俯仰 · {fire}/左键 发射 · 2000 km/h · {survival_services} 维修升级"
		"car": return "{forward}/{back} 加速倒车 · {left}/{right} 转向 · {brake} 急刹 · {drift} + {left}/{right} 漂移 · 常速 420 km/h"
		"motorcycle": return "{forward}/{back} 加速倒车 · {left}/{right} 转向 · {brake} 急刹 · {drift} + {left}/{right} 漂移 · 常速 320 km/h"
		"yacht","speedboat": return "{forward}/{back} 双机推力   {left}/{right} 船舵   {brake} 反向推力"
		"hoverboard": return "{forward}/{back} 加速 / 后退 · 200 km/h   {left}/{right} 转向   {rise}/{fall} 升降   {brake} 急停 · 自动越阶 / 掠水"
		"helicopter": return "{forward}/{back} 俯仰   {left}/{right} 偏航   {rise}/{fall} 升降 · 极速 350 km/h"
		"paraglider","glider": return "{left}/{right} 转弯   {rise}/{fall} 俯仰   {brake} 减速板 · 无动力"
		_: return "{forward}/{back} 推力   {left}/{right} 转弯   {rise}/{fall} 俯仰   {brake} 减速板 · 极速 800 km/h"
