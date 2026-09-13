extends Control
## Combat information only. The host owns input, health, economy and transactions.
signal service_requested()
signal heal_requested()

const Fonts = preload("res://scripts/ui_fonts.gd")
const CARD_SIZE := Vector2(300, 260)
const INK := Color("eef1e4")
const MUTED := Color("a9c0bc")
const MINT := Color("96ddc7")
const AMBER := Color("f3cb80")
const DANGER := Color("f2a195")
const HIT_SECONDS := 0.7

var host: Node
var _host_properties: Dictionary = {}
var _state: Dictionary = {}
var _card: StyleBoxFlat
var _pill: StyleBoxFlat
var _card_rect := Rect2(Vector2(28, 292), CARD_SIZE)
var _heal_button: Button
var _service_button: Button
var _built := false
var _last_health := 120.0
var _last_hurt := 0.0
var _last_aim_hit := false
var _health_visual := 1.0
var _damage_time := 0.0
var _low_entry_time := 0.0
var _hit_time := 0.0
var _hurt_label := ""


func setup(owner_host: Node) -> void:
	host = owner_host
	_host_properties.clear()
	if is_instance_valid(host):
		for property: Dictionary in host.get_property_list():
			_host_properties[str(property.name)] = true
	_build()
	_sync_visibility()


func _ready() -> void:
	_build()
	_sync_visibility()


func _build() -> void:
	if _built: return
	_built = true
	name = "SurvivalHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Fonts.make_theme(14)
	_card = _style(Color(0.025, 0.085, 0.11, 0.94), 10)
	_card.border_color = Color(0.39, 0.64, 0.61, 0.42)
	_card.set_border_width_all(1)
	_pill = _style(Color(0.09, 0.20, 0.22, 1.0), 5)
	_heal_button = _button("HealButton", "H  治疗", "按 H 治疗；按住 Option / Alt 可用鼠标点击")
	_service_button = _button("ServiceButton", "B  维修 / 升级", "按 B 查看维修、升级与补给；交易需满足安全条件")
	_heal_button.pressed.connect(_request_heal)
	_service_button.pressed.connect(_request_service)
	resized.connect(_layout)
	_layout()


func _style(color: Color, radius: int) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	return result


func _button(button_name: String, value: String, tip: String) -> Button:
	var result := Button.new()
	result.name = button_name
	result.text = value
	result.tooltip_text = tip
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_size_override("font_size", 13)
	result.add_theme_color_override("font_color", INK)
	result.add_theme_color_override("font_disabled_color", Color("718b87"))
	var normal := _style(Color("1a3e43"), 5)
	var hover := _style(Color("28545b"), 5)
	var pressed := _style(Color("326760"), 5)
	var disabled := _style(Color("142c32"), 5)
	for entry: Array in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled]]:
		result.add_theme_stylebox_override(entry[0], entry[1])
	add_child(result)
	return result


func _layout() -> void:
	if not _built: return
	# At 720p this ends at y=552, before the existing lower-left guidance.
	# Do not occupy the compass, right map, speedometer or lower driving strip.
	var top := minf(292.0, maxf(180.0, size.y - 428.0))
	_card_rect = Rect2(Vector2(28, top), CARD_SIZE)
	_heal_button.position = _card_rect.position + Vector2(16, 218)
	_heal_button.size = Vector2(128, 30)
	_service_button.position = _card_rect.position + Vector2(152, 218)
	_service_button.size = Vector2(132, 30)
	queue_redraw()


func _number(value: Variant, fallback: float = 0.0) -> float:
	if typeof(value) not in [TYPE_FLOAT, TYPE_INT]: return fallback
	var result := float(value)
	return result if is_finite(result) else fallback


func update_state(data: Dictionary) -> void:
	_build()
	var maximum := maxf(1.0, _number(data.get("max_health", 120), 120))
	var health := clampf(_number(data.get("player_health", maximum), maximum), 0, maximum)
	var amount := maxf(0.0, _number(data.get("hurt_amount", 0)))
	var was_active: bool = bool(_state.get("active", false))
	var now_active: bool = bool(data.get("active", false))
	var first_state := _state.is_empty() or (now_active and not was_active)
	# A value held across frames is not a stream of new hits. The real health
	# decrease also catches consecutive attacks with an identical damage value.
	if not first_state and (health < _last_health - 0.001 or amount > _last_hurt + 0.001):
		_damage_time = HIT_SECONDS
		_hurt_label = str(data.get("hurt_direction_label", "")).strip_edges()
	if first_state:
		_health_visual = health / maximum
		_damage_time = 0.0
		_low_entry_time = 0.0
		_hit_time = 0.0
	elif health / maximum <= 0.25 and _last_health / maximum > 0.25:
		_low_entry_time = 0.65
	if bool(data.get("aim_hit", false)) and not _last_aim_hit and not first_state:
		_hit_time = 0.3
	_last_aim_hit = bool(data.get("aim_hit", false))
	_last_health = health
	_last_hurt = amount
	_state = data.duplicate()
	_state["player_health"] = health
	_state["max_health"] = maximum
	_state["vehicle_health"] = clampf(_number(data.get("vehicle_health", 100), 100), 0, 100)
	_state["enemy_count"] = maxi(0, int(_number(data.get("enemy_count", 0))))
	_state["kills"] = maxi(0, int(_number(data.get("kills", 0))))
	_state["medkits"] = maxi(0, int(_number(data.get("medkits", 0))))
	_state["heal_cooldown"] = maxf(0, _number(data.get("heal_cooldown", 0)))
	_state["threat"] = clampf(_number(data.get("threat", 0)), 0, 1)
	_refresh_buttons()
	_sync_visibility()
	queue_redraw()


func _blocked() -> bool:
	if is_instance_valid(host):
		if _host_properties.has("paused") and bool(host.get("paused")): return true
		if _host_properties.has("active") and not bool(host.get("active")): return true
		for key: String in ["modal", "map_panel"]:
			if not _host_properties.has(key): continue
			var panel: Variant = host.get(key)
			if is_instance_valid(panel) and panel is CanvasItem and panel.visible: return true
	return is_inside_tree() and get_tree().paused


func _can_heal() -> bool:
	return int(_state.get("medkits", 0)) > 0 and float(_state.get("heal_cooldown", 0)) <= 0 and float(_state.get("player_health", 120)) > 0 and float(_state.get("player_health", 120)) < float(_state.get("max_health", 120))


func _refresh_buttons() -> void:
	if not _built: return
	var cooldown: float = float(_state.get("heal_cooldown", 0))
	_heal_button.text = "H  治疗 %.1f s" % cooldown if cooldown > 0 else "H  治疗 ×%d" % int(_state.get("medkits", 0))
	_heal_button.disabled = not _can_heal()
	_service_button.disabled = false


func _sync_visibility() -> void:
	var allowed: bool = bool(_state.get("active", false)) and not _blocked()
	visible = allowed
	if not _built: return
	# HUD buttons must not intercept aim clicks while the pointer is captured.
	var pointer_free := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	for button: Button in [_heal_button, _service_button]:
		button.mouse_filter = Control.MOUSE_FILTER_STOP if allowed and pointer_free else Control.MOUSE_FILTER_IGNORE
	if not allowed:
		_heal_button.disabled = true
		_service_button.disabled = true
	else:
		_refresh_buttons()


func _request_heal() -> void:
	if visible and not _blocked() and _can_heal(): heal_requested.emit()


func _request_service() -> void:
	if visible and not _blocked(): service_requested.emit()


func _process(delta: float) -> void:
	_sync_visibility()
	if not visible: return
	var target: float = float(_state.get("player_health", 120)) / float(_state.get("max_health", 120))
	var changing: bool = _damage_time > 0 or _low_entry_time > 0 or _hit_time > 0 or not is_equal_approx(_health_visual, target)
	_damage_time = maxf(0, _damage_time - delta)
	_low_entry_time = maxf(0, _low_entry_time - delta)
	_hit_time = maxf(0, _hit_time - delta)
	_health_visual = move_toward(_health_visual, target, delta * 2.5)
	if changing: queue_redraw()


func _text(at: Vector2, value: String, font_size: int = 14, color: Color = INK, width: float = 268) -> void:
	var face: Font = get_theme_default_font()
	var fitted := value.replace("\n", " ")
	if face.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		while not fitted.is_empty() and face.get_string_size(fitted + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			fitted = fitted.left(fitted.length() - 1)
		fitted += "…"
	draw_string(face, _card_rect.position + at, fitted, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)


func _bar(at: Vector2, width: float, height: float, amount: float, color: Color) -> void:
	var bounds := Rect2(_card_rect.position + at, Vector2(width, height))
	draw_rect(bounds, Color("213e42"))
	if amount > 0: draw_rect(Rect2(bounds.position, Vector2(width * clampf(amount, 0, 1), height)), color)
	for part in range(1, 4):
		var x := bounds.position.x + width * part / 4.0
		draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), Color(0.035, 0.10, 0.12, 0.75), 2)


func _draw() -> void:
	if not _built or _state.is_empty(): return
	var ratio: float = float(_state.player_health) / float(_state.max_health)
	var low: bool = ratio <= 0.25
	var pulse: float = maxf(_damage_time / HIT_SECONDS, _low_entry_time / 0.65)
	_card.border_color = Color(DANGER, 0.7) if low else Color(0.39, 0.64, 0.61, 0.42)
	_card.bg_color = Color(0.025, 0.085, 0.11, 0.94).lerp(Color(0.31, 0.10, 0.11, 0.94), pulse * 0.5)
	draw_style_box(_card, _card_rect)
	_text(Vector2(16, 28), "奶龙生存", 17, MINT, 124)
	var threat: float = float(_state.get("threat", 0))
	var phase: String = str(_state.get("phase", "巡游"))
	draw_style_box(_pill, Rect2(_card_rect.position + Vector2(171, 13), Vector2(113, 24)))
	_text(Vector2(180, 30), phase, 12, AMBER if threat >= 0.5 else MUTED, 94)
	var threat_text := "夜间威胁增强" if "夜" in phase else ("周边威胁较高 · 保持距离" if threat >= 0.5 else "保持移动，清理附近奶龙")
	_text(Vector2(16, 52), threat_text, 12, AMBER if threat >= 0.5 else MUTED)
	_text(Vector2(16, 78), "生命危急" if low else "生命", 14, DANGER if low else INK, 120)
	_text(Vector2(187, 78), "%d / %d" % [int(_state.player_health), int(_state.max_health)], 16, DANGER if low else INK, 97)
	_bar(Vector2(16, 89), 268, 10, _health_visual, DANGER if low else MINT)
	var vehicle_name: String = str(_state.get("vehicle_name", ""))
	if not vehicle_name.is_empty():
		_text(Vector2(16, 123), vehicle_name, 13, MUTED, 185)
		_text(Vector2(210, 123), "%d%%" % int(_state.vehicle_health), 14, INK, 74)
		_bar(Vector2(16, 133), 268, 5, float(_state.vehicle_health) / 100.0, Color("80bed1"))
	else:
		_text(Vector2(16, 123), "步行中 · Tab 新增载具", 13, MUTED)
		_bar(Vector2(16, 133), 268, 5, 0, MUTED)
	draw_line(_card_rect.position + Vector2(16, 150), _card_rect.position + Vector2(284, 150), Color("2b4649"), 1)
	_text(Vector2(16, 177), "%d" % int(_state.enemy_count), 23, INK, 65)
	_text(Vector2(68, 176), "附近奶龙", 12, MUTED, 91)
	_text(Vector2(184, 176), "已清理 %d" % int(_state.kills), 13, MINT, 100)
	var objective: String = str(_state.get("objective", "探索悉尼，清理奶龙"))
	var objective_color := MUTED
	if _damage_time > 0:
		objective = "受到攻击" + (" · " + _hurt_label if not _hurt_label.is_empty() else "")
		objective_color = DANGER
	elif low:
		objective = "H 治疗，先拉开距离" if _can_heal() else "先拉开距离，再寻找补给"
		objective_color = DANGER
	elif _hit_time > 0:
		objective = "命中 · 继续清理"
		objective_color = MINT
	elif not str(_state.get("reward_text", "")).is_empty():
		objective = str(_state.reward_text)
		objective_color = AMBER
	_text(Vector2(16, 201), objective, 12, objective_color)
