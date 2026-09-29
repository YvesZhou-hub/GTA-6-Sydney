extends Control
## Screen-space destination pin and heading ribbon over the production 3D view.
const GameSettings = preload("res://scripts/game_settings.gd")
var view_camera: Camera3D
var player_position := Vector3.ZERO
var player_heading := 0.0
var target_key := ""
var target_position := Vector3.ZERO
var target_name := ""
var arrival_radius := 25.0
var arrival_height := 12.0
var panel_style:StyleBoxFlat
var touch_safe := Rect2()
var touch_obstacles: Array[Rect2] = []

func set_touch_layout(safe: Rect2, obstacles: Array[Rect2]) -> void:
	touch_safe = safe
	touch_obstacles = obstacles

## Keep the whole destination label, not only its arrow, clear of touch controls.
static func clear_target_rect(preferred: Rect2, safe: Rect2, obstacles: Array[Rect2]) -> Rect2:
	var area := safe.grow(-8)
	var dimensions := preferred.size.min(area.size)
	var at := preferred.position.clamp(area.position, area.end-dimensions)
	var xs: Array[float] = [at.x,area.position.x,area.end.x-dimensions.x]
	var ys: Array[float] = [at.y,area.position.y,area.end.y-dimensions.y]
	for obstacle in obstacles:
		xs.append(clampf(obstacle.position.x-dimensions.x-8,area.position.x,area.end.x-dimensions.x))
		xs.append(clampf(obstacle.end.x+8,area.position.x,area.end.x-dimensions.x))
		ys.append(clampf(obstacle.position.y-dimensions.y-8,area.position.y,area.end.y-dimensions.y))
		ys.append(clampf(obstacle.end.y+8,area.position.y,area.end.y-dimensions.y))
	var best := Rect2(at,dimensions)
	var score := INF
	for x in xs:
		for y in ys:
			var candidate := Rect2(Vector2(x,y),dimensions)
			var blocked := false
			for obstacle in obstacles:
				if candidate.intersects(obstacle.grow(4)):
					blocked = true
					break
			if blocked: continue
			var distance := candidate.position.distance_squared_to(at)
			if distance < score: best=candidate;score=distance
	# A fully covered screen should suppress the pin, never paint over a button.
	return best if is_finite(score) else Rect2()

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel_style=_panel()

static func compass_bearing(offset:Vector3) -> float:
	return fposmod(rad_to_deg(atan2(offset.x,-offset.z)),360.0)

static func has_arrived(origin:Vector3,target:Vector3,radius:=25.0,height:=12.0) -> bool:
	return Vector2(origin.x-target.x,origin.z-target.z).length()<=radius and absf(origin.y-target.y)<=height

static func edge_position(direction:Vector2,bounds:Rect2) -> Vector2:
	var half:=bounds.size*0.5
	if direction.length_squared()<0.001: direction=Vector2.DOWN
	var factor:=minf(half.x/maxf(absf(direction.x),0.001),half.y/maxf(absf(direction.y),0.001))
	return bounds.get_center()+direction*factor

func sync_navigation(snapshot:Dictionary):
	player_position=snapshot.get("player_position",player_position)
	player_heading=float(snapshot.get("player_heading",player_heading))
	target_key=str(snapshot.get("target_key",""))
	target_position=snapshot.get("target_position",target_position)
	target_name=str(snapshot.get("target_name",""))
	view_camera=snapshot.get("camera",view_camera)
	queue_redraw()

func _text(at:Vector2,value:String,color:=Color("f4f4de"),font_size:=15):
	var font=get_theme_default_font()
	draw_string_outline(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color(0.015,0.04,0.055,0.9))
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw():
	var width:=minf(460.0,size.x*0.33)
	var center:=Vector2(size.x*0.52,43)
	var heading:=fposmod(-rad_to_deg(player_heading),360.0)
	draw_style_box(panel_style,Rect2(center-Vector2(width*0.5,21),Vector2(width,60)))
	for i in range(0,360,15):
		var relative:=wrapf(float(i)-heading,-180.0,180.0)
		if absf(relative)>60: continue
		var x:=center.x+relative*width/120.0
		draw_line(Vector2(x,center.y+12),Vector2(x,center.y+18),Color("829d9e"),1)
		if i%45==0:
			var title:String=["北","东北","东","东南","南","西南","西","西北"][i/45]
			_text(Vector2(x-10,center.y+5),title,Color("e6ede0"),14)
	draw_colored_polygon(PackedVector2Array([center+Vector2(-4,-19),center+Vector2(4,-19),center+Vector2(0,-12)]),Color("fff0a6"))
	_text(center+Vector2(-15,34),"%03d°"%int(heading),Color("a3cecb"),12)
	if target_key.is_empty() or not is_instance_valid(view_camera): return
	var delta_position:=target_position-player_position
	var distance:=Vector2(delta_position.x,delta_position.z).length()
	var destination_bearing:=compass_bearing(delta_position)
	var relative:=wrapf(destination_bearing-heading,-180.0,180.0)
	var compass_x:=center.x+clampf(relative,-58,58)*width/120.0
	draw_circle(Vector2(compass_x,center.y+16),4,Color("ffe38a"))
	var focus:=target_position+Vector3.UP*8
	var local:=view_camera.to_local(focus)
	var bounds:=Rect2(Vector2(56,135),Vector2(size.x-112,size.y-290))
	var behind:=view_camera.is_position_behind(focus)
	var projected:=view_camera.unproject_position(focus) if not behind else Vector2(-9999,-9999)
	var outside:=behind or not bounds.has_point(projected)
	var direction:=Vector2(local.x,-local.y)
	if behind and absf(direction.x)<0.5: direction=Vector2.DOWN
	var at:=edge_position(direction,bounds) if outside else projected
	var mobile_rect := Rect2()
	if touch_safe.has_area():
		mobile_rect = clear_target_rect(Rect2(at-Vector2(120,16),Vector2(240,98)),touch_safe,touch_obstacles)
		if not mobile_rect.has_area(): return
		at = mobile_rect.position+Vector2(mobile_rect.size.x*.5,16)
	var color:=Color("a6ffe8") if has_arrived(player_position,target_position,arrival_radius,arrival_height) else Color("ffe38a")
	if outside:
		var normal:Vector2=(at-bounds.get_center()).normalized()
		var tangent:=Vector2(-normal.y,normal.x)
		draw_colored_polygon(PackedVector2Array([at+normal*12,at-normal*8+tangent*8,at-normal*8-tangent*8]),color)
	else:
		draw_polyline(PackedVector2Array([at+Vector2(0,-11),at+Vector2(9,0),at+Vector2(0,11),at+Vector2(-9,0),at+Vector2(0,-11)]),color,3,true)
		draw_line(at+Vector2(0,13),at+Vector2(0,35),color,2,true)
	var distance_text:="%.2f km"%(distance/1000) if distance>=1000 else "%.0f m"%distance
	var short_name:=target_name.left(25)+( "…" if target_name.length()>25 else "")
	var text_x:=mobile_rect.position.x if mobile_rect.has_area() else clampf(at.x-80,28,size.x-300)
	if mobile_rect.has_area():
		var font := get_theme_default_font()
		while short_name.length()>1 and font.get_string_size(short_name,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x>mobile_rect.size.x:
			short_name=short_name.left(short_name.length()-2)+"…"
	_text(Vector2(text_x,at.y+54),short_name,color,16)
	var status:=distance_text+(" · 后方" if behind else "")
	if has_arrived(player_position,target_position,arrival_radius,arrival_height): status=GameSettings.keys("已到达 · {experiences} 附近体验")
	elif distance<arrival_radius and absf(delta_position.y)>arrival_height: status+=" · 目的地在地面"
	if mobile_rect.has_area():
		var font := get_theme_default_font()
		while status.length()>1 and font.get_string_size(status,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x>mobile_rect.size.x:
			status=status.left(status.length()-2)+"…"
	_text(Vector2(text_x,at.y+76),status,Color("edf3df"),14)

func _panel() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.02,0.065,0.085,0.80)
	style.set_corner_radius_all(8)
	return style
