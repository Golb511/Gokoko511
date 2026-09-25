class_name KeyArtScene
extends Node3D
## Main-menu diorama recreating the key art: heroes on a burning cliff,
## a dark citadel behind them and the colossal Shadow Crown overlord.

var camera: Camera3D
var _t := 0.0


func _ready() -> void:
	var theme := {"sky_top": [0.02, 0.015, 0.03], "sky_horizon": [0.35, 0.12, 0.06], "fog": [0.2, 0.1, 0.08], "ambient": [0.18, 0.15, 0.2], "sun": [0.9, 0.75, 0.7], "sun_energy": 0.7}
	var we := GraphicsSettings.make_environment(theme)
	we.environment.fog_density = 0.012
	add_child(we)
	var sun := GraphicsSettings.make_sun(theme)
	sun.rotation_degrees = Vector3(-25, 160, 0)
	add_child(sun)
	# Ground cliff
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = load("res://assets/shaders/ground.gdshader")
	gm.set_shader_parameter("noise_tex", ModelLib.noise_tex("detail"))
	gm.set_shader_parameter("cell_tex", ModelLib.noise_tex("cell"))
	gm.set_shader_parameter("normal_tex", ModelLib.noise_tex("normal"))
	gm.set_shader_parameter("color_a", Color(0.1, 0.085, 0.08))
	gm.set_shader_parameter("color_b", Color(0.05, 0.04, 0.04))
	gm.set_shader_parameter("lava", 1.0)
	ground.material_override = gm
	add_child(ground)
	for i in 5:
		var rock := ModelLib.prop("env/mountain_" + ["A", "B", "C"][i % 3], Color(0.22, 0.2, 0.2))
		add_child(rock)
		rock.position = Vector3(-6 + i * 3.0, -0.9, 1.5 + (i % 2) * 0.6)
		rock.scale = Vector3(3.5, 1.1, 3.0)
	# Citadel and spires
	var castle := ModelLib.prop("env/building_castle_red", Color(0.28, 0.25, 0.26), Color(1, 0.4, 0.1), 0.6)
	add_child(castle)
	castle.position = Vector3(0, 0, -16)
	castle.scale = Vector3.ONE * 5.0
	for x in [-11.0, -7.0, 7.0, 11.0]:
		var sp := ModelLib.prop("env/building_tower_B_red", Color(0.25, 0.23, 0.24))
		add_child(sp)
		sp.position = Vector3(x, 0, -14 - absf(x) * 0.3)
		sp.scale = Vector3.ONE * (3.4 - absf(x) * 0.1)
	for x in [-20.0, -16.0, 15.0, 19.0]:
		var m := ModelLib.prop("env/mountain_" + ["A", "B", "C"][int(absf(x)) % 3], Color(0.18, 0.16, 0.17))
		add_child(m)
		m.position = Vector3(x, 0, -24)
		m.scale = Vector3(11, 9, 9)
	# The colossal overlord behind the citadel.
	var lord := ModelLib.character({"base": "Knight", "show": ["2H_Sword", "Knight_Helmet", "Knight_Cape"], "tint": [0.08, 0.07, 0.1], "emission": [1.0, 0.35, 0.05], "emission_strength": 3.5, "metal": 0.9, "anim": "2h", "scale": 1.0})
	add_child(lord)
	lord.position = Vector3(0, -2, -34)
	lord.scale = Vector3.ONE * 13.0
	lord.play_loop("idle", 0.4)
	for s in [-1.0, 1.0]:
		VFX.fire_pillar(self, Vector3(9.5 * s, 11, -30), 5.0, true)
		var l := OmniLight3D.new()
		l.light_volumetric_fog_energy = 0.2
		l.light_color = Color(1, 0.45, 0.1)
		l.light_energy = 8.0
		l.omni_range = 26.0
		add_child(l)
		l.position = Vector3(9.5 * s, 13, -28)
	# Heroes lineup
	var ids := ["raven_archer", "poison_sorcerer", "hell_knight", "frost_mage", "bone_king"]
	for i in ids.size():
		var def: Dictionary = DB.heroes[ids[i]].model.duplicate()
		var c := ModelLib.character(def)
		add_child(c)
		var x := (i - 2) * 1.7
		c.position = Vector3(x * 1.1, 0.15, 0.6 - absf(i - 2) * 0.45)
		c.rotation.y = -x * 0.12
		c.scale *= 1.25 if i == 2 else 1.0
		c.play_loop("idle", 0.8 + randf() * 0.3)
		var rim := OmniLight3D.new()
		rim.light_volumetric_fog_energy = 0.2
		rim.light_color = ModelLib._col(def.emission)
		rim.light_energy = 3.0
		rim.omni_range = 3.5
		add_child(rim)
		rim.position = c.position + Vector3(0, 1.8, -1.0)
	for s in [-1.0, 1.0]:
		VFX.torch_flame(self, Vector3(5.0 * s, 0.4, 1.0), Color(1, 0.5, 0.15))
		var bra := ModelLib.prop("graveyard/lantern_standing", Color(0.3, 0.28, 0.26))
		add_child(bra)
		bra.position = Vector3(5.0 * s, 0, 1.0)
		bra.scale = Vector3.ONE * 1.6
	VFX.ambient(self, "embers", Vector3(0, 3, -5), Vector3(20, 4, 12))
	camera = Camera3D.new()
	camera.fov = 48.0
	add_child(camera)
	camera.current = true
	_update_camera()


func _process(delta: float) -> void:
	_t += delta
	_update_camera()


func _update_camera() -> void:
	camera.position = Vector3(sin(_t * 0.08) * 0.8, 2.1 + sin(_t * 0.13) * 0.1, 10.5)
	camera.look_at(Vector3(0, 2.9, -8))
