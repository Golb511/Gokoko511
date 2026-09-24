extends Node

func _ready() -> void:
	while not (get_tree().current_scene is BattleController):
		await get_tree().create_timer(0.5).timeout
	var b = get_tree().current_scene
	b.camera_rig.distance = 58.0
	b.camera_rig.focus_on(Vector3(0, 0, -2))
