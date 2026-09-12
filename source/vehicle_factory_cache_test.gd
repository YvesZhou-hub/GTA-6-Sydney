extends SceneTree
const Factory=preload("res://scripts/vehicle_factory.gd")
const Vehicle=preload("res://scripts/harbor_vehicle.gd")
var checks: Array=[]
var profiles: Dictionary={}
var failures:=0
var space: Node3D

func _init(): call_deferred("run")
func check(label: String, passed: bool, detail: Dictionary={}) -> void:
	checks.append({"name":label,"passed":passed,"detail":detail})
	if not passed: failures+=1
	print("FACTORY_CACHE ","PASS " if passed else "FAIL ",label," ",JSON.stringify(detail))

func make(kind: String, identity: String) -> RigidBody3D:
	var body:=Factory.make(kind,identity)
	body.freeze=true;space.add_child(body)
	body.set_physics_process(false);body.set_process(false)
	return body

func nodes(parent: Node, result: Array[Node]=[]) -> Array[Node]:
	for child: Node in parent.get_children():
		if child.is_queued_for_deletion(): continue
		result.append(child);nodes(child,result)
	return result

func resource_signature(resource: Resource) -> Dictionary:
	var result: Dictionary={"class":resource.get_class()}
	for property: Dictionary in resource.get_property_list():
		var key: String=property.name
		if not(int(property.usage)&PROPERTY_USAGE_STORAGE) or key in ["script","resource_name","resource_local_to_scene"]: continue
		var value: Variant=resource.get(key)
		if not value is Object: result[key]=value
	return result

func geometry_signature(body: Node3D) -> Dictionary:
	var result: Dictionary={"nodes":[],"metadata":{}}
	var list: Array[Node]=nodes(body,[])
	for node: Node in list:
		if not node is Node3D: continue
		var record: Dictionary={"class":node.get_class(),"transform":node.transform,"visible":node.visible,"parent_index":list.find(node.get_parent()),"metadata":{}}
		for key: StringName in node.get_meta_list(): record.metadata[key]=node.get_meta(key)
		if node is MeshInstance3D:
			var surfaces: Array=[]
			for surface in node.mesh.get_surface_count():
				var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256)
				context.update(var_to_bytes(node.mesh.surface_get_arrays(surface)))
				surfaces.append(context.finish().hex_encode())
			record["surface_sha256"]=surfaces;record["aabb"]=node.mesh.get_aabb()
			record["material"]=resource_signature(node.material_override) if node.material_override!=null else {}
			record["render_flags"]=[node.cast_shadow,node.layers,node.extra_cull_margin,node.gi_mode]
		if node is CollisionShape3D: record["shape"]=resource_signature(node.shape);record["disabled"]=node.disabled
		result.nodes.append(record)
	for key: String in Factory.MODEL_METADATA:
		if body.has_meta(key): result.metadata[key]=body.get_meta(key)
	return result

func references_belong(value: Variant, body: Node) -> bool:
	if value is Node: return is_instance_valid(value) and body.is_ancestor_of(value)
	if value is Array:
		for item in value:
			if not references_belong(item,body): return false
	if value is Dictionary:
		for item in value.values():
			if not references_belong(item,body): return false
	return true

func reference_count(value: Variant) -> int:
	if value is Node: return 1
	var result:=0
	if value is Array:
		for item in value: result+=reference_count(item)
	if value is Dictionary:
		for item in value.values(): result+=reference_count(item)
	return result

func model_meshes(body: Node3D) -> Array:
	var result: Array=[]
	for node: Node in nodes(body,[]):
		if node is MeshInstance3D and not body._wake.any(func(wake):return wake.node==node): result.append(node)
	return result

func run() -> void:
	Factory.clear_geometry_cache()
	space=Node3D.new();root.add_child(space)
	# Cold build under a transformed in-tree parent tests local/world transform handling.
	space.position=Vector3(145,320,-880);space.rotation=Vector3(.13,.41,-.09)
	for kind: String in Vehicle.NAMES:
		var cold:=make(kind,"cache_cold_"+kind)
		var baseline:=geometry_signature(cold)
		var profile: Dictionary=cold.get_meta("vehicle_factory_profile").duplicate(true)
		var hot:=make(kind,"cache_hot_"+kind)
		var hot_profile: Dictionary=hot.get_meta("vehicle_factory_profile").duplicate(true)
		profiles[kind]={"cold":profile,"hot":hot_profile}
		check(kind+" cold creates one recipe and hot skips all mesh extraction/commit",not profile.cache_hit and profile.cache_stored and hot_profile.cache_hit and hot_profile.source_meshes==0 and hot_profile.temporary_mesh_commits==0 and hot_profile.merged_meshes==0,profiles[kind])
		check(kind+" cached geometry, normals, UVs, indices, collider shapes and local transforms are exact",geometry_signature(hot)==baseline)
		check(kind+" moving references belong only to their own fresh nodes",references_belong(cold._moving,cold) and references_belong(hot._moving,hot) and reference_count(cold._moving)==reference_count(hot._moving) and cold._moving.keys()==hot._moving.keys(),{"node_references":reference_count(hot._moving)})
		check(kind+" identities and runtime physics material stay independent",cold.vehicle_id!=hot.vehicle_id and cold.physics_material_override!=hot.physics_material_override and cold._moving.material!=hot._moving.material)
		var cold_nodes:=nodes(cold,[]);var hot_nodes:=nodes(hot,[])
		var names_match:=cold_nodes.size()==hot_nodes.size()
		for index in mini(cold_nodes.size(),hot_nodes.size()):
			if not str(cold_nodes[index].name).begins_with("@") and cold_nodes[index].name!=hot_nodes[index].name: names_match=false
		check(kind+" authored node names survive caching",names_match)
		var cold_meshes:=model_meshes(cold);var hot_meshes:=model_meshes(hot)
		var shared_meshes:=cold_meshes.size()==hot_meshes.size()
		for index in mini(cold_meshes.size(),hot_meshes.size()):
			if cold_meshes[index]==hot_meshes[index] or cold_meshes[index].mesh!=hot_meshes[index].mesh: shared_meshes=false
		check(kind+" immutable mesh buffers are reused by fresh MeshInstance nodes",shared_meshes,{"meshes":hot_meshes.size()})
		var cold_shapes: Array=cold_nodes.filter(func(n):return n is CollisionShape3D)
		var hot_shapes: Array=hot_nodes.filter(func(n):return n is CollisionShape3D)
		var separate_shapes:=cold_shapes.size()==hot_shapes.size()
		for index in mini(cold_shapes.size(),hot_shapes.size()):
			if cold_shapes[index].shape==hot_shapes[index].shape: separate_shapes=false
		check(kind+" collision resources and runtime smoke stay per-instance",separate_shapes and cold._smoke!=hot._smoke)
		var paint_users_cold:=0;var paint_users_hot:=0
		for node in model_meshes(cold):
			if node.material_override==cold._moving.material: paint_users_cold+=1
		for node in model_meshes(hot):
			if node.material_override==hot._moving.material: paint_users_hot+=1
		check(kind+" paint aliasing within each vehicle is preserved",paint_users_cold==paint_users_hot and paint_users_hot>0,{"paint_meshes":paint_users_hot})
		var base_color: Color=cold._moving.material.albedo_color
		cold.health=23;cold._animate(.1)
		# Invincible kinds normally stay at 100; direct material mutation still must
		# not contaminate either the recipe or another instance.
		cold._moving.material.albedo_color=Color(.2,.11,.08)
		cold._add_dent(Vector3(.7,.2,0))
		var fresh:=make(kind,"cache_pristine_"+kind)
		check(kind+" damaged first vehicle cannot poison later fresh paint or geometry",fresh.health==100 and fresh._moving.material.albedo_color==base_color and hot._moving.material.albedo_color==base_color and fresh._dent_nodes.is_empty() and hot._dent_nodes.is_empty() and geometry_signature(fresh)==baseline)
		if not hot._moving.wheels.is_empty():
			var original: Basis=fresh._moving.wheels[0].basis
			hot._moving.wheels[0].rotate_x(.7)
			check(kind+" wheel animation cannot move another copy",fresh._moving.wheels[0].basis==original and hot._moving.wheels[0].basis!=original)
		if hot._moving.rider!=null:
			hot.occupied=true;hot._animate(.1)
			check(kind+" boarding shows only its own rider",hot._moving.rider.visible and not fresh._moving.rider.visible)
		for group: String in ["rotors","propellers"]:
			if hot._moving[group].is_empty(): continue
			var original: Basis=fresh._moving[group][0].basis
			hot._animate(.2)
			check(kind+" "+group+" animate without sharing pivots",fresh._moving[group][0].basis==original and hot._moving[group][0].basis!=original)
		if kind=="tank":
			hot._moving.turret.rotation.y=.8;hot._moving.barrel.rotation.x=.35
			check("Tank cached pivot hierarchy and muzzle remain independent",hot._moving.barrel.get_parent()==hot._moving.turret and hot._moving.muzzle.get_parent()==hot._moving.barrel and fresh._moving.turret.rotation.is_zero_approx() and fresh._moving.barrel.rotation.is_zero_approx())
			var saved: Dictionary=hot.get_state()
			fresh.apply_state(saved)
			check("Cached tank supports ordinary saved aim restoration",is_equal_approx(fresh._moving.turret.rotation.y,.8) and is_equal_approx(fresh._moving.barrel.rotation.x,.35))
		if kind=="fighter":
			check("Fighter exhaust and forward muzzle are freshly mapped",hot._moving.exhaust.size()==2 and hot._moving.weapon_muzzle.position.is_equal_approx(Vector3(0,-.08,-9.8)) and hot._moving.weapon_muzzle!=fresh._moving.weapon_muzzle and hot._moving.exhaust[0]!=fresh._moving.exhaust[0])
		if kind in ["speedboat","yacht"]:
			var old_exit: Vector3=fresh.boat_profile.exit
			hot.boat_profile.exit=Vector3(500,500,500)
			check(kind+" mutable boat profile is not shared",fresh.boat_profile.exit==old_exit)
		var prior_count: int=hot._moving.wheels.size()
		cold.free()
		var surviving:=make(kind,"cache_after_release_"+kind)
		check(kind+" cache survives releasing first instance",surviving.get_meta("vehicle_factory_profile").cache_hit and references_belong(surviving._moving,surviving) and surviving._moving.material.albedo_color==base_color and surviving._moving.wheels.size()==prior_count)
		hot.free();fresh.free();surviving.free()
	await process_frame
	check("Cache stays bounded by vehicle kinds, not spawned copies",Factory.geometry_cache_stats().entries==Vehicle.NAMES.size(),Factory.geometry_cache_stats())
	Factory.clear_geometry_cache();check("Explicit cache cleanup releases all recipes",Factory.geometry_cache_stats().entries==0)
	var report: Dictionary={"passed":failures==0,"count":checks.size(),"failures":failures,"checks":checks,"profiles":profiles,"native":false,"scope":"Isolated production Vehicle/Factory builds for every kind. Exact cold/hot arrays and authored collider properties; independent node/material/mutable metadata, first-copy damage, saved tank aim and release/recreate. CPU headless timings are not native GPU-performance claims.","factory_sha256":FileAccess.get_sha256("res://scripts/vehicle_factory.gd"),"test_sha256":FileAccess.get_sha256("res://../source/vehicle_factory_cache_test.gd"),"vehicle_sha256":FileAccess.get_sha256("res://scripts/harbor_vehicle.gd"),"engine":Engine.get_version_info().string}
	DirAccess.make_dir_recursive_absolute("res://../reports/vehicle-factory-cache")
	FileAccess.open("res://../reports/vehicle-factory-cache/checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FACTORY_CACHE_COMPLETE ",checks.size()," passed=",failures==0)
	space.queue_free();await process_frame;quit(failures)
