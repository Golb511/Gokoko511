extends ScreenBase
## Tower Mastery screen: one skill tree per tower type. The bar along the
## bottom lists every tower; the canvas shows the selected tower's tree with
## owned / available / locked / closed nodes and the links between them; the
## side panel explains the selected node (effects, level, cost, requirements)
## and buys it. Crown Sigils and the reset (respec) buttons sit in the header.

const NODE_SIZE := 76.0
const CAP_SIZE := 96.0
const GOLD_HI := Color(1.0, 0.84, 0.42)

const FX_GLYPH := {"dmg": "sword", "rate": "speed", "range": "mark", "cost": "coin", "pen": "crossed",
	"crit": "blades", "crit_mult": "blades", "multishot": "arrows", "splash": "blast", "pierce": "crossbow",
	"chain": "lightning", "stun": "quake", "freeze": "ice", "fear": "skull", "knockback": "storm",
	"ramp": "fire", "soldiers": "hero", "soldier_hp": "heart", "armor": "shield", "respawn": "upgrade",
	"lifesteal": "blood", "traps": "rune", "trap_splash": "blast", "status_power": "poison",
	"status_duration": "cloud", "air_bonus": "raven", "heal_allies": "heal", "execute": "skull",
	"mark": "mark", "bonus_status": "ice", "unit": "banner", "status": "poison"}
const SPECIAL_GLYPH := {"volley": "arrows", "nova": "nova", "barrage": "meteor", "empowered": "surge"}

var tower_id := "archer"
var selected_node := ""
var _canvas: TreeCanvas
var _details: VBoxContainer
var _sigil_label: Label
var _node_widgets: Dictionary = {}


func _init() -> void:
	_title_key = "tt.title"


func build() -> void:
	if not DB.tower_tree.get("towers", {}).has(tower_id):
		tower_id = TowerTree.tower_ids()[0]
	var root := UITheme.vbox(8)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(root)
	root.add_child(_header())
	var mid := UITheme.hbox(12)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)
	# Tree canvas framed in gold.
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.box(Color(0.02, 0.015, 0.018, 0.92), UITheme.GOLD_DARK, 2, 10, 10, 6))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(frame)
	_canvas = TreeCanvas.new()
	_canvas.screen = self
	_canvas.clip_contents = true
	frame.add_child(_canvas)
	# Detail panel.
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.022, 0.02, 0.95), UITheme.GOLD_DIM, 2, 10, 10, 16))
	side.custom_minimum_size = Vector2(360, 0)
	mid.add_child(side)
	var sscroll := ScrollContainer.new()
	sscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(sscroll)
	_details = UITheme.vbox(8)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sscroll.add_child(_details)
	root.add_child(_tower_bar())
	_build_nodes()
	_show_details()


# ---------------------------------------------------------------- header
func _header() -> Control:
	var h := UITheme.hbox(14)
	var ic := Icon.make(BattleHUD.TOWER_GLYPH.get(tower_id, "tower"), ModelLib._col(DB.towers[tower_id].model.accent), 58)
	h.add_child(ic)
	var tv := UITheme.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(UITheme.label(tr("tower." + tower_id), 30, UITheme.GOLD, true))
	var sub := "%s   ·   %s" % [TowerTree.tr_fmt("tt.spent", [TowerTree.spent_on(tower_id)]), _tower_status_text()]
	tv.add_child(UITheme.label(sub, 15, UITheme.TEXT_DIM))
	# Sigil purse.
	var purse := PanelContainer.new()
	purse.add_theme_stylebox_override("panel", UITheme.box(Color(0.06, 0.04, 0.02, 0.95), UITheme.GOLD, 2, 22, 8, 8))
	purse.tooltip_text = tr("tt.sigils_desc")
	h.add_child(purse)
	var ph := UITheme.hbox(8)
	purse.add_child(ph)
	ph.add_child(Icon.make("rune", GOLD_HI, 40))
	var pv := UITheme.vbox(0)
	ph.add_child(pv)
	_sigil_label = UITheme.label(str(TowerTree.available()), 28, GOLD_HI, true)
	pv.add_child(_sigil_label)
	pv.add_child(UITheme.label(tr("tt.sigils"), 13, UITheme.GOLD_DIM))
	var rv := UITheme.vbox(4)
	h.add_child(rv)
	var rc := TowerTree.respec_cost(tower_id)
	var rb := UITheme.button("↺ %s  (%d)" % [tr("tt.reset_tower"), rc], func(): _confirm_reset(tower_id), 14, 250, 38)
	rb.disabled = rc <= 0
	rv.add_child(rb)
	var ra := TowerTree.respec_cost("")
	var rab := UITheme.button("↺ %s  (%d)" % [tr("tt.reset_all"), ra], func(): _confirm_reset(""), 14, 250, 38)
	rab.disabled = ra <= 0
	rv.add_child(rab)
	return h


func _tower_status_text() -> String:
	var found := false
	for i in DB.stage_order.size():
		if Game.stage_stars(DB.stage_order[i]) > 0 or Game.is_stage_unlocked(DB.stage_order[i]):
			if tower_id in DB.stage_info(DB.stage_order[i]).data.get("towers", []):
				found = true
				break
	return tr("tt.unlocked") if found else tr("tt.tower_locked")


func _confirm_reset(tid: String) -> void:
	var cost := TowerTree.respec_cost(tid)
	var pts := TowerTree.spent_on(tid) if tid != "" else TowerTree.spent()
	var d := ConfirmationDialog.new()
	d.dialog_text = TowerTree.tr_fmt("tt.reset_confirm", [pts, cost])
	d.title = tr("tt.reset_all") if tid == "" else tr("tt.reset_tower")
	add_child(d)
	d.confirmed.connect(func():
		if TowerTree.respec(tid):
			Sfx.play("coin", 0.0)
			selected_node = ""
			rebuild_all()
		else:
			Events.notify(tr("ui.not_enough_gold"), UITheme.RED))
	d.popup_centered()


func rebuild_all() -> void:
	rebuild()
	build()


# ---------------------------------------------------------------- tower bar
func _tower_bar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UITheme.box(Color(0.02, 0.015, 0.015, 0.95), UITheme.GOLD_DARK, 2, 8, 8, 6))
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 118)
	bar.add_child(sc)
	var h := UITheme.hbox(6)
	sc.add_child(h)
	for tid in TowerTree.tower_ids():
		var b := Button.new()
		b.custom_minimum_size = Vector2(104, 106)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = tid == tower_id
		if tid == tower_id:
			b.add_theme_stylebox_override("normal", UITheme.box(Color(0.14, 0.09, 0.03), GOLD_HI, 3, 8, 6, 4))
			b.add_theme_stylebox_override("pressed", UITheme.box(Color(0.14, 0.09, 0.03), GOLD_HI, 3, 8, 6, 4))
		var v := UITheme.vbox(0)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var ic := Icon.make(BattleHUD.TOWER_GLYPH.get(tid, "tower"), ModelLib._col(DB.towers[tid].model.accent), 50)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(ic)
		var nl := UITheme.label(tr("tower." + tid), 12, UITheme.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
		nl.clip_text = true
		nl.custom_minimum_size = Vector2(96, 0)
		v.add_child(nl)
		var tier := TowerTree.mastery_tier(tid)
		var pips := "✦".repeat(tier) + "·".repeat(3 - tier)
		v.add_child(UITheme.label("%s  %d" % [pips, TowerTree.spent_on(tid)], 12, GOLD_HI if tier > 0 else UITheme.TEXT_DIM, true, HORIZONTAL_ALIGNMENT_CENTER))
		var id: String = tid
		b.pressed.connect(func():
			Sfx.play("click", -4.0)
			tower_id = id
			selected_node = ""
			rebuild_all())
		h.add_child(b)
	return bar


# ---------------------------------------------------------------- tree
func _build_nodes() -> void:
	_node_widgets.clear()
	for n in TowerTree.nodes(tower_id):
		var w := TreeNodeWidget.new()
		w.screen = self
		w.node = n
		w.tower_id = tower_id
		w.state = TowerTree.status(tower_id, n.id)
		w.glyph = _glyph_for(n)
		w.custom_minimum_size = Vector2.ONE * (CAP_SIZE if n.get("capstone", false) else NODE_SIZE)
		w.size = w.custom_minimum_size
		w.selected = n.id == selected_node
		_canvas.add_child(w)
		_node_widgets[n.id] = w
	# Path banners.
	for path in ["a", "b"]:
		var lab := UITheme.label(tr("tt.%s.path_%s" % [tower_id, path]), 20, GOLD_HI, true, HORIZONTAL_ALIGNMENT_CENTER)
		lab.set_meta("path", path)
		lab.custom_minimum_size = Vector2(300, 0)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(lab)
		var d := UITheme.label(tr("tt.%s.path_%s_desc" % [tower_id, path]), 13, UITheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER)
		d.set_meta("path_desc", path)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(300, 0)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(d)
	_canvas.layout_nodes()


func _glyph_for(n: Dictionary) -> String:
	if n.get("glyph", "") != "":
		return n.glyph
	var e: Dictionary = n.get("effects", {})
	if e.has("special"):
		return SPECIAL_GLYPH.get(str(e.special.type), "star")
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
		_details.add_child(UITheme.label(tr("tt.title"), 24, UITheme.GOLD, true))
		var d := UITheme.label(tr("tt.sigils_desc"), 15, UITheme.TEXT_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(d)
		_details.add_child(UITheme.separator())
		var c := UITheme.label(tr("tt.choose_path"), 15, UITheme.TEXT)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(c)
		_legend()
		return
	var n := TowerTree.node(tower_id, selected_node)
	var st := TowerTree.status(tower_id, selected_node)
	var head := UITheme.hbox(10)
	_details.add_child(head)
	head.add_child(Icon.make(_glyph_for(n), GOLD_HI if st == "owned" else UITheme.GOLD_DIM, 56))
	var hv := UITheme.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	var name_l := UITheme.label(tr("tt.%s.%s" % [tower_id, selected_node]), 22, GOLD_HI, true)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(name_l)
	var tag := tr("tt.capstone") if n.get("capstone", false) else (tr("tt.%s.path_%s" % [tower_id, n.path]) if n.has("path") else tr("tt.title"))
	hv.add_child(UITheme.label(tag, 14, UITheme.TEXT_DIM))
	_details.add_child(UITheme.label(_state_text(st), 16, _state_color(st), true))
	_details.add_child(UITheme.separator())
	for line in TowerTree.describe(tower_id, selected_node):
		var l := UITheme.label("• " + str(line), 16, UITheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(l)
	_details.add_child(UITheme.separator())
	var lvl_ok := int(Game.profile.player_level) >= int(n.level)
	_details.add_child(UITheme.label(TowerTree.tr_fmt("tt.req_level", [int(n.level)]), 15, UITheme.GREEN if lvl_ok else UITheme.RED))
	_details.add_child(UITheme.label(TowerTree.tr_fmt("tt.cost", [int(n.cost)]), 15, UITheme.GREEN if TowerTree.available() >= int(n.cost) or st == "owned" else UITheme.RED))
	var req: Array = n.get("requires_any", [])
	if not req.is_empty():
		var names := req.map(func(r): return tr("tt.%s.%s" % [tower_id, r]))
		var have := req.any(func(r): return TowerTree.has(tower_id, r))
		var rl := UITheme.label(TowerTree.tr_fmt("tt.req_nodes", [(" %s " % tr("tt.or")).join(names)]), 15, UITheme.GREEN if have else UITheme.RED)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(rl)
	if n.has("exclusive"):
		var rivals: Array = []
		for o in TowerTree.nodes(tower_id):
			if o.id != n.id and o.get("exclusive", "") == n.exclusive:
				rivals.append(tr("tt.%s.%s" % [tower_id, o.id]))
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
		"no_points": return tr("tt.not_enough")
		"blocked": return tr("tt.blocked")
		"level": return tr("tt.locked") if short else "%s — %s" % [tr("tt.locked"), TowerTree.tr_fmt("tt.req_level", [int(TowerTree.node(tower_id, selected_node).get("level", 1))])]
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
	if not TowerTree.buy(tower_id, nid):
		Sfx.play("click", -2.0)
		return
	var n := TowerTree.node(tower_id, nid)
	var w: Control = _node_widgets.get(nid)
	var at := w.global_position + w.size * 0.5 if w else get_viewport_rect().size * 0.5
	Sfx.play("levelup", 0.0 if n.get("capstone", false) else -4.0)
	Events.notify(tr("tt.new_unlock") + "  " + tr("tt.%s.%s" % [tower_id, nid]), GOLD_HI)
	rebuild_all()
	_unlock_fx(at, n.get("capstone", false))


## Gold burst, expanding ring and (for capstones) a golden screen flash.
func _unlock_fx(at: Vector2, capstone: bool) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	var burst := CPUParticles2D.new()
	burst.position = at
	burst.amount = 90 if capstone else 44
	burst.lifetime = 1.1
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.spread = 180.0
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 380.0 if capstone else 240.0
	burst.gravity = Vector2(0, 160)
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 5.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	g.set_color(1, Color(1.0, 0.55, 0.1, 0.0))
	burst.color_ramp = g
	layer.add_child(burst)
	burst.emitting = true
	var ring := RingFx.new()
	ring.center = at
	ring.max_r = 170.0 if capstone else 100.0
	layer.add_child(ring)
	if capstone:
		var flash := ColorRect.new()
		flash.color = Color(1.0, 0.8, 0.35, 0.35)
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(flash)
		flash.create_tween().tween_property(flash, "color:a", 0.0, 0.7)
	var tw := layer.create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(layer.queue_free)


# ================================================================ widgets
class TreeCanvas extends Control:
	var screen

	func _ready() -> void:
		resized.connect(layout_nodes)

	func layout_nodes() -> void:
		var pad := Vector2(60, 56)
		var area := size - pad * 2.0
		var tree_h := area.y * 0.78        # the tree itself; path banners go underneath
		for c in get_children():
			if c is TreeNodeWidget:
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
		# Faint gothic rings behind the tree.
		var c := size * 0.5
		for k in 3:
			draw_arc(c, minf(size.x, size.y) * (0.22 + 0.14 * k), 0, TAU, 96, Color(0.93, 0.76, 0.42, 0.05), 2.0)
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
				var wdt := 5.0 if owned_both else 3.0
				if owned_both:
					draw_line(a, b, Color(1.0, 0.7, 0.2, 0.25), 12.0, true)
				draw_line(a, b, col, wdt, true)


class TreeNodeWidget extends Control:
	var screen
	var node: Dictionary
	var tower_id := ""
	var state := "requires"
	var glyph := "rune"
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
		tooltip_text = tr("tt.%s.%s" % [tower_id, node.id])

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
		# Capstones: an outer star-shaped aura that turns when unlocked.
		if cap:
			var pts := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0 + (_t * 0.6 if state == "owned" else 0.0)
				var rr := r * (1.12 if i % 2 == 0 else 0.92)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, Color(border.r, border.g, border.b, 0.35 if state == "owned" else 0.15))
		if state == "owned":
			draw_circle(c, r * 1.05, Color(1.0, 0.7, 0.2, 0.18))
		draw_circle(c, r * 0.9, fill)
		draw_arc(c, r * 0.9, 0, TAU, 48, border, 4.0 if state in ["owned", "available"] else 2.0, true)
		draw_arc(c, r * 0.78, 0, TAU, 48, Color(border.r, border.g, border.b, 0.45), 1.5, true)
		if selected:
			draw_arc(c, r * 1.02, 0, TAU, 48, Color(1, 1, 1, 0.85), 2.5, true)
		# Cost badge.
		if state != "owned":
			var bc := c + Vector2(r * 0.62, r * 0.62)
			draw_circle(bc, 13, Color(0.05, 0.04, 0.03))
			draw_arc(bc, 13, 0, TAU, 24, border, 2.0, true)
			var f := UITheme.font_bold()
			var s := str(int(node.get("cost", 1)))
			draw_string(f, bc - Vector2(4.5 * s.length(), -6), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gold)
		if state in ["level", "requires"]:
			# Padlock glyph.
			var lc := c + Vector2(-r * 0.62, r * 0.6)
			draw_rect(Rect2(lc - Vector2(7, 3), Vector2(14, 11)), Color(0.55, 0.5, 0.45))
			draw_arc(lc - Vector2(0, 3), 5, PI, TAU, 12, Color(0.55, 0.5, 0.45), 2.0)
		elif state == "blocked":
			draw_line(c - Vector2(r, r) * 0.5, c + Vector2(r, r) * 0.5, Color(0.7, 0.2, 0.15, 0.8), 3.0)
			draw_line(c + Vector2(-r, r) * 0.5, c + Vector2(r, -r) * 0.5, Color(0.7, 0.2, 0.15, 0.8), 3.0)


class RingFx extends Control:
	var center := Vector2.ZERO
	var max_r := 100.0
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
		draw_arc(center, max_r * k * 0.7, 0, TAU, 64, Color(1.0, 0.95, 0.7, (1.0 - k) * 0.7), 3.0, true)
