extends Node
## The city loop: Nailong hold the harbour districts, the player takes them back
## one at a time. Clearing enemies and helping residents inside a district lowers
## its threat; at zero the district is liberated, its streets fill with people
## again, the reward lands and the next district opens.

const Achievements = preload("res://scripts/achievements.gd")
## id, name, the anchor its centre comes from, fallback centre, radius, work needed.
const DISTRICTS := [
	{"id": "quay", "name": "环形码头", "anchor": "quay", "center": Vector3(70, 5, 165), "radius": 260.0, "need": 6},
	{"id": "rocks", "name": "岩石区", "anchor": "rocks", "center": Vector3(-210, 5, -175), "radius": 240.0, "need": 8},
	{"id": "opera", "name": "歌剧院", "anchor": "opera", "center": Vector3(414, 5, -151), "radius": 260.0, "need": 10},
	{"id": "cbd", "name": "市中心", "anchor": "martin_place_metro", "center": Vector3(-33, 4.5, 700), "radius": 420.0, "need": 12},
	{"id": "darling", "name": "达令港", "anchor": "ribbon", "center": Vector3(-440, 5, 900), "radius": 380.0, "need": 14},
	{"id": "barangaroo", "name": "巴兰加鲁", "anchor": "tower_one", "center": Vector3(-700, 5, 120), "radius": 320.0, "need": 16},
	{"id": "north", "name": "北岸", "anchor": "north", "center": Vector3(50, 5, -1350), "radius": 340.0, "need": 18},
	{"id": "manly", "name": "曼利", "anchor": "manly_wharf", "center": Vector3(6100, 5, -5200), "radius": 420.0, "need": 20},
	{"id": "airport", "name": "悉尼机场", "anchor": "airport", "center": Vector3(-4180, 5, 8600), "radius": 700.0, "need": 22},
]
## Helping residents inside a district counts for this much clearing work.
const TASK_VALUE := 2
const BASE_REWARD := 6000
const STEP_REWARD := 2000
## Timed calls for help inside a district: clear a siege, or sweep three points.
const EVENT_SECONDS := 180.0
const EVENT_GAP := 150.0
const EVENT_WORK := 3
const EVENT_REWARD := 3000
const SIEGE_RADIUS := 70.0
const SWEEP_RADIUS := 22.0

signal district_changed(id: String)
signal event_changed(state: Dictionary)

var game: Node
var progress: Dictionary = {}
var liberated: Dictionary = {}
var centres: Dictionary = {}
var panel: PanelContainer
var event: Dictionary = {}
var _event_gap := 60.0
var _title: Label
var _detail: Label
var _bar: ProgressBar
var _clock := 0.0


func setup(host: Node) -> void:
	game = host
	name = "Districts"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for row: Dictionary in DISTRICTS:
		var anchor: Variant = game.world.anchors.get(str(row.anchor), null)
		centres[row.id] = anchor if anchor is Vector3 else row.center
	if is_instance_valid(game.survival) and game.survival.has_signal("enemy_defeated"):
		game.survival.enemy_defeated.connect(_on_enemy_defeated)
	if is_instance_valid(game.life):
		game.life.service_completed.connect(func(_result: Dictionary): add_work(game.player.global_position, TASK_VALUE, "城市体验"))
		game.life.job_completed.connect(func(_id: String): add_work(game.player.global_position, TASK_VALUE, "完成工作"))
	_build_panel()
	reset()


func reset() -> void:
	progress.clear()
	liberated.clear()
	end_event("")
	_event_gap = 60.0
	if is_instance_valid(panel): panel.visible = false


func definition(id: String) -> Dictionary:
	for row: Dictionary in DISTRICTS:
		if row.id == id: return row
	return {}


func centre(id: String) -> Vector3:
	return centres.get(id, definition(id).get("center", Vector3.ZERO))


## The first district is always open; each next one waits for the one before it.
func unlocked(id: String) -> bool:
	var index := 0
	for row: Dictionary in DISTRICTS:
		if row.id == id: break
		index += 1
	if index == 0: return true
	return liberated.has(str(DISTRICTS[index - 1].id))


func at(position: Vector3) -> String:
	var best := ""
	var best_distance := INF
	for row: Dictionary in DISTRICTS:
		var distance := Vector2(position.x - centre(row.id).x, position.z - centre(row.id).z).length()
		if distance <= float(row.radius) and distance < best_distance:
			best_distance = distance
			best = str(row.id)
	return best


func done(id: String) -> int:
	return int(progress.get(id, 0))


func need(id: String) -> int:
	return int(definition(id).get("need", 0))


## How lively the streets are here: quiet where Nailong still hold the ground.
func street_factor(position: Vector3) -> float:
	var id := at(position)
	if id.is_empty(): return 1.0
	if liberated.has(id): return 1.4
	if not unlocked(id): return 0.55
	return 0.7


## Clearing work from a defeated Nailong or from helping residents.
func add_work(position: Vector3, amount: int, reason: String) -> void:
	var id := at(position)
	if id.is_empty() or liberated.has(id) or not unlocked(id) or amount <= 0: return
	progress[id] = mini(need(id), done(id) + amount)
	district_changed.emit(id)
	if done(id) >= need(id): _liberate(id, reason)
	elif reason != "": game.notify("%s · %s  %d / %d" % [str(definition(id).name), reason, done(id), need(id)], false)


func _on_enemy_defeated(position: Vector3, _level: int) -> void:
	add_work(position, 1, "清剿奶龙")
	_event_kill(position)


func _liberate(id: String, _reason: String) -> void:
	liberated[id] = true
	var index := 0
	for row: Dictionary in DISTRICTS:
		if row.id == id: break
		index += 1
	var reward := BASE_REWARD + STEP_REWARD * index
	game.life.money += reward
	game.life.lifetime_earnings += reward
	game.life.money_changed.emit(game.life.money)
	var messages := ["%s 已解放  +$%s" % [str(definition(id).name), _money(reward)], "街上的人回来了。"]
	if index + 1 < DISTRICTS.size():
		messages.append("下一个港区已开放：" + str(DISTRICTS[index + 1].name))
	for unlock: String in ["first_district" if liberated.size() == 1 else "", "city_free" if liberated.size() >= DISTRICTS.size() else ""]:
		if unlock.is_empty(): continue
		var item := Achievements.unlock(unlock)
		if not item.is_empty(): messages.append("成就解锁 · " + str(item.title))
	game.notify("\n".join(messages))
	district_changed.emit(id)


func _money(amount: int) -> String:
	var text := str(amount)
	var grouped := ""
	for i in text.length():
		if i > 0 and (text.length() - i) % 3 == 0: grouped += ","
		grouped += text[i]
	return grouped


func get_state() -> Dictionary:
	return {"progress": progress.duplicate(), "liberated": liberated.keys()}


func apply_state(data: Dictionary) -> void:
	reset()
	if not data is Dictionary: return
	var saved: Variant = data.get("progress", {})
	if saved is Dictionary:
		for id: Variant in saved:
			if not definition(str(id)).is_empty() and typeof(saved[id]) in [TYPE_INT, TYPE_FLOAT]:
				progress[str(id)] = clampi(int(saved[id]), 0, need(str(id)))
	var cleared: Variant = data.get("liberated", [])
	if cleared is Array:
		for id: Variant in cleared:
			if not definition(str(id)).is_empty(): liberated[str(id)] = true


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "DistrictPanel"
	panel.theme_type_variation = "CardPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	_title = game.label("", 16, Color("f4f1df"))
	_detail = game.label("", 13, Color("bcc9c6"))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size.x = 246
	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.step = 0.001
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(246, 7)
	box.add_child(_title)
	box.add_child(_bar)
	box.add_child(_detail)
	# The left column already carries status, objective and survival cards, so the
	# district sits under the minimap, beside the map it describes.
	game.hud.add_child(panel)
	panel.visible = false


func update_panel() -> void:
	if not is_instance_valid(panel): return
	var id := at(game.player.global_position) if is_instance_valid(game.player) else ""
	panel.visible = bool(game.active) and not id.is_empty()
	if not panel.visible: return
	var row := definition(id)
	if liberated.has(id):
		_title.text = "%s · 已解放" % str(row.name)
		_bar.value = 1.0
		_detail.text = "街上恢复了往来的人和车。"
	elif not unlocked(id):
		_title.text = "%s · 未开放" % str(row.name)
		_bar.value = 0.0
		_detail.text = "先解放前一个港区。"
	else:
		_title.text = "%s · 清剿中  %d / %d" % [str(row.name), done(id), need(id)]
		_bar.value = float(done(id)) / maxf(1.0, float(need(id)))
		_detail.text = "击败这里的奶龙，或在这里完成工作与城市体验。"
	if not event.is_empty() and str(event.district) == id:
		var left := int(ceil(float(event.left)))
		_detail.text = "%s  %d / %d · 剩余 %d:%02d" % [str(event.title), int(event.done), int(event.need), left / 60, left % 60]
	# Placed last: the card is only as wide as the text it just received.
	_place_panel()


## Keeps the card under the minimap, whatever the window size is.
func _place_panel() -> void:
	if not is_instance_valid(panel) or not is_instance_valid(game.hud): return
	var top := 96.0
	if is_instance_valid(game.minimap) and game.minimap.is_visible_in_tree():
		top = game.minimap.get_global_rect().end.y - game.hud.global_position.y + 12.0
	var wanted: Vector2 = panel.get_combined_minimum_size()
	panel.size = wanted
	panel.position = Vector2(maxf(12.0, game.hud.size.x - wanted.x - 28.0), top)


func _process(delta: float) -> void:
	if not is_instance_valid(game) or not game.active or game.paused: return
	_clock += delta
	if _clock < 0.25: return
	_clock = 0.0
	_tick_event(0.25)


## A district in trouble calls for help: either a siege to break, or three
## points to sweep. Sweeps also work in the sandbox, where there are no Nailong.
func start_event(id: String, kind: String = "") -> Dictionary:
	if not unlocked(id) or liberated.has(id) or not event.is_empty(): return {}
	var fights: bool = is_instance_valid(game.survival) and bool(game.survival.enabled)
	var chosen := kind if kind != "" else ("siege" if fights else "sweep")
	if chosen == "siege" and not fights: chosen = "sweep"
	var middle := centre(id)
	var radius: float = float(definition(id).radius) * 0.55
	var angle := fposmod(float(Time.get_ticks_msec()) * 0.001, TAU)
	var points: Array = []
	for i in (3 if chosen == "sweep" else 1):
		var turn := angle + TAU * float(i) / 3.0
		points.append(middle + Vector3(sin(turn), 0.0, cos(turn)) * radius * (0.5 + 0.5 * float(i % 2)))
	event = {"district": id, "kind": chosen, "left": EVENT_SECONDS, "points": points, "index": 0,
		"need": 5 if chosen == "siege" else 3, "done": 0,
		"title": ("奶龙围攻 · %s" % str(definition(id).name)) if chosen == "siege" else ("巡查 · %s" % str(definition(id).name))}
	game.set_navigation_target("district_event", str(event.title), points[0], false)
	game.notify("%s\n%s" % [str(event.title), "在标记附近击退 5 只奶龙" if chosen == "siege" else "在时间内走访 3 个标记点"])
	event_changed.emit(event)
	return event


func end_event(reason: String) -> void:
	if event.is_empty(): return
	var finished := event.duplicate()
	event = {}
	_event_gap = EVENT_GAP
	if str(game.landmark_target_key) == "district_event": game.clear_landmark_target(false)
	if reason == "done":
		var id := str(finished.district)
		var reward := EVENT_REWARD
		game.life.money += reward
		game.life.lifetime_earnings += reward
		game.life.money_changed.emit(game.life.money)
		add_work(centre(id), EVENT_WORK, "")
		game.notify("%s 完成  +$%s\n港区清剿 +%d" % [str(finished.title), _money(reward), EVENT_WORK])
	elif reason == "timeout":
		game.notify("%s 超时 · 稍后还会有新的求助" % str(finished.title), false)
	elif reason == "left":
		game.notify("%s 已取消 · 你离开了这个港区" % str(finished.title), false)
	event_changed.emit({})


func _tick_event(delta: float) -> void:
	var here: Vector3 = game.player.global_position
	if event.is_empty():
		_event_gap = maxf(0.0, _event_gap - delta)
		var id := at(here)
		if _event_gap <= 0.0 and not id.is_empty() and unlocked(id) and not liberated.has(id): start_event(id)
		return
	if not event.has("district") or not event.has("points"):
		event = {}
		return
	event.left = float(event.left) - delta
	# Driving right out of the area cancels the call instead of leaving a timer
	# running on the other side of the harbour.
	var away := here.distance_to(centre(str(event.district)))
	if away > float(definition(str(event.district)).radius) * 1.8:
		end_event("left")
		return
	if str(event.kind) == "sweep":
		var target: Vector3 = event.points[int(event.index)]
		if Vector2(here.x - target.x, here.z - target.z).length() < SWEEP_RADIUS:
			event.index = int(event.index) + 1
			event.done = int(event.done) + 1
			if int(event.done) >= int(event.need):
				end_event("done")
				return
			game.set_navigation_target("district_event", str(event.title), event.points[int(event.index)], false)
			game.notify("%s  %d / %d" % [str(event.title), int(event.done), int(event.need)], false)
	if float(event.left) <= 0.0: end_event("timeout")


## Siege progress comes from Nailong defeated near the marked point.
func _event_kill(position: Vector3) -> void:
	if event.is_empty() or str(event.kind) != "siege": return
	var target: Vector3 = event.points[0]
	if Vector2(position.x - target.x, position.z - target.z).length() > SIEGE_RADIUS: return
	event.done = int(event.done) + 1
	if int(event.done) >= int(event.need): end_event("done")
	else: game.notify("%s  %d / %d" % [str(event.title), int(event.done), int(event.need)], false)


func summary() -> Array:
	var rows := []
	for row: Dictionary in DISTRICTS:
		var id := str(row.id)
		rows.append({"id": id, "name": str(row.name), "done": done(id), "need": need(id),
			"liberated": liberated.has(id), "unlocked": unlocked(id), "centre": centre(id)})
	return rows
