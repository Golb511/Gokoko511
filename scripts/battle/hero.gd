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
	l.light_color = ModelLib._col(hdef.model.get("emission", [1, 0.5, 0.2]))
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.position = Vector3(0, 1.6, 0)
	add_child(l)
	_gear_aura()


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
	var ab: Dictionary = DB.abilities[ability_ids[i]]
	return cooldowns[i] <= 0.0 and energy >= float(ab.energy) and not is_disabled()


func cast(i: int, point: Vector3, target_enemy: Enemy = null) -> bool:
	if not can_cast(i):
		return false
	var id: String = ability_ids[i]
	var ab: Dictionary = DB.abilities[id]
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
	return true


func ability_def(i: int) -> Dictionary:
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
	attack_cd -= delta
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
	if melee:
		var dealt: float = tgt.take_damage(dmg, elem, self, is_crit)
		if splash > 0.0:
			for e in battle.enemies_near(tgt.global_position, splash):
				if e != tgt and not e.flying:
					dealt += e.take_damage(dmg * 0.5, elem, self)
		heal(dealt * lifesteal)
		VFX.hit(battle.fx_root, tgt.global_position + Vector3(0, 1.0, 0), elem)
		Sfx.play("slash", -8.0)
		if int(hdef.attack.get("chain", 0)) > 0:
			AbilityExecutor.chain_lightning(self, tgt, dmg * 0.5, int(hdef.attack.chain), "lightning")
	else:
		var st: Dictionary = hdef.attack.get("status", {})
		var status := {}
		if not st.is_empty():
			status = {"id": st.id, "duration": float(st.duration), "power": float(st.power) * (stats.damage if st.id in ["burn", "poison"] else 1.0)}
		battle.spawn_projectile(global_position + Vector3(0, 1.4, 0), tgt, {"type": hdef.attack.get("projectile", "arrow"), "damage": dmg, "dmg_type": elem, "speed": 22.0, "team": Team.PLAYER, "source": self, "status": status, "splash": splash, "crit": is_crit, "lifesteal": lifesteal, "pierce": int(hdef.attack.get("pierce", 0))})
		Sfx.play("arrow" if elem == "physical" else "magic", -10.0)
	energy = minf(max_energy, energy + 1.5)


func take_damage(amount: float, dmg_type: String = "physical", source: Node = null, crit := false) -> float:
	var d := super.take_damage(amount, dmg_type, source, crit)
	if alive and model and randf() < 0.15 and not model.is_locked():
		model.play_action("hit", 1.4, false)
	return d


func _on_death() -> void:
	_release_target()
	respawn_timer = float(DB.cfg.hero_respawn)
	moving = false
	if model:
		model.play_action("death", 1.0)
	Events.notify(tr("battle.hero_dead"), Color(1, 0.4, 0.3))
	selection_ring.visible = false


func _respawn() -> void:
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
