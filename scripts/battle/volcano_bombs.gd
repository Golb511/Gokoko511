class_name VolcanoBombs
extends Node3D
## The erupting volcano hurls molten bombs onto the roads. Each landing spot is
## marked on the ground first, so the player (and the AUTO hero) can react;
## the blast burns every ground unit in the radius, friend or foe.

var battle: Node
var level: LevelBuilder
var crater := Vector3.ZERO
var interval := 9.0
var damage := 80.0
var radius := 2.3
var _t := 5.0
var _pending: Array = []     # landing spots currently marked [Vector3]


func setup(b: Node, lb: LevelBuilder, crater_pos: Vector3, cfg: Dictionary) -> void:
	battle = b
	level = lb
	crater = crater_pos
	interval = float(cfg.get("interval", 9.0))
	damage = float(cfg.get("damage", 80.0))
	radius = float(cfg.get("radius", 2.3))
	_t = interval * 0.6


func is_threat(p: Vector3, margin := 0.8) -> bool:
	for t in _pending:
		if Vector2(p.x - t.x, p.z - t.z).length() < radius + margin:
			return true
	return false


func threat_center(p: Vector3) -> Vector3:
	for t in _pending:
		if Vector2(p.x - t.x, p.z - t.z).length() < radius + 0.8:
			return t
	return p


func threat_radius() -> float:
	return radius


func _physics_process(delta: float) -> void:
	if battle == null or battle.ended or battle.waves == null or battle.waves.current < 0:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = interval * randf_range(0.8, 1.2)
	var routes := level.ground_routes()
	var r: PathRoute = routes[randi() % routes.size()]
	# Aim at the busiest stretch of road: near an enemy if one is marching.
	var target := r.sample(randf_range(r.length * 0.15, r.length * 0.85))
	var marching: Array = battle.enemies.filter(func(e): return is_instance_valid(e) and e.alive and not e.flying)
	if not marching.is_empty() and randf() < 0.7:
		var e: Enemy = marching[randi() % marching.size()]
		target = e.route.sample(e.progress + e.base_speed * 2.2)
	target.y = 0.0
	_launch(target)


func _launch(target: Vector3) -> void:
	var flight := 2.0
	_pending.append(target)
	var mark := VFX.area_disc(battle.fx_root, target + Vector3(0, 0.06, 0), radius, Color(1.0, 0.35, 0.05, 0.5))
	VFX.ground_ring(battle.fx_root, target + Vector3(0, 0.08, 0), radius, Color(1, 0.4, 0.05), flight, false)
	var bomb := Node3D.new()
	battle.fx_root.add_child(bomb)
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.55
	s.height = 1.1
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.06, 0.02)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.4, 0.05)
	m.emission_energy_multiplier = 3.0
	m.emission_texture = ModelLib.noise_tex("cell")
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mi.material_override = m
	bomb.add_child(mi)
	var trail := VFX.particles(bomb, crater, {"amount": 24, "lifetime": 0.7, "one_shot": false, "speed": 0.4, "size": 0.9,
		"size_end": 0.1, "color": Color(1, 0.45, 0.1), "radius": 0.3, "gravity": Vector3(0, 0.5, 0), "explosiveness": 0.0})
	trail.position = Vector3.ZERO
	var from := crater
	var tw := bomb.create_tween()
	tw.tween_method(func(t: float):
		var p := from.lerp(target, t)
		p.y = lerpf(from.y, target.y, t) + sin(t * PI) * 18.0
		bomb.global_position = p, 0.0, 1.0, flight)
	tw.tween_callback(func():
		_pending.erase(target)
		_impact(target)
		if is_instance_valid(mark):
			mark.queue_free()
		bomb.queue_free())


func _impact(p: Vector3) -> void:
	VFX.explosion(battle.fx_root, p, radius, "fire")
	VFX.particles(battle.fx_root, p + Vector3(0, 0.4, 0), {"amount": 26, "lifetime": 1.4, "speed": 7.0, "size": 0.3,
		"color": Color(1.0, 0.55, 0.12), "gravity": Vector3(0, -12.0, 0), "spread": 60.0})
	battle.shake(0.25, 0.3)
	Sfx.play("explosion", -8.0)
	var hp_scale: float = battle.waves.hp_mult
	for e in battle.enemies_near(p, radius):
		if not e.flying:
			e.take_damage(damage * hp_scale, "fire", null)
			e.apply_status("burn", 3.0, 10.0 * hp_scale)
	for a in battle.allies_near(p, radius):
		a.take_damage(damage * 0.8, "fire", null)
	# A cooling scorch mark stays for a while.
	var scorch := VFX.area_disc(battle.fx_root, p + Vector3(0, 0.04, 0), radius * 0.8, Color(0.9, 0.25, 0.03, 0.35))
	var tw := scorch.create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(scorch.queue_free)
