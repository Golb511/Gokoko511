class_name BuildSlot
extends Node3D
## Glowing rune circle where a tower can be constructed.

var battle: Node
var tower: Tower = null
var _ring: MeshInstance3D
var _mat: StandardMaterial3D
var _t := randf() * 10.0


func setup(b: Node, pos: Vector3) -> void:
	battle = b
	global_position = pos
	var base := ModelLib.prop("env/building_tower_base_red", Color(0.28, 0.26, 0.25))
	base.scale = Vector3(1.5, 0.12, 1.5)
	add_child(base)
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 1.05
	t.outer_radius = 1.2
	t.rings = 48
	_ring.mesh = t
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(1.0, 0.7, 0.25)
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.55, 0.15)
	_mat.emission_energy_multiplier = 2.0
	_ring.material_override = _mat
	_ring.scale = Vector3(1, 0.04, 1)
	_ring.position.y = 0.3
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	# Rune glyph marks around the ring.
	for i in 6:
		var rune := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.02, 0.3)
		rune.mesh = bm
		rune.material_override = _mat
		var a := TAU * i / 6.0
		rune.position = Vector3(cos(a) * 0.8, 0.31, sin(a) * 0.8)
		rune.rotation.y = -a
		_ring.add_child(rune)


func _process(delta: float) -> void:
	_t += delta
	_ring.visible = tower == null
	if tower == null:
		_mat.emission_energy_multiplier = 1.4 + sin(_t * 2.5) * 0.7
		_ring.rotation.y += delta * 0.3


func is_free() -> bool:
	return tower == null or not is_instance_valid(tower)
