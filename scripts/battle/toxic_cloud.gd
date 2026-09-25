class_name ToxicCloud
extends Node3D
## A lingering cloud of plague spores. It poisons the defenders standing in it
## (hero and soldiers) and can also poison enemies or knit their wounds —
## used by spore pods, dying Spore Bearers and the Plague Colossus.

var battle: Node
var radius := 2.5
var duration := 4.0
var ally_dps := 12.0         # poison applied to hero / soldiers
var enemy_dps := 0.0         # poison applied to enemies (spore pods hurt both sides)
var enemy_heal := 0.0        # fraction of max hp healed per second for enemies
var _t := 0.0
var minor := true            # the AUTO hero only avoids it when badly hurt
var _tick := 0.0
var _disc: MeshInstance3D


static func spawn(b: Node, pos: Vector3, cfg: Dictionary) -> ToxicCloud:
	var c := ToxicCloud.new()
	c.name = "ToxicCloud"
	b.fx_root.add_child(c)
	c.global_position = Vector3(pos.x, 0, pos.z)
	c.setup(b, cfg)
	# Registered as a hazard so the AUTO hero steps out of it.
	b.level.hazards = b.level.hazards.filter(func(h): return is_instance_valid(h))
	b.level.hazards.append(c)
	return c


func setup(b: Node, cfg: Dictionary) -> void:
	battle = b
	radius = float(cfg.get("radius", 2.5))
	duration = float(cfg.get("duration", 4.0))
	ally_dps = float(cfg.get("ally_dps", 12.0))
	enemy_dps = float(cfg.get("enemy_dps", 0.0))
	enemy_heal = float(cfg.get("enemy_heal", 0.0))
	var col := Color(0.45, 1.0, 0.15)
	_disc = VFX.area_disc(self, global_position, radius, Color(col.r, col.g, col.b, 0.45))
	var smoke := VFX.particles(self, global_position + Vector3(0, 0.6, 0), {"amount": 26, "lifetime": 1.8, "one_shot": false,
		"speed": 0.5, "size": radius * 0.9, "size_end": 1.3, "color": Color(0.3, 0.55, 0.12), "additive": false,
		"box": Vector3(radius * 0.7, 0.3, radius * 0.7), "gravity": Vector3(0, 0.35, 0), "explosiveness": 0.0})
	smoke.local_coords = false
	VFX.particles(self, global_position + Vector3(0, 0.3, 0), {"amount": 16, "lifetime": 1.2, "one_shot": false, "speed": 0.6,
		"size": 0.14, "color": col, "box": Vector3(radius * 0.8, 0.2, radius * 0.8), "gravity": Vector3(0, 1.0, 0), "explosiveness": 0.0})
	if GraphicsSettings.quality() >= 1:
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.4
		l.omni_range = radius * 2.2
		l.position.y = 1.0
		add_child(l)


func is_threat(p: Vector3, margin := 0.6) -> bool:
	return ally_dps > 0.0 and Vector2(p.x - global_position.x, p.z - global_position.z).length() < radius + margin


func threat_center(_p: Vector3) -> Vector3:
	return global_position


func threat_radius() -> float:
	return radius


func _physics_process(delta: float) -> void:
	if battle == null or battle.ended:
		return
	_t += delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		for a in battle.allies_near(global_position, radius):
			if not a.flying and ally_dps > 0.0:
				a.apply_status("poison", 1.2, ally_dps)
		for e in battle.enemies_near(global_position, radius):
			if e.flying:
				continue
			if enemy_dps > 0.0:
				e.apply_status("poison", 1.2, enemy_dps * battle.waves.hp_mult)
			if enemy_heal > 0.0 and e.hp_ratio() < 1.0 and not e.tags.has("boss"):
				e.heal(e.max_hp * enemy_heal * 0.5)
	if _t >= duration:
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_property(_disc, "scale", Vector3(0.01, 1, 0.01), 0.5)
		tw.tween_callback(queue_free)
