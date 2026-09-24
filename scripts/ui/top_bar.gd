class_name TopBar
extends PanelContainer
## Player level, XP, gold, gems and energy (with regen timer) — shared by
## the world map and every menu screen.

var level_lbl: Label
var xp_bar: ProgressBar
var gold_lbl: Label
var gems_lbl: Label
var energy_lbl: Label
var timer_lbl: Label


static func make(with_nav_icons := true) -> TopBar:
	var t := TopBar.new()
	t.add_theme_stylebox_override("panel", UITheme.box(Color(0.02, 0.015, 0.015, 0.85), UITheme.GOLD_DARK, 0, 0, 6, 8))
	t.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	t.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var h := UITheme.hbox(14)
	t.add_child(h)
	var lvl_ring := PanelContainer.new()
	lvl_ring.add_theme_stylebox_override("panel", UITheme.box(Color(0.08, 0.05, 0.03), UITheme.GOLD, 3, 30, 4, 6))
	lvl_ring.custom_minimum_size = Vector2(58, 58)
	h.add_child(lvl_ring)
	t.level_lbl = UITheme.label("1", 26, UITheme.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	lvl_ring.add_child(t.level_lbl)
	var pv := UITheme.vbox(2)
	pv.custom_minimum_size = Vector2(200, 0)
	h.add_child(pv)
	pv.add_child(UITheme.label(TranslationServer.translate("ui.player"), 16, UITheme.TEXT_DIM, true))
	t.xp_bar = UITheme.bar(0, 1, Color(0.8, 0.6, 0.25), 14)
	pv.add_child(t.xp_bar)
	h.add_child(UITheme.spacer())
	t.gold_lbl = t._pill(h, "coin", Color.GOLD)
	t.gems_lbl = t._pill(h, "diamond", Color(0.4, 0.7, 1.0))
	t.energy_lbl = t._pill(h, "energy", Color(1, 0.8, 0.2))
	t.timer_lbl = UITheme.label("", 14, UITheme.TEXT_DIM)
	h.add_child(t.timer_lbl)
	if with_nav_icons:
		var plus := UITheme.button("+", func(): Router.goto("shop"), 22, 44, 44)
		h.add_child(plus)
		var gear := Button.new()
		gear.custom_minimum_size = Vector2(48, 48)
		gear.focus_mode = Control.FOCUS_NONE
		gear.pressed.connect(func(): Router.goto("settings"))
		var gi := Icon.make("gear", UITheme.GOLD, 34, false)
		gi.position = Vector2(7, 7)
		gear.add_child(gi)
		h.add_child(gear)
	Events.currency_changed.connect(t.refresh)
	Events.profile_changed.connect(t.refresh)
	t.refresh()
	return t


func _pill(parent: Control, glyph: String, c: Color) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(Color(0.06, 0.04, 0.03, 0.9), UITheme.GOLD_DARK, 1, 20, 0, 4))
	parent.add_child(p)
	var h := UITheme.hbox(6)
	p.add_child(h)
	h.add_child(Icon.make(glyph, c, 30, false))
	var l := UITheme.label("0", 22, UITheme.TEXT, true)
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	return l


func _ready() -> void:
	refresh()


func refresh() -> void:
	if not is_inside_tree():
		return
	level_lbl.text = str(Game.profile.player_level)
	xp_bar.max_value = Game.player_xp_needed()
	xp_bar.value = int(Game.profile.player_xp)
	gold_lbl.text = Loc.num(Game.gold())
	gems_lbl.text = Loc.num(Game.gems())
	energy_lbl.text = "%d/%d" % [Game.energy(), int(DB.cfg.energy_max)]


func _process(_d: float) -> void:
	var s := Game.seconds_to_next_energy()
	timer_lbl.text = "" if s <= 0 else "%d:%02d" % [s / 60, s % 60]
	if Engine.get_process_frames() % 60 == 0:
		energy_lbl.text = "%d/%d" % [Game.energy(), int(DB.cfg.energy_max)]
