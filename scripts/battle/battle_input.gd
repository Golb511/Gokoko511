class_name BattleInput
extends Node
## Unified mouse / keyboard / touch input for the battlefield.
## Tap: select hero, open build/tower menus, move hero, confirm targeting.
## Drag: pan camera. Wheel / pinch: zoom. Right click: move hero (PC).

var battle: BattleController
var hero_selected := false
var pending: Dictionary = {}        # targeting mode {"kind": "ability"/"global", "index"/"id"}
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragging := false
var _touches: Dictionary = {}
var _pinch_dist := 0.0
var _indicator: MeshInstance3D
const DRAG_THRESHOLD := 12.0


func setup(b: BattleController) -> void:
	battle = b
	_indicator = VFX.area_disc(battle.fx_root, Vector3.ZERO, 1.0, Color(1, 0.8, 0.3))
	_indicator.visible = false


func set_pending(p: Dictionary) -> void:
	pending = p
	_indicator.visible = not p.is_empty()
	if not p.is_empty():
		var r := 2.0
		if p.kind == "ability":
			r = float(battle.hero.ability_def(p.index).get("radius", 2.0))
		elif p.kind == "global":
			r = float(DB.cfg.global_abilities[p.id].get("radius", 2.0))
		_indicator.scale = Vector3(maxf(1.0, r), 1, maxf(1.0, r))
		battle.hud.show_hint(tr("battle.select_target"))
	else:
		battle.hud.show_hint("")


func select_hero(v: bool) -> void:
	hero_selected = v and battle.hero.alive
	battle.hero.set_selected(hero_selected)
	battle.hud.set_hero_selected(hero_selected)


func _process(_delta: float) -> void:
	if _indicator.visible:
		var p := battle.camera_rig.screen_to_ground(battle.get_viewport().get_mouse_position())
		if p != Vector3.INF:
			_indicator.global_position = p + Vector3(0, 0.08, 0)


func _unhandled_input(event: InputEvent) -> void:
	if battle.ended:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() < 2:
			_pinch_dist = 0.0
		return
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var pts := _touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			if _pinch_dist > 0.0:
				battle.camera_rig.zoom(_pinch_dist / maxf(1.0, d))
			_pinch_dist = d
			_dragging = true
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed: battle.camera_rig.zoom(0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed: battle.camera_rig.zoom(1.1)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_pressing = true
					_dragging = false
					_press_pos = event.position
				else:
					if _pressing and not _dragging and _touches.size() < 2:
						_tap(event.position)
					_pressing = false
					_dragging = false
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					if not pending.is_empty():
						set_pending({})
					else:
						var p := battle.camera_rig.screen_to_ground(event.position)
						if p != Vector3.INF:
							battle.hero.command_move(p)
	elif event is InputEventMouseMotion:
		if _pressing and _touches.size() < 2:
			if not _dragging and event.position.distance_to(_press_pos) > DRAG_THRESHOLD:
				_dragging = true
				battle.hud.close_popups()
			if _dragging:
				battle.camera_rig.pan_screen(event.relative)
		elif (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
			battle.camera_rig.pan_screen(event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event.keycode)


func _key(k: int) -> void:
	match k:
		KEY_1, KEY_2, KEY_3, KEY_4:
			battle.hud.request_ability(k - KEY_1)
		KEY_R:
			battle.hud.request_ability(4)
		KEY_Z:
			battle.hud.request_global("meteor")
		KEY_X:
			battle.hud.request_global("freeze")
		KEY_C:
			battle.hud.request_global("tower_buff")
		KEY_V:
			battle.hud.request_global("summon_dragon")
		KEY_SPACE:
			battle.hud.call_next_wave()
		KEY_ESCAPE:
			if not pending.is_empty():
				set_pending({})
			elif battle.hud.has_popup():
				battle.hud.close_popups()
			else:
				battle.hud.toggle_pause()
		KEY_P:
			battle.hud.toggle_pause()
		KEY_F:
			battle.hud.toggle_speed()
		KEY_H:
			select_hero(true)
			battle.camera_rig.focus_on(battle.hero.global_position)


func _tap(screen: Vector2) -> void:
	var p := battle.camera_rig.screen_to_ground(screen)
	if p == Vector3.INF:
		return
	if not pending.is_empty():
		_confirm_target(p)
		return
	battle.hud.close_popups()
	# Hero picking by screen distance (friendlier on touch screens).
	var cam := battle.camera_rig.camera
	if battle.hero.alive:
		var hs := cam.unproject_position(battle.hero.global_position + Vector3(0, 1.0, 0))
		if hs.distance_to(screen) < 55.0:
			select_hero(not hero_selected)
			return
	# Towers and build slots.
	for s in battle.slots:
		if Vector2(s.global_position.x - p.x, s.global_position.z - p.z).length() < 2.0:
			select_hero(false)
			if s.is_free():
				battle.hud.open_build_menu(s)
			else:
				battle.hud.open_tower_menu(s.tower)
			return
	if battle.hud.rally_tower != null:
		battle.hud.finish_rally(p)
		return
	if hero_selected:
		battle.hero.command_move(p)
		select_hero(false)


func _confirm_target(p: Vector3) -> void:
	var pd := pending
	set_pending({})
	if pd.kind == "ability":
		var target: Enemy = null
		var best := 3.0
		for e in battle.enemies_near(p, 3.0):
			var d: float = e.global_position.distance_to(p)
			if d < best:
				best = d
				target = e
		battle.hero.cast(pd.index, p, target)
	elif pd.kind == "global":
		battle.globals.use(pd.id, p)
