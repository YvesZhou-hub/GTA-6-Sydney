extends SceneTree
const Diagnostics=preload("res://scripts/runtime_diagnostics.gd")
const DiagnosticsPanel=preload("res://scripts/diagnostics_panel.gd")
var checks: Array=[]
var failures:=0

class FixtureWorld extends Node3D:
	var structures: Dictionary={"one":{},"two":{},"three":{}}
	var destroyed: Dictionary={"two":true,"retired_id":true}
	var _visual_cells: Dictionary={}
	var material_roles: RefCounted
	func diagnostics_stats() -> Dictionary: return {"resident_tiles":7,"pending_tiles":2}
	func streaming_stats() -> Dictionary:
		return {"enabled":true,"scope":"near_facade_only","resident":7,"limit":64,"wanted":9,"last_worker_ms":2.5,"last_upload_ms":.8,"base_collision_resident":true}

class FixtureWeapons extends Node:
	func stats() -> Dictionary:
		return {"active_projectiles":3,"projectile_capacity":24,"effects":{"active":2,"capacity":12}}

class FixtureGame extends Node3D:
	var environment: WorldEnvironment
	var sun: DirectionalLight3D
	var world: Node3D
	var airport: Node3D
	var player: Node3D
	var vehicles: Array=[1,2,3,4]
	var current_vehicle: Node3D
	var weapons: Node
	var city_clock: Node
	var settings: Dictionary={"quality":1,"sensitivity":.003}

func _init(): call_deferred("run")
func check(label: String, value: bool, evidence: Dictionary={}):
	checks.append({"name":label,"passed":value,"evidence":evidence})
	print(("PASS " if value else "FAIL ")+label+" "+JSON.stringify(evidence))
	if not value: failures+=1

func fixture_cycle(game: FixtureGame, exposure: float, ambient: float, sunlight: float) -> void:
	# Exercise the documented numeric cycle metadata contract without running
	# a city clock or claiming a separate Daylight renderer integration test.
	var base: Dictionary={"exposure":exposure,"ambient":ambient,"sun_energy":sunlight,"fog_density":.000025,"fog_light_energy":1.0,"glow_intensity":.3,"ssao_intensity":1.0}
	var env:=game.environment.environment
	env.set_meta("cycle_base_values",base)
	var multipliers: Dictionary=env.get_meta("cycle_tuning_multipliers",{})
	for key: String in base:
		var spec: Dictionary=Diagnostics.NUMERIC[key]
		var value: float=clampf(base[key]*float(multipliers.get(key,1.0)),spec.min,spec.max)
		if key=="sun_energy": game.sun.light_energy=value
		else: env.set(spec.property,value)

func run():
	var diagnostics=Diagnostics.new();root.add_child(diagnostics)
	diagnostics.setup(null)
	var empty: Dictionary=diagnostics.snapshot()
	check("Missing world and environment are explicitly unavailable",not empty.world.available and empty.world.structures==null and empty.vehicles==null and empty.player_position==null and empty.tuning.is_empty())
	var missing: Dictionary=diagnostics.tune({"exposure":1.5})
	check("Missing environment rejects changes safely",not missing.ok and missing.applied.is_empty() and missing.rejected.has("exposure"))
	check("Missing environment reset is safe",not diagnostics.reset_tuning().ok)
	var game:=FixtureGame.new();root.add_child(game)
	game.environment=WorldEnvironment.new();game.environment.environment=Environment.new();game.add_child(game.environment)
	game.sun=DirectionalLight3D.new();game.sun.light_energy=1.2;game.add_child(game.sun)
	var env:=game.environment.environment
	env.tonemap_exposure=.8;env.ambient_light_energy=.6;env.fog_density=.000025
	env.fog_enabled=true;env.glow_enabled=false;env.ssao_enabled=true;env.ssr_enabled=false
	game.world=FixtureWorld.new();game.add_child(game.world)
	var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();game.world.add_child(mesh)
	game.world._visual_cells[Vector2i.ZERO]={"instance":mesh,"detail":null,"ids":["one","two"]}
	game.player=Node3D.new();game.add_child(game.player);game.player.position=Vector3(12.5,4.54,-9)
	game.weapons=FixtureWeapons.new();game.add_child(game.weapons)
	game.set_meta("last_spawn_profile",{"kind":"tank","model_ms":12.0,"occupancy_cache_ms":1.0,"placement_ms":3.0,"total_ms":16.0})
	diagnostics.setup(game)
	var original: Dictionary=diagnostics.values()
	var memory_before: float=Performance.get_monitor(Performance.MEMORY_STATIC)
	var snapshot: Dictionary=diagnostics.snapshot()
	var memory_after: float=Performance.get_monitor(Performance.MEMORY_STATIC)
	for key: String in Diagnostics.COUNTERS:
		if key=="static_memory_bytes":
			check("Live memory counter lies between immediate before/after engine samples",snapshot.performance[key]>=minf(memory_before,memory_after) and snapshot.performance[key]<=maxf(memory_before,memory_after),{"snapshot":snapshot.performance[key],"before":memory_before,"after":memory_after})
		else:
			check("Performance source truth: "+key,snapshot.performance[key]==Performance.get_monitor(Diagnostics.COUNTERS[key]),{"snapshot":snapshot.performance[key],"engine":Performance.get_monitor(Diagnostics.COUNTERS[key])})
	check("Headless marks rendering unavailable rather than valid zero FPS",snapshot.render.headless and not snapshot.availability.render_counters and snapshot.render.cpu_setup_ms==null)
	check("Absent city clock is reported as unavailable",snapshot.city_clock==null)
	game.city_clock=load("res://scripts/city_clock.gd").new();game.add_child(game.city_clock);game.city_clock.set_process(false)
	var clock_snapshot: Dictionary=diagnostics.snapshot().city_clock
	var clock_solar: Dictionary=game.city_clock.solar_state()
	check("City clock snapshot reports actual current time and solar numeric state",clock_snapshot.state==game.city_clock.get_state() and clock_snapshot.solar_state.elevation_deg==clock_solar.elevation_deg and clock_snapshot.solar_state.sunrise_hour==clock_solar.sunrise_hour and clock_snapshot.solar_state.sunset_hour==clock_solar.sunset_hour and clock_snapshot.solar_state.night_factor==clock_solar.night_factor)
	var json_clock: Dictionary=JSON.parse_string(JSON.stringify(clock_snapshot))
	check("Solar direction is a JSON numeric array instead of a stringified Vector3",json_clock.solar_state.sun_direction is Array and json_clock.solar_state.sun_direction.size()==3 and Vector3(json_clock.solar_state.sun_direction[0],json_clock.solar_state.sun_direction[1],json_clock.solar_state.sun_direction[2]).is_equal_approx(clock_solar.sun_direction))
	check("Release-only memory limitation is explicitly reported",snapshot.availability.static_memory==OS.is_debug_build())
	check("World distinguishes live destroyed structures from retired history",snapshot.world.structures==3 and snapshot.world.destroyed_registered==1 and snapshot.world.destroyed_history_ids==2,snapshot.world)
	check("Architecture batches count actual resident meshes",snapshot.world.structure_cells==1 and snapshot.world.architecture_mesh_batches==1)
	check("Optional world tile provider is used without inventing a count",snapshot.world.resident_tiles==7 and snapshot.world.provided.pending_tiles==2)
	check("Live facade streaming stats preserve scope and immutable collision state",snapshot.availability.resident_tiles and snapshot.world.streaming.scope=="near_facade_only" and snapshot.world.streaming.base_collision_resident and snapshot.world.streaming.last_upload_ms==.8)
	check("Last vehicle spawn timings expose actual supplied profiling phases",snapshot.last_spawn_profile==game.get_meta("last_spawn_profile"))
	check("Absent airport retains unavailable counts",not snapshot.airport.available and snapshot.airport.resident_tiles==null)
	check("Vehicle, player and weapon pools use live owner state",snapshot.vehicles==4 and Vector3(snapshot.player_position[0],snapshot.player_position[1],snapshot.player_position[2]).distance_to(Vector3(12.5,4.54,-9))<.00001 and snapshot.weapons.active_projectiles==3 and snapshot.weapons.effects.active==2)
	var changed: Dictionary=diagnostics.tune({"exposure":1.3,"ambient":.8,"sun_energy":2.2,"fog_density":.00008,"fog_light_energy":.9,"glow_intensity":.7,"ssao_intensity":1.4})
	check("Supported numerical tuning changes the real Environment",changed.ok and is_equal_approx(env.tonemap_exposure,1.3) and is_equal_approx(env.ambient_light_energy,.8) and is_equal_approx(env.fog_density,.00008) and is_equal_approx(env.ssao_intensity,1.4))
	check("Sun energy changes the existing directional light only",is_equal_approx(game.sun.light_energy,2.2) and game.sun.shadow_enabled==false)
	check("Tuning synchronizes in-memory settings without touching unrelated keys",game.settings.render_tuning==diagnostics.values() and game.settings.quality==1 and game.settings.sensitivity==.003)
	check("Numerical changes never enable disabled render features",not env.glow_enabled and not env.ssr_enabled and env.ssao_enabled and env.fog_enabled)
	var clamped: Dictionary=diagnostics.tune({"exposure":999.0,"ambient":-12.0,"fog_density":10.0,"glow_intensity":-1.0})
	check("Finite out-of-range values are clamped with disclosed results",clamped.ok and clamped.clamped.size()==4 and env.tonemap_exposure==3 and env.ambient_light_energy==0 and is_equal_approx(env.fog_density,.002) and env.glow_intensity==0,clamped)
	var before_invalid: Dictionary=diagnostics.values()
	var invalid: Dictionary=diagnostics.tune({"exposure":NAN,"ambient":INF,"fog_density":"0.1","glow_intensity":true,"ssao_enabled":false,"ssr_max_steps":100,"unknown":2})
	check("NaN, infinity, strings, booleans and unknown/structural keys are rejected",not invalid.ok and invalid.rejected.size()==7 and invalid.applied.is_empty() and diagnostics.values()==before_invalid,invalid.rejected)
	var restored: Dictionary=diagnostics.reset_tuning()
	check("Reset restores every exact original numerical value",restored.ok and diagnostics.values()==original and game.settings.render_tuning==original)
	check("Original reset preserves feature flags",not env.glow_enabled and not env.ssr_enabled and env.ssao_enabled and env.fog_enabled)
	diagnostics.tune({"exposure":1.1})
	diagnostics.setup(game)
	diagnostics.reset_tuning()
	check("Repeated setup cannot accidentally replace the original preset",diagnostics.values()==original)
	game.settings.render_tuning["exposure"]=1.6
	var another=Diagnostics.new();root.add_child(another);another.setup(game)
	check("A fresh setup reapplies previously stored numerical preferences",is_equal_approx(env.tonemap_exposure,1.6))
	another.reset_tuning();another.queue_free()
	game.world.material_roles=preload("res://scripts/material_roles.gd").new()
	var roles: RefCounted=game.world.material_roles
	var glass_a:=StandardMaterial3D.new();glass_a.roughness=.12;glass_a.metallic=.08
	var glass_b:=StandardMaterial3D.new();glass_b.roughness=.64;glass_b.metallic=.44
	var shader_glass:=ShaderMaterial.new();shader_glass.shader=load("res://shaders/city_facade.gdshader")
	roles.register_material(glass_a,"glass");roles.register_material(glass_b,"glass")
	roles.register_key(shader_glass,"map_facade")
	var native_values: Array=[glass_a.roughness,glass_a.metallic,glass_b.roughness,glass_b.metallic,shader_glass.get_shader_parameter("glass_roughness"),shader_glass.get_shader_parameter("glass_metallic")]
	diagnostics.setup(game)
	var per_material: Dictionary=diagnostics.snapshot()
	check("Untuned diverse glass is reported per-material without an invented shared value",per_material.tuning.has("glass_roughness") and per_material.tuning.glass_roughness==null and per_material.world.material_roles.roles.glass==3 and per_material.world.material_roles.covered_shader_count==1)
	var glass_tune: Dictionary=diagnostics.tune({"glass_roughness":.28,"glass_metallic":.61})
	check("Glass sliders update actual landmark and ordinary city shader resources",glass_tune.ok and is_equal_approx(glass_a.roughness,.28) and is_equal_approx(glass_b.roughness,.28) and is_equal_approx(float(shader_glass.get_shader_parameter("glass_roughness")),.28) and is_equal_approx(float(shader_glass.get_shader_parameter("glass_metallic")),.61))
	check("Glass role numerical tuning preserves structural material flags",glass_a.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and not glass_a.emission_enabled and glass_b.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED)
	var late_glass:=StandardMaterial3D.new();late_glass.roughness=.48;late_glass.metallic=.06
	var late_original:=Vector2(late_glass.roughness,late_glass.metallic)
	roles.register_material(late_glass,"glass")
	check("Newly registered materials adopt current shared numerical profile",is_equal_approx(late_glass.roughness,.28) and is_equal_approx(late_glass.metallic,.61))
	var glass_reset: Dictionary=diagnostics.reset_tuning()
	check("Glass reset restores distinct per-resource and raw shader defaults",glass_reset.ok and [glass_a.roughness,glass_a.metallic,glass_b.roughness,glass_b.metallic,shader_glass.get_shader_parameter("glass_roughness"),shader_glass.get_shader_parameter("glass_metallic")]==native_values)
	check("Late streamed-in glass also restores its authored values",Vector2(late_glass.roughness,late_glass.metallic)==late_original)
	check("Reset removes shared glass overrides from in-memory preferences",not game.settings.render_tuning.has("glass_roughness") and not game.settings.render_tuning.has("glass_metallic"))
	var panel=DiagnosticsPanel.new();root.add_child(panel);panel.setup(game,diagnostics)
	var transitions: Array=[]
	panel.toggled.connect(func(opened: bool): transitions.append(opened))
	check("Panel starts closed and does no background process",not panel.visible and not panel.is_processing())
	var old_pause: bool=paused
	var old_mouse: int=Input.mouse_mode
	panel.toggle()
	check("F3 panel exposes live state and notifies owner without taking pause ownership",panel.visible and panel.is_processing() and transitions==[true] and paused==old_pause and Input.mouse_mode==old_mouse)
	check("Disabled glow shows actual disabled status and cannot be edited by slider",not panel._sliders.glow_intensity.editable and panel._flags.text.contains("辉光 关"))
	check("Glass controls are enabled while visibly preserving per-material initial values",panel._sliders.glass_roughness.editable and panel._numbers.glass_roughness.text=="按各材质")
	panel._sliders.exposure.value=1.45
	check("Real slider callback updates Environment and displayed value",is_equal_approx(env.tonemap_exposure,1.45) and panel._numbers.exposure.text=="1.45")
	panel._reset()
	var after_panel_reset:=diagnostics.values()
	var same_original:=true
	for key in original:
		if after_panel_reset.get(key)!=original[key]: same_original=false
	check("Panel reset uses original production numerical preset",same_original and after_panel_reset.glass_roughness==null)
	panel.close()
	check("Close releases panel processing and emits owner hook",not panel.visible and not panel.is_processing() and transitions==[true,false] and paused==old_pause)
	var ui_validation=load("res://scripts/diagnostics_validation.gd").new();root.add_child(ui_validation)
	root.notify_mouse_entered();panel.toggle()
	var pointer_values:=diagnostics.values()
	var reset_button: Button=panel.find_child("DiagnosticsReset",true,false)
	var bottom_reached: bool=await ui_validation.reveal(reset_button)
	check("Real GUI wheel reaches reset without changing numerical settings",bottom_reached and diagnostics.values()==pointer_values)
	var close_button: Button=panel.find_child("DiagnosticsClose",true,false)
	var close_clicked: bool=await ui_validation.click(close_button)
	var scroll: ScrollContainer=panel._content.get_parent()
	check("Real GUI scroll and click can close the top button after visiting bottom controls",close_clicked and not panel.visible,{"click_injected":close_clicked,"button_rect":str(close_button.get_global_rect()),"scroll_rect":str(scroll.get_global_rect()),"scroll_vertical":scroll.scroll_vertical,"panel_visible":panel.visible})
	panel.close();ui_validation.queue_free()
	fixture_cycle(game,1.0,.6,1.2)
	var cycle_tune: Dictionary=diagnostics.tune({"exposure":1.5,"ambient":.9,"sun_energy":2.4})
	var ratios: Dictionary=env.get_meta("cycle_tuning_multipliers")
	check("Time-cycle tuning saves proportional overrides while applying requested absolute values",cycle_tune.ok and is_equal_approx(ratios.exposure,1.5) and is_equal_approx(ratios.ambient,1.5) and is_equal_approx(ratios.sun_energy,2.0) and is_equal_approx(env.tonemap_exposure,1.5))
	check("Time-cycle multipliers use separate in-memory preferences",game.settings.cycle_tuning==ratios and not game.settings.render_tuning.has("exposure") and not game.settings.render_tuning.has("sun_energy"))
	fixture_cycle(game,.8,.25,.3)
	check("Changed time-of-day baseline preserves the user's relative adjustment",is_equal_approx(env.tonemap_exposure,1.2) and is_equal_approx(env.ambient_light_energy,.375) and is_equal_approx(game.sun.light_energy,.6))
	diagnostics.reset_tuning()
	check("Cycle reset restores current time baseline instead of flashing old noon lighting",env.get_meta("cycle_tuning_multipliers").is_empty() and game.settings.cycle_tuning.is_empty() and is_equal_approx(env.tonemap_exposure,.8) and is_equal_approx(env.ambient_light_energy,.25) and is_equal_approx(game.sun.light_energy,.3))
	fixture_cycle(game,1.0,.04,0.0)
	var zero_sun: Dictionary=diagnostics.tune({"sun_energy":1.5})
	check("Zero night sun cannot silently create an invalid multiplier or artificial daylight",not zero_sun.ok and zero_sun.rejected.has("sun_energy") and game.sun.light_energy==0.0)
	panel._refresh()
	check("Nighttime zero-baseline slider explains why it cannot be changed",not panel._sliders.sun_energy.editable and panel._sliders.sun_energy.tooltip_text.contains("基础亮度为零"))
	game.settings.cycle_tuning={"sun_energy":2.0,"exposure":1.4,"ambient":INF,"unknown":5.0}
	var restored_cycle=Diagnostics.new();root.add_child(restored_cycle);restored_cycle.setup(game)
	check("Stored multipliers validate finite known values and survive a zero current baseline",env.get_meta("cycle_tuning_multipliers")=={"sun_energy":2.0,"exposure":1.4} and game.sun.light_energy==0 and is_equal_approx(env.tonemap_exposure,1.4))
	fixture_cycle(game,1.0,.6,1.1)
	check("Restored nighttime sun multiplier remains available at next sunrise",is_equal_approx(game.sun.light_energy,2.2))
	restored_cycle.reset_tuning();restored_cycle.queue_free()
	game.settings.erase("cycle_tuning")
	game.settings.render_tuning={"exposure":1.5,"glass_roughness":.31}
	var legacy_cycle=Diagnostics.new();root.add_child(legacy_cycle);legacy_cycle.setup(game)
	check("Legacy absolute tuning migrates to cycle ratios while preserving material settings",is_equal_approx(float(game.settings.cycle_tuning.exposure),1.5) and not game.settings.render_tuning.has("exposure") and is_equal_approx(float(game.settings.render_tuning.glass_roughness),.31) and is_equal_approx(glass_a.roughness,.31))
	legacy_cycle.reset_tuning();legacy_cycle.queue_free()
	diagnostics.inspector_tune_request={"exposure":1.25}
	diagnostics.apply_inspector_tuning=true
	check("Remote Inspector numerical request uses the same validated runtime API",diagnostics.inspector_tune_result.ok and is_equal_approx(env.tonemap_exposure,1.25) and not diagnostics.apply_inspector_tuning)
	diagnostics.refresh_inspector=true
	check("Remote Inspector snapshot exposes actual current owner values",diagnostics.inspector_snapshot.tuning.exposure==float(env.tonemap_exposure) and diagnostics.inspector_snapshot.world.resident_tiles==7 and not diagnostics.refresh_inspector)
	diagnostics.reset_inspector_tuning=true
	check("Remote Inspector reset restores current baseline safely",diagnostics.inspector_tune_result.ok and is_equal_approx(env.tonemap_exposure,1.0) and not diagnostics.reset_inspector_tuning)
	var daylight=load("res://scripts/daylight_environment.gd")
	game.environment.environment=daylight.make_environment()
	env=game.environment.environment
	game.settings.erase("cycle_tuning");game.settings.erase("render_tuning")
	var day: Dictionary={"sun_direction":Vector3(.4,.8,-.2).normalized(),"elevation_deg":48.0,"night_factor":0.0,"hour":12.0}
	var dusk: Dictionary={"sun_direction":Vector3(.9,.08,.25).normalized(),"elevation_deg":3.0,"night_factor":.15,"hour":18.0}
	var night: Dictionary={"sun_direction":Vector3(.8,-.5,.3).normalized(),"elevation_deg":-24.0,"night_factor":1.0,"hour":23.0}
	daylight.apply_cycle(env,game.sun,day)
	var production_diag=Diagnostics.new();root.add_child(production_diag);production_diag.setup(game)
	var production_base: Dictionary=env.get_meta("cycle_base_values")
	production_diag.tune({"exposure":1.3,"sun_energy":float(production_base.sun_energy)*1.4,"ambient":.9})
	daylight.apply_cycle(env,game.sun,dusk)
	var dusk_base: Dictionary=env.get_meta("cycle_base_values")
	check("Actual Daylight resource preserves Diagnostics multipliers at dusk",is_equal_approx(env.tonemap_exposure,float(dusk_base.exposure)*1.3) and is_equal_approx(env.ambient_light_energy,float(dusk_base.ambient)*(.9/float(production_base.ambient))) and is_equal_approx(game.sun.light_energy,float(dusk_base.sun_energy)*1.4))
	daylight.apply_cycle(env,game.sun,night)
	check("Actual Daylight night remains dark in direct sun despite retained multiplier",game.sun.light_energy==0 and env.get_meta("cycle_tuning_multipliers").sun_energy>1.3)
	production_diag.tune({"fog_light_energy":2.0})
	daylight.apply_cycle(env,game.sun,day)
	check("Actual Daylight transition clamps tuned fog energy to the shared slider range",env.fog_light_energy<=Diagnostics.NUMERIC.fog_light_energy.max and env.fog_light_energy>=0,{"fog_light_energy":env.fog_light_energy,"maximum":Diagnostics.NUMERIC.fog_light_energy.max})
	production_diag.reset_tuning()
	var daytime_base: Dictionary=env.get_meta("cycle_base_values")
	check("Actual Daylight reset restores current daylight profile",env.get_meta("cycle_tuning_multipliers").is_empty() and is_equal_approx(env.ambient_light_energy,float(daytime_base.ambient)) and is_equal_approx(game.sun.light_energy,float(daytime_base.sun_energy)))
	var actual_sun:=game.sun
	game.sun=null
	var ratios_before_missing: Dictionary=env.get_meta("cycle_tuning_multipliers").duplicate()
	var missing_sun_tune: Dictionary=production_diag.tune({"sun_energy":2.0})
	check("Rejected missing-sun tuning cannot silently change cycle metadata",not missing_sun_tune.ok and missing_sun_tune.applied.is_empty() and env.get_meta("cycle_tuning_multipliers")==ratios_before_missing)
	game.sun=actual_sun
	daylight.apply_cycle(env,game.sun,day)
	check("Reattached sun never receives a previously rejected adjustment",is_equal_approx(game.sun.light_energy,float(env.get_meta("cycle_base_values").sun_energy)))
	production_diag.queue_free()
	game.environment.environment=daylight.make_environment();env=game.environment.environment
	game.settings.cycle_tuning={"exposure":1.7,"ambient":1.25}
	game.settings.render_tuning={"exposure":2.8}
	var early_diag=Diagnostics.new();root.add_child(early_diag);early_diag.setup(game)
	daylight.apply_cycle(env,game.sun,dusk);early_diag.setup(game)
	check("Setup before initial daylight baseline preserves saved ratios over legacy absolute values",is_equal_approx(env.tonemap_exposure,1.7*float(env.get_meta("cycle_base_values").exposure)) and env.get_meta("cycle_tuning_multipliers")=={"exposure":1.7,"ambient":1.25})
	early_diag.queue_free()
	game.environment.environment=daylight.make_environment();env=game.environment.environment
	game.settings.cycle_tuning={"exposure":1.7};game.settings.render_tuning={}
	var early_reset=Diagnostics.new();root.add_child(early_reset);early_reset.setup(game)
	early_reset.reset_tuning();daylight.apply_cycle(env,game.sun,day)
	check("Reset before initial daylight cancels deferred ratios and their saved preferences",env.get_meta("cycle_tuning_multipliers").is_empty() and game.settings.cycle_tuning.is_empty() and is_equal_approx(env.tonemap_exposure,float(env.get_meta("cycle_base_values").exposure)))
	early_reset.queue_free()
	game.queue_free();await process_frame
	var freed: Dictionary=diagnostics.snapshot()
	check("Freed game owner is handled without stale references",not freed.world.available and freed.tuning.is_empty() and freed.player_position==null)
	var report: Dictionary={"passed":failures==0,"count":checks.size(),"failures":failures,"checks":checks,"gpu_used":false,"scope":"Isolated headless live Performance and Environment resource truth, optional owner data, clamps/rejection/reset/in-memory settings, exact heterogeneous landmark+city shader glass restore including late members, sun energy, time-cycle metadata contract, real production Daylight resource day/dusk/night/reset integration and actual Control slider callbacks; parent owns F3/aim/cursor, clock schedule and native appearance","engine":Engine.get_version_info().string,"diagnostics_sha256":FileAccess.get_sha256("res://scripts/runtime_diagnostics.gd"),"panel_sha256":FileAccess.get_sha256("res://scripts/diagnostics_panel.gd"),"ui_validation_sha256":FileAccess.get_sha256("res://scripts/diagnostics_validation.gd"),"roles_sha256":FileAccess.get_sha256("res://scripts/material_roles.gd"),"daylight_sha256":FileAccess.get_sha256("res://scripts/daylight_environment.gd"),"clock_sha256":FileAccess.get_sha256("res://scripts/city_clock.gd"),"test_sha256":FileAccess.get_sha256("res://../source/runtime_diagnostics_test.gd")}
	DirAccess.make_dir_recursive_absolute("res://../reports/runtime-diagnostics")
	var file:=FileAccess.open("res://../reports/runtime-diagnostics/checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("RUNTIME_DIAGNOSTICS_COMPLETE ",checks.size()," passed=",failures==0)
	quit(failures)
