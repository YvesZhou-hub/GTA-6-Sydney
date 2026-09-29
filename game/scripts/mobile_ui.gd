extends Node
## Runs after desktop HUD updates, preserving the existing gameplay/menu routes.
const Profile = preload("res://scripts/mobile_profile.gd")
var host: Node
var enabled := false
var health_panel: PanelContainer
var health_label: Label
var health_bar: ProgressBar
var status_label: Label
var _state_clock := 0.0
var _layout_cache: Dictionary = {}
var _last_safe := Rect2()
var _last_map := false
var _last_modal_visible := false
var _menu_dirty := true

func setup(game: Node, profile: Dictionary = {}) -> void:
	host = game
	enabled = Profile.is_mobile() if profile.is_empty() else bool(profile.get("enabled", false))
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100
	if not enabled:
		set_process(false)
		return
	_build_health()
	_process(0.0)

static func layout_rects(safe: Rect2, with_map := false) -> Dictionary:
	var inset := 16.0
	var status_width := minf(320.0, safe.size.x * 0.27)
	var menu_width := minf(480.0 if with_map else 560.0, safe.size.x - inset * 2)
	var menu_x := safe.position.x + inset if with_map else safe.get_center().x - menu_width * 0.5
	var modal := Rect2(Vector2(menu_x, safe.position.y + inset), Vector2(menu_width, safe.size.y - inset * 2))
	var available_middle := safe.size.x - 260.0 - 460.0
	var readout_width := minf(300.0, maxf(160.0, available_middle - 24.0))
	var touch_scale := clampf(minf(safe.size.y / 720.0, safe.size.x / 1180.0), 0.72, 1.15)
	# Keep notifications in the top HUD lane, below the compass and toolbar,
	# with clear space between the status cards and the minimap.
	var toast_left := safe.position.x + 24.0 + status_width + 12.0
	var toast_right := safe.end.x - 216.0 - 12.0
	var toast_width := minf(640.0, maxf(0.0, toast_right - toast_left))
	var toast_x := clampf(safe.get_center().x - toast_width * 0.5, toast_left, toast_right - toast_width)
	return {
		"status": Rect2(safe.position + Vector2(24, 20), Vector2(status_width, 100)),
		"health": Rect2(safe.position + Vector2(24, 132), Vector2(status_width, 110)),
		"minimap": Rect2(Vector2(safe.end.x - 216, safe.position.y + 16), Vector2(200, 220)),
		"toast": Rect2(Vector2(toast_x, safe.position.y + 166.0 * touch_scale + 8.0), Vector2(toast_width, 60)),
		"vehicle": Rect2(Vector2(safe.position.x + 260 + (available_middle - readout_width) * 0.5, safe.end.y - 172), Vector2(readout_width, 112)),
		"modal": modal,
		"map": Rect2(Vector2(modal.end.x + 16, modal.position.y), Vector2(maxf(0, safe.end.x - inset - modal.end.x - 16), modal.size.y)),
	}

func _build_health() -> void:
	health_panel = PanelContainer.new()
	health_panel.name = "MobileHealth"
	health_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.075, 0.10, 0.80)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	health_panel.add_theme_stylebox_override("panel", style)
	host.get("hud").add_child(health_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	health_panel.add_child(column)
	health_label = Label.new()
	health_label.add_theme_font_size_override("font_size", 18)
	health_label.clip_text = true
	column.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size.y = 10
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("86d9b8")
	fill.set_corner_radius_all(5)
	health_bar.add_theme_stylebox_override("fill", fill)
	var background := fill.duplicate()
	background.bg_color = Color(1, 1, 1, 0.12)
	health_bar.add_theme_stylebox_override("background", background)
	column.add_child(health_bar)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.clip_text = true
	column.add_child(status_label)

func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(host): return
	var touch: Variant = host.get("mobile_controls")
	var safe: Rect2 = touch.safe_area_rect() if is_instance_valid(touch) else Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	apply_layout(safe)
	_state_clock -= delta
	if _state_clock <= 0.0:
		_state_clock = 0.15
		_update_health()

func apply_layout(safe: Rect2) -> void:
	if not enabled: return
	var map_panel: Variant = host.get("map_panel")
	var showing_map: bool = is_instance_valid(map_panel) and map_panel.visible
	if _layout_cache.is_empty() or safe != _last_safe or showing_map != _last_map:
		_layout_cache = layout_rects(safe, showing_map)
		_last_safe = safe
		_last_map = showing_map
		_menu_dirty = true
	var rects := _layout_cache
	var guidance: Variant = host.get("navigation_hud")
	var controls: Variant = host.get("mobile_controls")
	if is_instance_valid(guidance) and is_instance_valid(controls) and controls.has_method("reserved_rects"):
		var obstacles: Array[Rect2] = controls.reserved_rects()
		guidance.set_touch_layout(safe,obstacles)
		var feedback: Variant = host.get("combat_feedback")
		if is_instance_valid(feedback): feedback.set_reserved_rects(obstacles)
	for property in ["activity_panel", "survival_hud", "hint_panel", "landmark_marker", "fire_button", "mode_label"]: _hide(host.get(property))
	for property in ["campaign", "districts"]:
		var system: Variant = host.get(property)
		if is_instance_valid(system): _hide(system.get("panel"))
	var left: Variant = host.get("left_column")
	if is_instance_valid(left):
		if left.custom_minimum_size.x != rects.status.size.x: left.custom_minimum_size.x = rects.status.size.x
		_place(left, rects.status)
		if left.get_child_count() > 0 and left.get_child(0) is PanelContainer:
			var panel: PanelContainer = left.get_child(0)
			if not panel.has_meta("mobile_compact"):
				var style: StyleBox = panel.get_theme_stylebox("panel").duplicate()
				style.content_margin_left = 12
				style.content_margin_right = 12
				style.content_margin_top = 8
				style.content_margin_bottom = 8
				panel.add_theme_stylebox_override("panel", style)
				panel.set_meta("mobile_compact", true)
	for row in [["mode_label", 12], ["region_label", 18], ["info", 16]]:
		var label: Variant = host.get(row[0])
		if label is Label:
			_font_size(label, row[1])
			label.custom_minimum_size.x = 0
			label.clip_text = true
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var mini: Variant = host.get("minimap")
	if is_instance_valid(mini):
		mini.custom_minimum_size = Vector2.ZERO
		_place(mini, rects.minimap)
		mini.set("cursor_released", true)
		mini.tooltip_text = "轻触打开地图"
	if is_instance_valid(health_panel):
		_place(health_panel, rects.health)
		health_panel.visible = bool(host.get("active")) and not bool(host.get("paused"))
	var toast: Variant = host.get("toast_panel")
	var toast_text: Variant = host.get("toast_label")
	if toast_text is Label:
		toast_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		toast_text.custom_minimum_size.x = 0
		toast_text.max_lines_visible = 2
		toast_text.clip_text = true
		toast_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		toast_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		toast_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_font_size(toast_text, 16)
	if is_instance_valid(toast):
		if not toast.has_meta("mobile_compact"):
			var style: StyleBox = toast.get_theme_stylebox("panel").duplicate()
			style.content_margin_left = 12
			style.content_margin_right = 12
			style.content_margin_top = 4
			style.content_margin_bottom = 4
			toast.add_theme_stylebox_override("panel", style)
			toast.set_meta("mobile_compact", true)
		_place(toast, rects.toast)
	var speed: Variant = host.get("speed_label")
	if speed is Label:
		_font_size(speed, 17)
		speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		speed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		speed.custom_minimum_size.x = 0
		speed.max_lines_visible = 4
	var vehicle: Variant = host.get("vehicle_panel")
	if is_instance_valid(vehicle):
		# The panel may grow for a wrapped vehicle name or a third/fourth line.
		# Anchor its actual minimum height above the look hint, rather than
		# assigning a too-small size that Container clamps again every frame.
		var vehicle_rect: Rect2 = rects.vehicle
		vehicle_rect.size.y = maxf(vehicle_rect.size.y, vehicle.get_combined_minimum_size().y)
		vehicle_rect.position.y = safe.end.y - 60.0 - vehicle_rect.size.y
		_place(vehicle, vehicle_rect)
	var save_label: Variant = host.get("save_indicator")
	if is_instance_valid(save_label):
		_place(save_label, Rect2(Vector2(safe.end.x - 216, safe.position.y + 244), Vector2(200, 22)))
	var modal: Variant = host.get("modal")
	var showing_modal: bool = is_instance_valid(modal) and modal.visible
	if showing_modal and not _last_modal_visible: _menu_dirty = true
	_last_modal_visible = showing_modal
	if showing_modal:
		if _menu_dirty:
			var margins: float = modal.get_theme_stylebox("panel").get_minimum_size().x + 16.0
			_fit_menu(modal, rects.modal.size.x - margins)
			if showing_map: _fit_menu(map_panel, rects.map.size.x - 32)
			_menu_dirty = false
		_place(modal, rects.modal)
		if showing_map: _place(map_panel, rects.map)

func _update_health() -> void:
	if not is_instance_valid(health_label): return
	var survival: Variant = host.get("survival")
	var state: Dictionary = survival.hud_state() if is_instance_valid(survival) and survival.has_method("hud_state") else {}
	var player: Variant = host.get("player")
	var hp: float = float(state.get("player_health", player.get("health") if is_instance_valid(player) else 0))
	var maximum: float = maxf(1, float(state.get("max_health", 120)))
	var has_vehicle: bool = state.get("vehicle_active", false)
	var vehicle_hp: float = float(state.get("vehicle_health", 0))
	health_label.text = "生命 %d/%d" % [hp, maximum] + (" · 载具 %d%%" % vehicle_hp if has_vehicle else "")
	health_bar.max_value = 100.0 if has_vehicle else maximum
	health_bar.value = vehicle_hp if has_vehicle else hp
	status_label.text = "药包 %d · 附近奶龙 %d · 击败 %d" % [int(state.get("medkits", 0)), int(state.get("enemy_count", 0)), int(state.get("kills", 0))]
	var ratio := health_bar.value / health_bar.max_value
	health_bar.modulate = Color("ffaf91") if ratio < 0.3 else Color.WHITE

func _fit_menu(node: Node, content_width: float) -> void:
	# Watch every existing branch, including nested settings rows. This catches
	# insertion, removal and same-count replacement without polling the tree.
	if not node.child_order_changed.is_connected(_invalidate_menu_layout):
		node.child_order_changed.connect(_invalidate_menu_layout)
	if node is ScrollContainer:
		node.custom_minimum_size = Vector2.ZERO
		node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	elif node is Control:
		node.custom_minimum_size.x = minf(node.custom_minimum_size.x, content_width)
		if node is Button:
			node.custom_minimum_size.y = maxf(node.custom_minimum_size.y, 72)
			node.clip_text = true
			node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			if node.tooltip_text.is_empty(): node.tooltip_text = node.text
		elif node is LineEdit:
			node.custom_minimum_size.y = maxf(node.custom_minimum_size.y, 64)
		elif node is Slider:
			node.custom_minimum_size.y = maxf(node.custom_minimum_size.y, 48)
		elif node is Label:
			node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for child in node.get_children(): _fit_menu(child, content_width)

func _invalidate_menu_layout() -> void:
	_menu_dirty = true

func _font_size(label: Label, value: int) -> void:
	# Even an identical override emits theme_changed and invalidates shaping.
	if not label.has_theme_font_size_override("font_size") or label.get_theme_font_size("font_size") != value:
		label.add_theme_font_size_override("font_size", value)

func _place(control: Control, rect: Rect2) -> void:
	# Preserve size while removing anchors: a minimum-size reset every frame
	# would invalidate the minimap's render cache twice on each HUD update.
	if control.anchor_left != 0 or control.anchor_right != 0 or control.anchor_top != 0 or control.anchor_bottom != 0:
		control.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	if control.position != rect.position: control.position = rect.position
	# Containers may need more height for newly wrapped text. Do not repeatedly
	# ask them to shrink below their minimum while the content remains unchanged.
	var wanted := rect.size.max(control.get_combined_minimum_size())
	if control.size != wanted: control.size = wanted

func _hide(value: Variant) -> void:
	if value is CanvasItem and value.visible: value.hide()
