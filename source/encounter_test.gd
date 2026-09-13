extends SceneTree
## Source entry uses the same flag-dispatched validator as the exported game.
const Main = preload("res://scripts/main.gd")
func _initialize(): call_deferred("run")
func run():
	if not "--encounter-qa" in OS.get_cmdline_user_args():
		push_error("Run with -- --encounter-qa; no player world is opened.")
		quit(2)
		return
	var game = Main.new()
	game.qa_running = true
	root.add_child(game)
	var dispatched := false
	for child in game.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/encounter_validation.gd": dispatched = true
	if not dispatched:
		push_error("Production main did not dispatch --encounter-qa; refusing an idle run.")
		quit(2)
