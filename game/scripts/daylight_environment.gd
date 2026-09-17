extends RefCounted
## Artistic daytime lighting. The CC0 sky is not a photograph of Sydney.
const PANORAMA = preload("res://assets/environment/rustig_koppie_puresky_2k.hdr")
const SUNSET_PANORAMA = preload("res://assets/environment/qwantani_sunset_puresky_2k.hdr")
const NIGHT_PANORAMA = preload("res://assets/environment/qwantani_night_puresky_2k.hdr")
const SKY_SHADER = preload("res://assets/environment/daylight.gdshader")
const CYCLE_SKY_INTERVAL_MS := 500
const DAY_AMBIENT := 0.55
const DAY_SKY_CONTRIBUTION := 0.55
const DAY_AMBIENT_COLOR := Color("d9cdb8")
const NIGHT_AMBIENT_COLOR := Color("8193bb")
const CYCLE_PROPERTY_KEYS := {"tonemap_exposure":"exposure","ambient_light_energy":"ambient","fog_density":"fog_density","fog_light_energy":"fog_light_energy","glow_intensity":"glow_intensity","ssao_intensity":"ssao_intensity"}
# Brightest source pixel centre, measured from the unchanged 2048 x 1024 HDR.
const SUN_UV := Vector2(1222.5 / 2048.0, 350.5 / 1024.0)
const TUNING_LIMITS := {
	"tonemap_exposure": Vector2(.5,1.5), "ambient_light_energy": Vector2(.2,1.0),
	"adjustment_contrast": Vector2(.9,1.15), "adjustment_saturation": Vector2(.8,1.2),
	"ssao_radius": Vector2(.25,2.0), "ssao_intensity": Vector2(0,1.5), "ssao_power": Vector2(.8,2.0),
	"glow_intensity": Vector2(0,.6), "glow_hdr_threshold": Vector2(1,4), "glow_hdr_scale": Vector2(.1,3),
	"ssr_max_steps": Vector2(16,96), "ssr_depth_tolerance": Vector2(.05,1),
	"fog_density": Vector2(0,.0001), "volumetric_fog_density": Vector2(0,.001), "volumetric_fog_length": Vector2(32,256)
}

static func quality_profile(quality: int) -> Dictionary:
	var level := clampi(quality,0,2)
	return {"quality":level,"name":["light","standard","fine"][level],
		"ssao_enabled":level>0,"ssao_radius":.95,"ssao_intensity":1.15,"ssao_power":1.3,
		"glow_enabled":level>0,"glow_intensity":.2 if level==1 else .27,
		"glow_hdr_threshold":1.6,"glow_hdr_scale":.8,
		"ssr_enabled":level==2,"ssr_max_steps":64,"ssr_depth_tolerance":.25}

static func make_environment() -> Environment:
	var env := Environment.new()
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("panorama", PANORAMA)
	material.set_shader_parameter("sunset_panorama", SUNSET_PANORAMA)
	material.set_shader_parameter("night_panorama", NIGHT_PANORAMA)
	var sky := Sky.new()
	sky.sky_material = material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# The blue HDR sky alone tinted every shadow and pale surface blue. Part of the
	# ambient term is a warm neutral in daylight and a cool blue at night.
	env.ambient_light_energy = DAY_AMBIENT
	env.ambient_light_sky_contribution = DAY_SKY_CONTRIBUTION
	env.ambient_light_color = DAY_AMBIENT_COLOR
	# AgX rolls off sunlit paving and the horizon sky instead of clipping them to white.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.16
	env.fog_enabled = true
	env.fog_light_color = Color("c4d4de")
	env.fog_density = 0.000025
	env.fog_sky_affect = 0.15
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.0
	env.ssao_power = 1.2
	env.ssao_light_affect = 0.08
	env.ssao_detail = 0.5
	# Only HDR highlights and emissive effects produce halos, not all surfaces.
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_normalized = true
	for index in 7: env.set_glow_level(index, [.2,.5,.25,.05,0,0,0][index])
	env.glow_hdr_luminance_cap = 8.0
	env.ssr_fade_in = .15
	env.ssr_fade_out = 2.0
	# Optional mist is not forced on in clear daylight or inside public halls.
	env.volumetric_fog_density = .0001
	env.volumetric_fog_length = 128.0
	env.volumetric_fog_albedo = Color("cad7df")
	env.volumetric_fog_anisotropy = .2
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_gi_inject = 0.0
	env.volumetric_fog_sky_affect = .05
	env.volumetric_fog_temporal_reprojection_amount = .8
	apply_quality(env, 1)
	return env

static func apply_quality(env: Environment, quality: int, options: Dictionary = {}) -> void:
	var profile := quality_profile(quality)
	var forward_plus := RenderingServer.get_current_rendering_method()=="forward_plus"
	for key in profile:
		if key in ["quality","name"]: continue
		env.set(key, profile[key])
	# Only setup or explicit quality-menu changes call this; no frame-time toggles.
	env.ssao_enabled = profile.ssao_enabled and forward_plus
	env.ssr_enabled = profile.ssr_enabled and forward_plus
	env.volumetric_fog_enabled = profile.quality==2 and forward_plus and bool(options.get("volumetric_fog",false))
	env.set_meta("quality_profile",profile.name)

static func apply_tuning(env: Environment, parameters: Dictionary) -> Dictionary:
	var applied := {}
	for key in parameters:
		if not TUNING_LIMITS.has(key) or not (parameters[key] is float or parameters[key] is int): continue
		var value := float(parameters[key])
		if not is_finite(value): continue
		var limits: Vector2 = TUNING_LIMITS[key]
		value = clampf(value,limits.x,limits.y)
		env.set(key,int(value) if key=="ssr_max_steps" else value)
		if CYCLE_PROPERTY_KEYS.has(key) and env.has_meta("cycle_base_values"):
			var cycle_key: String = CYCLE_PROPERTY_KEYS[key]
			var base: float = env.get_meta("cycle_base_values",{}).get(cycle_key,0)
			if base>0:
				var multipliers: Dictionary = env.get_meta("cycle_tuning_multipliers",{}).duplicate()
				multipliers[cycle_key]=value/base
				env.set_meta("cycle_tuning_multipliers",multipliers)
		applied[key] = env.get(key)
	return applied

static func runtime_parameters(env: Environment) -> Dictionary:
	var values := {"renderer":RenderingServer.get_current_rendering_method(),"profile":env.get_meta("quality_profile","custom"),
		"ssao_enabled":env.ssao_enabled,"ssr_enabled":env.ssr_enabled,"glow_enabled":env.glow_enabled,"volumetric_fog_enabled":env.volumetric_fog_enabled}
	for key in TUNING_LIMITS: values[key] = env.get(key)
	return values

static func cycle_profile(state: Dictionary, quality: int = 1) -> Dictionary:
	var elevation := clampf(float(state.get("elevation_deg",35)),-90,90)
	var night := clampf(float(state.get("night_factor",0)),0,1)
	var daylight := smoothstep(0.0,18.0,elevation)
	var warmth := 1.0-smoothstep(3.0,22.0,elevation)
	var evening := 1.0-smoothstep(-2.0,7.0,elevation)
	var above_horizon := smoothstep(-.833,2.5,elevation)
	var sunlight := 1.32*above_horizon*lerpf(.25,1.0,sqrt(maxf(0,sin(deg_to_rad(elevation)))))
	var profile := quality_profile(quality)
	return {"exposure":lerpf(1.0,1.18,night),"ambient":lerpf(DAY_AMBIENT,.78,night),
		"ambient_color":DAY_AMBIENT_COLOR.lerp(NIGHT_AMBIENT_COLOR,night),"sky_contribution":lerpf(DAY_SKY_CONTRIBUTION,.85,night),
		"sun_energy":sunlight,"fog_density":lerpf(.000025,.000018,night),
		"fog_light_energy":lerpf(1.0,.16,night),"glow_intensity":float(profile.glow_intensity)*lerpf(1.0,1.15,night),
		"ssao_intensity":lerpf(float(profile.ssao_intensity),.62,night),"day_weight":daylight,"night_weight":night,
		"sun_color":Color("ffad6b").lerp(Color("fff1dd"),1.0-warmth),
		"fog_color":Color("c4d4de").lerp(Color("ae8a99"),warmth*(1-night)).lerp(Color("344b73"),night),
		"sunset_tint":Vector3(1.24,.84,.66).lerp(Vector3(1.25,.77,.75),evening),
		"sunset_gain":lerpf(.85,.65,evening),"elevation":elevation}

static func apply_cycle(env: Environment, sun: DirectionalLight3D, state: Dictionary) -> void:
	if env==null or sun==null or env.sky==null or not env.sky.sky_material is ShaderMaterial: return
	var direction: Vector3 = state.get("sun_direction",Vector3(0,1,0))
	if not direction.is_finite() or direction.length_squared()<.5: return
	direction=direction.normalized()
	var quality: int = {"light":0,"standard":1,"fine":2}.get(env.get_meta("quality_profile","standard"),1)
	var profile := cycle_profile(state,quality)
	var base := {}
	for key in ["exposure","ambient","sun_energy","fog_density","fog_light_energy","glow_intensity","ssao_intensity"]: base[key]=profile[key]
	env.set_meta("cycle_base_values",base)
	var multipliers: Dictionary = env.get_meta("cycle_tuning_multipliers",{})
	var limits := {"exposure":Vector2(.1,3),"ambient":Vector2(0,2),"sun_energy":Vector2(0,4),"fog_density":Vector2(0,.002),"fog_light_energy":Vector2(0,2),"glow_intensity":Vector2(0,2),"ssao_intensity":Vector2(0,4)}
	var values := {}
	for key in base:
		var multiplier := float(multipliers.get(key,1.0))
		if not is_finite(multiplier): multiplier=1.0
		values[key]=clampf(float(base[key])*multiplier,limits[key].x,limits[key].y)
	env.tonemap_exposure=values.exposure
	env.ambient_light_energy=values.ambient
	env.fog_density=values.fog_density
	env.fog_light_energy=values.fog_light_energy
	env.glow_intensity=values.glow_intensity
	env.ssao_intensity=values.ssao_intensity
	env.fog_light_color=profile.fog_color
	env.ambient_light_color=profile.ambient_color
	env.ambient_light_sky_contribution=profile.sky_contribution
	sun.basis=Basis.looking_at(-direction,Vector3.RIGHT if absf(direction.y)>.999 else Vector3.UP)
	sun.light_color=profile.sun_color
	sun.light_energy=values.sun_energy
	# No moon proxy: the below-horizon sun contributes zero direct light.
	# All feature flags remain owned by explicit quality changes.
	var now := Time.get_ticks_msec()
	var last := int(env.get_meta("cycle_sky_tick_ms",-CYCLE_SKY_INTERVAL_MS))
	var hour := fposmod(float(state.get("hour",12)),24)
	var previous: float = env.get_meta("cycle_sky_hour",-100.0)
	var forced := bool(state.get("force_sky",false))
	if not forced and previous>-90 and absf(hour-previous)<.000001: return
	if not forced and previous>-90 and now-last<CYCLE_SKY_INTERVAL_MS: return
	var sky_material: ShaderMaterial = env.sky.sky_material
	if not env.has_meta("cycle_sky_updates"):
		env.sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL
		sky_material.set_shader_parameter("cycle_enabled",true)
	var parameters := {"sun_direction":direction,"sun_elevation":profile.elevation,"day_weight":profile.day_weight,
		"night_weight":profile.night_weight,"sunset_tint":profile.sunset_tint,"sunset_gain":profile.sunset_gain}
	for key in parameters: sky_material.set_shader_parameter(key,parameters[key])
	env.set_meta("cycle_sky_tick_ms",now)
	env.set_meta("cycle_sky_hour",hour)
	env.set_meta("cycle_sky_updates",int(env.get_meta("cycle_sky_updates",0))+1)

static func make_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	var bearing := (SUN_UV.x - 0.5) * TAU
	var polar := SUN_UV.y * PI
	var direction := Vector3(sin(bearing) * sin(polar), cos(polar), -cos(bearing) * sin(polar))
	sun.basis = Basis.looking_at(-direction)
	sun.light_color = Color("fff1dd")
	sun.light_energy = 1.15
	sun.light_angular_distance = 0.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 350
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	return sun
