class_name Inferno
extends RefCounted
## Region 3 (Inferno Tower) set dressing and terrain obstacles, driven by the
## authored stage map: flowing lava rivers with stone bridges where roads cross,
## lava pools, basalt column fields, iron braziers, an erupting volcano, the
## Inferno Tower on the horizon and falling ash. Everything that occupies
## ground is registered with the LevelBuilder so props never overlap it.

const IRON := Color(0.09, 0.08, 0.08)


static func lava_material(river: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/lava.gdshader")
	m.set_shader_parameter("noise_tex", ModelLib.noise_tex("detail"))
	m.set_shader_parameter("cell_tex", ModelLib.noise_tex("cell"))
	m.set_shader_parameter("use_uv", 1.0 if river else 0.0)
	return m


static func stone_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = ModelLib.noise_tex("cell")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.6, 0.6, 0.6)
	m.roughness = 0.9
	m.normal_enabled = true
	m.normal_texture = ModelLib.noise_tex("cell_normal")
	m.normal_scale = 0.8
	return m


# ---------------------------------------------------------------- lava rivers
static func lava_river(lb: LevelBuilder, cfg: Dictionary) -> void:
	var route := PathRoute.new()
	route.build(cfg.points)
	var w := float(cfg.get("width", 3.2))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := maxi(2, int(route.length / 0.7))
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in n + 1:
		var off := route.length * i / n
		var p := route.sample(off)
		var d := route.direction(off)
		var side := Vector3(-d.z, 0, d.x)
		# Slightly wavy banks so the river doesn't look like a ribbon.
		var wob := (1.0 + 0.12 * sin(off * 0.9) + 0.08 * sin(off * 2.3 + 1.0)) * clampf(minf(off, route.length - off) / 2.0, 0.25, 1.0)
		var l := p - side * w * 0.5 * wob + Vector3(0, 0.025, 0)
		var r := p + side * w * 0.5 * wob + Vector3(0, 0.025, 0)
		if i > 0:
			for v in [[l, 0.0], [r, 1.0], [prev_l, 0.0], [r, 1.0], [prev_r, 1.0], [prev_l, 0.0]]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v[1], off))
				st.add_vertex(v[0])
		prev_l = l
		prev_r = r
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = lava_material(true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "LavaRiver"
	lb.root.add_child(mi)
	# Charred banks, embers and heat light along the flow.
	var lights := 0
	var off := 1.0
	var k := 0
	while off < route.length - 0.5:
		var p := route.sample(off)
		var d := route.direction(off)
		var side := Vector3(-d.z, 0, d.x)
		for s in [-1.0, 1.0]:
			var bp: Vector3 = p + side * s * (w * 0.5 + lb.rng.randf_range(0.2, 0.7))
			if _near_road(lb, bp, 2.4):
				continue
			var key: String = ["env/rock_single_A", "env/rock_single_B", "env/rock_single_C"][lb.rng.randi() % 3]
			lb._place(key, bp, lb.rng.randf_range(0.7, 1.4), -1.0, Color(0.11, 0.08, 0.07), Color(1, 0.35, 0.05), 0.5)
		if k % 3 == 0:
			VFX.particles(lb.root, p + Vector3(0, 0.3, 0), {"amount": 7, "lifetime": 1.8, "one_shot": false, "speed": 0.7, "size": 0.16,
				"color": Color(1, 0.55, 0.12), "radius": w * 0.35, "gravity": Vector3(0, 1.4, 0), "explosiveness": 0.0})
		if k % 4 == 0 and lights < 8 and GraphicsSettings.quality() >= 1:
			lights += 1
			var l := OmniLight3D.new()
			l.light_volumetric_fog_energy = 0.2
			l.light_color = Color(1.0, 0.38, 0.06)
			l.light_energy = 2.2
			l.omni_range = w * 2.6
			lb.root.add_child(l)
			l.global_position = p + Vector3(0, 1.2, 0)
		off += 2.6
		k += 1
	for i in range(0, route.points.size(), 3):
		lb._occupied.append([route.points[i], w * 0.5 + 2.0])
	_bridges(lb, route, w)


static func _near_road(lb: LevelBuilder, p: Vector3, d: float) -> bool:
	for r in lb.ground_routes():
		if r.distance_to(p) < d:
			return true
	return false


## A stone bridge wherever a ground road crosses the river.
static func _bridges(lb: LevelBuilder, river: PathRoute, w: float) -> void:
	for r in lb.ground_routes():
		var off := 0.0
		var start := -1.0
		while off <= r.length:
			var wet := river.distance_to(r.sample(off)) < w * 0.5 + 0.9
			if wet and start < 0.0:
				start = off
			elif not wet and start >= 0.0:
				_bridge(lb, r, start - 1.4, off + 1.4)
				start = -1.0
			off += 0.4
		if start >= 0.0:
			_bridge(lb, r, start - 1.4, r.length)


static func _bridge(lb: LevelBuilder, r: PathRoute, a: float, b: float) -> void:
	a = maxf(0.0, a)
	b = minf(r.length, b)
	var mid := (a + b) * 0.5
	var p := r.sample(mid)
	var d := (r.sample(b) - r.sample(a))
	d.y = 0.0
	var length := maxf(3.0, d.length())
	d = d.normalized()
	var yaw := atan2(d.x, d.z)
	var holder := Node3D.new()
	holder.name = "Bridge"
	lb.root.add_child(holder)
	holder.global_position = p
	holder.rotation.y = yaw
	var stone := stone_material(Color(0.3, 0.25, 0.22))
	var deck := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4.4, 0.3, length)
	deck.mesh = bm
	deck.material_override = stone
	deck.position.y = -0.1
	holder.add_child(deck)
	# Paving strip so the bridge reads as part of the road.
	var pave := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(3.6, 0.04, length)
	pave.mesh = pm
	pave.material_override = stone_material(Color(0.42, 0.36, 0.32))
	pave.position.y = 0.06
	holder.add_child(pave)
	for s in [-1.0, 1.0]:
		var wall := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.4, 0.55, length)
		wall.mesh = wm
		wall.material_override = stone
		wall.position = Vector3(s * 2.25, 0.25, 0)
		holder.add_child(wall)
		for e in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(0.6, 1.1, 0.6)
			post.mesh = cm
			post.material_override = stone
			post.position = Vector3(s * 2.25, 0.5, e * length * 0.5)
			holder.add_child(post)
		# Glowing underside where lava licks the stone.
	var under := OmniLight3D.new()
	under.light_volumetric_fog_energy = 0.2
	under.light_color = Color(1.0, 0.4, 0.08)
	under.light_energy = 1.2
	under.omni_range = 4.0
	under.position = Vector3(0, -0.4, 0)
	holder.add_child(under)
	for e in [-1.0, 1.0]:
		var tp: Vector3 = holder.global_position + d * e * (length * 0.5) + Vector3(-d.z, 0, d.x) * 2.25
		VFX.torch_flame(lb.root, tp + Vector3(0, 1.2, 0), Color(1, 0.5, 0.15), e > 0.0 and GraphicsSettings.quality() >= 2)


# ---------------------------------------------------------------- pools & rocks
static func lava_pool(lb: LevelBuilder, p: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.04
	cyl.radial_segments = 36
	mi.mesh = cyl
	mi.material_override = lava_material(false)
	mi.scale = Vector3(1, 1, lb.rng.randf_range(0.7, 1.0))
	mi.rotation.y = lb.rng.randf() * TAU
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lb.root.add_child(mi)
	mi.global_position = p + Vector3(0, 0.025, 0)
	for k in 8:
		var a := TAU * k / 8.0 + lb.rng.randf_range(-0.2, 0.2)
		var sp := p + Vector3(cos(a), 0, sin(a) * mi.scale.z).rotated(Vector3.UP, mi.rotation.y) * radius * lb.rng.randf_range(0.95, 1.1)
		lb._place("env/rock_single_" + ["A", "B", "C"][k % 3], sp, lb.rng.randf_range(0.8, 1.6), -1.0, Color(0.1, 0.075, 0.065), Color(1, 0.35, 0.05), 0.7)
	VFX.particles(lb.root, p + Vector3(0, 0.3, 0), {"amount": 10, "lifetime": 2.0, "one_shot": false, "speed": 0.8, "size": 0.18,
		"color": Color(1, 0.55, 0.12), "radius": radius * 0.6, "gravity": Vector3(0, 1.3, 0), "explosiveness": 0.0})
	# Heat smoke.
	VFX.particles(lb.root, p + Vector3(0, 0.4, 0), {"amount": 6, "lifetime": 3.5, "one_shot": false, "speed": 0.4, "size": radius * 0.9,
		"size_end": 1.6, "color": Color(0.22, 0.14, 0.1), "additive": false, "radius": radius * 0.5, "gravity": Vector3(0.2, 0.6, 0), "explosiveness": 0.0})
	if GraphicsSettings.quality() >= 1:
		var l := OmniLight3D.new()
		l.light_volumetric_fog_energy = 0.2
		l.light_color = Color(1.0, 0.4, 0.07)
		l.light_energy = 2.5
		l.omni_range = radius * 2.8
		lb.root.add_child(l)
		l.global_position = p + Vector3(0, 1.0, 0)
	lb._occupied.append([p, radius + 0.8])


static func basalt(lb: LevelBuilder, p: Vector3, radius: float) -> void:
	var m := stone_material(Color(0.13, 0.11, 0.1))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.1, 0.03, 0.01)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.35, 0.05)
	glow.emission_energy_multiplier = 1.4
	var count := int(radius * radius * 1.6) + 4
	for k in count:
		var a := lb.rng.randf() * TAU
		var rr := sqrt(lb.rng.randf()) * radius
		var cp := p + Vector3(cos(a) * rr, 0, sin(a) * rr)
		var col := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.radial_segments = 6
		cm.rings = 1
		cm.top_radius = lb.rng.randf_range(0.35, 0.6)
		cm.bottom_radius = cm.top_radius * 1.05
		# Taller columns toward the middle of the cluster.
		cm.height = lb.rng.randf_range(0.6, 1.4) + (1.0 - rr / radius) * lb.rng.randf_range(1.0, 3.2)
		col.mesh = cm
		col.material_override = m
		lb.root.add_child(col)
		col.global_position = cp + Vector3(0, cm.height * 0.5, 0)
		col.rotation.y = lb.rng.randf() * TAU
		col.rotation.x = lb.rng.randf_range(-0.06, 0.06)
		if lb.rng.randf() < 0.25:
			var cap := MeshInstance3D.new()
			var capm := CylinderMesh.new()
			capm.radial_segments = 6
			capm.top_radius = cm.top_radius * 0.7
			capm.bottom_radius = cm.top_radius * 0.7
			capm.height = 0.03
			cap.mesh = capm
			cap.material_override = glow
			col.add_child(cap)
			cap.position.y = cm.height * 0.5 + 0.01
	lb._occupied.append([p, radius + 0.8])


static func brazier(lb: LevelBuilder, pos: Vector3, c: Color, with_light: bool) -> void:
	var holder := Node3D.new()
	holder.name = "Brazier"
	lb.root.add_child(holder)
	holder.global_position = pos
	var iron := StandardMaterial3D.new()
	iron.albedo_color = IRON
	iron.metallic = 0.85
	iron.roughness = 0.45
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.08
	pm.bottom_radius = 0.14
	pm.height = 1.2
	pole.mesh = pm
	pole.material_override = iron
	pole.position.y = 0.6
	holder.add_child(pole)
	var foot := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.2
	fm.bottom_radius = 0.38
	fm.height = 0.18
	fm.radial_segments = 8
	foot.mesh = fm
	foot.material_override = iron
	foot.position.y = 0.09
	holder.add_child(foot)
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.5
	bm.bottom_radius = 0.22
	bm.height = 0.34
	bm.radial_segments = 10
	bowl.mesh = bm
	bowl.material_override = iron
	bowl.position.y = 1.35
	holder.add_child(bowl)
	var coals := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.44
	cm.bottom_radius = 0.44
	cm.height = 0.02
	coals.mesh = cm
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color(0.1, 0.03, 0.01)
	hot.emission_enabled = true
	hot.emission = c
	hot.emission_energy_multiplier = 3.0
	coals.material_override = hot
	coals.position.y = 1.5
	holder.add_child(coals)
	VFX.torch_flame(lb.root, pos + Vector3(0, 1.55, 0), c, with_light)
	VFX.particles(lb.root, pos + Vector3(0, 1.7, 0), {"amount": 8, "lifetime": 0.7, "one_shot": false, "speed": 1.0, "size": 0.4,
		"color": c, "radius": 0.22, "gravity": Vector3(0, 2.4, 0), "spread": 12.0, "explosiveness": 0.0})


# ---------------------------------------------------------------- volcano
static func volcano(lb: LevelBuilder, cfg: Dictionary) -> Vector3:
	var p := Vector3(float(cfg.pos[0]), 0, float(cfg.pos[1]))
	var r := float(cfg.get("radius", 7.0))
	var h := float(cfg.get("height", 9.0))
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.28
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 28
	cm.rings = 6
	cone.mesh = cm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform sampler2D noise_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D cell_tex : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float ang = atan(lp.z, lp.x);
	float hgt = UV.y;
	vec2 uv = vec2(ang * 1.3, hgt * 2.5);
	float rock = texture(cell_tex, uv * 1.7).r;
	vec3 col = mix(vec3(0.05, 0.04, 0.035), vec3(0.16, 0.12, 0.1), rock);
	// Lava streams running down from the rim.
	float stream = texture(noise_tex, vec2(ang * 0.9, hgt * 0.35 - TIME * 0.03)).r;
	float band = smoothstep(0.62, 0.68, stream) * smoothstep(0.78, 0.7, stream);
	band *= smoothstep(1.0, 0.1, hgt) + 0.2;
	float rim = smoothstep(0.12, 0.0, hgt);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	NORMAL_MAP = texture(normal_tex, uv * 2.0).rgb;
	EMISSION = vec3(1.0, 0.38, 0.05) * (band * 1.4 + rim * 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("noise_tex", ModelLib.noise_tex("detail"))
	m.set_shader_parameter("cell_tex", ModelLib.noise_tex("cell"))
	m.set_shader_parameter("normal_tex", ModelLib.noise_tex("cell_normal"))
	cone.material_override = m
	cone.name = "Volcano"
	lb.root.add_child(cone)
	cone.global_position = p + Vector3(0, h * 0.5 - 0.2, 0)
	var crater := p + Vector3(0, h - 0.1, 0)
	var lake := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = r * 0.25
	lm.bottom_radius = r * 0.25
	lm.height = 0.05
	lake.mesh = lm
	lake.material_override = lava_material(false)
	lb.root.add_child(lake)
	lake.global_position = crater
	# Smoke column and a fire plume from the crater.
	var smoke := VFX.particles(lb.root, crater + Vector3(0, 1.5, 0), {"amount": 26, "lifetime": 7.0, "one_shot": false, "speed": 2.0,
		"size": 4.0, "size_end": 3.0, "color": Color(0.16, 0.12, 0.11), "additive": false, "radius": r * 0.2,
		"gravity": Vector3(0.5, 1.2, 0.2), "spread": 12.0, "explosiveness": 0.0})
	smoke.preprocess = 6.0
	VFX.fire_pillar(lb.root, crater, 2.4, true)
	var l := OmniLight3D.new()
	l.light_volumetric_fog_energy = 0.2
	l.light_color = Color(1.0, 0.4, 0.07)
	l.light_energy = 6.0
	l.omni_range = r * 3.0
	lb.root.add_child(l)
	l.global_position = crater + Vector3(0, 2.0, 0)
	var flick := LightFlicker.new()
	flick.light = l
	lb.root.add_child(flick)
	# Boulders around the foot.
	for k in 14:
		var a := TAU * k / 14.0 + lb.rng.randf_range(-0.15, 0.15)
		var bp := p + Vector3(cos(a), 0, sin(a)) * r * lb.rng.randf_range(0.95, 1.15)
		if _near_road(lb, bp, 2.6):
			continue
		lb._place("env/rock_single_" + ["A", "B", "C"][k % 3], bp, lb.rng.randf_range(1.4, 2.6), -1.0, Color(0.1, 0.08, 0.07), Color(1, 0.35, 0.05), 0.4)
	lb._occupied.append([p, r + 1.0])
	return crater


# ---------------------------------------------------------------- skyline
static func backdrop_tower(root: Node3D, cfg: Dictionary) -> void:
	var p := Vector3(float(cfg.pos[0]), 0, float(cfg.pos[1]))
	var tint := Color(0.14, 0.1, 0.09)
	var acc := Color(1.0, 0.35, 0.05)
	var stack := [["env/building_tower_base_red", 10.0], ["env/building_tower_B_red", 8.0], ["env/building_tower_A_red", 6.5]]
	var y := 0.0
	for s in stack:
		var n := ModelLib.prop(s[0], tint, acc, 1.8)
		root.add_child(n)
		n.global_position = p + Vector3(0, y, 0)
		n.scale = Vector3.ONE * float(s[1])
		y += _height(n) * 0.82
	# Flanking spires.
	for side in [-1.0, 1.0]:
		var sp := ModelLib.prop("env/building_tower_B_red", tint, acc, 1.4)
		root.add_child(sp)
		sp.global_position = p + Vector3(side * 20.0, 0, 8.0)
		sp.scale = Vector3.ONE * 5.5
		VFX.fire_pillar(root, sp.global_position + Vector3(0, _height(sp) + 0.5, 0), 2.5, true)
	# Crown of fire and lava falls.
	VFX.fire_pillar(root, p + Vector3(0, y + 1.0, 0), 6.0, true)
	for k in 5:
		var fall := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(2.2, y * 0.7)
		fall.mesh = q
		fall.material_override = lava_material(true)
		root.add_child(fall)
		var a := -1.2 + k * 0.6
		fall.global_position = p + Vector3(sin(a) * 7.5, y * 0.35, cos(a) * 7.5)
		fall.rotation.y = a
	for k in 7:
		var l := OmniLight3D.new()
		l.light_volumetric_fog_energy = 0.2
		l.light_color = acc
		l.light_energy = 5.0
		l.omni_range = 16.0
		root.add_child(l)
		l.global_position = p + Vector3(randf_range(-14, 14), randf_range(4, y), randf_range(6, 12))
	var smoke := VFX.particles(root, p + Vector3(0, y + 4.0, 0), {"amount": 22, "lifetime": 8.0, "one_shot": false, "speed": 2.5,
		"size": 9.0, "size_end": 2.5, "color": Color(0.14, 0.09, 0.08), "additive": false, "radius": 3.0,
		"gravity": Vector3(1.2, 1.0, 0), "spread": 10.0, "explosiveness": 0.0})
	smoke.preprocess = 6.0


static func _height(n: Node3D) -> float:
	var top := 0.0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var ab: AABB = mi.get_aabb()
		top = maxf(top, ab.end.y)
	return top * n.scale.y


static func ash_fall(root: Node3D, center: Vector3, b: Rect2) -> void:
	VFX.particles(root, center + Vector3(0, 9, 0), {"amount": 120, "lifetime": 7.0, "one_shot": false, "speed": 0.4,
		"size": 0.12, "size_end": 0.8, "color": Color(0.55, 0.5, 0.48), "additive": false, "box": Vector3(b.size.x * 0.55, 1.0, b.size.y * 0.55),
		"gravity": Vector3(0.4, -1.2, 0.2), "direction": Vector3.DOWN, "spread": 30.0, "end_alpha": 0.0, "explosiveness": 0.0}).preprocess = 7.0
