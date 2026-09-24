class_name AllyUnit
extends Unit
## Allied soldier / summon. Holds a rally point, intercepts and blocks ground
## enemies, returns home when idle. Flying summons hunt freely.

var home := Vector3.ZERO
var slot_offset := Vector3.ZERO
var owner_node: Node = null
var lifetime := -1.0
var engage_range := 3.2
var target: Enemy = null
var lifesteal := 0.0
var projectile := ""
var _think := 0.0
var _busy := 0.0
var fly_height := 0.0


func setup(b: Node, ally_id: String, stats: Dictionary, home_pos: Vector3) -> void:
	_init_unit(b, Team.PLAYER)
	unit_id = ally_id
	var d: Dictionary = DB.allies.get(ally_id, DB.allies.footman)
	max_hp = float(stats.get("hp", d.hp))
	hp = max_hp
	armor = float(stats.get("armor_frac", d.get("armor", 0.1)))
	damage_min = float(stats.get("dmg", d.damage)[0])
	damage_max = float(stats.get("dmg", d.damage)[1])
	attack_rate = float(d.get("attack_rate", 1.0))
	attack_range = float(d.get("range", 1.3))
	base_speed = float(d.get("speed", 3.2))
	lifesteal = float(stats.get("lifesteal", 0.0))
	flying = bool(d.get("flying", false))
	projectile = d.get("projectile", "")
	engage_range = float(stats.get("engage", 3.2))
	lifetime = float(stats.get("lifetime", -1.0))
	fly_height = 2.2 if flying else 0.0
	home = home_pos
	setup_model(d.model)
	global_position = home_pos + Vector3(0, fly_height, 0)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	tick_statuses(delta)
	if not alive:
		return
	if lifetime > 0.0:
		lifetime -= delta
		if lifetime <= 0.0:
			die()
			return
	attack_cd -= delta
	_busy -= delta
	_think -= delta
	if _think <= 0.0:
		_think = randf_range(0.2, 0.35)
		_pick_target()
	if is_disabled() or _busy > 0.0:
		return
	if target != null:
		_engage(delta)
	else:
		_return_home(delta)


func _pick_target() -> void:
	if target != null and (not is_instance_valid(target) or not target.is_valid_target() or target.global_position.distance_to(home) > engage_range + 3.0):
		_release()
	if target != null:
		return
	var best: Enemy = null
	var best_score := -INF
	var range_ := engage_range + (6.0 if projectile != "" else 0.0)
	for e in battle.enemies_near(home, range_):
		if not e.is_valid_target():
			continue
		if e.flying and not flying and projectile == "":
			continue
		var score: float = e.progress * 0.05 - e.global_position.distance_to(global_position)
		if not flying and e.blocker != null and e.blocker != self:
			score -= 6.0     # prefer unblocked enemies, spread the soldiers
		if score > best_score:
			best_score = score
			best = e
	target = best


func _release() -> void:
	if target != null and is_instance_valid(target) and target.blocker == self:
		target.blocker = null
	target = null


func on_target_lost(_e: Node) -> void:
	target = null


func _engage(delta: float) -> void:
	var tp := target.global_position
	var d := Vector2(tp.x - global_position.x, tp.z - global_position.z).length()
	var reach := attack_range + target.radius + (5.0 if projectile != "" else 0.0)
	if d > reach:
		_move_towards(tp, delta)
		return
	if not flying and projectile == "" and not target.flying:
		if target.blocker == null or not is_instance_valid(target.blocker) or not target.blocker.alive:
			target.blocker = self
	if model:
		model.face_towards(tp, delta)
	if attack_cd <= 0.0:
		attack_cd = 1.0 / maxf(0.1, attack_rate)
		_busy = 0.3
		if model:
			model.play_action("attack", 1.1)
		var tgt := target
		get_tree().create_timer(0.28, false).timeout.connect(func():
			if not alive or not is_instance_valid(tgt) or not tgt.alive: return
			if projectile != "":
				battle.spawn_projectile(global_position + Vector3(0, 0.5, 0), tgt, {"type": projectile, "damage": roll_damage(), "dmg_type": "fire", "speed": 16.0, "team": Team.PLAYER, "source": self})
			else:
				var dealt: float = tgt.take_damage(roll_damage(), "physical", self)
				if lifesteal > 0.0:
					heal(dealt * lifesteal)
				VFX.hit(battle.fx_root, tgt.global_position + Vector3(0, 1, 0))
				Sfx.play("slash", -14.0))
	elif model and not model.is_locked():
		model.play_loop("idle")


func _move_towards(p: Vector3, delta: float) -> void:
	var dir := p - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		return
	var step := minf(dir.length(), base_speed * speed_mult() * delta)
	global_position += dir.normalized() * step
	global_position.y = fly_height
	if model:
		model.face_towards(p, delta)
		model.play_loop("run")


func _return_home(delta: float) -> void:
	var goal := home + slot_offset
	var d := Vector2(goal.x - global_position.x, goal.z - global_position.z).length()
	if d > 0.25:
		_move_towards(goal, delta)
		if hp < max_hp:
			heal(max_hp * 0.02 * delta)
	else:
		if model and not model.is_locked():
			model.play_loop("idle")
		heal(max_hp * 0.08 * delta)


func _on_death() -> void:
	_release()
	if owner_node != null and is_instance_valid(owner_node) and owner_node.has_method("on_soldier_died"):
		owner_node.on_soldier_died(self)
	super._on_death()
