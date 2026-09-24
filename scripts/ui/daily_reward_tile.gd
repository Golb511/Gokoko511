class_name DailyRewardTile
extends PanelContainer
## One day in the 7-day login calendar.

static func make(i: int, today: int) -> DailyRewardTile:
	var t := DailyRewardTile.new()
	var r: Dictionary = DB.meta.daily_rewards[i]
	var claimed := i < today or (i == today and not Game.can_claim_daily())
	var border := UITheme.GOLD if i == today else UITheme.GOLD_DARK
	t.add_theme_stylebox_override("panel", UITheme.box(Color(0.08, 0.05, 0.03, 0.95) if not claimed else Color(0.03, 0.03, 0.03, 0.9), border, 3 if i == today else 1, 8, 4, 8))
	t.custom_minimum_size = Vector2(118, 150)
	var v := UITheme.vbox(4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	t.add_child(v)
	v.add_child(UITheme.label("%s %d" % [TranslationServer.translate("ui.day"), i + 1], 16, UITheme.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	var glyph := "coin"
	var col := Color.GOLD
	var txt := ""
	if r.has("chest"):
		glyph = "chest"
		col = Color(0.8, 0.4, 1.0)
		txt = TranslationServer.translate("item." + str(r.chest))
	elif r.has("gems"):
		glyph = "diamond"
		col = Color(0.4, 0.7, 1)
		txt = str(r.gems)
	elif r.has("material"):
		glyph = "material"
		col = Color(0.4, 0.9, 1)
		txt = "%s x%d" % [TranslationServer.translate("item." + str(r.material)), int(r.count)]
	else:
		txt = Loc.num(r.gold)
	var ic := Icon.make(glyph, col, 56)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if claimed:
		ic.dim = 0.6
	v.add_child(ic)
	var l := UITheme.label(txt, 14, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(108, 0)
	v.add_child(l)
	if claimed:
		v.add_child(UITheme.label(TranslationServer.translate("ui.claimed"), 13, Color(0.5, 0.9, 0.5), true, HORIZONTAL_ALIGNMENT_CENTER))
	return t
