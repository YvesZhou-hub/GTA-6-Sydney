extends SceneTree
## Independent damage/contact contracts; no save files or production world required.
const Durability = preload("res://scripts/vehicle_durability.gd")
var checks: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(label: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name": label, "passed": passed, "detail": detail})
	print("PASS " if passed else "FAIL ", label)

func run() -> void:
	for kind in ["car", "motorcycle", "speedboat", "yacht", "glider", "paraglider", "airliner", "helicopter"]:
		for speed in [0.0, 2.0, 3.5, 5.0, 6.0]:
			check("%s minor contact %.1f m/s stays intact" % [kind, speed], Durability.impact_damage(kind, speed) == 0.0)
		var damage: float = Durability.impact_damage(kind, 20.0)
		var impacts_to_break := ceili(100.0 / damage)
		check("%s survives at least 20 separate moderate hits" % kind, impacts_to_break >= 20 and impacts_to_break <= 25, impacts_to_break)
		check("%s hard hit still damages but cannot wreck in one hit" % kind, Durability.impact_damage(kind, 80.0) >= 8.0 and Durability.impact_damage(kind, 80.0) <= 12.0)
		check("%s damage increases with normal impact speed" % kind, Durability.impact_damage(kind, 8.0) < Durability.impact_damage(kind, 20.0) and Durability.impact_damage(kind, 20.0) < Durability.impact_damage(kind, 40.0))
	for kind in ["tank", "fighter", "hoverboard"]:
		check("%s takes no contact damage at any game speed" % kind, Durability.impact_damage(kind, 20.0) == 0.0 and Durability.impact_damage(kind, 620.0) == 0.0)
	check("negative relative normal means closing collision", is_equal_approx(Durability.contact_speed(Vector3(0, 0, -20), Vector3.BACK, Vector3.ZERO, 1000), 20.0))
	check("positive relative normal is separating motion", Durability.contact_speed(Vector3(0, 0, 20), Vector3.BACK, Vector3.ZERO, 1000) == 0.0)
	check("huge lateral friction impulse is not body damage", Durability.contact_speed(Vector3(40, 0, 0), Vector3.UP, Vector3(900000, 163.5, 0), 1000) < 1.0)
	check("normal solver impulse still detects stopped wall hit", is_equal_approx(Durability.contact_speed(Vector3.ZERO, Vector3.BACK, Vector3(0, 0, 20000), 1000), 20.0))
	check("impulse orientation sign does not hide a hard contact", is_equal_approx(Durability.contact_speed(Vector3.ZERO, Vector3.BACK, Vector3(0, 0, -20000), 1000), 20.0))
	check("collision speed is consistent across vehicle masses", is_equal_approx(Durability.contact_speed(Vector3.ZERO, Vector3.BACK, Vector3(0, 0, 6000), 300), Durability.contact_speed(Vector3.ZERO, Vector3.BACK, Vector3(0, 0, 2900000), 145000)))
	check("invalid normal has no collision damage", Durability.contact_speed(Vector3.ONE * 100, Vector3.ZERO, Vector3.ONE * 100000, 1000) == 0.0)
	check("invalid closing speed cannot poison health", Durability.impact_damage("car", NAN) == 0.0 and Durability.impact_damage("car", INF) == 0.0)
	var gate := Durability.new()
	gate.begin_step(1.0 / 60.0)
	var wall: String = gate.observe_contact(42, Vector3.BACK)
	check("fresh wall contact is eligible", gate.eligible_contact(wall, 20.0))
	gate.register_impact(wall)
	var repeated := 0
	for frame in 600:
		gate.begin_step(1.0 / 60.0)
		wall = gate.observe_contact(42, Vector3.BACK)
		if gate.eligible_contact(wall, 20.0):
			repeated += 1
	check("ten seconds pushing same wall cannot repeatedly drain health", repeated == 0, repeated)
	gate.begin_step(0.1)
	wall = gate.observe_contact(42, Vector3.BACK)
	check("brief contact solver gap cannot double-count collision", not gate.eligible_contact(wall, 20.0))
	gate.begin_step(0.3)
	wall = gate.observe_contact(42, Vector3.BACK)
	check("separating and returning allows a new genuine collision", gate.eligible_contact(wall, 20.0))
	gate.register_impact(wall)
	var ground: String = gate.observe_contact(42, Vector3.UP)
	check("ground and wall on one city body are separate episodes", gate.eligible_contact(ground, 20.0))
	check("new collision body can still be hit", gate.eligible_contact(gate.observe_contact(43, Vector3.BACK), 20.0))
	check("minor contact cannot consume collision episode", not gate.eligible_contact(gate.observe_contact(99, Vector3.BACK), 2.0))
	gate.reset()
	wall = gate.observe_contact(42, Vector3.BACK)
	check("repair and restore can reset transient contact gate", gate.eligible_contact(wall, 20.0))
	var passed := true
	for result in checks:
		if not result.passed: passed = false
	var report := {"passed": passed, "checks": checks, "scope": "Deterministic arcade durability and contact episode policy; native physical contact test is separate"}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://../reports/vehicle-durability.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("VEHICLE_DURABILITY ", JSON.stringify(report))
	quit(0 if passed else 1)
