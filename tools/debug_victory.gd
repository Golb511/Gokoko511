extends Node

func _ready() -> void:
	await get_tree().create_timer(3.0).timeout
	var b = get_tree().current_scene
	b.waves.current = 4
	b._end(true)
	await get_tree().create_timer(2.5).timeout
	for c in b.hud.root.get_children():
		if c is VictoryScreen:
			print("VS size ", c.size, " pos ", c.position, " anchors ", c.anchor_right, ",", c.anchor_bottom, " offsets ", c.offset_right, ",", c.offset_bottom)
			for cc in c.get_children():
				print("  child ", cc.get_class(), " size ", cc.size)
	print("root size ", b.hud.root.size)
	get_tree().quit()
