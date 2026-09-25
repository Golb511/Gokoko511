class_name Spinner
extends Node3D
## Spins (and gently bobs) its children — orbiting orbs, shard halos.

var speed := 1.5
var bob := 0.0
var _t := randf() * 10.0
var _y0 := 0.0


func _ready() -> void:
	_y0 = position.y


func _process(delta: float) -> void:
	_t += delta
	rotation.y += speed * delta
	if bob > 0.0:
		position.y = _y0 + sin(_t * 1.7) * bob
