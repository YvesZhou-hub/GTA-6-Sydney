extends RefCounted
## Paid ownership and free fitting are shared by vehicle type, never by copy.
const Modules = preload("res://scripts/weapon_modules.gd")
const KINDS := ["car", "motorcycle", "hoverboard", "speedboat", "yacht", "helicopter", "glider", "paraglider", "airliner", "tank", "fighter"]
var owned: Dictionary = {}
var equipped: Dictionary = {}

func clear() -> void:
	owned.clear()
	equipped.clear()

func level(kind: String, id: String) -> int:
	return int(owned.get(kind, {}).get(id, 0))

func loadout(kind: String) -> Array[Dictionary]:
	return Modules.power_loadout(equipped.get(kind, []), owned.get(kind, {}))

func is_equipped(kind: String, id: String) -> bool:
	return loadout(kind).any(func(item: Dictionary): return item.id == id)

func transact(kind: String, id: String, action: String, balance: int) -> Dictionary:
	var result := {"ok":false, "balance":balance, "cost":0, "message":"未知武器模块"}
	if not KINDS.has(kind) or not Modules.CATALOG.has(id): return result
	var tier := level(kind, id)
	var fitted: Array = equipped.get(kind, []).duplicate()
	var title: String = Modules.CATALOG[id].label
	match action:
		"buy":
			if tier >= Modules.MAX_LEVEL:
				result.message = title + "已达 III 级，金币已保留"
				return result
			var price := Modules.cost(id, tier)
			if balance < price:
				result.message = "金币不足 · 需要 $%d" % price
				return result
			if not owned.has(kind): owned[kind] = {}
			owned[kind][id] = tier + 1
			if tier == 0 and fitted.size() < Modules.MAX_SLOTS: fitted.append(id)
			result.balance = balance - price
			result.cost = price
			result.message = "%s %s 级 · $%d · %s" % [title, ["I", "II", "III"][tier], price, "已装配" if fitted.has(id) else "已入库，可免费更换装配"]
		"equip":
			if tier == 0:
				result.message = "先购买该模块"
				return result
			if fitted.has(id):
				result.message = "该模块已装配，不可重复占槽"
				return result
			if fitted.size() >= Modules.MAX_SLOTS:
				result.message = "三个槽位已满 · 先卸下一件，再免费装配"
				return result
			fitted.append(id)
			result.message = title + "已装配 · 免费弹药"
		"unequip":
			if not fitted.has(id):
				result.message = "该模块尚未装配"
				return result
			fitted.erase(id)
			result.message = title + "已卸下 · 保留等级，可免费装回"
		_:
			result.message = "未知装配操作"
			return result
	equipped[kind] = fitted
	result.ok = true
	return result

func snapshot() -> Dictionary:
	return {"revision":1, "owned":owned.duplicate(true), "equipped":equipped.duplicate(true)}

func restore(value: Variant) -> void:
	clear()
	if not value is Dictionary: return
	var saved_owned: Variant = value.get("owned", {})
	var saved_equipped: Variant = value.get("equipped", {})
	if not saved_owned is Dictionary: return
	for kind: String in KINDS:
		var items: Variant = saved_owned.get(kind, {})
		if not items is Dictionary: continue
		var clean := {}
		for id: String in Modules.CATALOG:
			var number: Variant = items.get(id, 0)
			if not (number is int or number is float) or not is_finite(float(number)): continue
			var tier := clampi(int(number), 0, Modules.MAX_LEVEL)
			if tier > 0: clean[id] = tier
		owned[kind] = clean
		var entries: Variant = saved_equipped.get(kind, []) if saved_equipped is Dictionary else []
		equipped[kind] = []
		if entries is Array:
			for item: Dictionary in Modules.power_loadout(entries, clean): equipped[kind].append(item.id)
