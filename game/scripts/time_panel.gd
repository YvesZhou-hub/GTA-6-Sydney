extends RefCounted
## A paused, pointer-owned time editor. Seeking changes the rendered world now.
static func build(game:Node3D):
	game.active_panel="time"
	game.clear_panel("悉尼的夏日", "默认 12 倍速 · 现实 2 小时 = 游戏 1 天\n日出约 06:02 · 日落约 20:00 · 白天约 14 小时")
	game.time_label=game.label("",30,Color("a2efe0"))
	game.modal_content.add_child(game.time_label)
	game.time_slider=HSlider.new()
	game.time_slider.name="TimeOfDay"
	game.time_slider.min_value=0
	game.time_slider.max_value=24
	game.time_slider.step=1.0/60.0
	game.time_slider.custom_minimum_size=Vector2(430,44)
	game.modal_content.add_child(game.time_slider)
	game.time_slider.value_changed.connect(func(value):
		game.city_clock.set_hour(value)
		refresh(game))
	game.modal_content.add_child(game.label("00:00                         12:00                         24:00",15))
	var grid:=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",8)
	game.modal_content.add_child(grid)
	for preset in [["sunrise","日出"],["noon","正午"],["golden","金色时刻"],["sunset","日落晚霞"],["night","夜游 22:00"]]:
		var button:=Button.new()
		button.name="Jump_"+preset[0]
		button.text=preset[1]
		button.custom_minimum_size=Vector2(206,40)
		button.pressed.connect(func():
			game.city_clock.jump(preset[0])
			refresh(game))
		grid.add_child(button)
	for offset in [-1.0,1.0]:
		var button:=Button.new()
		button.text="后退 1 小时" if offset<0 else "前进 1 小时"
		button.name="HourBack" if offset<0 else "HourForward"
		button.custom_minimum_size=Vector2(206,40)
		button.pressed.connect(func():
			game.city_clock.set_hour(game.city_clock.hour+offset)
			refresh(game))
		grid.add_child(button)
	game.time_running=CheckButton.new()
	game.time_running.name="CycleRunning"
	game.time_running.text="继续日夜循环（关闭可定格拍照）"
	game.time_running.toggled.connect(func(enabled):game.city_clock.running=enabled)
	game.modal_content.add_child(game.time_running)
	game.time_speed=OptionButton.new()
	game.time_speed.name="CycleSpeed"
	for speed in [1,6,12,24,60,120]:
		game.time_speed.add_item("%d 倍速%s"%[speed," · 默认，现实 2 小时一天" if speed==12 else ""],speed)
	game.time_speed.item_selected.connect(func(index):game.city_clock.set_speed(game.time_speed.get_item_id(index)))
	game.modal_content.add_child(game.time_speed)
	game.button("恢复夏日默认 · 16:00 / 12 倍速",func():
		game.city_clock.apply_state({})
		refresh(game))
	game.button("返回游戏  ·  T / Esc",game.close_panel)
	refresh(game)

static func refresh(game:Node3D):
	game.time_label.text=game.city_clock.display_time()+"  ·  悉尼夏季"
	game.time_slider.set_value_no_signal(game.city_clock.hour)
	game.time_running.set_pressed_no_signal(game.city_clock.running)
	var index:int=game.time_speed.get_item_index(int(game.city_clock.speed))
	game.time_speed.select(index)
