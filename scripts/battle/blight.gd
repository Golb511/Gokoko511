class_name Blight
extends RefCounted
## Region 4 (Poison Forest) terrain and set dressing, driven by the authored
## stage map: toxic pools, mud bogs that slow everyone crossing them, giant
## corrupted trees and fallen logs, glowing mushroom clusters, god rays
## through the canopy, acid rain and the Blight Heart on the horizon.
## Ground-occupying features are registered with the LevelBuilder.

const GREEN := Color(0.45, 1.0, 0.15)


static func toxic_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/toxic.gdshader")
	m.set_shader_parameter("noise_tex", ModelLib.noise_tex("detail"))
	m.set_shader_parameter("cell_tex", ModelLib.noise_tex("cell"))
	return m


static func toxic_pool(lb: LevelBuilder, p: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.04
	cyl.radial_segments = 36
	mi.mesh = cyl
	mi.material_override = toxic_material()
	mi.scale = Vector3(1, 1, lb.rng.randf_range(0.7, 1.0))
	mi.rotation.y = lb.rng.randf() * TAU
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lb.root.add_child(mi)
	mi.global_position = p + Vector3(0, 0.025, 0)
	# Slimy bank: mossy rocks, dead reeds and a few skulls of the unlucky.
	for k in 9:
		var a := TAU * k / 9.0 + lb.rng.randf_range(-0.2, 0.2)
		var sp := p + Vector3(cos(a), 0, sin(a) * mi.scale.z).rotated(Vector3.UP, mi.rotation.y) * radius * lb.rng.randf_range(0.95, 1.12)
		if k % 4 == 3:
			lb._place("graveyard/skull", sp, 1.2, -1.0, Color(0.5, 0.52, 0.4))
		else:
			lb._place("env/rock_single_" + ["A", "B", "C"][k % 3], sp, lb.rng.randf_range(0.8, 1.5), -1.0, Color(0.12, 0.16, 0.09), GREEN, 0.25)
	VFX.particles(lb.root, p + Vector3(0, 0.25, 0), {"amount": 10, "lifetime": 2.2, "one_shot": false, "speed": 0.5, "size": 0.2,
		"color": GREEN, "radius": radius * 0.6, "gravity": Vector3(0, 0.8, 0), "explosiveness": 0.0})
	VFX.particles(lb.root, p + Vector3(0, 0.4, 0), {"amount": 5, "lifetime": 4.0, "one_shot": false, "speed": 0.3, "size": radius,
		"size_end": 1.5, "color": Color(0.22, 0.35, 0.1), "additive": false, "radius": radius * 0.5, "gravity": Vector3(0.1, 0.35, 0), "explosiveness": 0.0})
	if GraphicsSettings.quality() >= 1:
		var l := OmniLight3D.new()
		l.light_color = GREEN
		l.light_energy = 1.8
		l.omni_range = radius * 2.6
		lb.root.add_child(l)
		l.global_position = p + Vector3(0, 1.0, 0)
	lb._occupied.append([p, radius + 0.8])


## Mud bog: dark sucking mud across the road. Every ground unit crossing it —
## enemy, soldier or hero — is slowed (see Unit.speed_mult / BattleController).
static func bog(lb: LevelBuilder, p: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.03
	cyl.radial_segments = 32
	mi.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.07, 0.065, 0.04)
	m.albedo_texture = ModelLib.noise_tex("detail")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.4, 0.4, 0.4)
	m.roughness = 0.25
	m.metallic = 0.15
	m.normal_enabled = true
	m.normal_texture = ModelLib.noise_tex("normal")
	m.normal_scale = 0.6
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lb.root.add_child(mi)
	mi.global_position = p + Vector3(0, 0.045, 0)
	# Reeds around the rim and slow mud bubbles.
	var reed := StandardMaterial3D.new()
	reed.albedo_color = Color(0.22, 0.24, 0.12)
	reed.roughness = 0.9
	for k in 18:
		var a := lb.rng.randf() * TAU
		var rp := p + Vector3(cos(a), 0, sin(a)) * radius * lb.rng.randf_range(0.9, 1.15)
		if lb._near_ground_road(rp, 2.2):
			continue
		var stalk := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.01
		sm.bottom_radius = 0.035
		sm.height = lb.rng.randf_range(0.6, 1.3)
		sm.radial_segments = 4
		stalk.mesh = sm
		stalk.material_override = reed
		lb.root.add_child(stalk)
		stalk.global_position = rp + Vector3(0, sm.height * 0.5, 0)
		stalk.rotation = Vector3(lb.rng.randf_range(-0.25, 0.25), 0, lb.rng.randf_range(-0.25, 0.25))
	VFX.particles(lb.root, p + Vector3(0, 0.1, 0), {"amount": 6, "lifetime": 1.6, "one_shot": false, "speed": 0.2, "size": 0.35,
		"size_end": 0.9, "color": Color(0.25, 0.22, 0.12), "additive": false, "radius": radius * 0.6, "gravity": Vector3(0, 0.3, 0), "explosiveness": 0.0})
	lb.bogs.append([p, radius])


static func giant_tree(lb: LevelBuilder, p: Vector3, scale: float, rot: float) -> void:
	var tint := Color(0.13, 0.16, 0.1)
	var key: String = ["env/trees_A_large", "env/trees_B_large", "env/tree_single_A"][int(abs(p.x * 7 + p.z * 3)) % 3]
	var t := lb._place(key, p, scale, rot, tint, GREEN, 0.15)
	t.name = "GiantTree"
	# Gnarled roots spreading from the trunk.
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.12, 0.09, 0.06)
	wood.roughness = 0.95
	for k in 5:
		var a := TAU * k / 5.0 + lb.rng.randf_range(-0.3, 0.3)
		var root := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06 * scale
		cm.bottom_radius = 0.18 * scale
		cm.height = 1.2 * scale
		cm.radial_segments = 6
		root.mesh = cm
		root.material_override = wood
		lb.root.add_child(root)
		root.global_position = p + Vector3(cos(a), 0.05, sin(a)) * 0.55 * scale
		root.rotation = Vector3(PI / 2 - 0.25, -a + PI / 2, 0)
	# Bracket fungus glowing on the bark.
	glow_mushrooms(lb, p + Vector3(0.6 * scale, 0, 0.3 * scale), 0.8, 3)
	lb._occupied.append([p, 0.9 * scale])


static func fallen_log(lb: LevelBuilder, p: Vector3, length: float, rot: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.7
	cm.height = length
	cm.radial_segments = 10
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.34, 0.27, 0.18)
	m.albedo_texture = ModelLib.noise_tex("cell")
	m.uv1_scale = Vector3(1, 4, 1)
	m.roughness = 0.95
	m.normal_enabled = true
	m.normal_texture = ModelLib.noise_tex("cell_normal")
	mi.material_override = m
	lb.root.add_child(mi)
	mi.global_position = p + Vector3(0, 0.5, 0)
	mi.rotation = Vector3(0, rot, PI / 2)
	var dir := Vector3(cos(-rot), 0, sin(-rot))
	for k in 3:
		glow_mushrooms(lb, p + dir * (k - 1) * length * 0.3 + Vector3(0, 0.7, 0), 0.5, 2)
	lb._occupied.append([p, length * 0.5 + 0.6])


## A cluster of bioluminescent mushrooms (reuses the level builder's crystals).
static func glow_mushrooms(lb: LevelBuilder, p: Vector3, size: float, _count: int) -> void:
	var holder := Node3D.new()
	lb.root.add_child(holder)
	holder.global_position = p
	var cap := StandardMaterial3D.new()
	cap.albedo_color = Color(0.12, 0.2, 0.06)
	cap.emission_enabled = true
	cap.emission = Color(0.35, 0.85, 0.12) if lb.rng.randf() < 0.7 else Color(0.15, 0.7, 0.85)
	cap.emission_energy_multiplier = 0.55
	var stem := StandardMaterial3D.new()
	stem.albedo_color = Color(0.4, 0.4, 0.32)
	stem.emission_enabled = true
	stem.emission = Color(0.4, 0.6, 0.3)
	stem.emission_energy_multiplier = 0.2
	for k in lb.rng.randi_range(3, 6):
		var h := lb.rng.randf_range(0.25, 0.8) * size
		var s := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.04 * size
		sm.bottom_radius = 0.07 * size
		sm.height = h
		s.mesh = sm
		s.material_override = stem
		holder.add_child(s)
		var off := Vector3(lb.rng.randf_range(-0.6, 0.6), 0, lb.rng.randf_range(-0.6, 0.6)) * size
		s.position = off + Vector3(0, h * 0.5, 0)
		var c := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = lb.rng.randf_range(0.14, 0.3) * size * 1.5
		cm.height = cm.radius
		cm.is_hemisphere = true
		c.mesh = cm
		c.material_override = cap
		holder.add_child(c)
		c.position = off + Vector3(0, h, 0)


## Shafts of sickly light falling through the canopy.
static func god_rays(root: Node3D, b: Rect2, count: int, rng: RandomNumberGenerator) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = _ray_tex()
	m.albedo_color = Color(0.75, 1.0, 0.5, 0.12)
	m.disable_receive_shadows = true
	for k in count:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(rng.randf_range(2.5, 5.0), 26.0)
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mi.global_position = Vector3(rng.randf_range(b.position.x, b.end.x), 11.0, rng.randf_range(b.position.y, b.end.y))
		mi.rotation = Vector3(0, rng.randf() * TAU, 0.35)
		# Rays breathe slowly.
		var tw := mi.create_tween().set_loops()
		var mat := m.duplicate() as StandardMaterial3D
		mi.material_override = mat
		tw.tween_property(mat, "albedo_color:a", 0.05, rng.randf_range(3.0, 5.0))
		tw.tween_property(mat, "albedo_color:a", 0.14, rng.randf_range(3.0, 5.0))


static func _ray_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 8
	return t


static func acid_rain(root: Node3D, center: Vector3, b: Rect2) -> void:
	var e := VFX.particles(root, center + Vector3(0, 14, 0), {"amount": 260, "lifetime": 1.1, "one_shot": false, "speed": 14.0,
		"size": 0.06, "size_end": 1.0, "color": Color(0.6, 1.0, 0.35), "box": Vector3(b.size.x * 0.55, 1.0, b.size.y * 0.55),
		"gravity": Vector3(1.0, -18.0, 0), "direction": Vector3.DOWN, "spread": 3.0, "explosiveness": 0.0})
	e.scale_amount_min = 0.05
	e.scale_amount_max = 0.08
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 5.0)
	e.mesh = q
	e.preprocess = 2.0


## The Blight Heart: a colossal corrupted tree with a pulsing green heart,
## looming over the boss stage from beyond the northern edge.
static func blight_heart(root: Node3D, cfg: Dictionary) -> void:
	var p := Vector3(float(cfg.pos[0]), 0, float(cfg.pos[1]))
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.1, 0.08, 0.06)
	wood.albedo_texture = ModelLib.noise_tex("cell")
	wood.uv1_scale = Vector3(2, 6, 2)
	wood.roughness = 0.95
	wood.emission_enabled = true
	wood.emission = Color(0.4, 1.0, 0.15)
	wood.emission_energy_multiplier = 0.25
	wood.emission_texture = ModelLib.noise_tex("cell")
	wood.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 4.0
	cm.bottom_radius = 9.0
	cm.height = 34.0
	cm.radial_segments = 14
	trunk.mesh = cm
	trunk.material_override = wood
	root.add_child(trunk)
	trunk.global_position = p + Vector3(0, 17, 0)
	# Twisting boughs.
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for k in 9:
		var br := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.4
		bm.bottom_radius = 2.2
		bm.height = rng.randf_range(16.0, 26.0)
		bm.radial_segments = 8
		br.mesh = bm
		br.material_override = wood
		root.add_child(br)
		var a := TAU * k / 9.0 + rng.randf_range(-0.3, 0.3)
		br.global_position = p + Vector3(cos(a) * 5.0, rng.randf_range(24.0, 34.0), sin(a) * 5.0)
		br.rotation = Vector3(rng.randf_range(0.7, 1.2), -a + PI / 2, 0)
		br.rotation_order = EULER_ORDER_YXZ
	# Roots clawing into the ground.
	for k in 8:
		var rt := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.5
		rm.bottom_radius = 2.4
		rm.height = 16.0
		rt.mesh = rm
		rt.material_override = wood
		root.add_child(rt)
		var a := TAU * k / 8.0 + 0.2
		rt.global_position = p + Vector3(cos(a) * 11.0, 2.0, sin(a) * 11.0)
		rt.rotation = Vector3(PI / 2 - 0.3, -a - PI / 2, 0)
		rt.rotation_order = EULER_ORDER_YXZ
	# The pulsing heart.
	var heart := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 4.5
	sm.height = 9.0
	heart.mesh = sm
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.15, 0.3, 0.05)
	hm.emission_enabled = true
	hm.emission = GREEN
	hm.emission_energy_multiplier = 3.0
	hm.emission_texture = ModelLib.noise_tex("cell")
	hm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	heart.material_override = hm
	root.add_child(heart)
	heart.global_position = p + Vector3(0, 18, 7.5)
	var tw := heart.create_tween().set_loops()
	tw.tween_property(heart, "scale", Vector3.ONE * 1.12, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(heart, "scale", Vector3.ONE, 0.75).set_trans(Tween.TRANS_SINE)
	var l := OmniLight3D.new()
	l.light_color = GREEN
	l.light_energy = 8.0
	l.omni_range = 30.0
	root.add_child(l)
	l.global_position = heart.global_position + Vector3(0, 0, 4)
	VFX.particles(root, p + Vector3(0, 30, 4), {"amount": 30, "lifetime": 6.0, "one_shot": false, "speed": 1.5, "size": 6.0,
		"size_end": 2.0, "color": Color(0.2, 0.35, 0.1), "additive": false, "radius": 8.0, "gravity": Vector3(0.5, 0.8, 0), "explosiveness": 0.0}).preprocess = 5.0
	VFX.particles(root, heart.global_position, {"amount": 40, "lifetime": 3.0, "one_shot": false, "speed": 3.0, "size": 0.5,
		"color": GREEN, "radius": 4.0, "gravity": Vector3(0, 1.0, 0), "explosiveness": 0.0})
