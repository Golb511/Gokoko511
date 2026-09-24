shader_type spatial;
// Molten lava: slowly flowing bright veins under a cooling dark crust, with
// pulsing heat and a hot edge where the crust breaks. Used for lava rivers
// (UV.y runs along the flow) and pools (world-space, flow = drift).
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D cell_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 hot_color : source_color = vec3(1.0, 0.42, 0.05);
uniform vec3 core_color : source_color = vec3(1.0, 0.72, 0.25);
uniform vec3 crust_color : source_color = vec3(0.06, 0.03, 0.02);
uniform float flow_speed = 0.35;
uniform float use_uv = 0.0;          // 1 = river (flow along UV.y), 0 = pool
uniform float heat = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 wp = world_pos.xz * 0.16;
	vec2 flow = vec2(TIME * 0.02, TIME * 0.013) * (1.0 + use_uv * flow_speed * 4.0);
	vec2 base_uv = wp;
	float n1 = texture(noise_tex, base_uv + flow).r;
	float n2 = texture(noise_tex, base_uv * 2.3 - flow * 1.7 + vec2(0.3, 0.1)).r;
	float cells = texture(cell_tex, base_uv * 1.4 + flow * 0.6).r;
	// Crust plates: dark islands floating on the molten flow.
	float crust = smoothstep(0.3, 0.58, cells * 0.6 + n2 * 0.5);
	float veins = 1.0 - crust;
	float pulse = 0.85 + 0.15 * sin(TIME * 1.7 + n1 * 6.0);
	// Rivers glow hotter in the middle and cool at the banks.
	float edge = mix(1.0, smoothstep(0.0, 0.35, UV.x) * smoothstep(1.0, 0.65, UV.x), use_uv);
	float molten = clamp(veins * (0.55 + n1 * 0.7) * edge, 0.0, 1.0);
	vec3 hot = mix(hot_color, core_color, smoothstep(0.55, 1.0, molten));
	ALBEDO = mix(crust_color, hot * 0.35, molten);
	ROUGHNESS = mix(0.85, 0.35, molten);
	EMISSION = hot * molten * 1.15 * pulse * heat + hot_color * 0.12 * edge;
}
