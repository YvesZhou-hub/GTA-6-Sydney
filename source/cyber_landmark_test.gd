extends SceneTree
const Cyber=preload("res://scripts/cyber_landmarks.gd")
var failures:=0
class ProbeWorld extends "res://scripts/harbor_world.gd":
	func _ready() -> void:
		_make_materials()
		Cyber.build(self)
		_box(self,Vector3(-440,4.2,1050),Vector3(1000,0.6,1000),"paving",true)
		for id in structures:
			for child in structures[id].node.get_children():
				if child is MeshInstance3D:child.set_meta("intact_material",child.material_override)
		_build_structure_batches();_ready_complete=true
func _initialize() -> void:call_deferred("run")
func verify(value: bool,label: String) -> void:
	if value:print("PASS ",label)
	else:failures+=1;push_error("FAIL "+label)
func run() -> void:
	var world:=ProbeWorld.new();root.add_child(world)
	verify(world._ready_complete,"isolated production geometry initialized completely")
	if not world._ready_complete:quit(1);return
	verify(Cyber.metadata().size()==2,"two offices have distinct addresses and destination identities")
	var coordinate_error:=0.0
	for item in Cyber.metadata():
		var expected:=Vector3((item.lon-151.2105)*92400,4.5,(-33.86-item.lat)*111320)
		coordinate_error=maxf(coordinate_error,expected.distance_to(item.center))
	verify(coordinate_error<0.02,"company destination coordinates use the existing Sydney projection")
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../source/map-data/city.json"))
	var ids:=Cyber.excluded_way_ids();var polys:=Cyber.footprints();var max_error:=0.0;var found:=0
	for item: Dictionary in source.elements:
		if item.type!="way" or not ids.has(int(item.id)):continue
		var poly: PackedVector2Array=polys[ids.find(int(item.id))]
		found+=1
		for g: Dictionary in item.geometry:
			var p:=Vector2((g.lon-151.2105)*92400,(-33.86-g.lat)*111320)
			var best:=INF
			for q in poly:best=minf(best,p.distance_to(q))
			max_error=maxf(max_error,best)
	verify(found==6 and max_error<0.002,"all six parent/part footprints match original OSM vertices within 2mm")
	var inside:=true
	for p in Cyber.pavilion_polygon():inside=inside and Geometry2D.is_point_in_polygon(p,Cyber.Geo.polygon(Cyber.GEORGE_OUTLINE))
	verify(inside,"photo-reconstructed curved Pavilion remains within the original parent outline")
	var triangles:=0;var degenerate:=0;var bad_winding:=0;var mismatch:=0;var heights:={"market":0.0,"george":0.0}
	for id: String in world.structures:
		var body: StaticBody3D=world.structures[id].node
		var solid: Mesh=body.get_child(0).mesh;var shape: Shape3D=body.get_child(1).shape
		if shape is ConcavePolygonShape3D and shape.get_faces()!=solid.get_faces():mismatch+=1
		for child in body.get_children():
			if not child is MeshInstance3D:continue
			for n in child.mesh.get_surface_count():
				var arrays: Array=child.mesh.surface_get_arrays(n)
				var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				for p in verts:
					var key:="market" if id.begins_with("cyber/market/") else "george"
					heights[key]=maxf(heights[key],(body.transform*child.transform*p).y-4.5)
				var count:=verts.size() if indices.is_empty() else indices.size();triangles+=count/3
				for j in range(0,count,3):
					var a:=j if indices.is_empty() else indices[j];var b:=j+1 if indices.is_empty() else indices[j+1];var c:=j+2 if indices.is_empty() else indices[j+2]
					var cross:=(verts[b]-verts[a]).cross(verts[c]-verts[a])
					if cross.length_squared()<0.00000000001:degenerate+=1
					if cross.dot(normals[a]+normals[b]+normals[c])>0.00002:bad_winding+=1
	verify(mismatch==0,"all structural meshes and colliders have identical faces")
	verify(degenerate==0,"no zero-area detail or structure triangles")
	verify(bad_winding==0,"all external faces use outward normals and Godot winding")
	verify(triangles<150000,"combined geometry remains bounded, triangles="+str(triangles))
	verify(absf(heights.market-83.0)<0.02 and absf(heights.george-131.0)<0.02,"the published 83m and 131m architectural envelopes are preserved")
	await physics_frame;await physics_frame
	var space:=world.get_world_3d().direct_space_state
	for entry: Array in [["market",Vector3(-593,95,1177),Vector3(-593,4.6,1177)],["george",Vector3(-285,145,925),Vector3(-285,4.6,925)],["george",Vector3(-306,30,949),Vector3(-306,4.6,949)]]:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(entry[1],entry[2]))
		verify(not hit.is_empty() and str(hit.collider.get_meta("damage_id","")).begins_with("cyber/"+entry[0]),entry[0]+" tower/pavilion has real collision at mapped position")
	var direction: Vector3=(Cyber.FRONT_B-Cyber.FRONT_A).normalized();var normal:=Vector3(-direction.z,0,direction.x)
	var center: Vector3=(Cyber.FRONT_A+Cyber.FRONT_B)*0.5
	var recesses:=0
	for group in range(5):
		var p:=center+Vector3.UP*(24+group*24+4.5)
		var front:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+normal*0.3,p-normal*4))
		var back:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+normal*0.3,p-normal*8))
		if front.is_empty() and not back.is_empty():recesses+=1
	verify(recesses==5,"all five four-storey atrium groups have genuine 6m recessed geometry")
	var capsule:=CapsuleShape3D.new();capsule.radius=0.33;capsule.height=1.8
	var blocked:=0;var unsupported:=0;var route:=Cyber.arcade_path()
	for i in range(route.size()-1):
		for j in range(40):
			var p: Vector3=route[i].lerp(route[i+1],float(j)/39)
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform.origin=p+Vector3.UP*1.04;query.margin=0.005
			var hit:=space.intersect_shape(query)
			if not hit.is_empty():
				blocked+=1
				if blocked<4:print("ARCADE_BLOCK ",p," ",hit.map(func(x):return x.collider.name))
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.25,p-Vector3.UP*0.2)).is_empty():unsupported+=1
	verify(blocked==0 and unsupported==0,"George-to-King public arcade has continuous support and 120 clear human positions")
	var id:="cyber/george/tower/10";var body: StaticBody3D=world.structures[id].node
	world._destroy_component(id,Vector3.ZERO,0,false);await physics_frame
	verify(world.destroyed.has(id) and body.get_child(1).disabled,"damaging an atrium floor removes its real collision")
	world.apply_state({});await physics_frame
	verify(not world.destroyed.has(id) and not body.get_child(1).disabled,"repair restores matching collision and facade")
	if "--capture" in OS.get_cmdline_user_args():await capture(world)
	print("CYBER CHECK COMPLETE failures=",failures," triangles=",triangles," components=",world.structures.size())
	quit(failures)
func capture(world: Node3D) -> void:
	root.size=Vector2i(1440,1000)
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("99bdce")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("d0dce1");env.ambient_light_energy=0.65
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var environment:=WorldEnvironment.new();environment.environment=env;world.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-43,-30,0);sun.light_energy=1.5;sun.shadow_enabled=true;world.add_child(sun)
	var camera:=Camera3D.new();camera.current=true;camera.fov=48;camera.far=1600;world.add_child(camera)
	var views:={"market-street":[Vector3(-635,40,1310),Vector3(-572,44,1179)],"market-roof":[Vector3(-492,139,1288),Vector3(-572,48,1179)],"george-tower":[Vector3(-445,83,1099),Vector3(-286,67,934)],"george-pavilion":[Vector3(-356,13,1000),Vector3(-303,16,950)],"george-arcade":[Vector3(-316,6.3,924),Vector3(-283,9.0,958)]}
	var dir:=ProjectSettings.globalize_path("res://../reports/cyber-refinement");DirAccess.make_dir_recursive_absolute(dir)
	for name: String in views:
		camera.position=views[name][0];camera.look_at(views[name][1])
		for i in range(8):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir+"/"+name+".png");print("CYBER FRAME ",name)
