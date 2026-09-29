extends "res://../source/facade_stream_test.gd"
## Profile and real facade-worker contracts. No iOS GPU / thermal claim.
const Settings = preload("res://scripts/game_settings.gd")
const Mobile = preload("res://scripts/mobile_profile.gd")
const Daylight = preload("res://scripts/daylight_environment.gd")

class ProfileGame extends Node3D:
	var camera: Camera3D
	var sun: DirectionalLight3D
	var environment: WorldEnvironment
	var world: Node3D

func check_saved_preferences(desktop: Dictionary, preview: Dictionary, phone: Dictionary) -> void:
	# Real save/reload operations, isolated from every player preference file.
	var folder := "user://qa_settings_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()]
	var created := DirAccess.make_dir_recursive_absolute(folder)
	verify("settings fixture has isolated storage",created==OK)
	if created != OK: return
	var desktop_choices := Settings.sanitized({"max_fps":144,"render_scale":.85,"window_mode":"borderless","volume":.8,"fov":84.0},desktop)
	verify("desktop preferences save successfully",Settings.save_preferences(desktop_choices,desktop,folder)==OK)
	var desktop_path := Settings.storage_path(desktop,folder)
	var desktop_before := FileAccess.get_file_as_bytes(desktop_path)
	var first_preview := Settings.load_preferences(preview,folder)
	verify("first mobile preview starts independently of desktop choices",not is_equal_approx(first_preview.volume,desktop_choices.volume) and first_preview.fov!=desktop_choices.fov)
	var mobile_choices := Settings.sanitized({"volume":.2,"fov":60.0,"render_scale":.5,"antialiasing":"off","large_text":true},preview)
	verify("mobile preview preferences save successfully",Settings.save_preferences(mobile_choices,preview,folder)==OK)
	verify("returning to desktop restores its display and sound choices unchanged",Settings.load_preferences(desktop,folder)==desktop_choices and FileAccess.get_file_as_bytes(desktop_path)==desktop_before)
	verify("reopening preview and native mobile restores mobile choices",Settings.load_preferences(preview,folder)==mobile_choices and Settings.load_preferences(phone,folder)==mobile_choices)
	var mobile_path := Settings.storage_path(preview,folder)
	var mobile_before := FileAccess.get_file_as_bytes(mobile_path)
	desktop_choices.volume=.95
	Settings.save_preferences(desktop_choices,desktop,folder)
	verify("later desktop edits preserve mobile sound and display choices",Settings.load_preferences(preview,folder)==mobile_choices and FileAccess.get_file_as_bytes(mobile_path)==mobile_before)
	var invalid_file := FileAccess.open(mobile_path,FileAccess.WRITE)
	invalid_file.store_string("[]");invalid_file.close()
	verify("unusable mobile preferences recover without importing desktop choices",Settings.load_preferences(preview,folder)==first_preview and Settings.load_preferences(desktop,folder)==desktop_choices)
	var actual_profile: Dictionary=Mobile._cached_current
	Mobile._cached_current=preview
	var launched_preview := Settings.load_preferences({},folder)
	Mobile._cached_current=desktop
	var launched_desktop := Settings.load_preferences({},folder)
	Mobile._cached_current=actual_profile
	verify("launch-selected persistence keeps preview and desktop separate",launched_preview==first_preview and launched_desktop==desktop_choices)
	DirAccess.remove_absolute(desktop_path)
	DirAccess.remove_absolute(mobile_path)
	DirAccess.remove_absolute(folder)

func run() -> void:
	var desktop := Mobile.detect("macOS",["desktop","arm64"],[],"MacBook Pro")
	var phone := Mobile.detect("iOS",["mobile","ios"],[],"iPhone17,2")
	var tablet := Mobile.detect("iOS",["mobile","ios"],[],"iPad13,8")
	var preview := Mobile.detect("macOS",["desktop"],["--mobile-preview"],"MacBook Pro")
	check_saved_preferences(desktop,preview,phone)
	verify("desktop platform stays desktop despite Apple silicon",not desktop.enabled and not desktop.preview)
	verify("actual iPhone and iPad select distinct scale budgets",phone.enabled and phone.native_mobile and not phone.tablet and tablet.tablet and phone.render_scale==.67 and tablet.render_scale==.75)
	verify("mobile export feature activates without relying on device name",Mobile.detect("Unknown",["mobile"],[],"").enabled)
	verify("Android uses the same conservative mobile defaults",Mobile.detect("Android",[],[],"").enabled)
	verify("desktop preview is explicit and does not claim native iOS",preview.enabled and preview.preview and not preview.native_mobile)
	var active_profile:=Mobile.current()
	var active_defaults:=Settings.defaults_for_platform()
	verify("no-argument platform API follows the actual launch flags",active_profile.preview==("--mobile-preview" in OS.get_cmdline_user_args()) and active_defaults.max_fps==(30 if active_profile.enabled else 0))
	verify("tablet preview requires the explicit mobile-preview switch",Mobile.detect("macOS",[],["--mobile-preview","--mobile-tablet"]).tablet and not Mobile.detect("macOS",[],["--mobile-tablet"]).enabled)
	verify("desktop defaults remain byte-for-byte equivalent dictionaries",Settings.defaults_for_platform(desktop)==Settings.DEFAULTS and Settings.sanitized({},desktop)==Settings.DEFAULTS)
	var copied: Dictionary=Settings.DEFAULTS.duplicate(true)
	copied.merge({"max_fps":240,"render_scale":1.0,"antialiasing":"taa","quality":2,"vsync":false,"window_mode":"windowed","street_life":2,"combat_difficulty":2,"bindings":{"map":[KEY_N]}},true)
	var before:=copied.duplicate(true)
	var bounded:=Settings.sanitized(copied,phone)
	verify("copied desktop high settings cannot bypass mobile budgets",bounded.max_fps==30 and bounded.render_scale==.67 and bounded.antialiasing=="msaa2" and bounded.quality==1 and bounded.vsync and bounded.window_mode=="fullscreen")
	verify("profile does not modify source preferences or gameplay settings",copied==before and bounded.street_life==2 and bounded.combat_difficulty==2 and bounded.bindings.map==[KEY_N])
	verify("desktop saved high-quality settings are preserved",Settings.sanitized(copied,desktop)==copied)
	verify("tablet default scale and mobile AA choices are bounded",Settings.defaults_for_platform(tablet).render_scale==.75 and Mobile.MOBILE_AA.map(func(row):return row[0])==["off","msaa2"])
	var low:=Settings.sanitized({"quality":0,"render_scale":.5,"antialiasing":"off"},phone)
	verify("players can select the lower-cost mobile options",low.quality==0 and low.render_scale==.5 and low.antialiasing=="off")
	var invalid:=Settings.sanitized({"max_fps":-1,"render_scale":NAN,"quality":"ultra","antialiasing":"fsr2","vsync":"no","fov":INF,"volume":NAN,"bindings":{"map":[INF],"jump":["x"]},"unknown":true},phone)
	verify("invalid config safely falls back before enforcing mobile limits",invalid.max_fps==30 and invalid.render_scale==.67 and invalid.quality==1 and invalid.antialiasing=="msaa2" and invalid.vsync and invalid.fov==68.0 and invalid.volume==.65 and invalid.bindings.is_empty() and not invalid.has("unknown"))
	var game:=ProfileGame.new();root.add_child(game)
	game.camera=Camera3D.new();game.camera.far=12000;game.add_child(game.camera)
	game.sun=Daylight.make_sun();game.add_child(game.sun)
	game.environment=WorldEnvironment.new();game.environment.environment=Daylight.make_environment();game.add_child(game.environment)
	var records:Array=[]
	for i in 30:records.append(record("way/%s"%(990030000+i),Vector2(16080+i*160,8080)))
	game.world=build_world(records)
	var stream=game.world.facade_stream
	var original_fps:=Engine.max_fps
	Engine.max_fps=0
	Settings.apply_display(copied,root,game.camera,false,desktop)
	verify("desktop QA keeps its frame pacing and requested native scale",Engine.max_fps==0 and root.scaling_3d_scale==1.0 and root.use_taa==(RenderingServer.get_current_rendering_method()=="forward_plus"))
	Settings.apply_display(copied,root,game.camera,false,phone)
	verify("30fps applies even when desktop window APIs are forbidden",Engine.max_fps==30)
	verify("display uses mobile bilinear scaling and rejects copied TAA",is_equal_approx(root.scaling_3d_scale,.67) and not root.use_taa and root.msaa_3d==Viewport.MSAA_2X and root.scaling_3d_mode==Viewport.SCALING_3D_MODE_BILINEAR)
	var env:=game.environment.environment
	var sky_id:=env.sky.get_instance_id()
	var source_count:int=game.world.structures.size()
	var light_before:=game.sun.directional_shadow_max_distance
	var desktop_result:=Mobile.apply_runtime(game,desktop)
	verify("desktop runtime does not alter sun, camera or streaming defaults",not desktop_result.enabled and game.sun.directional_shadow_max_distance==light_before and game.camera.far==12000 and stream.max_resident==64 and stream.load_radius==560 and stream.retain_radius==780)
	var report:=Mobile.apply_runtime(game,phone)
	verify("mobile runtime selects two cascades and shorter view distances",game.sun.directional_shadow_mode==DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and game.sun.directional_shadow_max_distance==120 and game.camera.far==6000)
	verify("unsupported effects and glow stay off with the same sky",not env.ssao_enabled and not env.ssr_enabled and not env.ssil_enabled and not env.sdfgi_enabled and not env.volumetric_fog_enabled and not env.glow_enabled and env.sky.get_instance_id()==sky_id and env.sky.radiance_size==Sky.RADIANCE_SIZE_128)
	verify("phone profile reaches the actual facade stream",stream.max_resident==16 and stream.load_radius==280 and stream.retain_radius==420 and stream.visible_distance==240)
	verify("QA reports actual renderer, limits and device-test uncertainty",report.engine_max_fps==30 and report.streaming.limit==16 and report.streaming.scope=="near_facade_only" and report.streaming.base_collision_resident and not report.device_performance_verified and not report.environment.ssao_enabled)
	var cells:Array[Vector2i]=[]
	for item:Dictionary in records:cells.append(cell_for(game.world,id_for(item)))
	var complete:=true
	for cell:Vector2i in cells.slice(0,16):
		stream.wanted.assign([cell]);stream._clock=1.0
		stream.tick(cell_point(cell),Vector3.ZERO,0.0)
		complete=complete and await finish_current(stream)
	verify("mobile limit contains 16 real uploaded facade meshes",complete and stream.resident.size()==16)
	var next:Vector2i=cells[16]
	stream.wanted.assign([next]);stream._clock=1.0;stream.tick(cell_point(next),Vector3.ZERO,0.0)
	complete=await finish_current(stream)
	verify("replacement reserves a slot before real worker upload",complete and stream.resident.size()==16 and stream.resident.has(next) and stream.evictions>0)
	var meshes:=0
	for cell:Vector2i in cells:
		meshes+=int(game.world._visual_cells[cell].detail.mesh!=null)
	verify("mesh and dictionary budgets agree without removing any base shells",meshes==16 and game.world.structures.size()==source_count and game.world._visual_cells[cells[0]].instance.mesh!=null and not collision(game.world,id_for(records[0])).disabled)
	Mobile.apply_runtime(game,tablet)
	verify("iPad profile has its own bounded facade and shadow settings",stream.max_resident==24 and stream.load_radius==320 and stream.visible_distance==280 and game.sun.directional_shadow_max_distance==160)
	stream.configure_budget(4,200,240,160)
	verify("shrinking a warm cache immediately evicts excess GPU meshes",stream.resident.size()==4 and stream.wanted.size()<=4)
	stream.configure_budget(999,INF,NAN,-100)
	verify("invalid streamer configuration clamps to safe finite limits",stream.max_resident==64 and stream.load_radius==560 and stream.retain_radius==780 and stream.visible_distance==80)
	stream.close()
	game.world.free();worlds.clear();game.free()
	Engine.max_fps=original_fps
	var folder:=ProjectSettings.globalize_path("res://../reports/mobile-profile")
	DirAccess.make_dir_recursive_absolute(folder)
	var result:={"passed":failures==0,"count":checks.size(),"failures":failures,"checks":checks,"profile_snapshot":report,"native_device_tested":false,"full_city_performance_tested":false,"real_facade_worker_tested":true,"renderer":RenderingServer.get_current_rendering_method(),"display_driver":DisplayServer.get_name()}
	FileAccess.open(folder+"/checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	FileAccess.open(folder+"/"+DisplayServer.get_name()+"-"+RenderingServer.get_current_rendering_method()+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("MOBILE_PROFILE_COMPLETE checks=",checks.size()," failures=",failures)
	quit(1 if failures else 0)
