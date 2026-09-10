extends SceneTree
## Legacy editor/debug command wrapper; exported applications use --visual-qa.
const Validation=preload("res://scripts/landmark_validation.gd")
func _initialize():call_deferred("run")
func run():
	var started_usec:=Time.get_ticks_usec()
	root.size=Vector2i(1440,900)
	var game=load("res://main.tscn").instantiate()
	game.qa_running=true
	root.add_child(game)
	if not game.get_children().any(func(child):return child.get_script()==Validation):
		var validation=Validation.new()
		validation.started_usec=started_usec
		validation.set_meta("wrapper_startup",true)
		game.add_child(validation)
