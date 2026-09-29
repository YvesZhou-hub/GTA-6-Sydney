extends SceneTree
## Touch map geometry and GUI actions use the production map, without a world/save.
var failures := 0
func _initialize(): call_deferred("run")
func check(title: String, okay: bool):
	print("PASS " if okay else "FAIL ", title)
	if not okay: failures += 1
func run():
	var map = preload("res://scripts/harbor_map.gd").new()
	map.touch_mode = true
	map.size = Vector2(700, 656)
	root.add_child(map)
	map.refresh()
	check("touch map buttons stay inside panel", Rect2(Vector2.ZERO,map.size).encloses(map._close_button.get_rect()) and Rect2(Vector2.ZERO,map.size).encloses(map._zoom_in.get_rect()))
	check("close and clear meet touch target height", map._close_button.size.y >= 64 and map._clear_button.size.y >= 64)
	check("touch header is outside interactive map", map.map_rect().position.y >= map._close_button.get_rect().end.y)
	var center: Vector2 = map.unproject_point(map.view_center())
	var zoom: float = map.pixels_per_metre
	map._zoom_in.pressed.emit()
	check("plus zooms without shifting center", map.pixels_per_metre > zoom and map.unproject_point(map.view_center()).distance_to(center)<0.01)
	map._zoom_out.pressed.emit()
	check("minus restores zoom", is_equal_approx(zoom,map.pixels_per_metre))
	var press := InputEventMouseButton.new()
	press.device = -1
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = map.map_rect().get_center()
	map._gui_input(press)
	press.pressed = false
	map._gui_input(press)
	check("emulated touch click sets destination", not map.target_key.is_empty())
	map._clear_button.pressed.emit()
	check("clear button clears navigation", map.target_key.is_empty())
	map.queue_free()
	await process_frame
	quit(1 if failures else 0)
