extends ScreenBase
## Shop: Daily Offers, Limited Offers, Weapons, Armor, Gauntlets, Boots,
## Rings, Necklaces, Materials, Chests, Gold and Gems. Stock is seeded per
## day so it is stable across sessions; purchases are tracked in the save.

const TABS := ["daily", "limited", "weapon", "armor", "gloves", "boots", "ring", "necklace", "materials", "chests", "gold", "gems"]
const LIMITED := [
	{"id": "lim_warlord", "name": ["Warlord's Hoard", "كنز أمير الحرب"], "cost": {"gems": 450}, "reward": {"gold": 6000, "chest": "chest_legendary"}},
	{"id": "lim_dragon", "name": ["Dragon Bundle", "حزمة التنين"], "cost": {"gems": 220}, "reward": {"material": "dragon_scale", "count": 6, "chest": "chest_epic"}},
	{"id": "lim_void", "name": ["Void Cache", "مخبأ الفراغ"], "cost": {"gold": 12000}, "reward": {"material": "void_essence", "count": 3}},
]
var tab := "daily"


func _init() -> void:
	_title_key = "nav.shop"


func _day_rng(salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Time.get_date_string_from_system() + salt + str(Game.profile.created))
	return r


func _ensure_day() -> void:
	var today := Time.get_date_string_from_system()
	if Game.profile.shop.date != today:
		Game.profile.shop.date = today
		Game.profile.shop.bought = []
		Game.mark_dirty()


func _bought(key: String) -> bool:
	return key in Game.profile.shop.bought


func _mark_bought(key: String) -> void:
	Game.profile.shop.bought.append(key)
	Game.mark_dirty()


func build() -> void:
	_ensure_day()
	var v := UITheme.vbox(10)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(v)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	v.add_child(tabs)
	var labels := {"daily": "ui.daily_offers", "limited": "ui.limited_offers", "materials": "ui.materials", "chests": "slot.chest", "gold": "ui.gold", "gems": "ui.gems"}
	for t in TABS:
		var key: String = labels.get(t, "slot." + t)
		var b := UITheme.button(tr(key), func():
			tab = t
			rebuild(), 16, 0, 44)
		if t == tab:
			b.add_theme_stylebox_override("normal", UITheme.box(Color(0.3, 0.18, 0.06), UITheme.GOLD, 2, 5, 2, 8))
		tabs.add_child(b)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var sc := ScreenBase.scroll(grid)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	match tab:
		"daily":
			var rng := _day_rng("daily")
			var lvl := int(Game.profile.player_level) + 1
			for i in 8:
				seed(rng.randi())
				var it := LootGenerator.generate_equipment(lvl, LootGenerator.roll_rarity(1.8, 1), "", 1.8)
				var price := {"gold": int(it.value) * 3} if int(it.rarity) < 3 else {"gems": 40 + 40 * (int(it.rarity) - 2)}
				grid.add_child(_item_offer("daily%d" % i, it, price, true))
			randomize()
			var end := _seconds_to_midnight()
			v.add_child(UITheme.label("%s %s" % [tr("ui.ends_in"), _fmt_time(end)], 16, UITheme.GOLD, true))
		"limited":
			for o in LIMITED:
				grid.add_child(_bundle_offer(o))
			v.add_child(UITheme.label("%s %s" % [tr("ui.ends_in"), _fmt_time(_seconds_to_week_end())], 16, UITheme.GOLD, true))
		"weapon", "armor", "gloves", "boots", "ring", "necklace":
			var rng := _day_rng(tab)
			for i in 8:
				seed(rng.randi())
				var it := LootGenerator.generate_equipment(int(Game.profile.player_level), LootGenerator.roll_rarity(1.2), tab)
				var price := {"gold": int(it.value) * 4} if int(it.rarity) < 3 else {"gems": 60 + 50 * (int(it.rarity) - 2)}
				grid.add_child(_item_offer(tab + str(i), it, price, true))
			randomize()
		"materials":
			for m in DB.meta.shop.materials:
				grid.add_child(_simple_offer("material", ModelLib._col(DB.material(m.id).color), "%s x%d" % [tr("item." + str(m.id)), int(m.count)], m.cost, func(): Game.add_material(m.id, int(m.count))))
		"chests":
			for c in DB.meta.shop.chests:
				grid.add_child(_simple_offer("chest", DB.rarity_color(int(c.min_rarity)), tr("item." + str(c.id)), c.cost, func(): _open_chest(c)))
		"gold":
			for g in DB.meta.shop.gold_packs:
				grid.add_child(_simple_offer("coin", Color.GOLD, "%s %s" % [Loc.num(g.gold), tr("ui.gold")], g.cost, func(): Game.add_gold(int(g.gold))))
			grid.add_child(_simple_offer("energy", Color(1, 0.8, 0.2), tr("ui.refill_energy"), DB.meta.shop.energy_refill.cost, func(): Game.add_energy(int(DB.cfg.energy_max))))
		"gems":
			for g in DB.meta.shop.gem_packs:
				grid.add_child(_iap_offer(g))


func _card() -> VBoxContainer:
	var p := UITheme.panel(Color(0.06, 0.04, 0.03, 0.95), UITheme.GOLD_DARK, 10)
	p.custom_minimum_size = Vector2(300, 250)
	var v := UITheme.vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	v.set_meta("panel", p)
	return v


func _price_button(key: String, cost: Dictionary, on_buy: Callable, once := false) -> Button:
	var txt := ""
	if cost.has("gold"):
		txt = "%s %s" % [Loc.num(cost.gold), tr("ui.gold")]
	elif cost.has("gems"):
		txt = "%s %s" % [Loc.num(cost.gems), tr("ui.gems")]
	var b := UITheme.primary_button(txt, func():
		if once and _bought(key):
			return
		if Game.spend(cost):
			on_buy.call()
			if once:
				_mark_bought(key)
			Sfx.play("coin", 0.0)
			rebuild(), 18, 220, 50)
	if once and _bought(key):
		b.text = tr("ui.claimed")
		b.disabled = true
	elif not Game.can_afford(cost):
		b.modulate = Color(0.7, 0.6, 0.6)
	return b


func _item_offer(key: String, it: Dictionary, price: Dictionary, once: bool) -> Control:
	var v := _card()
	var c := ItemCard.make(it, 96)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(c)
	var nl := UITheme.label(ItemLogic.display_name(it), 16, ItemLogic.color_for(it), true, HORIZONTAL_ALIGNMENT_CENTER)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(280, 0)
	v.add_child(nl)
	var s := ItemLogic.total_stats(it)
	var parts: Array = []
	for k in s:
		parts.append("%s %s" % [tr("stat." + str(k)), Loc.stat_value(k, s[k])])
	var sl := UITheme.label(", ".join(PackedStringArray(parts.slice(0, 3))), 13, UITheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size = Vector2(280, 0)
	v.add_child(sl)
	var b := _price_button(key, price, func():
		it["uid"] = LootGenerator.new_uid()
		Game.add_item(it), once)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	return v.get_meta("panel")


func _simple_offer(glyph: String, col: Color, title: String, cost: Dictionary, on_buy: Callable) -> Control:
	var v := _card()
	var ic := Icon.make(glyph, col, 96)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	v.add_child(UITheme.label(title, 18, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	var b := _price_button("", cost, on_buy)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	return v.get_meta("panel")


func _bundle_offer(o: Dictionary) -> Control:
	var v := _card()
	var p: PanelContainer = v.get_meta("panel")
	p.add_theme_stylebox_override("panel", UITheme.box(Color(0.12, 0.05, 0.08, 0.95), Color(0.85, 0.4, 1.0), 2, 8, 8, 10))
	var ic := Icon.make("chest", Color(0.85, 0.45, 1.0), 96)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	v.add_child(UITheme.label(o.name[1] if Loc.is_rtl() else o.name[0], 20, Color(1, 0.8, 0.5), true, HORIZONTAL_ALIGNMENT_CENTER))
	var r: Dictionary = o.reward
	var parts: Array = []
	if r.has("gold"): parts.append("%s %s" % [Loc.num(r.gold), tr("ui.gold")])
	if r.has("material"): parts.append("%s x%d" % [tr("item." + str(r.material)), int(r.count)])
	if r.has("chest"): parts.append(tr("item." + str(r.chest)))
	v.add_child(UITheme.label(" + ".join(PackedStringArray(parts)), 14, UITheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER))
	var b := _price_button(o.id, o.cost, func(): Game.grant_reward(r), true)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	return p


func _iap_offer(g: Dictionary) -> Control:
	var v := _card()
	var ic := Icon.make("diamond", Color(0.4, 0.7, 1), 96)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	v.add_child(UITheme.label("%s %s" % [Loc.num(g.gems), tr("ui.gems")], 20, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	# Real-money purchases require a platform store (Google Play / App Store /
	# Steam) plugin; this build grants the pack as a test purchase.
	var b := UITheme.primary_button(str(g.price), func():
		Game.add_gems(int(g.gems))
		Events.notify(tr("ui.iap_offline"), Color(0.6, 0.8, 1))
		Sfx.play("coin", 0.0)
		rebuild(), 18, 200, 50)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	return v.get_meta("panel")


func _open_chest(c: Dictionary) -> void:
	var items := LootGenerator.open_chest(c, int(Game.profile.player_level))
	for it in items:
		Game.add_item(it)
	var v := modal(640)
	v.add_child(UITheme.title(tr("ui.opened_chest"), 34))
	var h := UITheme.hbox(10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	for it in items:
		var col := UITheme.vbox(4)
		col.add_child(ItemCard.make(it, 110))
		var nl := UITheme.label(ItemLogic.display_name(it), 13, ItemLogic.color_for(it), true, HORIZONTAL_ALIGNMENT_CENTER)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(120, 0)
		col.add_child(nl)
		h.add_child(col)
	Sfx.play("levelup", 0.0)
	v.add_child(UITheme.primary_button(tr("ui.close"), close_modal, 20, 200, 52))


func _seconds_to_midnight() -> int:
	var t := Time.get_datetime_dict_from_system()
	return (23 - int(t.hour)) * 3600 + (59 - int(t.minute)) * 60 + (60 - int(t.second))


func _seconds_to_week_end() -> int:
	var t := Time.get_datetime_dict_from_system()
	var days_left := (7 - int(t.weekday)) % 7
	return days_left * 86400 + _seconds_to_midnight()


func _fmt_time(s: int) -> String:
	if s >= 86400:
		return "%dd %02dh" % [s / 86400, (s % 86400) / 3600]
	return "%02d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]
