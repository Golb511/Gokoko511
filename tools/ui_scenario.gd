extends Node
## Scripted UI scenario for screenshots: build menu -> tower menu -> victory.
## Pass --scenario=build|tower|victory|boss

func _ready() -> void:
	var which := "build"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario="):
			which = a.substr(11)
	await get_tree().create_timer(6.0).timeout
	var b = get_tree().current_scene
	var slot = b.slots[3]
	b.camera_rig.focus_on(slot.global_position + Vector3(0, 0, 4))
	await get_tree().create_timer(1.0).timeout
	match which:
		"build":
			b.hud.open_build_menu(slot)
		"tower":
			b.gold = 5000
			var t = b.build_tower(slot, "mage")
			b.upgrade_tower(t)
			b.upgrade_tower(t)
			await get_tree().create_timer(0.5).timeout
			b.hud.open_tower_menu(t)
		"victory":
			for i in 3:
				b.loot.append(LootGenerator.roll_drop(5, 3.0, 1 + i))
			b.waves.current = 4
			b.lives = 19
			b._end(true)
		"boss":
			b.gold = 5000
			for i in 5:
				var t = b.build_tower(b.slots[i], ["archer", "mage", "artillery"][i % 3])
				b.upgrade_tower(t)
			var boss = b.spawn_enemy("ashen_warlord", 0, 60.0)
			b.spawn_enemy("skeleton_warrior", 0, 55.0)
			b.spawn_enemy("skeleton_minion", 0, 58.0)
			b.camera_rig.follow = boss
			b.hero.command_move(boss.global_position + Vector3(2, 0, 2))
