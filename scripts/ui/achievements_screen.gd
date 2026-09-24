extends ScreenBase
## Achievements with three reward tiers each.

func _init() -> void:
	_title_key = "nav.achievements"


func build() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	var sc := ScreenBase.scroll(grid)
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(sc)
	for a in DB.meta.achievements:
		grid.add_child(_row(a))


func _row(a: Dictionary) -> Control:
	var st := Game.achievement_state(a.id)
	var value := Game.stat_value(a.stat)
	var reached := 0
	while reached < a.tiers.size() and value >= int(a.tiers[reached]):
		reached += 1
	st.reached = maxi(int(st.reached), reached)
	var claimed := int(st.claimed)
	var tier := mini(claimed, a.tiers.size() - 1)
	var target := int(a.tiers[tier])
	var p := UITheme.panel(Color(0.06, 0.04, 0.03, 0.95), UITheme.GOLD if int(st.reached) > claimed else UITheme.GOLD_DARK, 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UITheme.hbox(12)
	p.add_child(h)
	var tint: Color = [Color(0.8, 0.5, 0.3), Color(0.8, 0.8, 0.85), Color(1, 0.8, 0.3)][tier]
	h.add_child(Icon.make("trophy", tint, 60))
	var v := UITheme.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var th := UITheme.hbox(8)
	v.add_child(th)
	th.add_child(UITheme.label(tr("ach." + str(a.id)), 20, UITheme.GOLD, true))
	th.add_child(StarRow.make(claimed, a.tiers.size(), 18))
	v.add_child(UITheme.label("%s  %s" % [tr("stat_desc." + str(a.stat)), Loc.num(target)], 15, UITheme.TEXT_DIM))
	v.add_child(UITheme.bar(mini(value, target), target, Color(0.8, 0.6, 0.25), 12))
	var rw: Dictionary = a.reward[tier]
	var rtxt := ("%s %s" % [Loc.num(rw.gold), tr("ui.gold")]) if rw.has("gold") else ("%d %s" % [int(rw.gems), tr("ui.gems")])
	v.add_child(UITheme.label("%s: %s   •   %s/%s" % [tr("ui.reward"), rtxt, Loc.num(mini(value, target)), Loc.num(target)], 14, UITheme.TEXT_DIM))
	if claimed >= a.tiers.size():
		h.add_child(UITheme.label(tr("ui.max"), 18, UITheme.GOLD, true))
	else:
		var b := UITheme.primary_button(tr("ui.claim"), func():
			if Game.claim_achievement(a.id):
				Sfx.play("levelup", -2.0)
				rebuild(), 16, 120, 48)
		b.disabled = int(st.reached) <= claimed
		h.add_child(b)
	return p
