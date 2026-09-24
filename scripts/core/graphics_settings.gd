class_name GraphicsSettings
extends RefCounted
## Applies quality presets to environments, lights and particle density.
## quality: 0 low (mobile), 1 medium, 2 high, 3 ultra.

static func quality() -> int:
	return int(Game.setting("quality", 2))


static func apply_window() -> void:
	VFX.set_quality(quality())
	var vp := Engine.get_main_loop().root as Window
	vp.msaa_3d = Viewport.MSAA_DISABLED if quality() <= 1 else Viewport.MSAA_2X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality() >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.scaling_3d_scale = 0.75 if quality() == 0 else 1.0


static func is_mobile_renderer() -> bool:
	return str(ProjectSettings.get_setting_with_override("rendering/renderer/rendering_method")) != "forward_plus"


## Builds a cinematic dark-fantasy WorldEnvironment from a region theme.
static func make_environment(theme: Dictionary) -> WorldEnvironment:
	var q := quality()
	var env := Environment.new()
	var sky := Sky.new()
	var psky := ProceduralSkyMaterial.new()
	psky.sky_top_color = _c(theme.get("sky_top", [0.05, 0.03, 0.04]))
	psky.sky_horizon_color = _c(theme.get("sky_horizon", [0.4, 0.12, 0.05]))
	psky.ground_horizon_color = _c(theme.get("sky_horizon", [0.4, 0.12, 0.05])).darkened(0.4)
	psky.ground_bottom_color = Color(0.02, 0.015, 0.015)
	psky.sun_angle_max = 20.0
	psky.sky_energy_multiplier = 0.8
	sky.sky_material = psky
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _c(theme.get("ambient", [0.3, 0.22, 0.2]))
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = _c(theme.get("fog", [0.2, 0.08, 0.05]))
	env.fog_light_energy = 1.0
	env.fog_density = 0.006
	env.fog_sky_affect = 0.6
	env.fog_height = 1.5
	env.fog_height_density = 0.12
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.92
	if not is_mobile_renderer() and q >= 2:
		env.ssao_enabled = true
		env.ssao_radius = 1.4
		env.ssao_intensity = 2.2
		env.ssil_enabled = q >= 3
		if Game.setting("fog", true):
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = 0.012
			env.volumetric_fog_albedo = _c(theme.get("fog", [0.2, 0.08, 0.05])).lightened(0.3)
			env.volumetric_fog_emission = _c(theme.get("fog", [0.2, 0.08, 0.05])) * 0.15
			env.volumetric_fog_length = 80.0
			env.volumetric_fog_anisotropy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	return we


static func make_sun(theme: Dictionary) -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.light_color = _c(theme.get("sun", [1, 0.65, 0.45]))
	sun.light_energy = float(theme.get("sun_energy", 1.2))
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.shadow_enabled = bool(Game.setting("shadows", true)) and quality() >= 1
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if quality() <= 1 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.light_angular_distance = 1.0
	return sun


static func _c(a) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]))
