extends SceneTree
const Q=preload("res://scripts/qvb_public.gd")
const Migration=preload("res://scripts/map_migration.gd")
var failures:=0
var checks:=[]
var walk_evidence:=[]
var migration_evidence:=[]
var migration_recovery_evidence:=[]
var visual_geometry_evidence:=[]
class Game extends Node3D:
	var world:Node3D
	var player:CharacterBody3D
	var vehicles:Array=[]
	var yaw:=0.0
class ProbeWorld extends "res://scripts/harbor_world.gd":
	func _ready():
		_make_materials()
		Q.build(self)
		var snap:Dictionary=CityMap.data()
		var tri:=[]
		var rect:=PackedVector2Array([Vector2(-410,1190),Vector2(-300,1190),Vector2(-300,1425),Vector2(-410,1425)])
		for land in snap.land:
			for i in range(0,land.triangles.size(),3):
				var face:=PackedVector2Array()
				for j in 3:face.append(Vector2(land.triangles[i+j][0],land.triangles[i+j][1]))
				for piece in Geometry2D.intersect_polygons(face,rect):
					for index in Geometry2D.triangulate_polygon(piece):tri.append([piece[index].x,piece[index].y])
		CityMap.build_terrain(self,{"land":[{"triangles":tri}],"parks":[],"beaches":[]})
		map_snapshot={"buildings":[]}
		for item in snap.buildings:
			if int(item.id.get_slice("/",1)) in Q.excluded_way_ids():map_snapshot.buildings.append(item)
		_ready_complete=true
func _initialize():call_deferred("run")
func verify(pass_value:bool,name:String):
	checks.append({"name":name,"passed":pass_value})
	print("PASS " if pass_value else "FAIL ",name)
	if not pass_value:failures+=1
func run():
	for action in ["forward","back","left","right","jump","sprint"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	var world:=ProbeWorld.new();root.add_child(world)
	await physics_frame;await physics_frame
	if "--capture-only" in OS.get_cmdline_user_args():
		await capture_views(world)
		print("QVB_CAPTURE_ONLY completed; no checks run in this invocation")
		quit(0);return
	var expected:Array[String]=[];var actual:Array[String]=[]
	for item in world.map_snapshot.buildings:
		if not item.get("parts",[]).is_empty() and item.get("parent_geometry_policy",{}).get("mode","")!="preserve_tagged_base":continue
		var h:float=item.get("wall_height",item.height)
		for level in maxi(1,mini(8,ceili((h-item.base)/18.0))):expected.append("osm/%s/storey_group/%s"%[item.id,level])
		if item.has("roof_surface"):expected.append("osm/%s/roof"%item.id)
	var triangles:=0;var degenerate:=0;var inverted:=0;var collision_mismatch:=0;var unreferenced:=0
	for id in world.structures:
		if id.begins_with("osm/"):actual.append(id)
		var body:StaticBody3D=world.structures[id].node
		if body.get_child(0).mesh.get_faces()!=body.get_child(1).shape.get_faces():collision_mismatch+=1
		for child in body.get_children():
			if not child is MeshInstance3D:continue
			var faces:PackedVector3Array=child.mesh.get_faces();triangles+=faces.size()/3
			for i in range(0,faces.size(),3):
				if (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length_squared()<.0000000001:degenerate+=1
			for si in child.mesh.get_surface_count():
				var a=child.mesh.surface_get_arrays(si);var vs:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=a[Mesh.ARRAY_NORMAL];var ix:PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				if not ix.is_empty():
					var referenced:Dictionary={}
					for index in ix:referenced[index]=true
					unreferenced+=vs.size()-referenced.size()
				var n:=ix.size() if not ix.is_empty() else vs.size()
				for i in range(0,n,3):
					var ia:int=ix[i] if not ix.is_empty() else i;var ib:int=ix[i+1] if not ix.is_empty() else i+1;var ic:int=ix[i+2] if not ix.is_empty() else i+2
					if (vs[ib]-vs[ia]).cross(vs[ic]-vs[ia]).dot(ns[ia]+ns[ib]+ns[ic])>.0001:inverted+=1
	expected.sort();actual.sort()
	verify(expected==actual,"every prior QVB OSM damage component ID is preserved")
	verify(Q.legacy_damage_ids().size()==expected.size(),"legacy manifest agrees with source base wall-height and part policies")
	verify(Q.metadata()[0].position.distance_to(Q.walk_routes()[0].points[0])<.001 and Q.metadata()[0].position.distance_to(Q.CENTER)>90,"navigation arrival is the tested public Market Street threshold")
	verify(world.map_snapshot.buildings.size()==25,"exactly 25 existing QVB OSM footprints replaced")
	verify(collision_mismatch==0,"every structural collision mesh matches its visible solid")
	verify(unreferenced==0,"every QVB mesh vertex is drawn; no mixed-index vertices are silently omitted")
	verify(degenerate==0,"no degenerate QVB triangles")
	verify(inverted==0,"all QVB face winding agrees with normals")
	verify(triangles<330000,"bounded QVB mesh triangle count "+str(triangles))
	var reserved:=true
	for item in world.map_snapshot.buildings:reserved=reserved and world.CityMap._reserved(world,item)
	verify(reserved,"production generic building filter reserves all 25 QVB parts")
	var space:=world.get_world_3d().direct_space_state
	var supported:=0;var blocked:=0
	for z in range(-90,91,6):
		for x in [-3.6,0.0,3.6]:
			var at:=Q.point(Vector3(x,.08,z))
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.5,at-Vector3.UP*.5))
			if not hit.is_empty() and hit.normal.y>.99:supported+=1
			var shape:=CapsuleShape3D.new();shape.radius=.32;shape.height=1.78
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=at+Vector3.UP*.9;query.margin=0
			if not space.intersect_shape(query).is_empty():blocked+=1
	verify(supported==93 and blocked==0,"93 longitudinal aisle stations have real floor and standing-capsule clearance")
	verify_height_geometry(world)
	await verify_visual_enclosure(world)
	for route in Q.walk_routes():await walk_route(world,route)
	var game:=Game.new();game.world=world;root.add_child(game)
	var player=load("res://scripts/harbor_player.gd").new();game.add_child(player);game.player=player
	for flat in [Vector3(0,0,-84),Vector3(3.6,0,-35),Vector3(0,0,0),Vector3(3.6,0,35),Vector3(0,0,84)]:
		player.enabled=false;player.position=Q.point(flat+Vector3.UP*.15);player.velocity=Vector3.ZERO;player.last_safe=player.position;player.enabled=true
		for frame in 30:await physics_frame
		player.enabled=false
		var at:Vector3=player.global_position
		var preserve:bool=not Migration._player_needs_relocation(game,at)
		var buried:bool=Migration._player_needs_relocation(game,at-Vector3.UP*.06)
		var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.12,at-Vector3.UP*.25,15,[player.get_rid()]))
		print("QVB_POSE ",at," preserved=",preserve," buried=",buried," hit=",str(hit.collider.get_meta("damage_id","terrain")) if not hit.is_empty() else "none")
		verify(player.is_on_floor() and preserve,"migration preserves settled Grand Walk player "+str(flat))
		verify(buried,"migration rejects Grand Walk player buried 6 cm "+str(flat))
		migration_evidence.append({"at":[at.x,at.y,at.z],"preserved":preserve,"buried_rejected":buried})
	await recover_old_floor(game)
	var owner:StaticBody3D=world.structures["osm/way/568422349/storey_group/1"].node
	world._destroy_component("osm/way/568422349/storey_group/1",Vector3.ZERO,0,false)
	await physics_frame
	verify(not owner.visible and owner.get_child(1).disabled,"copper roof and its ribs disappear with the retained upper dome damage ID")
	world.apply_state({});await physics_frame
	verify(owner.visible and not owner.get_child(1).disabled,"legacy dome damage restores geometry and collision")
	var report:={"passed":failures==0,"checks":checks,"counts":{"checks":checks.size(),"components":world.structures.size(),"triangles":triangles,"legacy_ids":expected.size()},"continuous_walks":true,"walks":walk_evidence,"migration":migration_evidence,"old_floor_recovery":migration_recovery_evidence,"visual_geometry":visual_geometry_evidence,"hashes":{}}
	for path in ["res://scripts/qvb_public.gd","res://../source/qvb_public_test.gd","res://scripts/map_migration.gd","res://scripts/city_map.gd"]:report.hashes[path]=FileAccess.get_sha256(path)
	var dir:=ProjectSettings.globalize_path("res://../reports/qvb-public");DirAccess.make_dir_recursive_absolute(dir)
	FileAccess.open(dir+"/checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	if "--capture" in OS.get_cmdline_user_args():await capture_views(world)
	print("QVB_COMPLETE checks=",checks.size()," failures=",failures," triangles=",triangles)
	quit(1 if failures else 0)

func walk_route(world:Node3D,route:Dictionary) -> void:
	var player=load("res://scripts/harbor_player.gd").new();world.add_child(player)
	player.global_position=route.points[0]+Vector3.UP*0.10;player.last_safe=player.global_position;player.enabled=true
	for frame in 20:await physics_frame
	var targets:Array=route.points.slice(1)
	for phase in 2:
		var reached:=true;var airborne:=0;var segments:Array=[]
		for target:Vector3 in targets:
			var frames:=0
			Input.action_press("forward")
			while frames<1400:
				var delta:Vector3=target-player.global_position
				if Vector2(delta.x,delta.z).length()<0.28:break
				player.yaw=atan2(-delta.x,-delta.z)
				await physics_frame;frames+=1
				if not player.is_on_floor():airborne+=1
			Input.action_release("forward")
			for frame in 6:await physics_frame
			var actual:Vector3=player.global_position
			var segment_ok:bool=Vector2(actual.x-target.x,actual.z-target.z).length()<0.55 and absf(actual.y-target.y)<0.25 and player.is_on_floor()
			segments.append({"target":[target.x,target.y,target.z],"actual":[actual.x,actual.y,actual.z],"frames":frames,"reached":segment_ok})
			if not segment_ok:reached=false;break
		var label:String=route.name+(" outward" if phase==0 else " return")
		verify(reached and airborne<=3 and not player.swimming,label+" production HarborPlayer walks continuously without jumping or teleporting")
		walk_evidence.append({"name":label,"passed":reached and airborne<=3 and not player.swimming,"airborne_frames":airborne,"segments":segments})
		targets=route.points.duplicate();targets.reverse();targets=targets.slice(1)
	player.queue_free();await physics_frame


func recover_old_floor(game:Node3D) -> void:
	var player:CharacterBody3D=game.player
	var world:Node3D=game.world
	var space:=world.get_world_3d().direct_space_state
	for flat in [Vector3(0,0,-84),Vector3(3.6,0,-35),Vector3(0,0,0),Vector3(3.6,0,35),Vector3(0,0,84)]:
		var saved:=Q.point(flat)
		player.enabled=false;player.global_position=saved;player.velocity=Vector3.ZERO;player.last_safe=saved
		player.reset_physics_interpolation()
		await physics_frame
		# Test a private shop-wing roof at z +/-35 and the directly overhead
		# physical end roofs / central dome at the other saved positions.
		# The new glass skins are also independently tested as physical roofs.
		var roof_probe:Vector3=Q.point(Vector3(10,0,flat.z)) if absf(flat.z)==35.0 else saved
		var roof_hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(roof_probe+Vector3.UP*80,roof_probe-Vector3.UP*.4,15,[player.get_rid()]))
		var roof_id:String="" if roof_hit.is_empty() else str(roof_hit.collider.get_meta("damage_id",""))
		var roof_above:bool=not roof_hit.is_empty() and roof_hit.position.y>saved.y+5.0 and (roof_id.begins_with("osm/way/") or roof_id.begins_with("city/qvb/roof_"))
		verify(roof_above and not Migration._player_ground_allowed(game,roof_hit) and not Migration._clear_player_pose(game,roof_hit).is_finite(),"actual QVB roof is rejected as a migration landing "+str(roof_probe))
		var needs:bool=Migration._player_needs_relocation(game,saved)
		var predicted:Vector3=Migration._player_pose(game,saved)
		var count:int=Migration.apply(game)
		var relocated:Vector3=player.global_position
		var same_xz:=Vector2(relocated.x-saved.x,relocated.z-saved.z).length()<.001
		verify(needs and predicted.is_finite() and predicted.distance_to(relocated)<.001 and count==1 and same_xz and absf(relocated.y-4.58)<.002,"old Y4.5 save migrates vertically onto QVB Y4.54 floor at identical XZ "+str(flat))
		player.enabled=true
		for frame in 30:await physics_frame
		player.enabled=false
		var at:Vector3=player.global_position
		var floor_hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.12,at-Vector3.UP*.25,15,[player.get_rid()]))
		var floor_id:String="" if floor_hit.is_empty() else str(floor_hit.collider.get_meta("damage_id",""))
		var settled:bool=player.is_on_floor() and floor_id=="city/qvb/public_floor" and absf(floor_hit.position.y-4.54)<.002 and not Migration._player_needs_relocation(game,at)
		verify(settled and Vector2(at.x-saved.x,at.z-saved.z).length()<.001,"migrated production player settles on public tile without later horizontal relocation "+str(flat))
		migration_recovery_evidence.append({"saved":[saved.x,saved.y,saved.z],"relocated":[relocated.x,relocated.y,relocated.z],"settled":[at.x,at.y,at.z],"shifted":count,"same_xz":same_xz,"settled_safe":settled,"roof_probe":[roof_probe.x,roof_probe.y,roof_probe.z],"roof_id":roof_id,"roof_rejected":roof_above and not Migration._player_ground_allowed(game,roof_hit),"floor_id":floor_id})
	# This tile support is real, but lies entirely within a closed private shop
	# wing. The extra public-floor allowance must not defeat shell containment.
	var enclosed:=Q.point(Vector3(10,0,35))
	player.global_position=enclosed;await physics_frame
	var inside_hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(enclosed+Vector3.UP*.35,enclosed-Vector3.UP*.4,15,[player.get_rid()]))
	var has_floor:bool=not inside_hit.is_empty() and str(inside_hit.collider.get_meta("damage_id",""))=="city/qvb/public_floor"
	verify(has_floor and Migration._player_ground_allowed(game,inside_hit) and not Migration._clear_player_pose(game,inside_hit).is_finite(),"public-floor hit inside closed private QVB shop shell is rejected by actual containment")
	var escaped:Vector3=Migration._player_pose(game,enclosed)
	verify(escaped.is_finite() and escaped.y<5.0 and not Migration._player_needs_relocation(game,escaped),"closed-shop fallback finds clear ground and cannot select its private rooftop")

func verify_height_geometry(world:Node3D) -> void:
	var misplaced:=0
	for part in Q.PARTS:
		if part.id in ["way/40717424","way/568422314","way/568422315","way/568422349","way/568422351"]:continue
		var centre:Vector3=Basis(Vector3.UP,Q.ANGLE).inverse()*(Vector3(part.center[0],4.5,part.center[1])-Q.CENTER)
		for level in maxi(1,mini(8,ceili(part.height/18.0))):
			var owner:StaticBody3D=world.structures["osm/%s/storey_group/%s"%[part.id,level]].node
			for child in owner.get_children():
				if not child is MeshInstance3D:continue
				for p in child.mesh.get_faces():
					if Vector2(p.x-centre.x,p.z-centre.z).length()>5.0:misplaced+=1;break
	verify(misplaced==0,"all minor-dome meshes including collar rings stay within their own OSM-centred turret; no misplaced rings intrude into the central dome")
	var lantern:MeshInstance3D=world.structures["osm/way/568422351/storey_group/1"].node.get_child(0)
	var copper:MeshInstance3D=world.structures["osm/way/568422349/storey_group/1"].node.get_child(0)
	var copper_bounds:=copper.mesh.get_aabb()
	verify(absf(lantern.mesh.get_aabb().end.y-58.0)<.025,"actual retained lantern geometry reaches official nominal 58m above local ground")
	verify(absf(copper_bounds.size.x-19.0)<.025 and absf(copper_bounds.position.y-(35.4-.28))<.025 and absf(copper_bounds.end.y-47.9)<.025,"actual outer copper shell is19m wide and has35.4m spring/47.9m crown with28cm closed skin, independently of retail floors")
	var inner_bounds:=AABB();var found:=false
	for child in world.structures["osm/way/568422349/storey_group/0"].node.get_children():
		if child is MeshInstance3D and child.material_override in [world.materials.qvb_amber,world.materials.qvb_green]:
			inner_bounds=child.mesh.get_aabb() if not found else inner_bounds.merge(child.mesh.get_aabb());found=true
	verify(found and absf(inner_bounds.size.x-11.3)<.025 and absf(inner_bounds.position.y-26.5)<.025 and absf(inner_bounds.end.y-32.4)<.025,"actual separate coloured-glass inner dome is11.3m wide at26.5–32.4m")
	for level in [5.7,10.9]:
		var hit:=visible_surface(world,Q.point(Vector3(5.5,level+.8,35)),Q.point(Vector3(5.5,level-.8,35)),["osm/way/40717424/storey_group/0"])
		verify(not hit.is_empty() and hit.material==world.materials.qvb_cream and absf(hit.position.y-(Q.CENTER.y+level+.175))<.025,"retail gallery remains at its independently calibrated floor level "+str(level))

func visible_surface(world:Node3D,from:Vector3,to:Vector3,ids:Array) -> Dictionary:
	var distance:=INF;var result:Dictionary={}
	for id in ids:
		var body:StaticBody3D=world.structures[id].node
		for child in body.get_children():
			if not child is MeshInstance3D:continue
			var local_from:Vector3=child.global_transform.affine_inverse()*from;var local_to:Vector3=child.global_transform.affine_inverse()*to
			var faces:PackedVector3Array=child.mesh.get_faces()
			for i in range(0,faces.size(),3):
				var hit=Geometry3D.segment_intersects_triangle(local_from,local_to,faces[i],faces[i+1],faces[i+2])
				if not hit is Vector3:continue
				var d:float=local_from.distance_to(hit)
				if d<distance:
					distance=d;result={"id":id,"material":child.material_override,"position":child.global_transform*hit,"child_index":child.get_index(),"triangle":i/3}
	return result

func verify_visual_enclosure(world:Node3D) -> void:
	var space:=world.get_world_3d().direct_space_state
	var roof_ids:=["city/qvb/roof_glazing","city/qvb/roof_transition"]
	var sealed:=0;var samples:=0
	for z in [-73.0,-40.0,-15.0,15.0,40.0,73.0]:
		for x in [-5.0,0.0,5.0]:
			var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Q.point(Vector3(x,12,z)),Q.point(Vector3(x,30,z))))
			samples+=1
			if not hit.is_empty() and str(hit.collider.get_meta("damage_id",""))=="city/qvb/roof_glazing":sealed+=1
	verify(sealed==samples,"18 interior-to-sky rays hit the actual continuous glass roof collider")
	var infill:=0
	for p in [Vector3(-7,12,-8),Vector3(7,12,-8),Vector3(-7,12,8),Vector3(7,12,8),Vector3(0,12,-12),Vector3(0,12,12)]:
		var hit:Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(Q.point(p),Q.point(p+Vector3.UP*12)))
		visual_geometry_evidence.append({"kind":"dome_roof_infill","local_probe":[p.x,p.y,p.z],"first_physical_id":str(hit.collider.get_meta("damage_id","")) if not hit.is_empty() else "none"})
		if not hit.is_empty() and str(hit.collider.get_meta("damage_id","")) in roof_ids:infill+=1
	verify(infill==6,"all six former dome-to-arcade sky gaps have physical roof infill")
	var opaque_cover:=0
	for p in [Vector3(1.4,3,1.6),Vector3(0,3,-3.5),Vector3(5,3,0)]:
		var hit:=visible_surface(world,Q.point(p),Q.point(p+Vector3.UP*50),world.structures.keys())
		visual_geometry_evidence.append({"kind":"inner_dome_first_visible_surface","local_probe":[p.x,p.y,p.z],"first_material":world.materials.find_key(hit.get("material")),"first_id":hit.get("id","")})
		if hit.is_empty() or not hit.material in [world.materials.qvb_amber,world.materials.qvb_green]:opaque_cover+=1
	verify(opaque_cover==0,"actual first visible surface above the atrium is coloured inner-dome glass, not an opaque patch")
	var lattice:=visible_surface(world,Q.point(Vector3(0,12,40)),Q.point(Vector3(0,30,40)),["city/qvb/roof_glazing"])
	var pane:=visible_surface(world,Q.point(Vector3(2.7,12,41)),Q.point(Vector3(2.7,30,41)),["city/qvb/roof_glazing"])
	verify(not lattice.is_empty() and lattice.material==world.materials.qvb_cream and not pane.is_empty() and pane.material==world.materials.qvb_roof_glass,"actual first-visible roof alternates exposed inner framing and glass panes; no grey cover hides the trusses")
	var exterior:=visible_surface(world,Q.point(Vector3(20,23,0)),Q.point(Vector3(0,23,0)),["city/qvb/roof_transition"])
	var interior:=visible_surface(world,Q.point(Vector3(0,23,0)),Q.point(Vector3(20,23,0)),["city/qvb/roof_transition"])
	verify(not exterior.is_empty() and exterior.material==world.materials.qvb_stone and not interior.is_empty() and interior.material==world.materials.qvb_red,"central spacer shows sandstone externally and red finish only towards the public inner dome")
	var main_id:=["osm/way/40717424/storey_group/0"]
	var edge:float=Q._edge_x(-33.0,1.0)
	var visible_arch:=visible_surface(world,Q.point(Vector3(edge+3,15.4,-33)),Q.point(Vector3(edge-1,15.4,-33)),main_id)
	verify(not visible_arch.is_empty() and visible_arch.material==world.materials.qvb_trim and visible_arch.position.x>Q.point(Vector3(edge,15.4,-33)).x,"George arch relief is actually the first rendered mesh ahead of the full wall")
	var glass:=visible_surface(world,Q.point(Vector3(edge+3,9,-31.78)),Q.point(Vector3(edge-1,9,-31.78)),main_id)
	verify(not glass.is_empty() and glass.material==world.materials.qvb_glass,"arched street glazing survives the final mesh index stream")
	var arcade:=visible_surface(world,Q.point(Vector3(3,5.2,-35)),Q.point(Vector3(7,5.2,-35)),main_id)
	verify(not arcade.is_empty() and arcade.material==world.materials.qvb_cream,"interior round arch is visible ahead of closed shop volume and glass")
	var clear:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Q.point(Vector3(3,4.8,-97)),Q.point(Vector3(3,4.8,-92))))
	var blocked:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Q.point(Vector3(3,5.6,-97)),Q.point(Vector3(3,5.6,-92))))
	verify(clear.is_empty() and not blocked.is_empty(),"Market doorway has an actual curved opening: lower shoulder clear, upper spandrel solid")
	for id in roof_ids:
		var node:StaticBody3D=world.structures[id].node
		verify(Migration._closed_mesh(node.get_child(1).shape.get_faces()),id+" has a closed physical skin")
		world._destroy_component(id,Vector3.ZERO,0,false);await physics_frame
		verify(not node.visible and node.get_child(1).disabled,id+" hides glazing and frames and disables collision together")
	world.apply_state({});await physics_frame

func capture_views(world:Node3D) -> void:
	root.size=Vector2i(1440,900)
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("96b5c5")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("dbe5e9");env.ambient_light_energy=.65
	environment.environment=env;world.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-40,0);sun.light_energy=1.25;sun.shadow_enabled=true;world.add_child(sun)
	world._build_structure_batches()
	var camera:=Camera3D.new();camera.current=true;camera.fov=55;world.add_child(camera)
	var dir:=ProjectSettings.globalize_path("res://../reports/qvb-public/v4-preview");DirAccess.make_dir_recursive_absolute(dir)
	var captures:=[]
	for row in Q.capture_views():
		camera.global_position=row[1];camera.look_at(row[2])
		for frame in 10:await process_frame
		await RenderingServer.frame_post_draw
		var path:String=dir+"/"+row[0]+".png"
		root.get_texture().get_image().save_png(path)
		captures.append({"name":row[0],"position":[row[1].x,row[1].y,row[1].z],"target":[row[2].x,row[2].y,row[2].z],"sha256":FileAccess.get_sha256(path)})
	var manifest:={"capture_only":"--capture-only" in OS.get_cmdline_user_args(),"model_sha256":FileAccess.get_sha256("res://scripts/qvb_public.gd"),"fixture_sha256":FileAccess.get_sha256("res://../source/qvb_public_test.gd"),"captures":captures}
	FileAccess.open(dir+"/capture-manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
