extends Node
## Battle screenshot helper for Hero Mastery: waits until the hero's mastery
## effect HM_KEY (a key of Hero.mastery_log, e.g. "avatar", "kill_raise",
## "special_nova") has fired HM_COUNT times, waits HM_AFTER seconds, frames the
## camera on the hero and saves HM_SHOT. Gives up after HM_TIMEOUT seconds.

func _ready() -> void:
	while not (get_tree().current_scene is BattleController):
		await get_tree().process_frame
	var b = get_tree().current_scene
	var key := OS.get_environment("HM_KEY")
	var need := int(OS.get_environment("HM_COUNT")) if OS.get_environment("HM_COUNT") != "" else 1
	var limit := float(OS.get_environment("HM_TIMEOUT")) if OS.get_environment("HM_TIMEOUT") != "" else 240.0
	var t0 := Time.get_ticks_msec()
	while b.hero == null or int(b.hero.mastery_log.get(key, 0)) < need:
		await get_tree().process_frame
		if (Time.get_ticks_msec() - t0) / 1000.0 > limit or b.ended:
			print("HM_SHOT timeout ", key, " log=", b.hero.mastery_log if b.hero else {})
			get_tree().quit()
			return
	b.camera_rig.follow = b.hero
	b.camera_rig.focus_on(b.hero.global_position)
	if OS.get_environment("HM_ZOOM") != "":
		b.camera_rig.distance *= float(OS.get_environment("HM_ZOOM"))
	await get_tree().create_timer(float(OS.get_environment("HM_AFTER")) if OS.get_environment("HM_AFTER") != "" else 0.3, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("HM_SHOT"))
	print("HM_SHOT saved ", key, " log=", b.hero.mastery_log)
	get_tree().quit()
