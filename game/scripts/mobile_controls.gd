extends Control
## Touch-only gameplay layer. Add to the main CanvasLayer, then setup(main).
## Existing menus retain mouse emulation; claimed gameplay touches cannot leak
## through to GUI buttons or become a second mouse-triggered weapon request.

const HOLD_ACTIONS := {
	"fire": ["fire"], "boost": ["sprint", "boost"],
	"brake": ["jump", "brake"], "rise": ["rise", "combat_raise"],
	"fall": ["fall", "combat_lower"], "drift": ["drift"],
}
const MOVE_ACTIONS := ["left", "right", "forward", "back"]
const AIR_KINDS := ["helicopter", "airliner", "fighter", "glider", "paraglider", "hoverboard", "tank"]
const DEAD_ZONE := 0.13

var host: Node
var enabled := false
var _focused := true
var _touches: Dictionary = {}
var _pressed_actions: Dictionary = {}
var _buttons: Dictionary = {}
var _button_styles: Dictionary = {}
var _safe := Rect2()
var _layout_size := Vector2.ZERO
var _stick_center := Vector2.ZERO
var _stick_radius := 92.0
var _stick_vector := Vector2.ZERO
var _scale := 1.0
var _kind := ""
var _draw_font: Font
var _mouse_echo_position := Vector2(-10000, -10000)
var _mouse_echo_until := 0

static func available() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("ios") or "--mobile-preview" in OS.get_cmdline_user_args()

func setup(game: Node) -> void:
	host = game
	enabled = available()
	name = "MobileControls"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_font = get_theme_default_font()
	if host.get("font") is Font: _draw_font = host.get("font")
	_refresh_layout()
	_sync_state()

func is_gameplay_enabled() -> bool:
	if not enabled or not _focused or not is_instance_valid(host): return false
	if not bool(host.get("active")) or bool(host.get("paused")): return false
	if is_inside_tree() and get_tree().paused: return false
	for property in ["modal", "map_panel", "diagnostics_panel"]:
		var panel: Variant = host.get(property)
		if is_instance_valid(panel) and panel is CanvasItem and panel.visible: return false
	return true

## Logical canvas coordinates, including the iPhone notch and home-indicator inset.
func safe_area_rect() -> Rect2:
	var bounds := Rect2(Vector2.ZERO, get_viewport_rect().size)
	if DisplayServer.get_name() == "headless" or not OS.has_feature("mobile"): return bounds
	var pixels := Rect2(DisplayServer.get_display_safe_area())
	if not pixels.has_area(): return bounds
	var mapped: Rect2 = get_viewport().get_screen_transform().affine_inverse() * pixels
	var result := bounds.intersection(mapped)
	return result if result.has_area() else bounds

## These areas should stay clear of desktop HUD panels while touch is enabled.
func reserved_rects() -> Array[Rect2]:
	var result: Array[Rect2] = [Rect2(_stick_center - Vector2.ONE * (_stick_radius + 20 * _scale), Vector2.ONE * (_stick_radius + 20 * _scale) * 2)]
	for id: String in _buttons:
		if _button_visible(id): result.append(_buttons[id].rect)
	return result

## Pure geometry entry point also used by the small no-world regression fixture.
func layout_for(view_size: Vector2, safe_rect := Rect2()) -> void:
	_layout_size = view_size
	_safe = Rect2(Vector2.ZERO, view_size).intersection(safe_rect) if safe_rect.has_area() else Rect2(Vector2.ZERO, view_size)
	_scale = clampf(minf(_safe.size.y / 720.0, _safe.size.x / 1180.0), 0.72, 1.15)
	var pad := 20.0 * _scale
	_stick_radius = 92.0 * _scale
	_stick_center = Vector2(_safe.position.x + 132 * _scale, _safe.end.y - 142 * _scale)
	var right := _safe.end.x - pad
	var bottom := _safe.end.y - pad
	_buttons.clear()
	var top_ids := ["vehicles", "map", "heal", "survival_services", "pause"]
	var top_text := ["载具", "地图", "急救", "整备", "暂停"]
	var toolbar_width := 5 * 88.0 * _scale + 4 * 10.0 * _scale
	var toolbar_x := _safe.get_center().x - toolbar_width / 2.0
	for i in top_ids.size():
		_buttons[top_ids[i]] = {"rect": Rect2(Vector2(toolbar_x + i * 98 * _scale, _safe.position.y + 94 * _scale), Vector2(88, 72) * _scale), "text": top_text[i]}
	_add_button("fire", "开火", Vector2(right - 108 * _scale, bottom - 120 * _scale), Vector2(108, 108) * _scale)
	_add_button("interact", "上下车", Vector2(right - 214 * _scale, bottom - 102 * _scale), Vector2(94, 84) * _scale)
	_add_button("boost", "奔跑", Vector2(right - 318 * _scale, bottom - 102 * _scale), Vector2(94, 84) * _scale)
	_add_button("brake", "跳跃", Vector2(right - 422 * _scale, bottom - 102 * _scale), Vector2(94, 84) * _scale)
	_add_button("rise", "升高", Vector2(right - 94 * _scale, bottom - 316 * _scale), Vector2(94, 84) * _scale)
	_add_button("fall", "降低", Vector2(right - 94 * _scale, bottom - 220 * _scale), Vector2(94, 84) * _scale)
	_add_button("drift", "漂移", Vector2(right - 214 * _scale, bottom - 202 * _scale), Vector2(94, 84) * _scale)
	_build_button_styles()
	queue_redraw()

func _add_button(id: String, text: String, at: Vector2, dimensions: Vector2) -> void:
	_buttons[id] = {"rect": Rect2(at, dimensions), "text": text}

func _build_button_styles() -> void:
	_button_styles.clear()
	for fire in [false, true]:
		for held in [false, true]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.13, 0.47, 0.59, 0.82) if held else Color(0.035, 0.075, 0.11, 0.58)
			style.border_color = Color(0.42, 0.92, 0.79, 0.85) if fire else Color(0.78, 0.92, 1.0, 0.42)
			style.set_border_width_all(2)
			style.set_corner_radius_all(int(24 * _scale if fire else 18 * _scale))
			_button_styles[("fire" if fire else "normal") + ("_held" if held else "")] = style

func _refresh_layout() -> void:
	if not is_inside_tree(): return
	var next_safe := safe_area_rect()
	if get_viewport_rect().size != _layout_size or next_safe != _safe:
		release_all()
		layout_for(get_viewport_rect().size, next_safe)

func _sync_state() -> void:
	var playing := is_gameplay_enabled()
	if not playing: release_all()
	visible = playing
	var vehicle: Variant = host.get("current_vehicle") if is_instance_valid(host) else null
	var next_kind: String = str(vehicle.get("kind")) if is_instance_valid(vehicle) else ""
	if next_kind != _kind:
		# A held jump or aircraft control must not carry into a newly entered vehicle.
		release_all()
		_kind = next_kind
		queue_redraw()

func _process(_delta: float) -> void:
	if not enabled:
		release_all()
		visible = false
		return
	_refresh_layout()
	_sync_state()
	if is_gameplay_enabled() and _is_held("fire"): _request_fire()

func _input(event: InputEvent) -> void:
	if not enabled: return
	# Godot uses device -1 for synthetic mouse events. Keep normal menu mouse
	# emulation, including after release, but swallow the echo of our own fingers.
	if event is InputEventMouse and event.device == -1 and Time.get_ticks_msec() <= _mouse_echo_until and event.position.distance_to(_mouse_echo_position) < 12.0:
		get_viewport().set_input_as_handled()
		return
	if handle_touch(event): get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# GUI gets first refusal on look gestures. Touching another HUD/menu control
	# must never start camera movement, even if that finger later leaves the UI.
	if handle_touch(event, true): get_viewport().set_input_as_handled()

func handle_touch(event: InputEvent, allow_look := false) -> bool:
	if not event is InputEventScreenTouch and not event is InputEventScreenDrag: return false
	if not is_gameplay_enabled():
		release_all()
		return false
	var index: int = event.index
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			if not _touches.has(index): return false
			var role: String = _touches[index]
			_touches.erase(index)
			_remember_mouse_echo(event.position)
			if role == "stick": _stick_vector = Vector2.ZERO
			_update_actions()
			if not event.canceled and not HOLD_ACTIONS.has(role) and _buttons.has(role) and _buttons[role].rect.has_point(event.position): _activate_tap(role)
			queue_redraw()
			return true
		if _touches.has(index): return true
		for id: String in _buttons:
			if _button_visible(id) and _buttons[id].rect.has_point(event.position):
				_touches[index] = id
				_remember_mouse_echo(event.position)
				_update_actions()
				queue_redraw()
				return true
		if event.position.distance_to(_stick_center) <= _stick_radius + 24 * _scale:
			_touches[index] = "blocked" if _is_held("stick") else "stick"
			if _touches[index] == "stick": _move_stick(event.position)
			_remember_mouse_echo(event.position)
			return true
		if allow_look and _look_region().has_point(event.position):
			_touches[index] = "blocked" if _is_held("look") else "look"
			_remember_mouse_echo(event.position)
			return true
	elif _touches.has(index):
		_remember_mouse_echo(event.position)
		match _touches[index]:
			"stick": _move_stick(event.position)
			"look": _move_camera(event.relative)
		# Held buttons retain their original finger until release. A swipe across
		# neighbouring buttons cannot accidentally press another action.
		return true
	return false

func _remember_mouse_echo(at: Vector2) -> void:
	_mouse_echo_position = at
	_mouse_echo_until = Time.get_ticks_msec() + 180

func _look_region() -> Rect2:
	return Rect2(Vector2(_safe.get_center().x, _safe.position.y + 176 * _scale), Vector2(_safe.size.x / 2.0, maxf(0, _safe.size.y - 196 * _scale)))

func _move_stick(at: Vector2) -> void:
	_stick_vector = ((at - _stick_center) / _stick_radius).limit_length(1.0)
	_update_actions()
	queue_redraw()

func _move_camera(relative: Vector2) -> void:
	if not relative.is_finite(): return
	var settings: Dictionary = host.get("settings") if host.get("settings") is Dictionary else {}
	var sensitivity := clampf(float(settings.get("sensitivity", 0.003)), 0.0005, 0.02) / _scale
	host.set("yaw", float(host.get("yaw")) - relative.x * sensitivity)
	host.set("pitch", clampf(float(host.get("pitch")) - relative.y * sensitivity * (-1.0 if settings.get("invert", false) else 1.0), -1.05, 0.65))

func _is_held(role: String) -> bool:
	return _touches.find_key(role) != null

func _update_actions() -> void:
	var wanted: Dictionary = {}
	var magnitude := _stick_vector.length()
	var move := _stick_vector.normalized() * ((magnitude - DEAD_ZONE) / (1.0 - DEAD_ZONE)) if magnitude > DEAD_ZONE else Vector2.ZERO
	wanted["left"] = maxf(0, -move.x)
	wanted["right"] = maxf(0, move.x)
	wanted["forward"] = maxf(0, -move.y)
	wanted["back"] = maxf(0, move.y)
	for role: String in HOLD_ACTIONS:
		for action: String in HOLD_ACTIONS[role]: wanted[action] = 1.0 if _is_held(role) else 0.0
	for action: String in wanted:
		if not InputMap.has_action(action): continue
		var strength := float(wanted[action])
		if strength > 0.0:
			Input.action_press(action, strength)
			_pressed_actions[action] = strength
		elif _pressed_actions.has(action):
			Input.action_release(action)
			_pressed_actions.erase(action)

func _request_fire() -> void:
	# Both production methods enforce health, eligibility and their own cooldown.
	# No touch-side timer, ammunition write or cooldown reset can bypass them.
	if not is_gameplay_enabled(): return
	if host.has_method("can_fire_weapon") and host.call("can_fire_weapon"):
		var weapons: Variant = host.get("weapons")
		if is_instance_valid(weapons): weapons.call("fire_current")
	elif _kind.is_empty():
		var survival: Variant = host.get("survival")
		if is_instance_valid(survival) and survival.has_method("fire_blaster"): survival.call("fire_blaster")

func _activate_tap(id: String) -> void:
	if not is_gameplay_enabled(): return
	if id == "pause":
		release_all()
		host.call("pause_menu")
	else:
		var event := InputEventAction.new()
		event.action = id
		event.pressed = true
		# Target the existing production route once. Feeding synthetic key/mouse
		# events back through Input would also activate unrelated GUI shortcuts.
		host.call("_input" if id == "map" else "_unhandled_input", event)
	_sync_state()

func _button_visible(id: String) -> bool:
	if id in ["rise", "fall"]: return _kind in AIR_KINDS
	if id == "drift": return _kind in ["car", "motorcycle"]
	return true

func release_all() -> void:
	if _pressed_actions.is_empty() and _touches.is_empty() and _stick_vector == Vector2.ZERO: return
	for action: String in _pressed_actions: Input.action_release(action)
	_pressed_actions.clear()
	_touches.clear()
	_stick_vector = Vector2.ZERO
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_focused = false
		release_all()
		visible = false
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		_focused = true
	elif what == NOTIFICATION_EXIT_TREE: release_all()

func _draw() -> void:
	if not is_gameplay_enabled() or _draw_font == null: return
	var rim := Color(0.78, 0.92, 1.0, 0.42)
	var fill := Color(0.035, 0.075, 0.11, 0.58)
	draw_circle(_stick_center, _stick_radius + 12 * _scale, fill)
	draw_arc(_stick_center, _stick_radius + 12 * _scale, 0, TAU, 64, rim, 2 * _scale, true)
	draw_circle(_stick_center + _stick_vector * _stick_radius * 0.64, 38 * _scale, Color(0.64, 0.85, 0.98, 0.52 if _is_held("stick") else 0.26))
	_draw_text("移动 / 转向", Rect2(_stick_center + Vector2(-90, 112) * _scale, Vector2(180, 24) * _scale), 17)
	for id: String in _buttons:
		if not _button_visible(id): continue
		var rect: Rect2 = _buttons[id].rect
		var style: StyleBoxFlat = _button_styles[("fire" if id == "fire" else "normal") + ("_held" if _is_held(id) else "")]
		draw_style_box(style, rect)
		var title: String = _buttons[id].text
		if id == "boost": title = "加速" if not _kind.is_empty() else "奔跑"
		elif id == "brake": title = "刹车" if not _kind.is_empty() else "跳跃"
		elif id == "interact": title = "下车" if not _kind.is_empty() else "互动"
		elif id == "rise" and _kind == "tank": title = "抬炮"
		elif id == "fall" and _kind == "tank": title = "压炮"
		_draw_text(title, rect, 23 if id == "fire" else 20)
	_draw_text("右侧滑动 · 转动视角", Rect2(Vector2(_safe.get_center().x - 140 * _scale, _safe.end.y - 48 * _scale), Vector2(280, 28) * _scale), 16)

func _draw_text(text: String, rect: Rect2, point_size: int) -> void:
	var font_size := int(point_size * _scale)
	var baseline := rect.get_center().y + (_draw_font.get_ascent(font_size) - _draw_font.get_descent(font_size)) / 2.0
	draw_string(_draw_font, Vector2(rect.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, Color(0.91, 0.97, 1.0, 0.94))
