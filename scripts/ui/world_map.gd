extends Control
## World map screen: 3D overworld + top bar, bottom navigation (Heroes,
## Missions, Shop, Arsenal, Achievements, Guild, More), region/stage panel,
## campaign & portal shortcuts and the daily reward popup.

var map3d: WorldMap3D
var vpc: SubViewportContainer
var panel: Control
var ui: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	vpc = SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vpc)
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_2X if GraphicsSettings.quality() >= 2 else Viewport.MSAA_DISABLED
	vpc.add_child(vp)
	map3d = WorldMap3D.new()
	vp.add_child(map3d)
	map3d.stage_clicked.connect(_open_stage)
	map3d.region_clicked.connect(_open_region)
	vpc.gui_input.connect(func(e): map3d.handle_input(e))
	_build_ui()
	Events.language_changed.connect(func(_l): Router.goto("world_map"))
	if Game.can_claim_daily() and not "--no-daily" in OS.get_cmdline_user_args():
		_daily_popup.call_deferred()


func _build_ui() -> void:
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	ui.add_child(TopBar.make())
	# Bottom navigation bar.
	var nav := PanelContainer.new()
	nav.add_theme_stylebox_override("panel", UITheme.box(Color(0.02, 0.015, 0.015, 0.9), UITheme.GOLD_DARK, 0, 0, 8, 6))
	nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	nav.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(nav)
	var h := UITheme.hbox(4)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_child(h)
	var portal := _nav_button("portal", "nav.portal", func(): map3d.focus_region(DB.regions.size() - 1); _open_region(DB.regions.size() - 1), Color(0.6, 0.35, 1.0), 96)
	h.add_child(portal)
	h.add_child(UITheme.spacer())
	for it in [["hero", "nav.heroes", "heroes"], ["missions", "nav.missions", "missions"], ["shop", "nav.shop", "shop"], ["crossed", "nav.arsenal", "inventory"], ["trophy", "nav.achievements", "achievements"], ["guild", "nav.guild", "guild"], ["more", "nav.more", "settings"]]:
		var target: String = it[2]
		h.add_child(_nav_button(it[0], it[1], func(): Router.goto(target), UITheme.GOLD, 84))
	h.add_child(UITheme.spacer())
	var camp := UITheme.primary_button(tr("nav.campaign"), _campaign, 28, 200, 76)
	h.add_child(camp)


func _nav_button(glyph: String, key: String, cb: Callable, tint: Color, w: float) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, 84)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", UITheme.box(Color(0.15, 0.1, 0.05, 0.6), UITheme.GOLD_DARK, 1, 6, 0, 4))
	b.add_theme_stylebox_override("pressed", UITheme.box(Color(0.1, 0.07, 0.04, 0.8), UITheme.GOLD, 1, 6, 0, 4))
	var v := UITheme.vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := Icon.make(glyph, tint, 46, false)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	v.add_child(UITheme.label(tr(key), 15, UITheme.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	b.pressed.connect(cb)
	b.pressed.connect(func(): Sfx.play("click", -4.0))
	return b


func _campaign() -> void:
	var s := Game.next_stage()
	if s == "":
		s = DB.stage_order[0]
	_open_stage(s)


func _close_panel() -> void:
	if panel and is_instance_valid(panel):
		panel.queue_free()
	panel = null


func _side_panel() -> VBoxContainer:
	_close_panel()
	panel = UITheme.panel(Color(0.03, 0.02, 0.02, 0.94), UITheme.GOLD, 16)
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = 92
	panel.offset_bottom = -110
	panel.offset_right = -14
	panel.custom_minimum_size = Vector2(430, 0)
	ui.add_child(panel)
	var v := UITheme.vbox(10)
	panel.add_child(v)
	panel.position.x += 40
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	return v


func _open_region(ri: int) -> void:
	var r: Dictionary = DB.regions[ri]
	map3d.focus_region(ri)
	var v := _side_panel()
	var head := UITheme.hbox(8)
	v.add_child(head)
	var t := UITheme.title(tr("region." + str(r.id)), 30)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UITheme.button("✕", _close_panel, 18, 44, 44))
	v.add_child(UITheme.separator())
	for s in r.stages:
		v.add_child(_stage_row(s))
	v.add_child(UITheme.separator())
	v.add_child(UITheme.label(tr("boss." + str(r.boss)), 20, Color(1, 0.4, 0.3), true, HORIZONTAL_ALIGNMENT_CENTER))


func _stage_row(s: Dictionary) -> Control:
	var unlocked := Game.is_stage_unlocked(s.id)
	var p := UITheme.panel(Color(0.07, 0.05, 0.04, 0.9), UITheme.GOLD_DARK if not s.get("boss", false) else Color(0.6, 0.15, 0.1), 8)
	var h := UITheme.hbox(10)
	p.add_child(h)
	h.add_child(Icon.make("skull" if s.get("boss", false) else "flag", Color(1, 0.3, 0.2) if s.get("boss", false) else UITheme.GOLD, 40))
	var v := UITheme.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UITheme.label("%s %s%s" % [tr("ui.stage"), DB.stage_label(s.id), ("  — " + tr("ui.boss_stage")) if s.get("boss", false) else ""], 18, UITheme.TEXT, true))
	v.add_child(StarRow.make(Game.stage_stars(s.id), 3, 20))
	if unlocked:
		var sid: String = s.id
		h.add_child(UITheme.primary_button("%s  ⚡%d" % [tr("ui.play"), int(DB.cfg.stage_energy_cost)], func(): _open_stage(sid), 18, 130, 50))
	else:
		h.add_child(UITheme.label(tr("ui.locked"), 18, UITheme.TEXT_DIM, true))
	return p


func _open_stage(stage_id: String) -> void:
	if not Game.is_stage_unlocked(stage_id):
		Events.notify(tr("ui.locked"))
		return
	var info := DB.stage_info(stage_id)
	map3d.focus_region(info.region_idx)
	var v := _side_panel()
	var head := UITheme.hbox(8)
	v.add_child(head)
	var t := UITheme.title("%s %s" % [tr("ui.stage"), DB.stage_label(stage_id)], 32)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UITheme.button("✕", _close_panel, 18, 44, 44))
	v.add_child(UITheme.label(tr("region." + str(info.region.id)), 20, UITheme.TEXT_DIM, true, HORIZONTAL_ALIGNMENT_CENTER))
	var sr := StarRow.make(Game.stage_stars(stage_id), 3, 40)
	sr.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(sr)
	v.add_child(UITheme.separator())
	# Enemies preview
	v.add_child(UITheme.label(tr("ui.enemies"), 18, UITheme.GOLD, true))
	var eh := HFlowContainer.new()
	v.add_child(eh)
	var seen := {}
	var waves: Array = DB.explicit_waves[stage_id].waves if DB.explicit_waves.has(stage_id) else _preview_waves(stage_id)
	for w in waves:
		for g in w.groups:
			if not seen.has(g.enemy):
				seen[g.enemy] = true
				var boss := DB.is_boss(g.enemy)
				var chip := UITheme.label(tr(("boss." if boss else "enemy.") + str(g.enemy)), 15, Color(1, 0.45, 0.35) if boss else UITheme.TEXT)
				var pc := UITheme.panel(Color(0.1, 0.06, 0.05), UITheme.GOLD_DARK, 4)
				pc.add_child(chip)
				eh.add_child(pc)
	v.add_child(UITheme.label("%s: %d" % [tr("ui.waves"), waves.size()], 16, UITheme.TEXT_DIM))
	v.add_child(UITheme.label(tr("ui.towers"), 18, UITheme.GOLD, true))
	var th := HFlowContainer.new()
	v.add_child(th)
	for tid in info.data.get("towers", []):
		var ic := Icon.make(BattleHUD.TOWER_GLYPH.get(tid, "tower"), ModelLib._col(DB.towers[tid].model.accent), 44)
		ic.tooltip_text = tr("tower." + tid)
		ic.mouse_filter = Control.MOUSE_FILTER_PASS
		th.add_child(ic)
	v.add_child(UITheme.separator())
	# Selected hero
	var hid: String = Game.profile.selected_hero
	var hh := UITheme.hbox(10)
	v.add_child(hh)
	hh.add_child(Icon.make("hero", VFX.color(DB.heroes[hid].element), 52))
	var hv := UITheme.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(hv)
	hv.add_child(UITheme.label(tr("hero." + hid), 20, UITheme.GOLD, true))
	hv.add_child(UITheme.label("%s %d   %s %s" % [tr("ui.lv"), int(Game.hero_state(hid).level), tr("ui.power"), Loc.num(Game.hero_power(hid))], 16, UITheme.TEXT_DIM))
	hh.add_child(UITheme.button(tr("nav.heroes"), func(): Router.goto("heroes"), 16, 120, 44))
	v.add_child(UITheme.spacer(false))
	var play := UITheme.primary_button("%s   ⚡ %d" % [tr("battle.start"), int(DB.cfg.stage_energy_cost)], func(): Router.start_battle(stage_id), 26, 380, 70)
	v.add_child(play)


func _preview_waves(stage_id: String) -> Array:
	var wm := WaveManager.new()
	var info := DB.stage_info(stage_id)
	var out := wm._generate(info, DB.stage_order.find(stage_id))
	wm.free()
	return out


func _daily_popup() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var p := UITheme.panel(Color(0.04, 0.03, 0.02, 0.98), UITheme.GOLD, 24)
	cc.add_child(p)
	var v := UITheme.vbox(14)
	p.add_child(v)
	v.add_child(UITheme.title(tr("ui.daily_rewards"), 40))
	var h := UITheme.hbox(10)
	v.add_child(h)
	var today := Game.daily_day_index()
	for i in DB.meta.daily_rewards.size():
		h.add_child(DailyRewardTile.make(i, today))
	v.add_child(UITheme.primary_button(tr("ui.claim"), func():
		Game.claim_daily()
		Sfx.play("levelup", 0.0)
		dim.queue_free(), 26, 300, 64))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if panel:
			_close_panel()
		else:
			Router.goto("main_menu")
