extends Node
## Debug: prints every leaked enemy (wave, type, route) during a battle.

func _ready() -> void:
	Events.enemy_leaked.connect(func(e, n):
		var b = get_tree().current_scene
		print("LEAK w%d %s route=%d lives=%d gold=%d hp=%.2f max=%d t=%d" % [b.waves.current + 1, e.unit_id, e.route_idx, n, b.gold, e.hp_ratio(), e.max_hp, b.elapsed]))
