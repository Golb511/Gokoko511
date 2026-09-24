class_name HeroBrain
extends RefCounted
## AUTO-mode bot for the hero. Reads only what the player could see
## (enemy positions/health on the field) and issues the same commands.
## Behaviour adapts to hero role: melee holds the frontline closest to the
## citadel, ranged kites behind it, everyone retreats when badly hurt.

var hero: Hero
var _t := 0.0
var retreating := false


func update(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or not hero.alive:
		return
	_t = 0.5
	var b = hero.battle
	if hero.hp_ratio() < 0.28:
		retreating = true
	elif hero.hp_ratio() > 0.7:
		retreating = false
	if retreating:
		if hero.guard_pos.distance_to(hero.spawn_pos) > 2.0:
			hero.command_move(hero.spawn_pos)
		_use_defensive()
		return
	# Most dangerous enemy = furthest along its route (closest to the citadel).
	var danger: Enemy = null
	for e in b.enemies:
		if e.alive and not e.stealthed and (danger == null or e.progress / e.route.length > danger.progress / danger.route.length):
			if hero.melee and e.flying:
				continue
			danger = e
	if danger == null:
		return
	var want: Vector3 = danger.global_position
	if not hero.melee:
		var back: Vector3 = danger.route.sample(danger.progress + 6.0)
		want = back
	if want.distance_to(hero.guard_pos) > 3.5:
		hero.command_move(want)
	_use_abilities()


func _use_abilities() -> void:
	var b = hero.battle
	for i in range(4, -1, -1):
		if not hero.can_cast(i):
			continue
		var ab: Dictionary = hero.ability_def(i)
		var r := float(ab.get("radius", 3.0))
		var rng := float(ab.get("range", 8.0))
		var cluster := _best_cluster(hero.global_position, rng, maxf(2.0, r))
		var n: int = cluster.count
		var boss_near: bool = cluster.boss
		var need := 5 if i == 4 else 3
		match ab.type:
			"buff", "taunt", "tower_buff":
				if n >= 2 or boss_near:
					hero.cast(i, hero.global_position)
					return
			"summon", "summon_dragon":
				if n >= 3 or boss_near:
					hero.cast(i, cluster.center)
					return
			"melee_aoe", "nova":
				var near: Array = b.enemies_near(hero.global_position, r)
				if near.size() >= need - 1 or (boss_near and near.size() > 0):
					hero.cast(i, hero.global_position)
					return
			_:
				if n >= need or (boss_near and n >= 1):
					hero.cast(i, cluster.center, cluster.best)
					return


func _use_defensive() -> void:
	for i in 5:
		if hero.can_cast(i) and hero.ability_def(i).type in ["buff", "taunt"]:
			hero.cast(i, hero.global_position)
			return


func _best_cluster(origin: Vector3, rng: float, r: float) -> Dictionary:
	var best := {"count": 0, "center": origin, "boss": false, "best": null}
	var cands: Array = hero.battle.enemies_near(origin, rng)
	for e in cands:
		if not e.is_valid_target():
			continue
		var c := 0
		for o in cands:
			if o.global_position.distance_to(e.global_position) <= r:
				c += 1
		var is_boss: bool = e is Boss
		if c > best.count or (is_boss and not best.boss):
			best = {"count": c, "center": e.global_position, "boss": is_boss or best.boss, "best": e}
	return best
