extends Node
## Guided first chapter that strings the sandbox's existing systems into a goal
## path, plus account achievements. Checks poll production state (vehicles,
## jobs, experiences, photos, survival kills), so no system needs special hooks.

const Achievements = preload("res://scripts/achievements.gd")
const Bridge = preload("res://scripts/bridge_landmark.gd")
const GameSettings = preload("res://scripts/game_settings.gd")
const CHAPTER_ID := "harbour_first_day"
const CHAPTER_TITLE := "港城第一天"
const CHAPTER_REWARD := 20000
const GROUND := ["car", "motorcycle", "hoverboard", "tank"]
const AIR_OR_SEA := ["helicopter", "airliner", "fighter", "glider", "paraglider", "speedboat", "yacht"]
const STEPS := [
	{"id": "ride", "title": "坐进一辆载具", "detail": "走到家门口的车旁按 {interact} 上车，或按 {vehicles} 免费新增一辆。", "kind": "vehicle", "reward": 2000, "achievement": "first_ride"},
	{"id": "quay", "title": "开到环形码头", "detail": "跟随黄色标记开往 Circular Quay，渡轮码头就在海边。", "kind": "reach", "target": "quay", "radius": 90.0, "reward": 3000, "achievement": "quay_arrival"},
	{"id": "opera_photo", "title": "给歌剧院拍张照", "detail": "到歌剧院附近，按 {photo} 拍照；也可以在暂停菜单里拍。", "kind": "photo", "target": "opera", "radius": 320.0, "reward": 3000, "achievement": "opera_photo"},
	{"id": "job", "title": "完成一份工作", "detail": "按 {jobs} 打开工作与活动，接一份工作并完成它。", "kind": "job", "reward": 4000, "achievement": "first_job"},
	{"id": "bridge", "title": "驾车驶过海港大桥", "detail": "开地面载具经过海港大桥，到达北岸桥头。", "kind": "reach", "target": "bridge_north", "radius": 80.0, "vehicles": GROUND, "reward": 4000, "achievement": "bridge_cross"},
	{"id": "manly", "title": "前往曼利", "detail": "乘直升机、飞机或快艇沿海港往东北，抵达曼利码头。", "kind": "reach", "target": "manly_wharf", "radius": 320.0, "vehicles": AIR_OR_SEA, "reward": 5000, "achievement": "manly_trip"},
	{"id": "taste", "title": "品尝城市美食", "detail": "按 {experiences} 打开城市体验，选一个项目，前往后完成体验。", "kind": "experience", "reward": 3000, "achievement": "taste_city"},
	{"id": "nailong", "title": "击败 5 只奶龙", "detail": "奶龙危机中按 {fire} 反击；自由观光世界可在暂停菜单开启奶龙危机。", "kind": "kills", "amount": 5, "reward": 5000},
]
const PAD_LABELS := {"interact": "B", "vehicles": "Y", "photo": "暂停菜单 → 拍照", "jobs": "十字键 ←", "experiences": "Back", "fire": "RT"}
const TOUR := {"opera": ["opera"], "bridge": ["bridge_mid"], "sydney_tower": ["sydney_tower"], "qvb": ["qvb", "qvb_public"], "icc": ["icc_convention", "icc_exhibition"], "manly": ["manly_wharf", "manly_beach"]}

var game: Node
var step := 0
var completed: Array = []
## Steps already paid for; restarting the chapter never pays the same step twice.
var rewarded: Array = []
var hidden := false
var finished := false
var baseline := {}
var photos := 0
var last_photo_position := Vector3(INF, INF, INF)
var visited := {}
var _clock := 0.0
var panel: PanelContainer
var _header: Label
var _title: Label
var _detail: Label
var _distance: Label


func setup(host: Node) -> void:
	game = host
	name = "Campaign"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Achievements.persist = not bool(game.qa_running)
	_build_panel()


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "ObjectivePanel"
	var style: StyleBoxFlat = game.panel_style(Color(0.035, 0.1, 0.09, 0.84), 10)
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.border_color = Color("c9a94f")
	style.border_width_left = 3
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	_header = game.label("", 13, Color("e3c46e"))
	_title = game.label("", 17, Color("f4f1df"))
	_detail = game.label("", 13, Color("c7d2c8"))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size.x = 321
	_distance = game.label("", 13, Color("9fd6c6"))
	for child: Label in [_header, _title, _detail, _distance]: box.add_child(child)
	game.left_column.add_child(panel)
	game.left_column.move_child(panel, 1)
	panel.visible = false


func start_new() -> void:
	rewarded = []
	visited = {}
	hidden = false
	photos = 0
	last_photo_position = Vector3(INF, INF, INF)
	_reset_steps()


func _reset_steps() -> void:
	step = 0
	completed = []
	finished = false
	_begin_step(false)


func get_state() -> Dictionary:
	return {"chapter": CHAPTER_ID, "step": step, "completed": completed.duplicate(), "rewarded": rewarded.duplicate(), "hidden": hidden, "finished": finished, "baseline": baseline.duplicate(), "photos": photos, "visited": visited.keys()}


func _step_ids(value: Variant) -> Array:
	var ids := []
	if value is Array:
		for id: Variant in value:
			if STEPS.any(func(row: Dictionary): return row.id == str(id)) and not ids.has(str(id)): ids.append(str(id))
	return ids


func apply_state(data: Dictionary) -> void:
	if data.is_empty() or str(data.get("chapter", "")) != CHAPTER_ID:
		start_new()
		return
	step = clampi(int(data.get("step", 0)) if typeof(data.get("step")) in [TYPE_INT, TYPE_FLOAT] else 0, 0, STEPS.size())
	completed = _step_ids(data.get("completed", []))
	rewarded = _step_ids(data.get("rewarded", completed))
	if data.get("rewarded") is Array and "chapter" in data.rewarded: rewarded.append("chapter")
	hidden = bool(data.get("hidden", false))
	finished = bool(data.get("finished", false)) or step >= STEPS.size()
	photos = maxi(0, int(data.get("photos", 0))) if typeof(data.get("photos")) in [TYPE_INT, TYPE_FLOAT] else 0
	visited = {}
	var places: Variant = data.get("visited", [])
	if places is Array:
		for key: Variant in places: if TOUR.has(str(key)): visited[str(key)] = true
	_capture_baseline()
	var saved_baseline: Variant = data.get("baseline", {})
	if saved_baseline is Dictionary:
		for key: String in baseline:
			if typeof(saved_baseline.get(key)) in [TYPE_INT, TYPE_FLOAT]: baseline[key] = mini(int(saved_baseline[key]), int(baseline[key]))


func current() -> Dictionary:
	return STEPS[step] if step < STEPS.size() else {}


func target_position(key: String) -> Vector3:
	if key == "bridge_north": return Bridge.NORTH_ENTRY
	if key == "bridge_mid": return Bridge.pos(251.5)
	var anchors: Dictionary = game.world.anchors
	if anchors.has(key) and anchors[key] is Vector3: return anchors[key]
	return Vector3(INF, INF, INF)


func _totals() -> Dictionary:
	var jobs := 0
	for id: Variant in game.life.completed_jobs: jobs += int(game.life.completed_jobs[id])
	var tastes := 0
	for id: Variant in game.life.experience_visits: tastes += int(game.life.experience_visits[id])
	return {"jobs": jobs, "experiences": tastes, "kills": int(game.survival.kills) if is_instance_valid(game.survival) else 0, "photos": photos}


func _capture_baseline() -> void:
	baseline = _totals()


func _begin_step(announce: bool) -> void:
	_capture_baseline()
	if step >= STEPS.size():
		finished = true
		return
	_point_navigation(announce)


func _point_navigation(announce: bool) -> void:
	var row := current()
	var position := target_position(str(row.target)) if row.has("target") else Vector3(INF, INF, INF)
	if position.is_finite(): game.set_navigation_target("campaign_" + str(row.id), CHAPTER_TITLE + " · " + str(row.title), position, announce)
	elif str(game.landmark_target_key).begins_with("campaign_"): game.clear_landmark_target(false)


func record_photo(position: Vector3) -> void:
	photos += 1
	last_photo_position = position


func skip_step() -> void:
	if finished: return
	step += 1
	_begin_step(false)
	if finished and str(game.landmark_target_key).begins_with("campaign_"): game.clear_landmark_target(false)
	game.notify("已跳过 · 下一个目标：" + (str(current().title) if not finished else "本章结束"), false)


func restart() -> void:
	_reset_steps()
	game.notify("重新开始 · " + CHAPTER_TITLE + "\n" + str(current().title), false)


func _vehicle_kind() -> String:
	return str(game.current_vehicle.kind) if is_instance_valid(game.current_vehicle) else ""


func _player_position() -> Vector3:
	return game.current_vehicle.global_position if is_instance_valid(game.current_vehicle) else game.player.global_position


func step_satisfied(row: Dictionary) -> bool:
	var totals := _totals()
	match str(row.kind):
		"vehicle": return is_instance_valid(game.current_vehicle)
		"reach":
			var target := target_position(str(row.target))
			if not target.is_finite(): return false
			var vehicles: Array = row.get("vehicles", [])
			if not vehicles.is_empty() and not _vehicle_kind() in vehicles: return false
			var here := _player_position()
			return Vector2(here.x - target.x, here.z - target.z).length() <= float(row.radius)
		"photo":
			if int(totals.photos) <= int(baseline.get("photos", 0)): return false
			var target := target_position(str(row.target))
			return target.is_finite() and last_photo_position.is_finite() and Vector2(last_photo_position.x - target.x, last_photo_position.z - target.z).length() <= float(row.radius)
		"job": return int(totals.jobs) > int(baseline.get("jobs", 0))
		"experience": return int(totals.experiences) > int(baseline.get("experiences", 0))
		"kills": return int(totals.kills) >= int(baseline.get("kills", 0)) + int(row.get("amount", 1))
	return false


func tick(delta: float) -> void:
	_clock += delta
	if _clock < 0.25: return
	_clock = 0.0
	_check_achievements()
	if finished: return
	var row := current()
	if row.is_empty() or not step_satisfied(row): return
	completed.append(str(row.id))
	var reward := 0 if rewarded.has(str(row.id)) else int(row.get("reward", 0))
	if not rewarded.has(str(row.id)): rewarded.append(str(row.id))
	_pay(reward)
	var messages := ["目标完成 · " + str(row.title) + ("  +$" + _money(reward) if reward > 0 else "")]
	if row.has("achievement"): messages.append_array(_unlock(str(row.achievement)))
	step += 1
	_begin_step(false)
	if finished:
		var bonus := 0 if rewarded.has("chapter") else CHAPTER_REWARD
		if bonus > 0: rewarded.append("chapter")
		_pay(bonus)
		messages.append("第一章完成 · " + CHAPTER_TITLE + ("  +$" + _money(bonus) if bonus > 0 else ""))
		messages.append_array(_unlock("chapter_one"))
		if str(game.landmark_target_key).begins_with("campaign_"): game.clear_landmark_target(false)
	else:
		messages.append("下一个目标：" + str(current().title))
	game.notify("\n".join(messages))


func _pay(amount: int) -> void:
	if amount <= 0: return
	game.life.money += amount
	game.life.lifetime_earnings += amount
	game.life.money_changed.emit(game.life.money)


func _money(amount: int) -> String:
	var text := str(amount)
	var grouped := ""
	for i in text.length():
		if i > 0 and (text.length() - i) % 3 == 0: grouped += ","
		grouped += text[i]
	return grouped


func _unlock(id: String) -> Array:
	var item := Achievements.unlock(id)
	return [] if item.is_empty() else ["成就解锁 · " + str(item.title)]


func _check_achievements() -> void:
	var notes := []
	var kind := _vehicle_kind()
	if is_instance_valid(game.current_vehicle):
		var kmh: float = game.current_vehicle.linear_velocity.length() * 3.6
		if kind in ["car", "motorcycle", "hoverboard"] and kmh >= 300.0: notes.append_array(_unlock("speed_300"))
		if kind == "fighter" and kmh >= 1235.0: notes.append_array(_unlock("supersonic"))
		if kind == "airliner" and game.current_vehicle.global_position.y > 40.0 and kmh > 150.0: notes.append_array(_unlock("airliner_takeoff"))
	var kills := int(game.survival.kills) if is_instance_valid(game.survival) else 0
	if kills >= 10: notes.append_array(_unlock("nailong_10"))
	if kills >= 100: notes.append_array(_unlock("nailong_100"))
	if int(game.life.money) >= 100000: notes.append_array(_unlock("money_100k"))
	var here := _player_position()
	for place: String in TOUR:
		if visited.has(place): continue
		for key: String in TOUR[place]:
			var target := target_position(key)
			if target.is_finite() and Vector2(here.x - target.x, here.z - target.z).length() <= 260.0:
				visited[place] = true
				break
	if visited.size() == TOUR.size(): notes.append_array(_unlock("landmark_tour"))
	if not notes.is_empty(): game.notify("\n".join(notes))


## Fills {action} placeholders with the player's current bindings or pad buttons.
func describe(text: String) -> String:
	var labels := {}
	for action: String in PAD_LABELS:
		labels[action] = PAD_LABELS[action] if bool(game._using_pad) else GameSettings.key_label(action)
	if not bool(game._using_pad): labels["fire"] = "左键 / " + str(labels.fire)
	return text.format(labels)


func update_panel() -> void:
	panel.visible = not hidden and not finished and bool(game.active)
	if not panel.visible: return
	var row := current()
	_header.text = "主线 · %s   %d / %d" % [CHAPTER_TITLE, step + 1, STEPS.size()]
	_title.text = str(row.title)
	var detail := str(row.detail)
	if str(row.kind) == "kills" and is_instance_valid(game.survival):
		detail = "进度 %d / %d · " % [mini(int(_totals().kills) - int(baseline.get("kills", 0)), int(row.amount)), int(row.amount)] + detail
	_detail.text = describe(detail)
	_distance.text = ""
	if row.has("target"):
		var target := target_position(str(row.target))
		if target.is_finite():
			var here := _player_position()
			var metres := Vector2(here.x - target.x, here.z - target.z).length()
			_distance.text = ("%.1f km" % (metres / 1000.0) if metres >= 1000.0 else "%d m" % int(metres)) + (" · 需要" + ("地面载具" if row.get("vehicles", []) == GROUND else "飞行器或船") if row.has("vehicles") else "")
	_distance.visible = not _distance.text.is_empty()


func menu_label() -> String:
	var progress := "已完成" if finished else "%d / %d" % [step + 1, STEPS.size()]
	return "目标与成就 · 主线 %s · 成就 %d / %d" % [progress, Achievements.unlocked_count(), Achievements.LIST.size()]


func build_menu() -> void:
	game.clear_panel("目标与成就", "主线任务把城市里的驾驶、工作、观光与战斗串起来；成就记录在本机，所有世界共享。")
	game._settings_section("主线 · %s%s" % [CHAPTER_TITLE, "  ·  已完成" if finished else ""])
	for i in STEPS.size():
		var row: Dictionary = STEPS[i]
		var done := completed.has(str(row.id))
		var skipped := not done and i < step
		var mark := "✓" if done else "—" if skipped else "▶" if i == step else "○"
		var text := "%s  %d. %s" % [mark, i + 1, row.title] + ("  · 已跳过" if skipped else "  · 奖励 $" + _money(int(row.reward)) if not rewarded.has(str(row.id)) else "")
		var line: Label = game.label(text, 16, Color("f4e3a6") if i == step and not finished else Color("dfe6dc") if done else Color("8d9a94"))
		game.modal_content.add_child(line)
		if i == step and not finished:
			var detail: Label = game.label(describe(str(row.detail)), 14, Color("b9c6bf"))
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.custom_minimum_size.x = 430
			game.modal_content.add_child(detail)
	if not finished:
		var row := current()
		if row.has("target"):
			game.button("导航到当前目标", func():
				_point_navigation(false)
				game.close_panel())
		game.button("跳过这一步（不发奖励）", func():
			skip_step()
			build_menu())
	game.button("显示目标追踪" if hidden else "隐藏目标追踪", func():
		hidden = not hidden
		build_menu())
	game.button("重新开始本章（已领奖励不重复发放）", func():
		restart()
		build_menu())
	game._settings_section("成就  %d / %d" % [Achievements.unlocked_count(), Achievements.LIST.size()])
	for item: Dictionary in Achievements.LIST:
		var unlocked := Achievements.is_unlocked(str(item.id))
		var line: Label = game.label(("✓  " if unlocked else "○  ") + str(item.title) + "  ·  " + str(item.detail), 15, Color("e3c46e") if unlocked else Color("7f8c86"))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 430
		game.modal_content.add_child(line)
	game.button("返回", game.pause_menu)
