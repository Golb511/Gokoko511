extends Node
## Loads every screen in sequence to catch runtime errors (used headless).

func _ready() -> void:
	for key in ["main_menu", "world_map", "heroes", "inventory", "shop", "missions", "achievements", "guild", "settings", "tower_tree"]:
		print("SMOKE: ", key)
		get_tree().change_scene_to_file(Router.SCENES[key])
		for i in 20:
			await get_tree().process_frame
	# exercise some logic
	Game.add_gold(100000)
	Game.add_gems(5000)
	for i in 6:
		Game.add_item(LootGenerator.roll_drop(5, 2.0))
	var it := LootGenerator.generate_equipment(5, 3, "weapon")
	Game.add_item(it)
	Game.equip("hell_knight", it.uid)
	Game.upgrade_item(it.uid)
	Game.add_item(LootGenerator.generate_socketable("gem"))
	var gems := Game.inventory().filter(func(x): return x.kind == "gem")
	if not gems.is_empty():
		print("socket: ", Game.socket_gem(it.uid, gems[0].uid))
	print("hero stats: ", Game.hero_stats("hell_knight"))
	print("power: ", Game.hero_power("hell_knight"))
	Game.quick_equip("hell_knight")
	Game.add_hero_xp("hell_knight", 2000)
	print("learn: ", Game.learn_skill("hell_knight", "brutality"))
	print("claim daily: ", Game.claim_daily())
	print("SMOKE DONE")
	get_tree().quit()
