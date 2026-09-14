extends RefCounted
## New reinforcements adapt gradually. Existing enemies never gain health.
const MAX_LEVEL := 30
const RAMP_SECONDS := 18.0

static func equipment_strength(main_tier: int, modules: Array) -> float:
	var score := clampi(main_tier, 0, 3) * .65
	for module: Dictionary in modules:
		score += .8 + .45 * clampi(int(module.get("level", 1)), 1, 3)
	return score

static func target_level(cleared: int, main_tier: int, modules: Array, in_vehicle: bool) -> int:
	var veteran := clampi(1 + int(maxi(0, cleared) / 2.0), 1, MAX_LEVEL)
	# A strong loadout adds pressure, but does not cancel its full damage advantage.
	var equipment := 1 + floori(equipment_strength(main_tier, modules)) if in_vehicle else 1
	return clampi(maxi(veteran, equipment), 1, MAX_LEVEL)

static func allowed_air_count(level: int, low_health: bool, airborne: bool) -> int:
	if low_health: return 1
	if airborne: return clampi(2 + int(level / 7.0), 2, 5)
	return clampi(1 + int(level / 8.0), 1, 3)
