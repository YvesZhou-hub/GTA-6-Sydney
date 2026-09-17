extends Node
## Chapter one and achievement evidence. Drives the production world through every
## objective by moving the player and changing the same counters real play changes,
## then checks rewards, navigation, menus, save/load and malformed saves.
const OUTPUT := "user://campaign-qa"
const Achievements = preload("res://scripts/achievements.gd")
const Store = preload("res://scripts/save_store.gd")
const QA_WORLD := "campaign_qa_roundtrip"
var game: Node
var campaign: Node
var checks: Array[Dictionary] = []
var native := false


class RecordingBackend:
	var ids := []
	func set_achievement(id: String) -> void: ids.append(id)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func check(title: String, okay: bool, detail: Dictionary = {}) -> void:
	checks.append({"name": title, "passed": okay, "detail": detail})
	print("CAMPAIGN_QA ", "PASS " if okay else "FAIL ", title, " ", JSON.stringify(detail))


func frames(count: int = 3) -> void:
	for _i in count: await get_tree().process_frame


func settle() -> void:
	# The campaign polls four times a second.
	await get_tree().create_timer(0.45, true, false, true).timeout
	await frames(2)


func move_to(position: Vector3) -> void:
	if is_instance_valid(game.current_vehicle):
		game.current_vehicle.global_position = position
		game.current_vehicle.linear_velocity = Vector3.ZERO
		game.current_vehicle.reset_physics_interpolation()
	game.player.global_position = position
	await frames(2)


func ride(kind: String) -> void:
	if is_instance_valid(game.current_vehicle) and game.current_vehicle.kind == kind: return
	var vehicle = game.request_vehicle(kind)
	check("spawned and entered " + kind, vehicle != null and game.current_vehicle == vehicle)
	await frames(10)


func capture(name: String) -> void:
	if not native: return
	await frames(4)
	var started := Time.get_ticks_msec()
	var target := Engine.get_frames_drawn() + 1
	while Engine.get_frames_drawn() < target and Time.get_ticks_msec() - started < 30000: await get_tree().process_frame
	get_tree().root.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png"))


func run(host: Node) -> void:
	game = host
	campaign = game.campaign
	native = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await frames(3)
	if not game.world._ready_complete:
		check("production world assembled", false)
		return finish()
	game.qa_running = true
	Achievements.reset_for_qa()
	check("QA never writes player achievements", not Achievements.persist)
	game.new_world("life", "Campaign QA - no save", false)
	game.survival.auto_spawn = false
	await frames(30)
	await check_chapter()
	await check_restart_and_skip()
	await check_achievements()
	await check_text_and_menu()
	await check_saves()
	finish()


func check_chapter() -> void:
	var font: Font = game.font
	check("UI font has the checklist symbols", Array("✓○▶—".split("")).all(func(c: String): return font.has_char(c.unicode_at(0))))
	check("new world starts chapter one at the first step", campaign.step == 0 and not campaign.finished and campaign.completed.is_empty())
	check("objective tracker is shown in the left HUD column", campaign.panel.is_visible_in_tree() and campaign.panel.get_parent() == game.left_column and "1 / 8" in campaign._header.text, {"header": campaign._header.text})
	await capture("objective-tracker")
	var money_start: int = game.life.money
	await settle()
	check("walking alone does not complete the ride step", campaign.step == 0)

	await ride("car")
	await settle()
	check("entering a vehicle completes step 1 and pays $2,000", campaign.step == 1 and game.life.money == money_start + 2000, {"step": campaign.step, "money": game.life.money - money_start})
	check("step 1 unlocks 上路", Achievements.is_unlocked("first_ride"))
	check("step 2 points navigation at Circular Quay", game.landmark_target_key == "campaign_quay" and game.landmark_target_position.distance_to(game.world.anchors.quay) < 0.1, {"key": game.landmark_target_key})
	check("tracker shows the distance to the quay", campaign._distance.visible and ("m" in campaign._distance.text), {"distance": campaign._distance.text})

	await move_to(game.world.anchors.quay + Vector3(0, 1.5, 0))
	await settle()
	check("arriving at the quay completes step 2", campaign.step == 2, {"step": campaign.step})

	var photos_before: int = campaign.photos
	campaign.record_photo(game.player.global_position)
	await settle()
	check("a photo far from the opera house does not count", campaign.step == 2 and campaign.photos == photos_before + 1)
	await move_to(game.world.anchors.opera + Vector3(0, 1.5, 0))
	if native:
		var existing := DirAccess.get_files_at("user://photos") if DirAccess.dir_exists_absolute("user://photos") else PackedStringArray()
		game.pause_menu()
		await frames(2)
		await game.photo_from_menu()
		for file: String in DirAccess.get_files_at("user://photos"):
			if not file in existing: DirAccess.remove_absolute("user://photos/" + file)
	else:
		campaign.record_photo(game.player.global_position)
	await settle()
	check("a photo near the opera house completes step 3", campaign.step == 3 and campaign.completed.has("opera_photo"), {"step": campaign.step, "native_photo_path": native})
	check("photo taken from the pause menu returns to gameplay", not game.modal.visible and not game.paused)
	check("a step without a place clears the previous objective marker", game.landmark_target_key == "", {"key": game.landmark_target_key})

	game.life.completed_jobs["campaign_qa"] = int(game.life.completed_jobs.get("campaign_qa", 0)) + 1
	await settle()
	check("completing a job completes step 4", campaign.step == 4)
	check("step 5 points navigation at the north bridge entry", game.landmark_target_key == "campaign_bridge", {"key": game.landmark_target_key})

	await ride("helicopter")
	await move_to(campaign.target_position("bridge_north") + Vector3(0, 30, 0))
	await settle()
	check("flying over the north bridge entry does not count as driving across", campaign.step == 4)
	await ride("car")
	await move_to(campaign.target_position("bridge_north") + Vector3(0, 1.5, 0))
	await settle()
	check("driving to the north bridge entry completes step 5", campaign.step == 5)
	check("tracker names the vehicle requirement", "飞行器或船" in campaign._distance.text, {"distance": campaign._distance.text})

	await move_to(game.world.anchors.manly_wharf + Vector3(0, 1.5, 0))
	await settle()
	check("driving a car to Manly does not complete the air or sea step", campaign.step == 5)
	await ride("helicopter")
	await move_to(game.world.anchors.manly_wharf + Vector3(0, 60, 0))
	await settle()
	check("flying to Manly Wharf completes step 6", campaign.step == 6)

	game.life.experience_visits["campaign_qa"] = int(game.life.experience_visits.get("campaign_qa", 0)) + 1
	await settle()
	check("an experience completes step 7", campaign.step == 7)

	game.survival.kills += 4
	await settle()
	check("four kills are not enough for step 8", campaign.step == 7 and "4 / 5" in campaign._detail.text, {"detail": campaign._detail.text})
	game.survival.kills += 1
	await settle()
	var expected := 2000 + 3000 + 3000 + 4000 + 4000 + 5000 + 3000 + 5000 + 20000
	check("fifth kill finishes the chapter", campaign.finished and campaign.completed.size() == 8)
	check("chapter pays every step plus the $20,000 bonus exactly once", game.life.money - money_start == expected, {"paid": game.life.money - money_start, "expected": expected})
	check("chapter unlocks 港城第一天 and seven step achievements", Achievements.is_unlocked("chapter_one") and ["first_ride", "quay_arrival", "opera_photo", "first_job", "bridge_cross", "manly_trip", "taste_city"].all(func(id: String): return Achievements.is_unlocked(id)))
	check("finished chapter hides the tracker and clears its marker", not campaign.panel.visible and not str(game.landmark_target_key).begins_with("campaign_"), {"key": game.landmark_target_key})
	check("completion toast reports the chapter", "第一章完成" in game.toast_label.text, {"toast": game.toast_label.text})


func check_restart_and_skip() -> void:
	var money: int = game.life.money
	campaign.restart()
	await settle()
	check("restart returns to step 1, and sitting in a vehicle re-completes it", campaign.step == 1 and not campaign.finished)
	check("restarted steps never pay twice", game.life.money == money, {"delta": game.life.money - money})
	campaign.skip_step()
	await frames(2)
	check("skip advances without marking the step complete", campaign.step == 2 and not campaign.completed.has("quay"))
	check("skip points navigation at the next target", game.landmark_target_key == "campaign_opera_photo", {"key": game.landmark_target_key})
	for i in 6: campaign.skip_step()
	check("skipping the last step ends the chapter without a marker", campaign.finished and not str(game.landmark_target_key).begins_with("campaign_"))
	campaign.restart()
	await frames(2)


func check_achievements() -> void:
	await ride("car")
	check("walking pace does not unlock 风驰电掣", not Achievements.is_unlocked("speed_300"))
	await move_to(game.world.anchors.quay + Vector3(0, 120, -300))
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 700:
		game.current_vehicle.linear_velocity = Vector3(0, 0, 90)
		await get_tree().physics_frame
	check("300 km/h in a ground vehicle unlocks 风驰电掣", Achievements.is_unlocked("speed_300"))
	game.current_vehicle.linear_velocity = Vector3.ZERO
	await move_to(game.world.anchors.quay + Vector3(0, 1.5, 0))
	game.life.money = 100000
	await settle()
	check("holding $100,000 unlocks 海港富翁", Achievements.is_unlocked("money_100k"))
	for place: String in campaign.TOUR:
		check("tour place %s has an anchor" % place, campaign.TOUR[place].any(func(key: String): return campaign.target_position(key).is_finite()))
	for place: String in campaign.TOUR:
		var key: String = campaign.TOUR[place].filter(func(k: String): return campaign.target_position(k).is_finite()).front()
		await move_to(campaign.target_position(key) + Vector3(0, 2, 0))
		await settle()
	check("visiting six landmarks unlocks 悉尼通", Achievements.is_unlocked("landmark_tour"), {"visited": campaign.visited.keys()})
	check("unlocking twice returns nothing", Achievements.unlock("first_ride").is_empty())
	var backend := RecordingBackend.new()
	Achievements.set_backend(backend)
	check("platform backend receives existing unlocks when attached", backend.ids.has("speed_300") and backend.ids.has("chapter_one"), {"ids": backend.ids})
	Achievements.unlock("nailong_10")
	check("platform backend receives new unlocks with stable IDs", backend.ids.has("nailong_10"))
	Achievements.set_backend(null)


func check_text_and_menu() -> void:
	campaign.restart()
	await frames(2)
	GameSettings_apply({"interact": [KEY_F]})
	check("objective text follows rebound keys", "按 F 上车" in campaign.describe(str(campaign.STEPS[0].detail)), {"text": campaign.describe(str(campaign.STEPS[0].detail))})
	GameSettings_apply({})
	game._using_pad = true
	check("objective text switches to controller buttons", "按 B 上车" in campaign.describe(str(campaign.STEPS[0].detail)) and "按 Y" in campaign.describe(str(campaign.STEPS[0].detail)))
	game._using_pad = false
	check("objective text never shows unfilled placeholders", campaign.STEPS.all(func(row: Dictionary): return not "{" in campaign.describe(str(row.detail))))

	game.pause_menu()
	await frames(2)
	var entry: Button = null
	for child in game.modal_content.get_children():
		if child is Button and str(child.text).begins_with("目标与成就"): entry = child
	check("pause menu lists 目标与成就 with progress", entry != null and "成就" in entry.text, {"text": entry.text if entry else ""})
	if entry: entry.pressed.emit()
	await frames(2)
	var texts: Array = game.modal_content.get_children().filter(func(c): return c is Label or c is Button).map(func(c): return str(c.text))
	check("objectives menu lists all eight steps", range(1, 9).all(func(i: int): return texts.any(func(t: String): return (" %d. " % i) in t)))
	check("objectives menu lists every achievement", Achievements.LIST.all(func(item: Dictionary): return texts.any(func(t: String): return str(item.title) in t)))
	await capture("objectives-menu")
	var hide: Button = null
	for child in game.modal_content.get_children():
		if child is Button and child.text == "隐藏目标追踪": hide = child
	check("objectives menu can hide the tracker", hide != null)
	if hide: hide.pressed.emit()
	await frames(2)
	game.close_panel()
	await frames(3)
	check("hidden tracker stays hidden in play", campaign.hidden and not campaign.panel.visible)
	campaign.hidden = false
	await frames(3)
	check("tracker returns when shown again", campaign.panel.visible)


func GameSettings_apply(bindings: Dictionary) -> void:
	preload("res://scripts/game_settings.gd").apply_bindings(bindings)


func check_saves() -> void:
	campaign.restart()
	campaign.skip_step()
	campaign.skip_step()
	await frames(2)
	var state: Dictionary = campaign.get_state()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(state))
	campaign.start_new()
	campaign.apply_state(parsed)
	check("campaign state survives a JSON round trip", JSON.stringify(campaign.get_state()) == JSON.stringify(state), {"before": state, "after": campaign.get_state()})
	campaign.apply_state({"chapter": campaign.CHAPTER_ID, "step": "nine", "completed": 5, "rewarded": {"x": 1}, "visited": "opera", "baseline": [], "photos": null})
	check("malformed campaign data loads as a safe chapter start", campaign.step == 0 and campaign.completed.is_empty() and campaign.rewarded.is_empty() and campaign.visited.is_empty())
	campaign.apply_state({"chapter": campaign.CHAPTER_ID, "step": 99})
	check("out-of-range step loads as a finished chapter", campaign.finished and campaign.step == campaign.STEPS.size())

	campaign.restart()
	campaign.skip_step()
	campaign.skip_step()
	await frames(2)
	game.world_id = QA_WORLD
	check("production save writes the world", game.save_world())
	var saved: Dictionary = Store.read(QA_WORLD)
	check("save file contains the campaign section", saved.get("campaign") is Dictionary and int(saved.campaign.step) == 2)
	campaign.start_new()
	game.load_world(QA_WORLD)
	await frames(10)
	check("loading the world restores the campaign step", campaign.step == 2 and not campaign.finished, {"step": campaign.step})
	check("loading restores the objective marker with its campaign key", game.landmark_target_key == "campaign_opera_photo" and "给歌剧院拍张照" in str(game.landmark_target_name) and game.landmark_target_position.distance_to(game.world.anchors.opera) < 0.1, {"key": game.landmark_target_key, "name": game.landmark_target_name})
	await move_to(game.world.anchors.opera + Vector3(0, 1.5, 0))
	campaign.record_photo(game.player.global_position)
	await settle()
	check("a loaded objective marker is cleared when the next step has no place", campaign.step == 3 and game.landmark_target_key == "", {"key": game.landmark_target_key})
	campaign.restart()
	campaign.skip_step()
	campaign.skip_step()
	check("production save keeps step 2 for the old-save check", game.save_world())
	saved = Store.read(QA_WORLD)

	saved.erase("campaign")
	Store.write(QA_WORLD, saved)
	game.load_world(QA_WORLD)
	await frames(10)
	check("worlds saved before the campaign start chapter one", campaign.step <= 1 and not campaign.finished, {"step": campaign.step})

	saved["campaign"] = []
	var file := FileAccess.open(Store.ROOT + QA_WORLD + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	check("save validation rejects a campaign section that is not a dictionary", Store.read(QA_WORLD).is_empty())
	for suffix: String in [".json", ".json.bak"]:
		if FileAccess.file_exists(Store.ROOT + QA_WORLD + suffix): DirAccess.remove_absolute(Store.ROOT + QA_WORLD + suffix)


func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(row: Dictionary): return row.passed)
	var file := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"passed": passed, "native": native, "checks": checks}, "\t"))
	print("CAMPAIGN_QA COMPLETE checks=%d failures=%d" % [checks.size(), checks.filter(func(row: Dictionary): return not row.passed).size()])
	game.active = false
	game.finish_quit(0 if passed else 1)
