extends SceneTree
func _initialize():call_deferred("run")
func run():root.add_child(load("res://scripts/mobility_validation.gd").new())
