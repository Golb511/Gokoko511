class_name DragonSweep
extends Node3D
## Summoned dragon flight: follows the route backwards and scorches enemies.

var battle: Node
var route: PathRoute
var dps := 90.0
var duration := 6.0
var dragon: FlyingCreature
var flames: CPUParticles3D
var _t := 0.0
var _tick := 0.0
var _leaving := false
const FLY_H := 7.0


func start(b: Node, r: PathRoute, damage_per_sec: float, dur: float) -> void:
	battle = b
	route = r
	dps = damage_per_sec
	duration = dur
	dragon = ProceduralCreatures.dragon(1.3)
	add_child(dragon)
	dragon.global_position = route.sample(route.length) + Vector3(0, FLY_H + 6, 8)
	flames = VFX.particles(self, dragon.global_position, {"amount": 90, "lifetime": 0.7, "one_shot": false, "speed": 9.0, "size": 1.1, "color": Color(1, 0.45, 0.08), "direction": Vector3(0, -1, 0.6), "spread": 14.0, "gravity": Vector3(0, -4, 0)})
	var l := OmniLight3D.new()
	l.light_volumetric_fog_energy = 0.2
	l.light_color = Color(1, 0.5, 0.1)
	l.light_energy = 4.0
	l.omni_range = 14.0
	dragon.add_child(l)
	Sfx.play("boss", -2.0)


func _physics_process(delta: float) -> void:
	if dragon == null or _leaving:
		return
	_t += delta
	_tick += delta
	var k := clampf(_t / duration, 0.0, 1.0)
	var ground := route.sample(route.length * (1.0 - k))
	var target := ground + Vector3(0, FLY_H, 0)
	var prev := dragon.global_position
	dragon.global_position = prev.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
	var dir := target - prev
	dir.y = 0.0
	if dir.length() > 0.01:
		dragon.rotation.y = lerp_angle(dragon.rotation.y, atan2(dir.x, dir.z), clampf(delta * 4.0, 0.0, 1.0))
	if dragon.head:
		flames.global_position = dragon.head.global_position
		var fwd := dragon.global_transform.basis.z
		flames.direction = (Vector3(0, -1, 0) + fwd * 0.6).normalized()
	var burn_at := Vector3(dragon.global_position.x, 0.0, dragon.global_position.z) + dragon.global_transform.basis.z * 3.0
	if _tick >= 0.25:
		_tick = 0.0
		for e in battle.enemies_near(burn_at, 3.8):
			e.take_damage(dps * 0.25, "fire", null)
			e.apply_status("burn", 2.0, dps * 0.2)
		if randf() < 0.6:
			VFX.fire_pillar(battle.fx_root, burn_at, 1.5, false)
	if _t >= duration:
		_leaving = true
		flames.emitting = false
		var tw := create_tween()
		tw.tween_property(dragon, "global_position", dragon.global_position + Vector3(0, 22, -18), 1.4)
		tw.tween_callback(queue_free)
