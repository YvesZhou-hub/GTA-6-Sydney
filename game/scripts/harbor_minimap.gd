extends Control
## North-up navigation over the full map's shared geographic drawing resources.
## Geographic vectors are rasterized into a local overscan cache. Ordinary
## movement transforms one texture, not every road/building in the whole city.
signal clicked

class TerrainInk extends Node2D:
	var minimap
	func _draw(): minimap.paint_terrain(self)

class OverlayInk extends Node2D:
	var minimap
	func _draw(): minimap.paint_overlay(self)

var player_position:=Vector3.ZERO
var player_heading:=0.0
var target_key:=""
var target_position:=Vector3.ZERO
var target_name:=""
var north_up:=true
var pixels_per_metre:=0.20
var map_source
var _cache:Dictionary={}
var _viewport:Control
var _terrain:TerrainInk
var _overlay:OverlayInk
var _terrain_viewport:SubViewport
var _terrain_image:Sprite2D
var _cached_center:=Vector2.ZERO
var _cached_scale:=-1.0
var cache_update_count:=0
var _refresh_clock:=0.0
var _press_position:=Vector2.ZERO
var _pressed:=false
var terrain_draw_count:=0
var cursor_released:=false

func _ready():
	custom_minimum_size=Vector2(260,288)
	clip_contents=true
	mouse_filter=Control.MOUSE_FILTER_STOP
	tooltip_text="M 开关地图 · 按住 Alt / Option 释放鼠标后可点击\n金色箭头指向目的地，距离为直线距离"
	_viewport=Control.new()
	_viewport.clip_contents=true
	_viewport.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_viewport)
	_terrain_viewport=SubViewport.new()
	_terrain_viewport.size=Vector2i(768,768)
	_terrain_viewport.disable_3d=true
	_terrain_viewport.transparent_bg=true
	_terrain_viewport.world_2d=World2D.new()
	_terrain_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(_terrain_viewport)
	_terrain=TerrainInk.new()
	_terrain.minimap=self
	_terrain_viewport.add_child(_terrain)
	_terrain_image=Sprite2D.new()
	_terrain_image.texture=_terrain_viewport.get_texture()
	_terrain_image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	_viewport.add_child(_terrain_image)
	_overlay=OverlayInk.new()
	_overlay.minimap=self
	add_child(_overlay)
	resized.connect(refresh)
	refresh()

func configure(source):
	map_source=source
	_cache=source.geometry_cache()
	_cached_scale=-1.0
	if is_instance_valid(_terrain): _terrain.queue_redraw()
	refresh()

func geometry_cache() -> Dictionary: return _cache
func map_rect() -> Rect2: return Rect2(Vector2(8,32),Vector2(maxf(size.x-16,1),maxf(size.y-86,1)))
func view_center() -> Vector2: return map_rect().get_center()
func map_rotation() -> float: return 0.0 if north_up else player_heading
func project_point(point:Vector3) -> Vector2:
	return view_center()+Vector2(point.x-player_position.x,point.z-player_position.z).rotated(map_rotation())*pixels_per_metre

func target_indicator() -> Dictionary:
	var delta:=Vector2(target_position.x-player_position.x,target_position.z-player_position.z)
	var screen_delta:=delta.rotated(map_rotation())*pixels_per_metre
	var half:=map_rect().size*0.5-Vector2.ONE*13.0
	var ratio:=maxf(absf(screen_delta.x)/half.x,absf(screen_delta.y)/half.y)
	var edge:=view_center()+screen_delta/maxf(ratio,1.0)
	return {"visible":not target_key.is_empty(),"position":edge,"offscreen":ratio>1.0,"distance":delta.length(),"direction":screen_delta.normalized(),"bearing_degrees":fposmod(rad_to_deg(atan2(delta.x,-delta.y)),360.0)}

func sync_navigation(snapshot:Dictionary):
	player_position=snapshot.get("player_position",player_position)
	player_heading=float(snapshot.get("player_heading",player_heading))
	target_key=str(snapshot.get("target_key",target_key))
	target_position=snapshot.get("target_position",target_position)
	target_name=str(snapshot.get("target_name",target_name))
	refresh()

func _process(delta:float):
	# Also supports callers assigning the public snapshot variables directly.
	_refresh_clock+=delta
	if visible and _refresh_clock>=0.10:
		_refresh_clock=0.0
		refresh()

func refresh():
	if not is_instance_valid(_viewport): return
	var rect:=map_rect()
	_viewport.position=rect.position
	_viewport.size=rect.size
	var angle:=map_rotation()
	var location:=Vector2(player_position.x,player_position.z)
	# Keep a generous border around the visible circle, including heading-up
	# rotation. Refresh only on leaving that region, resizing, zoom or teleport.
	var required_size:=maxi(768,ceili(rect.size.length()+256.0))
	var resize_cache:bool=_terrain_viewport.size.x!=required_size
	if resize_cache:_terrain_viewport.size=Vector2i(required_size,required_size)
	var visible_radius:=rect.size.length()*.5
	var coverage_left:=float(required_size)*.5-visible_radius-32.0
	if resize_cache or not is_equal_approx(_cached_scale,pixels_per_metre) or location.distance_to(_cached_center)*pixels_per_metre>coverage_left:
		_cached_center=location
		_cached_scale=pixels_per_metre
		_terrain.position=Vector2.ONE*float(required_size)*.5-location*pixels_per_metre
		_terrain.scale=Vector2.ONE*pixels_per_metre
		_terrain_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		cache_update_count+=1
	_terrain_image.position=rect.size*.5+(_cached_center-location).rotated(angle)*pixels_per_metre
	_terrain_image.rotation=angle
	_overlay.queue_redraw()
	queue_redraw()

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed=true
			_press_position=event.position
		else:
			if _pressed and event.position.distance_to(_press_position)<6: clicked.emit()
			_pressed=false
		accept_event()

func _draw():
	draw_style_box(_panel_style(),Rect2(Vector2.ZERO,size))
	draw_rect(map_rect(),Color("173743"))

func _panel_style() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("10252d")
	style.border_color=Color("647778")
	style.set_border_width_all(1)
	return style

func paint_terrain(ink:Node2D):
	terrain_draw_count+=1
	if _cache.is_empty(): return
	if _cache.simplified!=null: ink.draw_mesh(_cache.simplified,null,Transform2D.IDENTITY,Color("625e4b"))
	if _cache.land!=null: ink.draw_mesh(_cache.land,null,Transform2D.IDENTITY,Color("3e5950"))
	if _cache.get("pedestrian_areas")!=null: ink.draw_mesh(_cache.pedestrian_areas,null,Transform2D.IDENTITY,Color("7c8d76"))
	if _cache.buildings!=null: ink.draw_mesh(_cache.buildings,null,Transform2D.IDENTITY,Color("748277"))
	if not _cache.coast.is_empty(): ink.draw_multiline(_cache.coast,Color("a4b3a1"),4.0,true)
	for category in ["path","street","major","rail"]:
		var lines:PackedVector2Array=_cache.roads.get(category,PackedVector2Array())
		if not lines.is_empty(): ink.draw_multiline(lines,Color("dfc698") if category=="major" else Color("a8b5a1"),8.0 if category=="major" else 3.4,true)
	if is_instance_valid(map_source):
		for runway in map_source.runway_data:
			ink.draw_line(Vector2(runway.a.x,runway.a.z),Vector2(runway.b.x,runway.b.z),Color("ddd8be"),45,true)

func _text(ink:Node2D,at:Vector2,value:String,font_size:int,color:Color,width:float=-1):
	var font=get_theme_default_font()
	var text:=value
	if width>0:
		while text.length()>1 and font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width:
			text=text.left(text.length()-2)+"…"
	ink.draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func paint_overlay(ink:Node2D):
	var rect:=map_rect()
	var centre:=view_center()
	if is_instance_valid(map_source):
		for landmark in map_source.landmarks:
			var point:=project_point(map_source.landmark_point(landmark))
			if rect.grow(-6).has_point(point): ink.draw_circle(point,2.5,Color("d8d3bc"),true,-1,true)
	var indicator:=target_indicator()
	if indicator.visible:
		ink.draw_dashed_line(centre,indicator.position,Color("e3b756"),1.6,6,true,true)
		var at:Vector2=indicator.position
		if indicator.offscreen:
			var direction:Vector2=indicator.direction
			var side:=direction.orthogonal()
			ink.draw_colored_polygon(PackedVector2Array([at+direction*8,at-direction*6+side*6,at-direction*6-side*6]),Color("ffd36b"))
		else:
			ink.draw_circle(at,6,Color("ffd36b"),false,2,true)
			ink.draw_line(at,at+Vector2(0,-13),Color("ffd36b"),2,true)
			ink.draw_line(at+Vector2(0,-13),at+Vector2(9,-10),Color("ffd36b"),3,true)
	var forward:=Vector2(-sin(player_heading),-cos(player_heading)).rotated(map_rotation())
	var side:=forward.orthogonal()
	ink.draw_circle(centre,12,Color(0.25,1,0.8,0.16),true,-1,true)
	ink.draw_colored_polygon(PackedVector2Array([centre+forward*10,centre-forward*7+side*6,centre-forward*4,centre-forward*7-side*6]),Color("94f3cf"))
	_text(ink,Vector2(11,22),"悉尼 · 导航",14,Color("e4e9da"))
	_text(ink,Vector2(size.x-76,22),"M 地图 ↗",12,Color("b1c5bc"))
	var north:=Vector2.UP.rotated(map_rotation())
	var north_at:=centre+north*(minf(rect.size.x,rect.size.y)*0.5-13)
	_text(ink,north_at+Vector2(-4,4),"N",13,Color("eef3df"))
	var scale_m:=100.0 if pixels_per_metre>=0.15 else 500.0
	var scale_origin:=rect.end-Vector2(scale_m*pixels_per_metre+8,12)
	ink.draw_line(scale_origin,scale_origin+Vector2(scale_m*pixels_per_metre,0),Color("e6e0ce"),2,true)
	_text(ink,scale_origin+Vector2(-2,-5),"%d m"%scale_m,10,Color("e6e0ce"))
	var title:=target_name if indicator.visible else "按 M 选点 · 按住 Alt / Option 点这里"
	_text(ink,Vector2(10,size.y-32),title,13,Color("f2d18b") if indicator.visible else Color("b1c5bc"),size.x-20)
	var detail:="北朝上 · OSM" if north_up else "朝向跟随 · OSM"
	if indicator.visible:
		detail=("%.2f km"%(indicator.distance/1000.0) if indicator.distance>=1000 else "%.0f m"%indicator.distance)+" · 直线距离"
		if indicator.distance<35: detail="已到达附近 · "+detail
	_text(ink,Vector2(10,size.y-13),detail,11,Color("b1c5bc"))
	if cursor_released:
		_text(ink,Vector2(12,46),"鼠标已释放 · 点击打开地图",12,Color("b6ffe1"),size.x-24)
