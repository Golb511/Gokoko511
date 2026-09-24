extends Node

func _ready() -> void:
	while not (get_tree().current_scene is BattleController):
		await get_tree().create_timer(0.5).timeout
	var b: BattleController = get_tree().current_scene
	await get_tree().create_timer(1.0).timeout
	b.gold = 3000
	var t := b.build_tower(b.slots[0], "archer")
	var e := b.spawn_enemy("winged_fiend", 0, 30.0)
	e.global_position = t.global_position + Vector3(3, 2.6, 0)
	e.set_physics_process(false)
	for i in 10:
		await get_tree().create_timer(0.5).timeout
		print("FLY hp=", e.hp, " valid=", e.is_valid_target(), " targets=", t._targets().size(), " near=", b.enemies_near(t.global_position, t.range_()).size(), " cd=", t.cooldown, " dist=", t.global_position.distance_to(e.global_position))
	get_tree().quit()
