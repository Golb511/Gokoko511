class_name WaveManager
extends Node
## Wave scheduling. Uses hand-authored waves when available (r1s1) and
## otherwise generates waves from the region's enemy pool and difficulty.

signal wave_started(index: int)
signal all_waves_spawned

const BETWEEN_WAVES := 22.0

var battle: Node
var waves: Array = []
var current := -1
var countdown := -1.0          # time until next wave auto-starts (-1 = waiting for player)
var spawning := false
var hp_mult := 1.0
var start_gold := 320
var _queue: Array = []         # [{t, enemy, path}]
var _wave_time := 0.0
var finished_spawning := false
var endless := false
var _stage_info: Dictionary = {}


func setup(b: Node, stage_id: String) -> void:
	battle = b
	var info := DB.stage_info(stage_id)
	_stage_info = info
	var gi := DB.stage_order.find(stage_id)
	hp_mult = 1.0 + gi * 0.1
	if stage_id == DB.ENDLESS:
		endless = true
		hp_mult = 1.0
		start_gold = 700
		waves = [_endless_wave(0)]
		return
	if DB.explicit_waves.has(stage_id):
		var ex: Dictionary = DB.explicit_waves[stage_id]
		waves = ex.waves
		start_gold = int(ex.get("start_gold", 320))
	else:
		waves = _generate(info, gi)
		start_gold = 360 + gi * 35


## Budgeted wave generator. Each wave gets an HP budget that follows the
## hand-tuned curve of stage 1-1 and grows per stage; groups are drawn from the
## region pool. New enemy types are introduced in small numbers, flyers are
## capped so ground-only defences are never hopeless, and boss stages end with
## the region boss.
func _generate(info: Dictionary, gi: int) -> Array:
	var region: Dictionary = info.region
	var stage: Dictionary = info.data
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(stage.id)
	var pool: Array = region.pool.duplicate()
	var basic: Array = pool.filter(func(id): return not DB.enemy(id).get("flying", false) and float(DB.enemy(id).hp) <= 160.0)
	if basic.is_empty():
		basic = ["skeleton_minion", "cultist"]
	var paths: int = DB.stage_map(stage.id).paths.filter(func(p): return not p.get("air", false)).size()
	var is_boss: bool = stage.get("boss", false)
	var n := 5 + mini(2, info.region_idx / 2) + (1 if is_boss else 0)
	var mult := 1.0 + gi * 0.1
	var base := 520.0 + 70.0 * gi
	var out: Array = []
	for w in n:
		var budget := base * (1.0 + 0.7 * w)
		var groups: Array = []
		var delay := 0.0
		var flyer_budget := budget * 0.3
		# Introduce the new enemy type gently in waves 2-3.
		if stage.has("new") and w in [1, 2]:
			var nid: String = stage.new[0]
			var ne := DB.enemy(nid)
			var cnt := clampi(int(budget * 0.35 / (float(ne.hp) * mult)), 2, 6)
			groups.append({"enemy": nid, "count": cnt, "interval": 2.2, "delay": 4.0, "path": w % paths})
			budget -= cnt * float(ne.hp) * mult
		var kinds := 1 if w == 0 else rng.randi_range(2, 3)
		for k in kinds:
			var id: String = basic[rng.randi_range(0, basic.size() - 1)] if (k == 0 or w == 0) else pool[rng.randi_range(0, pool.size() - 1)]
			var e := DB.enemy(id)
			var share := budget / (kinds - k)
			if e.get("flying", false):
				share = minf(share, flyer_budget)
			var unit_hp := float(e.hp) * mult
			var count := clampi(int(share / unit_hp), 1, 20)
			budget -= count * unit_hp
			groups.append({"enemy": id, "count": count, "interval": clampf(0.45 + unit_hp / 400.0, 0.6, 3.0), "delay": delay, "path": (w + k) % paths})
			delay += rng.randf_range(4.0, 8.0)
		if w == n - 1 and is_boss:
			groups.append({"enemy": region.boss, "count": 1, "interval": 1.0, "delay": delay + 8.0, "path": 0, "hp": 0.8})
		out.append({"groups": groups})
	return out


## Endless: waves are generated on demand; HP and count keep climbing and a
## random boss appears every 10th wave.
func _endless_wave(w: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("endless") + w * 7919
	var pool: Array = DB.enemies.keys()
	pool = pool.filter(func(id): return w >= 6 or float(DB.enemy(id).hp) <= 300.0)
	var groups: Array = []
	var budget := 700.0 * pow(1.16, w)
	var kinds := mini(4, 1 + w / 3)
	var delay := 0.0
	for k in kinds:
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		var e := DB.enemy(id)
		var share := budget / kinds
		if e.get("flying", false):
			share *= 0.5
		var cnt := clampi(int(share / float(e.hp)), 2, 28)
		groups.append({"enemy": id, "count": cnt, "interval": clampf(0.4 + float(e.hp) / 500.0, 0.5, 2.5), "delay": delay, "path": 0})
		delay += rng.randf_range(3.0, 6.0)
	if w > 0 and (w + 1) % 10 == 0:
		var bosses: Array = DB.bosses.keys()
		groups.append({"enemy": bosses[(w / 10) % bosses.size()], "count": 1, "interval": 1.0, "delay": delay + 5.0, "path": 0, "hp": 0.5 + w * 0.03})
	return {"groups": groups}


func total() -> int:
	return 9999 if endless else waves.size()


func is_waiting_first() -> bool:
	return current < 0


func start_next_wave(early := false) -> void:
	if endless and current + 1 >= waves.size():
		waves.append(_endless_wave(current + 1))
	if current + 1 >= waves.size():
		return
	if early and countdown > 0.0 and current >= 0:
		var bonus := int(countdown * float(DB.cfg.early_wave_bonus_per_sec))
		if bonus > 0:
			battle.add_gold(bonus)
			Events.notify("%s +%d" % [tr("battle.wave_bonus"), bonus], Color(1, 0.85, 0.3))
	current += 1
	countdown = -1.0
	_wave_time = 0.0
	spawning = true
	var w: Dictionary = waves[current]
	for g in w.groups:
		for i in int(g.count):
			_queue.append({"t": float(g.get("delay", 0.0)) + i * float(g.interval), "enemy": g.enemy, "path": int(g.get("path", 0)), "hp": float(g.get("hp", 1.0))})
	_queue.sort_custom(func(a, b): return a.t < b.t)
	wave_started.emit(current)
	Events.wave_started.emit(current, waves.size())
	for g in w.groups:
		if DB.is_boss(g.enemy):
			get_tree().create_timer(float(g.get("delay", 0.0)) * 0.6, false).timeout.connect(func(): Events.notify(tr("battle.boss_incoming"), Color(1, 0.25, 0.15)))


func _physics_process(delta: float) -> void:
	if spawning:
		_wave_time += delta
		while not _queue.is_empty() and float(_queue[0].t) <= _wave_time:
			var q: Dictionary = _queue.pop_front()
			var pidx := mini(int(q.path), battle.routes.size() - 1)
			var wave_hp := hp_mult * (1.0 + current * (0.09 if endless else 0.06)) * float(q.get("hp", 1.0))
			battle.spawn_enemy(q.enemy, pidx, 0.0, false, wave_hp)
		if _queue.is_empty():
			spawning = false
			if endless or current + 1 < waves.size():
				countdown = BETWEEN_WAVES
			else:
				finished_spawning = true
				all_waves_spawned.emit()
	elif countdown > 0.0:
		countdown -= delta
		if countdown <= 0.0:
			start_next_wave(false)


func can_call_early() -> bool:
	return countdown > 0.0 or (current < 0)
