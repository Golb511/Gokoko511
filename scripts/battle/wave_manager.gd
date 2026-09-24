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


func setup(b: Node, stage_id: String) -> void:
	battle = b
	var info := DB.stage_info(stage_id)
	var gi := DB.stage_order.find(stage_id)
	hp_mult = 1.0 + gi * 0.2
	if DB.explicit_waves.has(stage_id):
		var ex: Dictionary = DB.explicit_waves[stage_id]
		waves = ex.waves
		start_gold = int(ex.get("start_gold", 320))
	else:
		waves = _generate(info, gi)
		start_gold = 320 + gi * 30


func _generate(info: Dictionary, gi: int) -> Array:
	var region: Dictionary = info.region
	var stage: Dictionary = info.data
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(stage.id)
	var pool: Array = region.pool.duplicate()
	var paths: int = DB.layouts[stage.layout].paths.size()
	var n := 5 + mini(3, info.region_idx) + (1 if stage.get("boss", false) else 0)
	var out: Array = []
	for w in n:
		var budget := 10.0 + w * 5.5 + gi * 2.5
		var groups: Array = []
		var delay := 0.0
		var kinds := 1 + mini(2, w / 2)
		for k in kinds:
			var id: String = pool[rng.randi_range(0, pool.size() - 1)]
			if w <= 1 and stage.has("new") and k == 0:
				id = stage.new[0]
			var e := DB.enemy(id)
			var cost := maxf(1.0, float(e.hp) / 80.0)
			var count := clampi(int(budget / kinds / cost), 1, 24)
			groups.append({"enemy": id, "count": count, "interval": clampf(0.5 + cost * 0.35, 0.6, 3.0), "delay": delay, "path": (w + k) % paths})
			delay += rng.randf_range(3.0, 7.0)
		if w == n - 1 and stage.get("boss", false):
			groups.append({"enemy": region.boss, "count": 1, "interval": 1.0, "delay": delay + 8.0, "path": 0})
		out.append({"groups": groups})
	return out


func total() -> int:
	return waves.size()


func is_waiting_first() -> bool:
	return current < 0


func start_next_wave(early := false) -> void:
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
			var wave_hp := hp_mult * (1.0 + current * 0.06) * float(q.get("hp", 1.0))
			battle.spawn_enemy(q.enemy, pidx, 0.0, false, wave_hp)
		if _queue.is_empty():
			spawning = false
			if current + 1 < waves.size():
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
