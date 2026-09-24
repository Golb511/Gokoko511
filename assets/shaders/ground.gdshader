shader_type spatial;
// Battlefield ground: two-tone rocky soil, scattered stones, scorched cracks
// with optional glowing lava veins, all world-space so it tiles seamlessly.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D cell_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 color_a : source_color = vec3(0.16, 0.13, 0.12);
uniform vec3 color_b : source_color = vec3(0.09, 0.07, 0.07);
uniform vec3 lava_color : source_color = vec3(1.0, 0.35, 0.05);
uniform float lava = 0.0;
uniform float snow = 0.0;
uniform float moss = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float big = texture(noise_tex, p * 0.012).r;
	float mid = texture(noise_tex, p * 0.07 + vec2(0.3, 0.7)).r;
	float fine = texture(noise_tex, p * 0.45).r;
	float cells = texture(cell_tex, p * 0.18).r;
	vec3 col = mix(color_a, color_b, smoothstep(0.35, 0.7, big * 0.7 + mid * 0.3));
	col *= 0.75 + 0.5 * fine;
	// pebbles
	float peb = smoothstep(0.12, 0.02, cells) * step(0.45, mid);
	col = mix(col, col * 1.7 + vec3(0.03), peb);
	col = mix(col, vec3(0.1, 0.16, 0.06), moss * smoothstep(0.45, 0.7, mid));
	col = mix(col, vec3(0.78, 0.82, 0.9), snow * smoothstep(0.3, 0.6, big + fine * 0.3));
	float crack = smoothstep(0.93, 0.99, 1.0 - abs(mid * 2.0 - 1.0)) * smoothstep(0.4, 0.65, big);
	col *= 1.0 - crack * 0.7;
	ALBEDO = col;
	NORMAL_MAP = texture(normal_tex, p * 0.25).rgb;
	NORMAL_MAP_DEPTH = 1.5;
	ROUGHNESS = 0.92 - snow * 0.25;
	float pulse = 0.75 + 0.25 * sin(TIME * 1.7 + big * 20.0);
	EMISSION = lava_color * crack * lava * 3.0 * pulse;
}
