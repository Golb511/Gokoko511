extends Node
## Static game database. Loads all JSON design data once at startup.

var cfg: Dictionary = {}
var heroes: Dictionary = {}
var abilities: Dictionary = {}
var towers: Dictionary = {}
var enemies: Dictionary = {}
var bosses: Dictionary = {}
var allies: Dictionary = {}
var items: Dictionary = {}
var meta: Dictionary = {}
var layouts: Dictionary = {}
var regions: Array = []
var explicit_waves: Dictionary = {}
var tower_tree: Dictionary = {}
var hero_tree: Dictionary = {}

const ENDLESS := "endless"
var hero_order: Array = []
var tower_order: Array = []
var stage_order: Array = []           # flat list of stage ids in progression order
var _stage_index: Dictionary = {}     # stage_id -> {region_idx, stage_idx, data}


func _ready() -> void:
	cfg = _load("res://data/config.json")
	heroes = _load("res://data/heroes.json")
	abilities = _load("res://data/abilities.json")
	towers = _load("res://data/towers.json")
	tower_tree = _load("res://data/tower_tree.json")
	hero_tree = _load("res://data/hero_tree.json")
	var units := _load("res://data/units.json")
	enemies = units.get("enemies", {})
	bosses = units.get("bosses", {})
	allies = units.get("allies", {})
	items = _load("res://data/items.json")
	meta = _load("res://data/meta.json")
	var reg := _load("res://data/regions.json")
	layouts = reg.get("layouts", {})
	regions = reg.get("regions", [])
	explicit_waves = reg.get("explicit_waves", {})
	hero_order = heroes.keys()
	tower_order = towers.keys()
	for ri in regions.size():
		var r: Dictionary = regions[ri]
		for si in r.stages.size():
			var s: Dictionary = r.stages[si]
			stage_order.append(s.id)
			_stage_index[s.id] = {"region_idx": ri, "stage_idx": si, "data": s, "region": r}
	# Endless mode lives at the Gate (last region) and is not part of the campaign order.
	_stage_index[ENDLESS] = {"region_idx": regions.size() - 1, "stage_idx": -1, "region": regions[-1],
		"data": {"id": ENDLESS, "layout": "gauntlet", "towers": towers.keys(), "endless": true}}


func _load(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DB: cannot open %s" % path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("DB: invalid JSON in %s" % path)
		return {}
	return parsed


func enemy(id: String) -> Dictionary:
	if enemies.has(id):
		return enemies[id]
	return bosses.get(id, {})


func is_boss(id: String) -> bool:
	return bosses.has(id)


func stage_info(stage_id: String) -> Dictionary:
	return _stage_index.get(stage_id, {})


## Normalised battlefield map for a stage: a hand-authored "map" block on the
## stage wins; otherwise the shared layout it references. Paths are returned as
## [{"points": [...], "air": bool}].
func stage_map(stage_id: String) -> Dictionary:
	var info := stage_info(stage_id)
	var data: Dictionary = info.get("data", {})
	if data.has("map"):
		return data.map
	var lay: Dictionary = layouts.get(data.get("layout", "serpent"), layouts.serpent)
	var paths: Array = []
	for p in lay.paths:
		paths.append({"points": p, "air": false})
	return {"paths": paths, "castle": lay.castle, "bounds": lay.bounds}


func stage_label(stage_id: String) -> String:
	if stage_id == ENDLESS:
		return "∞"
	var info := stage_info(stage_id)
	if info.is_empty():
		return stage_id
	# Wrapped in a left-to-right isolate so Arabic text around it can't flip "1-3" into "3-1".
	return "\u2066%d-%d\u2069" % [info.region_idx + 1, info.stage_idx + 1]


func rarity(idx: int) -> Dictionary:
	return cfg.rarities[clampi(idx, 0, cfg.rarities.size() - 1)]


func rarity_color(idx: int) -> Color:
	var c: Array = rarity(idx).color
	return Color(c[0], c[1], c[2])


func find_in(list: Array, id: String) -> Dictionary:
	for e in list:
		if e.get("id", "") == id:
			return e
	return {}


func gem_or_rune(id: String) -> Dictionary:
	var d := find_in(items.gems, id)
	if d.is_empty():
		d = find_in(items.runes, id)
	return d


func material(id: String) -> Dictionary:
	return find_in(items.materials, id)


## Returns the stats for a tower at a given level (1-based) and branch index (-1 = none).
func tower_level_data(tower_id: String, level: int, branch: int) -> Dictionary:
	var t: Dictionary = towers[tower_id]
	var base_levels: Array = t.levels
	if level <= base_levels.size() or branch < 0:
		return base_levels[clampi(level - 1, 0, base_levels.size() - 1)]
	var b: Dictionary = t.branches[branch]
	return b.levels[clampi(level - base_levels.size() - 1, 0, b.levels.size() - 1)]


func tower_max_level(tower_id: String) -> int:
	var t: Dictionary = towers[tower_id]
	return t.levels.size() + t.branches[0].levels.size()


## Merge tower root + branch overrides (attack type, projectile, element...).
func tower_attr(tower_id: String, branch: int, key: String, default = null):
	var t: Dictionary = towers[tower_id]
	if branch >= 0 and t.branches[branch].has(key):
		return t.branches[branch][key]
	return t.get(key, default)
