extends Node
## Visual showcase inside a real battle (for screenshots): builds towers on the
## stage's slots (SC_TOWERS="archer:3,mage:4a,..." or every tower type), starts
## the waves after SC_START seconds, frames the camera (SC_CAM = "x,z,dist" or
## "tower:N" / "hero") and saves SC_SHOT after SC_WAIT seconds.

func _ready() -> void:
	if OS.get_environment("SC_NOFOG") == "1":
		Game.profile.settings["fog"] = false
	while not (get_tree().current_scene is BattleController):
		await get_tree().process_frame
	var b = get_tree().current_scene
	await get_tree().create_timer(0.8).timeout
	b.gold = 999999
	var spec := OS.get_environment("SC_TOWERS")
	var list: Array = []
	if spec == "":
		var ids := ["archer", "mage", "artillery", "soldier", "poison", "fire", "ice", "lightning", "shadow", "light", "earth", "wind", "crossbow", "trap"]
		for i in ids.size():
			list.append("%s:%s" % [ids[i], ["1", "2", "3", "4a", "4b"][i % 5]])
	else:
		list = Array(spec.split(","))
	var built: Array = []
	for i in mini(list.size(), b.slots.size()):
		var kv: PackedStringArray = str(list[i]).split(":")
		var t = b.build_tower(b.slots[i], kv[0])
		if t == null:
			continue
		built.append(t)
		var lv: String = kv[1] if kv.size() > 1 else "1"
		for k in mini(2, int(lv[0]) - 1):
			b.upgrade_tower(t)
		if lv.length() > 1:
			b.upgrade_tower(t, 0 if lv[1] == "a" else 1)
			if int(lv[0]) >= 5:
				b.upgrade_tower(t)
	var start := float(OS.get_environment("SC_START")) if OS.get_environment("SC_START") != "" else -1.0
	if start >= 0.0:
		await get_tree().create_timer(start).timeout
		b.waves.start_next_wave()
	var cam := OS.get_environment("SC_CAM")
	var rig = b.camera_rig
	if cam.begins_with("tower:") and built.size() > int(cam.substr(6)):
		rig.follow = null
		rig.focus_on(built[int(cam.substr(6))].global_position)
		rig.distance = float(OS.get_environment("SC_DIST")) if OS.get_environment("SC_DIST") != "" else 12.0
	elif cam == "castle":
		rig.follow = null
		rig.focus_on(b.level.castle_pos + Vector3(0, 0, 0))
		rig.distance = float(OS.get_environment("SC_DIST")) if OS.get_environment("SC_DIST") != "" else 20.0
	elif cam == "hero":
		if OS.get_environment("SC_PITCH") != "":
			rig.pitch = deg_to_rad(float(OS.get_environment("SC_PITCH")))
		rig.follow = b.hero
		rig.distance = float(OS.get_environment("SC_DIST")) if OS.get_environment("SC_DIST") != "" else 10.0
	elif cam != "":
		var p := cam.split(",")
		rig.follow = null
		rig.focus_on(Vector3(float(p[0]), 0, float(p[1])))
		if p.size() > 2:
			rig.distance = float(p[2])
	var wait := float(OS.get_environment("SC_WAIT")) if OS.get_environment("SC_WAIT") != "" else 3.0
	var face_cam := OS.get_environment("SC_FACE") == "1"
	var t := 0.0
	while t < wait:
		await get_tree().process_frame
		t += get_process_delta_time()
		if face_cam and b.hero:
			# Keep the camera in front of the hero (rig yaw follows the hero's facing).
			var m: Node3D = b.hero.model
			if m:
				rig.rotation.y = lerp_angle(rig.rotation.y, m.global_rotation.y, 0.08)
	var shots := int(OS.get_environment("SC_SHOTS")) if OS.get_environment("SC_SHOTS") != "" else 1
	for i in shots:
		await RenderingServer.frame_post_draw
		var path := OS.get_environment("SC_SHOT")
		if shots > 1:
			path = path.replace(".png", "_%d.png" % i)
		get_viewport().get_texture().get_image().save_png(path)
		var t2 := 0.0
		while t2 < float(OS.get_environment("SC_GAP")) if OS.get_environment("SC_GAP") != "" else 1.0:
			await get_tree().process_frame
			t2 += get_process_delta_time()
			if face_cam and b.hero and b.hero.model:
				rig.rotation.y = lerp_angle(rig.rotation.y, b.hero.model.global_rotation.y, 0.08)
	print("SC_SHOT saved towers=", built.size())
	get_tree().quit()
	return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SC_SHOT"))
	print("SC_SHOT saved towers=", built.size())
	get_tree().quit()
