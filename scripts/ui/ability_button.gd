class_name AbilityButton
extends Button
## Round ability button with vector icon, cooldown sweep, key hint and cost.

var icon_ctrl: Icon
var key_label: Label
var cost_label: Label
var _available := true


static func make(glyph: String, tint: Color, size: float, key_hint: String, cost: String = "") -> AbilityButton:
	var b := AbilityButton.new()
	b.custom_minimum_size = Vector2(size, size)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.icon_ctrl = Icon.make(glyph, tint, size)
	b.icon_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(b.icon_ctrl)
	b.key_label = UITheme.label(key_hint, int(size * 0.22), UITheme.GOLD, true)
	b.key_label.position = Vector2(size * 0.02, -size * 0.04)
	b.add_child(b.key_label)
	b.cost_label = UITheme.label(cost, int(size * 0.2), Color(0.6, 0.85, 1.0), true, HORIZONTAL_ALIGNMENT_RIGHT)
	b.cost_label.position = Vector2(size * 0.45, size * 0.72)
	b.cost_label.size = Vector2(size * 0.5, size * 0.25)
	b.add_child(b.cost_label)
	b.mouse_entered.connect(func(): b.icon_ctrl.scale = Vector2.ONE * 1.06)
	b.mouse_exited.connect(func(): b.icon_ctrl.scale = Vector2.ONE)
	return b


func set_state(cooldown_frac: float, available: bool) -> void:
	icon_ctrl.cooldown = cooldown_frac
	if available != _available:
		_available = available
		icon_ctrl.dim = 0.0 if available else 0.45
