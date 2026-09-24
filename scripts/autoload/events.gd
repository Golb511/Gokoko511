extends Node
## Global event bus. Decouples systems (UI, progression, battle) from each other.

signal currency_changed
signal profile_changed
signal language_changed(locale: String)
signal inventory_changed
signal hero_changed(hero_id: String)
signal achievement_unlocked(achievement_id: String)
signal quest_progress(quest_id: String)
signal toast(text: String, color: Color)
signal settings_changed

# Battle-scoped events
signal enemy_killed(enemy: Node, by_hero: bool)
signal enemy_leaked(enemy: Node, lives_lost: int)
signal wave_started(index: int, total: int)
signal wave_cleared(index: int)
signal tower_built(tower: Node)
signal tower_upgraded(tower: Node)
signal tower_sold(tower: Node)
signal boss_spawned(boss: Node)
signal boss_phase_changed(boss: Node, phase: int)
signal battle_gold_changed(gold: int)
signal battle_lives_changed(lives: int)
signal loot_dropped(item: Dictionary, world_pos: Vector3)
signal battle_ended(victory: bool, result: Dictionary)


## Track a stat counter (achievements + quests listen to this).
signal stat_tracked(stat: String, amount: int)

func track(stat: String, amount: int = 1) -> void:
	stat_tracked.emit(stat, amount)

func notify(text: String, color: Color = Color(1, 0.85, 0.5)) -> void:
	toast.emit(text, color)
