extends Node
## Captures the hero's animations inside a real battle (for model reviews):
## idle, run, attack, ability (slot AS_SLOT), hit and death. The camera sits in
## front of the hero at AS_DIST / AS_PITCH. Output: AS_OUT_<name>.png

func _ready() -> void:
	while not (get_tree().current_scene is BattleController):
		await get_tree().process_frame
	var b = get_tree().current_scene
	await get_tree().create_timer(1.0).timeout
	var h: Hero = b.hero
	h.auto_mode = false
	var rig = b.camera_rig
	rig.follow = h
	rig.distance = float(OS.get_environment("AS_DIST")) if OS.get_environment("AS_DIST") != "" else 5.5
	rig.pitch = deg_to_rad(float(OS.get_environment("AS_PITCH")) if OS.get_environment("AS_PITCH") != "" else 16.0)
	var out := OS.get_environment("AS_OUT")
	h.model.rotation.y = 0.0
	# Spawn a few enemies in front so attacks and abilities have targets.
	var fwd := Vector3(0, 0, -3.0)
	await _hold(h, rig, 1.2)
	await _snap(out + "_idle.png")
	# Run (in place, facing the camera).
	h.model.play_loop("run")
	await _hold(h, rig, 0.5)
	await _snap(out + "_run.png")
	h.model.play_loop("idle")
	await _hold(h, rig, 0.6)
	h.model.play_action("attack", 1.0)
	await _hold(h, rig, 0.28)
	await _snap(out + "_attack.png")
	await _hold(h, rig, 0.9)
	h.model.play_action("special", 1.0)
	await _hold(h, rig, 0.35)
	await _snap(out + "_attack2.png")
	await _hold(h, rig, 0.9)
	h.energy = h.max_energy
	var slot := int(OS.get_environment("AS_SLOT")) if OS.get_environment("AS_SLOT") != "" else 0
	h.cooldowns[slot] = 0.0
	h.cast(slot, h.global_position + h.model.global_transform.basis.z * 3.0)
	await _hold(h, rig, 0.3)
	await _snap(out + "_ability.png")
	await _hold(h, rig, 1.5)
	h.energy = h.max_energy
	h.cooldowns[4] = 0.0
	h.cast(4, h.global_position + h.model.global_transform.basis.z * 4.0)
	await _hold(h, rig, 0.45)
	await _snap(out + "_ultimate.png")
	await _hold(h, rig, 1.5)
	h.model.play_action("hit", 1.0)
	h.model.flash()
	await _hold(h, rig, 0.12)
	await _snap(out + "_hit.png")
	await _hold(h, rig, 1.0)
	h._revive_used = true
	h.take_damage(h.hp + 99999.0, "true", null)
	await _hold(h, rig, 1.1)
	await _snap(out + "_death.png")
	print("AS_DONE")
	get_tree().quit()


func _hold(h: Hero, rig, t: float) -> void:
	var e := 0.0
	while e < t:
		await get_tree().process_frame
		e += get_process_delta_time()
		if h.model and h.alive:
			h.moving = false
			h.model.face_instant(rig.camera.global_position)


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
