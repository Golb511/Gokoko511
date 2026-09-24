class_name WingFlapper
extends Node
## Flaps a pair of wing pivots (used for winged fiends).

var wings: Array = []
var speed := 10.0
var _t := randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	var f := sin(_t * speed)
	for i in wings.size():
		if is_instance_valid(wings[i]):
			wings[i].rotation.z = f * 0.7 * (1.0 if i == 1 else -1.0)
