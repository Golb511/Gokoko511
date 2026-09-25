extends Node3D
## Dev scene for visual tuning: a lit stage with heroes / enemies in a row.
## GAL = "heroes" | "heroes2" | "enemies" | "enemies2" | "<hero or enemy id>" (close-up).
## GAL_SHOT = output png; GAL_ANIM = logical animation (idle/attack/cast).

func _ready() -> void:
	if OS.get_environment("GAL_CLASSIC") == "1":
		Game.profile.settings["classic_characters"] = true
	var theme: Dictionary = DB.regions[int(OS.get_environment("GAL_REGION")) if OS.get_environment("GAL_REGION") != "" else 0].theme
	add_child(GraphicsSettings.make_environment(theme))
	add_child(GraphicsSettings.make_sun(theme))
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/ground.gdshader")
	m.set_shader_parameter("noise_tex", ModelLib.noise_tex("detail"))
	m.set_shader_parameter("cell_tex", ModelLib.noise_tex("cell"))
	m.set_shader_parameter("normal_tex", ModelLib.noise_tex("normal"))
	m.set_shader_parameter("color_a", Color(0.16, 0.13, 0.12))
	m.set_shader_parameter("color_b", Color(0.09, 0.07, 0.07))
	ground.material_override = m
	add_child(ground)
	var mode := OS.get_environment("GAL") if OS.get_environment("GAL") != "" else "heroes"
	var ids: Array = []
	var is_hero := true
	match mode:
		"heroes": ids = DB.hero_order.slice(0, 6)
		"heroes2": ids = DB.hero_order.slice(6, 12)
		"enemies", "enemies2":
			is_hero = false
			var all: Array = []
			for k in DB.enemies.keys():
				all.append(k)
			ids = all.slice(0, 7) if mode == "enemies" else all.slice(7, 14)
		_:
			ids = [mode]
			is_hero = DB.heroes.has(mode)
	if mode.begins_with("towers"):
		_towers(mode)
		return
	var spacing := 2.3
	var x0 := -spacing * (ids.size() - 1) * 0.5
	for i in ids.size():
		var def: Dictionary = DB.heroes[ids[i]].model if is_hero else DB.enemy(ids[i]).model
		if OS.get_environment("GAL_SHAPE") != "":
			def = def.duplicate()
			def["shape"] = OS.get_environment("GAL_SHAPE")
		if OS.get_environment("GAL_GEAR") != "":
			def = def.duplicate()
			def["gear"] = Array(OS.get_environment("GAL_GEAR").split(","))
		var c := ModelLib.character(def)
		add_child(c)
		c.position = Vector3(x0 + i * spacing, 0, 0)
		c.rotation.y = float(OS.get_environment("GAL_ROT")) if OS.get_environment("GAL_ROT") != "" else 0.35
		if c is CharacterModel and OS.get_environment("GAL_ANIM") != "":
			c.call_deferred("play_loop", OS.get_environment("GAL_ANIM"))
		var l := OmniLight3D.new()
		l.light_color = Color(1, 0.8, 0.6)
		l.light_energy = 1.6
		l.omni_range = 7.0
		l.position = c.position + Vector3(1.4, 3.0, 2.6)
		add_child(l)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	if ids.size() == 1:
		var fy := float(OS.get_environment("GAL_FOCUS")) if OS.get_environment("GAL_FOCUS") != "" else 1.0
		cam.position = Vector3(0, fy + 0.8, 3.2 + fy * 1.2)
		cam.look_at(Vector3(0, fy, 0))
	else:
		cam.position = Vector3(0, 3.2, 9.0 + ids.size() * 0.6)
		cam.look_at(Vector3(0, 0.9, 0))
	cam.current = true
	await get_tree().create_timer(float(OS.get_environment("GAL_WAIT")) if OS.get_environment("GAL_WAIT") != "" else 3.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("GAL_SHOT"))
	get_tree().quit()


func _towers(mode: String) -> void:
	var ids := ["archer", "mage", "artillery", "soldier", "poison", "fire", "ice", "lightning", "shadow", "light", "earth", "wind", "crossbow", "trap"]
	var lv := int(OS.get_environment("GAL_LEVEL")) if OS.get_environment("GAL_LEVEL") != "" else 3
	var br := int(OS.get_environment("GAL_BRANCH")) if OS.get_environment("GAL_BRANCH") != "" else -1
	var row := ids.slice(0, 7) if mode == "towers" else ids.slice(7, 14)
	for i in row.size():
		var acc := ModelLib._col(DB.towers[row[i]].model.accent)
		var g := GothicKit.tower(row[i], acc, lv, br, i * 7919)
		var n: Node3D = g.node
		add_child(n)
		n.position = Vector3(-10.5 + i * 3.5, 0, 0)
		n.rotation.y = 0.4
		var l := OmniLight3D.new()
		l.light_color = acc
		l.light_energy = 1.2
		l.omni_range = 5.0
		l.position = n.position + Vector3(0, float(g.top) + 0.6, 0)
		add_child(l)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 42
	cam.position = Vector3(0, 7.5, 17.0)
	cam.look_at(Vector3(0, 1.8, 0))
	cam.current = true
	await get_tree().create_timer(float(OS.get_environment("GAL_WAIT")) if OS.get_environment("GAL_WAIT") != "" else 3.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("GAL_SHOT"))
	get_tree().quit()
