extends Node
## Regression for the reported stair/podium fall: complete city and production controllers.
const Opera = preload("res://scripts/opera_landmark.gd")
var game
var checks:Array=[]
var journeys:Array=[]
var screenshots:Array=[]

func _ready():call_deferred("run")
func point(p:Vector3)->Vector3:return Opera.CENTER+Opera.site_basis()*p
func local(p:Vector3)->Vector3:return Opera.site_basis().inverse()*(p-Opera.CENTER)
func vector(p:Vector3)->Array:return [p.x,p.y,p.z]
func stair_y(z:float)->float:return clampf((95.76-z)/29.76,0,1)*11.2
func check(name:String,okay:bool,detail:Dictionary={}):
	checks.append({"name":name,"passed":okay,"detail":detail})
	print("OPERA_ACCESS ","PASS " if okay else "FAIL ",name," ",JSON.stringify(detail))

func support_grid(label:String):
	var missing:Array=[];var samples:=0;var maximum_error:=0.0
	var space:PhysicsDirectSpaceState3D=game.world.get_world_3d().direct_space_state
	# Includes the exact top join, either side, and all eight former full-width sections.
	for x in range(-47,48,2):
		for z in [64.0,65.8,65.98,66.0,66.02,66.2,67.5,71.5,75.5,79.5,83.5,87.5,91.5,94.5]:
			var y:float=stair_y(z)
			var query:=PhysicsRayQueryParameters3D.create(point(Vector3(x,y+.35,z)),point(Vector3(x,y-.4,z)),1)
			var hit:Dictionary={}
			var accepted:=false
			# Inspect the stair itself, including beneath the higher restaurant floor.
			# An overhead floor or grazing glass edge must not conceal a missing stair.
			for retry in 8:
				hit=space.intersect_ray(query)
				if hit.is_empty():break
				var id:String=str(hit.collider.get_meta("damage_id",""))
				var correct_body:bool=id.begins_with("opera/steps/") or (z<=66.0 and id.begins_with("opera/podium/upper/"))
				if hit.normal.y>=.8 and correct_body:
					accepted=true;break
				var excluded:Array[RID]=query.exclude;excluded.append(hit.rid);query.exclude=excluded
			samples+=1
			var error:float=INF if hit.is_empty() else absf(hit.position.y-Opera.CENTER.y-y)
			if not hit.is_empty():maximum_error=maxf(maximum_error,error)
			if not accepted or error>.10:
				if missing.size()<12:missing.append({"x":x,"z":z,"expected_y":y,"hit":"none" if hit.is_empty() else str(hit.collider.name),"height_error":error if not is_inf(error) else -1})
	check(label+" full-width stair and landing support",missing.is_empty(),{"samples":samples,"maximum_height_error_m":maximum_error,"first_failures":missing})

func walk(label:String,x:float,start_z:float,end_z:float):
	var player=game.player
	player.enabled=false
	player.global_position=point(Vector3(x,stair_y(start_z)+.08,start_z))
	player.velocity=Vector3.ZERO;player.last_safe=player.global_position;player.reset_physics_interpolation()
	player.enabled=true
	for i in 12:await get_tree().physics_frame
	var target:=point(Vector3(x,stair_y(end_z),end_z))
	var previous:Vector3=player.global_position
	var drops:=0;var jumps:=0;var frames:=0;var reached:=false
	for frame in 750:
		var delta:Vector3=target-player.global_position;delta.y=0
		if delta.length()<.34:reached=true;break
		game.yaw=atan2(-delta.x,-delta.z);player.yaw=game.yaw
		Input.action_press("forward")
		await get_tree().physics_frame
		frames+=1
		var p:=local(player.global_position)
		if p.y<stair_y(p.z)-.42:drops+=1
		if player.global_position.distance_to(previous)>1:jumps+=1
		previous=player.global_position
		if drops>10:break
	Input.action_release("forward")
	for i in 8:await get_tree().physics_frame
	var okay:bool=reached and drops==0 and jumps==0 and absf(player.global_position.y-target.y)<.45
	var record:={"name":label,"passed":okay,"frames":frames,"below_surface_frames":drops,"discontinuities":jumps,"actual_local":vector(local(player.global_position)),"target_local":[x,stair_y(end_z),end_z]}
	journeys.append(record);check(label,okay,record)
	player.enabled=false

func hover(label:String,x:float,start_z:float,end_z:float):
	var board=load("res://scripts/harbor_vehicle.gd").new()
	board.configure("hoverboard","qa_opera_access_"+str(journeys.size()))
	game.add_child(board)
	board.global_position=point(Vector3(x,stair_y(start_z)+1.0,start_z))
	board.global_basis=Opera.site_basis()*Basis(Vector3.UP,0 if end_z<start_z else PI)
	board.occupied=true;board._was_occupied=true
	board.impacted.connect(func(p,e):game.world.damage_at(p,e))
	board.reset_physics_interpolation()
	var below:=0;var frames:=0;var reached:=false
	var previous:Vector3=board.global_position;var jumps:=0
	for frame in 360:
		var p:=local(board.global_position)
		if (end_z<start_z and p.z<=end_z) or (end_z>start_z and p.z>=end_z):reached=true;break
		Input.action_press("forward",.13)
		await get_tree().physics_frame
		frames+=1;p=local(board.global_position)
		if p.y<stair_y(p.z)+.3:below+=1
		if previous.distance_to(board.global_position)>1:jumps+=1
		previous=board.global_position
		if below>10:break
	Input.action_release("forward")
	var okay:bool=reached and below==0 and jumps==0 and board.health>=99.9
	var record:={"name":label,"passed":okay,"frames":frames,"below_surface_frames":below,"discontinuities":jumps,"health":board.health,"actual_local":vector(local(board.global_position)),"target_z":end_z,"last_impact":board.last_impact_info}
	journeys.append(record);check(label,okay,record)
	board.queue_free();await get_tree().physics_frame

func capture(name:String,eye:Vector3,target:Vector3):
	if DisplayServer.get_name()=="headless":return
	game.camera.global_position=point(eye);game.camera.look_at(point(target))
	for i in 6:
		RenderingServer.force_draw(false)
		await get_tree().process_frame
	var image:=get_tree().root.get_texture().get_image()
	var path:="user://opera-access-qa/"+name+".png"
	var okay:=image.save_png(path)==OK
	screenshots.append({"name":name,"saved":okay,"camera_local":vector(eye),"target_local":vector(target)})
	check("native screenshot "+name,okay)

func run():
	game=get_parent()
	DirAccess.make_dir_recursive_absolute("user://opera-access-qa")
	game.new_world("sandbox","Opera stairs regression",false)
	game.world_id="qa_opera_access_"+str(Time.get_ticks_usec())
	game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
	game.player.enabled=false;game.player.visible=false;game.canvas.hide();game.life.set_process(false)
	if is_instance_valid(game.life._marker):game.life._marker.hide()
	for vehicle in game.vehicles:vehicle.freeze=true
	for action in ["forward","back","left","right","rise","fall","jump","sprint","brake"]:InputMap.action_erase_events(action)
	if DisplayServer.get_name()!="headless":RenderingServer.render_loop_enabled=false
	await get_tree().physics_frame;await get_tree().physics_frame
	check("complete production city ready",game.world._ready_complete)
	support_grid("intact")
	for x in [-24.0,0.0,23.0,46.0]:
		await walk("intact upper join uphill x="+str(x),x,71,64)
		await walk("intact upper join downhill x="+str(x),x,64,71)
	await walk("intact full stair uphill",0,94,64)
	await walk("intact full stair downhill",0,64,94)
	await hover("intact hoverboard uphill",0,75,64)
	await hover("intact hoverboard downhill",23,64,80)
	await capture("opera-stair-join-intact",Vector3(45,18,76),Vector3(0,11.2,65.7))
	# Reproduce a real old-world structural state without opening a player's save.
	var old_ids:Array=[]
	for i in 8:old_ids.append("opera/steps/"+str(i))
	game.world.apply_state({"destroyed":old_ids,"partial":{},"rubble":[]})
	await get_tree().physics_frame;await get_tree().physics_frame
	var saved:Dictionary=game.world.get_state()
	game.world.apply_state(saved)
	await get_tree().physics_frame;await get_tree().physics_frame
	check("old stair destruction history survives reload",old_ids.all(func(id):return id in game.world.get_state().destroyed))
	support_grid("loaded legacy stair damage")
	await walk("legacy damage full stair uphill",0,94,64)
	await walk("legacy damage full stair downhill",0,64,94)
	await hover("legacy damage hoverboard uphill",0,75,64)
	await hover("legacy damage hoverboard downhill",23,64,80)
	await capture("opera-stair-join-legacy-save",Vector3(45,18,76),Vector3(0,11.2,65.7))
	# A localized impact must not remove a 97m-wide strip of traversable ground.
	game.world.damage_at(point(Vector3(0,10.5,67.5)),450000,2)
	await get_tree().physics_frame;await get_tree().physics_frame
	var damaged_finish:Array=game.world.destroyed.keys().filter(func(id):return str(id).begins_with("opera/steps/tread/"))
	var damaged_core:Array=game.world.destroyed.keys().filter(func(id):return str(id).begins_with("opera/steps/foundation/"))
	check("local impact removes finish without destroying its foundation",not damaged_finish.is_empty() and damaged_core.is_empty(),{"removed_finish":damaged_finish,"removed_foundations":damaged_core})
	support_grid("after local 450kJ impact")
	await walk("post-impact join uphill",0,71,64)
	await walk("post-impact join downhill",0,64,71)
	await hover("post-impact hoverboard uphill",0,75,64)
	await hover("post-impact hoverboard downhill",0,64,80)
	await capture("opera-stair-join-after-impact",Vector3(45,18,76),Vector3(0,11.2,65.7))
	var passed:bool=checks.all(func(item):return item.passed)
	var report:={"passed":passed,"checks":checks,"journeys":journeys,"screenshots":screenshots,"user_saves_touched":false,"scope":"Complete production city. Isolated intact, legacy destroyed-stair reload and localized impact states. Actual player and hoverboard controllers cross the join without repositioning after each route start; not an OS hardware-input or real-world survey claim."}
	FileAccess.open("user://opera-access-qa/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("OPERA_ACCESS_COMPLETE checks=",checks.size()," passed=",passed)
	game.active=false;game.finish_quit(0 if passed else 1)
