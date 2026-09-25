extends Node
## Entry point: applies the global theme and graphics settings, then opens the main menu.


func _ready() -> void:
	get_tree().root.theme = UITheme.get_theme()
	get_tree().root.content_scale_factor = 1.0
	GraphicsSettings.apply_window()
	# Warm-up caches used everywhere (noise textures generate in the background).
	for k in ["detail", "normal", "cell", "cell_normal"]:
		ModelLib.noise_tex(k)
	await get_tree().process_frame
	var stage := "r1s1"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stage="):
			stage = a.substr(8)
		elif a.begins_with("--hero="):
			var hid := a.substr(7)
			Game.profile.heroes[hid].unlocked = true
			Game.profile.selected_hero = hid
		elif a.begins_with("--hero-level="):
			for h in Game.profile.heroes.values():
				h.level = int(a.substr(13))
		elif a.begins_with("--player-level="):
			Game.profile.player_level = int(a.substr(15))
		elif a.begins_with("--sigils="):
			TowerTree.state().earned = TowerTree.earned() + int(a.substr(9))
		elif a.begins_with("--hero-tree="):
			# Dev/balance: grant hero mastery setups, e.g. "a", "b", "hell_knight:a"
			HeroTree.dev_grant(a.substr(12))
		elif a.begins_with("--tower-tree="):
			# Dev/balance: grant mastery setups, e.g. "a", "b", "trunk", "archer:a,mage:b"
			TowerTree.dev_grant(a.substr(13))
	if "--battle" in OS.get_cmdline_user_args():
		Game.current_stage = stage
		Router.goto("battle")
	elif "--map" in OS.get_cmdline_user_args():
		Router.goto("world_map")
	else:
		var target := "main_menu"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--screen="):
				target = a.substr(9)
		Router.goto(target)
