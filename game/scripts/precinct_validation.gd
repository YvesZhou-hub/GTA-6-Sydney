extends Node
## Full production city, native captures and continuous walks using the player controller.
## Route origins are test setup; subsequent movement uses input actions, never teleports.
const MODULE_PATHS := ["res://scripts/opera_landmark.gd", "res://scripts/opera_interiors.gd", "res://scripts/darling_square_detail.gd", "res://scripts/darling_public_facilities.gd", "res://scripts/darling_precinct_businesses.gd", "res://scripts/circular_quay_detail.gd", "res://scripts/sydney_tower_landmark.gd", "res://scripts/city_landmarks.gd", "res://scripts/icc_landmarks.gd", "res://scripts/quay_landmarks.gd", "res://scripts/bank_landmarks.gd", "res://scripts/manowar_detail.gd"]
var game
var checks:Array=[]
var screenshots:Array=[]
var routes:Array=[]
var native:=false

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(title:String,passed:bool,detail:Dictionary={}):
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("PRECINCT_QA ","PASS " if passed else "FAIL ",title)

func vector(value:Vector3) -> Array: return [value.x,value.y,value.z]

func capture(name:String,eye:Vector3,target:Vector3):
	if not native:return
	# These documentation viewpoints keep the actual city trees intact while
	# looking above or below foreground crowns. They do not alter play cameras.
	var public_space_views:={
		"darling_waterplay":[Vector3(-799,6.8,1650),Vector3(-806,5.8,1644.5)],
		"darling_octanet":[Vector3(-845,24,1644),Vector3(-847,9.5,1625)],
		"darling_wide_slide":[Vector3(-843,7,1652),Vector3(-844.8,6.0,1644.2)],
		"tumbalong_fountains":[Vector3(-821,20,1871),Vector3(-816.5,4.7,1846.5)]
	}
	if public_space_views.has(name):
		eye=public_space_views[name][0]
		target=public_space_views[name][1]
	game.camera.global_position=eye
	game.camera.look_at(target)
	for i in 6:
		RenderingServer.force_draw(false)
		await get_tree().process_frame
	var path:="user://precinct-qa/"+name+".png"
	var picture:=get_tree().root.get_texture().get_image()
	var saved:=picture.save_png(path)==OK
	screenshots.append({"file":name+".png","saved":saved,"camera":vector(eye),"target":vector(target),"resolution":[picture.get_width(),picture.get_height()]})
	check("native capture "+name,saved)

func walk(route:Dictionary):
	var points:Array=route.points
	if points.size()<2:
		check("walk route has an origin and destination "+str(route.name),false)
		return
	var player=game.player
	player.enabled=false
	player.global_position=points[0]+Vector3.UP*.08
	player.last_safe=player.global_position
	player.velocity=Vector3.ZERO
	player.reset_physics_interpolation()
	player.enabled=true
	for i in 20:await get_tree().physics_frame
	var okay:=true
	var records:Array=[]
	var previous:Vector3=player.global_position
	var discontinuities:=0
	for target:Vector3 in points.slice(1):
		var distance:float=Vector2(target.x-player.position.x,target.z-player.position.z).length()
		var frame_limit:=maxi(180,ceili(distance/5.2*60.0*2.2)+90)
		var frames:=0
		while frames<frame_limit:
			var delta:Vector3=target-player.global_position
			if Vector2(delta.x,delta.z).length()<.42:break
			game.yaw=atan2(-delta.x,-delta.z)
			player.yaw=game.yaw
			Input.action_press("forward")
			await get_tree().physics_frame
			frames+=1
			if previous.distance_to(player.global_position)>1.0:discontinuities+=1
			previous=player.global_position
		Input.action_release("forward")
		for i in 8:await get_tree().physics_frame
		var remaining:float=Vector2(target.x-player.position.x,target.z-player.position.z).length()
		var reached:bool=remaining<.60 and absf(player.global_position.y-target.y)<.65
		var contacts:Array=[]
		if not reached:
			for index in player.get_slide_collision_count():
				var contact=player.get_slide_collision(index)
				var collider=contact.get_collider()
				contacts.append({"body":str(collider.get_meta("damage_id",collider.name)) if is_instance_valid(collider) else "none","position":vector(contact.get_position()),"normal":vector(contact.get_normal())})
		records.append({"target":vector(target),"actual":vector(player.global_position),"frames":frames,"reached":reached,"distance":remaining,"contacts":contacts})
		if not reached:
			okay=false
			break
	player.enabled=false
	routes.append({"name":route.name,"passed":okay and discontinuities==0,"origin":vector(points[0]),"segments":records,"discontinuities":discontinuities})
	check("continuous player walk "+str(route.name),okay and discontinuities==0,{"segments":records.size(),"discontinuities":discontinuities})
	if okay:
		check("map migration preserves actual settled player "+str(route.name),not preload("res://scripts/map_migration.gd")._player_needs_relocation(game,player.global_position))
	print("PRECINCT_WALK ",JSON.stringify(routes[-1]))

func run():
	game=get_parent()
	native=DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute("user://precinct-qa")
	game.new_world("sandbox","Precinct walk QA",false)
	game.world_id="qa_precinct_"+str(Time.get_ticks_usec())
	game.set_process(false)
	game.player.enabled=false
	game.canvas.hide()
	for vehicle in game.vehicles:vehicle.freeze=true
	if native:RenderingServer.render_loop_enabled=false
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("complete production city ready",game.world._ready_complete)
	check("both Opera halls are actually built",game.world.has_meta("opera_interiors") and game.world.get_meta("opera_interiors",[]).size()==4 and int(game.world.get_meta("opera_concert_seats",0))>0 and int(game.world.get_meta("opera_jst_seats",0))>0)
	var authored_shop_ids:Array=[]
	for path:String in ["res://assets/darling_square_frontages.json","res://assets/darling_precinct_frontages.json"]:
		for shop:Dictionary in JSON.parse_string(FileAccess.get_file_as_string(path)).shops:
			if not str(shop.get("osm","")).is_empty():authored_shop_ids.append(shop.osm)
	var duplicate_signs:Array=[]
	for node in game.world.get_children():
		if node.has_meta("osm_id") and node.get_meta("osm_id") in authored_shop_ids:duplicate_signs.append(node.get_meta("osm_id"))
	check("authored shop signs replace generic floating labels",duplicate_signs.is_empty(),{"duplicates":duplicate_signs})
	var catalog:Array=game.landmark_catalog()
	var camera_views:Array=[]
	var walking_routes:Array=[]
	for path:String in MODULE_PATHS:
		if not ResourceLoader.exists(path):
			check("authored precinct module bundled "+path,false)
			continue
		var model=load(path)
		var module_ready:bool=model!=null and model.has_method("build")
		if not path.ends_with("darling_square_detail.gd"):module_ready=module_ready and model.has_method("capture_views")
		check("authored precinct module loaded "+path,module_ready)
		if not module_ready:continue
		if model.has_method("capture_views"):
			var views:Array=model.capture_views()
			camera_views.append_array(views)
			if path.ends_with("opera_landmark.gd"):check("Opera exterior has views of distinct sides",views.size()>=4)
			if path.ends_with("opera_interiors.gd"):check("both halls and public foyers have interior views",views.size()>=6)
		if model.has_method("walk_routes"):walking_routes.append_array(model.walk_routes())
		if model.has_method("metadata"):
			for place:Dictionary in model.metadata():
				if not place.has("arrival"):continue
				var id:String=place.id
				check("authored place has matching map destination "+id,catalog.any(func(item):return item.key==id and item.position.distance_to(place.arrival)<.01))
	check("new exterior and interior capture views supplied",camera_views.size()>=8)
	check("Opera, Darling and Quay continuous walking routes supplied",walking_routes.size()>=11)
	for route:Dictionary in walking_routes:await walk(route)
	game.player.visible=false
	game.life.set_process(false)
	if is_instance_valid(game.life._marker):game.life._marker.hide()
	for view:Array in camera_views:await capture(view[0],view[1],view[2])
	var passed:=checks.all(func(item):return item.passed)
	var report={"passed":passed,"native":native,"checks":checks,"routes":routes,"screenshots":screenshots,"user_saves_touched":false,"scope":"Exportable production-world validator. Route starts are isolated setup; subsequent walks use production player physics and forward input actions. Native manual frames capture authored buildings in the complete city. This is not an OS hardware-input or real-world survey-accuracy claim."}
	FileAccess.open("user://precinct-qa/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PRECINCT_QA_COMPLETE ",checks.size()," passed=",passed)
	game.active=false
	game.finish_quit(0 if passed else 1)
