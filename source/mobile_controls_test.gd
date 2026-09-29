extends SceneTree
## No city, saves, network, physics bodies or player profile are loaded.
## Run: tools/runtime/godot --headless --audio-driver Dummy --path game --script ../source/mobile_controls_test.gd
const Mobile = preload("res://scripts/mobile_controls.gd")
var checks: Array[Dictionary] = []
var host: FixtureHost
var controls: Control
var flow_failures: Array[String] = []

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
	var settings := {"sensitivity": 0.003, "invert": false, "mobile_floating_stick": false}
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
	if not passed: print("MOBILE_CONTROLS FAIL ", title)

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

func flow_step(passed: bool, detail: String) -> void:
	if not passed: flow_failures.append(detail)

func finish_flow() -> bool:
	for detail in flow_failures: print("MOBILE_CONTROLS FLOW FAIL ", detail)
	return flow_failures.is_empty()

## One complete on-foot flow: move, aim while firing, lock a run, then stop it.
func firing_movement_flow() -> bool:
	flow_failures.clear()
	controls.release_all()
	host.current_vehicle = null
	host.resume()
	host.settings.merge({"mobile_floating_stick": true, "mobile_left_fire": true, "mobile_run_lock": true, "mobile_look_sensitivity": 1.3, "mobile_fire_sensitivity": 0.6}, true)
	controls._process(0)
	var origin := Vector2(285, 560)
	flow_step(not touch(40, origin) and touch(40, origin, true, true), "floating stick waits for GUI, then starts at the finger")
	flow_step(no_actions(), "floating touch starts neutral away from its old fixed center")
	drag(40, origin + Vector2(0, -55), Vector2(0, -55))
	flow_step(Input.get_action_strength("forward") > 0.4, "floating displacement starts proportional movement")
	var fire_at := button_center("fire")
	var fired: Array[int] = []
	var on_shot := func(): fired.append(1)
	controls.weapon_fired.connect(on_shot)
	var shots_before := host.survival.shots
	var attempts_before := host.survival.attempts
	host.survival.cooldown = 0
	touch(41, fire_at)
	var yaw_before := host.yaw
	var pitch_before := host.pitch
	drag(41, fire_at + Vector2(-48, -26), Vector2(-48, -26))
	var expected_fire := 0.003 * 0.6
	flow_step(is_equal_approx(host.yaw - yaw_before, 48 * expected_fire) and is_equal_approx(host.pitch - pitch_before, 26 * expected_fire), "right fire drag changes camera yaw and pitch using firing sensitivity")
	controls._process(0.016)
	controls._process(0.016)
	host.survival.cooldown = 0
	controls._process(0.016)
	flow_step(host.survival.shots == shots_before + 2 and host.survival.attempts == attempts_before + 3 and fired.size() == 2, "held drag continues requesting fire, cooldown suppresses duplicate shots and haptics")
	flow_step(Input.is_action_pressed("forward") and Input.is_action_pressed("fire"), "movement and firing remain held during camera drag")
	var look_at := Vector2(850, 290)
	touch(42, look_at, true, true)
	yaw_before = host.yaw
	drag(42, look_at + Vector2(50, 0), Vector2(50, 0))
	flow_step(is_equal_approx(host.yaw, yaw_before), "second camera finger cannot steal right-fire aim")
	touch(42, look_at, false)
	touch(43, button_center("fire_left"))
	touch(41, fire_at, false)
	flow_step(Input.is_action_pressed("fire"), "left fire keeps the weapon held when right fire lifts")
	touch(42, look_at, true, true)
	yaw_before = host.yaw
	drag(42, look_at + Vector2(30, 0), Vector2(30, 0))
	flow_step(is_equal_approx(yaw_before - host.yaw, 30 * expected_fire), "left fire allows an independent right-side aim finger")
	touch(43, button_center("fire_left"), false)
	yaw_before = host.yaw
	drag(42, look_at + Vector2(60, 0), Vector2(30, 0))
	flow_step(not Input.is_action_pressed("fire") and is_equal_approx(yaw_before - host.yaw, 30 * 0.003 * 1.3), "releasing fire restores ordinary look sensitivity")
	touch(42, look_at, false)
	var far_forward := origin + Vector2(0, -150)
	drag(40, far_forward, far_forward - origin)
	controls._process(0.3)
	touch(40, far_forward, false)
	flow_step(Input.is_action_pressed("forward") and Input.is_action_pressed("sprint"), "pushing beyond the forward ring then releasing locks a run")
	touch(44, origin, true, true)
	flow_step(no_actions(), "a fresh floating-stick touch cancels the run and starts neutral")
	drag(44, far_forward, far_forward - origin)
	controls._process(0.3)
	touch(44, far_forward, false, false, true)
	flow_step(no_actions(), "OS cancellation never commits a run lock")
	host.settings.mobile_left_fire = false
	host.settings.mobile_run_lock = false
	controls._process(0)
	flow_step(not touch(45, button_center("fire_left"), true, true), "disabled left fire no longer captures touches")
	touch(46, origin, true, true)
	drag(46, far_forward, far_forward - origin)
	controls._process(0.3)
	touch(46, far_forward, false)
	flow_step(no_actions(), "run-lock setting prevents a sustained run after release")
	controls.weapon_fired.disconnect(on_shot)
	controls.release_all()
	return finish_flow()

## One interruption/vehicle journey: menu, background, two drive modes, get out.
func interruption_vehicle_flow() -> bool:
	flow_failures.clear()
	host.settings.merge({"mobile_left_fire": true, "mobile_run_lock": true, "mobile_floating_stick": true, "mobile_drive_mode": "joystick", "mobile_vehicle_sensitivity": 1.8}, true)
	controls._process(0)
	var origin := Vector2(250, 550)
	var ahead := origin + Vector2(0, -150)
	touch(50, origin, true, true)
	drag(50, ahead, ahead - origin)
	controls._process(0.3)
	touch(50, ahead, false)
	touch(51, button_center("fire"))
	touch(52, button_center("pause"))
	touch(52, button_center("pause"), false)
	flow_step(host.paused and no_actions(), "pause clears held fire and latched run")
	host.resume()
	controls._process(0)
	flow_step(not drag(51, Vector2(900, 350), Vector2(80, 0)) and no_actions(), "menu return cannot revive an old finger")
	touch(53, button_center("fire_left"))
	touch(54, origin, true, true)
	drag(54, ahead, ahead - origin)
	controls._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	flow_step(no_actions(), "backgrounding releases both movement and left fire")
	controls._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	controls._process(0)
	flow_step(not drag(54, ahead, Vector2(0, -30)) and no_actions(), "foreground return requires fresh touches")
	touch(55, button_center("boost"))
	var car := VehicleFixture.new()
	car.kind = "car"
	host.add_child(car)
	host.current_vehicle = car
	controls._process(0)
	flow_step(no_actions(), "entering a car clears foot run input")
	touch(56, origin, true, true)
	drag(56, origin + Vector2(45, -60), Vector2(45, -60))
	flow_step(Input.is_action_pressed("right") and Input.is_action_pressed("forward"), "vehicle joystick steers and accelerates together")
	host.settings.mobile_drive_mode = "buttons"
	controls._process(0)
	flow_step(no_actions() and not touch(57, origin, true, true), "drive-mode switch releases joystick and its old touch area")
	touch(58, button_center("steer_left"))
	touch(59, button_center("throttle"))
	flow_step(Input.is_action_pressed("left") and Input.is_action_pressed("forward"), "button mode supports simultaneous left turn and throttle")
	touch(58, button_center("steer_left"), false)
	touch(59, button_center("throttle"), false)
	touch(60, button_center("steer_right"))
	touch(61, button_center("reverse"))
	flow_step(Input.is_action_pressed("right") and Input.is_action_pressed("back") and not Input.is_action_pressed("brake"), "button mode exposes right turn and independent reverse")
	touch(61, button_center("reverse"), false)
	touch(62, button_center("brake"))
	flow_step(Input.is_action_pressed("brake") and not Input.is_action_pressed("back"), "braking does not simultaneously request reverse")
	var replacement := VehicleFixture.new()
	replacement.kind = "car"
	host.add_child(replacement)
	host.current_vehicle = replacement
	controls._process(0)
	flow_step(no_actions(), "switching even between two cars clears held driving controls")
	replacement.kind = "tank"
	controls._process(0)
	touch(63, button_center("fire"))
	var yaw_before := host.yaw
	drag(63, button_center("fire") + Vector2(-40, 0), Vector2(-40, 0))
	flow_step(is_equal_approx(host.yaw - yaw_before, 40 * 0.003 * 1.8), "tank fire drag uses vehicle camera sensitivity")
	for fixture in [{"size": Vector2(1560, 720), "safe": Rect2(50, 0, 1460, 694)}, {"size": Vector2(1280, 960), "safe": Rect2(0, 24, 1280, 908)}]:
		controls.release_all()
		controls.layout_for(fixture.size, fixture.safe)
		var rects: Array[Rect2] = controls.reserved_rects()
		var fits := true
		for a in rects.size():
			fits = fits and fixture.safe.encloses(rects[a])
			for b in range(a + 1, rects.size()): fits = fits and not rects[a].intersects(rects[b])
		flow_step(fits, "vehicle buttons fit safe area at " + str(fixture.size))
	controls._process(0)
	touch(64, button_center("throttle"))
	touch(65, button_center("fire"))
	host.current_vehicle = null
	controls._process(0)
	flow_step(no_actions(), "getting out clears all vehicle controls")
	touch(66, button_center("fire"))
	host.map_panel.show()
	controls._process(0)
	flow_step(no_actions() and not controls.visible, "a map modal clears fire before the pause flag is set")
	host.resume()
	controls._process(0)
	car.queue_free()
	replacement.queue_free()
	controls.release_all()
	return finish_flow()

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
	check("player flow: fire-drag camera, continuous shots, floating movement and run lock", firing_movement_flow())
	check("player flow: menu/background/vehicle transitions never leave held inputs", interruption_vehicle_flow())
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
