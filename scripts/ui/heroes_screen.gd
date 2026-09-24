extends ScreenBase
## Heroes: roster grid (portraits from the real models), 3D preview, stats,
## equipment slots, abilities, skill tree, select/unlock.

var selected := ""
var preview: HeroPreview
var detail: VBoxContainer


func _init() -> void:
	_title_key = "nav.heroes"


func build() -> void:
	if selected == "":
		selected = Game.profile.selected_hero
	var h := UITheme.hbox(16)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(h)
	# Roster
	var left := UITheme.panel(Color(0.03, 0.02, 0.02, 0.85), UITheme.GOLD_DARK, 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.1
	h.add_child(left)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	left.add_child(ScreenBase.scroll(grid))
	for id in DB.hero_order:
		grid.add_child(_card(id))
	# Detail
	var right := UITheme.panel(Color(0.03, 0.02, 0.02, 0.9), UITheme.GOLD_DIM, 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.4
	h.add_child(right)
	var rh := UITheme.hbox(12)
	right.add_child(rh)
	var pv := UITheme.vbox(8)
	rh.add_child(pv)
	preview = HeroPreview.make(DB.heroes[selected].model, Vector2(340, 470))
	pv.add_child(preview)
	detail = UITheme.vbox(8)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.add_child(ScreenBase.scroll(detail))
	detail.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_detail()


func _card(id: String) -> Control:
	var d: Dictionary = DB.heroes[id]
	var unlocked := Game.is_hero_unlocked(id)
	var col := VFX.color(d.element)
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 200)
	b.focus_mode = Control.FOCUS_NONE
	var border := UITheme.GOLD if id == selected else col.darkened(0.3)
	b.add_theme_stylebox_override("normal", UITheme.box(Color(col.r * 0.1, col.g * 0.1, col.b * 0.1, 0.95), border, 3 if id == selected else 2, 6, 4, 4))
	b.add_theme_stylebox_override("hover", UITheme.box(Color(col.r * 0.18, col.g * 0.18, col.b * 0.18, 0.95), UITheme.GOLD, 2, 6, 4, 4))
	b.add_theme_stylebox_override("pressed", UITheme.box(Color(0.05, 0.04, 0.03), UITheme.GOLD, 3, 6, 4, 4))
	var face := Icon.make("hero", col, 110)
	face.position = Vector2(20, 14)
	b.add_child(face)
	var tr_ := TextureRect.new()
	tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr_.position = Vector2(6, 6)
	tr_.size = Vector2(138, 150)
	tr_.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tr_)
	Portraits.request(id, func(tex):
		if tex and is_instance_valid(tr_):
			tr_.texture = tex
			face.visible = false)
	var name_l := UITheme.label(tr("hero." + id), 14, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	name_l.position = Vector2(0, 160)
	name_l.size = Vector2(150, 34)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(name_l)
	var lv := UITheme.label(str(int(Game.hero_state(id).level)), 18, UITheme.GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT)
	lv.position = Vector2(90, 132)
	lv.size = Vector2(52, 24)
	b.add_child(lv)
	if not unlocked:
		var lock := ColorRect.new()
		lock.color = Color(0, 0, 0, 0.6)
		lock.position = Vector2(4, 4)
		lock.size = Vector2(142, 192)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lock)
		var ll := UITheme.label(tr("ui.locked"), 16, UITheme.TEXT_DIM, true, HORIZONTAL_ALIGNMENT_CENTER)
		ll.position = Vector2(0, 70)
		ll.size = Vector2(150, 30)
		b.add_child(ll)
	b.pressed.connect(func():
		Sfx.play("click", -4.0)
		selected = id
		rebuild())
	return b


func _fill_detail() -> void:
	var id := selected
	var d: Dictionary = DB.heroes[id]
	var st := Game.hero_state(id)
	var stats := Game.hero_stats(id)
	var unlocked := Game.is_hero_unlocked(id)
	detail.add_child(UITheme.title(tr("hero." + id), 32))
	detail.add_child(UITheme.label("%s  •  %s" % [tr("role." + str(d.role)), tr(d.style)], 16, UITheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER))
	var lh := UITheme.hbox(8)
	detail.add_child(lh)
	lh.add_child(UITheme.label("%s %d" % [tr("ui.level"), int(st.level)], 20, UITheme.GOLD, true))
	var xb := UITheme.bar(int(st.xp), Game.hero_xp_needed(int(st.level)), Color(0.8, 0.6, 0.25), 14)
	xb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.add_child(xb)
	lh.add_child(UITheme.label("%s %s" % [tr("ui.power"), Loc.num(Game.hero_power(id))], 18, Color(1, 0.7, 0.35), true))
	# Stats
	var sg := GridContainer.new()
	sg.columns = 4
	sg.add_theme_constant_override("h_separation", 18)
	detail.add_child(sg)
	for pair in [["damage", stats.damage], ["defense", stats.defense], ["health", stats.health], ["attack_speed", stats.attack_speed], ["move_speed", stats.move_speed], ["energy", stats.energy], ["crit", stats.crit * 100.0], ["range", stats.range]]:
		sg.add_child(UITheme.label(tr("stat." + str(pair[0])), 16, UITheme.TEXT_DIM))
		var val: float = pair[1]
		var txt := Loc.num(val) if val >= 10.0 else "%.2f" % val
		if pair[0] == "crit":
			txt = "%d%%" % int(val)
		sg.add_child(UITheme.label(txt, 17, UITheme.TEXT, true))
	detail.add_child(UITheme.separator())
	# Abilities
	detail.add_child(UITheme.label(tr("ui.skills"), 18, UITheme.GOLD, true))
	var ah := UITheme.hbox(8)
	detail.add_child(ah)
	var abil: Array = d.abilities.duplicate()
	abil.append(d.ultimate)
	for i in abil.size():
		var ab: Dictionary = DB.abilities[abil[i]]
		var ic := Icon.make(ab.icon, VFX.color(ab.element), 62 if i < 4 else 76)
		ic.mouse_filter = Control.MOUSE_FILTER_PASS
		ic.tooltip_text = "%s%s\n%s\n%s %ds  •  %s %d" % [tr("ability." + str(abil[i])), ("  (" + tr("ui.ultimate") + ")") if i == 4 else "", tr("abtype." + str(ab.type)), tr("ui.cooldown"), int(ab.cooldown), tr("ui.energy_cost"), int(ab.energy)]
		ah.add_child(ic)
	var names := UITheme.label(", ".join(PackedStringArray(abil.map(func(a): return tr("ability." + str(a))))), 14, UITheme.TEXT_DIM)
	names.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(names)
	detail.add_child(UITheme.separator())
	# Equipment
	detail.add_child(UITheme.label(tr("ui.equipment"), 18, UITheme.GOLD, true))
	var eg := GridContainer.new()
	eg.columns = 6
	eg.add_theme_constant_override("h_separation", 6)
	detail.add_child(eg)
	for slot in DB.items.slots:
		var it := Game.equipped_item(id, slot)
		if it.is_empty():
			var e := Button.new()
			e.custom_minimum_size = Vector2(76, 76)
			e.tooltip_text = tr("slot." + slot)
			var ic := Icon.make(slot, Color(0.4, 0.38, 0.35), 50)
			ic.position = Vector2(13, 13)
			ic.dim = 0.4
			e.add_child(ic)
			e.pressed.connect(func(): Router.goto("inventory"))
			eg.add_child(e)
		else:
			var c := ItemCard.make(it, 76)
			c.pressed.connect(func(): Router.goto("inventory"))
			eg.add_child(c)
	# Actions
	var row := UITheme.hbox(10)
	detail.add_child(row)
	if unlocked:
		if Game.profile.selected_hero == id:
			row.add_child(UITheme.label(tr("ui.selected"), 20, Color(0.5, 1, 0.5), true))
		else:
			row.add_child(UITheme.primary_button(tr("ui.select"), func():
				Game.select_hero(id)
				rebuild(), 20, 160, 52))
		row.add_child(UITheme.button("%s (%d)" % [tr("ui.skill_tree"), Game.skill_points_available(id)], _skill_tree, 18, 200, 52))
		row.add_child(UITheme.button(tr("ui.quick_equip"), func():
			Game.quick_equip(id)
			rebuild(), 18, 170, 52))
	else:
		var u: Dictionary = d.unlock
		if u.type == "gems":
			row.add_child(UITheme.primary_button("%s  %d" % [tr("ui.unlock"), int(u.cost)], func():
				if Game.unlock_hero_with_gems(id):
					Sfx.play("levelup", 0.0)
					rebuild(), 20, 220, 52))
			row.add_child(Icon.make("diamond", Color(0.4, 0.7, 1), 36, false))
		elif u.type == "stage":
			row.add_child(UITheme.label("%s: %s %s" % [tr("ui.requires"), tr("ui.stage"), DB.stage_label(u.stage)], 18, UITheme.TEXT_DIM, true))


func _skill_tree() -> void:
	var id := selected
	var v := modal(1000)
	v.add_child(UITheme.title(tr("ui.skill_tree"), 34))
	v.add_child(UITheme.label("%s: %d" % [tr("ui.skill_points"), Game.skill_points_available(id)], 20, UITheme.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	var cols := UITheme.hbox(18)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cols)
	var abil_names: Array = DB.heroes[id].abilities
	for branch in ["offense", "defense", "mastery", "abilities"]:
		var cv := UITheme.vbox(6)
		cols.add_child(cv)
		cv.add_child(UITheme.label(tr("skill.branch." + branch), 20, UITheme.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
		for n in Game.SKILL_TREE:
			if n.branch != branch:
				continue
			var rank := Game.skill_rank(id, n.id)
			var p := UITheme.panel(Color(0.08, 0.05, 0.03), UITheme.GOLD if rank > 0 else UITheme.GOLD_DARK, 6)
			p.custom_minimum_size = Vector2(215, 0)
			cv.add_child(p)
			var nv := UITheme.vbox(4)
			p.add_child(nv)
			if n.branch == "abilities":
				var ai := int(str(n.id).substr(2))
				nv.add_child(UITheme.label(tr("ability." + str(abil_names[ai])), 18, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
				nv.add_child(UITheme.label(tr("skill.ability_desc"), 14, UITheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER))
			else:
				nv.add_child(UITheme.label(tr("skill." + str(n.id)), 18, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
				var stat_key: String = str(n.stat).replace("_pct", "").replace("ult_mult", "damage")
				nv.add_child(UITheme.label("%s %s / %s" % [tr("stat." + stat_key), Loc.stat_value("crit", float(n.per_rank)), tr("ui.rank")], 14, UITheme.TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER))
			var btn := UITheme.button("+   %d/%d" % [rank, Game.SKILL_MAX_RANK], func():
				if Game.learn_skill(id, n.id):
					Sfx.play("levelup", -4.0)
					close_modal()
					_skill_tree(), 18, 0, 38)
			btn.disabled = not Game.can_learn(id, n)
			nv.add_child(btn)
	v.add_child(UITheme.button(tr("ui.close"), func():
		close_modal()
		rebuild(), 20, 200, 52))
