extends RefCounted
## Arcade body durability. The world still receives the actual impact energy;
## this policy controls only vehicle damage and contact-episode bookkeeping.
const EFFECT_THRESHOLD_MPS := 3.5
const DAMAGE_THRESHOLD_MPS := 6.0
const DAMAGE_PER_MPS := 0.35
const MAX_DAMAGE := 12.0
const CONTACT_REARM_SECONDS := 0.22

var _clock := 0.0
var _contacts: Dictionary = {}

static func is_damage_proof(kind: String) -> bool:
	return kind in ["tank", "fighter", "hoverboard"]

static func impact_damage(kind: String, closing_speed: float) -> float:
	if is_damage_proof(kind) or not is_finite(closing_speed):
		return 0.0
	return clampf((closing_speed - DAMAGE_THRESHOLD_MPS) * DAMAGE_PER_MPS, 0.0, MAX_DAMAGE)

static func contact_speed(relative_velocity: Vector3, normal: Vector3, impulse: Vector3, body_mass: float) -> float:
	if not relative_velocity.is_finite() or not normal.is_finite() or not impulse.is_finite():
		return 0.0
	if normal.length_squared() < 0.0001 or not is_finite(body_mass) or body_mass <= 0.0:
		return 0.0
	var unit_normal := normal.normalized()
	var normal_closing := maxf(0.0, -relative_velocity.dot(unit_normal))
	# Friction during a drift/handbrake stop is tangential and cannot dent a car.
	# The normal impulse also detects hits whose speed the solver already removed.
	var impulse_closing := absf(impulse.dot(unit_normal)) / body_mass
	return maxf(normal_closing, impulse_closing)

func begin_step(delta: float) -> void:
	_clock += maxf(0.0, delta)
	# Bound state for a vehicle that travels through many city collision bodies.
	for key in _contacts.keys():
		if _clock - float(_contacts[key].last_seen) > 2.0:
			_contacts.erase(key)

func observe_contact(collider_id: int, normal: Vector3) -> String:
	# Ground and walls may share a StaticBody3D. Keep their contact episodes apart.
	var axis := normal.abs().max_axis_index()
	var side := 1 if normal[axis] >= 0.0 else -1
	var key := "%d:%d:%d" % [collider_id, axis, side]
	var entry: Dictionary = _contacts.get(key, {"last_seen": -100.0, "blocked": false})
	if _clock - float(entry.last_seen) > CONTACT_REARM_SECONDS:
		entry.blocked = false
	entry.last_seen = _clock
	_contacts[key] = entry
	return key

func eligible_contact(key: String, closing_speed: float) -> bool:
	return is_finite(closing_speed) and closing_speed > EFFECT_THRESHOLD_MPS and _contacts.has(key) and not bool(_contacts[key].blocked)

func register_impact(key: String) -> void:
	if _contacts.has(key):
		_contacts[key].blocked = true

func reset() -> void:
	_clock = 0.0
	_contacts.clear()
