extends Control
## Metre-for-metre map of the same geographic frame as the 3D world.
## All base geometry is cached; mouse movement only changes the canvas transform.
signal landmark_selected(key: String)
signal waypoint_selected(position: Vector3, title: String)
signal navigation_cleared
class MapInk extends Node2D:
	var owner_map
	func _draw(): owner_map.paint(self)

var anchors:Dictionary={}
var landmarks:Array=[]
var player_position:=Vector3.ZERO
var player_heading:=0.0
var target_key:=""
var target_position:=Vector3.ZERO
var target_name:=""
var spawn_position:=Vector3.ZERO
var has_spawn:=false
var runway_data:Array=[]
var map_center:=Vector2(0,-350)
var pixels_per_metre:=0.26
var view_name:="悉尼海港"
var data_loaded:=false
var data_counts:={"land":0,"roads":0,"buildings":0,"places":0}
var _ink:MapInk
var _land_mesh:ArrayMesh
var _building_mesh:ArrayMesh
var _simplified_mesh:ArrayMesh
var _simplified_lines:=PackedVector2Array()
var _simplified_hatching:=PackedVector2Array()
var _road_lines:Dictionary={}
var _coast_lines:=PackedVector2Array()
var _footprint_lines:=PackedVector2Array()
var _places:Array=[]
var _named_roads:Array=[]
var _dragging:=false
var _drag_distance:=0.0
var _press_position:=Vector2.ZERO
var _labels:Array[Rect2]=[]
var _label_hits:Array[Dictionary]=[]
var _clear_button:Button
# Resource and packed-array references are shared by all map views. Only the
# first full map reads the geographic JSON and constructs its meshes.
static var _shared_geometry:Dictionary={}
static var source_load_count:=0
var _source_note:="位置参考 OpenStreetMap · 普通建筑立面仍在细化"
const ROAD_COLOURS={"major":Color("e6d5ad"),"street":Color("b9c8b1"),"path":Color("8db29b"),"rail":Color("c9a491")}
const FOOTER_HEIGHT:=124.0

func _ready():
	clip_contents=true
	mouse_filter=Control.MOUSE_FILTER_STOP
	_ink=MapInk.new()
	_ink.owner_map=self
	add_child(_ink)
	_clear_button=Button.new()
	_clear_button.text="清除标记"
	_clear_button.custom_minimum_size=Vector2(104,34)
	_clear_button.pressed.connect(clear_navigation)
	add_child(_clear_button)
	resized.connect(refresh)
	visibility_changed.connect(func(): _dragging=false)
	load_map_data()

func _points(values,offset:=Vector2.ZERO) -> PackedVector2Array:
	var points:=PackedVector2Array()
	if not values is Array: return points
	for value in values:
		if value is Array and value.size()>=2:
			points.append(Vector2(float(value[0]),float(value[1]))+offset)
	return points

func _mesh(vertices:PackedVector2Array) -> ArrayMesh:
	if vertices.is_empty(): return null
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _append_lines(to:PackedVector2Array,points:PackedVector2Array,closed:=false):
	for i in range(points.size()-1): to.append_array(PackedVector2Array([points[i],points[i+1]]))
	if closed and points.size()>2 and not points[0].is_equal_approx(points[-1]): to.append_array(PackedVector2Array([points[-1],points[0]]))

func load_map_data():
	if not _shared_geometry.is_empty():
		_use_geometry(_shared_geometry)
		refresh()
		return
	source_load_count+=1
	var file_path:="res://assets/city_map.json"
	var data:Dictionary={}
	if FileAccess.file_exists(file_path):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(file_path))
		if parsed is Dictionary: data=parsed
	data_loaded=not data.is_empty()
	var land_vertices:=PackedVector2Array()
	var building_vertices:=PackedVector2Array()
	var simplified_vertices:=PackedVector2Array()
	_simplified_lines.clear()
	_simplified_hatching.clear()
	for patch in preload("res://scripts/airport_world.gd").SIMPLIFIED_TERRAIN:
		var polygon:=_points(patch.outline)
		for index in Geometry2D.triangulate_polygon(polygon): simplified_vertices.append(polygon[index])
		_append_lines(_simplified_lines,polygon,true)
		_append_hatching(polygon)
	_simplified_mesh=_mesh(simplified_vertices)
	_coast_lines.clear()
	_footprint_lines.clear()
	_road_lines={"major":PackedVector2Array(),"street":PackedVector2Array(),"path":PackedVector2Array(),"rail":PackedVector2Array()}
	_named_roads.clear()
	_places.clear()
	data_counts={"land":0,"roads":0,"buildings":0,"places":0}
	if data_loaded:
		for land in data.get("land",[]):
			var outline:=_points(land.get("outline",[]))
			var triangles:=_points(land.get("triangles",[]))
			if triangles.size()>0 and triangles.size()%3==0: land_vertices.append_array(triangles)
			elif outline.size()>2:
				for index in Geometry2D.triangulate_polygon(outline): land_vertices.append(outline[index])
			_append_lines(_coast_lines,outline,true)
			data_counts.land+=1
	else:
		# A missing optional city file shows the original surveyed coast/road lines,
		# never invented filled shapes masquerading as geography.
		var original=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world_geography.json"))
		if original is Dictionary:
			data.roads=original.get("roads",[])
			_append_lines(_coast_lines,_points(original.get("south_coast",[])))
			_append_lines(_coast_lines,_points(original.get("north_coast",[])))
	for road in data.get("roads",[]):
		var points:=_points(road.get("points",[]))
		if points.size()<2: continue
		var tags:Dictionary=road.get("tags",{})
		var highway:=str(tags.get("highway","residential"))
		var category:="major" if highway in ["motorway","motorway_link","trunk","trunk_link","primary","primary_link","secondary"] else ("path" if highway in ["footway","path","steps","pedestrian","cycleway"] else ("rail" if tags.has("railway") else "street"))
		var lines:PackedVector2Array=_road_lines[category]
		_append_lines(lines,points)
		_road_lines[category]=lines
		var road_name:=str(road.get("name",tags.get("name","")))
		if not road_name.is_empty(): _named_roads.append({"point":points[points.size()/2],"name":road_name})
		data_counts.roads+=1
	for building in data.get("buildings",[]):
		# Building geometry is local to its surveyed centre; roads/coasts are world-space.
		var centre_values=building.get("center",[0,0])
		var centre:=Vector2(float(centre_values[0]),float(centre_values[1]))
		var outline:=_points(building.get("outline",[]),centre)
		if outline.size()<3: continue
		if outline[0].is_equal_approx(outline[-1]): outline.remove_at(outline.size()-1)
		var roof:=_points(building.get("roof",[]),centre)
		if not roof.is_empty() and roof.size()%3==0: building_vertices.append_array(roof)
		else:
			for index in Geometry2D.triangulate_polygon(outline): building_vertices.append(outline[index])
		_append_lines(_footprint_lines,outline,true)
		for hole in building.get("holes",[]): _append_lines(_footprint_lines,_points(hole,centre),true)
		data_counts.buildings+=1
	for place in data.get("places",[]):
		var point_values=place.get("point",[])
		if not point_values is Array or point_values.size()<2: continue
		var tags:Dictionary=place.get("tags",{})
		var place_name:=str(place.get("name",tags.get("name",tags.get("brand",""))))
		if place_name.is_empty(): continue
		_places.append({"point":Vector2(float(point_values[0]),float(point_values[1])),"name":place_name,"shop":tags.has("shop") or tags.has("amenity")})
		data_counts.places+=1
	_land_mesh=_mesh(land_vertices)
	_building_mesh=_mesh(building_vertices)
	_shared_geometry={"land":_land_mesh,"buildings":_building_mesh,"simplified":_simplified_mesh,"simplified_lines":_simplified_lines,"hatching":_simplified_hatching,"roads":_road_lines,"coast":_coast_lines,"footprints":_footprint_lines,"places":_places,"named_roads":_named_roads,"counts":data_counts,"loaded":data_loaded}
	refresh()

func geometry_cache() -> Dictionary:
	return _shared_geometry

func _use_geometry(cache:Dictionary):
	_land_mesh=cache.land
	_building_mesh=cache.buildings
	_simplified_mesh=cache.simplified
	_simplified_lines=cache.simplified_lines
	_simplified_hatching=cache.hatching
	_road_lines=cache.roads
	_coast_lines=cache.coast
	_footprint_lines=cache.footprints
	_places=cache.places
	_named_roads=cache.named_roads
	data_counts=cache.counts
	data_loaded=cache.loaded

func navigation_snapshot() -> Dictionary:
	return {"player_position":player_position,"player_heading":player_heading,"target_key":target_key,"target_position":target_position,"target_name":target_name}

func sync_navigation(snapshot:Dictionary):
	player_position=snapshot.get("player_position",player_position)
	player_heading=float(snapshot.get("player_heading",player_heading))
	target_key=str(snapshot.get("target_key",target_key))
	target_position=snapshot.get("target_position",target_position)
	target_name=str(snapshot.get("target_name",target_name))
	refresh()

func refresh():
	_label_hits.clear()
	if is_instance_valid(_clear_button):
		_clear_button.position=Vector2(size.x-122,10)
		_clear_button.size=Vector2(104,34)
		_clear_button.disabled=target_key.is_empty()
	if is_instance_valid(_ink): _ink.queue_redraw()

func _append_hatching(polygon:PackedVector2Array):
	# Intersect evenly spaced diagonal lines with each actual game-terrain outline.
	var low:=INF
	var high:=-INF
	for point in polygon:
		low=minf(low,point.y-point.x)
		high=maxf(high,point.y-point.x)
	for diagonal in range(int(floor(low/220))*220,int(high)+1,220):
		var hits:Array[Vector2]=[]
		for i in polygon.size():
			var a:=polygon[i]
			var b:=polygon[(i+1)%polygon.size()]
			var da:=a.y-a.x
			var db:=b.y-b.x
			if (da<=diagonal and db>diagonal) or (db<=diagonal and da>diagonal): hits.append(a.lerp(b,(diagonal-da)/(db-da)))
		hits.sort_custom(func(a:Vector2,b:Vector2): return a.x<b.x)
		for i in range(0,hits.size()-1,2): _simplified_hatching.append_array(PackedVector2Array([hits[i],hits[i+1]]))

func view_center() -> Vector2: return Vector2(size.x*0.5,(size.y-FOOTER_HEIGHT-54)*0.5+54)
func project_flat(point:Vector2) -> Vector2: return (point-map_center)*pixels_per_metre+view_center()
func project_point(point:Vector3) -> Vector2: return project_flat(Vector2(point.x,point.z))
func unproject_point(point:Vector2) -> Vector2: return (point-view_center())/pixels_per_metre+map_center
func map_rect() -> Rect2: return Rect2(Vector2(10,62),Vector2(maxf(0,size.x-20),maxf(0,size.y-FOOTER_HEIGHT-69)))
func landmark_point(landmark:Dictionary) -> Vector3: return landmark.get("map_position",landmark.position)

func destination_at(screen_point:Vector2) -> Dictionary:
	if not map_rect().has_point(screen_point): return {}
	var nearest:Dictionary={}
	var distance:=17.0
	for landmark in landmarks:
		var at:=project_point(landmark_point(landmark))
		var candidate:=at.distance_to(screen_point)
		if candidate<distance:
			distance=candidate
			nearest={"key":str(landmark.key),"title":str(landmark.title),"position":landmark.position,"landmark":true}
	if not nearest.is_empty(): return nearest
	# Labels have the same collision-resolved hit region as the rendered text.
	for hit in _label_hits:
		if hit.rect.has_point(screen_point): return hit.destination
	return {}

func select_at(screen_point:Vector2):
	if not map_rect().has_point(screen_point): return
	var hit:=destination_at(screen_point)
	if not hit.is_empty() and hit.get("landmark",false):
		target_key=hit.key
		target_position=hit.position
		target_name=hit.title
		refresh()
		landmark_selected.emit(target_key)
		return
	var flat:=unproject_point(screen_point)
	target_position=hit.get("position",Vector3(flat.x,4.5,flat.y))
	target_name=str(hit.get("title","地图标记"))
	target_key="map_waypoint"
	refresh()
	waypoint_selected.emit(target_position,target_name)

func clear_navigation():
	target_key=""
	target_name=""
	refresh()
	navigation_cleared.emit()

func fit_area(bounds:Rect2):
	map_center=bounds.get_center()
	pixels_per_metre=clampf(minf((size.x-85)/maxf(bounds.size.x,1.0),(size.y-FOOTER_HEIGHT-85)/maxf(bounds.size.y,1.0)),0.012,2.8)
	refresh()

func show_preset(preset:String):
	match preset:
		"all":
			view_name="悉尼 · 机场至 Manly"
			var bounds:=Rect2(Vector2(-900,-1750),Vector2(2000,3000))
			for value in anchors.values():
				if value is Vector3: bounds=bounds.expand(Vector2(value.x,value.z))
			for place in _places:
				if "Manly Wharf"==str(place.name): bounds=bounds.expand(place.point)
			for runway in runway_data:
				bounds=bounds.expand(Vector2(runway.a.x,runway.a.z)).expand(Vector2(runway.b.x,runway.b.z))
			fit_area(bounds.grow(650))
		"manly":
			view_name="Manly · 码头与海滩"
			var at:=Vector3(6680,0,-6730)
			for landmark in landmarks:
				if "manly" in str(landmark.key).to_lower(): at=landmark.position; break
			fit_area(Rect2(Vector2(at.x,at.z)-Vector2(1400,1650),Vector2(2800,3300)))
		"airport":
			view_name="Sydney Airport · YSSY"
			fit_area(Rect2(Vector2(-5600,7250),Vector2(4700,5750)))
		"player":
			view_name="我的位置"
			map_center=Vector2(player_position.x,player_position.z)
			pixels_per_metre=maxf(pixels_per_metre,0.34)
			refresh()
		_:
			view_name="悉尼海港 · 城市街区"
			fit_area(Rect2(Vector2(-1550,-2000),Vector2(3600,4800)))

func zoom_at(factor:float,screen_point:Vector2):
	var before:=unproject_point(screen_point)
	pixels_per_metre=clampf(pixels_per_metre*factor,0.012,2.8)
	map_center=before-(screen_point-view_center())/pixels_per_metre
	refresh()

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and map_rect().has_point(event.position):
			clear_navigation()
			accept_event()
			return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			if not map_rect().has_point(event.position): return
			zoom_at(1.22 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.22,event.position)
			accept_event()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging=map_rect().has_point(event.position)
				_drag_distance=0.0
				_press_position=event.position
			else:
				var click:bool=_dragging and maxf(_drag_distance,_press_position.distance_to(event.position))<6.0
				_dragging=false
				if click: select_at(event.position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_drag_distance+=event.relative.length()
		map_center-=event.relative/pixels_per_metre
		refresh()
		accept_event()
	elif event is InputEventMagnifyGesture:
		zoom_at(event.factor,event.position)
		accept_event()
	elif event is InputEventPanGesture:
		map_center+=event.delta*18.0/pixels_per_metre
		refresh()
		accept_event()

func _label(ink:Node2D,point:Vector2,text:String,color:Color,font_size:int=13,force:=false) -> bool:
	var font=get_theme_default_font()
	var extent=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var rect:=Rect2(point+Vector2(7,-extent.y),extent+Vector2(10,5))
	if not Rect2(Vector2(18,63),size-Vector2(36,FOOTER_HEIGHT+70)).encloses(rect): return false
	if not force:
		for previous in _labels:
			if previous.grow(5).intersects(rect): return false
	_labels.append(rect)
	ink.draw_string_outline(font,point+Vector2(10,-3),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color("153d42"))
	ink.draw_string(font,point+Vector2(10,-3),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
	return true

func paint(ink:Node2D):
	ink.draw_rect(Rect2(Vector2.ZERO,size),Color("153d4d"))
	ink.draw_set_transform(view_center()-map_center*pixels_per_metre,0,Vector2.ONE*pixels_per_metre)
	if _simplified_mesh!=null:
		ink.draw_mesh(_simplified_mesh,null,Transform2D.IDENTITY,Color("665f4f"))
		ink.draw_multiline(_simplified_hatching,Color("827962"),0.8/pixels_per_metre,true)
		ink.draw_multiline(_simplified_lines,Color("a99b7e"),1.0/pixels_per_metre,true)
	if _land_mesh!=null: ink.draw_mesh(_land_mesh,null,Transform2D.IDENTITY,Color("496e65"))
	if pixels_per_metre>0.08 and _building_mesh!=null: ink.draw_mesh(_building_mesh,null,Transform2D.IDENTITY,Color("729080"))
	if not _coast_lines.is_empty(): ink.draw_multiline(_coast_lines,Color("b4c7ac"),maxf(1.0/pixels_per_metre,1.0),true)
	if pixels_per_metre>0.55 and not _footprint_lines.is_empty(): ink.draw_multiline(_footprint_lines,Color("a6b69d"),0.65/pixels_per_metre,true)
	for category in ["path","street","major","rail"]:
		if category=="path" and pixels_per_metre<0.2: continue
		var points:PackedVector2Array=_road_lines.get(category,PackedVector2Array())
		if not points.is_empty(): ink.draw_multiline(points,ROAD_COLOURS[category],maxf((1.8 if category=="major" else 0.85)/pixels_per_metre,8.0 if category=="major" else 3.4),true)
	var connector=anchors.get("airport_connector",[])
	for i in range(connector.size()-1):
		var a:Vector3=connector[i]
		var b:Vector3=connector[i+1]
		ink.draw_dashed_line(Vector2(a.x,a.z),Vector2(b.x,b.z),Color("c9bfa1"),1.5/pixels_per_metre,7.0/pixels_per_metre,true,true)
	for runway in runway_data: ink.draw_line(Vector2(runway.a.x,runway.a.z),Vector2(runway.b.x,runway.b.z),Color("f0e4c5"),maxf(3.0/pixels_per_metre,45.0),true)
	ink.draw_set_transform(Vector2.ZERO)
	_labels.clear()
	_label_hits.clear()
	var viewport_rect:=map_rect()
	if not target_key.is_empty():
		var from:=project_point(player_position)
		var to:=project_point(target_position)
		ink.draw_dashed_line(from,to,Color("f2ce85"),2.0,9.0,true,true)
		if viewport_rect.has_point(to):
			ink.draw_circle(to,13,Color(1.0,0.79,0.3,0.18),true,-1,true)
			ink.draw_line(to,to+Vector2(0,-24),Color("ffcf60"),2.4,true)
			ink.draw_colored_polygon(PackedVector2Array([to+Vector2(0,-24),to+Vector2(17,-20),to+Vector2(0,-14)]),Color("ffcf60"))
			_label(ink,to+Vector2(12,-18),target_name,Color("ffe3a0"),14)
	for landmark in landmarks:
		var point:=project_point(landmark_point(landmark))
		if not viewport_rect.has_point(point): continue
		var selected:bool=str(landmark.key)==target_key
		ink.draw_circle(point,8 if selected else 4.5,Color("ffdc8d") if selected else Color("dfd6b6"),true,-1,true)
		if _label(ink,point,str(landmark.title),Color("ffdfa0") if selected else Color("f0e2bc"),14 if selected else 12):
			_label_hits.append({"rect":_labels[-1].grow(3),"destination":{"key":str(landmark.key),"title":str(landmark.title),"position":landmark.position,"landmark":true}})
	if pixels_per_metre>0.38:
		for road in _named_roads:
			var point:=project_flat(road.point)
			if viewport_rect.has_point(point): _label(ink,point,road.name,Color("c6d0b5"),12)
	if pixels_per_metre>0.62:
		for place in _places:
			var point:=project_flat(place.point)
			if not viewport_rect.has_point(point): continue
			if _label(ink,point,place.name,Color("e1c9a1") if place.shop else Color("cde0be"),12):
				ink.draw_circle(point,3,Color("e4be81"))
				_label_hits.append({"rect":_labels[-1].grow(4).merge(Rect2(point-Vector2.ONE*8,Vector2.ONE*16)),"destination":{"title":place.name,"position":Vector3(place.point.x,4.5,place.point.y),"landmark":false}})
	if has_spawn:
		var spawned:=project_point(spawn_position)
		if viewport_rect.has_point(spawned):
			ink.draw_arc(spawned,9,0,TAU,24,Color("f4d882"),2,true)
			_label(ink,spawned,"新载具",Color("f4d882"),13)
	var player:=project_point(player_position)
	if viewport_rect.has_point(player):
		ink.draw_circle(player,12,Color(0.4,1,0.82,0.22),true,-1,true)
		ink.draw_circle(player,5,Color("8ff6c9"),true,-1,true)
		var forward:=Vector2(-sin(player_heading),-cos(player_heading))*15.0
		ink.draw_line(player,player+forward,Color("c8ffe3"),2.2,true)
		_label(ink,player,"你在这里",Color("b9f8d6"),13)
	var font=get_theme_default_font()
	ink.draw_rect(Rect2(Vector2.ZERO,Vector2(size.x,54)),Color("0c2936"))
	ink.draw_string(font,Vector2(22,34),"N ↑   "+view_name,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("eee6c9"))
	ink.draw_rect(Rect2(Vector2(0,size.y-FOOTER_HEIGHT),Vector2(size.x,FOOTER_HEIGHT)),Color("0c2936"))
	var distance:=pow(10.0,floor(log(120.0/pixels_per_metre)/log(10.0)))
	if distance*pixels_per_metre<55: distance*=2
	var length_px:=distance*pixels_per_metre
	var origin:=Vector2(24,size.y-104)
	ink.draw_line(origin,origin+Vector2(length_px,0),Color("e5dfc6"),2)
	ink.draw_line(origin+Vector2(0,-4),origin+Vector2(0,4),Color("e5dfc6"),2)
	ink.draw_line(origin+Vector2(length_px,-4),origin+Vector2(length_px,4),Color("e5dfc6"),2)
	ink.draw_string(font,origin+Vector2(length_px+10,5),("%.1f km"%(distance/1000.0)) if distance>=1000 else ("%d m"%distance),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e5dfc6"))
	ink.draw_string(font,Vector2(size.x-374,size.y-99),"滚轮缩放 · 拖动平移 · 点击设标 · 右键清除",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("b2c9be"))
	var target_distance:=Vector2(target_position.x-player_position.x,target_position.z-player_position.z).length()
	var status:="绿箭头：你  ·  白点：地标  ·  金旗：目的地  ·  虚线：直线方向"
	if not target_key.is_empty(): status="前往 %s · %s · 直线指引，未计算道路路线"%[target_name.left(34),("%.2f km"%(target_distance/1000.0)) if target_distance>=1000 else ("%.0f m"%target_distance)]
	ink.draw_string(font,Vector2(24,size.y-73),status,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e8d39d"))
	ink.draw_string(font,Vector2(24,size.y-42),"斜纹：简化机场/走廊地形 · 放大可点选地点名称",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("b9c6ad"))
	ink.draw_string(font,Vector2(24,size.y-19),"© OpenStreetMap contributors · ODbL · openstreetmap.org/copyright",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("91b2ad"))
	if not data_loaded: ink.draw_string(font,Vector2(28,86),"扩展城市地图等待数据载入；当前显示已核实的海港岸线与道路。",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("efd28c"))
