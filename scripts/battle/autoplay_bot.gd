class_name AutoplayBot
extends Node
## Test harness: plays a battle automatically (builds and upgrades towers,
## hero on AUTO, uses global powers) so balance can be verified headless.
## Enabled with the user arg --autoplay.

var battle: BattleController
var _t := 0.0


func setup(b: BattleController) -> void:
	battle = b
	battle.hero.auto_mode = true
	Engine.time_scale = 3.0
	Events.wave_started.connect(func(i, _n): _log("wave %d start" % (i + 1)))
	Events.enemy_leaked.connect(func(e, n): _log("leak %s -%d" % [e.unit_id, n]))
	Events.boss_phase_changed.connect(func(_b, p): _log("boss phase %d" % p))


func _log(msg: String) -> void:
	var tw := {}
	for t in battle.towers:
		tw[t.tower_id + str(t.level)] = tw.get(t.tower_id + str(t.level), 0) + 1
	print("[%.0fs] %s | lives=%d gold=%d towers=%s hero_hp=%d/%d lvl=%d" % [battle.elapsed, msg, battle.lives, battle.gold, tw, battle.hero.hp, battle.hero.max_hp, Game.hero_state(battle.hero.hero_id).level])


func _physics_process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or battle.ended:
		return
	_t = 1.0
	if battle.waves.is_waiting_first():
		_build()
		battle.waves.start_next_wave()
		return
	_build()
	_upgrade()
	_globals()
	if battle.waves.countdown > 0.0 and battle.enemies.size() < 3:
		battle.waves.start_next_wave(true)


func _slot_value(s: BuildSlot) -> float:
	# Prefer slots covering the most road.
	var v := 0.0
	for r in battle.routes:
		for i in range(0, r.points.size(), 4):
			if r.points[i].distance_to(s.global_position) < 9.0:
				v += 1.0
	return v


func _build() -> void:
	var avail := battle.available_towers()
	var free := battle.slots.filter(func(s): return s.is_free())
	free.sort_custom(func(a, b): return _slot_value(a) > _slot_value(b))
	if battle.towers.size() >= 7 and battle.towers.any(func(t): return t.can_upgrade() or t.needs_branch_choice()):
		return
	for s in free:
		var id: String = avail[battle.towers.size() % avail.size()]
		var cost := int(DB.towers[id].levels[0].cost)
		if battle.gold >= cost + 20:
			battle.build_tower(s, id)
		else:
			return


func _upgrade() -> void:
	var ts := battle.towers.duplicate()
	ts.sort_custom(func(a, b): return a.level < b.level)
	for t in ts:
		if t.needs_branch_choice():
			var c: int = t.upgrade_cost(0)
			if battle.gold >= c + 40:
				battle.upgrade_tower(t, randi() % 2)
		elif t.can_upgrade() and battle.gold >= t.upgrade_cost() + 40:
			battle.upgrade_tower(t)


func _globals() -> void:
	var best: Enemy = null
	var best_n := 0
	for e in battle.enemies:
		var n := battle.enemies_near(e.global_position, 4.0).size()
		if n > best_n or e is Boss:
			best_n = n
			best = e
	if best == null:
		return
	if best_n >= 5 or best is Boss:
		if battle.globals.can_use("meteor"):
			battle.globals.use("meteor", best.global_position)
		elif battle.globals.can_use("freeze"):
			battle.globals.use("freeze", best.global_position)
	if best is Boss and battle.globals.can_use("tower_buff"):
		battle.globals.use("tower_buff", Vector3.ZERO)
