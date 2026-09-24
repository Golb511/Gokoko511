class_name ItemCard
extends Button
## Square inventory/loot tile: rarity frame, icon, level, upgrade and sockets.

var item: Dictionary


static func make(it: Dictionary, sz: float = 96.0) -> ItemCard:
	var c := ItemCard.new()
	c.item = it
	c.custom_minimum_size = Vector2(sz, sz)
	c.focus_mode = Control.FOCUS_NONE
	var col := ItemLogic.color_for(it) if not it.has("material") else ModelLib._col(DB.material(it.material).get("color", [0.6, 0.6, 0.6]))
	var bg := UITheme.box(Color(col.r * 0.12, col.g * 0.12, col.b * 0.12, 0.95), col.darkened(0.2), 2, 6, 2, 4)
	var hv := bg.duplicate()
	hv.border_color = col.lightened(0.3)
	hv.bg_color = Color(col.r * 0.2, col.g * 0.2, col.b * 0.2, 0.95)
	c.add_theme_stylebox_override("normal", bg)
	c.add_theme_stylebox_override("hover", hv)
	c.add_theme_stylebox_override("pressed", hv)
	c.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var glyph := "material" if it.has("material") else ItemLogic.icon_for(it)
	var ic := Icon.make(glyph, col, sz * 0.7)
	ic.position = Vector2(sz * 0.15, sz * 0.12)
	c.add_child(ic)
	if it.has("material"):
		var cl := UITheme.label("x%d" % int(it.get("count", 1)), int(sz * 0.2), UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_RIGHT)
		cl.position = Vector2(sz * 0.3, sz * 0.7)
		cl.size = Vector2(sz * 0.65, sz * 0.25)
		c.add_child(cl)
		c.tooltip_text = TranslationServer.translate("item." + str(it.material))
		return c
	var lv := UITheme.label(str(int(it.get("level", 1))), int(sz * 0.18), UITheme.TEXT, true)
	lv.position = Vector2(sz * 0.06, sz * 0.02)
	c.add_child(lv)
	if int(it.get("upgrade", 0)) > 0:
		var up := UITheme.label("+%d" % int(it.upgrade), int(sz * 0.18), Color(0.5, 1, 0.5), true, HORIZONTAL_ALIGNMENT_RIGHT)
		up.position = Vector2(sz * 0.45, sz * 0.02)
		up.size = Vector2(sz * 0.5, sz * 0.2)
		c.add_child(up)
	for s in int(it.get("sockets", 0)):
		var filled: bool = s < it.get("gems", []).size()
		var gcol := Color(0.25, 0.22, 0.2)
		if filled:
			gcol = ModelLib._col(DB.gem_or_rune(it.gems[s]).get("color", [1, 1, 1]))
		var dot := Icon.make("gem", gcol, sz * 0.14, false)
		dot.position = Vector2(sz * 0.08 + s * sz * 0.16, sz * 0.8)
		c.add_child(dot)
	if it.get("new", false):
		var n := UITheme.label(TranslationServer.translate("ui.new"), int(sz * 0.14), Color(1, 0.4, 0.3), true)
		n.position = Vector2(sz * 0.55, sz * 0.72)
		c.add_child(n)
	c.tooltip_text = ItemLogic.display_name(it) + "\n" + TranslationServer.translate("rarity." + str(DB.rarity(int(it.get("rarity", 0))).id))
	return c
