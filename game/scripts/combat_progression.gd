extends RefCounted
## New reinforcements adapt gradually. Existing enemies never gain health.
const MAX_LEVEL := 30
const RAMP_SECONDS := 18.0

## 轻松 / 标准 / 硬核. Health and damage scale the reinforcements a player meets,
## count shifts how many are around at once, grace shortens the entry protection
## and reward keeps the risk worth taking.
const DIFFICULTY := [
	{"name": "轻松", "health": 0.78, "damage": 0.72, "count": -1, "grace": 1.5, "reward": 0.9, "level": -1},
	{"name": "标准", "health": 1.0, "damage": 1.0, "count": 0, "grace": 1.0, "reward": 1.0, "level": 0},
	{"name": "硬核", "health": 1.3, "damage": 1.28, "count": 2, "grace": 0.55, "reward": 1.25, "level": 1},
]


static func difficulty(index: int) -> Dictionary:
	return DIFFICULTY[clampi(index, 0, DIFFICULTY.size() - 1)]


## Waves start short so the first clear arrives quickly, then settle into a
## steady length instead of growing without end.
static func wave_quota(cleared: int) -> int:
	return clampi(6 + maxi(0, cleared) * 2, 6, 16)


## Pressure comes from waves cleared, districts taken back, and the difficulty.
static func encounter_level(cleared: int, districts_liberated: int, adaptive: int, difficulty_index: int) -> int:
	var veteran := 1 + int(maxi(0, cleared) / 2.0) + int(maxi(0, districts_liberated) / 2.0)
	var shift := int(difficulty(difficulty_index).level)
	return clampi(maxi(veteran, maxi(1, adaptive)) + shift, 1, MAX_LEVEL)


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
