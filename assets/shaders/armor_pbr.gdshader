shader_type spatial;
// PBR material for the forged hero armour (ArmorForge). Samples full texture
// sets (albedo / normal / roughness / metallic / emission maps from
// assets/textures/armor) with object-space triplanar projection, because the
// armour plates are rigid parts riding the skeleton bones. Keeps the gameplay
// feedback uniforms of character.gdshader (hit flash, freeze, poison,
// dissolve, shadow form, rim/glow) so every combat effect still shows.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_map : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D metallic_map : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D emission_map : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float albedo_gain = 1.0;
uniform float tile = 3.0;
uniform float normal_strength = 1.0;
uniform float roughness_mul = 1.0;
uniform float metallic_mul = 1.0;
uniform vec3 emission_color : source_color = vec3(1.0, 0.35, 0.06);
uniform float emission_energy = 0.0;
uniform float flat_emission = 0.0;      // uniform glow (visor, runes)
uniform float edge_wear = 0.35;         // brighter worn metal on convex silhouettes
// Gameplay feedback (same names as character.gdshader).
uniform vec3 glow_color : source_color = vec3(1.0, 0.3, 0.05);
uniform float glow_strength = 1.0;
uniform float rim_strength = 0.35;
uniform float hit_flash = 0.0;
uniform float frozen = 0.0;
uniform float poisoned = 0.0;
uniform float dissolve = 0.0;
uniform float shadow_form = 0.0;

varying vec3 op;
varying vec3 on;

void vertex() {
	op = VERTEX;
	on = NORMAL;
}

vec3 blend_w(vec3 n) {
	vec3 w = pow(abs(n), vec3(5.0));
	return w / (w.x + w.y + w.z);
}

void fragment() {
	vec3 n = normalize(on);
	vec3 w = blend_w(n);
	vec2 ux = op.zy * tile;
	vec2 uy = op.xz * tile;
	vec2 uz = op.xy * tile;
	vec3 alb = texture(albedo_map, ux).rgb * w.x + texture(albedo_map, uy).rgb * w.y + texture(albedo_map, uz).rgb * w.z;
	float rough = texture(roughness_map, ux).r * w.x + texture(roughness_map, uy).r * w.y + texture(roughness_map, uz).r * w.z;
	float metal = texture(metallic_map, ux).r * w.x + texture(metallic_map, uy).r * w.y + texture(metallic_map, uz).r * w.z;
	vec3 em = texture(emission_map, ux).rgb * w.x + texture(emission_map, uy).rgb * w.y + texture(emission_map, uz).rgb * w.z;

	// Triplanar normal mapping (whiteout blend) in object space, then to view space.
	vec3 tx = texture(normal_map, ux).rgb * 2.0 - 1.0;
	vec3 ty = texture(normal_map, uy).rgb * 2.0 - 1.0;
	vec3 tz = texture(normal_map, uz).rgb * 2.0 - 1.0;
	tx.xy *= normal_strength; ty.xy *= normal_strength; tz.xy *= normal_strength;
	vec3 nx = vec3(tx.xy + n.zy, abs(tx.z) * n.x).zyx;
	vec3 ny = vec3(ty.xy + n.xz, abs(ty.z) * n.y).xzy;
	vec3 nz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	vec3 nobj = normalize(nx * w.x + ny * w.y + nz * w.z);
	vec3 nview = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(nobj, 0.0)).xyz);
	// Normals are authored outward (analytic), so no back-face flip is needed.
	NORMAL = nview;

	float fres = pow(1.0 - clamp(dot(nview, VIEW), 0.0, 1.0), 3.0);
	vec3 col = alb * tint * albedo_gain;
	// Worn highlights where the plate curves away (cheap edge-wear stand-in).
	col = mix(col, col * 2.2 + vec3(0.03), smoothstep(0.35, 0.9, fres) * edge_wear * metal);

	vec3 emit = em * emission_color * emission_energy * (0.85 + 0.15 * sin(TIME * 2.6 + op.y * 9.0));
	emit += emission_color * flat_emission;
	emit += glow_color * glow_strength * fres * rim_strength * 0.35;
	emit += vec3(1.0, 0.95, 0.9) * hit_flash * 1.6;
	col = mix(col, vec3(0.55, 0.8, 1.0), frozen * 0.65);
	emit += vec3(0.25, 0.6, 1.0) * frozen * (0.3 + fres * 2.0);
	col = mix(col, col * vec3(0.5, 1.1, 0.4), poisoned * 0.6);
	emit += vec3(0.2, 0.9, 0.1) * poisoned * fres * 1.2;
	col = mix(col, vec3(0.02, 0.0, 0.05), shadow_form * 0.8);
	emit += vec3(0.5, 0.15, 1.0) * shadow_form * (fres * 2.5 + 0.1);
	if (dissolve > 0.0) {
		float d = fract(sin(dot(floor(op * 24.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453) * 0.6 + rough * 0.4;
		if (d < dissolve) { discard; }
		emit += glow_color * 6.0 * (1.0 - smoothstep(0.0, 0.06, d - dissolve));
	}
	ALBEDO = col;
	METALLIC = clamp(metal * metallic_mul, 0.0, 1.0);
	ROUGHNESS = clamp(rough * roughness_mul, 0.04, 1.0);
	SPECULAR = 0.5;
	EMISSION = emit;
}
