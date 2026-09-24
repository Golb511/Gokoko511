class_name FloatingText
extends Label3D
## Rising, fading combat text (damage numbers, gold, status).

var velocity := Vector3(0, 2.2, 0)
var life := 0.9
var _t := 0.0

static var _font: Font


static func spawn(parent: Node, pos: Vector3, text: String, col: Color, size: int = 48) -> void:
	var ft := FloatingText.new()
	ft.text = text
	ft.modulate = col
	ft.outline_modulate = Color(0, 0, 0, 0.85)
	ft.outline_size = 10
	ft.font_size = size
	ft.pixel_size = 0.01
	ft.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ft.no_depth_test = true
	ft.fixed_size = false
	if _font == null:
		_font = UITheme.font_bold()
	ft.font = _font
	parent.add_child(ft)
	ft.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.2, 0.2))


func _process(delta: float) -> void:
	_t += delta
	position += velocity * delta
	velocity.y = maxf(0.4, velocity.y - delta * 3.0)
	modulate.a = clampf(1.0 - (_t - life * 0.5) / (life * 0.5), 0.0, 1.0)
	if _t >= life:
		queue_free()
