extends CharacterBody3D
## The resident the player controls. The model and its animation clips are CC0
## by Quaternius; see assets/thirdparty/SOURCES.md.
const Visual = preload("res://scripts/character_visual.gd")
const HEIGHT := 1.8

var enabled = false
var yaw = 0.0
var swimming = false
var visual: Visual
var model_key := "casual"
var armed_pose := false
var last_safe = Vector3.ZERO
var stamina = 100.0
var foot_clock = 0.0
var max_health: float = 120.0
var health: float = 120.0
var damage_cooldown: float = 0.0
var last_damage_origin := Vector3.ZERO
signal footstep(water: bool)
signal landed(speed: float)
signal health_changed(current: float, maximum: float)
signal defeated

func take_damage(amount: float, origin: Vector3 = Vector3.ZERO) -> float:
	if not is_finite(amount) or amount <= 0.0 or health <= 0.0 or damage_cooldown > 0.0:
		return 0.0
	var removed := minf(health, amount)
	health = maxf(0.0, health - removed)
	damage_cooldown = 0.6
	last_damage_origin = origin if origin.is_finite() else Vector3.ZERO
	health_changed.emit(health, max_health)
	if is_instance_valid(visual): visual.set_state("death" if health <= 0.0 else "hit", 1.1, true)
	if health <= 0.0: defeated.emit()
	return removed

func reset_health() -> void:
	health = max_health
	damage_cooldown = 0.0
	if is_instance_valid(visual): visual.set_state("idle", 1.0, true)
	health_changed.emit(health, max_health)

func heal(amount: float) -> float:
	if not is_finite(amount) or amount <= 0.0 or health <= 0.0: return 0.0
	var restored := minf(amount, maxf(0.0, max_health - health))
	health += restored
	if restored > 0.0: health_changed.emit(health, max_health)
	return restored

func _ready():
	name = "Resident"
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.78
	var shape = CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	visual = Visual.new()
	add_child(visual)
	visual.setup(model_key, HEIGHT)
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(48)

func _physics_process(delta):
	damage_cooldown = maxf(0.0, damage_cooldown - delta)
	if not enabled or health <= 0.0: return
	var direction = Input.get_vector("left","right","forward","back")
	var move = Vector3(direction.x,0,direction.y).rotated(Vector3.UP,yaw)
	swimming = global_position.y < 0.65 and not is_on_floor() and not preload("res://scripts/metro_entrances.gd").contains_dry_volume(global_position)
	var sprint = Input.is_action_pressed("sprint") and stamina > 1 and not swimming
	var target = move * (9.0 if sprint else (3.2 if swimming else 5.2))
	stamina = clampf(stamina + (-17.0 if sprint and move.length()>0 else 14.0)*delta,0,100)
	velocity.x = move_toward(velocity.x,target.x,22*delta)
	velocity.z = move_toward(velocity.z,target.z,22*delta)
	if swimming:
		velocity.y += (0.2-global_position.y)*16*delta - velocity.y*3*delta
		if Input.is_action_pressed("jump"): velocity.y = 3.8
	else:
		velocity.y -= 22*delta
		if is_on_floor():
			last_safe = global_position
			if Input.is_action_just_pressed("jump"): velocity.y = 7.5
	if is_on_floor() and move.length()>0.1 and test_move(global_transform,move.normalized()*0.38):
		var raised=global_transform
		raised.origin.y+=0.42
		if not test_move(raised,move.normalized()*0.42):
			global_position.y+=0.42
	var before = velocity.y
	move_and_slide()
	if is_on_floor() and before < -9: landed.emit(-before)
	for i in get_slide_collision_count():
		var hit = get_slide_collision(i)
		var other = hit.get_collider()
		if other is RigidBody3D:
			other.apply_central_impulse(-hit.get_normal()*minf(60,other.mass*0.35))
	if move.length() > 0.1: visual.face(move, delta)
	_animate(delta)
	visual.rotation.x = lerpf(visual.rotation.x,-0.8 if swimming else 0,delta*4)
	if move.length()>0.1 and (is_on_floor() or swimming):
		foot_clock += delta
		if foot_clock>(0.28 if sprint else 0.43):
			foot_clock=0
			footstep.emit(swimming)
	if global_position.y < -80: recover()

func recover():
	global_position = last_safe + Vector3.UP*2
	reset_physics_interpolation()
	velocity = Vector3.ZERO


## Picks the clip that matches how the resident is actually moving.
func _animate(delta: float) -> void:
	if health <= 0.0:
		visual.set_state("death", 1.0, true)
		return
	if visual.playing_one_shot(): return
	var armed := armed_pose
	var speed := Vector2(velocity.x, velocity.z).length()
	if swimming:
		visual.set_state("swim", clampf(speed / 3.2, 0.6, 1.4))
	elif not is_on_floor():
		visual.set_state("air", 1.0)
	elif speed < 0.35:
		visual.set_state("idle_armed" if armed else "idle")
	elif speed < 3.4:
		visual.set_state("walk", clampf(speed / 1.6, 0.7, 1.8))
	else:
		visual.set_state("run_armed" if armed else "run", clampf(speed / 5.2, 0.8, 1.7))


## Survival mode shows a weapon; the armed clips keep the hands on it.
func set_armed(value: bool) -> void:
	armed_pose = value
