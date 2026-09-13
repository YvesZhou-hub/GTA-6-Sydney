extends SceneTree
const Validation = preload("res://scripts/driving_validation.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var validation := Validation.new()
	root.add_child(validation)
	var report: Dictionary = await validation.run()
	var path := "res://../reports/road-handling.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): path = argument.trim_prefix("--report=")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write driving QA report: ", path)
		quit(2)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("DRIVING_QA_READY ", JSON.stringify({"checks":report.checks.size(), "failures":report.failures, "report":path}))
	quit(int(report.failures))
