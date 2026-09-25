class_name ProjectileVisuals
extends RefCounted
## Builds the look of each projectile type (arrow models, glowing orbs with
## trails and lights, iron bombs with sparks, diving ravens).

static var _mats: Dictionary = {}


static func _glow_mat(c: Color, energy := 4.0) -> StandardMaterial3D:
	var key := "%s_%.1f" % [c, energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


static func _orb(root: Node3D, c: Color, r: float, trail := true, light := true) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = _glow_mat(c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * r * 5.0
	halo.mesh = q
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_texture = ModelLib.radial_tex()
	hm.albedo_color = Color(c.r, c.g, c.b, 0.8)
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	if trail:
		var e := CPUParticles3D.new()
		e.amount = 24
		e.lifetime = 0.35
		e.local_coords = false
		var qm := QuadMesh.new()
		e.mesh = qm
		e.material_override = VFX._additive()
		e.gravity = Vector3(0, 0.5, 0)
		e.initial_velocity_max = 0.3
		e.scale_amount_min = r * 1.5
		e.scale_amount_max = r * 3.0
		var curve := Curve.new()
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(1, 0))
		e.scale_amount_curve = curve
		e.color_ramp = VFX._ramp(c)
		root.add_child(e)
	if light and VFX._quality >= 2:
		var l := OmniLight3D.new()
		l.light_volumetric_fog_energy = 0.2
		l.light_color = c
		l.light_energy = 1.5
		l.omni_range = 3.5
		root.add_child(l)


static func make(type: String) -> Node3D:
	var root := Node3D.new()
	match type:
		"arrow", "bolt", "shadow_arrow":
			var a := _arrow_model()
			root.add_child(a)
			if type == "shadow_arrow":
				_orb(root, Color(0.6, 0.2, 1.0), 0.08, true, false)
			elif type == "bolt":
				a.scale *= 1.2
		"fireball":
			_orb(root, Color(1.0, 0.45, 0.08), 0.22)
		"blue_fireball":
			_orb(root, Color(0.25, 0.55, 1.0), 0.24)
		"frost_bolt":
			_orb(root, Color(0.5, 0.85, 1.0), 0.16)
			var ice := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.15, 0.6, 0.15)
			ice.mesh = pm
			ice.rotation.x = -PI / 2
			ice.material_override = _glow_mat(Color(0.7, 0.9, 1.0), 2.0)
			root.add_child(ice)
		"poison_bolt":
			_orb(root, Color(0.4, 1.0, 0.2), 0.18)
		"arcane_orb":
			_orb(root, Color(0.75, 0.4, 1.0), 0.2)
		"shadow_orb":
			_orb(root, Color(0.5, 0.15, 0.9), 0.22)
		"lightning_orb":
			_orb(root, Color(0.6, 0.8, 1.0), 0.15)
		"bomb":
			var mi := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.3
			s.height = 0.6
			mi.mesh = s
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.08, 0.07, 0.07)
			m.metallic = 0.9
			m.roughness = 0.35
			mi.material_override = m
			root.add_child(mi)
			var e := CPUParticles3D.new()
			e.amount = 16
			e.lifetime = 0.3
			e.local_coords = false
			e.mesh = QuadMesh.new()
			e.material_override = VFX._additive()
			e.scale_amount_min = 0.1
			e.scale_amount_max = 0.25
			e.color_ramp = VFX._ramp(Color(1, 0.5, 0.1))
			e.position = Vector3(0, 0.3, 0)
			root.add_child(e)
		"raven":
			var r := ProceduralCreatures.raven()
			r.rotation.y = PI
			root.add_child(r)
		_:
			_orb(root, Color(1, 0.8, 0.5), 0.15)
	return root


static func _arrow_model() -> Node3D:
	var ps := ModelLib.scene("res://assets/models/weapons/arrow.gltf")
	var holder := Node3D.new()
	if ps:
		var a: Node3D = ps.instantiate()
		holder.add_child(a)
		a.rotation_degrees = Vector3(-90, 0, 0)   # model points +Y; look_at uses -Z forward
		a.scale = Vector3.ONE * 1.3
	return holder
