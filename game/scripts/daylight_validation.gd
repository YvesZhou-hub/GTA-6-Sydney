extends Node
## Explicitly started by main's internal --daylight-qa entry. No automatic _ready.
## Production city and clock; fixed camera images are not a performance test.
const Daylight = preload("res://scripts/daylight_environment.gd")
const ICC = preload("res://scripts/icc_landmarks.gd")
const HARBOUR_EYE := Vector3(1000,85,-720)
const HARBOUR_TARGET := Vector3(180,28,-530)
const FACADE_PATHS := ["res://shaders/city_facade.gdshader","res://assets/world_facade.gdshader"]
var game
var native := false
var checks:Array[Dictionary] = []
var screenshots:Array[Dictionary] = []
var phases:Array[Dictionary] = []
var sky_assets:Array[Dictionary] = []
var started := false

func check(title:String,passed:bool,detail:Dictionary={}):
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("DAYLIGHT_QA ","PASS " if passed else "FAIL ",title)

func vector(value:Vector3) -> Array: return [value.x,value.y,value.z]

func bytes_sha(data:PackedByteArray) -> String:
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()

func available_file_sha(path:String) -> String:
	# Imported texture originals may be omitted from a PCK; report that honestly.
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""

func facade_parameters() -> Dictionary:
	var records:Array[Dictionary]=[]
	var total:=0
	for entry:Dictionary in game.world.material_roles._members.values():
		var material:Material=entry.weak.get_ref()
		if not material is ShaderMaterial or material.shader==null:continue
		if material.shader.resource_path not in FACADE_PATHS:continue
		total+=1
		if records.size()>=8:continue
		records.append({"shader":material.shader.resource_path,
			"night_uniform_declared":"global uniform float city_night_amount;" in material.shader.code,
			"emission_uses_night_amount":"EMISSION = night_radiance" in material.shader.code and "city_night_amount)" in material.shader.code,
			"raw_uniform_overrides":{"glazing":material.get_shader_parameter("glazing"),"floor_height":material.get_shader_parameter("floor_height"),"bay_width":material.get_shader_parameter("bay_width"),"lit_windows":material.get_shader_parameter("lit_windows")}})
	return {"registered_facade_materials":total,"sample":records,
		"night_global_name":"city_night_amount","clock_expected_value":game.city_clock.solar_state().night_factor,
		"clock_write":game.city_clock.get_meta("night_window_write",{}).duplicate(true),
		"global_gpu_readback":false,"scope":"Actual registered production materials and CPU metadata written immediately after the production RenderingServer submission. This is a submission witness, not GPU global-uniform readback; pixel appearance requires the native CBD image."}

func valid_night_write(write:Dictionary,state:Dictionary,previous_sequence:int=-1,current_frame:bool=false) -> bool:
	# Exported scripts can be compiled in PCKs: source text availability is not
	# evidence that the running clock actually submitted the uniform this phase.
	# Clock records this witness immediately AFTER its RenderingServer write.
	if write.get("name","")!="city_night_amount":return false
	for key:String in ["value","hour","frame","sequence"]:
		if not (write.get(key) is float or write.get(key) is int):return false
		if not is_finite(float(write[key])):return false
	if int(write.sequence)<=maxi(0,previous_sequence):return false
	if int(write.frame)<0 or int(write.frame)>Engine.get_process_frames():return false
	if current_frame and int(write.frame)!=Engine.get_process_frames():return false
	return is_equal_approx(float(write.value),float(state.night_factor)) and is_equal_approx(float(write.hour),float(state.hour))

func read_sky_assets():
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/sky_sources.json"))
	var material:ShaderMaterial=game.environment.environment.sky.sky_material
	for binding:String in ["panorama","sunset_panorama","night_panorama"]:
		var texture:Texture2D=material.get_shader_parameter(binding)
		var record:Dictionary={"binding":binding,"resource_path":texture.resource_path if texture!=null else "","declared_source_sha256":""}
		if texture!=null:
			for source:Dictionary in manifest.assets:
				if texture.resource_path.ends_with(source.file):record.declared_source_sha256=source.sha256
			record.source_file_sha256=available_file_sha(texture.resource_path)
			record.width=texture.get_width();record.height=texture.get_height()
			if native:
				var pixels:Image=texture.get_image()
				record.loaded_pixel_format=pixels.get_format()
				record.loaded_pixels_sha256=bytes_sha(pixels.get_data())
		check("licensed source sky bound "+binding,texture!=null and texture.get_width()==2048 and texture.get_height()==1024 and not record.declared_source_sha256.is_empty())
		sky_assets.append(record)

func select_time(preset:String) -> Dictionary:
	var clock=game.city_clock
	var env:Environment=game.environment.environment
	var previous_updates:int=env.get_meta("cycle_sky_updates",0)
	var previous_write:int=int(clock.get_meta("night_window_write",{}).get("sequence",0))
	clock.jump(preset)
	var state:Dictionary=clock.solar_state()
	var write:Dictionary=clock.get_meta("night_window_write",{}).duplicate(true)
	check("clock submits fresh matching night-window parameter for "+preset,valid_night_write(write,state,previous_write,true),{"write":write,"expected_value":state.night_factor,"expected_hour":state.hour,"previous_sequence":previous_write,"observed_frame":Engine.get_process_frames(),"gpu_readback":false})
	var direction:Vector3=state.sun_direction
	var sky_material:ShaderMaterial=env.sky.sky_material
	check("real clock immediately updates sky for "+preset,int(env.get_meta("cycle_sky_updates",0))>previous_updates and is_equal_approx(float(env.get_meta("cycle_sky_hour",-1)),clock.hour))
	check("solar light and rendered disc share direction for "+preset,game.sun.basis.z.dot(direction)>.99999 and sky_material.get_shader_parameter("sun_direction").is_equal_approx(direction))
	check("night blend follows real summer elevation for "+preset,is_equal_approx(float(sky_material.get_shader_parameter("night_weight")),float(state.night_factor)))
	var record:Dictionary={"preset":preset,"clock":clock.get_state(),"display_time":clock.display_time(),
		"solar_direction":vector(direction),"elevation_deg":state.elevation_deg,"night_factor":state.night_factor,
		"sunrise_hour":state.sunrise_hour,"sunset_hour":state.sunset_hour,
		"actual_sun_direction":vector(game.sun.basis.z),"actual_sun_energy":game.sun.light_energy,
		"actual_sun_color":[game.sun.light_color.r,game.sun.light_color.g,game.sun.light_color.b],
		"sky_material_sha256":bytes_sha(sky_material.shader.code.to_utf8_buffer()),
		"cycle_base_values":env.get_meta("cycle_base_values",{}),"runtime_parameters":Daylight.runtime_parameters(env),
		"night_window_expected_value":state.night_factor,"night_window_write":write}
	phases.append(record)
	return record

func capture(name:String,eye:Vector3,target:Vector3,preset:String):
	if not native:return
	game.camera.global_position=eye
	game.camera.look_at(target)
	game.camera.reset_physics_interpolation()
	check("production facade stream ready for "+name,await game.world.prepare_view(eye))
	for index in 16:
		RenderingServer.force_draw(false)
		await get_tree().process_frame
	var picture:Image=get_tree().root.get_texture().get_image()
	var path:="user://daylight-qa/"+name+".png"
	var saved:=picture.save_png(path)==OK
	var values:=facade_parameters()
	screenshots.append({"file":name+".png","saved":saved,"sha256":FileAccess.get_sha256(path) if saved else "",
		"camera":vector(eye),"target":vector(target),"fov":game.camera.fov,
		"resolution":[picture.get_width(),picture.get_height()],"preset":preset,
		"clock":game.city_clock.get_state(),"sky_material_sha256":bytes_sha(game.environment.environment.sky.sky_material.shader.code.to_utf8_buffer()),
		"facade_stream":game.world.streaming_stats(),"night_windows":values,"public_lighting":game.public_lighting.snapshot() if is_instance_valid(game.public_lighting) else {}})
	check("native production image "+name,saved)

func run(main:Node3D):
	if started:return
	started=true;game=main;native=DisplayServer.get_name()!="headless"
	process_mode=Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute("user://daylight-qa")
	check("internal QA guard precedes isolated world setup",game.qa_running)
	if not game.qa_running:await finish();return
	game.active=false # new_world cannot autosave a previous player slot.
	game.new_world("sandbox","Daylight QA isolated unsaved world",false)
	game.world_id="qa_daylight_unsaved"
	game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
	game.player.enabled=false;game.player.visible=false;game.player.velocity=Vector3.ZERO
	game.canvas.hide()
	game.city_clock.running=false;game.city_clock.set_process(false)
	game.life.set_process(false)
	if is_instance_valid(game.life._marker):game.life._marker.hide()
	if is_instance_valid(game.weapons):game.weapons.clear();game.weapons.set_physics_process(false)
	for vehicle in game.vehicles:
		vehicle.freeze=true;vehicle.linear_velocity=Vector3.ZERO;vehicle.angular_velocity=Vector3.ZERO
		vehicle.set_physics_process(false)
	game.camera.fov=64;game.camera.current=true
	await get_tree().physics_frame;await get_tree().physics_frame
	check("complete production city and real summer clock ready",game.world._ready_complete and not game.city_clock.baseline.is_empty())
	if not game.world._ready_complete:await finish();return
	check("native renderer required for final App visual validation",native)
	if native:RenderingServer.render_loop_enabled=false
	read_sky_assets()
	var facade:Dictionary=facade_parameters()
	var declaration:Dictionary=ProjectSettings.get_setting("shader_globals/city_night_amount",{})
	check("real city facades use clock driven night-window parameter",facade.registered_facade_materials>0 and facade.sample.all(func(row):return row.night_uniform_declared and row.emission_uses_night_amount) and declaration.get("type","")=="float" and valid_night_write(facade.clock_write,game.city_clock.solar_state()),{"facades":facade,"global_declaration":declaration})
	for preset:String in ["sunrise","noon","golden","sunset","night"]:
		var state:=select_time(preset)
		if preset in ["sunrise","sunset"]:
			check("apparent summer horizon for "+preset,absf(state.elevation_deg+.833)<.0001 and state.solar_direction[2]>0 and (state.solar_direction[0]>0 if preset=="sunrise" else state.solar_direction[0]<0))
		elif preset=="noon":
			check("summer solar noon is high in the north",state.elevation_deg>70 and state.solar_direction[2]<0 and absf(state.solar_direction[0])<.0001 and state.actual_sun_energy>0)
		elif preset=="golden":
			check("golden hour is before actual summer sunset",state.elevation_deg>0 and state.clock.hour<state.sunset_hour and state.solar_direction[0]<0)
		elif preset=="night":
			check("night has zero direct sunlight and enabled window blend",state.elevation_deg<0 and state.actual_sun_energy==0 and state.night_factor>.99)
		await capture("harbour-"+preset,HARBOUR_EYE,HARBOUR_TARGET,preset)
	await capture("cbd-george-street-night",Vector3(-329.08,8,1090),Vector3(-329.08,12,980),"night")
	var foyer:Array=[]
	for view:Array in ICC.capture_views():
		if view[0]=="icc-theatre-red-foyer":foyer=view
	check("actual public ICC foyer viewpoint is available",foyer.size()==3 and game.world.has_meta("icc_landmarks"))
	check("public lighting module provides bounded active night lights",is_instance_valid(game.public_lighting) and game.public_lighting.snapshot().count>0 and game.public_lighting.snapshot().count<=40 and game.public_lighting.snapshot().total_energy>0)
	check("ICC foyer has separate non-emissive tiled finish without geometry change",game.world.materials.get("icc_theatre_floor") is ShaderMaterial and not game.world.get_meta("icc_theatre_floor_finish",{}).get("geometry_changed",true))
	if foyer.size()==3:await capture("icc-public-foyer-night",foyer[1],foyer[2],"night")
	check("clock remains frozen during camera and streaming waits",is_equal_approx(game.city_clock.hour,22.0) and not game.city_clock.running)
	check("all seven final city images exist",native and screenshots.size()==7 and screenshots.all(func(item):return item.saved))
	await finish()

func finish():
	var passed:=checks.all(func(item):return item.passed)
	var hashes:={}
	for path:String in ["res://scripts/daylight_validation.gd","res://scripts/public_lighting.gd","res://scripts/icc_landmarks.gd","res://scripts/daylight_environment.gd","res://scripts/city_clock.gd","res://assets/environment/daylight.gdshader","res://shaders/water.gdshader","res://assets/sydney_summer.json","res://assets/environment/sky_sources.json"]+FACADE_PATHS:
		hashes[path]=available_file_sha(path)
	var report:={"passed":passed,"count":checks.size(),"checks":checks,"screenshots":screenshots,"phases":phases,
		"sky_assets":sky_assets,"source_sha256":hashes,"native":native,"user_saves_touched":false,"save_written":false,
		"world_ready":game.world._ready_complete,"astronomy_inputs":"Actual production city_clock.jump presets and bundled Sydney average-summer baseline; no synthetic solar vectors.",
		"night_window_validation":"Five fresh CPU submission witnesses recorded by city_clock immediately after RenderingServer.global_shader_parameter_set, matched to actual solar_state, current frame and increasing sequence; registered material declarations/emission connection also checked. Not GPU uniform readback.",
		"scope":"Complete main, real city and public ICC foyer, frozen actors and identical harbour camera. Native fixed-frame visual review, not gameplay FPS, real-time weather, GPU global-uniform readback or measured indoor lighting compliance."}
	FileAccess.open("user://daylight-qa/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("DAYLIGHT_QA_COMPLETE ",checks.size()," passed=",passed)
	game.active=false
	game.finish_quit(0 if passed else 1)
