extends Node
## Tests the actual Viewport input pipeline, not direct calls to menu handlers.
var game
var checks:Array=[]
var screenshots:Array=[]
var routed_map_events:=0
var last_pointer:=Vector2(700,430)
var native:=false

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(title:String,okay:bool,detail:Dictionary={}):
	checks.append({"name":title,"passed":okay,"detail":detail})
	print("POINTER_QA ","PASS " if okay else "FAIL ",title)

func key(code:int,pressed:=true,echo_event:=false):
	var event:=InputEventKey.new()
	event.keycode=code;event.physical_keycode=code;event.pressed=pressed;event.echo=echo_event
	get_tree().root.push_input(event,true)

func tap(code:int):
	key(code);key(code,false)
	await get_tree().process_frame

func type_text(value:String):
	for character in value:
		var event:=InputEventKey.new()
		event.keycode=character.to_upper().unicode_at(0)
		event.physical_keycode=event.keycode
		event.unicode=character.unicode_at(0)
		event.pressed=true
		get_tree().root.push_input(event,true)
		event=event.duplicate()
		event.pressed=false
		get_tree().root.push_input(event,true)
	await get_tree().process_frame

func motion(point:Vector2,relative:Vector2,dragging:=false):
	var event:=InputEventMouseMotion.new()
	event.position=point;event.global_position=point;event.relative=relative
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if dragging else 0
	get_tree().root.push_input(event,true)
	last_pointer=point

func mouse(point:Vector2,pressed:bool,button:=MOUSE_BUTTON_LEFT):
	var event:=InputEventMouseButton.new()
	event.position=point;event.global_position=point;event.button_index=button;event.pressed=pressed
	get_tree().root.push_input(event,true)

func click(point:Vector2):
	motion(point,point-last_pointer)
	mouse(point,true);mouse(point,false)
	await get_tree().process_frame

func capture(name:String):
	if not native:return
	for i in 3:await get_tree().process_frame
	RenderingServer.force_draw(false)
	var picture:=get_tree().root.get_texture().get_image()
	var path:="user://navigation-input-qa/"+name+".png"
	var error:=picture.save_png(path)
	screenshots.append({"file":name+".png","saved":error==OK,"resolution":[picture.get_width(),picture.get_height()]})

func run():
	game=get_parent();native=DisplayServer.get_name()!="headless"
	get_tree().root.notify_mouse_entered()
	DirAccess.make_dir_recursive_absolute("user://navigation-input-qa")
	game.new_world("sandbox","Pointer input QA",false)
	game.world_id="qa_pointer_"+str(Time.get_ticks_usec())
	game.player.enabled=false
	for vehicle in game.vehicles:vehicle.freeze=true
	await get_tree().physics_frame
	await get_tree().physics_frame
	var map=game.map_panel
	map.gui_input.connect(func(_event):routed_map_events+=1)
	check("assembled world and actual map UI ready",game.world._ready_complete and map.data_loaded)
	check("new world captures pointer for camera",Input.mouse_mode==Input.MOUSE_MODE_CAPTURED)
	var original_yaw:float=game.yaw
	motion(Vector2(705,435),Vector2(24,0))
	check("normal gameplay mouse still turns camera",absf(game.yaw-original_yaw)>.01)
	await tap(KEY_M)
	check("M enters paused map and visibly releases pointer",game.active_panel=="map" and map.visible and game.paused and get_tree().paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	check("map hides gameplay HUD and toasts behind the controls",not game.hud.visible)
	var map_yaw:float=game.yaw
	motion(map.global_position+Vector2(450,310),Vector2(170,35))
	check("moving across map does not change yaw or enable camera",is_equal_approx(game.yaw,map_yaw) and not game.camera_accepts_mouse())
	var local:=Vector2(470,410)
	for i in 20:
		local=Vector2(470+i*6,410)
		if map.destination_at(local).is_empty():break
	var expected:Vector2=map.unproject_point(local)
	var position_before:Vector3=game.player.global_position
	var fleet_before:int=game.vehicles.size()
	await click(map.global_position+local)
	check("viewport-routed click creates correct world waypoint",game.landmark_target_key=="map_pin" and Vector2(game.landmark_target_position.x,game.landmark_target_position.z).distance_to(expected)<.02)
	check("pin selection keeps map open and cursor usable",map.visible and game.paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	check("pin selection preserves player and existing fleet",game.player.global_position.is_equal_approx(position_before) and game.vehicles.size()==fleet_before)
	var target:Vector3=game.landmark_target_position
	var center_before:Vector2=map.map_center
	var start:Vector2=map.global_position+Vector2(480,300)
	mouse(start,true);motion(start+Vector2(60,25),Vector2(60,25),true);mouse(start+Vector2(60,25),false)
	check("real GUI drag pans map without turning camera or changing pin",map.map_center.distance_to(center_before)>1 and game.landmark_target_position.is_equal_approx(target) and is_equal_approx(game.yaw,map_yaw))
	var zoom_before:float=map.pixels_per_metre
	mouse(start,true,MOUSE_BUTTON_WHEEL_UP)
	check("viewport-routed wheel zooms map",map.pixels_per_metre>zoom_before)
	check("map GUI received genuine routed pointer events",routed_map_events>=7,{"events":routed_map_events})
	await capture("01-map-pointer-pin")
	map._clear_button.grab_focus()
	await tap(KEY_M)
	check("M closes paused map even with a focused GUI button",not map.visible and not game.paused and not get_tree().paused and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED)
	var after_map_yaw:float=game.yaw
	motion(Vector2(710,440),Vector2(25,0))
	check("camera turns again after closing map",absf(game.yaw-after_map_yaw)>.01)
	await tap(KEY_M)
	key(KEY_M,true,true)
	check("key-repeat does not repeatedly toggle the map",map.visible and game.active_panel=="map")
	key(KEY_M,false)
	await tap(KEY_ESCAPE)
	check("Esc also closes map and restores captured gameplay",not map.visible and not game.paused and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED)
	key(KEY_ALT)
	check("Alt Option hold releases pointer while minimap stays visible",Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and game.minimap.visible and game._cursor_held)
	var free_yaw:float=game.yaw
	motion(game.minimap.get_global_rect().get_center(),Vector2(140,30))
	check("released cursor does not rotate camera",is_equal_approx(game.yaw,free_yaw))
	await click(game.minimap.get_global_rect().get_center())
	check("actual small-map click opens full map",game.active_panel=="map" and map.visible and game.paused)
	key(KEY_ALT,false)
	check("releasing Alt inside map never steals its cursor",map.visible and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	await click(map._clear_button.get_global_rect().get_center())
	check("visible clear button clears navigation without closing map",game.landmark_target_key.is_empty() and map.visible)
	await click(map._close_button.get_global_rect().get_center())
	check("visible top close button restores gameplay",not map.visible and not game.paused and game.hud.visible and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED)
	for kind in ["car","airliner"]:
		var vehicle=game.vehicles.filter(func(v):return v.kind==kind)[0]
		game.enter_vehicle(vehicle);vehicle.freeze=true
		var identity:String=vehicle.vehicle_id
		await tap(KEY_M)
		var yaw_before:float=game.yaw
		motion(map.global_position+Vector2(400,350),Vector2(200,-80))
		check("map pointer cannot turn or replace occupied "+kind,is_equal_approx(game.yaw,yaw_before) and game.current_vehicle==vehicle and vehicle.occupied and vehicle.vehicle_id==identity and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
		await tap(KEY_M)
		check("closing map preserves driver and resumes "+kind,game.current_vehicle==vehicle and not game.paused and game.camera_accepts_mouse())
	await tap(KEY_ESCAPE)
	check("Esc pause menu releases mouse",game.active_panel=="pause" and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	await tap(KEY_M)
	check("M can open map directly from pause",game.active_panel=="map" and map.visible and game.paused)
	await capture("02-map-top-close")
	await click(game.map_search.get_global_rect().get_center())
	await type_text("manly")
	check("typing M into destination search does not close map",game.map_search.text=="manly" and game.active_panel=="map" and map.visible)
	var results:Array=game.map_results.get_children()
	check("typed query filters real destination buttons",not results.is_empty() and results[0] is Button and "manly" in results[0].text.to_lower())
	if not results.is_empty() and results[0] is Button:
		var location:Vector3=game.player.global_position
		await click(results[0].get_global_rect().get_center())
		check("search result click marks destination and keeps vehicle in place",map.visible and "manly" in game.landmark_target_name.to_lower() and game.player.global_position.is_equal_approx(location) and game.current_vehicle.kind=="airliner")
	await capture("03-map-search-manly")
	await tap(KEY_ESCAPE)
	check("Esc exits searched map and restores camera",not game.paused and game.camera_accepts_mouse())
	key(KEY_ALT)
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	Input.action_release("cursor") # Emulate the OS clearing input state without key-up delivery.
	check("losing window focus clears Option even without a key-up event",not game._cursor_held and not game.minimap.cursor_released and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check("returning from another window restores gameplay camera",game.camera_accepts_mouse() and game.current_vehicle.kind=="airliner")
	await tap(KEY_M)
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check("refocusing an open map keeps its pointer and pause",map.visible and game.paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not game.camera_accepts_mouse())
	await tap(KEY_ESCAPE)
	var passed:=checks.all(func(item):return item.passed)
	var report={"passed":passed,"checks":checks,"native":native,"scope":"Full production world; Viewport.push_input enters Node input, focused GUI dispatch and unhandled camera routing. Window focus notifications are injected through Object.notification. No direct calls to menu or map click handlers. This is engine event automation, not an OS hardware-input claim.","screenshots":screenshots,"user_saves_touched":false,"qa_fixtures_retained":true}
	FileAccess.open("user://navigation-input-qa/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("POINTER_QA_COMPLETE ",checks.size()," passed=",passed)
	game.active=false
	get_tree().paused=false
	game.finish_quit(0 if passed else 1)
