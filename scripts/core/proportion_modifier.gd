class_name ProportionModifier
extends SkeletonModifier3D
## Reshapes the stylised (big-head) KayKit rigs into heroic proportions after
## the animation has been applied: a smaller head, broader chest and longer
## legs. Runs every frame on top of whatever animation is playing.

var head := 0.42
var chest := Vector3(1.16, 1.12, 1.1)
var spine := Vector3(1.0, 1.2, 1.0)
var legs := 1.22
var arms := 1.14
var _ids := {}


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for n in ["head", "chest", "spine", "upperleg.l", "upperleg.r", "lowerleg.l", "lowerleg.r", "upperarm.l", "upperarm.r"]:
		_ids[n] = sk.find_bone(n)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _ids.is_empty():
		return
	_scale(sk, "spine", spine)
	# Chest scale also scales its children; compensate so the head ends up at `head`.
	_scale(sk, "chest", chest)
	_scale(sk, "head", Vector3.ONE * head / maxf(0.01, chest.y))
	for n in ["upperleg.l", "upperleg.r", "lowerleg.l", "lowerleg.r"]:
		_scale(sk, n, Vector3(1.0, legs, 1.0))
	for n in ["upperarm.l", "upperarm.r"]:
		_scale(sk, n, Vector3(1.0, arms, 1.0) / Vector3(chest.x, chest.y, chest.z) * Vector3(1.04, 1.0, 1.04))


func _scale(sk: Skeleton3D, bone: String, s: Vector3) -> void:
	var i: int = _ids.get(bone, -1)
	if i < 0:
		return
	sk.set_bone_pose_scale(i, sk.get_bone_pose_scale(i) * s)
