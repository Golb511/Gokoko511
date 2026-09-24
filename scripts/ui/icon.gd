@tool
class_name Icon
extends Control
## Vector-drawn icon: gold-rimmed medallion with an element-tinted glyph.
## Keeps the UI crisp at any resolution without bitmap icon assets.

@export var glyph := "sword":
	set(v):
		glyph = v
		queue_redraw()
@export var tint := Color(1, 0.6, 0.2):
	set(v):
		tint = v
		queue_redraw()
@export var medallion := true:
	set(v):
		medallion = v
		queue_redraw()
@export var dim := 0.0:
	set(v):
		dim = v
		queue_redraw()
@export var cooldown := 0.0:
	set(v):
		cooldown = v
		queue_redraw()


static func make(g: String, c: Color, sz: float = 48.0, with_medallion := true) -> Icon:
	var i := Icon.new()
	i.glyph = g
	i.tint = c
	i.medallion = with_medallion
	i.custom_minimum_size = Vector2(sz, sz)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var r := s * 0.5
	if medallion:
		draw_circle(c, r, Color(0.02, 0.015, 0.015))
		var steps := 10
		for i in steps:
			var t := float(i) / steps
			draw_circle(c + Vector2(0, -r * 0.1 * t), r * (0.9 - t * 0.55), tint.darkened(0.82 - t * 0.5) * Color(1, 1, 1, 0.9))
		draw_arc(c, r * 0.94, 0, TAU, 48, UITheme.GOLD_DIM, maxf(1.5, s * 0.05), true)
		draw_arc(c, r * 0.84, 0, TAU, 48, Color(0, 0, 0, 0.6), maxf(1.0, s * 0.02), true)
	var gc := tint.lightened(0.35)
	draw_glyph(self, glyph, c, r * (0.62 if medallion else 0.95), gc)
	if dim > 0.0:
		draw_circle(c, r * 0.95, Color(0, 0, 0, dim))
	if cooldown > 0.0:
		var pts := PackedVector2Array([c])
		var seg := 32
		for i in seg + 1:
			var a := -PI / 2 + TAU * cooldown * float(i) / seg
			pts.append(c + Vector2(cos(a), sin(a)) * r * 0.92)
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0, 0, 0, 0.62))


static func _poly(ci: CanvasItem, pts: Array, c: Vector2, r: float, col: Color) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append(c + Vector2(v.x, v.y) * r)
	ci.draw_colored_polygon(p, col)


static func _line(ci: CanvasItem, pts: Array, c: Vector2, r: float, col: Color, w: float) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append(c + Vector2(v.x, v.y) * r)
	ci.draw_polyline(p, col, maxf(1.0, w * r), true)


static func star_points(n := 5, inner := 0.45) -> Array:
	var out := []
	for i in n * 2:
		var a := -PI / 2 + PI * i / n
		var rr := 1.0 if i % 2 == 0 else inner
		out.append(Vector2(cos(a), sin(a)) * rr)
	return out


## Draws a named glyph centered at c with radius r.
static func draw_glyph(ci: CanvasItem, g: String, c: Vector2, r: float, col: Color) -> void:
	var dark := Color(0, 0, 0, 0.55)
	match g:
		"sword":
			_poly(ci, [Vector2(-0.08, 0.35), Vector2(-0.08, -0.85), Vector2(0, -1.0), Vector2(0.08, -0.85), Vector2(0.08, 0.35)], c, r, col)
			_poly(ci, [Vector2(-0.4, 0.35), Vector2(0.4, 0.35), Vector2(0.4, 0.47), Vector2(-0.4, 0.47)], c, r, col.darkened(0.2))
			_poly(ci, [Vector2(-0.06, 0.47), Vector2(0.06, 0.47), Vector2(0.06, 0.85), Vector2(-0.06, 0.85)], c, r, col.darkened(0.4))
			ci.draw_circle(c + Vector2(0, 0.92) * r, 0.1 * r, col)
		"axe":
			_poly(ci, [Vector2(-0.05, -0.9), Vector2(0.05, -0.9), Vector2(0.05, 0.95), Vector2(-0.05, 0.95)], c, r, col.darkened(0.4))
			_poly(ci, [Vector2(0.05, -0.75), Vector2(0.75, -0.95), Vector2(0.6, -0.35), Vector2(0.75, 0.2), Vector2(0.05, -0.05)], c, r, col)
			_poly(ci, [Vector2(-0.05, -0.65), Vector2(-0.45, -0.75), Vector2(-0.45, -0.1), Vector2(-0.05, -0.2)], c, r, col.darkened(0.15))
		"staff":
			_line(ci, [Vector2(-0.3, 0.95), Vector2(0.25, -0.55)], c, r, col.darkened(0.3), 0.12)
			ci.draw_circle(c + Vector2(0.32, -0.72) * r, 0.24 * r, col)
			ci.draw_arc(c + Vector2(0.32, -0.72) * r, 0.36 * r, 0, TAU, 20, col.darkened(0.2), 0.06 * r)
		"crossbow", "arrow":
			_line(ci, [Vector2(-0.8, 0.8), Vector2(0.7, -0.7)], c, r, col, 0.1)
			_poly(ci, [Vector2(0.85, -0.85), Vector2(0.45, -0.72), Vector2(0.72, -0.45)], c, r, col)
			_line(ci, [Vector2(-0.8, 0.8), Vector2(-0.55, 0.85)], c, r, col.darkened(0.3), 0.08)
			_line(ci, [Vector2(-0.8, 0.8), Vector2(-0.85, 0.55)], c, r, col.darkened(0.3), 0.08)
			if g == "crossbow":
				ci.draw_arc(c + Vector2(0.1, -0.1) * r, 0.75 * r, -PI * 0.95, -PI * 0.05, 20, col.darkened(0.2), 0.1 * r)
		"arrows":
			for o in [-0.35, 0.0, 0.35]:
				_line(ci, [Vector2(o - 0.4, 0.8), Vector2(o + 0.3, -0.7)], c, r, col, 0.08)
				_poly(ci, [Vector2(o + 0.38, -0.88), Vector2(o + 0.12, -0.72), Vector2(o + 0.36, -0.58)], c, r, col)
		"shield", "armor", "robe":
			var sh := [Vector2(0, -0.95), Vector2(0.75, -0.65), Vector2(0.65, 0.2), Vector2(0, 0.95), Vector2(-0.65, 0.2), Vector2(-0.75, -0.65)]
			if g == "armor":
				sh = [Vector2(-0.4, -0.9), Vector2(0.4, -0.9), Vector2(0.85, -0.6), Vector2(0.65, 0.0), Vector2(0.5, 0.9), Vector2(-0.5, 0.9), Vector2(-0.65, 0.0), Vector2(-0.85, -0.6)]
			elif g == "robe":
				sh = [Vector2(-0.3, -0.9), Vector2(0.3, -0.9), Vector2(0.5, -0.4), Vector2(0.8, 0.9), Vector2(-0.8, 0.9), Vector2(-0.5, -0.4)]
			_poly(ci, sh, c, r, col)
			_line(ci, [Vector2(0, -0.7), Vector2(0, 0.7)], c, r, dark, 0.08)
			_line(ci, [Vector2(-0.45, -0.3), Vector2(0.45, -0.3)], c, r, dark, 0.08)
		"gloves":
			_poly(ci, [Vector2(-0.5, 0.9), Vector2(-0.55, -0.1), Vector2(-0.35, -0.75), Vector2(-0.15, -0.3), Vector2(-0.05, -0.9), Vector2(0.12, -0.3), Vector2(0.25, -0.85), Vector2(0.4, -0.2), Vector2(0.72, -0.35), Vector2(0.55, 0.2), Vector2(0.45, 0.9)], c, r, col)
			_line(ci, [Vector2(-0.5, 0.55), Vector2(0.45, 0.55)], c, r, dark, 0.08)
		"boots":
			_poly(ci, [Vector2(-0.4, -0.9), Vector2(0.2, -0.9), Vector2(0.2, 0.35), Vector2(0.85, 0.5), Vector2(0.85, 0.9), Vector2(-0.4, 0.9)], c, r, col)
			_line(ci, [Vector2(-0.4, -0.45), Vector2(0.2, -0.45)], c, r, dark, 0.08)
		"ring":
			ci.draw_arc(c + Vector2(0, 0.2) * r, 0.6 * r, 0, TAU, 32, col, 0.18 * r, true)
			_poly(ci, [Vector2(0, -0.95), Vector2(0.3, -0.6), Vector2(0, -0.3), Vector2(-0.3, -0.6)], c, r, col.lightened(0.4))
		"necklace":
			ci.draw_arc(c + Vector2(0, -0.3) * r, 0.7 * r, 0.1, PI - 0.1, 24, col.darkened(0.2), 0.08 * r, true)
			_poly(ci, [Vector2(0, 0.25), Vector2(0.3, 0.6), Vector2(0, 0.98), Vector2(-0.3, 0.6)], c, r, col)
		"gem":
			_poly(ci, [Vector2(-0.7, -0.3), Vector2(-0.35, -0.75), Vector2(0.35, -0.75), Vector2(0.7, -0.3), Vector2(0, 0.9)], c, r, col)
			_line(ci, [Vector2(-0.7, -0.3), Vector2(0.7, -0.3)], c, r, Color(1, 1, 1, 0.5), 0.05)
			_line(ci, [Vector2(-0.3, -0.3), Vector2(0, 0.85), Vector2(0.3, -0.3)], c, r, Color(1, 1, 1, 0.3), 0.04)
		"rune":
			_poly(ci, [Vector2(-0.6, -0.9), Vector2(0.6, -0.9), Vector2(0.75, 0.9), Vector2(-0.75, 0.9)], c, r, col.darkened(0.45))
			_line(ci, [Vector2(0, -0.6), Vector2(0, 0.6)], c, r, col.lightened(0.3), 0.12)
			_line(ci, [Vector2(0, -0.2), Vector2(0.35, -0.55)], c, r, col.lightened(0.3), 0.12)
			_line(ci, [Vector2(0, 0.1), Vector2(-0.35, -0.25)], c, r, col.lightened(0.3), 0.12)
		"fire", "meteor", "blast":
			_poly(ci, [Vector2(0, -1.0), Vector2(0.35, -0.45), Vector2(0.6, -0.65), Vector2(0.7, 0.2), Vector2(0.4, 0.85), Vector2(-0.4, 0.85), Vector2(-0.7, 0.2), Vector2(-0.45, -0.35), Vector2(-0.2, -0.2)], c, r, col)
			_poly(ci, [Vector2(0, -0.35), Vector2(0.3, 0.2), Vector2(0.2, 0.75), Vector2(-0.2, 0.75), Vector2(-0.3, 0.2)], c, r, Color(1, 0.95, 0.7))
			if g == "meteor":
				_line(ci, [Vector2(-0.95, -0.95), Vector2(-0.4, -0.4)], c, r, col, 0.1)
		"ice", "snow":
			for k in 3:
				var a := PI / 3 * k
				var d := Vector2(cos(a), sin(a))
				_line(ci, [-d * 0.9, d * 0.9], c, r, col, 0.1)
				for sgn in [-1.0, 1.0]:
					var p0: Vector2 = d * 0.55 * sgn
					_line(ci, [p0, p0 + (d * sgn).rotated(0.7) * 0.3], c, r, col, 0.07)
					_line(ci, [p0, p0 + (d * sgn).rotated(-0.7) * 0.3], c, r, col, 0.07)
		"poison", "cloud":
			_poly(ci, [Vector2(0, -0.95), Vector2(0.55, -0.05), Vector2(0.5, 0.5), Vector2(0, 0.85), Vector2(-0.5, 0.5), Vector2(-0.55, -0.05)], c, r, col)
			ci.draw_circle(c + Vector2(-0.18, 0.25) * r, 0.14 * r, Color(1, 1, 1, 0.4))
		"skull":
			ci.draw_circle(c + Vector2(0, -0.2) * r, 0.62 * r, col)
			_poly(ci, [Vector2(-0.35, 0.2), Vector2(0.35, 0.2), Vector2(0.3, 0.8), Vector2(-0.3, 0.8)], c, r, col)
			ci.draw_circle(c + Vector2(-0.24, -0.15) * r, 0.17 * r, Color(0, 0, 0, 0.85))
			ci.draw_circle(c + Vector2(0.24, -0.15) * r, 0.17 * r, Color(0, 0, 0, 0.85))
			_poly(ci, [Vector2(0, 0.08), Vector2(0.08, 0.25), Vector2(-0.08, 0.25)], c, r, Color(0, 0, 0, 0.85))
		"bolt", "storm", "lightning":
			_poly(ci, [Vector2(0.2, -1.0), Vector2(-0.45, 0.1), Vector2(-0.02, 0.1), Vector2(-0.25, 1.0), Vector2(0.5, -0.2), Vector2(0.05, -0.2), Vector2(0.35, -1.0)], c, r, col)
		"shadow", "eclipse", "blades":
			ci.draw_circle(c, 0.75 * r, col)
			ci.draw_circle(c + Vector2(0.3, -0.2) * r, 0.62 * r, Color(0.04, 0.02, 0.06))
			if g == "blades":
				_line(ci, [Vector2(-0.9, 0.9), Vector2(0.9, -0.9)], c, r, col.lightened(0.4), 0.08)
		"dash":
			for k in 3:
				var o := -0.45 + k * 0.45
				_line(ci, [Vector2(-0.9, o), Vector2(0.2 - k * 0.2, o)], c, r, col.darkened(0.3 * (2 - k) / 2.0), 0.1)
			_poly(ci, [Vector2(0.2, -0.6), Vector2(0.95, 0), Vector2(0.2, 0.6)], c, r, col)
		"summon", "taunt":
			for k in 3:
				var x := -0.55 + k * 0.55
				ci.draw_circle(c + Vector2(x, -0.35) * r, 0.2 * r, col)
				_poly(ci, [Vector2(x - 0.25, 0.8), Vector2(x - 0.2, 0.0), Vector2(x + 0.2, 0.0), Vector2(x + 0.25, 0.8)], c, r, col.darkened(0.15))
		"nova", "quake", "surge":
			ci.draw_arc(c, 0.8 * r, 0, TAU, 32, col, 0.1 * r, true)
			ci.draw_arc(c, 0.5 * r, 0, TAU, 32, col.darkened(0.2), 0.1 * r, true)
			ci.draw_circle(c, 0.22 * r, col.lightened(0.4))
		"rock":
			_poly(ci, [Vector2(-0.8, 0.6), Vector2(-0.6, -0.3), Vector2(-0.1, -0.8), Vector2(0.6, -0.5), Vector2(0.85, 0.3), Vector2(0.3, 0.8)], c, r, col)
		"dragon":
			_poly(ci, [Vector2(-0.95, -0.2), Vector2(-0.3, -0.35), Vector2(0, -0.95), Vector2(0.15, -0.3), Vector2(0.95, -0.2), Vector2(0.35, 0.1), Vector2(0.2, 0.85), Vector2(0, 0.35), Vector2(-0.2, 0.85), Vector2(-0.35, 0.1)], c, r, col)
		"raven":
			_poly(ci, [Vector2(-0.95, -0.4), Vector2(-0.1, 0.0), Vector2(0.0, -0.3), Vector2(0.1, 0.0), Vector2(0.95, -0.4), Vector2(0.2, 0.3), Vector2(0.0, 0.8), Vector2(-0.2, 0.3)], c, r, col)
		"blood", "heal":
			_poly(ci, [Vector2(0, -0.95), Vector2(0.55, 0.15), Vector2(0.45, 0.6), Vector2(0, 0.9), Vector2(-0.45, 0.6), Vector2(-0.55, 0.15)], c, r, col)
			if g == "heal":
				_line(ci, [Vector2(0, 0.0), Vector2(0, 0.6)], c, r, Color.WHITE, 0.1)
				_line(ci, [Vector2(-0.3, 0.3), Vector2(0.3, 0.3)], c, r, Color.WHITE, 0.1)
		"mark":
			ci.draw_arc(c, 0.7 * r, 0, TAU, 32, col, 0.1 * r, true)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				_line(ci, [d * 0.35, d * 0.95], c, r, col, 0.1)
		"tower":
			_poly(ci, [Vector2(-0.45, 0.9), Vector2(-0.35, -0.4), Vector2(0.35, -0.4), Vector2(0.45, 0.9)], c, r, col)
			for k in 3:
				var x := -0.45 + k * 0.35
				_poly(ci, [Vector2(x, -0.4), Vector2(x, -0.75), Vector2(x + 0.2, -0.75), Vector2(x + 0.2, -0.4)], c, r, col)
			_poly(ci, [Vector2(-0.12, 0.9), Vector2(-0.12, 0.45), Vector2(0.12, 0.45), Vector2(0.12, 0.9)], c, r, dark)
		"gold", "coin":
			ci.draw_circle(c, 0.8 * r, Color(0.95, 0.72, 0.2))
			ci.draw_circle(c, 0.6 * r, Color(0.75, 0.52, 0.12))
			_poly(ci, star_points(5, 0.45).map(func(v): return v * 0.4), c, r, Color(1, 0.88, 0.45))
		"diamond":
			_poly(ci, [Vector2(0, -0.9), Vector2(0.7, -0.2), Vector2(0, 0.9), Vector2(-0.7, -0.2)], c, r, Color(0.35, 0.65, 1.0))
			_poly(ci, [Vector2(0, -0.9), Vector2(0.3, -0.2), Vector2(0, 0.6), Vector2(-0.3, -0.2)], c, r, Color(0.7, 0.9, 1.0))
		"energy":
			_poly(ci, [Vector2(0.2, -1.0), Vector2(-0.45, 0.1), Vector2(-0.02, 0.1), Vector2(-0.25, 1.0), Vector2(0.5, -0.2), Vector2(0.05, -0.2), Vector2(0.35, -1.0)], c, r, Color(1.0, 0.8, 0.2))
		"star":
			_poly(ci, star_points(), c, r, col)
		"star_empty":
			_poly(ci, star_points(), c, r, Color(0.15, 0.12, 0.1))
			_line(ci, star_points() + [star_points()[0]], c, r, Color(0.45, 0.38, 0.28), 0.08)
		"chest":
			_poly(ci, [Vector2(-0.85, -0.1), Vector2(0.85, -0.1), Vector2(0.85, 0.8), Vector2(-0.85, 0.8)], c, r, col.darkened(0.2))
			_poly(ci, [Vector2(-0.85, -0.1), Vector2(-0.7, -0.7), Vector2(0.7, -0.7), Vector2(0.85, -0.1)], c, r, col)
			_poly(ci, [Vector2(-0.15, -0.2), Vector2(0.15, -0.2), Vector2(0.15, 0.25), Vector2(-0.15, 0.25)], c, r, Color(1, 0.85, 0.4))
		"material":
			_poly(ci, [Vector2(-0.7, 0.4), Vector2(-0.3, -0.6), Vector2(0.4, -0.7), Vector2(0.8, 0.1), Vector2(0.3, 0.8)], c, r, col)
			_line(ci, [Vector2(-0.3, -0.6), Vector2(0.0, 0.2), Vector2(0.8, 0.1)], c, r, Color(1, 1, 1, 0.3), 0.05)
		"pause":
			_poly(ci, [Vector2(-0.5, -0.7), Vector2(-0.15, -0.7), Vector2(-0.15, 0.7), Vector2(-0.5, 0.7)], c, r, col)
			_poly(ci, [Vector2(0.15, -0.7), Vector2(0.5, -0.7), Vector2(0.5, 0.7), Vector2(0.15, 0.7)], c, r, col)
		"play":
			_poly(ci, [Vector2(-0.45, -0.75), Vector2(0.75, 0), Vector2(-0.45, 0.75)], c, r, col)
		"speed":
			_poly(ci, [Vector2(-0.8, -0.6), Vector2(0.0, 0), Vector2(-0.8, 0.6)], c, r, col)
			_poly(ci, [Vector2(0.0, -0.6), Vector2(0.8, 0), Vector2(0.0, 0.6)], c, r, col)
		"gear":
			ci.draw_arc(c, 0.55 * r, 0, TAU, 24, col, 0.25 * r, true)
			for k in 8:
				var a := TAU * k / 8.0
				_line(ci, [Vector2(cos(a), sin(a)) * 0.6, Vector2(cos(a), sin(a)) * 0.95], c, r, col, 0.2)
		"mail":
			_poly(ci, [Vector2(-0.85, -0.55), Vector2(0.85, -0.55), Vector2(0.85, 0.6), Vector2(-0.85, 0.6)], c, r, col)
			_line(ci, [Vector2(-0.85, -0.55), Vector2(0, 0.1), Vector2(0.85, -0.55)], c, r, dark, 0.08)
		"heart":
			ci.draw_circle(c + Vector2(-0.3, -0.25) * r, 0.36 * r, Color(0.9, 0.15, 0.15))
			ci.draw_circle(c + Vector2(0.3, -0.25) * r, 0.36 * r, Color(0.9, 0.15, 0.15))
			_poly(ci, [Vector2(-0.64, -0.12), Vector2(0.64, -0.12), Vector2(0, 0.85)], c, r, Color(0.9, 0.15, 0.15))
		"portal":
			ci.draw_arc(c, 0.8 * r, 0, TAU, 40, col, 0.14 * r, true)
			ci.draw_circle(c, 0.6 * r, col.darkened(0.5))
			ci.draw_arc(c, 0.4 * r, 0, TAU * 0.75, 30, col.lightened(0.3), 0.08 * r, true)
		"crossed":
			_line(ci, [Vector2(-0.8, 0.8), Vector2(0.8, -0.8)], c, r, col, 0.13)
			_line(ci, [Vector2(0.8, 0.8), Vector2(-0.8, -0.8)], c, r, col, 0.13)
			_line(ci, [Vector2(-0.8, 0.35), Vector2(-0.35, 0.8)], c, r, col.darkened(0.3), 0.1)
			_line(ci, [Vector2(0.8, 0.35), Vector2(0.35, 0.8)], c, r, col.darkened(0.3), 0.1)
		"banner", "guild":
			_poly(ci, [Vector2(-0.55, -0.9), Vector2(0.55, -0.9), Vector2(0.55, 0.9), Vector2(0, 0.5), Vector2(-0.55, 0.9)], c, r, col)
			_poly(ci, star_points().map(func(v): return v * 0.28 + Vector2(0, -0.25)), c, r, Color(0.1, 0.05, 0.02))
		"trophy":
			_poly(ci, [Vector2(-0.6, -0.85), Vector2(0.6, -0.85), Vector2(0.45, -0.1), Vector2(0.12, 0.2), Vector2(0.12, 0.55), Vector2(0.4, 0.85), Vector2(-0.4, 0.85), Vector2(-0.12, 0.55), Vector2(-0.12, 0.2), Vector2(-0.45, -0.1)], c, r, col)
			ci.draw_arc(c + Vector2(-0.62, -0.5) * r, 0.25 * r, PI * 0.5, PI * 1.5, 12, col, 0.08 * r)
			ci.draw_arc(c + Vector2(0.62, -0.5) * r, 0.25 * r, -PI * 0.5, PI * 0.5, 12, col, 0.08 * r)
		"scroll", "missions":
			_poly(ci, [Vector2(-0.6, -0.8), Vector2(0.6, -0.8), Vector2(0.6, 0.8), Vector2(-0.6, 0.8)], c, r, col)
			for k in 4:
				_line(ci, [Vector2(-0.4, -0.5 + k * 0.3), Vector2(0.4, -0.5 + k * 0.3)], c, r, dark, 0.07)
		"shop":
			_poly(ci, [Vector2(-0.8, -0.3), Vector2(0.8, -0.3), Vector2(0.65, 0.85), Vector2(-0.65, 0.85)], c, r, col)
			ci.draw_arc(c + Vector2(0, -0.35) * r, 0.4 * r, PI, TAU, 16, col, 0.1 * r)
		"hero":
			_poly(ci, [Vector2(-0.55, -0.1), Vector2(-0.45, -0.75), Vector2(0, -0.95), Vector2(0.45, -0.75), Vector2(0.55, -0.1), Vector2(0.25, 0.1), Vector2(-0.25, 0.1)], c, r, col)
			_poly(ci, [Vector2(-0.8, 0.9), Vector2(-0.6, 0.25), Vector2(0.6, 0.25), Vector2(0.8, 0.9)], c, r, col.darkened(0.2))
			_line(ci, [Vector2(-0.3, -0.45), Vector2(0.3, -0.45)], c, r, dark, 0.1)
		"more":
			for x in [-0.55, 0.0, 0.55]:
				ci.draw_circle(c + Vector2(x, 0) * r, 0.16 * r, col)
		"plus":
			_line(ci, [Vector2(0, -0.7), Vector2(0, 0.7)], c, r, col, 0.18)
			_line(ci, [Vector2(-0.7, 0), Vector2(0.7, 0)], c, r, col, 0.18)
		"upgrade":
			_poly(ci, [Vector2(0, -0.9), Vector2(0.7, -0.1), Vector2(0.25, -0.1), Vector2(0.25, 0.85), Vector2(-0.25, 0.85), Vector2(-0.25, -0.1), Vector2(-0.7, -0.1)], c, r, col)
		"sell":
			ci.draw_circle(c, 0.8 * r, Color(0.95, 0.72, 0.2))
			_line(ci, [Vector2(-0.35, -0.2), Vector2(0.35, -0.2)], c, r, Color(0.3, 0.2, 0.05), 0.12)
			_line(ci, [Vector2(-0.35, 0.2), Vector2(0.35, 0.2)], c, r, Color(0.3, 0.2, 0.05), 0.12)
		"flag":
			_line(ci, [Vector2(-0.6, 0.95), Vector2(-0.6, -0.95)], c, r, col.darkened(0.3), 0.1)
			_poly(ci, [Vector2(-0.55, -0.9), Vector2(0.8, -0.6), Vector2(-0.55, -0.2)], c, r, col)
		_:
			ci.draw_circle(c, 0.4 * r, col)
