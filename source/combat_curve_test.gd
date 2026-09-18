extends SceneTree
## The difficulty curve is a pure function, so it is checked without a world.
const Progression = preload("res://scripts/combat_progression.gd")
var failures := 0

func check(title: String, okay: bool, detail: Variant = null) -> void:
	if not okay: failures += 1
	print("COMBAT_CURVE ", "PASS " if okay else "FAIL ", title, "" if detail == null else " " + str(detail))

func _initialize() -> void:
	check("the first wave is short", Progression.wave_quota(0) == 6, Progression.wave_quota(0))
	check("waves grow by two", Progression.wave_quota(1) == 8 and Progression.wave_quota(3) == 12)
	check("wave length settles instead of growing forever", Progression.wave_quota(5) == 16 and Progression.wave_quota(40) == 16)
	check("a fresh city starts at level one", Progression.encounter_level(0, 0, 1, 1) == 1)
	check("clearing waves raises the level", Progression.encounter_level(10, 0, 1, 1) == 6, Progression.encounter_level(10, 0, 1, 1))
	check("liberated districts raise it too", Progression.encounter_level(10, 4, 1, 1) == 8, Progression.encounter_level(10, 4, 1, 1))
	check("easy takes one level off, hardcore adds one",
		Progression.encounter_level(10, 0, 1, 0) == 5 and Progression.encounter_level(10, 0, 1, 2) == 7)
	check("the level never drops below one", Progression.encounter_level(0, 0, 1, 0) == 1)
	check("an adaptive level still counts", Progression.encounter_level(0, 0, 9, 1) == 9)
	check("the level is capped", Progression.encounter_level(400, 400, 1, 2) == Progression.MAX_LEVEL)
	var easy: Dictionary = Progression.difficulty(0)
	var standard: Dictionary = Progression.difficulty(1)
	var hard: Dictionary = Progression.difficulty(2)
	check("standard leaves every number alone",
		float(standard.health) == 1.0 and float(standard.damage) == 1.0 and int(standard.count) == 0 and float(standard.grace) == 1.0 and float(standard.reward) == 1.0)
	check("easy is gentler in every way",
		float(easy.health) < 1.0 and float(easy.damage) < 1.0 and int(easy.count) < 0 and float(easy.grace) > 1.0)
	check("hardcore is harder and pays more",
		float(hard.health) > 1.0 and float(hard.damage) > 1.0 and int(hard.count) > 0 and float(hard.grace) < 1.0 and float(hard.reward) > 1.0)
	check("an unknown difficulty falls back inside the table",
		Progression.difficulty(-5) == easy and Progression.difficulty(99) == hard)
	check("air counts are unchanged", Progression.allowed_air_count(1, false, true) == 2 and Progression.allowed_air_count(1, true, true) == 1)
	print("COMBAT_CURVE COMPLETE failures=%d" % failures)
	quit(1 if failures > 0 else 0)
