shader_type spatial;
// Dark-fantasy PBR remap for stylised source textures: desaturates and darkens
// the albedo, derives metal/roughness from luminance, adds worn-metal detail,
// fiery rim lighting, glowing veins (lava/stone), plus gameplay feedback
// (hit flash, freeze, poison, dissolve on death).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_depth = 0.45;
uniform vec3 tint : source_color = vec3(0.4);
uniform float desaturate : hint_range(0.0, 1.0) = 0.6;
uniform float metal : hint_range(0.0, 1.0) = 0.6;
uniform float base_roughness : hint_range(0.0, 1.0) = 0.42;
uniform vec3 glow_color : source_color = vec3(1.0, 0.3, 0.05);
uniform float glow_strength = 1.0;
uniform float rim_strength = 0.6;
uniform float vein_amount : hint_range(0.0, 1.0) = 0.15;
uniform float stone = 0.0;
uniform float hit_flash = 0.0;
uniform float frozen = 0.0;
uniform float poisoned = 0.0;
uniform float dissolve = 0.0;
uniform float shadow_form = 0.0;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	vec2 duv = obj_pos.xy * 1.7 + obj_pos.zz * 0.9;
	float n = texture(detail_tex, duv).r;
	float n2 = texture(detail_tex, duv * 3.1 + vec2(0.37)).r;

	vec3 col = mix(base, vec3(lum), desaturate) * tint * 1.75;
	col *= 0.85 + 0.3 * n2;
	float metallic_mask = smoothstep(0.28, 0.62, lum) * metal;

	// Stone / lava-rock skin.
	vec3 stone_col = vec3(0.22, 0.2, 0.19) * (0.6 + 0.8 * n) * tint * 2.0;
	col = mix(col, stone_col, stone);
	metallic_mask *= (1.0 - stone);

	// Glowing veins (cracks) following the detail noise.
	float ridge = 1.0 - abs(n * 2.0 - 1.0);
	float mask = smoothstep(0.5, 0.72, texture(detail_tex, obj_pos.xz * 0.31 + vec2(0.61, 0.13)).r);
	float vein = smoothstep(0.975 - stone * 0.02, 0.996, ridge) * mask * (stone + vein_amount * 1.5);

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);

	vec3 emit = glow_color * glow_strength * (vein * 1.4 + fres * rim_strength);
	emit += vec3(1.0, 0.95, 0.9) * hit_flash * 1.8;

	col = mix(col, vec3(0.55, 0.8, 1.0), frozen * 0.65);
	emit += vec3(0.25, 0.6, 1.0) * frozen * (0.4 + fres * 2.0);
	col = mix(col, col * vec3(0.5, 1.1, 0.4), poisoned * 0.6);
	emit += vec3(0.2, 0.9, 0.1) * poisoned * fres * 1.2;
	col = mix(col, vec3(0.02, 0.0, 0.05), shadow_form * 0.8);
	emit += vec3(0.5, 0.15, 1.0) * shadow_form * (fres * 2.5 + 0.1);

	if (dissolve > 0.0) {
		float d = n * 0.8 + n2 * 0.2;
		if (d < dissolve) { discard; }
		emit += glow_color * 6.0 * (1.0 - smoothstep(0.0, 0.06, d - dissolve));
	}

	// Hammered / worn surface detail so flat low-poly panels catch light like forged metal.
	NORMAL_MAP = texture(detail_normal, duv * 2.3).rgb;
	NORMAL_MAP_DEPTH = normal_depth * (0.5 + metallic_mask + stone);
	ALBEDO = col;
	METALLIC = metallic_mask;
	ROUGHNESS = clamp(base_roughness + (n2 - 0.5) * 0.35 + stone * 0.4 - metallic_mask * 0.15, 0.08, 1.0);
	SPECULAR = 0.5;
	EMISSION = emit;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
