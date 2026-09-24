class_name HealthBar3D
extends MeshInstance3D
## Camera-facing health bar drawn by a tiny shader (one quad per unit).

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled;
uniform float fill = 1.0;
uniform float fill2 = 0.0;
uniform vec4 fill_color : source_color = vec4(0.85, 0.15, 0.1, 1.0);
uniform vec4 fill2_color : source_color = vec4(0.3, 0.6, 1.0, 1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 uv = UV;
	float border = step(uv.x, 0.02) + step(0.98, uv.x) + step(uv.y, 0.1) + step(0.9, uv.y);
	vec3 col = vec3(0.05, 0.03, 0.03);
	float f = step(uv.x, fill);
	col = mix(col, fill_color.rgb * (0.75 + 0.5 * (1.0 - uv.y)), f);
	if (fill2 > 0.0) {
		float lower = step(0.62, uv.y);
		col = mix(col, fill2_color.rgb, lower * step(uv.x, fill2));
	}
	col = mix(col, vec3(0.75, 0.58, 0.3), clamp(border, 0.0, 1.0));
	ALBEDO = col;
}
"""

static var _shader: Shader
var _mat: ShaderMaterial
var _last := -1.0


static func make(width: float, color: Color, height_offset: float) -> HealthBar3D:
	var hb := HealthBar3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, width * 0.13)
	hb.mesh = q
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	hb._mat = ShaderMaterial.new()
	hb._mat.shader = _shader
	hb._mat.set_shader_parameter("fill_color", color)
	hb.material_override = hb._mat
	hb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hb.position = Vector3(0, height_offset, 0)
	hb.sorting_offset = 10.0
	return hb


func set_fill(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	if absf(v - _last) > 0.002:
		_last = v
		_mat.set_shader_parameter("fill", v)
	visible = v < 0.999 or get_meta("always", false)


func set_fill2(v: float) -> void:
	_mat.set_shader_parameter("fill2", clampf(v, 0.0, 1.0))
