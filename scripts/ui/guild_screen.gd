extends ScreenBase
## Guild (offline): AI companion members, donations, level and perks.

func _init() -> void:
	_title_key = "nav.guild"


func build() -> void:
	var g: Dictionary = Game.profile.guild
	var h := UITheme.hbox(16)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(h)
	var left := UITheme.panel(Color(0.03, 0.02, 0.02, 0.9), UITheme.GOLD_DIM, 16)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	var v := UITheme.vbox(10)
	left.add_child(v)
	var hh := UITheme.hbox(12)
	v.add_child(hh)
	hh.add_child(Icon.make("banner", Color(0.8, 0.2, 0.1), 80))
	var hv := UITheme.vbox(4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(hv)
	hv.add_child(UITheme.title(tr("ui.guild_name"), 30))
	hv.add_child(UITheme.label("%s %d" % [tr("ui.guild_level"), int(g.level)], 20, UITheme.GOLD, true))
	hv.add_child(UITheme.bar(int(g.xp), Game.guild_xp_needed(), Color(0.8, 0.3, 0.15), 14))
	var desc := UITheme.label(tr("ui.guild_desc"), 16, UITheme.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	v.add_child(UITheme.primary_button(tr("ui.donate"), func():
		if Game.guild_donate(1000):
			Sfx.play("coin", 0.0)
			rebuild(), 20, 280, 56))
	v.add_child(UITheme.separator())
	v.add_child(UITheme.label("%s  (%d)" % [tr("ui.perks"), Game.guild_perk_points()], 22, UITheme.GOLD, true))
	for p in DB.meta.guild.perks:
		var row := UITheme.hbox(10)
		v.add_child(row)
		var lv := int(g.perks.get(p.id, 0))
		row.add_child(UITheme.label(tr("perk." + str(p.id)), 18, UITheme.TEXT, true))
		row.add_child(UITheme.label(Loc.stat_value(p.stat, float(p.per_level) * lv), 16, UITheme.TEXT_DIM))
		row.add_child(UITheme.spacer())
		row.add_child(UITheme.label("%s %d" % [tr("ui.lv"), lv], 16, UITheme.GOLD))
		var b := UITheme.button("+", func():
			if Game.guild_upgrade_perk(p.id):
				rebuild(), 20, 48, 44)
		b.disabled = Game.guild_perk_points() <= 0
		row.add_child(b)
	var right := UITheme.panel(Color(0.03, 0.02, 0.02, 0.9), UITheme.GOLD_DIM, 16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var rv := UITheme.vbox(8)
	right.add_child(rv)
	rv.add_child(UITheme.label(tr("ui.members"), 22, UITheme.GOLD, true))
	var you := {"name": tr("ui.player"), "ai": "commander", "level": int(Game.profile.player_level)}
	for m in [you] + DB.meta.guild.bots:
		var row := UITheme.panel(Color(0.07, 0.05, 0.04), UITheme.GOLD_DARK, 8)
		rv.add_child(row)
		var mh := UITheme.hbox(10)
		row.add_child(mh)
		mh.add_child(Icon.make("hero", VFX.color(["fire", "ice", "poison", "shadow", "holy", "lightning"][hash(m.name) % 6]), 44))
		var mv := UITheme.vbox(0)
		mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mh.add_child(mv)
		mv.add_child(UITheme.label(str(m.name), 18, UITheme.TEXT, true))
		mv.add_child(UITheme.label("%s  •  %s %d" % [tr("role." + str(m.ai)), tr("ui.lv"), int(m.level)], 14, UITheme.TEXT_DIM))
		var online := (hash(str(m.name) + Time.get_date_string_from_system()) % 3) != 0
		mh.add_child(UITheme.label("●", 18, Color(0.4, 0.9, 0.4) if online else Color(0.4, 0.4, 0.4)))
