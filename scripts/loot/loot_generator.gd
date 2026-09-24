class_name LootGenerator
extends RefCounted
## Random loot: rarity rolls, random affixes, sockets, gems, runes and materials.

static var _uid_counter := 0


static func new_uid() -> String:
	_uid_counter += 1
	return "i%d_%d_%d" % [Time.get_unix_time_from_system(), _uid_counter, randi() % 100000]


static func roll_rarity(luck: float = 1.0, min_rarity: int = 0) -> int:
	var rar: Array = DB.cfg.rarities
	var total := 0.0
	var weights: Array[float] = []
	for i in rar.size():
		var w := float(rar[i].weight)
		if i < min_rarity:
			w = 0.0
		elif i >= 2:
			w *= luck   # luck boosts epic+ weights
		weights.append(w)
		total += w
	var r := randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return min_rarity


static func generate_equipment(level: int, rarity: int = -1, slot: String = "", luck: float = 1.0) -> Dictionary:
	var slots: Array = DB.items.slots
	if slot == "":
		slot = slots.pick_random()
	if rarity < 0:
		rarity = roll_rarity(luck)
	var rd := DB.rarity(rarity)
	var base: Dictionary = DB.items.bases[slot].pick_random()
	var quality := randi_range(40, 100)
	var level_mult := 1.0 + 0.12 * (level - 1)
	var q := 0.8 + quality / 250.0
	var dmg := float(base.dmg) * level_mult * float(rd.mult) * q
	var def := float(base.def) * level_mult * float(rd.mult) * q
	var bonuses: Array = []
	var pool: Array = DB.items.affixes.filter(func(a): return slot in a.slots)
	pool.shuffle()
	var n := mini(int(rd.affixes), pool.size())
	for i in n:
		var a: Dictionary = pool[i]
		var v := randf_range(float(a.min), float(a.max))
		v *= (1.0 + float(a.scale) * (level - 1)) * (0.85 + 0.15 * rarity)
		if a.stat in ["health", "damage", "defense"]:
			v = round(v)
		else:
			v = snappedf(v, 0.005)
		bonuses.append({"stat": a.stat, "value": v})
	var sock: Array = rd.sockets
	var item := {
		"uid": new_uid(), "kind": "equipment", "slot": slot, "base": base.id,
		"prefix": DB.items.prefixes.pick_random() if rarity >= 1 else "",
		"suffix": DB.items.suffixes.pick_random() if rarity >= 2 else "",
		"level": level, "rarity": rarity, "quality": quality,
		"damage": round(dmg), "defense": round(def), "bonuses": bonuses,
		"sockets": randi_range(int(sock[0]), int(sock[1])), "gems": [], "upgrade": 0, "new": true,
	}
	item["value"] = int((20 + ItemLogic.power(item) * 0.6) * (1.0 + rarity * 0.5))
	return item


static func generate_socketable(kind: String, level: int = 1) -> Dictionary:
	var list: Array = DB.items.gems if kind == "gem" else DB.items.runes
	var d: Dictionary = list.pick_random()
	return {"uid": new_uid(), "kind": kind, "slot": kind, "base": d.id, "level": level, "rarity": 1 if kind == "gem" else 2,
		"quality": 100, "damage": 0, "defense": 0, "bonuses": [], "sockets": 0, "gems": [], "upgrade": 0,
		"value": 60 if kind == "gem" else 90, "new": true}


static func roll_material() -> Dictionary:
	var mats: Array = DB.items.materials
	var total := 0.0
	for m in mats:
		total += float(m.weight)
	var r := randf() * total
	for m in mats:
		r -= float(m.weight)
		if r <= 0.0:
			return {"material": m.id, "count": randi_range(1, 3) if m.id == "iron_ore" else 1}
	return {"material": "iron_ore", "count": 1}


## A single random drop: returns either an item dictionary or {"material": id, "count": n}.
static func roll_drop(level: int, luck: float = 1.0, min_rarity: int = 0) -> Dictionary:
	var w: Dictionary = DB.items.drop_weights
	if min_rarity > 0:
		return generate_equipment(level, roll_rarity(luck, min_rarity), "", luck)
	var total := float(w.equipment + w.gem + w.rune + w.material)
	var r := randf() * total
	if r < float(w.equipment):
		return generate_equipment(level, roll_rarity(luck), "", luck)
	r -= float(w.equipment)
	if r < float(w.gem):
		return generate_socketable("gem", level)
	r -= float(w.gem)
	if r < float(w.rune):
		return generate_socketable("rune", level)
	return roll_material()


static func open_chest(chest: Dictionary, level: int) -> Array:
	var out: Array = []
	for i in int(chest.items):
		var minr := int(chest.min_rarity) if i == 0 else 0
		out.append(generate_equipment(level, roll_rarity(float(chest.luck), minr), "", float(chest.luck)))
	return out
