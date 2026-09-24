class_name ModelLib
extends RefCounted
## Central factory for all 3D visuals: rigged characters with dark PBR
## materials and weapons, environment props, and shared procedural textures.

const CHAR_DIR := "res://assets/models/characters/%s.glb"
const WEAPON_DIR := "res://assets/models/weapons/%s.gltf"
const BODY_PARTS := ["Body", "Head", "ArmLeft", "ArmRight", "LegLeft", "LegRight", "Eyes", "Jaw", "Skull", "Head_Hooded"]

static var _scene_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _char_shader: Shader
static var _env_shader: Shader
static var _env_mat_cache: Dictionary = {}


static func scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path) if ResourceLoader.exists(path) else null
		if _scene_cache[path] == null:
			push_warning("ModelLib: missing %s" % path)
	return _scene_cache[path]


# ---------------------------------------------------------------- textures
static func noise_tex(kind: String) -> Texture2D:
	if _tex_cache.has(kind):
		return _tex_cache[kind]
	var n := FastNoiseLite.new()
	var t := NoiseTexture2D.new()
	t.seamless = true
	t.width = 512
	t.height = 512
	match kind:
		"detail":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.012
			n.fractal_octaves = 5
		"normal":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.frequency = 0.02
			n.fractal_octaves = 5
			t.as_normal_map = true
			t.bump_strength = 6.0
		"cell":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.02
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			n.fractal_type = FastNoiseLite.FRACTAL_NONE
		"cell_normal":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.frequency = 0.02
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			n.fractal_type = FastNoiseLite.FRACTAL_NONE
			t.as_normal_map = true
			t.bump_strength = 10.0
		"soft":
			n.noise_type = FastNoiseLite.TYPE_PERLIN
			n.frequency = 0.008
			n.fractal_octaves = 3
			t.width = 256
			t.height = 256
	t.noise = n
	_tex_cache[kind] = t
	return t


static func gradient_tex(colors: Array, key: String) -> Texture2D:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offs.append(float(i) / max(1, colors.size() - 1))
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	_tex_cache[key] = t
	return t


static func radial_tex(key: String = "radial") -> Texture2D:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	_tex_cache[key] = t
	return t


# ---------------------------------------------------------------- materials
static func char_material(albedo: Texture2D, def: Dictionary) -> ShaderMaterial:
	if _char_shader == null:
		_char_shader = load("res://assets/shaders/character.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _char_shader
	m.set_shader_parameter("albedo_tex", albedo)
	m.set_shader_parameter("detail_tex", noise_tex("detail"))
	m.set_shader_parameter("detail_normal", noise_tex("normal"))
	m.set_shader_parameter("tint", _col(def.get("tint", [0.4, 0.4, 0.4])))
	m.set_shader_parameter("metal", float(def.get("metal", 0.55)))
	m.set_shader_parameter("glow_color", _col(def.get("emission", [1, 0.3, 0.05])))
	m.set_shader_parameter("glow_strength", float(def.get("emission_strength", 1.0)))
	m.set_shader_parameter("stone", 1.0 if def.get("stone", false) else 0.0)
	m.set_shader_parameter("vein_amount", 0.25 if def.get("stone", false) else 0.1)
	return m


static func env_material(albedo: Texture2D, tint: Color, accent := Color(1, 0.4, 0.1), accent_strength := 0.0, snow := 0.0, desat := 0.65, brightness := 1.0) -> ShaderMaterial:
	var key := "%s|%s|%s|%.2f|%.2f|%.2f|%.2f" % [albedo.get_rid() if albedo else 0, tint, accent, accent_strength, snow, desat, brightness]
	if _env_mat_cache.has(key):
		return _env_mat_cache[key]
	if _env_shader == null:
		_env_shader = load("res://assets/shaders/environment_prop.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _env_shader
	m.set_shader_parameter("albedo_tex", albedo)
	m.set_shader_parameter("detail_tex", noise_tex("detail"))
	m.set_shader_parameter("detail_normal", noise_tex("normal"))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("accent", accent)
	m.set_shader_parameter("accent_strength", accent_strength)
	m.set_shader_parameter("snow", snow)
	m.set_shader_parameter("desaturate", desat)
	m.set_shader_parameter("brightness", brightness)
	_env_mat_cache[key] = m
	return m


static func _col(a) -> Color:
	if a is Color:
		return a
	return Color(float(a[0]), float(a[1]), float(a[2]))


static func _source_albedo(mat: Material) -> Texture2D:
	if mat is BaseMaterial3D:
		return mat.albedo_texture
	return null


# ---------------------------------------------------------------- characters
static func character(def: Dictionary) -> Node3D:
	var base: String = def.get("base", "Knight")
	if base == "dragon":
		return ProceduralCreatures.dragon(float(def.get("scale", 1.0)))
	if base == "raven":
		return ProceduralCreatures.raven()
	var ps := scene(CHAR_DIR % base)
	var model := CharacterModel.new()
	model.name = "Model"
	if ps == null:
		return model
	var inst: Node3D = ps.instantiate()
	model.add_child(inst)
	model.rig = inst
	var show: Array = def.get("show", [])
	var mats: Array[ShaderMaterial] = []
	var mat_by_tex: Dictionary = {}
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		var nm := String(mesh_inst.name)
		var is_body := false
		for part in BODY_PARTS:
			if nm.ends_with(part):
				is_body = true
		if not is_body and nm not in show:
			mesh_inst.visible = false
			continue
		for si in mesh_inst.mesh.get_surface_count():
			var src := mesh_inst.mesh.surface_get_material(si)
			if src != null and src.resource_name == "Glow":
				var glow := StandardMaterial3D.new()
				glow.albedo_color = _col(def.get("emission", [1, 0.3, 0.1]))
				glow.emission_enabled = true
				glow.emission = glow.albedo_color
				glow.emission_energy_multiplier = 4.0
				mesh_inst.set_surface_override_material(si, glow)
				continue
			var tex := _source_albedo(src)
			var key := tex.get_rid() if tex else RID()
			if not mat_by_tex.has(key):
				var m := char_material(tex, def)
				mat_by_tex[key] = m
				mats.append(m)
			mesh_inst.set_surface_override_material(si, mat_by_tex[key])
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.materials = mats
	if float(def.get("scale", 1.0)) >= 2.0:
		# Giants: keep the ember glow in the cracks, not smeared over the silhouette.
		for m in mats:
			m.set_shader_parameter("rim_strength", 0.22)
			m.set_shader_parameter("glow_strength", minf(2.2, float(def.get("emission_strength", 1.0))))
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	model.skeleton = skel
	if skel:
		if def.has("weapon_r"):
			_attach(skel, "handslot.r", WEAPON_DIR % def.weapon_r, def, model)
		if def.has("weapon_l"):
			_attach(skel, "handslot.l", WEAPON_DIR % def.weapon_l, def, model)
		if def.get("wings", false):
			var att := BoneAttachment3D.new()
			att.bone_name = "chest"
			skel.add_child(att)
			var wings := ProceduralCreatures.bat_wings(_col(def.get("emission", [1, 0.2, 0.3])))
			att.add_child(wings)
			model.wings = wings
	model.setup_animations(inst.find_child("AnimationPlayer", true, false), def.get("anim", "1h"))
	var s := float(def.get("scale", 1.0))
	model.scale = Vector3.ONE * s * 0.78
	return model


static func _attach(skel: Skeleton3D, bone: String, path: String, def: Dictionary, model: CharacterModel) -> void:
	var ps := scene(path)
	if ps == null:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skel.add_child(att)
	var w: Node3D = ps.instantiate()
	att.add_child(w)
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var tex := _source_albedo(mi.mesh.surface_get_material(si))
			var m := char_material(tex, def)
			model.materials.append(m)
			mi.set_surface_override_material(si, m)


# ---------------------------------------------------------------- props
## Instantiates an environment model ("env/name" or "graveyard/name") with the gothic material.
static func prop(path_key: String, tint := Color(0.5, 0.48, 0.46), accent := Color(1, 0.4, 0.1), accent_strength := 0.0, snow := 0.0, desat := 0.65, brightness := 1.0) -> Node3D:
	var ps := scene("res://assets/models/%s.gltf" % path_key)
	if ps == null:
		return Node3D.new()
	var inst: Node3D = ps.instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var tex := _source_albedo(mi.mesh.surface_get_material(si))
			mi.set_surface_override_material(si, env_material(tex, tint, accent, accent_strength, snow, desat, brightness))
	return inst


## Per-instance copy of a prop's materials (for towers that flash/disable).
static func make_unique_materials(root: Node) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		for si in mi.mesh.get_surface_count():
			var m = mi.get_surface_override_material(si)
			if m is ShaderMaterial:
				var d: ShaderMaterial = m.duplicate()
				mi.set_surface_override_material(si, d)
				out.append(d)
	return out
