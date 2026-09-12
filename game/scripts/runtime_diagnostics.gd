extends Node
## Local, read-only counters and bounded numerical Environment tuning.
## No network listener, shader feature toggles, resource rebuilds or file writes.
signal tuning_changed(values: Dictionary)
@export_category("Local runtime diagnostics")
@export var inspector_snapshot: Dictionary={}
@export var inspector_tune_request: Dictionary={}
@export var inspector_tune_result: Dictionary={}
@export var refresh_inspector: bool=false:
	set(requested):
		refresh_inspector=false
		if requested and is_inside_tree(): snapshot()
@export var apply_inspector_tuning: bool=false:
	set(requested):
		apply_inspector_tuning=false
		if requested and is_inside_tree(): inspector_tune_result=tune(inspector_tune_request)
@export var reset_inspector_tuning: bool=false:
	set(requested):
		reset_inspector_tuning=false
		if requested and is_inside_tree(): inspector_tune_result=reset_tuning()
const NUMERIC := {
	"exposure":{"property":"tonemap_exposure","min":0.10,"max":3.0,"step":0.01,"label":"曝光"},
	"ambient":{"property":"ambient_light_energy","min":0.0,"max":2.0,"step":0.01,"label":"环境光"},
	"sun_energy":{"property":"light_energy","min":0.0,"max":4.0,"step":0.01,"label":"阳光强度","target":"sun"},
	"fog_density":{"property":"fog_density","min":0.0,"max":0.002,"step":0.000005,"label":"雾密度","feature":"fog_enabled"},
	"fog_light_energy":{"property":"fog_light_energy","min":0.0,"max":2.0,"step":0.01,"label":"雾亮度","feature":"fog_enabled"},
	"glow_intensity":{"property":"glow_intensity","min":0.0,"max":2.0,"step":0.01,"label":"辉光强度","feature":"glow_enabled"},
	"ssao_intensity":{"property":"ssao_intensity","min":0.0,"max":4.0,"step":0.05,"label":"接触阴影强度","feature":"ssao_enabled"},
	"glass_roughness":{"property":"roughness","min":0.0,"max":1.0,"step":0.01,"label":"玻璃粗糙度","target":"glass"},
	"glass_metallic":{"property":"metallic","min":0.0,"max":1.0,"step":0.01,"label":"玻璃金属度","target":"glass"}
}
const COUNTERS := {
	"fps":Performance.TIME_FPS,
	"process_seconds":Performance.TIME_PROCESS,
	"physics_seconds":Performance.TIME_PHYSICS_PROCESS,
	"objects":Performance.OBJECT_COUNT,
	"nodes":Performance.OBJECT_NODE_COUNT,
	"resources":Performance.OBJECT_RESOURCE_COUNT,
	"render_objects":Performance.RENDER_TOTAL_OBJECTS_IN_FRAME,
	"render_primitives":Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME,
	"draw_calls":Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,
	"video_memory_bytes":Performance.RENDER_VIDEO_MEM_USED,
	"texture_memory_bytes":Performance.RENDER_TEXTURE_MEM_USED,
	"buffer_memory_bytes":Performance.RENDER_BUFFER_MEM_USED,
	"static_memory_bytes":Performance.MEMORY_STATIC,
	"static_memory_max_bytes":Performance.MEMORY_STATIC_MAX,
	"active_physics_bodies":Performance.PHYSICS_3D_ACTIVE_OBJECTS,
	"physics_collision_pairs":Performance.PHYSICS_3D_COLLISION_PAIRS,
	"physics_islands":Performance.PHYSICS_3D_ISLAND_COUNT,
	"pipeline_canvas":Performance.PIPELINE_COMPILATIONS_CANVAS,
	"pipeline_mesh":Performance.PIPELINE_COMPILATIONS_MESH,
	"pipeline_surface":Performance.PIPELINE_COMPILATIONS_SURFACE,
	"pipeline_draw":Performance.PIPELINE_COMPILATIONS_DRAW,
	"pipeline_specialization":Performance.PIPELINE_COMPILATIONS_SPECIALIZATION
}
var _game_ref: WeakRef
var _environment_ref: WeakRef
var _sun_ref: WeakRef
var _roles_ref: WeakRef
var _role_original: Dictionary={}
var _original: Dictionary = {}
var _property_cache: Dictionary = {}

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_process(false)

func _read(object: Variant, property: StringName, fallback: Variant = null) -> Variant:
	if not object is Object or not is_instance_valid(object): return fallback
	var id: int=object.get_instance_id()
	if not _property_cache.has(id):
		var names: Dictionary={}
		for item: Dictionary in object.get_property_list(): names[item.name]=true
		_property_cache[id]=names
	return object.get(property) if _property_cache[id].has(property) else fallback

func _game() -> Node:
	return _game_ref.get_ref() if _game_ref!=null else null

func _environment() -> Environment:
	var holder: Variant=_read(_game(),"environment")
	if holder is Environment: return holder
	if holder is WorldEnvironment: return holder.environment
	return null

func _sun() -> DirectionalLight3D:
	var light: Variant=_read(_game(),"sun")
	return light if light is DirectionalLight3D and is_instance_valid(light) else null

func _roles() -> Variant:
	return _read(_read(_game(),"world"),"material_roles")

func _role_ready(role_registry: Variant) -> bool:
	return role_registry is Object and is_instance_valid(role_registry) and role_registry.has_method("snapshot_role") and role_registry.has_method("restore_role") and role_registry.has_method("set_role") and role_registry.has_method("stats")

func _cycle_base() -> Dictionary:
	var env:=_environment()
	if env==null or not env.has_meta("cycle_base_values"): return {}
	var supplied: Variant=env.get_meta("cycle_base_values")
	var result: Dictionary={}
	if supplied is Dictionary:
		for key in supplied:
			if NUMERIC.has(key) and NUMERIC[key].get("target","")!="glass" and (supplied[key] is float or supplied[key] is int) and is_finite(float(supplied[key])) and float(supplied[key])>=0.0: result[key]=float(supplied[key])
	return result

func _cycle_multipliers() -> Dictionary:
	var env:=_environment()
	if env==null or not env.has_meta("cycle_tuning_multipliers"): return {}
	var supplied: Variant=env.get_meta("cycle_tuning_multipliers")
	return supplied.duplicate() if supplied is Dictionary else {}

func _restore_cycle_preferences(preferences: Dictionary) -> void:
	var base:=_cycle_base()
	var env:=_environment()
	if env==null: return
	var ratios: Dictionary={}
	for key in preferences:
		var ratio: Variant=preferences[key]
		if not NUMERIC.has(key) or NUMERIC[key].get("target","")=="glass" or (not ratio is float and not ratio is int) or not is_finite(float(ratio)): continue
		ratios[key]=clampf(float(ratio),0.0,100.0)
		# Store legitimate preferences before the first daylight update as well.
		# The cycle reads this metadata when its baseline becomes available.
		if not base.has(key): continue
		var value: float=clampf(base[key]*ratios[key],NUMERIC[key].min,NUMERIC[key].max)
		if NUMERIC[key].get("target","")=="sun":
			if _sun()!=null: _sun().light_energy=value
		else: env.set(NUMERIC[key].property,value)
	env.set_meta("cycle_tuning_multipliers",ratios)
	_sync_settings(values())

func _capture_targets() -> void:
	var env:=_environment()
	if env!=null and (_environment_ref==null or _environment_ref.get_ref()!=env):
		_environment_ref=weakref(env)
		for key: String in NUMERIC:
			if not NUMERIC[key].has("target"): _original[key]=float(env.get(NUMERIC[key].property))
	var sun:=_sun()
	if sun!=null and (_sun_ref==null or _sun_ref.get_ref()!=sun):
		_sun_ref=weakref(sun);_original.sun_energy=float(sun.light_energy)
	var roles: Variant=_roles()
	if _role_ready(roles) and (_roles_ref==null or _roles_ref.get_ref()!=roles):
		_roles_ref=weakref(roles)
		_role_original=roles.snapshot_role("glass")
		var current:=values()
		for key: String in ["glass_roughness","glass_metallic"]:
			if current.has(key): _original[key]=current[key]

func setup(game: Node) -> void:
	var same_game: bool=_game()==game and is_instance_valid(game)
	_game_ref=weakref(game) if is_instance_valid(game) else null
	_property_cache.clear()
	if not same_game:
		_environment_ref=null;_sun_ref=null;_roles_ref=null
		_original.clear();_role_original.clear()
	_capture_targets()
	if same_game: return
	# Settings synchronization is in memory only; main owns explicit persistence.
	var settings: Variant=_read(game,"settings",{})
	if settings is Dictionary:
		var cycle_preferences: Variant=settings.get("cycle_tuning")
		if cycle_preferences is Dictionary: cycle_preferences=cycle_preferences.duplicate()
		var legacy: Variant=settings.get("render_tuning")
		if legacy is Dictionary:
			legacy=legacy.duplicate()
			if cycle_preferences is Dictionary:
				for key in cycle_preferences: legacy.erase(key)
			tune(legacy)
		if cycle_preferences is Dictionary: _restore_cycle_preferences(cycle_preferences)

func limits() -> Dictionary:
	return NUMERIC.duplicate(true)

func values() -> Dictionary:
	var env:=_environment()
	var result: Dictionary={}
	if env!=null:
		for key: String in NUMERIC:
			if not NUMERIC[key].has("target"): result[key]=float(env.get(NUMERIC[key].property))
	var sun:=_sun()
	if sun!=null: result.sun_energy=float(sun.light_energy)
	var roles: Variant=_roles()
	if _role_ready(roles):
		var stats: Dictionary=roles.stats()
		if int(stats.get("roles",{}).get("glass",0))>0:
			var profile: Dictionary=stats.get("current_overrides",{}).get("glass",{})
			result.glass_roughness=profile.get("roughness")
			result.glass_metallic=profile.get("metallic")
	return result

func _sync_settings(current: Dictionary) -> void:
	var settings: Variant=_read(_game(),"settings")
	if settings is Dictionary:
		var numeric: Dictionary={}
		var cycle:=_cycle_base()
		for key in current:
			if (current[key] is float or current[key] is int) and not cycle.has(key): numeric[key]=current[key]
		settings["render_tuning"]=numeric
		if not cycle.is_empty(): settings["cycle_tuning"]=_cycle_multipliers()

func tune(changes: Dictionary) -> Dictionary:
	var rejected: Dictionary={}
	var accepted: Dictionary={}
	var clamped: Dictionary={}
	_capture_targets()
	for raw_key in changes:
		var key:=str(raw_key)
		var value: Variant=changes[raw_key]
		if not raw_key is String and not raw_key is StringName:
			rejected[key]="key must be a string";continue
		if not NUMERIC.has(key): rejected[key]="unknown or structural setting";continue
		if not value is float and not value is int: rejected[key]="finite number required";continue
		if not is_finite(float(value)): rejected[key]="finite number required";continue
		var bounded: float=clampf(float(value),NUMERIC[key].min,NUMERIC[key].max)
		accepted[key]=bounded
		if bounded!=float(value): clamped[key]={"requested":value,"applied":bounded}
	var env:=_environment()
	var sun:=_sun()
	var roles: Variant=_roles()
	var glass: Dictionary={}
	var cycle:=_cycle_base()
	var ratios:=_cycle_multipliers()
	var cycle_changed:=false
	for key: String in accepted.keys():
		var target: String=NUMERIC[key].get("target","environment")
		if target=="sun" and sun==null:
			rejected[key]="sun unavailable";accepted.erase(key);continue
		if target=="environment" and env==null:
			rejected[key]="environment unavailable";accepted.erase(key);continue
		if cycle.has(key):
			var base: float=cycle[key]
			if base<0.000000001:
				if accepted[key]!=0.0:
					rejected[key]="current time-cycle baseline is zero";accepted.erase(key);continue
			else:
				var ratio: float=clampf(accepted[key]/base,0.0,100.0)
				var actual: float=clampf(base*ratio,NUMERIC[key].min,NUMERIC[key].max)
				if not is_equal_approx(actual,accepted[key]): clamped[key]={"requested":changes[key],"applied":actual}
				accepted[key]=actual;ratios[key]=ratio;cycle_changed=true
		if target=="sun":
			if sun!=null: sun.light_energy=accepted[key]
			else: rejected[key]="sun unavailable";accepted.erase(key)
		elif target=="glass":
			if _role_ready(roles): glass[NUMERIC[key].property]=accepted[key]
			else: rejected[key]="material role registry unavailable";accepted.erase(key)
		elif env!=null: env.set(NUMERIC[key].property,accepted[key])
		else: rejected[key]="environment unavailable";accepted.erase(key)
	if cycle_changed and env!=null: env.set_meta("cycle_tuning_multipliers",ratios)
	if not glass.is_empty():
		var role_result: Dictionary=roles.set_role("glass",glass)
		if not role_result.get("ok",false):
			for key: String in ["glass_roughness","glass_metallic"]:
				if accepted.has(key): rejected[key]="material role update rejected";accepted.erase(key)
	var current:=values()
	if not accepted.is_empty():
		_sync_settings(current)
		tuning_changed.emit(current)
	return {"ok":rejected.is_empty(),"applied":accepted,"clamped":clamped,"rejected":rejected,"values":current}

func reset_tuning() -> Dictionary:
	var env:=_environment()
	if env==null or _environment_ref==null or _environment_ref.get_ref()!=env:
		return {"ok":false,"applied":{},"rejected":{"reset":"original environment unavailable"},"values":values()}
	# Restore exact original numerical values, even if an author preset lies
	# outside the narrower interactive slider range. Feature flags remain untouched.
	var cycle:=_cycle_base()
	if env.has_meta("cycle_tuning_multipliers"):
		env.set_meta("cycle_tuning_multipliers",{})
		var settings: Variant=_read(_game(),"settings")
		if settings is Dictionary: settings["cycle_tuning"]={}
	for key: String in _original:
		if not NUMERIC[key].has("target"): env.set(NUMERIC[key].property,cycle.get(key,_original[key]))
	var rejected: Dictionary={}
	var sun:=_sun()
	if _original.has("sun_energy"):
		if sun!=null and _sun_ref!=null and _sun_ref.get_ref()==sun: sun.light_energy=cycle.get("sun_energy",_original.sun_energy)
		else: rejected.sun_energy="original sun unavailable"
	var roles: Variant=_roles()
	if not _role_original.is_empty():
		if _role_ready(roles) and _roles_ref!=null and _roles_ref.get_ref()==roles:
			var role_result: Dictionary=roles.restore_role("glass",_role_original)
			if not role_result.get("ok",false): rejected.glass="role restoration rejected"
		else: rejected.glass="original registry unavailable"
	var current:=values()
	_sync_settings(current)
	tuning_changed.emit(current)
	return {"ok":rejected.is_empty(),"applied":current.duplicate(),"rejected":rejected,"values":current}

func _world_snapshot(world: Variant) -> Dictionary:
	var structures: Variant=_read(world,"structures")
	var destroyed: Variant=_read(world,"destroyed")
	var cells: Variant=_read(world,"_visual_cells")
	var live_destroyed: Variant=null
	if structures is Dictionary and destroyed is Dictionary:
		live_destroyed=0
		for id in destroyed:
			if structures.has(id): live_destroyed+=1
	var mesh_batches: Variant=null
	if cells is Dictionary:
		mesh_batches=0
		for data in cells.values():
			if not data is Dictionary: continue
			for key: String in ["instance","detail"]:
				var node: Variant=data.get(key)
				if node is MeshInstance3D and is_instance_valid(node) and node.mesh!=null: mesh_batches+=1
	var supplied: Dictionary={}
	if world is Object and is_instance_valid(world) and world.has_method("diagnostics_stats"):
		var returned: Variant=world.call("diagnostics_stats")
		if returned is Dictionary: supplied=returned.duplicate(true)
	var streaming: Variant=null
	if world is Object and is_instance_valid(world) and world.has_method("streaming_stats"):
		var returned: Variant=world.call("streaming_stats")
		if returned is Dictionary: streaming=returned.duplicate(true)
	var roles: Variant=_read(world,"material_roles")
	var role_stats: Variant=null
	if roles is Object and is_instance_valid(roles) and roles.has_method("stats"): role_stats=roles.stats().duplicate(true)
	return {"available":world is Object and is_instance_valid(world),"structures":structures.size() if structures is Dictionary else null,
		"destroyed_registered":live_destroyed,"destroyed_history_ids":destroyed.size() if destroyed is Dictionary else null,
		"structure_cells":cells.size() if cells is Dictionary else null,"architecture_mesh_batches":mesh_batches,
		"resident_tiles":streaming.get("resident") if streaming is Dictionary else supplied.get("resident_tiles"),"streaming":streaming,"material_roles":role_stats,"provided":supplied}

func snapshot() -> Dictionary:
	var counters: Dictionary={}
	for key: String in COUNTERS: counters[key]=Performance.get_monitor(COUNTERS[key])
	var game:=_game()
	var env:=_environment()
	var vehicles: Variant=_read(game,"vehicles")
	var player: Variant=_read(game,"player")
	var current_vehicle: Variant=_read(game,"current_vehicle")
	var weapons: Variant=_read(game,"weapons")
	var weapon_stats: Variant=null
	if weapons is Object and is_instance_valid(weapons) and weapons.has_method("stats"): weapon_stats=weapons.stats().duplicate(true)
	var flags: Dictionary={}
	if env!=null:
		for key: String in ["ssao_enabled","ssr_enabled","glow_enabled","fog_enabled","volumetric_fog_enabled"]: flags[key]=env.get(key)
	var headless: bool=DisplayServer.get_name()=="headless"
	var position: Variant=player.global_position if player is Node3D and is_instance_valid(player) else null
	var world_data:=_world_snapshot(_read(game,"world"))
	var city_clock: Variant=_read(game,"city_clock")
	var clock_data: Variant=null
	if city_clock is Object and is_instance_valid(city_clock) and city_clock.has_method("get_state") and city_clock.has_method("solar_state"):
		var solar: Dictionary=city_clock.solar_state().duplicate(true)
		for key in solar:
			if solar[key] is Vector3: solar[key]=[solar[key].x,solar[key].y,solar[key].z]
		clock_data={"state":city_clock.get_state().duplicate(true),"solar_state":solar}
	var last_spawn: Variant=game.get_meta("last_spawn_profile") if is_instance_valid(game) and game.has_meta("last_spawn_profile") else null
	var result: Dictionary={"sample_ticks_usec":Time.get_ticks_usec(),"frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),
		"tree_paused":get_tree().paused if is_inside_tree() else false,"game_paused":_read(game,"paused"),
		"engine":Engine.get_version_info().string,"performance":counters,
		"render":{"method":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"headless":headless,"cpu_setup_ms":RenderingServer.get_frame_setup_time_cpu() if not headless else null,"enabled_flags":flags},
		"availability":{"render_counters":not headless,"static_memory":OS.is_debug_build(),"resident_tiles":world_data.resident_tiles!=null,"gpu_frame_time":false},
		"world":world_data,"airport":_world_snapshot(_read(game,"airport")),"city_clock":clock_data,"last_spawn_profile":last_spawn.duplicate(true) if last_spawn is Dictionary else null,
		"vehicles":vehicles.size() if vehicles is Array else null,
		"player_position":[position.x,position.y,position.z] if position is Vector3 else null,
		"vehicle_kind":_read(current_vehicle,"kind"),"weapons":weapon_stats,"tuning":values(),"original_tuning":_original.duplicate(),
		"cycle":{"active":not _cycle_base().is_empty(),"base":_cycle_base(),"multipliers":_cycle_multipliers()},
		"monitor_note":"Godot counters may update once per second; primitives include rendering passes, not unique authored triangles. Release static-memory counters and headless rendering counters are unavailable."}
	inspector_snapshot=result
	return result
