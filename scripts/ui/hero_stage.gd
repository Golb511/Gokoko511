class_name HeroStage
extends Node3D
## Small lit 3D stage showing one character model (hero screen preview,
## inventory paper-doll, portraits). Dramatic rim light like the key art.

var model: CharacterModel
var camera: Camera3D
var turntable := false
var _rot := 0.0
var _floor: MeshInstance3D


func setup(model_def: Dictionary, portrait := false) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR if portrait else Environment.BG_COLOR
	e.background_color = Color(0.03, 0.02, 0.02)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.28, 0.25)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.glow_enabled = true
	e.glow_intensity = 0.4
	e.glow_hdr_threshold = 1.2
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.8
	key.light_color = Color(1.0, 0.85, 0.7)
	key.shadow_enabled = true
	add_child(key)
	var glow_c := ModelLib._col(model_def.get("emission", [1, 0.4, 0.1]))
	var rim := OmniLight3D.new()
	rim.light_volumetric_fog_energy = 0.2
	rim.position = Vector3(-1.4, 2.4, -2.0)
	rim.light_color = glow_c
	rim.light_energy = 2.6
	rim.omni_range = 6.0
	add_child(rim)
	var rim2 := OmniLight3D.new()
	rim2.light_volumetric_fog_energy = 0.2
	rim2.position = Vector3(1.6, 1.0, -1.2)
	rim2.light_color = glow_c.lerp(Color(1, 0.5, 0.2), 0.5)
	rim2.light_energy = 1.4
	rim2.omni_range = 5.0
	add_child(rim2)
	if not portrait:
		_floor = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.3
		cyl.bottom_radius = 1.4
		cyl.height = 0.12
		_floor.mesh = cyl
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.08, 0.07, 0.07)
		fm.roughness = 0.6
		fm.metallic = 0.4
		fm.normal_enabled = true
		fm.normal_texture = ModelLib.noise_tex("cell_normal")
		_floor.material_override = fm
		_floor.position.y = -0.06
		add_child(_floor)
		VFX.particles(self, Vector3(0, 0.5, 0), {"amount": 24, "lifetime": 3.0, "one_shot": false, "speed": 0.3, "size": 0.06, "color": glow_c, "box": Vector3(1.2, 0.5, 1.2), "gravity": Vector3(0, 0.4, 0), "explosiveness": 0.0})
	camera = Camera3D.new()
	camera.fov = 30.0
	add_child(camera)
	set_model(model_def)


func set_model(model_def: Dictionary) -> void:
	if model:
		model.queue_free()
	model = ModelLib.character(model_def)
	add_child(model)
	model.scale = Vector3.ONE * float(model_def.get("scale", 1.0))
	model.rotation.y = deg_to_rad(20)
	frame_full()


func frame_full() -> void:
	var s := model.scale.y if model else 1.0
	camera.transform = Transform3D(Basis(), Vector3(0, 1.15 * s, 6.2 * s)).looking_at(Vector3(0, 0.85 * s, 0), Vector3.UP)


func frame_portrait() -> void:
	var s := model.scale.y if model else 1.0
	camera.fov = 30.0
	camera.transform = Transform3D(Basis(), Vector3(0.35, 1.45 * s, 3.1 * s)).looking_at(Vector3(0, 1.15 * s, 0), Vector3.UP)
	model.rotation.y = deg_to_rad(15)


func _process(delta: float) -> void:
	if turntable and model:
		_rot += delta * 0.4
		model.rotation.y = deg_to_rad(20) + sin(_rot) * 0.6
