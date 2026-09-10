extends SceneTree
## Manual input review against either the source project or the exported PCK.
## All controls are normal production UI. Saves use a separate retained QA ID.
func _initialize():call_deferred("run")
func run():
	var game=load("res://scripts/main.gd").new()
	game.qa_running=true
	root.add_child(game)
	game.new_world("sandbox","Interactive release QA",false)
	game.world_id="qa_interactive_"+str(Time.get_ticks_usec())
	print("INTERACTIVE_QA_READY world=",game.world_id," components=",game.world.structures.size())
