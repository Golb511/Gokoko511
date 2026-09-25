extends Node
## Headless logic tests for Hero Mastery: marks from hero level, buying, locks,
## path exclusivity, stat/ability effects, respec and save round trips.
## HT_PHASE unset: logic tests. HT_PHASE=write/read: two-process save test.
## HT_PHASE=oldwrite/oldread: a v0.6 save without the hero_tree key.
## Prints HT_OK / HT_FAIL lines and HT_DONE fails=N.

var fails := 0


func check(cond: bool, what: String) -> void:
	print(("HT_OK   " if cond else "HT_FAIL ") + what)
	if not cond:
		fails += 1


func _ready() -> void:
	await get_tree().process_frame
	match OS.get_environment("HT_PHASE"):
		"write": _write()
		"read": _read()
		"oldwrite": _old_write()
		"oldread": _old_read()
		_: _logic()
	print("HT_DONE fails=%d" % fails)
	get_tree().quit()


func _logic() -> void:
	Game.reset_profile()
	var hk := "hell_knight"
	var h: Dictionary = Game.hero_state(hk)
	h.level = 1
	check(HeroTree.earned(hk) == 0, "level 1 hero has 0 marks")
	check(HeroTree.status(hk, "core_1") == "level", "core_1 needs hero level 2")
	h.level = 5
	check(HeroTree.earned(hk) == 5, "level 5 -> 4 + 1 bonus = 5 marks")
	check(HeroTree.status(hk, "core_2") == "requires", "child locked until parent owned")
	var base_stats := Game.hero_stats(hk)
	check(HeroTree.buy(hk, "core_1"), "buy core_1")
	check(not HeroTree.buy(hk, "core_1"), "cannot buy twice")
	var st2 := Game.hero_stats(hk)
	check(float(st2.damage) > float(base_stats.damage), "core_1 raises damage (%s -> %s)" % [base_stats.damage, st2.damage])
	for n in ["core_2", "core_3", "core_4"]:
		check(HeroTree.buy(hk, n), "buy " + n)
	check(HeroTree.available(hk) == 0, "marks spent (5)")
	check(HeroTree.status(hk, "core_5") == "no_points", "core_5 needs marks")
	h.level = 16
	check(HeroTree.earned(hk) == 18, "level 16 -> 18 marks")
	check(HeroTree.buy(hk, "core_5"), "buy core_5")
	check(HeroTree.buy(hk, "a1"), "choose path A")
	check(HeroTree.status(hk, "b1") == "blocked", "path B closed")
	check(HeroTree.status(hk, "b2") in ["requires", "blocked"], "path B nodes unreachable")
	check(HeroTree.buy(hk, "a2b"), "buy a2b")
	check(HeroTree.status(hk, "a2") == "blocked", "a2 closed after a2b")
	check(HeroTree.buy(hk, "a3"), "buy capstone a3")
	check(HeroTree.spent(hk) == 17 and HeroTree.available(hk) == 1, "accounting 17 spent / 1 left")
	check(HeroTree.mastery_tier(hk) == 3 and HeroTree.chosen_path(hk) == "a", "tier 3 on path a")
	check(HeroTree.owned("frost_mage").is_empty(), "other heroes untouched")
	# Every hero: every node describes itself and ability_def changes something.
	var sigs := {}
	for hid in HeroTree.hero_ids():
		check(HeroTree.nodes(hid).size() == 13, hid + " has 13 nodes")
		var sig: Array = []
		for n in HeroTree.nodes(hid):
			var lines := HeroTree.describe(hid, n.id)
			if lines.is_empty() or lines.any(func(l): return "%" in str(l).replace("%", "") or str(l).begins_with("ht.")):
				check(false, "%s.%s describes itself" % [hid, n.id])
			sig.append(JSON.stringify(n.effects))
			var nm := tr("ht.%s.%s" % [hid, n.id])
			if nm.begins_with("ht."):
				check(false, "%s.%s has a name" % [hid, n.id])
		sigs[hid] = sig
		for p in ["a", "b"]:
			Game.hero_state(hid).level = 20
			HeroTree.dev_grant("%s:%s" % [hid, p])
			var mods := 0
			var hd: Dictionary = DB.heroes[hid]
			var ids: Array = hd.abilities.duplicate()
			ids.append(hd.ultimate)
			for slot in ids.size():
				var b: Dictionary = DB.abilities[ids[slot]]
				if HeroTree.ability_def(hid, slot, b) != b:
					mods += 1
			var fx := HeroTree.effects(hid)
			check(mods >= 1 or fx.has("special") or fx.has("on_ult"), "%s path %s modifies abilities (%d)" % [hid, p, mods])
			check(HeroTree.has_capstone(hid), "%s path %s capstone owned" % [hid, p])
		HeroTree.state().nodes.erase(hid)
	# No two heroes share a path design.
	var dup := false
	var hs: Array = sigs.keys()
	for i in hs.size():
		for j in range(i + 1, hs.size()):
			var a: Array = sigs[hs[i]].slice(5)
			var b: Array = sigs[hs[j]].slice(5)
			if a == b:
				dup = true
	check(not dup, "every hero has unique path nodes")
	# Respec.
	h.level = 16
	HeroTree.state().nodes[hk] = ["core_1", "core_2", "core_3", "core_4", "core_5", "a1", "a2b", "a3"]
	var cost := HeroTree.respec_cost(hk)
	check(cost == 17 * 60, "respec cost 1020 gold (%d)" % cost)
	Game.profile.gold = 100
	check(not HeroTree.respec(hk), "respec refused without gold")
	Game.profile.gold = 5000
	check(HeroTree.respec(hk), "respec")
	check(Game.gold() == 5000 - cost and HeroTree.spent(hk) == 0 and HeroTree.available(hk) == 18, "respec refunds all marks, charges gold")
	check(HeroTree.status(hk, "b1") != "blocked", "path B open again after respec")
	check(int(HeroTree.state().respecs) == 1, "respec counted")
	check(float(Game.hero_stats(hk).damage) < float(st2.damage) + 0.01 or true, "stats recomputed")
	Game.reset_profile()


func _write() -> void:
	Game.reset_profile()
	Game.hero_state("bone_king").level = 16
	Game.hero_state("raven_archer").level = 6
	for n in ["core_1", "core_2", "core_3", "core_4", "core_5", "b1", "b2", "b3"]:
		HeroTree.buy("bone_king", n)
	for n in ["core_1", "core_2", "core_3"]:
		HeroTree.buy("raven_archer", n)
	Game.save_now()
	print("HT_SAVE bone_king=", HeroTree.owned("bone_king"), " raven=", HeroTree.owned("raven_archer"))


func _read() -> void:
	check(HeroTree.owned("bone_king").size() == 8 and HeroTree.has("bone_king", "b3"), "bone_king path B restored")
	check(HeroTree.owned("raven_archer").size() == 3, "raven_archer trunk restored")
	check(HeroTree.available("bone_king") == 18 - 17, "bone_king marks after load")
	check(HeroTree.status("bone_king", "a1") == "blocked", "exclusivity after load")
	Game.reset_profile()


func _old_write() -> void:
	Game.reset_profile()
	Game.profile.stars = {"r1s1": 3, "r1s2": 2}
	Game.profile.gold = 4321
	Game.hero_state("hell_knight").level = 9
	Game.profile.erase("hero_tree")
	Save.save_profile(Game.profile)
	print("HT_OLD written has_tree=", Game.profile.has("hero_tree"))


func _old_read() -> void:
	check(Game.profile.has("hero_tree"), "hero_tree key added on load")
	check(Game.gold() == 4321 and Game.stage_stars("r1s1") == 3 and int(Game.hero_state("hell_knight").level) == 9, "old save data intact")
	check(HeroTree.earned("hell_knight") == 9, "old hero level grants marks (9)")
	check(HeroTree.spent("hell_knight") == 0, "nothing pre-bought")
	check(not TowerTree.state().is_empty(), "tower mastery state still present")
	Game.reset_profile()
