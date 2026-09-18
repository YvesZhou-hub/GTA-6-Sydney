extends RefCounted
## Player settings that PC and Steam Deck players expect: display, frame pacing,
## upscaling, anti-aliasing, field of view, controller input and key rebinding.
## main.gd owns the menu; this file owns defaults, validation and application.

const DEFAULTS := {
	"volume": 0.65, "sensitivity": 0.003, "quality": 1, "invert": false, "large_text": false,
	"window_mode": "windowed", "vsync": true, "max_fps": 0, "render_scale": 1.0,
	"antialiasing": "msaa2", "fov": 68.0, "pad_sensitivity": 2.6, "mute_unfocused": false,
	"street_life": 1, "combat_difficulty": 1,
	"bindings": {},
}
const WINDOW_MODES := [["windowed", "窗口"], ["borderless", "全屏（无边框）"], ["fullscreen", "独占全屏"]]
const FPS_LIMITS := [0, 30, 60, 120, 144, 240]
const RENDER_SCALES := [1.0, 0.85, 0.75, 0.67, 0.5]
const COMBAT_DIFFICULTY := [["轻松", "奶龙更少更弱，保护更久"], ["标准", "默认平衡"], ["硬核", "奶龙更多更强，保护更短，奖金更高"]]
const STREET_LIFE := [["关闭", "街上没有车流和行人"], ["正常", "附近有车流和行人"], ["热闹", "更多车流和行人 · 更吃性能"]]
const ANTIALIASING := [["off", "关闭"], ["fxaa", "FXAA · 最省性能"], ["msaa2", "MSAA 2× · 默认"], ["msaa4", "MSAA 4× · 更平滑"], ["taa", "TAA · 首次开启需编译数秒"]]
const PAD_DEADZONE := 0.2

## Rebindable keyboard controls. Paired actions intentionally share one key.
const REBINDABLE := [
	["前进 / 油门", ["forward"]], ["后退 / 倒车", ["back"]], ["左转", ["left"]], ["右转", ["right"]],
	["奔跑 / 3 倍加速", ["sprint", "boost"]], ["跳跃 / 刹车", ["jump", "brake"]], ["漂移", ["drift"]],
	["飞行升高 / 炮管抬高", ["rise", "combat_raise"]], ["飞行下降 / 炮管压低", ["fall", "combat_lower"]],
	["互动 / 上下车", ["interact"]], ["开火（键盘）", ["fire"]], ["载具", ["vehicles"]], ["地图", ["map"]],
	["工作与活动", ["jobs"]], ["城市体验", ["experiences"]], ["急救 / 快修", ["heal"]],
	["战地整备", ["survival_services"]], ["自动武器开关", ["auto_support"]], ["拿起 / 放下", ["carry"]],
	["拍照", ["photo"]], ["保存", ["save"]], ["救援", ["recover"]],
]

const KEY_NAMES := {"Space": "空格", "Escape": "Esc"}

static var default_keys: Dictionary = {}
static var _hint_cache: Dictionary = {}


static func sanitized(data: Dictionary) -> Dictionary:
	var result := DEFAULTS.duplicate(true)
	for key: String in data:
		if not result.has(key): continue
		var fallback: Variant = DEFAULTS[key]
		var value: Variant = data[key]
		if typeof(fallback) == TYPE_BOOL and typeof(value) == TYPE_BOOL: result[key] = value
		elif typeof(fallback) in [TYPE_INT, TYPE_FLOAT] and typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)): result[key] = value
		elif typeof(fallback) == TYPE_STRING and typeof(value) == TYPE_STRING: result[key] = value
		elif typeof(fallback) == TYPE_DICTIONARY and typeof(value) == TYPE_DICTIONARY: result[key] = value
	result.volume = clampf(float(result.volume), 0.0, 1.0)
	result.sensitivity = clampf(float(result.sensitivity), 0.0005, 0.02)
	result.quality = clampi(int(result.quality), 0, 2)
	result.street_life = clampi(int(result.street_life), 0, 2)
	result.combat_difficulty = clampi(int(result.combat_difficulty), 0, 2)
	result.max_fps = int(result.max_fps) if int(result.max_fps) in FPS_LIMITS else 0
	result.render_scale = clampf(float(result.render_scale), 0.5, 1.0)
	result.fov = clampf(float(result.fov), 55.0, 95.0)
	result.pad_sensitivity = clampf(float(result.pad_sensitivity), 0.8, 6.0)
	if not WINDOW_MODES.any(func(row: Array): return row[0] == result.window_mode): result.window_mode = "windowed"
	if not ANTIALIASING.any(func(row: Array): return row[0] == result.antialiasing): result.antialiasing = "msaa2"
	var bindings := {}
	for group: Array in REBINDABLE:
		var codes: Variant = result.bindings.get(group[1][0], null)
		if codes is Array and not codes.is_empty() and codes.all(func(code: Variant): return typeof(code) in [TYPE_INT, TYPE_FLOAT] and int(code) > 0):
			bindings[group[1][0]] = codes.map(func(code: Variant): return int(code))
	result.bindings = bindings
	return result


static func apply_display(settings: Dictionary, viewport: Viewport, camera: Camera3D, allow_window_changes: bool) -> void:
	if allow_window_changes and DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_WINDOWED
		if settings.window_mode == "borderless": mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		elif settings.window_mode == "fullscreen": mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if DisplayServer.window_get_mode() != mode: DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = int(settings.max_fps)
	var scale := float(settings.render_scale)
	viewport.scaling_3d_scale = scale
	# FSR 1 is a spatial upscaler. FSR 2 needs motion-vector pipelines that took
	# 8-68 s to compile across the city on first use, freezing the game mid-menu.
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 0.999 else Viewport.SCALING_3D_MODE_BILINEAR
	var aa: String = settings.antialiasing
	viewport.msaa_3d = Viewport.MSAA_4X if aa == "msaa4" else Viewport.MSAA_2X if aa == "msaa2" else Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == "fxaa" else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = aa == "taa"
	if is_instance_valid(camera): camera.fov = float(settings.fov)


static func _key(physical: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	return event


static func _pad_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


static func _pad_axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	return event


## Xbox-style layout; Godot maps PlayStation, Switch Pro and Steam Deck controls to the same indices.
static func add_gamepad_bindings() -> void:
	var layout := {
		"forward": [_pad_axis(JOY_AXIS_LEFT_Y, -1.0)], "back": [_pad_axis(JOY_AXIS_LEFT_Y, 1.0)],
		"left": [_pad_axis(JOY_AXIS_LEFT_X, -1.0)], "right": [_pad_axis(JOY_AXIS_LEFT_X, 1.0)],
		"look_left": [_pad_axis(JOY_AXIS_RIGHT_X, -1.0)], "look_right": [_pad_axis(JOY_AXIS_RIGHT_X, 1.0)],
		"look_up": [_pad_axis(JOY_AXIS_RIGHT_Y, -1.0)], "look_down": [_pad_axis(JOY_AXIS_RIGHT_Y, 1.0)],
		"jump": [_pad_button(JOY_BUTTON_A)], "brake": [_pad_button(JOY_BUTTON_A)],
		"interact": [_pad_button(JOY_BUTTON_B)], "drift": [_pad_button(JOY_BUTTON_X)],
		"vehicles": [_pad_button(JOY_BUTTON_Y)],
		"sprint": [_pad_axis(JOY_AXIS_TRIGGER_LEFT, 1.0), _pad_button(JOY_BUTTON_LEFT_STICK)],
		"boost": [_pad_axis(JOY_AXIS_TRIGGER_LEFT, 1.0), _pad_button(JOY_BUTTON_LEFT_STICK)],
		"fire": [_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"rise": [_pad_button(JOY_BUTTON_RIGHT_SHOULDER)], "fall": [_pad_button(JOY_BUTTON_LEFT_SHOULDER)],
		"combat_raise": [_pad_button(JOY_BUTTON_RIGHT_SHOULDER)], "combat_lower": [_pad_button(JOY_BUTTON_LEFT_SHOULDER)],
		"map": [_pad_button(JOY_BUTTON_DPAD_UP)], "heal": [_pad_button(JOY_BUTTON_DPAD_DOWN)],
		"jobs": [_pad_button(JOY_BUTTON_DPAD_LEFT)], "survival_services": [_pad_button(JOY_BUTTON_DPAD_RIGHT)],
		"auto_support": [_pad_button(JOY_BUTTON_RIGHT_STICK)], "experiences": [_pad_button(JOY_BUTTON_BACK)],
		"pause": [_pad_button(JOY_BUTTON_START)],
	}
	for action: String in layout:
		if not InputMap.has_action(action): InputMap.add_action(action, PAD_DEADZONE)
		else: InputMap.action_set_deadzone(action, PAD_DEADZONE)
		for event: InputEvent in layout[action]:
			if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)


static func capture_default_keys() -> void:
	if not default_keys.is_empty(): return
	for group: Array in REBINDABLE:
		for action: String in group[1]:
			if not InputMap.has_action(action): continue
			var codes := []
			for event: InputEvent in InputMap.action_get_events(action):
				if event is InputEventKey: codes.append(int(event.physical_keycode))
			default_keys[action] = codes


static func apply_bindings(bindings: Dictionary) -> void:
	capture_default_keys()
	_hint_cache.clear()
	for group: Array in REBINDABLE:
		var custom: Variant = bindings.get(group[1][0], null)
		for action: String in group[1]:
			if not InputMap.has_action(action): continue
			for event: InputEvent in InputMap.action_get_events(action):
				if event is InputEventKey: InputMap.action_erase_event(action, event)
			for code: Variant in (custom if custom is Array else default_keys.get(action, [])):
				InputMap.action_add_event(action, _key(int(code)))


static func key_label(action: String) -> String:
	var names := []
	if InputMap.has_action(action):
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				names.append(_key_name(event.physical_keycode))
	return " / ".join(names) if not names.is_empty() else "未绑定"


## Name of a physical key on the player's keyboard layout. Headless runs have no
## layout and the lookup logs an error per call, so they use the physical name.
static func _key_name(physical: Key) -> String:
	if DisplayServer.get_name() == "headless": return OS.get_keycode_string(physical)
	var keycode := DisplayServer.keyboard_get_keycode_from_physical(physical)
	return OS.get_keycode_string(keycode if keycode != KEY_NONE else physical)


## First keyboard key of an action, as hints show it. Follows rebinding and keyboard layout.
static func primary_key(action: String) -> String:
	if InputMap.has_action(action):
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var label := _key_name(event.physical_keycode)
				return KEY_NAMES.get(label, label)
	return "未绑定"


## Fills {action} placeholders in a hint with current keys; {move} is the four walking keys.
## Results are cached per template until bindings change, so HUD code can call it every frame.
static func keys(template: String) -> String:
	if _hint_cache.has(template): return _hint_cache[template]
	var result := template
	for found: RegExMatch in RegEx.create_from_string("\\{([a-z_]+)\\}").search_all(template):
		var action := found.get_string(1)
		var label := primary_key(action)
		if action == "move":
			var parts := PackedStringArray(["forward", "left", "back", "right"].map(func(name: String): return primary_key(name)))
			label = "".join(parts) if Array(parts).all(func(part: String): return part.length() == 1) else "/".join(parts)
		result = result.replace(found.get_string(), label)
	_hint_cache[template] = result
	return result


static func conflicts(bindings: Dictionary, group_key: String, code: int) -> Array:
	# Paired actions share keys by design, so only report other groups.
	var other := []
	for group: Array in REBINDABLE:
		if group[1][0] == group_key: continue
		for action: String in group[1]:
			if not InputMap.has_action(action): continue
			for event: InputEvent in InputMap.action_get_events(action):
				if event is InputEventKey and int(event.physical_keycode) == code and not other.has(group[0]): other.append(group[0])
	return other


static func pad_hint(vehicle_kind: String, survival: bool) -> String:
	if vehicle_kind.is_empty():
		return "左摇杆 移动 · 右摇杆 视角 · A 跳跃 · LT 奔跑 · B 互动 / 上车 · Y 载具 · ↑ 地图 · Start 暂停" + ("\nRT 反击 · ↓ 急救 · → 整备 · R3 自动武器" if survival else "")
	var flying := vehicle_kind in ["airliner", "fighter", "helicopter", "glider", "paraglider", "hoverboard"]
	return "左摇杆 驾驶 · 右摇杆 视角 · LT 3 倍加速 · A 刹车" + (" · RB / LB 升降俯仰" if flying else " · X 漂移") + " · B 离开 · Y 新增 · ↑ 地图" + ("\nRT 开火 · ↓ 快修 · → 整备 · R3 自动武器" if survival else "")
