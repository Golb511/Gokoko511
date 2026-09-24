extends Node

var dealt := 0.0

func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	var b = get_tree().current_scene
	for i in 40:
		await get_tree().create_timer(5.0).timeout
		if not is_instance_valid(b) or b.ended: return
		var h: Hero = b.hero
		var d := 999.0
		for e in b.enemies:
			if is_instance_valid(e):
				d = minf(d, e.global_position.distance_to(h.global_position))
		print("HERO t=%.0f pos=%s moving=%s target=%s energy=%d nearest_enemy=%.1f enemies=%d cds=%s" % [b.elapsed, h.global_position.snapped(Vector3.ONE), h.moving, h.target != null, h.energy, d, b.enemies.size(), h.cooldowns])
