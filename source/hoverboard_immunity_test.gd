extends SceneTree
const Vehicle=preload("res://scripts/harbor_vehicle.gd")
var checks:Array=[]
var stage:Node3D
func _initialize():call_deferred("run")
func check(title:String,passed:bool,detail:Dictionary={}):
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("HOVER_IMMUNITY ","PASS " if passed else "FAIL ",title)
func steps(count:int):
	for i in count:await physics_frame
func solid(label:String,at:Vector3,size:Vector3):
	var b:=StaticBody3D.new();b.name=label;b.position=at;b.collision_layer=2
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;b.add_child(shape);stage.add_child(b)
func run():
	for action in ["forward","back","left","right","rise","fall","brake","drift","boost"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
		Input.action_release(action)
	stage=Node3D.new();root.add_child(stage)
	solid("ground",Vector3(0,-1,0),Vector3(1000,2,1000))
	solid("wall",Vector3(0,20,-4),Vector3(30,40,1))
	var board=Vehicle.new();board.configure("hoverboard","qa_immune_board")
	var old={"health":0,"fuel":42,"dents":[[.2,0,0]],"position":[0,1,-2.2],"velocity":[0,0,-50],"hover_lift_offset":7.5}
	board.apply_state(JSON.parse_string(JSON.stringify(old)));stage.add_child(board)
	check("damaged legacy hoverboard restores health and discards damage before first tick",board.health==100 and board._dents.is_empty() and board._dent_nodes.is_empty())
	check("legacy identity position fuel and lift survive immunity migration",board.vehicle_id=="qa_immune_board" and board.position.distance_to(Vector3(0,1,-2.2))<.001 and board.fuel==42 and board.get_meta("hover_lift_offset")==7.5)
	check("hoverboard immunity does not grant combat crushing",board.is_damage_immune() and not board.is_invincible())
	var impacts:Array=[];board.impacted.connect(func(point,energy):impacts.append({"point":point,"energy":energy}))
	board.occupied=true
	await steps(180)
	check("real wall impact retains physical contact and event",not impacts.is_empty() and not board.last_impact_info.is_empty(),{"impacts":impacts.size(),"contact":board.last_impact_info})
	check("real collision leaves hoverboard intact and smoke-free",board.health==100 and board._dents.is_empty() and board._dent_nodes.is_empty() and not board._smoke.emitting and board._moving.material.albedo_color==board._base_paint)
	var water=Vehicle.new();water.configure("hoverboard","qa_immune_water");water.position=Vector3(1500,-8,0);stage.add_child(water);water.occupied=true
	await steps(120)
	check("submerged hoverboard does not lose health",water.health==100 and water._dents.is_empty() and not water._smoke.emitting,{"height":water.position.y})
	var saved:Dictionary=JSON.parse_string(JSON.stringify(board.get_state()))
	var restored=Vehicle.new();restored.configure("hoverboard","qa_immune_restored");restored.apply_state(saved);stage.add_child(restored);restored.freeze=true
	check("save and reload persist undamaged board",restored.health==100 and restored._dents.is_empty() and not restored._smoke.emitting and restored.fuel==board.fuel)
	var car=Vehicle.new();car.configure("car","qa_normal_damage");stage.add_child(car);car.freeze=true
	car.apply_state({"position":[100,1,0],"health":37,"fuel":42,"dents":[[.2,0,0]],"frozen":true})
	check("ordinary vehicles still preserve saved damage",car.health==37 and car.fuel==42 and car._dents.size()==1 and car._dent_nodes.size()==1)
	car.repair();await process_frame
	check("repair clears normal damage smoke and darkened paint",car.health==100 and car._dents.is_empty() and car._dent_nodes.is_empty() and not car._smoke.emitting and car._moving.material.albedo_color==car._base_paint)
	var report={"passed":checks.all(func(c):return c.passed),"checks":checks}
	var file=FileAccess.open("res://../reports/hoverboard-immunity.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	stage.queue_free();await process_frame;await process_frame
	quit(0 if report.passed else 1)
