extends SceneTree
## Regression: a model upgrade must keep the support floor and preserve flight.
const Migration=preload("res://scripts/vehicle_model_migration.gd")
const MapMigration=preload("res://scripts/map_migration.gd")
const Bridge=preload("res://scripts/bridge_landmark.gd")
class FixturePlayer extends CharacterBody3D:
	var last_safe:=Vector3.ZERO
class FixtureWorld extends Node3D:
	var _building_plots:Array=[]
	var _distant_visual_plots:Array=[]
	var destroyed:Dictionary={}
class FixtureGame extends Node3D:
	var yaw:=0.0
	var world:FixtureWorld
	var player:FixturePlayer
	var vehicles:Array=[]
	var current_vehicle
var failures:=0
func _initialize():call_deferred("run")
func check(title:String,okay:bool):
	print("MODEL_MIGRATION ","PASS " if okay else "FAIL ",title)
	if not okay:failures+=1
func slab(parent:Node3D,pos:Vector3,size:Vector3):
	var body:=StaticBody3D.new()
	body.position=pos
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new();box.size=size;shape.shape=box
	body.add_child(shape);parent.add_child(body)
func run():
	var game:=FixtureGame.new();root.add_child(game)
	game.world=FixtureWorld.new();game.add_child(game.world)
	game.world.set_meta("map_migration_cache",{"mapped":[],"custom":[]})
	game.player=FixturePlayer.new();game.add_child(game.player)
	game.player.position=Vector3(200,6,0)
	slab(game.world,Vector3(0,4,-600),Vector3(3000,1,3000))
	slab(game.world,Vector3(0,54.5,0),Vector3(35,1,200))
	for kind in ["car","airliner"]:
		var vehicle=load("res://scripts/harbor_vehicle.gd").new()
		vehicle.configure(kind,"legacy_"+kind)
		vehicle.position=Vector3(0,5.18,0) if kind=="car" else Vector3(85,40,0)
		vehicle.freeze=true
		vehicle.health=73;vehicle.fuel=42
		game.add_child(vehicle);game.vehicles.append(vehicle)
		vehicle.set_meta("loaded_model_revision",1)
	game.current_vehicle=game.vehicles[0]
	await physics_frame
	await physics_frame
	var plane_pose:Transform3D=game.vehicles[1].global_transform
	Migration.apply(game,"legacy_car")
	check("safe bridge-underpass car stays on its original floor",game.vehicles[0].position.y>5.1 and game.vehicles[0].position.y<5.5 and absf(game.vehicles[0].position.x)<0.01)
	check("stationary airborne aircraft retains exact flight pose",game.vehicles[1].global_transform.is_equal_approx(plane_pose))
	check("driver identities health fuel and frozen state persist",game.current_vehicle==game.vehicles[0] and game.vehicles.all(func(v):return v.health==73 and v.fuel==42 and v.freeze))
	var old_start:=Vector3(-83,54,-662)+Vector3(232,0,-447).normalized()*503.0
	var retired_pose:=old_start.lerp(Vector3(353.49108752,4.5,-1502.99791431),.6)
	var car=load("res://scripts/harbor_vehicle.gd").new()
	car.configure("car","retired_north_car");car.position=retired_pose+Vector3.UP*.68
	car.freeze=true;car.health=67;car.fuel=39
	game.add_child(car);game.vehicles.append(car)
	await physics_frame
	check("retired straight approach detected from saved support height",MapMigration._on_old_north_approach(retired_pose))
	var moved:=MapMigration.repair_old_approach(game,"legacy_car")
	check("retired unsupported parking moves safely with identity intact",moved==1 and car.position.y<6 and car.health==67 and car.fuel==39 and car.vehicle_id=="retired_north_car")
	check("unrelated airborne aircraft still unchanged after map recovery",game.vehicles[1].global_transform.is_equal_approx(plane_pose))
	var low_flight=game.vehicles[1]
	low_flight.position=retired_pose+Vector3.UP*4.24
	low_flight.linear_velocity=Vector3(0,0,-80)
	low_flight.throttle=.74
	var low_pose:Transform3D=low_flight.global_transform
	check("low flight fixture crosses the exact retired ramp envelope",MapMigration._on_old_north_approach(low_flight.position+Vector3.DOWN*4.24))
	MapMigration.repair_old_approach(game,"legacy_car")
	check("low-flying aircraft keeps pose velocity and throttle over retired ramp",low_flight.global_transform.is_equal_approx(low_pose) and low_flight.linear_velocity.is_equal_approx(Vector3(0,0,-80)) and is_equal_approx(low_flight.throttle,.74))
	# The current south plane is up to ~3m above the same v0.1.1 X/Z.
	# A real sloped collider demonstrates recovery rather than checking constants.
	var south:=StaticBody3D.new();south.name="CurrentSouthSupport"
	var south_basis:Basis=Bridge.ramp_basis("south",.5)
	var south_shape:=CollisionShape3D.new();var south_box:=BoxShape3D.new()
	south_box.size=Vector3(49,2,Bridge.SOUTH_ENTRY.distance_to(Bridge.pos(0)))
	south_shape.shape=south_box;south.add_child(south_shape)
	south.transform=Transform3D(south_basis,(Bridge.SOUTH_ENTRY+Bridge.pos(0))*.5-south_basis.y)
	south.set_meta("damage_id","bridge/ramp/south/fixture");game.world.add_child(south)
	var old_south_a:=Vector3(-325.70848036,4.5,-194.3677124)
	var old_south_b:=Vector3(-83,54,-662)
	var old_south_right:=Vector3(-(old_south_b-old_south_a).z,0,(old_south_b-old_south_a).x).normalized()
	var south_cars:Array=[]
	for fraction in [.25,.5,.75,.9]:
		var parked=load("res://scripts/harbor_vehicle.gd").new()
		parked.configure("car","legacy_south_"+str(fraction))
		parked.position=old_south_a.lerp(old_south_b,fraction)+old_south_right*2.15+Vector3.UP*.68
		parked.rotation=Basis.looking_at((old_south_b-old_south_a).normalized(),Vector3.UP).get_euler()
		parked.freeze=true;parked.health=64;parked.fuel=37
		game.add_child(parked);game.vehicles.append(parked);south_cars.append(parked)
	var moving=load("res://scripts/harbor_vehicle.gd").new()
	moving.configure("car","moving_south");moving.freeze=true
	moving.position=old_south_a.lerp(old_south_b,.4)-old_south_right*6.5+Vector3.UP*.68
	moving.linear_velocity=Vector3(0,0,-12);game.add_child(moving);game.vehicles.append(moving)
	var moving_pose:Transform3D=moving.global_transform
	var under=load("res://scripts/harbor_vehicle.gd").new()
	under.configure("car","under_south");under.freeze=true
	var under_xz:=old_south_a.lerp(old_south_b,.6)
	under.position=Vector3(under_xz.x,5.18,under_xz.z);game.add_child(under);game.vehicles.append(under)
	var under_pose:Transform3D=under.global_transform
	low_flight.position=old_south_a.lerp(old_south_b,.65)+Vector3.UP*4.24
	low_flight.linear_velocity=Vector3(0,0,-80);var south_flight_pose:Transform3D=low_flight.global_transform
	await physics_frame
	var south_moved:=MapMigration.repair_old_approach(game,"legacy_car")
	check("exactly four unsupported old south parked cars recover",south_moved==4)
	for parked in south_cars:
		var foot:Vector3=parked.global_position+parked.global_basis.y*preload("res://scripts/vehicle_spawn.gd").envelope(parked).position.y
		var hit:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.2,foot-Vector3.UP*.5,15,[parked.get_rid(),game.player.get_rid()]))
		check(parked.vehicle_id+" now has upward south-ramp wheel support",not hit.is_empty() and hit.collider==south and hit.normal.y>.98 and absf(foot.y-hit.position.y)<.2)
	check("south recovery preserves IDs health fuel freeze and travel heading",south_cars.all(func(v):return v.health==64 and v.fuel==37 and v.freeze and v.vehicle_id.begins_with("legacy_south_") and (-v.global_basis.z).dot((old_south_b-old_south_a).normalized())>.99))
	check("moving road vehicle retains pose and velocity over old south plane",moving.global_transform.is_equal_approx(moving_pose) and moving.linear_velocity.is_equal_approx(Vector3(0,0,-12)))
	check("normal bridge-underpass parking stays unchanged",under.global_transform.is_equal_approx(under_pose))
	check("low flight over old south plane retains pose velocity throttle",low_flight.global_transform.is_equal_approx(south_flight_pose) and low_flight.linear_velocity.is_equal_approx(Vector3(0,0,-80)) and is_equal_approx(low_flight.throttle,.74))
	for fraction in [.5,.75]:
		game.player.position=old_south_a.lerp(old_south_b,fraction)-old_south_right*10.8
		var old_player_y:float=game.player.position.y
		var changed:=MapMigration.repair_old_approach(game,"")
		var hit:=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(game.player.position+Vector3.UP*.1,game.player.position-Vector3.UP*.3,15,[game.player.get_rid()]))
		check("old south pedestrian "+str(fraction)+" recovers onto actual support",changed==1 and game.player.position.y>old_player_y+.5 and not hit.is_empty() and hit.collider==south and game.player.last_safe==game.player.position)
	game.player.position=old_south_a.lerp(old_south_b,.35)-old_south_right*10.8
	game.player.velocity=Vector3(2,0,0);var walking_pose:Vector3=game.player.position
	MapMigration.repair_old_approach(game,"")
	check("moving pedestrian retains position and velocity",game.player.position==walking_pose and game.player.velocity==Vector3(2,0,0))
	game.player.velocity=Vector3.ZERO;game.player.position=Vector3(under_xz.x,4.54,under_xz.z)
	var under_player:Vector3=game.player.position
	MapMigration.repair_old_approach(game,"")
	check("pedestrian below south bridge stays on ground",game.player.position==under_player)
	print("MODEL_MIGRATION COMPLETE checks=21 failures=",failures)
	game.queue_free();await process_frame
	quit(1 if failures else 0)
