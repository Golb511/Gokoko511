class_name ExternalCharacter
extends RefCounted
## Loads a professional, externally made character model (GLB/GLTF with its
## own skeleton, PBR materials and animations) into the existing character
## system. Configured per unit with an "external" block in its model
## definition, e.g. data/heroes.json:
##
##   "external": {
##     "path": "res://assets/models/heroes/hell_knight/hell_knight.glb",
##     "height": 2.0,        # metres, head to toe, before the unit "scale"
##     "yaw": 0.0,           # degrees, if the model does not face +Z
##     "anims": {"idle": "Idle", "run": "Run", "attack": ["Slash1", "Slash2"], ...}
##   }
##
## Missing entries in "anims" are found automatically by name keywords.
## If the file is missing (or "Classic characters" is on) the unit keeps its
## current model, so nothing breaks while the asset is not there yet.

const KEYWORDS := {
	"idle": ["idle", "stand", "breath"],
	"run": ["run", "sprint", "jog"],
	"walk": ["walk"],
	"attack": ["attack", "slash", "swing", "strike", "combo", "hit_1", "melee"],
	"special": ["heavy", "power", "spin", "special", "attack_2", "attack2"],
	"cast": ["cast", "spell", "magic", "roar", "shout", "ability", "skill"],
	"summon": ["summon", "raise", "roar", "cast"],
	"hit": ["hit", "impact", "react", "damage", "hurt"],
	"death": ["death", "die", "dying", "dead"],
	"cheer": ["victory", "cheer", "taunt", "roar"],
}
const LOOPING := ["idle", "run", "walk"]


static func available(def: Dictionary) -> bool:
	if not def.has("external") or bool(Game.setting("classic_characters", false)):
		return false
	return ResourceLoader.exists(str(def.external.get("path", "")))


static func build(def: Dictionary) -> CharacterModel:
	var cfg: Dictionary = def.external
	var model := CharacterModel.new()
	model.name = "Model"
	var ps: PackedScene = ModelLib.scene(str(cfg.path))
	if ps == null:
		return model
	var inst: Node3D = ps.instantiate()
	model.add_child(inst)
	model.rig = inst
	# Normalise the height, stand on the ground, face +Z like the other units.
	var aabb := _aabb(inst)
	var want := float(cfg.get("height", 2.0))
	var k := want / maxf(0.01, aabb.size.y)
	inst.scale = Vector3.ONE * k
	inst.position.y = -aabb.position.y * k
	inst.rotation.y = deg_to_rad(float(cfg.get("yaw", 0.0)))
	# Combat feedback overlay on every mesh; the model's own PBR stays as is.
	var overlay := ShaderMaterial.new()
	overlay.shader = load("res://assets/shaders/unit_feedback_overlay.gdshader")
	overlay.set_shader_parameter("glow_color", ModelLib._col(def.get("emission", [1, 0.3, 0.05])))
	overlay.set_shader_parameter("glow_strength", float(def.get("emission_strength", 1.0)))
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = overlay
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	model.materials.append(overlay)
	var sks := inst.find_children("*", "Skeleton3D", true, false)
	model.skeleton = sks[0] if not sks.is_empty() else null
	var player: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	model.setup_external_animations(player, resolve_anims(player, cfg.get("anims", {})), LOOPING)
	model.scale = Vector3.ONE * float(def.get("scale", 1.0))
	return model


## Logical animation -> clip name(s), from the config first, then by keyword.
static func resolve_anims(player: AnimationPlayer, given: Dictionary) -> Dictionary:
	var out := {}
	var names: Array = []
	if player:
		for n in player.get_animation_list():
			if n != "RESET":
				names.append(n)
	for logical in KEYWORDS:
		if given.has(logical):
			out[logical] = given[logical]
			continue
		var found: Array = []
		for kw in KEYWORDS[logical]:
			for n in names:
				if kw in str(n).to_lower() and not (n in found):
					found.append(n)
			if not found.is_empty():
				break
		if not found.is_empty():
			out[logical] = found if logical == "attack" else found[0]
	# Sensible fallbacks so every logical name plays something.
	for logical in ["special", "cast", "summon", "cheer"]:
		if not out.has(logical) and out.has("attack"):
			out[logical] = out.attack[0] if out.attack is Array else out.attack
	if not out.has("walk") and out.has("run"):
		out["walk"] = out.run
	return out


static func _aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (mi as MeshInstance3D).get_aabb()
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != root:
			if n is Node3D:
				t = (n as Node3D).transform * t
			n = n.get_parent()
		a = t * a
		out = a if first else out.merge(a)
		first = false
	return out
