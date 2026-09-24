extends ScreenBase
## Missions: daily quests with progress and rewards + 7-day login calendar.

func _init() -> void:
	_title_key = "nav.missions"


func build() -> void:
	Game.ensure_daily_quests()
	var h := UITheme.hbox(16)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(h)
	var left := UITheme.panel(Color(0.03, 0.02, 0.02, 0.9), UITheme.GOLD_DIM, 14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	var v := UITheme.vbox(10)
	left.add_child(v)
	v.add_child(UITheme.label(tr("ui.daily_quests"), 26, UITheme.GOLD, true))
	for q in Game.profile.quests.list:
		var qd := DB.find_in(DB.meta.quests, q.id)
		v.add_child(_quest_row(q, qd))
	var right := UITheme.panel(Color(0.03, 0.02, 0.02, 0.9), UITheme.GOLD_DIM, 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var rv := UITheme.vbox(12)
	right.add_child(rv)
	rv.add_child(UITheme.label(tr("ui.daily_rewards"), 26, UITheme.GOLD, true))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	rv.add_child(grid)
	var today := Game.daily_day_index()
	for i in DB.meta.daily_rewards.size():
		grid.add_child(DailyRewardTile.make(i, today))
	var b := UITheme.primary_button(tr("ui.claim") if Game.can_claim_daily() else tr("ui.claimed"), func():
		if Game.claim_daily():
			Sfx.play("levelup", 0.0)
			rebuild(), 22, 280, 60)
	b.disabled = not Game.can_claim_daily()
	rv.add_child(b)


func _quest_row(q: Dictionary, qd: Dictionary) -> Control:
	var p := UITheme.panel(Color(0.07, 0.05, 0.04, 0.95), UITheme.GOLD_DARK, 10)
	var h := UITheme.hbox(12)
	p.add_child(h)
	h.add_child(Icon.make("scroll", UITheme.GOLD, 50))
	var v := UITheme.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UITheme.label("%s  (%d)" % [tr("stat_desc." + str(qd.stat)), int(qd.target)], 19, UITheme.TEXT, true))
	var bar := UITheme.bar(int(q.progress), int(qd.target), Color(0.8, 0.6, 0.25), 14)
	v.add_child(bar)
	var rw: Dictionary = qd.reward
	var parts: Array = []
	if rw.has("gold"): parts.append("%s %s" % [Loc.num(rw.gold), tr("ui.gold")])
	if rw.has("gems"): parts.append("%d %s" % [int(rw.gems), tr("ui.gems")])
	if rw.has("xp"): parts.append("%d %s" % [int(rw.xp), tr("ui.xp")])
	v.add_child(UITheme.label("%s: %s   •   %d/%d" % [tr("ui.reward"), " + ".join(PackedStringArray(parts)), int(q.progress), int(qd.target)], 14, UITheme.TEXT_DIM))
	if q.claimed:
		h.add_child(UITheme.label(tr("ui.claimed"), 18, Color(0.5, 0.9, 0.5), true))
	else:
		var b := UITheme.primary_button(tr("ui.claim"), func():
			if Game.claim_quest(q.id):
				Sfx.play("coin", 0.0)
				rebuild(), 18, 140, 50)
		b.disabled = int(q.progress) < int(qd.target)
		h.add_child(b)
	return p
