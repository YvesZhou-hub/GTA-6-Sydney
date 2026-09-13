extends SceneTree
## Isolated production HUD: no world generation, player saves or economy writes.
const HUD = preload("res://scripts/survival_hud.gd")
var checks: Array[Dictionary] = []
var healing := 0
var services := 0

class HostFixture extends Node:
	var active := true
	var paused := false
	var modal := Control.new()
	var map_panel := Control.new()
	func _init():
		modal.visible = false
		map_panel.visible = false
		add_child(modal)
		add_child(map_panel)


func _initialize():
	call_deferred("run")


func check(label: String, passed: bool) -> void:
	checks.append({"name": label, "passed": passed})
	print("PASS " if passed else "FAIL ", label)


func run() -> void:
	var host := HostFixture.new()
	root.add_child(host)
	var overlay := Control.new()
	root.add_child(overlay)
	var hud := HUD.new()
	overlay.add_child(hud)
	hud.setup(host)
	hud.heal_requested.connect(func(): healing += 1)
	hud.service_requested.connect(func(): services += 1)
	var state := {"active": true, "player_health": 120.0, "max_health": 120.0,
		"vehicle_name": "Aether X1 · 磁悬浮平衡车", "vehicle_health": 100.0,
		"enemy_count": 12, "kills": 4, "threat": 0.1, "phase": "巡游",
		"objective": "沿港口前进，清理附近奶龙", "medkits": 3,
		"heal_cooldown": 0.0, "hurt_amount": 0.0, "aim_hit": false}
	hud.update_state(state)
	hud.set_process(false)
	check("production HUD is visible in active gameplay", hud.visible)
	check("full-screen HUD ignores input", hud.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	check("full health cannot consume a medical kit", hud._heal_button.disabled)
	hud._request_heal()
	check("full-health callback emits no heal request", healing == 0)
	for dimensions: Vector2 in [Vector2(1440, 900), Vector2(1280, 720)]:
		overlay.size = dimensions
		await process_frame
		hud._layout()
		var card: Rect2 = hud._card_rect
		check("HUD fits viewport %s" % dimensions, Rect2(Vector2.ZERO, dimensions).encloses(card))
		check("HUD stays below activity text %s" % dimensions, card.position.y >= 287)
		check("HUD leaves lower navigation clear %s" % dimensions, card.end.y <= dimensions.y - 146)
		check("HUD leaves map and center aim clear %s" % dimensions, card.end.x < dimensions.x * 0.4)
		check("buttons remain inside card %s" % dimensions, card.encloses(hud._heal_button.get_rect()) and card.encloses(hud._service_button.get_rect()))
	state.player_health = 75.0
	state.hurt_amount = 45.0
	state.hurt_direction_label = "左后方"
	hud.update_state(state)
	check("damage pulse carries actual supplied direction", hud._damage_time > 0 and hud._hurt_label == "左后方")
	hud._process(0.3)
	var remaining: float = hud._damage_time
	hud.update_state(state)
	check("held damage values never restart the pulse", is_equal_approx(hud._damage_time, remaining))
	hud._request_heal()
	check("eligible heal emits one request", healing == 1)
	state.heal_cooldown = 8.4
	hud.update_state(state)
	hud._request_heal()
	check("cooldown blocks requests and displays time", healing == 1 and hud._heal_button.disabled and "8.4" in hud._heal_button.text)
	state.heal_cooldown = 0.0
	state.medkits = 0
	hud.update_state(state)
	hud._request_heal()
	check("empty inventory blocks heal requests", healing == 1 and hud._heal_button.disabled)
	state.medkits = 3
	state.player_health = 25.0
	hud.update_state(state)
	check("entering low health triggers one bounded pulse", hud._low_entry_time > 0)
	hud._process(2.0)
	hud.update_state(state)
	check("remaining at low health does not flash continuously", is_zero_approx(hud._low_entry_time) and is_zero_approx(hud._damage_time))
	for panel: Control in [host.modal, host.map_panel]:
		panel.visible = true
		hud._process(0.016)
		hud._request_heal()
		hud._request_service()
		check("visible panel hides and disables combat overlay", not hud.visible and hud._heal_button.disabled and hud._service_button.disabled)
		check("panel cannot receive behind-panel HUD actions", healing == 1 and services == 0)
		panel.visible = false
		hud._process(0.016)
	host.paused = true
	hud._process(0.016)
	hud._request_service()
	check("host pause guards action callbacks", not hud.visible and services == 0)
	host.paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud._process(0.016)
	if DisplayServer.get_name() != "headless":
		check("captured aim pointer cannot hit HUD buttons", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and hud._heal_button.mouse_filter == Control.MOUSE_FILTER_IGNORE and hud._service_button.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud._process(0.016)
	check("released pointer can click real HUD buttons", hud._heal_button.mouse_filter == Control.MOUSE_FILTER_STOP and hud._service_button.mouse_filter == Control.MOUSE_FILTER_STOP)
	hud._request_service()
	check("unblocked service emits a request only", services == 1)
	state.active = false
	hud.update_state(state)
	hud._request_service()
	check("inactive survival HUD cannot issue requests", not hud.visible and services == 1)
	state.active = true
	state.player_health = 120.0
	state.vehicle_health = -50
	state.enemy_count = -1
	state.medkits = -4
	hud.update_state(state)
	check("UI clamps invalid display values", hud._state.vehicle_health == 0 and hud._state.enemy_count == 0 and hud._state.medkits == 0)
	check("new run clears previous attack pulses", hud._damage_time == 0 and hud._low_entry_time == 0)
	if "--visual" in OS.get_cmdline_user_args():
		root.title = "Harbourlife Survival HUD Verification"
		root.content_scale_size = Vector2i.ZERO
		for dimensions: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 720)]:
			root.size = dimensions
			overlay.size = Vector2(dimensions)
			state.player_health = 75.0 if dimensions.y == 900 else 25.0
			state.vehicle_health = 84.0
			state.vehicle_name = "Harbour Bastion · 城市突围坦克"
			state.medkits = 3
			state.enemy_count = 12
			state.threat = 0.1 if dimensions.y == 900 else 0.9
			state.phase = "巡游" if dimensions.y == 900 else "夜间威胁"
			hud.update_state(state)
			hud._process(1.0)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var folder := ProjectSettings.globalize_path("res://../reports/survival-hud")
			DirAccess.make_dir_recursive_absolute(folder)
			var saved: int = image.save_png(folder + "/hud-%dx%d.png" % [dimensions.x, dimensions.y])
			check("native production HUD screenshot %s" % dimensions, saved == OK and not image.is_empty())
	var passed := checks.all(func(row): return row.passed)
	var result := {"passed": passed, "count": checks.size(), "checks": checks, "display": DisplayServer.get_name(), "captured_pointer_tested": DisplayServer.get_name() != "headless", "scope": "isolated production survival HUD; actual city integration is separate"}
	var path := ProjectSettings.globalize_path("res://../reports/survival-hud/" + ("native-checks.json" if DisplayServer.get_name() != "headless" else "checks.json"))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	print("SURVIVAL_HUD_QA ", JSON.stringify(result))
	overlay.free()
	host.free()
	quit(0 if passed else 1)
