extends SceneTree
## Production HarborVehicle/Factory/Models/Motion in an isolated Jolt scene.
## Input actions drive every sampled frame; no pose/velocity writes after launch.
const Models = preload("res://scripts/fighter_models.gd")
const Motion = preload("res://scripts/fighter_motion.gd")
const Factory = preload("res://scripts/vehicle_factory.gd")
var checks: Array = []
var failures := 0
var scene: Node3D
var body: RigidBody3D
var measured_max_speed := 0.0
var measured_max_step := 0.0

func _init(): call_deferred("run")
func check(label: String, value: bool, metrics: Dictionary = {}):
	checks.append({"name":label,"passed":value,"metrics":metrics})
	print(("PASS " if value else "FAIL ")+label+" "+JSON.stringify(metrics))
	if not value: failures+=1
func clear_input():
	for action: String in ["forward","back","left","right","rise","fall","brake"]: Input.action_release(action)
func frames(count: int) -> Dictionary:
	var start := body.position
	var min_y: float=body.position.y
	var max_y: float=body.position.y
	var min_speed: float=body.linear_velocity.length()
	var max_speed: float=min_speed
	var max_roll := 0.0
	var max_pitch := 0.0
	var max_angular_speed := 0.0
	var last_position: Vector3=body.position
	var max_frame_step := 0.0
	for i in count:
		await physics_frame
		max_frame_step=maxf(max_frame_step,body.position.distance_to(last_position))
		last_position=body.position
		min_y=minf(min_y,body.position.y);max_y=maxf(max_y,body.position.y)
		min_speed=minf(min_speed,body.linear_velocity.length());max_speed=maxf(max_speed,body.linear_velocity.length())
		max_roll=maxf(max_roll,absf(body.rotation.z));max_pitch=maxf(max_pitch,absf(asin(clampf(-body.global_basis.z.y,-1,1))))
		max_angular_speed=maxf(max_angular_speed,body.angular_velocity.length())
	measured_max_speed=maxf(measured_max_speed,max_speed)
	measured_max_step=maxf(measured_max_step,max_frame_step)
	return {"seconds":count/60.0,"distance":body.position.distance_to(start),"height_change":body.position.y-start.y,"min_y":min_y,"max_y":max_y,"min_speed_mps":min_speed,"max_speed_mps":max_speed,"final_speed_mps":body.linear_velocity.length(),"max_roll_rad":max_roll,"max_pitch_rad":max_pitch,"max_angular_speed":max_angular_speed,"maximum_frame_distance_m":max_frame_step}
func _geometry(node: Node3D, accumulated: Transform3D, state: Dictionary):
	for child in node.get_children():
		if not child is Node3D: continue
		var pose: Transform3D=accumulated*child.transform
		if child is MeshInstance3D:
			state.meshes+=1
			for surface in child.mesh.get_surface_count():
				var arrays: Array=child.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				state.triangles+=(indices.size() if indices.size()>0 else vertices.size())/3
				for vertex: Vector3 in vertices:
					var point: Vector3=pose*vertex
					state.min=state.min.min(point);state.max=state.max.max(point)
		elif child is CollisionShape3D:
			state.colliders+=1
			var mesh: ArrayMesh=child.shape.get_debug_mesh()
			var bounds: AABB=pose*mesh.get_aabb()
			state.collision_min=state.collision_min.min(bounds.position)
			state.collision_max=state.collision_max.max(bounds.end)
		_geometry(child,pose,state)
func run():
	Engine.physics_ticks_per_second=60
	for action: String in ["forward","back","left","right","rise","fall","brake"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	clear_input()
	scene=Node3D.new();root.add_child(scene)
	var ground:=StaticBody3D.new();scene.add_child(ground);ground.position.y=-1
	var floor_shape:=BoxShape3D.new();floor_shape.size=Vector3(200000,2,200000)
	var floor_collider:=CollisionShape3D.new();floor_collider.shape=floor_shape;ground.add_child(floor_collider)
	body=Factory.make("fighter","fighter_flight_fixture")
	body.freeze=true;body.position=Vector3(0,1000,0);scene.add_child(body)
	await physics_frame
	await physics_frame
	check("Factory registers actual production fighter",body.kind=="fighter" and body.get_script().resource_path=="res://scripts/harbor_vehicle.gd")
	body.freeze=false;body.prepare_for_boarding(true);body.occupied=true
	var pending_save: Dictionary=body.get_state()
	check("Saving immediately after boarding preserves pending launch",Vector3(pending_save.velocity[0],pending_save.velocity[1],pending_save.velocity[2]).length()>139.0 and not pending_save.frozen,pending_save)
	await physics_frame
	await physics_frame
	var moving: Dictionary=body._moving
	var geometry: Dictionary={"min":Vector3(INF,INF,INF),"max":Vector3(-INF,-INF,-INF),"collision_min":Vector3(INF,INF,INF),"collision_max":Vector3(-INF,-INF,-INF),"triangles":0,"colliders":0,"meshes":0}
	_geometry(body,Transform3D.IDENTITY,geometry)
	check("Real Jolt backend and live collision body",ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics" and body.collision_mask==15 and body.collision_layer==4 and body.continuous_cd and not body.freeze)
	check("Original model has independent detailed twin-engine geometry",geometry.triangles>10000 and geometry.colliders>=20 and moving.exhaust.size()==2,geometry)
	check("Wings, tail and nose fit declared metre envelope",geometry.min.is_finite() and geometry.max.is_finite() and geometry.min.x>=-6.9 and geometry.max.x<=6.9 and geometry.min.z>=-9.5 and geometry.max.z<=9.2 and geometry.max.y<=4.4,geometry)
	check("Three real landing wheels preserve exact ground plane",moving.wheels.size()==3 and absf(geometry.min.y-Models.GROUND_CONTACT_Y)<.002 and absf(geometry.collision_min.y-Models.GROUND_CONTACT_Y)<.002,geometry)
	check("Muzzle is beyond nose and points forward",moving.weapon_muzzle.position.z<geometry.min.z-.2 and moving.weapon_muzzle.basis==Basis.IDENTITY,{"muzzle":moving.weapon_muzzle.position})
	check("Pending first-integrator launch actually applies",body.linear_velocity.length()>139 and body.linear_velocity.length()<141,{"speed_mps":body.linear_velocity.length()})
	var launch: Dictionary=await frames(900)
	check("Hands-off first fifteen seconds do not drop or stall",launch.min_y>999.5 and launch.max_y<1000.5 and launch.min_speed_mps>139 and launch.max_speed_mps<141 and launch.max_pitch_rad<.02,launch)
	Input.action_press("forward")
	var acceleration: Dictionary=await frames(900)
	check("W accelerates through real forces to 2000 km/h",acceleration.final_speed_mps>=Motion.TOP_SPEED*.995 and acceleration.max_speed_mps<=Motion.TOP_SPEED+.3 and acceleration.distance>4500,acceleration)
	Input.action_release("forward")
	var full_speed_save: Dictionary=body.get_state()
	check("Production save guard preserves 2000 km/h",Vector3(full_speed_save.velocity[0],full_speed_save.velocity[1],full_speed_save.velocity[2]).length()>550 and float(full_speed_save.throttle)>.99,{"velocity":full_speed_save.velocity,"throttle":full_speed_save.throttle})
	var steady: Dictionary=await frames(300)
	check("Released throttle holds full-speed level flight",steady.min_speed_mps>=Motion.TOP_SPEED*.99 and steady.max_speed_mps<=Motion.TOP_SPEED+.3 and steady.max_y-steady.min_y<.5,steady)
	var forward_before: Vector3=-body.global_basis.z
	Input.action_press("right",.65)
	var turning: Dictionary=await frames(420)
	Input.action_release("right")
	var turn_angle: float=forward_before.angle_to(-body.global_basis.z)
	check("Coordinated high-speed turn changes actual heading",turn_angle>.55 and turning.distance>2000 and turning.min_speed_mps>Motion.TOP_SPEED*.85 and turning.max_roll_rad<.9 and absf(turning.height_change)<30.0,turning.merged({"heading_change_rad":turn_angle}))
	var levelling: Dictionary=await frames(360)
	check("Release steering smoothly levels the airframe",absf(body.rotation.z)<.04 and absf(body.linear_velocity.y)<2 and levelling.max_angular_speed<1.5,levelling)
	Input.action_press("rise",.70)
	var climb: Dictionary=await frames(300)
	check("R input produces an actual sustained climb",climb.height_change>350 and climb.max_pitch_rad>.35 and climb.max_pitch_rad<1.1 and climb.max_speed_mps<=Motion.TOP_SPEED+.3,climb)
	Input.action_release("rise")
	await frames(360)
	check("Release pitch returns to stable level flight",absf(asin(clampf(-body.global_basis.z.y,-1,1)))<.03 and absf(body.linear_velocity.y)<3,{"vertical_mps":body.linear_velocity.y,"pitch":asin(-body.global_basis.z.y)})
	Input.action_press("fall",.45)
	var descent: Dictionary=await frames(180)
	check("F input produces a controlled descent",descent.height_change< -100 and descent.min_y>500 and descent.max_pitch_rad<.8,descent)
	Input.action_release("fall")
	await frames(360)
	Input.action_press("brake")
	var braking: Dictionary=await frames(360)
	check("Space airbrake reduces real speed without a fall",braking.final_speed_mps<85 and braking.final_speed_mps>=Motion.MINIMUM_FLIGHT_SPEED-.5 and absf(braking.height_change)<5,braking)
	Input.action_release("brake")
	Input.action_press("back")
	var low_throttle: Dictionary=await frames(360)
	Input.action_release("back")
	check("S reduces throttle and retains assisted low-speed flight",body.throttle<.01 and low_throttle.final_speed_mps<85 and absf(low_throttle.height_change)<5,low_throttle)
	check("No instability, overspeed or position discontinuity observed",body.position.is_finite() and body.linear_velocity.is_finite() and body.angular_velocity.is_finite() and measured_max_speed<=Motion.TOP_SPEED+.3 and measured_max_step<=Motion.TOP_SPEED/60.0+.02,{"max_speed_kmh":measured_max_speed*3.6,"max_frame_distance_m":measured_max_step,"per_frame_limit_m":Motion.TOP_SPEED/60.0+.02})
	clear_input()
	body.queue_free();await process_frame
	body=Factory.make("fighter","fighter_restored_fixture")
	body.apply_state(full_speed_save);scene.add_child(body);body.occupied=true
	await physics_frame
	await physics_frame
	var restored: Dictionary=await frames(120)
	check("Restored production aircraft preserves full-speed flight",restored.min_speed_mps>550 and body.health>99.9 and absf(restored.height_change)<1.0,restored)
	var report: Dictionary={"passed":failures==0,"checks":checks,"count":checks.size(),"failures":failures,"engine":Engine.get_version_info().string,"backend":ProjectSettings.get_setting("physics/3d/physics_engine"),"engine_velocity_limit":ProjectSettings.get_setting("physics/jolt_physics_3d/limits/max_linear_velocity"),"physics_hz":60,"scope":"Actual production HarborVehicle/Factory/Models/Motion, isolated real Jolt scene and Input actions; frozen new copy boarded through production pending launch, no pose or velocity writes while flying. Immediate save and 2000 km/h save/reload included; city spawning, destruction and weapons integration tested by root","model_sha256":FileAccess.get_sha256("res://scripts/fighter_models.gd"),"motion_sha256":FileAccess.get_sha256("res://scripts/fighter_motion.gd"),"vehicle_sha256":FileAccess.get_sha256("res://scripts/harbor_vehicle.gd"),"factory_sha256":FileAccess.get_sha256("res://scripts/vehicle_factory.gd"),"project_sha256":FileAccess.get_sha256("res://project.godot"),"test_sha256":FileAccess.get_sha256("res://../source/fighter_flight_test.gd")}
	DirAccess.make_dir_recursive_absolute("res://../reports/fighter-flight")
	var file:=FileAccess.open("res://../reports/fighter-flight/checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("FIGHTER_FLIGHT_COMPLETE ",checks.size()," passed=",failures==0)
	quit(failures)
