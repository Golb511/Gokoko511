class_name StarRow
extends HBoxContainer
## Row of earned / unearned stars.

static func make(earned: int, total := 3, size := 24.0) -> StarRow:
	var s := StarRow.new()
	s.add_theme_constant_override("separation", 2)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in total:
		s.add_child(Icon.make("star" if i < earned else "star_empty", Color(1.0, 0.82, 0.25), size, false))
	return s
