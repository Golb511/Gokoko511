extends Node
## Headless logic tests for Tower Mastery: buying, locks, exclusivity, effects,
## costs, respec, awards and save migration. Prints TT_OK / TT_FAIL lines.

var fails := 0


func check(cond: bool, what: String) -> void:
	print(("TT_OK   " if cond else "TT_FAIL ") + what)
	if not cond:
		fails += 1


func _ready() -> void:
	await get_tree().process_frame
	var p: Dictionary = Game.profile
	p.player_level = 1
	p.tower_tree = {"earned": 0, "nodes": {}, "respecs": 0, "init": true}
	check(TowerTree.available() == 0, "fresh profile has 0 sigils")
	check(TowerTree.status("archer", "core_dmg") == "no_points", "root node needs sigils")
	TowerTree.award(40)
	check(TowerTree.available() == 40, "award adds sigils")
	check(TowerTree.status("archer", "core_rate") == "requires", "child locked until parent owned")
	check(TowerTree.buy("archer", "core_dmg"), "buy root")
	check(not TowerTree.buy("archer", "core_dmg"), "cannot buy twice")
	check(TowerTree.buy("archer", "core_rate"), "buy core_rate")
	check(TowerTree.status("archer", "core_range") == "level", "core_range needs player level 2")
	p.player_level = 9
	for n in ["core_range", "core_cost", "core_spec", "a1"]:
		check(TowerTree.buy("archer", n), "buy " + n)
	check(TowerTree.status("archer", "b1") == "blocked", "path B closed after choosing path A")
	check(TowerTree.buy("archer", "a2"), "buy a2")
	check(TowerTree.status("archer", "a2b") == "blocked", "mid-tier alternative closed")
	check(TowerTree.status("archer", "a3") == "available", "capstone available after a2")
	check(TowerTree.buy("archer", "a3"), "buy capstone")
	check(TowerTree.spent_on("archer") == 20 and TowerTree.available() == 20, "points accounting (20 spent)")
	check(TowerTree.mastery_tier("archer") == 3 and TowerTree.has_capstone("archer"), "mastery tier 3")
	# Effects on stats.
	var base: Dictionary = DB.tower_level_data("archer", 3, -1)
	var mod: Dictionary = TowerTree.level_data("archer", 3, -1)
	var dm := float(mod.dmg[0]) / float(base.dmg[0])
	check(absf(dm - 1.18) < 0.01, "archer damage x1.18 (core + eagle eye + death mark) got %.2f" % dm)
	check(absf(float(mod.range) / float(base.range) - 1.15) < 0.01, "archer range x1.15")
	check(absf(float(mod.rate) / float(base.rate) - 1.05) < 0.01, "archer rate x1.05")
	check(absf(float(mod.crit) - 0.09) < 0.001 and absf(float(mod.crit_mult) - 2.3) < 0.001, "heartseeker crit 9pct x2.3")
	check(absf(float(mod.pen) - 0.15) < 0.001, "barbed heads 15pct armour pierce")
	check(float(mod.execute) >= 0.05 and (mod.extra_status as Array).any(func(s): return s.id == "marked"), "death mark: execute + mark status")
	check(base.get("crit", null) == null and base.get("pen", null) == null, "DB data untouched (copy-on-write)")
	check(TowerTree.build_cost("archer") == 63, "build cost 70 -> 63 with Guild Contracts")
	check(TowerTree.build_cost("mage") == int(DB.towers.mage.levels[0].cost), "other towers unaffected")
	# Every tower: full path A and B produce valid data at every level/branch.
	var ok_all := true
	for tid in TowerTree.tower_ids():
		for spec in ["a", "b", "a2b", "b2b"]:
			TowerTree.dev_grant("%s:%s" % [tid, spec])
			for lv in range(1, DB.tower_max_level(tid) + 1):
				for br in [-1, 0, 1]:
					if lv <= 3 and br >= 0:
						continue
					var d := TowerTree.level_data(tid, lv, br)
					if not d.get("mastery", false) or float(d.get("rate", 1.0)) <= 0.0:
						ok_all = false
						print("  bad data ", tid, " ", spec, " ", lv, " ", br)
			var desc_ok := true
			for n in TowerTree.nodes(tid):
				if TowerTree.describe(tid, n.id).is_empty():
					desc_ok = false
					print("  no description ", tid, " ", n.id)
			ok_all = ok_all and desc_ok
	check(ok_all, "all 14 towers x 4 path choices x all levels produce valid stats and descriptions")
	p.tower_tree.nodes.clear()
	p.tower_tree.earned = 40
	for n in ["core_dmg", "core_rate", "core_range", "core_cost", "core_spec", "b1", "b2b", "b3"]:
		TowerTree.buy("mage", n)
	check(TowerTree.spent_on("mage") == 20, "mage path B bought")
	# Respec
	var gold_before := Game.gold()
	var cost := TowerTree.respec_cost("mage")
	check(cost == 20 * 40, "respec cost 40 gold per sigil (%d)" % cost)
	Game.add_gold(-Game.gold() + cost - 1)
	check(not TowerTree.respec("mage"), "respec refused without gold")
	Game.add_gold(1)
	check(TowerTree.respec("mage") and Game.gold() == 0, "respec pays gold")
	check(TowerTree.owned("mage").is_empty() and TowerTree.available() == 40, "respec refunds all sigils")
	check(TowerTree.status("mage", "a1") != "blocked", "path choice reopened after respec")
	Game.add_gold(gold_before)
	# Migration of an old save: stars + boss + achievements.
	var old := {"stars": {"r1s1": 3, "r1s2": 2, "r1s4": 1}, "achievements": {"first_blood": {"reached": 2, "claimed": 2}}, "endless_best": 23}
	var saved := Game.profile
	Game.profile = old
	var s := TowerTree.state()
	var expect := (1 + 3) + (1 + 2) + (1 + 1 + 2) + 2 + 2
	check(int(s.earned) == expect, "old save migration grants %d sigils (got %d)" % [expect, int(s.earned)])
	Game.profile = saved
	# Save round-trip through JSON (as the save system does).
	TowerTree.buy("archer", "core_dmg")
	var round: Dictionary = JSON.parse_string(JSON.stringify(Game.profile))
	check(round.tower_tree.nodes.has("archer") and "core_dmg" in round.tower_tree.nodes.archer, "tree survives JSON save round-trip")
	print("TT_DONE fails=%d" % fails)
	get_tree().quit()
