class_name LightFlicker
extends Node
## Organic flame flicker for an OmniLight3D.

var light: OmniLight3D
var base_energy := -1.0
var _t := randf() * 100.0


func _process(delta: float) -> void:
	if light == null:
		return
	if base_energy < 0.0:
		base_energy = light.light_energy
	_t += delta
	light.light_energy = base_energy * (0.82 + 0.12 * sin(_t * 13.0) + 0.08 * sin(_t * 29.0 + 1.3))
