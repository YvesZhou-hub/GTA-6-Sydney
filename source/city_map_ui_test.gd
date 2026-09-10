extends SceneTree
## Real scene map UI: native geometry, zoom/pan, click-to-guide, no player teleport.
var game
var checks:Array=[]
var screenshots:Array=[]
func _initialize(): call_deferred("run")
func check(name:String,okay:bool):
	checks.append({"name":name,"passed":okay})
	print("PASS " if okay else "FAIL ",name)
func capture(name:String):
	if DisplayServer.get_name()=="headless": return
	for i in 3: await process_frame
	RenderingServer.force_draw(true,1.0/60.0)
	var path=ProjectSettings.globalize_path("res://../reports/map-"+name+".png")
	root.get_texture().get_image().save_png(path)
	screenshots.append(path.get_file())
func run():
	game=load("res://main.tscn").instantiate()
	game.qa_running=true
	root.add_child(game)
	game.new_world("sandbox","Map UI QA - no save",false)
	game.player.enabled=false
	game.map_menu()
	var map=game.map_panel
	check("compiled real city map loaded",map.data_loaded)
	check("geographic roads and actual footprints present",map.data_counts.roads>10000 and map.data_counts.buildings>10000 and map.data_counts.land>5)
	check("named OpenStreetMap places retained",map.data_counts.places>1000)
	check("cached native land and building triangle meshes",map._land_mesh!=null and map._building_mesh!=null)
	var geographic_data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/city_map.json"))
	var first_building:Dictionary=geographic_data.buildings[0]
	var first_roof:Array=first_building.roof[0]
	var building_centre:Array=first_building.center
	var expected_roof_vertex:=Vector2(float(building_centre[0])+float(first_roof[0]),float(building_centre[1])+float(first_roof[1]))
	var cached_building_vertices=map._building_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check("local building geometry translated to mapped world centre",Vector2(cached_building_vertices[0].x,cached_building_vertices[0].y).distance_to(expected_roof_vertex)<0.02)
	check("road vectors reach drawing cache",map._road_lines.major.size()>100 and map._road_lines.street.size()>100)
	var sample:=Vector2(1537.2,-6123.7)
	check("map projection roundtrip preserves metres",map.unproject_point(map.project_flat(sample)).distance_to(sample)<0.01)
	map.show_preset("core")
	await capture("core")
	var cursor:=Vector2(430,320)
	var before:Vector2=map.unproject_point(cursor)
	var before_zoom:float=map.pixels_per_metre
	var wheel:=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	wheel.position=cursor
	wheel.pressed=true
	map._gui_input(wheel)
	check("wheel zoom holds cursor world position",map.pixels_per_metre>before_zoom and map.unproject_point(cursor).distance_to(before)<0.01)
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.position=Vector2(350,330)
	press.pressed=true
	map._gui_input(press)
	var centre_before:Vector2=map.map_center
	var drag:=InputEventMouseMotion.new()
	drag.position=Vector2(380,350)
	drag.relative=Vector2(30,20)
	map._gui_input(drag)
	press.pressed=false
	press.position=drag.position
	map._gui_input(press)
	check("drag pans geographic frame",map.map_center.distance_to(centre_before)>1)
	map.show_preset("all")
	check("full overview contains Manly and airport",Rect2(Vector2(0,54),map.size-Vector2(0,148)).has_point(map.project_flat(Vector2(6764.78,-6628.984))) and Rect2(Vector2(0,54),map.size-Vector2(0,148)).has_point(map.project_point(game.world.anchors.airport)))
	await capture("all")
	map.show_preset("manly")
	await capture("manly")
	map.show_preset("player")
	map.pixels_per_metre=1.2
	map.refresh()
	await capture("street")
	var position_before:Vector3=game.player.global_position
	var fleet_before:int=game.vehicles.size()
	map.show_preset("core")
	var opera_record:Dictionary=game.landmark_catalog().filter(func(item):return item.key=="opera")[0]
	var opera_point:Vector2=map.project_point(opera_record.get("map_position",opera_record.position))
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.position=opera_point
	click.pressed=true
	map._gui_input(click)
	click.pressed=false
	map._gui_input(click)
	check("click landmark sets correct live HUD target",game.landmark_target_key=="opera" and game.landmark_marker.visible)
	check("guidance never teleports player or creates vehicles",game.player.global_position.is_equal_approx(position_before) and game.vehicles.size()==fleet_before)
	game.map_menu()
	check("destination survives reopening map",map.target_key=="opera")
	game.clear_landmark_target()
	check("clear removes HUD and map destination",game.landmark_target_key.is_empty() and not game.landmark_marker.visible and map.target_key.is_empty())
	var catalog=game.landmark_catalog()
	var names:Array=[]
	for item in catalog: names.append(item.key)
	var expanded_present:=true
	for key in ["tower_one","boc","ribbon","exchange_haidilao","manly_wharf","manly_beach","hotel_steyne"]:
		if key not in names: expanded_present=false
	check("city and Manly real landmarks available as destinations",expanded_present)
	var institutions_present:=true
	for key in ["westpac","cba_south","cba_north","barangaroo_metro","martin_place_metro","quay_quarter","salesforce"]:
		if key not in names:institutions_present=false
	check("researched banks metro entrances and Quay towers have destinations",institutions_present)
	var shops_present:=true
	for record in game.world.get_meta("darling_square_frontages",[]):
		if "shop_"+record.id not in names:shops_present=false
	check("all 12 researched shopfronts have matching navigation anchors",shops_present and game.world.get_meta("darling_square_frontages",[]).size()==12)
	for group in ["cyber_landmarks","icc_landmarks"]:
		var venue_records: Array=game.world.get_meta(group,[])
		var venue_keys_present:=venue_records.size()==(2 if group=="cyber_landmarks" else 3)
		for record in venue_records:
			if record.id not in names:venue_keys_present=false
		check(group+" independent buildings have actual arrival destinations",venue_keys_present)
	var icc_navigation:=true
	for record in game.world.get_meta("icc_landmarks",[]):
		game.set_landmark_target(record.id)
		if game.landmark_target_key!=record.id or game.landmark_target_position.distance_to(record.arrival)>0.01 or not game.player.global_position.is_equal_approx(position_before):icc_navigation=false
	check("ICC guidance targets real public entrances without teleport",icc_navigation and game.world.get_meta("icc_landmarks",[]).size()==3)

	var targets_work:=true
	for item in catalog:
		game.set_landmark_target(item.key)
		if game.landmark_target_key!=item.key or game.landmark_target_position.distance_to(item.position)>0.01 or not game.player.global_position.is_equal_approx(position_before): targets_work=false
	check("every destination guides to its anchor without teleport",targets_work)
	game.clear_landmark_target()
	var passed:=true
	for item in checks:
		if not item.passed: passed=false
	var report={"passed":passed,"checks":checks,"counts":map.data_counts,"landmark_keys":names,"screenshots":screenshots,"renderer":RenderingServer.get_current_rendering_method(),"user_saves_touched":false}
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../reports/city-map-ui.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("CITY_MAP_UI ",JSON.stringify(report))
	game.active=false
	paused=false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
