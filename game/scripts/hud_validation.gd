extends Node
## HUD layout evidence at common PC and Steam Deck window sizes. Measures the
## visible rectangles of production HUD elements, fails on overlaps or content
## outside the visible canvas, and saves one native screenshot per case.
const OUTPUT := "user://hud-qa"
const SIZES := [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1440, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(2560, 1080)]
var game: Node
var checks: Array[Dictionary] = []
var screenshots: Array[Dictionary] = []
var native := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func check(title: String, okay: bool, detail: Dictionary = {}) -> void:
	checks.append({"name": title, "passed": okay, "detail": detail})
	print("HUD_QA ", "PASS " if okay else "FAIL ", title, " ", JSON.stringify(detail))


func frames(count: int = 3) -> void:
	for _i in count: await get_tree().process_frame


static func label_text_rect(label: Label) -> Rect2:
	if not is_instance_valid(label) or not label.is_visible_in_tree() or label.text.strip_edges().is_empty(): return Rect2()
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var lines := label.get_visible_line_count()
	var width := 0.0
	for line: String in label.text.split("\n"):
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	width = minf(width, label.size.x)
	var height := lines * label.get_line_height()
	var x := label.global_position.x
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT: x += label.size.x - width
	elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER: x += (label.size.x - width) * 0.5
	return Rect2(x, label.global_position.y, width, height)


func element_rects() -> Dictionary:
	var rects := {}
	var top: Control = game.region_label.get_parent().get_parent()
	if top.is_visible_in_tree(): rects["status_panel"] = top.get_global_rect()
	if game.activity_panel.is_visible_in_tree(): rects["activity_panel"] = game.activity_panel.get_global_rect()
	if is_instance_valid(game.campaign) and game.campaign.panel.is_visible_in_tree(): rects["objective_panel"] = game.campaign.panel.get_global_rect()
	if is_instance_valid(game.districts) and game.districts.panel.is_visible_in_tree(): rects["district_panel"] = game.districts.panel.get_global_rect()
	if game.survival_hud.is_visible_in_tree():
		rects["survival_card"] = Rect2(game.survival_hud.global_position + game.survival_hud._card_rect.position, game.survival_hud._card_rect.size)
	if game.minimap.is_visible_in_tree(): rects["minimap"] = game.minimap.get_global_rect()
	if game.navigation_hud.is_visible_in_tree():
		var nav: Control = game.navigation_hud
		var width := minf(460.0, nav.size.x * 0.33)
		rects["compass"] = Rect2(nav.global_position + Vector2(nav.size.x * 0.52 - width * 0.5, 22), Vector2(width, 60))
	if game.hint_panel.is_visible_in_tree(): rects["hint_bar"] = game.hint_panel.get_global_rect()
	if game.vehicle_panel.is_visible_in_tree(): rects["vehicle_readout"] = game.vehicle_panel.get_global_rect()
	if game.toast_panel.is_visible_in_tree() and game.toast_panel.modulate.a > 0.05: rects["toast"] = game.toast_panel.get_global_rect()
	if game.fire_button.is_visible_in_tree(): rects["fire_button"] = game.fire_button.get_global_rect()
	var destination := label_text_rect(game.landmark_marker)
	if destination.has_area(): rects["destination_readout"] = destination
	var save := label_text_rect(game.save_indicator)
	if save.has_area(): rects["save_indicator"] = save
	return rects


func measure(scene: String, window_size: Vector2i) -> void:
	var canvas: Rect2 = game.hud.get_viewport().get_visible_rect()
	var rects := element_rects()
	var tag := "%s %dx%d" % [scene, window_size.x, window_size.y]
	var outside := []
	for key: String in rects:
		var rect: Rect2 = rects[key]
		if not canvas.grow(0.5).encloses(rect): outside.append({"element": key, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
	check(tag + ": HUD elements stay inside the visible canvas", outside.is_empty(), {"canvas": [canvas.size.x, canvas.size.y], "outside": outside})
	var overlaps := []
	var keys: Array = rects.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Rect2 = rects[keys[i]]
			var b: Rect2 = rects[keys[j]]
			if a.intersects(b): overlaps.append([keys[i], keys[j], snappedf(a.intersection(b).get_area(), 0.1)])
	var layout := {}
	for key: String in rects: layout[key] = [snappedf(rects[key].position.x, 0.1), snappedf(rects[key].position.y, 0.1), snappedf(rects[key].size.x, 0.1), snappedf(rects[key].size.y, 0.1)]
	check(tag + ": HUD elements do not overlap", overlaps.is_empty(), {"layout": layout, "overlaps": overlaps})
	# The 3D view must fill the window rather than letterboxing wide displays.
	var window_size_now := Vector2(get_tree().root.size)
	var bars := absf(canvas.size.aspect() - window_size_now.aspect()) > 0.01
	check(tag + ": canvas matches the window aspect (no letterbox bars)", not bars, {"canvas_aspect": snappedf(canvas.size.aspect(), 0.001), "window_aspect": snappedf(window_size_now.aspect(), 0.001)})
	await capture("%s-%dx%d" % [scene, window_size.x, window_size.y])


func capture(name: String) -> void:
	if not native: return
	await frames(2)
	if await drawn_frame("capture " + name, 30.0) < 0.0: return
	var picture := get_tree().root.get_texture().get_image()
	var filename := name + ".png"
	var error := picture.save_png(OUTPUT.path_join(filename))
	screenshots.append({"file": filename, "saved": error == OK, "resolution": [picture.get_width(), picture.get_height()]})


func run(host: Node) -> void:
	game = host
	native = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await frames(3)
	if not game.world._ready_complete:
		check("production world assembled", false)
		return finish()
	game.qa_running = true
	game.new_world("survival", "HUD QA - no save", false)
	game.survival.auto_spawn = false
	game.notify("$50,000 已到账 · 12 秒保护，奶龙正在接近\n左键反击 / Tab 武装载具 · H 急救 / 快修 · B 升级", false)
	# A long destination name exercises the bottom-left readout against the hint bar.
	game.set_navigation_target("campaign_quay", "港城第一天 · 开到环形码头", game.world.anchors.quay, false)
	await frames(45)
	var window := get_tree().root
	for window_size: Vector2i in SIZES:
		window.size = window_size
		await frames(10)
		await measure("foot", window_size)
	var tank = game.request_vehicle("tank")
	check("armed vehicle spawned for the driving HUD", tank != null)
	await frames(60)
	for window_size: Vector2i in SIZES:
		window.size = window_size
		await frames(10)
		await measure("tank", window_size)
	await check_settings_and_gamepad(window)
	finish()


func drawn_frame(label: String, timeout: float = 120.0) -> float:
	# Poll the engine's drawn-frame counter: frame_post_draw is not always delivered
	# to scripts while menus pause the tree, even though frames keep rendering.
	var started := Time.get_ticks_msec()
	var target := Engine.get_frames_drawn() + 1
	while Engine.get_frames_drawn() < target and Time.get_ticks_msec() - started < timeout * 1000.0:
		await get_tree().process_frame
	var drawn := Engine.get_frames_drawn() >= target
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("HUD_QA FRAME %s %s after %.2f s" % [label, "drawn" if drawn else "NOT DRAWN", elapsed])
	return elapsed if drawn else -1.0


func press_pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(3)


func check_settings_and_gamepad(window: Window) -> void:
	const GameSettings = preload("res://scripts/game_settings.gd")
	var clean := GameSettings.sanitized({"fov": 999, "window_mode": "bogus", "max_fps": 77, "render_scale": 0.1, "antialiasing": "ssaa", "bindings": {"jump": ["x"], "map": [KEY_N]}})
	check("invalid saved settings are clamped or reset", clean.fov == 95.0 and clean.window_mode == "windowed" and clean.max_fps == 0 and clean.render_scale == 0.5 and clean.antialiasing == "msaa2" and not clean.bindings.has("jump") and clean.bindings.get("map") == [KEY_N], clean)
	var viewport: Viewport = game.get_viewport()
	await drawn_frame("before settings changes")
	game.settings.render_scale = 0.67
	game.settings.antialiasing = "msaa4"
	game.settings.fov = 80.0
	game.apply_settings()
	var upscale_seconds := await drawn_frame("after FSR 1 at 67%")
	check("render scale below 100% switches to FSR 1 and keeps MSAA", viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR and is_equal_approx(viewport.scaling_3d_scale, 0.67) and viewport.msaa_3d == Viewport.MSAA_4X)
	check("switching render scale does not stall rendering", upscale_seconds >= 0.0 and upscale_seconds < 2.0, {"seconds": upscale_seconds})
	check("field of view setting reaches the gameplay camera", is_equal_approx(game.camera.fov, 80.0))
	game.settings.render_scale = 1.0
	game.apply_settings()
	await drawn_frame("after native + MSAA 4x")
	check("native resolution restores bilinear scaling with MSAA 4x", viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR and viewport.msaa_3d == Viewport.MSAA_4X)
	game.settings = GameSettings.DEFAULTS.duplicate(true)
	game.apply_settings()
	await drawn_frame("after defaults (MSAA 2x)")
	game.settings_menu()
	await drawn_frame("after opening settings menu")
	await frames(10)
	for window_size: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		window.size = window_size
		await frames(10)
		var canvas: Rect2 = game.hud.get_viewport().get_visible_rect()
		check("settings %dx%d: menu panel fits the canvas" % [window_size.x, window_size.y], canvas.encloses(game.modal.get_global_rect()), {"modal": [game.modal.global_position.x, game.modal.global_position.y, game.modal.size.x, game.modal.size.y]})
		await capture("settings-%dx%d" % [window_size.x, window_size.y])
	game._rebind_group = "jump"
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	key.keycode = KEY_J
	key.pressed = true
	game._input(key)
	var jump_keys := InputMap.action_get_events("jump").filter(func(event: InputEvent): return event is InputEventKey).map(func(event: InputEventKey): return event.physical_keycode)
	var brake_keys := InputMap.action_get_events("brake").filter(func(event: InputEvent): return event is InputEventKey).map(func(event: InputEventKey): return event.physical_keycode)
	check("rebinding jump moves the paired brake action to the same key", jump_keys == [KEY_J] and brake_keys == [KEY_J], {"jump": jump_keys, "brake": brake_keys})
	var notice := ""
	for child: Node in game.modal_content.get_children():
		if child is Label and "同时用于" in child.text: notice = child.text
	check("rebinding J warns that Jobs already uses it", game.active_panel == "settings" and "工作与活动" in notice, {"notice": notice})
	game.settings.bindings = {}
	game.apply_settings()
	jump_keys = InputMap.action_get_events("jump").filter(func(event: InputEvent): return event is InputEventKey).map(func(event: InputEventKey): return event.physical_keycode)
	check("default keys restore after clearing bindings", jump_keys == [KEY_SPACE], {"jump": jump_keys})
	game.settings.bindings = {"map": [KEY_N], "heal": [KEY_U]}
	game.apply_settings()
	game.close_panel()
	await frames(5)
	check("control hints follow rebound keys", "N 地图" in game.context_hint.text and not "M 地图" in game.context_hint.text and game.survival_hud._heal_button.text.begins_with("U "), {"hint": game.context_hint.text, "heal": game.survival_hud._heal_button.text})
	game.settings.bindings = {}
	game.apply_settings()
	await frames(5)
	check("control hints return to default keys", "M 地图" in game.context_hint.text and game.survival_hud._heal_button.text.begins_with("H "), {"hint": game.context_hint.text})
	await press_pad(JOY_BUTTON_START)
	await frames(5)
	var focus: Control = game.get_viewport().gui_get_focus_owner()
	check("controller Start opens the pause menu with a focused button", game.active_panel == "pause" and game.modal.visible and focus is Button and game.modal.is_ancestor_of(focus), {"panel": game.active_panel, "focus": str(focus)})
	await press_pad(JOY_BUTTON_B)
	await frames(5)
	check("controller B closes the menu back to gameplay", not game.modal.visible and not game.paused)
	var yaw_before: float = game.yaw
	Input.action_press("look_right", 1.0)
	await frames(20)
	Input.action_release("look_right")
	check("right stick turns the camera", game.yaw < yaw_before - 0.05, {"before": yaw_before, "after": game.yaw})


func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(row: Dictionary): return row.passed)
	var report := {"passed": passed, "native": native, "checks": checks, "screenshots": screenshots}
	var file := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report, "\t"))
	print("HUD_QA COMPLETE checks=%d failures=%d" % [checks.size(), checks.filter(func(row: Dictionary): return not row.passed).size()])
	game.active = false
	game.finish_quit(0 if passed else 1)
