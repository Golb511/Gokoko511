class_name Trap
extends Node3D
## Hidden spike/snare trap placed on the road by Trap Towers.

var battle: Node
var damage := 50.0
var splash := 0.0            # Tower Mastery: blast radius (0 = default 1.6 m)
var armor_pen := 0.0
var status: Dictionary = {}
var armed := true
var _spikes: MeshInstance3D


func setup(b: Node, pos: Vector3, dmg: float, st: Dictionary, col: Color) -> void:
	battle = b
	damage = dmg
	status = st
	global_position = pos
	var plate := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.7
	cyl.bottom_radius = 0.75
	cyl.height = 0.08
	plate.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.15, 0.13, 0.12)
	m.metallic = 0.8
	m.roughness = 0.4
	m.emission_enabled = true
	m.emission = col * 0.4
	plate.material_override = m
	add_child(plate)
	_spikes = MeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.07
	cone.height = 0.6
	mm.mesh = cone
	mm.instance_count = 9
	for i in 9:
		var a := TAU * i / 8.0
		var p := Vector3(cos(a), 0, sin(a)) * (0.45 if i < 8 else 0.0)
		mm.set_instance_transform(i, Transform3D(Basis(), p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.55, 0.5, 0.48)
	sm.metallic = 0.9
	sm.roughness = 0.3
	mmi.material_override = sm
	mmi.position.y = -0.35
	add_child(mmi)
	_spikes = null
	set_meta("spikes", mmi)


func _physics_process(_delta: float) -> void:
	if not armed:
		return
	for e in battle.enemies_near(global_position, 0.9):
		if not e.flying:
			_trigger()
			return


func _trigger() -> void:
	armed = false
	var spikes: Node3D = get_meta("spikes")
	var tw := create_tween()
	tw.tween_property(spikes, "position:y", 0.2, 0.08)
	for e in battle.enemies_near(global_position, maxf(1.6, splash)):
		if e.flying:
			continue
		e.take_damage(damage, "physical", self)
		if not status.is_empty():
			e.apply_status(status.id, float(status.duration), float(status.power))
	VFX.hit(battle.fx_root, global_position + Vector3(0, 0.4, 0), "physical")
	if splash > 1.6:
		VFX.explosion(battle.fx_root, global_position, splash, "fire")
	VFX.particles(battle.fx_root, global_position, {"amount": 14, "lifetime": 0.5, "speed": 3.0, "size": 0.2, "color": Color(0.7, 0.1, 0.05), "gravity": Vector3(0, -8, 0)})
	Sfx.play("slash", -6.0)
	tw.tween_interval(0.6)
	tw.tween_callback(queue_free)
