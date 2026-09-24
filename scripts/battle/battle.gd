class_name BattleController
extends Node3D
## Orchestrates a battle: level, economy, lives, waves, units, towers, hero,
## global powers, spatial queries, victory/defeat and rewards.

var stage_id := "r1s1"
var level: LevelBuilder
var routes: Array[PathRoute] = []
var slots: Array[BuildSlot] = []
var enemies: Array[Enemy] = []
var allies: Array[Unit] = []
var towers: Array[Tower] = []
var hero: Hero
var waves: WaveManager
var globals: GlobalAbilities
var camera_rig: CameraRig
var hud: BattleHUD
var fx_root: Node3D
var units_root: Node3D
var world_root: Node3D
var gold := 0
var lives := 20
var start_lives := 20
var kills := 0
var loot: Array = []
var gold_earned := 0
var xp_earned := 0
var ended := false
var elapsed := 0.0
var show_damage_numbers := true
var damage_log: Dictionary = {}     # source -> damage dealt to enemies (balance telemetry)
var autoplay := false
var _autoplay_bot: AutoplayBot


func _ready() -> void:
	stage_id = Game.current_stage if Game.current_stage != "" else "r1s1"
	Game.current_stage = stage_id
	autoplay = "--autoplay" in OS.get_cmdline_user_args()
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)
	units_root = Node3D.new()
	units_root.name = "Units"
	add_child(units_root)
	fx_root = Node3D.new()
	fx_root.name = "FX"
	add_child(fx_root)
	level = LevelBuilder.new()
	level.build(self, world_root, stage_id)
	routes = level.routes
	slots = level.slots
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.setup(level.bounds, level.castle_pos + Vector3(0, 0, -12))
	waves = WaveManager.new()
	add_child(waves)
	waves.setup(self, stage_id)
	waves.all_waves_spawned.connect(_check_victory)
	gold = waves.start_gold
	start_lives = int(DB.cfg.start_lives)
	lives = start_lives
	globals = GlobalAbilities.new()
	add_child(globals)
	globals.setup(self)
	_spawn_hero()
	hud = BattleHUD.new()
	add_child(hud)
	hud.setup(self)
	var input := BattleInput.new()
	add_child(input)
	input.setup(self)
	Events.battle_gold_changed.emit(gold)
	Events.battle_lives_changed.emit(lives)
	if stage_id == "r1s1" and not bool(Game.setting("tutorial_done", false)) and not autoplay:
		var tut := TutorialDirector.new()
		add_child(tut)
		tut.setup(self)
	if autoplay:
		_autoplay_bot = AutoplayBot.new()
		add_child(_autoplay_bot)
		_autoplay_bot.setup(self)


func _spawn_hero() -> void:
	hero = Hero.new()
	hero.name = "Hero"
	units_root.add_child(hero)
	var r := routes[0]
	var p := r.sample(r.length - 12.0)
	hero.setup(self, Game.profile.selected_hero, p + Vector3(2.5, 0, 0))
	allies.append(hero)


func _physics_process(delta: float) -> void:
	if ended:
		return
	elapsed += delta
	enemies = enemies.filter(func(e): return is_instance_valid(e) and e.alive)
	allies = allies.filter(func(a): return is_instance_valid(a) and (a.alive or a == hero))
	towers = towers.filter(func(t): return is_instance_valid(t))


# ---------------------------------------------------------------- spatial queries
func enemies_near(p: Vector3, r: float) -> Array:
	var out: Array = []
	var r2 := r * r
	for e in enemies:
		if is_instance_valid(e) and e.alive:
			var d := e.global_position - p
			d.y = 0.0
			if d.length_squared() <= r2:
				out.append(e)
	return out


func allies_near(p: Vector3, r: float) -> Array:
	var out: Array = []
	var r2 := r * r
	for a in allies:
		if is_instance_valid(a) and a.alive:
			var d := a.global_position - p
			d.y = 0.0
			if d.length_squared() <= r2:
				out.append(a)
	return out


func towers_near(p: Vector3, r: float) -> Array:
	var out: Array = []
	for t in towers:
		if is_instance_valid(t) and t.global_position.distance_to(p) <= r:
			out.append(t)
	return out


## Where a unit standing at p should step to get clear of an erupting vent or
## an incoming volcanic bomb, or Vector3.INF when p is safe.
func hazard_escape(p: Vector3) -> Vector3:
	for h in level.hazards:
		if is_instance_valid(h) and h.is_threat(p):
			var c: Vector3 = h.threat_center(p)
			var away := p - c
			away.y = 0.0
			if away.length() < 0.2:
				away = Vector3(1, 0, 0.3)
			return clamp_to_bounds(c + away.normalized() * (h.threat_radius() + 1.8))
	return Vector3.INF


func nearest_path_point(p: Vector3, max_dist := 6.0) -> Vector3:
	var best := Vector3.INF
	var bd := INF
	for r in routes:
		if r.air:
			continue
		var c := r.curve.get_closest_point(p)
		var d := c.distance_to(p)
		if d < bd:
			bd = d
			best = c
	if bd > max_dist:
		best = p + (best - p).normalized() * max_dist
	return best


func random_path_point_near(p: Vector3, r: float) -> Vector3:
	var cands: Array[Vector3] = []
	for rt in routes:
		if rt.air:
			continue
		for i in range(0, rt.points.size(), 3):
			if rt.points[i].distance_to(p) <= r:
				cands.append(rt.points[i])
	if cands.is_empty():
		return Vector3.INF
	return cands.pick_random()


func in_bounds(p: Vector3) -> bool:
	return level.bounds.grow(10).has_point(Vector2(p.x, p.z))


func clamp_to_bounds(p: Vector3) -> Vector3:
	var b := level.bounds
	return Vector3(clampf(p.x, b.position.x + 1, b.end.x - 1), 0.0, clampf(p.z, b.position.y + 1, b.end.y - 1))


func shake(amp: float, dur: float) -> void:
	camera_rig.shake(amp, dur)


# ---------------------------------------------------------------- spawning
func spawn_enemy(id: String, route_idx: int, progress := 0.0, summoned := false, hp_mult := -1.0) -> Enemy:
	if ended:
		return null
	var e: Enemy = Boss.new() if DB.is_boss(id) else Enemy.new()
	e.name = id
	units_root.add_child(e)
	var mult := hp_mult if hp_mult > 0.0 else waves.hp_mult * (1.0 + maxi(0, waves.current) * 0.06)
	e.setup(self, id, routes[clampi(route_idx, 0, routes.size() - 1)], route_idx, mult, progress)
	e.summoned = summoned
	e.gold = int(ceil(e.gold * (1.0 + DB.stage_order.find(stage_id) * 0.04)))
	if summoned:
		e.gold = maxi(1, e.gold / 2)
		e.xp = maxi(1, e.xp / 2)
		e.loot_chance *= 0.2
	enemies.append(e)
	e.died.connect(_on_enemy_died)
	if e is Boss:
		Events.boss_spawned.emit(e)
		Sfx.play("boss", 2.0, 0.0)
		shake(0.5, 0.8)
	return e


func spawn_ally(id: String, stats: Dictionary, pos: Vector3) -> AllyUnit:
	var a := AllyUnit.new()
	a.name = id
	units_root.add_child(a)
	a.setup(self, id, stats, pos)
	allies.append(a)
	return a


func spawn_projectile(from: Vector3, target: Unit, params: Dictionary) -> Projectile:
	var p := Projectile.new()
	fx_root.add_child(p)
	p.setup(self, from, target, params)
	return p


# ---------------------------------------------------------------- economy & towers
func add_gold(v: int) -> void:
	gold += v
	Events.battle_gold_changed.emit(gold)


func try_spend(v: int) -> bool:
	if gold < v:
		Events.notify(tr("ui.not_enough"), Color(1, 0.4, 0.3))
		return false
	gold -= v
	Events.battle_gold_changed.emit(gold)
	return true


func available_towers() -> Array:
	return DB.stage_info(stage_id).data.get("towers", ["archer", "mage", "artillery"])


func build_tower(slot: BuildSlot, tower_id: String) -> Tower:
	if not slot.is_free():
		return null
	var cost := int(DB.towers[tower_id].levels[0].cost)
	if not try_spend(cost):
		return null
	var t := Tower.new()
	t.name = "Tower_" + tower_id
	world_root.add_child(t)
	t.setup(self, slot, tower_id)
	slot.tower = t
	towers.append(t)
	VFX.build_dust(fx_root, slot.global_position)
	Sfx.play("build", 0.0)
	Events.tower_built.emit(t)
	Events.track("towers_built")
	return t


func upgrade_tower(t: Tower, branch_idx := -1) -> bool:
	if not t.can_upgrade() and not t.needs_branch_choice():
		return false
	if not try_spend(t.upgrade_cost(branch_idx)):
		return false
	t.upgrade(branch_idx)
	return true


func sell_tower(t: Tower) -> void:
	add_gold(t.sell_value())
	Sfx.play("coin", 0.0)
	if t.slot:
		t.slot.tower = null
	towers.erase(t)
	t.sell()


# ---------------------------------------------------------------- events
func _on_enemy_died(u: Unit) -> void:
	var e := u as Enemy
	if e == null:
		return
	kills += 1
	add_gold(int(e.gold * (1.0 + Game.guild_bonus("gold_bonus"))))
	gold_earned += e.gold
	xp_earned += e.xp
	FloatingText.spawn(fx_root, e.global_position + Vector3(0, e.bar_height + 0.4, 0), "+%d" % e.gold, Color(1, 0.82, 0.3), 36)
	Sfx.play("coin", -14.0)
	Events.track("kills")
	if e is Boss:
		Events.track("boss_kills")
	Events.enemy_killed.emit(e, false)
	_roll_loot(e)
	_check_victory()


func _roll_loot(e: Enemy) -> void:
	var luck := 1.0 + Game.guild_bonus("loot_bonus")
	var lvl := int(Game.profile.player_level) + DB.stage_order.find(stage_id)
	if e is Boss:
		var lt: Dictionary = e.def.get("loot_table", {"count": 2, "min_rarity": 2})
		for i in int(lt.count):
			var it := LootGenerator.roll_drop(lvl + 2, luck * 1.5, int(lt.min_rarity) if i == 0 else 1)
			_drop(it, e.global_position)
	elif randf() < e.loot_chance * luck:
		_drop(LootGenerator.roll_drop(lvl, luck), e.global_position)


func _drop(item: Dictionary, pos: Vector3) -> void:
	loot.append(item)
	var col := Color(0.6, 0.6, 0.62)
	if item.has("rarity"):
		col = DB.rarity_color(int(item.rarity))
	LootOrb.spawn(fx_root, pos, col, camera_rig)
	Events.loot_dropped.emit(item, pos)


func on_enemy_leaked(e: Enemy) -> void:
	if not e.alive:
		return
	e.alive = false
	lives = maxi(0, lives - e.lives)
	Events.battle_lives_changed.emit(lives)
	Events.enemy_leaked.emit(e, e.lives)
	shake(0.25, 0.25)
	Sfx.play("death", -2.0)
	e.queue_free()
	if lives <= 0:
		_end(false)
	else:
		_check_victory()


func _check_victory() -> void:
	if ended or not waves.finished_spawning:
		return
	await get_tree().process_frame
	for e in enemies:
		if is_instance_valid(e) and e.alive:
			return
	if not ended and lives > 0:
		_end(true)


func stars_for_lives() -> int:
	var th: Array = DB.cfg.stars_thresholds
	if lives >= int(th[0]):
		return 3
	if lives >= int(th[1]):
		return 2
	return 1


func _end(victory: bool) -> void:
	if ended:
		return
	ended = true
	var result := {"victory": victory, "stage": stage_id, "kills": kills, "lives": lives, "time": elapsed}
	var gi := DB.stage_order.find(stage_id)
	if waves.endless:
		# Endless runs always pay out: rewards scale with the wave reached.
		var w := maxi(0, waves.current)
		var prev_best := Game.endless_best()
		var best := maxi(prev_best, w)
		Game.profile["endless_best"] = best
		var reward_gold := 80 * w + gold_earned / 2
		var gems := (w / 5) * 5 + (10 if w > prev_best else 0)
		Game.add_gold(reward_gold)
		if gems > 0:
			Game.add_gems(gems)
		var hero_xp := xp_earned / 2 + 20 * w
		var lv := Game.add_hero_xp(hero.hero_id, hero_xp)
		Game.add_player_xp(15 * w)
		for it in loot:
			Game.add_item(it)
		result.merge({"endless": true, "wave": w, "best": best, "new_best": w > prev_best, "stars": 0, "gold": reward_gold,
			"gems": gems, "hero_xp": hero_xp, "player_xp": 15 * w, "loot": loot.duplicate(), "hero_levels": lv})
		Sfx.play("victory" if w > prev_best else "defeat", 0.0, 0.0)
	elif victory:
		var stars := stars_for_lives()
		var first := Game.stage_stars(stage_id) == 0
		var reward_gold := 150 + gi * 40 + gold_earned / 2
		if first:
			reward_gold += 200 + gi * 50
		var gems := 0
		var gained_stars := Game.record_stage_result(stage_id, stars)
		gems += gained_stars * 5
		var hero_xp := xp_earned / 2 + 60 + gi * 15
		var player_xp := 40 + gi * 12 + stars * 10
		Game.add_gold(reward_gold)
		if gems > 0:
			Game.add_gems(gems)
		var lv := Game.add_hero_xp(hero.hero_id, hero_xp)
		Game.add_player_xp(player_xp)
		var granted: Array = []
		for it in loot:
			Game.add_item(it)
			granted.append(it)
		Events.track("victories")
		if stars == 3:
			Events.track("perfect_wins")
		result.merge({"stars": stars, "gold": reward_gold, "gems": gems, "hero_xp": hero_xp, "player_xp": player_xp, "loot": granted, "hero_levels": lv, "first": first})
		Sfx.play("victory", 0.0, 0.0)
	else:
		var hero_xp := int(xp_earned * 0.4)
		Game.add_hero_xp(hero.hero_id, hero_xp)
		result.merge({"stars": 0, "gold": 0, "hero_xp": hero_xp, "loot": []})
		Sfx.play("defeat", 0.0, 0.0)
	Game.last_battle_result = result
	Game.save_now()
	Events.battle_ended.emit(victory, result)
	if autoplay:
		print("AUTOPLAY_RESULT ", JSON.stringify({"victory": victory, "lives": lives, "kills": kills, "time": elapsed, "wave": waves.current + 1, "stars": result.get("stars", 0), "loot": loot.size()}))
		var dl := {}
		for k in damage_log:
			dl[k] = int(damage_log[k])
		print("DAMAGE ", JSON.stringify(dl))
		get_tree().create_timer(0.5, true).timeout.connect(get_tree().quit)
