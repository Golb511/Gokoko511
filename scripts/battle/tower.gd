class_name Tower
extends Node3D
## Defensive tower with 3 base levels and two branching specialisations.
## Attack styles: projectile, artillery, chain, beam, pulse, storm, lance,
## barracks (soldiers) and trap. Visuals change with level and branch.

var battle: Node
var slot: Node        # BuildSlot
var tower_id := ""
var tdef: Dictionary
var level := 1
var branch := -1
var data: Dictionary = {}
var invested := 0
var cooldown := 0.0
var disabled_t := 0.0
var weaken_t := 0.0
var weaken_p := 0.0
var buffs: Dictionary = {}     # id -> {t, mult}
var rally_point := Vector3.ZERO
var soldiers: Array = []
var _respawn_q: Array = []
var traps: Array = []
var beam_target: Enemy = null
var beam_time := 0.0
var _beam: MeshInstance3D
var _visual: Node3D
var _materials: Array[ShaderMaterial] = []
var _orb: Node3D
var _orb_light: OmniLight3D
var _top_height := 3.0
var _pips: Node3D
var range_ring: MeshInstance3D


func setup(b: Node, s: Node, id: String) -> void:
	battle = b
	slot = s
	tower_id = id
	tdef = DB.towers[id]
	level = 1
	data = DB.tower_level_data(id, 1, -1)
	invested = int(data.cost)
	global_position = s.global_position
	rally_point = battle.nearest_path_point(global_position, 4.5)
	_build_visual()
	_make_range_ring()
	if attack_type() == "barracks":
		_spawn_all_soldiers()


# ---------------------------------------------------------------- data helpers
func attack_type() -> String:
	return DB.tower_attr(tower_id, branch, "attack", "projectile")


func element() -> String:
	return DB.tower_attr(tower_id, branch, "element", "physical")


func dmg_type() -> String:
	return DB.tower_attr(tower_id, branch, "dmg_type", "physical")


func hits_air() -> bool:
	return bool(DB.tower_attr(tower_id, branch, "air", true))


func accent() -> Color:
	var a = tdef.model.accent
	if branch >= 0:
		a = tdef.branches[branch].get("accent", a)
	return ModelLib._col(a)


func range_() -> float:
	return float(data.get("range", 8.0))


func max_level() -> int:
	return DB.tower_max_level(tower_id)


func can_upgrade() -> bool:
	return level < tdef.levels.size() or (branch >= 0 and level < max_level())


func needs_branch_choice() -> bool:
	return level == tdef.levels.size() and branch < 0


func upgrade_cost(branch_idx: int = -1) -> int:
	if needs_branch_choice():
		return int(tdef.branches[branch_idx if branch_idx >= 0 else 0].levels[0].cost)
	if not can_upgrade():
		return 0
	return int(DB.tower_level_data(tower_id, level + 1, branch).cost)


func sell_value() -> int:
	return int(invested * float(DB.cfg.sell_refund))


func display_name() -> String:
	if branch >= 0:
		return tr("branch." + str(tdef.branches[branch].id))
	return tr("tower." + tower_id)


func dps_estimate() -> float:
	var d: Array = data.get("dmg", [0, 0])
	return (float(d[0]) + float(d[1])) * 0.5 * float(data.get("rate", 1.0)) * maxf(1, int(data.get("multishot", 1)))


# ---------------------------------------------------------------- upgrades
func upgrade(branch_idx: int = -1) -> void:
	var cost := upgrade_cost(branch_idx)
	if needs_branch_choice():
		branch = maxi(0, branch_idx)
	level += 1
	invested += cost
	data = DB.tower_level_data(tower_id, level, branch)
	_build_visual()
	VFX.build_dust(battle.fx_root, global_position)
	VFX.level_up(battle.fx_root, global_position)
	Sfx.play("levelup", -6.0)
	if attack_type() == "barracks":
		_refresh_soldiers()
	else:
		for s in soldiers:
			if is_instance_valid(s):
				s.die()
		soldiers.clear()
	Events.tower_upgraded.emit(self)
	Events.track("tower_upgrades")


func sell() -> void:
	for s in soldiers:
		if is_instance_valid(s):
			s.owner_node = null
			s.die()
	for tr_ in traps:
		if is_instance_valid(tr_):
			tr_.queue_free()
	if _beam:
		_beam.queue_free()
	VFX.build_dust(battle.fx_root, global_position)
	Events.tower_sold.emit(self)
	queue_free()


func set_rally(p: Vector3) -> void:
	rally_point = p
	for i in soldiers.size():
		if is_instance_valid(soldiers[i]):
			soldiers[i].home = p
			soldiers[i].slot_offset = _slot_offset(i)
			soldiers[i].target = null


# ---------------------------------------------------------------- status
func is_disabled() -> bool:
	return disabled_t > 0.0


func is_weakened() -> bool:
	return weaken_t > 0.0


func disable(seconds: float) -> void:
	disabled_t = maxf(disabled_t, seconds)
	for m in _materials:
		m.set_shader_parameter("disabled", 1.0)
	if _orb:
		_orb.visible = false


func apply_weaken(seconds: float, power: float) -> void:
	weaken_t = seconds
	weaken_p = power
	VFX.shadow_burst(battle.fx_root, global_position + Vector3(0, _top_height, 0), 1.0)


func add_buff(id: String, mult: float, seconds: float) -> void:
	buffs[id] = {"t": seconds, "mult": mult}
	for m in _materials:
		m.set_shader_parameter("buffed", 1.0)


func _mult() -> float:
	var m := 1.0 + Game.guild_bonus("tower_dmg")
	for b in buffs.values():
		m *= float(b.mult)
	if weaken_t > 0.0:
		m *= 1.0 - weaken_p
	return m


# ---------------------------------------------------------------- loop
func _physics_process(delta: float) -> void:
	if disabled_t > 0.0:
		disabled_t -= delta
		if disabled_t <= 0.0:
			for m in _materials:
				m.set_shader_parameter("disabled", 0.0)
			if _orb:
				_orb.visible = true
		_clear_beam()
		return
	weaken_t -= delta
	for id in buffs.keys():
		buffs[id].t = float(buffs[id].t) - delta
		if float(buffs[id].t) <= 0.0:
			buffs.erase(id)
			if buffs.is_empty():
				for m in _materials:
					m.set_shader_parameter("buffed", 0.0)
	if _orb:
		_orb.rotation.y += delta * 1.5
		_orb.position.y = _top_height + 0.5 + sin(Time.get_ticks_msec() / 500.0) * 0.12
	var rate_mult := _mult() if buffs.size() > 0 else 1.0
	cooldown -= delta * rate_mult
	match attack_type():
		"barracks":
			_tick_barracks(delta)
			return
		"beam":
			_tick_beam(delta)
			return
		"trap":
			if cooldown <= 0.0:
				_place_trap()
			return
	if cooldown > 0.0:
		return
	match attack_type():
		"projectile":
			_attack_projectile()
		"artillery":
			_attack_artillery()
		"chain":
			_attack_chain()
		"pulse":
			_attack_pulse()
		"storm":
			_attack_storm()
		"lance":
			_attack_lance()


func _targets() -> Array:
	var out: Array = []
	for e in battle.enemies_near(global_position, range_()):
		if e.is_valid_target() and (hits_air() or not e.flying):
			out.append(e)
	# Priority: furthest along the route first.
	out.sort_custom(func(a, b): return a.progress / a.route.length > b.progress / b.route.length)
	return out


func _roll() -> float:
	var d: Array = data.get("dmg", [1, 1])
	return randf_range(float(d[0]), float(d[1])) * _mult()


func _reset_cd() -> void:
	cooldown = 1.0 / maxf(0.05, float(data.get("rate", 1.0)))


func _muzzle() -> Vector3:
	return global_position + Vector3(0, _top_height + 0.4, 0)


func _base_params() -> Dictionary:
	return {"dmg_type": dmg_type(), "team": Unit.Team.PLAYER, "source": self, "status": data.get("status", {}),
		"splash": float(data.get("splash", 0.0)), "freeze_chance": float(data.get("freeze_chance", 0.0)),
		"stun_chance": float(data.get("stun_chance", 0.0)), "instakill": float(data.get("instakill", 0.0)),
		"bonus_vs": data.get("bonus_vs", ""), "pierce": int(data.get("pierce", 0))}


func _attack_projectile() -> void:
	var ts := _targets()
	if ts.is_empty():
		return
	_reset_cd()
	var shots := int(data.get("multishot", 1))
	var ptype: String = DB.tower_attr(tower_id, branch, "projectile", "arrow")
	for i in mini(shots, ts.size()):
		var t: Enemy = ts[i]
		var prm := _base_params()
		var crit := randf() < float(data.get("crit", 0.0))
		prm.merge({"type": ptype, "damage": _roll() * (2.0 if crit else 1.0), "speed": 24.0 if ptype in ["arrow", "bolt"] else 16.0, "crit": crit})
		battle.spawn_projectile(_muzzle(), t, prm)
	Sfx.play("arrow" if ptype in ["arrow", "bolt"] else "magic", -12.0)


func _attack_artillery() -> void:
	var ts := _targets()
	if ts.is_empty():
		return
	_reset_cd()
	var t: Enemy = ts[0]
	# Lead the target: predict position along its route at impact time.
	var flight := 1.1
	var lead: Vector3 = t.route.sample(t.progress + t.base_speed * t.speed_mult() * flight * (0.0 if t.blocker != null else 1.0))
	var prm := _base_params()
	prm.merge({"type": "bomb", "damage": _roll(), "target_pos": lead, "speed": global_position.distance_to(lead) / flight, "arc": 5.0, "ground_only": true})
	if data.has("ground_fire"):
		prm["ground_fire"] = data.ground_fire
	battle.spawn_projectile(_muzzle(), null, prm)
	Sfx.play("build", -10.0)


func _attack_chain() -> void:
	var ts := _targets()
	if ts.is_empty():
		return
	_reset_cd()
	var hit_list: Array = []
	var cur: Enemy = ts[0]
	var from := _muzzle()
	var dmg := _roll()
	for k in int(data.get("chain", 2)) + 1:
		if cur == null:
			break
		hit_list.append(cur)
		VFX.lightning(battle.fx_root, from, cur.global_position + Vector3(0, 1.0, 0), accent())
		cur.take_damage(dmg * pow(0.85, k), "lightning", self)
		from = cur.global_position + Vector3(0, 1.0, 0)
		var nxt: Enemy = null
		var best := 4.5
		for e in battle.enemies_near(cur.global_position, 4.5):
			if e in hit_list or not e.is_valid_target():
				continue
			var d: float = e.global_position.distance_to(cur.global_position)
			if d < best:
				best = d
				nxt = e
		cur = nxt
	Sfx.play("lightning", -10.0)


func _attack_pulse() -> void:
	var ts := _targets()
	if ts.is_empty():
		return
	_reset_cd()
	var elem := element()
	var kb := float(data.get("knockback", 0.0))
	for e in ts:
		var dmg := _roll()
		if e.flying and data.has("air_bonus"):
			dmg *= float(data.air_bonus)
		e.take_damage(dmg, dmg_type() if elem != "wind" else "physical", self)
		var st: Dictionary = data.get("status", {})
		if not st.is_empty():
			e.apply_status(st.id, float(st.duration), float(st.power))
		if randf() < float(data.get("stun_chance", 0.0)) and not e.flying:
			e.apply_status("stun", 1.0, 1.0)
		if kb > 0.0 and not e.tags.has("boss"):
			e.progress = maxf(0.0, e.progress - kb * (0.5 if e.tags.has("elite") else 1.0))
	VFX.nova(battle.fx_root, global_position, range_(), elem if elem != "physical" else "earth")
	if elem == "earth":
		battle.shake(0.12, 0.2)
	Sfx.play("explosion" if elem == "earth" else "freeze", -10.0)


func _attack_storm() -> void:
	var ts := _targets()
	if ts.is_empty():
		return
	_reset_cd()
	var t: Enemy = ts.pick_random()
	var pos := t.global_position
	VFX.lightning(battle.fx_root, pos + Vector3(randf_range(-1, 1), 12, randf_range(-1, 1)), pos, accent(), 0.2, 0.25)
	for e in battle.enemies_near(pos, float(data.get("splash", 1.5))):
		e.take_damage(_roll(), "lightning", self)
		if randf() < float(data.get("stun_chance", 0.0)):
			e.apply_status("stun", 0.8, 1.0)
	Sfx.play("lightning", -8.0)


func _attack_lance() -> void:
	var ts := _targets()
	if ts.is_empty():
		return
	_reset_cd()
	var t: Enemy = ts[0]
	var from := _muzzle()
	var dir := t.global_position + Vector3(0, 1, 0) - from
	var end := from + dir.normalized() * (range_() + 2.0)
	VFX.lightning(battle.fx_root, from, end, accent(), 0.3, 0.3)
	for e in battle.enemies_near((from + end) * 0.5, from.distance_to(end) * 0.5 + 1.0):
		if AbilityExecutor._dist_to_segment(e.global_position, from, end) <= 1.1:
			var dmg := _roll() * (1.5 if e.tags.has(data.get("bonus_vs", "-")) else 1.0)
			e.take_damage(dmg, "holy", self)
	Sfx.play("magic", -6.0)


# ---------------------------------------------------------------- beam
func _tick_beam(delta: float) -> void:
	if beam_target != null and (not is_instance_valid(beam_target) or not beam_target.is_valid_target() or beam_target.global_position.distance_to(global_position) > range_() + 0.5):
		beam_target = null
		beam_time = 0.0
	if beam_target == null:
		var ts := _targets()
		if ts.is_empty():
			_clear_beam()
			return
		beam_target = ts[0]
		beam_time = 0.0
	beam_time += delta
	var ramp := 1.0 + float(data.get("ramp", 0.5)) * minf(beam_time, 4.0)
	var dps := float(data.dmg[0]) * _mult() * ramp
	var dmg := dps * delta
	if data.get("bonus_vs", "") != "" and beam_target.tags.has(data.bonus_vs):
		dmg *= 1.5
	_beam_damage(dmg)
	if data.has("heal_allies"):
		for a in battle.allies_near(global_position, range_()):
			a.heal(float(data.heal_allies) * delta)
	_draw_beam(ramp)


func _beam_damage(dmg: float) -> void:
	# Accumulate tiny ticks so damage numbers stay readable.
	beam_target.set_meta("beam_acc", float(beam_target.get_meta("beam_acc", 0.0)) + dmg)
	var acc := float(beam_target.get_meta("beam_acc"))
	if acc >= 8.0:
		beam_target.set_meta("beam_acc", 0.0)
		beam_target.take_damage(acc, dmg_type(), self)


func _draw_beam(ramp: float) -> void:
	if _beam == null:
		_beam = MeshInstance3D.new()
		_beam.mesh = ImmediateMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = accent() * 1.6
		_beam.material_override = m
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		battle.fx_root.add_child(_beam)
	if beam_target == null or not is_instance_valid(beam_target):
		return
	var im: ImmediateMesh = _beam.mesh
	im.clear_surfaces()
	var a := _muzzle()
	var b := beam_target.global_position + Vector3(0, 1.0, 0)
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else a + Vector3(0, 10, 10)
	var w := 0.08 + 0.05 * ramp + sin(Time.get_ticks_msec() / 40.0) * 0.02
	var side := (b - a).cross(eye - a).normalized() * w
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
		im.surface_add_vertex(v)
	im.surface_end()
	if randf() < 0.3:
		VFX.hit(battle.fx_root, b, element())


func _clear_beam() -> void:
	if _beam:
		(_beam.mesh as ImmediateMesh).clear_surfaces()


# ---------------------------------------------------------------- barracks
func _soldier_stats() -> Dictionary:
	return {"hp": float(data.hp), "dmg": data.dmg, "armor_frac": float(data.get("armor", 10)) / 100.0, "lifesteal": float(data.get("lifesteal", 0.0)), "engage": range_() * 0.45}


func _slot_offset(i: int) -> Vector3:
	var n := int(data.get("soldiers", 3))
	if n <= 1:
		return Vector3.ZERO
	var ang := TAU * i / n
	return Vector3(cos(ang), 0, sin(ang)) * 1.1


func _spawn_soldier(i: int) -> void:
	var unit_type: String = data.get("unit", "footman")
	var s: AllyUnit = battle.spawn_ally(unit_type, _soldier_stats(), global_position + Vector3(0, 0, 1.2))
	s.home = rally_point
	s.slot_offset = _slot_offset(i)
	s.owner_node = self
	s.set_meta("slot_index", i)
	if soldiers.size() <= i:
		soldiers.resize(i + 1)
	soldiers[i] = s


func _spawn_all_soldiers() -> void:
	for i in int(data.get("soldiers", 3)):
		_spawn_soldier(i)


func _refresh_soldiers() -> void:
	for s in soldiers:
		if is_instance_valid(s) and s.alive:
			s.owner_node = null
			s.die()
	soldiers.clear()
	_respawn_q.clear()
	_spawn_all_soldiers()


func on_soldier_died(s: AllyUnit) -> void:
	_respawn_q.append({"i": int(s.get_meta("slot_index", 0)), "t": float(data.get("respawn", 10))})


func _tick_barracks(delta: float) -> void:
	for q in _respawn_q:
		q.t = float(q.t) - delta
	for q in _respawn_q.duplicate():
		if float(q.t) <= 0.0:
			_respawn_q.erase(q)
			_spawn_soldier(int(q.i))


# ---------------------------------------------------------------- traps
func _place_trap() -> void:
	traps = traps.filter(func(t): return is_instance_valid(t))
	if traps.size() >= int(data.get("traps", 2)):
		cooldown = 1.0
		return
	var p: Vector3 = battle.random_path_point_near(global_position, range_())
	if p == Vector3.INF:
		cooldown = 1.0
		return
	_reset_cd()
	var trap := Trap.new()
	battle.fx_root.add_child(trap)
	trap.setup(battle, p, _roll(), data.get("status", {}), accent())
	traps.append(trap)
	VFX.build_dust(battle.fx_root, p)


# ---------------------------------------------------------------- visuals
func _build_visual() -> void:
	if _visual:
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	var m: Dictionary = tdef.model
	var tint := Color(0.42, 0.38, 0.36) if branch < 0 else Color(0.36, 0.33, 0.32)
	var base_key: String = DB.tower_attr(tower_id, branch, "model_base", m.base)
	var model := ModelLib.prop(base_key, tint, accent(), 0.6 + level * 0.15)
	_visual.add_child(model)
	# Normalise any source asset to a common footprint, then grow with level.
	var aabb := _aabb_of(model)
	var fit := minf(2.6 / maxf(0.01, maxf(aabb.size.x, aabb.size.z)), 3.6 / maxf(0.01, aabb.size.y))
	var s := fit * float(m.get("scale", 1.0)) * (0.85 + 0.09 * level)
	model.scale = Vector3.ONE * s
	model.rotation.y = PI * 0.25 * (hash(slot.name) % 4)
	_top_height = aabb.end.y * s
	_materials = ModelLib.make_unique_materials(model)
	# Stone plinth so the tower sits into the ground.
	var plinth := ModelLib.prop("env/building_tower_base_red", Color(0.3, 0.28, 0.27))
	plinth.scale = Vector3(1.55, 0.18, 1.55)
	_visual.add_child(plinth)
	_build_top(m.get("top", "none"))
	_build_pips()
	_build_level_decor()


func _aabb_of(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = mi.transform * mi.get_aabb()
		var p: Node = mi.get_parent()
		while p != n and p is Node3D:
			a = p.transform * a
			p = p.get_parent()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


func _build_top(kind: String) -> void:
	var c := accent()
	_orb = Node3D.new()
	_orb.position.y = _top_height + 0.5
	_visual.add_child(_orb)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = c
	glow.emission_enabled = true
	glow.emission = c
	glow.emission_energy_multiplier = 3.0 + level
	var crystal := MeshInstance3D.new()
	match kind:
		"crystal", "ice", "void", "halo":
			var pm := PrismMesh.new()
			pm.size = Vector3(0.45, 0.8, 0.45)
			crystal.mesh = pm
			var low := MeshInstance3D.new()
			low.mesh = pm
			low.rotation.x = PI
			low.position.y = -0.55
			low.material_override = glow
			_orb.add_child(low)
			if kind == "halo":
				var ring := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.55
				tm.outer_radius = 0.62
				ring.mesh = tm
				ring.material_override = glow
				ring.position.y = 0.6
				_orb.add_child(ring)
		"coil":
			var tm := TorusMesh.new()
			tm.inner_radius = 0.25
			tm.outer_radius = 0.36
			for k in 3:
				var r := MeshInstance3D.new()
				r.mesh = tm
				r.position.y = -0.4 + k * 0.3
				r.material_override = glow
				_orb.add_child(r)
			var sm := SphereMesh.new()
			sm.radius = 0.22
			sm.height = 0.44
			crystal.mesh = sm
			crystal.position.y = 0.45
		"brazier", "cauldron":
			VFX.fire_pillar(_orb, _orb.global_position if _orb.is_inside_tree() else global_position + Vector3(0, _top_height + 0.5, 0), 0.8 + level * 0.1).position = Vector3.ZERO
			var sm := SphereMesh.new()
			sm.radius = 0.15
			sm.height = 0.3
			crystal.mesh = sm
		_:
			var sm := SphereMesh.new()
			sm.radius = 0.16 + level * 0.02
			sm.height = sm.radius * 2.0
			crystal.mesh = sm
	crystal.material_override = glow
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb.add_child(crystal)
	# Element sparkles and light.
	var e := CPUParticles3D.new()
	e.amount = 10 + level * 4
	e.lifetime = 1.2
	e.mesh = QuadMesh.new()
	e.material_override = VFX._additive()
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 0.5
	e.gravity = Vector3(0, 0.6, 0)
	e.scale_amount_min = 0.08
	e.scale_amount_max = 0.18
	e.color_ramp = VFX._ramp(c)
	_orb.add_child(e)
	_orb_light = OmniLight3D.new()
	_orb_light.light_color = c
	_orb_light.light_energy = 1.2 + level * 0.3
	_orb_light.omni_range = 5.0 + level * 0.5
	_orb.add_child(_orb_light)
	if branch >= 0:
		# Branch crown: ring of floating shards in the branch colour.
		for k in 4:
			var shard := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.14, 0.5, 0.14)
			shard.mesh = pm
			shard.material_override = glow
			var ang := TAU * k / 4.0
			shard.position = Vector3(cos(ang) * 0.8, -0.2, sin(ang) * 0.8)
			_orb.add_child(shard)


## Level 2+: iron braziers at the plinth corners. Level 3+: floating rune ring.
func _build_level_decor() -> void:
	if level >= 2:
		for k in 4:
			var a := TAU * k / 4.0 + PI * 0.25
			var p := Vector3(cos(a), 0, sin(a)) * 1.35
			var post := ModelLib.prop("graveyard/fence_pillar", Color(0.3, 0.28, 0.27))
			post.scale = Vector3.ONE * 0.9
			post.position = p
			_visual.add_child(post)
			if level >= 3 and k % 2 == 0:
				VFX.torch_flame(_visual, global_position + p + Vector3(0, 0.95, 0), accent(), false)
	if level >= 3:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.25
		tm.outer_radius = 1.32
		tm.rings = 48
		tm.ring_segments = 6
		ring.mesh = tm
		var gm := StandardMaterial3D.new()
		gm.albedo_color = accent()
		gm.emission_enabled = true
		gm.emission = accent()
		gm.emission_energy_multiplier = 2.0 + level * 0.4
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = gm
		ring.position.y = _top_height * 0.55
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(ring)
		var spin := ring.create_tween().set_loops()
		spin.tween_property(ring, "rotation:y", TAU, 6.0).from(0.0)
		for k in 6:
			var rune := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.12, 0.3, 0.04)
			rune.mesh = bm
			rune.material_override = gm
			var a := TAU * k / 6.0
			rune.position = Vector3(cos(a) * 1.28, 0.0, sin(a) * 1.28)
			rune.rotation.y = -a
			ring.add_child(rune)


func _build_pips() -> void:
	_pips = Node3D.new()
	_visual.add_child(_pips)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1, 0.8, 0.35)
	gold.emission_enabled = true
	gold.emission = Color(1, 0.7, 0.2)
	gold.emission_energy_multiplier = 0.6
	gold.metallic = 0.9
	gold.roughness = 0.3
	for i in level:
		var pip := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		pip.mesh = sm
		pip.material_override = gold
		pip.position = Vector3(-0.35 * (level - 1) * 0.5 + i * 0.35, 0.45, 1.5)
		_pips.add_child(pip)


func _make_range_ring() -> void:
	range_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.97
	t.outer_radius = 1.0
	t.rings = 64
	range_ring.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.85, 0.4, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	range_ring.material_override = m
	range_ring.visible = false
	range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(range_ring)


func show_range(v: bool) -> void:
	range_ring.visible = v
	range_ring.scale = Vector3(range_(), 0.02, range_())
	range_ring.position.y = 0.1
