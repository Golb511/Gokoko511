class_name ProceduralCreatures
extends RefCounted
## Procedurally assembled creatures (dragon, raven, bat wings) for units that
## have no rigged source asset. Built from many sculpted parts with PBR shading.

static func _scale_mat(base: Color, glow: Color, key: String) -> ShaderMaterial:
	var tex := ModelLib.gradient_tex([base.darkened(0.6), base, base.lightened(0.25)], key)
	var m := ModelLib.char_material(tex, {"tint": [0.42, 0.42, 0.42], "metal": 0.35, "emission": [glow.r, glow.g, glow.b], "emission_strength": 1.6})
	m.set_shader_parameter("desaturate", 0.0)
	m.set_shader_parameter("vein_amount", 0.35)
	return m


static func _membrane_mat(col: Color, glow: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.7
	m.rim_enabled = true
	m.rim = 0.6
	m.emission_enabled = true
	m.emission = glow * 0.08
	m.backlight_enabled = true
	m.backlight = glow * 0.22
	return m


static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return s


static func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	return c


static func _wing_mesh(span: float, depth: float, fingers: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tips: Array[Vector3] = []
	for i in fingers + 1:
		var t := float(i) / fingers
		var ang := lerpf(0.15, 1.45, t)
		var len := span * lerpf(1.0, 0.55, t)
		tips.append(Vector3(cos(ang) * len, sin(t * PI) * 0.15 * span, -sin(ang) * len * depth))
	var root := Vector3.ZERO
	for i in fingers:
		var a := tips[i]
		var b := tips[i + 1]
		var mid := (a + b) * 0.5 * 0.72    # scalloped edge between fingers
		for tri in [[root, a, mid], [root, mid, b]]:
			var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			for v in tri:
				st.set_normal(n)
				st.set_uv(Vector2(v.x / span, -v.z / span))
				st.add_vertex(v)
	return st.commit()


static func _wing(parent: Node3D, side: float, span: float, mem: Material, bone_mat: Material, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.scale = Vector3(side, 1, 1)
	parent.add_child(pivot)
	var w := MeshInstance3D.new()
	w.mesh = _wing_mesh(span, 1.0, 4)
	w.material_override = mem
	pivot.add_child(w)
	# wing "finger" bones
	for i in 5:
		var t := float(i) / 4.0
		var ang := lerpf(0.15, 1.45, t)
		var len := span * lerpf(1.0, 0.55, t)
		var bone := CylinderMesh.new()
		bone.top_radius = 0.004 * span
		bone.bottom_radius = 0.014 * span
		bone.height = len
		var bm := _part(pivot, bone, bone_mat, Vector3(cos(ang) * len * 0.5, 0.02, -sin(ang) * len * 0.5))
		bm.rotation = Vector3(0, ang, -PI / 2)
	return pivot


## Lofted tube mesh along a smoothed spine. radii: [rx, ry] per point.
static func loft(points: Array, radii: Array, rings_per_seg := 6, sides := 16) -> ArrayMesh:
	var sp: Array[Vector3] = []
	var sr: Array[Vector2] = []
	for i in points.size() - 1:
		var p0: Vector3 = points[maxi(0, i - 1)]
		var p1: Vector3 = points[i]
		var p2: Vector3 = points[i + 1]
		var p3: Vector3 = points[mini(points.size() - 1, i + 2)]
		for k in rings_per_seg:
			var t := float(k) / rings_per_seg
			sp.append(p1.cubic_interpolate(p2, p0, p3, t))
			var ra: Vector2 = radii[i]
			var rb: Vector2 = radii[i + 1]
			sr.append(ra.lerp(rb, t * t * (3.0 - 2.0 * t)))
	sp.append(points[-1])
	sr.append(radii[-1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := sp.size()
	var rings: Array = []
	for i in n:
		var tan := (sp[mini(n - 1, i + 1)] - sp[maxi(0, i - 1)]).normalized()
		var up := Vector3.UP if absf(tan.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
		var nx := tan.cross(up).normalized()
		var ny := nx.cross(tan).normalized()
		var ring: Array = []
		for k in sides + 1:
			var a := TAU * k / sides
			var off := nx * cos(a) * sr[i].x + ny * sin(a) * sr[i].y
			ring.append([sp[i] + off, off.normalized(), Vector2(float(k) / sides, float(i) / (n - 1))])
		rings.append(ring)
	for i in n - 1:
		for k in sides:
			var a: Array = rings[i][k]
			var b: Array = rings[i][k + 1]
			var c: Array = rings[i + 1][k + 1]
			var d: Array = rings[i + 1][k]
			for v in [a, b, c, a, c, d]:
				st.set_normal(v[1])
				st.set_uv(v[2])
				st.add_vertex(v[0])
	return st.commit()


static func dragon(scale: float = 1.0) -> Node3D:
	var root := FlyingCreature.new()
	root.name = "Dragon"
	var body_root := Node3D.new()
	root.add_child(body_root)
	root.body = body_root
	var scales := _scale_mat(Color(0.3, 0.06, 0.035), Color(1.0, 0.4, 0.05), "dragon_scales")
	var belly := _scale_mat(Color(0.5, 0.3, 0.15), Color(1.0, 0.5, 0.1), "dragon_belly")
	var horn := _scale_mat(Color(0.12, 0.1, 0.09), Color(1, 0.3, 0.05), "dragon_horn")
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(1, 0.8, 0.2)
	eye.emission_enabled = true
	eye.emission = Color(1, 0.6, 0.1)
	eye.emission_energy_multiplier = 6.0
	root.materials.append(scales)
	root.materials.append(belly)
	root.materials.append(horn)
	# Body + neck + head as one smooth lofted tube.
	var spine := [Vector3(0, 0.1, -1.6), Vector3(0, 0.05, -0.6), Vector3(0, 0.1, 0.5), Vector3(0, 0.35, 1.5), Vector3(0, 0.9, 2.3), Vector3(0, 1.4, 2.9), Vector3(0, 1.62, 3.45), Vector3(0, 1.58, 4.0), Vector3(0, 1.45, 4.6), Vector3(0, 1.38, 4.95)]
	var rad := [Vector2(0.5, 0.45), Vector2(0.85, 0.75), Vector2(0.95, 0.85), Vector2(0.62, 0.6), Vector2(0.42, 0.42), Vector2(0.33, 0.35), Vector2(0.4, 0.36), Vector2(0.3, 0.26), Vector2(0.2, 0.15), Vector2(0.06, 0.05)]
	var torso := MeshInstance3D.new()
	torso.mesh = loft(spine, rad)
	torso.material_override = scales
	body_root.add_child(torso)
	# Belly plates
	var bl := MeshInstance3D.new()
	bl.mesh = loft([Vector3(0, -0.35, -1.2), Vector3(0, -0.55, 0.0), Vector3(0, -0.35, 1.3), Vector3(0, 0.2, 2.2)], [Vector2(0.4, 0.2), Vector2(0.7, 0.35), Vector2(0.5, 0.3), Vector2(0.25, 0.15)])
	bl.material_override = belly
	body_root.add_child(bl)
	# Head details: jaw, horns, eyes, brow ridges
	var head := Node3D.new()
	head.position = Vector3(0, 1.58, 4.0)
	body_root.add_child(head)
	root.head = head
	var jaw := MeshInstance3D.new()
	jaw.mesh = loft([Vector3(0, -0.2, -0.4), Vector3(0, -0.28, 0.2), Vector3(0, -0.22, 0.75)], [Vector2(0.25, 0.1), Vector2(0.2, 0.08), Vector2(0.06, 0.04)])
	jaw.material_override = belly
	head.add_child(jaw)
	for s in [-1.0, 1.0]:
		var h1 := MeshInstance3D.new()
		h1.mesh = loft([Vector3(0.18 * s, 0.2, -0.35), Vector3(0.3 * s, 0.45, -0.8), Vector3(0.35 * s, 0.5, -1.3), Vector3(0.32 * s, 0.35, -1.6)], [Vector2(0.09, 0.09), Vector2(0.07, 0.07), Vector2(0.04, 0.04), Vector2(0.005, 0.005)], 5, 8)
		h1.material_override = horn
		head.add_child(h1)
		var h2 := MeshInstance3D.new()
		h2.mesh = loft([Vector3(0.3 * s, 0.05, -0.2), Vector3(0.55 * s, 0.1, -0.5), Vector3(0.62 * s, 0.05, -0.8)], [Vector2(0.05, 0.05), Vector2(0.03, 0.03), Vector2(0.003, 0.003)], 5, 8)
		h2.material_override = horn
		head.add_child(h2)
		_part(head, _sphere(0.055), eye, Vector3(0.2 * s, 0.1, 0.12))
		_part(head, _sphere(0.08), scales, Vector3(0.2 * s, 0.17, 0.08), Vector3(1.2, 0.5, 1.4))
	# Dorsal spines along the back and neck
	for i in 14:
		var t := float(i) / 13.0
		var pz := lerpf(-1.4, 3.2, t)
		var y := 0.85 if pz < 1.2 else lerpf(0.85, 1.9, (pz - 1.2) / 2.0)
		var h := lerpf(0.35, 0.18, absf(t - 0.35) * 1.5)
		_part(body_root, _cone(0.09, h), horn, Vector3(0, y, pz), Vector3.ONE, Vector3(-0.5, 0, 0))
	# Tail: separate lofted piece so it can sway from its base.
	var tail_pivot := Node3D.new()
	tail_pivot.position = Vector3(0, 0.1, -1.5)
	body_root.add_child(tail_pivot)
	var tail := MeshInstance3D.new()
	tail.mesh = loft([Vector3(0, 0, 0.1), Vector3(0, -0.05, -1.2), Vector3(0.1, 0.0, -2.6), Vector3(0, 0.1, -4.0), Vector3(-0.1, 0.15, -5.2)], [Vector2(0.48, 0.42), Vector2(0.32, 0.3), Vector2(0.2, 0.18), Vector2(0.1, 0.09), Vector2(0.02, 0.02)])
	tail.material_override = scales
	tail_pivot.add_child(tail)
	_part(tail_pivot, _cone(0.28, 0.7), horn, Vector3(-0.1, 0.15, -5.4), Vector3(1, 0.25, 1), Vector3(-PI / 2, 0, 0))
	for i in 6:
		_part(tail_pivot, _cone(0.07, 0.22), horn, Vector3(0, 0.35 - i * 0.05, -0.6 - i * 0.8), Vector3.ONE, Vector3(-0.6, 0, 0))
	root.tail.append(tail_pivot)
	# Legs (lofted, clawed, folded under in flight)
	for s in [-1.0, 1.0]:
		for z in [0.9, -0.9]:
			var leg := MeshInstance3D.new()
			leg.mesh = loft([Vector3(0.55 * s, -0.2, z), Vector3(0.75 * s, -0.7, z + 0.2), Vector3(0.7 * s, -1.0, z - 0.25), Vector3(0.72 * s, -1.15, z + 0.1)], [Vector2(0.24, 0.24), Vector2(0.16, 0.16), Vector2(0.11, 0.11), Vector2(0.08, 0.06)], 5, 10)
			leg.material_override = scales
			body_root.add_child(leg)
			for c in 3:
				_part(body_root, _cone(0.035, 0.18), horn, Vector3(0.72 * s + (c - 1) * 0.06, -1.18, z + 0.18), Vector3.ONE, Vector3(1.4, 0, 0))
	# Wings
	var mem := _membrane_mat(Color(0.16, 0.035, 0.025), Color(1.0, 0.35, 0.05))
	root.wing_l = _wing(body_root, -1.0, 4.4, mem, horn, Vector3(-0.55, 0.7, 1.0))
	root.wing_r = _wing(body_root, 1.0, 4.4, mem, horn, Vector3(0.55, 0.7, 1.0))
	root.flap_speed = 3.2
	root.scale = Vector3.ONE * scale
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root


static func raven() -> Node3D:
	var root := FlyingCreature.new()
	root.name = "Raven"
	var body_root := Node3D.new()
	root.add_child(body_root)
	root.body = body_root
	var feathers := _scale_mat(Color(0.06, 0.05, 0.08), Color(0.6, 0.2, 1.0), "raven_feathers")
	root.materials.append(feathers)
	var beak := _scale_mat(Color(0.2, 0.18, 0.16), Color(0.6, 0.2, 1.0), "raven_beak")
	var eye := StandardMaterial3D.new()
	eye.emission_enabled = true
	eye.emission = Color(0.7, 0.3, 1.0)
	eye.emission_energy_multiplier = 5.0
	_part(body_root, _sphere(0.22), feathers, Vector3.ZERO, Vector3(0.8, 0.8, 1.6))
	_part(body_root, _sphere(0.14), feathers, Vector3(0, 0.08, 0.32))
	_part(body_root, _cone(0.05, 0.2), beak, Vector3(0, 0.06, 0.5), Vector3.ONE, Vector3(PI / 2, 0, 0))
	for s in [-1.0, 1.0]:
		_part(body_root, _sphere(0.025), eye, Vector3(0.07 * s, 0.12, 0.42))
	_part(body_root, _cone(0.14, 0.35), feathers, Vector3(0, 0, -0.42), Vector3(1, 0.25, 1), Vector3(-PI / 2, 0, 0))
	var mem := _membrane_mat(Color(0.05, 0.04, 0.07), Color(0.6, 0.2, 1.0))
	root.wing_l = _wing(body_root, -1.0, 0.75, mem, feathers, Vector3(-0.1, 0.05, 0.1))
	root.wing_r = _wing(body_root, 1.0, 0.75, mem, feathers, Vector3(0.1, 0.05, 0.1))
	root.flap_speed = 9.0
	return root


static func bat_wings(glow: Color) -> Node3D:
	var root := Node3D.new()
	var mem := _membrane_mat(Color(0.12, 0.08, 0.1), glow)
	var bone := _scale_mat(Color(0.3, 0.27, 0.25), glow, "batwing_bone")
	var l := _wing(root, -1.0, 1.4, mem, bone, Vector3(-0.15, 0.2, -0.2))
	var r := _wing(root, 1.0, 1.4, mem, bone, Vector3(0.15, 0.2, -0.2))
	l.rotation = Vector3(0, -0.3, 0)
	r.rotation = Vector3(0, 0.3, 0)
	var flapper := WingFlapper.new()
	flapper.wings = [l, r]
	root.add_child(flapper)
	return root
