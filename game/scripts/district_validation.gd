extends Node
## Evidence for the district loop: clearing work lands in the right district,
## liberation pays and opens the next one, the streets react, and a saved world
## comes back with the same progress.
const OUTPUT := "user://district-qa"
const Achievements = preload("res://scripts/achievements.gd")
const Store = preload("res://scripts/save_store.gd")
const QA_WORLD := "district_qa_roundtrip"
var game: Node
var districts: Node
var checks: Array[Dictionary] = []
var native := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func check(title: String, okay: bool, detail: Dictionary = {}) -> void:
	checks.append({"name": title, "passed": okay, "detail": detail})
	print("DISTRICT_QA ", "PASS " if okay else "FAIL ", title, " ", JSON.stringify(detail))

func frames(count: int = 3) -> void:
	for _i in count: await get_tree().process_frame

func settle() -> void:
	await get_tree().create_timer(0.4, true, false, true).timeout
	await frames(2)

func capture(name: String) -> void:
	if not native: return
	await frames(3)
	var started := Time.get_ticks_msec()
	var target := Engine.get_frames_drawn() + 1
	while Engine.get_frames_drawn() < target and Time.get_ticks_msec() - started < 30000: await get_tree().process_frame
	get_tree().root.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png"))

func clear_district(id: String) -> void:
	var centre: Vector3 = districts.centre(id)
	for i in districts.need(id):
		districts.add_work(centre, 1, "清剿奶龙")

func run(host: Node) -> void:
	game = host
	districts = game.districts
	native = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await frames(3)
	if not game.world._ready_complete:
		check("production world assembled", false)
		return finish()
	game.qa_running = true
	Achievements.reset_for_qa()
	game.new_world("life", "District QA - no save", false)
	game.survival.auto_spawn = false
	await frames(20)
	check("the city starts with every district held", districts.liberated.is_empty() and districts.progress.is_empty())
	check("only the first district is open", districts.unlocked("quay") and not districts.unlocked("rocks"))
	var quay: Vector3 = districts.centre("quay")
	game.player.global_position = quay + Vector3(0, 1.0, 0)
	await settle()
	check("standing in a district shows its card", districts.panel.visible and "环形码头" in districts._title.text, {"title": districts._title.text})
	check("the streets stay quiet while it is held", districts.street_factor(quay) < 1.0, {"factor": districts.street_factor(quay)})
	districts.add_work(quay + Vector3(4000, 0, 4000), 5, "清剿奶龙")
	check("work outside a district counts for nothing", districts.done("quay") == 0)
	districts.add_work(districts.centre("rocks"), 3, "清剿奶龙")
	check("a locked district cannot be cleared early", districts.done("rocks") == 0)
	# A defeated Nailong reports through the survival signal, not a direct call.
	game.survival.enemy_defeated.emit(quay, 3)
	await settle()
	check("defeating a Nailong credits the district it fell in", districts.done("quay") == 1, {"done": districts.done("quay")})
	await capture("district-card")
	var money: int = game.life.money
	for i in districts.need("quay") - 1: game.survival.enemy_defeated.emit(quay, 2)
	await settle()
	var reward: int = districts.BASE_REWARD
	check("clearing the work liberates the district", districts.liberated.has("quay"))
	check("liberation pays its reward", game.life.money == money + reward, {"paid": game.life.money - money, "expected": reward})
	check("liberation opens the next district", districts.unlocked("rocks"))
	check("a liberated district gets busier streets", districts.street_factor(quay) > 1.0, {"factor": districts.street_factor(quay)})
	check("first liberation unlocks 夺回第一个港区", Achievements.is_unlocked("first_district"))
	check("further work in a cleared district is ignored", districts.done("quay") == districts.need("quay"))
	game.survival.enemy_defeated.emit(quay, 2)
	check("the cleared district stays at full", districts.done("quay") == districts.need("quay"))
	# Helping residents counts as well, through the service signal.
	game.player.global_position = districts.centre("rocks") + Vector3(0, 1.0, 0)
	game.life.service_completed.emit({"ok": true, "id": "qa"})
	await settle()
	check("a city experience counts as clearing work", districts.done("rocks") == districts.TASK_VALUE, {"done": districts.done("rocks")})
	game.districts_menu()
	await frames(3)
	var texts: Array = game.modal_content.get_children().filter(func(c): return c is Label or c is Button).map(func(c): return str(c.text))
	check("the district menu lists every district", districts.DISTRICTS.all(func(row: Dictionary): return texts.any(func(t: String): return str(row.name) in t)))
	check("the menu shows what is done and what is locked", texts.any(func(t: String): return "已解放" in t) and texts.any(func(t: String): return "未开放" in t))
	await capture("district-menu")
	game.close_panel()
	await frames(3)
	var state: Dictionary = districts.get_state()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(state))
	districts.reset()
	districts.apply_state(parsed)
	check("district progress survives a JSON round trip", JSON.stringify(districts.get_state()) == JSON.stringify(state), {"before": state, "after": districts.get_state()})
	districts.apply_state({"progress": {"quay": "lots", "nowhere": 4}, "liberated": ["nowhere", 7]})
	check("malformed district data loads as a clean city", districts.progress.is_empty() and districts.liberated.is_empty())
	districts.apply_state(parsed)
	game.world_id = QA_WORLD
	check("production save writes the world", game.save_world())
	var saved: Dictionary = Store.read(QA_WORLD)
	check("the save file carries the district section", saved.get("districts") is Dictionary and saved.districts.liberated.has("quay"))
	districts.reset()
	game.load_world(QA_WORLD)
	await frames(10)
	check("loading restores liberated districts and progress", districts.liberated.has("quay") and districts.done("rocks") == districts.TASK_VALUE, {"state": districts.get_state()})
	saved.erase("districts")
	Store.write(QA_WORLD, saved)
	game.load_world(QA_WORLD)
	await frames(10)
	check("worlds saved before the districts start with the city held", districts.liberated.is_empty())
	for suffix: String in [".json", ".json.bak"]:
		if FileAccess.file_exists(Store.ROOT + QA_WORLD + suffix): DirAccess.remove_absolute(Store.ROOT + QA_WORLD + suffix)
	for row: Dictionary in districts.summary(): clear_district(str(row.id))
	check("clearing every district unlocks 港城解放", Achievements.is_unlocked("city_free") and districts.liberated.size() == districts.DISTRICTS.size(), {"liberated": districts.liberated.size()})
	finish()

func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(row: Dictionary): return row.passed)
	var file := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"passed": passed, "native": native, "checks": checks}, "\t"))
	print("DISTRICT_QA COMPLETE checks=%d failures=%d" % [checks.size(), checks.filter(func(row: Dictionary): return not row.passed).size()])
	game.active = false
	game.finish_quit(0 if passed else 1)
