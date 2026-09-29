extends RefCounted
## Touch preferences use main's immediate apply/save route and mobile storage.
const Settings = preload("res://scripts/game_settings.gd")

static func build(game: Node) -> void:
	game.active_panel = "mobile_settings"
	game.clear_panel("触屏操作", "修改立即生效并保存，仅用于手机版和手机预览。")
	game.section("瞄准灵敏度")
	game.note("100% 为标准速度。按住开火拖动时使用开火灵敏度。")
	for entry in [["平时转镜头", "mobile_look_sensitivity"], ["开火转镜头", "mobile_fire_sensitivity"], ["载具转镜头", "mobile_vehicle_sensitivity"], ["陀螺仪瞄准", "mobile_gyro_sensitivity"]]:
		var key: String = entry[1]
		game._settings_slider(entry[0], Settings.MOBILE_SENSITIVITY_MIN, Settings.MOBILE_SENSITIVITY_MAX, 0.1, float(game.settings[key]),
			func(value): return "%d%%" % roundi(value * 100), func(value): _change(game, key, value))
	game.section("移动与开火")
	_toggle(game, "左手开火键", "mobile_left_fire")
	_toggle(game, "浮动摇杆", "mobile_floating_stick")
	game.note("浮动摇杆跟随左下区域的落指位置；关闭后固定在原位。")
	_toggle(game, "锁定奔跑", "mobile_run_lock")
	game.note("摇杆推过外圈后松手保持奔跑，再次触碰摇杆即可解除。")
	game.section("载具操作")
	game._settings_option("驾驶方式", Settings.MOBILE_DRIVE_MODES.map(func(row): return row[1]),
		Settings.MOBILE_DRIVE_MODES.map(func(row): return row[0]).find(game.settings.mobile_drive_mode),
		func(index): _change(game, "mobile_drive_mode", Settings.MOBILE_DRIVE_MODES[index][0]))
	game.note("摇杆驾驶：左侧摇杆控制方向与前进、后退。\n按键驾驶：分别使用左右转向、油门、倒车和刹车键。下车键位置固定。")
	game.section("陀螺仪与反馈")
	game._settings_option("陀螺仪", Settings.MOBILE_GYRO_MODES.map(func(row): return row[1]),
		Settings.MOBILE_GYRO_MODES.map(func(row): return row[0]).find(game.settings.mobile_gyro_mode),
		func(index): _change(game, "mobile_gyro_mode", Settings.MOBILE_GYRO_MODES[index][0]))
	game.note("倾斜手机微调瞄准，仅在支持陀螺仪的设备上生效。")
	_toggle(game, "震动反馈", "mobile_haptics")
	game.note("开火、受击和命中时轻震，仅在设备支持时生效。")
	game.button("返回设置", game.settings_menu)

static func _toggle(game: Node, title: String, key: String) -> void:
	game._settings_toggle(title, bool(game.settings[key]), func(value): _change(game, key, value))

static func _change(game: Node, key: String, value: Variant) -> void:
	game.settings[key] = value
	game._settings_changed()
