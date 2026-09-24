extends Node

func _ready() -> void:
	await get_tree().create_timer(3.0).timeout
	var b = get_tree().current_scene
	b.gold = 5000
	var t = b.build_tower(b.slots[3], "mage")
	print("L1 visual children: ", t._visual.get_child_count(), " top=", t._top_height)
	for c in t._visual.get_children():
		print("   ", c.name, " scale=", c.scale if c is Node3D else "", " vis=", c.visible if c is Node3D else "")
	b.upgrade_tower(t)
	b.upgrade_tower(t)
	await get_tree().process_frame
	print("L3 visual children: ", t._visual.get_child_count(), " top=", t._top_height, " valid=", is_instance_valid(t._visual))
	for c in t._visual.get_children():
		print("   ", c.name, " scale=", c.scale if c is Node3D else "")
	get_tree().quit()
