extends Node

func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	var b = get_tree().current_scene
	var h: Hero = b.hero
	var fired := [0]
	var states := {}
	for i in 600:
		await get_tree().create_timer(0.25).timeout
		if not is_instance_valid(b) or b.ended: break
		var st := "moving" if h.moving else ("target" if h.target != null else "idle")
		if h._busy > 0: st += "_busy"
		if h.is_disabled(): st = "disabled"
		if not h.alive: st = "dead"
		states[st] = states.get(st, 0) + 1
		if i % 40 == 0:
			print("STATES ", states, " cd=", h.attack_cd, " rate=", h.attack_rate, " fx_children=", b.fx_root.get_child_count())
