shader_type spatial;
// Overlay for imported (external GLB) character models: their own PBR
// materials stay untouched, and this pass adds the combat feedback that the
// built-in character shader provides (hit flash, freeze, poison, shadow form,
// death dissolve glow, element rim).
render_mode blend_add, depth_draw_never, cull_back, unshaded;

uniform vec3 glow_color : source_color = vec3(1.0, 0.3, 0.05);
uniform float glow_strength = 1.0;
uniform float rim_strength = 0.0;
uniform float hit_flash = 0.0;
uniform float frozen = 0.0;
uniform float poisoned = 0.0;
uniform float dissolve = 0.0;
uniform float shadow_form = 0.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 c = glow_color * glow_strength * fres * rim_strength * 0.5;
	c += vec3(1.0, 0.95, 0.9) * hit_flash * 0.9;
	c += vec3(0.25, 0.6, 1.0) * frozen * (0.25 + fres * 1.6);
	c += vec3(0.2, 0.9, 0.1) * poisoned * fres * 1.0;
	c += vec3(0.5, 0.15, 1.0) * shadow_form * (fres * 2.0 + 0.1);
	c += glow_color * dissolve * (0.4 + fres * 3.0);
	ALBEDO = c;
	ALPHA = 1.0;
}
