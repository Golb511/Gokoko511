class_name ScreenBase
extends Control
## Base for menu screens: gothic backdrop, top bar, title, back button and a
## content area. Subclasses implement build() and may call rebuild().

var content: Control
var title_label: Label
var top_bar: TopBar
var _title_key := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	_backdrop()
	top_bar = TopBar.make()
	add_child(top_bar)
	var header := UITheme.hbox(12)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 86
	header.offset_left = 20
	header.offset_right = -20
	add_child(header)
	var back := UITheme.button("‹  " + tr("nav.back"), func(): Router.goto(back_target()), 20, 150, 50)
	header.add_child(back)
	title_label = UITheme.title(tr(_title_key), 38)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(150, 0)
	header.add_child(pad)
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_top = 150
	content.offset_left = 20
	content.offset_right = -20
	content.offset_bottom = -16
	add_child(content)
	Events.language_changed.connect(func(_l): rebuild())
	build()


func back_target() -> String:
	return "world_map"


func set_title(key: String) -> void:
	_title_key = key
	if title_label:
		title_label.text = tr(key)


func build() -> void:
	pass


func rebuild() -> void:
	for c in content.get_children():
		c.queue_free()
	title_label.text = tr(_title_key)
	build()


func _backdrop() -> void:
	var bg := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.13, 0.07, 0.05))
	g.set_color(1, Color(0.015, 0.01, 0.012))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.35)
	gt.fill_to = Vector2(1.1, 1.1)
	bg.texture = gt
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var embers := CPUParticles2D.new()
	embers.amount = 60
	embers.lifetime = 8.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(1000, 10)
	embers.position = Vector2(800, 950)
	embers.direction = Vector2(0, -1)
	embers.spread = 20.0
	embers.gravity = Vector2(0, -12)
	embers.initial_velocity_min = 20
	embers.initial_velocity_max = 60
	embers.scale_amount_min = 1.5
	embers.scale_amount_max = 4.0
	embers.color = Color(1, 0.5, 0.15, 0.7)
	add_child(embers)


## Modal dialog helper. Returns the content VBox; call close_modal() to dismiss.
func modal(min_w := 520.0) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.name = "Modal"
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var p := UITheme.panel(Color(0.04, 0.03, 0.025, 0.98), UITheme.GOLD, 22)
	p.custom_minimum_size = Vector2(min_w, 0)
	cc.add_child(p)
	var v := UITheme.vbox(12)
	p.add_child(v)
	return v


func close_modal() -> void:
	for c in get_children():
		if c.name.begins_with("Modal"):
			c.queue_free()


func confirm(text: String, on_yes: Callable) -> void:
	var v := modal(480)
	var l := UITheme.label(text, 22, UITheme.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var h := UITheme.hbox(16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	h.add_child(UITheme.button(tr("ui.cancel"), close_modal, 20, 160))
	h.add_child(UITheme.primary_button(tr("ui.confirm"), func():
		close_modal()
		on_yes.call(), 20, 180, 52))


static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.add_child(child)
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s
