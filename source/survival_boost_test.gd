extends "res://../source/vehicle_boost_test.gd"
## Run every existing boost phase with real survival mode enabled. Base fixture
## setup remains unchanged, so comparisons retain identical initial conditions.
func fixture(kind: String) -> void:
	await super.fixture(kind)
	body.survival_enabled = true
	check(kind+" boost fixture actually enables survival",body.survival_enabled and not body.is_damage_immune())

func run() -> void:
	await super.run()
	# SceneTree.quit is deferred until the next iteration: retain a separate copy
	# of the completed inherited report before process teardown.
	var file := FileAccess.open("res://../reports/vehicle-boost.json",FileAccess.READ)
	if file:
		var report: Dictionary = JSON.parse_string(file.get_as_text()); file.close()
		report["survival_enabled"] = true
		var output := FileAccess.open("res://../reports/survival-boost.json",FileAccess.WRITE)
		output.store_string(JSON.stringify(report,"\t")); output.close()
