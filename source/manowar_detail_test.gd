extends SceneTree
const Model=preload("res://scripts/manowar_detail.gd")
const City=preload("res://scripts/city_map.gd")
const Migration=preload("res://scripts/map_migration.gd")
class LocalWorld:
	extends "res://scripts/harbor_world.gd"
	func _ready():
		_make_materials()
		map_snapshot=City.data()
		geography=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world_geography.json"))
		_build_land()
		Model.build(self)
		for id in structures:
			for child in structures[id].node.get_children():
				if child is MeshInstance3D:child.set_meta("intact_material",child.material_override)
		_flush_batches()
		_ready_complete=true
class Game extends Node3D:
	var world:Node3D
	var player:CharacterBody3D
var checks:Array=[]
var game:Game
func _initialize():call_deferred("run")
func check(label:String,okay:bool,detail:Dictionary={}):
	checks.append({"name":label,"passed":okay,"detail":detail})
	print("PASS " if okay else "FAIL ",label," ",detail if not okay else "")
func run():
	for name in ["forward","back","left","right","jump","sprint"]:
		if not InputMap.has_action(name):InputMap.add_action(name)
	game=Game.new();root.add_child(game)
	game.world=LocalWorld.new();game.add_child(game.world)
	game.player=load("res://scripts/harbor_player.gd").new();game.add_child(game.player)
	game.player.enabled=false
	await physics_frame;await physics_frame
	var space:=game.get_world_3d().direct_space_state
	for item in Model.pier_data():
		var body:Node3D=game.world.structures["quay/manowar/pier/%s"%int(item.id)].node
		check("OSM pier outline retained %s"%int(item.id),body.get_meta("source_outline")==item.points)
		var shape:ConcavePolygonShape3D=body.get_child(1).shape
		check("structural render/collision agree %s"%int(item.id),shape.get_faces()==body.get_child(0).mesh.get_faces())
	var before:int=game.world.structures.size();Model.build(game.world)
	check("module idempotent",before==game.world.structures.size())
	var wrong_normals:=0;var unclosed:=0;var triangles:=0
	for id in game.world.structures:
		var body:Node3D=game.world.structures[id].node
		var mesh:Mesh=body.get_child(0).mesh
		var face_vertices:=mesh.get_faces();triangles+=face_vertices.size()/3
		if "gangway" in id:
			var edges:Dictionary={}
			for i in range(0,face_vertices.size(),3):
				for j in 3:
					var a:Vector3=face_vertices[i+j];var b:Vector3=face_vertices[i+(j+1)%3]
					var key:=str(a)+"|"+str(b) if str(a)<str(b) else str(b)+"|"+str(a)
					edges[key]=edges.get(key,0)+1
			for count in edges.values():
				if count!=2:unclosed+=1
		for index in mesh.get_surface_count():
			var ar:=mesh.surface_get_arrays(index);var vertices:PackedVector3Array=ar[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=ar[Mesh.ARRAY_NORMAL];var ix:PackedInt32Array=ar[Mesh.ARRAY_INDEX] if ar[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			for k in range(0,ix.size() if not ix.is_empty() else vertices.size(),3):
				var a:int=ix[k] if not ix.is_empty() else k;var b:int=ix[k+1] if not ix.is_empty() else k+1;var c:int=ix[k+2] if not ix.is_empty() else k+2
				if not vertices[a].is_finite() or (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).dot(normals[a])>=0:wrong_normals+=1
	check("all structural faces finite and outward",wrong_normals==0,{"wrong":wrong_normals,"triangles":triangles})
	check("both gangway colliders are closed solids",unclosed==0,{"unclosed_edges":unclosed})
	for route in ([] if "--geometry-only" in OS.get_cmdline_user_args() else Model.walk_routes()):
		await walk(route.name+" outward",route.points)
		var points:Array=route.points.duplicate();points.reverse()
		await walk(route.name+" return",points)
	for item in Model.metadata():
		var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(item.arrival+Vector3.UP*.2,item.arrival-Vector3.UP*.2))
		check(item.id+" arrival is on actual pontoon",not hit.is_empty() and str(hit.collider.get_meta("damage_id","")).begins_with("quay/manowar/pier/"))
	for g in Model.GANGWAYS:
		for fraction in [.25,.5,.75]:
			var sample:Vector3=g[1].lerp(g[2],fraction)
			var support:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(sample.x,6,sample.z),Vector3(sample.x,1,sample.z),15,[game.player.get_rid()]))
			game.player.global_position=support.position+Vector3.UP*.20;game.player.velocity=Vector3.ZERO;game.player.enabled=true
			for frame in 30:await physics_frame
			game.player.enabled=false
			var at:Vector3=game.player.global_position
			check("safe saved gangway pose "+g[0]+str(fraction),not Migration._player_needs_relocation(game,at),{"actual":[at.x,at.y,at.z]})
			check("buried gangway pose rejected "+g[0]+str(fraction),Migration._player_needs_relocation(game,at-Vector3.UP*.06))
	var id:="quay/manowar/pier/354759944";var owner:Node3D=game.world.structures[id].node
	game.world._destroy_component(id,Vector3(500,2.5,-244),0,false)
	check("pier fittings disappear with their damage owner",not owner.is_visible_in_tree())
	game.world.repair_all()
	check("pier repairs restore fittings",owner.is_visible_in_tree())
	var materials_restored:=true
	for child in owner.get_children():
		if child is MeshInstance3D:materials_restored=materials_restored and child.material_override==child.get_meta("intact_material")
	check("pier repairs preserve each fitting material",materials_restored)
	if "--capture" in OS.get_cmdline_user_args():await capture()
	var okay:bool=checks.all(func(c):return c.passed)
	DirAccess.make_dir_recursive_absolute("res://../reports/manowar")
	FileAccess.open("res://../reports/manowar/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":okay,"checks":checks,"continuous_walks_ran":not "--geometry-only" in OS.get_cmdline_user_args(),"headless":DisplayServer.get_name()=="headless","model_sha256":FileAccess.get_sha256("res://scripts/manowar_detail.gd"),"scope":"Actual production player continuous walks in the mapped coast fixture, closed solids, save poses and damage. Heights and fittings remain estimates."},"  "))
	print("MANOWAR_COMPLETE ",checks.size()," passed=",okay)
	quit(0 if okay else 1)
func walk(label:String,points:Array):
	game.player.global_position=points[0]+Vector3.UP*.1;game.player.velocity=Vector3.ZERO;game.player.enabled=true
	for frame in 20:await physics_frame
	var okay:=true;var detail:Array=[]
	for target:Vector3 in points.slice(1):
		var frames:=0
		while frames<900:
			var delta:Vector3=target-game.player.global_position
			if Vector2(delta.x,delta.z).length()<.38:break
			game.player.yaw=atan2(-delta.x,-delta.z);Input.action_press("forward")
			await physics_frame;frames+=1
		Input.action_release("forward")
		for frame in 6:await physics_frame
		var at:Vector3=game.player.global_position
		var reached:=Vector2(at.x-target.x,at.z-target.z).length()<.6 and absf(at.y-target.y)<.3
		detail.append({"actual":[at.x,at.y,at.z],"target":[target.x,target.y,target.z],"reached":reached})
		if not reached:okay=false;break
	game.player.enabled=false
	check(label,okay,{"segments":detail})

func capture():
	root.size=Vector2i(1440,900)
	game.player.visible=false
	game.world._build_water()
	game.world._build_structure_batches()
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("b0c4ca");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("d7e3df");env.ambient_light_energy=.8;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var e:=WorldEnvironment.new();e.environment=env;game.add_child(e)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-30,0);sun.light_energy=1.3;sun.shadow_enabled=true;game.add_child(sun)
	var camera:=Camera3D.new();camera.current=true;camera.far=1000;camera.fov=62;game.add_child(camera)
	DirAccess.make_dir_recursive_absolute("res://../reports/manowar/native")
	for view in Model.capture_views():
		camera.position=view[1];camera.look_at(view[2])
		for frame in 5:await process_frame
		RenderingServer.force_draw(false);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../reports/manowar/native/"+view[0]+".png")
