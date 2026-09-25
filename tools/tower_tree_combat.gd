extends Node
## Controlled combat test for Tower Mastery. For one tower type (TT_TOWER) and
## one level/branch (TT_LEVEL, TT_BRANCH), builds the tower on the slot with the
## most road around it, streams armoured test enemies past it for a fixed time
## (no hero, no waves) and prints its damage, kills, specials and stats.
## Run it once without a tree and once with --tower-tree=<tower>:<path>.

const DURATION := 45.0


func _ready() -> void:
	while not (get_tree().current_scene is BattleController):
		await get_tree().process_frame
	var b: BattleController = get_tree().current_scene
	await get_tree().create_timer(0.5).timeout
	var tid := OS.get_environment("TT_TOWER")
	var lvl := int(OS.get_environment("TT_LEVEL")) if OS.get_environment("TT_LEVEL") != "" else 3
	var br := int(OS.get_environment("TT_BRANCH")) if OS.get_environment("TT_BRANCH") != "" else -1
	b.hero.set_physics_process(false)
	b.hero.visible = false
	b.hero.alive = false
	b.gold = 100000
	var r: PathRoute = b.routes[0]
	var best: BuildSlot = null
	var best_v := -1.0
	for s in b.slots:
		var v := 0.0
		for i in range(0, r.points.size(), 4):
			if r.points[i].distance_to(s.global_position) < 8.0:
				v += 1.0
		if v > best_v:
			best_v = v
			best = s
	var t := b.build_tower(best, tid)
	var paid := 100000 - b.gold
	while t.level < lvl:
		if t.needs_branch_choice():
			b.upgrade_tower(t, maxi(0, br))
		else:
			b.upgrade_tower(t)
	var start_kills := b.kills
	var enemy := OS.get_environment("TT_ENEMY") if OS.get_environment("TT_ENEMY") != "" else "skeleton_warrior"
	var el := 0.0
	var spawn_t := 0.0
	var off := r.closest_offset(t.global_position)
	var spawn_at := maxf(0.0, off - t.range_() - 4.0)
	var free_at := minf(r.length - 1.0, off + t.range_() + 6.0)
	while el < DURATION:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		el += dt
		spawn_t -= dt
		if spawn_t <= 0.0:
			spawn_t = 1.6
			var e := b.spawn_enemy(enemy, 0, spawn_at, false, 1.4)
			if e and OS.get_environment("TT_AIR") == "1":
				var f := b.spawn_enemy("winged_fiend", 0, spawn_at, false, 1.4)
		for e in b.enemies:
			if is_instance_valid(e) and e.progress > free_at:
				e.queue_free()
		if OS.get_environment("TT_DEBUG") == "1" and int(el * 60) % 300 == 0:
			var near := b.enemies_near(t.global_position, t.range_()).size()
			var e0 = b.enemies[0] if b.enemies.size() > 0 else null
			print("DBG t=%.0f enemies=%d near=%d prog=%s state=%s pos=%s" % [el, b.enemies.size(), near, str(e0.progress) if e0 else "-", e0.state if e0 else "-", str(e0.global_position) if e0 else "-"])
	var dmg := float(b.damage_log.get("tower_" + tid, 0.0))
	var solds := 0
	var shp := 0.0
	for s in t.soldiers:
		if is_instance_valid(s):
			solds += 1
			shp = s.max_hp
	print("TT_COMBAT tower=%s tree=%s lvl=%d br=%d dmg=%d kills=%d specials=%d build_cost=%d range=%.1f rate=%.2f pen=%.2f soldiers=%d soldier_hp=%d traps=%d special=%s" % [
		tid, OS.get_environment("TT_TAG"), t.level, t.branch, int(dmg), b.kills - start_kills, t.special_count, paid,
		t.range_(), float(t.data.get("rate", 0.0)), t.armor_pen, solds, int(shp), t.traps.size(), str(t.data.get("special", {}).get("type", "-"))])
	get_tree().quit()
