extends Node
## E2E: after an autoplay battle, verify progression was recorded and that
## the save file round-trips.

func _ready() -> void:
	var inv_before := Game.inventory().size()
	var gold_before := Game.gold()
	Events.battle_ended.connect(func(victory, result):
		print("TEST victory=", victory, " stars=", Game.stage_stars("r1s1"), " r1s2_unlocked=", Game.is_stage_unlocked("r1s2"),
			" inv ", inv_before, "->", Game.inventory().size(), " gold ", gold_before, "->", Game.gold(),
			" hero_lvl=", Game.hero_state("hell_knight").level, " player_xp=", Game.profile.player_xp,
			" quests=", Game.profile.quests.list.map(func(q): return q.progress), " kills_stat=", Game.stat_value("kills"))
		Game.no_save = false
		Save.save_profile(Game.profile)
		var loaded := Save.load_profile()
		print("TEST save roundtrip stars=", loaded.stars, " inv=", loaded.inventory.size())
		Save.delete_save())
