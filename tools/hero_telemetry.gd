extends Node
## Debug: AUTO-hero telemetry — deaths, ability casts, time spent idle,
## retreating, fighting and walking; printed as HERO_STATS at the end.

var stats := {"deaths": 0, "idle": 0.0, "fight": 0.0, "move": 0.0, "retreat": 0.0, "dead": 0.0, "casts": {}, "blocked_max": 0, "hp_low": 0.0}
var _prev_cd: Array = []
var _was_alive := true


func _ready() -> void:
	while not (get_tree().current_scene is BattleController):
		await get_tree().process_frame
	var b = get_tree().current_scene
	Events.enemy_leaked.connect(func(e, n):
		var h: Hero = b.hero
		var tg: String = h.target.unit_id if h.target != null and is_instance_valid(h.target) else "-"
		print("LEAK t=%d %s r=%d hp=%.2f | hero=(%d,%d) hp=%.2f tgt=%s moving=%s energy=%d" % [b.elapsed, e.unit_id, e.route_idx, e.hp_ratio(), h.global_position.x, h.global_position.z, h.hp_ratio(), tg, h.moving, h.energy]))
	b.tree_exiting.connect(_dump)
	get_tree().root.tree_exiting.connect(_dump)


func _physics_process(delta: float) -> void:
	var b = get_tree().current_scene
	if not (b is BattleController) or b.hero == null or b.ended:
		return
	var h: Hero = b.hero
	if _prev_cd.is_empty():
		_prev_cd = h.cooldowns.duplicate()
	for i in h.cooldowns.size():
		if h.cooldowns[i] > _prev_cd[i] + 0.5:
			var id: String = h.ability_ids[i]
			stats.casts[id] = int(stats.casts.get(id, 0)) + 1
	_prev_cd = h.cooldowns.duplicate()
	if not h.alive:
		stats.dead += delta
		if _was_alive:
			stats.deaths += 1
			print("HERO_DIED t=%d" % b.elapsed)
		_was_alive = false
		return
	_was_alive = true
	if h.hp_ratio() < 0.35:
		stats.hp_low += delta
	if h.brain.retreating:
		stats.retreat += delta
	elif h.moving:
		stats.move += delta
	elif h.target != null:
		stats.fight += delta
	else:
		stats.idle += delta
	var n := 0
	for e in b.enemies:
		if is_instance_valid(e) and e.blocker == h:
			n += 1
	stats.blocked_max = maxi(stats.blocked_max, n)


func _dump() -> void:
	if stats.has("dumped"):
		return
	stats["dumped"] = true
	for k in ["idle", "fight", "move", "retreat", "dead", "hp_low"]:
		stats[k] = int(stats[k])
	print("HERO_STATS ", JSON.stringify(stats))
