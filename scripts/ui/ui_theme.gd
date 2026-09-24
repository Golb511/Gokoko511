class_name UITheme
extends RefCounted
## Black & gold dark-gothic theme, built in code so it scales for desktop and
## mobile. Latin text uses Cinzel, Arabic falls back to Amiri automatically.

const GOLD := Color(0.93, 0.76, 0.42)
const GOLD_DIM := Color(0.62, 0.47, 0.24)
const GOLD_DARK := Color(0.32, 0.22, 0.1)
const TEXT := Color(0.92, 0.87, 0.78)
const TEXT_DIM := Color(0.62, 0.58, 0.52)
const BG := Color(0.035, 0.03, 0.035, 0.95)
const BG2 := Color(0.08, 0.065, 0.06, 0.96)
const RED := Color(0.85, 0.2, 0.15)
const GREEN := Color(0.45, 0.9, 0.35)
const BLUE := Color(0.4, 0.7, 1.0)

static var _theme: Theme
static var _font: Font
static var _bold: Font
static var _title: Font


static func font() -> Font:
	if _font == null:
		_build_fonts()
	return _font


static func font_bold() -> Font:
	if _bold == null:
		_build_fonts()
	return _bold


static func font_title() -> Font:
	if _title == null:
		_build_fonts()
	return _title


static func _build_fonts() -> void:
	var amiri: FontFile = load("res://assets/fonts/Amiri-Regular.ttf")
	var amiri_b: FontFile = load("res://assets/fonts/Amiri-Bold.ttf")
	var cinzel: FontFile = load("res://assets/fonts/Cinzel.ttf")
	var deco: FontFile = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	var reg := FontVariation.new()
	reg.base_font = cinzel
	reg.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500}
	reg.fallbacks = [amiri]
	_font = reg
	var bold := FontVariation.new()
	bold.base_font = cinzel
	bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	bold.fallbacks = [amiri_b]
	_bold = bold
	var title := FontVariation.new()
	title.base_font = deco
	title.fallbacks = [amiri_b]
	_title = title


static func box(bg: Color, border: Color, bw: int = 2, radius: int = 6, shadow := 6, margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = shadow
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 20
	# Panels
	t.set_stylebox("panel", "Panel", box(BG, GOLD_DIM))
	t.set_stylebox("panel", "PanelContainer", box(BG, GOLD_DIM))
	t.set_stylebox("panel", "PopupPanel", box(BG, GOLD))
	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", "Label", 4)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("bold_font", "RichTextLabel", font_bold())
	t.set_font("normal_font", "RichTextLabel", font())
	# Buttons
	var bn := box(Color(0.11, 0.08, 0.06, 0.96), GOLD_DIM, 2, 5, 4, 8)
	bn.set_content_margin(SIDE_LEFT, 16)
	bn.set_content_margin(SIDE_RIGHT, 16)
	var bh := bn.duplicate()
	bh.bg_color = Color(0.2, 0.14, 0.08, 0.98)
	bh.border_color = GOLD
	var bp := bn.duplicate()
	bp.bg_color = Color(0.06, 0.04, 0.03, 1)
	bp.border_color = GOLD
	var bd := bn.duplicate()
	bd.bg_color = Color(0.07, 0.06, 0.06, 0.8)
	bd.border_color = Color(0.3, 0.26, 0.22)
	for cls in ["Button", "OptionButton", "CheckBox", "CheckButton"]:
		t.set_stylebox("normal", cls, bn)
		t.set_stylebox("hover", cls, bh)
		t.set_stylebox("pressed", cls, bp)
		t.set_stylebox("disabled", cls, bd)
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, GOLD)
		t.set_color("font_hover_color", cls, Color(1, 0.92, 0.7))
		t.set_color("font_pressed_color", cls, Color(1, 0.85, 0.5))
		t.set_color("font_disabled_color", cls, Color(0.45, 0.42, 0.38))
		t.set_color("font_outline_color", cls, Color(0, 0, 0, 1))
		t.set_constant("outline_size", cls, 4)
		t.set_font("font", cls, font_bold())
	# Progress
	t.set_stylebox("background", "ProgressBar", box(Color(0.03, 0.02, 0.02, 0.9), GOLD_DARK, 1, 3, 0, 0))
	var fill := box(GOLD_DIM, Color(0, 0, 0, 0), 0, 3, 0, 0)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_color("font_color", "ProgressBar", TEXT)
	# Slider
	t.set_stylebox("slider", "HSlider", box(Color(0.05, 0.04, 0.04), GOLD_DARK, 1, 3, 0, 3))
	t.set_stylebox("grabber_area", "HSlider", box(GOLD_DIM, Color(0, 0, 0, 0), 0, 3, 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, Color(0, 0, 0, 0), 0, 3, 0, 3))
	# Scroll
	t.set_stylebox("scroll", "VScrollBar", box(Color(0.04, 0.03, 0.03, 0.6), Color(0, 0, 0, 0), 0, 3, 0, 2))
	t.set_stylebox("grabber", "VScrollBar", box(GOLD_DARK, Color(0, 0, 0, 0), 0, 3, 0, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(GOLD_DIM, Color(0, 0, 0, 0), 0, 3, 0, 2))
	t.set_stylebox("scroll", "HScrollBar", box(Color(0.04, 0.03, 0.03, 0.6), Color(0, 0, 0, 0), 0, 3, 0, 2))
	t.set_stylebox("grabber", "HScrollBar", box(GOLD_DARK, Color(0, 0, 0, 0), 0, 3, 0, 2))
	# Tooltip
	t.set_stylebox("panel", "TooltipPanel", box(BG, GOLD, 1, 4, 4, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	# Popup menu (OptionButton list)
	t.set_stylebox("panel", "PopupMenu", box(BG, GOLD_DIM, 2, 4, 4, 6))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", GOLD)
	t.set_stylebox("hover", "PopupMenu", box(Color(0.2, 0.14, 0.08), Color(0, 0, 0, 0), 0, 3, 0, 4))
	# Tabs
	t.set_stylebox("tab_selected", "TabBar", box(Color(0.2, 0.14, 0.08), GOLD, 2, 4, 0, 8))
	t.set_stylebox("tab_unselected", "TabBar", box(Color(0.07, 0.05, 0.05), GOLD_DARK, 1, 4, 0, 8))
	t.set_stylebox("tab_hovered", "TabBar", box(Color(0.14, 0.1, 0.07), GOLD_DIM, 1, 4, 0, 8))
	t.set_color("font_selected_color", "TabBar", GOLD)
	t.set_color("font_unselected_color", "TabBar", TEXT_DIM)
	t.set_font("font", "TabBar", font_bold())
	_theme = t
	return t


# ---------------------------------------------------------------- widget helpers
static func label(text: String, size: int = 20, col: Color = TEXT, bold := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", font_bold())
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func title(text: String, size: int = 40) -> Label:
	var l := label(text, size, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", font_title())
	l.add_theme_constant_override("outline_size", 8)
	return l


static func button(text: String, cb: Callable = Callable(), size: int = 20, min_w := 0.0, min_h := 48.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(min_w, min_h)
	if cb.is_valid():
		b.pressed.connect(cb)
	b.pressed.connect(func(): Sfx.play("click", -4.0))
	return b


static func primary_button(text: String, cb: Callable = Callable(), size: int = 24, min_w := 220.0, min_h := 60.0) -> Button:
	var b := button(text, cb, size, min_w, min_h)
	var n := box(Color(0.35, 0.2, 0.06), GOLD, 3, 6, 8, 10)
	var h := box(Color(0.5, 0.3, 0.08), Color(1, 0.9, 0.6), 3, 6, 10, 10)
	var p := box(Color(0.25, 0.14, 0.04), GOLD, 3, 6, 4, 10)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	return b


static func panel(bg := BG, border := GOLD_DIM, margin := 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, 2, 6, 8, margin))
	return p


static func separator() -> Control:
	var c := ColorRect.new()
	c.color = GOLD_DARK
	c.custom_minimum_size = Vector2(0, 2)
	return c


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func spacer(expand_h := true) -> Control:
	var c := Control.new()
	if expand_h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func stars_text(n: int, total := 3) -> String:
	var s := ""
	for i in total:
		s += "★" if i < n else "☆"
	return s


static func bar(value: float, max_value: float, fill: Color, height := 14.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.max_value = max_value
	pb.value = value
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, height)
	pb.add_theme_stylebox_override("fill", box(fill, Color(0, 0, 0, 0), 0, 3, 0, 0))
	return pb
