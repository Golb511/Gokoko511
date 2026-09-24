shader_type spatial;
// Environment / building remap: gothic grade + world-space triplanar stone
// detail so low-poly assets read as weathered rock, iron and timber.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.5);
uniform float desaturate : hint_range(0.0, 1.0) = 0.78;
uniform float brightness = 1.0;
uniform float detail_scale = 0.9;
uniform vec3 accent : source_color = vec3(1.0, 0.4, 0.1);
uniform float accent_strength = 0.0;
uniform float metal = 0.1;
uniform float snow = 0.0;
uniform float disabled = 0.0;
uniform float buffed = 0.0;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 triplanar(sampler2D tex, vec3 p, vec3 nrm) {
	vec3 w = pow(abs(nrm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(tex, p.zy) * w.x + texture(tex, p.xz) * w.y + texture(tex, p.xy) * w.z;
}

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 p = world_pos * detail_scale;
	float n = triplanar(detail_tex, p, world_nrm).r;
	float n2 = triplanar(detail_tex, p * 3.7, world_nrm).r;
	vec3 col = mix(base, vec3(lum), max(desaturate, 0.72)) * tint * 1.8 * brightness;
	col *= 0.65 + 0.55 * n * (0.7 + 0.6 * n2);
	// Dirt/soot in crevices and near the ground.
	col *= mix(0.55, 1.0, smoothstep(0.0, 1.6, world_pos.y));
	float up = clamp(world_nrm.y, 0.0, 1.0);
	col = mix(col, vec3(0.85, 0.9, 1.0), snow * smoothstep(0.55, 0.85, up) * smoothstep(0.35, 0.6, n));
	col = mix(col, vec3(lum * 0.3), disabled * 0.7);
	ALBEDO = col;
	vec3 nm = triplanar(detail_normal, p, world_nrm).rgb;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 1.2;
	METALLIC = metal * smoothstep(0.35, 0.7, lum);
	ROUGHNESS = clamp(0.75 + (n2 - 0.5) * 0.4 - snow * 0.3, 0.2, 1.0);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 emit = accent * accent_strength * fres * 0.35;
	emit += vec3(1.0, 0.75, 0.3) * buffed * (0.3 + fres * 1.5);
	emit += vec3(0.6, 0.1, 1.0) * disabled * fres * 1.5;
	EMISSION = emit;
}
