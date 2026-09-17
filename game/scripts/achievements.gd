extends RefCounted
## Account-wide achievements, stored once per player like platform achievements.
## A platform backend (for example Steamworks) can be attached with set_backend();
## it receives the same stable IDs. QA runs keep unlocks in memory only.

const PATH := "user://achievements.json"
const LIST := [
	{"id": "first_ride", "title": "上路", "detail": "第一次驾驶任意载具"},
	{"id": "quay_arrival", "title": "港口来客", "detail": "抵达环形码头"},
	{"id": "opera_photo", "title": "镜头里的歌剧院", "detail": "在歌剧院附近拍一张照片"},
	{"id": "first_job", "title": "第一份工作", "detail": "完成任意一份工作"},
	{"id": "bridge_cross", "title": "跨越海港", "detail": "驾驶地面载具驶过海港大桥"},
	{"id": "manly_trip", "title": "北岸海风", "detail": "乘飞行器或船抵达曼利"},
	{"id": "taste_city", "title": "城市味道", "detail": "完成一次城市体验"},
	{"id": "chapter_one", "title": "港城第一天", "detail": "完成主线第一章"},
	{"id": "speed_300", "title": "风驰电掣", "detail": "地面载具时速超过 300 km/h"},
	{"id": "supersonic", "title": "音障之外", "detail": "驾驶战斗机时速超过 1,235 km/h"},
	{"id": "airliner_takeoff", "title": "航班起飞", "detail": "驾驶客机离开跑道"},
	{"id": "nailong_10", "title": "清理街区", "detail": "累计击败 10 只奶龙"},
	{"id": "nailong_100", "title": "港城守护者", "detail": "累计击败 100 只奶龙"},
	{"id": "money_100k", "title": "海港富翁", "detail": "持有 $100,000"},
	{"id": "landmark_tour", "title": "悉尼通", "detail": "到访歌剧院、海港大桥、悉尼塔、QVB、ICC 与曼利"},
]

static var _unlocked: Dictionary = {}
static var _loaded := false
static var _backend: Object = null
static var persist := true


static func set_backend(backend: Object) -> void:
	_backend = backend
	if is_instance_valid(_backend) and _backend.has_method("set_achievement"):
		for id: String in _unlocked: _backend.call("set_achievement", id)


static func _load() -> void:
	if _loaded: return
	_loaded = true
	if not persist or not FileAccess.file_exists(PATH): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is Dictionary and data.get("unlocked") is Dictionary:
		for id: Variant in data.unlocked:
			if find(str(id)).is_empty(): continue
			_unlocked[str(id)] = str(data.unlocked[id])


static func reset_for_qa() -> void:
	persist = false
	_loaded = true
	_unlocked.clear()


static func find(id: String) -> Dictionary:
	for item: Dictionary in LIST:
		if item.id == id: return item
	return {}


static func is_unlocked(id: String) -> bool:
	_load()
	return _unlocked.has(id)


static func unlocked_count() -> int:
	_load()
	return _unlocked.size()


## Returns the achievement when this call unlocked it, otherwise an empty dictionary.
static func unlock(id: String) -> Dictionary:
	_load()
	var item := find(id)
	if item.is_empty() or _unlocked.has(id): return {}
	_unlocked[id] = Time.get_datetime_string_from_system(true)
	if persist:
		var file := FileAccess.open(PATH, FileAccess.WRITE)
		if file: file.store_string(JSON.stringify({"version": 1, "unlocked": _unlocked}, "\t"))
	if is_instance_valid(_backend) and _backend.has_method("set_achievement"): _backend.call("set_achievement", id)
	return item
