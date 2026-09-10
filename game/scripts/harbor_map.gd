extends Control
var anchors:Dictionary={}
var player_position=Vector3.ZERO
var overview=false
var runway_data:Array=[]
var south_points=PackedVector2Array()
var north_points=PackedVector2Array()
func project_point(v:Vector3)->Vector2:
	return Vector2(430+v.x*0.046,120+v.z*0.044) if overview else Vector2(390+v.x*0.34,580+v.z*0.34)
func _draw():
	draw_style_box(style(),Rect2(Vector2.ZERO,size))
	var grid=Color(0.7,0.85,0.8,0.08)
	for x in range(0,int(size.x),50): draw_line(Vector2(x,0),Vector2(x,size.y),grid)
	for y in range(0,int(size.y),50): draw_line(Vector2(0,y),Vector2(size.x,y),grid)
	if overview:
		draw_overview()
		return
	var south=PackedVector2Array([Vector2(0,735),Vector2(0,490),Vector2(225,435),Vector2(345,360),Vector2(376,408),Vector2(380,535),Vector2(432,543),Vector2(480,415),Vector2(555,422),Vector2(550,568),Vector2(780,580),Vector2(780,735)])
	var north=PackedVector2Array([Vector2(0,0),Vector2(780,0),Vector2(780,180),Vector2(470,185),Vector2(425,251),Vector2(365,208),Vector2(260,265),Vector2(0,220)])
	draw_colored_polygon(south,Color("3c6262"))
	draw_colored_polygon(north,Color("3c6262"))
	draw_line(Vector2(365,395),Vector2(420,210),Color("d4c39a"),9)
	var f=get_theme_default_font()
	var names={"home":"STUDIO","quay":"CIRCULAR QUAY","opera":"OPERA HOUSE","rocks":"THE ROCKS","north":"MILSONS POINT","marina":"MARINA","helipad":"HELIPAD"}
	for key in names:
		if anchors.has(key):
			var p=project_point(anchors[key])
			draw_circle(p,5,Color("ecdbac"))
			draw_string(f,p+Vector2(10,-8),names[key],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("ecdbac"))
	var player=project_point(player_position)
	draw_circle(player,11,Color(0.4,1,0.82,0.22))
	draw_circle(player,5,Color("8ff6c9"))
	draw_string(f,Vector2(30,35),"N ↑    SYDNEY HARBOUR",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("c6ddd5"))
	draw_string(f,Vector2(30,size.y-26),"Schematic · 游戏示意图 / not a surveyed map",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("9cbbb4"))
func style()->StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=Color(0.035,0.17,0.23,0.96)
	s.set_corner_radius_all(12)
	return s

func draw_overview():
	var f=get_theme_default_font()
	draw_string(f,Vector2(30,35),"N ↑   AIRPORT ↔ HARBOUR",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("ecdbac"))
	for key in ["airport","opera","north"]:
		if anchors.has(key):
			var p=project_point(anchors[key])
			draw_circle(p,6,Color("ecdbac"))
			draw_string(f,p+Vector2(12,0),{"airport":"SYDNEY AIRPORT","opera":"OPERA HOUSE","north":"HARBOUR BRIDGE"}[key],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("ecdbac"))
	for runway in runway_data:
		draw_line(project_point(runway.a),project_point(runway.b),Color("f4f0d8"),5)
	if anchors.has("airport"):
		draw_dashed_line(project_point(anchors.airport),project_point(anchors.opera),Color("7abda8"),2,10)
	draw_circle(project_point(player_position),7,Color("8ff6c9"))
	draw_string(f,Vector2(30,650),"中间区域：简化地形 / 未建街区",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("c6ddd5"))
	draw_string(f,Vector2(30,681),"位置保持真实距离；这是游戏路线示意图。",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("9cbbb4"))
