extends "res://../source/render_environment_test.gd"
## Synthetic elevations test render integration only; city_clock tests astronomy.
func state(hour:float,elevation:float,bearing:float,night:float) -> Dictionary:
	var el:=deg_to_rad(elevation);var az:=deg_to_rad(bearing)
	return {"hour":hour,"elevation_deg":elevation,"sun_direction":Vector3(sin(az)*cos(el),sin(el),-cos(az)*cos(el)),"night_factor":night,"sunrise_hour":6.0372011581,"sunset_hour":19.9932813589}

func apply_now(env:Environment,light:DirectionalLight3D,data:Dictionary):
	env.set_meta("cycle_sky_tick_ms",-10000)
	Daylight.apply_cycle(env,light,data)

func cycle_capture(name:String):
	for index in 16:
		RenderingServer.force_draw(false)
		await process_frame
	var image:Image=root.get_texture().get_image()
	var path:="res://../reports/daylight-cycle/"+name+".png"
	var saved:=image.save_png(path)==OK
	var pixel_measurements:={}
	if name.ends_with("water-sky"):
		var count:=0;var clipped:=0;var sky_total:=0.0
		for y in range(0,int(image.get_height()*.45),4):
			for x in range(0,image.get_width(),4):
				var color:=image.get_pixel(x,y);count+=1;sky_total+=color.get_luminance()
				if minf(color.r,minf(color.g,color.b))>.98:clipped+=1
		pixel_measurements.sky_white_fraction=float(clipped)/maxi(1,count)
		pixel_measurements.sky_mean_srgb_luminance=sky_total/maxi(1,count)
		check("no broad white-clipped sky in "+name,pixel_measurements.sky_white_fraction<.10,pixel_measurements.duplicate())
		if name.begins_with("night"):
			var water_count:=0;var water_total:=0.0
			for y in range(int(image.get_height()*.62),int(image.get_height()*.9),4):
				for x in range(int(image.get_width()*.15),int(image.get_width()*.7),4):
					water_count+=1;water_total+=image.get_pixel(x,y).get_luminance()
			pixel_measurements.night_water_mean_srgb_luminance=water_total/maxi(1,water_count)
			check("night water has visible sky-light response",pixel_measurements.night_water_mean_srgb_luminance>.015,pixel_measurements.duplicate())
	pictures.append({"file":name+".png","sha256":FileAccess.get_sha256(path) if saved else "","parameters":Daylight.runtime_parameters(environment.environment),"base":environment.environment.get_meta("cycle_base_values",{}),"pixel_measurements":pixel_measurements})
	check("native time-of-day capture "+name,saved)

func run():
	DirAccess.make_dir_recursive_absolute("res://../reports/daylight-cycle")
	var env:=Daylight.make_environment();var light:=Daylight.make_sun()
	var day:=state(13.015,75,0,0);var dusk:=state(19.98,.1,248,0);var night:=state(23,-30,220,1)
	var toggles:=[env.ssao_enabled,env.glow_enabled,env.ssr_enabled,env.volumetric_fog_enabled]
	apply_now(env,light,day)
	check("clock direction controls actual sunlight",light.basis.z.dot(day.sun_direction)>.99999)
	check("day profile maintains readable daytime light",light.light_energy>1.0 and is_equal_approx(env.ambient_light_energy,.6))
	check("sky switches to incremental radiance updates",env.sky.process_mode==Sky.PROCESS_MODE_INCREMENTAL and env.sky.radiance_size==Sky.RADIANCE_SIZE_256)
	check("sky receives the same solar direction",env.sky.sky_material.get_shader_parameter("sun_direction").is_equal_approx(day.sun_direction))
	var initial_updates:int=env.get_meta("cycle_sky_updates")
	for index in 120:Daylight.apply_cycle(env,light,state(13.015+index*.00001,75,0,0))
	check("120 rapid clock calls do not rebuild120 sky cubes",int(env.get_meta("cycle_sky_updates"))==initial_updates)
	var manual:Dictionary=night.duplicate();manual.force_sky=true
	Daylight.apply_cycle(env,light,manual)
	check("paused time-menu jump forces immediate sky update",int(env.get_meta("cycle_sky_updates"))==initial_updates+1 and env.sky.sky_material.get_shader_parameter("night_weight")==1)
	Daylight.apply_cycle(env,light,manual)
	check("forced same-hour restore also refreshes sky",int(env.get_meta("cycle_sky_updates"))==initial_updates+2)
	apply_now(env,light,dusk)
	var sunset_color:=light.light_color
	check("sunset is dimmer and warmer than daylight",light.light_energy<.5 and sunset_color.r>sunset_color.b)
	check("sunset source dominates near horizon",env.sky.sky_material.get_shader_parameter("day_weight")<.01)
	check("sunset uses independent licensed panorama",env.sky.sky_material.get_shader_parameter("sunset_panorama")==Daylight.SUNSET_PANORAMA)
	apply_now(env,light,night)
	check("night has no below-horizon direct sun",light.light_energy==0)
	check("night panorama and blend are selected",env.sky.sky_material.get_shader_parameter("night_panorama")==Daylight.NIGHT_PANORAMA and env.sky.sky_material.get_shader_parameter("night_weight")==1)
	check("night keeps finite ambient and lower fog light",env.ambient_light_energy>.1 and env.fog_light_energy<.3)
	check("clock never toggles expensive effect flags",toggles==[env.ssao_enabled,env.glow_enabled,env.ssr_enabled,env.volumetric_fog_enabled])
	var base:Dictionary=env.get_meta("cycle_base_values")
	check("F3 base contract provides all seven controls",base.size()==7 and base.has("sun_energy") and base.has("fog_light_energy"))
	env.set_meta("cycle_tuning_multipliers",{"exposure":.8,"ambient":1.4,"sun_energy":1.2,"fog_density":.5,"glow_intensity":1.1,"ssao_intensity":.7})
	apply_now(env,light,day)
	base=env.get_meta("cycle_base_values")
	check("F3 multipliers survive changes of time",is_equal_approx(env.tonemap_exposure,float(base.exposure)*.8) and is_equal_approx(env.ambient_light_energy,float(base.ambient)*1.4) and is_equal_approx(light.light_energy,float(base.sun_energy)*1.2))
	Daylight.apply_tuning(env,{"tonemap_exposure":1.15})
	apply_now(env,light,night)
	check("legacy numeric tuning is rebased instead of overwritten",is_equal_approx(env.tonemap_exposure,1.18*1.15))
	check("a sun multiplier cannot create fake moonlight",light.light_energy==0)
	env.set_meta("cycle_tuning_multipliers",{"exposure":100,"ambient":100,"sun_energy":100,"fog_density":100000,"fog_light_energy":100})
	apply_now(env,light,day)
	check("cycle values honor final diagnostic safety limits",env.tonemap_exposure==3 and env.ambient_light_energy==2 and light.light_energy==4 and is_equal_approx(env.fog_density,.002) and env.fog_light_energy==2)
	var old_energy:float=light.light_energy
	Daylight.apply_cycle(env,light,{"sun_direction":Vector3(NAN,0,0)})
	check("nonfinite solar direction is ignored safely",light.light_energy==old_energy)
	check("sky shader does not force per-frame time filtering",not "TIME" in Daylight.SKY_SHADER.code and not "LIGHT0" in Daylight.SKY_SHADER.code)
	check("dawn and dusk share elevation-driven color profile",Daylight.cycle_profile(state(6.04,0,110,0)).sunset_tint==Daylight.cycle_profile(state(19.99,0,248,0)).sunset_tint)
	light.free()
	var capture_requested:bool="--capture" in OS.get_cmdline_user_args()
	if capture_requested:
		check("cycle captures require native renderer",DisplayServer.get_name()!="headless")
		if DisplayServer.get_name()!="headless":
			root.size=Vector2i(1440,900);RenderingServer.render_loop_enabled=false;make_scene()
			var material:=ShaderMaterial.new();material.shader=Water;material.set_shader_parameter("time_override",6.0);water.material_override=material
			Daylight.apply_quality(environment.environment,2)
			var phases:={"dawn":state(5.8,-5,110,.35),"sunrise":state(6.04,0,112,0),"day":day,"golden-hour":state(19.5,5,245,0),"pink-sunset":state(20.05,-2,248,.12),"night":night}
			for phase:String in phases:
				apply_now(environment.environment,sun,phases[phase])
				camera.position=Vector3(25,5,20);camera.look_at(Vector3(-35,6,40))
				await cycle_capture(phase+"-water-sky")
				camera.position=Vector3(18,5,1);camera.look_at(Vector3(0,4.5,-17))
				await cycle_capture(phase+"-colonnade")
	var passed:bool=checks.all(func(c):return c.passed)
	var report:={"passed":passed,"count":checks.size(),"checks":checks,"images":pictures,"native":capture_requested and DisplayServer.get_name()!="headless","scope":"Render-cycle property and fixed-camera calibration fixture. Synthetic solar inputs test the API; they do not validate Sydney astronomy, actual city night lamps or gameplay FPS.","hashes":{}}
	for path in ["res://scripts/daylight_environment.gd","res://assets/environment/daylight.gdshader","res://../source/daylight_cycle_test.gd"]:report.hashes[path]=FileAccess.get_sha256(path)
	FileAccess.open("res://../reports/daylight-cycle/"+("native.json" if capture_requested else "headless.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("DAYLIGHT_CYCLE_COMPLETE ",checks.size()," passed=",passed)
	quit(0 if passed else 1)
