shader_type spatial;
// Still, dark marsh water: animated ripples, fresnel sky sheen and a soft
// moon-coloured glint so pools read clearly even on night stages.
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 deep_color : source_color = vec3(0.04, 0.07, 0.1);
uniform vec3 sheen_color : source_color = vec3(0.45, 0.6, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 n1 = texture(normal_tex, p * 0.12 + vec2(TIME * 0.015, TIME * 0.01)).rgb;
	vec3 n2 = texture(normal_tex, p * 0.21 - vec2(TIME * 0.012, -TIME * 0.018)).rgb;
	NORMAL_MAP = normalize(n1 + n2 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.35;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float glint = smoothstep(0.72, 0.9, texture(noise_tex, p * 0.35 + vec2(TIME * 0.03)).r);
	ALBEDO = deep_color;
	METALLIC = 0.2;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	float ripple = texture(noise_tex, p * 0.6 + vec2(TIME * 0.02, -TIME * 0.015)).r;
	EMISSION = sheen_color * (fres * 0.6 + glint * 0.35 + 0.1 + ripple * 0.06);
}
