extends SceneTree
const Migration=preload("res://scripts/map_migration.gd")
const City=preload("res://scripts/city_map.gd")
const Geo=preload("res://scripts/city_landmarks.gd")
const Spawn=preload("res://scripts/vehicle_spawn.gd")
const Store=preload("res://scripts/save_store.gd")
const Tower=preload("res://scripts/sydney_tower_landmark.gd")
const QuayDetail=preload("res://scripts/circular_quay_detail.gd")
const DarlingDetail=preload("res://scripts/darling_square_detail.gd")
const Opera=preload("res://scripts/opera_landmark.gd")
class LocalWorld:
	extends "res://scripts/harbor_world.gd"
	func _ready():
		_make_materials()
		anchors={"home":Vector3(1800,4.5,1800),"marina":Vector3(1700,1,1700),"north":Vector3(1800,4.5,1850),"helipad":Vector3(1850,4.5,1800)}
		var ground:=StaticBody3D.new();ground.name="MigrationGround";add_child(ground)
		var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(2000,.2,2000);collider.shape=shape
		ground.add_child(collider);ground.position=Vector3(2200,GROUND-.1,2200)
		map_snapshot={"buildings":[],"roads":[],"land":[],"places":[]}
		add_block("way/qa_tall",Vector2(2000,2000),1000)
		add_block("way/qa_distant",Vector2(2500,2500),35)
		add_block("way/qa_court",Vector2(2080,2000),35,0,[[[-7,-7],[-7,7],[7,7],[7,-7]]])
		add_block("way/qa_high",Vector2(2160,2000),60,30)
		add_block("way/qa_roof",Vector2(2400,2000),43)
		var pitched:Dictionary=map_snapshot.buildings[-1]
		pitched.wall_height=35.0
		# Four pitched panels + two gable infills, deliberately crossing the
		# old ceil(total_height/18) boundary (walls=2 groups, total=3).
		var a=[-10,35,-10];var b=[10,35,-10];var c=[10,35,10];var d=[-10,35,10]
		var e=[0,43,-10];var f=[0,43,10]
		pitched.roof_surface=[a,e,f,a,f,d,e,b,c,e,c,f,a,b,e,d,f,c]
		for item in City.data().buildings:
			if int(str(item.id).get_slice("/",1)) in Tower.excluded_way_ids():map_snapshot.buildings.append(item)
		City.build_buildings(self,map_snapshot)
		var poly:=PackedVector2Array([Vector2(-10,-10),Vector2(10,-10),Vector2(10,10),Vector2(-10,10)])
		_structure_mesh("bank/qa_closed/lobby",Geo.prism(poly,0,40),Vector3(2240,GROUND,2000),"concrete")
		_structure_box("metro/qa_column",Vector3(2280,GROUND+5,2000),Vector3(6,10,6),"concrete")
		_structure_mesh("city/qa_overhang/floor",Geo.prism(poly,15,20),Vector3(2320,GROUND,2000),"concrete")
		# Actual v0.1.3 authored meshes exercise new damage namespaces, including
		# complete containment that a collision-shell query cannot detect alone.
		Tower.build(self)
		QuayDetail.build(self)
		DarlingDetail.build(self)
		# Only the production monumental stair, not a full-city/Opera-shell build.
		_mat("opera_granite",Color("b5a18b"),.86)
		Opera._build_monumental_stair(self,Opera.site_basis())
		var promenade:=StaticBody3D.new();promenade.name="OperaMigrationPromenade";add_child(promenade)
		var support:=CollisionShape3D.new();var pavement:=BoxShape3D.new();pavement.size=Vector3(180,.2,180);support.shape=pavement;promenade.add_child(support)
		promenade.position=Opera.CENTER+Opera.site_basis()*Vector3(0,-.1,90);promenade.basis=Opera.site_basis()
		_ready_complete=true
	func add_block(id:String,center:Vector2,height:float,base:=0.0,holes:Array=[]):
		var outline=[[-10,-10],[10,-10],[10,10],[-10,10]]
		var roof:Array=[]
		if holes.is_empty(): roof=[[-10,-10],[10,-10],[10,10],[-10,-10],[10,10],[-10,10]]
		else:
			for rect in [[-10,-10,10,-7],[-10,7,10,10],[-10,-7,-7,7],[7,-7,10,7]]:
				var a=[rect[0],rect[1]];var b=[rect[2],rect[1]];var c=[rect[2],rect[3]];var d=[rect[0],rect[3]]
				roof.append_array([a,b,c,a,c,d])
		map_snapshot.buildings.append({"id":id,"center":[center.x,center.y],"outline":outline,"roof":roof,"holes":holes,"height":height,"base":base,"height_source":"QA authored fixture","tags":{},"parts":[]})
	func _process(_delta):pass
class LocalGame:
	extends "res://scripts/main.gd"
	func _ready():
		qa_running=true
		setup_input()
		world=LocalWorld.new();add_child(world)
		player=Player.new();add_child(player)
		camera=Camera3D.new();add_child(camera)
		life=load("res://scripts/harbor_life.gd").new();add_child(life)
		audio=Sound.new();add_child(audio)
		setup_ui()
		set_process(false)
		set_physics_process(false)
var checks:Array=[]
var test_id:="qa_map_migration_"+str(Time.get_ticks_usec())
func _initialize():call_deferred("run")
func check(name:String,value:bool):
	checks.append({"name":name,"passed":value})
	print("PASS " if value else "FAIL ",name)
func player_bounds(point:Vector3)->AABB:return AABB(point+Vector3(-.32,0,-.32),Vector3(.64,1.8,.64))
func run():
	var game=LocalGame.new();root.add_child(game)
	game.new_world("sandbox","QA map revision fixture",false)
	game.world_id=test_id
	game.player.enabled=false
	game.reset_fleet(false)
	await physics_frame
	await physics_frame
	var world:Node3D=game.world
	check("tall OSM hollow collision shell detected semantically",Migration.overlaps_new_building(world,player_bounds(Vector3(2000,5,2000))))
	check("actual courtyard hole remains usable",not Migration.overlaps_new_building(world,player_bounds(Vector3(2080,5,2000))))
	check("courtyard edge crossing masonry is rejected",Migration.overlaps_new_building(world,AABB(Vector3(2086.8,5,1999),Vector3(1,2,2))))
	var saved_holes=world.map_snapshot.buildings[2].holes
	world.map_snapshot.buildings[2].holes=[[[-7,-7],[7,-7],[7,-2],[0,-2],[0,2],[7,2],[7,7],[-7,7]]]
	if world.has_meta("map_migration_cache"):world.remove_meta("map_migration_cache")
	check("concave courtyard must contain entire footprint not just corners",Migration.overlaps_new_building(world,AABB(Vector3(2078,5,1995),Vector3(7,2,10))))
	world.map_snapshot.buildings[2].holes=saved_holes
	if world.has_meta("map_migration_cache"):world.remove_meta("map_migration_cache")
	check("overhead building part leaves ground open",not Migration.overlaps_new_building(world,player_bounds(Vector3(2160,5,2000))))
	check("custom bank closed trimesh interior detected",Migration.overlaps_new_building(world,player_bounds(Vector3(2240,5,2000))))
	check("custom metro solid column interior detected",Migration.overlaps_new_building(world,player_bounds(Vector3(2280,5,2000))))
	check("custom raised architecture does not fill public ground",not Migration.overlaps_new_building(world,player_bounds(Vector3(2320,5,2000))))
	var tower_inside:Vector3=Tower.CENTER+Vector3(10,42,0)
	var tower_base:Node3D=world.structures["sydney_tower/base/09"].node
	var tower_collision:CollisionShape3D=tower_base.get_child(1)
	check("v013 actual tower base is a closed solid containing the legacy roof region",Migration._closed_mesh(tower_collision.shape.get_faces()) and Migration._inside_mesh(tower_collision.global_transform.affine_inverse()*(tower_inside+Vector3.UP*.9),tower_collision.shape.get_faces()))
	check("v013 tower interior is detected despite replacing reserved OSM geometry",Migration.overlaps_new_building(world,player_bounds(tower_inside)))
	check("reserved original tower OSM pieces are not double-counted as migration solids",Migration._geometry(world).mapped.all(func(item):return not int(str(item.id).get_slice("/",1)) in Tower.excluded_way_ids()))
	check("v013 tower Market Street public arrival remains outside closed geometry",not Migration.overlaps_new_building(world,player_bounds(Tower.ARRIVAL+Vector3.UP*.10)))
	var tower_copy=game.make_vehicle("hoverboard","qa_tower_enclosure",tower_inside)
	tower_copy.freeze=true
	check("summon rejects a complete hoverboard enclosure in the new tower base",not Spawn.clear_envelope(game,tower_copy,tower_copy.global_transform))
	game.reset_fleet(false)
	world._destroy_component("sydney_tower/base/09",Vector3.ZERO,0,false)
	await physics_frame
	check("destroyed tower base floor leaves its actual interior usable",not Migration.overlaps_new_building(world,player_bounds(tower_inside)))
	world.repair_all();await physics_frame
	var kiosk_id:=""
	for id in world.structures:
		if str(id).begins_with("circular_quay/kiosk/"):kiosk_id=str(id);break
	var kiosk:Dictionary=world.structures[kiosk_id]
	var kiosk_inside:Vector3=kiosk.node.global_transform*kiosk.node.get_child(0).mesh.get_aabb().get_center()
	check("v013 real mapped Circular Quay kiosk closed interior is rejected",Migration.overlaps_new_building(world,AABB(kiosk_inside-Vector3.ONE*.05,Vector3.ONE*.1)))
	var wharves_open:=true
	for item in QuayDetail.metadata():
		if str(item.id).begins_with("cq_wharf_") and Migration.overlaps_new_building(world,player_bounds(item.arrival+Vector3.UP*.15)):wharves_open=false
	check("all five Circular Quay public arrivals remain open below overhead roofs",wharves_open)
	var post_id:=""
	for id in world.structures:
		if str(id).begins_with("darling_detail/canopy/post/"):post_id=str(id);break
	var post:Dictionary=world.structures[post_id]
	check("v013 Darling public canopy post is an occupied solid",Migration.overlaps_new_building(world,AABB(post.position-Vector3.ONE*.02,Vector3.ONE*.04)))
	var canopy_center:Vector3=DarlingDetail.CANOPY_A.lerp(DarlingDetail.CANOPY_B,.5)
	var canopy_floor:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(canopy_center+Vector3.UP*.75,canopy_center-Vector3.UP*.5,15))
	# Stand on the actual paving top, not 2 cm inside its raised surface.
	check("Darling public canopy centre remains an open walk route",not canopy_floor.is_empty() and not Migration.overlaps_new_building(world,player_bounds(canopy_floor.position+Vector3.UP*.04)))
	var enclosed_wing=game.make_vehicle("paraglider","qa_enclosed_wing",Vector3(2240,20,2000));enclosed_wing.freeze=true
	check("summon rejects complete enclosure in custom solid shell",not Spawn.clear_envelope(game,enclosed_wing,enclosed_wing.global_transform))
	game.reset_fleet(false)
	var pitched_entry:Dictionary={}
	for item in Migration._geometry(world).mapped:
		if item.id=="way/qa_roof":pitched_entry=item
	check("pitched building uses two actual wall groups instead of three total-height groups",pitched_entry.groups==2 and is_equal_approx(pitched_entry.high,world.GROUND+35))
	var upper_wall:=player_bounds(Vector3(2400,world.GROUND+32,2000))
	var roof_inside:=player_bounds(Vector3(2400,world.GROUND+39,2000))
	var roof_void:=player_bounds(Vector3(2408.5,world.GROUND+39,2000))
	check("uppermost real wall group remains occupied below eaves",Migration.overlaps_new_building(world,upper_wall))
	check("pitched roof interior is detected independently of wall height",Migration.overlaps_new_building(world,roof_inside))
	check("empty space above low eaves is not filled to ridge bounding height",not Migration.overlaps_new_building(world,roof_void))
	check("roof ridge crossing wide box detected when every box corner is outside",Migration.overlaps_new_building(world,AABB(Vector3(2389,world.GROUND+41,1999.9),Vector3(22,0.3,0.2))))
	world._destroy_component("osm/way/qa_roof/storey_group/1",Vector3.ZERO,0,false)
	await physics_frame
	check("destroyed upper wall leaves its actual interval empty under intact roof",not Migration.overlaps_new_building(world,upper_wall))
	check("lower wall survives independent upper wall destruction",Migration.overlaps_new_building(world,player_bounds(Vector3(2400,world.GROUND+7,2000))))
	check("roof survives independent wall destruction",Migration.overlaps_new_building(world,roof_inside))
	world._destroy_component("osm/way/qa_roof/roof",Vector3.ZERO,0,false)
	await physics_frame
	check("destroyed roof leaves pitched interior empty",not Migration.overlaps_new_building(world,roof_inside))
	world.repair_all()
	await physics_frame
	world._destroy_component("osm/way/qa_roof/roof",Vector3.ZERO,0,false)
	await physics_frame
	check("roof destruction preserves independently intact upper wall",Migration.overlaps_new_building(world,upper_wall) and not Migration.overlaps_new_building(world,roof_inside))
	world.repair_all()
	await physics_frame
	check("repair restores separate wall and pitched roof occupancy",Migration.overlaps_new_building(world,upper_wall) and Migration.overlaps_new_building(world,roof_inside) and not Migration.overlaps_new_building(world,roof_void))
	var original:Vector3=Vector3(2000,5,2000)
	game.player.global_position=original
	var replacement:Vector3=Migration._player_pose(game,original)
	check("player relocation exits tall shell rather than returning same floor",replacement.is_finite() and replacement.distance_to(original)>10 and not Migration.overlaps_new_building(world,player_bounds(replacement)))
	check("replacement has grounded full-height clearance",replacement.is_finite() and absf(replacement.y-world.GROUND)<.2)
	game.yaw=1.23
	check("on-foot migration updates safe position without changing view heading",Migration.apply(game)==1 and game.player.global_position.is_equal_approx(game.player.last_safe) and game.yaw==1.23 and not Migration.overlaps_new_building(world,player_bounds(game.player.global_position)))
	game.player.global_position=Vector3(1800,5,1800)
	var widebody=game.make_vehicle("airliner","qa_migration_widebody",Vector3(2000,20,2000));widebody.freeze=true;widebody.health=77;widebody.fuel=29
	var widebody_origin:Vector3=widebody.global_position
	var migrated_plane:int=Migration.apply(game)
	check("wide aircraft migration finds nearby flat field with full footprint clearance",migrated_plane==1 and widebody.global_position.distance_to(widebody_origin)<250 and Spawn.clear_envelope(game,widebody,widebody.global_transform))
	check("wide aircraft migration preserves ID health fuel and parked state",widebody.vehicle_id=="qa_migration_widebody" and widebody.health==77 and widebody.fuel==29 and widebody.freeze)
	game.reset_fleet(false)
	# Same ordering as load_world: apply_state queues first-frame velocities,
	# then map migration may relocate the body before physics integrates it.
	var loaded_car=game.make_vehicle("car","qa_pending_motion",Vector3(2000,5.5,2000))
	var moving_state:Dictionary=loaded_car.get_state()
	moving_state.velocity=[15.0,0.0,0.0];moving_state.angular_velocity=[0.0,.1,0.0]
	moving_state.throttle=.8;moving_state.frozen=false
	loaded_car.apply_state(moving_state)
	var motion_relocated:int=Migration.apply(game)
	var stopped_state:Dictionary=loaded_car.get_state()
	var stopped_position:Vector3=loaded_car.global_position
	check("relocated loaded car clears queued velocity before same-frame save",motion_relocated==1 and not loaded_car.freeze and loaded_car.linear_velocity.is_zero_approx() and loaded_car.angular_velocity.is_zero_approx() and game.unvec(stopped_state.velocity).is_zero_approx() and game.unvec(stopped_state.angular_velocity).is_zero_approx() and stopped_state.throttle==0.0)
	await physics_frame;await physics_frame
	check("first physics integration cannot restore pre-migration driving momentum",Vector2(loaded_car.linear_velocity.x,loaded_car.linear_velocity.z).length()<.02 and loaded_car.angular_velocity.length()<.02 and Vector2(loaded_car.global_position.x-stopped_position.x,loaded_car.global_position.z-stopped_position.z).length()<.02)
	game.reset_fleet(false)
	var live_plane=game.make_vehicle("airliner","qa_live_motion_preserved",Vector3(2700,180,2000))
	var live_state:Dictionary=live_plane.get_state()
	live_state.velocity=[0.0,0.0,-80.0];live_state.frozen=false;live_state.throttle=.5
	live_plane.apply_state(live_state)
	check("non-overlapping live flight keeps queued saved velocity during map migration",Migration.apply(game)==0 and game.unvec(live_plane.get_state().velocity).is_equal_approx(Vector3(0,0,-80)) and live_plane.global_position.is_equal_approx(Vector3(2700,180,2000)))
	game.enter_vehicle(live_plane)
	await physics_frame;await physics_frame
	check("unmigrated flight resumes saved motion after normal boarding integration",live_plane.linear_velocity.distance_to(Vector3(0,0,-80))<.6 and live_plane.health==100 and live_plane.global_position.y>179.9)
	game.reset_fleet(false)
	# Destroy every overlapping lower storey: saved gaps must stay usable.
	for id in world.structures:
		if str(id).begins_with("osm/way/qa_distant/"):world._destroy_component(id,Vector3.ZERO,0,false)
	await physics_frame
	check("destroyed mapped building is not an occupied volume",not Migration.overlaps_new_building(world,player_bounds(Vector3(2500,5,2500))))
	world.repair_all()
	await physics_frame
	# Actual load/save integration against an isolated file; original world ID
	# is QA-owned from creation. No slots() or real save reads occur here.
	var car=game.make_vehicle("car","qa_migration_car_A",Vector3(2000,5.5,2000));car.freeze=true;car.health=67;car.fuel=39
	var far=game.make_vehicle("motorcycle","qa_migration_bike_B",Vector3(2500,5.5,2500));far.freeze=true;far.health=81;far.fuel=52
	var safe=game.make_vehicle("car","qa_migration_safe",Vector3(1800,5.5,1800));safe.freeze=true;safe.health=91;safe.fuel=84
	var court=game.make_vehicle("motorcycle","qa_migration_court",Vector3(2080,5.5,2000));court.freeze=true
	game.player.global_position=car.global_position
	game.current_vehicle=car;car.occupied=true
	game.spawn_target=far
	check("QA revision fixture writes",game.save_world())
	var old:Dictionary=Store.read(test_id)
	var saved_safe:Vector3=safe.global_position
	var old_copy=old.duplicate(true)
	old.map_revision=0
	Store.write(test_id,old)
	var before_bytes:=FileAccess.get_file_as_string(Store.ROOT+test_id+".json")
	game.load_world(test_id)
	check("load preserves all fleet IDs and count",game.vehicles.size()==4 and game.vehicles.map(func(v):return v.vehicle_id).has("qa_migration_bike_B"))
	var all_fields:=true
	var safe_unchanged:=true
	var relocated_near:=true
	for body in game.vehicles:
		var entry:Dictionary={}
		for state in old_copy.vehicles:
			if state.id==body.vehicle_id:entry=state
		if entry.is_empty() or body.health!=entry.health or body.fuel!=entry.fuel:all_fields=false
		if body.vehicle_id in ["qa_migration_safe","qa_migration_court"]:
			if body.global_position.distance_to(game.unvec(entry.position))>.001:safe_unchanged=false
		else:
			if body.global_position.distance_to(game.unvec(entry.position))>120 or Migration.overlaps_new_building(world,body.global_transform*Spawn.envelope(body)):relocated_near=false
	check("migration preserves independent health and fuel",all_fields)
	check("safe and courtyard copies retain exact saved position",safe_unchanged)
	check("each displaced copy stays near its own saved neighborhood",relocated_near)
	check("original occupied copy restored after relocation",is_instance_valid(game.current_vehicle) and game.current_vehicle.vehicle_id=="qa_migration_car_A" and game.current_vehicle.occupied and game.player.global_position.is_equal_approx(game.current_vehicle.global_position))
	check("spawn waypoint remains on its original new-copy ID",is_instance_valid(game.spawn_target) and game.spawn_target.vehicle_id=="qa_migration_bike_B")
	check("load reports migration to player",game.toast_label.text.contains("安全调整"))
	check("loading does not rewrite source save",before_bytes==FileAccess.get_file_as_string(Store.ROOT+test_id+".json"))
	check("save persists current map revision",game.save_world() and Store.read(test_id).map_revision==Migration.REVISION)
	var positions:Dictionary={}
	for body in game.vehicles:positions[body.vehicle_id]=body.global_transform
	game.load_world(test_id)
	var stable:=true
	for body in game.vehicles:
		if not body.global_transform.is_equal_approx(positions[body.vehicle_id]):stable=false
	check("current revision reload does not migrate twice or create copies",stable and game.vehicles.size()==4)
	# Deliberately overlapping current revision poses are preserved exactly:
	# revision migration must not become an every-load teleport/reset mechanic.
	old_copy.map_revision=Migration.REVISION
	Store.write(test_id,old_copy)
	game.load_world(test_id)
	check("current revision does not rewrite deliberately saved pose",game.current_vehicle.global_position.is_equal_approx(Vector3(2000,5.5,2000)))
	await opera_stair_revision(game)
	game.active=false
	var okay:=true
	for item in checks:
		if not item.passed:okay=false
	var file:=FileAccess.open(ProjectSettings.globalize_path("res://../reports/map-migration.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":okay,"checks":checks,"user_saves_touched":false,"isolated_test_id":test_id},"\t"));file.close()
	game.finish_quit(0 if okay else 1)

func opera_point(local:Vector3) -> Vector3:return Opera.CENTER+Opera.site_basis()*local
func opera_stair_revision(game:Node3D):
	var world:Node3D=game.world
	check("current revision 6 enables a one-time check for older geometry saves",Migration.REVISION==6)
	for bay in 8:
		var body:Node3D=world.structures["opera/steps/foundation/%d"%bay].node
		var collision:CollisionShape3D=body.get_child(1)
		var faces:PackedVector3Array=collision.shape.get_faces()
		var x:float=lerpf(-Opera.STAIR_HALF_WIDTH,Opera.STAIR_HALF_WIDTH,(bay+.5)/8.0)
		var inside:=opera_point(Vector3(x,2,68.5))
		check("v015 actual stair foundation %d is closed and contains its buried legacy point"%bay,Migration._closed_mesh(faces) and Migration._inside_mesh(collision.global_transform.affine_inverse()*inside,faces) and Migration.overlaps_new_building(world,player_bounds(inside)))
	game.current_vehicle=null;game.reset_fleet(false);await physics_frame
	var trapped_player:=opera_point(Vector3(20,2,68.5))
	var trapped_board_point:=opera_point(Vector3(-18,3,68.5))
	var safe_ground:=opera_point(Vector3(64,1,78))
	var safe_air:=opera_point(Vector3(0,140,72))
	var board=game.make_vehicle("hoverboard","qa_opera_buried_board",trapped_board_point);board.freeze=true;board.health=63;board.fuel=37
	var ground_board=game.make_vehicle("hoverboard","qa_opera_safe_ground",safe_ground);ground_board.freeze=true;ground_board.health=86;ground_board.fuel=59
	var air_board=game.make_vehicle("hoverboard","qa_opera_safe_air",safe_air);air_board.freeze=true;air_board.health=72;air_board.fuel=41
	game.player.global_position=trapped_player;game.player.last_safe=trapped_player
	check("v015 buried player still requires relocation despite Opera support exception",Migration._player_needs_relocation(game,trapped_player))
	check("v015 buried hoverboard is fully contained by the production stair foundation",Migration.overlaps_new_building(world,board.global_transform*Spawn.envelope(board)))
	world.apply_state({"destroyed":["opera/steps/7"]})
	await physics_frame;await physics_frame
	var fixture_id:String=test_id+"_opera_revision4"
	game.world_id=fixture_id
	check("v015 isolated Opera fixture writes without reading user worlds",game.save_world())
	var legacy:Dictionary=Store.read(fixture_id);legacy.map_revision=4
	# Exercise current load_world ordering, including a harmless airborne copy
	# whose queued velocity must survive because it does not intersect new solid.
	for state in legacy.vehicles:
		if state.id=="qa_opera_safe_air":state.frozen=false;state.velocity=[0,0,-18];state.throttle=.35
	check("v015 revision-4 fixture with retired stair damage is accepted",Store.write(fixture_id,legacy))
	var before_bytes:String=FileAccess.get_file_as_string(Store.ROOT+fixture_id+".json")
	game.load_world(fixture_id)
	var copies:Dictionary={}
	for body in game.vehicles:copies[body.vehicle_id]=body
	var moved_board:Node3D=copies["qa_opera_buried_board"]
	check("v015 actual load migrates a buried player to nearby clear ground",game.player.global_position.distance_to(trapped_player)>.5 and game.player.global_position.distance_to(trapped_player)<120 and not Migration.overlaps_new_building(world,player_bounds(game.player.global_position)) and game.player.last_safe.is_equal_approx(game.player.global_position))
	check("v015 actual load migrates buried hoverboard outside the filled stair",moved_board.global_position.distance_to(trapped_board_point)>.5 and moved_board.global_position.distance_to(trapped_board_point)<120 and not Migration.overlaps_new_building(world,moved_board.global_transform*Spawn.envelope(moved_board)) and Spawn.clear_envelope(game,moved_board,moved_board.global_transform))
	check("v015 migration preserves all hoverboard IDs health fuel and copy count",copies.size()==3 and copies["qa_opera_buried_board"].health==63 and copies["qa_opera_buried_board"].fuel==37 and copies["qa_opera_safe_ground"].health==86 and copies["qa_opera_safe_ground"].fuel==59 and copies["qa_opera_safe_air"].health==72 and copies["qa_opera_safe_air"].fuel==41)
	check("v015 valid ground and airborne hoverboards retain exact saved positions",copies["qa_opera_safe_ground"].global_position.is_equal_approx(safe_ground) and copies["qa_opera_safe_air"].global_position.is_equal_approx(safe_air))
	check("v015 unrelated airborne hoverboard retains queued saved motion",game.unvec(copies["qa_opera_safe_air"].get_state().velocity).is_equal_approx(Vector3(0,0,-18)) and is_equal_approx(float(copies["qa_opera_safe_air"].get_state().throttle),.35))
	check("v015 loading retains retired damage history and leaves fixture bytes untouched",world.destroyed.has("opera/steps/7") and not world.destroyed.has("opera/steps/foundation/4") and before_bytes==FileAccess.get_file_as_string(Store.ROOT+fixture_id+".json"))
	for body in game.vehicles:body.freeze=true;body.stop_motion_after_relocation()
	var safe_player:=opera_point(Vector3(64,.04,90))
	var on_stair:=opera_point(Vector3(18,Opera.PODIUM_HEIGHT*(Opera.STAIR_FOOT_Z-72)/(Opera.STAIR_FOOT_Z-Opera.STAIR_HEAD_Z)+.10,72))
	for valid_pose:Vector3 in [safe_player,on_stair,safe_air]:
		var stair_pose:bool=valid_pose.is_equal_approx(on_stair)
		game.player.global_position=valid_pose;game.player.last_safe=valid_pose
		if stair_pose:
			game.player.global_position+=Vector3.UP*.35;game.player.enabled=true
			for frame in 90:await physics_frame
			game.player.enabled=false;valid_pose=game.player.global_position
			print("OPERA_MIGRATION_SLOPE_CONTACT position=",valid_pose," floor=",game.player.is_on_floor()," velocity=",game.player.velocity)
		check("v015 safe player pose does not require relocation at "+str(valid_pose),not Migration._player_needs_relocation(game,valid_pose))
		var before:Vector3=game.player.global_position
		Migration.apply(game)
		check("v015 safe player pose is not relocated at "+str(valid_pose),game.player.global_position.is_equal_approx(before))
		if stair_pose:
			check("v015 stair support exemption does not accept a capsule buried four centimetres into the slope",Migration._player_needs_relocation(game,valid_pose-Vector3.UP*.04))
			check("v015 standing-stair fixture writes",game.save_world())
			var standing:Dictionary=Store.read(fixture_id);standing.map_revision=4
			check("v015 standing-stair revision-4 fixture writes",Store.write(fixture_id,standing))
			game.load_world(fixture_id)
			check("v015 actual revision-4 load preserves the settled production-player stair pose",game.player.global_position.is_equal_approx(before))
	game.current_vehicle=null
	for body in game.vehicles:body.freeze=true;body.stop_motion_after_relocation()
	check("explicit save records current revision after the one-time safety migration",game.save_world() and Store.read(fixture_id).map_revision==Migration.REVISION)
	var positions:Dictionary={}
	for body in game.vehicles:positions[body.vehicle_id]=body.global_transform
	var saved_player:Vector3=game.player.global_position
	game.load_world(fixture_id)
	var unchanged:bool=game.player.global_position.is_equal_approx(saved_player)
	for body in game.vehicles:
		if not body.global_transform.is_equal_approx(positions[body.vehicle_id]):unchanged=false
	check("v015 current-revision reload performs no second relocation",unchanged and game.vehicles.size()==3)
	# A v0.1.5 save is the immediately preceding release, so exercise that
	# actual load gate separately from the retained revision-4 regression.
	game.player.global_position=trapped_player;game.player.last_safe=trapped_player
	check("v016 isolated revision-5 fixture saves",game.save_world())
	var previous_release:Dictionary=Store.read(fixture_id);previous_release.map_revision=5
	check("v016 previous-release map revision fixture writes",Store.write(fixture_id,previous_release))
	var previous_bytes:=FileAccess.get_file_as_string(Store.ROOT+fixture_id+".json")
	game.load_world(fixture_id)
	check("v016 revision-5 load runs solid-geometry recovery",game.player.global_position.distance_to(trapped_player)>.5 and not Migration._player_needs_relocation(game,game.player.global_position))
	check("v016 revision-5 load leaves the source save and fleet identities intact",previous_bytes==FileAccess.get_file_as_string(Store.ROOT+fixture_id+".json") and game.vehicles.size()==3 and game.vehicles.all(func(vehicle):return positions.has(vehicle.vehicle_id)))
