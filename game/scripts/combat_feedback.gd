extends Control
## Presentation only: every number comes from an enemy's settled damage signal.
## Add before the main HUD in its CanvasLayer. This Control never consumes input.
const Fonts = preload("res://scripts/ui_fonts.gd")
const MAX_BARS := 24
const MAX_NUMBERS := 48
const BAR_SIZE := Vector2(184, 54)
const MERGE_SECONDS := 0.18
const NUMBER_SECONDS := 1.15
const INK := Color("f7f4e8")
const GOLD := Color("ffdc83")
const MINT := Color("a8f1df")
const RAPID_STYLES := ["rotary", "micro", "laser", "tesla", "support"]

var host: Node
var _properties: Dictionary = {}
var _enemies: Dictionary = {}
var _numbers: Array[Dictionary] = []
var _bars: Array[Dictionary] = []
var _draw_numbers: Array[Dictionary] = []
var _reserved: Array[Rect2] = []
var _extra_reserved: Array[Rect2] = []
var _locked_override: WeakRef
var _clock := 0.0
var _scan_left := 0.0
var _serial := 0
var _damage_events := 0
var _actual_damage := 0.0
var _reward_events := 0
var _built := false
var _panel: StyleBoxFlat
var _locked_panel: StyleBoxFlat


func setup(game: Node) -> void:
	host = game
	_properties.clear()
	if is_instance_valid(host):
		for property: Dictionary in host.get_property_list(): _properties[str(property.name)] = true
	_build()
	visible = not _blocked()


func _ready() -> void:
	_build()


func _build() -> void:
	if _built: return
	_built = true
	name = "CombatFeedback"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Fonts.make_theme(14)
	_panel = StyleBoxFlat.new()
	_panel.bg_color = Color(0.025, 0.07, 0.085, 0.91)
	_panel.set_corner_radius_all(5)
	_panel.set_border_width_all(1)
	_panel.border_color = Color(0.75, 0.82, 0.78, 0.38)
	_locked_panel = _panel.duplicate()
	_locked_panel.border_color = MINT


func _host_value(key: String, fallback: Variant = null) -> Variant:
	return host.get(key) if is_instance_valid(host) and _properties.has(key) else fallback


func _blocked() -> bool:
	if not is_instance_valid(host): return true
	if not bool(_host_value("active", true)) or bool(_host_value("paused", false)) or bool(_host_value("quitting", false)): return true
	if is_inside_tree() and get_tree().paused: return true
	for key: String in ["modal", "map_panel"]:
		var panel: Variant = _host_value(key)
		if is_instance_valid(panel) and panel is CanvasItem and panel.visible: return true
	var director: Variant = _host_value("survival")
	if is_instance_valid(director) and not bool(director.get("enabled")): return true
	return false


func register_enemy(enemy: Node3D) -> void:
	if not is_instance_valid(enemy) or not enemy.has_signal("damaged") or not enemy.has_signal("defeated"): return
	var id := enemy.get_instance_id()
	if _enemies.has(id): return
	var maximum := maxf(1.0, float(enemy.get("max_health")))
	var hp := clampf(float(enemy.get("health")), 0.0, maximum)
	var spec: Dictionary = enemy.get("spec")
	_enemies[id] = {"ref": weakref(enemy), "health": hp, "maximum": maximum, "trail": hp,
		"label": "Lv.%d %s" % [int(enemy.get("level")), str(spec.get("label", "奶龙"))],
		"hurt_until": 0.0, "dead_until": 0.0, "rewarded": false, "clear": false,
		"anchor": _anchor(enemy), "body": _body_point(enemy), "distance": 0.0}
	enemy.connect("damaged", _on_damaged)
	enemy.connect("defeated", _on_defeated)
	if enemy.has_method("set_feedback_managed"): enemy.call("set_feedback_managed", true)
	_scan_left = 0.0


func unregister_enemy(enemy: Node3D) -> void:
	if not is_instance_valid(enemy): return
	if enemy.is_connected("damaged", _on_damaged): enemy.disconnect("damaged", _on_damaged)
	if enemy.is_connected("defeated", _on_defeated): enemy.disconnect("defeated", _on_defeated)
	if enemy.has_method("set_feedback_managed"): enemy.call("set_feedback_managed", false)
	_enemies.erase(enemy.get_instance_id())


func clear() -> void:
	for record: Dictionary in _enemies.values():
		var enemy: Node3D = record.ref.get_ref()
		if is_instance_valid(enemy): unregister_enemy(enemy)
	_enemies.clear()
	_numbers.clear()
	_bars.clear()
	_draw_numbers.clear()
	_locked_override = null
	_clock = 0.0
	_damage_events = 0
	_actual_damage = 0.0
	_reward_events = 0
	_scan_left = 0.0
	queue_redraw()


func reset() -> void:
	clear()


func _exit_tree() -> void:
	clear()


func set_locked_target(enemy: Node3D) -> void:
	_locked_override = weakref(enemy) if is_instance_valid(enemy) else null


func set_reserved_rects(rects: Array) -> void:
	# Optional extra occlusion for custom HUDs; production HUD bounds are automatic.
	_extra_reserved.clear()
	for rect: Variant in rects:
		if rect is Rect2: _extra_reserved.append(rect)


func _anchor(enemy: Node3D) -> Vector3:
	# Match the transform the renderer uses between fixed physics ticks.
	return enemy.get_global_transform_interpolated().origin + Vector3.UP * float(enemy.get_meta("enemy_feedback_height", 3.24))


func _body_point(enemy: Node3D) -> Vector3:
	return enemy.get_global_transform_interpolated().origin + Vector3.UP * 1.7 * float(enemy.get_meta("enemy_body_scale", 1.0))


static func format_amount(amount: float) -> String:
	if not is_finite(amount): return "0"
	if amount > 0.0 and amount < 0.05: return "<0.1"
	return str(roundi(amount)) if absf(amount - roundf(amount)) < 0.001 else "%.1f" % amount


func _on_damaged(enemy: Node3D, actual: float, hit_position: Vector3, remaining: float) -> void:
	if not is_instance_valid(enemy) or not is_finite(actual) or actual <= 0.0 or not is_finite(remaining): return
	var id := enemy.get_instance_id()
	if not _enemies.has(id): return
	var record: Dictionary = _enemies[id]
	record.health = clampf(remaining, 0.0, float(record.maximum))
	record.hurt_until = _clock + 2.0
	record.anchor = _anchor(enemy)
	record.body = _body_point(enemy)
	if remaining <= 0.0: record.dead_until = _clock + 0.5
	_damage_events += 1
	_actual_damage += actual
	var style := str(enemy.get_meta("damage_style", "default"))
	# Blast callbacks carry the shared explosion centre, not each victim's body.
	# Keep every HP number attached to its actual victim. A precise bullet hit
	# may be used only when it is close to that victim's physical silhouette.
	var point := _body_point(enemy)
	var body_radius := 2.0 * float(enemy.get_meta("enemy_body_scale", 1.0))
	if style not in ["cannon", "splash", "micro"] and hit_position.is_finite() and not hit_position.is_zero_approx() and hit_position.distance_to(point) <= body_radius:
		point = hit_position
	# Short bursts sum unrounded actual HP loss. Shells never merge into gunfire.
	if style in RAPID_STYLES:
		for i: int in range(_numbers.size() - 1, -1, -1):
			var number: Dictionary = _numbers[i]
			if number.id == id and number.style == style and number.kind == "damage" and _clock - float(number.started) <= MERGE_SECONDS:
				number.amount += actual
				number.hits += 1
				number.text = "−" + format_amount(float(number.amount))
				number.until = _clock + NUMBER_SECONDS
				number.point = point
				return
	_append_number(id, point, actual, "−" + format_amount(actual), style, "damage")


func _on_defeated(enemy: Node3D, reward: int) -> void:
	if not is_instance_valid(enemy) or not _enemies.has(enemy.get_instance_id()): return
	var record: Dictionary = _enemies[enemy.get_instance_id()]
	if bool(record.rewarded): return
	record.rewarded = true
	_reward_events += 1
	_append_number(enemy.get_instance_id(), record.anchor, 0.0, "击败  +%d 金币" % maxi(0, reward), "reward", "reward")


func _append_number(id: int, point: Vector3, amount: float, text_value: String, style: String, kind: String) -> void:
	if _numbers.size() >= MAX_NUMBERS:
		# Evict the oldest ordinary hit before a still-visible shell or reward.
		var remove := 0
		for i: int in _numbers.size():
			if _numbers[i].style in RAPID_STYLES or _numbers[i].style == "default": remove = i; break
		_numbers.remove_at(remove)
	_serial += 1
	_numbers.append({"id": id, "serial": _serial, "point": point, "amount": amount, "text": text_value,
		"style": style, "kind": kind, "hits": 1, "started": _clock, "until": _clock + (1.5 if kind == "reward" else NUMBER_SECONDS)})


func _locked_ids() -> Dictionary:
	var result := {}
	var override: Node3D = _locked_override.get_ref() if _locked_override is WeakRef else null
	if is_instance_valid(override): result[override.get_instance_id()] = true
	var weapons: Variant = _host_value("weapons")
	if is_instance_valid(weapons) and weapons.has_method("auto_status"):
		var status: Dictionary = weapons.call("auto_status")
		if bool(status.get("locked", false)): result[int(status.get("target_id", 0))] = true
		var modules: Dictionary = status.get("modules", {})
		for id: Variant in Dictionary(modules.get("locks", {})).values(): result[int(id)] = true
	return result


func _camera() -> Camera3D:
	var result: Variant = _host_value("camera")
	return result if is_instance_valid(result) and result is Camera3D else null


func _line_clear(camera: Camera3D, point: Vector3) -> bool:
	if not camera.is_inside_tree() or camera.get_world_3d() == null: return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1 | 4)
	var excluded: Array[RID] = []
	for key: String in ["player", "current_vehicle"]:
		var value: Variant = _host_value(key)
		if is_instance_valid(value) and value is CollisionObject3D: excluded.append(value.get_rid())
	query.exclude = excluded
	return camera.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _collect_reserved() -> void:
	_reserved = _extra_reserved.duplicate()
	var hud: Variant = _host_value("hud")
	if not is_instance_valid(hud): return
	for child: Node in hud.get_children():
		if not child is Control or not child.is_visible_in_tree(): continue
		if child is Label and child.text.is_empty(): continue
		if child.name == "SurvivalHUD":
			var card: Rect2 = child.get("_card_rect")
			_reserved.append(Rect2(child.global_position + card.position - global_position, card.size).grow(8))
			continue
		var rect: Rect2 = child.get_global_rect()
		if rect.size.x >= size.x * 0.9 and rect.size.y >= size.y * 0.8: continue
		if rect.size.x <= 0.0 or rect.size.y <= 0.0: continue
		_reserved.append(Rect2(rect.position - global_position, rect.size).grow(8))
	# The navigation compass is custom-drawn inside a full-viewport Control.
	var width := minf(460.0, size.x * 0.33)
	_reserved.append(Rect2(Vector2(size.x * 0.52 - width * 0.5, 15), Vector2(width, 83)))


func _scan_visibility(camera: Camera3D) -> void:
	for id: Variant in _enemies.keys():
		var record: Dictionary = _enemies[id]
		var enemy: Node3D = record.ref.get_ref()
		if is_instance_valid(enemy):
			record.anchor = _anchor(enemy)
			record.body = _body_point(enemy)
		elif _clock > float(record.dead_until) and _clock > float(record.hurt_until):
			_enemies.erase(id)
			continue
		record.distance = camera.global_position.distance_to(record.body)
		record.clear = float(record.distance) <= 300.0 and not camera.is_position_behind(record.body) and _line_clear(camera, record.body)


func _follow_rendered_positions(camera: Camera3D) -> void:
	# Position updates are per rendered frame, independent from the bounded
	# 0.12-second physics ray budget. Fast pursuers must not have 8-Hz labels.
	for record: Dictionary in _enemies.values():
		var enemy: Node3D = record.ref.get_ref()
		if not is_instance_valid(enemy) or not enemy.is_inside_tree(): continue
		record.anchor = _anchor(enemy)
		record.body = _body_point(enemy)
		record.distance = camera.global_position.distance_to(record.body)


func _fits(rect: Rect2, occupied: Array[Rect2]) -> bool:
	if not Rect2(Vector2(12, 12), size - Vector2(24, 24)).encloses(rect): return false
	for other: Rect2 in _reserved:
		if rect.intersects(other): return false
	for other: Rect2 in occupied:
		if rect.grow(4).intersects(other): return false
	return true


func _place(anchor: Vector2, dimensions: Vector2, occupied: Array[Rect2], is_number := false) -> Rect2:
	# A bounded fan stays close to the actual enemy; hide overflow instead of
	# stacking labels over the HUD or moving them to unrelated screen edges.
	var gaps: Array[Vector2] = [Vector2.ZERO, Vector2(0, -62), Vector2(-196, -12), Vector2(196, -12), Vector2(-100, -76), Vector2(100, -76)]
	if is_number:
		var side := BAR_SIZE.x * 0.5 + dimensions.x * 0.5 + 14.0
		gaps = [Vector2(side, -4), Vector2(-side, -4), Vector2(0, 30), Vector2(0, -68), Vector2(side, -68), Vector2(-side, -68), Vector2(0, 62)]
	for offset: Vector2 in gaps:
		var rect := Rect2(anchor - Vector2(dimensions.x * 0.5, dimensions.y + 12) + offset, dimensions)
		if _fits(rect, occupied): return rect
	return Rect2()


func _update_layout(camera: Camera3D) -> void:
	_bars.clear()
	_draw_numbers.clear()
	var locks := _locked_ids()
	var candidates: Array[Dictionary] = []
	for id: Variant in _enemies:
		var record: Dictionary = _enemies[id]
		var locked := locks.has(id)
		var hurt := _clock < float(record.hurt_until)
		if not bool(record.clear) or camera.is_position_behind(record.anchor): continue
		if float(record.health) <= 0.0 and _clock >= float(record.dead_until): continue
		if float(record.distance) > (300.0 if locked or hurt else 95.0): continue
		var anchor := camera.unproject_position(record.anchor) - global_position
		if not Rect2(Vector2.ZERO, size).has_point(anchor): continue
		candidates.append({"id": id, "record": record, "anchor": anchor, "locked": locked,
			"priority": (10000.0 if locked else 0.0) + (2000.0 if hurt else 0.0) - float(record.distance)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.priority > b.priority if not is_equal_approx(a.priority, b.priority) else a.id < b.id)
	var occupied: Array[Rect2] = []
	for candidate: Dictionary in candidates:
		if _bars.size() >= MAX_BARS: break
		var rect := _place(candidate.anchor, BAR_SIZE, occupied)
		if not rect.has_area(): continue
		candidate.rect = rect
		_bars.append(candidate)
		occupied.append(rect)
	# Newest shell hits and real rewards remain readable when a burst is dense.
	var ordered: Array[Dictionary] = _numbers.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority := 2 if a.style in ["cannon", "splash", "reward"] else 1
		var b_priority := 2 if b.style in ["cannon", "splash", "reward"] else 1
		return a_priority > b_priority if a_priority != b_priority else a.serial > b.serial)
	for number: Dictionary in ordered:
		if not _enemies.has(number.id): continue
		var record: Dictionary = _enemies[number.id]
		if not bool(record.clear) or camera.is_position_behind(number.point): continue
		var anchor := camera.unproject_position(number.point) - global_position
		if not Rect2(Vector2.ZERO, size).has_point(anchor): continue
		anchor.y -= minf(35.0, (_clock - float(number.started)) * 30.0)
		var font_size := _number_size(str(number.style))
		var dimensions := Fonts.regular().get_string_size(number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) + Vector2(16, 10)
		var rect := _place(anchor, dimensions, occupied, true)
		if not rect.has_area(): continue
		var view: Dictionary = number.duplicate()
		view.rect = rect
		view.font_size = font_size
		_draw_numbers.append(view)
		occupied.append(rect)


func _process(delta: float) -> void:
	visible = not _blocked()
	if not visible: return
	var camera := _camera()
	if camera == null: _bars.clear(); _draw_numbers.clear(); queue_redraw(); return
	var dt := clampf(delta, 0.0, 0.25)
	_clock += dt
	for i: int in range(_numbers.size() - 1, -1, -1):
		if _clock >= float(_numbers[i].until): _numbers.remove_at(i)
	for record: Dictionary in _enemies.values():
		if _clock >= float(record.hurt_until) - 1.6:
			record.trail = move_toward(float(record.trail), float(record.health), float(record.maximum) * dt * 1.8)
	_follow_rendered_positions(camera)
	_scan_left -= dt
	if _scan_left <= 0.0: _scan_visibility(camera); _scan_left = 0.12
	_collect_reserved()
	_update_layout(camera)
	queue_redraw()


static func _number_size(style: String) -> int:
	return 31 if style in ["cannon", "splash"] else (17 if style == "reward" else 23)


func _text(at: Vector2, value: String, color: Color, font_size: int) -> void:
	draw_string_outline(Fonts.regular(), at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.015, 0.03, 0.04, color.a))
	draw_string(Fonts.regular(), at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	if not _built: return
	for candidate: Dictionary in _bars:
		var rect: Rect2 = candidate.rect
		var record: Dictionary = candidate.record
		var tint := MINT if candidate.locked else INK
		draw_line(candidate.anchor, Vector2(clampf(candidate.anchor.x, rect.position.x + 6, rect.end.x - 6), rect.end.y), Color(tint, 0.5), 1.0, true)
		draw_style_box(_locked_panel if candidate.locked else _panel, rect)
		var title: String = record.label
		var title_size := 14
		while Fonts.regular().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > rect.size.x - 18 and title.length() > 4: title = title.left(title.length() - 2) + "…"
		_text(rect.position + Vector2(9, 18), title, tint, title_size)
		var track := Rect2(rect.position + Vector2(9, 25), Vector2(rect.size.x - 18, 8))
		draw_rect(track, Color("3e2027"))
		draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(float(record.trail) / float(record.maximum), 0, 1), track.size.y)), GOLD)
		var hp_color := Color("e25c65") if float(record.health) / float(record.maximum) > 0.25 else Color("ff8990")
		draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(float(record.health) / float(record.maximum), 0, 1), track.size.y)), hp_color)
		var value := "%s / %s" % [format_amount(float(record.health)), format_amount(float(record.maximum))]
		_text(rect.position + Vector2(9, 47), value, INK, 14)
		if candidate.locked: _text(rect.position + Vector2(132, 47), "锁定", MINT, 12)
	for number: Dictionary in _draw_numbers:
		var color := GOLD if number.style in ["cannon", "splash", "reward"] else (MINT if number.style in RAPID_STYLES else INK)
		color.a = clampf((float(number.until) - _clock) / 0.3, 0.0, 1.0)
		var rect: Rect2 = number.rect
		_text(rect.position + Vector2(8, rect.size.y - 8), number.text, color, int(number.font_size))


func snapshot() -> Dictionary:
	var bars: Array[Dictionary] = []
	for candidate: Dictionary in _bars:
		var record: Dictionary = candidate.record
		bars.append({"id": candidate.id, "label": record.label, "health": record.health, "maximum": record.maximum,
			"trail": record.trail, "locked": candidate.locked, "rect": _rect_values(candidate.rect)})
	var floating: Array[Dictionary] = []
	for number: Dictionary in _numbers:
		floating.append({"id": number.id, "amount": number.amount, "text": number.text, "style": number.style, "kind": number.kind, "hits": number.hits})
	return {"visible": visible, "registered": _enemies.size(), "bar_capacity": MAX_BARS, "number_capacity": MAX_NUMBERS,
		"bars": bars, "floating": floating, "visible_numbers": _draw_numbers.size(), "damage_events": _damage_events,
		"actual_damage": _actual_damage, "reward_events": _reward_events, "clock": _clock}


func _rect_values(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
