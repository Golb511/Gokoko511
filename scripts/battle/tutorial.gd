class_name TutorialDirector
extends Node
## First-battle guided tutorial: build, build again, start, move hero, use an
## ability, upgrade. Each step shows a hint panel and a bouncing 3D marker, and
## advances on the real gameplay event (never pauses the game).

var battle: BattleController
var step := -1
var panel: PanelContainer
var text: Label
var marker: Node3D
var _towers_built := 0
var _t := 0.0

const STEPS := ["tut.build", "tut.build2", "tut.start", "tut.move", "tut.ability", "tut.upgrade", "tut.done"]


func setup(b: BattleController) -> void:
	battle = b
	panel = UITheme.panel(Color(0.05, 0.03, 0.02, 0.94), UITheme.GOLD, 14)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 96
	panel.custom_minimum_size = Vector2(620, 0)
	battle.hud.root.add_child(panel)
	var h := UITheme.hbox(12)
	panel.add_child(h)
	h.add_child(Icon.make("scroll", UITheme.GOLD, 48))
	var v := UITheme.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UITheme.label(tr("tut.title"), 16, UITheme.GOLD, true))
	text = UITheme.label("", 20, UITheme.TEXT, true)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(460, 0)
	v.add_child(text)
	h.add_child(UITheme.button(tr("tut.skip"), _finish, 16, 90, 44))
	marker = _make_marker()
	battle.fx_root.add_child(marker)
	Events.tower_built.connect(func(_t): _towers_built += 1; _on_event("build"))
	Events.wave_started.connect(func(_i, _n): _on_event("start"))
	battle.hero.commanded.connect(func(_p): _on_event("move"))
	Events.stat_tracked.connect(func(s, _a): if s == "abilities_used": _on_event("ability"))
	Events.tower_upgraded.connect(func(_t): _on_event("upgrade"))
	battle.hud.show_hint("")
	_go(0)


func _make_marker() -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.9, 1.2, 0.25)
	mi.mesh = pm
	mi.rotation.z = PI
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.8, 0.3)
	m.emission_enabled = true
	m.emission = Color(1, 0.7, 0.2)
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	root.add_child(mi)
	var l := OmniLight3D.new()
	l.light_volumetric_fog_energy = 0.2
	l.light_color = Color(1, 0.75, 0.3)
	l.light_energy = 2.0
	l.omni_range = 5.0
	root.add_child(l)
	return root


func _go(i: int) -> void:
	step = i
	if step >= STEPS.size():
		_finish()
		return
	text.text = tr(STEPS[step])
	panel.modulate = Color(1.4, 1.3, 1.0)
	panel.create_tween().tween_property(panel, "modulate", Color.WHITE, 0.5)
	Sfx.play("click", 0.0)
	if STEPS[step] == "tut.done":
		marker.visible = false
		get_tree().create_timer(5.0, false).timeout.connect(_finish)


func _on_event(kind: String) -> void:
	if step < 0 or step >= STEPS.size():
		return
	var cur: String = STEPS[step]
	var ok := false
	match cur:
		"tut.build":
			ok = kind == "build"
		"tut.build2":
			ok = kind == "build" and _towers_built >= 2
		"tut.start":
			ok = kind == "start"
		"tut.move":
			ok = kind == "move"
		"tut.ability":
			ok = kind == "ability"
		"tut.upgrade":
			ok = kind == "upgrade"
	if ok:
		_go(step + 1)
	# Players may act ahead of the script; skip steps already done.
	elif kind == "start" and cur in ["tut.build", "tut.build2"] and _towers_built > 0:
		_go(3)


func _process(delta: float) -> void:
	_t += delta
	if step < 0 or step >= STEPS.size() or not is_instance_valid(marker):
		return
	var target := Vector3.INF
	match STEPS[step]:
		"tut.build", "tut.build2":
			var best: BuildSlot = null
			var bd := INF
			var start := battle.routes[0].sample(battle.routes[0].length * 0.35)
			for s in battle.slots:
				if s.is_free() and s.global_position.distance_to(start) < bd:
					bd = s.global_position.distance_to(start)
					best = s
			if best:
				target = best.global_position
		"tut.move", "tut.ability":
			target = battle.hero.global_position
		"tut.upgrade":
			if not battle.towers.is_empty():
				target = battle.towers[0].global_position + Vector3(0, battle.towers[0]._top_height, 0)
	marker.visible = target != Vector3.INF
	if marker.visible:
		marker.global_position = target + Vector3(0, 3.2 + sin(_t * 4.0) * 0.35, 0)
		marker.rotation.y += delta * 2.0
	# When enemies get close during the ability step, point at them.
	if STEPS[step] == "tut.ability" and battle.enemies_near(battle.hero.global_position, 7.0).is_empty():
		text.modulate.a = 0.7
	else:
		text.modulate.a = 1.0


func _finish() -> void:
	Game.set_setting("tutorial_done", true)
	if is_instance_valid(panel):
		panel.queue_free()
	if is_instance_valid(marker):
		marker.queue_free()
	queue_free()
