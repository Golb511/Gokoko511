extends Node3D
## Dev scene: shows characters/towers close-up for visual tuning (screenshots).

func _ready() -> void:
	var theme: Dictionary = DB.regions[0].theme
	add_child(GraphicsSettings.make_environment(theme))
	add_child(GraphicsSettings.make_sun(theme))
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/ground.gdshader")
	m.set_shader_parameter("noise_tex", ModelLib.noise_tex("detail"))
	m.set_shader_parameter("cell_tex", ModelLib.noise_tex("cell"))
	m.set_shader_parameter("normal_tex", ModelLib.noise_tex("normal"))
	m.set_shader_parameter("color_a", Color(0.16, 0.13, 0.12))
	m.set_shader_parameter("color_b", Color(0.09, 0.07, 0.07))
	m.set_shader_parameter("lava", 1.0)
	ground.material_override = m
	add_child(ground)
	var x := -6.0
	for id in ["hell_knight", "poison_sorcerer", "raven_archer", "bone_king", "giant_executioner", "stone_beast"]:
		var c := ModelLib.character(DB.heroes[id].model)
		add_child(c)
		c.position = Vector3(x, 0, 0)
		c.rotation.y = 0.3
		x += 2.4
	x = -6.0
	for id in ["skeleton_minion", "skeleton_warrior", "skeleton_archer", "bone_mage", "winged_fiend", "ash_brute"]:
		var c := ModelLib.character(DB.enemy(id).model)
		add_child(c)
		c.position = Vector3(x, 2.6 if id == "winged_fiend" else 0.0, -3)
		x += 2.4
	x = -8.0
	for tid in ["archer", "mage", "artillery", "soldier", "lightning", "shadow"]:
		var holder := Node3D.new()
		add_child(holder)
		holder.position = Vector3(x, 0, -8)
		var p := ModelLib.prop(DB.towers[tid].model.base, Color(0.42, 0.38, 0.36), ModelLib._col(DB.towers[tid].model.accent), 0.8)
		holder.add_child(p)
		p.scale = Vector3.ONE * 1.6
		x += 3.4
	VFX.torch_flame(self, Vector3(-9, 0.5, 2))
	var d := ProceduralCreatures.dragon(0.9)
	add_child(d)
	d.position = Vector3(3.5, 3.2, 2)
	d.rotation.y = -1.2
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 45
	cam.position = Vector3(0, 5.5, 9.5)
	cam.look_at(Vector3(0, 1.0, -3))
	cam.current = true
