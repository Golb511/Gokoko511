class_name AbilityZone
extends Node3D
## Persistent damaging area (poison cloud, blizzard, burning ground).

var battle: Node
var radius := 3.0
var duration := 5.0
var dps := 10.0
var dtype := "poison"
var status: Dictionary = {}
var _tick := 0.0
var _t := 0.0


func start(b: Node, pos: Vector3, r: float, dur: float, dmg_per_tick: float, dt: String, st: Dictionary, hero_dmg: float, elem: String) -> void:
	battle = b
	radius = r
	duration = dur
	dps = dmg_per_tick
	dtype = dt
	global_position = pos
	if not st.is_empty():
		status = st.duplicate()
		if st.id in ["burn", "poison"]:
			status.power = float(st.power) * hero_dmg
	VFX.cloud(b.fx_root, pos, r, elem, dur)


func _physics_process(delta: float) -> void:
	_t += delta
	_tick += delta
	if _tick >= 0.5:
		_tick -= 0.5
		for e in battle.enemies_near(global_position, radius):
			e.take_damage(dps * 0.5, dtype, null)
			if not status.is_empty():
				e.apply_status(status.id, float(status.duration), float(status.power))
	if _t >= duration:
		queue_free()
