extends RefCounted
## Conservative starting budgets, not measured device performance claims.
## Mobile keeps the full base city/collision resident; only nearby facade detail
## is streamed. Renderer selection itself belongs to project.godot / launch args.
static var _cached_current: Dictionary = {}
const TARGET_FPS := 30
const PHONE_SCALE := 0.67
const TABLET_SCALE := 0.75
const MOBILE_AA := [["off", "关闭"], ["msaa2", "MSAA 2×"]]


## Pure detection entry point lets QA exercise native/preview/desktop without
## pretending the host OS changed. A touch-capable desktop alone is not mobile.
static func detect(platform: String, features: PackedStringArray, arguments: PackedStringArray, model: String = "") -> Dictionary:
	var native := platform in ["iOS", "Android"] or "mobile" in features or "ios" in features or "android" in features
	var preview := "--mobile-preview" in arguments
	var enabled := native or preview
	var tablet := enabled and (model.to_lower().begins_with("ipad") or (preview and "--mobile-tablet" in arguments))
	return {"enabled":enabled,"native_mobile":native,"preview":preview,"tablet":tablet,
		"name":"mobile_tablet" if tablet else "mobile_phone" if enabled else "desktop",
		"target_fps":TARGET_FPS,"render_scale":TABLET_SCALE if tablet else PHONE_SCALE,
		"shadow_distance_m":160.0 if tablet else 120.0,"camera_far_m":6000.0,
		"facade_limit":24 if tablet else 16,"facade_load_radius_m":320.0 if tablet else 280.0,
		"facade_retain_radius_m":480.0 if tablet else 420.0,"facade_visible_distance_m":280.0 if tablet else 240.0}


static func current() -> Dictionary:
	# Platform, launch flags and hardware model cannot change during a run.
	if not _cached_current.is_empty(): return _cached_current.duplicate()
	var features := PackedStringArray()
	for feature: String in ["mobile", "ios", "android"]:
		if OS.has_feature(feature): features.append(feature)
	_cached_current = detect(OS.get_name(),features,OS.get_cmdline_user_args(),OS.get_model_name())
	return _cached_current.duplicate()


static func is_mobile() -> bool:
	if _cached_current.is_empty(): current()
	return bool(_cached_current.enabled)


## Input has already passed GameSettings validation. Never mutate the caller.
static func constrain_settings(settings: Dictionary, profile: Dictionary = {}) -> Dictionary:
	var selected := current() if profile.is_empty() else profile
	var result := settings.duplicate(true)
	if not bool(selected.enabled): return result
	result.max_fps = TARGET_FPS
	result.render_scale = minf(float(result.render_scale),float(selected.render_scale))
	result.quality = mini(int(result.quality),1)
	result.antialiasing = "off" if result.antialiasing == "off" else "msaa2"
	result.window_mode = "fullscreen"
	result.vsync = true
	return result


## Call AFTER main.apply_settings applies its desktop environment and sun values.
## No physics, gameplay, save data, base shells, or collision are modified here.
static func apply_runtime(game: Node, profile: Dictionary = {}) -> Dictionary:
	var selected := current() if profile.is_empty() else profile
	if not bool(selected.enabled): return {"enabled":false,"profile":"desktop"}
	var camera: Camera3D = game.get("camera")
	if is_instance_valid(camera): camera.far = float(selected.camera_far_m)
	var sun: DirectionalLight3D = game.get("sun")
	if is_instance_valid(sun):
		sun.directional_shadow_max_distance = float(selected.shadow_distance_m)
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	var holder: WorldEnvironment = game.get("environment")
	if is_instance_valid(holder) and holder.environment != null:
		var env := holder.environment
		# Forward+-only effects must also remain disabled during desktop preview.
		env.ssao_enabled = false
		env.ssr_enabled = false
		env.ssil_enabled = false
		env.sdfgi_enabled = false
		env.volumetric_fog_enabled = false
		env.glow_enabled = false
		if env.sky != null: env.sky.radiance_size = Sky.RADIANCE_SIZE_128
	var world: Node = game.get("world")
	if is_instance_valid(world):
		var stream: Variant = world.get("facade_stream")
		if is_instance_valid(stream) and stream.has_method("configure_budget"):
			stream.configure_budget(int(selected.facade_limit),float(selected.facade_load_radius_m),float(selected.facade_retain_radius_m),float(selected.facade_visible_distance_m))
	var report := status(game,selected)
	game.set_meta("mobile_profile",report)
	return report


## Read actual settings/renderer alongside intended budgets for honest QA.
static func status(game: Node = null, profile: Dictionary = {}) -> Dictionary:
	var selected := current() if profile.is_empty() else profile
	var result := selected.duplicate(true)
	result.renderer = RenderingServer.get_current_rendering_method()
	result.engine_max_fps = Engine.max_fps
	result.device_performance_verified = false
	result.streaming_scope = "near_facade_only; base city and collision remain resident"
	if not is_instance_valid(game): return result
	var viewport := game.get_viewport()
	if viewport != null:
		result.actual_render_scale = viewport.scaling_3d_scale
		result.actual_msaa = int(viewport.msaa_3d)
		result.actual_taa = viewport.use_taa
		result.actual_upscaler = int(viewport.scaling_3d_mode)
	var camera: Camera3D = game.get("camera")
	if is_instance_valid(camera): result.actual_camera_far_m = camera.far
	var sun: DirectionalLight3D = game.get("sun")
	if is_instance_valid(sun):
		result.actual_shadow_distance_m = sun.directional_shadow_max_distance
		result.actual_shadows_enabled = sun.shadow_enabled
	var holder: WorldEnvironment = game.get("environment")
	if is_instance_valid(holder) and holder.environment != null:
		result.environment = {}
		for key: String in ["ssao_enabled","ssr_enabled","ssil_enabled","sdfgi_enabled","volumetric_fog_enabled","glow_enabled"]:
			result.environment[key] = holder.environment.get(key)
	var world: Node = game.get("world")
	if is_instance_valid(world) and world.has_method("streaming_stats"): result.streaming = world.streaming_stats()
	return result
