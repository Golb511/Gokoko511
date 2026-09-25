class_name RootSnare
extends Node3D
## Environmental hazard of the Poison Forest: a nest of corrupted roots under
## the road. The ground heaves (warning), then thorned roots burst out and
## hold every ground unit in the circle in place for a moment — enemies and
## defenders alike — while the thorns draw blood.

const WARN := 1.4
const HOLD := 2.2

var battle: Node
var radius := 2.4
var period := 11.0
var damage := 30.0
var root_time := 2.0
var _t := 0.0
var _state := "idle"
var _spikes: Array[MeshInstance3D] = []
var _mound_mat: StandardMaterial3D


func setup(b: Node, cfg: Dictionary) -> void:
	battle = b
	radius = float(cfg.get("radius", 2.4))
	period = float(cfg.get("period", 11.0))
	damage = float(cfg.get("damage", 30.0))
	root_time = float(cfg.get("root", 2.0))
	_t = float(cfg.get("offset", randf() * period))
	# Gnarled mound of roots marking the spot.
	_mound_mat = StandardMaterial3D.new()
	_mound_mat.albedo_color = Color(0.16, 0.12, 0.08)
	_mound_mat.roughness = 0.9
	_mound_mat.emission_enabled = true
	_mound_mat.emission = Color(0.4, 1.0, 0.15)
	_mound_mat.emission_energy_multiplier = 0.15
	for k in 7:
		var a := TAU * k / 7.0 + randf() * 0.5
		var root := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = randf_range(0.14, 0.24)
		cm.height = radius * randf_range(0.8, 1.2)
		cm.radial_segments = 6
		root.mesh = cm
		root.material_override = _mound_mat
		add_child(root)
		root.position = Vector3(cos(a), 0.05, sin(a)) * radius * 0.45
		root.rotation = Vector3(PI / 2 - 0.12, -a + PI / 2, 0)
	var thorn := StandardMaterial3D.new()
	thorn.albedo_color = Color(0.14, 0.1, 0.07)
	thorn.roughness = 0.8
	thorn.emission_enabled = true
	thorn.emission = Color(0.5, 1.0, 0.2)
	thorn.emission_energy_multiplier = 0.6
	for k in 14:
		var sp := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = randf_range(0.12, 0.22)
		cm.height = randf_range(1.2, 2.2)
		cm.radial_segments = 5
		sp.mesh = cm
		sp.material_override = thorn
		add_child(sp)
		var a := randf() * TAU
		var r := sqrt(randf()) * radius * 0.9
		sp.position = Vector3(cos(a) * r, -cm.height * 0.5 - 0.1, sin(a) * r)
		sp.rotation = Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.35, 0.35))
		sp.visible = false
		_spikes.append(sp)


func is_threat(p: Vector3, margin := 0.8) -> bool:
	if _state == "idle" and _t > 1.2:
		return false
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() < radius + margin


func threat_center(_p: Vector3) -> Vector3:
	return global_position


func threat_radius() -> float:
	return radius


func _physics_process(delta: float) -> void:
	if battle == null or battle.ended:
		return
	_t -= delta
	match _state:
		"idle":
			if _t <= 0.0:
				_state = "warn"
				_t = WARN
				VFX.ground_ring(battle.fx_root, global_position + Vector3(0, 0.08, 0), radius, Color(0.5, 1.0, 0.2), WARN, false)
				VFX.particles(battle.fx_root, global_position + Vector3(0, 0.2, 0), {"amount": 22, "lifetime": 1.0, "speed": 1.4,
					"size": 0.35, "color": Color(0.3, 0.22, 0.12), "additive": false, "radius": radius * 0.8, "gravity": Vector3(0, -3, 0)})
		"warn":
			_mound_mat.emission_energy_multiplier = lerpf(1.6, 0.2, _t / WARN)
			if _t <= 0.0:
				_state = "hold"
				_t = HOLD
				_erupt()
		"hold":
			if _t <= 0.0:
				_state = "idle"
				_t = maxf(1.0, period - WARN - HOLD)
				_mound_mat.emission_energy_multiplier = 0.15
				for sp in _spikes:
					var tw := sp.create_tween()
					tw.tween_property(sp, "position:y", -(sp.mesh as CylinderMesh).height * 0.5 - 0.1, 0.35)
					tw.tween_callback(sp.hide)


func _erupt() -> void:
	for sp in _spikes:
		sp.visible = true
		var h := (sp.mesh as CylinderMesh).height
		var tw := sp.create_tween()
		tw.tween_property(sp, "position:y", h * 0.4, 0.12).set_ease(Tween.EASE_OUT)
	battle.shake(0.15, 0.2)
	Sfx.play("hit", -4.0)
	var hp_scale: float = battle.waves.hp_mult
	for e in battle.enemies_near(global_position, radius):
		if not e.flying:
			e.apply_status("root", root_time, 1.0)
			e.take_damage(damage * hp_scale, "physical", null)
	for a in battle.allies_near(global_position, radius):
		if not a.flying:
			a.apply_status("root", root_time, 1.0)
			a.take_damage(damage, "physical", null)
