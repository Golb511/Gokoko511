shader_type spatial;
// Tattered cloth cape: sways in the wind (more at the hem), torn edges via
// alpha scissor, dark dyed fabric with an embroidered glowing border, and the
// same gameplay feedback uniforms as the character shader.
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;

uniform vec3 cloth : source_color = vec3(0.3, 0.05, 0.04);
uniform vec3 glow_color : source_color = vec3(1.0, 0.3, 0.05);
uniform float glow_strength = 1.0;
uniform sampler2D noise_tex : hint_default_white, repeat_enable;
uniform float tatter = 0.55;
uniform float hit_flash = 0.0;
uniform float frozen = 0.0;
uniform float poisoned = 0.0;
uniform float dissolve = 0.0;
uniform float shadow_form = 0.0;
uniform float sway = 1.0;
uniform float cape_len = 1.25;
varying float hem_v;
varying float side_v;

void vertex() {
	float hem = clamp(0.5 - VERTEX.y / cape_len, 0.0, 1.0);   // 0 at the shoulders, 1 at the hem
	hem_v = hem;
	side_v = UV.x;
	float t = TIME * 2.2 + NODE_POSITION_WORLD.x * 0.7 + NODE_POSITION_WORLD.z * 0.5;
	VERTEX.z -= hem * hem * (0.12 + 0.07 * sin(t + UV.x * 3.0)) * sway;
	VERTEX.x += hem * hem * 0.04 * sin(t * 1.3 + UV.x * 5.0) * sway;
	VERTEX.y += hem * hem * 0.03 * sin(t * 0.9) * sway;
}

void fragment() {
	vec2 cuv = vec2(side_v, hem_v);
	float n = texture(noise_tex, cuv * vec2(2.5, 1.2)).r;
	float n2 = texture(noise_tex, cuv * vec2(9.0, 4.0) + vec2(0.3)).r;
	// Torn hem (jagged strips) and a few holes.
	float strips = abs(fract(side_v * 7.0 + n * 0.6) - 0.5) * 2.0;
	float torn = hem_v - (1.0 - tatter * 0.45) + strips * tatter * 0.35 + n2 * 0.15 - 0.05;
	if (torn > 0.0 || n2 * n > 0.68 - dissolve) { discard; }
	if (dissolve > 0.0 && n < dissolve) { discard; }
	float folds = 0.7 + 0.3 * sin(side_v * 26.0 + n * 4.0);
	vec3 col = cloth * 1.7 * folds * (0.7 + 0.5 * n2);
	float border = smoothstep(0.035, 0.0, min(side_v, 1.0 - side_v)) * (1.0 - hem_v);
	vec3 emit = glow_color * glow_strength * border * 0.35;
	emit += glow_color * glow_strength * 0.12 * smoothstep(0.06, 0.0, -torn);
	emit += vec3(1.0, 0.95, 0.9) * hit_flash * 1.2;
	col = mix(col, vec3(0.55, 0.8, 1.0), frozen * 0.6);
	col = mix(col, col * vec3(0.5, 1.1, 0.4), poisoned * 0.6);
	col = mix(col, vec3(0.02, 0.0, 0.05), shadow_form * 0.8);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	EMISSION = emit;
	BACKLIGHT = cloth * 0.4;
}
