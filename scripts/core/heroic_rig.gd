class_name HeroicRig
extends SkeletonModifier3D
## Realistic proportions for the forged hero models: lengthens the legs and
## arms and widens the shoulders by moving the joints (bone pose positions)
## after the animation is applied, instead of scaling bones. The armour plates
## riding the bones therefore keep their true shape, and every existing
## animation (idle, run, attacks, casts, hit, death) keeps working.

var thigh := 2.0       # hip -> knee
var shin := 2.9        # knee -> ankle
var foot := 1.15
var upper_arm := 1.25
var fore_arm := 1.3
var shoulder := 1.25
var _ids := {}


static func make(cfg: Dictionary) -> HeroicRig:
	var r := HeroicRig.new()
	r.name = "HeroicRig"
	for k in cfg:
		if k in ["thigh", "shin", "foot", "upper_arm", "fore_arm", "shoulder"]:
			r.set(k, float(cfg[k]))
	return r


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for n in ["lowerleg.l", "lowerleg.r", "foot.l", "foot.r", "toes.l", "toes.r", "lowerarm.l", "lowerarm.r", "wrist.l", "wrist.r", "upperarm.l", "upperarm.r"]:
		_ids[n] = sk.find_bone(n)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _ids.is_empty():
		return
	for s in [".l", ".r"]:
		_mul(sk, "lowerleg" + s, thigh)
		_mul(sk, "foot" + s, shin)
		_mul(sk, "toes" + s, foot)
		_mul(sk, "lowerarm" + s, upper_arm)
		_mul(sk, "wrist" + s, fore_arm)
		var i: int = _ids.get("upperarm" + s, -1)
		if i >= 0:
			var p := sk.get_bone_pose_position(i)
			sk.set_bone_pose_position(i, Vector3(p.x * shoulder, p.y, p.z))


func _mul(sk: Skeleton3D, bone: String, k: float) -> void:
	var i: int = _ids.get(bone, -1)
	if i >= 0:
		sk.set_bone_pose_position(i, sk.get_bone_pose_position(i) * k)


## Extra height the longer legs add (to lift the rig so the feet touch the ground).
func leg_lift(sk: Skeleton3D) -> float:
	var ul := sk.find_bone("upperleg.l")
	var ll := sk.find_bone("lowerleg.l")
	var ft := sk.find_bone("foot.l")
	if ul < 0 or ll < 0 or ft < 0:
		return 0.0
	var a := sk.get_bone_rest(ll).origin.length()
	var b := sk.get_bone_rest(ft).origin.length()
	return a * (thigh - 1.0) + b * (shin - 1.0)
