extends ScreenBase
## Settings: language, audio, graphics quality, shadows, fog, camera speed,
## FPS display, controls reference and progress reset.

func _init() -> void:
	_title_key = "menu.settings"


func back_target() -> String:
	return "world_map" if Router.current != "" and Router.current != "settings" else "main_menu"


func build() -> void:
	var p := UITheme.panel(Color(0.03, 0.02, 0.02, 0.92), UITheme.GOLD_DIM, 20)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(820, 0)
	content.add_child(p)
	var v := UITheme.vbox(14)
	p.add_child(v)
	var lang := _row(v, "ui.language")
	for pair in [["ar", "العربية"], ["en", "English"]]:
		var b := UITheme.button(pair[1], func(): Game.set_setting("lang", pair[0]), 18, 150, 46)
		if Game.setting("lang") == pair[0]:
			b.add_theme_stylebox_override("normal", UITheme.box(Color(0.3, 0.18, 0.06), UITheme.GOLD, 2, 5, 2, 8))
		lang.add_child(b)
	_slider(v, "ui.music", "music")
	_slider(v, "ui.sfx", "sfx")
	var q := _row(v, "ui.graphics")
	var names := ["ui.low", "ui.medium", "ui.high", "ui.ultra"]
	for i in 4:
		var b := UITheme.button(tr(names[i]), func():
			Game.set_setting("quality", i)
			GraphicsSettings.apply_window()
			rebuild(), 16, 110, 44)
		if int(Game.setting("quality", 2)) == i:
			b.add_theme_stylebox_override("normal", UITheme.box(Color(0.3, 0.18, 0.06), UITheme.GOLD, 2, 5, 2, 8))
		q.add_child(b)
	_toggle(v, "ui.shadows", "shadows")
	_toggle(v, "ui.fog", "fog")
	_toggle(v, "ui.show_fps", "show_fps")
	var cs := _row(v, "ui.camera_speed")
	var sl := HSlider.new()
	sl.min_value = 0.4
	sl.max_value = 2.0
	sl.step = 0.1
	sl.value = float(Game.setting("camera_speed", 1.0))
	sl.custom_minimum_size = Vector2(320, 30)
	sl.value_changed.connect(func(x): Game.set_setting("camera_speed", x))
	cs.add_child(sl)
	v.add_child(UITheme.separator())
	v.add_child(UITheme.label(tr("ui.controls"), 20, UITheme.GOLD, true))
	var ct := UITheme.label(tr("ui.controls_text"), 15, UITheme.TEXT_DIM)
	ct.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ct)
	v.add_child(UITheme.separator())
	var reset := UITheme.button(tr("ui.reset_save"), func():
		confirm(tr("ui.reset_confirm"), func():
			Game.reset_profile()
			Router.goto("main_menu")), 16, 260, 48)
	reset.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	v.add_child(reset)


func _row(parent: Control, key: String) -> HBoxContainer:
	var h := UITheme.hbox(12)
	parent.add_child(h)
	var l := UITheme.label(tr(key), 19, UITheme.TEXT, true)
	l.custom_minimum_size = Vector2(260, 0)
	h.add_child(l)
	return h


func _slider(parent: Control, key: String, setting: String) -> void:
	var h := _row(parent, key)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Game.setting(setting, 0.7))
	s.custom_minimum_size = Vector2(320, 30)
	s.value_changed.connect(func(x): Game.set_setting(setting, x))
	h.add_child(s)


func _toggle(parent: Control, key: String, setting: String) -> void:
	var h := _row(parent, key)
	var c := CheckButton.new()
	c.button_pressed = bool(Game.setting(setting, true))
	c.toggled.connect(func(on): Game.set_setting(setting, on))
	h.add_child(c)
