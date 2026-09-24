extends Control
## Main menu: 3D key-art diorama with gothic title and actions.

var _lang_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vpc)
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_2X if GraphicsSettings.quality() >= 2 else Viewport.MSAA_DISABLED
	vpc.add_child(vp)
	vp.add_child(KeyArtScene.new())
	var vignette := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.4)
	gt.fill_to = Vector2(1.15, 1.1)
	vignette.texture = gt
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	_build_ui()
	Events.language_changed.connect(func(_l): _rebuild())


func _rebuild() -> void:
	for c in get_children():
		if c.name == "UI":
			c.queue_free()
	_build_ui()


func _build_ui() -> void:
	var ui := Control.new()
	ui.name = "UI"
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var top := UITheme.vbox(0)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 18
	ui.add_child(top)
	for word in ["SHADOW", "CROWN"]:
		var t := UITheme.label(word, 88, UITheme.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
		t.add_theme_font_override("font", UITheme.font_title())
		t.add_theme_constant_override("outline_size", 14)
		t.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.02))
		t.add_theme_constant_override("line_spacing", -20)
		top.add_child(t)
	top.add_child(UITheme.label("—  ETERNAL SIEGE  —", 30, Color(0.85, 0.78, 0.62), true, HORIZONTAL_ALIGNMENT_CENTER))
	if Loc.is_rtl():
		top.add_child(UITheme.label("تاج الظل: الحصار الأبدي", 28, UITheme.TEXT_DIM, true, HORIZONTAL_ALIGNMENT_CENTER))
	var v := UITheme.vbox(10)
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.offset_bottom = -36
	ui.add_child(v)
	var start := UITheme.primary_button(tr("menu.start"), func(): Router.goto("world_map"), 34, 440, 78)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(start)
	var pulse := start.create_tween().set_loops()
	pulse.tween_property(start, "modulate", Color(1.25, 1.15, 0.95), 1.1)
	pulse.tween_property(start, "modulate", Color.WHITE, 1.1)
	var row := UITheme.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	row.add_child(UITheme.button(tr("menu.settings"), func(): Router.goto("settings"), 20, 200, 52))
	_lang_btn = UITheme.button("English" if Loc.is_rtl() else "العربية", func():
		Game.set_setting("lang", "en" if Loc.is_rtl() else "ar"), 20, 160, 52)
	row.add_child(_lang_btn)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		row.add_child(UITheme.button(tr("menu.quit"), func(): get_tree().quit(), 20, 160, 52))
	var ver := UITheme.label("v" + str(ProjectSettings.get_setting("application/config/version")), 14, UITheme.TEXT_DIM)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.offset_right = -12
	ver.offset_bottom = -8
	ui.add_child(ver)
