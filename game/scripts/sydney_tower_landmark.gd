extends RefCounted
## Sydney Tower exterior; documented main dimensions and mapped plan position.
## This is not a surveyed BIM or an operating tower visitor/elevator simulation.
const Geo=preload("res://scripts/city_landmarks.gd")
const CENTER:=Vector3(-143.48673656,4.5,1168.3552663)
const BASE_POINTS:=[[-51.449543, -22.427186], [-53.316023, 12.605218], [-29.236583, 15.889158], [-29.208863, 14.34181], [-5.803943, 17.414242], [16.288897, 17.536694], [16.335097, 15.610858], [22.821577, 15.766706], [22.775377, 16.891038], [39.601417, 16.468022], [41.569537, -18.60891], [24.189097, -20.690594], [24.281497, -14.901954], [16.852537, -15.592138], [17.286817, -25.499618], [-26.640143, -27.614698], [-27.444023, -17.55137], [-34.503383, -17.651558], [-34.374023, -23.685102]]
const HEIGHT:=309.0
const SHAFT_RADIUS:=3.35
const TURRET_RADIUS:=15.5
const BASE_ROOF:=55.0 # inferred vertical datum, not surveyed elevation
const ARRIVAL:=Vector3(-168.4,4.5,1190.8) # public Market Street pavement

static func metadata() -> Array[Dictionary]:
	return [{"id":"sydney_tower","name":"Sydney Tower Eye · 悉尼塔","address":"100 Market Street, Sydney NSW 2000","center":CENTER,"building_center":CENTER,"map_position":CENTER,"arrival":ARRIVAL,"lat":-33.87049546592079,"lon":151.2089471132407,"height_m":HEIGHT,"height_confidence":"operator: 309m tip, 250m observation, 268m SKYWALK; base roof elevation inferred","footprint_confidence":"OSM tower centroid and exact office outline; no cadastral survey","facade_confidence":"operator and owner photographs; BBR cable layout; details and floor elevations reconstructed","interior":"exterior model only; lifts, ticket hall and observation visit are not yet simulated","source":"https://www.sydneytowereye.com.au/explore/explore/about-sydney-tower/"}]

static func excluded_way_ids() -> Array[int]:
	return [197801072,197801073,197801074,273960049]

static func footprints() -> Array[PackedVector2Array]:
	var p:=Geo.polygon(BASE_POINTS)
	for i in p.size():p[i]+=Vector2(CENTER.x,CENTER.z)
	return [p]

static func _lathe(profile:Array[Vector2],segments:int=112) -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(profile.size()-1):
		var a:=profile[j];var b:=profile[j+1]
		for i in segments:
			var aa:=TAU*i/segments;var bb:=TAU*(i+1)/segments
			var p:=Vector3(cos(aa)*a.x,a.y,sin(aa)*a.x);var q:=Vector3(cos(bb)*a.x,a.y,sin(bb)*a.x)
			var r:=Vector3(cos(bb)*b.x,b.y,sin(bb)*b.x);var u:=Vector3(cos(aa)*b.x,b.y,sin(aa)*b.x)
			var mid:=(aa+bb)*0.5
			var n:=Vector3(cos(mid)*(b.y-a.y),a.x-b.x,sin(mid)*(b.y-a.y)).normalized()
			Geo._triangle(st,p,q,r,n,Vector2(aa*TURRET_RADIUS,a.y),Vector2(bb*TURRET_RADIUS,a.y),Vector2(bb*TURRET_RADIUS,b.y))
			Geo._triangle(st,p,r,u,n,Vector2(aa*TURRET_RADIUS,a.y),Vector2(bb*TURRET_RADIUS,b.y),Vector2(aa*TURRET_RADIUS,b.y))
	for end in [0,profile.size()-1]:
		var ring:=profile[end]
		if ring.x<0.001:continue
		for i in segments:
			var a:=TAU*i/segments;var b:=TAU*(i+1)/segments
			Geo._triangle(st,Vector3(0,ring.y,0),Vector3(cos(a)*ring.x,ring.y,sin(a)*ring.x),Vector3(cos(b)*ring.x,ring.y,sin(b)*ring.x),Vector3.DOWN if end==0 else Vector3.UP,Vector2.ZERO,Vector2(cos(a),sin(a)),Vector2(cos(b),sin(b)))
	return st.commit()

static func _solid(w:Node3D,id:String,profile:Array[Vector2],mat:String) -> StaticBody3D:
	return w._structure_mesh("sydney_tower/"+id,_lathe(profile),CENTER,"sydney_tower_"+mat,240000)

static func _ring(st:SurfaceTool,radius:float,y:float,width:float,segments:int=112) -> void:
	for i in segments:
		var a:=TAU*i/segments;var b:=TAU*(i+1)/segments
		Geo._append_beam(st,Vector3(cos(a)*radius,y,sin(a)*radius),Vector3(cos(b)*radius,y,sin(b)*radius),width,width)

static func _st() -> SurfaceTool:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);return st

static func build(w:Node3D) -> void:
	if w.has_meta("sydney_tower_landmark"):return
	for row:Array in [["gold","b59c57"],["edge","d3c17c"],["shaft","5e5550"],["cable","aea89b"],["dark","203240"],["silver","c1c9c7"],["roof","777b76"],["red","c22a35"]]:
		w._mat("sydney_tower_"+row[0],Color(row[1]),0.38 if row[0] in ["gold","edge","dark"] else 0.64,0.45 if row[0] in ["gold","edge","cable"] else 0.15)
	Geo._glazing(w,"sydney_tower_office",Color("334e61"),Color("b7c0c1"),Vector2(1.55,4.1),Vector2(0.07,0.07),14)
	var outline:=Geo.polygon(BASE_POINTS)
	for level in 12:
		var low:=level*BASE_ROOF/12.0;var high:=(level+1)*BASE_ROOF/12.0
		var body:StaticBody3D=w._structure_mesh("sydney_tower/base/%02d"%level,Geo.prism(outline,low,high),CENTER,"sydney_tower_office",180000)
		var fins:=_st()
		for sample:Dictionary in Geo._perimeter_samples(outline,1.55):
			var p:Vector3=sample.position+sample.outward*0.12;p.y=(low+high)*0.5
			Geo._append_box(fins,p,Vector3(0.075,high-low,0.38),sample.basis)
		Geo._commit_detail(w,body,fins,"sydney_tower_silver")
		if level in [2,11]:Geo._detail(w,body,Geo.prism(Geo._scaled(outline,1.001),high-0.23,high),"sydney_tower_silver")
	var support:=_solid(w,"anchor_ring",[Vector2(17.9,BASE_ROOF),Vector2(18.8,BASE_ROOF+0.30),Vector2(18.8,BASE_ROOF+0.65)],"shaft")
	for section in 9:
		var low:=BASE_ROOF+section*(239-BASE_ROOF)/9.0;var high:=BASE_ROOF+(section+1)*(239-BASE_ROOF)/9.0
		var shaft:=_solid(w,"shaft/%02d"%section,[Vector2(SHAFT_RADIUS,low),Vector2(SHAFT_RADIUS,high)],"shaft")
		var seams:=_st()
		for i in 28:
			var a:=TAU*i/28
			Geo._append_box(seams,Vector3(cos(a)*3.365,(low+high)*0.5,sin(a)*3.365),Vector3(0.038,high-low,0.060),Basis(Vector3.UP,-a))
		for y in range(ceili(low),floori(high),5):_ring(seams,3.365,y,0.038,56)
		Geo._commit_detail(w,shaft,seams,"sydney_tower_dark")
	# Two sets of 28 straight lower cables form the observed hyperboloid.
	# BBR specifies the 37.2m anchor circle, 90m coupling, 140m neck and
	# upper anchorage184m above roof. The 55m roof datum is inferred here.
	var cables:=_st();var joints:=_st()
	var twist:=acos(3.6/18.6)
	for family in [-1,1]:
		for i in 28:
			var a:=TAU*(i+0.25)/28
			var lower:=Vector3(cos(a)*18.6,BASE_ROOF+0.65,sin(a)*18.6)
			var neck:=Vector3(cos(a+family*twist)*3.6,BASE_ROOF+140,sin(a+family*twist)*3.6)
			var coupling:=lower.lerp(neck,90.0/140.0)
			var upper:=Vector3(cos(a+family*(twist+0.60))*12.2,BASE_ROOF+184,sin(a+family*(twist+0.60))*12.2)
			Geo._append_beam(cables,lower,coupling,0.17,0.17);Geo._append_beam(cables,coupling,neck,0.17,0.17)
			Geo._append_beam(cables,neck,upper,0.115,0.115)
			Geo._append_box(joints,coupling,Vector3(0.3,0.75,0.3),Basis.IDENTITY)
			Geo._append_beam(joints,lower,lower.lerp(neck,0.009),0.33,0.33)
	_ring(joints,3.75,BASE_ROOF+140,0.26)
	Geo._commit_detail(w,support,cables,"sydney_tower_cable")
	Geo._commit_detail(w,support,joints,"sydney_tower_shaft")
	_solid(w,"turret_underside",[Vector2(3.6,234.4),Vector2(12.2,238.9),Vector2(15.5,240.0)],"shaft")
	for level in 4:
		var low:=240+level*6.0
		var body:=_solid(w,"turret/%02d"%level,[Vector2(15.5,low),Vector2(15.5,low+6)],"gold")
		var glass:=_st();var ribs:=_st()
		# 4×105 physical dark window panels reproduce the documented 420 total.
		for i in 105:
			var a:=TAU*(i+0.5)/105;var radial:=Vector3(cos(a),0,sin(a));var frame:=Basis.looking_at(-radial,Vector3.UP)
			Geo._append_box(glass,radial*15.53+Vector3.UP*(low+3.4),Vector3(0.82,3.55,0.07),frame)
			Geo._append_box(ribs,radial*15.61+Vector3.UP*(low+3.0),Vector3(0.068,6,0.11),frame)
		_ring(ribs,15.65,low+0.16,0.17);_ring(ribs,15.65,low+5.8,0.17)
		Geo._commit_detail(w,body,glass,"sydney_tower_dark");Geo._commit_detail(w,body,ribs,"sydney_tower_edge")
	var top:=_solid(w,"turret_roof",[Vector2(15.5,264),Vector2(15.7,264.5),Vector2(10.0,265.1)],"silver")
	var drum:=_solid(w,"upper_drum",[Vector2(8.8,264.9),Vector2(8.8,279.6)],"gold")
	var trim:=_st()
	for i in 84:
		var a:=TAU*i/84;Geo._append_beam(trim,Vector3(cos(a)*8.84,265,sin(a)*8.84),Vector3(cos(a)*8.84,279.6,sin(a)*8.84),0.05,0.05)
	for y in [268.0,279.65]:_ring(trim,8.94,y,0.18)
	# External SKYWALK is a visible ring/platform structure. It is not exposed
	# as a visit destination until an accessible lift/interior is implemented.
	for radius in [10.1,12.0]:
		_ring(trim,radius,268,0.18);_ring(trim,radius,269.15,0.08)
		for i in 56:
			var a:=TAU*i/56
			Geo._append_beam(trim,Vector3(cos(a)*radius,265.0,sin(a)*radius),Vector3(cos(a)*radius,269.15,sin(a)*radius),0.07,0.07)
	for i in 56:
		var a:=TAU*i/56;var b:=TAU*(i+1)/56
		Geo._append_box(trim,Vector3(cos(a)*11.05,267.88,sin(a)*11.05),Vector3(2.1,0.12,1.20),Basis(Vector3.UP,-a))
		Geo._append_beam(trim,Vector3(cos(a)*10.1,266.4,sin(a)*10.1),Vector3(cos(b)*12,268,sin(b)*12),0.065,0.065)
	Geo._commit_detail(w,drum,trim,"sydney_tower_edge")
	for yaw in [0,120,240]:
		var sign:=Label3D.new();sign.text="Westfield";sign.font_size=96;sign.pixel_size=0.042;sign.modulate=Color("bb2637");sign.outline_size=0;sign.double_sided=false
		var a:=deg_to_rad(yaw);sign.position=Vector3(sin(a)*9.04,273.4,cos(a)*9.04);sign.rotation.y=a;drum.add_child(sign)
	_solid(w,"plant",[Vector2(6.3,279.6),Vector2(6.3,285.2),Vector2(7.6,285.4),Vector2(5.6,287.8)],"silver")
	_solid(w,"spire/lower",[Vector2(1.05,287.8),Vector2(0.7,299)],"shaft")
	_solid(w,"spire/upper",[Vector2(0.7,299),Vector2(0.18,308.7)],"silver")
	_solid(w,"beacon",[Vector2(0.19,308.7),Vector2(0.19,309.0)],"red")
	w.set_meta("sydney_tower_landmark",metadata())
	w.set_meta("sydney_tower_geometry",{"cables":56,"cable_families":2,"windows":420,"shaft_diameter_m":6.7,"turret_diameter_m":31.0,"tip_height_m":309.0,"base_roof_estimate_m":55.0})
