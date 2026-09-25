shader_type spatial;
// Gothic architecture material for the procedural towers (GothicKit).
// Parts are encoded in the vertex colour: R = glowing (windows, runes,
// crystals), G = dark slate / iron (roofs, cages, barrels), B = gold trim;
// everything else is carved stone with per-block variation, mortar, soot at
// the base and worn edges. Also keeps the tower feedback uniforms
// (disabled / buffed) of the old prop shader.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 stone_color : source_color = vec3(0.34, 0.31, 0.29);
uniform vec3 roof_color : source_color = vec3(0.07, 0.07, 0.09);
uniform vec3 accent : source_color = vec3(1.0, 0.4, 0.1);
uniform float glow_energy = 3.0;
uniform float block_w = 0.42;
uniform float block_h = 0.22;
uniform float disabled = 0.0;
uniform float buffed = 0.0;
uniform float snow = 0.0;

varying vec3 lp;
varying vec3 ln;
varying vec3 wp;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Running-bond masonry on a plane: returns (mortar mask, block id hash).
vec2 masonry(vec2 p) {
	float row = floor(p.y / block_h);
	float x = p.x / block_w + mod(row, 2.0) * 0.5;
	vec2 cell = vec2(floor(x), row);
	vec2 f = vec2(fract(x) * block_w, fract(p.y / block_h) * block_h);
	float m = min(min(f.x, block_w - f.x), min(f.y, block_h - f.y));
	return vec2(1.0 - smoothstep(0.008, 0.024, m), hash(cell));
}

void fragment() {
	float glow = COLOR.r;
	float roof = COLOR.g;
	float gold = COLOR.b;
	vec3 an = abs(normalize(ln));
	// Pick the masonry projection from the dominant local normal.
	vec2 mp = an.x > an.z ? lp.zy : lp.xy;
	if (an.y > 0.7) { mp = lp.xz; }
	vec2 ms = masonry(mp + vec2(lp.x * 0.0, 0.0));
	float n = texture(detail_tex, wp.xz * 0.35 + wp.yy * 0.21).r;
	float n2 = texture(detail_tex, mp * 2.3 + vec2(0.13)).r;

	// Stone: per-block tone, mortar, soot rising from the ground, worn highlights.
	vec3 st = stone_color * (0.84 + 0.26 * ms.y) * (0.78 + 0.4 * n2) * (0.9 + 0.2 * n);
	st = mix(st, stone_color * 0.35, ms.x * 0.75);
	st *= mix(0.45, 1.0, smoothstep(0.0, 1.4, lp.y));
	st = mix(st, st * vec3(0.72, 0.8, 0.62), smoothstep(0.62, 0.8, n) * 0.5 * (1.0 - smoothstep(0.0, 2.0, lp.y)));

	// Slate shingles for roofs / dark iron.
	float sh_row = floor(lp.y * 11.0);
	float ang = atan(lp.z, lp.x);
	float sh = fract(ang * 5.0 + mod(sh_row, 2.0) * 0.5);
	float scallop = smoothstep(0.0, 0.12, fract(lp.y * 11.0) - 0.5 * abs(sh - 0.5));
	vec3 rf = roof_color * (0.6 + 0.6 * scallop) * (0.8 + 0.4 * hash(vec2(floor(ang * 5.0), sh_row)));

	vec3 gd = vec3(0.6, 0.42, 0.15) * (0.7 + 0.5 * n2);
	vec3 col = st;
	col = mix(col, rf, roof);
	col = mix(col, gd, gold);
	// Full glow (R=1): windows / runes. Partial (R<0.9): crystal — glassy, tinted.
	float crystal = step(0.01, glow) * (1.0 - step(0.9, glow));
	col = mix(col, accent * 0.2, step(0.9, glow));
	col = mix(col, accent * 0.45 + vec3(0.05), crystal);
	float up = clamp(normalize(ln).y, 0.0, 1.0);
	col = mix(col, vec3(0.82, 0.88, 0.95), snow * smoothstep(0.6, 0.9, up) * (1.0 - glow));
	col = mix(col, vec3(dot(col, vec3(0.33)) * 0.4), disabled * 0.7);
	ALBEDO = col;

	float metal = max(gold, roof * 0.55);
	METALLIC = metal;
	ROUGHNESS = mix(clamp(mix(0.88 - n2 * 0.2, 0.35, metal) + ms.x * 0.1, 0.15, 1.0), 0.08, crystal);
	SPECULAR = mix(0.5, 1.0, crystal);
	NORMAL_MAP = texture(detail_normal, mp * 1.3).rgb;
	NORMAL_MAP_DEPTH = mix(1.2 + ms.x * 1.6, 0.4, max(sign(glow), metal));

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float pulse = 0.85 + 0.15 * sin(TIME * 2.3 + lp.y * 3.0);
	vec3 emit = accent * glow * glow_energy * pulse * (1.0 - crystal);
	emit += accent * crystal * (0.2 + fres * 0.9) * glow_energy * 0.18;
	// Faint element light bleeding from the mortar near glowing parts.
	emit += accent * fres * 0.012 * (1.0 - glow);
	emit += vec3(1.0, 0.75, 0.3) * buffed * (0.25 + fres * 1.4);
	emit += vec3(0.6, 0.1, 1.0) * disabled * fres * 1.5;
	EMISSION = emit;
}
