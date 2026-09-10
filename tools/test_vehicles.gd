extends SceneTree
## Reproduce: Godot --headless --path game --script ../tools/test_vehicles.gd --fixed-fps 60
## Uses the production vehicle scripts and native physics. No transform/velocity writes after spawn.
## The airport/city render and human control ergonomics require the separate full-game checks.

class Runner extends Node:
	var stage: Node3D
	var results: Array = []
	var report: Dictionary = {"engine":Engine.get_version_info().string,"physics_hz":60,"scope":"Production vehicle physics on deterministic test surfaces; not a city visual or airport geography test","checks":[],"samples":[]}
	var plane: RigidBody3D
	var circuit_time := 0.0
	var circuit_wp := 0
	var circuit_next_sample := 0.0
	var circuit_active := false
	var circuit_peak_altitude := 0.0
	var circuit_liftoff_run := 0.0
	var circuit_liftoff_time := 0.0
	var circuit_targets := [Vector3(0,240,-1000),Vector3(1500,250,-1900),Vector3(2200,250,1000),Vector3(1550,230,4000),Vector3(0,200,6200),Vector3(0,150,3900),Vector3(0,4.4,600)]

	func _ready() -> void:
		for action in ["forward","back","left","right","rise","fall","brake"]:
			if not InputMap.has_action(action): InputMap.add_action(action)
		run_cases()

	func check(test_name:String,ok:bool,metrics:Dictionary={}) -> void:
		var row:Dictionary={"name":test_name,"pass":ok,"metrics":metrics}
		results.append(row)
		print(("PASS " if ok else "FAIL ")+test_name+" "+JSON.stringify(metrics))

	func release_all() -> void:
		for action in ["forward","back","left","right","rise","fall","brake"]: Input.action_release(action)

	func frames(count:int) -> void:
		for i in count: await get_tree().physics_frame

	func new_stage(ground:bool=false) -> void:
		release_all()
		if is_instance_valid(stage):
			stage.queue_free()
			await get_tree().process_frame
		stage=Node3D.new()
		add_child(stage)
		if ground: add_box(Vector3(400,2,12000),Vector3(0,3.5,0))

	func add_box(size:Vector3,pos:Vector3) -> StaticBody3D:
		var body:=StaticBody3D.new()
		var col:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=size
		col.shape=shape
		body.add_child(col)
		body.position=pos
		stage.add_child(body)
		return body

	func make(kind:String,pos:Vector3) -> RigidBody3D:
		var body:RigidBody3D=load("res://scripts/harbor_vehicle.gd").new()
		body.configure(kind,"verify_"+kind)
		body.position=pos
		stage.add_child(body)
		return body

	func save_roundtrip(vehicle:RigidBody3D) -> void:
		var state:Dictionary=JSON.parse_string(JSON.stringify(vehicle.get_state()))
		var copy:RigidBody3D=load("res://scripts/harbor_vehicle.gd").new()
		copy.configure(vehicle.kind,"roundtrip_"+vehicle.kind)
		copy.apply_state(state) # Also verifies applying data before add_child / _ready.
		stage.add_child(copy)
		var okay:bool=copy.position.is_equal_approx(vehicle.position) and copy.linear_velocity.is_equal_approx(vehicle.linear_velocity) and is_equal_approx(copy.health,vehicle.health) and copy.freeze==vehicle.freeze
		check("save_roundtrip_"+vehicle.kind,okay,{"health":copy.health,"frozen":copy.freeze})
		copy.queue_free()

	func run_cases() -> void:
		for kind in ["car","motorcycle"]:
			await new_stage(true)
			var vehicle:=make(kind,Vector3(0,5.25,0))
			vehicle.occupied=true
			Input.action_press("forward")
			await frames(360)
			var cruise:float=vehicle.linear_velocity.length()
			var travelled:float=-vehicle.position.z
			Input.action_press("right",0.45)
			await frames(80)
			var heading:float=absf(vehicle.rotation.y)
			release_all()
			Input.action_press("brake")
			await frames(180)
			check(kind+"_drive_steer_brake",cruise>25.0 and travelled>100.0 and heading>0.2 and vehicle.linear_velocity.length()<2.0 and vehicle.health>95.0,{"cruise_mps":cruise,"travel_m":travelled,"turn_rad":heading,"braked_mps":vehicle.linear_velocity.length(),"health":vehicle.health})
			save_roundtrip(vehicle)
		await new_stage(false)
		var boat:=make("yacht",Vector3(0,0.9,0))
		boat.occupied=true
		var cargo:=RigidBody3D.new()
		cargo.mass=120.0
		cargo.collision_layer=8
		cargo.collision_mask=15
		cargo.position=Vector3(0,2.2,3.2)
		var cargo_shape:=CollisionShape3D.new()
		var box:=BoxShape3D.new()
		box.size=Vector3.ONE*0.8
		cargo_shape.shape=box
		cargo.add_child(cargo_shape)
		var cargo_friction:=PhysicsMaterial.new()
		cargo_friction.friction=0.8
		cargo.physics_material_override=cargo_friction
		stage.add_child(cargo)
		await frames(120)
		Input.action_press("forward",0.8)
		await frames(600)
		var cargo_relative:=boat.to_local(cargo.position)
		check("yacht_buoyancy_and_physical_cargo",boat.position.y>0.15 and boat.position.y<1.1 and boat.linear_velocity.length()>7.0 and absf(cargo_relative.x)<2.4 and cargo_relative.z>0.7 and cargo_relative.z<6.5 and cargo_relative.y>0.9 and cargo_relative.y<1.7,{"boat_height_m":boat.position.y,"speed_mps":boat.linear_velocity.length(),"cargo_local":[cargo_relative.x,cargo_relative.y,cargo_relative.z],"cargo_physical":not cargo.freeze})
		save_roundtrip(boat)
		await new_stage(false)
		var ferry:=make("yacht",Vector3(0,0.9,0))
		var loaded_car:=make("car",Vector3(0,2.45,3.2))
		ferry.occupied=true
		Input.action_press("forward",0.6)
		await frames(900)
		var car_local:=ferry.to_local(loaded_car.position)
		check("yacht_transports_unfrozen_parked_car",ferry.linear_velocity.length()>7.0 and absf(car_local.x)<1.0 and car_local.z>1.0 and car_local.z<5.0 and car_local.y>1.1 and car_local.y<1.9 and loaded_car.health>99.0 and not loaded_car.freeze,{"speed_mps":ferry.linear_velocity.length(),"car_local":[car_local.x,car_local.y,car_local.z],"car_health":loaded_car.health,"boat_height_m":ferry.position.y})
		for kind in ["paraglider","glider"]:
			await new_stage(false)
			var wing:=make(kind,Vector3(0,160,0))
			wing.occupied=true
			await frames(3)
			var initial_energy:float=9.8*wing.position.y+0.5*wing.linear_velocity.length_squared()
			await frames(300)
			Input.action_press("right",0.6)
			await frames(180)
			release_all()
			await frames(420)
			var final_energy:float=9.8*wing.position.y+0.5*wing.linear_velocity.length_squared()
			check(kind+"_unpowered_flight",wing.position.y<151.0 and wing.position.y>10.0 and Vector2(wing.position.x,wing.position.z).length()>110.0 and final_energy<initial_energy*1.02 and absf(wing.rotation.y)>0.2,{"height_m":wing.position.y,"distance_m":Vector2(wing.position.x,wing.position.z).length(),"mechanical_energy_initial_per_kg":initial_energy,"mechanical_energy_final_per_kg":final_energy,"yaw_rad":wing.rotation.y})
			save_roundtrip(wing)
		await new_stage(true)
		var heli:=make("helicopter",Vector3(0,6.15,0))
		heli.occupied=true
		Input.action_press("rise")
		await frames(600)
		release_all()
		Input.action_press("forward",0.7)
		await frames(360)
		var altitude:float=heli.position.y
		var distance:float=-heli.position.z
		release_all()
		await frames(180)
		check("helicopter_collective_cyclic_hover",altitude>35.0 and distance>30.0 and absf(heli.linear_velocity.y)<2.0 and heli.health>95.0,{"altitude_m":altitude,"forward_m":distance,"hover_vertical_mps":heli.linear_velocity.y,"health":heli.health})
		save_roundtrip(heli)
		await new_stage(true)
		add_box(Vector3(30,8,2),Vector3(0,8.5,-90))
		var crash_car:=make("car",Vector3(0,5.25,0))
		var incidents:Array=[]
		crash_car.impacted.connect(func(point:Vector3,energy:float):incidents.append({"point":[point.x,point.y,point.z],"energy_j":energy}))
		crash_car.occupied=true
		Input.action_press("forward")
		await frames(420)
		var before_repair:float=crash_car.health
		var dent_count:int=crash_car.get_state().dents.size()
		crash_car.repair()
		check("collision_energy_damage_and_repair",before_repair<85.0 and incidents.size()>0 and dent_count>0 and crash_car.health==100.0 and crash_car.get_state().dents.is_empty(),{"impact_count":incidents.size(),"health_before_repair":before_repair,"dent_count":dent_count,"health_after_repair":crash_car.health})
		await new_stage(false)
		var stalled_jet:=make("airliner",Vector3(0,180,0))
		stalled_jet.apply_state({"position":[0,180,0],"velocity":[0,0,0],"fuel":0,"health":100,"frozen":false})
		stalled_jet.occupied=true
		await frames(180)
		check("airliner_zero_airspeed_stalls_without_hover",stalled_jet.stalled and stalled_jet.position.y<155.0 and stalled_jet.linear_velocity.y < -20.0,{"height_m":stalled_jet.position.y,"vertical_mps":stalled_jet.linear_velocity.y,"stall":stalled_jet.stalled,"fuel":stalled_jet.fuel})
		await new_stage(false)
		add_box(Vector3(140,2,12000),Vector3(0,-1,0))
		plane=make("airliner",Vector3(0,4.35,3500))
		plane.throttle=0.0
		await frames(180)
		check("airliner_parked_on_wheels",plane.linear_velocity.length()<0.1 and plane.position.y>4.0 and plane.position.y<4.4,{"speed_mps":plane.linear_velocity.length(),"height_m":plane.position.y})
		plane.occupied=true
		circuit_active=true

	func axis(negative:String,positive:String,value:float) -> void:
		Input.action_release(negative)
		Input.action_release(positive)
		if absf(value)>0.025: Input.action_press(positive if value>0 else negative,clampf(absf(value),0.0,1.0))

	func _physics_process(delta:float) -> void:
		if not circuit_active: return
		circuit_time+=delta
		circuit_peak_altitude=maxf(circuit_peak_altitude,plane.position.y)
		if circuit_liftoff_time==0.0 and plane.position.y>6.5 and not plane.grounded:
			circuit_liftoff_time=circuit_time
			circuit_liftoff_run=3500-plane.position.z
		var speed:float=plane.linear_velocity.length()
		var target:Vector3=circuit_targets[circuit_wp]
		var offset:Vector3=target-plane.position
		var horizontal_distance:=Vector2(offset.x,offset.z).length()
		if circuit_wp<circuit_targets.size()-1 and horizontal_distance<350.0 and plane.position.y>100.0:
			circuit_wp+=1
			target=circuit_targets[circuit_wp]
			offset=target-plane.position
		if circuit_wp==6: offset=Vector3(-plane.position.x,0,-1000)
		var heading:=atan2(-offset.x,-offset.z)
		var heading_error:=wrapf(heading-plane.rotation.y,-PI,PI)
		axis("left","right",-heading_error*2.6)
		var target_speed:=83.0
		var target_height:=target.y
		if circuit_wp==6:
			target_height=maxf(4.4,(plane.position.z-600)*0.042+4.4)
			target_speed=72.0
		if plane.grounded and circuit_time<65:
			axis("back","forward",1.0)
			axis("fall","rise",1.0 if speed>68 else 0.0)
		else:
			axis("back","forward",clampf((target_speed-speed)*0.4,-1,1))
			var desired_vertical:=clampf((target_height-plane.position.y)*0.05,-7.0,10.0)
			var pitch_command:=clampf(asin(clampf(desired_vertical/maxf(speed,20),-0.4,0.4))+(desired_vertical-plane.linear_velocity.y)*0.035+0.015,-0.21,0.21)
			axis("fall","rise",(pitch_command-0.015)/0.22)
		if circuit_wp==6 and plane.position.y<5.5 and circuit_time>100:
			axis("back","forward",-1.0)
			Input.action_press("brake")
			axis("fall","rise",0.0)
		if circuit_time>=circuit_next_sample:
			circuit_next_sample+=20
			report.samples.append({"time_s":circuit_time,"waypoint":circuit_wp,"position":[plane.position.x,plane.position.y,plane.position.z],"speed_mps":speed,"health":plane.health,"throttle":plane.throttle})
		if circuit_time>100 and circuit_wp==6 and plane.grounded and speed<0.20:
			circuit_active=false
			check("airliner_takeoff_circuit_return_landing",plane.health>95.0 and absf(plane.position.x)<35.0 and circuit_peak_altitude>200.0 and circuit_liftoff_run>600.0 and circuit_liftoff_run<2200.0,{"elapsed_s":circuit_time,"liftoff_time_s":circuit_liftoff_time,"takeoff_run_m":circuit_liftoff_run,"peak_altitude_m":circuit_peak_altitude,"landing_cross_track_m":plane.position.x,"final_speed_mps":speed,"health":plane.health})
			save_roundtrip(plane)
			finish.call_deferred()
		elif circuit_time>420 or plane.position.y< -10:
			circuit_active=false
			check("airliner_takeoff_circuit_return_landing",false,{"time_s":circuit_time,"waypoint":circuit_wp,"height_m":plane.position.y})
			finish.call_deferred()

	func finish() -> void:
		release_all()
		report.checks=results
		report.passed=results.all(func(row:Dictionary)->bool:return row.pass)
		report.check_count=results.size()
		var path:=ProjectSettings.globalize_path("res://../reports/vehicle-physics.json")
		var file:=FileAccess.open(path,FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(report,"\t")); file.close()
		print("VEHICLE_QA pass=",report.passed," checks=",results.size()," report=",path)
		if is_instance_valid(stage): stage.queue_free()
		await frames(10)
		get_tree().quit(0 if report.passed else 1)

func _initialize() -> void:
	root.add_child.call_deferred(Runner.new())
