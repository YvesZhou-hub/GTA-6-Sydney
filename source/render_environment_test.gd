extends SceneTree
## Small independent property checks and optional native fixed-camera A/B scene.
const Daylight = preload("res://scripts/daylight_environment.gd")
const Water = preload("res://shaders/water.gdshader")
var checks: Array[Dictionary] = []
var pictures: Array[Dictionary] = []
var scene: Node3D
var camera: Camera3D
var environment: WorldEnvironment
var water: MeshInstance3D
var sun: DirectionalLight3D

func _initialize(): call_deferred("run")
func check(title: String, passed: bool, detail: Dictionary = {}):
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("RENDER_ENVIRONMENT ","PASS " if passed else "FAIL ",title)

func make_material(color: Color, roughness: float = .7, metal: float = 0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color=color;material.roughness=roughness;material.metallic=metal
	return material

func box(at: Vector3, size: Vector3, material: Material):
	var instance := MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size
	instance.mesh=mesh;instance.material_override=material;instance.position=at;scene.add_child(instance)

func make_scene():
	scene=Node3D.new();root.add_child(scene)
	environment=WorldEnvironment.new();environment.environment=Daylight.make_environment();scene.add_child(environment)
	sun=Daylight.make_sun();scene.add_child(sun)
	camera=Camera3D.new();camera.near=.1;camera.far=1200;camera.fov=62;camera.current=true;scene.add_child(camera)
	water=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(300,220);plane.subdivide_width=100;plane.subdivide_depth=80
	water.mesh=plane;water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;scene.add_child(water)
	box(Vector3(0,-1,-49),Vector3(160,6,86),make_material(Color("bbae92")))
	box(Vector3(0,1.1,0),Vector3(10,2.2,27),make_material(Color("6d5a43")))
	for x in [-18,-9,0,9,18]:
		box(Vector3(x,5,-16),Vector3(1.1,6,1.1),make_material(Color("d5c7a9")))
	box(Vector3(0,8.4,-16),Vector3(39,1.1,8),make_material(Color("d5c7a9")))
	box(Vector3(0,5,-21),Vector3(39,6,.5),make_material(Color("433b33")))
	var colors: Array[Color] = [Color("a23632"),Color("cb9f42"),Color("366666"),Color("315788"),Color("cbb9a1")]
	for index in 5:
		box(Vector3(-15+index*7.5,5,-20.6),Vector3(5,4,.3),make_material(colors[index],.2 if index%2 else .7))
	for index in 4:
		var sphere:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=1.3;mesh.height=2.6
		sphere.mesh=mesh;sphere.position=Vector3(-11+index*7,3.3,-9)
		sphere.material_override=make_material(Color("b4b6bc"),.12+index*.22,1 if index==0 else 0)
		scene.add_child(sphere)
	var glow:=make_material(Color("df7528"));glow.emission_enabled=true;glow.emission=Color(1,.22,.025);glow.emission_energy_multiplier=5
	box(Vector3(0,5,8),Vector3(.8,.8,.8),glow)
	var lamp:=OmniLight3D.new();lamp.position=Vector3(0,5,8);lamp.light_color=Color("ffbb77");lamp.light_energy=4;lamp.light_volumetric_fog_energy=0;lamp.omni_range=12;scene.add_child(lamp)

func shot(name: String, eye: Vector3, target: Vector3):
	camera.position=eye;camera.look_at(target)
	for index in 12:
		RenderingServer.force_draw(false)
		await process_frame
	var image:Image=root.get_texture().get_image()
	var path:="res://../reports/render-environment/"+name+".png"
	var saved:=image.save_png(path)==OK
	pictures.append({"file":name+".png","sha256":FileAccess.get_sha256(path) if saved else "","eye":[eye.x,eye.y,eye.z],"target":[target.x,target.y,target.z],"resolution":[image.get_width(),image.get_height()],"parameters":Daylight.runtime_parameters(environment.environment)})
	check("native calibration image "+name,saved)

func run():
	DirAccess.make_dir_recursive_absolute("res://../reports/render-environment")
	var env:=Daylight.make_environment()
	check("CC0 panorama remains the source texture",env.sky.sky_material.get_shader_parameter("panorama")==Daylight.PANORAMA)
	check("explicit photograph mapping shader remains intact",env.sky.sky_material.shader==Daylight.SKY_SHADER)
	check("AgX keeps exposure fixed across profiles",env.tonemap_mode==Environment.TONE_MAPPER_AGX and env.tonemap_exposure==1)
	check("colour adjustment stays modest",is_equal_approx(env.adjustment_contrast,1.1) and is_equal_approx(env.adjustment_saturation,1.16))
	check("daylight ambient blends a warm neutral with the sky",is_equal_approx(env.ambient_light_sky_contribution,.55) and env.ambient_light_color==Color("d9cdb8"))
	check("glow only processes HDR highlights",env.glow_bloom==0 and env.glow_hdr_threshold>=1.5 and env.glow_intensity<.3)
	var sky_identity:=env.sky.get_instance_id()
	var renderer:=RenderingServer.get_current_rendering_method()
	for quality in 3:
		Daylight.apply_quality(env,quality)
		check("quality%d AO capability gate"%quality,env.ssao_enabled==(quality>0 and renderer=="forward_plus"))
		check("quality%d SSR reserved for fine Forward+"%quality,env.ssr_enabled==(quality==2 and renderer=="forward_plus"))
		check("quality%d glow and clear-air setting"%quality,env.glow_enabled==(quality>0) and not env.volumetric_fog_enabled)
	check("quality switches reuse sky and preserve exposure",env.sky.get_instance_id()==sky_identity and env.tonemap_exposure==1)
	Daylight.apply_quality(env,2,{"volumetric_fog":true})
	check("mist requires explicit high-quality Forward+ opt-in",env.volumetric_fog_enabled==(renderer=="forward_plus"))
	Daylight.apply_quality(env,0)
	check("lower profile clears expensive effects",not env.ssao_enabled and not env.ssr_enabled and not env.volumetric_fog_enabled and not env.glow_enabled)
	var altered:=Daylight.apply_tuning(env,{"tonemap_exposure":100,"glow_intensity":-1,"ssr_max_steps":999,"fog_density":NAN,"not_an_option":5})
	check("numeric diagnostics clamp known safe ranges",altered.size()==3 and env.tonemap_exposure==1.5 and env.glow_intensity==0 and env.ssr_max_steps==96)
	check("runtime snapshot exposes actual toggles",Daylight.runtime_parameters(env).has("ssr_enabled") and Daylight.runtime_parameters(env).has("base_roughness")==false)
	var light:=Daylight.make_sun()
	var bearing:float=(Daylight.SUN_UV.x-.5)*TAU;var polar:float=Daylight.SUN_UV.y*PI
	var direction:=Vector3(sin(bearing)*sin(polar),cos(polar),-cos(bearing)*sin(polar))
	check("sun still matches unchanged HDR solar core",light.basis.z.dot(direction)>.999999)
	light.free()
	var source:=Water.code
	check("water stays opaque for depth and SSR",not "ALPHA =" in source and not "depth_draw_never" in source)
	check("water uses dielectric material", "METALLIC = 0.0" in source)
	check("small-wave normal has pixel-footprint filtering", "fwidth(a)" in source and "fwidth(b)" in source and "fwidth(c)" in source)
	check("world-space phase preserves neighbouring tile continuity", "(MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz" in source and "world_pos = p" in source)
	check("both real metro dry rectangles remain", "p.x > dry_rect_a.x" in source and "p.x > dry_rect_b.x" in source and "discard" in source)
	check("original total wave amplitude stays455mm", "sin(a) * 0.27 + sin(b) * 0.13 + sin(c) * 0.055" in source)
	for key in ["normal_strength","ripple_strength","base_roughness","specular_strength","time_override"]:
		check("water exposes numeric diagnostic uniform "+key,"uniform float "+key in source)
	var capture_requested:bool="--capture" in OS.get_cmdline_user_args()
	if capture_requested:
		check("capture requires actual native renderer",DisplayServer.get_name()!="headless")
		if DisplayServer.get_name()!="headless":
			root.size=Vector2i(1440,900);RenderingServer.render_loop_enabled=false;make_scene()
			var old_env:Script=load("res://../reports/render-environment/baseline_environment.gd")
			var old_water:=Shader.new();old_water.code=FileAccess.get_file_as_string("res://../reports/render-environment/baseline_water.gdshader").replace("TIME","6.0")
			for variant in ["baseline","standard","fine","optional-mist"]:
				environment.environment=old_env.make_environment() if variant=="baseline" else Daylight.make_environment()
				if variant!="baseline":Daylight.apply_quality(environment.environment,1 if variant=="standard" else 2,{"volumetric_fog":variant=="optional-mist"})
				var material:=ShaderMaterial.new();material.shader=old_water if variant=="baseline" else Water
				if variant!="baseline":material.set_shader_parameter("time_override",6.0)
				water.material_override=material
				await shot(variant+"-water",Vector3(28,9,36),Vector3(0,3,-14))
				await shot(variant+"-colonnade",Vector3(18,5,1),Vector3(0,4.5,-17))
	var passed:=checks.all(func(c):return c.passed)
	var hashes:={}
	for path in ["res://scripts/daylight_environment.gd","res://shaders/water.gdshader","res://../source/render_environment_test.gd"]:hashes[path]=FileAccess.get_sha256(path)
	var report:={"passed":passed,"count":checks.size(),"checks":checks,"images":pictures,"source_sha256":hashes,"renderer":renderer,"native_capture_requested":capture_requested,"scope":"Small calibration scene and property/source contracts. Headless cannot prove compiled GPU shader appearance, reflection correctness, shimmer or final city performance."}
	FileAccess.open("res://../reports/render-environment/"+("native.json" if capture_requested else "headless.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RENDER_ENVIRONMENT_COMPLETE ",checks.size()," passed=",passed)
	quit(0 if passed else 1)
