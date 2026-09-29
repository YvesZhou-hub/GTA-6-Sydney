extends SceneTree
## No city, saves, network, physics bodies or player profile are loaded.
## Run: tools/runtime/godot --headless --path game --script ../source/mobile_controls_test.gd
const Mobile = preload("res://scripts/mobile_controls.gd")
var checks: Array[Dictionary] = []
var host: FixtureHost
var controls: Control

class WeaponFixture extends Node:
	var attempts := 0
	var shots := 0
	var cooldown := 0.0
	func fire_current() -> bool:
		attempts += 1
		if cooldown > 0: return false
		shots += 1
		cooldown = 1.0
		return true
	func fire_blaster() -> bool: return fire_current()

class VehicleFixture extends Node:
	var kind := "tank"

class FixtureHost extends Node:
	var active := true
	var paused := false
	var yaw := 0.0
	var pitch := 0.0
	var font: Font
	var settings := {"sensitivity": 0.003, "invert": false}
	var current_vehicle: Node
	var modal := Control.new()
	var map_panel := Control.new()
	var diagnostics_panel := Control.new()
	var weapons := WeaponFixture.new()
	var survival := WeaponFixture.new()
	var taps: Array[String] = []
	func _ready() -> void:
		for node in [modal, map_panel, diagnostics_panel, weapons, survival]: add_child(node)
		for panel in [modal, map_panel, diagnostics_panel]: panel.hide()
	func can_fire_weapon() -> bool: return current_vehicle != null and current_vehicle.kind == "tank"
	func pause_menu() -> void:
		taps.append("pause")
		paused = true
		modal.show()
	func _input(event: InputEvent) -> void:
		if event is InputEventAction and event.is_action_pressed("map"):
			taps.append("map")
			paused = true
			map_panel.show()
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventAction and event.pressed: taps.append(event.action)
	func resume() -> void:
		paused = false
		modal.hide()
		map_panel.hide()
		diagnostics_panel.hide()

func _initialize() -> void: call_deferred("run")

func check(title: String, passed: bool) -> void:
	checks.append({"name": title, "passed": passed})
	print("MOBILE_CONTROLS ", "PASS " if passed else "FAIL ", title)

func touch(index: int, at: Vector2, pressed := true, look := false, canceled := false) -> bool:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	return controls.handle_touch(event, look)

func drag(index: int, at: Vector2, relative: Vector2) -> bool:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = relative
	return controls.handle_touch(event)

func button_center(id: String) -> Vector2: return controls._buttons[id].rect.get_center()

func no_actions() -> bool:
	for action in Mobile.MOVE_ACTIONS:
		if Input.is_action_pressed(action): return false
	for actions in Mobile.HOLD_ACTIONS.values():
		for action in actions:
			if Input.is_action_pressed(action): return false
	return true

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	for action in ["left", "right", "forward", "back", "fire", "sprint", "boost", "jump", "brake", "rise", "combat_raise", "fall", "combat_lower", "drift", "interact", "vehicles", "map", "heal", "survival_services"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	host = FixtureHost.new()
	root.add_child(host)
	var canvas := CanvasLayer.new()
	host.add_child(canvas)
	controls = Mobile.new()
	canvas.add_child(controls)
	controls.setup(host)
	check("desktop does not activate touch controls without opt-in", controls.enabled == Mobile.available())
	controls.enabled = true
	controls._process(0.0)
	var stick: Vector2 = controls._stick_center
	var radius: float = controls._stick_radius
	touch(1, stick)
	check("stick dead zone produces no unintended movement", no_actions())
	drag(1, stick + Vector2(0, -radius * 0.55), Vector2(0, -radius * 0.55))
	var strength := Input.get_action_strength("forward")
	check("analog stick preserves partial forward strength", strength > 0.4 and strength < 0.55 and not Input.is_action_pressed("back"))
	var look_at := Vector2(850, 290)
	check("free look waits for GUI refusal", not touch(2, look_at) and touch(2, look_at, true, true))
	drag(2, look_at + Vector2(40, 25), Vector2(40, 25))
	check("two fingers move and turn simultaneously", host.yaw < 0 and host.pitch < 0 and Input.is_action_pressed("forward"))
	touch(3, button_center("fire"))
	controls._process(0)
	controls._process(0)
	check("third finger holds foot fire through production cooldown method", Input.is_action_pressed("fire") and host.survival.attempts == 2 and host.survival.shots == 1 and Input.is_action_pressed("forward"))
	host.survival.cooldown = 0
	controls._process(0)
	check("held fire resumes after production cooldown expires", host.survival.shots == 2)
	touch(4, button_center("fire"))
	touch(3, button_center("fire"), false)
	check("lifting one of two fire fingers does not release the other", Input.is_action_pressed("fire"))
	touch(4, button_center("fire"), false)
	check("last fire finger releases only its own action", not Input.is_action_pressed("fire") and Input.is_action_pressed("forward"))
	var old_yaw: float = host.yaw
	touch(5, stick)
	drag(5, Vector2(1000, 350), Vector2(800, -50))
	check("extra stick finger cannot steal movement or become camera", is_equal_approx(Input.get_action_strength("forward"), strength) and is_equal_approx(host.yaw, old_yaw))
	touch(1, stick, false)
	check("releasing movement leaves camera ownership intact", not Input.is_action_pressed("forward") and controls._is_held("look"))
	controls.release_all()
	touch(6, button_center("boost"))
	touch(7, button_center("brake"))
	check("shared keyboard pairs work for run boost and jump brake", Input.is_action_pressed("sprint") and Input.is_action_pressed("boost") and Input.is_action_pressed("jump") and Input.is_action_pressed("brake"))
	touch(8, button_center("pause"))
	check("menu opens on release so the same finger cannot press through", not host.paused)
	touch(8, button_center("pause"), false)
	check("pause releases every held action and hides overlay immediately", host.paused and host.taps == ["pause"] and no_actions() and not controls.visible)
	check("paused overlay rejects touches", not touch(9, button_center("fire")))
	host.resume()
	controls._process(0)
	check("resuming requires fresh fingers and cannot restore stale holds", no_actions() and not drag(6, button_center("boost"), Vector2(30, 0)))
	for action in ["interact", "vehicles", "heal", "survival_services"]:
		touch(10, button_center(action))
		touch(10, button_center(action), false)
	check("touch shortcuts reuse production action routing once each", host.taps == ["pause", "interact", "vehicles", "heal", "survival_services"])
	touch(11, button_center("map"))
	touch(11, button_center("map"), false)
	check("map uses early input route and blocks gameplay", host.map_panel.visible and not controls.visible and no_actions() and host.taps.back() == "map")
	host.resume()
	controls._process(0)
	touch(12, button_center("heal"))
	touch(12, button_center("heal"), false, false, true)
	check("system-cancelled touch does not activate a tap", host.taps.back() == "map")
	touch(13, button_center("boost"))
	controls._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check("background focus loss releases all gameplay input", no_actions() and not controls.visible and not controls.is_gameplay_enabled())
	controls._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	controls._process(0)
	var tank := VehicleFixture.new()
	host.add_child(tank)
	host.current_vehicle = tank
	controls._process(0)
	touch(14, button_center("rise"))
	touch(15, button_center("fall"))
	touch(16, button_center("fire"))
	controls._process(0)
	controls._process(0)
	check("tank elevation uses paired flight and combat controls", Input.is_action_pressed("rise") and Input.is_action_pressed("combat_raise") and Input.is_action_pressed("fall") and Input.is_action_pressed("combat_lower"))
	check("tank held fire delegates eligibility and cooldown to weapon system", host.weapons.attempts == 2 and host.weapons.shots == 1)
	host.modal.show()
	controls._process(0)
	check("a modal blocks and releases controls even before paused flag updates", no_actions() and not controls.visible)
	host.resume()
	tank.kind = "car"
	controls._process(0)
	check("car exposes drift and hides flight controls", controls._button_visible("drift") and not controls._button_visible("rise") and not controls._button_visible("fall"))
	touch(17, button_center("drift"))
	check("car drift holds production action", Input.is_action_pressed("drift"))
	controls.release_all()
	for fixture in [
		{"size": Vector2(1280, 720), "safe": Rect2(0, 0, 1280, 720)},
		{"size": Vector2(1560, 720), "safe": Rect2(50, 0, 1460, 694)},
		{"size": Vector2(1280, 960), "safe": Rect2(0, 24, 1280, 908)},
		{"size": Vector2(1440, 900), "safe": Rect2(0, 0, 1440, 880)},
	]:
		controls.layout_for(fixture.size, fixture.safe)
		var contained := true
		var rects: Array[Rect2] = controls.reserved_rects()
		for rect in rects: contained = contained and fixture.safe.encloses(rect)
		var separate := true
		for a in rects.size():
			for b in range(a + 1, rects.size()): separate = separate and not rects[a].intersects(rects[b])
		check("controls fit safe area without overlapping at " + str(fixture.size), contained and separate)
	controls._process(0)
	host.current_vehicle = null
	controls._process(0)
	var gui_button := Button.new()
	gui_button.position = Vector2(770, 250)
	gui_button.size = Vector2(180, 100)
	gui_button.text = "UI test"
	canvas.add_child(gui_button)
	var gui_clicks: Array[int] = []
	gui_button.pressed.connect(func(): gui_clicks.append(1))
	await process_frame
	var down := InputEventScreenTouch.new()
	down.index = 30
	down.position = Vector2(820, 290)
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	check("native GUI touch gets first refusal and cannot own look", not controls._is_held("look"))
	var up := InputEventScreenTouch.new()
	up.index = 30
	up.position = down.position
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	check("existing GUI buttons remain tappable", gui_clicks.size() == 1)
	touch(0, button_center("boost"))
	check("first OS touch index zero owns paired hold actions", Input.is_action_pressed("boost") and Input.is_action_pressed("sprint"))
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	await process_frame
	check("viewport resize immediately releases all fingers and held actions", no_actions() and controls._touches.is_empty())
	var passed := checks.all(func(item): return item.passed)
	print("MOBILE_CONTROLS_RESULT ", JSON.stringify({"passed": passed, "checks": checks.size(), "scope": "isolated overlay, fake host and production API contracts; no world or player saves; physical iOS multitouch not tested"}))
	controls.release_all()
	host.queue_free()
	await process_frame
	quit(0 if passed else 1)
