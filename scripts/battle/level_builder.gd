class_name LevelBuilder
extends RefCounted
## Builds a playable battlefield from a layout + region theme: terrain, roads,
## build slots, citadel, enemy portal, themed props, mountains, lights, weather.

var battle: Node
var root: Node3D
var theme: Dictionary
var layout: Dictionary
var routes: Array[PathRoute] = []
var slots: Array[BuildSlot] = []
var bounds := Rect2()
var castle_pos := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var _occupied: Array = []      # [Vector3, radius]


func build(b: Node, parent: Node3D, stage_id: String) -> void:
	battle = b
	root = parent
	var info := DB.stage_info(stage_id)
	layout = DB.stage_map(stage_id)
	# Stage atmosphere overrides the region's base theme key by key.
	theme = info.region.theme.duplicate(true)
	theme.merge(layout.get("theme", {}), true)
	rng.seed = hash(stage_id)
	var bb: Array = layout.bounds
	bounds = Rect2(float(bb[0]), float(bb[1]), float(bb[2]) - float(bb[0]), float(bb[3]) - float(bb[1]))
	for p in layout.paths:
		var r := PathRoute.new()
		r.air = bool(p.get("air", false))
		r.build(p.points)
		routes.append(r)
	castle_pos = Vector3(float(layout.castle[0]), 0, float(layout.castle[1]))
	root.add_child(GraphicsSettings.make_environment(theme))
	root.add_child(GraphicsSettings.make_sun(theme))
	_ground()
	for r in ground_routes():
		_road(r)
	_castle()
	for r in routes:
		if r.air:
			Atmosphere.air_portal(root, r)
			_occupied.append([r.sample(0.0), 4.0])
		else:
			_portal(r)
	_landmarks()
	_water()
	if layout.has("slots"):
		_authored_slots()
	else:
		_slots()
	Atmosphere.build(self, theme)
	_graveyard_rows()
	_crystal_spots()
	_mountains()
	_decor()
	VFX.ambient(root, theme.get("particles", "embers"), Vector3(bounds.get_center().x, 3, bounds.get_center().y), Vector3(bounds.size.x * 0.5, 3, bounds.size.y * 0.5))


func ground_routes() -> Array[PathRoute]:
	var out: Array[PathRoute] = []
	for r in routes:
		if not r.air:
			out.append(r)
	return out


func _authored_slots() -> void:
	var i := 0
	for s in layout.slots:
		var p := Vector3(float(s[0]), 0, float(s[1]))
		var slot := BuildSlot.new()
		slot.name = "Slot%d" % i
		root.add_child(slot)
		slot.setup(battle, p)
		slots.append(slot)
		_occupied.append([p, 3.0])
		i += 1


func _landmarks() -> void:
	for lm in layout.get("landmarks", []):
		var p := Vector3(float(lm.pos[0]), 0, float(lm.pos[1]))
		var tint := ModelLib._col(lm.get("tint", [0.35, 0.33, 0.32]))
		var acc := ModelLib._col(lm.get("accent", [1, 0.4, 0.1]))
		var n := _place(lm.model, p, float(lm.get("scale", 1.0)), float(lm.get("rot", 0.0)), tint, acc, float(lm.get("accent_s", 0.0)))
		n.name = "Landmark"
		if lm.has("light") and GraphicsSettings.quality() >= 1:
			var lc: Array = lm.light
			var l := OmniLight3D.new()
			l.light_color = Color(lc[0], lc[1], lc[2])
			l.light_energy = float(lc[3]) if lc.size() > 3 else 2.5
			l.omni_range = 9.0
			root.add_child(l)
			l.global_position = p + Vector3(0, 3.5, 0)
		_occupied.append([p, float(lm.get("clear", 3.0))])


func _water() -> void:
	for w in layout.get("water", []):
		var p := Vector3(float(w[0]), 0, float(w[1]))
		Atmosphere.water_pool(root, p, float(w[2]), rng)
		_occupied.append([p, float(w[2])])


func _graveyard_rows() -> void:
	for g in layout.get("graveyard_rows", []):
		for cx in int(g[2]):
			for cz in int(g[3]):
				var p := Vector3(float(g[0]) + cx * 2.4 - g[2] * 1.2, 0, float(g[1]) + cz * 2.6 - g[3] * 1.3)
				if not _free(p, 0.8):
					continue
				var key: String = ["graveyard/grave_A", "graveyard/grave_B", "graveyard/gravestone"][rng.randi() % 3]
				_place(key, p, rng.randf_range(1.4, 1.8), PI + rng.randf_range(-0.25, 0.25), Color(0.34, 0.34, 0.33))
				_occupied.append([p, 1.0])
				if rng.randf() < 0.18:
					VFX.torch_flame(root, p + Vector3(0.6, 0.2, 0.3), ModelLib._col(theme.get("road_torches", {}).get("color", [0.75, 0.35, 1.0])), false)


func _crystal_spots() -> void:
	for c in layout.get("crystals", []):
		var p := Vector3(float(c[0]), 0, float(c[1]))
		_crystals(p, Color(0.65, 0.2, 1.0))
		_occupied.append([p, 2.0])


func _c(key: String, def := [0.2, 0.2, 0.2]) -> Color:
	var a: Array = theme.get(key, def)
	return Color(float(a[0]), float(a[1]), float(a[2]))


func _ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(bounds.size.x + 140, bounds.size.y + 140)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/ground.gdshader")
	m.set_shader_parameter("noise_tex", ModelLib.noise_tex("detail"))
	m.set_shader_parameter("cell_tex", ModelLib.noise_tex("cell"))
	m.set_shader_parameter("normal_tex", ModelLib.noise_tex("normal"))
	m.set_shader_parameter("color_a", _c("ground"))
	m.set_shader_parameter("color_b", _c("ground2"))
	var props: Array = theme.get("props", [])
	m.set_shader_parameter("lava", 1.0 if "lava" in props else 0.0)
	m.set_shader_parameter("snow", 1.0 if theme.get("particles", "") == "snow" else 0.0)
	m.set_shader_parameter("moss", 1.0 if theme.get("particles", "") == "spores" else 0.0)
	mi.material_override = m
	mi.position = Vector3(bounds.get_center().x, 0, bounds.get_center().y)
	root.add_child(mi)


func _road(r: PathRoute) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 1.9
	var n := int(r.length / 0.6)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in n + 1:
		var off := r.length * i / n
		var p := r.sample(off)
		var d := r.direction(off)
		var side := Vector3(-d.z, 0, d.x)
		var l := p - side * w + Vector3(0, 0.03, 0)
		var rr := p + side * w + Vector3(0, 0.03, 0)
		if i > 0:
			for v in [[l, 0.0], [rr, 1.0], [prev_l, 0.0], [rr, 1.0], [prev_r, 1.0], [prev_l, 0.0]]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v[1], off))
				st.add_vertex(v[0])
		prev_l = l
		prev_r = rr
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/road.gdshader")
	m.set_shader_parameter("cell_tex", ModelLib.noise_tex("cell"))
	m.set_shader_parameter("noise_tex", ModelLib.noise_tex("detail"))
	m.set_shader_parameter("normal_tex", ModelLib.noise_tex("cell_normal"))
	m.set_shader_parameter("stone_color", _c("path"))
	m.set_shader_parameter("edge_color", _c("ground2"))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	for i in range(0, r.points.size(), 4):
		_occupied.append([r.points[i], 3.0])


func _place(path_key: String, pos: Vector3, scale: float, rot := -1.0, tint := Color(0.42, 0.4, 0.38), accent := Color(1, 0.4, 0.1), accent_s := 0.0) -> Node3D:
	var snow := 1.0 if theme.get("particles", "") == "snow" else 0.0
	var n := ModelLib.prop(path_key, tint, accent, accent_s, snow)
	root.add_child(n)
	n.global_position = pos
	n.scale = Vector3.ONE * scale
	n.rotation.y = rng.randf() * TAU if rot < 0.0 else rot
	return n


func _castle() -> void:
	var r := ground_routes()[0]
	var end := r.sample(r.length)
	var dir := r.direction(r.length - 1.0)
	var face := atan2(-dir.x, -dir.z)
	var c := _place("env/building_castle_red", castle_pos, 2.6, face, Color(0.4, 0.37, 0.36), Color(1, 0.5, 0.15), 0.4)
	c.name = "Citadel"
	var side := Vector3(-dir.z, 0, dir.x)
	for s in [-1.0, 1.0]:
		for k in range(1, 4):
			var wp: Vector3 = castle_pos + side * s * (3.2 + k * 2.3) - dir * 1.5
			_place("env/wall_straight", wp, 2.3, face + PI / 2, Color(0.36, 0.34, 0.33))
		var tw := _place("env/building_tower_A_red", castle_pos + side * s * 11.0 - dir * 1.5, 2.2, face, Color(0.4, 0.37, 0.35))
		VFX.torch_flame(root, tw.global_position + Vector3(0, 5.3, 0))
	for s in [-1.0, 1.0]:
		VFX.torch_flame(root, end + side * s * 2.6 + Vector3(0, 0.1, 0) - dir * 1.0, Color(1, 0.5, 0.15))
		_place("graveyard/lantern_standing", end + side * s * 2.6 - dir * 1.0, 1.4, face, Color(0.35, 0.33, 0.3))
	_occupied.append([castle_pos, 9.0])
	for s in [-1.0, 1.0]:
		_occupied.append([castle_pos + side * s * 8.0, 4.0])


func _portal(r: PathRoute) -> void:
	var start := r.sample(0.0)
	var dir := r.direction(0.5)
	var gate := _place("graveyard/arch_gate", start + dir * 1.0, 1.8, atan2(dir.x, dir.z), Color(0.3, 0.27, 0.3), Color(0.7, 0.2, 1.0), 1.2)
	gate.name = "Portal"
	var col := Color(0.75, 0.2, 1.0) if theme.get("particles", "") != "embers" else Color(1.0, 0.3, 0.1)
	VFX.particles(root, start + dir * 1.0 + Vector3(0, 2.2, 0), {"amount": 70, "lifetime": 1.6, "one_shot": false, "speed": 1.0, "size": 0.7, "color": col, "box": Vector3(1.8, 1.8, 0.3), "gravity": Vector3(0, 0.3, 0), "explosiveness": 0.0})
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 4.0
	l.omni_range = 10.0
	root.add_child(l)
	l.global_position = start + Vector3(0, 3, 0)
	_occupied.append([start, 5.0])


func _slots() -> void:
	var cands: Array[Vector3] = []
	for r in ground_routes():
		var off := 7.0
		while off < r.length - 6.0:
			var p := r.sample(off)
			var d := r.direction(off)
			var side := Vector3(-d.z, 0, d.x)
			for s in [-1.0, 1.0]:
				cands.append(p + side * s * 4.4)
			off += 5.5
	cands.shuffle()
	var placed: Array[Vector3] = []
	var want := 14
	for c in cands:
		if placed.size() >= want:
			break
		if not _in_bounds(c, 3.0):
			continue
		var ok := true
		for r in ground_routes():
			if r.distance_to(c) < 3.6:
				ok = false
		for p in placed:
			if p.distance_to(c) < 5.2:
				ok = false
		if c.distance_to(castle_pos) < 9.0 or c.distance_to(routes[0].sample(0)) < 6.0:
			ok = false
		if ok:
			placed.append(c)
	placed.sort_custom(func(a, b): return a.z < b.z)
	for i in placed.size():
		var s := BuildSlot.new()
		s.name = "Slot%d" % i
		root.add_child(s)
		s.setup(battle, placed[i])
		slots.append(s)
		_occupied.append([placed[i], 3.0])


func _in_bounds(p: Vector3, margin := 0.0) -> bool:
	return p.x > bounds.position.x + margin and p.x < bounds.end.x - margin and p.z > bounds.position.y + margin and p.z < bounds.end.y - margin


func _free(p: Vector3, r: float) -> bool:
	for o in _occupied:
		if (o[0] as Vector3).distance_to(p) < float(o[1]) + r:
			return false
	return true


func _mountains() -> void:
	var tint := Color(0.23, 0.21, 0.2)
	var per := bounds.size.x * 2 + bounds.size.y * 2
	var step := 7.0
	var t := 0.0
	var snow: bool = theme.get("particles", "") == "snow"
	while t < per:
		var p := _perimeter(t)
		var outward := (p - Vector3(bounds.get_center().x, 0, bounds.get_center().y)).normalized()
		p += outward * rng.randf_range(11.0, 18.0)
		# keep the camera-facing (south) edge low so it never blocks the view
		var south := p.z > bounds.end.y - 2.0
		var key: String = ["env/mountain_A", "env/mountain_B", "env/mountain_C"][rng.randi() % 3]
		if south:
			key = ["env/rock_single_A", "env/rock_single_B", "env/hill_single_A"][rng.randi() % 3]
		var sc := rng.randf_range(5.5, 9.0) * (0.45 if south else 1.0)
		var n := _place(key, p, sc, -1.0, Color(tint.r, tint.g, tint.b) * (1.4 if snow else 1.0))
		n.scale.y *= rng.randf_range(0.55, 1.0) * (0.6 if south else 1.0)
		t += step * rng.randf_range(0.7, 1.3)


func _perimeter(t: float) -> Vector3:
	var w := bounds.size.x
	var h := bounds.size.y
	if t < w:
		return Vector3(bounds.position.x + t, 0, bounds.position.y)
	t -= w
	if t < h:
		return Vector3(bounds.end.x, 0, bounds.position.y + t)
	t -= h
	if t < w:
		return Vector3(bounds.end.x - t, 0, bounds.end.y)
	t -= w
	return Vector3(bounds.position.x, 0, bounds.end.y - t)


func _random_point() -> Vector3:
	return Vector3(rng.randf_range(bounds.position.x, bounds.end.x), 0, rng.randf_range(bounds.position.y, bounds.end.y))


func _decor() -> void:
	var props: Array = theme.get("props", [])
	var tint := Color(0.4, 0.38, 0.36)
	var count := 110 if GraphicsSettings.quality() >= 2 else 60
	var tries := 0
	var placed := 0
	var lights := 0
	while placed < count and tries < count * 12:
		tries += 1
		var p := _random_point()
		var kind: String = props[rng.randi() % props.size()]
		var r := 1.2
		if kind in ["ruins", "trees"]:
			r = 2.2
		if not _free(p, r):
			continue
		placed += 1
		_occupied.append([p, r])
		match kind:
			"ruins":
				var key: String = ["env/building_destroyed", "env/wall_straight", "graveyard/arch", "graveyard/fence_broken", "env/building_scaffolding"][rng.randi() % 5]
				_place(key, p, rng.randf_range(1.8, 2.6), -1.0, tint * 0.9)
				if rng.randf() < 0.25 and lights < 10:
					lights += 1
					VFX.torch_flame(root, p + Vector3(0, 0.3, 0), Color(1, 0.45, 0.1), true)
			"dead_trees":
				var key: String = ["graveyard/tree_dead_large", "graveyard/tree_dead_medium", "graveyard/tree_dead_small"][rng.randi() % 3]
				_place(key, p, rng.randf_range(0.9, 1.5), -1.0, Color(0.3, 0.27, 0.25))
			"trees":
				var key: String = ["env/trees_A_large", "env/trees_B_large", "env/tree_single_A", "env/tree_single_B"][rng.randi() % 4]
				_place(key, p, rng.randf_range(2.0, 3.0), -1.0, Color(0.22, 0.3, 0.2))
			"graves":
				var key: String = ["graveyard/grave_A", "graveyard/grave_B", "graveyard/gravestone", "graveyard/coffin", "graveyard/skull", "graveyard/ribcage", "graveyard/post_skull", "graveyard/bone_A"][rng.randi() % 8]
				_place(key, p, rng.randf_range(1.2, 1.8), -1.0, Color(0.4, 0.4, 0.38))
			"rocks":
				var key: String = ["env/rock_single_A", "env/rock_single_B", "env/rock_single_C"][rng.randi() % 3]
				_place(key, p, rng.randf_range(1.5, 3.2), -1.0, _c("ground").lightened(0.6))
			"torches":
				if lights < 16:
					lights += 1
					_place("graveyard/lantern_standing", p, 1.5, -1.0, Color(0.3, 0.28, 0.26))
					VFX.torch_flame(root, p + Vector3(0, 1.55, 0), Color(1, 0.5, 0.15), true)
			"lava":
				_lava_pool(p)
			"crystals_purple":
				_crystals(p, Color(0.65, 0.2, 1.0))
			"crystals_ice":
				_crystals(p, Color(0.45, 0.85, 1.0))
			"mushrooms":
				_crystals(p, Color(0.4, 1.0, 0.25), true)


func _lava_pool(p: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rng.randf_range(1.0, 2.2)
	cyl.bottom_radius = cyl.top_radius
	cyl.height = 0.05
	cyl.radial_segments = 20
	mi.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.06, 0.02)
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = Color(1.0, 0.28, 0.02)
	m.emission_energy_multiplier = 1.1
	m.emission_texture = ModelLib.noise_tex("detail")
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mi.material_override = m
	mi.scale = Vector3(1, 1, rng.randf_range(0.5, 1.0))
	root.add_child(mi)
	mi.global_position = p + Vector3(0, 0.02, 0)
	VFX.particles(root, p + Vector3(0, 0.2, 0), {"amount": 8, "lifetime": 1.5, "one_shot": false, "speed": 0.8, "size": 0.2, "color": Color(1, 0.5, 0.1), "radius": cyl.top_radius * 0.6, "gravity": Vector3(0, 1.2, 0), "explosiveness": 0.0})
	for k in 3:
		var rock_p := p + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * (cyl.top_radius + 0.3)
		_place("env/rock_single_" + ["A", "B", "C"][k], rock_p, 1.2, -1.0, Color(0.2, 0.18, 0.17))


func _crystals(p: Vector3, c: Color, mushrooms := false) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	holder.global_position = p
	var m := StandardMaterial3D.new()
	m.albedo_color = c.darkened(0.3)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.1
	m.metallic = 0.3
	m.roughness = 0.15
	for k in rng.randi_range(3, 6):
		var mi := MeshInstance3D.new()
		if mushrooms:
			var sm := SphereMesh.new()
			sm.radius = rng.randf_range(0.2, 0.45)
			sm.height = sm.radius
			sm.is_hemisphere = true
			mi.mesh = sm
			var stem := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.06
			cm.bottom_radius = 0.09
			cm.height = 0.5
			stem.mesh = cm
			stem.position.y = -0.25
			var sm2 := StandardMaterial3D.new()
			sm2.albedo_color = Color(0.3, 0.28, 0.22)
			stem.material_override = sm2
			mi.add_child(stem)
			mi.position = Vector3(rng.randf_range(-0.8, 0.8), 0.5, rng.randf_range(-0.8, 0.8))
		else:
			var pm := PrismMesh.new()
			pm.size = Vector3(rng.randf_range(0.3, 0.6), rng.randf_range(0.9, 2.2), rng.randf_range(0.3, 0.6))
			mi.mesh = pm
			mi.position = Vector3(rng.randf_range(-0.7, 0.7), pm.size.y * 0.4, rng.randf_range(-0.7, 0.7))
			mi.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
		mi.material_override = m
		holder.add_child(mi)
	if rng.randf() < 0.4 and GraphicsSettings.quality() >= 2:
		var l := OmniLight3D.new()
		l.light_color = c
		l.light_energy = 1.5
		l.omni_range = 5.0
		l.position.y = 1.0
		holder.add_child(l)
