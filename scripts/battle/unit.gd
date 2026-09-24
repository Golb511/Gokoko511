class_name Unit
extends Node3D
## Base combat unit: health, mitigation, status effects, model & health bar.
## Enemies, allied soldiers, summons and heroes all derive from this.

signal died(unit: Unit)
signal damaged(unit: Unit, amount: float)

enum Team { PLAYER, ENEMY }

var battle: Node          # BattleController
var team: int = Team.ENEMY
var unit_id := ""
var max_hp := 100.0
var hp := 100.0
var armor := 0.0          # physical reduction 0..0.9
var mres := 0.0           # magical reduction 0..0.9
var base_speed := 2.0
var damage_min := 1.0
var damage_max := 2.0
var attack_rate := 1.0    # attacks per second
var attack_range := 1.3
var radius := 0.45
var flying := false
var tags: Array = []
var alive := true
var model: CharacterModel
var hp_bar: HealthBar3D
var statuses: Dictionary = {}     # id -> {"t": remaining, "p": power, "tick": acc}
var buffs: Dictionary = {}        # id -> {"t": remaining, "stat": name, "mult": value}
var cc_resist := 0.0
var stealthed := false
var attack_cd := 0.0
var bar_height := 2.1


func _init_unit(b: Node, t: int) -> void:
	battle = b
	team = t


func setup_model(def: Dictionary) -> void:
	model = ModelLib.character(def)
	add_child(model)
	var s := float(def.get("scale", 1.0))
	bar_height = 1.75 * s + 0.3
	radius = 0.4 * s
	var col := Color(0.85, 0.15, 0.1) if team == Team.ENEMY else Color(0.3, 0.85, 0.3)
	hp_bar = HealthBar3D.make(0.9 + 0.25 * s, col, bar_height)
	add_child(hp_bar)
	hp_bar.set_fill(1.0)


func is_valid_target() -> bool:
	return alive and not stealthed and is_inside_tree()


func hp_ratio() -> float:
	return hp / maxf(1.0, max_hp)


# ---------------------------------------------------------------- damage
func mitigation(dmg_type: String) -> float:
	var ab := float(statuses.get("armor_break", {}).get("p", 0.0))
	if dmg_type == "true":
		return 0.0
	if dmg_type == "physical":
		return clampf(armor * _buff_mult("armor") + _buff_add("armor") - ab, 0.0, 0.9)
	return clampf(mres - ab * 0.5, 0.0, 0.9)


## Returns actual damage dealt.
func take_damage(amount: float, dmg_type: String = "physical", source: Node = null, crit := false) -> float:
	if not alive:
		return 0.0
	var dealt := amount * (1.0 - mitigation(dmg_type))
	if statuses.has("freeze") and dmg_type == "physical":
		dealt *= 1.2
	hp -= dealt
	damaged.emit(self, dealt)
	if battle and team == Team.ENEMY:
		var key := "other"
		if source is Hero: key = "hero"
		elif source is Tower: key = "tower_" + source.tower_id
		elif source is AllyUnit: key = "ally"
		battle.damage_log[key] = float(battle.damage_log.get(key, 0.0)) + dealt
	if model:
		model.flash()
	if hp_bar:
		hp_bar.set_fill(hp_ratio())
	if battle and battle.show_damage_numbers and dealt >= 1.0:
		var col := Color(1, 0.9, 0.7) if team == Team.ENEMY else Color(1, 0.35, 0.3)
		if crit:
			col = Color(1, 0.55, 0.1)
		FloatingText.spawn(battle.fx_root, global_position + Vector3(0, bar_height, 0), str(int(dealt)) + ("!" if crit else ""), col, 64 if crit else 44)
	if hp <= 0.0:
		die(source)
	return dealt


func heal(amount: float) -> void:
	if not alive:
		return
	hp = minf(max_hp, hp + amount)
	if hp_bar:
		hp_bar.set_fill(hp_ratio())


func die(_source: Node = null) -> void:
	if not alive:
		return
	alive = false
	hp = 0.0
	if hp_bar:
		hp_bar.visible = false
	died.emit(self)
	_on_death()


func _on_death() -> void:
	if model:
		model.play_action("death", 1.0)
		model.dissolve_out(1.4)
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(queue_free)


# ---------------------------------------------------------------- statuses
func apply_status(id: String, duration: float, power: float, _source: Node = null) -> void:
	if not alive:
		return
	if id in ["stun", "freeze", "root", "fear"]:
		duration *= (1.0 - cc_resist)
		if tags.has("boss"):
			duration *= 0.35
	if duration <= 0.05:
		return
	var cur: Dictionary = statuses.get(id, {})
	if cur.is_empty() or float(cur.p) <= power or float(cur.t) < duration:
		statuses[id] = {"t": maxf(duration, float(cur.get("t", 0.0))), "p": maxf(power, float(cur.get("p", 0.0))), "tick": 0.0}
	if model:
		if id == "freeze":
			model.set_param("frozen", 1.0)
		elif id == "poison":
			model.set_param("poisoned", 1.0)


func add_buff(id: String, stat: String, mult: float, duration: float) -> void:
	buffs[id] = {"t": duration, "stat": stat, "mult": mult}


func _buff_mult(stat: String) -> float:
	var m := 1.0
	for b in buffs.values():
		if b.stat == stat:
			m *= float(b.mult)
	return m


func _buff_add(stat: String) -> float:
	var a := 0.0
	for b in buffs.values():
		if b.stat == stat + "_add":
			a += float(b.mult)
	return a


func tick_statuses(delta: float) -> void:
	for id in statuses.keys():
		var s: Dictionary = statuses[id]
		s.t = float(s.t) - delta
		if id == "burn" or id == "poison":
			s.tick = float(s.tick) + delta
			if float(s.tick) >= 0.5:
				s.tick = float(s.tick) - 0.5
				take_damage(float(s.p) * 0.5, "fire" if id == "burn" else "poison", null)
				if not alive:
					return
				if id == "burn" and randf() < 0.5:
					VFX.particles(battle.fx_root, global_position + Vector3(0, 1, 0), {"amount": 4, "lifetime": 0.5, "speed": 1.0, "size": 0.3, "color": Color(1, 0.4, 0.05), "gravity": Vector3(0, 3, 0)})
		if float(s.t) <= 0.0:
			statuses.erase(id)
			if model:
				if id == "freeze":
					model.set_param("frozen", 0.0)
				elif id == "poison":
					model.set_param("poisoned", 0.0)
	for id in buffs.keys():
		buffs[id].t = float(buffs[id].t) - delta
		if float(buffs[id].t) <= 0.0:
			buffs.erase(id)


func is_disabled() -> bool:
	return statuses.has("stun") or statuses.has("freeze")


func is_immobile() -> bool:
	return is_disabled() or statuses.has("root")


func speed_mult() -> float:
	var m := 1.0
	if statuses.has("slow"):
		m *= 1.0 - clampf(float(statuses.slow.p), 0.0, 0.85)
	m *= _buff_mult("speed")
	return m


func damage_mult() -> float:
	var m := _buff_mult("damage")
	if statuses.has("weaken"):
		m *= 1.0 - float(statuses.weaken.p)
	return m


func roll_damage() -> float:
	return randf_range(damage_min, damage_max) * damage_mult()


func attack_miss() -> bool:
	return statuses.has("blind") and randf() < float(statuses.blind.p)
