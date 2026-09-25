class_name Hero
extends Unit
## Player hero: click/tap-to-move, auto-attacks, four abilities + ultimate,
## energy, respawn, and an optional AUTO bot brain (HeroBrain).

signal energy_changed(value: float, max_value: float)
signal respawn_tick(seconds: float)
signal commanded(point: Vector3)

var hero_id := "hell_knight"
var hdef: Dictionary
var stats: Dictionary
var move_target := Vector3.ZERO
var guard_pos := Vector3.ZERO
var moving := false
var target: Enemy = null
var energy := 0.0
var max_energy := 100.0
var ability_ids: Array = []        # 4 abilities + ultimate at index 4
var cooldowns: Array[float] = [0, 0, 0, 0, 0]
var respawn_timer := 0.0
var spawn_pos := Vector3.ZERO
var auto_mode := false
var brain: HeroBrain
var crit := 0.1
var crit_dmg := 1.5
var lifesteal := 0.0
var cdr := 0.0
var energy_regen := 2.0
var melee := true
var splash := 0.0
var _think := 0.0
var _busy := 0.0
var selection_ring: MeshInstance3D
var _ability_bonus := 1.0
var move_marker: Node3D
# Hero Mastery (HeroTree)
var mfx: Dictionary = {}
var _abilities: Array = []         # ability data with mastery modifiers, per slot
var _aura_t := 0.0
var _special_t := 0.0
var _basic_count := 0
var _revive_used := false
var _rampage := 0
var _rampage_t := 0.0
var _avatar_t := 0.0
var _avatar: Dictionary = {}
var _avatar_fx: Node3D
var _raised: Array = []
var _last_ult_point := Vector3.ZERO
var mastery_procs := 0              # telemetry: specials / on-kill effects fired
var mastery_log := {}               # telemetry: fired count per mastery effect


func setup(b: Node, id: String, pos: Vector3) -> void:
	_init_unit(b, Team.PLAYER)
	hero_id = id
	unit_id = id
	hdef = DB.heroes[id]
	stats = Game.hero_stats(id)
	max_hp = stats.health
	hp = max_hp
	armor = stats.defense / (stats.defense + 100.0)
	mres = armor * 0.8
	base_speed = stats.move_speed
	damage_min = stats.damage * 0.9
	damage_max = stats.damage * 1.1
	attack_rate = stats.attack_speed
	attack_range = stats.range
	crit = stats.crit
	crit_dmg = stats.crit_dmg
	lifesteal = stats.lifesteal
	cdr = stats.cdr
	energy_regen = stats.energy_regen
	max_energy = stats.energy
	energy = max_energy * 0.5
	melee = hdef.attack.type == "melee"
	splash = float(hdef.attack.get("splash", 0.0))
	ability_ids = hdef.abilities.duplicate()
	ability_ids.append(hdef.ultimate)
	mfx = HeroTree.effects(id) if not HeroTree.owned(id).is_empty() else {}
	splash += float(mfx.get("splash", 0.0))
	_abilities.clear()
	for i in ability_ids.size():
		_abilities.append(HeroTree.ability_def(id, i, DB.abilities[ability_ids[i]]))
	var mdef: Dictionary = hdef.model.duplicate()
	mdef["scale"] = float(mdef.get("scale", 1.0)) * 1.18
	setup_model(mdef)
	hp_bar.set_meta("always", true)
	hp_bar.set_fill(1.0)
	spawn_pos = pos
	guard_pos = pos
	global_position = pos
	_make_selection_ring()
	brain = HeroBrain.new()
	brain.hero = self
	# Aura light so the hero reads clearly in dark scenes.
	var l := OmniLight3D.new()
	l.light_volumetric_fog_energy = 0.2
	l.light_color = ModelLib._col(hdef.model.get("emission", [1, 0.5, 0.2]))
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.position = Vector3(0, 1.6, 0)
	add_child(l)
	_gear_aura()
	_mastery_look()


## Heroes wearing epic-or-better gear radiate an aura of the best rarity colour.
func _gear_aura() -> void:
	var best := -1
	for slot in DB.items.slots:
		var it := Game.equipped_item(hero_id, slot)
		if not it.is_empty():
			best = maxi(best, int(it.get("rarity", 0)))
	if best < 2:
		return
	var c := DB.rarity_color(best)
	VFX.particles(self, global_position + Vector3(0, 0.3, 0), {"amount": 10 + best * 6, "lifetime": 1.4, "one_shot": false, "local": true,
		"speed": 0.4, "size": 0.14, "color": c, "radius": 0.7, "gravity": Vector3(0, 1.4, 0), "explosiveness": 0.0})
	if model:
		model.set_param("rim_strength", 0.6 + 0.25 * best)


func _make_selection_ring() -> void:
	selection_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	selection_ring.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.8, 0.3)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.7, 0.2)
	selection_ring.material_override = m
	selection_ring.scale = Vector3(0.9, 0.05, 0.9)
	selection_ring.position.y = 0.05
	selection_ring.visible = false
	selection_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(selection_ring)


func set_selected(v: bool) -> void:
	selection_ring.visible = v


# ---------------------------------------------------------------- commands
func command_move(p: Vector3) -> void:
	if not alive:
		return
	move_target = battle.clamp_to_bounds(p)
	guard_pos = move_target
	moving = true
	_release_target()
	VFX.ground_ring(battle.fx_root, move_target, 0.9, Color(1, 0.8, 0.3), 0.5)
	commanded.emit(move_target)


func can_cast(i: int) -> bool:
	if not alive or i >= ability_ids.size():
		return false
	var ab: Dictionary = ability_def(i)
	return cooldowns[i] <= 0.0 and energy >= float(ab.energy) and not is_disabled()


func cast(i: int, point: Vector3, target_enemy: Enemy = null) -> bool:
	if not can_cast(i):
		return false
	var id: String = ability_ids[i]
	var ab: Dictionary = ability_def(i)
	var rank := Game.skill_rank(hero_id, "ab%d" % i) if i < 4 else 0
	_ability_bonus = 1.0 + 0.12 * rank
	var ok := AbilityExecutor.execute(self, id, ab, point, target_enemy)
	_ability_bonus = 1.0
	if not ok:
		return false
	energy -= float(ab.energy)
	cooldowns[i] = float(ab.cooldown) * (1.0 - cdr) * (1.0 - Game.ABILITY_CDR_PER_RANK * rank)
	energy_changed.emit(energy, max_energy)
	Events.track("abilities_used")
	if i == 4:
		_last_ult_point = point
		_on_ultimate(ab, point, target_enemy)
	return true


func ability_def(i: int) -> Dictionary:
	if i < _abilities.size():
		return _abilities[i]
	return DB.abilities[ability_ids[i]]


func damage_value(mult: float, ultimate := false) -> float:
	return stats.damage * mult * damage_mult() * (stats.ult_mult if ultimate else 1.0) * _ability_bonus


func dmg_type() -> String:
	return hdef.attack.get("dmg_type", "physical")


# ---------------------------------------------------------------- loop
func _physics_process(delta: float) -> void:
	for i in cooldowns.size():
		cooldowns[i] = maxf(0.0, cooldowns[i] - delta)
	if not alive:
		respawn_timer -= delta
		respawn_tick.emit(respawn_timer)
		if respawn_timer <= 0.0:
			_respawn()
		return
	tick_statuses(delta)
	if not alive:
		return
	energy = minf(max_energy, energy + energy_regen * delta)
	energy_changed.emit(energy, max_energy)
	attack_cd -= delta * (1.0 + _extra_attack_speed())
	if not mfx.is_empty():
		_mastery_tick(delta)
	_busy -= delta
	if auto_mode:
		brain.update(delta)
	if is_disabled() or _busy > 0.0:
		return
	if moving:
		_move(delta)
		if not melee:
			_kite_shot()
		return
	_think -= delta
	if _think <= 0.0:
		_think = 0.2
		_acquire_target()
	if target != null:
		_combat(delta)
	else:
		var d := Vector2(guard_pos.x - global_position.x, guard_pos.z - global_position.z).length()
		if d > 0.3:
			_step_towards(guard_pos, delta)
		elif model and not model.is_locked():
			model.play_loop("idle")
		if hp < max_hp:
			heal(max_hp * 0.01 * delta)


func _move(delta: float) -> void:
	var d := Vector2(move_target.x - global_position.x, move_target.z - global_position.z).length()
	if d < 0.2 or is_immobile():
		moving = false
		return
	_step_towards(move_target, delta)


## Ranged heroes keep firing at anything in range while repositioning.
func _kite_shot() -> void:
	if attack_cd > 0.0:
		return
	var best: Enemy = null
	var bd := attack_range + 0.5
	for e in battle.enemies_near(global_position, attack_range + 0.5):
		var d: float = e.global_position.distance_to(global_position)
		if e.is_valid_target() and d < bd:
			bd = d
			best = e
	if best == null:
		return
	attack_cd = 1.0 / maxf(0.1, attack_rate)
	_deal_basic(weakref(best))


func _step_towards(p: Vector3, delta: float) -> void:
	var dir := p - global_position
	dir.y = 0.0
	var step := minf(dir.length(), base_speed * speed_mult() * delta)
	if step <= 0.0001:
		return
	global_position += dir.normalized() * step
	global_position.y = 0.0
	if model:
		model.face_towards(p, delta, 14.0)
		model.play_loop("run", clampf(base_speed / 4.5, 0.8, 1.4))


func _acquire_target() -> void:
	if target != null and (not is_instance_valid(target) or not target.is_valid_target()):
		_release_target()
	var leash := 4.0 if melee else attack_range
	if target != null and target.global_position.distance_to(guard_pos) > leash + 3.0:
		_release_target()
	if target != null:
		return
	var best: Enemy = null
	var best_d := INF
	for e in battle.enemies_near(global_position, leash + 1.0):
		if not e.is_valid_target() or (melee and e.flying):
			continue
		var d: float = e.global_position.distance_to(global_position)
		if e.blocker != null and e.blocker != self:
			d += 2.5
		if d < best_d:
			best_d = d
			best = e
	target = best


func _release_target() -> void:
	if target != null and is_instance_valid(target) and target.blocker == self:
		target.blocker = null
	target = null


func on_target_lost(_e: Node) -> void:
	target = null


func _combat(delta: float) -> void:
	var tp := target.global_position
	var d := Vector2(tp.x - global_position.x, tp.z - global_position.z).length()
	var reach := attack_range + target.radius
	if d > reach:
		_step_towards(tp, delta)
		return
	if melee and not target.flying and (target.blocker == null or not is_instance_valid(target.blocker) or not target.blocker.alive):
		target.blocker = self
	if model:
		model.face_towards(tp, delta, 14.0)
	if attack_cd <= 0.0:
		attack_cd = 1.0 / maxf(0.1, attack_rate)
		_busy = minf(0.45, attack_cd * 0.8)
		if model:
			model.play_action("attack", clampf(attack_rate * 1.2, 0.9, 1.8))
		get_tree().create_timer(0.28, false).timeout.connect(_deal_basic.bind(weakref(target)))
	elif model and not model.is_locked():
		model.play_loop("idle")


func _deal_basic(ref: WeakRef) -> void:
	var tgt: Enemy = ref.get_ref()
	if not alive or tgt == null or not tgt.alive:
		return
	var is_crit := randf() < crit
	var dmg := roll_damage() * (crit_dmg if is_crit else 1.0)
	var elem := dmg_type()
	if not mfx.is_empty():
		var bs: Dictionary = mfx.get("bonus_status", {})
		if not bs.is_empty() and (tgt.statuses.has(bs.id) or tgt.statuses.has("freeze")):
			dmg *= float(bs.mult)
	if melee:
		var dealt: float = tgt.take_damage(dmg, elem, self, is_crit)
		if splash > 0.0:
			for e in battle.enemies_near(tgt.global_position, splash):
				if e != tgt and not e.flying:
					dealt += e.take_damage(dmg * 0.5, elem, self)
		heal(dealt * lifesteal)
		VFX.hit(battle.fx_root, tgt.global_position + Vector3(0, 1.0, 0), elem)
		Sfx.play("slash", -8.0)
		var chain_n := int(hdef.attack.get("chain", 0)) + int(mfx.get("chain", 0))
		if chain_n > 0:
			AbilityExecutor.chain_lightning(self, tgt, dmg * 0.5, chain_n, "lightning")
		_apply_on_hit(tgt)
		on_hit_landed(tgt)
	else:
		var st: Dictionary = hdef.attack.get("status", {})
		var status := {}
		if not st.is_empty():
			status = {"id": st.id, "duration": float(st.duration), "power": float(st.power) * (stats.damage if st.id in ["burn", "poison"] else 1.0)}
		var prm := {"type": hdef.attack.get("projectile", "arrow"), "damage": dmg, "dmg_type": elem, "speed": 22.0, "team": Team.PLAYER, "source": self, "status": status, "splash": splash, "crit": is_crit, "lifesteal": lifesteal, "pierce": int(hdef.attack.get("pierce", 0)) + int(mfx.get("pierce", 0))}
		if not mfx.is_empty():
			prm["extra_status"] = _on_hit_statuses()
			prm["execute"] = float(mfx.get("on_hit_execute", 0.0))
			if mfx.has("bonus_status"):
				prm["bonus_status"] = mfx.bonus_status
		battle.spawn_projectile(global_position + Vector3(0, 1.4, 0), tgt, prm)
		# Mastery multishot: extra projectiles at other enemies in range.
		var extra := int(mfx.get("multishot", 0))
		if extra > 0:
			var others: Array = battle.enemies_near(global_position, attack_range + 0.5).filter(func(e): return e != tgt and e.is_valid_target())
			for k in mini(extra, others.size()):
				var p2 := prm.duplicate()
				p2.damage = dmg * 0.7
				battle.spawn_projectile(global_position + Vector3(0, 1.4, 0), others[k], p2)
		Sfx.play("arrow" if elem == "physical" else "magic", -10.0)
	_count_basic(tgt)
	energy = minf(max_energy, energy + 1.5)


func take_damage(amount: float, dmg_type: String = "physical", source: Node = null, crit := false) -> float:
	if not mfx.is_empty() or _avatar_t > 0.0:
		var dr := float(mfx.get("dr", 0.0)) + (float(_avatar.get("dr", 0.0)) if _avatar_t > 0.0 else 0.0)
		amount *= 1.0 - clampf(dr, 0.0, 0.7)
		var th := float(mfx.get("thorns", 0.0))
		if th > 0.0 and source is Enemy and is_instance_valid(source) and source.alive and source.global_position.distance_to(global_position) < 3.5:
			source.take_damage(amount * th, dmg_type(), self)
	var d := super.take_damage(amount, dmg_type, source, crit)
	if alive and model and randf() < 0.15 and not model.is_locked():
		model.play_action("hit", 1.4, false)
	return d


## Mastery revive: once per battle the hero rises instead of falling.
func die(source: Node = null) -> void:
	if alive and not _revive_used and float(mfx.get("revive", 0.0)) > 0.0:
		_revive_used = true
		hp = max_hp * float(mfx.revive)
		hp_bar.set_fill(hp_ratio())
		statuses.clear()
		VFX.level_up(battle.fx_root, global_position)
		VFX.nova(battle.fx_root, global_position, 3.5, "holy")
		VFX.flash_light(battle.fx_root, global_position + Vector3(0, 2, 0), Color(1, 0.85, 0.4), 8.0, 10.0, 0.6)
		Events.notify(tr("battle.hero_mastery") + ": " + tr("hero." + hero_id), Color(1, 0.85, 0.4))
		_proc("revive")
		return
	super.die(source)


func _on_death() -> void:
	_release_target()
	respawn_timer = float(DB.cfg.hero_respawn)
	moving = false
	if model:
		model.play_action("death", 1.0)
	Events.notify(tr("battle.hero_dead"), Color(1, 0.4, 0.3))
	selection_ring.visible = false


func _respawn() -> void:
	_revive_used = false
	alive = true
	hp = max_hp
	statuses.clear()
	global_position = spawn_pos
	guard_pos = spawn_pos
	hp_bar.visible = true
	hp_bar.set_fill(1.0)
	if model:
		model.unlock()
		model.set_param("dissolve", 0.0)
		model.play_loop("idle")
	VFX.level_up(battle.fx_root, spawn_pos)


# ---------------------------------------------------------------- hero mastery
func _extra_attack_speed() -> float:
	var x := 0.0
	if _avatar_t > 0.0:
		x += float(_avatar.get("attack_speed", 0.0))
	if _rampage > 0:
		for ok in mfx.get("on_kill", []):
			if ok.type == "rampage":
				x += float(ok.attack_speed) * _rampage
	return x


func _on_hit_statuses() -> Array:
	var out: Array = []
	for oh in mfx.get("on_hit", []):
		if randf() > float(oh.get("chance", 1.0)):
			continue
		var st: Dictionary = (oh.status as Dictionary).duplicate()
		if st.id in ["burn", "poison"]:
			st.power = float(st.power) * float(stats.damage)
		out.append(st)
	return out


func _apply_on_hit(tgt: Enemy) -> void:
	if mfx.is_empty() or not is_instance_valid(tgt) or not tgt.alive:
		return
	for st in _on_hit_statuses():
		tgt.apply_status(st.id, float(st.duration), float(st.power), self)
	var ex := float(mfx.get("on_hit_execute", 0.0))
	if ex > 0.0 and tgt.alive and not tgt.tags.has("boss") and tgt.hp_ratio() <= ex:
		tgt.take_damage(tgt.hp + 1.0, "true", self, true)
		VFX.shadow_burst(battle.fx_root, tgt.global_position, 1.0)
		_proc("execute")


## Called whenever the hero's attack or ability lands (kill detection).
func on_hit_landed(e: Enemy) -> void:
	if mfx.is_empty() or not is_instance_valid(e) or e.alive or e.has_meta("mastery_killed"):
		return
	e.set_meta("mastery_killed", true)
	var pos := e.global_position
	for ok in mfx.get("on_kill", []):
		match str(ok.type):
			"explode":
				var r := float(ok.radius)
				var st: Dictionary = ok.get("status", {})
				for o in battle.enemies_near(pos, r):
					if o == e: continue
					o.take_damage(damage_value(float(ok.dmg)), str(ok.get("element", "fire")), self)
					if not st.is_empty():
						o.apply_status(st.id, float(st.duration), float(st.power) * (float(stats.damage) if st.id in ["burn", "poison"] else 1.0), self)
				VFX.explosion(battle.fx_root, pos, r, str(ok.get("element", "fire")))
				_proc("kill_explode")
			"heal":
				heal(max_hp * float(ok.get("heal", 0.05)))
				_proc("kill_heal")
			"energy":
				energy = minf(max_energy, energy + float(ok.amount))
				_proc("kill_energy")
			"reset_cd":
				var slot := int(ok.slot)
				if slot < cooldowns.size() and cooldowns[slot] > 0.0:
					cooldowns[slot] = 0.0
					VFX.ground_ring(battle.fx_root, global_position, 1.6, Color(1, 0.3, 0.2), 0.4)
					_proc("kill_reset_cd")
			"rampage":
				_rampage = mini(int(ok.max), _rampage + 1)
				_rampage_t = float(ok.duration)
				add_buff("rampage", "damage", 1.0 + float(ok.damage) * _rampage, float(ok.duration))
				_proc("kill_rampage")
			"raise":
				_raised = _raised.filter(func(u): return is_instance_valid(u) and u.alive)
				if _raised.size() < int(ok.get("max", 6)) and pos.distance_to(global_position) < 8.0 and randf() < float(ok.chance):
					var d: Dictionary = DB.allies[ok.unit]
					var sc := 1.0 + 0.06 * (int(stats.level) - 1)
					var u: AllyUnit = battle.spawn_ally(ok.unit, {"hp": float(d.hp) * sc, "dmg": [float(d.damage[0]) * sc, float(d.damage[1]) * sc], "lifetime": float(ok.duration), "engage": 5.0}, battle.clamp_to_bounds(pos))
					u.slot_offset = Vector3.ZERO
					_raised.append(u)
					VFX.shadow_burst(battle.fx_root, pos, 1.2)
					_proc("kill_raise")


func _count_basic(tgt: Enemy) -> void:
	var sp: Dictionary = mfx.get("special", {})
	if sp.is_empty() or sp.type != "every_attacks":
		return
	_basic_count += 1
	if _basic_count % maxi(1, int(sp.every)) == 0 and is_instance_valid(tgt) and tgt.alive:
		_run_synthetic(sp.ab, tgt.global_position, tgt)


func _mastery_tick(delta: float) -> void:
	var rg := float(mfx.get("regen", 0.0))
	if rg > 0.0 and hp < max_hp:
		heal(max_hp * rg * delta)
	if _rampage > 0:
		_rampage_t -= delta
		if _rampage_t <= 0.0:
			_rampage = 0
	if _avatar_t > 0.0:
		_avatar_t -= delta
		if _avatar_t <= 0.0:
			_end_avatar()
	var aura: Dictionary = mfx.get("aura", {})
	if not aura.is_empty():
		_aura_t -= delta
		if _aura_t <= 0.0:
			_aura_t = 1.0
			var r := float(aura.radius)
			var hit := 0
			var st: Dictionary = aura.get("status", {})
			for e in battle.enemies_near(global_position, r):
				if not e.is_valid_target():
					continue
				var dealt: float = e.take_damage(damage_value(float(aura.dps)), str(aura.get("element", "fire")), self)
				if aura.has("drain"):
					heal(dealt * float(aura.drain))
				if not st.is_empty():
					e.apply_status(st.id, float(st.duration), float(st.power) * (float(stats.damage) if st.id in ["burn", "poison"] else 1.0), self)
				on_hit_landed(e)
				hit += 1
			if hit > 0:
				_proc("aura")
				VFX.ground_ring(battle.fx_root, global_position, r, VFX.color(str(aura.get("element", "fire"))), 0.6)
	var sp: Dictionary = mfx.get("special", {})
	if not sp.is_empty() and sp.type == "periodic":
		_special_t -= delta
		if _special_t <= 0.0:
			var near: Array = battle.enemies_near(global_position, 9.0)
			if not near.is_empty() or str(sp.ab.type) in ["tower_buff", "summon"] and not battle.enemies.is_empty():
				_special_t = float(sp.every)
				var tgt: Enemy = near[0] if not near.is_empty() else null
				_run_synthetic(sp.ab, tgt.global_position if tgt else global_position, tgt)


func _proc(kind: String) -> void:
	mastery_procs += 1
	mastery_log[kind] = int(mastery_log.get(kind, 0)) + 1


## Mastery specials reuse the ability executor with a synthetic ability.
func _run_synthetic(ab: Dictionary, point: Vector3, tgt: Enemy) -> void:
	if not alive:
		return
	var busy_before := _busy
	AbilityExecutor.execute(self, "mastery", ab, point, tgt)
	_busy = minf(_busy, maxf(busy_before, 0.15))      # specials barely interrupt the hero
	_proc("special_" + str(ab.type))
	if ab.has("ally_heal"):
		for a in battle.allies_near(global_position, float(ab.get("radius", 8.0))):
			a.heal(a.max_hp * float(ab.ally_heal))
			VFX.heal(battle.fx_root, a.global_position)
	VFX.ground_ring(battle.fx_root, global_position, 1.8, Color(1.0, 0.8, 0.35), 0.5)


func _on_ultimate(ab: Dictionary, point: Vector3, tgt: Enemy) -> void:
	if mfx.has("on_ult"):
		_start_avatar(mfx.on_ult)
	if mfx.has("ult_echo"):
		var echo: Dictionary = ab.duplicate(true)
		echo.dmg = float(echo.get("dmg", 1.0)) * float(mfx.ult_echo.mult)
		get_tree().create_timer(float(mfx.ult_echo.delay), false).timeout.connect(func():
			if alive and battle and not battle.ended:
				VFX.flash_light(battle.fx_root, point + Vector3(0, 3, 0), Color(0.5, 0.7, 1.0), 6.0, 10.0, 0.4)
				AbilityExecutor.execute(self, "mastery_echo", echo, point, tgt if is_instance_valid(tgt) else null)
				_proc("ult_echo"))


## Capstone transformation (Avatar of Wrath / Dragonform).
func _start_avatar(cfg: Dictionary) -> void:
	var was_active := _avatar_t > 0.0
	_avatar = cfg
	_avatar_t = float(cfg.get("duration", 8.0))
	add_buff("avatar", "damage", 1.0 + float(cfg.get("damage", 0.3)), _avatar_t)
	if model and not was_active:
		var tw := model.create_tween()
		tw.tween_property(model, "scale", model.scale * float(cfg.get("scale", 1.3)), 0.35).set_trans(Tween.TRANS_BACK)
		model.set_param("rim_strength", 2.0)
	if _avatar_fx == null:
		_avatar_fx = Node3D.new()
		add_child(_avatar_fx)
		var col := ModelLib._col(hdef.model.get("emission", [1, 0.4, 0.1]))
		VFX.particles(_avatar_fx, global_position + Vector3(0, 1.0, 0), {"amount": 40, "lifetime": 0.8, "one_shot": false, "local": true,
			"speed": 1.2, "size": 0.45, "color": col, "radius": 0.8, "gravity": Vector3(0, 3.0, 0), "explosiveness": 0.0})
		var l := OmniLight3D.new()
		l.light_volumetric_fog_energy = 0.2
		l.light_color = col
		l.light_energy = 4.0
		l.omni_range = 7.0
		l.position.y = 1.5
		_avatar_fx.add_child(l)
	VFX.nova(battle.fx_root, global_position, 4.0, str(hdef.element))
	VFX.flash_light(battle.fx_root, global_position + Vector3(0, 2, 0), VFX.color(str(hdef.element)), 8.0, 12.0, 0.5)
	battle.shake(0.35, 0.4)
	_proc("avatar")


func _end_avatar() -> void:
	if model:
		var s := float(_avatar.get("scale", 1.3))
		model.create_tween().tween_property(model, "scale", model.scale / s, 0.4)
		model.set_param("rim_strength", 0.6)
	if _avatar_fx:
		_avatar_fx.queue_free()
		_avatar_fx = null


## Gold sigil at the hero's feet once a path is chosen; a floating crown for capstones.
func _mastery_look() -> void:
	var tier := HeroTree.mastery_tier(hero_id)
	if tier < 2:
		return
	var gold := Color(1.0, 0.8, 0.32)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = gold
	gm.emission_enabled = true
	gm.emission = gold
	gm.emission_energy_multiplier = 2.0 if tier == 2 else 3.2
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.95
	tm.outer_radius = 1.02
	tm.rings = 48
	tm.ring_segments = 4
	ring.mesh = tm
	ring.material_override = gm
	ring.scale = Vector3(1, 0.2, 1)
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	for k in 6:
		var rune := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 0.02, 0.07)
		rune.mesh = bm
		rune.material_override = gm
		var a := TAU * k / 6.0
		rune.position = Vector3(cos(a) * 1.0, 0, sin(a) * 1.0)
		rune.rotation.y = -a
		ring.add_child(rune)
	ring.create_tween().set_loops().tween_property(ring, "rotation:y", TAU, 8.0).from(0.0)
	if tier < 3:
		return
	var crown := Node3D.new()
	crown.position.y = bar_height + 0.55
	add_child(crown)
	for k in 5:
		var shard := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.1, 0.28, 0.1)
		shard.mesh = pm
		shard.material_override = gm
		var a := TAU * k / 5.0
		shard.position = Vector3(cos(a) * 0.32, 0, sin(a) * 0.32)
		crown.add_child(shard)
	crown.create_tween().set_loops().tween_property(crown, "rotation:y", TAU, 2.5).from(0.0)
