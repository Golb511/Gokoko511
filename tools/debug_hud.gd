extends Node

func _ready() -> void:
	await get_tree().create_timer(3.0).timeout
	var b = get_tree().current_scene
	var hud = b.hud
	for btn in hud.ability_btns:
		print("ability btn ", btn.global_position, " size ", btn.size, " vis ", btn.is_visible_in_tree())
	for k in hud.global_btns:
		print("global ", k, " ", hud.global_btns[k].global_position, " vis ", hud.global_btns[k].is_visible_in_tree())
	print("viewport ", get_viewport().get_visible_rect())
	get_tree().quit()
