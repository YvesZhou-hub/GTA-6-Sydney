extends SceneTree
## Minimal real GUI fixture; never constructs the city or reads player saves.
## tools/runtime/godot --headless --path game --script ../source/mobile_ui_test.gd
const MobileUI = preload("res://scripts/mobile_ui.gd")
const MobileControls = preload("res://scripts/mobile_controls.gd")
const ThemeSource = preload("res://scripts/ui_theme.gd")
var checks: Array[Dictionary] = []

class ObservedUI extends MobileUI:
	var menu_node_visits := 0
	func _fit_menu(node: Node, content_width: float) -> void:
		menu_node_visits += 1
		super._fit_menu(node, content_width)

class PanelOwner extends Node:
	var panel := PanelContainer.new()
	func _ready() -> void: add_child(panel)

class SurvivalFixture extends Node:
	func hud_state() -> Dictionary:
		return {"player_health": 72, "max_health": 120, "vehicle_active": true, "vehicle_health": 48, "medkits": 3, "enemy_count": 4, "kills": 12}

class MinimapFixture extends Control:
	var cursor_released := false

class SafeFixture extends Node:
	var safe := Rect2(50, 0, 1460, 694)
	func safe_area_rect() -> Rect2: return safe

class Host extends Node:
	var active := true
	var paused := false
	var font: Font
	var player: Node
	var current_vehicle: Node
	var diagnostics_panel: Control
	var canvas := CanvasLayer.new()
	var hud := Control.new()
	var left_column := VBoxContainer.new()
	var mode_label := Label.new()
	var region_label := Label.new()
	var info := Label.new()
	var activity_panel := PanelContainer.new()
	var survival_hud := Control.new()
	var hint_panel := PanelContainer.new()
	var landmark_marker := Label.new()
	var fire_button := Button.new()
	var campaign := PanelOwner.new()
	var districts := PanelOwner.new()
	var minimap := MinimapFixture.new()
	var toast_panel := PanelContainer.new()
	var toast_label := Label.new()
	var speed_label := Label.new()
	var vehicle_panel := PanelContainer.new()
	var save_indicator := Label.new()
	var modal := PanelContainer.new()
	var modal_content := VBoxContainer.new()
	var map_panel := Control.new()
	var scroll := ScrollContainer.new()
	var survival := SurvivalFixture.new()
	var mobile_controls := SafeFixture.new()
	func _ready() -> void:
		add_child(canvas)
		add_child(survival)
		add_child(mobile_controls)
		canvas.add_child(hud)
		hud.theme = ThemeSource.build()
		hud.size = Vector2(1560, 720)
		hud.add_child(left_column)
		var top := PanelContainer.new()
		left_column.add_child(top)
		var column := VBoxContainer.new()
		top.add_child(column)
		for label in [mode_label, region_label, info]: column.add_child(label)
		mode_label.text = "HARBOURLIFE / 奶龙危机"
		region_label.text = "Sydney Airport · 悉尼机场"
		info.text = "$12000 · 耐力100% · 16:00"
		for item in [activity_panel, survival_hud, hint_panel, landmark_marker, fire_button, campaign, districts, minimap, toast_panel, vehicle_panel, save_indicator]: hud.add_child(item)
		minimap.custom_minimum_size = Vector2(260, 288)
		toast_panel.add_child(toast_label)
		toast_label.text = "这是用于检查长提示自动换行的内容，确保不会遮住操纵杆、开火按钮或顶部菜单。"
		vehicle_panel.add_child(speed_label)
		speed_label.text = "200 km/h · 120 m\n战斗机 48%\n3倍加速中"
		canvas.add_child(modal)
		modal.theme = hud.theme
		modal.theme_type_variation = "ModalPanel"
		modal.add_child(scroll)
		scroll.custom_minimum_size = Vector2(500, 760)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.add_child(modal_content)
		modal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var heading := Label.new()
		heading.text = "触屏设置与战地整备"
		heading.custom_minimum_size.x = 470
		modal_content.add_child(heading)
		var edit := LineEdit.new()
		edit.placeholder_text = "搜索"
		modal_content.add_child(edit)
		var slider := HSlider.new()
		modal_content.add_child(slider)
		for i in 15:
			var button := Button.new()
			button.text = "一条很长的整备和载具选项用于检查窄侧栏布局 %d" % i
			modal_content.add_child(button)
		canvas.add_child(map_panel)
		map_panel.hide()
		modal.hide()

func _initialize() -> void: call_deferred("run")
func check(title: String, passed: bool) -> void:
	checks.append({"name": title, "passed": passed})
	print("MOBILE_UI ", "PASS " if passed else "FAIL ", title)

func run() -> void:
	var host := Host.new()
	root.add_child(host)
	var ui := ObservedUI.new()
	host.add_child(ui)
	ui.setup(host, {"enabled":true})
	check("mobile profile selects touch UI and late processing", ui.enabled and ui.process_priority == 100 and ui.process_mode == Node.PROCESS_MODE_ALWAYS)
	var controls := MobileControls.new()
	host.canvas.add_child(controls)
	controls.setup(host)
	controls.set_process(false)
	controls.enabled = false
	for fixture in [{"size":Vector2i(1560, 720), "safe":Rect2(50, 0, 1460, 694)}, {"size":Vector2i(1280, 960), "safe":Rect2(0, 24, 1280, 908)}]:
		root.size = fixture.size
		root.content_scale_size = fixture.size
		host.hud.size = fixture.size
		host.mobile_controls.safe = fixture.safe
		controls.layout_for(fixture.size, fixture.safe)
		ui.apply_layout(fixture.safe)
		await process_frame
		await process_frame
		var rects: Dictionary = MobileUI.layout_rects(fixture.safe)
		var in_safe := true
		var no_overlap := true
		var names := ["status", "health", "minimap", "toast", "vehicle"]
		for name in names:
			in_safe = in_safe and fixture.safe.encloses(rects[name])
			for touch_rect in controls.reserved_rects(): no_overlap = no_overlap and not touch_rect.intersects(rects[name])
		for a in names.size():
			for b in range(a + 1, names.size()): no_overlap = no_overlap and not rects[names[a]].intersects(rects[names[b]])
		check("HUD and touch controls fit without overlap " + str(fixture.size), in_safe and no_overlap)
		check("actual compact status and health stay within their allocated areas " + str(fixture.size), rects.status.encloses(host.left_column.get_global_rect()) and rects.health.encloses(ui.health_panel.get_global_rect()))
		check("actual vehicle readout stays safe and toast fits the compact banner " + str(fixture.size), fixture.safe.encloses(host.vehicle_panel.get_global_rect()) and rects.toast.encloses(host.toast_panel.get_global_rect()) and host.toast_label.size.y >= host.toast_label.get_theme_font("font").get_height(16))
		check("native minimap resizes below desktop minimum " + str(fixture.size), host.minimap.size == Vector2(200, 220) and host.minimap.cursor_released)
		host.modal.show()
		ui.apply_layout(fixture.safe)
		await process_frame
		await process_frame
		check("single menu stays in safe area and scrolls at phone height " + str(fixture.size), fixture.safe.encloses(host.modal.get_global_rect()) and host.scroll.custom_minimum_size == Vector2.ZERO and host.scroll.get_v_scroll_bar().max_value > host.scroll.size.y)
		host.map_panel.show()
		ui.apply_layout(fixture.safe)
		await process_frame
		await process_frame
		check("map and 480px menu are side by side in safe area " + str(fixture.size), fixture.safe.encloses(host.modal.get_global_rect()) and fixture.safe.encloses(host.map_panel.get_global_rect()) and not host.modal.get_global_rect().intersects(host.map_panel.get_global_rect()) and host.modal.size.x == 480)
		var usable := true
		for node in host.modal_content.get_children():
			if node is Button: usable = usable and node.size.y >= 72 and node.size.x <= host.scroll.size.x
			elif node is LineEdit: usable = usable and node.size.y >= 64
			elif node is Slider: usable = usable and node.size.y >= 48
		check("menu controls keep physical touch target sizes " + str(fixture.size), usable)
		host.modal.hide()
		host.map_panel.hide()
	check("desktop-only cards and keyboard hints are hidden", not host.activity_panel.visible and not host.survival_hud.visible and not host.campaign.panel.visible and not host.districts.panel.visible and not host.hint_panel.visible and not host.fire_button.visible)
	check("compact health uses current player vehicle and threat values", ui.health_label.text == "生命 72/120 · 载具 48%" and ui.health_bar.value == 48 and ui.status_label.text == "药包 3 · 附近奶龙 4 · 击败 12")
	await process_frame
	await process_frame
	var theme_events: Array[int] = []
	var minimap_resizes: Array[int] = []
	host.info.theme_changed.connect(func(): theme_events.append(1))
	host.minimap.resized.connect(func(): minimap_resizes.append(1))
	var started := Time.get_ticks_usec()
	for i in 300: ui._process(0)
	var idle_us := Time.get_ticks_usec() - started
	await process_frame
	await process_frame
	check("steady HUD frames emit no repeated font or minimap resize notifications", theme_events.is_empty() and minimap_resizes.is_empty())
	host.modal.show()
	ui._process(0)
	await process_frame
	await process_frame
	var visits_before := ui.menu_node_visits
	started = Time.get_ticks_usec()
	for i in 300: ui._process(0)
	var menu_us := Time.get_ticks_usec() - started
	check("unchanged open menu does not walk its control tree each frame", ui.menu_node_visits == visits_before)
	print("MOBILE_UI_TIMING ", JSON.stringify({"iterations":300,"idle_us":idle_us,"open_menu_us":menu_us,"theme_events":theme_events.size(),"extra_menu_node_visits":ui.menu_node_visits-visits_before,"scope":"host CPU fixture only, not iPhone performance"}))
	var nested := VBoxContainer.new()
	host.modal_content.add_child(nested)
	var appended := Button.new()
	appended.text = "动态新增菜单项"
	nested.add_child(appended)
	ui._process(0)
	check("nested menu children get touch target size in the next UI update", appended.custom_minimum_size.y >= 72)
	nested.remove_child(appended)
	appended.queue_free()
	var replacement := Button.new()
	replacement.text = "同样数量的新菜单项"
	nested.add_child(replacement)
	ui._process(0)
	check("same-count menu replacement cannot reuse stale layout cache", replacement.custom_minimum_size.y >= 72)
	host.toast_label.add_theme_font_size_override("font_size", 22)
	ui._process(0)
	check("settings changes restore mobile text size without permanent stale style cache", host.toast_label.get_theme_font_size("font_size") == 16)
	var new_safe := Rect2(60, 20, 1160, 890)
	host.mobile_controls.safe = new_safe
	ui._process(0)
	check("safe-area changes reposition visible menus immediately", new_safe.encloses(host.modal.get_global_rect()))
	host.modal.hide()
	host.survival_hud.show()
	ui._process(0)
	check("late update suppresses a desktop card shown again by gameplay", not host.survival_hud.visible)
	host.paused = true
	ui._process(0)
	check("paused gameplay hides compact health", not ui.health_panel.visible)
	ui.enabled = false
	host.survival_hud.show()
	var before: Vector2 = host.minimap.size
	ui.apply_layout(Rect2(0, 0, 2000, 1200))
	ui._process(0)
	check("disabled desktop path does not mutate UI", host.survival_hud.visible and host.minimap.size == before)
	var passed := checks.all(func(item): return item.passed)
	print("MOBILE_UI_RESULT ", JSON.stringify({"passed": passed, "checks":checks.size(), "scope":"real isolated Godot containers and controls, no city or player saves; physical-device visual fit not measured"}))
	host.queue_free()
	await process_frame
	quit(0 if passed else 1)
