class_name CameraRig
extends Node3D
## Angled top-down camera: pan (drag/WASD/edge), zoom (wheel/pinch), shake.

var camera: Camera3D
var bounds := Rect2(-40, -32, 80, 62)
var distance := 40.0
var min_distance := 16.0
var max_distance := 58.0
var pitch := deg_to_rad(56.0)
var _target := Vector3.ZERO
var _shake_t := 0.0
var _shake_amp := 0.0
var follow: Node3D = null


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.far = 400.0
	camera.near = 0.3
	add_child(camera)
	camera.current = true
	_target = global_position
	_apply()


func setup(b: Rect2, focus: Vector3) -> void:
	bounds = b
	_target = focus
	global_position = focus
	_apply()


func pan_screen(delta_px: Vector2) -> void:
	var vp := get_viewport().get_visible_rect().size
	var scale := distance / maxf(1.0, vp.y) * 1.25 * float(Game.setting("camera_speed", 1.0))
	_target += Vector3(-delta_px.x, 0, -delta_px.y / sin(pitch)) * scale
	follow = null


func zoom(factor: float) -> void:
	distance = clampf(distance * factor, min_distance, max_distance)


func shake(amp: float, dur: float) -> void:
	_shake_amp = maxf(_shake_amp, amp)
	_shake_t = maxf(_shake_t, dur)


func focus_on(p: Vector3) -> void:
	_target = p


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move.x += 1
	if move != Vector2.ZERO:
		_target += Vector3(move.x, 0, move.y) * distance * 0.9 * delta * float(Game.setting("camera_speed", 1.0))
		follow = null
	if follow != null and is_instance_valid(follow):
		_target = _target.lerp(follow.global_position, clampf(delta * 3.0, 0, 1))
	_target.x = clampf(_target.x, bounds.position.x + 6, bounds.end.x - 6)
	_target.z = clampf(_target.z, bounds.position.y + 2, bounds.end.y - 2)
	global_position = global_position.lerp(_target, clampf(delta * 8.0, 0.0, 1.0))
	_apply()
	if _shake_t > 0.0:
		_shake_t -= delta
		var a := _shake_amp * clampf(_shake_t * 3.0, 0.0, 1.0)
		camera.h_offset = randf_range(-a, a)
		camera.v_offset = randf_range(-a, a)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _apply() -> void:
	if camera == null:
		return
	camera.position = Vector3(0, sin(pitch) * distance, cos(pitch) * distance)
	camera.look_at(global_position, Vector3.UP)


## Ground-plane point under a screen position.
func screen_to_ground(screen: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := -from.y / dir.y
	return from + dir * t
