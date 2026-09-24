extends Node
## Player profile & progression: currencies, energy, heroes, inventory,
## stars, quests, achievements, daily rewards, guild and settings.

const SKILL_TREE := [
	{"id": "brutality",  "branch": "offense", "stat": "damage_pct",   "per_rank": 0.04, "req": ""},
	{"id": "precision",  "branch": "offense", "stat": "crit",         "per_rank": 0.02, "req": "brutality"},
	{"id": "fury",       "branch": "offense", "stat": "attack_speed", "per_rank": 0.05, "req": "precision"},
	{"id": "iron_skin",  "branch": "defense", "stat": "defense_pct",  "per_rank": 0.05, "req": ""},
	{"id": "vitality",   "branch": "defense", "stat": "health_pct",   "per_rank": 0.06, "req": "iron_skin"},
	{"id": "bulwark",    "branch": "defense", "stat": "lifesteal",    "per_rank": 0.02, "req": "vitality"},
	{"id": "focus",      "branch": "mastery", "stat": "cdr",          "per_rank": 0.04, "req": ""},
	{"id": "swiftness",  "branch": "mastery", "stat": "move_speed",   "per_rank": 0.04, "req": "focus"},
	{"id": "mastery",    "branch": "mastery", "stat": "ult_mult",     "per_rank": 0.10, "req": "swiftness"},
	# Hero-specific branch: one node per ability (named after the hero's own abilities).
	{"id": "ab0", "branch": "abilities", "stat": "ability", "per_rank": 0.12, "req": ""},
	{"id": "ab1", "branch": "abilities", "stat": "ability", "per_rank": 0.12, "req": ""},
	{"id": "ab2", "branch": "abilities", "stat": "ability", "per_rank": 0.12, "req": "ab0"},
	{"id": "ab3", "branch": "abilities", "stat": "ability", "per_rank": 0.12, "req": "ab1"},
]
const ABILITY_CDR_PER_RANK := 0.05
const SKILL_MAX_RANK := 3

var profile: Dictionary = {}
var current_stage: String = ""          # stage selected for battle
var last_battle_result: Dictionary = {}
var _dirty := false
var _save_timer := 0.0


var no_save := false


func _ready() -> void:
	no_save = "--fresh" in OS.get_cmdline_user_args()
	var loaded := {} if no_save else Save.load_profile()
	profile = Save.merge_defaults(loaded, _default_profile()) if not loaded.is_empty() else _default_profile()
	Events.stat_tracked.connect(_on_stat)
	ensure_daily_quests()
	apply_settings()


func _process(delta: float) -> void:
	if _dirty and not no_save:
		_save_timer -= delta
		if _save_timer <= 0.0:
			_dirty = false
			Save.save_profile(profile)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_now()


func mark_dirty() -> void:
	_dirty = true
	_save_timer = 0.6


func save_now() -> void:
	_dirty = false
	if not no_save:
		Save.save_profile(profile)


func reset_profile() -> void:
	Save.delete_save()
	profile = _default_profile()
	ensure_daily_quests()
	save_now()
	Events.profile_changed.emit()


func _default_profile() -> Dictionary:
	var heroes := {}
	for id in DB.heroes:
		heroes[id] = {"unlocked": DB.heroes[id].unlock.type == "start", "level": 1, "xp": 0, "skills": {}, "equipment": {}}
	var starter := LootGenerator.generate_equipment(1, 0, "weapon")
	starter["base"] = "w_greatsword"
	starter["new"] = false
	var starter_armor := LootGenerator.generate_equipment(1, 1, "armor")
	starter_armor["new"] = false
	return {
		"created": Time.get_unix_time_from_system(),
		"player_level": 1, "player_xp": 0,
		"gold": int(DB.cfg.start_gold), "gems": int(DB.cfg.start_gems),
		"energy": int(DB.cfg.energy_max), "energy_ts": Time.get_unix_time_from_system(),
		"stars": {}, "best_lives": {},
		"heroes": heroes, "selected_hero": "hell_knight",
		"inventory": [starter, starter_armor], "materials": {"iron_ore": 5},
		"stats": {}, "achievements": {},
		"quests": {"date": "", "list": []},
		"daily": {"last": "", "streak": 0},
		"shop": {"date": "", "bought": []},
		"guild": {"level": 1, "xp": 0, "perks": {}},
		"settings": {"lang": "ar", "music": 0.7, "sfx": 0.8, "quality": 2, "shadows": true, "fog": true, "camera_speed": 1.0, "show_fps": false, "tutorial_done": false},
	}


# ---------------------------------------------------------------- currencies
func gold() -> int: return int(profile.gold)
func gems() -> int: return int(profile.gems)


func add_gold(v: int) -> void:
	profile.gold = maxi(0, gold() + v)
	Events.currency_changed.emit()
	mark_dirty()


func add_gems(v: int) -> void:
	profile.gems = maxi(0, gems() + v)
	Events.currency_changed.emit()
	mark_dirty()


## cost: {"gold": n} and/or {"gems": n}
func can_afford(cost: Dictionary) -> bool:
	return gold() >= int(cost.get("gold", 0)) and gems() >= int(cost.get("gems", 0))


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		Events.notify(tr("ui.not_enough"), Color(1, 0.4, 0.3))
		return false
	profile.gold = gold() - int(cost.get("gold", 0))
	profile.gems = gems() - int(cost.get("gems", 0))
	Events.currency_changed.emit()
	mark_dirty()
	return true


func energy() -> int:
	var maxe := int(DB.cfg.energy_max)
	var e := int(profile.energy)
	if e >= maxe:
		return e
	var regen := float(DB.cfg.energy_regen_seconds)
	var now := Time.get_unix_time_from_system()
	var gained := int((now - float(profile.energy_ts)) / regen)
	if gained > 0:
		e = mini(maxe, e + gained)
		profile.energy = e
		profile.energy_ts = float(profile.energy_ts) + gained * regen if e < maxe else now
	return e


func seconds_to_next_energy() -> int:
	if energy() >= int(DB.cfg.energy_max):
		return 0
	var regen := float(DB.cfg.energy_regen_seconds)
	return int(regen - fmod(Time.get_unix_time_from_system() - float(profile.energy_ts), regen))


func spend_energy(v: int) -> bool:
	var e := energy()
	if e < v:
		Events.notify(tr("ui.not_enough_energy"), Color(1, 0.4, 0.3))
		return false
	if e >= int(DB.cfg.energy_max):
		profile.energy_ts = Time.get_unix_time_from_system()
	profile.energy = e - v
	Events.currency_changed.emit()
	mark_dirty()
	return true


func add_energy(v: int) -> void:
	profile.energy = energy() + v
	Events.currency_changed.emit()
	mark_dirty()


# ---------------------------------------------------------------- player xp
static func xp_needed(level: int, base: float, growth: float) -> int:
	return int(base * pow(growth, level - 1))


func player_xp_needed() -> int:
	return xp_needed(int(profile.player_level), float(DB.cfg.player_xp_base), float(DB.cfg.player_xp_growth))


func add_player_xp(v: int) -> void:
	v = int(v * (1.0 + guild_bonus("xp_bonus")))
	profile.player_xp = int(profile.player_xp) + v
	while int(profile.player_xp) >= player_xp_needed() and int(profile.player_level) < int(DB.cfg.player_max_level):
		profile.player_xp = int(profile.player_xp) - player_xp_needed()
		profile.player_level = int(profile.player_level) + 1
		add_gems(10)
		profile.energy = energy() + 20
		Events.notify("%s %d" % [tr("ui.player_level_up"), profile.player_level], Color(1, 0.85, 0.3))
	Events.profile_changed.emit()
	mark_dirty()


# ---------------------------------------------------------------- stages
func stage_stars(stage_id: String) -> int:
	return int(profile.stars.get(stage_id, 0))


func total_stars() -> int:
	var t := 0
	for k in profile.stars:
		t += int(profile.stars[k])
	return t


func is_endless_unlocked() -> bool:
	return stage_stars("r1s4") > 0


func endless_best() -> int:
	return int(profile.get("endless_best", 0))


func is_stage_unlocked(stage_id: String) -> bool:
	if stage_id == DB.ENDLESS:
		return is_endless_unlocked()
	var idx := DB.stage_order.find(stage_id)
	if idx <= 0:
		return idx == 0
	return stage_stars(DB.stage_order[idx - 1]) > 0


func is_region_unlocked(region_idx: int) -> bool:
	return is_stage_unlocked(DB.regions[region_idx].stages[0].id)


func next_stage() -> String:
	for s in DB.stage_order:
		if stage_stars(s) == 0:
			return s if is_stage_unlocked(s) else ""
	return DB.stage_order[-1]


func record_stage_result(stage_id: String, stars: int) -> int:
	var prev := stage_stars(stage_id)
	var gained := maxi(0, stars - prev)
	if stars > prev:
		profile.stars[stage_id] = stars
	for id in DB.heroes:
		var u: Dictionary = DB.heroes[id].unlock
		if u.type == "stage" and u.stage == stage_id and not is_hero_unlocked(id):
			profile.heroes[id].unlocked = true
			Events.notify("%s: %s" % [tr("ui.unlocked_hero"), tr("hero." + id)], Color(1, 0.7, 0.2))
	if gained > 0:
		Events.track("stars_earned", gained)
	_update_star_achievement()
	mark_dirty()
	return gained


func _update_star_achievement() -> void:
	profile.stats["stars"] = total_stars()


# ---------------------------------------------------------------- heroes
func hero_state(id: String) -> Dictionary:
	return profile.heroes[id]


func is_hero_unlocked(id: String) -> bool:
	return bool(profile.heroes.get(id, {}).get("unlocked", false))


func unlock_hero_with_gems(id: String) -> bool:
	var u: Dictionary = DB.heroes[id].unlock
	if u.type != "gems" or is_hero_unlocked(id):
		return false
	if not spend({"gems": int(u.cost)}):
		return false
	profile.heroes[id].unlocked = true
	Events.hero_changed.emit(id)
	return true


func select_hero(id: String) -> void:
	if is_hero_unlocked(id):
		profile.selected_hero = id
		Events.hero_changed.emit(id)
		mark_dirty()


func hero_xp_needed(level: int) -> int:
	return xp_needed(level, float(DB.cfg.hero_xp_base), float(DB.cfg.hero_xp_growth))


func add_hero_xp(id: String, v: int) -> int:
	var h: Dictionary = profile.heroes[id]
	var levels := 0
	h.xp = int(h.xp) + int(v * (1.0 + guild_bonus("xp_bonus")))
	while int(h.xp) >= hero_xp_needed(int(h.level)) and int(h.level) < int(DB.cfg.hero_max_level):
		h.xp = int(h.xp) - hero_xp_needed(int(h.level))
		h.level = int(h.level) + 1
		levels += 1
	if levels > 0:
		Events.notify("%s  %s %d" % [tr("ui.hero_level_up"), tr("hero." + id), h.level], Color(1, 0.8, 0.3))
		Events.hero_changed.emit(id)
	mark_dirty()
	return levels


func skill_points_available(id: String) -> int:
	var h: Dictionary = profile.heroes[id]
	var spent := 0
	for k in h.skills:
		spent += int(h.skills[k])
	return int(h.level) - 1 - spent


func skill_rank(id: String, node: String) -> int:
	return int(profile.heroes[id].skills.get(node, 0))


func can_learn(id: String, node: Dictionary) -> bool:
	if skill_points_available(id) <= 0 or skill_rank(id, node.id) >= SKILL_MAX_RANK:
		return false
	return node.req == "" or skill_rank(id, node.req) > 0


func learn_skill(id: String, node_id: String) -> bool:
	for n in SKILL_TREE:
		if n.id == node_id and can_learn(id, n):
			profile.heroes[id].skills[node_id] = skill_rank(id, node_id) + 1
			Events.hero_changed.emit(id)
			mark_dirty()
			return true
	return false


func _skill_bonus(id: String, stat: String) -> float:
	var t := 0.0
	for n in SKILL_TREE:
		if n.stat == stat:
			t += float(n.per_rank) * skill_rank(id, n.id)
	return t


func equipment_stats(id: String) -> Dictionary:
	var out := {}
	for slot in profile.heroes[id].equipment:
		var item := find_item(profile.heroes[id].equipment[slot])
		var s := ItemLogic.total_stats(item)
		for k in s:
			out[k] = out.get(k, 0.0) + s[k]
	return out


## Final combat stats for a hero including level, equipment and skill tree.
func hero_stats(id: String) -> Dictionary:
	var d: Dictionary = DB.heroes[id]
	var base: Dictionary = d.stats
	var g: Dictionary = DB.cfg.hero_growth
	var lvl := int(profile.heroes[id].level) - 1
	var eq := equipment_stats(id)
	var caps: Dictionary = DB.items.affix_caps
	var s := {}
	s.health = (float(base.health) * (1.0 + float(g.health) * lvl) + eq.get("health", 0.0)) * (1.0 + _skill_bonus(id, "health_pct"))
	s.damage = (float(base.damage) * (1.0 + float(g.damage) * lvl) + eq.get("damage", 0.0)) * (1.0 + _skill_bonus(id, "damage_pct"))
	s.defense = (float(base.defense) * (1.0 + float(g.defense) * lvl) + eq.get("defense", 0.0)) * (1.0 + _skill_bonus(id, "defense_pct"))
	s.attack_speed = float(base.attack_speed) * (1.0 + minf(caps.attack_speed, eq.get("attack_speed", 0.0) + _skill_bonus(id, "attack_speed")))
	s.move_speed = float(base.move_speed) * (1.0 + minf(caps.move_speed, eq.get("move_speed", 0.0) + _skill_bonus(id, "move_speed")))
	s.energy = float(base.energy)
	s.energy_regen = 2.0 + eq.get("energy_regen", 0.0)
	s.crit = minf(caps.crit, float(base.crit) + eq.get("crit", 0.0) + _skill_bonus(id, "crit"))
	s.crit_dmg = 1.5 + eq.get("crit_dmg", 0.0)
	s.cdr = minf(caps.cdr, eq.get("cdr", 0.0) + _skill_bonus(id, "cdr"))
	s.lifesteal = minf(caps.lifesteal, eq.get("lifesteal", 0.0) + _skill_bonus(id, "lifesteal"))
	s.ult_mult = 1.0 + _skill_bonus(id, "ult_mult")
	s.range = float(base.range)
	s.level = lvl + 1
	return s


func hero_power(id: String) -> int:
	var s := hero_stats(id)
	return int(s.health * 0.25 + s.damage * s.attack_speed * 6.0 + s.defense * 4.0 + s.crit * 500.0 + s.cdr * 600.0)


# ---------------------------------------------------------------- inventory
func inventory() -> Array:
	return profile.inventory


func find_item(uid) -> Dictionary:
	if uid == null or str(uid) == "":
		return {}
	for it in profile.inventory:
		if it.uid == uid:
			return it
	return {}


func equipped_by(uid: String) -> String:
	for id in profile.heroes:
		for slot in profile.heroes[id].equipment:
			if profile.heroes[id].equipment[slot] == uid:
				return id
	return ""


func add_item(item: Dictionary) -> bool:
	if item.has("material"):
		add_material(item.material, int(item.get("count", 1)))
		return true
	if profile.inventory.size() >= int(DB.cfg.inventory_capacity):
		# Overflow is auto-salvaged into gold so loot is never silently lost.
		add_gold(ItemLogic.sell_value(item))
		Events.notify(tr("ui.inventory_full"), Color(1, 0.5, 0.3))
		return false
	profile.inventory.append(item)
	Events.track("items_looted")
	if int(item.get("rarity", 0)) >= 3 and ItemLogic.is_equipment(item):
		Events.track("legendary_found")
	Events.inventory_changed.emit()
	mark_dirty()
	return true


func remove_item(uid: String) -> void:
	var owner := equipped_by(uid)
	if owner != "":
		for slot in profile.heroes[owner].equipment.keys():
			if profile.heroes[owner].equipment[slot] == uid:
				profile.heroes[owner].equipment.erase(slot)
	for i in profile.inventory.size():
		if profile.inventory[i].uid == uid:
			profile.inventory.remove_at(i)
			break
	Events.inventory_changed.emit()
	mark_dirty()


func sell_item(uid: String) -> void:
	var it := find_item(uid)
	if it.is_empty():
		return
	add_gold(ItemLogic.sell_value(it))
	remove_item(uid)


func equip(hero_id: String, uid: String) -> void:
	var it := find_item(uid)
	if it.is_empty() or not ItemLogic.is_equipment(it):
		return
	var prev_owner := equipped_by(uid)
	if prev_owner != "":
		profile.heroes[prev_owner].equipment.erase(it.slot)
	profile.heroes[hero_id].equipment[it.slot] = uid
	it["new"] = false
	Events.inventory_changed.emit()
	Events.hero_changed.emit(hero_id)
	mark_dirty()


func unequip(hero_id: String, slot: String) -> void:
	profile.heroes[hero_id].equipment.erase(slot)
	Events.inventory_changed.emit()
	Events.hero_changed.emit(hero_id)
	mark_dirty()


func equipped_item(hero_id: String, slot: String) -> Dictionary:
	return find_item(profile.heroes[hero_id].equipment.get(slot, ""))


## Equip the highest-power item for each slot on the given hero.
func quick_equip(hero_id: String) -> void:
	for slot in DB.items.slots:
		var best := equipped_item(hero_id, slot)
		var best_p := ItemLogic.power(best) if not best.is_empty() else -1
		for it in profile.inventory:
			if it.get("slot", "") == slot and ItemLogic.is_equipment(it):
				var owner := equipped_by(it.uid)
				if owner != "" and owner != hero_id:
					continue
				var p := ItemLogic.power(it)
				if p > best_p:
					best = it
					best_p = p
		if not best.is_empty():
			profile.heroes[hero_id].equipment[slot] = best.uid
			best["new"] = false
	Events.inventory_changed.emit()
	Events.hero_changed.emit(hero_id)
	mark_dirty()


func upgrade_item(uid: String) -> bool:
	var it := find_item(uid)
	var cost := ItemLogic.upgrade_cost(it)
	if cost.is_empty():
		return false
	if material_count(cost.material) < int(cost.count):
		Events.notify(tr("ui.not_enough"), Color(1, 0.4, 0.3))
		return false
	if not spend({"gold": cost.gold}):
		return false
	add_material(cost.material, -int(cost.count))
	it.upgrade = int(it.upgrade) + 1
	it.value = int(float(it.value) * 1.15)
	Events.track("item_upgrades")
	Events.inventory_changed.emit()
	var owner := equipped_by(uid)
	if owner != "":
		Events.hero_changed.emit(owner)
	mark_dirty()
	return true


func socket_gem(item_uid: String, gem_uid: String) -> bool:
	var it := find_item(item_uid)
	var gem := find_item(gem_uid)
	if it.is_empty() or gem.is_empty() or it.gems.size() >= int(it.sockets):
		return false
	it.gems.append(gem.base)
	remove_item(gem_uid)
	var owner := equipped_by(item_uid)
	if owner != "":
		Events.hero_changed.emit(owner)
	Events.inventory_changed.emit()
	mark_dirty()
	return true


func material_count(id: String) -> int:
	return int(profile.materials.get(id, 0))


func add_material(id: String, count: int) -> void:
	profile.materials[id] = maxi(0, material_count(id) + count)
	Events.inventory_changed.emit()
	mark_dirty()


# ---------------------------------------------------------------- stats, achievements, quests
func _on_stat(stat: String, amount: int) -> void:
	profile.stats[stat] = int(profile.stats.get(stat, 0)) + amount
	for q in profile.quests.list:
		var qd := DB.find_in(DB.meta.quests, q.id)
		if not qd.is_empty() and qd.stat == stat and not q.claimed:
			q.progress = mini(int(qd.target), int(q.progress) + amount)
	for a in DB.meta.achievements:
		if a.stat == stat:
			var st := achievement_state(a.id)
			var tier := int(st.reached)
			while tier < a.tiers.size() and stat_value(stat) >= int(a.tiers[tier]):
				tier += 1
				Events.achievement_unlocked.emit(a.id)
				Events.notify("★ " + tr("ach." + a.id), Color(1, 0.8, 0.3))
			st.reached = tier
	mark_dirty()


func stat_value(stat: String) -> int:
	if stat == "stars":
		return total_stars()
	return int(profile.stats.get(stat, 0))


func achievement_state(id: String) -> Dictionary:
	if not profile.achievements.has(id):
		profile.achievements[id] = {"reached": 0, "claimed": 0}
	return profile.achievements[id]


func claim_achievement(id: String) -> bool:
	var a := DB.find_in(DB.meta.achievements, id)
	var st := achievement_state(id)
	if a.id == "star_collector":
		var tier := int(st.reached)
		while tier < a.tiers.size() and total_stars() >= int(a.tiers[tier]):
			tier += 1
		st.reached = tier
	if int(st.claimed) >= int(st.reached):
		return false
	grant_reward(a.reward[int(st.claimed)])
	st.claimed = int(st.claimed) + 1
	mark_dirty()
	return true


func ensure_daily_quests() -> void:
	var today := Time.get_date_string_from_system()
	if profile.quests.date == today:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today)
	var pool: Array = DB.meta.quests.duplicate()
	var list: Array = []
	for i in 4:
		var q: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		list.append({"id": q.id, "progress": 0, "claimed": false})
	profile.quests = {"date": today, "list": list}
	mark_dirty()


func claim_quest(id: String) -> bool:
	for q in profile.quests.list:
		if q.id == id and not q.claimed:
			var qd := DB.find_in(DB.meta.quests, id)
			if int(q.progress) >= int(qd.target):
				q.claimed = true
				grant_reward(qd.reward)
				return true
	return false


func grant_reward(r: Dictionary) -> void:
	if r.has("gold"): add_gold(int(r.gold))
	if r.has("gems"): add_gems(int(r.gems))
	if r.has("xp"): add_player_xp(int(r.xp))
	if r.has("material"): add_material(r.material, int(r.get("count", 1)))
	if r.has("chest"):
		var chest := DB.find_in(DB.meta.shop.chests, r.chest)
		for it in LootGenerator.open_chest(chest, int(profile.player_level)):
			add_item(it)
	mark_dirty()


func can_claim_daily() -> bool:
	return profile.daily.last != Time.get_date_string_from_system()


func daily_day_index() -> int:
	return int(profile.daily.streak) % DB.meta.daily_rewards.size()


func claim_daily() -> bool:
	if not can_claim_daily():
		return false
	var idx := daily_day_index()
	grant_reward(DB.meta.daily_rewards[idx])
	profile.daily.streak = int(profile.daily.streak) + 1
	profile.daily.last = Time.get_date_string_from_system()
	mark_dirty()
	return true


# ---------------------------------------------------------------- guild
func guild_bonus(stat: String) -> float:
	var t := 0.0
	for p in DB.meta.guild.perks:
		if p.stat == stat:
			t += float(p.per_level) * int(profile.guild.perks.get(p.id, 0))
	return t


func guild_xp_needed() -> int:
	return 3000 * int(profile.guild.level)


func guild_donate(amount: int) -> bool:
	if not spend({"gold": amount}):
		return false
	profile.guild.xp = int(profile.guild.xp) + amount
	while int(profile.guild.xp) >= guild_xp_needed():
		profile.guild.xp = int(profile.guild.xp) - guild_xp_needed()
		profile.guild.level = int(profile.guild.level) + 1
	Events.profile_changed.emit()
	return true


func guild_perk_points() -> int:
	var spent := 0
	for k in profile.guild.perks:
		spent += int(profile.guild.perks[k])
	return int(profile.guild.level) - 1 - spent


func guild_upgrade_perk(id: String) -> bool:
	if guild_perk_points() <= 0:
		return false
	profile.guild.perks[id] = int(profile.guild.perks.get(id, 0)) + 1
	Events.profile_changed.emit()
	mark_dirty()
	return true


# ---------------------------------------------------------------- settings
func setting(key: String, default = null):
	return profile.settings.get(key, default)


func set_setting(key: String, value) -> void:
	profile.settings[key] = value
	apply_settings()
	Events.settings_changed.emit()
	mark_dirty()


func apply_settings() -> void:
	Loc.set_language(profile.settings.lang)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.001, float(profile.settings.sfx))))
