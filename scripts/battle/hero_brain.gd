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
	# Most dangerous enemy = furthest along its route (closest to the citadel),
	# discounted by distance so the hero doesn't run back and forth across the map.
	var danger: Enemy = null
	var best_score := -INF
	for e in b.enemies:
		if not is_instance_valid(e) or not e.alive or e.stealthed or (hero.melee and e.flying):
			continue
		var score: float = e.progress / e.route.length * 40.0 - e.global_position.distance_to(hero.global_position) * (0.6 if hero.melee else 1.0)
		if score > best_score:
			best_score = score
			danger = e
	if danger == null:
		return
	var engaged: bool = hero.target != null and is_instance_valid(hero.target) and hero.target.alive \
		and hero.target.global_position.distance_to(hero.global_position) <= hero.attack_range + 1.5
	var desired := 1.2 if hero.melee else hero.attack_range * 0.8
	var dist: float = hero.global_position.distance_to(danger.global_position)
	if not (engaged and dist < desired + 6.0) and dist > desired + 1.5 and not hero.moving:
		var want: Vector3 = danger.global_position
		if not hero.melee:
			var away: Vector3 = hero.global_position - danger.global_position
			away.y = 0.0
			want = danger.global_position + away.normalized() * desired
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
		var cluster := _best_cluster(hero.global_position, rng, maxf(3.0, r))
		var n: int = cluster.count
		var boss_near: bool = cluster.boss
		var need := 3 if i == 4 else 2
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
				if near.size() >= need or (boss_near and near.size() > 0):
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
