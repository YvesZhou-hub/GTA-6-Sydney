extends SceneTree
## Reuse the complete existing driving scenarios with production survival mode on.
class SurvivalDriving extends "res://scripts/driving_validation.gd":
	var survival_instances := 0
	func _spawn(kind: String, height: float = 0.76) -> RigidBody3D:
		var vehicle := super._spawn(kind,height)
		vehicle.survival_enabled = true
		survival_instances += 1
		return vehicle

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var validation := SurvivalDriving.new(); root.add_child(validation)
	var report: Dictionary = await validation.run()
	report["survival_enabled"] = true
	report["survival_instances"] = validation.survival_instances
	var file := FileAccess.open("res://../reports/survival-driving.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("SURVIVAL_DRIVING_COMPLETE ",report.count," passed=",report.passed," survival_instances=",validation.survival_instances)
	quit(0 if report.passed and validation.survival_instances>0 else 1)
