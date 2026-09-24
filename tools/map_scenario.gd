extends Node

func _ready() -> void:
	while not (get_tree().current_scene and get_tree().current_scene.has_method("_open_stage")):
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(3.0).timeout
	get_tree().current_scene._open_stage("r1s1")
