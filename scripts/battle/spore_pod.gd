class_name SporePod
extends Node3D
## Environmental hazard: a giant glowing puffball beside the road. It swells
## for a few seconds, then bursts into a cloud of plague spores that lingers
## on the road, poisoning everything that walks through — both sides.

const SWELL := 2.0

var battle: Node
var period := 12.0
var cloud := {}
var _t := 0.0
var _swelling := false
var _cap: MeshInstance3D
var _cap_mat: StandardMaterial3D
var _base_scale := Vector3.ONE


func setup(b: Node, cfg: Dictionary) -> void:
	battle = b
	period = float(cfg.get("period", 12.0))
	_t = float(cfg.get("offset", randf() * period))
	cloud = {"radius": float(cfg.get("radius", 2.8)), "duration": float(cfg.get("duration", 4.0)),
		"ally_dps": float(cfg.get("ally_dps", 14.0)), "enemy_dps": float(cfg.get("enemy_dps", 10.0))}
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.35
	sm.bottom_radius = 0.55
	sm.height = 1.0
	stem.mesh = sm
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.3, 0.3, 0.22)
	stem_mat.roughness = 0.8
	stem.material_override = stem_mat
	stem.position.y = 0.5
	add_child(stem)
	_cap = MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 1.1
	cm.height = 1.6
	_cap.mesh = cm
	_cap_mat = StandardMaterial3D.new()
	_cap_mat.albedo_color = Color(0.2, 0.3, 0.1)
	_cap_mat.roughness = 0.5
	_cap_mat.emission_enabled = true
	_cap_mat.emission = Color(0.5, 1.0, 0.2)
	_cap_mat.emission_energy_multiplier = 0.6
	_cap_mat.emission_texture = ModelLib.noise_tex("cell")
	_cap_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	_cap.material_override = _cap_mat
	_cap.position.y = 1.35
	add_child(_cap)
	_base_scale = _cap.scale
	VFX.particles(self, global_position + Vector3(0, 1.6, 0), {"amount": 6, "lifetime": 2.5, "one_shot": false, "speed": 0.3,
		"size": 0.12, "color": Color(0.6, 1.0, 0.3), "radius": 0.9, "gravity": Vector3(0, 0.4, 0), "explosiveness": 0.0}).position = Vector3(0, 1.6, 0)
	if GraphicsSettings.quality() >= 1:
		var l := OmniLight3D.new()
		l.light_color = Color(0.5, 1.0, 0.2)
		l.light_energy = 1.3
		l.omni_range = 5.0
		l.position.y = 1.6
		add_child(l)


func is_threat(p: Vector3, margin := 0.6) -> bool:
	return _swelling and Vector2(p.x - global_position.x, p.z - global_position.z).length() < float(cloud.radius) + margin


func threat_center(_p: Vector3) -> Vector3:
	return global_position


func threat_radius() -> float:
	return float(cloud.radius)


func _physics_process(delta: float) -> void:
	if battle == null or battle.ended:
		return
	_t -= delta
	if not _swelling and _t <= SWELL:
		_swelling = true
	if _swelling:
		var k := clampf(1.0 - _t / SWELL, 0.0, 1.0)
		_cap.scale = _base_scale * (1.0 + 0.35 * k + 0.05 * sin(Time.get_ticks_msec() * 0.02) * k)
		_cap_mat.emission_energy_multiplier = 0.6 + 2.5 * k
	if _t <= 0.0:
		_swelling = false
		_t = period
		_cap.scale = _base_scale * 0.6
		_cap.create_tween().tween_property(_cap, "scale", _base_scale, 3.0)
		_cap_mat.emission_energy_multiplier = 0.4
		VFX.particles(battle.fx_root, global_position + Vector3(0, 1.4, 0), {"amount": 40, "lifetime": 1.0, "speed": 5.0,
			"size": 0.5, "color": Color(0.55, 1.0, 0.2), "gravity": Vector3(0, -2.0, 0)})
		Sfx.play("explosion", -16.0)
		ToxicCloud.spawn(battle, global_position, cloud)
