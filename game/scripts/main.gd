extends Node3D

const Store = preload("res://scripts/save_store.gd")
const Player = preload("res://scripts/harbor_player.gd")
const Sound = preload("res://scripts/harbor_audio.gd")
const VehicleSpawn = preload("res://scripts/vehicle_spawn.gd")
const VEHICLE_NAMES = {"car":"Veloce V12 · 超跑","motorcycle":"Apex RR · 超级运动摩托","hoverboard":"Aether X1 · 反重力平衡车","speedboat":"Riviera 39 · 豪华快艇","yacht":"Ocean 90 · 豪华游艇","paraglider":"Thermal 9 · 滑翔伞","glider":"Southern Arc · 滑翔机","helicopter":"Harbour H6 · 直升机","airliner":"Dreamliner 787-9 · 双发客机"}
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
var settings={"volume":0.65,"sensitivity":0.003,"quality":1,"invert":false,"large_text":false}
var active_panel=""
var name_edit: LineEdit
var map_search: LineEdit
var map_results: VBoxContainer
var font: SystemFont
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

func _ready():
	var arguments:=OS.get_cmdline_user_args()
	if "--mobility-qa" in arguments:
		qa_running=true
		setup_input()
		set_process(false)
		set_process_unhandled_input(false)
		add_child(load("res://scripts/mobility_validation.gd").new())
		return
	qa_running=qa_running or "--script" in OS.get_cmdline_args() or ["--qa","--flight-qa","--experience-qa","--air-vehicle-qa","--visual-qa","--interactive-qa","--navigation-input-qa","--precinct-qa","--opera-access-qa"].any(func(flag):return flag in arguments)
	get_tree().auto_accept_quit=false
	setup_input()
	setup_environment()
	world=load("res://scripts/harbor_world.gd").new()
	add_child(world)
	world.process_mode=Node.PROCESS_MODE_PAUSABLE
	if ResourceLoader.exists("res://scripts/airport_world.gd"):
		airport=load("res://scripts/airport_world.gd").new()
		add_child(airport)
		airport.process_mode=Node.PROCESS_MODE_PAUSABLE
		airport.setup()
		world.anchors.merge(airport.anchors)
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
	setup_ui()
	if not qa_running: load_settings()
	else: apply_settings()
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
	elif "--visual-qa" in arguments:
		add_child(load("res://scripts/landmark_validation.gd").new())
	elif "--interactive-qa" in arguments:
		call_deferred("start_interactive_qa")
	elif "--navigation-input-qa" in arguments:
		add_child(load("res://scripts/navigation_input_validation.gd").new())
	elif "--opera-access-qa" in arguments:
		add_child(load("res://scripts/opera_access_validation.gd").new())
	elif "--precinct-qa" in arguments:
		add_child(load("res://scripts/precinct_validation.gd").new())
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
	var bindings={"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"rise":[KEY_R],"fall":[KEY_F],"brake":[KEY_SPACE],"jump":[KEY_SPACE],"sprint":[KEY_SHIFT],"interact":[KEY_E],"vehicles":[KEY_TAB],"jobs":[KEY_J],"map":[KEY_M],"experiences":[KEY_K],"carry":[KEY_G],"photo":[KEY_P],"save":[KEY_F5],"recover":[KEY_HOME]}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in bindings[action]:
			var event=InputEventKey.new()
			event.physical_keycode=key
			InputMap.action_add_event(action,event)
	if not InputMap.has_action("cursor"): InputMap.add_action("cursor")
	var cursor_key:=InputEventKey.new()
	cursor_key.physical_keycode=KEY_ALT
	if not InputMap.action_has_event("cursor",cursor_key): InputMap.action_add_event("cursor",cursor_key)

func setup_environment():
	environment=WorldEnvironment.new()
	var env=Environment.new()
	env.background_mode=Environment.BG_SKY
	var sky=Sky.new()
	var mat=ProceduralSkyMaterial.new()
	mat.sky_top_color=Color("477b9c")
	mat.sky_horizon_color=Color("cad6d7")
	mat.ground_horizon_color=Color("c1caca")
	mat.ground_bottom_color=Color("566b6a")
	mat.sky_curve=0.18
	mat.sun_angle_max=12
	sky.sky_material=mat
	env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy=0.7
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure=0.9
	env.fog_enabled=true
	env.fog_light_color=Color("bccdd1")
	env.fog_density=0.00004
	env.fog_sky_affect=0.2
	environment.environment=env
	add_child(environment)
	sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-37,-32,0)
	sun.light_color=Color("ffe3b7")
	sun.light_energy=0.9
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=450
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)

func setup_ui():
	canvas=CanvasLayer.new()
	add_child(canvas)
	font=SystemFont.new()
	font.font_names=PackedStringArray(["Avenir Next","PingFang SC","Arial"])
	var theme=Theme.new()
	theme.default_font=font
	theme.default_font_size=18
	theme.set_color("font_color","Label",Color("f1f1df"))
	var button_style=panel_style(Color(0.11,0.22,0.25,0.96),8)
	button_style.content_margin_left=18
	button_style.content_margin_right=18
	button_style.content_margin_top=13
	button_style.content_margin_bottom=13
	theme.set_stylebox("normal","Button",button_style)
	var hover=button_style.duplicate()
	hover.bg_color=Color("28545b")
	theme.set_stylebox("hover","Button",hover)
	var focus=button_style.duplicate()
	focus.border_color=Color("92d4c5")
	focus.set_border_width_all(2)
	theme.set_stylebox("focus","Button",focus)
	theme.set_color("font_color","Button",Color("f1efdc"))
	var root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.theme=theme
	canvas.add_child(root)
	hud=Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var top=PanelContainer.new()
	top.position=Vector2(28,24)
	top.size=Vector2(365,105)
	top.add_theme_stylebox_override("panel",panel_style(Color(0.025,0.09,0.12,0.82),10))
	hud.add_child(top)
	var topbox=VBoxContainer.new()
	topbox.add_theme_constant_override("separation",5)
	top.add_child(topbox)
	mode_label=label("HARBOURLIFE  /  SYDNEY",14,Color("8ed1c1"))
	topbox.add_child(mode_label)
	region_label=label("Circular Quay · 环形码头",23)
	topbox.add_child(region_label)
	info=label("",15,Color("d0d6c9"))
	topbox.add_child(info)
	activity_label=label("",18)
	activity_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.95))
	activity_label.add_theme_constant_override("shadow_offset_x",1)
	activity_label.add_theme_constant_override("shadow_offset_y",2)
	activity_label.position=Vector2(28,147)
	activity_label.size=Vector2(520,140)
	activity_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(activity_label)
	speed_label=label("",25)
	speed_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_label.position=Vector2(-350,-225)
	speed_label.size=Vector2(320,140)
	speed_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(speed_label)
	var bottom=PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left=28
	bottom.offset_right=-28
	bottom.offset_top=-76
	bottom.offset_bottom=-24
	bottom.add_theme_stylebox_override("panel",panel_style(Color(0.025,0.09,0.12,0.86),10))
	hud.add_child(bottom)
	context_hint=label("",16)
	context_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(context_hint)
	toast_label=label("",21,Color("f5e4b6"))
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.position=Vector2(-320,154)
	toast_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.9))
	toast_label.add_theme_constant_override("shadow_offset_y",2)
	toast_label.size=Vector2(800,100)
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(toast_label)
	save_indicator=label("",14,Color("a6d9c9"))
	save_indicator.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	save_indicator.position=Vector2(-260,30)
	save_indicator.size=Vector2(230,25)
	save_indicator.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(save_indicator)
	modal=PanelContainer.new()
	modal.position=Vector2(44,40)
	modal.size=Vector2(520,820)
	modal.add_theme_stylebox_override("panel",panel_style(Color(0.025,0.075,0.1,0.96),14))
	root.add_child(modal)
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(490,780)
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
	life.service_completed.connect(on_service_completed)

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
	var scroll:ScrollContainer=modal_content.get_parent()
	scroll.scroll_vertical=0
	for child in modal_content.get_children():
		modal_content.remove_child(child)
		child.queue_free()
	modal_content.add_child(label("H A R B O U R L I F E",15,Color("8ed1c1")))
	modal_content.add_child(label(title,36))
	if subtitle!="":
		var sub=label(subtitle,16,Color("bbc8c5"))
		sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size.x=430
		modal_content.add_child(sub)
	var line=HSeparator.new()
	modal_content.add_child(line)
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

func button(text_value:String,action:Callable):
	var b=Button.new()
	b.text=text_value
	b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(action)
	modal_content.add_child(b)
	return b

func main_menu():
	active_panel="main"
	hud.visible=false
	clear_panel("属于你的海港。","A life by the water.\n悉尼核心海港 · 单人离线世界 · v"+str(ProjectSettings.get_setting("application/config/version")))
	name_edit=LineEdit.new()
	name_edit.placeholder_text="为你的世界取个名字"
	name_edit.text="我的悉尼"
	name_edit.custom_minimum_size.y=45
	modal_content.add_child(name_edit)
	button("开始生活  →",func(): new_world("life",name_edit.text))
	button("自由沙盒  →",func(): new_world("sandbox",name_edit.text))
	if is_instance_valid(airport): button("从悉尼机场起飞  ↗",airport_start)
	modal_content.add_child(label("开局 $50,000 · 所有载具免费，新增就直接驾驶。\n轻松赚取旅费，探索美食、场馆与海滨体验。",15,Color("b7c4bc")))
	var worlds=[] if qa_running else Store.slots()
	if not worlds.is_empty():
		modal_content.add_child(label("继续你的世界",21))
		for entry in worlds.slice(0,4):
			button(str(entry.name)+"  ·  "+("沙盒" if entry.mode=="sandbox" else "生活"),func(): load_world(entry.id))
	button("存档与恢复",worlds_menu)
	button("操作与设置",settings_menu)
	button("制作与资料来源",credits_menu)
	button("退出",func(): get_tree().quit())

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
	world.repair_all()
	if is_instance_valid(airport) and airport.has_method("repair_all"): airport.repair_all()
	life.setup(world.anchors,mode=="sandbox")
	owned=VEHICLE_NAMES.keys()
	landmark_target_key=""
	landmark_target_name=""
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
	notify("$50,000 已到账 · Tab 免费新增并驾驶 · M 标点探索 · K 城市体验")
	if save_now: save_world()

func reset_fleet(with_defaults: bool = true):
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
	var placements={"car":home+Vector3(12,1,6),"motorcycle":home+Vector3(18,1,6),"hoverboard":home+Vector3(22,1,6),"speedboat":Vector3(marina.x-8.5,0.9,marina.z-28),"yacht":Vector3(marina.x-30,0.9,marina.z-64),"helicopter":helipad+Vector3(0,3,0),"paraglider":world.anchors.get("north",Vector3(50,5,-1350))+Vector3(40,90,0),"glider":Vector3(700,230,-1600),"airliner":Vector3(-4180,10.78,8600)}
	for kind in VEHICLE_NAMES:
		var v=make_vehicle(kind,"owned_"+kind,placements[kind])
		# Place parked contact geometry just above its authored support surface.
		# The new world has not necessarily flushed its Jolt broad phase yet.
		if kind in ["car","motorcycle","helicopter"]:
			var support:float=helipad.y-.20 if kind=="helicopter" else world.GROUND
			v.position.y=support-VehicleSpawn.envelope(v).position.y+.12
			v.reset_physics_interpolation()
		if kind in ["paraglider","glider","airliner"]: v.freeze=true
		if kind=="airliner" and is_instance_valid(airport):
			v.rotation.y=airport.runway_heading
			v.throttle=0.0

func make_vehicle(kind:String,id:String,pos:Vector3):
	var v=load("res://scripts/harbor_vehicle.gd").new()
	v.configure(kind,id)
	v.process_mode=Node.PROCESS_MODE_PAUSABLE
	add_child(v)
	v.global_position=pos
	v.reset_physics_interpolation()
	v.impacted.connect(on_impact.bind(v))
	vehicles.append(v)
	return v

func on_impact(point:Vector3,energy:float,source:RigidBody3D=null):
	world.damage_at(point,energy,clampf(sqrt(energy)*0.005,2,28))
	life.on_incident(point,energy,is_instance_valid(source) and source==current_vehicle)
	if is_instance_valid(airport) and airport.has_method("apply_impact"): airport.apply_impact(point,energy)
	if energy>8000: audio.crash(point)

func save_world() -> bool:
	if not active or world_id=="": return false
	var data={"name":world_name,"mode":mode,"player":vec(player.global_position),"yaw":yaw,"pitch":pitch,"owned":owned,"world":world.get_state(),"airport":airport.get_state() if is_instance_valid(airport) else {},"life":life.get_state(),"vehicles":[],"settings":settings,"elapsed":elapsed,"vehicle":current_vehicle.vehicle_id if is_instance_valid(current_vehicle) else "","spawn_target":spawn_target.vehicle_id if is_instance_valid(spawn_target) else ""}
	for v in vehicles: data.vehicles.append(v.get_state())
	data["map_revision"]=preload("res://scripts/map_migration.gd").REVISION
	data["navigation"]={"key":landmark_target_key,"title":landmark_target_name,"position":vec(landmark_target_position)}
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
	button("继续游玩",close_panel)
	button("保存世界",func():
		if save_world(): notify("世界已保存"))
	button("工作与活动",jobs_menu)
	button("我的载具",vehicles_menu)
	button("地图与位置",map_menu)
	button("城市体验 · 美食、场馆与海滨",experiences_menu)
	button("设置与操作",settings_menu)
	button("存档与恢复",worlds_menu)
	button("返回个人空间 · 救援",recover_player)
	button("找回遗失货物",func(): notify(life.recover_cargo()))
	button("修复建筑 · "+("免费" if mode=="sandbox" else "$500"),func():
		if mode=="sandbox" or life.spend(500,"世界修缮"):
			world.repair_all()
			airport.repair_all()
			notify("海港与机场建筑已修复"))
	button("保存并回到标题",func():
		if save_world():
			active=false
			for v in vehicles: v.occupied=false
			player.enabled=false
			get_tree().paused=false
			main_menu())
	button("保存并退出",quit_game)

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
	clear_panel("新增载具，立即出发。","全部免费 · 点击即生成并入座。自动寻找合适的道路、水面或机场；之前的载具继续保留。")
	for kind in VEHICLE_NAMES:
		button(VEHICLE_NAMES[kind]+" · 免费驾驶",func(): request_vehicle(kind))
	if is_instance_valid(current_vehicle):
		button("维修当前载具 · "+("免费" if mode=="sandbox" else "$120"),repair_vehicle)
	button("机场跑道起飞",airport_start)
	button("返回",close_panel)

func next_vehicle_id(kind:String) -> String:
	spawn_sequence+=1
	return "spawn_%s_%d_%d_%s"%[kind,Time.get_ticks_usec(),spawn_sequence,Crypto.new().generate_random_bytes(6).hex_encode()]

func request_vehicle(kind:String):
	if not VEHICLE_NAMES.has(kind): return null
	# Placement succeeds before changing the driver. Failure preserves the current ride.
	var v=make_vehicle(kind,next_vehicle_id(kind),Vector3(0,-2000,0))
	v.freeze=true
	v.visible=false
	var placement=VehicleSpawn.find_spawn(self,v)
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
	notify("已免费新增并入座 · %s\n%s · %s"%[VEHICLE_NAMES[kind],placement.description,vehicle_help(kind)])
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
	if not v.kind in owned: owned.append(v.kind)
	if is_instance_valid(current_vehicle) and current_vehicle!=v:
		current_vehicle.occupied=false
	current_vehicle=v
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
	notify(VEHICLE_NAMES[v.kind]+" · "+vehicle_help(v.kind))

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
	if not is_instance_valid(current_vehicle): return
	if mode!="sandbox" and not life.purchase("repair",120):
		notify("维修需要 $120",false)
		return
	current_vehicle.repair()
	notify("载具维修完成")

func recover_player():
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
	for group in ["bank_landmarks","metro_entrances","quay_landmarks","darling_square_frontages","cyber_landmarks","icc_landmarks","sydney_tower_landmark","circular_quay_detail","darling_square_detail","opera_interiors","darling_public_facilities","darling_precinct_businesses"]:
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

func set_navigation_target(key:String,title:String,position:Vector3):
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
	if active_panel!="map": close_panel()
	update_navigation(1.0)
	update_landmark_marker()
	notify("目的地已标记 · "+landmark_target_name+"\n跟随黄色标记与小地图；M 更换目的地。")

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
	landmark_target_key="map_pin"
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

func clear_landmark_target():
	landmark_target_key=""
	landmark_target_name=""
	if is_instance_valid(landmark_marker): landmark_marker.visible=false
	map_panel.target_key=""
	map_panel.refresh()
	update_navigation(1.0)
	notify("地标指引已清除")

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
	landmark_marker.text=("◎ 已到达 · "+landmark_target_name+"
K 城市体验  ·  M 选择下一个目的地") if distance<25 and absf(offset.y)<12 else ("◎ %s · %s · %s\n方向 %03d°  ·  M 地图  ·  K 城市体验"%[landmark_target_name,("%.2f km"%(distance/1000.0)) if distance>=1000 else ("%.0f m"%distance),direction,int(bearing)])

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

func settings_menu():
	active_panel="settings"
	clear_panel("让操作适合你。","WASD 移动 / 油门转向，鼠标观察，Shift 奔跑\nE 互动 / 上下车，空格跳跃 / 制动\nR / F 飞行升降，G 拿起 / 放下物件\nTab 免费新增并入座，J 工作，K 城市体验，M 开关地图\n按住 Alt / Option 显示鼠标，可点击小地图；松开继续观察\nF5 保存，Esc 暂停，P 摄影，Home 返回个人空间")
	modal_content.add_child(label("音量",18))
	var volume=HSlider.new()
	volume.min_value=0
	volume.max_value=1
	volume.step=0.05
	volume.value=settings.volume
	volume.value_changed.connect(func(v): settings.volume=v; apply_settings(); save_settings())
	modal_content.add_child(volume)
	modal_content.add_child(label("鼠标灵敏度",18))
	var sensitivity=HSlider.new()
	sensitivity.min_value=0.001
	sensitivity.max_value=0.008
	sensitivity.step=0.0005
	sensitivity.value=settings.sensitivity
	sensitivity.value_changed.connect(func(v): settings.sensitivity=v; save_settings())
	modal_content.add_child(sensitivity)
	var quality=OptionButton.new()
	quality.add_item("轻盈 · 关闭实时阴影")
	quality.add_item("标准 · 实时阴影")
	quality.add_item("精细 · 更远阴影")
	quality.select(int(settings.quality))
	quality.item_selected.connect(func(i): settings.quality=i; apply_settings(); save_settings())
	modal_content.add_child(quality)
	var invert=CheckButton.new()
	invert.text="反转垂直视角"
	invert.button_pressed=settings.invert
	invert.toggled.connect(func(v): settings.invert=v; save_settings())
	modal_content.add_child(invert)
	var large=CheckButton.new()
	large.text="加大游戏提示文字"
	large.button_pressed=settings.large_text
	large.toggled.connect(func(v): settings.large_text=v; apply_settings(); save_settings())
	modal_content.add_child(large)
	button("返回",pause_menu if active else main_menu)

func load_settings():
	if FileAccess.file_exists("user://settings.json"):
		var data=JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
		if data is Dictionary: settings.merge(data,true)
	apply_settings()

func apply_settings():
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(float(settings.volume),0.001)))
	sun.shadow_enabled=int(settings.quality)>0
	sun.directional_shadow_max_distance=700 if int(settings.quality)==2 else 350
	context_hint.add_theme_font_size_override("font_size",20 if settings.large_text else 16)
	activity_label.add_theme_font_size_override("font_size",22 if settings.large_text else 18)

func save_settings():
	var file=FileAccess.open("user://settings.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(settings))

func credits_menu():
	active_panel="credits"
	clear_panel("关于这片海港","Harbourlife · 开发预览 "+str(ProjectSettings.get_setting("application/config/version"))+"\n原创程序、建筑重建、材质和合成音效。")
	var text_value="Godot Engine 4.7.2 · MIT License\nhttps://godotengine.org/license\n\n建筑轮廓、道路与岸线：© OpenStreetMap contributors · ODbL 1.0\nhttps://www.openstreetmap.org/copyright\n\n主要地标、总部及所列店面参考建筑师、物业与商户公开资料及真实照片。普通楼体立面、大部分地形高程仍为近似；这不是完整的一比一城市扫描。\n\n各地标依据、数据日期、估算范围与许可附在源码 docs 和 licenses 中。系统字体由本机提供，不分发字体文件。"
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

func _input(event):
	# These shortcuts must run before focused GUI controls and before the paused
	# gameplay guard. Otherwise M cannot close the very map it opened.
	if event is InputEventKey and event.echo: return
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
	if event.is_action_pressed("map"):
		if active_panel=="map": close_panel()
		else: map_menu()
		get_viewport().set_input_as_handled()

func _unhandled_input(event):
	if not active or paused: return
	if event is InputEventMouseMotion and camera_accepts_mouse():
		yaw-=event.relative.x*float(settings.sensitivity)
		pitch=clampf(pitch-event.relative.y*float(settings.sensitivity)*(-1 if settings.invert else 1),-1.05,0.65)
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
	if life.has_method("take_photo"): life.take_photo(player.global_position)

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
	if not active:
		menu_orbit+=delta*0.015
		camera.global_position=Vector3(690+sin(menu_orbit)*35,170,-15)
		camera.look_at(Vector3(0,50,-650))
		return
	if paused: return
	elapsed+=delta
	autosave+=delta
	photo_cooldown-=delta
	if autosave>60 and not qa_running:
		autosave=0
		save_world()
	_update_follow_camera(delta)
	update_navigation(delta)
	update_spawn_marker()
	update_landmark_marker()
	update_hud()
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
	if is_instance_valid(current_vehicle) and Input.is_action_pressed("forward") and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
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

func update_hud():
	mode_label.text="HARBOURLIFE  /  "+("自由沙盒" if mode=="sandbox" else "生活")
	info.text="$%s    ·    耐力 %d%%    ·    %02d:%02d" %[life.money,player.stamina,16+int(elapsed/3600)%7,int(elapsed/60)%60]
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
	if is_instance_valid(current_vehicle):
		speed_label.text="%d km/h  ·  %d m\n%s  %d%%" %[current_vehicle.linear_velocity.length()*3.6,current_vehicle.global_position.y,VEHICLE_NAMES[current_vehicle.kind].split(" · ")[0],current_vehicle.health]
		if current_vehicle.kind=="airliner":
			speed_label.text+="\n推力 %d%% %s" %[current_vehicle.throttle*100,"失速 · 放低机头" if current_vehicle.stalled else ""]
			var forward=-current_vehicle.global_basis.z
			info.text="航向 %03d° · 海港 %.1f km" %[fposmod(rad_to_deg(atan2(forward.x,-forward.z)),360),current_vehicle.global_position.distance_to(world.anchors.opera)/1000]
		context_hint.text=vehicle_help(current_vehicle.kind)+"   E 离开   Tab 新增   M 地图   K 体验"
	else:
		speed_label.text="游泳" if player.swimming else ""
		var near=nearest_vehicle()
		var hint="E 进入 "+VEHICLE_NAMES[near.kind] if near else life.available_actions(player.global_position)
		context_hint.text=(hint+"   ·   " if hint!="" else "")+"WASD 行走   Shift 奔跑   G 搬运   J 工作   Tab 车库   M 地图"

func _notification(what):
	if what==NOTIFICATION_WM_CLOSE_REQUEST: quit_game()
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
	# Release looping WAV playback before engine teardown, including paused exits.
	get_tree().paused=false
	var pending: Array[Node]=[self]
	while not pending.is_empty():
		var node=pending.pop_back()
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
			node.stop()
			node.stream=null
		for child in node.get_children(): pending.append(child)
	for i in 5: await get_tree().process_frame
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
	if not active: new_world("sandbox","悉尼机场试飞")
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
	match kind:
		"car": return "W/S 加速倒车   A/D 转向   空格 制动 · 极速 420 km/h"
		"motorcycle": return "W/S 加速倒车   A/D 转向   空格 制动 · 极速 320 km/h"
		"yacht","speedboat": return "W/S 双机推力   A/D 船舵   空格 反向推力"
		"hoverboard": return "W/S 加速 / 后退 · 200 km/h   A/D 转向   R/F 升降   空格 急停 · 自动越阶 / 掠水"
		"helicopter": return "W/S 俯仰   A/D 偏航   R/F 升降 · 极速 350 km/h"
		"paraglider","glider": return "A/D 转弯   R/F 俯仰   空格 减速板 · 无动力"
		_: return "W/S 推力   A/D 转弯   R/F 俯仰   空格 减速板 · 极速 800 km/h"
