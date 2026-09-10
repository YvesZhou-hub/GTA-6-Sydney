extends SceneTree
## Small UI fixture; no production 3D city construction and no player saves.
const MAP=preload("res://scripts/harbor_map.gd")
const MINI=preload("res://scripts/harbor_minimap.gd")
var checks:Array=[]
var selected:Array=[]
var pins:Array=[]
var clears:=0
var opens:=0
func _initialize(): call_deferred("run")
func check(label:String,pass_value:bool):
	checks.append({"name":label,"passed":pass_value})
	print("PASS " if pass_value else "FAIL ",label)
func mouse(view,point:Vector2,pressed:bool):
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=point
	event.pressed=pressed
	view._gui_input(event)
func run():
	root.size=Vector2i(1200,850)
	var map=MAP.new()
	map.size=Vector2(820,735)
	root.add_child(map)
	map.landmarks=[{"key":"venue","title":"Public entrance","position":Vector3(120,4.5,-70),"map_position":Vector3(100,4.5,-100)}]
	map.player_position=Vector3(0,4.5,0)
	map.map_center=Vector2.ZERO
	map.pixels_per_metre=0.5
	map.landmark_selected.connect(func(key): selected.append(key))
	map.waypoint_selected.connect(func(at,title): pins.append({"at":at,"title":title}))
	map.navigation_cleared.connect(func(): clears+=1)
	check("real geographic cache loaded once",map.data_loaded and MAP.source_load_count==1 and map.data_counts.buildings>15000)
	var mini=MINI.new()
	mini.position=Vector2(860,30)
	mini.size=Vector2(280,300)
	root.add_child(mini)
	mini.configure(map)
	var second=MAP.new()
	second.visible=false
	root.add_child(second)
	check("minimap and second full map reuse original mesh resources without JSON reload",MAP.source_load_count==1 and mini.geometry_cache().land==map._land_mesh and second._building_mesh==map._building_mesh)
	for world_point in [Vector2(-3200,11500),Vector2(7400,-6800),Vector2(-768.5,1993.5)]:
		check("geographic projection round trip "+str(world_point),map.unproject_point(map.project_flat(world_point)).distance_to(world_point)<0.01)
	var cursor:=Vector2(270,200)
	var anchored:Vector2=map.unproject_point(cursor)
	map.zoom_at(1.25,cursor)
	check("zoom keeps cursor geographic point",map.unproject_point(cursor).distance_to(anchored)<0.01)
	var marker:Vector2=map.project_point(map.landmarks[0].map_position)
	mouse(map,marker,true);mouse(map,marker,false)
	check("building marker selects its separate public entrance destination",selected==["venue"] and map.target_position.is_equal_approx(Vector3(120,4.5,-70)))
	var pin_pixel:=Vector2(480,420)
	var expected:Vector2=map.unproject_point(pin_pixel)
	mouse(map,pin_pixel,true);mouse(map,pin_pixel+Vector2(1,1),false)
	var actual:Vector2=map.unproject_point(pin_pixel+Vector2(1,1))
	check("short empty-map click creates arbitrary metre-accurate pin",pins.size()==1 and map.target_key=="map_waypoint" and Vector2(map.target_position.x,map.target_position.z).distance_to(actual)<0.01)
	var previous_target:Vector3=map.target_position
	var previous_center:Vector2=map.map_center
	mouse(map,pin_pixel,true)
	var motion:=InputEventMouseMotion.new()
	motion.relative=Vector2(35,-22);motion.position=pin_pixel+motion.relative
	map._gui_input(motion)
	mouse(map,motion.position,false)
	check("drag pans without creating or moving pin",pins.size()==1 and map.target_position==previous_target and map.map_center.distance_to(previous_center)>1)
	mouse(map,pin_pixel,true);mouse(map,pin_pixel+Vector2(45,0),false)
	check("large release displacement without motion events still cannot pin",pins.size()==1)
	mouse(map,Vector2(50,25),true);mouse(map,Vector2(50,25),false)
	mouse(map,Vector2(50,720),true);mouse(map,Vector2(50,720),false)
	check("header and footer cannot create geographic pins",pins.size()==1)
	# Visible, collision-resolved label hit regions are the same input consumed
	# by map painting. Fixture checks the semantic selection of an OSM label.
	var place:Dictionary=map._places[0]
	map._label_hits.clear()
	map._label_hits.append({"rect":Rect2(Vector2(70,110),Vector2(120,25)),"destination":{"title":place.name,"position":Vector3(place.point.x,4.5,place.point.y),"landmark":false}})
	mouse(map,Vector2(85,120),true);mouse(map,Vector2(85,120),false)
	check("rendered OSM place label selects named geographic POI",pins.size()==2 and map.target_name==place.name and map.target_position.distance_to(Vector3(place.point.x,4.5,place.point.y))<0.01)
	var right:=InputEventMouseButton.new()
	right.button_index=MOUSE_BUTTON_RIGHT;right.pressed=true;right.position=Vector2(450,300)
	map._gui_input(right)
	check("right-click clears target and emits shared clear event",map.target_key.is_empty() and clears==1)
	map._clear_button.pressed.emit()
	check("visible clear button follows same navigation API",clears==2)
	mini.sync_navigation({"player_position":Vector3(0,4.5,0),"player_heading":0.0,"target_key":"test","target_position":Vector3(0,4.5,-1000),"target_name":"North"})
	var north:Dictionary=mini.target_indicator()
	check("north target at top edge with exact distance/bearing",north.offscreen and north.position.y<mini.view_center().y and is_equal_approx(north.position.x,mini.view_center().x) and is_equal_approx(north.distance,1000.0) and is_zero_approx(north.bearing_degrees))
	mini.target_position=Vector3(1000,4.5,0)
	var east:Dictionary=mini.target_indicator()
	check("east target edge and bearing",east.offscreen and east.position.x>mini.view_center().x and is_equal_approx(east.bearing_degrees,90.0))
	mini.target_position=Vector3(10,4.5,20)
	check("nearby target stays at its actual map position",not mini.target_indicator().offscreen and mini.target_indicator().position.distance_to(mini.project_point(mini.target_position))<0.01)
	mini.north_up=false;mini.player_heading=PI*0.5;mini.target_position=Vector3(-1000,4.5,0)
	var heading:Dictionary=mini.target_indicator()
	check("heading-up rotation uses Godot west-facing yaw correctly",heading.position.y<mini.view_center().y and absf(heading.position.x-mini.view_center().x)<0.01)
	mini.target_position=mini.player_position
	check("arrival at same coordinate has finite centre marker",mini.target_indicator().position.is_finite() and mini.target_indicator().position.distance_to(mini.view_center())<0.01)
	mini.sync_navigation(map.navigation_snapshot())
	check("cleared full-map snapshot removes minimap target",not mini.target_indicator().visible)
	mini.clicked.connect(func(): opens+=1)
	mouse(mini,Vector2(80,100),true);mouse(mini,Vector2(81,101),false)
	check("minimap click requests full map",opens==1)
	for i in 3: await process_frame
	var cached_draws:int=mini.terrain_draw_count
	for i in 10:
		mini.player_position.x+=5;mini.refresh()
		await process_frame
	check("moving minimap transforms cached terrain without rebuilding commands",mini.terrain_draw_count==cached_draws and MAP.source_load_count==1)
	if DisplayServer.get_name()!="headless":
		map.map_center=Vector2(-768,1993);map.pixels_per_metre=0.7;map.refresh()
		mini.north_up=true;mini.sync_navigation({"player_position":Vector3(-768,4.5,1993),"player_heading":-0.4,"target_key":"test","target_position":Vector3(414,4.5,-300),"target_name":"歌剧院"})
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../reports/navigation-map.png"))
	var passed:=true
	for result in checks: passed=passed and result.passed
	FileAccess.open(ProjectSettings.globalize_path("res://../reports/navigation-map.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"source_reads":MAP.source_load_count,"user_saves_touched":false},"\t"))
	print("NAVIGATION_MAP_CHECKS ",checks.size()," passed=",passed)
	quit(0 if passed else 1)
