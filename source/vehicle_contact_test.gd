extends SceneTree
## Production contacts: settling/driving stay intact, real hits damage, sustained contact is not repeated damage.
var stage:Node3D
var checks:Array=[]
func _initialize(): call_deferred("run")
func ground_box(size:Vector3,at:Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	body.add_child(collision)
	body.position=at
	stage.add_child(body)
	return body
func make_car(at:Vector3):
	var car=load("res://scripts/harbor_vehicle.gd").new()
	car.configure("car","contact_probe")
	car.position=at
	stage.add_child(car)
	return car
func check(name:String,okay:bool,car):
	checks.append({"name":name,"passed":okay,"health":car.health,"impact":car.last_impact_info.duplicate(true)})
	print("PASS " if okay else "FAIL ",name," health=",car.health)
func reset():
	for action in ["forward","back","left","right","rise","fall","brake"]: Input.action_release(action)
	if is_instance_valid(stage):
		stage.queue_free()
		await process_frame
	stage=Node3D.new()
	root.add_child(stage)
	ground_box(Vector3(200,2,300),Vector3(0,3.5,0))
	await physics_frame
func run():
	for action in ["forward","back","left","right","rise","fall","brake"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	await reset()
	var gentle=make_car(Vector3(0,5.35,0))
	for i in 240: await physics_frame
	check("normal wheel settling causes no damage",gentle.health==100 and gentle.sleeping,gentle)
	await reset()
	var hard=make_car(Vector3(0,18,0))
	hard.linear_velocity=Vector3.DOWN*8
	for i in 240: await physics_frame
	check("hard landing damages vehicle without instant wrecking",hard.health<100 and hard.health>=76 and not hard.last_impact_info.is_empty(),hard)
	await reset()
	var driving=make_car(Vector3(0,5.3,50))
	driving.occupied=true
	Input.action_press("forward")
	for i in 150: await physics_frame
	Input.action_release("forward")
	Input.action_press("brake")
	for i in 120: await physics_frame
	Input.action_release("brake")
	check("straight acceleration and emergency brake do not damage body",driving.health==100,driving)
	await reset()
	ground_box(Vector3(30,12,2),Vector3(0,10.5,-75))
	var wall=make_car(Vector3(0,5.3,0))
	wall.occupied=true
	Input.action_press("forward")
	for i in 480: await physics_frame
	Input.action_release("forward")
	check("normal throttle into real wall damages body but remains drivable",wall.health<100 and wall.health>=70 and not wall.last_impact_info.is_empty(),wall)
	var after_first_contact:float=wall.health
	Input.action_press("forward")
	for i in 180: await physics_frame
	Input.action_release("forward")
	check("continuing to push wall does not repeatedly deduct impact health",is_equal_approx(wall.health,after_first_contact),wall)
	var passed:=true
	for result in checks:
		if not result.passed: passed=false
	var report={"passed":passed,"checks":checks,"scope":"Native production vehicle contacts on controlled physical surfaces; no user saves"}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../reports/vehicle-contact.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("VEHICLE_CONTACT ",JSON.stringify(report))
	stage.queue_free()
	await process_frame
	quit(0 if passed else 1)
