class_name Enemy
extends Unit
## Enemy unit: follows its route toward the citadel, fights blockers and uses
## role-based utility AI (attacker, tank, ranged, mage, support, summoner,
## trickster, commander, siege, flyer, elite). Perception is limited to its
## own sight radius and it follows the same rules as the player's units.

const SIGHT := 9.0

var def: Dictionary = {}
var route: PathRoute
var route_idx := 0
var progress := 0.0
var lateral := 0.0
var ai_role := "attacker"
var blocker: Unit = null
var shoot_target: Unit = null
var gold := 5
var xp := 5
var lives := 1
var loot_chance := 0.03
var skills: Dictionary = {}
var skill_cd: Dictionary = {}
var state := "march"
var fly_height := 0.0
var projectile_type := "bolt"
var _think := 0.0
var _busy := 0.0        # action lock (attack / cast wind-up)
var _moving := false
var summoned := false
var taunt_time := 0.0     # while > 0 the enemy keeps chasing its taunting blocker


func setup(b: Node, enemy_id: String, r: PathRoute, ridx: int, hp_mult: float, start_progress := 0.0) -> void:
	_init_unit(b, Team.ENEMY)
	unit_id = enemy_id
	def = DB.enemy(enemy_id)
	route = r
	route_idx = ridx
	progress = start_progress
	ai_role = def.get("ai", "attacker")
	max_hp = float(def.hp) * hp_mult
	hp = max_hp
	armor = float(def.get("armor", 0.0))
	mres = float(def.get("mres", 0.0))
	base_speed = float(def.speed)
	damage_min = float(def.damage[0]) * (0.5 + 0.5 * hp_mult)
	damage_max = float(def.damage[1]) * (0.5 + 0.5 * hp_mult)
	attack_rate = float(def.get("attack_rate", 1.0))
	attack_range = float(def.get("range", 1.3))
	gold = int(def.get("gold", 5))
	xp = int(def.get("xp", 5))
	lives = int(def.get("lives", 1))
	loot_chance = float(def.get("loot", 0.03))
	tags = def.get("tags", [])
	flying = bool(def.get("flying", false))
	projectile_type = def.get("projectile", "bolt")
	skills = def.get("skills", {})
	cc_resist = float(skills.get("unstoppable", {}).get("cc_resist", 0.0))
	for k in skills:
		skill_cd[k] = randf_range(1.0, 3.0)
	lateral = randf_range(-0.9, 0.9)
	fly_height = 2.6 if flying else 0.0
	setup_model(def.model)
	if flying:
		bar_height += 0.2
	global_position = _path_pos()
	_think = randf() * 0.3
	if start_progress <= 0.5 and model:
		# Emerge from the portal.
		model.set_param("dissolve", 0.95)
		var tw := create_tween()
		tw.tween_method(func(v): if model: model.set_param("dissolve", v), 0.95, 0.0, 0.8)


func _path_pos() -> Vector3:
	var p := route.sample(progress)
	var d := route.direction(progress)
	var side := Vector3(-d.z, 0, d.x)
	return p + side * lateral + Vector3(0, fly_height, 0)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	tick_statuses(delta)
	if not alive:
		return
	attack_cd -= delta
	_busy -= delta
	for k in skill_cd:
		skill_cd[k] = float(skill_cd[k]) - delta
	taunt_time -= delta
	_think -= delta
	if _think <= 0.0:
		_think = randf_range(0.25, 0.4)
		think()
	if is_disabled():
		if model and model.anim:
			model.anim.speed_scale = 0.0 if statuses.has("freeze") else 0.4
		return
	elif model and model.anim and model.anim.speed_scale == 0.0:
		model.anim.speed_scale = 1.0
	if _busy > 0.0:
		return
	match state:
		"march":
			_march(delta)
		"fight":
			_fight(delta)
		"shoot":
			_shoot(delta)
		"fear":
			_retreat(delta)


# ---------------------------------------------------------------- decision making
func think() -> void:
	var leash := 3.0 if taunt_time <= 0.0 else 8.0
	if blocker != null and (not is_instance_valid(blocker) or not blocker.alive or blocker.global_position.distance_to(global_position) > leash):
		blocker = null
	if statuses.has("fear"):
		state = "fear"
		return
	# Stunned or frozen enemies can't act, and that includes their skills.
	if is_disabled():
		return
	# Passive / periodic role skills.
	_role_skills()
	if blocker != null and not flying:
		state = "fight"
		return
	if ai_role in ["ranged", "mage", "support", "summoner"]:
		shoot_target = _pick_ranged_target()
		if shoot_target != null and hp_ratio() > 0.25:
			state = "shoot"
			return
	state = "march"


func _pick_ranged_target() -> Unit:
	var best: Unit = null
	var best_score := -INF
	for a in battle.allies_near(global_position, attack_range + 0.5):
		if not a.is_valid_target():
			continue
		# Prefer wounded targets and heroes (focus fire), but ignore unreachable flyers.
		var score: float = (1.0 - a.hp_ratio()) * 2.0 + (1.5 if a is Hero else 0.0) - a.global_position.distance_to(global_position) * 0.1
		if score > best_score:
			best_score = score
			best = a
	return best


func _role_skills() -> void:
	if skills.has("haste_aura"):
		var sk: Dictionary = skills.haste_aura
		for e in battle.enemies_near(global_position, float(sk.radius)):
			if e != self:
				e.add_buff("herald_haste", "speed", float(sk.mult), 0.6)
	if skills.has("rally") and _skill_ready("rally"):
		var sk: Dictionary = skills.rally
		var engaged := 0
		var near: Array = battle.enemies_near(global_position, float(sk.radius))
		for e in near:
			if e.blocker != null:
				engaged += 1
		if engaged >= 1:
			for e in near:
				e.add_buff("rally", "armor_add", float(sk.armor), float(sk.duration))
			VFX.ground_ring(battle.fx_root, global_position, float(sk.radius), Color(1, 0.7, 0.2), 0.6)
			_cast_anim("cheer")
			skill_cd.rally = float(sk.cooldown)
	if skills.has("heal") and _skill_ready("heal"):
		var sk: Dictionary = skills.heal
		var wounded := []
		for e in battle.enemies_near(global_position, float(sk.radius)):
			if e.hp_ratio() < 0.85:
				wounded.append(e)
		if not wounded.is_empty():
			for e in wounded:
				e.heal(float(sk.amount) * (max_hp / float(def.hp)))
				VFX.heal(battle.fx_root, e.global_position)
			_cast_anim("cast")
			skill_cd.heal = float(sk.cooldown)
	if skills.has("summon") and _skill_ready("summon"):
		var sk: Dictionary = skills.summon
		# Only summon when it perceives a threat (defenders in sight).
		if not battle.allies_near(global_position, SIGHT).is_empty() or not battle.towers_near(global_position, SIGHT).is_empty():
			for i in int(sk.count):
				battle.spawn_enemy(sk.unit, route_idx, maxf(0.0, minf(progress - 1.0, route.length * 0.6) - i * 0.6), true)
			VFX.shadow_burst(battle.fx_root, global_position, 1.5)
			_cast_anim("summon")
			skill_cd.summon = float(sk.cooldown)
	if skills.has("weaken_tower") and _skill_ready("weaken_tower"):
		var sk: Dictionary = skills.weaken_tower
		var best: Node = null
		for t in battle.towers_near(global_position, float(sk.range)):
			if not t.is_weakened() and (best == null or t.level > best.level):
				best = t
		if best != null:
			best.apply_weaken(float(sk.duration), float(sk.power))
			if sk.get("fx", "") == "fire":
				# Flame callers scorch the tower instead of draining it.
				VFX.lightning(battle.fx_root, global_position + Vector3(0, 1.5, 0), best.global_position + Vector3(0, 3, 0), Color(1.0, 0.45, 0.08), 0.14, 0.4)
				VFX.explosion(battle.fx_root, best.global_position + Vector3(0, 2.5, 0), 1.2, "fire")
			else:
				VFX.lightning(battle.fx_root, global_position + Vector3(0, 1.5, 0), best.global_position + Vector3(0, 3, 0), Color(0.7, 0.2, 1.0), 0.1, 0.4)
			_cast_anim("cast")
			skill_cd.weaken_tower = float(sk.cooldown)
	if skills.has("attack_tower") and _skill_ready("attack_tower"):
		var sk: Dictionary = skills.attack_tower
		for t in battle.towers_near(global_position, float(sk.range)):
			if not t.is_disabled():
				model.face_instant(t.global_position)
				_busy = model.play_action("special", 1.0) * 0.8
				var tref := weakref(t)
				get_tree().create_timer(0.45, false).timeout.connect(func():
					var tower = tref.get_ref()
					if alive and tower != null:
						tower.disable(float(sk.disable))
						VFX.explosion(battle.fx_root, tower.global_position, 1.6, "earth")
						Sfx.play("explosion", -6.0))
				skill_cd.attack_tower = float(sk.cooldown)
				break
	if skills.has("blink") and _skill_ready("blink") and (blocker != null or hp_ratio() < 0.5):
		var sk: Dictionary = skills.blink
		VFX.shadow_burst(battle.fx_root, global_position)
		if blocker != null:
			blocker = null
		progress = minf(route.length - 2.0, progress + float(sk.distance))
		global_position = _path_pos()
		VFX.shadow_burst(battle.fx_root, global_position)
		skill_cd.blink = float(sk.cooldown)
	if skills.has("stealth") and _skill_ready("stealth") and hp_ratio() < 0.5:
		var sk: Dictionary = skills.stealth
		stealthed = true
		model.set_param("shadow_form", 1.0)
		skill_cd.stealth = float(sk.cooldown)
		get_tree().create_timer(float(sk.duration), false).timeout.connect(func():
			stealthed = false
			if model: model.set_param("shadow_form", 0.0))
	if ai_role == "tank" and hp_ratio() < 0.5 and _skill_ready("fortify"):
		add_buff("fortify", "armor_add", 0.25, 4.0)
		VFX.ground_ring(battle.fx_root, global_position, 1.5, Color(0.8, 0.8, 1.0), 0.5)
		skill_cd.fortify = 12.0
	if skills.has("cleave") and blocker != null and _skill_ready("cleave"):
		var sk: Dictionary = skills.cleave
		_busy = model.play_action("special", 1.0) * 0.8
		get_tree().create_timer(0.4, false).timeout.connect(func():
			if not alive: return
			for a in battle.allies_near(global_position, float(sk.radius)):
				a.take_damage(roll_damage() * 1.3, "physical", self)
			VFX.nova(battle.fx_root, global_position, float(sk.radius), "shadow"))
		skill_cd.cleave = float(sk.cooldown)


## Forced to fight `by` for `duration` seconds (taunt abilities).
func taunt(by: Unit, duration: float) -> void:
	if flying or not alive:
		return
	blocker = by
	taunt_time = duration * (1.0 - cc_resist) * (0.35 if tags.has("boss") else 1.0)
	state = "fight"


func _skill_ready(skill: String) -> bool:
	return float(skill_cd.get(skill, 0.0)) <= 0.0


func _cast_anim(logical: String) -> void:
	if model:
		_busy = minf(0.8, model.play_action(logical, 1.2) * 0.6)


# ---------------------------------------------------------------- behaviours
func _march(delta: float) -> void:
	var spd := base_speed * speed_mult()
	if is_immobile():
		spd = 0.0
	progress += spd * delta
	if progress >= route.length:
		battle.on_enemy_leaked(self)
		return
	var target := _path_pos()
	if model:
		model.face_towards(target + route.direction(progress) * 2.0, delta, 8.0)
		model.play_loop("run" if spd > 2.2 or flying else "walk", clampf(spd / 2.0, 0.6, 1.6))
	global_position = target


func _fight(delta: float) -> void:
	if blocker == null or not is_instance_valid(blocker) or not blocker.alive:
		blocker = null
		state = "march"
		return
	var d := global_position.distance_to(blocker.global_position)
	if d > attack_range + blocker.radius + 0.3:
		# Close the gap toward the blocker (stays near its lane).
		var dir := (blocker.global_position - global_position)
		dir.y = 0.0
		global_position += dir.normalized() * base_speed * speed_mult() * delta
		progress = route.closest_offset(global_position)
		if model:
			model.face_towards(blocker.global_position, delta)
			model.play_loop("walk")
		return
	if model:
		model.face_towards(blocker.global_position, delta)
	if attack_cd <= 0.0:
		attack_cd = 1.0 / maxf(0.1, attack_rate)
		_busy = 0.35
		if model:
			model.play_action("attack", 1.1)
		get_tree().create_timer(0.3, false).timeout.connect(_melee_hit.bind(weakref(blocker)))
	elif model and not model.is_locked():
		model.play_loop("idle")


func _shoot(delta: float) -> void:
	if shoot_target == null or not is_instance_valid(shoot_target) or not shoot_target.is_valid_target() \
			or shoot_target.global_position.distance_to(global_position) > attack_range + 1.0:
		shoot_target = null
		state = "march"
		return
	if model:
		model.face_towards(shoot_target.global_position, delta)
	if attack_cd <= 0.0:
		attack_cd = 1.0 / maxf(0.1, attack_rate)
		_busy = 0.4
		if model:
			model.play_action("attack", 1.2)
		get_tree().create_timer(0.3, false).timeout.connect(_ranged_shot.bind(weakref(shoot_target)))
	elif model and not model.is_locked():
		model.play_loop("idle")


func _melee_hit(ref: WeakRef) -> void:
	var tgt: Unit = ref.get_ref()
	if alive and tgt != null and tgt.alive and not attack_miss():
		tgt.take_damage(roll_damage(), "physical", self)
		Sfx.play("hit", -12.0)


func _ranged_shot(ref: WeakRef) -> void:
	var tgt: Unit = ref.get_ref()
	if alive and tgt != null and tgt.alive:
		battle.spawn_projectile(global_position + Vector3(0, 1.3, 0), tgt, {"type": projectile_type, "damage": roll_damage(), "dmg_type": def.get("dmg_type", "physical" if projectile_type == "bolt" else "shadow"), "speed": 14.0, "team": Team.ENEMY, "source": self})


func _retreat(delta: float) -> void:
	if not statuses.has("fear"):
		state = "march"
		return
	progress = maxf(0.0, progress - base_speed * 0.7 * delta)
	global_position = _path_pos()
	if model:
		model.play_loop("walk", 0.8)


func _on_death() -> void:
	if blocker != null and is_instance_valid(blocker) and blocker.has_method("on_target_lost"):
		blocker.on_target_lost(self)
	if skills.has("death_burst"):
		# Magma imps burst when slain, scorching the defenders around them.
		var sk: Dictionary = skills.death_burst
		var pos := global_position
		VFX.explosion(battle.fx_root, pos, float(sk.radius), "fire")
		for a in battle.allies_near(pos, float(sk.radius)):
			a.take_damage(float(sk.damage), "fire", null)
	if skills.has("split") and not battle.ended:
		# Obsidian golems crack apart into molten imps.
		var sk: Dictionary = skills.split
		VFX.particles(battle.fx_root, global_position + Vector3(0, 1.0, 0), {"amount": 22, "lifetime": 0.9, "speed": 5.0, "size": 0.35, "color": Color(1, 0.4, 0.05), "gravity": Vector3(0, -8, 0)})
		for i in int(sk.count):
			var imp: Enemy = battle.spawn_enemy(sk.unit, route_idx, maxf(0.0, progress - 0.6 - i * 0.9), true)
			if imp:
				imp.lateral = clampf(lateral + (i - 0.5) * 1.2, -1.0, 1.0)
				# They crawl out of the rubble for a moment before running on.
				imp.apply_status("stun", 1.0, 1.0)
	super._on_death()
