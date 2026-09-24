extends Node
## Scene navigation with a cinematic fade.

const SCENES := {
	"main_menu": "res://scenes/main_menu.tscn",
	"world_map": "res://scenes/world_map.tscn",
	"battle": "res://scenes/battle.tscn",
	"heroes": "res://scenes/ui/heroes_screen.tscn",
	"inventory": "res://scenes/ui/inventory_screen.tscn",
	"shop": "res://scenes/ui/shop_screen.tscn",
	"missions": "res://scenes/ui/missions_screen.tscn",
	"achievements": "res://scenes/ui/achievements_screen.tscn",
	"guild": "res://scenes/ui/guild_screen.tscn",
	"settings": "res://scenes/ui/settings_screen.tscn",
}

var current: String = ""
var _fade: ColorRect
var _layer: CanvasLayer
var _busy := false
var _fps: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fade)
	_fps = Label.new()
	_fps.position = Vector2(8, 70)
	_fps.add_theme_font_size_override("font_size", 16)
	_fps.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fps)


func _process(_d: float) -> void:
	var show := bool(Game.setting("show_fps", false))
	_fps.visible = show
	if show:
		_fps.text = "FPS %d" % Engine.get_frames_per_second()


func goto(scene_key: String) -> void:
	if _busy or not SCENES.has(scene_key):
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.25)
	await tw.finished
	get_tree().paused = false
	Engine.time_scale = 1.0
	var err := get_tree().change_scene_to_file(SCENES[scene_key])
	if err != OK:
		push_error("Router: failed to load %s (%d)" % [scene_key, err])
	current = scene_key
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.35)
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func start_battle(stage_id: String) -> void:
	if not Game.spend_energy(int(DB.cfg.stage_energy_cost)):
		return
	Game.current_stage = stage_id
	goto("battle")
