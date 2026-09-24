class_name LootOrb
extends Node3D
## Glowing loot drop that pops out of a fallen enemy and flies to the HUD.

var col := Color.WHITE
var _t := 0.0
var _start := Vector3.ZERO
var _cam: CameraRig


static func spawn(parent: Node, pos: Vector3, c: Color, cam: CameraRig) -> void:
	var o := LootOrb.new()
	o.col = c
	o._cam = cam
	parent.add_child(o)
	o.global_position = pos + Vector3(0, 1, 0)
	o._start = o.global_position
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.35, 0.5, 0.35)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 5.0
	mi.material_override = m
	o.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 2.0
	l.omni_range = 3.0
	o.add_child(l)
	VFX.particles(o, o.global_position, {"amount": 20, "lifetime": 0.8, "one_shot": false, "speed": 0.5, "size": 0.15, "color": c, "radius": 0.3, "gravity": Vector3(0, 1.5, 0), "local": false})
	VFX.ground_ring(parent, pos, 1.2, c, 0.6)


func _process(delta: float) -> void:
	_t += delta
	rotation.y += delta * 4.0
	if _t < 1.4:
		global_position = _start + Vector3(0, sin(minf(_t, 0.6) / 0.6 * PI * 0.5) * 1.2 + sin(_t * 5.0) * 0.1, 0)
	else:
		var goal := _cam.global_position + Vector3(0, 0, 0) if _cam else _start
		global_position = global_position.lerp(goal, clampf(delta * 4.0, 0, 1))
		scale = Vector3.ONE * maxf(0.1, 1.0 - (_t - 1.4))
		if _t > 2.4:
			queue_free()
