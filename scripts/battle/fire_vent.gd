class_name FireVent
extends Node3D
## Environmental hazard: a volcanic vent in the ground. It smoulders, glows as
## a warning, then erupts in a column of fire that burns everything standing
## on it — enemies, soldiers and the hero alike. Placed on roads so the player
## can time the hero around it and enemies take damage marching through.

const WARN := 1.3
const ERUPT := 1.1

var battle: Node
var radius := 1.9
var period := 9.0
var damage := 70.0
var _t := 0.0
var _state := "idle"
var _glow: MeshInstance3D
var _glow_mat: StandardMaterial3D
var _light: OmniLight3D
var _smoke: CPUParticles3D
var _hit_tick := 0.0


func setup(b: Node, cfg: Dictionary) -> void:
	battle = b
	radius = float(cfg.get("radius", 1.9))
	period = float(cfg.get("period", 9.0))
	damage = float(cfg.get("damage", 70.0))
	_t = float(cfg.get("offset", randf() * period))
	# Cracked basalt rim.
	for k in 6:
		var a := TAU * k / 6.0 + randf() * 0.4
		var r := ModelLib.prop("env/rock_single_" + ["A", "B", "C"][k % 3], Color(0.12, 0.09, 0.08), Color(1, 0.35, 0.05), 0.6)
		add_child(r)
		r.position = Vector3(cos(a), 0, sin(a)) * (radius + 0.25)
		r.scale = Vector3.ONE * randf_range(0.5, 0.8)
		r.rotation.y = randf() * TAU
	_glow = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.8
	cyl.bottom_radius = radius * 0.8
	cyl.height = 0.04
	cyl.radial_segments = 24
	_glow.mesh = cyl
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(0.1, 0.03, 0.01)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(1.0, 0.35, 0.04)
	_glow_mat.emission_energy_multiplier = 0.4
	_glow_mat.emission_texture = ModelLib.noise_tex("cell")
	_glow_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	_glow.material_override = _glow_mat
	_glow.position.y = 0.05
	add_child(_glow)
	_smoke = VFX.particles(self, global_position + Vector3(0, 0.3, 0), {"amount": 10, "lifetime": 2.4, "one_shot": false,
		"speed": 0.6, "size": 1.3, "size_end": 2.2, "color": Color(0.18, 0.15, 0.14), "additive": false, "radius": 0.5,
		"gravity": Vector3(0, 0.9, 0), "spread": 15.0, "explosiveness": 0.0})
	_smoke.position = Vector3(0, 0.3, 0)
	if GraphicsSettings.quality() >= 1:
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.4, 0.08)
		_light.light_energy = 0.4
		_light.omni_range = 6.0
		_light.position.y = 1.0
		add_child(_light)


## True while standing here is (or is about to be) dangerous.
func is_threat(p: Vector3, margin := 0.8) -> bool:
	if _state == "idle" and _t > 1.5:
		return false
	var d := p - global_position
	d.y = 0.0
	return d.length() < radius + margin


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
			_set_heat(0.9 + 0.25 * sin(Time.get_ticks_msec() * 0.003))
			if _t <= 0.0:
				_state = "warn"
				_t = WARN
				VFX.ground_ring(battle.fx_root, global_position + Vector3(0, 0.08, 0), radius, Color(1, 0.4, 0.05), WARN, false)
		"warn":
			_set_heat(lerpf(3.0, 0.5, _t / WARN))
			if _t <= 0.0:
				_state = "erupt"
				_t = ERUPT
				_hit_tick = 0.0
				_erupt_fx()
		"erupt":
			_set_heat(4.0)
			_hit_tick -= delta
			if _hit_tick <= 0.0:
				_hit_tick = 0.25
				_burn(damage * 0.25)
			if _t <= 0.0:
				_state = "idle"
				_t = maxf(1.0, period - WARN - ERUPT)


func _set_heat(v: float) -> void:
	_glow_mat.emission_energy_multiplier = v
	if _light:
		_light.light_energy = v * 1.2


func _erupt_fx() -> void:
	var col := VFX.particles(battle.fx_root, global_position, {"amount": 60, "lifetime": 0.9, "one_shot": false, "speed": 9.0,
		"size": 1.0, "size_end": 0.3, "color": Color(1.0, 0.45, 0.06), "radius": radius * 0.45, "gravity": Vector3(0, 2.0, 0),
		"spread": 8.0, "explosiveness": 0.0})
	col.emitting = true
	var tw := col.create_tween()
	tw.tween_interval(ERUPT)
	tw.tween_callback(func(): col.emitting = false)
	tw.tween_interval(1.0)
	tw.tween_callback(col.queue_free)
	VFX.particles(battle.fx_root, global_position + Vector3(0, 0.5, 0), {"amount": 18, "lifetime": 1.2, "speed": 6.0, "size": 0.25,
		"color": Color(1.0, 0.6, 0.15), "gravity": Vector3(0, -9.0, 0), "spread": 50.0})
	VFX.flash_light(battle.fx_root, global_position + Vector3(0, 2, 0), Color(1, 0.45, 0.1), 6.0, 9.0, ERUPT)
	Sfx.play("explosion", -14.0)


func _burn(amount: float) -> void:
	var hp_scale: float = battle.waves.hp_mult if battle.waves else 1.0
	for e in battle.enemies_near(global_position, radius):
		if not e.flying:
			e.take_damage(amount * hp_scale, "fire", null)
			e.apply_status("burn", 2.0, 8.0 * hp_scale)
	for a in battle.allies_near(global_position, radius):
		a.take_damage(amount, "fire", null)
