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
	if OS.has_feature("movie") or "--battle" in OS.get_cmdline_user_args():
		Game.current_stage = "r1s1"
		Router.goto("battle")
	elif "--map" in OS.get_cmdline_user_args():
		Router.goto("world_map")
	else:
		var target := "main_menu"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--screen="):
				target = a.substr(9)
		Router.goto(target)
