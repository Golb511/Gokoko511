class_name Projectile
extends Node3D
## Homing or ballistic projectile with elemental visuals, splash, pierce and
## on-hit effects (status, crit, stun, freeze, instakill, burning ground).

var battle: Node
var p: Dictionary
var target: Unit = null
var target_pos := Vector3.ZERO
var speed := 18.0
var team := Unit.Team.PLAYER
var start := Vector3.ZERO
var flight := 0.0
var t := 0.0
var arc := 0.0
var pierce_left := 0
var pierce_dir := Vector3.ZERO
var _hit_list: Array = []
var _visual: Node3D
var _done := false


func setup(b: Node, from: Vector3, tgt: Unit, params: Dictionary) -> void:
	battle = b
	p = params
	target = tgt
	team = int(params.get("team", Unit.Team.PLAYER))
	speed = float(params.get("speed", 18.0))
	start = from
	global_position = from
	target_pos = params.get("target_pos", tgt.global_position + Vector3(0, 1.0, 0) if tgt else from)
	arc = float(params.get("arc", 0.0))
	pierce_left = int(params.get("pierce", 0))
	flight = maxf(0.08, start.distance_to(target_pos) / speed)
	_visual = ProjectileVisuals.make(params.get("type", "arrow"))
	add_child(_visual)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if pierce_left > 0 and pierce_dir != Vector3.ZERO:
		_pierce_flight(delta)
		return
	t += delta
	if arc == 0.0:
		# Homing: steer straight at the (moving) target at constant speed.
		if target != null and is_instance_valid(target) and target.alive:
			target_pos = target.global_position + Vector3(0, 1.0 if not target.flying else 0.4, 0)
		var to := target_pos - global_position
		var step := speed * delta
		if to.length() <= maxf(step, 0.25) or t > 4.0:
			global_position = target_pos
			_impact()
			return
		var dir := to.normalized()
		global_position += dir * step
		_visual.look_at(global_position + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
		return
	var k := clampf(t / flight, 0.0, 1.0)
	var pos := start.lerp(target_pos, k)
	if arc > 0.0:
		pos.y += sin(k * PI) * arc
	var prev := global_position
	global_position = pos
	var vel := pos - prev
	if vel.length_squared() > 0.00001:
		_visual.look_at(global_position + vel, Vector3.UP if absf(vel.normalized().y) < 0.99 else Vector3.RIGHT)
	if k >= 1.0:
		_impact()


func _pierce_flight(delta: float) -> void:
	global_position += pierce_dir * speed * delta
	t += delta
	for e in battle.enemies_near(global_position, 1.0):
		if e in _hit_list or e.flying:
			continue
		_hit_list.append(e)
		_damage(e, 1.0)
		pierce_left -= 1
		if pierce_left <= 0:
			break
	if pierce_left <= 0 or t > 2.5 or not battle.in_bounds(global_position):
		queue_free()


func _impact() -> void:
	var dmg := float(p.get("damage", 0.0))
	var splash := float(p.get("splash", 0.0))
	var elem: String = p.get("dmg_type", "physical")
	if dmg > 0.0:
		if splash > 0.0:
			var victims: Array = battle.enemies_near(target_pos, splash) if team == Unit.Team.PLAYER else battle.allies_near(target_pos, splash)
			for v in victims:
				if bool(p.get("ground_only", false)) and v.flying:
					continue
				_damage(v, 1.0 if v == target else 0.75)
			VFX.explosion(battle.fx_root, Vector3(target_pos.x, 0.0, target_pos.z), splash, _vfx_elem(elem))
			if p.has("ground_fire"):
				var gf: Dictionary = p.ground_fire
				var zone := AbilityZone.new()
				battle.fx_root.add_child(zone)
				zone.start(battle, Vector3(target_pos.x, 0, target_pos.z), splash * 0.8, float(gf.duration), float(gf.dps), "fire", {}, 0.0, "fire")
			Sfx.play("explosion", -10.0)
		elif target != null and is_instance_valid(target) and target.alive:
			_damage(target, 1.0)
			VFX.hit(battle.fx_root, target_pos, _vfx_elem(elem))
	if pierce_left > 0:
		_hit_list.append(target)
		pierce_dir = (target_pos - start)
		pierce_dir.y = 0.0
		pierce_dir = pierce_dir.normalized()
		t = 0.0
		return
	_done = true
	queue_free()


func _vfx_elem(elem: String) -> String:
	return "fire" if elem == "physical" and p.get("type", "") == "bomb" else elem


func _damage(v: Unit, mult: float) -> void:
	if not is_instance_valid(v) or not v.alive:
		return
	var dmg := float(p.get("damage", 0.0)) * mult
	var bonus_vs: String = p.get("bonus_vs", "")
	if bonus_vs != "" and v.tags.has(bonus_vs):
		dmg *= 1.5
	if bool(p.get("flying_bonus", false)) and v.flying:
		dmg *= float(p.get("air_bonus", 2.0))
	var inst := float(p.get("instakill", 0.0))
	if inst > 0.0 and randf() < inst and not v.tags.has("boss") and not v.tags.has("elite"):
		v.take_damage(v.hp + 1.0, "true", p.get("source"), true)
		VFX.shadow_burst(battle.fx_root, v.global_position, 1.2)
		return
	var bs: Dictionary = p.get("bonus_status", {})
	if not bs.is_empty() and v.statuses.has(bs.id):
		dmg *= float(bs.mult)
	var src = p.get("source")
	var dealt := v.take_damage(dmg, p.get("dmg_type", "physical"), src if is_instance_valid(src) else null, bool(p.get("crit", false)))
	var ex := float(p.get("execute", 0.0))
	if ex > 0.0 and v.alive and not v.tags.has("boss") and v.hp_ratio() <= ex:
		# Tower Mastery execute: finishes off wounded non-boss enemies.
		v.take_damage(v.hp + 1.0, "true", src if is_instance_valid(src) else null, true)
		VFX.shadow_burst(battle.fx_root, v.global_position, 1.0)
		return
	if float(p.get("lifesteal", 0.0)) > 0.0 and is_instance_valid(src) and src is Unit:
		src.heal(dealt * float(p.lifesteal))
	var st: Dictionary = p.get("status", {})
	if not st.is_empty():
		v.apply_status(st.id, float(st.duration), float(st.power), src)
	if randf() < float(p.get("freeze_chance", 0.0)):
		v.apply_status("freeze", 1.5, 1.0)
	if randf() < float(p.get("stun_chance", 0.0)):
		v.apply_status("stun", 1.0, 1.0)
	for xs in p.get("extra_status", []):
		v.apply_status(xs.id, float(xs.duration), float(xs.power), src)
	if randf() < float(p.get("fear_chance", 0.0)) and not v.tags.has("boss"):
		v.apply_status("fear", 1.5, 1.0)
