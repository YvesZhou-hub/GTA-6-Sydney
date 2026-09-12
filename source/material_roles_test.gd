extends SceneTree
const Roles=preload("res://scripts/material_roles.gd")
var checks:Array=[]
var failures:=0
func _initialize():call_deferred("run")
func verify(name:String,passed:bool,evidence:Dictionary={}) -> void:
	checks.append({"name":name,"passed":passed,"evidence":evidence})
	print("PASS " if passed else "FAIL ",name," ",JSON.stringify(evidence))
	if not passed:failures+=1
func appearance(m:StandardMaterial3D) -> Dictionary:
	return {"albedo":m.albedo_color,"emission":m.emission,"texture":m.albedo_texture,"normal_texture":m.normal_texture,"transparency":m.transparency,"cull":m.cull_mode,"depth":m.depth_draw_mode,"triplanar":m.uv1_triplanar,"uvscale":m.uv1_scale,"normal":m.normal_enabled,"emission_enabled":m.emission_enabled,"specular":m.metallic_specular,"shading":m.shading_mode}
func run() -> void:
	var registry:=Roles.new();var a:=StandardMaterial3D.new();var b:=StandardMaterial3D.new()
	a.albedo_color=Color(.43,.61,.66,.27);a.roughness=.23;a.metallic=.04;a.emission=Color("a77f62");a.metallic_specular=.35
	a.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;a.cull_mode=BaseMaterial3D.CULL_DISABLED;a.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
	a.uv1_triplanar=true;a.uv1_scale=Vector3(.2,.3,.4);a.normal_enabled=true
	var tex:=GradientTexture2D.new();tex.gradient=Gradient.new();a.albedo_texture=tex;a.normal_texture=tex
	b.albedo_color=Color("314a57");b.roughness=.45;b.metallic=.12
	var reference:=MeshInstance3D.new();reference.material_override=a;var second_reference:=MeshInstance3D.new();second_reference.material_override=a
	var original_id:=a.get_instance_id();var before:=appearance(a)
	verify("registration preserves authored numeric values and actual resource identity",registry.register_material(a,"glass") and registry.register_key(b,"manly_glass") and is_equal_approx(a.roughness,.23) and is_equal_approx(b.roughness,.45) and a.get_instance_id()==original_id)
	verify("same resource is registered once despite many users",registry.register_material(a,"glass") and registry.stats().resources==2)
	var updated:Dictionary=registry.set_role("glass",{"roughness":.17,"metallic":.08})
	verify("one role update changes two distinct glass resources in place",updated.updated==2 and is_equal_approx(a.roughness,.17) and is_equal_approx(b.roughness,.17) and reference.material_override==a and second_reference.material_override==a and a.get_instance_id()==original_id)
	verify("role changes preserve colour alpha texture UV specular and shader flags",appearance(a)==before)
	verify("identical tuning is an idempotent no-op",registry.set_role("glass",{"roughness":.17,"metallic":.08}).updated==0)
	var later:=StandardMaterial3D.new();registry.register_material(later,"glass")
	verify("newly registered existing material inherits active numeric role overrides",is_equal_approx(later.roughness,.17) and is_equal_approx(later.metallic,.08))
	var limits:Dictionary=registry.set_role("glass",{"metallic":8,"roughness":-4})
	verify("metallic and roughness clamp to valid unit range",a.metallic==1 and a.roughness==0 and limits.clamped.size()==2)
	var ignored:Dictionary=registry.set_role("glass",{"albedo_color":Color.RED,"transparency":0,"normal_enabled":false,"emission_enabled":true,"albedo_texture":null,"energy":8,"roughness":NAN,"metallic":"0.5"})
	verify("non-numeric nonfinite forbidden and non-light energy inputs are ignored",ignored.ignored.size()==8 and appearance(a)==before and a.metallic==1 and a.roughness==0)
	verify("booleans and infinity cannot masquerade as numeric material properties",registry.set_role("glass",{"roughness":true,"metallic":INF}).ignored.size()==2 and a.metallic==1 and a.roughness==0)
	var unknown:=StandardMaterial3D.new();var unknown_before:=unknown.roughness
	verify("unknown role neither registers nor changes material",not registry.register_material(unknown,"surprise") and not registry.set_role("surprise",{"roughness":.5}).ok and unknown.roughness==unknown_before)
	verify("conflicting semantic ownership of same resource is rejected",not registry.register_material(a,"stone") and registry.stats().roles.glass==3 and registry.stats().roles.stone==0)
	var shader:=ShaderMaterial.new();var source:=Shader.new();source.code="shader_type spatial;void fragment(){ROUGHNESS=.7;}";shader.shader=source
	verify("custom shaders and null resources are explicitly unsupported",not registry.register_material(shader,"glass") and not registry.register_material(null,"stone") and shader.shader==source)
	var light:=StandardMaterial3D.new();light.albedo_color=Color("ffd89a");light.emission=Color("dabb7e");var emission_color:=light.emission
	verify("light feature may initialize once at explicit material creation",registry.register_material(light,"light",true) and light.emission_enabled)
	registry.set_role("light",{"energy":32,"roughness":.3});light.emission_enabled=false;registry.register_material(light,"light",true)
	verify("light runtime tuning clamps energy and never re-enables feature flags",light.emission_energy_multiplier==16 and light.emission==emission_color and not light.emission_enabled)
	registry.set_role("light",{"emission_energy_multiplier":-3})
	verify("energy zero does not switch the emission shader feature",light.emission_energy_multiplier==0 and not light.emission_enabled)
	var adopted:=StandardMaterial3D.new();registry.register_material(adopted,"light")
	verify("registering an existing light without creation flag leaves emission disabled",not adopted.emission_enabled)
	var metal:=StandardMaterial3D.new();registry.register_material(metal,"vertical_fins");registry.set_role("metal",{"metallic":.62})
	verify("vertical fins and steel aliases share the metal role",is_equal_approx(metal.metallic,.62) and Roles.canonical_role(" STEEL ")=="metal")
	verify("source-reviewed colour exceptions classify by substance",Roles.classify_key("qvb_green")=="glass" and Roles.classify_key("qvb_amber")=="glass" and Roles.classify_key("qvb_trim")=="stone" and Roles.classify_key("quay_green")=="vegetation" and Roles.classify_key("city_exchange_wood_light")=="wood")
	verify("ambiguous or custom shader keys do not silently become glass or metal",Roles.classify_key("city_tower_one_perforated").is_empty() and Roles.classify_key("dp_water").is_empty() and Roles.classify_key("new_unreviewed_glass").is_empty())
	verify("dynamic OSM roof colours retain separate roof classification",Roles.classify_key("mapped_roof_#ad4136")=="roof")
	var stats:Dictionary=registry.stats();stats.current_overrides.glass.roughness=.99
	verify("stats exposes actual role counts and isolated override snapshots",stats.roles.glass==3 and stats.roles.metal==1 and stats.roles.light==2 and registry.stats().current_overrides.glass.roughness==0)
	var temporary:=StandardMaterial3D.new();registry.register_material(temporary,"stone");var weak:WeakRef=weakref(temporary);temporary=null
	verify("registry weak references do not keep released materials alive",weak.get_ref()==null and registry.stats().roles.stone==0)
	registry.unregister_material(b);registry.set_role("glass",{"roughness":.42})
	verify("unregister detaches future role updates without cloning or clearing material",is_equal_approx(a.roughness,.42) and b.roughness==0 and registry.stats().roles.glass==2)
	registry.clear();verify("world reset clears membership and overrides",registry.stats().resources==0 and registry.stats().current_overrides.is_empty())
	reference.free();second_reference.free()
	snapshot_shader_checks()
	var report:={"passed":failures==0,"count":checks.size(),"failures":failures,"checks":checks,"scope":"Bounded StandardMaterial3D and exact-path ShaderMaterial resource tests; no GPU or full city","hashes":{}}
	for path in ["res://scripts/material_roles.gd","res://shaders/city_facade.gdshader","res://assets/world_facade.gdshader","res://../source/material_roles_test.gd"]:report.hashes[path]=FileAccess.get_sha256(path)
	var folder:=ProjectSettings.globalize_path("res://../reports/material-roles");DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder+"/checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MATERIAL_ROLES_COMPLETE checks=",checks.size()," failures=",failures);quit(1 if failures else 0)

func snapshot_shader_checks() -> void:
	var registry:=Roles.new();var a:=StandardMaterial3D.new();var b:=StandardMaterial3D.new()
	a.roughness=.13;a.metallic=.03;b.roughness=.67;b.metallic=.61
	registry.register_material(a,"glass");registry.register_material(b,"glass")
	var original:Dictionary=registry.snapshot_role("glass")
	registry.set_role("glass",{"roughness":.44,"metallic":.1})
	var restored:Dictionary=registry.restore_role("glass",original)
	verify("snapshot restores each material exact original roughness and metallic",restored.ok and restored.restored==2 and a.roughness==original.materials[a.get_instance_id()].roughness and b.roughness==original.materials[b.get_instance_id()].roughness and a.metallic==original.materials[a.get_instance_id()].metallic and b.metallic==original.materials[b.get_instance_id()].metallic)
	verify("restoring an absent profile removes temporary overrides",not registry.stats().current_overrides.has("glass"))
	registry.set_role("glass",{"metallic":.21});var tuned:Dictionary=registry.snapshot_role("glass")
	registry.set_role("glass",{"roughness":.77,"metallic":.8})
	var late:=StandardMaterial3D.new();late.roughness=.44;late.metallic=.06;var late_roughness:=late.roughness;registry.register_material(late,"glass")
	restored=registry.restore_role("glass",tuned)
	verify("snapshot restores prior role profile as well as per-material values",registry.stats().current_overrides.glass==tuned.profile and a.roughness==tuned.materials[a.get_instance_id()].roughness and b.roughness==tuned.materials[b.get_instance_id()].roughness)
	verify("materials registered during preview restore authored baseline and prior profile",restored.late_members==1 and late.roughness==late_roughness and is_equal_approx(late.metallic,.21))
	var wrong:=Roles.new()
	verify("unknown wrong-role and foreign-registry snapshots fail without mutation",not registry.snapshot_role("unknown").ok and not registry.restore_role("stone",tuned).ok and not wrong.restore_role("glass",tuned).ok and is_equal_approx(a.metallic,.21))
	var malformed:Dictionary=tuned.duplicate(true);malformed.materials[a.get_instance_id()].roughness="bad"
	verify("malformed snapshot rejects atomically without changing values or profile",not registry.restore_role("glass",malformed).ok and registry.stats().current_overrides.glass==tuned.profile and a.roughness==tuned.materials[a.get_instance_id()].roughness)
	var removed:=StandardMaterial3D.new();registry.register_material(removed,"glass");var released:Dictionary=registry.snapshot_role("glass");var weak:WeakRef=weakref(removed);removed=null
	verify("snapshots do not retain released materials and restore skips them",weak.get_ref()==null and registry.restore_role("glass",released).skipped==1)
	registry.clear();registry.register_material(a,"glass")
	verify("snapshot from before registry clear is rejected",not registry.restore_role("glass",tuned).ok)
	var shader_registry:=Roles.new();var city:=ShaderMaterial.new();var world:=ShaderMaterial.new()
	city.shader=load("res://shaders/city_facade.gdshader");world.shader=load("res://assets/world_facade.gdshader")
	city.set_shader_parameter("wall_color",Color("934b3e"));city.set_shader_parameter("glazing",.72)
	world.set_shader_parameter("window_color",Color("41788a"));world.set_shader_parameter("heritage",.8)
	# Explicitly assigning the declared default must remain distinct from null.
	world.set_shader_parameter("glass_roughness",.20)
	var city_code:String=city.shader.code;var world_code:String=world.shader.code;var city_id:=city.get_instance_id();var world_shader:Shader=world.shader
	verify("exact-path facade resources register glass and stone without duplication",shader_registry.register_key(city,"map_facade_stone") and shader_registry.register_key(world,"legacy_facade") and shader_registry.stats().resources==2 and shader_registry.stats().roles.glass==2 and shader_registry.stats().roles.stone==2 and shader_registry.stats().covered_shader_count==2)
	var sg:Dictionary=shader_registry.snapshot_role("glass");var ss:Dictionary=shader_registry.snapshot_role("stone")
	verify("shader snapshots distinguish unset defaults and explicit default overrides",sg.materials[city_id].roughness==null and sg.materials[world.get_instance_id()].roughness==.20 and ss.materials[city_id].roughness==null)
	shader_registry.set_role("glass",{"roughness":.39,"metallic":.64})
	verify("glass role edits only mapped facade glass uniforms",city.get_shader_parameter("glass_roughness")==.39 and world.get_shader_parameter("glass_metallic")==.64 and city.get_shader_parameter("wall_roughness")==null)
	shader_registry.set_role("stone",{"roughness":.62,"metallic":.2})
	verify("stone role changes wall roughness without changing facade glass or adding uniforms",world.get_shader_parameter("wall_roughness")==.62 and world.get_shader_parameter("glass_metallic")==.64 and world.get_shader_parameter("wall_metallic")==null)
	shader_registry.restore_role("glass",sg)
	verify("shader restore returns null to defaults and explicit originals exactly",city.get_shader_parameter("glass_roughness")==null and city.get_shader_parameter("glass_metallic")==null and world.get_shader_parameter("glass_roughness")==.20 and world.get_shader_parameter("glass_metallic")==null and world.get_shader_parameter("wall_roughness")==.62)
	shader_registry.restore_role("stone",ss)
	verify("independent stone restore clears only its temporary wall override",city.get_shader_parameter("wall_roughness")==null and world.get_shader_parameter("wall_roughness")==null and world.get_shader_parameter("glass_roughness")==.20)
	verify("facade tuning preserves resource identity shader code and authored colour pattern parameters",city.get_instance_id()==city_id and world.shader==world_shader and city.shader.code==city_code and world.shader.code==world_code and city.get_shader_parameter("wall_color")==Color("934b3e") and city.get_shader_parameter("glazing")==.72 and world.get_shader_parameter("window_color")==Color("41788a") and world.get_shader_parameter("heritage")==.8)
	var unsupported:=ShaderMaterial.new();unsupported.shader=load("res://shaders/water.gdshader")
	verify("water shader remains unregistered despite a glass-like material key",not shader_registry.register_key(unsupported,"glass") and shader_registry.stats().covered_shader_count==2)
	verify("duplicate facade registration remains idempotent for both memberships",shader_registry.register_key(city,"glass") and shader_registry.stats().resources==2 and shader_registry.stats().roles.glass==2 and shader_registry.stats().roles.stone==2 and city.get_shader_parameter("glass_roughness")==null)
