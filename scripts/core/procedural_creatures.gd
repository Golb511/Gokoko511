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
	m.emission = glow * 0.25
	m.backlight_enabled = true
	m.backlight = glow * 0.6
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
		bone.top_radius = 0.015 * span
		bone.bottom_radius = 0.04 * span
		bone.height = len
		var bm := _part(pivot, bone, bone_mat, Vector3(cos(ang) * len * 0.5, 0.02, -sin(ang) * len * 0.5))
		bm.rotation = Vector3(0, ang, -PI / 2)
	return pivot


static func dragon(scale: float = 1.0) -> Node3D:
	var root := FlyingCreature.new()
	root.name = "Dragon"
	var body_root := Node3D.new()
	root.add_child(body_root)
	root.body = body_root
	var scales := _scale_mat(Color(0.35, 0.07, 0.04), Color(1.0, 0.4, 0.05), "dragon_scales")
	var belly := _scale_mat(Color(0.55, 0.35, 0.18), Color(1.0, 0.5, 0.1), "dragon_belly")
	var horn := _scale_mat(Color(0.12, 0.1, 0.09), Color(1, 0.3, 0.05), "dragon_horn")
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(1, 0.8, 0.2)
	eye.emission_enabled = true
	eye.emission = Color(1, 0.6, 0.1)
	eye.emission_energy_multiplier = 6.0
	root.materials.append(scales)
	root.materials.append(belly)
	root.materials.append(horn)
	# torso
	_part(body_root, _sphere(1.0), scales, Vector3(0, 0, 0), Vector3(0.95, 0.8, 1.7))
	_part(body_root, _sphere(0.9), belly, Vector3(0, -0.25, 0.2), Vector3(0.8, 0.6, 1.4))
	_part(body_root, _sphere(0.85), scales, Vector3(0, 0.15, 1.1), Vector3(1.0, 0.9, 1.0))
	# neck
	var neck_pts := [Vector3(0, 0.45, 1.8), Vector3(0, 0.85, 2.3), Vector3(0, 1.2, 2.75), Vector3(0, 1.45, 3.2)]
	for i in neck_pts.size():
		_part(body_root, _sphere(0.5 - i * 0.07), scales, neck_pts[i], Vector3(1, 1, 1.2))
		_part(body_root, _cone(0.12, 0.45), horn, neck_pts[i] + Vector3(0, 0.45 - i * 0.05, -0.1), Vector3.ONE, Vector3(-0.5, 0, 0))
	# head
	var head := Node3D.new()
	head.position = Vector3(0, 1.6, 3.7)
	body_root.add_child(head)
	root.head = head
	_part(head, _sphere(0.42), scales, Vector3(0, 0, 0), Vector3(1.0, 0.8, 1.3))
	_part(head, _sphere(0.3), scales, Vector3(0, -0.05, 0.5), Vector3(0.9, 0.6, 1.5))
	_part(head, _sphere(0.26), belly, Vector3(0, -0.28, 0.4), Vector3(0.85, 0.35, 1.5))
	for s in [-1.0, 1.0]:
		_part(head, _cone(0.1, 0.9), horn, Vector3(0.2 * s, 0.3, -0.35), Vector3.ONE, Vector3(-2.2, 0, 0.35 * s))
		_part(head, _cone(0.06, 0.5), horn, Vector3(0.32 * s, 0.1, -0.25), Vector3.ONE, Vector3(-2.0, 0, 0.8 * s))
		_part(head, _sphere(0.06), eye, Vector3(0.22 * s, 0.12, 0.28))
	# tail
	var prev := Vector3(0, 0, -1.4)
	for i in 9:
		var r := 0.55 * pow(0.8, i)
		var p := prev + Vector3(0, -0.02 * i, -0.55 + i * 0.01)
		var seg := _part(body_root, _sphere(r), scales, p, Vector3(1, 0.9, 1.3))
		root.tail.append(seg)
		_part(seg, _cone(0.1, 0.35), horn, Vector3(0, r * 0.9 / 0.9, 0), Vector3(1, 1, 1), Vector3(-0.4, 0, 0))
		prev = p
	_part(body_root, _cone(0.3, 0.8), horn, prev + Vector3(0, 0, -0.4), Vector3(1, 0.3, 1), Vector3(-PI / 2, 0, 0))
	# legs
	for s in [-1.0, 1.0]:
		for z in [0.9, -0.8]:
			var leg := _part(body_root, CapsuleMesh.new(), scales, Vector3(0.65 * s, -0.7, z), Vector3(0.35, 0.5, 0.35), Vector3(0.6, 0, 0))
			_part(leg, _cone(0.15, 0.5), horn, Vector3(0, -1.1, 0.3), Vector3.ONE * 1.5, Vector3(1.2, 0, 0))
	# wings
	var mem := _membrane_mat(Color(0.18, 0.04, 0.03), Color(1.0, 0.35, 0.05))
	root.wing_l = _wing(body_root, -1.0, 4.2, mem, horn, Vector3(-0.6, 0.6, 1.0))
	root.wing_r = _wing(body_root, 1.0, 4.2, mem, horn, Vector3(0.6, 0.6, 1.0))
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
