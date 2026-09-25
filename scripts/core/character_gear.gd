class_name CharacterGear
extends RefCounted
## Sculpted armour and trappings added on top of the rigged source characters
## so every hero / enemy gets its own dark-fantasy silhouette: spiked
## pauldrons, horns, crowns, tattered capes, glowing eyes, orbiting orbs,
## floating shard halos, back crystals, a shoulder raven, embers and smoke.
## Driven by the "gear" list of a unit's model definition. Parts ride on bone
## attachments, so they follow every animation and the heroic proportions.
##
## Skeleton space of the source rigs: Y up, Z forward. The (chibi) head bone
## sits at the neck with the head mesh ~1.1 units tall above it.

const EYE_Z := 0.58

static var _tex_cache: Dictionary = {}
static var _glow_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}


static func apply(model: CharacterModel, skel: Skeleton3D, def: Dictionary) -> void:
	var gear: Array = def.get("gear", [])
	if gear.is_empty() or skel == null:
		return
	var glow := ModelLib._col(def.get("emission", [1, 0.3, 0.05]))
	var tint := ModelLib._col(def.get("tint", [0.3, 0.3, 0.3]))
	var cloth := ModelLib._col(def.get("cloth", [tint.r * 0.9, tint.g * 0.9, tint.b * 0.9]))
	var steel := _mat(model, def, Color(0.55, 0.55, 0.56))
	var dark := _mat(model, def, Color(0.22, 0.22, 0.23))
	var gold := _mat(model, def, Color(0.7, 0.7, 0.7))
	gold.set_shader_parameter("gold_mode", 1.0)
	var bone := _mat(model, def, Color(0.86, 0.84, 0.8))
	bone.set_shader_parameter("metal", 0.1)
	var glow_m := _glow(glow, 1.6)
	for g in gear:
		var kind := str(g)
		match kind:
			"spiked_pauldrons", "pauldrons", "bone_pauldrons":
				for side in ["l", "r"]:
					var att := _att(skel, "upperarm." + side)
					if att == null:
						continue
					var pm := bone if kind == "bone_pauldrons" else steel
					_pauldron(att, pm, dark, kind != "pauldrons", side == "l")
			"horns", "big_horns":
				var h := _att(skel, "head")
				if h:
					var sz := 1.4 if kind == "big_horns" else 1.0
					for sx in [-1.0, 1.0]:
						_horn(h, bone if def.get("bone_horns", false) else dark, Vector3(0.34 * sx, 0.95, 0.02), sx, sz)
			"crown":
				var h2 := _att(skel, "head")
				if h2:
					_crown(h2, gold, glow_m, 1.13, 0.4)
			"helm_spikes":
				var h3 := _att(skel, "head")
				if h3:
					for k in 5:
						var a := -0.9 + k * 0.45
						_spike(h3, dark, Vector3(sin(a) * 0.46, 1.02 + cos(a) * 0.06, cos(a) * 0.1 - 0.05), Vector3(-0.2, 0, -a * 0.8), 0.07, 0.32)
			"eyes", "eyes_slit":
				var h4 := _att(skel, "head")
				if h4:
					for sx in [-1.0, 1.0]:
						var e := MeshInstance3D.new()
						if kind == "eyes_slit":
							var bm := BoxMesh.new()
							bm.size = Vector3(0.16, 0.035, 0.03)
							e.mesh = bm
						else:
							e.mesh = _sphere(0.055)
						e.material_override = _glow(glow, 3.0)
						e.position = Vector3(0.16 * sx, float(def.get("eye_y", 0.5)), EYE_Z + float(def.get("eye_z", 0.0)))
						e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						h4.add_child(e)
			"cape":
				var c := _att(skel, "chest")
				if c:
					_cape(model, c, cloth, glow, def)
			"orbs":
				var c2 := _att(skel, "chest")
				if c2:
					var sp := Spinner.new()
					sp.speed = 1.8
					sp.bob = 0.08
					sp.position = Vector3(0, 0.15, 0)
					c2.add_child(sp)
					for k in 3:
						var a := TAU * k / 3.0
						var o := MeshInstance3D.new()
						o.mesh = _sphere(0.09)
						o.material_override = _glow(glow, 1.4)
						o.position = Vector3(cos(a) * 0.62, 0.1 * sin(a * 2.0), sin(a) * 0.62)
						sp.add_child(o)
			"shard_halo":
				var h5 := _att(skel, "head")
				if h5:
					var sp2 := Spinner.new()
					sp2.speed = 0.9
					sp2.bob = 0.04
					sp2.position = Vector3(0, 1.25, 0)
					h5.add_child(sp2)
					for k in 7:
						var a := TAU * k / 7.0
						var s := MeshInstance3D.new()
						var pr := PrismMesh.new()
						pr.size = Vector3(0.1, 0.36, 0.1)
						s.mesh = pr
						s.material_override = _glow(glow, 1.2)
						s.position = Vector3(cos(a) * 0.55, 0, sin(a) * 0.55)
						s.rotation = Vector3(0, -a, 0.35)
						sp2.add_child(s)
			"back_crystals":
				var c3 := _att(skel, "chest")
				if c3:
					for k in 5:
						var s2 := MeshInstance3D.new()
						var pr2 := PrismMesh.new()
						pr2.size = Vector3(0.08, 0.26 + 0.06 * (k % 3), 0.08)
						s2.mesh = pr2
						s2.material_override = _crystal(glow)
						s2.position = Vector3(-0.32 + k * 0.16, 0.3 + 0.08 * (2 - absi(k - 2)), -0.3)
						s2.rotation = Vector3(-0.6, 0, (k - 2) * 0.25)
						c3.add_child(s2)
			"raven":
				var ua := _att(skel, "upperarm.l")
				if ua:
					var r := ProceduralCreatures.raven()
					r.scale = Vector3.ONE * 0.32
					r.position = Vector3(0, 0.05, 0.22)
					r.rotation = Vector3(-PI * 0.5, 0, 0)
					ua.add_child(r)
			"embers", "frost_mist", "smoke", "sparks", "spores":
				var c4 := _att(skel, "chest")
				if c4:
					c4.add_child(_aura_particles(kind, glow))
			"skull_belt":
				var hp := _att(skel, "hips")
				if hp:
					for k in 3:
						var sk := MeshInstance3D.new()
						sk.mesh = _sphere(0.07)
						sk.material_override = bone
						sk.position = Vector3(-0.15 + k * 0.15, 0.12, 0.3)
						hp.add_child(sk)
			"chest_rune":
				var c5 := _att(skel, "chest")
				if c5:
					var rn := MeshInstance3D.new()
					var tm := TorusMesh.new()
					tm.inner_radius = 0.07
					tm.outer_radius = 0.1
					rn.mesh = tm
					rn.material_override = _glow(glow, 1.5)
					rn.position = Vector3(0, 0.12, 0.3)
					rn.rotation.x = PI * 0.5
					c5.add_child(rn)


# ---------------------------------------------------------------- parts
static func _pauldron(att: Node3D, m: Material, trim: Material, spiked: bool, left: bool) -> void:
	# upperarm local space: +Y along the arm, +Z world up.
	var root := Node3D.new()
	root.position = Vector3(0, 0.07, 0.07)
	att.add_child(root)
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.2
	sm.is_hemisphere = true
	sm.radial_segments = 20
	sm.rings = 8
	dome.mesh = sm
	dome.material_override = m
	dome.rotation.x = PI * 0.5
	dome.scale = Vector3(1.15, 1.0, 1.25)
	root.add_child(dome)
	# Layered plates under the dome.
	for k in 2:
		var plate := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.2 - k * 0.02
		cm.bottom_radius = 0.23 - k * 0.02
		cm.height = 0.05
		cm.radial_segments = 16
		plate.mesh = cm
		plate.material_override = trim
		plate.rotation.x = PI * 0.5
		plate.position = Vector3(0, 0.05 + k * 0.06, -0.05 - k * 0.05)
		root.add_child(plate)
	if spiked:
		for k in 3:
			var a := -0.5 + k * 0.5
			_spike(root, trim, Vector3(0, -0.03 + k * 0.07, 0.16), Vector3(0.3 - k * 0.1, 0, a * 0.3), 0.055, 0.34 - absf(a) * 0.12)


static func _spike(parent: Node3D, m: Material, pos: Vector3, rot: Vector3, r: float, h: float) -> void:
	var s := MeshInstance3D.new()
	var key := "c%.3f|%.3f" % [r, h]
	if not _mesh_cache.has(key):
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = r
		cm.height = h
		cm.radial_segments = 8
		_mesh_cache[key] = cm
	var c: CylinderMesh = _mesh_cache[key]
	s.mesh = c
	s.material_override = m
	s.position = pos + Vector3(0, 0, 0)
	s.rotation = rot
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation = rot
	parent.add_child(holder)
	s.position = Vector3(0, h * 0.5, 0)
	s.rotation = Vector3.ZERO
	holder.add_child(s)


## Curved horn: three tapering segments that sweep outwards, up and back.
static func _horn(parent: Node3D, m: Material, base: Vector3, side: float, size: float) -> void:
	var p := Node3D.new()
	p.position = base
	p.rotation = Vector3(-0.35, 0, -0.9 * side)
	parent.add_child(p)
	var cur := p
	var r := 0.09 * size
	for k in 3:
		var seg := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.bottom_radius = r
		c.top_radius = r * 0.6 if k < 2 else 0.0
		c.height = 0.24 * size
		c.radial_segments = 10
		seg.mesh = c
		seg.material_override = m
		seg.position = Vector3(0, c.height * 0.5, 0)
		cur.add_child(seg)
		var nxt := Node3D.new()
		nxt.position = Vector3(0, c.height, 0)
		nxt.rotation = Vector3(-0.25, 0, 0.55 * side)
		cur.add_child(nxt)
		cur = nxt
		r *= 0.6


static func _crown(parent: Node3D, m: Material, gem: Material, y: float, radius: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(0, y, -0.02)
	parent.add_child(root)
	var band := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius * 0.95
	cm.height = 0.12
	cm.radial_segments = 24
	band.mesh = cm
	band.material_override = m
	root.add_child(band)
	for k in 8:
		var a := TAU * k / 8.0
		var tall := 0.3 if k % 2 == 0 else 0.18
		_spike(root, m, Vector3(cos(a) * radius * 0.95, 0.04, sin(a) * radius * 0.95), Vector3(sin(a) * 0.18, 0, -cos(a) * 0.18), 0.05, tall)
		if k % 2 == 0:
			var g := MeshInstance3D.new()
			g.mesh = _sphere(0.035)
			g.material_override = gem
			g.position = Vector3(cos(a) * radius * 1.01, 0.0, sin(a) * radius * 1.01)
			root.add_child(g)


static func _cape(model: CharacterModel, att: Node3D, cloth: Color, glow: Color, def: Dictionary) -> void:
	var len := float(def.get("cape_len", 1.35))
	var w := float(def.get("cape_w", 0.6))
	var pm := PlaneMesh.new()
	pm.size = Vector2(w, len)
	pm.subdivide_width = 6
	pm.subdivide_depth = 12
	pm.orientation = PlaneMesh.FACE_Z
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/cape.gdshader")
	m.set_shader_parameter("cloth", cloth)
	m.set_shader_parameter("glow_color", glow)
	m.set_shader_parameter("glow_strength", float(def.get("emission_strength", 1.0)))
	m.set_shader_parameter("noise_tex", ModelLib.noise_tex("detail"))
	m.set_shader_parameter("cape_len", len)
	m.set_shader_parameter("tatter", float(def.get("tatter", 0.7)))
	mi.material_override = m
	# Hang from the shoulders, behind the back, flaring slightly outwards.
	mi.position = Vector3(0, 0.32 - len * 0.5, -0.27)
	mi.rotation.x = 0.1
	att.add_child(mi)
	model.materials.append(m)


static func _aura_particles(kind: String, glow: Color) -> CPUParticles3D:
	var e := CPUParticles3D.new()
	e.amount = 8
	e.lifetime = 1.2
	e.local_coords = false
	var q := QuadMesh.new()
	e.mesh = q
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 0.45
	e.direction = Vector3.UP
	e.spread = 25.0
	e.initial_velocity_min = 0.2
	e.initial_velocity_max = 0.6
	e.gravity = Vector3(0, 0.8, 0)
	e.scale_amount_min = 0.025
	e.scale_amount_max = 0.06
	var c := glow
	match kind:
		"smoke":
			e.material_override = VFX._smoke()
			c = Color(0.08, 0.04, 0.12)
			e.scale_amount_min = 0.15
			e.scale_amount_max = 0.3
			e.gravity = Vector3(0, 0.3, 0)
		"frost_mist":
			e.material_override = VFX._additive()
			c = Color(0.6, 0.85, 1.0)
			e.gravity = Vector3(0, -0.3, 0)
		_:
			e.material_override = VFX._additive()
	var g := Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, 0.0))
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	g.add_point(0.25, Color(c.r, c.g, c.b, 0.55))
	e.color_ramp = g
	return e


static func _trail(c: Color, size: float) -> CPUParticles3D:
	var e := CPUParticles3D.new()
	e.amount = 10
	e.lifetime = 0.5
	e.local_coords = false
	e.mesh = QuadMesh.new()
	e.material_override = VFX._additive()
	e.gravity = Vector3.ZERO
	e.initial_velocity_min = 0.0
	e.initial_velocity_max = 0.05
	e.scale_amount_min = size * 0.5
	e.scale_amount_max = size
	var g := Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, 0.5))
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	e.color_ramp = g
	return e


# ---------------------------------------------------------------- helpers
static func _att(skel: Skeleton3D, bone: String) -> BoneAttachment3D:
	if skel.find_bone(bone) < 0:
		return null
	for c in skel.get_children():
		if c is BoneAttachment3D and c.bone_name == bone and c.has_meta("gear"):
			return c
	var a := BoneAttachment3D.new()
	a.bone_name = bone
	a.set_meta("gear", true)
	skel.add_child(a)
	return a


static func _mat(model: CharacterModel, def: Dictionary, c: Color) -> ShaderMaterial:
	var key := c.to_html()
	if not _tex_cache.has(key):
		var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
		img.fill(c)
		_tex_cache[key] = ImageTexture.create_from_image(img)
	var m := ModelLib.char_material(_tex_cache[key], def)
	m.set_shader_parameter("rim_strength", 0.3)
	model.materials.append(m)
	return m


static func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var key := "%s|%.2f" % [c.to_html(), energy]
	if _glow_cache.has(key):
		return _glow_cache[key]
	var m := StandardMaterial3D.new()
	_glow_cache[key] = m
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _crystal(c: Color) -> StandardMaterial3D:
	var key := "crystal|" + c.to_html()
	if _glow_cache.has(key):
		return _glow_cache[key]
	var m := StandardMaterial3D.new()
	_glow_cache[key] = m
	m.albedo_color = c.darkened(0.55)
	m.metallic = 0.3
	m.roughness = 0.15
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.35
	m.rim_enabled = true
	m.rim = 0.8
	return m


static func _sphere(r: float) -> SphereMesh:
	var key := "s%.3f" % r
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var s := SphereMesh.new()
	_mesh_cache[key] = s
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s
