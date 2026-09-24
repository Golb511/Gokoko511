class_name HeroPreview
extends SubViewportContainer
## Live 3D preview of a hero (turntable) embedded in UI screens.

var viewport: SubViewport
var stage: HeroStage
var _drag := false


static func make(model_def: Dictionary, min_size := Vector2(360, 460)) -> HeroPreview:
	var p := HeroPreview.new()
	p.custom_minimum_size = min_size
	p.stretch = true
	p.viewport = SubViewport.new()
	p.viewport.own_world_3d = true
	p.viewport.msaa_3d = Viewport.MSAA_2X
	p.add_child(p.viewport)
	p.stage = HeroStage.new()
	p.viewport.add_child(p.stage)
	p.stage.setup(model_def)
	p.stage.turntable = true
	return p


func set_model(model_def: Dictionary) -> void:
	stage.set_model(model_def)


func play(logical: String) -> void:
	if stage.model:
		stage.model.play_action(logical, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
		if event.pressed and event.double_click:
			play("attack")
	elif event is InputEventMouseMotion and _drag and stage.model:
		stage.turntable = false
		stage.model.rotation.y += event.relative.x * 0.01
