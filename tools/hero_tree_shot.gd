extends Node
## Screenshot helper for the Hero Mastery screen.
## HT_NODES="core_1,core_2,a1" sets the owned nodes of the shown hero,
## HT_SEL=node selects a node, HT_BUY=node buys it (unlock FX) just before the shot.

func _ready() -> void:
	while not (get_tree().current_scene and get_tree().current_scene.has_method("select_node")):
		await get_tree().create_timer(0.2).timeout
	var scr = get_tree().current_scene
	await get_tree().create_timer(0.5).timeout
	var nodes := OS.get_environment("HT_NODES")
	if nodes != "":
		HeroTree.state().nodes[scr.hero_id] = Array(nodes.split(","))
		scr.rebuild_all()
		await get_tree().process_frame
	var sel := OS.get_environment("HT_SEL")
	if sel != "":
		scr.select_node(sel)
	var buy := OS.get_environment("HT_BUY")
	if buy != "":
		await get_tree().create_timer(float(OS.get_environment("HT_BUY_AT")) if OS.get_environment("HT_BUY_AT") != "" else 2.0).timeout
		scr.select_node(buy)
		scr._buy_selected()
		scr.select_node(buy)
	var out := OS.get_environment("HT_SHOT")
	if out != "":
		await get_tree().create_timer(float(OS.get_environment("HT_SHOT_AFTER")) if OS.get_environment("HT_SHOT_AFTER") != "" else 0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out)
		get_tree().quit()
