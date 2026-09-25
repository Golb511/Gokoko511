class_name Atmosphere
extends RefCounted
## Per-stage atmosphere dressing driven by theme keys: moon, ground mist,
## fireflies, torch-lined roads, lightning storms, circling ravens, a distant
## gothic castle, reflective water pools and flyer portals.

static func build(lb: LevelBuilder, theme: Dictionary) -> void:
	var root := lb.root
	var b := lb.bounds
	var center := Vector3(b.get_center().x, 0, b.get_center().y)
	if theme.has("moon"):
		moon(root, _v3(theme.moon))
	if theme.get("mist", false):
		mist(root, center, b, ModelLib._col(theme.get("fog", [0.12, 0.12, 0.18])))
	if theme.get("fireflies", false):
		VFX.particles(root, center + Vector3(0, 1.2, 0), {"amount": 90, "lifetime": 5.0, "one_shot": false, "speed": 0.35,
			"size": 0.08, "size_end": 0.9, "color": Color(0.7, 1.0, 0.55), "box": Vector3(b.size.x * 0.5, 1.0, b.size.y * 0.5),
			"gravity": Vector3(0, 0.05, 0), "explosiveness": 0.0})
	if theme.has("road_torches"):
		road_torches(lb, theme.road_torches)
	if theme.get("lightning", false):
		var s := LightningStorm.new()
		root.add_child(s)
		s.setup(lb, ModelLib._col(theme.get("sky_horizon", [0.4, 0.2, 0.6])).lightened(0.4))
	if theme.has("ravens"):
		var rv: Dictionary = theme.ravens
		for i in int(rv.count):
			var c := RavenCircler.new()
			root.add_child(c)
			c.setup(Vector3(float(rv.center[0]), float(rv.get("height", 9.0)), float(rv.center[1])), float(rv.radius), TAU * i / float(rv.count))
	if theme.has("backdrop_castle"):
		backdrop_castle(root, theme.backdrop_castle)


static func _v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func moon(root: Node3D, pos: Vector3) -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
uniform sampler2D noise_tex : hint_default_white, repeat_enable;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, 1, 0), vec4(0, 0, 0, 1));
}
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float disc = smoothstep(0.52, 0.49, r);
	float n = texture(noise_tex, UV * 1.3).r;
	float craters = smoothstep(0.45, 0.62, texture(noise_tex, UV * 3.1 + 0.4).r);
	vec3 moon = vec3(0.86, 0.9, 1.0) * (0.75 + 0.35 * n) * (1.0 - craters * 0.25);
	float halo = pow(max(0.0, 1.0 - r), 3.0) * 0.55;
	ALBEDO = moon * disc + vec3(0.55, 0.65, 1.0) * halo * (1.0 - disc);
	ALPHA = clamp(disc + halo, 0.0, 1.0);
	EMISSION = ALBEDO * 1.6;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("noise_tex", ModelLib.noise_tex("detail"))
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(26, 26)
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.global_position = pos


static func mist(root: Node3D, center: Vector3, b: Rect2, fog: Color) -> void:
	var c := fog.lightened(0.35)
	c.a = 1.0
	var e := VFX.particles(root, center + Vector3(0, 0.5, 0), {"amount": 46, "lifetime": 14.0, "one_shot": false, "speed": 0.25,
		"size": 9.0, "size_end": 1.0, "color": c, "additive": false, "box": Vector3(b.size.x * 0.55, 0.3, b.size.y * 0.55),
		"gravity": Vector3(0.12, 0.0, 0.05), "direction": Vector3(1, 0, 0), "spread": 40.0, "end_alpha": 0.0, "explosiveness": 0.0})
	# Very low alpha so the mist hugs the ground without hiding gameplay.
	var g := Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, 0.0))
	g.add_point(0.3, Color(c.r, c.g, c.b, 0.16))
	g.add_point(0.7, Color(c.r, c.g, c.b, 0.12))
	g.set_color(g.get_point_count() - 1, Color(c.r, c.g, c.b, 0.0))
	e.color_ramp = g
	e.preprocess = 10.0


static func road_torches(lb: LevelBuilder, cfg: Dictionary) -> void:
	var col := ModelLib._col(cfg.get("color", [1.0, 0.5, 0.15]))
	var spacing := float(cfg.get("spacing", 10.0))
	var lights := 0
	var max_lights := 14 if GraphicsSettings.quality() >= 2 else 6
	var side := 1.0
	for r in lb.ground_routes():
		var off := 6.0
		while off < r.length - 7.0:
			var p := r.sample(off)
			var d := r.direction(off)
			var n := Vector3(-d.z, 0, d.x) * side
			var pos := p + n * 2.9
			side = -side
			off += spacing
			if not lb._free(pos, 0.6):
				continue
			if cfg.get("style", "") == "brazier":
				Inferno.brazier(lb, pos, col, lights < max_lights)
				lights += 1
				lb._occupied.append([pos, 0.9])
				continue
			var post := lb._place("graveyard/lantern_standing", pos, 1.35, atan2(-n.x, -n.z), Color(0.28, 0.26, 0.26))
			post.name = "RoadTorch"
			var with_light := lights < max_lights
			if with_light:
				lights += 1
			VFX.torch_flame(lb.root, pos + Vector3(0, 1.38, 0), col, with_light)
			lb._occupied.append([pos, 0.9])


static func water_pool(root: Node3D, p: Vector3, radius: float, rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.04
	cyl.radial_segments = 40
	mi.mesh = cyl
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/water.gdshader")
	m.set_shader_parameter("noise_tex", ModelLib.noise_tex("detail"))
	m.set_shader_parameter("normal_tex", ModelLib.noise_tex("normal"))
	mi.material_override = m
	mi.scale = Vector3(1, 1, rng.randf_range(0.65, 1.0))
	mi.rotation.y = rng.randf() * TAU
	root.add_child(mi)
	mi.global_position = p + Vector3(0, 0.025, 0)
	# Reeds and rocks around the shore.
	for k in 7:
		var a := rng.randf() * TAU
		var sp := p + Vector3(cos(a), 0, sin(a) * mi.scale.z) * radius * rng.randf_range(0.95, 1.15)
		var key: String = ["env/rock_single_A", "env/rock_single_B", "env/rock_single_C"][k % 3]
		var r := ModelLib.prop(key, Color(0.16, 0.17, 0.19))
		root.add_child(r)
		r.global_position = sp
		r.scale = Vector3.ONE * rng.randf_range(0.8, 1.5)
		r.rotation.y = rng.randf() * TAU


static func air_portal(root: Node3D, r: PathRoute) -> void:
	var p := r.sample(0.0) + Vector3(0, 4.0, 0)
	var col := Color(0.6, 0.2, 1.0)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.8
	tm.outer_radius = 2.1
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 4.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	ring.rotation.x = PI / 2
	root.add_child(ring)
	ring.global_position = p
	var spin := ring.create_tween().set_loops()
	spin.tween_property(ring, "rotation:y", TAU, 5.0).from(0.0)
	var e := VFX.particles(root, p, {"amount": 70, "lifetime": 1.6, "one_shot": false, "speed": 1.2, "size": 0.7, "color": col, "radius": 1.6, "gravity": Vector3(0, 0, 0), "explosiveness": 0.0})
	e.flatness = 0.8
	var l := OmniLight3D.new()
	l.light_volumetric_fog_energy = 0.2
	l.light_color = col
	l.light_energy = 4.0
	l.omni_range = 12.0
	root.add_child(l)
	l.global_position = p


static func backdrop_castle(root: Node3D, cfg: Dictionary) -> void:
	var p := Vector3(float(cfg.pos[0]), 0, float(cfg.pos[1]))
	var acc := ModelLib._col(cfg.get("accent", [0.8, 0.25, 1.0]))
	var tint := Color(0.2, 0.18, 0.23)
	var c := ModelLib.prop("env/building_castle_red", tint, acc, 1.6)
	root.add_child(c)
	c.global_position = p
	c.scale = Vector3.ONE * 9.0
	for s in [-1.0, 1.0]:
		for k in 2:
			var t := ModelLib.prop("env/building_tower_B_red", tint, acc, 1.4)
			root.add_child(t)
			t.global_position = p + Vector3(s * (16 + k * 11), 0, 6 + k * 5)
			t.scale = Vector3.ONE * (6.5 - k * 1.2)
	# Glowing windows / soul fire.
	for k in 9:
		var l := OmniLight3D.new()
		l.light_volumetric_fog_energy = 0.2
		l.light_color = acc
		l.light_energy = 3.5
		l.omni_range = 14.0
		root.add_child(l)
		l.global_position = p + Vector3(randf_range(-24, 24), randf_range(6, 26), randf_range(4, 14))
	VFX.fire_pillar(root, p + Vector3(0, 38, 3), 4.0, true).color_ramp = VFX._ramp(acc)
