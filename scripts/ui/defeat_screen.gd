class_name DefeatScreen
extends Control
## Defeat screen with retry / return options.

func setup(result: Dictionary) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UITheme.panel(Color(0.04, 0.02, 0.02, 0.97), Color(0.7, 0.15, 0.1), 28)
	p.custom_minimum_size = Vector2(640, 0)
	center.add_child(p)
	var v := UITheme.vbox(16)
	p.add_child(v)
	var t := UITheme.title(tr("battle.defeat"), 64)
	t.add_theme_color_override("font_color", Color(0.9, 0.25, 0.15))
	v.add_child(t)
	var sub := UITheme.label(tr("battle.defeat_text"), 22, UITheme.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	v.add_child(UITheme.label("+%d %s" % [int(result.get("hero_xp", 0)), tr("ui.xp")], 20, Color(1, 0.7, 0.3), true, HORIZONTAL_ALIGNMENT_CENTER))
	var row := UITheme.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	row.add_child(UITheme.button(tr("battle.quit"), func(): Router.goto("world_map"), 20, 220, 56))
	row.add_child(UITheme.primary_button(tr("battle.retry"), func(): Router.start_battle(result.stage), 24, 240, 60))
