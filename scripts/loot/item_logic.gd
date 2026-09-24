class_name ItemLogic
extends RefCounted
## Pure functions over item dictionaries (names, stats, costs, comparison).

const FLAT_STATS := ["health", "damage", "defense"]


static func is_equipment(item: Dictionary) -> bool:
	return item.get("kind", "") == "equipment"


static func display_name(item: Dictionary) -> String:
	var base := TranslationServer.translate("item." + str(item.get("base", "")))
	if not is_equipment(item):
		return base
	var pre: String = item.get("prefix", "")
	var suf: String = item.get("suffix", "")
	var p := TranslationServer.translate("prefix." + pre) if pre != "" else ""
	var s := TranslationServer.translate("suffix." + suf) if suf != "" else ""
	var name := ""
	if TranslationServer.get_locale().begins_with("ar"):
		name = " ".join(PackedStringArray([base, p, s].filter(func(x): return x != "")))
	else:
		name = " ".join(PackedStringArray([p, base, s].filter(func(x): return x != "")))
	if int(item.get("upgrade", 0)) > 0:
		name += " +%d" % int(item.upgrade)
	return name


static func upgrade_mult(item: Dictionary) -> float:
	return 1.0 + float(DB.cfg.upgrade.stat_per_level) * int(item.get("upgrade", 0))


## Aggregated stat contributions of one item (includes upgrades and socketed gems).
static func total_stats(item: Dictionary) -> Dictionary:
	var out := {}
	if item.is_empty():
		return out
	var m := upgrade_mult(item)
	if not is_equipment(item):
		var d := DB.gem_or_rune(item.get("base", ""))
		if not d.is_empty():
			out[d.stat] = float(d.value)
		return out
	if float(item.get("damage", 0)) > 0:
		out["damage"] = float(item.damage) * m
	if float(item.get("defense", 0)) > 0:
		out["defense"] = float(item.defense) * m
	for b in item.get("bonuses", []):
		var v := float(b.value)
		if b.stat in FLAT_STATS:
			v *= m
		out[b.stat] = out.get(b.stat, 0.0) + v
	for g in item.get("gems", []):
		var gd := DB.gem_or_rune(g)
		if not gd.is_empty():
			out[gd.stat] = out.get(gd.stat, 0.0) + float(gd.value)
	return out


static func power(item: Dictionary) -> int:
	var s := total_stats(item)
	var p := 0.0
	p += s.get("damage", 0.0) * 4.0
	p += s.get("defense", 0.0) * 3.0
	p += s.get("health", 0.0) * 0.25
	p += (s.get("attack_speed", 0.0) + s.get("crit", 0.0) + s.get("cdr", 0.0) + s.get("lifesteal", 0.0) + s.get("move_speed", 0.0)) * 400.0
	p += s.get("crit_dmg", 0.0) * 150.0 + s.get("energy_regen", 0.0) * 40.0
	return int(p)


static func upgrade_cost(item: Dictionary) -> Dictionary:
	var u := int(item.get("upgrade", 0))
	var cfg: Dictionary = DB.cfg.upgrade
	if u >= int(cfg.max):
		return {}
	var gold := int(float(cfg.gold_base) * pow(float(cfg.gold_growth), u) * (1.0 + 0.25 * int(item.get("rarity", 0))) * (1.0 + int(item.get("level", 1)) * 0.03))
	var mat := "iron_ore"
	if u >= 10:
		mat = "void_essence"
	elif u >= 7:
		mat = "dragon_scale"
	elif u >= 4:
		mat = "soul_shard"
	return {"gold": gold, "material": mat, "count": 1 + u % 4}


static func sell_value(item: Dictionary) -> int:
	return int(item.get("value", 10))


## Stat differences item - other (positive = item better).
static func compare(item: Dictionary, other: Dictionary) -> Dictionary:
	var a := total_stats(item)
	var b := total_stats(other)
	var out := {}
	for k in a:
		out[k] = a[k] - b.get(k, 0.0)
	for k in b:
		if not out.has(k):
			out[k] = -b[k]
	return out


static func icon_for(item: Dictionary) -> String:
	if item.get("kind", "") == "gem":
		return "gem"
	if item.get("kind", "") == "rune":
		return "rune"
	var slot: String = item.get("slot", "weapon")
	for b in DB.items.bases.get(slot, []):
		if b.id == item.get("base", ""):
			return b.icon
	return slot


static func color_for(item: Dictionary) -> Color:
	if not is_equipment(item):
		var d := DB.gem_or_rune(item.get("base", ""))
		if d.has("color"):
			return Color(d.color[0], d.color[1], d.color[2])
	return DB.rarity_color(int(item.get("rarity", 0)))
