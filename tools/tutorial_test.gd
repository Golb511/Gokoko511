extends Node

func _ready() -> void:
	await get_tree().create_timer(3.0).timeout
	var b = get_tree().current_scene
	var tut = null
	for c in b.get_children():
		if c is TutorialDirector: tut = c
	print("TUT present=", tut != null, " step=", tut.step if tut else -9)
	b.build_tower(b.slots[0], "archer"); await get_tree().process_frame
	print("TUT after build1 step=", tut.step)
	b.build_tower(b.slots[1], "mage"); await get_tree().process_frame
	print("TUT after build2 step=", tut.step)
	b.hud.call_next_wave(); await get_tree().process_frame
	print("TUT after start step=", tut.step)
	b.hero.command_move(b.hero.global_position + Vector3(2, 0, 0)); await get_tree().process_frame
	print("TUT after move step=", tut.step)
	b.hero.energy = 100
	b.hero.cast(0, b.hero.global_position); await get_tree().process_frame
	print("TUT after ability step=", tut.step)
	b.gold = 1000
	b.upgrade_tower(b.towers[0]); await get_tree().process_frame
	print("TUT after upgrade step=", tut.step)
	await get_tree().create_timer(6.0).timeout
	print("TUT done setting=", Game.setting("tutorial_done"), " node_valid=", is_instance_valid(tut))
	get_tree().quit()
