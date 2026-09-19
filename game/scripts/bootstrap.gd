extends Control
## Present a real loading screen before constructing the native city scene.
const Loading = preload("res://scripts/loading_progress.gd")
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
	var progress:=ProgressView.new()
	progress.custom_minimum_size=Vector2(520,48)
	column.add_child(progress)
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless": RenderingServer.force_draw(true)
	var started:=Time.get_ticks_msec()
	# The build reports between stages so the window keeps redrawing and handling events.
	Loading.listen(progress.show_stage)
	var game:=preload("res://main.tscn").instantiate()
	get_parent().add_child(game)
	Loading.stop()
	get_tree().current_scene=game
	print("CITY_STARTUP_MS ",Time.get_ticks_msec()-started)
	queue_free()


## Loading reports arrive while no frame is running, so Label and ProgressBar
## redraws (queued for the next frame) would never reach the screen. This view
## sends its canvas commands straight to the RenderingServer instead.
class ProgressView extends Control:
	var fraction:=0.0
	var title:="准备开始"

	func show_stage(value:float,stage:String) -> void:
		fraction=value
		title=stage
		RenderingServer.canvas_item_clear(get_canvas_item())
		_paint(get_canvas_item())

	func _draw() -> void:
		_paint(get_canvas_item())

	func _paint(item:RID) -> void:
		var track:=Rect2(0,0,size.x,8)
		RenderingServer.canvas_item_add_rect(item,track,Color("1d4450"))
		RenderingServer.canvas_item_add_rect(item,Rect2(0,0,size.x*fraction,8),Color("e2d3b5"))
		var font:=get_theme_font("font","Label")
		var text:="%s  ·  %d%%"%[title,roundi(fraction*100.0)]
		font.draw_string(item,Vector2(0,40),text,HORIZONTAL_ALIGNMENT_CENTER,size.x,16,Color("9fbfbd"))
