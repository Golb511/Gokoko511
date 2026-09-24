class_name LightningStorm
extends Node
## Distant storm: random sky flashes with forked bolts beyond the battlefield.

var lb: LevelBuilder
var color := Color(0.8, 0.6, 1.0)
var sun: DirectionalLight3D
var _t := 3.0
var _base := 1.0


func setup(builder: LevelBuilder, c: Color) -> void:
	lb = builder
	color = c
	for n in lb.root.get_children():
		if n is DirectionalLight3D:
			sun = n
			_base = sun.light_energy


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = randf_range(4.0, 9.0)
	var b := lb.bounds
	var ground := Vector3(randf_range(b.position.x - 10, b.end.x + 10), 0, b.position.y - randf_range(12, 30))
	var top := ground + Vector3(randf_range(-6, 6), 45, randf_range(-8, 0))
	VFX.lightning(lb.root, top, ground, color, 0.6, 0.35)
	if randf() < 0.5:
		VFX.lightning(lb.root, top, ground + Vector3(randf_range(-10, 10), 0, randf_range(-5, 5)), color, 0.35, 0.25)
	if sun:
		var tw := sun.create_tween()
		sun.light_energy = _base * 2.4
		tw.tween_property(sun, "light_energy", _base, 0.45)
	Sfx.play("lightning", -16.0)
