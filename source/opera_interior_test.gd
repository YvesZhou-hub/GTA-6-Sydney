extends SceneTree
const Exterior=preload("res://scripts/opera_landmark.gd")
const Interior=preload("res://scripts/opera_interiors.gd")
var checks:Array=[]
class MigrationProbe extends Node3D:
	var world:Node3D
	var player:CharacterBody3D
class ProbeWorld extends "res://scripts/harbor_world.gd":
	func _ready():
		_make_materials()
		if "--interior-only" in OS.get_cmdline_user_args():
			# Temporary fixture only, while the separately owned exterior is edited.
			_structure_box("fixture/ground",Interior.point(Vector3(0,-.12,0)),Vector3(140,.24,220),"sandstone",100000,Interior.basis())
			var xs:Array=[-60.0,-10.5,-3.5,15.0,31.0,60.0]
			var zs:Array=[-85.0,4.0,8.0,37.0,59.5,66.0]
			for i in range(xs.size()-1):
				for j in range(zs.size()-1):
					if (i==1 and j==3) or (i==3 and j==1):continue
					_structure_box("fixture/upper_%s_%s"%[i,j],Interior.point(Vector3((xs[i]+xs[i+1])*.5,11.08,(zs[j]+zs[j+1])*.5)),Vector3(xs[i+1]-xs[i],.24,zs[j+1]-zs[j]),"sandstone",100000,Interior.basis())
		else:
			Exterior.build(self)
			# Local test context substitutes only the existing outside promenade ground.
			_structure_box("fixture/west_promenade",Interior.point(Vector3(-62.5,-.12,53)),Vector3(5,.24,14),"sandstone",100000,Interior.basis())
		Interior.build(self)
		_flush_batches()
		for record:Dictionary in structures.values():
			for child in record.node.get_children():
				if child is MeshInstance3D:child.set_meta("intact_material",child.material_override)
		_build_structure_batches()
		_ready_complete=true
func _initialize():
	for action:String in ["left","right","forward","back","sprint","jump"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	call_deferred("run")
func verify(name:String,ok:bool,detail:Dictionary={}):
	checks.append({"name":name,"passed":ok,"detail":detail});print("OPERA_INTERIOR ","PASS " if ok else "FAIL ",name," ",JSON.stringify(detail))
func run():
	var world:=ProbeWorld.new();root.add_child(world)
	await physics_frame;await physics_frame
	verify("exterior and interior share mapped frame",Interior.CENTER==Exterior.CENTER and Interior.ANGLE==Exterior.ANGLE)
	verify("four interior navigation destinations are registered",world.get_meta("opera_interiors",[]).size()==4)
	var component_count:=0
	for id:String in world.structures:
		if id.begins_with("opera/interior/"):component_count+=1
	verify("independent floors, walls, stages, tiers and stairs have collision",component_count>150,{"components":component_count})
	if "--visual-only" in OS.get_cmdline_user_args():
		await capture(world);quit(0);return
	var space:=world.get_world_3d().direct_space_state
	verify("ticket ceiling has folded concrete profiles",world.get_meta("opera_ticket_folded_beams",0)==22)
	for foyer:String in ["concert_foyer","jst_foyer"]:
		verify(foyer+" broad flight uses real curved treads",world.structures["opera/interior/"+foyer+"/broad_stairs"].node.get_meta("curved_carpet_treads",0)==14)
	# The local fixture has no generic city buildings. Feed its actual authored
	# colliders to the production migration checker, not a synthetic landing box.
	world.map_snapshot={"buildings":[]}
	var migration=load("res://scripts/map_migration.gd")
	var proxy:=MigrationProbe.new();root.add_child(proxy);proxy.world=world
	proxy.player=load("res://scripts/harbor_player.gd").new();proxy.add_child(proxy.player)
	for p:Vector3 in [Vector3(-26,13.4,-60.2),Vector3(23,13.4,-48.2)]:
		var buried:=Interior.point(p-Vector3.UP*.15)
		var safe:=Interior.point(p+Vector3.UP*.04)
		verify("new landing buried player is identified "+str(p.x),migration._player_needs_relocation(proxy,buried))
		verify("new landing safely standing player stays "+str(p.x),not migration._player_needs_relocation(proxy,safe))
	for spec:Array in [[-26.0,18.0*.775,-77.0,-59.0],[23.0,14.0*.775,-62.0,-47.0]]:
		for u in [0.0,-.75,.75]:
			var mid:Vector3=Interior._foyer_stair_p(spec[0],spec[1],spec[2],spec[3],u,.5)
			proxy.player.global_position=Interior.point(mid+Vector3.UP*.08)
			proxy.player.velocity=Vector3.ZERO;proxy.player.reset_physics_interpolation();proxy.player.enabled=true
			for frame in 30:await physics_frame
			proxy.player.enabled=false
			var settled:Vector3=proxy.player.global_position
			var occupied:bool=migration._player_needs_relocation(proxy,settled)
			verify("foyer actual settled slope player stays cx=%s u=%s"%[spec[0],u],proxy.player.is_on_floor() and not occupied,{"local_position":Interior.basis().inverse()*(settled-Interior.CENTER),"on_floor":proxy.player.is_on_floor(),"needs_relocation":occupied})
			verify("foyer slope buried 4cm player is identified cx=%s u=%s"%[spec[0],u],migration._player_needs_relocation(proxy,settled-Vector3.UP*.04))
	proxy.queue_free();await physics_frame
	if "--migration-only" in OS.get_cmdline_user_args():
		var path:=ProjectSettings.globalize_path("res://../reports/opera-v016-migration.json")
		FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"execution_flags":OS.get_cmdline_user_args(),"continuous_walks_ran":false,"scope":"Local complete Opera geometry; actual settled production capsules and migration decisions only","user_saves_touched":false},"  "))
		print("OPERA_MIGRATION COMPLETE ",checks.size()," CHECKS / ",checks.filter(func(c):return not c.passed).size()," FAILURES")
		quit(0 if checks.all(func(c):return c.passed) else 1);return
	for route:Dictionary in Interior.walk_routes():
		var filter:String=""
		for argument:String in OS.get_cmdline_user_args():
			if argument.begins_with("--route-filter="):filter=argument.trim_prefix("--route-filter=")
		if not filter.is_empty() and not route.name.contains(filter):continue
		var blocked:Array=[];var missing:Array=[]
		for segment in range(route.points.size()-1):
			var a:Vector3=route.points[segment];var b:Vector3=route.points[segment+1];var steps:=ceili(a.distance_to(b)/.6)
			for sample in range(steps+1):
				var p:Vector3=a.lerp(b,float(sample)/steps)
				var body:=CapsuleShape3D.new();body.radius=.32;body.height=1.78
				var q:=PhysicsShapeQueryParameters3D.new();q.shape=body;q.transform.origin=p+Vector3.UP*1.02;q.collision_mask=1
				var hits:=space.intersect_shape(q)
				if not hits.is_empty() and blocked.size()<8:blocked.append({"position":p,"local_position":Interior.basis().inverse()*(p-Interior.CENTER),"hits":hits.map(func(h):return str(h.collider.name))})
				var support:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.4,p-Vector3.UP*.55,1))
				if support.is_empty() and missing.size()<8:missing.append(p)
		verify(route.name+" capsule route clearance",blocked.is_empty(),{"blocked":blocked})
		verify(route.name+" continuous floor",missing.is_empty(),{"missing":missing})
		if not "--geometry-only" in OS.get_cmdline_user_args():await walk(world,route)
	for view:Array in Interior.capture_views():
		var shape:=SphereShape3D.new();shape.radius=.1
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=view[1];query.collision_mask=1
		var hits:=space.intersect_shape(query)
		verify(view[0]+" camera lies in clear interior space",hits.is_empty(),{"hits":hits.map(func(h):return str(h.collider.name))})
	if not "--interior-only" in OS.get_cmdline_user_args():check_external_envelopes(world)
	for view:Array in Interior.capture_views():
		if view[0] not in ["opera-concert-hall","opera-joan-sutherland"]:continue
		var sightline:PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(view[1],view[2],1)
		sightline.hit_back_faces=true
		var obstruction:Dictionary=space.intersect_ray(sightline)
		verify(view[0]+" clear audience view towards stage",obstruction.is_empty(),{"obstruction":str(obstruction.get("collider","none")),"point":obstruction.get("position",Vector3.ZERO)})
	verify("all 18 photographed acoustic reflectors are represented",world.get_meta("opera_concert_reflectors",0)==18)
	# The two venues retain opaque acoustic linings between seating and glazing.
	for hall:Array in [["Concert",Vector3(-26,15,10),Vector3(-26,24,-45)],["JST",Vector3(23,19,1),Vector3(23,23,-45)]]:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Interior.point(hall[1]),Interior.point(hall[2]),1))
		verify(hall[0]+" audience sightline meets inner acoustic wall",not hit.is_empty() and hit.collider.get_meta("opera_acoustic_enclosure",false),{"hit":str(hit.get("collider","none"))})
	# The dark stage housing must enclose both sides behind the proscenium.
	for side in [-1,1]:
		var ray:PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(Interior.point(Vector3(23+side*12,17,12)),Interior.point(Vector3(23+side*12,17,35)),1)
		var hit:Dictionary=space.intersect_ray(ray)
		verify("JST stage rear enclosure "+str(side),not hit.is_empty() and hit.collider.get_meta("opera_acoustic_enclosure",false),{"hit":str(hit.get("collider","none"))})
	# Stage-front dimensions are physical 0.9m elevation, not a painted floor.
	for cx in [-26.0,23.0]:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Interior.point(Vector3(cx,14,18)),Interior.point(Vector3(cx,10,18)),1))
		verify("raised playable stage "+str(cx),not hit.is_empty() and absf(hit.position.y-(Interior.CENTER.y+Interior.STAGE))<.03)
	if "--capture" in OS.get_cmdline_user_args():await capture(world)
	var folder:=ProjectSettings.globalize_path("res://../reports/opera-interiors");DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"execution_flags":OS.get_cmdline_user_args(),"continuous_walks_ran":not "--geometry-only" in OS.get_cmdline_user_args(),"physics_engine":ProjectSettings.get_setting("physics/3d/physics_engine"),"components":component_count,"concert_seats":world.get_meta("opera_concert_seats"),"jst_seats":world.get_meta("opera_jst_seats"),"fixture_mode":"temporary_interior_only" if "--interior-only" in OS.get_cmdline_user_args() else "complete_exterior_and_interiors","user_saves_touched":false},"  "))
	print("OPERA_INTERIOR COMPLETE ",checks.size()," CHECKS / ",checks.filter(func(c):return not c.passed).size()," FAILURES")
	quit(0 if checks.all(func(c):return c.passed) else 1)
func walk(world:Node3D,route:Dictionary):
	var player=load("res://scripts/harbor_player.gd").new();world.add_child(player);player.position=route.points[0]+Vector3.UP*.08;player.enabled=true;player.last_safe=player.position
	for i in 15:await physics_frame
	var points:Array=route.points.slice(1);var failures:Array=[]
	for phase in 2:
		for target:Vector3 in points:
			var arrived:=false;Input.action_press("forward")
			for frame in 1600:
				var d:=Vector3(target.x-player.position.x,0,target.z-player.position.z)
				if d.length()<.36:arrived=true;break
				player.yaw=atan2(-d.x,-d.z);await physics_frame
			Input.action_release("forward")
			if not arrived or absf(player.position.y-target.y)>.40:
				var contacts:Array=[]
				for collision_index in player.get_slide_collision_count():
					var contact:KinematicCollision3D=player.get_slide_collision(collision_index)
					contacts.append({"collider":str(contact.get_collider().name),"local_position":Interior.basis().inverse()*(contact.get_position()-Interior.CENTER),"local_normal":Interior.basis().inverse()*contact.get_normal()})
				failures.append({"target":target,"actual":player.position,"arrived":arrived,"contacts":contacts});break
		var endpoint:Vector3=route.points[-1] if phase==0 else route.points[0]
		verify(route.name+(" actual player enters" if phase==0 else " actual player returns"),failures.is_empty() and player.position.distance_to(endpoint)<.6,{"failures":failures})
		if not failures.is_empty():break
		points=route.points.duplicate();points.reverse();points=points.slice(1)
	player.queue_free();await physics_frame
func capture(world:Node3D):
	root.size=Vector2i(1440,900)
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("8bbad3");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("dde5e8");env.ambient_light_energy=.48;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var environment:=WorldEnvironment.new();environment.environment=env;world.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.2;sun.shadow_enabled=true;world.add_child(sun)
	var camera:=Camera3D.new();camera.current=true;camera.fov=76;camera.far=1000;world.add_child(camera)
	var folder:=ProjectSettings.globalize_path("res://../reports/opera-interiors/native");DirAccess.make_dir_recursive_absolute(folder)
	for view:Array in Interior.capture_views():
		camera.position=view[1];camera.look_at(view[2]);await process_frame;await process_frame
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png(folder+"/"+view[0]+".png");print("OPERA_INTERIOR CAPTURE ",view[0])

func check_external_envelopes(world:Node3D) -> void:
	# Inspect actual external triangles, including decorative blade meshes which
	# collision-only camera tests cannot see. A 0.5m barycentric grid tests the
	# occupied hall volume; 0.15m wall inset avoids classifying shared joints as leaks.
	var room_hits:Dictionary={"Concert":[],"JST":[]}
	var samples:int=0
	var inverse:Transform3D=Transform3D(Interior.basis(),Interior.CENTER).affine_inverse()
	for id:String in world.structures:
		if not (id.begins_with("opera/shell/") or id.begins_with("opera/infill/") or id.begins_with("opera/glass/")):continue
		var body:Node3D=world.structures[id].node
		for child:Node in body.get_children():
			if not child is MeshInstance3D or child.mesh==null or child.get_meta("collision_only",false):continue
			var frame:Transform3D=inverse*child.global_transform
			var vertices:PackedVector3Array=child.mesh.get_faces()
			for face in range(0,vertices.size(),3):
				var a:Vector3=frame*vertices[face];var b:Vector3=frame*vertices[face+1];var c:Vector3=frame*vertices[face+2]
				if maxf(a.y,maxf(b.y,c.y))<11.35 or minf(a.y,minf(b.y,c.y))>38.0:continue
				var divisions:int=maxi(1,ceili(maxf(a.distance_to(b),maxf(b.distance_to(c),c.distance_to(a)))/.5))
				for i in range(divisions+1):
					for j in range(divisions+1-i):
						var p:Vector3=a+(b-a)*(float(i)/divisions)+(c-a)*(float(j)/divisions)
						samples+=1
						var room:String=""
						if absf(p.x+26)<Interior.concert_half_width(p.z)-.18 and p.z> -36.8 and p.z<30.8 and p.y>11.35 and p.y<Interior._concert_ceiling_y(p.x+26,p.z)-.15:room="Concert"
						if p.x>8.50 and p.x<37.50 and p.z> -36.8 and p.z<31.8 and p.y>11.35 and p.y<23.55:room="JST"
						if not room.is_empty() and room_hits[room].size()<12:room_hits[room].append({"id":id,"local_point":p})
	for room:String in room_hits:verify(room+" external shells and louvres stay outside acoustic room",room_hits[room].is_empty(),{"samples":samples,"intrusions":room_hits[room]})
