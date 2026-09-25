class_name VictoryScreen
extends Control
## Victory screen: stars, rewards, loot with rarity colours.

func setup(result: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UITheme.panel(Color(0.04, 0.03, 0.02, 0.97), UITheme.GOLD, 28)
	p.custom_minimum_size = Vector2(760, 0)
	center.add_child(p)
	var v := UITheme.vbox(14)
	p.add_child(v)
	var endless: bool = result.get("endless", false)
	var t := UITheme.title(tr("mode.endless") if endless else tr("battle.victory"), 56 if endless else 64)
	v.add_child(t)
	var stars := StarRow.make(0, 3, 72)
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	if endless:
		v.add_child(UITheme.label("%s: %d" % [tr("mode.wave_reached"), int(result.wave)], 34, UITheme.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
		var bl := UITheme.label("%s: %d%s" % [tr("mode.best_wave"), int(result.best), ("   ★ " + tr("ui.new")) if result.get("new_best", false) else ""], 22, Color(1, 0.7, 0.3), true, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(bl)
	else:
		v.add_child(stars)
	for i in int(result.get("stars", 0)):
		var idx := i
		get_tree().create_timer(0.35 + i * 0.35).timeout.connect(func():
			if not is_instance_valid(stars): return
			var ic: Icon = stars.get_child(idx)
			ic.glyph = "star"
			ic.pivot_offset = ic.size * 0.5
			ic.scale = Vector2(1.8, 1.8)
			ic.create_tween().tween_property(ic, "scale", Vector2.ONE, 0.25)
			Sfx.play("coin", 0.0))
	v.add_child(UITheme.separator())
	var rw := UITheme.hbox(28)
	rw.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(rw)
	_reward(rw, "coin", "+" + Loc.num(result.get("gold", 0)), Color.GOLD)
	if int(result.get("gems", 0)) > 0:
		_reward(rw, "diamond", "+" + str(result.gems), Color(0.5, 0.8, 1))
	if int(result.get("sigils", 0)) > 0:
		_reward(rw, "rune", TowerTree.tr_fmt("tt.sigils_gained", [int(result.sigils)]), Color(1.0, 0.84, 0.42))
	_reward(rw, "hero", "+%d %s" % [int(result.get("hero_xp", 0)), tr("ui.xp")], Color(1, 0.7, 0.3))
	_reward(rw, "star", "+%d %s" % [int(result.get("player_xp", 0)), tr("ui.xp")], Color(1, 0.85, 0.4))
	var loot: Array = result.get("loot", [])
	if not loot.is_empty():
		v.add_child(UITheme.label(tr("battle.loot"), 22, UITheme.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		var cc := CenterContainer.new()
		cc.add_child(grid)
		v.add_child(cc)
		for it in loot:
			grid.add_child(ItemCard.make(it, 100))
	var row := UITheme.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	row.add_child(UITheme.button(tr("battle.retry"), func(): Router.start_battle(result.stage), 20, 200, 56))
	row.add_child(UITheme.primary_button(tr("battle.continue"), func(): Router.goto("world_map"), 24, 260, 60))
	p.pivot_offset = Vector2(380, 300)
	p.scale = Vector2(0.8, 0.8)
	p.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.3)


func _reward(parent: Control, glyph: String, text: String, c: Color) -> void:
	var h := UITheme.hbox(6)
	h.add_child(Icon.make(glyph, c, 40, false))
	h.add_child(UITheme.label(text, 24, c, true))
	parent.add_child(h)
