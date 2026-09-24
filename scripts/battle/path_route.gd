class_name PathRoute
extends RefCounted
## A walkable route for enemies (baked Curve3D + helpers).

var curve := Curve3D.new()
var length := 0.0
var points: PackedVector3Array


func build(pts2d: Array, y: float = 0.0) -> void:
	curve.clear_points()
	curve.bake_interval = 0.25
	var pts: Array[Vector3] = []
	for p in pts2d:
		pts.append(Vector3(float(p[0]), y, float(p[1])))
	for i in pts.size():
		var prev := pts[maxi(0, i - 1)]
		var next := pts[mini(pts.size() - 1, i + 1)]
		var tangent := (next - prev) * 0.22
		if i == 0 or i == pts.size() - 1:
			tangent = Vector3.ZERO
		curve.add_point(pts[i], -tangent, tangent)
	length = curve.get_baked_length()
	points = curve.get_baked_points()


func sample(offset: float) -> Vector3:
	return curve.sample_baked(clampf(offset, 0.0, length))


func direction(offset: float) -> Vector3:
	var a := sample(offset - 0.5)
	var b := sample(offset + 0.5)
	var d := b - a
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.0001 else Vector3.FORWARD


func closest_offset(p: Vector3) -> float:
	return curve.get_closest_offset(p)


func distance_to(p: Vector3) -> float:
	var c := curve.get_closest_point(p)
	return Vector2(c.x - p.x, c.z - p.z).length()
