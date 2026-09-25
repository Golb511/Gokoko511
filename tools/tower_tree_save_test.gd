extends Node
## Two-process save/load test. TT_PHASE=write: reset profile, buy nodes, save.
## TT_PHASE=read: load the saved profile and verify the tree.

func _ready() -> void:
	await get_tree().process_frame
	if OS.get_environment("TT_PHASE") == "write":
		Game.reset_profile()
		Game.profile.player_level = 9
		TowerTree.award(30)
		for n in ["core_dmg", "core_rate", "core_range", "core_cost", "core_spec", "b1", "b2", "b3"]:
			TowerTree.buy("crossbow", n)
		TowerTree.buy("ice", "core_dmg")
		Game.save_now()
		print("TT_SAVE written owned=", TowerTree.owned("crossbow"), " avail=", TowerTree.available())
	else:
		var ok: bool = TowerTree.owned("crossbow").size() == 8 and TowerTree.has("ice", "core_dmg") and TowerTree.available() == 30 - 20 - 1
		print("TT_LOAD owned=", TowerTree.owned("crossbow"), " ice=", TowerTree.owned("ice"), " avail=", TowerTree.available(), (" TT_OK" if ok else " TT_FAIL"))
		var d := TowerTree.level_data("crossbow", 3, -1)
		print("TT_LOAD crossbow multishot=", d.get("multishot"), " special=", d.get("special", {}).get("type"))
		Game.reset_profile()
	get_tree().quit()
