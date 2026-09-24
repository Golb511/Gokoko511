class_name Boss
extends Enemy
## Multi-phase boss: area slams, summons, tower smashing, fire rain, enrage.
## Every telegraphed attack gives the player a readable warning window.

var phases: Array = []
var phase := 0
var _invuln := 0.0
var skill_list: Array = []
var boss_cd := {"ground_slam": 5.0, "summon_horde": 9.0, "tower_smash": 8.0, "fire_rain": 10.0}
const COOLDOWNS := {"ground_slam": 7.0, "summon_horde": 18.0, "tower_smash": 13.0, "fire_rain": 11.0}


func setup(b: Node, enemy_id: String, r: PathRoute, ridx: int, hp_mult: float, start_progress := 0.0) -> void:
	super.setup(b, enemy_id, r, ridx, hp_mult, start_progress)
	phases = def.get("phases", [])
	skill_list = phases[0].skills if not phases.is_empty() else []
	lateral = 0.0
	radius = 1.4
	hp_bar.visible = false
	hp_bar.set_meta("always", false)
	var light := OmniLight3D.new()
	light.light_color = ModelLib._col(def.model.get("emission", [1, 0.3, 0.05]))
	light.light_energy = 2.5
	light.omni_range = 8.0
	light.position = Vector3(0, 3.5, 0)
	add_child(light)
	VFX.particles(self, global_position + Vector3(0, 2, 0), {"amount": 30, "lifetime": 1.4, "one_shot": false, "local": true, "speed": 0.8, "size": 0.35, "color": light.light_color, "radius": 1.2, "gravity": Vector3(0, 1.5, 0)})


func take_damage(amount: float, dmg_type: String = "physical", source: Node = null, crit := false) -> float:
	if _invuln > 0.0:
		return 0.0
	var d := super.take_damage(amount, dmg_type, source, crit)
	_check_phase()
	return d


func _check_phase() -> void:
	if not alive:
		return
	var next := phase + 1
	if next < phases.size() and hp_ratio() <= float(phases[next].hp):
		phase = next
		var ph: Dictionary = phases[phase]
		skill_list = ph.skills
		base_speed = float(def.speed) * float(ph.get("speed_mult", 1.0))
		if ph.get("enrage", false):
			attack_rate = float(def.attack_rate) * 1.4
			model.set_param("glow_strength", float(def.model.get("emission_strength", 3.0)) * 1.8)
		_invuln = 1.2
		_busy = 1.2
		blocker = null
		model.play_action("cheer", 1.0)
		VFX.nova(battle.fx_root, global_position, 7.0, "fire" if ph.get("enrage", false) else "shadow")
		Sfx.play("boss", 0.0, 0.0)
		battle.shake(0.6, 0.5)
		Events.boss_phase_changed.emit(self, phase)
		# Knock back and stun nearby defenders on phase transition.
		for a in battle.allies_near(global_position, 5.0):
			a.apply_status("stun", 1.0, 1.0)


func _physics_process(delta: float) -> void:
	_invuln -= delta
	for k in boss_cd:
		boss_cd[k] = float(boss_cd[k]) - delta
	super._physics_process(delta)


func think() -> void:
	super.think()
	if not alive or _busy > 0.0 or is_disabled():
		return
	var mult := 1.0 if phase < 2 else 0.75
	for s in skill_list:
		if float(boss_cd.get(s, 0.0)) > 0.0:
			continue
		if call("_skill_" + s):
			boss_cd[s] = COOLDOWNS[s] * mult
			return


func _skill_ground_slam() -> bool:
	var targets: Array = battle.allies_near(global_position, 5.0)
	if targets.is_empty():
		return false
	var r := 4.5
	var tele := VFX.area_disc(battle.fx_root, global_position, r, Color(1, 0.25, 0.05))
	_busy = 1.3
	model.play_action("special", 0.8)
	get_tree().create_timer(0.9, false).timeout.connect(func():
		if is_instance_valid(tele): tele.queue_free()
		if not alive: return
		for a in battle.allies_near(global_position, r):
			a.take_damage(roll_damage() * 1.6, "physical", self)
			a.apply_status("stun", 1.4, 1.0)
		VFX.explosion(battle.fx_root, global_position, r, "earth")
		battle.shake(0.4, 0.35)
		Sfx.play("explosion", 0.0))
	return true


func _skill_summon_horde() -> bool:
	var gi := DB.stage_order.find(battle.stage_id)
	var n := 2 + phase * 2 + mini(3, gi / 4)
	_busy = 1.0
	model.play_action("summon", 1.0)
	VFX.shadow_burst(battle.fx_root, global_position, 3.0)
	for i in n:
		var kind := "skeleton_warrior" if (gi >= 3 and i % 3 == 2) else "skeleton_minion"
		battle.spawn_enemy(kind, route_idx, maxf(0.0, progress - 2.0 - i * 0.5), true)
	return true


func _skill_tower_smash() -> bool:
	var towers: Array = battle.towers_near(global_position, 11.0)
	var best: Node = null
	for t in towers:
		if not t.is_disabled() and (best == null or t.level > best.level):
			best = t
	if best == null:
		return false
	var tref := weakref(best)
	var tower = best
	_busy = 1.3
	model.face_instant(tower.global_position)
	model.play_action("attack", 0.8)
	var tele := VFX.area_disc(battle.fx_root, tower.global_position, 2.2, Color(1, 0.1, 0.05))
	get_tree().create_timer(1.0, false).timeout.connect(func():
		if is_instance_valid(tele): tele.queue_free()
		tower = tref.get_ref()
		if not alive or tower == null: return
		VFX.lightning(battle.fx_root, global_position + Vector3(0, 4, 0), tower.global_position + Vector3(0, 2, 0), Color(1, 0.35, 0.1), 0.25, 0.3)
		VFX.explosion(battle.fx_root, tower.global_position, 2.5, "fire")
		tower.disable(7.0 + phase)
		battle.shake(0.35, 0.3)
		Sfx.play("explosion", 0.0)
		Events.notify(tr("battle.tower_disabled"), Color(1, 0.4, 0.2)))
	return true


func _skill_fire_rain() -> bool:
	var spots: Array[Vector3] = []
	for t in battle.towers_near(global_position, 14.0):
		spots.append(t.global_position)
	for a in battle.allies_near(global_position, 14.0):
		spots.append(a.global_position)
	if spots.is_empty():
		return false
	spots.shuffle()
	spots = spots.slice(0, 3 + phase)
	_busy = 1.0
	model.play_action("cast", 1.0)
	for p in spots:
		var pos: Vector3 = p + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
		var tele := VFX.area_disc(battle.fx_root, pos, 2.2, Color(1, 0.35, 0.05))
		get_tree().create_timer(1.3 + randf() * 0.4, false).timeout.connect(func():
			if is_instance_valid(tele): tele.queue_free()
			if not is_instance_valid(battle): return
			VFX.explosion(battle.fx_root, pos, 2.2, "fire")
			Sfx.play("explosion", -6.0)
			for a in battle.allies_near(pos, 2.2):
				a.take_damage(roll_damage() * 0.9, "fire", self)
			for t in battle.towers_near(pos, 2.2):
				t.disable(2.5))
	return true


func _on_death() -> void:
	battle.shake(0.8, 0.8)
	VFX.explosion(battle.fx_root, global_position, 6.0, "fire")
	Sfx.play("boss", 0.0, 0.0)
	super._on_death()
