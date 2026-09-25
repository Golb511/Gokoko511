class_name GlobalAbilities
extends Node
## Player-wide powers: Meteor, Freeze, Tower Fury and Summon Dragon.

var battle: Node
var cooldowns := {}
var order := ["meteor", "freeze", "tower_buff", "summon_dragon"]


func setup(b: Node) -> void:
	battle = b
	for id in order:
		cooldowns[id] = float(DB.cfg.global_abilities[id].cooldown) * 0.35


func _physics_process(delta: float) -> void:
	for k in cooldowns:
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - delta)


func def(id: String) -> Dictionary:
	return DB.cfg.global_abilities[id]


func is_unlocked(id: String) -> bool:
	var s: String = def(id).get("unlock_stage", "")
	return s == "" or Game.stage_stars(s) > 0 or Game.current_stage == s


func can_use(id: String) -> bool:
	return is_unlocked(id) and float(cooldowns.get(id, 0.0)) <= 0.0


func needs_target(id: String) -> bool:
	return def(id).target == "point"


func use(id: String, point: Vector3) -> bool:
	if not can_use(id):
		return false
	var d := def(id)
	match id:
		"meteor":
			_meteor(point, d)
		"freeze":
			_freeze(point, d)
		"tower_buff":
			for t in battle.towers:
				t.add_buff("fury", float(d.mult), float(d.duration))
				VFX.level_up(battle.fx_root, t.global_position)
			Sfx.play("levelup", 0.0)
		"summon_dragon":
			summon_dragon(float(d.damage), float(d.duration))
	cooldowns[id] = float(d.cooldown)
	Events.track("global_used")
	return true


func _meteor(point: Vector3, d: Dictionary) -> void:
	var r := float(d.radius)
	var tele := VFX.area_disc(battle.fx_root, point, r, Color(1, 0.35, 0.05))
	var from := point + Vector3(-8, 26, -10)
	var rock := Node3D.new()
	battle.fx_root.add_child(rock)
	rock.global_position = from
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.1
	sm.height = 2.0
	mi.mesh = sm
	var mat := ModelLib.char_material(ModelLib.gradient_tex([Color(0.1, 0.05, 0.03), Color(0.3, 0.1, 0.03)], "meteor"), {"tint": [0.4, 0.4, 0.4], "stone": true, "emission": [1, 0.4, 0.05], "emission_strength": 4.0})
	mi.material_override = mat
	rock.add_child(mi)
	VFX.particles(rock, from, {"amount": 60, "lifetime": 0.6, "one_shot": false, "speed": 1.0, "size": 1.4, "color": Color(1, 0.4, 0.05), "radius": 0.8, "gravity": Vector3(0, 2, 0)})
	var l := OmniLight3D.new()
	l.light_volumetric_fog_energy = 0.2
	l.light_color = Color(1, 0.5, 0.1)
	l.light_energy = 5.0
	l.omni_range = 12.0
	rock.add_child(l)
	var tw := rock.create_tween()
	tw.tween_property(rock, "global_position", point, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		if is_instance_valid(tele): tele.queue_free()
		rock.queue_free()
		VFX.explosion(battle.fx_root, point, r * 1.2, "fire")
		battle.shake(0.7, 0.6)
		Sfx.play("explosion", 3.0)
		var st: Dictionary = d.status
		for e in battle.enemies_near(point, r):
			e.take_damage(float(d.damage) * (1.0 + 0.08 * DB.stage_order.find(Game.current_stage)), "fire", null)
			e.apply_status(st.id, float(st.duration), float(st.power))
		var zone := AbilityZone.new()
		battle.fx_root.add_child(zone)
		zone.start(battle, point, r * 0.7, 4.0, 20.0, "fire", {}, 0.0, "fire"))


func _freeze(point: Vector3, d: Dictionary) -> void:
	var r := float(d.radius)
	VFX.nova(battle.fx_root, point, r, "ice")
	VFX.particles(battle.fx_root, point + Vector3(0, 0.5, 0), {"amount": 80, "lifetime": 1.5, "speed": 2.0, "size": 0.35, "color": Color(0.7, 0.9, 1.0), "radius": r * 0.8, "gravity": Vector3(0, 1, 0)})
	Sfx.play("freeze", 3.0)
	var st: Dictionary = d.status
	for e in battle.enemies_near(point, r):
		e.take_damage(float(d.damage), "ice", null)
		e.apply_status("freeze", float(st.duration), 1.0)


## A dragon sweeps along the enemy route from the citadel toward the spawn,
## breathing fire on enemies beneath it.
func summon_dragon(dps: float, duration: float) -> void:
	Events.track("dragons_summoned")
	var sweep := DragonSweep.new()
	battle.fx_root.add_child(sweep)
	sweep.start(battle, battle.routes[0], dps, duration)
