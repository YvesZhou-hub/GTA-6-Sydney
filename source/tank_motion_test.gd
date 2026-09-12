extends SceneTree
## Real Jolt rigid-body trajectories using the exact TankMotion and TankModels.
## Adapter exists while the root integrates kind=tank into HarborVehicle.
const Motion=preload("res://scripts/tank_motion.gd")
const TankModels=preload("res://scripts/tank_models.gd")
const Factory=preload("res://scripts/vehicle_factory.gd")
var stage:Node3D
var checks:Array=[]
var failures:=0
class Tank extends "res://scripts/harbor_vehicle.gd":
	var test_power:=0.0
	var test_steer:=0.0
	var test_brake:=false
	func _ready() -> void:
		kind="tank";occupied=true;collision_layer=4;collision_mask=15
		continuous_cd=true;contact_monitor=true;max_contacts_reported=8
		Motion.setup(self)
		var mats:={"metal":Factory.material(Color("a1a8a4"),.8,.35),"red":Factory.material(Color("bb443a")),"light":Factory.material(Color("fff3d0"))}
		_moving={"wheels":[],"rotors":[],"propellers":[],"rider":null}
		TankModels.build(self,mats,_moving,Factory)
	func _physics_process(delta:float) -> void:
		Motion.tick(self,delta,-global_basis.z,global_basis.x,global_basis.y,test_power,test_steer,0.0,test_brake)
		speed_kmh=linear_velocity.length()*3.6
		for wheel in _moving.wheels:
			var speed:float=get_meta("tank_track_left_speed") if wheel.get_meta("tank_side")<0 else get_meta("tank_track_right_speed")
			wheel.rotate_x(-speed*delta/float(wheel.get_meta("radius")))
	func _integrate_forces(_state:PhysicsDirectBodyState3D) -> void:
		# Combat/damage is deliberately outside this movement-only adapter.
		pass

func _initialize():call_deferred("run")
func verify(name:String,passed:bool,evidence:Dictionary={}) -> void:
	checks.append({"name":name,"passed":passed,"evidence":evidence})
	print("PASS " if passed else "FAIL ",name," ",JSON.stringify(evidence))
	if not passed:failures+=1
func frames(n:int) -> void:
	for i in n:await physics_frame
func box(size:Vector3,p:Vector3,rotation:=Vector3.ZERO) -> StaticBody3D:
	var body:=StaticBody3D.new();var col:=CollisionShape3D.new();var shape:=BoxShape3D.new()
	shape.size=size;col.shape=shape;body.add_child(col);body.position=p;body.rotation=rotation;stage.add_child(body);return body
func reset(flat:bool=true) -> void:
	if is_instance_valid(stage):stage.queue_free();await process_frame
	stage=Node3D.new();root.add_child(stage)
	if flat:box(Vector3(400,2,5000),Vector3(0,-1,0))
	await physics_frame
func spawn(at:Vector3) -> Tank:
	var v:=Tank.new();v.position=at;stage.add_child(v);return v
func pose(v:RigidBody3D) -> Dictionary:
	return {"position":[v.position.x,v.position.y,v.position.z],"speed_kmh":v.linear_velocity.length()*3.6,"roll":v.rotation.z,"pitch":v.rotation.x,"yaw":v.rotation.y,"grounded":v.grounded,"angular_speed":v.angular_velocity.length()}
func inspect_geometry(v:Tank) -> void:
	var moving:Dictionary=v._moving
	verify("turret/barrel/muzzle are independent nested pivots",moving.turret.get_parent()==v and moving.barrel.get_parent()==moving.turret and moving.muzzle.get_parent()==moving.barrel)
	var before:Vector3=moving.muzzle.global_position
	moving.turret.rotation.y=PI*.5;moving.barrel.rotation.x=deg_to_rad(18)
	var aimed:Vector3=-moving.muzzle.global_basis.z
	verify("yaw and elevation propagate to the actual muzzle transform",aimed.x<-.93 and aimed.y>.30 and absf(aimed.z)<.02 and moving.muzzle.global_position.distance_to(before)>5,{"direction":[aimed.x,aimed.y,aimed.z]})
	moving.turret.rotation=Vector3.ZERO;moving.barrel.rotation=Vector3.ZERO
	verify("18 running gear pivots carry side and wheel-radius metadata",moving.wheels.size()==18)
	var overlap:=false
	for side in [-1.0,1.0]:
		var wheels:Array=[]
		for wheel in moving.wheels:
			if wheel.get_meta("tank_side")==side:wheels.append(wheel)
		for a in wheels:
			for b in wheels:
				if a==b:continue
				if a.position.distance_to(b.position)<float(a.get_meta("radius"))+float(b.get_meta("radius"))-.01:overlap=true
	verify("road wheels and end wheels do not intersect each other",not overlap)
	var meshes:Array=[];Factory._gather_static_meshes(v,[],meshes)
	var triangles:=0;var degenerates:=0;var inverted:=0;var bounds:=AABB();var have_bounds:=false
	for view:MeshInstance3D in meshes:
		var relative:Transform3D=v.global_transform.affine_inverse()*view.global_transform
		var aabb:AABB=relative*view.mesh.get_aabb();bounds=aabb if not have_bounds else bounds.merge(aabb);have_bounds=true
		var faces:=view.mesh.get_faces();triangles+=faces.size()/3
		for i in range(0,faces.size(),3):
			if (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length_squared()<1e-12:degenerates+=1
		for si in view.mesh.get_surface_count():
			var a=view.mesh.surface_get_arrays(si);var vs:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=a[Mesh.ARRAY_NORMAL];var ids:PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			for i in range(0,ids.size() if not ids.is_empty() else vs.size(),3):
				var ia:int=ids[i] if not ids.is_empty() else i;var ib:int=ids[i+1] if not ids.is_empty() else i+1;var ic:int=ids[i+2] if not ids.is_empty() else i+2
				if (vs[ib]-vs[ia]).cross(vs[ic]-vs[ia]).dot(ns[ia]+ns[ib]+ns[ic])>.00001:inverted+=1
	verify("original tank meshes contain no degenerate or reversed faces",degenerates==0 and inverted==0,{"triangles":triangles,"degenerate":degenerates,"reversed":inverted,"mesh_count_before_factory_merge":meshes.size()})
	verify("tank geometry remains within declared practical spawn envelope",bounds.position.y> -1.06 and bounds.size.x<4.2 and bounds.size.z<10.5 and bounds.end.y<3.1,{"min":[bounds.position.x,bounds.position.y,bounds.position.z],"max":[bounds.end.x,bounds.end.y,bounds.end.z]})
	# Reproduce the required factory merge boundary, including nested aiming.
	var pivots:Array=moving.wheels+[moving.barrel,moving.turret]
	for pivot in pivots:Factory._merge_static_meshes(pivot,pivots)
	Factory._merge_static_meshes(v,pivots)
	await process_frame
	meshes.clear();Factory._gather_static_meshes(v,[],meshes)
	var merged_triangles:=0
	for view:MeshInstance3D in meshes:merged_triangles+=view.mesh.get_faces().size()/3
	verify("material merging preserves every triangle and animated pivot",merged_triangles==triangles and meshes.size()<100 and moving.barrel.get_parent()==moving.turret and moving.muzzle.get_parent()==moving.barrel,{"triangles":merged_triangles,"draw_meshes":meshes.size()})

func run() -> void:
	if "--capture-only" in OS.get_cmdline_user_args():
		await capture();return
	await reset();var tank:=spawn(Vector3(0,1.1,0));await frames(120)
	await inspect_geometry(tank)
	verify("tank settles on actual rigid track contacts",tank.grounded and tank.linear_velocity.length()<.2 and absf(tank.position.y-.96)<.06,pose(tank))
	tank.test_power=1.0
	var max_tilt:=0.0;var airborne:=0
	for i in 1800:
		await physics_frame;max_tilt=maxf(max_tilt,acos(clampf(tank.global_basis.y.dot(Vector3.UP),-1,1)))
		if not tank.grounded:airborne+=1
	verify("forward drive reaches approximately110kmh through forces",tank.speed_kmh>104 and tank.speed_kmh<116 and tank.position.z< -450 and max_tilt<.15 and airborne<5,pose(tank).merged({"max_tilt":max_tilt,"airborne_frames":airborne}))
	var brake_start:=tank.position;tank.test_power=0;tank.test_brake=true;await frames(300)
	verify("brake stops full-speed tank without teleporting",tank.speed_kmh<1.0 and tank.position.distance_to(brake_start)<55,pose(tank).merged({"stopping_distance":tank.position.distance_to(brake_start)}))
	tank.test_brake=false;tank.test_power=-1;await frames(720)
	verify("reverse tracks reach controlled reverse speed",tank.linear_velocity.dot(-tank.global_basis.z)< -10.0 and tank.speed_kmh<47,pose(tank))
	tank.test_power=0;tank.test_brake=true;await frames(240)
	var turn_start:=tank.position;var yaw_before:=tank.rotation.y;tank.test_brake=false;tank.test_steer=1;await frames(240)
	verify("differential tracks pivot at rest with little translation",absf(wrapf(tank.rotation.y-yaw_before,-PI,PI))>1.0 and tank.position.distance_to(turn_start)<2.0 and absf(tank.rotation.z)<.12,pose(tank).merged({"translation":tank.position.distance_to(turn_start)}))
	verify("pivot turn sends opposite motion to left/right wheels",float(tank.get_meta("tank_track_left_speed"))*float(tank.get_meta("tank_track_right_speed"))<0)
	# A long tilted solid is a genuine25degree slope; the tank is placed once
	# and subsequently climbs, stops, parks and descends through physics only.
	await reset(false)
	var slope:=deg_to_rad(25.0)
	box(Vector3(30,2,360),Vector3(0,22,0),Vector3(slope,0,0))
	var start_z:=35.0;var surface_y:=22.0-tan(slope)*start_z+1.0/cos(slope)
	tank=spawn(Vector3(0,surface_y+1.13,start_z));tank.rotation.x=slope;await frames(180)
	var normal:=Vector3(0,cos(slope),sin(slope));var ascent_start:=tank.position;tank.test_power=.48
	var worst_alignment:=1.0
	for i in 660:await physics_frame;worst_alignment=minf(worst_alignment,tank.global_basis.y.dot(normal))
	verify("tank climbs a25degree physical ramp without being forced level",tank.position.y>ascent_start.y+8 and tank.position.z<ascent_start.z-20 and worst_alignment>.94 and tank.grounded,pose(tank).merged({"up_dot_surface":worst_alignment,"height_gain":tank.position.y-ascent_start.y}))
	tank.test_power=0;tank.test_brake=true;await frames(180);var parked:=tank.position;await frames(240)
	verify("parking brake holds on a25degree incline",tank.position.distance_to(parked)<.35 and tank.speed_kmh<.6,pose(tank).merged({"drift":tank.position.distance_to(parked)}))
	tank.test_brake=false;tank.test_power=-.60;var descending:=tank.position;await frames(540)
	verify("reverse descends the incline with stable ground contact",tank.position.y<descending.y-5 and tank.grounded and tank.global_basis.y.dot(normal)>.94,pose(tank))
	# Crossing a slope boundary exercises normal averaging and real contact,
	# unlike starting with the tank already aligned to an incline.
	await reset()
	var entry_angle:=deg_to_rad(15.0)
	box(Vector3(30,2,80),Vector3(0,40*sin(entry_angle)-cos(entry_angle),-40*cos(entry_angle)),Vector3(entry_angle,0,0))
	tank=spawn(Vector3(0,1.1,18));await frames(120);tank.test_power=.25
	var max_transition_roll:=0.0
	for i in 660:await physics_frame;max_transition_roll=maxf(max_transition_roll,absf(tank.rotation.z))
	verify("tank drives from level ground onto a15degree ramp",tank.position.z< -35 and tank.position.y>9 and tank.grounded and absf(tank.rotation.x-entry_angle)<.08 and max_transition_roll<.12,pose(tank).merged({"max_roll":max_transition_roll}))
	await reset(false)
	var bank:=deg_to_rad(15.0);box(Vector3(60,2,350),Vector3(0,10,0),Vector3(0,0,bank))
	tank=spawn(Vector3(0,10+1.0/cos(bank)+1.12,30));tank.rotation.z=bank;await frames(180);tank.test_power=.3
	var bank_start:=tank.position;await frames(480)
	verify("side-slope driving resists downhill sideways slip",tank.position.z<bank_start.z-40 and absf(tank.position.x-bank_start.x)<2.0 and tank.grounded and absf(tank.rotation.z-bank)<.06,pose(tank).merged({"lateral_drift":tank.position.x-bank_start.x}))
	# Negative case: ground propulsion must not create a flying tank.
	await reset();tank=spawn(Vector3(0,15,0));tank.test_power=1.0;await frames(45)
	verify("airborne tank receives no unsupported forward propulsion",not tank.grounded and absf(tank.position.z)<.03 and tank.linear_velocity.y< -5,pose(tank))
	var report:={"passed":failures==0,"checks":checks,"count":checks.size(),"failures":failures,"scope":"Actual Jolt rigid contacts and TankMotion forces in a bounded adapter fixture; combat and whole-city integration verified separately","physics_hz":Engine.physics_ticks_per_second,"hashes":{}}
	for path in ["res://scripts/tank_models.gd","res://scripts/tank_motion.gd","res://scripts/harbor_vehicle.gd","res://scripts/vehicle_factory.gd","res://../source/tank_motion_test.gd"]:report.hashes[path]=FileAccess.get_sha256(path)
	var directory:=ProjectSettings.globalize_path("res://../reports/tank");DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory+"/motion-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("TANK_MOTION_COMPLETE checks=",checks.size()," failures=",failures)
	stage.queue_free();await process_frame;quit(1 if failures else 0)

func capture() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Tank capture requires the root-coordinated native GPU run");quit(1);return
	await reset()
	var floor_view:=MeshInstance3D.new();var floor_mesh:=BoxMesh.new();floor_mesh.size=Vector3(70,.10,70)
	floor_view.mesh=floor_mesh;floor_view.position.y=-.06;floor_view.material_override=Factory.material(Color("737a76"),0,.9);stage.add_child(floor_view)
	var v:=Factory.make("tank","tank_capture");v.position.y=1.01;v.freeze=true;stage.add_child(v)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("a6bfcc")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("d9e5e9");environment.environment.ambient_light_energy=.65
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-32,0);sun.light_energy=1.6;sun.shadow_enabled=true;stage.add_child(sun)
	var camera:=Camera3D.new();camera.fov=48;camera.far=300;stage.add_child(camera);camera.make_current()
	root.size=Vector2i(1600,1000);DisplayServer.window_set_size(Vector2i(1600,1000))
	var directory:=ProjectSettings.globalize_path("res://../reports/tank/native");DirAccess.make_dir_recursive_absolute(directory)
	var views:=[{"name":"tank-front","position":Vector3(11,7,-14),"target":Vector3(0,1.5,-.5)},{"name":"tank-tracks","position":Vector3(-11,3,2),"target":Vector3(0,1.2,-.2)},{"name":"tank-rear","position":Vector3(9,7,12),"target":Vector3(0,1.5,.5)},{"name":"tank-aim","position":Vector3(8,6,-11),"target":Vector3(-.8,2.3,-1.7)}]
	for view in views:
		if view.name=="tank-aim":v._moving.turret.rotation.y=deg_to_rad(35);v._moving.barrel.rotation.x=deg_to_rad(18)
		camera.position=view.position;camera.look_at(view.target)
		for i in 8:await process_frame
		await RenderingServer.frame_post_draw
		var path:String=directory+"/"+view.name+".png";root.get_texture().get_image().save_png(path);print("TANK_CAPTURE ",path)
	print("TANK_CAPTURE_COMPLETE4 model_sha=",FileAccess.get_sha256("res://scripts/tank_models.gd"))
	stage.queue_free();await process_frame;quit(0)
