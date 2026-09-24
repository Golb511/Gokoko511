extends ScreenBase
## Arsenal / Inventory: hero paper-doll with a live 3D model, equipment slots,
## filterable item grid, item details with Equip / Unequip / Upgrade / Sell /
## Delete / Compare / Socket gem, and materials.

const FILTERS := ["all", "weapon", "armor", "gloves", "boots", "ring", "necklace", "gem"]
var hero_id := ""
var filter := "all"
var selected_uid := ""
var detail: VBoxContainer
var grid: GridContainer


func _init() -> void:
	_title_key = "nav.arsenal"


func build() -> void:
	if hero_id == "":
		hero_id = Game.profile.selected_hero
	var h := UITheme.hbox(14)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(h)
	# Paper doll
	var doll := UITheme.panel(Color(0.03, 0.02, 0.02, 0.9), UITheme.GOLD_DIM, 10)
	h.add_child(doll)
	var dv := UITheme.vbox(8)
	doll.add_child(dv)
	var hs := OptionButton.new()
	var idx := 0
	var sel := 0
	for id in DB.hero_order:
		if Game.is_hero_unlocked(id):
			hs.add_item(tr("hero." + id))
			hs.set_item_metadata(idx, id)
			if id == hero_id:
				sel = idx
			idx += 1
	hs.select(sel)
	hs.item_selected.connect(func(i):
		hero_id = hs.get_item_metadata(i)
		rebuild())
	dv.add_child(hs)
	var body := UITheme.hbox(6)
	dv.add_child(body)
	var lslots := UITheme.vbox(6)
	body.add_child(lslots)
	body.add_child(HeroPreview.make(DB.heroes[hero_id].model, Vector2(250, 360)))
	var rslots := UITheme.vbox(6)
	body.add_child(rslots)
	for i in DB.items.slots.size():
		var slot: String = DB.items.slots[i]
		(lslots if i < 3 else rslots).add_child(_slot_tile(slot))
	var stats := Game.hero_stats(hero_id)
	var sg := GridContainer.new()
	sg.columns = 4
	sg.add_theme_constant_override("h_separation", 14)
	dv.add_child(sg)
	for pair in [["damage", stats.damage], ["defense", stats.defense], ["health", stats.health], ["crit", stats.crit], ["attack_speed", stats.attack_speed], ["cdr", stats.cdr]]:
		sg.add_child(UITheme.label(tr("stat." + str(pair[0])), 15, UITheme.TEXT_DIM))
		var v: float = pair[1]
		sg.add_child(UITheme.label(("%d%%" % int(v * 100)) if pair[0] in ["crit", "cdr"] else (Loc.num(v) if v >= 10 else "%.2f" % v), 16, UITheme.TEXT, true))
	dv.add_child(UITheme.primary_button(tr("ui.quick_equip"), func():
		Game.quick_equip(hero_id)
		rebuild(), 20, 0, 52))
	# Items
	var mid := UITheme.panel(Color(0.03, 0.02, 0.02, 0.9), UITheme.GOLD_DARK, 10)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	var mv := UITheme.vbox(8)
	mid.add_child(mv)
	var tabs := UITheme.hbox(4)
	mv.add_child(tabs)
	for f in FILTERS:
		var key: String = "ui.all" if f == "all" else ("slot." + f)
		var b := UITheme.button(tr(key), func():
			filter = f
			rebuild(), 14, 0, 40)
		if f == filter:
			b.add_theme_stylebox_override("normal", UITheme.box(Color(0.25, 0.16, 0.06), UITheme.GOLD, 2, 5, 2, 6))
		tabs.add_child(b)
	mv.add_child(UITheme.label("%d / %d" % [Game.inventory().size(), int(DB.cfg.inventory_capacity)], 14, UITheme.TEXT_DIM))
	grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var sc := ScreenBase.scroll(grid)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mv.add_child(sc)
	var items := Game.inventory().filter(func(it): return filter == "all" or it.get("slot", "") == filter or (filter == "gem" and it.get("kind", "") in ["gem", "rune"]))
	items.sort_custom(func(a, b): return int(a.get("rarity", 0)) * 10000 + ItemLogic.power(a) > int(b.get("rarity", 0)) * 10000 + ItemLogic.power(b))
	if items.is_empty():
		mv.add_child(UITheme.label(tr("ui.no_items"), 18, UITheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER))
	for it in items:
		var c := ItemCard.make(it, 92)
		var owner := Game.equipped_by(it.uid)
		if owner != "":
			var e := UITheme.label("E", 16, Color(0.5, 1, 0.5), true)
			e.position = Vector2(74, 64)
			c.add_child(e)
		if it.uid == selected_uid:
			c.modulate = Color(1.3, 1.25, 1.0)
		var uid: String = it.uid
		c.pressed.connect(func():
			Sfx.play("click", -6.0)
			selected_uid = uid
			it["new"] = false
			rebuild())
		grid.add_child(c)
	# Materials row
	var mats := UITheme.hbox(8)
	mv.add_child(mats)
	mats.add_child(UITheme.label(tr("ui.materials") + ":", 16, UITheme.GOLD, true))
	for m in DB.items.materials:
		mats.add_child(Icon.make("material", ModelLib._col(m.color), 30, false))
		var l := UITheme.label("%s %d" % [tr("item." + str(m.id)), Game.material_count(m.id)], 14, UITheme.TEXT)
		mats.add_child(l)
	# Detail
	var right := UITheme.panel(Color(0.03, 0.02, 0.02, 0.92), UITheme.GOLD_DIM, 12)
	right.custom_minimum_size = Vector2(380, 0)
	h.add_child(right)
	detail = UITheme.vbox(8)
	right.add_child(ScreenBase.scroll(detail))
	_fill_detail()


func _slot_tile(slot: String) -> Control:
	var it := Game.equipped_item(hero_id, slot)
	if it.is_empty():
		var e := Button.new()
		e.custom_minimum_size = Vector2(86, 86)
		e.tooltip_text = tr("slot." + slot)
		var ic := Icon.make(slot, Color(0.4, 0.38, 0.35), 56)
		ic.position = Vector2(15, 15)
		ic.dim = 0.45
		e.add_child(ic)
		e.pressed.connect(func():
			filter = slot
			rebuild())
		return e
	var c := ItemCard.make(it, 86)
	c.pressed.connect(func():
		selected_uid = it.uid
		rebuild())
	return c


func _fill_detail() -> void:
	var it := Game.find_item(selected_uid)
	if it.is_empty():
		detail.add_child(UITheme.label(tr("ui.no_items"), 18, UITheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER))
		return
	var col := ItemLogic.color_for(it)
	var hh := UITheme.hbox(10)
	detail.add_child(hh)
	hh.add_child(ItemCard.make(it, 96))
	var hv := UITheme.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(hv)
	var nl := UITheme.label(ItemLogic.display_name(it), 20, col, true)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(nl)
	hv.add_child(UITheme.label("%s  •  %s" % [tr("rarity." + str(DB.rarity(int(it.get("rarity", 0))).id)), tr("slot." + str(it.slot))], 15, col.lightened(0.2)))
	hv.add_child(UITheme.label("%s %d   %s %d%%" % [tr("ui.level"), int(it.level), tr("ui.quality"), int(it.quality)], 15, UITheme.TEXT_DIM))
	detail.add_child(UITheme.separator())
	var stats := ItemLogic.total_stats(it)
	for k in stats:
		var row := UITheme.hbox(6)
		row.add_child(UITheme.label(tr("stat." + str(k)), 16, UITheme.TEXT_DIM))
		row.add_child(UITheme.spacer())
		row.add_child(UITheme.label(Loc.stat_value(k, stats[k]), 16, UITheme.TEXT, true))
		detail.add_child(row)
	if ItemLogic.is_equipment(it):
		var sock := UITheme.hbox(6)
		sock.add_child(UITheme.label("%s: %d/%d" % [tr("ui.sockets"), it.gems.size(), int(it.sockets)], 15, UITheme.TEXT_DIM))
		for g in it.gems:
			sock.add_child(Icon.make("gem", ModelLib._col(DB.gem_or_rune(g).color), 24, false))
		detail.add_child(sock)
	detail.add_child(UITheme.label("%s: %s" % [tr("ui.value"), Loc.num(ItemLogic.sell_value(it))], 15, UITheme.GOLD))
	# Compare with equipped
	if ItemLogic.is_equipment(it):
		var eq := Game.equipped_item(hero_id, it.slot)
		if not eq.is_empty() and eq.uid != it.uid:
			detail.add_child(UITheme.separator())
			detail.add_child(UITheme.label(tr("ui.compare_title") + ": " + ItemLogic.display_name(eq), 15, UITheme.GOLD, true))
			var diff := ItemLogic.compare(it, eq)
			for k in diff:
				if absf(diff[k]) < 0.0001:
					continue
				var good: bool = diff[k] > 0
				var txt := Loc.stat_value(k, absf(diff[k]))
				txt = ("▲ " if good else "▼ ") + txt.trim_prefix("+")
				var row := UITheme.hbox(6)
				row.add_child(UITheme.label(tr("stat." + str(k)), 15, UITheme.TEXT_DIM))
				row.add_child(UITheme.spacer())
				row.add_child(UITheme.label(txt, 15, UITheme.GREEN if good else UITheme.RED, true))
				detail.add_child(row)
			var pd := ItemLogic.power(it) - ItemLogic.power(eq)
			detail.add_child(UITheme.label("%s %s%d" % [tr("ui.power"), "+" if pd >= 0 else "", pd], 16, UITheme.GREEN if pd >= 0 else UITheme.RED, true))
	detail.add_child(UITheme.separator())
	# Actions
	var owner := Game.equipped_by(it.uid)
	if ItemLogic.is_equipment(it):
		if owner == hero_id:
			detail.add_child(UITheme.button(tr("ui.unequip"), func():
				Game.unequip(hero_id, it.slot)
				rebuild(), 18, 0, 50))
		else:
			detail.add_child(UITheme.primary_button(tr("ui.equip"), func():
				Game.equip(hero_id, it.uid)
				Sfx.play("build", -6.0)
				rebuild(), 20, 0, 54))
		var cost := ItemLogic.upgrade_cost(it)
		if not cost.is_empty():
			var ub := UITheme.button("%s  %s %s  +  %s x%d" % [tr("ui.upgrade"), Loc.num(cost.gold), tr("ui.gold"), tr("item." + str(cost.material)), int(cost.count)], func():
				if Game.upgrade_item(it.uid):
					Sfx.play("levelup", -4.0)
				rebuild(), 15, 0, 50)
			ub.disabled = Game.gold() < int(cost.gold) or Game.material_count(cost.material) < int(cost.count)
			detail.add_child(ub)
		else:
			detail.add_child(UITheme.label(tr("ui.max"), 16, UITheme.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
		if it.gems.size() < int(it.sockets):
			detail.add_child(UITheme.button(tr("ui.socket"), func(): _socket_dialog(it), 16, 0, 48))
	var row2 := UITheme.hbox(8)
	detail.add_child(row2)
	var sell := UITheme.button("%s +%s" % [tr("ui.sell"), Loc.num(ItemLogic.sell_value(it))], func():
		Game.sell_item(it.uid)
		Sfx.play("coin", 0.0)
		selected_uid = ""
		rebuild(), 16, 170, 48)
	row2.add_child(sell)
	var del := UITheme.button(tr("ui.delete"), func():
		confirm(tr("ui.delete") + ": " + ItemLogic.display_name(it) + "?", func():
			Game.remove_item(it.uid)
			selected_uid = ""
			rebuild()), 16, 150, 48)
	del.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	row2.add_child(del)


func _socket_dialog(item: Dictionary) -> void:
	var v := modal(520)
	v.add_child(UITheme.title(tr("ui.choose_gem"), 28))
	var g := GridContainer.new()
	g.columns = 5
	v.add_child(g)
	var gems := Game.inventory().filter(func(x): return x.get("kind", "") in ["gem", "rune"])
	if gems.is_empty():
		v.add_child(UITheme.label(tr("ui.no_gems"), 18, UITheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER))
	for gem in gems:
		var c := ItemCard.make(gem, 84)
		c.tooltip_text += "\n" + tr("stat." + str(DB.gem_or_rune(gem.base).stat)) + " " + Loc.stat_value(DB.gem_or_rune(gem.base).stat, float(DB.gem_or_rune(gem.base).value))
		c.pressed.connect(func():
			Game.socket_gem(item.uid, gem.uid)
			Sfx.play("levelup", -4.0)
			close_modal()
			rebuild())
		g.add_child(c)
	v.add_child(UITheme.button(tr("ui.close"), close_modal, 18, 180, 48))
