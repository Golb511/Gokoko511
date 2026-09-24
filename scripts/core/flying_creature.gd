class_name FlyingCreature
extends CharacterModel
## Procedural flying creature with wing flapping, tail sway and attack lunges.
## Shares CharacterModel's API so gameplay code can treat it the same way.

var body: Node3D
var head: Node3D
var wing_l: Node3D
var wing_r: Node3D
var tail: Array[Node3D] = []
var flap_speed := 4.0
var _lunge := 0.0


func _process(delta: float) -> void:
	super._process(delta)
	var f := sin(_time * flap_speed)
	if wing_l:
		wing_l.rotation.z = -(f * 0.6 + 0.1)
		wing_r.rotation.z = f * 0.6 + 0.1
	if body:
		body.position.y = -f * 0.08
		_lunge = maxf(0.0, _lunge - delta * 2.5)
		body.rotation.x = -_lunge * 0.4
	for i in tail.size():
		tail[i].position.x = sin(_time * 2.0 - i * 0.5) * 0.06 * i


func play_loop(_logical: String, speed: float = 1.0) -> void:
	flap_speed = flap_speed if speed <= 0.0 else flap_speed


func play_action(_logical: String, _speed: float = 1.0, _lock: bool = true) -> float:
	_lunge = 1.0
	return 0.4
