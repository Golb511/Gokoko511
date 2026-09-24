class_name VFX
extends RefCounted
## Particle and light effects factory (fire, ice, poison, lightning, shadow,
## holy, explosions, ambient weather). Uses CPUParticles3D for portability
## across desktop and mobile renderers.

const ELEMENT_COLORS := {
	"fire": Color(1.0, 0.42, 0.08), "ice": Color(0.45, 0.8, 1.0), "poison": Color(0.4, 1.0, 0.2),
	"lightning": Color(0.55, 0.75, 1.0), "shadow": Color(0.6, 0.2, 1.0), "holy": Color(1.0, 0.9, 0.55),
	"arcane": Color(0.75, 0.4, 1.0), "physical": Color(1.0, 0.85, 0.6), "earth": Color(0.85, 0.55, 0.3),
	"wind": Color(0.8, 1.0, 0.95), "true": Color(1, 1, 1),
}

static var _add_mat: StandardMaterial3D
static var _smoke_mat: StandardMaterial3D
static var _quality := 2


static func set_quality(q: int) -> void:
	_quality = q


static func color(element: String) -> Color:
	return ELEMENT_COLORS.get(element, Color(1, 0.8, 0.5))


static func _additive() -> StandardMaterial3D:
	if _add_mat == null:
		_add_mat = StandardMaterial3D.new()
		_add_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_add_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_add_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_add_mat.vertex_color_use_as_albedo = true
		_add_mat.albedo_texture = ModelLib.radial_tex()
		_add_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_add_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return _add_mat


static func _smoke() -> StandardMaterial3D:
	if _smoke_mat == null:
		_smoke_mat = StandardMaterial3D.new()
		_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_mat.vertex_color_use_as_albedo = true
		_smoke_mat.albedo_texture = ModelLib.radial_tex()
		_smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_smoke_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return _smoke_mat


static func _ramp(c: Color, end_alpha := 0.0) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(minf(1.0, c.r * 1.15 + 0.08), minf(1.0, c.g * 1.15 + 0.08), minf(1.0, c.b * 1.15 + 0.08), 0.85))
	g.set_color(1, Color(c.r * 0.5, c.g * 0.3, c.b * 0.3, end_alpha))
	g.add_point(0.35, Color(c.r, c.g, c.b, 0.6))
	return g


## Generic particle emitter. `p` keys: amount, lifetime, one_shot, speed, spread,
## gravity, size, size_end, radius, color, additive, direction, explosiveness, box.
static func particles(parent: Node, pos: Vector3, p: Dictionary) -> CPUParticles3D:
	var e := CPUParticles3D.new()
	var amount := int(p.get("amount", 24))
	if _quality <= 0:
		amount = maxi(4, amount / 3)
	elif _quality == 1:
		amount = maxi(6, amount * 2 / 3)
	e.amount = amount
	e.lifetime = float(p.get("lifetime", 0.8))
	e.one_shot = bool(p.get("one_shot", true))
	e.explosiveness = float(p.get("explosiveness", 0.9 if e.one_shot else 0.0))
	e.randomness = 0.5
	e.local_coords = bool(p.get("local", false))
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	e.mesh = q
	e.material_override = _additive() if p.get("additive", true) else _smoke()
	e.direction = p.get("direction", Vector3.UP)
	e.spread = float(p.get("spread", 180.0))
	e.initial_velocity_min = float(p.get("speed", 3.0)) * 0.5
	e.initial_velocity_max = float(p.get("speed", 3.0))
	e.gravity = p.get("gravity", Vector3(0, 1.0, 0))
	e.damping_min = float(p.get("damping", 1.0))
	e.damping_max = float(p.get("damping", 1.0)) * 2.0
	var sz := float(p.get("size", 0.4))
	e.scale_amount_min = sz * 0.6
	e.scale_amount_max = sz
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, float(p.get("size_end", 0.2))))
	e.scale_amount_curve = curve
	e.color_ramp = _ramp(p.get("color", Color(1, 0.5, 0.1)), float(p.get("end_alpha", 0.0)))
	var r := float(p.get("radius", 0.0))
	if p.has("box"):
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		e.emission_box_extents = p.box
	elif r > 0.0:
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		e.emission_sphere_radius = r
	parent.add_child(e)
	e.global_position = pos
	e.emitting = true
	if e.one_shot:
		_free_after(e, e.lifetime + 0.3)
	return e


static func _free_after(n: Node, t: float) -> void:
	if not n.is_inside_tree():
		return
	var timer := n.get_tree().create_timer(t, false)
	timer.timeout.connect(func(): if is_instance_valid(n): n.queue_free())


static func flash_light(parent: Node, pos: Vector3, c: Color, energy: float = 4.0, range_: float = 6.0, dur: float = 0.35) -> void:
	if _quality <= 0:
		return
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = range_
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = pos + Vector3(0, 1.0, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)


# ---------------------------------------------------------------- composite effects
static func hit(parent: Node, pos: Vector3, element: String = "physical") -> void:
	particles(parent, pos, {"amount": 10, "lifetime": 0.35, "speed": 4.0, "size": 0.18, "color": color(element), "gravity": Vector3(0, -6, 0)})


static func explosion(parent: Node, pos: Vector3, radius: float, element: String = "fire") -> void:
	var c := color(element)
	particles(parent, pos + Vector3(0, 0.4, 0), {"amount": 40, "lifetime": 0.7, "speed": radius * 3.5, "size": radius * 0.55, "color": c, "radius": radius * 0.3, "gravity": Vector3(0, 2, 0), "damping": 4.0})
	particles(parent, pos + Vector3(0, 0.3, 0), {"amount": 26, "lifetime": 0.6, "speed": radius * 5.0, "size": 0.12, "color": c.lightened(0.4), "gravity": Vector3(0, -9, 0)})
	particles(parent, pos + Vector3(0, 0.6, 0), {"amount": 16, "lifetime": 1.6, "speed": radius * 1.2, "size": radius * 0.8, "color": Color(0.12, 0.1, 0.1), "additive": false, "radius": radius * 0.4, "gravity": Vector3(0, 1.5, 0), "end_alpha": 0.0})
	flash_light(parent, pos, c, 6.0, radius * 3.0, 0.4)
	ground_ring(parent, pos, radius, c, 0.45)


static func nova(parent: Node, pos: Vector3, radius: float, element: String) -> void:
	var c := color(element)
	var e := particles(parent, pos + Vector3(0, 0.3, 0), {"amount": 60, "lifetime": 0.6, "speed": radius * 3.0, "size": 0.45, "color": c, "direction": Vector3(1, 0, 0), "spread": 180.0, "gravity": Vector3.ZERO, "damping": 2.0})
	e.flatness = 1.0
	ground_ring(parent, pos, radius, c, 0.55)
	flash_light(parent, pos, c, 5.0, radius * 2.5, 0.45)


static func ground_ring(parent: Node, pos: Vector3, radius: float, c: Color, dur: float, grow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	mi.mesh = torus
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c.r, c.g, c.b, 0.9)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.08, 0)
	mi.scale = Vector3(radius * (0.2 if grow else 1.0), 0.05, radius * (0.2 if grow else 1.0))
	var tw := mi.create_tween().set_parallel(true)
	if grow:
		tw.tween_property(mi, "scale", Vector3(radius, 0.05, radius), dur * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)
	return mi


## Persistent telegraph/aoe decal (caller frees it).
static func area_disc(parent: Node, pos: Vector3, radius: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.02
	cyl.radial_segments = 40
	mi.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = ModelLib.radial_tex()
	m.albedo_color = Color(c.r, c.g, c.b, 0.55)
	m.uv1_scale = Vector3(1, 1, 1)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.06, 0)
	mi.scale = Vector3(radius, 1, radius)
	return mi


static func cloud(parent: Node, pos: Vector3, radius: float, element: String, duration: float) -> Node3D:
	var c := color(element)
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var e := particles(root, pos + Vector3(0, 0.5, 0), {"amount": 40, "lifetime": 1.6, "one_shot": false, "speed": 0.6, "size": radius * 0.6, "color": c.darkened(0.3), "additive": element != "poison" and element != "shadow", "box": Vector3(radius * 0.8, 0.3, radius * 0.8), "gravity": Vector3(0, 0.4, 0), "end_alpha": 0.0})
	e.local_coords = false
	area_disc(root, pos, radius, c)
	if element == "ice":
		particles(root, pos + Vector3(0, 4, 0), {"amount": 60, "lifetime": 1.2, "one_shot": false, "speed": 1.0, "size": 0.12, "color": Color(0.9, 0.95, 1.0), "box": Vector3(radius, 0.2, radius), "gravity": Vector3(1.5, -6, 0), "direction": Vector3.DOWN, "spread": 10.0})
	elif element == "fire":
		particles(root, pos + Vector3(0, 0.2, 0), {"amount": 50, "lifetime": 0.9, "one_shot": false, "speed": 2.0, "size": 0.55, "color": c, "box": Vector3(radius * 0.8, 0.1, radius * 0.8), "gravity": Vector3(0, 3, 0), "spread": 15.0})
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 2.0
	l.omni_range = radius * 2.2
	root.add_child(l)
	l.position = Vector3(0, 1.2, 0)
	_free_after(root, duration + 0.2)
	return root


static func fire_pillar(parent: Node, pos: Vector3, scale: float = 1.0, looping := true) -> CPUParticles3D:
	var e := particles(parent, pos, {"amount": 36, "lifetime": 0.9, "one_shot": not looping, "speed": 1.5 * scale, "size": 0.5 * scale, "color": Color(1.0, 0.4, 0.06), "radius": 0.15 * scale, "gravity": Vector3(0, 3.5 * scale, 0), "spread": 12.0})
	return e


static func torch_flame(parent: Node, pos: Vector3, c: Color = Color(1.0, 0.45, 0.1), with_light := true) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	particles(root, pos, {"amount": 16, "lifetime": 0.55, "one_shot": false, "speed": 0.7, "size": 0.28, "color": c, "radius": 0.05, "gravity": Vector3(0, 2.2, 0), "spread": 10.0})
	if with_light and _quality > 0:
		var l := OmniLight3D.new()
		l.light_color = c
		l.light_energy = 2.2
		l.omni_range = 7.0
		l.omni_attenuation = 1.4
		l.shadow_enabled = _quality >= 3
		root.add_child(l)
		l.position = Vector3(0, 0.4, 0)
		var flick := LightFlicker.new()
		flick.light = l
		root.add_child(flick)
	return root


static func lightning(parent: Node, from: Vector3, to: Vector3, c: Color = Color(0.6, 0.8, 1.0), width := 0.12, dur := 0.18) -> void:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(c.r * 1.5, c.g * 1.5, c.b * 1.5, 1.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var pts: Array[Vector3] = [from]
	var segs := maxi(4, int(from.distance_to(to) * 1.5))
	for i in range(1, segs):
		var t := float(i) / segs
		var jitter := Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)) * 0.35 * sin(t * PI)
		pts.append(from.lerp(to, t) + jitter)
	pts.append(to)
	var cam := mi.get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else from + Vector3(0, 10, 10)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var side := (b - a).cross(eye - a).normalized() * width
		im.surface_add_vertex(a - side)
		im.surface_add_vertex(a + side)
		im.surface_add_vertex(b + side)
		im.surface_add_vertex(a - side)
		im.surface_add_vertex(b + side)
		im.surface_add_vertex(b - side)
	im.surface_end()
	flash_light(parent, to, c, 3.0, 5.0, dur)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.tween_callback(mi.queue_free)


static func heal(parent: Node, pos: Vector3) -> void:
	particles(parent, pos + Vector3(0, 0.2, 0), {"amount": 16, "lifetime": 0.9, "speed": 1.2, "size": 0.22, "color": Color(0.4, 1.0, 0.5), "radius": 0.6, "gravity": Vector3(0, 2.5, 0), "spread": 20.0})


static func shadow_burst(parent: Node, pos: Vector3, radius := 1.2) -> void:
	particles(parent, pos + Vector3(0, 0.8, 0), {"amount": 30, "lifetime": 0.7, "speed": radius * 3.0, "size": 0.6, "color": Color(0.35, 0.08, 0.6), "additive": false, "radius": 0.3, "gravity": Vector3(0, 1.0, 0)})
	particles(parent, pos + Vector3(0, 0.8, 0), {"amount": 16, "lifetime": 0.5, "speed": radius * 4.0, "size": 0.2, "color": Color(0.7, 0.3, 1.0), "radius": 0.3})


static func level_up(parent: Node, pos: Vector3) -> void:
	particles(parent, pos, {"amount": 50, "lifetime": 1.2, "speed": 2.0, "size": 0.25, "color": Color(1.0, 0.8, 0.3), "radius": 0.8, "gravity": Vector3(0, 3, 0), "spread": 25.0})
	ground_ring(parent, pos, 2.0, Color(1, 0.8, 0.3), 0.8)


static func build_dust(parent: Node, pos: Vector3) -> void:
	particles(parent, pos + Vector3(0, 0.3, 0), {"amount": 26, "lifetime": 1.0, "speed": 3.0, "size": 0.9, "color": Color(0.35, 0.3, 0.26), "additive": false, "radius": 1.0, "gravity": Vector3(0, 0.5, 0), "direction": Vector3(0, 0.3, 0), "damping": 3.0})
	particles(parent, pos + Vector3(0, 1.5, 0), {"amount": 20, "lifetime": 0.8, "speed": 3.0, "size": 0.15, "color": Color(1.0, 0.8, 0.4), "radius": 1.0})


# ---------------------------------------------------------------- ambient weather
static func ambient(parent: Node, kind: String, center: Vector3, extents: Vector3) -> void:
	match kind:
		"embers":
			particles(parent, center, {"amount": 160, "lifetime": 5.0, "one_shot": false, "speed": 0.6, "size": 0.09, "size_end": 0.6, "color": Color(1.0, 0.45, 0.1), "box": extents, "gravity": Vector3(0.3, 0.7, 0), "spread": 60.0, "explosiveness": 0.0})
			particles(parent, center + Vector3(0, 1, 0), {"amount": 40, "lifetime": 8.0, "one_shot": false, "speed": 0.2, "size": 5.0, "size_end": 1.0, "color": Color(0.16, 0.1, 0.09), "additive": false, "box": extents, "gravity": Vector3(0.2, 0.05, 0), "end_alpha": 0.0, "explosiveness": 0.0})
		"snow":
			particles(parent, center + Vector3(0, 8, 0), {"amount": 300, "lifetime": 5.0, "one_shot": false, "speed": 0.5, "size": 0.1, "size_end": 1.0, "color": Color(0.9, 0.95, 1.0), "box": Vector3(extents.x, 1, extents.z), "gravity": Vector3(0.6, -1.8, 0), "direction": Vector3.DOWN, "spread": 20.0, "explosiveness": 0.0})
		"spores":
			particles(parent, center, {"amount": 140, "lifetime": 6.0, "one_shot": false, "speed": 0.3, "size": 0.1, "size_end": 0.8, "color": Color(0.5, 1.0, 0.3), "box": extents, "gravity": Vector3(0.1, 0.25, 0), "explosiveness": 0.0})
			particles(parent, center, {"amount": 30, "lifetime": 8.0, "one_shot": false, "speed": 0.1, "size": 6.0, "size_end": 1.0, "color": Color(0.12, 0.22, 0.08), "additive": false, "box": extents, "end_alpha": 0.0, "explosiveness": 0.0})
		"shadow":
			particles(parent, center, {"amount": 120, "lifetime": 6.0, "one_shot": false, "speed": 0.25, "size": 0.12, "size_end": 0.5, "color": Color(0.55, 0.3, 1.0), "box": extents, "gravity": Vector3(0, 0.3, 0), "explosiveness": 0.0})
			particles(parent, center, {"amount": 36, "lifetime": 9.0, "one_shot": false, "speed": 0.1, "size": 6.0, "size_end": 1.0, "color": Color(0.08, 0.05, 0.14), "additive": false, "box": extents, "end_alpha": 0.0, "explosiveness": 0.0})
