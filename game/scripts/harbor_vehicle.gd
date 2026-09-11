extends RigidBody3D
## Physically distinct, offline native vehicles. Units: metres / kilograms / seconds.
## Contacts emit kinetic energy in joules for the world damage system.
signal impacted(point: Vector3, energy: float)

const Models = preload("res://scripts/vehicle_factory.gd")
const G := 9.8
const TOP_SPEED_KMH := {"car":420.0,"motorcycle":320.0,"airliner":800.0,"helicopter":350.0}
const GLIDE_TRIM_SPEED := {"glider":28.0,"paraglider":11.5}
const NAMES := {"car":"Veloce V12", "motorcycle":"Apex RR", "speedboat":"Riviera 39", "yacht":"Ocean 90", "paraglider":"Thermal 9", "glider":"Southern Arc", "helicopter":"Harbour H6", "airliner":"Dreamliner 787-9", "hoverboard":"Aether X1"}
var kind: String = "car"
var vehicle_id: String = ""
var occupied: bool = false
var health: float = 100.0
var fuel: float = 100.0
var throttle: float = 0.0
var grounded: bool = false
var stalled: bool = false
var speed_kmh: float = 0.0
var controls_hint: String = "W/S accelerate • A/D steer • Space brake"
var _moving: Dictionary = {}
var _was_occupied: bool = false
var _impact_cooldown: float = 0.0
var _previous_velocity := Vector3.ZERO
var _engine: AudioStreamPlayer3D
var _hit_audio: AudioStreamPlayer3D
var _engine_target: float = -30.0
var _visual_time: float = 0.0
var _wake_time: float = 0.0
var _wake: Array = []
var _wake_cursor: int = 0
var _dents: Array = []
var _dent_nodes: Array[Node3D] = []
var _pending_state: Dictionary = {}
var _smoke: CPUParticles3D
var _restored: bool = false
var _idle_sleep_time := 0.0
var _built: bool = false
var last_impact_info: Dictionary = {}
var _base_paint: Color = Color("287b89")
var boat_profile: Dictionary = {}
var _launch_pending := false
var _launch_velocity := Vector3.ZERO
var _restore_motion_pending := false
var _restore_linear := Vector3.ZERO
var _restore_angular := Vector3.ZERO

func configure(type: String, id: String) -> void:
	kind = type if NAMES.has(type) else "car"
	vehicle_id = id
	name = id.validate_node_name()

func _ready() -> void:
	add_to_group("vehicles")
	set_meta("vehicle_id", vehicle_id)
	set_meta("interaction_name", NAMES.get(kind, kind))
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = true
	collision_layer = 4
	collision_mask = 15
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.015
	angular_damp = 0.1
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	var surface := PhysicsMaterial.new()
	surface.friction = 0.85 if kind in ["car", "motorcycle"] else (0.018 if kind == "airliner" else 0.52)
	surface.bounce = 0.08
	physics_material_override = surface
	match kind:
		"hoverboard": preload("res://scripts/hoverboard_motion.gd").setup(self)
		"car":
			linear_damp = 0.0
			mass = 1480.0
			inertia = mass*Vector3(1.85,2.15,0.48)
			center_of_mass = Vector3(0,-0.25,0)
		"motorcycle":
			linear_damp = 0.0
			mass = 265.0
			inertia = mass*Vector3(0.54,0.65,0.20)
			center_of_mass = Vector3(0,-0.24,0)
		"yacht":
			mass = 94000.0
			inertia = mass*Vector3(62.0,65.0,6.0)
			center_of_mass = Vector3(0,-0.33,0)
			controls_hint = "W/S twin engines • A/D rudder • Space reverse thrust"
		"speedboat":
			mass = 11500.0
			inertia = mass*Vector3(13.0,14.0,1.8)
			center_of_mass = Vector3(0,-0.35,0)
			controls_hint = "W/S throttle • A/D turn • Space reverse thrust"
		"paraglider":
			linear_damp = 0.0
			mass = 115.0
			inertia = mass*Vector3(1.5,3.0,1.2)
			controls_hint = "A/D turn • R/F pitch • Space airbrake • Always descending"
		"glider":
			linear_damp = 0.0
			mass = 570.0
			inertia = mass*Vector3(5.0,14.0,12.0)
			controls_hint = "A/D bank • R/F pitch • Space airbrake • No engine"
		"helicopter":
			linear_damp = 0.0
			mass = 6050.0
			inertia = mass*Vector3(13.0,14.0,3.8)
			center_of_mass = Vector3(0,-0.38,0)
			controls_hint = "W/S tilt forward/back • A/D yaw • R/F climb/descend"
		"airliner":
			linear_damp = 0.0
			mass = 145000.0
			inertia = mass*Vector3(220.0,340.0,125.0)
			center_of_mass = Vector3(0,-0.35,0)
			throttle = 0.68
			controls_hint = "W/S thrust • A/D bank • R/F pitch • Space speedbrake • Stall below 50 m/s"
	_moving = Models.build(self,kind)
	boat_profile=get_meta("boat_profile",{})
	if _moving.has("material"):
		_base_paint = _moving.material.albedo_color
	_setup_audio()
	_setup_smoke()
	if kind in ["yacht","speedboat"]:
		_setup_wake()
	_built = true
	if not _pending_state.is_empty():
		var data := _pending_state.duplicate(true)
		_pending_state.clear()
		apply_state(data)

func _physics_process(delta: float) -> void:
	_impact_cooldown = maxf(0.0,_impact_cooldown-delta)
	_visual_time += delta
	if occupied != _was_occupied and kind in ["car", "motorcycle"]:
		physics_material_override.friction = 0.07 if occupied else 0.85
	if occupied and not _was_occupied:
		sleeping = false
		prepare_for_boarding()
		if not _restored and global_position.y > 30.0 and linear_velocity.length()<4.0:
			match kind:
				"airliner": linear_velocity = -global_basis.z*82.0
		_restored = false
	_was_occupied = occupied
	# Truly idle rigid bodies use normal engine sleeping. Applying zero-input forces
	# every frame otherwise keeps every newly created copy awake indefinitely.
	if not occupied and (sleeping or freeze):
		_engine_target = -60.0
		if is_instance_valid(_engine): _engine.volume_db = -60.0
		return
	if not occupied and linear_velocity.length_squared()<0.012 and angular_velocity.length_squared()<0.01:
		_idle_sleep_time+=delta
	else: _idle_sleep_time=0.0
	if _idle_sleep_time>2.0:
		var has_support := not _ground_probe(5.0 if kind=="airliner" else 2.0).is_empty()
		if has_support or (kind in ["yacht","speedboat"] and global_position.y>0.3 and global_position.y<1.8):
			sleeping=true
			return
	var forward := -global_basis.z.normalized()
	var right := global_basis.x.normalized()
	var up := global_basis.y.normalized()
	var power := 0.0
	var steer := 0.0
	var pitch := 0.0
	var braking := false
	if occupied:
		power = Input.get_axis("back","forward")
		steer = Input.get_axis("left","right")
		pitch = Input.get_axis("fall","rise")
		braking = Input.is_action_pressed("brake")
		sleeping = false
	var operable: float = clampf(health/50.0,0.0,1.0) if fuel>0.0 else 0.0
	if health <= 0.0 and kind != "hoverboard":
		power = 0.0
		pitch = 0.0
	match kind:
		"hoverboard": preload("res://scripts/hoverboard_motion.gd").tick(self,delta,forward,right,up,power,steer,pitch,braking)
		"car", "motorcycle": _road(delta,forward,right,up,power*operable,steer,braking or not occupied)
		"yacht", "speedboat": _boat(delta,forward,right,up,power*operable,steer,braking)
		"paraglider", "glider": _gliding(delta,forward,right,up,steer,pitch,braking)
		"helicopter": _helicopter(delta,forward,right,up,power*operable,steer,pitch*operable)
		"airliner": _airliner(delta,forward,right,up,power,steer,pitch,braking,operable)
	# Immersion applies drag and small residual displacement buoyancy, not a blue floor.
	if not kind in ["yacht","speedboat"] and global_position.y < 0.0:
		var immersion := clampf(-global_position.y/2.5,0.0,1.0)
		apply_central_force(-linear_velocity*mass*immersion*1.8)
		apply_central_force(Vector3.UP*mass*G*immersion*0.72)
		if immersion>0.4:
			health = maxf(0.0,health-delta*3.0)
		_torque_accel(-angular_velocity*immersion*2.0)
	if not linear_velocity.is_finite():
		linear_velocity = Vector3.ZERO
	if not angular_velocity.is_finite():
		angular_velocity = Vector3.ZERO
	# Caps are numerical recovery guards above normal performance, not movement control.
	if linear_velocity.length()>240.0:
		linear_velocity = linear_velocity.limit_length(240.0)
	if angular_velocity.length()>5.0:
		angular_velocity = angular_velocity.limit_length(5.0)
	speed_kmh = linear_velocity.length()*3.6
	_animate(delta)
	_previous_velocity = linear_velocity

func _ground_probe(length: float = 1.65) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.15,global_position+Vector3.DOWN*length,15,[get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)

func _road(delta:float,f:Vector3,r:Vector3,u:Vector3,power:float,steer:float,brake:bool) -> void:
	var probe := _ground_probe()
	grounded = not probe.is_empty()
	var forward_speed := linear_velocity.dot(f)
	throttle = move_toward(throttle,power,delta*3.5)
	if grounded:
		var ground_normal: Vector3 = probe.normal
		var deck_velocity := Vector3.ZERO
		if probe.collider is RigidBody3D:
			deck_velocity = probe.collider.linear_velocity
		var rel: Vector3 = linear_velocity-deck_velocity
		forward_speed = rel.dot(f)
		var lateral := rel.dot(r)
		var traction := 8.0 if kind=="car" else 6.0
		var acceleration := 14.0 if kind=="car" else 16.0
		var target_speed := throttle*(float(TOP_SPEED_KMH[kind])/3.6 if throttle>=0 else 16.0)
		var resistance := forward_speed*.032+forward_speed*absf(forward_speed)*.00018
		var downforce := minf(forward_speed*forward_speed*.00025,3.8) if occupied else 0.0
		# Engine force, tyre resistance and aerodynamic drag determine speed. The
		# cruise governor reduces thrust continuously; it never clamps velocity.
		if absf(throttle)>.01:
			var rolling := (G+downforce)*.07*signf(forward_speed)
			var drive := clampf((target_speed-forward_speed)*.85+resistance+rolling,-acceleration,acceleration)
			apply_central_force(f*mass*drive)
		var lateral_accel := lateral*traction
		if occupied:lateral_accel=clampf(lateral_accel,-11.0,11.0)
		apply_central_force(-r*lateral_accel*mass)
		apply_central_force(-ground_normal*mass*downforce)
		var deceleration := clampf(forward_speed*7.0,-16.0,16.0) if brake else 0.0
		apply_central_force(-f*mass*(resistance+deceleration))
		var yaw_limit := minf(1.03 if kind=="car" else 1.30,8.5/maxf(absf(forward_speed),1.0))
		var yaw_rate := -steer*clampf(forward_speed/8.0,-1.0,1.0)*yaw_limit
		var desired_up: Vector3 = ground_normal
		if kind=="motorcycle":
			desired_up = (ground_normal+r*steer*clampf(absf(forward_speed)/17.0,0.0,0.50)).normalized()
		_torque_accel(u.cross(desired_up)*18.0 - Vector3(angular_velocity.x,0,angular_velocity.z)*5.0 + Vector3.UP*(yaw_rate-angular_velocity.y)*6.0)
	else:
		_torque_accel(-angular_velocity*0.10)
	if occupied and absf(throttle)>0.05:
		fuel = maxf(0.0,fuel-delta*absf(throttle)*0.006)
	_engine_target = -22.0 + absf(throttle)*9.0 if occupied and health>0.0 else -60.0

func _boat(delta:float,f:Vector3,r:Vector3,u:Vector3,power:float,steer:float,brake:bool) -> void:
	var fast:=kind=="speedboat"
	throttle = move_toward(throttle,power,delta*(1.2 if fast else 0.65))
	var in_water := false
	var support_x:=float(boat_profile.get("buoyancy_x",1.2 if fast else 2.6))
	var support_z:=float(boat_profile.get("buoyancy_z",3.8 if fast else 8.0))
	var rest_height:=float(boat_profile.get("float_height",0.9))
	for x in [-support_x,support_x]:
		for z in [-support_z,support_z]:
			var offset: Vector3 = global_basis*Vector3(x,0,z)
			var point: Vector3 = global_position+offset
			var wave: float = sin(point.x*0.044+_visual_time*1.1)*0.07 + sin(point.z*0.066+_visual_time*0.9)*0.045
			var depth: float = wave+rest_height+1.0/(4.0*0.42)-point.y
			if depth>0.0 and not preload("res://scripts/metro_entrances.gd").contains_dry_volume(point):
				in_water = true
				var vertical_speed: float = (linear_velocity+angular_velocity.cross(offset)).y
				var force: float = maxf(0.0,depth*mass*G*0.42-vertical_speed*mass*0.52)
				apply_force(Vector3.UP*minf(force,mass*G*1.25),offset)
	if in_water:
		var forward_speed := linear_velocity.dot(f)
		apply_central_force(f*mass*(4.0 if fast else 2.5)*throttle)
		apply_central_force(-r*linear_velocity.dot(r)*mass*1.55)
		apply_central_force(-f*forward_speed*absf(forward_speed)*mass*(0.009 if fast else 0.014))
		if brake:
			apply_central_force(-f*forward_speed*mass*0.36)
		var rudder := -steer*clampf(forward_speed/4.0,-1.0,1.0)*(0.40 if fast else 0.19)
		_torque_accel(Vector3.UP*(rudder-angular_velocity.y)*1.8-Vector3(angular_velocity.x,0,angular_velocity.z)*1.4)
		if u.y<0.65:
			_torque_accel(u.cross(Vector3.UP)*1.5)
	if occupied:
		fuel = maxf(0.0,fuel-delta*absf(throttle)*0.01)
	_engine_target = -25.0+absf(throttle)*11.0 if occupied and health>0 else -60.0
	_update_wake(delta,in_water)

func stop_motion_after_relocation() -> void:
	# Safety relocation supersedes a queued save restore or unconsumed launch.
	# Clear the serialized state too, so an immediate save cannot revive it.
	_launch_pending=false
	_launch_velocity=Vector3.ZERO
	_restore_motion_pending=false
	_restore_linear=Vector3.ZERO
	_restore_angular=Vector3.ZERO
	_previous_velocity=Vector3.ZERO
	linear_velocity=Vector3.ZERO
	angular_velocity=Vector3.ZERO
	throttle=0.0

func glide_trim_speed() -> float:
	return float(GLIDE_TRIM_SPEED.get(kind,0.0))

func prepare_for_boarding(was_frozen:bool=false) -> void:
	# Jolt can replace a velocity written while a newly added body is frozen.
	# Apply launch energy inside its first live integration step, exactly once.
	if not kind in ["glider","paraglider"] or global_position.y<30:return
	if _restored and not was_frozen:return
	if not was_frozen and linear_velocity.length()>4.0:return
	# Launch at the same airspeed used to size lift. A slower launch makes the
	# wing drop before gravity can accelerate it to its normal glide condition.
	var trim:=glide_trim_speed()
	if linear_velocity.length()>trim*1.5:return
	var drop := 0.22 if kind=="glider" else 0.52
	_launch_velocity=-global_basis.z*trim+Vector3.DOWN*drop
	_launch_pending=true

func _gliding(_delta:float,f:Vector3,r:Vector3,u:Vector3,steer:float,pitch:float,brake:bool) -> void:
	grounded = not _ground_probe(0.85).is_empty()
	var speed := maxf(0.0,linear_velocity.dot(f))
	var target_speed := glide_trim_speed()
	var min_speed := 7.2 if kind=="paraglider" else 18.0
	stalled = speed<min_speed and not grounded
	var local_velocity := global_basis.inverse()*linear_velocity
	var angle_of_attack := atan2(-local_velocity.y,maxf(speed,0.1))
	var lift_ratio := clampf(pow(speed/target_speed,2.0)*clampf(0.94+angle_of_attack*2.8,0.0,1.65),0.0,1.65)
	var effective_up := (u-linear_velocity.normalized()*u.dot(linear_velocity.normalized())).normalized()
	if effective_up.y<0.1:
		effective_up = u
	apply_central_force(effective_up*mass*G*lift_ratio*(0.73 if brake else 0.995))
	var drag_coefficient := 0.0065 if kind=="paraglider" else 0.0005
	apply_central_force(-linear_velocity*linear_velocity.length()*mass*drag_coefficient*(2.7 if brake else 1.0))
	apply_central_force(-r*linear_velocity.dot(r)*mass*0.75)
	# Gravity powers both wings. Nose-down trim trades height for forward speed.
	var wanted_pitch := -0.10 + pitch*0.28 if kind=="paraglider" else -0.025+pitch*0.23
	if stalled:
		wanted_pitch = -0.20
	var current_pitch := asin(clampf(f.y,-1.0,1.0))
	var roll_target := -steer*(0.30 if kind=="paraglider" else 0.52)
	var desired_up := (Vector3.UP+r*(-roll_target)).normalized()
	var pitch_accel := (wanted_pitch-current_pitch)*2.6
	var yaw_rate := -steer*(0.39 if kind=="paraglider" else 0.27)*clampf(speed/min_speed,0.15,1.0)
	_torque_accel(r*pitch_accel + f*(u.cross(desired_up).dot(f)*3.6) + Vector3.UP*(yaw_rate-angular_velocity.y)*2.4 - (r*angular_velocity.dot(r)+f*angular_velocity.dot(f))*2.0)
	# Soft fabric wing has considerably more vertical drag than a rigid sailplane.
	if kind=="paraglider" and linear_velocity.y < -2.0:
		apply_central_force(Vector3.UP*pow(-linear_velocity.y-2.0,2.0)*mass*0.38)
	_engine_target = -28.0+clampf(speed/target_speed,0.0,2.0)*5.0 if occupied else -60.0

func _helicopter(delta:float,f:Vector3,r:Vector3,u:Vector3,power:float,steer:float,pitch:float) -> void:
	grounded = not _ground_probe(1.6).is_empty()
	var engine_on := occupied and health>0.0 and fuel>0.0
	throttle = move_toward(throttle,1.0 if engine_on else 0.0,delta*.40)
	var horizontal_forward := Vector3(f.x,0,f.z).normalized()
	var forward_speed := linear_velocity.dot(horizontal_forward)
	var target_forward_speed := power*float(TOP_SPEED_KMH.helicopter)/3.6
	var drag := linear_velocity*(.02+linear_velocity.length()*.00035)
	# Rotor collective compensates its bank/tilt, maintaining commanded vertical
	# speed while the horizontal component accelerates the aircraft.
	var desired_vertical := pitch*8.0
	var vertical_accel := clampf((desired_vertical-linear_velocity.y)*1.75,-6.0,8.0)
	var collective := clampf((G+vertical_accel+drag.y)/maxf(u.y,.35),0.0,G*2.4)*throttle
	apply_central_force(u*mass*collective)
	apply_central_force(-drag*mass)
	apply_central_force(-r*linear_velocity.dot(r)*mass*.37)
	var desired_forward_accel := clampf((target_forward_speed-forward_speed)*.65,-8.0,8.0)
	var tilt := clampf((desired_forward_accel+drag.dot(horizontal_forward))/G,-.85,.95)
	var desired_up := (Vector3.UP+horizontal_forward*tilt).normalized()
	var yaw_rate := -steer*minf(.66,8.0/maxf(absf(forward_speed),1.0))
	_torque_accel(u.cross(desired_up)*4.2 - Vector3(angular_velocity.x,0,angular_velocity.z)*2.8 + Vector3.UP*(yaw_rate-angular_velocity.y)*2.5)
	if engine_on:fuel = maxf(0.0,fuel-delta*.016)
	_engine_target = -35.0+throttle*20.0

func _airliner(delta:float,f:Vector3,r:Vector3,u:Vector3,power:float,steer:float,pitch:float,brake:bool,operable:float) -> void:
	grounded = not _ground_probe(4.5).is_empty()
	if occupied:
		throttle = clampf(throttle+power*delta*0.22,0.0,1.0)
	var speed := maxf(0.0,linear_velocity.dot(f))
	stalled = speed<49.0 and not grounded
	var aerodynamic_drag := .000064
	var governed_thrust := clampf((float(TOP_SPEED_KMH.airliner)/3.6-speed)*.30+speed*speed*aerodynamic_drag,0.0,3.5)
	apply_central_force(f*mass*governed_thrust*throttle*operable*(1.0 if occupied else 0.0))
	var speed_ratio := speed/76.0
	var local_velocity := global_basis.inverse()*linear_velocity
	var angle_of_attack := atan2(-local_velocity.y,maxf(speed,0.1))
	var lift_coefficient := clampf(.97+angle_of_attack*4.6,0.0,1.8)
	if angle_of_attack>0.38:
		lift_coefficient *= 0.38
		stalled = not grounded
	var lift_factor := clampf(minf(speed_ratio*speed_ratio,1.0)*lift_coefficient,0.0,1.85)
	if speed<49.0:
		lift_factor *= clampf(speed/49.0,0.0,1.0)
	var velocity_direction := linear_velocity.normalized()
	var lift_direction := (u-velocity_direction*u.dot(velocity_direction)).normalized()
	apply_central_force(lift_direction*mass*G*lift_factor*(0.62 if brake else 1.0))
	apply_central_force(-linear_velocity*linear_velocity.length()*mass*(aerodynamic_drag if not brake else .00032))
	apply_central_force(-r*linear_velocity.dot(r)*mass*0.22)
	var current_pitch := asin(clampf(f.y,-1.0,1.0))
	var target_pitch := pitch*0.22 + 0.015
	if stalled:
		target_pitch = -0.15 + pitch*0.10
	var desired_up := (Vector3.UP+r*steer*0.56).normalized()
	var control_authority := clampf(speed/65.0,0.05,1.0)
	var yaw_rate := -steer*0.105*control_authority*minf(1.0,76.0/maxf(speed,1.0))
	if grounded:
		yaw_rate = -steer*clampf(speed/8.0,0.0,1.0)*0.16
		apply_central_force(-r*linear_velocity.dot(r)*mass*1.8)
		if brake or not occupied:
			apply_central_force(-f*speed*mass*0.60)
		# Pitch-up requires runway speed; low-speed thrust never creates hover.
		if speed<55.0:
			target_pitch = 0.0
			desired_up = Vector3.UP
	_torque_accel(r*(target_pitch-current_pitch)*1.4*control_authority + f*u.cross(desired_up).dot(f)*1.2*control_authority + Vector3.UP*(yaw_rate-angular_velocity.y)*1.6 - (r*angular_velocity.dot(r)+f*angular_velocity.dot(f))*1.4)
	if occupied and throttle>0.01 and operable>0.0:
		fuel = maxf(0.0,fuel-delta*throttle*0.02)
	_engine_target = -29.0+throttle*14.0 if occupied and operable>0 else -60.0

func _torque_accel(acceleration:Vector3) -> void:
	var local: Vector3 = global_basis.inverse()*acceleration
	apply_torque(global_basis*(local*inertia))

func _integrate_forces(state:PhysicsDirectBodyState3D) -> void:
	if _restore_motion_pending:
		state.linear_velocity=_restore_linear
		state.angular_velocity=_restore_angular
		_previous_velocity=_restore_linear
		_restore_motion_pending=false
	if _launch_pending:
		state.linear_velocity=_launch_velocity
		_previous_velocity=_launch_velocity
		_launch_pending=false
	if _impact_cooldown>0.0:
		return
	var worst_speed := 0.0
	var worst_point := global_position
	var worst_collider := ""
	var worst_normal := Vector3.ZERO
	var worst_contact := {}
	for i in state.get_contact_count():
		var other: Object = state.get_contact_collider_object(i)
		if other is Node and other.is_in_group("players") and occupied:
			continue
		var normal: Vector3 = state.get_contact_local_normal(i)
		var relative_velocity: Vector3 = _previous_velocity-state.get_contact_collider_velocity_at_position(i)
		var closing: float = maxf(0.0,-relative_velocity.dot(normal))
		# Native impulse detects contacts after the solver already removed speed.
		closing = maxf(closing,state.get_contact_impulse(i).length()/maxf(mass,1.0))
		if closing>worst_speed:
			worst_speed = closing
			worst_point = state.get_contact_local_position(i)
			worst_collider = str(other.get_path()) if other is Node else str(other)
			worst_normal = normal
			if worst_speed>3.5:
				worst_contact = {"previous_velocity":[_previous_velocity.x,_previous_velocity.y,_previous_velocity.z],"linear_velocity":[state.linear_velocity.x,state.linear_velocity.y,state.linear_velocity.z],"angular_velocity":[state.angular_velocity.x,state.angular_velocity.y,state.angular_velocity.z],"relative_velocity":[relative_velocity.x,relative_velocity.y,relative_velocity.z],"normal_closing":maxf(0.0,-relative_velocity.dot(normal)),"impulse_mps":state.get_contact_impulse(i).length()/maxf(mass,1.0),"impulse_normal_mps":absf(state.get_contact_impulse(i).dot(normal))/maxf(mass,1.0),"contact_count":state.get_contact_count(),"rotation":[rotation.x,rotation.y,rotation.z]}
	if worst_speed>3.5:
		_impact_cooldown = 0.30
		var energy := 0.5*mass*worst_speed*worst_speed
		var damage := clampf((worst_speed-3.5)*2.8,0.0,75.0)
		health = maxf(0.0,health-damage)
		last_impact_info = {"collider":worst_collider,"point":[worst_point.x,worst_point.y,worst_point.z],"normal":[worst_normal.x,worst_normal.y,worst_normal.z],"closing_mps":worst_speed,"energy_j":energy,"health":health}
		last_impact_info.merge(worst_contact)
		call_deferred("_show_impact",worst_point,energy)

func _show_impact(point:Vector3,energy:float) -> void:
	impacted.emit(point,energy)
	if _hit_audio:
		_hit_audio.volume_db = clampf(-20.0+log(maxf(1.0,energy/3000.0))*4.0,-20.0,0.0)
		_hit_audio.play()
	if _dents.size()<12:
		var local_point := to_local(point)
		_dents.append([local_point.x,local_point.y,local_point.z])
		_add_dent(local_point)

func _add_dent(point:Vector3) -> void:
	var size := 0.26 if kind!="airliner" else 1.15
	var mark := Models._ellipsoid(self,Vector3.ONE*size,point,Models.material(Color("303334"),0.1,0.97))
	_dent_nodes.append(mark)

func _setup_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_engine = AudioStreamPlayer3D.new()
	_engine.name = "EngineAndWind"
	_engine.stream = _synth_sound(false)
	_engine.unit_size = 9.0 if kind!="airliner" else 40.0
	_engine.max_distance = 230.0 if kind!="airliner" else 800.0
	_engine.attenuation_filter_cutoff_hz = 7000.0
	_engine.volume_db = -60.0
	add_child(_engine)
	_engine.play()
	_hit_audio = AudioStreamPlayer3D.new()
	_hit_audio.stream = _synth_sound(true)
	_hit_audio.unit_size = 16.0
	_hit_audio.max_distance = 260.0
	add_child(_hit_audio)

func _synth_sound(hit:bool) -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.65 if hit else 1.0
	var count := int(rate*duration)
	var samples := PackedByteArray()
	samples.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 51273+kind.hash()
	var smooth_noise := 0.0
	for i in count:
		var t := float(i)/rate
		var noise := rng.randf_range(-1.0,1.0)
		smooth_noise = lerpf(smooth_noise,noise,0.15)
		var value := 0.0
		if hit:
			value = (noise*0.58+sin(TAU*62.0*t)*0.42)*exp(-t*11.0)
		else:
			match kind:
				"car": value = sin(TAU*55*t)*0.32+sin(TAU*110*t)*0.18+sin(TAU*165*t)*0.08+smooth_noise*0.08
				"motorcycle": value = sin(TAU*73*t)*0.28+sin(TAU*146*t)*0.14+sin(TAU*219*t)*0.12+smooth_noise*0.10
				"yacht": value = sin(TAU*35*t)*0.36+sin(TAU*70*t)*0.17+smooth_noise*0.30
				"speedboat": value = sin(TAU*58*t)*0.29+sin(TAU*116*t)*0.20+smooth_noise*0.28
				"helicopter": value = (sin(TAU*60*t)*0.28+smooth_noise*0.43)*(0.55+sin(TAU*18*t)*0.45)
				"airliner": value = smooth_noise*0.54+sin(TAU*126*t)*0.10+sin(TAU*252*t)*0.04
				_: value = smooth_noise*0.62+noise*0.05
		var encoded := int(clampf(value,-1.0,1.0)*30000.0)
		samples.encode_s16(i*2,encoded)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = samples
	if not hit:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = count
	return wav

func _setup_smoke() -> void:
	_smoke = CPUParticles3D.new()
	_smoke.amount = 18
	_smoke.lifetime = 2.4
	_smoke.emitting = false
	_smoke.position = Vector3(0,0.8,-1.2)
	_smoke.direction = Vector3.UP
	_smoke.spread = 22.0
	_smoke.initial_velocity_min = 1.4
	_smoke.initial_velocity_max = 2.6
	_smoke.gravity = Vector3(0,0.6,0)
	_smoke.scale_amount_min = 0.10
	_smoke.scale_amount_max = 0.36 if kind!="airliner" else 1.4
	_smoke.color = Color(0.13,0.15,0.16,0.55)
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := Models.material(Color(0.15,0.17,0.18,0.46),0,1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	_smoke.mesh = mesh
	add_child(_smoke)

func _setup_wake() -> void:
	for i in 22:
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.75
		mesh.outer_radius = 1.0
		mesh.rings = 16
		mesh.ring_segments = 6
		ring.mesh = mesh
		var mat := Models.material(Color(0.78,0.94,0.95,0.45),0,0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		ring.top_level = true
		ring.visible = false
		_wake.append({"node":ring,"age":10.0,"mat":mat})

func _update_wake(delta:float,in_water:bool) -> void:
	_wake_time += delta
	var speed := linear_velocity.length()
	if in_water and speed>1.1 and _wake_time>0.18 and not _wake.is_empty():
		_wake_time = 0.0
		var wake: Dictionary = _wake[_wake_cursor]
		wake.age = 0.0
		wake.node.global_position = global_position+global_basis.z*float(boat_profile.get("wake_z",6.8))
		wake.node.global_position.y = 0.05
		wake.node.global_rotation = Vector3(0,rotation.y,0)
		wake.node.visible = true
		_wake_cursor = (_wake_cursor+1)%_wake.size()
	for wake in _wake:
		wake.age += delta
		if wake.age<4.0:
			wake.node.scale = Vector3(2.2+wake.age*1.8,0.045,0.7+wake.age*1.6)
			wake.mat.albedo_color.a = (1.0-wake.age/4.0)*0.4
		else:
			wake.node.visible = false

func _animate(delta:float) -> void:
	if _moving.get("rider") != null:
		_moving.rider.visible = occupied
	var forward_speed := linear_velocity.dot(-global_basis.z)
	for wheel in _moving.get("wheels",[]):
		wheel.rotate_x(-forward_speed*delta/float(wheel.get_meta("radius",0.4)))
	for rotor in _moving.get("rotors",[]):
		rotor.rotate_y(delta*(2.0+throttle*44.0))
	for prop in _moving.get("propellers",[]):
		if kind=="helicopter":
			prop.rotate_x(delta*(2.0+throttle*68.0))
		else:
			prop.rotate_z(delta*(8.0+throttle*80.0))
	if _engine:
		var volume := _engine_target if occupied or linear_velocity.length()>1.0 else -60.0
		_engine.volume_db = lerpf(_engine.volume_db,volume,1.0-exp(-delta*3.0))
		var pitch := 0.80+clampf(absf(forward_speed)/35.0,0.0,1.0)*0.80+absf(throttle)*0.24
		if kind=="helicopter": pitch = 0.75+throttle*0.45
		if kind=="airliner": pitch = 0.80+throttle*0.42
		_engine.pitch_scale = lerpf(_engine.pitch_scale,pitch,1.0-exp(-delta*3.0))
	if _smoke:
		_smoke.emitting = health<40.0
	if _moving.has("material"):
		_moving.material.albedo_color = _base_paint.lerp(Color("343c3e"),(1.0-health/100.0)*0.62)

func get_exit_position() -> Vector3:
	if kind=="hoverboard":return to_global(Vector3(1.4,0,0))
	if kind in ["yacht","speedboat"] and boat_profile.has("exit"):
		return to_global(boat_profile.exit)
	var offset := Vector3(-2.3,0.85,0)
	match kind:
		"motorcycle": offset = Vector3(-1.4,0.8,0)
		"yacht": offset = Vector3(-1.2,1.4,3.0)
		"paraglider": offset = Vector3(-1.3,0.6,0)
		"glider": offset = Vector3(-2.0,0.9,-1.3)
		"helicopter": offset = Vector3(-2.4,0.5,-0.5)
		"airliner": offset = Vector3(-4.5,1.2,-20.4)
	return to_global(offset)

func get_camera_distance() -> float:
	if kind=="hoverboard":return 7.0
	if kind in ["yacht","speedboat"]: return float(boat_profile.get("camera_distance",23.0 if kind=="speedboat" else 38.0))
	match kind:
		"motorcycle": return 6.5
		"yacht": return 20.0
		"paraglider": return 12.0
		"glider": return 20.0
		"helicopter": return 25.0
		"airliner": return 84.0
	return 9.0

func get_camera_height() -> float:
	if kind=="hoverboard":return 1.1
	if kind in ["yacht","speedboat"]: return float(boat_profile.get("camera_height",2.2 if kind=="speedboat" else 4.5))
	if kind=="car": return 0.40
	if kind=="motorcycle": return 0.65
	return 3.0 if kind=="airliner" else 1.5

func repair() -> void:
	health = 100.0
	fuel = 100.0
	for node in _dent_nodes:
		if is_instance_valid(node): node.queue_free()
	_dent_nodes.clear()
	_dents.clear()

func get_state() -> Dictionary:
	var q := global_basis.get_rotation_quaternion()
	var saved_velocity := _launch_velocity if _launch_pending else _restore_linear if _restore_motion_pending else linear_velocity
	var saved_angular := _restore_angular if _restore_motion_pending else angular_velocity
	return {"version":1,"model_revision":3,"kind":kind,"id":vehicle_id,"position":[global_position.x,global_position.y,global_position.z],"quaternion":[q.x,q.y,q.z,q.w],"velocity":[saved_velocity.x,saved_velocity.y,saved_velocity.z],"angular_velocity":[saved_angular.x,saved_angular.y,saved_angular.z],"health":health,"fuel":fuel,"throttle":throttle,"frozen":freeze,"hover_lift_offset":float(get_meta("hover_lift_offset",0.0)),"dents":_dents.duplicate(true)}

func apply_state(data:Dictionary) -> void:
	if not _built:
		_pending_state = data.duplicate(true)
		return
	var pos: Array = data.get("position",[0,7,0])
	var rot: Array = data.get("quaternion",[0,0,0,1])
	var vel: Array = data.get("velocity",[0,0,0])
	var ang: Array = data.get("angular_velocity",[0,0,0])
	if pos.size()==3:
		global_position = Vector3(float(pos[0]),float(pos[1]),float(pos[2]))
	if rot.size()==4:
		var q := Quaternion(float(rot[0]),float(rot[1]),float(rot[2]),float(rot[3]))
		if q.length_squared()>0.001:
			global_basis = Basis(q.normalized())
	if vel.size()==3:
		linear_velocity = Vector3(float(vel[0]),float(vel[1]),float(vel[2])).limit_length(240.0)
	if ang.size()==3:
		angular_velocity = Vector3(float(ang[0]),float(ang[1]),float(ang[2])).limit_length(5.0)
	health = clampf(float(data.get("health",100.0)),0.0,100.0)
	fuel = clampf(float(data.get("fuel",100.0)),0.0,100.0)
	throttle = clampf(float(data.get("throttle",0.68 if kind=="airliner" else 0.0)),-1.0,1.0)
	for node in _dent_nodes:
		if is_instance_valid(node): node.queue_free()
	_dent_nodes.clear()
	_dents = data.get("dents",[]).slice(0,12)
	for dent in _dents:
		if dent is Array and dent.size()==3:
			_add_dent(Vector3(float(dent[0]),float(dent[1]),float(dent[2])))
	set_meta("hover_lift_offset",clampf(float(data.get("hover_lift_offset",0.0)),0.0,180.0))
	freeze = bool(data.get("frozen",false))
	_launch_pending=false
	_restore_linear=linear_velocity
	_restore_angular=angular_velocity
	_restore_motion_pending=not freeze
	_restored = true
	sleeping = false
	reset_physics_interpolation()

func _exit_tree() -> void:
	if is_instance_valid(_engine):
		_engine.stop()
		_engine.stream = null
	if is_instance_valid(_hit_audio):
		_hit_audio.stop()
		_hit_audio.stream = null
