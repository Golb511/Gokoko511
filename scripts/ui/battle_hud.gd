class_name BattleHUD
extends CanvasLayer
## In-battle interface. Works with mouse and touch (large hit targets).

const TOWER_GLYPH := {"archer": "arrows", "mage": "staff", "artillery": "blast", "soldier": "summon", "poison": "poison",
	"fire": "fire", "ice": "ice", "lightning": "bolt", "shadow": "shadow", "light": "star", "earth": "rock",
	"wind": "dash", "crossbow": "crossbow", "trap": "mark"}

var battle: BattleController
var root: Control
var wave_label: Label
var wave_btn: Button
var gold_label: Label
var lives_label: Label
var speed_btn: Button
var auto_btn: Button
var boss_panel: Control
var boss_bar: ProgressBar
var boss_name: Label
var boss: Boss
var hero_portrait: Button
var hero_hp: ProgressBar
var hero_energy: ProgressBar
var hero_respawn: Label
var ability_btns: Array[AbilityButton] = []
var global_btns: Dictionary = {}
var ult_label: Label
var hint_label: Label
var toast_box: VBoxContainer
var popup: Control
var pause_panel: Control
var rally_tower: Tower = null
var _speed := 1


func setup(b: BattleController) -> void:
	battle = b
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(root)
	_build_top()
	_build_hero_panel()
	_build_right_panel()
	hint_label = UITheme.label("", 22, UITheme.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_label.custom_minimum_size = Vector2(700, 40)
	hint_label.offset_bottom = -170
	root.add_child(hint_label)
	toast_box = UITheme.vbox(6)
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.custom_minimum_size = Vector2(700, 0)
	toast_box.offset_top = 120
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
	Events.battle_gold_changed.connect(func(g): gold_label.text = Loc.num(g))
	Events.battle_lives_changed.connect(_on_lives)
	Events.wave_started.connect(func(i, n):
		wave_label.text = ("%s %d" % [tr("battle.wave"), i + 1]) if battle.waves.endless else ("%s %d/%d" % [tr("battle.wave"), i + 1, n])
		if i == 0:
			show_hint(""))
	Events.boss_spawned.connect(_on_boss)
	Events.toast.connect(toast)
	Events.battle_ended.connect(_on_end)
	Events.boss_phase_changed.connect(func(_b, _p): toast(tr("battle.boss_phase"), Color(1, 0.3, 0.2)))
	wave_label.text = ("%s 0" % tr("battle.wave")) if battle.waves.endless else ("%s 0/%d" % [tr("battle.wave"), battle.waves.total()])
	show_hint(tr("battle.first_wave_hint"))


# ---------------------------------------------------------------- layout
func _build_top() -> void:
	var tl := UITheme.panel(Color(0.03, 0.02, 0.02, 0.8), UITheme.GOLD_DIM, 8)
	tl.position = Vector2(16, 14)
	root.add_child(tl)
	var v := UITheme.vbox(6)
	tl.add_child(v)
	var h := UITheme.hbox(10)
	v.add_child(h)
	h.add_child(Icon.make("skull", Color(0.9, 0.3, 0.2), 34))
	wave_label = UITheme.label("", 24, UITheme.GOLD, true)
	h.add_child(wave_label)
	var stage_name := tr("mode.endless") if battle.stage_id == DB.ENDLESS else tr("region." + str(DB.stage_info(battle.stage_id).region.id)) + "  " + DB.stage_label(battle.stage_id)
	var stage_lbl := UITheme.label("  " + stage_name, 16, UITheme.TEXT_DIM)
	h.add_child(stage_lbl)
	wave_btn = UITheme.primary_button(tr("battle.start"), call_next_wave, 20, 230, 50)
	v.add_child(wave_btn)

	var tr_ := UITheme.panel(Color(0.03, 0.02, 0.02, 0.8), UITheme.GOLD_DIM, 8)
	tr_.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tr_.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr_.offset_right = -16
	tr_.offset_top = 14
	root.add_child(tr_)
	var hr := UITheme.hbox(10)
	tr_.add_child(hr)
	hr.add_child(Icon.make("heart", Color.RED, 34, false))
	lives_label = UITheme.label(str(battle.lives), 26, Color(1, 0.6, 0.55), true)
	hr.add_child(lives_label)
	hr.add_child(Icon.make("coin", Color.GOLD, 34, false))
	gold_label = UITheme.label(Loc.num(battle.gold), 26, UITheme.GOLD, true)
	gold_label.custom_minimum_size.x = 80
	hr.add_child(gold_label)
	var pause := _icon_button("pause", toggle_pause, 50)
	hr.add_child(pause)
	speed_btn = UITheme.button("x1", toggle_speed, 20, 60, 50)
	hr.add_child(speed_btn)
	auto_btn = UITheme.button(tr("battle.auto"), toggle_auto, 18, 90, 50)
	auto_btn.toggle_mode = true
	hr.add_child(auto_btn)

	boss_panel = UITheme.panel(Color(0.05, 0.01, 0.01, 0.85), Color(0.8, 0.2, 0.1), 8)
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss_panel.offset_top = 14
	boss_panel.custom_minimum_size = Vector2(640, 0)
	boss_panel.visible = false
	root.add_child(boss_panel)
	var bv := UITheme.vbox(4)
	boss_panel.add_child(bv)
	boss_name = UITheme.label("", 24, Color(1, 0.5, 0.35), true, HORIZONTAL_ALIGNMENT_CENTER)
	bv.add_child(boss_name)
	boss_bar = UITheme.bar(1, 1, Color(0.8, 0.12, 0.08), 20)
	bv.add_child(boss_bar)


func _icon_button(glyph: String, cb: Callable, sz := 56.0, tint := UITheme.GOLD) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(sz, sz)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	b.pressed.connect(func(): Sfx.play("click", -4.0))
	var ic := Icon.make(glyph, tint, sz * 0.7, false)
	ic.set_anchors_preset(Control.PRESET_CENTER)
	ic.position = -Vector2(sz, sz) * 0.35
	b.add_child(ic)
	return b


func _build_hero_panel() -> void:
	var panel := UITheme.panel(Color(0.03, 0.02, 0.02, 0.82), UITheme.GOLD_DIM, 8)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 16
	panel.offset_bottom = -16
	root.add_child(panel)
	var h := UITheme.hbox(10)
	panel.add_child(h)
	var hv := UITheme.vbox(4)
	h.add_child(hv)
	hero_portrait = Button.new()
	hero_portrait.custom_minimum_size = Vector2(96, 96)
	hero_portrait.focus_mode = Control.FOCUS_NONE
	hero_portrait.pressed.connect(func():
		var inp := _get_input()
		inp.select_hero(not inp.hero_selected)
		battle.camera_rig.focus_on(battle.hero.global_position))
	hv.add_child(hero_portrait)
	var face := Icon.make("hero", VFX.color(DB.heroes[battle.hero.hero_id].element), 80)
	face.set_anchors_preset(Control.PRESET_CENTER)
	face.position = Vector2(-40, -40)
	hero_portrait.add_child(face)
	Portraits.request(battle.hero.hero_id, func(tex):
		if tex and is_instance_valid(hero_portrait):
			face.visible = false
			var tr_ := TextureRect.new()
			tr_.texture = tex
			tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr_.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tr_.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hero_portrait.add_child(tr_))
	hero_respawn = UITheme.label("", 30, Color(1, 0.4, 0.3), true, HORIZONTAL_ALIGNMENT_CENTER)
	hero_respawn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero_portrait.add_child(hero_respawn)
	hero_hp = UITheme.bar(1, 1, Color(0.75, 0.15, 0.1), 12)
	hv.add_child(hero_hp)
	hero_energy = UITheme.bar(0, 1, Color(0.25, 0.55, 1.0), 10)
	hv.add_child(hero_energy)
	for i in 4:
		var ab: Dictionary = battle.hero.ability_def(i)
		var btn := AbilityButton.make(ab.icon, VFX.color(ab.element), 84, str(i + 1), str(int(ab.energy)))
		btn.tooltip_text = _ability_tooltip(battle.hero.ability_ids[i], ab)
		var idx := i
		btn.pressed.connect(func(): request_ability(idx))
		h.add_child(btn)
		ability_btns.append(btn)


func _ability_tooltip(id: String, ab: Dictionary) -> String:
	return "%s\n%s\n%s: %ds   %s: %d" % [tr("ability." + id), tr("abtype." + str(ab.type)), tr("ui.cooldown"), int(ab.cooldown), tr("ui.energy_cost"), int(ab.energy)]


func _build_right_panel() -> void:
	var panel := UITheme.panel(Color(0.03, 0.02, 0.02, 0.82), UITheme.GOLD_DIM, 8)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -16
	panel.offset_bottom = -16
	root.add_child(panel)
	var h := UITheme.hbox(12)
	panel.add_child(h)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	h.add_child(grid)
	var keys := {"meteor": "Z", "freeze": "X", "tower_buff": "C", "summon_dragon": "V"}
	for id in battle.globals.order:
		var d: Dictionary = DB.cfg.global_abilities[id]
		var btn := AbilityButton.make(d.icon, VFX.color(d.get("element", "holy")), 66, keys[id])
		btn.tooltip_text = "%s\n%s" % [tr("global." + id), tr("global." + id + ".desc")]
		var gid: String = id
		btn.pressed.connect(func(): request_global(gid))
		if not battle.globals.is_unlocked(id):
			btn.disabled = true
			btn.icon_ctrl.dim = 0.75
			btn.tooltip_text += "\n" + tr("ui.locked")
		grid.add_child(btn)
		global_btns[id] = btn
	var uv := UITheme.vbox(2)
	h.add_child(uv)
	var ult_ab: Dictionary = battle.hero.ability_def(4)
	var ult := AbilityButton.make(ult_ab.icon, VFX.color(ult_ab.element), 124, "R", "")
	ult.tooltip_text = _ability_tooltip(battle.hero.ability_ids[4], ult_ab)
	ult.pressed.connect(func(): request_ability(4))
	uv.add_child(ult)
	ability_btns.append(ult)
	ult_label = UITheme.label("0", 22, Color(1, 0.9, 0.6), true, HORIZONTAL_ALIGNMENT_CENTER)
	uv.add_child(ult_label)


func _get_input() -> BattleInput:
	for c in battle.get_children():
		if c is BattleInput:
			return c
	return null


# ---------------------------------------------------------------- per-frame
func _process(_delta: float) -> void:
	var h := battle.hero
	hero_hp.value = h.hp_ratio()
	hero_energy.value = h.energy / h.max_energy
	hero_respawn.text = "" if h.alive else str(ceili(h.respawn_timer))
	ult_label.text = "%d/%d" % [int(h.energy), int(float(h.ability_def(4).energy))]
	for i in ability_btns.size():
		var ab: Dictionary = h.ability_def(i)
		var cd_max := float(ab.cooldown) * (1.0 - h.cdr)
		ability_btns[i].set_state(h.cooldowns[i] / maxf(0.01, cd_max), h.can_cast(i))
	for id in global_btns:
		if not battle.globals.is_unlocked(id):
			continue
		var d: Dictionary = DB.cfg.global_abilities[id]
		global_btns[id].set_state(float(battle.globals.cooldowns[id]) / float(d.cooldown), battle.globals.can_use(id))
	if boss != null and is_instance_valid(boss):
		boss_bar.value = boss.hp_ratio()
		if not boss.alive:
			boss_panel.visible = false
	var w := battle.waves
	if w.is_waiting_first():
		wave_btn.text = tr("battle.start")
		wave_btn.visible = true
	elif w.countdown > 0.0:
		wave_btn.visible = true
		wave_btn.text = "%s (%d)  +%d" % [tr("battle.next_wave"), ceili(w.countdown), int(w.countdown * float(DB.cfg.early_wave_bonus_per_sec))]
	else:
		wave_btn.visible = false
	if popup != null and is_instance_valid(popup) and popup.has_meta("tower"):
		_refresh_tower_popup_affordability()


# ---------------------------------------------------------------- actions
func call_next_wave() -> void:
	if battle.waves.can_call_early():
		battle.waves.start_next_wave(not battle.waves.is_waiting_first())
		show_hint("")
		Sfx.play("boss", -8.0)


func request_ability(i: int) -> void:
	var h := battle.hero
	if not h.can_cast(i):
		return
	var ab: Dictionary = h.ability_def(i)
	if ab.target == "point":
		_get_input().set_pending({"kind": "ability", "index": i})
	elif ab.target == "enemy":
		var t: Enemy = null
		var best := -1.0
		for e in battle.enemies_near(h.global_position, float(ab.get("range", 8.0))):
			if e.is_valid_target() and e.hp > best:
				best = e.hp
				t = e
		if t != null:
			h.cast(i, t.global_position, t)
	else:
		h.cast(i, h.global_position)


func request_global(id: String) -> void:
	if not battle.globals.can_use(id):
		return
	if battle.globals.needs_target(id):
		_get_input().set_pending({"kind": "global", "id": id})
	else:
		battle.globals.use(id, Vector3.ZERO)


func toggle_pause() -> void:
	if battle.ended:
		return
	if pause_panel != null and is_instance_valid(pause_panel):
		pause_panel.queue_free()
		pause_panel = null
		get_tree().paused = false
		return
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel = _modal()
	var v: VBoxContainer = pause_panel.get_meta("content")
	v.add_child(UITheme.title(tr("battle.paused"), 44))
	v.add_child(UITheme.primary_button(tr("battle.resume"), toggle_pause, 24, 320))
	v.add_child(UITheme.button(tr("battle.restart"), func():
		get_tree().paused = false
		Router.start_battle(battle.stage_id), 22, 320, 54))
	v.add_child(UITheme.button(tr("battle.quit"), func():
		get_tree().paused = false
		Router.goto("world_map"), 22, 320, 54))
	var ctrl := UITheme.label(tr("ui.controls_text"), 15, UITheme.TEXT_DIM)
	ctrl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ctrl.custom_minimum_size = Vector2(520, 0)
	v.add_child(ctrl)


func toggle_speed() -> void:
	_speed = 2 if _speed == 1 else 1
	Engine.time_scale = float(_speed)
	speed_btn.text = "x%d" % _speed


func toggle_auto() -> void:
	battle.hero.auto_mode = not battle.hero.auto_mode
	auto_btn.button_pressed = battle.hero.auto_mode
	auto_btn.add_theme_color_override("font_color", Color(0.5, 1, 0.5) if battle.hero.auto_mode else UITheme.GOLD)


func set_hero_selected(v: bool) -> void:
	hero_portrait.modulate = Color(1.3, 1.2, 0.9) if v else Color.WHITE


func show_hint(t: String) -> void:
	hint_label.text = t


func toast(t: String, c: Color = Color(1, 0.85, 0.5)) -> void:
	var l := UITheme.label(t, 26, c, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 8)
	toast_box.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	while toast_box.get_child_count() > 4:
		toast_box.get_child(0).free()


func _on_lives(v: int) -> void:
	lives_label.text = str(v)
	var tw := lives_label.create_tween()
	lives_label.modulate = Color(2, 0.5, 0.5)
	tw.tween_property(lives_label, "modulate", Color.WHITE, 0.4)


func _on_boss(b: Boss) -> void:
	boss = b
	boss_panel.visible = true
	boss_name.text = tr("boss." + b.unit_id)
	toast(tr("battle.boss_incoming"), Color(1, 0.3, 0.2))


# ---------------------------------------------------------------- popups
func has_popup() -> bool:
	return popup != null and is_instance_valid(popup)


func close_popups() -> void:
	if has_popup():
		if popup.has_meta("tower"):
			var t = popup.get_meta("tower")
			if is_instance_valid(t):
				t.show_range(false)
		popup.queue_free()
	popup = null


func open_build_menu(slot: BuildSlot) -> void:
	close_popups()
	var p := UITheme.panel(Color(0.03, 0.02, 0.02, 0.94), UITheme.GOLD, 10)
	root.add_child(p)
	popup = p
	var v := UITheme.vbox(6)
	p.add_child(v)
	v.add_child(UITheme.label(tr("battle.build"), 22, UITheme.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for id in battle.available_towers():
		var td: Dictionary = DB.towers[id]
		var cost := int(td.levels[0].cost)
		var b := Button.new()
		b.custom_minimum_size = Vector2(118, 124)
		b.focus_mode = Control.FOCUS_NONE
		var bv := UITheme.vbox(2)
		bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bv.alignment = BoxContainer.ALIGNMENT_CENTER
		bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bv)
		var ic := Icon.make(TOWER_GLYPH.get(id, "tower"), ModelLib._col(td.model.accent), 58)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bv.add_child(ic)
		var nl := UITheme.label(tr("tower." + id), 13, UITheme.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(110, 0)
		bv.add_child(nl)
		var cl := UITheme.label(str(cost), 18, UITheme.GOLD if battle.gold >= cost else Color(0.7, 0.3, 0.25), true, HORIZONTAL_ALIGNMENT_CENTER)
		bv.add_child(cl)
		var lv0: Dictionary = td.levels[0]
		b.tooltip_text = "%s\n%s: %s   %s: %.1f\n%s" % [tr("tower." + id), tr("ui.damage"), _dmg_text(lv0), tr("battle.range"), float(lv0.get("range", 0)), tr("battle.air") if td.get("air", true) else tr("battle.ground_only")]
		var tid: String = id
		b.pressed.connect(func():
			Sfx.play("click", -4.0)
			if battle.build_tower(slot, tid) != null:
				close_popups())
		grid.add_child(b)
	_position_popup(p, slot.global_position)


func _dmg_text(lv: Dictionary) -> String:
	if lv.has("soldiers"):
		return "%d x %s" % [int(lv.soldiers), tr("battle.soldiers")]
	var d: Array = lv.get("dmg", [0, 0])
	return "%d-%d" % [int(d[0]), int(d[1])]


func _position_popup(p: Control, world: Vector3) -> void:
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	var sp := battle.camera_rig.camera.unproject_position(world)
	var vs := root.get_viewport_rect().size
	# Open beside the target so the tower / slot itself stays visible.
	var x := sp.x + 110.0
	if x + p.size.x > vs.x - 8:
		x = sp.x - 110.0 - p.size.x
	p.position = Vector2(clampf(x, 8, vs.x - p.size.x - 8), clampf(sp.y - p.size.y * 0.5, 90, vs.y - p.size.y - 8))


func open_tower_menu(t: Tower) -> void:
	close_popups()
	var p := UITheme.panel(Color(0.03, 0.02, 0.02, 0.94), UITheme.GOLD, 10)
	p.custom_minimum_size = Vector2(340, 0)
	root.add_child(p)
	popup = p
	p.set_meta("tower", t)
	t.show_range(true)
	var v := UITheme.vbox(6)
	p.add_child(v)
	var head := UITheme.hbox(8)
	v.add_child(head)
	head.add_child(Icon.make(TOWER_GLYPH.get(t.tower_id, "tower"), t.accent(), 48))
	var hv := UITheme.vbox(0)
	head.add_child(hv)
	hv.add_child(UITheme.label(t.display_name(), 22, UITheme.GOLD, true))
	hv.add_child(UITheme.label("%s %d / %d" % [tr("ui.level"), t.level, t.max_level()], 16, UITheme.TEXT_DIM))
	v.add_child(UITheme.label("%s: %s   %s: %.1f" % [tr("ui.damage"), _dmg_text(t.data), tr("battle.range"), t.range_()], 16))
	var btns: Array = []
	if t.needs_branch_choice():
		v.add_child(UITheme.label(tr("battle.choose_path"), 18, UITheme.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
		var bh := UITheme.hbox(8)
		v.add_child(bh)
		for bi in t.tdef.branches.size():
			var br: Dictionary = t.tdef.branches[bi]
			var cost := int(br.levels[0].cost)
			var b := Button.new()
			b.custom_minimum_size = Vector2(160, 150)
			b.focus_mode = Control.FOCUS_NONE
			var bv := UITheme.vbox(2)
			bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bv.alignment = BoxContainer.ALIGNMENT_CENTER
			bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(bv)
			var ic := Icon.make(TOWER_GLYPH.get(t.tower_id, "tower"), ModelLib._col(br.accent), 56)
			ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			bv.add_child(ic)
			var nl := UITheme.label(tr("branch." + str(br.id)), 15, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.custom_minimum_size = Vector2(150, 0)
			bv.add_child(nl)
			bv.add_child(UITheme.label(str(cost), 18, UITheme.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
			b.tooltip_text = "%s\n%s: %s   %s: %.1f" % [tr("branch." + str(br.id)), tr("ui.damage"), _dmg_text(br.levels[0]), tr("battle.range"), float(br.levels[0].get("range", 0))]
			var idx: int = bi
			b.pressed.connect(func():
				Sfx.play("click", -4.0)
				if battle.upgrade_tower(t, idx):
					open_tower_menu(t))
			b.set_meta("cost", cost)
			bh.add_child(b)
			btns.append(b)
	elif t.can_upgrade():
		var cost := t.upgrade_cost()
		var b := UITheme.primary_button("%s  %d" % [tr("ui.upgrade"), cost], func():
			if battle.upgrade_tower(t):
				open_tower_menu(t), 20, 300, 54)
		b.set_meta("cost", cost)
		v.add_child(b)
		btns.append(b)
	else:
		v.add_child(UITheme.label(tr("ui.max"), 20, UITheme.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	p.set_meta("buttons", btns)
	var row := UITheme.hbox(8)
	v.add_child(row)
	if t.attack_type() == "barracks":
		row.add_child(UITheme.button(tr("battle.rally"), func():
			rally_tower = t
			close_popups()
			show_hint(tr("battle.rally")), 16, 150, 46))
	row.add_child(UITheme.button("%s  +%d" % [tr("ui.sell"), t.sell_value()], func():
		battle.sell_tower(t)
		close_popups(), 16, 150, 46))
	_position_popup(p, t.global_position + Vector3(0, 1.5, 0))


func _refresh_tower_popup_affordability() -> void:
	for b in popup.get_meta("buttons", []):
		if is_instance_valid(b):
			b.disabled = battle.gold < int(b.get_meta("cost", 0))


func finish_rally(p: Vector3) -> void:
	if rally_tower != null and is_instance_valid(rally_tower):
		var q := p
		if q.distance_to(rally_tower.global_position) > rally_tower.range_():
			q = rally_tower.global_position + (q - rally_tower.global_position).normalized() * rally_tower.range_()
		rally_tower.set_rally(q)
		VFX.ground_ring(battle.fx_root, q, 1.5, Color(1, 0.8, 0.3), 0.6)
	rally_tower = null
	show_hint("")


func _modal() -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := UITheme.panel(Color(0.03, 0.02, 0.02, 0.97), UITheme.GOLD, 24)
	center.add_child(p)
	var v := UITheme.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	dim.set_meta("content", v)
	return dim


# ---------------------------------------------------------------- end screens
func _on_end(victory: bool, result: Dictionary) -> void:
	close_popups()
	Engine.time_scale = 1.0
	await get_tree().create_timer(1.2).timeout
	var screen: Control = VictoryScreen.new() if (victory or result.get("endless", false)) else DefeatScreen.new()
	root.add_child(screen)
	screen.setup(result)
