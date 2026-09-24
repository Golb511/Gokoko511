class_name RavenCircler
extends Node3D
## Decorative raven orbiting a landmark.

var center := Vector3.ZERO
var radius := 6.0
var phase := 0.0
var speed := 0.45
var bird: Node3D


func setup(c: Vector3, r: float, ph: float) -> void:
	center = c
	radius = r * randf_range(0.8, 1.2)
	phase = ph
	speed = randf_range(0.35, 0.6)
	bird = ProceduralCreatures.raven()
	bird.scale = Vector3.ONE * 1.6
	add_child(bird)


func _process(delta: float) -> void:
	phase += delta * speed
	var p := center + Vector3(cos(phase) * radius, sin(phase * 2.3) * 0.8, sin(phase) * radius)
	var nxt := center + Vector3(cos(phase + 0.1) * radius, 0, sin(phase + 0.1) * radius)
	global_position = p
	bird.look_at(Vector3(nxt.x, p.y, nxt.z), Vector3.UP)
	bird.rotate_object_local(Vector3.UP, PI)
