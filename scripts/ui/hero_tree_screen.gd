extends ScreenBase
## Hero Mastery screen: one hand-authored skill tree per hero. The bar along
## the bottom lists every hero (portrait, level, mastery pips); the canvas shows
## the selected hero's tree — a shared trunk, then two mutually exclusive paths
## with a sub-choice each and a capstone that changes how the hero plays. The
## side panel explains the selected node and buys it; the header holds the
## hero's Hero Marks and the reset (respec) button.
## Kept separate from the Tower Mastery screen (own widget classes) so the two
## systems never interfere.

const NODE_SIZE := 76.0
const CAP_SIZE := 100.0
const GOLD_HI := Color(1.0, 0.84, 0.42)

const FX_GLYPH := {"damage_pct": "sword", "health_pct": "heart", "defense_pct": "shield", "attack_speed": "speed",
	"move_speed": "boots", "range_add": "mark", "crit": "blades", "crit_dmg": "blades", "lifesteal": "blood",
	"cdr": "energy", "energy_regen": "energy", "ult_mult": "surge", "dr": "armor", "thorns": "crossed",
	"regen": "heal", "splash": "blast", "multishot": "arrows", "pierce": "crossbow", "chain": "lightning",
	"on_hit": "poison", "on_hit_execute": "skull", "bonus_status": "poison", "aura": "nova", "on_kill": "skull",
	"on_ult": "surge", "ult_echo": "eclipse", "revive": "upgrade", "ab": "rune"}
const SYN_GLYPH := {"summon": "summon", "blink_strike": "dash", "chain": "lightning", "meteor": "meteor",
	"nova": "nova", "tower_buff": "banner", "quake": "quake", "storm": "storm"}

var hero_id := ""
var selected_node := ""
var _canvas: HeroTreeCanvas
var _details: VBoxContainer
var _node_widgets: Dictionary = {}


func _init() -> void:
	_title_key = "ht.title"


func build() -> void:
	if hero_id == "" or not DB.hero_tree.get("heroes", {}).has(hero_id):
		hero_id = str(Game.profile.get("selected_hero", ""))
		if not DB.hero_tree.get("heroes", {}).has(hero_id):
			hero_id = HeroTree.hero_ids()[0]
	var root := UITheme.vbox(8)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(root)
	root.add_child(_header())
	var mid := UITheme.hbox(12)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.box(Color(0.02, 0.015, 0.018, 0.92), UITheme.GOLD_DARK, 2, 10, 10, 6))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(frame)
	_canvas = HeroTreeCanvas.new()
	_canvas.screen = self
	_canvas.accent = VFX.color(DB.heroes[hero_id].element)
	_canvas.clip_contents = true
	frame.add_child(_canvas)
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.022, 0.02, 0.95), UITheme.GOLD_DIM, 2, 10, 10, 16))
	side.custom_minimum_size = Vector2(370, 0)
	mid.add_child(side)
	var sscroll := ScrollContainer.new()
	sscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(sscroll)
	_details = UITheme.vbox(8)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sscroll.add_child(_details)
	root.add_child(_hero_bar())
	_build_nodes()
	_show_details()


# ---------------------------------------------------------------- header
func _portrait(hid: String, sz: float) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(sz, sz)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := Icon.make("hero", VFX.color(DB.heroes[hid].element), sz)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(face)
	var tr_ := TextureRect.new()
	tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr_.size = Vector2(sz, sz)
	tr_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tr_)
	Portraits.request(hid, func(tex):
		if tex and is_instance_valid(tr_):
			tr_.texture = tex
			face.visible = false)
	return box


func _header() -> Control:
	var h := UITheme.hbox(14)
	var pf := PanelContainer.new()
	pf.add_theme_stylebox_override("panel", UITheme.box(Color(0.05, 0.035, 0.02), GOLD_HI, 2, 8, 2, 2))
	pf.add_child(_portrait(hero_id, 62))
	h.add_child(pf)
	var tv := UITheme.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(UITheme.label(tr("hero." + hero_id), 30, UITheme.GOLD, true))
	var path := HeroTree.chosen_path(hero_id)
	var sub := HeroTree.fmt("ht.level", [HeroTree.hero_level(hero_id)])
	if path != "":
		sub += "   ·   " + tr("ht.%s.path_%s" % [hero_id, path])
	if not Game.is_hero_unlocked(hero_id):
		sub += "   ·   " + tr("ht.locked_hero")
	tv.add_child(UITheme.label(sub, 15, UITheme.TEXT_DIM))
	# Hero Marks purse.
	var purse := PanelContainer.new()
	purse.add_theme_stylebox_override("panel", UITheme.box(Color(0.06, 0.04, 0.02, 0.95), UITheme.GOLD, 2, 22, 8, 8))
	purse.tooltip_text = tr("ht.marks_desc")
	h.add_child(purse)
	var ph := UITheme.hbox(8)
	purse.add_child(ph)
	ph.add_child(Icon.make("mark", GOLD_HI, 40))
	var pv := UITheme.vbox(0)
	ph.add_child(pv)
	pv.add_child(UITheme.label("%d / %d" % [HeroTree.available(hero_id), HeroTree.earned(hero_id)], 26, GOLD_HI, true))
	pv.add_child(UITheme.label(tr("ht.marks"), 13, UITheme.GOLD_DIM))
	var rc := HeroTree.respec_cost(hero_id)
	var rb := UITheme.button("↺ %s  (%d)" % [tr("ht.reset"), rc], _confirm_reset, 14, 250, 44)
	rb.disabled = rc <= 0
	h.add_child(rb)
	return h


func _confirm_reset() -> void:
	var cost := HeroTree.respec_cost(hero_id)
	var d := ConfirmationDialog.new()
	d.dialog_text = HeroTree.fmt("ht.reset_confirm", [HeroTree.spent(hero_id), cost])
	d.title = tr("ht.reset")
	add_child(d)
	d.confirmed.connect(func():
		if HeroTree.respec(hero_id):
			Sfx.play("coin", 0.0)
			selected_node = ""
			rebuild_all()
		else:
			Events.notify(tr("ui.not_enough_gold"), UITheme.RED))
	d.popup_centered()


func rebuild_all() -> void:
	rebuild()
	build()


# ---------------------------------------------------------------- hero bar
func _hero_bar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UITheme.box(Color(0.02, 0.015, 0.015, 0.95), UITheme.GOLD_DARK, 2, 8, 8, 6))
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 122)
	bar.add_child(sc)
	var h := UITheme.hbox(6)
	sc.add_child(h)
	for hid in HeroTree.hero_ids():
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 110)
		b.focus_mode = Control.FOCUS_NONE
		var col := VFX.color(DB.heroes[hid].element)
		var sel: bool = hid == hero_id
		var sb := UITheme.box(Color(0.14, 0.09, 0.03) if sel else Color(col.r * 0.08, col.g * 0.08, col.b * 0.08, 0.95), GOLD_HI if sel else col.darkened(0.35), 3 if sel else 2, 8, 6, 4)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("hover", UITheme.box(Color(0.1, 0.07, 0.03), UITheme.GOLD, 2, 8, 6, 4))
		var v := UITheme.vbox(0)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var pic := _portrait(hid, 58)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(pic)
		var nl := UITheme.label(tr("hero." + hid), 12, UITheme.TEXT if Game.is_hero_unlocked(hid) else UITheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER)
		nl.clip_text = true
		nl.custom_minimum_size = Vector2(102, 0)
		v.add_child(nl)
		var tier := HeroTree.mastery_tier(hid)
		var pips := "✦".repeat(tier) + "·".repeat(3 - tier)
		var avail := HeroTree.available(hid)
		var tail := "  +%d" % avail if avail > 0 else ""
		v.add_child(UITheme.label("%s  %d%s" % [pips, HeroTree.hero_level(hid), tail], 12, GOLD_HI if tier > 0 else UITheme.TEXT_DIM, true, HORIZONTAL_ALIGNMENT_CENTER))
		if not Game.is_hero_unlocked(hid):
			var dim := ColorRect.new()
			dim.color = Color(0, 0, 0, 0.45)
			dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(dim)
		var id: String = hid
		b.pressed.connect(func():
			Sfx.play("click", -4.0)
			hero_id = id
			selected_node = ""
			rebuild_all())
		h.add_child(b)
	return bar


# ---------------------------------------------------------------- tree
func _build_nodes() -> void:
	_node_widgets.clear()
	for n in HeroTree.nodes(hero_id):
		var w := HeroTreeNode.new()
		w.screen = self
		w.node = n
		w.hero_id = hero_id
		w.state = HeroTree.status(hero_id, n.id)
		w.glyph = _glyph_for(n)
		w.accent = _canvas.accent
		w.custom_minimum_size = Vector2.ONE * (CAP_SIZE if n.get("capstone", false) else NODE_SIZE)
		w.size = w.custom_minimum_size
		w.selected = n.id == selected_node
		_canvas.add_child(w)
		_node_widgets[n.id] = w
	for path in ["a", "b"]:
		var lab := UITheme.label(tr("ht.%s.path_%s" % [hero_id, path]), 20, GOLD_HI, true, HORIZONTAL_ALIGNMENT_CENTER)
		lab.set_meta("path", path)
		lab.custom_minimum_size = Vector2(320, 0)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(lab)
		var d := UITheme.label(tr("ht.%s.path_%s_desc" % [hero_id, path]), 13, UITheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER)
		d.set_meta("path_desc", path)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(320, 0)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(d)
	_canvas.layout_nodes()


func _glyph_for(n: Dictionary) -> String:
	var e: Dictionary = n.get("effects", {})
	if e.has("special"):
		return SYN_GLYPH.get(str(e.special.ab.type), "star")
	# Ability mods take the look of the element they boost.
	for k in ["on_ult", "ult_echo", "aura", "revive", "on_kill", "on_hit"]:
		if e.has(k):
			return FX_GLYPH[k]
	if e.has("ab"):
		var st: Dictionary = e.ab[0].get("status", {})
		if not st.is_empty():
			return {"burn": "fire", "poison": "poison", "slow": "ice", "freeze": "ice", "stun": "quake",
				"weaken": "skull", "armor_break": "crossed", "fear": "skull", "blind": "shadow"}.get(str(st.get("id", "")), "rune")
		# Otherwise show the icon of the ability being upgraded.
		var hd: Dictionary = DB.heroes[hero_id]
		var ids: Array = hd.abilities.duplicate()
		ids.append(hd.ultimate)
		var slot := clampi(int(e.ab[0].slot), 0, ids.size() - 1)
		return str(DB.abilities[ids[slot]].get("icon", "rune"))
	for k in e:
		if FX_GLYPH.has(k):
			return FX_GLYPH[k]
	return "rune"


func select_node(nid: String) -> void:
	selected_node = nid
	for id in _node_widgets:
		_node_widgets[id].selected = id == nid
		_node_widgets[id].queue_redraw()
	_show_details()
	Sfx.play("click", -8.0)


func _show_details() -> void:
	for c in _details.get_children():
		c.queue_free()
	if selected_node == "":
		_details.add_child(UITheme.label(tr("ht.title"), 24, UITheme.GOLD, true))
		var d := UITheme.label(tr("ht.marks_desc"), 15, UITheme.TEXT_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(d)
		_details.add_child(UITheme.separator())
		for path in ["a", "b"]:
			_details.add_child(UITheme.label(tr("ht.%s.path_%s" % [hero_id, path]), 18, GOLD_HI, true))
			var pd := UITheme.label(tr("ht.%s.path_%s_desc" % [hero_id, path]), 14, UITheme.TEXT)
			pd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_details.add_child(pd)
		_details.add_child(UITheme.separator())
		var c := UITheme.label(tr("ht.choose_path"), 15, UITheme.TEXT)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(c)
		_legend()
		return
	var n := HeroTree.node(hero_id, selected_node)
	var st := HeroTree.status(hero_id, selected_node)
	var head := UITheme.hbox(10)
	_details.add_child(head)
	head.add_child(Icon.make(_glyph_for(n), GOLD_HI if st == "owned" else UITheme.GOLD_DIM, 56))
	var hv := UITheme.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	var name_l := UITheme.label(tr("ht.%s.%s" % [hero_id, selected_node]), 22, GOLD_HI, true)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(name_l)
	var tag := tr("tt.capstone") if n.get("capstone", false) else (tr("ht.%s.path_%s" % [hero_id, n.path]) if n.has("path") else tr("ht.title"))
	hv.add_child(UITheme.label(tag, 14, UITheme.TEXT_DIM))
	_details.add_child(UITheme.label(_state_text(st), 16, _state_color(st), true))
	_details.add_child(UITheme.separator())
	for line in HeroTree.describe(hero_id, selected_node):
		var l := UITheme.label("• " + str(line), 16, UITheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(l)
	_details.add_child(UITheme.separator())
	var lvl_ok := HeroTree.hero_level(hero_id) >= int(n.level)
	_details.add_child(UITheme.label(HeroTree.fmt("ht.req_level", [int(n.level)]), 15, UITheme.GREEN if lvl_ok else UITheme.RED))
	_details.add_child(UITheme.label(HeroTree.fmt("ht.cost", [int(n.cost)]), 15, UITheme.GREEN if HeroTree.available(hero_id) >= int(n.cost) or st == "owned" else UITheme.RED))
	var req: Array = n.get("requires_any", [])
	if not req.is_empty():
		var names := req.map(func(r): return tr("ht.%s.%s" % [hero_id, r]))
		var have := req.any(func(r): return HeroTree.has(hero_id, r))
		var rl := UITheme.label(TowerTree.tr_fmt("tt.req_nodes", [(" %s " % tr("tt.or")).join(names)]), 15, UITheme.GREEN if have else UITheme.RED)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(rl)
	if n.has("exclusive"):
		var rivals: Array = []
		for o in HeroTree.nodes(hero_id):
			if o.id != n.id and o.get("exclusive", "") == n.exclusive:
				rivals.append(tr("ht.%s.%s" % [hero_id, o.id]))
		var xl := UITheme.label(TowerTree.tr_fmt("tt.excl", [", ".join(rivals)]), 14, Color(0.9, 0.55, 0.35))
		xl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(xl)
	if st != "owned":
		var buy := UITheme.primary_button("%s  (%d)" % [tr("tt.buy"), int(n.cost)], _buy_selected, 22, 300, 58)
		buy.disabled = st != "available"
		_details.add_child(buy)


func _legend() -> void:
	for st in ["owned", "available", "level", "blocked"]:
		var row := UITheme.hbox(8)
		_details.add_child(row)
		var dot := ColorRect.new()
		dot.color = _state_color(st)
		dot.custom_minimum_size = Vector2(16, 16)
		row.add_child(dot)
		row.add_child(UITheme.label(_state_text(st, true), 14, UITheme.TEXT))


func _state_text(st: String, short := false) -> String:
	match st:
		"owned": return tr("tt.unlocked")
		"available": return tr("tt.available")
		"no_points": return tr("ht.not_enough")
		"blocked": return tr("tt.blocked")
		"level": return tr("tt.locked") if short else "%s — %s" % [tr("tt.locked"), HeroTree.fmt("ht.req_level", [int(HeroTree.node(hero_id, selected_node).get("level", 1))])]
	return tr("tt.locked")


func _state_color(st: String) -> Color:
	match st:
		"owned": return GOLD_HI
		"available": return UITheme.GREEN
		"no_points": return Color(0.9, 0.7, 0.3)
		"blocked": return Color(0.7, 0.25, 0.2)
	return UITheme.TEXT_DIM


func _buy_selected() -> void:
	var nid := selected_node
	if not HeroTree.buy(hero_id, nid):
		Sfx.play("click", -2.0)
		return
	var n := HeroTree.node(hero_id, nid)
	var w: Control = _node_widgets.get(nid)
	var at := w.global_position + w.size * 0.5 if w else get_viewport_rect().size * 0.5
	Sfx.play("levelup", 0.0 if n.get("capstone", false) else -4.0)
	Events.notify(tr("ht.new_unlock") + "  " + tr("ht.%s.%s" % [hero_id, nid]), GOLD_HI)
	var accent := VFX.color(DB.heroes[hero_id].element)
	rebuild_all()
	_unlock_fx(at, n.get("capstone", false), accent)


## Gold burst tinted by the hero's element, an expanding ring and — for a
## capstone — a golden screen flash with the capstone's name in big letters.
func _unlock_fx(at: Vector2, capstone: bool, accent: Color) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	var burst := CPUParticles2D.new()
	burst.position = at
	burst.amount = 110 if capstone else 44
	burst.lifetime = 1.2
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.spread = 180.0
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 420.0 if capstone else 240.0
	burst.gravity = Vector2(0, 160)
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 5.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	g.set_color(1, Color(accent.r, accent.g, accent.b, 0.0))
	burst.color_ramp = g
	layer.add_child(burst)
	burst.emitting = true
	var ring := HeroRingFx.new()
	ring.center = at
	ring.max_r = 190.0 if capstone else 100.0
	ring.tint = accent
	layer.add_child(ring)
	if capstone:
		var flash := ColorRect.new()
		flash.color = Color(1.0, 0.8, 0.35, 0.38)
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(flash)
		flash.create_tween().tween_property(flash, "color:a", 0.0, 0.8)
	var tw := layer.create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(layer.queue_free)


# ================================================================ widgets
class HeroTreeCanvas extends Control:
	var screen
	var accent := Color(1, 0.6, 0.3)

	func _ready() -> void:
		resized.connect(layout_nodes)

	func layout_nodes() -> void:
		var pad := Vector2(60, 56)
		var area := size - pad * 2.0
		var tree_h := area.y * 0.78
		for c in get_children():
			if c is HeroTreeNode:
				var p := Vector2(float(c.node.x), float(c.node.y))
				c.position = pad + Vector2(area.x * p.x, tree_h * p.y) - c.size * 0.5
			elif c.has_meta("path"):
				var x := 0.27 if c.get_meta("path") == "a" else 0.73
				c.position = Vector2(pad.x + area.x * x - c.custom_minimum_size.x * 0.5, pad.y + tree_h + 34)
			elif c.has_meta("path_desc"):
				var x2 := 0.27 if c.get_meta("path_desc") == "a" else 0.73
				c.position = Vector2(pad.x + area.x * x2 - c.custom_minimum_size.x * 0.5, pad.y + tree_h + 62)
		queue_redraw()

	func _draw() -> void:
		# A crown-and-halo backdrop tinted with the hero's element.
		var c := size * 0.5
		for k in 3:
			draw_arc(c, minf(size.x, size.y) * (0.2 + 0.15 * k), 0, TAU, 96, Color(accent.r, accent.g, accent.b, 0.06), 2.0)
		draw_arc(c, minf(size.x, size.y) * 0.62, PI * 1.1, PI * 1.9, 64, Color(0.93, 0.76, 0.42, 0.07), 3.0)
		if screen == null:
			return
		var ws: Dictionary = screen._node_widgets
		for id in ws:
			var w = ws[id]
			for r in w.node.get("requires_any", []):
				if not ws.has(r):
					continue
				var o = ws[r]
				var a: Vector2 = o.position + o.size * 0.5
				var b: Vector2 = w.position + w.size * 0.5
				var owned_both: bool = w.state == "owned" and o.state == "owned"
				var live: bool = o.state == "owned" and w.state in ["available", "no_points", "level"]
				var col := Color(1.0, 0.8, 0.35, 0.95) if owned_both else (Color(0.8, 0.62, 0.3, 0.6) if live else Color(0.4, 0.33, 0.25, 0.35))
				if w.state == "blocked":
					col = Color(0.45, 0.15, 0.12, 0.35)
				if owned_both:
					draw_line(a, b, Color(accent.r, accent.g, accent.b, 0.3), 12.0, true)
				draw_line(a, b, col, 5.0 if owned_both else 3.0, true)


class HeroTreeNode extends Control:
	var screen
	var node: Dictionary
	var hero_id := ""
	var state := "requires"
	var glyph := "rune"
	var accent := Color(1, 0.6, 0.3)
	var selected := false
	var _icon: Icon
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var col := Color(1.0, 0.84, 0.42) if state == "owned" else (Color(0.93, 0.76, 0.42) if state in ["available", "no_points"] else Color(0.55, 0.5, 0.45))
		_icon = Icon.make(glyph, col, size.x * 0.62, false)
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon.position = size * 0.19
		_icon.dim = 0.0 if state in ["owned", "available", "no_points"] else 0.55
		add_child(_icon)
		tooltip_text = tr("ht.%s.%s" % [hero_id, node.id])

	func _process(delta: float) -> void:
		if state == "available" or node.get("capstone", false) and state == "owned":
			_t += delta
			queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			screen.select_node(node.id)
			accept_event()

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5
		var cap: bool = node.get("capstone", false)
		var gold := Color(1.0, 0.84, 0.42)
		var fill := Color(0.06, 0.045, 0.035)
		var border := Color(0.35, 0.3, 0.26)
		match state:
			"owned":
				fill = Color(0.2, 0.13, 0.04)
				border = gold
			"available":
				fill = Color(0.08, 0.07, 0.04)
				border = Color(0.55, 0.85, 0.4).lerp(gold, 0.5 + 0.5 * sin(_t * 4.0))
			"no_points":
				border = Color(0.75, 0.6, 0.3)
			"blocked":
				fill = Color(0.07, 0.03, 0.03)
				border = Color(0.5, 0.16, 0.12)
		# Hero nodes are diamonds (tower nodes are circles); capstones get a
		# spiked crown aura in the hero's element that turns once unlocked.
		if cap:
			var pts := PackedVector2Array()
			for i in 20:
				var a := TAU * i / 20.0 + (_t * 0.5 if state == "owned" else 0.0)
				var rr := r * (1.16 if i % 2 == 0 else 0.9)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			var ac := accent if state == "owned" else border
			draw_colored_polygon(pts, Color(ac.r, ac.g, ac.b, 0.4 if state == "owned" else 0.15))
		if state == "owned":
			draw_circle(c, r * 1.02, Color(accent.r, accent.g, accent.b, 0.2))
		var d := PackedVector2Array([c + Vector2(0, -r * 0.92), c + Vector2(r * 0.92, 0), c + Vector2(0, r * 0.92), c + Vector2(-r * 0.92, 0)])
		draw_colored_polygon(d, fill)
		var w := 4.0 if state in ["owned", "available"] else 2.0
		for i in 4:
			draw_line(d[i], d[(i + 1) % 4], border, w, true)
		var d2 := PackedVector2Array([c + Vector2(0, -r * 0.76), c + Vector2(r * 0.76, 0), c + Vector2(0, r * 0.76), c + Vector2(-r * 0.76, 0)])
		for i in 4:
			draw_line(d2[i], d2[(i + 1) % 4], Color(border.r, border.g, border.b, 0.45), 1.5, true)
		if selected:
			draw_arc(c, r * 1.02, 0, TAU, 48, Color(1, 1, 1, 0.85), 2.5, true)
		if state != "owned":
			var bc := c + Vector2(r * 0.6, r * 0.6)
			draw_circle(bc, 13, Color(0.05, 0.04, 0.03))
			draw_arc(bc, 13, 0, TAU, 24, border, 2.0, true)
			var s := str(int(node.get("cost", 1)))
			draw_string(UITheme.font_bold(), bc - Vector2(4.5 * s.length(), -6), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gold)
		if state in ["level", "requires"]:
			var lc := c + Vector2(-r * 0.6, r * 0.58)
			draw_rect(Rect2(lc - Vector2(7, 3), Vector2(14, 11)), Color(0.55, 0.5, 0.45))
			draw_arc(lc - Vector2(0, 3), 5, PI, TAU, 12, Color(0.55, 0.5, 0.45), 2.0)
		elif state == "blocked":
			draw_line(c - Vector2(r, r) * 0.45, c + Vector2(r, r) * 0.45, Color(0.7, 0.2, 0.15, 0.8), 3.0)
			draw_line(c + Vector2(-r, r) * 0.45, c + Vector2(r, -r) * 0.45, Color(0.7, 0.2, 0.15, 0.8), 3.0)


class HeroRingFx extends Control:
	var center := Vector2.ZERO
	var max_r := 100.0
	var tint := Color(1, 0.6, 0.3)
	var _t := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / 0.8, 0.0, 1.0)
		draw_arc(center, max_r * k, 0, TAU, 64, Color(1.0, 0.82, 0.35, 1.0 - k), 6.0 * (1.0 - k) + 1.0, true)
		draw_arc(center, max_r * k * 0.7, 0, TAU, 64, Color(tint.r, tint.g, tint.b, (1.0 - k) * 0.8), 3.0, true)
