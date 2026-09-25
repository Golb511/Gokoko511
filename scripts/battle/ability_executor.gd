class_name AbilityExecutor
extends RefCounted
## Executes data-driven hero abilities (see data/abilities.json). Each ability
## type is one function so new abilities are pure data unless a new type is needed.

static func execute(hero: Hero, id: String, ab: Dictionary, point: Vector3, target: Enemy) -> bool:
	var b = hero.battle
	var ult := bool(ab.get("ultimate", false))
	var elem: String = ab.get("element", "physical")
	var dmg := hero.damage_value(float(ab.get("dmg", 1.0)), ult)
	var dtype := elem if elem != "earth" else "physical"
	var range_ := float(ab.get("range", 8.0))
	# Clamp point to range.
	var to := point - hero.global_position
	to.y = 0.0
	if to.length() > range_:
		point = hero.global_position + to.normalized() * range_
	point.y = 0.0
	match ab.type:
		"melee_aoe":
			_anim(hero, "special", 0.45)
			var r := float(ab.radius)
			_later(hero, 0.3, func():
				for e in b.enemies_near(hero.global_position, r):
					if e.flying: continue
					_hit(hero, e, dmg, dtype, ab)
				VFX.explosion(b.fx_root, hero.global_position, r, elem if elem != "physical" else "earth")
				b.shake(0.25, 0.25)
				Sfx.play("explosion", -4.0))
		"nova":
			_anim(hero, "cast", 0.4)
			var r := float(ab.radius)
			_later(hero, 0.25, func():
				for e in b.enemies_near(hero.global_position, r):
					_hit(hero, e, dmg, dtype, ab)
				VFX.nova(b.fx_root, hero.global_position, r, elem)
				if ult: b.shake(0.4, 0.4)
				Sfx.play("freeze" if elem == "ice" else "magic", -2.0))
		"dash":
			var from := hero.global_position
			var dest: Vector3 = b.clamp_to_bounds(point)
			hero.moving = false
			hero._release_target()
			hero.guard_pos = dest
			hero.model.face_instant(dest)
			hero.model.play_action("run", 2.0)
			hero._busy = 0.3
			var tw := hero.create_tween()
			tw.tween_property(hero, "global_position", dest, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			VFX.particles(b.fx_root, from + Vector3(0, 1, 0), {"amount": 24, "lifetime": 0.5, "speed": 1.0, "size": 0.5, "color": VFX.color(elem), "box": Vector3(0.3, 0.5, 0.3)})
			var r := float(ab.get("radius", 1.5))
			if dmg > 0.0 and r > 0.0:
				for e in b.enemies_near((from + dest) * 0.5, from.distance_to(dest) * 0.5 + r):
					if _dist_to_segment(e.global_position, from, dest) <= r and not e.flying:
						_hit(hero, e, dmg, dtype, ab)
			_later(hero, 0.25, func(): VFX.nova(b.fx_root, dest, maxf(1.5, r), elem))
			Sfx.play("slash", -2.0)
			_apply_buff(hero, ab)
		"blink_strike":
			var hits := int(ab.get("hits", 1))
			var ranged := bool(ab.get("ranged", false))
			hero._busy = hits * 0.2 + 0.2
			for h in hits:
				_later(hero, h * 0.2, func():
					var t := _strongest(b, hero.global_position if ranged else hero.global_position, range_)
					if t == null: return
					if not ranged:
						VFX.shadow_burst(b.fx_root, hero.global_position)
						var dir: Vector3 = (hero.global_position - t.global_position)
						dir.y = 0
						hero.global_position = t.global_position + dir.normalized() * 1.1
						hero.guard_pos = hero.global_position
						hero.model.face_instant(t.global_position)
						hero.model.play_action("attack", 2.0)
					else:
						hero.model.face_instant(t.global_position)
						hero.model.play_action("attack", 2.0)
						VFX.lightning(b.fx_root, hero.global_position + Vector3(0, 1.4, 0), t.global_position + Vector3(0, 1, 0), VFX.color(elem), 0.08, 0.15)
					_hit(hero, t, dmg, dtype, ab)
					VFX.shadow_burst(b.fx_root, t.global_position, 0.8)
					Sfx.play("slash", -4.0))
		"summon":
			_anim(hero, "summon", 0.5)
			var pos := point if ab.target == "point" else hero.global_position
			var lvl := int(hero.stats.level)
			for k in int(ab.count):
				var ang := TAU * k / float(ab.count)
				var p := pos + Vector3(cos(ang), 0, sin(ang)) * 1.4
				var d: Dictionary = DB.allies[ab.unit]
				var scale := 1.0 + 0.06 * (lvl - 1)
				# Hero Mastery can strengthen summons (summon_hp / summon_dmg).
				var hs := scale * (1.0 + float(ab.get("summon_hp", 0.0)))
				var ds := scale * (1.0 + float(ab.get("summon_dmg", 0.0)))
				var u: AllyUnit = b.spawn_ally(ab.unit, {"hp": float(d.hp) * hs, "dmg": [float(d.damage[0]) * ds, float(d.damage[1]) * ds], "lifetime": float(ab.duration), "engage": 5.0}, b.clamp_to_bounds(p))
				u.slot_offset = Vector3.ZERO
				if elem == "shadow":
					VFX.shadow_burst(b.fx_root, p, 1.0)
				else:
					VFX.fire_pillar(b.fx_root, p, 1.0, false)
			Sfx.play("magic", -2.0)
		"blast":
			_anim(hero, "cast", 0.35)
			var r := float(ab.radius)
			var tele := VFX.area_disc(b.fx_root, point, r, VFX.color(elem))
			b.spawn_projectile(hero.global_position + Vector3(0, 1.6, 0), null, {"type": _orb_for(elem), "target_pos": point, "speed": 20.0, "damage": 0.0, "team": Unit.Team.PLAYER, "arc": 2.0 if not ult else 0.0, "from_sky": ult})
			_later(hero, 0.45 if not ult else 0.7, func():
				if is_instance_valid(tele): tele.queue_free()
				for e in b.enemies_near(point, r):
					_hit(hero, e, dmg, dtype, ab)
				VFX.explosion(b.fx_root, point, r, elem)
				b.shake(0.2 + (0.4 if ult else 0.0), 0.3)
				Sfx.play("explosion", -2.0))
		"cloud":
			_anim(hero, "cast", 0.35)
			var zone := AbilityZone.new()
			b.fx_root.add_child(zone)
			zone.start(b, point, float(ab.radius), float(ab.duration), dmg, dtype, ab.get("status", {}), hero.stats.damage, elem)
			Sfx.play("magic", -2.0)
		"buff":
			_anim(hero, "cheer" if elem == "physical" else "cast", 0.4)
			_apply_buff(hero, ab)
			if ab.has("heal"):
				hero.heal(hero.max_hp * float(ab.heal))
				VFX.heal(b.fx_root, hero.global_position)
			if ab.has("lifesteal"):
				hero.lifesteal = hero.stats.lifesteal + float(ab.lifesteal)
				_later(hero, float(ab.buff.duration), func(): hero.lifesteal = hero.stats.lifesteal)
			VFX.nova(b.fx_root, hero.global_position, 2.0, elem)
			Sfx.play("levelup", -8.0)
		"chain":
			var t := target if target != null and is_instance_valid(target) and target.alive else _nearest(b, hero.global_position, range_)
			if t == null:
				return false
			_anim(hero, "cast", 0.3)
			chain_lightning(hero, t, dmg, int(ab.count), elem)
		"volley":
			_anim(hero, "cast", 0.4)
			var r := float(ab.radius)
			var n := int(ab.count)
			var dur := float(ab.duration)
			var tele := VFX.area_disc(b.fx_root, point, r, VFX.color(elem))
			for k in n:
				_later(hero, 0.2 + dur * k / n, func():
					var p := point + Vector3(randf_range(-r, r), 0, randf_range(-r, r)) * 0.8
					b.spawn_projectile(p + Vector3(randf_range(-2, 2), 9.0, randf_range(-2, 2)), null, {"type": "raven" if ab.icon == "raven" else ("lightning_orb" if elem == "lightning" else "arrow"), "target_pos": p, "speed": 26.0, "damage": dmg, "dmg_type": dtype, "splash": 1.4, "team": Unit.Team.PLAYER, "status": _status_abs(ab, hero), "source": hero}))
			_later(hero, dur + 0.5, func(): if is_instance_valid(tele): tele.queue_free())
		"line":
			_anim(hero, "cast", 0.4)
			var from := hero.global_position
			var dir := (point - from)
			dir.y = 0
			dir = dir.normalized()
			var end := from + dir * range_
			var r := float(ab.radius)
			hero.model.face_instant(end)
			var steps := int(range_ / 1.5)
			for k in steps:
				_later(hero, k * 0.03, func():
					var p := from + dir * (1.0 + k * 1.5)
					if elem == "fire":
						VFX.fire_pillar(b.fx_root, p, 1.2, false)
					else:
						VFX.hit(b.fx_root, p + Vector3(0, 0.5, 0), elem)
						VFX.particles(b.fx_root, p, {"amount": 8, "lifetime": 0.5, "speed": 2.0, "size": 0.5, "color": VFX.color(elem)}))
			for e in b.enemies_near((from + end) * 0.5, range_ * 0.5 + r):
				if _dist_to_segment(e.global_position, from, end) <= r:
					_hit(hero, e, dmg, dtype, ab)
			Sfx.play("explosion", -6.0)
		"taunt":
			_anim(hero, "cheer", 0.5)
			for e in b.enemies_near(hero.global_position, float(ab.radius)):
				e.taunt(hero, float(ab.get("duration", 4.0)))
			_apply_buff(hero, ab)
			VFX.nova(b.fx_root, hero.global_position, float(ab.radius), elem)
			Sfx.play("boss", -10.0)
		"execute":
			var t := target if target != null and is_instance_valid(target) and target.alive else _strongest(b, hero.global_position, range_)
			if t == null:
				return false
			hero.model.face_instant(t.global_position)
			_anim(hero, "special", 0.45)
			var tref := weakref(t)
			_later(hero, 0.3, func():
				var tt: Enemy = tref.get_ref()
				if tt == null or not tt.alive: return
				var thr := float(ab.get("execute", 0.0))
				if thr > 0.0 and tt.hp_ratio() <= thr and not tt.tags.has("boss"):
					tt.take_damage(tt.hp + 1.0, "true", hero, true)
				else:
					_hit(hero, tt, dmg, dtype, ab)
				VFX.explosion(b.fx_root, tt.global_position, 1.2, elem if elem != "physical" else "fire")
				Sfx.play("slash", 0.0))
		"tower_buff":
			_anim(hero, "cast", 0.4)
			for t in b.towers_near(hero.global_position, float(ab.radius)):
				t.add_buff("overcharge", float(ab.buff.mult), float(ab.buff.duration))
				VFX.lightning(b.fx_root, hero.global_position + Vector3(0, 1.5, 0), t.global_position + Vector3(0, 3, 0), VFX.color(elem), 0.1, 0.3)
			Sfx.play("lightning", -4.0)
		"summon_dragon":
			_anim(hero, "summon", 0.5)
			b.globals.summon_dragon(dmg, float(ab.get("duration", 6.0)))
		_:
			push_warning("Unknown ability type %s" % ab.type)
			return false
	return true


static func chain_lightning(hero: Unit, first: Enemy, dmg: float, count: int, elem: String) -> void:
	var b = hero.battle
	var hit_list: Array = []
	var cur: Enemy = first
	var from := hero.global_position + Vector3(0, 1.5, 0)
	for k in count:
		if cur == null:
			break
		hit_list.append(cur)
		VFX.lightning(b.fx_root, from, cur.global_position + Vector3(0, 1.0, 0), VFX.color(elem))
		cur.take_damage(dmg * pow(0.88, k), elem, hero)
		from = cur.global_position + Vector3(0, 1.0, 0)
		var nxt: Enemy = null
		var best := 5.0
		for e in b.enemies_near(cur.global_position, 5.0):
			if e in hit_list or not e.is_valid_target():
				continue
			var d: float = e.global_position.distance_to(cur.global_position)
			if d < best:
				best = d
				nxt = e
		cur = nxt
	Sfx.play("lightning", -6.0)


static func _hit(hero: Hero, e: Enemy, dmg: float, dtype: String, ab: Dictionary) -> void:
	if not is_instance_valid(e) or not e.alive:
		return
	var crit := randf() < hero.crit
	var dealt := e.take_damage(dmg * (hero.crit_dmg if crit else 1.0), dtype, hero, crit)
	hero.heal(dealt * (hero.lifesteal + float(ab.get("lifesteal", 0.0))))
	var st := _status_abs(ab, hero)
	if not st.is_empty():
		e.apply_status(st.id, st.duration, st.power, hero)
	var thr := float(ab.get("execute", 0.0))
	if thr > 0.0 and e.alive and e.hp_ratio() <= thr and not e.tags.has("boss"):
		e.take_damage(e.hp + 1.0, "true", hero)
	hero.on_hit_landed(e)


static func _status_abs(ab: Dictionary, hero: Hero) -> Dictionary:
	if not ab.has("status"):
		return {}
	var st: Dictionary = ab.status
	var p := float(st.power)
	if st.id in ["burn", "poison"]:
		p *= hero.stats.damage
	return {"id": st.id, "duration": float(st.duration), "power": p}


static func _apply_buff(hero: Hero, ab: Dictionary) -> void:
	if not ab.has("buff"):
		return
	var bf: Dictionary = ab.buff
	match bf.stat:
		"attack_speed":
			var base: float = hero.stats.attack_speed
			hero.attack_rate = base * float(bf.mult)
			_later(hero, float(bf.duration), func(): hero.attack_rate = base)
		"defense":
			hero.add_buff("ab_def", "armor", float(bf.mult), float(bf.duration))
		"damage":
			hero.add_buff("ab_dmg", "damage", float(bf.mult), float(bf.duration))


static func _anim(hero: Hero, logical: String, busy: float) -> void:
	hero._busy = busy
	if hero.model:
		hero.model.play_action(logical, 1.2)


static func _later(node: Node, t: float, cb: Callable) -> void:
	if t <= 0.0:
		cb.call()
		return
	node.get_tree().create_timer(t, false).timeout.connect(func(): if is_instance_valid(node): cb.call())


static func _dist_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var p2 := Vector2(p.x, p.z)
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var ab := b2 - a2
	var t := clampf((p2 - a2).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
	return p2.distance_to(a2 + ab * t)


static func _strongest(b: Node, pos: Vector3, r: float) -> Enemy:
	var best: Enemy = null
	for e in b.enemies_near(pos, r):
		if e.is_valid_target() and (best == null or e.hp > best.hp):
			best = e
	return best


static func _nearest(b: Node, pos: Vector3, r: float) -> Enemy:
	var best: Enemy = null
	var bd := INF
	for e in b.enemies_near(pos, r):
		var d: float = e.global_position.distance_to(pos)
		if e.is_valid_target() and d < bd:
			bd = d
			best = e
	return best


static func _orb_for(elem: String) -> String:
	match elem:
		"fire": return "fireball"
		"ice": return "frost_bolt"
		"poison": return "poison_bolt"
		"shadow": return "shadow_orb"
		"earth": return "bomb"
		"lightning": return "lightning_orb"
	return "arcane_orb"
