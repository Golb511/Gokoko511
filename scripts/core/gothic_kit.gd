class_name GothicKit
extends RefCounted
## Procedural dark-gothic architecture for the defence towers. Each tower type
## has its own hand-designed silhouette (watch spire, arcane spire, siege
## bastion, barracks keep, plague cauldron, brazier tower, frost obelisk,
## storm spire, void obelisk, cathedral shrine, rock bastion, aeolian tower,
## ballista platform, trap workshop) that grows with the tower level and gains
## a crown of pinnacles once a branch is chosen.
##
## All parts of one tower are baked into a single mesh; the part type is in
## the vertex colour and read by gothic_stone.gdshader (stone / slate-iron /
## gold / glowing). Footprint ~2.6 m, height ~3-6 m, y up, centred at origin.

const STONE := Color(0, 0, 0)
const ROOF := Color(0, 1, 0)
const GOLD := Color(0, 0, 1)
const GLOW := Color(1, 0, 0)
const CRYSTAL := Color(0.5, 0, 0)

static var _shader: Shader


## Returns {"node": Node3D, "top": float (height of the top platform / muzzle),
## "material": ShaderMaterial}.
static func tower(kind: String, accent: Color, level: int, branch: int, seed: int) -> Dictionary:
	var mk := MK.new()
	var extras: Array[Node3D] = []
	var top := 3.0
	var lv := clampi(level, 1, 3) + (1 if branch >= 0 else 0)
	_plinth(mk, lv)
	match kind:
		"archer": top = _watch_spire(mk, lv, extras, accent)
		"mage": top = _arcane_spire(mk, lv)
		"artillery": top = _siege_bastion(mk, lv)
		"soldier": top = _barracks_keep(mk, lv, extras, accent)
		"poison": top = _plague_cauldron(mk, lv)
		"fire": top = _brazier_tower(mk, lv)
		"ice": top = _frost_obelisk(mk, lv, seed)
		"lightning": top = _storm_spire(mk, lv)
		"shadow": top = _void_obelisk(mk, lv, seed)
		"light": top = _cathedral_shrine(mk, lv)
		"earth": top = _rock_bastion(mk, lv, seed)
		"wind": top = _aeolian_tower(mk, lv, extras)
		"crossbow": top = _ballista_platform(mk, lv)
		"trap": top = _trap_workshop(mk, lv)
		_: top = _watch_spire(mk, lv, extras, accent)
	if branch >= 0:
		_branch_crown(mk, top, branch)
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mk.commit()
	var mat := material(accent, 2.2 + lv * 0.5)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.add_child(mi)
	for e in extras:
		node.add_child(e)
		_apply_mat(e, mat)
	return {"node": node, "top": top, "material": mat}


static func material(accent: Color, energy: float) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://assets/shaders/gothic_stone.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("detail_tex", ModelLib.noise_tex("detail"))
	m.set_shader_parameter("detail_normal", ModelLib.noise_tex("normal"))
	m.set_shader_parameter("accent", accent)
	m.set_shader_parameter("glow_energy", energy)
	return m


static func _apply_mat(n: Node, mat: Material) -> void:
	if n is MeshInstance3D and n.material_override == null:
		n.material_override = mat
	for c in n.get_children():
		_apply_mat(c, mat)


# ================================================================ buildings
## Drop-in gothic replacements for the red-roofed source buildings, fitted to
## the original prop's bounding box so every existing placement keeps its size.
const REPLACE := {
	"env/building_castle_red": "citadel",
	"env/building_tower_A_red": "spire_a",
	"env/building_tower_B_red": "spire_b",
	"env/building_tower_base_red": "plinth",
	"env/wall_straight": "wall",
}
static var _aabb_cache: Dictionary = {}


static func replaces(path_key: String) -> bool:
	return REPLACE.has(path_key)


static func replacement(path_key: String, tint: Color, accent: Color, accent_strength: float, snow := 0.0) -> Node3D:
	var mk := MK.new()
	match str(REPLACE[path_key]):
		"citadel": _citadel(mk)
		"spire_a":
			_plinth(mk, 2)
			_watch_spire(mk, 3, [] as Array[Node3D], accent)
		"spire_b":
			_plinth(mk, 2)
			_arcane_spire(mk, 3)
			_spire(mk, 8, 0.5, 3.35 + 3 * 0.35, 1.4, PI / 8.0)
		"wall":
			_wall(mk, _source_aabb(path_key))
		"plinth":
			mk.prism(8, 1.32, 1.26, 0.0, 0.16, STONE, PI / 8.0)
			mk.prism(8, 1.18, 1.12, 0.16, 0.3, STONE, PI / 8.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mk.commit()
	var mat := material(accent, 0.8 + accent_strength * 1.6)
	mat.set_shader_parameter("stone_color", Color(tint.r * 1.05, tint.g * 1.02, tint.b, 1.0))
	mat.set_shader_parameter("snow", snow)
	mi.material_override = mat
	var holder := Node3D.new()
	holder.add_child(mi)
	# Fit to the original footprint.
	var want := _source_aabb(path_key)
	var have := mi.mesh.get_aabb()
	if want.size != Vector3.ZERO and have.size != Vector3.ZERO:
		var sc := maxf(want.size.x, want.size.z) / maxf(0.01, maxf(have.size.x, have.size.z))
		if str(REPLACE[path_key]) == "wall":
			mi.scale = Vector3.ONE
		elif str(REPLACE[path_key]) == "plinth":
			mi.scale = Vector3(sc, want.size.y / maxf(0.01, have.size.y), sc)
		else:
			mi.scale = Vector3.ONE * sc
		var c_want := want.get_center()
		var c_have := have.get_center() * mi.scale
		mi.position = Vector3(c_want.x - c_have.x, want.position.y - have.position.y * mi.scale.y, c_want.z - c_have.z)
	return holder


static func _source_aabb(path_key: String) -> AABB:
	if _aabb_cache.has(path_key):
		return _aabb_cache[path_key]
	var out := AABB()
	var ps := ModelLib.scene("res://assets/models/%s.gltf" % path_key)
	if ps:
		var inst: Node3D = ps.instantiate()
		var first := true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = mi.get_aabb()
			var n: Node = mi
			while n != null and n != inst.get_parent():
				if n is Node3D:
					a = (n as Node3D).transform * a
				if n == inst:
					break
				n = n.get_parent()
			out = a if first else out.merge(a)
			first = false
		inst.free()
	_aabb_cache[path_key] = out
	return out


## Crenellated curtain wall matching the source wall's proportions.
static func _wall(mk: MK, src: AABB) -> void:
	var along_x := src.size.x < src.size.z   # the source wall runs across its bounding box
	var l := maxf(src.size.x, src.size.z) * 1.05
	var h := maxf(0.6, src.size.y) * 0.58
	var t := maxf(0.16, minf(src.size.x, src.size.z) * 0.28)
	var sz := Vector3(l, h, t) if along_x else Vector3(t, h, l)
	mk.box(Vector3(0, h * 0.5, 0), sz, STONE)
	var n := maxi(3, int(l / (t * 1.1)))
	for i in n:
		if i % 2 == 1:
			continue
		var f := -l * 0.5 + (float(i) + 0.5) * l / float(n)
		var c := Vector3(f, h + h * 0.12, 0) if along_x else Vector3(0, h + h * 0.12, f)
		var s2 := Vector3(l / float(n), h * 0.24, t * 1.05) if along_x else Vector3(t * 1.05, h * 0.24, l / float(n))
		mk.box(c, s2, STONE)
	# A buttress at each end.
	for e in [-1.0, 1.0]:
		var c2 := Vector3(e * l * 0.5, h * 0.45, 0) if along_x else Vector3(0, h * 0.45, e * l * 0.5)
		mk.box(c2, Vector3(t * 1.4, h * 0.9, t * 1.4), STONE)


## The player's citadel: a buttressed keep with a great glowing gate (+Z),
## four corner towers with slate spires and a tall central spire.
static func _citadel(mk: MK) -> void:
	mk.box(Vector3(0, 0.25, 0), Vector3(9.4, 0.5, 9.4), STONE)
	mk.box(Vector3(0, 0.6, 0), Vector3(8.6, 0.2, 8.6), STONE)
	var h := 5.2
	mk.box(Vector3(0, 0.7 + h * 0.5, 0), Vector3(5.6, h, 5.6), STONE)
	mk.box(Vector3(0, 0.7 + h + 0.1, 0), Vector3(6.0, 0.2, 6.0), STONE)
	for i in 4:
		var a := TAU * float(i) / 4.0
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x)
		for k in 9:
			mk.box(d * 2.95 + side * (-2.6 + k * 0.65) + Vector3(0, 0.7 + h + 0.4, 0), Vector3(0.36 if k % 2 == 0 else 0.3, 0.6, 0.3), STONE, Vector3(0, -a + PI * 0.5, 0))
		# Tall lancet windows.
		for k in 3:
			var c := d * 2.82 + side * (-1.5 + k * 1.5) + Vector3(0, 0.7 + h * 0.62, 0)
			mk.box(c, Vector3(0.34, 1.3, 0.08), GLOW, Vector3(0, -a + PI * 0.5, 0))
			mk.box(c + Vector3(0, 0.72, 0), Vector3(0.24, 0.24, 0.08), GLOW, Vector3(0, -a + PI * 0.5, PI * 0.25))
			mk.box(c - d * 0.05 + Vector3(0, -0.72, 0), Vector3(0.6, 0.12, 0.2), STONE, Vector3(0, -a + PI * 0.5, 0))
		# Buttresses between the windows.
		for k in 2:
			var b := d * 3.0 + side * (-0.75 + k * 1.5)
			mk.box(b + Vector3(0, 0.7 + h * 0.4, 0), Vector3(0.4, h * 0.8, 0.5), STONE, Vector3(0, -a + PI * 0.5, 0))
			_pinnacle(mk, b + Vector3(0, 0.7 + h * 0.8, 0), 0.9)
	# Great gate facing +Z.
	mk.box(Vector3(0, 0.7 + 1.35, 2.83), Vector3(1.8, 2.7, 0.1), GLOW)
	mk.box(Vector3(0, 0.7 + 2.9, 2.83), Vector3(1.28, 1.28, 0.1), GLOW, Vector3(0, 0, PI * 0.25))
	mk.box(Vector3(0, 0.7 + 1.6, 2.95), Vector3(2.5, 3.4, 0.16), ROOF)
	mk.box(Vector3(0, 0.7 + 3.55, 2.9), Vector3(2.9, 0.3, 0.4), GOLD)
	# Corner towers.
	for c in [Vector3(-3.1, 0, -3.1), Vector3(3.1, 0, -3.1), Vector3(-3.1, 0, 3.1), Vector3(3.1, 0, 3.1)]:
		mk.prism(8, 1.25, 1.1, 0.6, 0.6 + h + 1.6, STONE, PI / 8.0, true, false, c)
		for k in 2:
			for j in 4:
				var a2 := TAU * (float(j) + 0.5) / 4.0
				var dd := Vector3(cos(a2), 0, sin(a2))
				mk.box(c + dd * 1.15 + Vector3(0, 2.2 + k * 2.3, 0), Vector3(0.18, 0.7, 0.06), GLOW, Vector3(0, -a2 + PI * 0.5, 0))
		var ty := 0.6 + h + 1.6
		mk.prism(8, 1.1, 1.45, ty, ty + 0.3, STONE, PI / 8.0, false, false, c)
		mk.prism(8, 1.45, 1.45, ty + 0.3, ty + 0.5, STONE, PI / 8.0, true, false, c)
		mk.prism(8, 1.3, 0.02, ty + 0.5, ty + 3.2, ROOF, PI / 8.0, false, false, c)
		mk.prism(6, 0.06, 0.06, ty + 3.1, ty + 3.6, GOLD, 0.0, true, false, c)
	# Central keep spire.
	var ky := 0.7 + h + 0.2
	mk.prism(8, 1.7, 1.5, ky, ky + 2.4, STONE, PI / 8.0)
	for j in 8:
		var a3 := TAU * (float(j) + 0.5) / 8.0
		mk.box(Vector3(cos(a3), 0, sin(a3)) * 1.58 + Vector3(0, ky + 1.3, 0), Vector3(0.2, 1.0, 0.06), GLOW, Vector3(0, -a3 + PI * 0.5, 0))
	_spire(mk, 8, 1.65, ky + 2.4, 4.6, PI / 8.0)


# ================================================================ shared parts
static func _plinth(mk: MK, lv: int) -> void:
	mk.prism(8, 1.32, 1.26, 0.0, 0.16, STONE, PI / 8.0)
	mk.prism(8, 1.18, 1.12, 0.16, 0.3, STONE, PI / 8.0)
	if lv >= 3:
		mk.prism(8, 1.34, 1.34, 0.0, 0.05, GOLD, PI / 8.0, false)


## Arrow-slit windows around an n-gon shaft (radius r at height y).
static func _slits(mk: MK, sides: int, r: float, y: float, h: float, count: int, rot := 0.0, glow := true) -> void:
	for i in count:
		var a := rot + TAU * (float(i) + 0.5) / float(count)
		var d := Vector3(cos(a), 0, sin(a))
		var c := d * (r * cos(PI / float(sides)) + 0.015) + Vector3(0, y, 0)
		mk.box(c, Vector3(0.12, h, 0.06), GLOW if glow else ROOF, Vector3(0, -a + PI * 0.5, 0))
		# Pointed arch cap and stone frame.
		mk.box(c + d * 0.01 + Vector3(0, h * 0.5 + 0.05, 0), Vector3(0.09, 0.09, 0.05), GLOW if glow else ROOF, Vector3(0, -a + PI * 0.5, PI * 0.25))
		mk.box(c - d * 0.02 + Vector3(0, -h * 0.5 - 0.04, 0), Vector3(0.24, 0.06, 0.1), STONE, Vector3(0, -a + PI * 0.5, 0))


static func _crenels(mk: MK, r: float, y: float, count: int, h := 0.26, w := 0.26) -> void:
	for i in count:
		var a := TAU * float(i) / float(count)
		var d := Vector3(cos(a), 0, sin(a))
		mk.box(d * r + Vector3(0, y + h * 0.5, 0), Vector3(w, h, 0.18), STONE, Vector3(0, -a + PI * 0.5, 0))


## Corbelled walkway: a wider ring on stepped brackets.
static func _corbel(mk: MK, sides: int, r_in: float, r_out: float, y: float, rot := 0.0) -> void:
	for i in sides:
		var a := rot + TAU * (float(i) + 0.5) / float(sides)
		var d := Vector3(cos(a), 0, sin(a))
		mk.box(d * (r_in + 0.06) + Vector3(0, y - 0.2, 0), Vector3(0.14, 0.3, 0.2), STONE, Vector3(0, -a + PI * 0.5, 0))
	mk.prism(sides, r_in, r_out, y - 0.08, y, STONE, rot, false)
	mk.prism(sides, r_out, r_out, y, y + 0.14, STONE, rot)


static func _spire(mk: MK, sides: int, r: float, y: float, h: float, rot := 0.0, finial := true) -> void:
	mk.prism(sides, r * 1.08, r, y, y + 0.08, STONE, rot, false)
	mk.prism(sides, r, 0.02, y + 0.08, y + h, ROOF, rot, false)
	if finial:
		mk.prism(6, 0.05, 0.05, y + h - 0.05, y + h + 0.3, GOLD)
		mk.prism(6, 0.1, 0.0, y + h + 0.22, y + h + 0.42, GOLD)
		mk.box(Vector3(0, y + h + 0.2, 0), Vector3(0.26, 0.04, 0.04), GOLD)


static func _pinnacle(mk: MK, c: Vector3, h: float, col := STONE) -> void:
	mk.prism(4, 0.1, 0.09, c.y, c.y + h * 0.55, col, PI * 0.25, false, false, c)
	mk.prism(4, 0.1, 0.0, c.y + h * 0.55, c.y + h, ROOF if col == STONE else col, PI * 0.25, false, false, c)


static func _buttresses(mk: MK, count: int, r: float, h: float, rot := 0.0) -> void:
	for i in count:
		var a := rot + TAU * float(i) / float(count)
		var d := Vector3(cos(a), 0, sin(a))
		mk.box(d * (r + 0.12) + Vector3(0, h * 0.35, 0), Vector3(0.2, h * 0.7, 0.34), STONE, Vector3(0, -a, 0))
		mk.box(d * (r + 0.26) + Vector3(0, h * 0.14, 0), Vector3(0.22, h * 0.28, 0.3), STONE, Vector3(0, -a, 0))
		_pinnacle(mk, d * (r + 0.12) + Vector3(0, h * 0.7, 0), 0.45)


static func _branch_crown(mk: MK, top: float, branch: int) -> void:
	var n := 4 if branch == 0 else 6
	for i in n:
		var a := TAU * float(i) / float(n) + PI * 0.25
		var d := Vector3(cos(a), 0, sin(a))
		mk.box(d * 0.95 + Vector3(0, top - 0.1, 0), Vector3(0.1, 0.32, 0.1), GLOW, Vector3(0, -a, 0.2))
		mk.prism(4, 0.07, 0.0, top + 0.06, top + 0.36, GOLD, 0.0, false, false, d * 0.95 + Vector3(0, top + 0.06, 0))


# ================================================================ towers
static func _watch_spire(mk: MK, lv: int, extras: Array[Node3D], accent: Color) -> float:
	var h := 2.2 + lv * 0.3
	mk.prism(8, 0.82, 0.68, 0.3, 0.3 + h, STONE, PI / 8.0)
	mk.prism(8, 0.86, 0.86, 0.3 + h * 0.42, 0.3 + h * 0.42 + 0.1, STONE, PI / 8.0)
	_slits(mk, 8, 0.75, 0.3 + h * 0.25, 0.42, 4, PI / 8.0)
	_slits(mk, 8, 0.7, 0.3 + h * 0.68, 0.36, 4 if lv < 3 else 8, 0.0)
	var y := 0.3 + h
	_corbel(mk, 8, 0.68, 1.0, y, PI / 8.0)
	_crenels(mk, 0.92, y + 0.14, 8 + lv * 2)
	if lv >= 2:
		_buttresses(mk, 4, 0.78, h * 0.55, PI * 0.25)
	# Small conical roof over the lookout, open sides for the archers.
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		mk.box(Vector3(cos(a) * 0.55, y + 0.55, sin(a) * 0.55), Vector3(0.1, 0.8, 0.1), STONE)
	_spire(mk, 8, 0.78, y + 0.95, 1.1 + lv * 0.25, PI / 8.0)
	extras.append(_banner(accent, Vector3(0.62, y + 1.3, 0.62)))
	return y + 0.2


static func _arcane_spire(mk: MK, lv: int) -> float:
	var h := 2.6 + lv * 0.35
	mk.prism(4, 0.72, 0.52, 0.3, 0.3 + h, STONE, PI * 0.25)
	_buttresses(mk, 4, 0.6, h * 0.75, 0.0)
	_slits(mk, 4, 0.62, 0.3 + h * 0.3, 0.6, 4, PI * 0.25)
	_slits(mk, 4, 0.55, 0.3 + h * 0.72, 0.5, 4, PI * 0.25)
	mk.prism(4, 0.62, 0.62, 0.3 + h * 0.5, 0.36 + h * 0.5, GOLD, PI * 0.25, false)
	var y := 0.3 + h
	mk.prism(8, 0.6, 0.7, y, y + 0.16, STONE, 0.0)
	# Open crown of four pinnacles around the floating crystal.
	for i in 4:
		var a := TAU * float(i) / 4.0
		_pinnacle(mk, Vector3(cos(a) * 0.55, y + 0.16, sin(a) * 0.55), 0.9 + lv * 0.12)
		mk.box(Vector3(cos(a) * 0.35, y + 0.6, sin(a) * 0.35), Vector3(0.05, 0.5, 0.05), GLOW, Vector3(0, -a, 0.6))
	return y + 0.3


static func _siege_bastion(mk: MK, lv: int) -> float:
	var h := 1.1 + lv * 0.15
	mk.prism(12, 1.1, 1.0, 0.3, 0.3 + h, STONE, 0.0)
	mk.prism(12, 1.14, 1.14, 0.3 + h * 0.5, 0.38 + h * 0.5, STONE)
	_slits(mk, 12, 1.02, 0.3 + h * 0.45, 0.28, 6)
	var y := 0.3 + h
	_crenels(mk, 1.02, y, 12, 0.32, 0.3)
	# Heavy iron mortar on a turntable.
	mk.prism(10, 0.55, 0.5, y, y + 0.2, ROOF)
	var b := Basis.from_euler(Vector3(-0.75, 0.4, 0))
	mk.cyl_basis(Vector3(0, y + 0.55, 0), b, 0.26, 0.3, 1.0, ROOF)
	mk.cyl_basis(Vector3(0, y + 0.55, 0) + b.y * 0.5, b, 0.3, 0.3, 0.12, GOLD)
	mk.cyl_basis(Vector3(0, y + 0.55, 0) + b.y * 0.53, b, 0.2, 0.2, 0.02, GLOW)
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.9
		mk.sphere_lo(Vector3(cos(a) * 0.75, y + 0.12, sin(a) * 0.75), 0.14, ROOF)
	if lv >= 2:
		_buttresses(mk, 6, 1.0, h, 0.26)
	return y + 0.4


static func _barracks_keep(mk: MK, lv: int, extras: Array[Node3D], accent: Color) -> float:
	var h := 1.5 + lv * 0.2
	mk.box(Vector3(0, 0.3 + h * 0.5, 0), Vector3(1.9, h, 1.5), STONE)
	mk.box(Vector3(0, 0.3 + h + 0.06, 0), Vector3(2.0, 0.12, 1.6), STONE)
	# Arched glowing gate and windows.
	mk.box(Vector3(0, 0.3 + 0.42, 0.76), Vector3(0.52, 0.84, 0.05), GLOW)
	mk.box(Vector3(0, 0.3 + 0.9, 0.76), Vector3(0.36, 0.36, 0.05), GLOW, Vector3(0, 0, PI * 0.25))
	mk.box(Vector3(0, 0.3 + 0.42, 0.8), Vector3(0.66, 0.96, 0.04), ROOF)
	for sx in [-0.62, 0.62]:
		mk.box(Vector3(sx, 0.3 + h * 0.65, 0.76), Vector3(0.14, 0.4, 0.05), GLOW)
	var y := 0.3 + h + 0.12
	for i in 6:
		mk.box(Vector3(-0.85 + i * 0.34, y + 0.13, 0.72), Vector3(0.22, 0.26, 0.14), STONE)
		mk.box(Vector3(-0.85 + i * 0.34, y + 0.13, -0.72), Vector3(0.22, 0.26, 0.14), STONE)
	# Corner turrets.
	for c in [Vector3(-0.95, 0, 0.75), Vector3(0.95, 0, 0.75), Vector3(-0.95, 0, -0.75), Vector3(0.95, 0, -0.75)]:
		mk.prism(8, 0.3, 0.27, 0.3, y + 0.35, STONE, 0.0, true, false, c)
		mk.prism(8, 0.34, 0.0, y + 0.35, y + 1.0 + lv * 0.1, ROOF, 0.0, false, false, c)
	extras.append(_banner(accent, Vector3(0, y + 0.9, 0)))
	return y + 0.2


static func _plague_cauldron(mk: MK, lv: int) -> float:
	mk.prism(10, 1.05, 1.0, 0.3, 0.75, STONE)
	_crenels(mk, 0.98, 0.75, 10, 0.2, 0.26)
	mk.sphere_lo(Vector3(0, 1.05, 0), 0.72, ROOF, true)
	mk.prism(16, 0.72, 0.75, 1.02, 1.12, GOLD)
	mk.prism(16, 0.66, 0.66, 1.02, 1.07, GLOW)
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		mk.box(Vector3(cos(a) * 0.75, 0.68, sin(a) * 0.75), Vector3(0.14, 0.7, 0.14), ROOF, Vector3(0, -a, 0.35))
	# Chimneys / alchemical pipes.
	var n := 1 + lv
	for i in n:
		var a := TAU * float(i) / float(n) + 1.9
		var c := Vector3(cos(a) * 0.95, 0, sin(a) * 0.95)
		mk.prism(6, 0.1, 0.09, 0.75, 1.6 + 0.2 * i, ROOF, 0.0, true, false, c)
		mk.prism(6, 0.14, 0.14, 1.55 + 0.2 * i, 1.65 + 0.2 * i, GOLD, 0.0, true, false, c)
	return 1.25


static func _brazier_tower(mk: MK, lv: int) -> float:
	var h := 2.0 + lv * 0.3
	mk.prism(6, 0.8, 0.62, 0.3, 0.3 + h, STONE, 0.0)
	_slits(mk, 6, 0.7, 0.3 + h * 0.4, 0.5, 3, 0.0)
	_slits(mk, 6, 0.66, 0.3 + h * 0.75, 0.3, 3, PI / 3.0)
	if lv >= 2:
		_buttresses(mk, 3, 0.72, h * 0.6, PI / 6.0)
	var y := 0.3 + h
	mk.prism(6, 0.62, 0.9, y, y + 0.25, STONE)
	# Iron cage brazier bowl with glowing coals.
	mk.prism(8, 0.62, 0.8, y + 0.25, y + 0.55, ROOF, 0.0, false)
	mk.prism(8, 0.62, 0.62, y + 0.4, y + 0.48, GLOW)
	for i in 6:
		var a := TAU * float(i) / 6.0
		mk.box(Vector3(cos(a) * 0.78, y + 0.75, sin(a) * 0.78), Vector3(0.06, 0.55, 0.06), ROOF, Vector3(0, -a, -0.25))
	return y + 0.6


static func _frost_obelisk(mk: MK, lv: int, seed: int) -> float:
	mk.prism(8, 0.95, 0.85, 0.3, 0.9, STONE, PI / 8.0)
	_crenels(mk, 0.85, 0.9, 8, 0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tall := 2.2 + lv * 0.45
	mk.crystal(Vector3(0, 0.9, 0), 0.34, tall, CRYSTAL, Vector3.ZERO)
	for i in 5 + lv:
		var a := TAU * float(i) / float(5 + lv) + rng.randf() * 0.4
		var r := 0.35 + rng.randf() * 0.25
		var hh := tall * (0.3 + rng.randf() * 0.35)
		mk.crystal(Vector3(cos(a) * r, 0.9, sin(a) * r), 0.16 + rng.randf() * 0.08, hh, CRYSTAL, Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35))
	return 0.9 + tall * 0.75


static func _storm_spire(mk: MK, lv: int) -> float:
	var h := 2.8 + lv * 0.35
	mk.prism(8, 0.7, 0.42, 0.3, 0.3 + h, STONE, PI / 8.0)
	_buttresses(mk, 4, 0.6, h * 0.6, PI * 0.25)
	_slits(mk, 8, 0.6, 0.3 + h * 0.35, 0.4, 4, PI / 8.0)
	# Copper coils winding up the shaft.
	for k in 3 + lv:
		var y := 0.9 + k * (h - 0.9) / float(3 + lv)
		var rr := lerpf(0.72, 0.46, (y - 0.3) / h) + 0.04
		mk.prism(12, rr, rr, y, y + 0.07, GOLD)
	var y2 := 0.3 + h
	mk.prism(8, 0.42, 0.6, y2, y2 + 0.2, STONE, PI / 8.0)
	mk.prism(6, 0.05, 0.05, y2 + 0.2, y2 + 1.0, GOLD)
	return y2 + 0.5


static func _void_obelisk(mk: MK, lv: int, seed: int) -> float:
	var h := 2.4 + lv * 0.4
	mk.prism(4, 0.6, 0.3, 0.3, 0.3 + h, ROOF, PI * 0.25)
	mk.prism(4, 0.3, 0.0, 0.3 + h, 0.8 + h, ROOF, PI * 0.25, false)
	# Rune bands down the faces.
	for k in 3 + lv:
		var y := 0.6 + k * 0.45
		var rr := lerpf(0.6, 0.3, (y - 0.3) / h) + 0.01
		mk.prism(4, rr, rr, y, y + 0.05, GLOW, PI * 0.25, false)
	# Broken standing stones in a ring.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.3
		var hh := 0.5 + rng.randf() * 0.6
		mk.box(Vector3(cos(a) * 1.0, 0.3 + hh * 0.5, sin(a) * 1.0), Vector3(0.24, hh, 0.16), STONE, Vector3(rng.randf() * 0.2, -a, rng.randf() * 0.2))
	return 0.3 + h


static func _cathedral_shrine(mk: MK, lv: int) -> float:
	var h := 1.5 + lv * 0.2
	mk.box(Vector3(0, 0.3 + h * 0.5, 0), Vector3(1.3, h, 1.7), STONE)
	# Steep gabled roof.
	mk.gable(Vector3(0, 0.3 + h, 0), 1.45, 1.85, 1.0 + lv * 0.1, ROOF)
	# Rose window and lancets.
	mk.box(Vector3(0, 0.3 + h * 0.62, 0.86), Vector3(0.5, 0.5, 0.04), GLOW, Vector3(0, 0, PI * 0.25))
	for sx in [-0.4, 0.4]:
		mk.box(Vector3(sx, 0.3 + h * 0.35, 0.86), Vector3(0.14, 0.55, 0.04), GLOW)
		mk.box(Vector3(0.66, 0.3 + h * 0.45, sx), Vector3(0.04, 0.6, 0.14), GLOW)
		mk.box(Vector3(-0.66, 0.3 + h * 0.45, sx), Vector3(0.04, 0.6, 0.14), GLOW)
	_buttresses(mk, 4, 0.85, h, PI * 0.25)
	# Bell spire at the back.
	var y := 0.3 + h
	mk.prism(4, 0.3, 0.28, y, y + 0.9, STONE, PI * 0.25, true, false, Vector3(0, 0, -0.55))
	_spire(mk, 4, 0.3, y + 0.9, 0.9 + lv * 0.2, PI * 0.25)
	return y + 1.0


static func _rock_bastion(mk: MK, lv: int, seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var y := 0.3
	for k in 3 + lv:
		var s := 1.0 - k * 0.14
		var hh := 0.45 + rng.randf() * 0.2
		mk.prism(7, s, s * 0.85, y, y + hh, STONE, rng.randf() * TAU)
		if k % 2 == 1:
			mk.prism(7, s * 0.86, s * 0.86, y + hh * 0.4, y + hh * 0.45, GLOW, rng.randf() * TAU, false)
		y += hh
	for i in 4:
		var a := TAU * float(i) / 4.0 + rng.randf()
		mk.crystal(Vector3(cos(a) * 0.95, 0.3, sin(a) * 0.95), 0.2, 0.6 + rng.randf() * 0.5, STONE, Vector3(sin(a) * 0.4, 0, -cos(a) * 0.4))
	return y


static func _aeolian_tower(mk: MK, lv: int, extras: Array[Node3D]) -> float:
	var h := 2.4 + lv * 0.3
	mk.prism(8, 0.78, 0.55, 0.3, 0.3 + h, STONE, PI / 8.0)
	_slits(mk, 8, 0.68, 0.3 + h * 0.35, 0.44, 4, PI / 8.0)
	_slits(mk, 8, 0.6, 0.3 + h * 0.7, 0.3, 4, 0.0)
	var y := 0.3 + h
	_spire(mk, 8, 0.66, y, 1.0, PI / 8.0)
	# Rotating vanes (a separate spinning part).
	var hub := Spinner.new()
	hub.speed = 0.0
	hub.position = Vector3(0, y - 0.25, 0.72)
	var rot := Node3D.new()
	hub.add_child(rot)
	var vane := MK.new()
	for i in 4:
		var a := TAU * float(i) / 4.0
		var d := Vector3(cos(a), sin(a), 0)
		vane.box(d * 0.6, Vector3(0.1, 0.1, 0.06), ROOF, Vector3(0, 0, a))
		vane.box(d * 0.95, Vector3(0.7, 0.28, 0.03), STONE, Vector3(0, 0, a))
	vane.sphere_lo(Vector3.ZERO, 0.14, GOLD)
	var vm := MeshInstance3D.new()
	vm.mesh = vane.commit()
	rot.add_child(vm)
	var sp := VaneSpinner.new()
	sp.target = rot
	hub.add_child(sp)
	extras.append(hub)
	return y


static func _ballista_platform(mk: MK, lv: int) -> float:
	# Stone legs carrying a timber platform with a great ballista.
	for c in [Vector3(-0.8, 0, -0.8), Vector3(0.8, 0, -0.8), Vector3(-0.8, 0, 0.8), Vector3(0.8, 0, 0.8)]:
		mk.prism(4, 0.22, 0.18, 0.3, 1.5 + lv * 0.1, STONE, PI * 0.25, true, false, c)
	var y := 1.5 + lv * 0.1
	mk.box(Vector3(0, y + 0.08, 0), Vector3(2.0, 0.16, 2.0), STONE)
	_crenels(mk, 1.0, y + 0.16, 8, 0.24, 0.3)
	mk.box(Vector3(0, y + 0.35, 0), Vector3(0.24, 0.24, 1.4), ROOF, Vector3(0.1, 0, 0))
	mk.box(Vector3(0, y + 0.45, 0.45), Vector3(1.5, 0.1, 0.1), ROOF, Vector3(0, 0, 0))
	for sx in [-1.0, 1.0]:
		mk.box(Vector3(sx * 0.8, y + 0.42, 0.3), Vector3(0.08, 0.08, 0.45), GOLD, Vector3(0, sx * 0.6, 0))
	mk.box(Vector3(0, y + 0.47, 0.9), Vector3(0.05, 0.05, 0.5), GLOW)
	return y + 0.4


static func _trap_workshop(mk: MK, lv: int) -> float:
	mk.box(Vector3(0, 0.3 + 0.5, 0), Vector3(1.6, 1.0, 1.3), STONE)
	mk.gable(Vector3(0, 1.3, 0), 1.75, 1.45, 0.7, ROOF)
	mk.box(Vector3(0, 0.65, 0.66), Vector3(0.45, 0.6, 0.04), GLOW)
	# Spiked barricades around.
	for i in 5 + lv:
		var a := TAU * float(i) / float(5 + lv)
		var d := Vector3(cos(a), 0, sin(a))
		mk.prism(4, 0.06, 0.0, 0.3, 0.9, ROOF, 0.0, false, false, d * 1.1, 1.0, 1.0, Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5), 0.0)
	return 1.4


static func _banner(accent: Color, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.03
	cm.height = 1.1
	pole.mesh = cm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.5, 0.36, 0.14)
	gm.metallic = 0.9
	gm.roughness = 0.35
	pole.material_override = gm
	root.add_child(pole)
	var flag := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.42, 0.7)
	pm.orientation = PlaneMesh.FACE_Z
	pm.subdivide_width = 3
	pm.subdivide_depth = 6
	flag.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/cape.gdshader")
	m.set_shader_parameter("cloth", Color(0.16, 0.03, 0.03).lerp(accent * 0.35, 0.35))
	m.set_shader_parameter("glow_color", accent)
	m.set_shader_parameter("glow_strength", 1.5)
	m.set_shader_parameter("noise_tex", ModelLib.noise_tex("detail"))
	m.set_shader_parameter("tatter", 0.4)
	m.set_shader_parameter("sway", 0.8)
	flag.material_override = m
	flag.position = Vector3(0.23, 0.15, 0)
	flag.rotation = Vector3(0, 0, PI * 0.5)
	root.add_child(flag)
	return root


# ================================================================ mesh builder
class MK:
	var st := SurfaceTool.new()
	var count := 0

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, hint: Vector3) -> void:
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-10:
			return
		n = n.normalized()
		if hint != Vector3.ZERO and n.dot(hint) < 0.0:
			n = -n
			var t := b
			b = c
			c = t
		for v in [a, b, c]:
			st.set_color(col)
			st.set_normal(n)
			st.set_uv(Vector2(v.x + v.z, v.y))
			st.add_vertex(v)
		count += 3

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, hint: Vector3) -> void:
		tri(a, b, c, col, hint)
		tri(a, c, d, col, hint)

	## Tapered n-gon prism from y0 (radius r0) to y1 (radius r1) around `center`,
	## optionally tilted by `tilt` (euler) about its base.
	func prism(sides: int, r0: float, r1: float, y0: float, y1: float, col: Color, rot := 0.0, cap_top := true, cap_bot := false, center := Vector3.ZERO, sx := 1.0, sz := 1.0, tilt := Vector3.ZERO, _unused := 0.0) -> void:
		var b := Basis.from_euler(tilt)
		var base := Vector3(center.x, y0, center.z)
		var lo: Array[Vector3] = []
		var hi: Array[Vector3] = []
		for i in sides:
			var a := rot + TAU * float(i) / float(sides)
			lo.append(base + b * Vector3(cos(a) * r0 * sx, 0.0, sin(a) * r0 * sz))
			hi.append(base + b * Vector3(cos(a) * r1 * sx, y1 - y0, sin(a) * r1 * sz))
		var axis_top := base + b * Vector3(0, y1 - y0, 0)
		for i in sides:
			var j := (i + 1) % sides
			var mid := (lo[i] + lo[j] + hi[i] + hi[j]) * 0.25
			var axis := base + b * Vector3(0, (mid - base).dot(b.y), 0)
			var hint := mid - axis
			if r1 <= 0.0:
				tri(lo[i], lo[j], hi[i], col, hint)
			else:
				quad(lo[i], lo[j], hi[j], hi[i], col, hint)
		if cap_top and r1 > 0.0:
			for i in sides:
				tri(axis_top, hi[i], hi[(i + 1) % sides], col, b.y)
		if cap_bot:
			for i in sides:
				tri(base, lo[i], lo[(i + 1) % sides], col, -b.y)

	func box(c: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO) -> void:
		var b := Basis.from_euler(rot)
		var h := size * 0.5
		var p: Array[Vector3] = []
		for i in 8:
			var v := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
			p.append(c + b * v)
		quad(p[0], p[1], p[3], p[2], col, -b.z)
		quad(p[4], p[5], p[7], p[6], col, b.z)
		quad(p[0], p[2], p[6], p[4], col, -b.x)
		quad(p[1], p[3], p[7], p[5], col, b.x)
		quad(p[0], p[1], p[5], p[4], col, -b.y)
		quad(p[2], p[3], p[7], p[6], col, b.y)

	## Cylinder along basis Y starting at `c`.
	func cyl_basis(c: Vector3, b: Basis, r0: float, r1: float, h: float, col: Color) -> void:
		var sides := 10
		for i in sides:
			var a0 := TAU * float(i) / float(sides)
			var a1 := TAU * float(i + 1) / float(sides)
			var d0 := b.x * cos(a0) + b.z * sin(a0)
			var d1 := b.x * cos(a1) + b.z * sin(a1)
			quad(c + d0 * r0, c + d1 * r0, c + b.y * h + d1 * r1, c + b.y * h + d0 * r1, col, (d0 + d1) * 0.5)
			tri(c + b.y * h, c + b.y * h + d0 * r1, c + b.y * h + d1 * r1, col, b.y)

	func sphere_lo(c: Vector3, r: float, col: Color, bowl := false) -> void:
		var rings := 5
		var seg := 10
		var r_start := rings / 2 if bowl else 0
		for i in range(r_start, rings):
			var t0 := PI * float(i) / float(rings)
			var t1 := PI * float(i + 1) / float(rings)
			for j in seg:
				var p0 := TAU * float(j) / float(seg)
				var p1 := TAU * float(j + 1) / float(seg)
				var v := func(t: float, p: float) -> Vector3: return c + Vector3(sin(t) * cos(p), cos(t), sin(t) * sin(p)) * r
				var a: Vector3 = v.call(t0, p0)
				var bb: Vector3 = v.call(t0, p1)
				var cc: Vector3 = v.call(t1, p1)
				var d: Vector3 = v.call(t1, p0)
				quad(a, bb, cc, d, col, (a + cc) * 0.5 - c)

	## Faceted crystal (hexagonal body + pointed tip), tilted by `tilt`.
	func crystal(base: Vector3, r: float, h: float, col: Color, tilt: Vector3) -> void:
		prism(6, r * 0.8, r, base.y, base.y + h * 0.7, col, 0.3, false, false, base, 1.0, 1.0, tilt)
		var b := Basis.from_euler(tilt)
		var top := Vector3(base.x, base.y, base.z) + b * Vector3(0, h * 0.7, 0)
		prism(6, r, 0.0, top.y, top.y + h * 0.3, col, 0.3, false, false, Vector3(top.x, 0, top.z), 1.0, 1.0, tilt)

	## Gabled roof over a rectangle of width w (x) and depth d (z) at height c.y.
	func gable(c: Vector3, w: float, d: float, h: float, col: Color) -> void:
		var hw := w * 0.5
		var hd := d * 0.5
		var a := c + Vector3(-hw, 0, -hd)
		var b := c + Vector3(hw, 0, -hd)
		var cc := c + Vector3(hw, 0, hd)
		var dd := c + Vector3(-hw, 0, hd)
		var r0 := c + Vector3(0, h, -hd)
		var r1 := c + Vector3(0, h, hd)
		quad(a, r0, r1, dd, col, Vector3(-h, hw, 0))
		quad(b, r0, r1, cc, col, Vector3(h, hw, 0))
		tri(a, b, r0, col, Vector3(0, 0, -1))
		tri(dd, cc, r1, col, Vector3(0, 0, 1))

	func commit() -> ArrayMesh:
		return st.commit()


## Turns the vanes of the aeolian tower.
class VaneSpinner extends Node:
	var target: Node3D
	var speed := 1.6

	func _process(delta: float) -> void:
		if is_instance_valid(target):
			target.rotation.z += speed * delta
