extends SceneTree
## Legacy editor/debug command wrapper; exported applications use --experience-qa.
const Validation=preload("res://scripts/experience_validation.gd")
func _initialize():call_deferred("run")
func run():
	var game=load("res://scripts/main.gd").new()
	game.qa_running=true
	root.add_child(game)
	if not game.get_children().any(func(child):return child.get_script()==Validation):
		game.add_child(Validation.new())
