extends Node
## Old-save compatibility: TT_PHASE=write stores a v0.5-style profile (no
## tower_tree key, some stars/achievements); TT_PHASE=read loads it and checks
## that retroactive sigils were granted and nothing else changed.

func _ready() -> void:
	await get_tree().process_frame
	if OS.get_environment("TT_PHASE") == "write":
		Game.reset_profile()
		Game.profile.stars = {"r1s1": 3, "r1s2": 3, "r1s3": 2, "r1s4": 2, "r2s1": 1}
		Game.profile.gold = 12345
		Game.profile.erase("tower_tree")
		Save.save_profile(Game.profile)
		print("TT_OLD written keys=", Game.profile.keys().size(), " has_tree=", Game.profile.has("tower_tree"))
		get_tree().quit()
		return
	var expect := (1 + 3) + (1 + 3) + (1 + 2) + (1 + 2 + 2) + (1 + 1)
	var s := TowerTree.state()
	var ok: bool = int(s.earned) == expect and Game.gold() == 12345 and Game.stage_stars("r1s4") == 2 and TowerTree.spent() == 0
	print("TT_OLD loaded earned=%d expect=%d gold=%d %s" % [int(s.earned), expect, Game.gold(), "TT_OK" if ok else "TT_FAIL"])
	Game.reset_profile()
	get_tree().quit()
