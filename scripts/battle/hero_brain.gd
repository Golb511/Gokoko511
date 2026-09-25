class_name HeroBrain
extends RefCounted
## AUTO-mode bot for the hero. Reads only what the player could see
## (enemy positions/health on the field) and issues the same commands.
##
## Behaviour adapts to the hero's role:
## - melee heroes intercept enemies ahead of them on the road instead of
##   chasing from behind, commit to a fight once engaged and only break off to
##   stop an unblocked enemy that is about to reach the citadel;
## - tanks hold the enemy front, retreat later and heal themselves first;
## - ranged heroes keep their distance behind the front and focus the enemy
##   that is furthest along the road;
## - energy is budgeted: summons and the ultimate have priority over cheap
##   self-buffs, and defensive skills are used when they actually help.

const LEAK_RATIO := 0.78       # route progress at which an enemy counts as "about to leak"

var hero: Hero
var _t := 0.0
var retreating := false
var _committed: Enemy = null
var _role := ""
var _anchor := Vector3.INF      # the choke point every ground road passes
var _kz_cache: Dictionary = {}  # PathRoute -> [offset, time]
var _retreat_to := Vector3.INF  # fixed once per retreat so the hero can stop and recover


func update(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or not hero.alive:
		return
	_t = 0.4
	if _role == "":
		_role = str(hero.hdef.get("role", "attacker"))
	var b = hero.battle
	var escape: Vector3 = b.hazard_escape(hero.global_position, hero.hp_ratio())
	if escape != Vector3.INF:
		hero.command_move(escape)
		return
	var tank := _role == "tank"
	var retreat_at := 0.22 if tank else 0.28
	var resume_at := 0.6 if tank else 0.7
	if hero.hp_ratio() < 0.5 and _use_defensive(true):
		return
	if hero.hp_ratio() < retreat_at:
		if not retreating:
			_retreat_to = _safe_point()
		retreating = true
	elif hero.hp_ratio() > resume_at:
		retreating = false
		_retreat_to = Vector3.INF
	if retreating:
		if _retreat_to == Vector3.INF:
			_retreat_to = _safe_point()
		if hero.guard_pos.distance_to(_retreat_to) > 2.0:
			hero.command_move(_retreat_to)
		_use_defensive(false)
		return
	if _engage_on_contact():
		_use_abilities()
		return
	_position()
	_use_abilities()


# ---------------------------------------------------------------- positioning
## A melee hero walking to an intercept point doesn't swing at anything, so an
## enemy could slip right past it. Stop and fight whatever comes into reach.
func _engage_on_contact() -> bool:
	if not hero.melee or not hero.moving:
		return false
	var best: Enemy = null
	var bd := hero.attack_range + 1.6
	for e in hero.battle.enemies_near(hero.global_position, bd):
		if not e.is_valid_target() or e.flying or (_is_blocked(e) and e.blocker != hero):
			continue
		var d: float = e.global_position.distance_to(hero.global_position)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return false
	hero.moving = false
	hero.guard_pos = hero.global_position
	hero.target = best
	_committed = best
	return true


func _position() -> void:
	var b = hero.battle
	var engaged := _engaged()
	var danger := _most_dangerous()
	if danger == null:
		_committed = null
		# Quiet moment: melee heroes wait at the choke point every road passes
		# (at its best tower coverage when the roads never merge early).
		if hero.melee and not engaged and not hero.moving:
			if _anchor == Vector3.INF:
				_anchor = _find_choke()
			var wait := _anchor
			var main: PathRoute = null
			for r in b.routes:
				if not r.air:
					main = r
					break
			var kz := _kill_zone(main)
			if kz >= 0.0 and kz < main.closest_offset(_anchor):
				wait = main.sample(kz)
			if hero.guard_pos.distance_to(wait) > 3.0:
				hero.command_move(wait)
		return
	# Stay in a fight we are winning unless an unblocked enemy is about to leak.
	if engaged:
		var urgent: bool = danger != hero.target and _is_leaking(danger) and not _is_blocked(danger) \
			and danger.global_position.distance_to(hero.global_position) > hero.attack_range + 2.0
		if not urgent:
			_retarget()
			return
	if hero.moving:
		# Re-plan only when the committed enemy is gone.
		if _committed != null and is_instance_valid(_committed) and _committed.alive:
			return
	_committed = danger
	var want := _intercept(danger)
	if hero.melee and not danger.flying and danger.route != null:
		# Hold enemies where the towers can reach them: if we would meet the
		# enemy upstream of its road's kill zone, wait in the kill zone instead.
		var kz := _kill_zone(danger.route)
		# Only worth waiting when the enemy is already close to the kill zone;
		# on a long road the hero goes and fights upstream instead of idling.
		# Waiting is only worth it while the hero has nothing to spend: with
		# full energy it goes and uses it on the enemies upstream.
		if kz >= 0.0 and danger.progress < kz and hero.energy < hero.max_energy * 0.95 \
				and danger.route.closest_offset(want) < kz - 3.0:
			want = danger.route.sample(kz)
	if not hero.melee:
		var away: Vector3 = hero.global_position - want
		away.y = 0.0
		if away.length() < 0.1:
			away = Vector3(0, 0, 1)
		want = want + away.normalized() * hero.attack_range * 0.8
	if want.distance_to(hero.global_position) > (1.2 if hero.melee else 1.8):
		hero.command_move(b.clamp_to_bounds(want))


# ---------------------------------------------------------------- choke point
## The stretch of road where all ground routes have merged (or the last part of
## a single road before the citadel): every leaker has to come through it.
## Offset along `r` with the most tower firepower (towers in range, weighted
## by level), between 30% and 92% of the road; -1 when no tower covers it.
func _kill_zone(r: PathRoute) -> float:
	var now := Time.get_ticks_msec() / 1000.0
	var c: Array = _kz_cache.get(r, [])
	if not c.is_empty() and now - float(c[1]) < 4.0:
		return float(c[0])
	var best := -1.0
	var best_v := 0.0
	var off := r.length * 0.3
	while off < r.length * 0.92:
		var v := _coverage(r.sample(off))
		# Slight preference for points closer to the citadel (less walking back).
		v += off / r.length * 0.5
		if v > best_v:
			best_v = v
			best = off
		off += 2.0
	if best_v < 1.5:
		best = -1.0
	_kz_cache[r] = [best, now]
	return best


## Tower firepower reaching point p (towers in range, weighted by level).
func _coverage(p: Vector3) -> float:
	var v := 0.0
	for t in hero.battle.towers:
		if is_instance_valid(t) and t.traps.is_empty() and t.global_position.distance_to(p) <= t.range_():
			v += float(t.level)
	return v


func _find_choke() -> Vector3:
	var ground: Array = []
	for r in hero.battle.routes:
		if not r.air:
			ground.append(r)
	var main: PathRoute = ground[0]
	var off: float = main.length - 10.0
	if ground.size() > 1:
		# Walk back from the citadel while every road is still together.
		var o := main.length - 4.0
		while o > 6.0:
			var p := main.sample(o)
			var together := true
			for r in ground:
				if r.distance_to(p) > 2.0:
					together = false
					break
			if not together:
				break
			o -= 1.0
		off = clampf(o + 2.0, 6.0, main.length - 8.0)
	else:
		off = clampf(main.length * 0.82, 6.0, main.length - 8.0)
	return main.sample(off)


func _engaged() -> bool:
	var t: Enemy = hero.target
	return t != null and is_instance_valid(t) and t.alive \
		and t.global_position.distance_to(hero.global_position) <= hero.attack_range + t.radius + 1.2


## Most dangerous enemy = furthest along its route (closest to the citadel),
## discounted by distance so the hero doesn't run back and forth.
func _most_dangerous() -> Enemy:
	var best: Enemy = null
	var best_score := -INF
	for e in hero.battle.enemies:
		if not is_instance_valid(e) or not e.alive or e.stealthed or (hero.melee and e.flying):
			continue
		var ratio: float = e.progress / maxf(1.0, e.route.length)
		var score: float = ratio * 40.0 - e.global_position.distance_to(hero.global_position) * (0.6 if hero.melee else 1.0)
		if hero.melee and _is_blocked(e):
			score -= 8.0          # soldiers already hold it
		if e is Boss:
			score += 6.0
		if score > best_score:
			best_score = score
			best = e
	return best


## Where to meet a marching enemy: a point ahead of it on its road, so a
## slower hero isn't left chasing it from behind.
func _intercept(e: Enemy) -> Vector3:
	if e.flying or e.route == null:
		return e.global_position
	var spd: float = maxf(0.1, e.base_speed * e.speed_mult())
	if e.state != "march" or e.blocker != null:
		spd = 0.0
	var p: Vector3 = e.global_position
	for i in 2:
		var t: float = p.distance_to(hero.global_position) / maxf(1.0, hero.base_speed)
		p = e.route.sample(e.progress + spd * t * 0.9)
	return p


## Pick the best target within reach: for melee, the leading enemy that nobody
## blocks yet; for ranged, the enemy furthest along that can be killed fastest.
func _retarget() -> void:
	var cur: Enemy = hero.target
	var best: Enemy = null
	var best_score := -INF
	var reach := hero.attack_range + 1.5
	for e in hero.battle.enemies_near(hero.global_position, reach):
		if not e.is_valid_target() or (hero.melee and e.flying):
			continue
		var ratio: float = e.progress / maxf(1.0, e.route.length)
		var score := ratio * 4.0
		if hero.melee:
			if _is_blocked(e) and e.blocker != hero:
				score -= 3.0
			# Slippery enemies (blink / stealth) escape blockers: kill them while in reach.
			if e.skills.has("blink") or e.skills.has("stealth"):
				score += 1.5
		else:
			score += (1.0 - e.hp_ratio()) * 1.5
		if e == cur:
			score += 0.6            # avoid flip-flopping
		if score > best_score:
			best_score = score
			best = e
	if best != null and best != cur:
		hero.target = best


func _is_blocked(e: Enemy) -> bool:
	return e.blocker != null and is_instance_valid(e.blocker) and e.blocker.alive


func _is_leaking(e: Enemy) -> bool:
	return e.progress / maxf(1.0, e.route.length) > LEAK_RATIO


## Retreat behind the nearest defended stretch of road rather than all the way
## to the gate: the point on the hero's current road ~10 m back toward the citadel.
func _safe_point() -> Vector3:
	var b = hero.battle
	var best_r: PathRoute = null
	var bd := INF
	for r in b.routes:
		if r.air:
			continue
		var d: float = r.distance_to(hero.global_position)
		if d < bd:
			bd = d
			best_r = r
	if best_r == null:
		return hero.spawn_pos
	var off: float = best_r.closest_offset(hero.global_position) + 10.0
	var p: Vector3 = best_r.sample(minf(off, best_r.length - 8.0))
	var d := best_r.direction(best_r.closest_offset(p))
	return b.clamp_to_bounds(p + Vector3(-d.z, 0, d.x) * 2.5)


# ---------------------------------------------------------------- abilities
func _use_abilities() -> void:
	var b = hero.battle
	# Hold energy for the ultimate only while it is about to come off cooldown,
	# or while it is ready but unaffordable and a big fight is building up.
	var ult_cost := float(hero.ability_def(4).energy) if hero.ability_ids.size() > 4 else 0.0
	var ult_cd: float = hero.cooldowns[4] if hero.ability_ids.size() > 4 else 99.0
	var ult_ready_soon: bool = (ult_cd > 0.0 and ult_cd < 5.0) \
		or (ult_cd <= 0.0 and hero.energy < ult_cost and hero.energy >= ult_cost * 0.7 and _threat(hero.global_position, 12.0) >= 5.0)
	# Summon upkeep: heroes whose summons are their main damage keep enough
	# energy for the next summon instead of spending it on self-buffs.
	var summon_cost := 0.0
	for k in mini(4, hero.ability_ids.size()):
		var sd: Dictionary = hero.ability_def(k)
		if sd.type == "summon" and hero.cooldowns[k] < 4.0:
			summon_cost = maxf(summon_cost, float(sd.energy))
	var order := _priority_order()
	for i in order:
		if not hero.can_cast(i):
			continue
		var ab: Dictionary = hero.ability_def(i)
		var cost := float(ab.energy)
		# Save up for the ultimate when it is almost off cooldown, unless this
		# skill is cheap enough to leave the ultimate affordable.
		var urgent_summon: bool = ab.type == "summon" and _leak_near(float(ab.get("range", 8.0)) + 4.0)
		if i != 4 and ult_ready_soon and hero.energy - cost < ult_cost and hero.hp_ratio() > 0.45 and not urgent_summon:
			continue
		if ab.type in ["buff", "taunt", "tower_buff"] and summon_cost > 0.0 and hero.energy - cost < summon_cost and hero.hp_ratio() > 0.45:
			continue
		var r := float(ab.get("radius", 3.0))
		var rng := float(ab.get("range", 8.0))
		var cluster := _best_cluster(hero.global_position, rng, maxf(3.0, r))
		var n: int = cluster.count
		var boss_near: bool = cluster.boss
		var threat := _threat(hero.global_position, rng)
		var need := 4 if i == 4 else 2
		match ab.type:
			"summon", "summon_dragon":
				# Summons are worth it against a crowd, a big enemy or a leak.
				if n >= (4 if i == 4 else 1) or boss_near or threat >= (6.0 if i == 4 else 1.0) or _leak_near(rng):
					hero.cast(i, _summon_point(cluster, rng))
					return
			"taunt":
				var loose := 0
				for e in b.enemies_near(hero.global_position, r):
					if not e.flying and not _is_blocked(e):
						loose += 1
				if (loose >= 2 and hero.hp_ratio() > 0.45) or (boss_near and hero.hp_ratio() > 0.6):
					hero.cast(i, hero.global_position)
					return
			"buff":
				var near: int = b.enemies_near(hero.global_position, 4.0).size()
				var defensive: bool = ab.has("heal") or str(ab.get("buff", {}).get("stat", "")) == "defense"
				var want := false
				if defensive:
					want = (near >= 3 and hero.hp_ratio() < 0.85) or (boss_near and near > 0) or (near > 0 and hero.hp_ratio() < 0.55)
				else:
					want = near >= 2 or (boss_near and near > 0)
				if want:
					hero.cast(i, hero.global_position)
					return
			"tower_buff":
				if (n >= 3 or boss_near) and not b.towers_near(hero.global_position, r).is_empty():
					hero.cast(i, hero.global_position)
					return
			"melee_aoe", "nova":
				var near: Array = b.enemies_near(hero.global_position, r)
				if near.size() >= need or (boss_near and near.size() > 0) or (near.size() >= 1 and _leak_near(r)):
					hero.cast(i, hero.global_position)
					return
			_:
				if n >= need or (boss_near and n >= 1) or (n >= 1 and _leak_near(rng)):
					hero.cast(i, cluster.center, cluster.best)
					return


## Ultimate first, then summons, then damage, then self-buffs.
func _priority_order() -> Array:
	var rank := {"summon": 1, "summon_dragon": 1, "taunt": 3, "buff": 4, "tower_buff": 3}
	var order: Array = []
	for i in hero.ability_ids.size():
		order.append(i)
	order.sort_custom(func(a, c):
		var ra: int = 0 if a == 4 else int(rank.get(hero.ability_def(a).type, 2))
		var rc: int = 0 if c == 4 else int(rank.get(hero.ability_def(c).type, 2))
		return ra < rc if ra != rc else a > c)
	return order


## Summed enemy strength nearby, in units of "one basic enemy".
func _threat(p: Vector3, r: float) -> float:
	var t := 0.0
	for e in hero.battle.enemies_near(p, r):
		t += clampf(e.max_hp / 250.0, 0.4, 8.0)
	return t


func _leak_near(r: float) -> bool:
	for e in hero.battle.enemies_near(hero.global_position, r):
		if _is_leaking(e) and not _is_blocked(e):
			return true
	return false


## Drop summons in front of the enemy column so they meet it as a wall.
func _summon_point(cluster: Dictionary, rng: float) -> Vector3:
	var e: Enemy = cluster.best
	if e == null or e.flying or e.route == null:
		return cluster.center
	var p: Vector3 = e.route.sample(e.progress + 3.0)
	if p.distance_to(hero.global_position) > rng:
		return cluster.center
	return p


## Defensive skills. `urgent` = the hero is hurt and still fighting.
func _use_defensive(urgent: bool) -> bool:
	for i in 5:
		if not hero.can_cast(i):
			continue
		var ab: Dictionary = hero.ability_def(i)
		var defensive: bool = ab.has("heal") or str(ab.get("buff", {}).get("stat", "")) == "defense"
		if ab.type == "buff" and defensive and (ab.has("heal") or not urgent):
			hero.cast(i, hero.global_position)
			return true
	return false


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
