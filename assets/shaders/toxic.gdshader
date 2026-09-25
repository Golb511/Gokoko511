shader_type spatial;
// Toxic swamp water: murky green liquid with drifting scum, rising bubbles
// that pop in bright rings, and a sickly inner glow.
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D cell_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 deep_color : source_color = vec3(0.04, 0.09, 0.03);
uniform vec3 glow_color : source_color = vec3(0.45, 1.0, 0.15);
uniform float glow = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * 0.2;
	float scum = texture(noise_tex, p * 0.8 + vec2(TIME * 0.012, TIME * 0.008)).r;
	float scum2 = texture(noise_tex, p * 1.9 - vec2(TIME * 0.01, -TIME * 0.015)).r;
	// Bubbles: cells that swell and pop on a per-cell phase.
	vec2 cuv = p * 2.2;
	float cell = texture(cell_tex, cuv).r;
	float phase = fract(TIME * 0.35 + texture(noise_tex, floor(cuv * 4.0) / 16.0).r * 5.0);
	float bubble = smoothstep(0.12, 0.02, abs(cell - (1.0 - phase) * 0.35)) * smoothstep(1.0, 0.6, phase);
	float film = smoothstep(0.45, 0.7, scum * 0.6 + scum2 * 0.5);
	vec3 col = mix(deep_color, deep_color * 2.4 + vec3(0.02, 0.05, 0.0), film);
	ALBEDO = col;
	ROUGHNESS = mix(0.12, 0.6, film);
	METALLIC = 0.1;
	SPECULAR = 0.7;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = glow_color * glow * ((1.0 - film) * 0.18 + bubble * 0.9 + fres * 0.12);
}
