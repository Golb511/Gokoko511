class_name CharacterModel
extends Node3D
## Wraps an imported rigged character: logical animation names, material
## feedback (hit flash, freeze, poison, dissolve) and facing.

const ANIM_SETS := {
	"2h":        {"idle": "2H_Melee_Idle", "run": "Running_A", "walk": "Walking_A", "attack": ["2H_Melee_Attack_Chop", "2H_Melee_Attack_Slice", "2H_Melee_Attack_Stab"], "cast": "Spellcast_Shoot", "special": "2H_Melee_Attack_Spin", "hit": "Hit_A", "death": "Death_A", "cheer": "Cheer", "summon": "Spellcast_Raise"},
	"1h":        {"idle": "Idle", "run": "Running_A", "walk": "Walking_A", "attack": ["1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal"], "cast": "Spellcast_Shoot", "special": "1H_Melee_Attack_Stab", "hit": "Hit_A", "death": "Death_A", "cheer": "Cheer", "summon": "Spellcast_Raise"},
	"dual":      {"idle": "Idle", "run": "Running_B", "walk": "Walking_B", "attack": ["Dualwield_Melee_Attack_Chop", "Dualwield_Melee_Attack_Slice", "Dualwield_Melee_Attack_Stab"], "cast": "Spellcast_Shoot", "special": "Dualwield_Melee_Attack_Slice", "hit": "Hit_B", "death": "Death_B", "cheer": "Cheer", "summon": "Spellcast_Raise"},
	"staff":     {"idle": "Idle", "run": "Running_A", "walk": "Walking_A", "attack": ["Spellcast_Shoot"], "cast": "Spellcast_Long", "special": "Spellcast_Raise", "hit": "Hit_A", "death": "Death_A", "cheer": "Cheer", "summon": "Spellcast_Raise"},
	"ranged_1h": {"idle": "Idle", "run": "Running_A", "walk": "Walking_A", "attack": ["1H_Ranged_Shoot"], "cast": "Throw", "special": "1H_Ranged_Shoot", "hit": "Hit_A", "death": "Death_A", "cheer": "Cheer", "summon": "Spellcast_Raise"},
	"ranged_2h": {"idle": "Idle", "run": "Running_A", "walk": "Walking_A", "attack": ["2H_Ranged_Shoot"], "cast": "Throw", "special": "2H_Ranged_Shoot", "hit": "Hit_A", "death": "Death_A", "cheer": "Cheer", "summon": "Spellcast_Raise"},
	"unarmed":   {"idle": "Unarmed_Idle", "run": "Running_A", "walk": "Walking_A", "attack": ["Unarmed_Melee_Attack_Punch_A", "Unarmed_Melee_Attack_Punch_B", "Unarmed_Melee_Attack_Kick"], "cast": "Spellcast_Shoot", "special": "Unarmed_Melee_Attack_Kick", "hit": "Hit_A", "death": "Death_A", "cheer": "Cheer", "summon": "Spellcast_Raise"},
	"fly":       {"idle": "Jump_Idle", "run": "Jump_Idle", "walk": "Jump_Idle", "attack": ["Spellcast_Shoot"], "cast": "Spellcast_Shoot", "special": "Spellcast_Shoot", "hit": "Hit_A", "death": "Death_A", "cheer": "Jump_Idle", "summon": "Spellcast_Raise"},
}
const LOOPING := ["Idle", "Idle_B", "Idle_Combat", "2H_Melee_Idle", "Unarmed_Idle", "Running_A", "Running_B", "Running_C", "Walking_A", "Walking_B", "Walking_C", "Walking_D_Skeletons", "Jump_Idle", "Spellcasting", "Blocking", "2H_Ranged_Aiming", "1H_Ranged_Aiming"]

var rig: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var materials: Array[ShaderMaterial] = []
var wings: Node3D
var anim_set: Dictionary = ANIM_SETS["1h"]
var _current := ""
var _locked_until := 0.0
var _flash := 0.0
var _time := 0.0


func setup_animations(player: AnimationPlayer, set_name: String) -> void:
	anim = player
	anim_set = ANIM_SETS.get(set_name, ANIM_SETS["1h"])
	if anim == null:
		return
	for n in LOOPING:
		if anim.has_animation(n):
			var a := anim.get_animation(n)
			if a.loop_mode != Animation.LOOP_LINEAR:
				a.loop_mode = Animation.LOOP_LINEAR
	play_loop("idle")


func _process(delta: float) -> void:
	_time += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		set_param("hit_flash", _flash)
	if wings:
		wings.rotation.x = sin(_time * 9.0) * 0.1


func anim_name(logical: String) -> String:
	var v = anim_set.get(logical, logical)
	if v is Array:
		return v.pick_random()
	return v


## Looping state animation (idle/run/walk). Won't interrupt a one-shot action.
func play_loop(logical: String, speed: float = 1.0) -> void:
	if anim == null:
		return
	var n := anim_name(logical)
	if Time.get_ticks_msec() / 1000.0 < _locked_until:
		return
	if _current == n and anim.is_playing():
		anim.speed_scale = speed
		return
	if anim.has_animation(n):
		anim.play(n, 0.2)
		anim.speed_scale = speed
		_current = n


## One-shot action animation (attack/cast/hit/death). Returns its duration.
func play_action(logical: String, speed: float = 1.0, lock: bool = true) -> float:
	if anim == null:
		return 0.5
	var n := anim_name(logical)
	if not anim.has_animation(n):
		return 0.5
	anim.stop()
	anim.play(n, 0.08)
	anim.speed_scale = speed
	_current = n
	var length := anim.get_animation(n).length / maxf(0.01, speed)
	if lock:
		_locked_until = Time.get_ticks_msec() / 1000.0 + length * 0.9
	return length


func unlock() -> void:
	_locked_until = 0.0


func is_locked() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _locked_until


func set_param(p: String, v) -> void:
	for m in materials:
		m.set_shader_parameter(p, v)


func flash() -> void:
	_flash = 1.0


func face_towards(target: Vector3, delta: float, turn_speed: float = 12.0) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var want := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(delta * turn_speed, 0.0, 1.0))


func face_instant(target: Vector3) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		rotation.y = atan2(dir.x, dir.z)


func dissolve_out(duration: float = 1.2) -> void:
	# Glowing gear (eyes, orbs, halos) fades with the body.
	if skeleton:
		for a in skeleton.get_children():
			if a is BoneAttachment3D and a.has_meta("gear"):
				for g in a.get_children():
					if g is Node3D and not (g is MeshInstance3D and g.material_override is ShaderMaterial):
						g.create_tween().tween_property(g, "scale", Vector3.ONE * 0.01, duration * 0.6)
	var tw := create_tween()
	tw.tween_method(func(v): set_param("dissolve", v), 0.0, 1.0, duration)
