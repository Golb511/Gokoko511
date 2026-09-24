extends Node

func _ready() -> void:
	while not (get_tree().current_scene is BattleController):
		await get_tree().create_timer(0.5).timeout
	var b: BattleController = get_tree().current_scene
	var air: PathRoute = null
	for r in b.routes:
		if r.air: air = r
	var dmg_to_fly := {"v": 0.0}
	b.get_node("Units").child_entered_tree.connect(func(n):
		if n is Enemy:
			n.damaged.connect(func(u, a): if u.flying: dmg_to_fly.v += a))
	for i in 12:
		await get_tree().create_timer(15.0).timeout
		if b.ended: break
		var near := []
		for t in b.towers:
			near.append("%s%d@%.0f(air=%s)" % [t.tower_id, t.level, air.distance_to(t.global_position), t.hits_air()])
		print("AIRDBG t=%.0f fly_dmg=%d towers=%s" % [b.elapsed, dmg_to_fly.v, near])
