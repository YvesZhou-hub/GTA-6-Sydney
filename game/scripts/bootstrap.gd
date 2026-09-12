extends Control
## Present a real loading screen before constructing the native city scene.
func _ready() -> void:
	preload("res://scripts/ui_fonts.gd").install_defaults()
	theme=preload("res://scripts/ui_fonts.gd").make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background:=ColorRect.new()
	background.color=Color("102b35")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center:=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",24)
	center.add_child(column)
	var title:=Label.new()
	title.text="HARBOURLIFE"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",52)
	title.add_theme_color_override("font_color",Color("e2d3b5"))
	column.add_child(title)
	var caption:=Label.new()
	caption.text="正在加载悉尼海港\n准备建筑、道路和可破坏场景，请稍候。"
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",21)
	column.add_child(caption)
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless": RenderingServer.force_draw(false)
	var started:=Time.get_ticks_msec()
	var game:=preload("res://main.tscn").instantiate()
	get_parent().add_child(game)
	get_tree().current_scene=game
	print("CITY_STARTUP_MS ",Time.get_ticks_msec()-started)
	queue_free()
