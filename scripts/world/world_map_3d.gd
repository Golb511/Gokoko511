class_name WorldMap3D
extends Node3D
## 3D overworld: eight themed regions, connecting roads, a river, stage
## markers with star counts, animated fires/crystals and a pannable camera.

signal stage_clicked(stage_id: String)
signal region_clicked(region_idx: int)

const SCALE := 1.7
var camera: Camera3D
var cam_target := Vector3(0, 0, 4)
var cam_dist := 60.0
var stage_markers: Dictionary = {}     # stage_id -> Node3D
var region_centers: Array[Vector3] = []
var rng := RandomNumberGenerator.new()
var _dragging := false
var _press := Vector2.ZERO
var _touches := {}
var _pinch := 0.0


func _ready() -> void:
	rng.seed = 1337
	var theme := {"sky_top": [0.03, 0.03, 0.05], "sky_horizon": [0.3, 0.14, 0.08], "fog": [0.12, 0.09, 0.09], "ambient": [0.3, 0.28, 0.34], "sun": [1.0, 0.82, 0.7], "sun_energy": 1.7}
	var we := GraphicsSettings.make_environment(theme)
	we.environment.fog_density = 0.004
	add_child(we)
	add_child(GraphicsSettings.make_sun(theme))
	_terrain()
	for i in DB.regions.size():
		var r: Dictionary = DB.regions[i]
		var c := Vector3(float(r.map_pos[0]) * SCALE, 0, float(r.map_pos[1]) * SCALE)
		region_centers.append(c)
	_roads()
	_river()
	for i in DB.regions.size():
		_region(i)
	VFX.ambient(self, "embers", Vector3(0, 4, 0), Vector3(60, 4, 45))
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.far = 500.0
	add_child(camera)
	camera.current = true
	var focus := region_centers[0]
	var nxt := Game.next_stage()
	if nxt != "":
		focus = region_centers[DB.stage_info(nxt).region_idx]
	cam_target = focus + Vector3(0, 0, 4)
	_apply_cam()


func _terrain() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(260, 200)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/ground.gdshader")
	m.set_shader_parameter("noise_tex", ModelLib.noise_tex("detail"))
	m.set_shader_parameter("cell_tex", ModelLib.noise_tex("cell"))
	m.set_shader_parameter("normal_tex", ModelLib.noise_tex("normal"))
	m.set_shader_parameter("color_a", Color(0.16, 0.15, 0.13))
	m.set_shader_parameter("color_b", Color(0.08, 0.075, 0.07))
	m.set_shader_parameter("moss", 0.25)
	mi.material_override = m
	add_child(mi)
	# Outer mountain ring
	for k in 70:
		var a := TAU * k / 70.0
		var p := Vector3(cos(a) * rng.randf_range(72, 88), 0, sin(a) * rng.randf_range(52, 64))
		var n := ModelLib.prop("env/mountain_" + ["A", "B", "C"][k % 3], Color(0.2, 0.19, 0.2))
		add_child(n)
		n.position = p
		n.scale = Vector3.ONE * rng.randf_range(8, 14)
		n.rotation.y = rng.randf() * TAU


func _roads() -> void:
	var pts: Array = []
	var order := [7, 1, 0, 2, 3, 4, 5, 6]
	for idx in order:
		pts.append([region_centers[idx].x, region_centers[idx].z])
	var r := PathRoute.new()
	r.build(pts)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(r.length / 0.8)
	var pl := Vector3.ZERO
	var pr := Vector3.ZERO
	for i in n + 1:
		var off := r.length * i / n
		var p := r.sample(off)
		var d := r.direction(off)
		var side := Vector3(-d.z, 0, d.x)
		var l := p - side * 1.1 + Vector3(0, 0.04, 0)
		var rr := p + side * 1.1 + Vector3(0, 0.04, 0)
		if i > 0:
			for v in [[l, 0.0], [rr, 1.0], [pl, 0.0], [rr, 1.0], [pr, 1.0], [pl, 0.0]]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v[1], off))
				st.add_vertex(v[0])
		pl = l
		pr = rr
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/road.gdshader")
	m.set_shader_parameter("cell_tex", ModelLib.noise_tex("cell"))
	m.set_shader_parameter("noise_tex", ModelLib.noise_tex("detail"))
	m.set_shader_parameter("normal_tex", ModelLib.noise_tex("cell_normal"))
	m.set_shader_parameter("stone_color", Color(0.3, 0.25, 0.2))
	m.set_shader_parameter("edge_color", Color(0.08, 0.08, 0.06))
	mi.material_override = m
	add_child(mi)


func _river() -> void:
	var r := PathRoute.new()
	r.build([[70, -50], [40, -30], [28, -8], [36, 10], [18, 30], [-5, 40], [-40, 52]])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(r.length / 1.0)
	var pl := Vector3.ZERO
	var pr := Vector3.ZERO
	for i in n + 1:
		var off := r.length * i / n
		var p := r.sample(off)
		var d := r.direction(off)
		var side := Vector3(-d.z, 0, d.x)
		var w := 2.2 + sin(off * 0.1) * 0.8
		var l := p - side * w + Vector3(0, 0.03, 0)
		var rr := p + side * w + Vector3(0, 0.03, 0)
		if i > 0:
			for v in [l, rr, pl, rr, pr, pl]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		pl = l
		pr = rr
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.12, 0.18)
	m.metallic = 0.6
	m.roughness = 0.08
	m.emission_enabled = true
	m.emission = Color(0.05, 0.2, 0.35)
	m.emission_energy_multiplier = 0.6
	m.normal_enabled = true
	m.normal_texture = ModelLib.noise_tex("normal")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.2, 0.2, 0.2)
	mi.material_override = m
	add_child(mi)


func _p(key: String, pos: Vector3, s: float, tint := Color(0.4, 0.38, 0.36), accent := Color(1, 0.4, 0.1), acc_s := 0.0, snow := 0.0) -> Node3D:
	var n := ModelLib.prop(key, tint, accent, acc_s, snow)
	add_child(n)
	n.position = pos
	n.scale = Vector3.ONE * s * 1.45
	n.rotation.y = rng.randf() * TAU
	return n


func _around(c: Vector3, rmin: float, rmax: float) -> Vector3:
	var a := rng.randf() * TAU
	return c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(rmin, rmax)


func _region(i: int) -> void:
	var r: Dictionary = DB.regions[i]
	var c := region_centers[i]
	var col := ModelLib._col(r.color)
	var unlocked := Game.is_region_unlocked(i)
	match r.id:
		"shattered_citadel":
			var castle := _p("env/building_castle_red", c, 3.2, Color(0.38, 0.35, 0.34), col, 0.5)
			castle.rotation.y = 0.3
			for k in 5:
				_p(["env/building_destroyed", "env/wall_straight", "env/building_tower_A_red"][k % 3], _around(c, 5, 8), 2.2, Color(0.35, 0.32, 0.3))
			for k in 4:
				VFX.torch_flame(self, _around(c, 3, 6) + Vector3(0, 0.5, 0))
		"shadow_lands":
			for k in 7:
				_p("graveyard/tree_dead_" + ["large", "medium"][k % 2], _around(c, 1, 7), 1.6, Color(0.22, 0.22, 0.3))
			_p("env/building_tower_B_red", c, 2.6, Color(0.25, 0.27, 0.38), col, 1.0)
			_crystal_cluster(c + Vector3(3, 0, 2), col)
		"inferno_tower":
			var t := _p("env/building_tower_A_red", c, 4.0, Color(0.34, 0.2, 0.16), col, 1.2)
			VFX.fire_pillar(self, c + Vector3(0, t.scale.y * 2.3, 0), 2.5, true)
			for k in 4:
				_lava(_around(c, 4, 7))
			var l := OmniLight3D.new()
			l.light_color = col
			l.light_energy = 5.0
			l.omni_range = 16.0
			add_child(l)
			l.position = c + Vector3(0, 8, 0)
		"poison_forest":
			for k in 12:
				_p(["env/trees_A_large", "env/trees_B_large", "env/tree_single_A"][k % 3], _around(c, 0.5, 8), rng.randf_range(2.0, 3.0), Color(0.18, 0.3, 0.16))
			_crystal_cluster(c, col, true)
		"frost_lands":
			for k in 6:
				_p("env/mountain_" + ["A", "B", "C"][k % 3], _around(c, 2, 8), rng.randf_range(3.5, 6.0), Color(0.55, 0.62, 0.72), col, 0.0, 1.0)
			_crystal_cluster(c + Vector3(-2, 0, 3), col)
			_crystal_cluster(c + Vector3(3, 0, -1), col)
		"tower_of_evil":
			var t := _p("graveyard/crypt", c, 1.3, Color(0.3, 0.24, 0.36), col, 1.5)
			t.scale.y = 2.2
			_crystal_cluster(c + Vector3(4, 0, 2), col)
			_crystal_cluster(c + Vector3(-4, 0, -2), col)
			var ring := VFX.particles(self, c + Vector3(0, 0.5, 0), {"amount": 60, "lifetime": 2.0, "one_shot": false, "speed": 0.6, "size": 0.4, "color": col, "radius": 5.0, "gravity": Vector3(0, 1.0, 0), "explosiveness": 0.0})
			ring.flatness = 1.0
		"oblivion_crypt":
			for k in 14:
				_p(["graveyard/grave_A", "graveyard/grave_B", "graveyard/gravestone", "graveyard/skull"][k % 4], _around(c, 1, 7), 1.6, Color(0.38, 0.38, 0.36))
			_p("graveyard/crypt", c + Vector3(0, 0, -2), 0.9, Color(0.32, 0.32, 0.3), col, 0.6)
			VFX.ambient(self, "shadow", c + Vector3(0, 1, 0), Vector3(7, 1, 7))
		"the_gate":
			var g := _p("graveyard/arch_gate", c, 3.0, Color(0.28, 0.24, 0.3), col, 1.5)
			g.rotation.y = 0.6
			VFX.particles(self, c + Vector3(0, 3.5, 0), {"amount": 90, "lifetime": 1.8, "one_shot": false, "speed": 1.0, "size": 0.9, "color": col, "box": Vector3(2.5, 2.5, 0.4), "explosiveness": 0.0})
			var l := OmniLight3D.new()
			l.light_color = col
			l.light_energy = 6.0
			l.omni_range = 14.0
			add_child(l)
			l.position = c + Vector3(0, 4, 0)
	# Region banner label
	var lbl := Label3D.new()
	lbl.text = tr("region." + str(r.id))
	lbl.font = UITheme.font_bold()
	lbl.font_size = 110
	lbl.pixel_size = 0.028
	lbl.outline_size = 18
	lbl.outline_modulate = Color(0, 0, 0, 0.9)
	lbl.modulate = UITheme.GOLD if unlocked else Color(0.55, 0.5, 0.45)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = c + Vector3(0, 11.0, 0)
	add_child(lbl)
	# Stage markers in an arc in front of the region.
	var n: int = r.stages.size()
	for si in n:
		var s: Dictionary = r.stages[si]
		var a := PI * 0.15 + PI * 0.7 * si / maxf(1, n - 1)
		var mp := c + Vector3(cos(a) * 10.5, 0, sin(a) * 7.5)
		_stage_marker(s.id, mp, col, s.get("boss", false))


func _stage_marker(stage_id: String, pos: Vector3, col: Color, boss: bool) -> void:
	var unlocked := Game.is_stage_unlocked(stage_id)
	var stars := Game.stage_stars(stage_id)
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	root.scale = Vector3.ONE * 1.6
	var base := ModelLib.prop("env/building_tower_base_red", Color(0.3, 0.28, 0.27))
	base.scale = Vector3(0.9, 0.25, 0.9)
	root.add_child(base)
	var gem := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.6, 1.1, 0.6) * (1.4 if boss else 1.0)
	gem.mesh = pm
	var m := StandardMaterial3D.new()
	var gc := (Color(1, 0.2, 0.1) if boss else col) if unlocked else Color(0.3, 0.3, 0.3)
	m.albedo_color = gc
	m.emission_enabled = true
	m.emission = gc
	m.emission_energy_multiplier = 3.0 if unlocked else 0.2
	gem.material_override = m
	gem.position.y = 1.4
	root.add_child(gem)
	var spin := gem.create_tween().set_loops()
	spin.tween_property(gem, "rotation:y", TAU, 4.0).from(0.0)
	if unlocked and stars == 0:
		VFX.particles(root, pos + Vector3(0, 1.4, 0), {"amount": 16, "lifetime": 1.2, "one_shot": false, "speed": 0.5, "size": 0.2, "color": gc, "radius": 0.5, "gravity": Vector3(0, 1.2, 0), "explosiveness": 0.0})
		var l := OmniLight3D.new()
		l.light_color = gc
		l.light_energy = 2.0
		l.omni_range = 4.0
		l.position.y = 1.5
		root.add_child(l)
	var lbl := Label3D.new()
	lbl.text = DB.stage_label(stage_id) + ("  ★%d" % stars if stars > 0 else "")
	lbl.font = UITheme.font_bold()
	lbl.font_size = 72
	lbl.pixel_size = 0.022
	lbl.outline_size = 12
	lbl.modulate = Color(1, 0.85, 0.4) if unlocked else Color(0.5, 0.48, 0.45)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0, 2.6, 0)
	root.add_child(lbl)
	stage_markers[stage_id] = root


func _lava(p: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = rng.randf_range(1.0, 2.0)
	cyl.bottom_radius = cyl.top_radius
	cyl.height = 0.05
	mi.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.06, 0.02)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.3, 0.03)
	m.emission_energy_multiplier = 1.2
	m.emission_texture = ModelLib.noise_tex("detail")
	mi.material_override = m
	add_child(mi)
	mi.position = p + Vector3(0, 0.03, 0)


func _crystal_cluster(p: Vector3, c: Color, mush := false) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = c.darkened(0.3)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.5
	m.roughness = 0.15
	for k in 6:
		var mi := MeshInstance3D.new()
		if mush:
			var sm := SphereMesh.new()
			sm.radius = rng.randf_range(0.4, 0.9)
			sm.height = sm.radius
			sm.is_hemisphere = true
			mi.mesh = sm
			mi.position = p + Vector3(rng.randf_range(-2, 2), 0.6, rng.randf_range(-2, 2))
		else:
			var pm := PrismMesh.new()
			pm.size = Vector3(0.6, rng.randf_range(1.5, 3.5), 0.6)
			mi.mesh = pm
			mi.position = p + Vector3(rng.randf_range(-1.5, 1.5), pm.size.y * 0.4, rng.randf_range(-1.5, 1.5))
			mi.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		mi.material_override = m
		add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 2.5
	l.omni_range = 7.0
	add_child(l)
	l.position = p + Vector3(0, 2, 0)


# ---------------------------------------------------------------- camera & picking
func _apply_cam() -> void:
	cam_target.x = clampf(cam_target.x, -55, 55)
	cam_target.z = clampf(cam_target.z, -40, 45)
	var pitch := deg_to_rad(55.0)
	camera.position = cam_target + Vector3(0, sin(pitch) * cam_dist, cos(pitch) * cam_dist)
	camera.look_at(cam_target)


func focus_region(i: int) -> void:
	var tw := create_tween()
	tw.tween_method(func(v): cam_target = v; _apply_cam(), cam_target, region_centers[i] + Vector3(0, 0, 3), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func handle_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() < 2:
			_pinch = 0.0
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var pts := _touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch > 0.0:
				cam_dist = clampf(cam_dist * _pinch / maxf(1.0, d), 24.0, 80.0)
				_apply_cam()
			_pinch = d
			_dragging = true
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam_dist = clampf(cam_dist * 0.9, 24.0, 80.0)
			_apply_cam()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam_dist = clampf(cam_dist * 1.1, 24.0, 80.0)
			_apply_cam()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press = event.position
				_dragging = false
			elif not _dragging and _touches.size() < 2:
				_pick(event.position)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if event.position.distance_to(_press) > 10.0:
			_dragging = true
		if _dragging and _touches.size() < 2:
			var k := cam_dist / 700.0
			cam_target += Vector3(-event.relative.x, 0, -event.relative.y * 1.2) * k
			_apply_cam()


func _pick(screen: Vector2) -> void:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return
	var p := from + dir * (-from.y / dir.y)
	var best := ""
	var bd := 2.8
	for id in stage_markers:
		var d := Vector2(stage_markers[id].position.x - p.x, stage_markers[id].position.z - p.z).length()
		if d < bd:
			bd = d
			best = id
	if best != "":
		stage_clicked.emit(best)
		return
	for i in region_centers.size():
		if Vector2(region_centers[i].x - p.x, region_centers[i].z - p.z).length() < 8.0:
			region_clicked.emit(i)
			return
