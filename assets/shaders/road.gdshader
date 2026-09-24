shader_type spatial;
// Worn cobblestone road with soft edges that blend into the ground.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D cell_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 stone_color : source_color = vec3(0.24, 0.19, 0.15);
uniform vec3 edge_color : source_color = vec3(0.12, 0.1, 0.09);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float c = texture(cell_tex, p * 0.55).r;
	float n = texture(noise_tex, p * 0.3).r;
	float gap = smoothstep(0.08, 0.2, c);
	vec3 col = stone_color * (0.7 + 0.6 * n) * mix(0.35, 1.0, gap);
	float edge = abs(UV.x * 2.0 - 1.0);
	float edge_n = edge + (n - 0.5) * 0.5;
	col = mix(col, edge_color, smoothstep(0.55, 0.95, edge_n));
	ALBEDO = col;
	ALPHA = 1.0;
	NORMAL_MAP = texture(normal_tex, p * 0.55).rgb;
	NORMAL_MAP_DEPTH = 2.0 * gap;
	ROUGHNESS = mix(0.95, 0.65, gap);
}
