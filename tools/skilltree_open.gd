extends Node

func _ready() -> void:
	while not (get_tree().current_scene and get_tree().current_scene.has_method("_skill_tree")):
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(2.0).timeout
	Game.add_hero_xp("hell_knight", 3000)
	Game.learn_skill("hell_knight", "ab0")
	Game.learn_skill("hell_knight", "brutality")
	get_tree().current_scene._skill_tree()
