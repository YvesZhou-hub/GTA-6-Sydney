extends RefCounted
## Sydney Tower exterior; documented main dimensions and mapped plan position.
## This is not a surveyed BIM or an operating tower visitor/elevator simulation.
const CpuMesh = preload("res://scripts/cpu_mesh.gd")
const Geo=preload("res://scripts/city_landmarks.gd")
const CENTER:=Vector3(-143.48673656,4.5,1168.3552663)
const BASE_POINTS:=[[-51.449543, -22.427186], [-53.316023, 12.605218], [-29.236583, 15.889158], [-29.208863, 14.34181], [-5.803943, 17.414242], [16.288897, 17.536694], [16.335097, 15.610858], [22.821577, 15.766706], [22.775377, 16.891038], [39.601417, 16.468022], [41.569537, -18.60891], [24.189097, -20.690594], [24.281497, -14.901954], [16.852537, -15.592138], [17.286817, -25.499618], [-26.640143, -27.614698], [-27.444023, -17.55137], [-34.503383, -17.651558], [-34.374023, -23.685102]]
const HEIGHT:=309.0
const SHAFT_RADIUS:=3.35
const TURRET_RADIUS:=15.5
const BASE_ROOF:=55.0 # inferred vertical datum, not surveyed elevation
const SKYWALK_Y:=268.0
const SKYWALK_PLATFORM_ANGLES:=[-35.0,145.0] # photo-derived azimuths, not surveyed bearings
const ARRIVAL:=Vector3(-168.4,4.5,1190.8) # public Market Street pavement

static func metadata() -> Array[Dictionary]:
	return [{"id":"sydney_tower","name":"Sydney Tower Eye · 悉尼塔","address":"100 Market Street, Sydney NSW 2000","center":CENTER,"building_center":CENTER,"map_position":CENTER,"arrival":ARRIVAL,"lat":-33.87049546592079,"lon":151.2089471132407,"height_m":HEIGHT,"height_confidence":"operator: 309m tip, 250m observation, 268m SKYWALK; base roof elevation inferred","footprint_confidence":"OSM tower centroid and exact office outline; no cadastral survey","facade_confidence":"operator and owner photographs; BBR cable layout; details and floor elevations reconstructed","interior":"exterior model only; lifts, ticket hall and observation visit are not yet simulated","source":"https://www.sydneytowereye.com.au/explore/explore/about-sydney-tower/"}]

static func capture_views() -> Array:
	return [
		["sydney-tower-whole",CENTER+Vector3(-295,167,375),CENTER+Vector3(0,150,0)],
		["sydney-tower-skywalk",CENTER+Vector3(-45,284,67),CENTER+Vector3(0,270,0)],
		["sydney-tower-podium",CENTER+Vector3(-83,14,90),CENTER+Vector3(-6,33,0)],
	]

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
	return CpuMesh.commit(st)

static func _solid(w:Node3D,id:String,profile:Array[Vector2],mat:String) -> StaticBody3D:
	return w._structure_mesh("sydney_tower/"+id,_lathe(profile),CENTER,"sydney_tower_"+mat,240000)

static func _ring(st:SurfaceTool,radius:float,y:float,width:float,segments:int=112) -> void:
	for i in segments:
		var a:=TAU*i/segments;var b:=TAU*(i+1)/segments
		Geo._append_beam(st,Vector3(cos(a)*radius,y,sin(a)*radius),Vector3(cos(b)*radius,y,sin(b)*radius),width,width)

static func _st() -> SurfaceTool:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);return st

static func _quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3,n:Vector3) -> void:
	Geo._triangle(st,a,b,c,n,Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z))
	Geo._triangle(st,a,c,d,n,Vector2(a.x,a.z),Vector2(c.x,c.z),Vector2(d.x,d.z))

static func _annulus(st:SurfaceTool,inner:float,outer:float,y:float,thickness:float,segments:int=70) -> void:
	for i in segments:
		var a:=TAU*i/segments;var b:=TAU*(i+1)/segments
		var p:=Vector3(cos(a)*inner,y,sin(a)*inner);var q:=Vector3(cos(a)*outer,y,sin(a)*outer)
		var r:=Vector3(cos(b)*outer,y,sin(b)*outer);var t:=Vector3(cos(b)*inner,y,sin(b)*inner)
		var down:=Vector3.DOWN*thickness;var normal:=Vector3(cos((a+b)*0.5),0,sin((a+b)*0.5))
		_quad(st,p,q,r,t,Vector3.UP);_quad(st,p+down,t+down,r+down,q+down,Vector3.DOWN)
		_quad(st,q,q+down,r+down,r,normal);_quad(st,p,t,t+down,p+down,-normal)

static func _named_detail(w:Node3D,body:StaticBody3D,st:SurfaceTool,mat:String,role:String) -> void:
	Geo._commit_detail(w,body,st,"sydney_tower_"+mat)
	body.get_child(body.get_child_count()-1).name=role

static func _at_platform_entry(a:float) -> bool:
	for degrees in SKYWALK_PLATFORM_ANGLES:
		if absf(wrapf(a-deg_to_rad(degrees),-PI,PI))<0.15:return true
	return false

static func _skywalk(w:Node3D,drum:StaticBody3D) -> void:
	var decks:=_st();var rails:=_st();var supports:=_st();var glass:=_st()
	# Operator close-up shows two narrow stacked galleries, with the upper
	# visitor gallery at 268m and a lower maintenance gallery above the roof.
	for y in [265.8,SKYWALK_Y]:
		_annulus(decks,8.94,10.2,y,0.13)
		for h in [0.12,0.58,1.15]:
			for segment in 70:
				var a:=TAU*segment/70;var b:=TAU*(segment+1)/70
				if y==SKYWALK_Y and _at_platform_entry((a+b)*0.5):continue
				Geo._append_beam(rails,Vector3(cos(a)*10.22,y+h,sin(a)*10.22),Vector3(cos(b)*10.22,y+h,sin(b)*10.22),0.055,0.055)
		for i in 35:
			var a:=TAU*i/35;var radial:=Vector3(cos(a),0,sin(a))
			if y==SKYWALK_Y and _at_platform_entry(a):continue
			Geo._append_beam(rails,radial*10.22+Vector3.UP*y,radial*10.22+Vector3.UP*(y+1.17),0.065,0.065)
	for i in 35:
		var a:=TAU*i/35;var radial:=Vector3(cos(a),0,sin(a))
		Geo._append_beam(supports,radial*10.12+Vector3.UP*264.5,radial*10.12+Vector3.UP*268.0,0.16,0.16)
		Geo._append_beam(supports,radial*8.94+Vector3.UP*265.0,radial*10.12+Vector3.UP*267.86,0.095,0.095)
		Geo._append_beam(supports,radial*8.94+Vector3.UP*267.84,radial*10.24+Vector3.UP*267.84,0.15,0.15)
	# The official operator explicitly describes TWO glass platforms. Their
	# rectangular plan and paired legs/diagonal braces are visible in photos.
	for degrees in SKYWALK_PLATFORM_ANGLES:
		var a:=deg_to_rad(degrees);var outward:=Vector3(cos(a),0,sin(a));var tangent:=Vector3(-sin(a),0,cos(a))
		var frame:=Basis.looking_at(-outward,Vector3.UP)
		var center:=outward*13.0+Vector3.UP*SKYWALK_Y
		Geo._append_box(decks,outward*10.42+Vector3.UP*(SKYWALK_Y-0.065),Vector3(2.75,0.13,0.60),frame)
		# Four independently framed floor panels; no borrowed photo texture.
		for x in [-1.34,1.34]:
			for z in [-1.27,1.27]:Geo._append_box(glass,center+tangent*x+outward*z-Vector3.UP*0.055,Vector3(2.58,0.11,2.44),frame)
		for x in [-2.75,0.0,2.75]:
			Geo._append_beam(supports,center+tangent*x-outward*2.6-Vector3.UP*0.18,center+tangent*x+outward*2.6-Vector3.UP*0.18,0.17,0.30)
		for z in [-2.6,0.0,2.6]:Geo._append_beam(supports,center-tangent*2.8+outward*z-Vector3.UP*0.18,center+tangent*2.8+outward*z-Vector3.UP*0.18,0.17,0.30)
		for side in [-1,1]:
			var foot:Vector3=outward*13.4+tangent*side*2.4+Vector3.UP*264.5
			Geo._append_box(supports,foot+Vector3.UP*0.10,Vector3(0.75,0.20,0.65),frame)
			Geo._append_beam(supports,foot,center+tangent*side*2.4+outward*0.4-Vector3.UP*0.2,0.25,0.25)
			Geo._append_beam(supports,foot,center+tangent*side*2.4+outward*2.55-Vector3.UP*0.2,0.16,0.16)
		# Three exposed sides have inset glass guards, top rails and safety wire.
		var corners:=[center-tangent*2.8-outward*2.6,center-tangent*2.8+outward*2.6,center+tangent*2.8+outward*2.6,center+tangent*2.8-outward*2.6]
		for edge in 3:
			var start:Vector3=corners[edge];var end:Vector3=corners[edge+1]
			for h in [0.12,1.12,1.44]:Geo._append_beam(rails,start+Vector3.UP*h,end+Vector3.UP*h,0.075,0.075)
			for post in 5:
				var pos:=start.lerp(end,post/4.0)
				Geo._append_beam(rails,pos,pos+Vector3.UP*1.48,0.09,0.09)
			for panel in 4:
				var p1:=start.lerp(end,(panel+0.05)/4.0)+Vector3.UP*0.62;var p2:=start.lerp(end,(panel+0.95)/4.0)+Vector3.UP*0.62
				var along:=(p2-p1).normalized()
				Geo._append_box(glass,(p1+p2)*0.5,Vector3(p1.distance_to(p2),0.86,0.065),Basis(along,Vector3.UP,along.cross(Vector3.UP)))
	_named_detail(w,drum,decks,"roof","SkywalkGalleryDecks")
	_named_detail(w,drum,supports,"gold","SkywalkPlatformFrames")
	_named_detail(w,drum,rails,"edge","SkywalkGuardrails")
	_named_detail(w,drum,glass,"platform_glass","SkywalkGlassPlatforms")

static func _roof_detail(w:Node3D,top:StaticBody3D) -> void:
	var ribs:=_st();var guards:=_st();var glass:=_st()
	for i in 70:
		var a:=TAU*i/70;var radial:=Vector3(cos(a),0,sin(a));var frame:=Basis.looking_at(-radial,Vector3.UP)
		Geo._append_beam(ribs,radial*10.5+Vector3.UP*264.56,radial*15.45+Vector3.UP*264.56,0.13,0.13)
		Geo._append_beam(guards,radial*15.47+Vector3.UP*264.4,radial*15.47+Vector3.UP*265.42,0.095,0.095)
		Geo._append_box(glass,radial*15.46+Vector3.UP*264.93,Vector3(1.28,0.8,0.06),frame)
	for radius in [14.0,14.55]:_ring(ribs,radius,264.61,0.12,70)
	for y in [264.5,265.42]:_ring(guards,15.47,y,0.13,70)
	_named_detail(w,top,ribs,"silver","RoofRadialRibsAndTrack")
	_named_detail(w,top,guards,"edge","RoofPerimeterGuard")
	_named_detail(w,top,glass,"platform_glass","RoofGlassParapet")

static func _plant_detail(w:Node3D,plant:StaticBody3D) -> void:
	var ribs:=_st();var slots:=_st();var rails:=_st()
	for i in 42:
		var a:=TAU*i/42;var radial:=Vector3(cos(a),0,sin(a));var frame:=Basis.looking_at(-radial,Vector3.UP)
		Geo._append_beam(ribs,radial*6.35+Vector3.UP*279.7,radial*6.35+Vector3.UP*285.1,0.075,0.075)
		Geo._append_box(slots,radial*6.355+Vector3.UP*281.4,Vector3(0.25,1.9,0.045),frame)
	# White upper maintenance gallery and the visibly rounded safety hoops.
	_annulus(ribs,6.30,8.3,279.84,0.14)
	for y in [280.0,280.48,280.98]:_ring(rails,8.27,y,0.07,56)
	for i in 28:
		var a:=TAU*i/28;var radial:=Vector3(cos(a),0,sin(a))
		Geo._append_beam(rails,radial*8.27+Vector3.UP*279.8,radial*8.27+Vector3.UP*281.1,0.08,0.08)
	for i in 14:
		var a:=TAU*i/14;var radial:=Vector3(cos(a),0,sin(a));var tangent:=Vector3(-sin(a),0,cos(a))
		for side in [-1,1]:Geo._append_beam(rails,radial*7.92+tangent*side*0.4+Vector3.UP*279.9,radial*7.92+tangent*side*0.4+Vector3.UP*281.64,0.09,0.09)
		for j in 8:
			var first:=PI*j/8;var last:=PI*(j+1)/8
			Geo._append_beam(rails,radial*7.92+tangent*cos(first)*0.4+Vector3.UP*(281.64+sin(first)*0.4),radial*7.92+tangent*cos(last)*0.4+Vector3.UP*(281.64+sin(last)*0.4),0.09,0.09)
	_named_detail(w,plant,ribs,"silver","PlantFlutesAndGallery")
	_named_detail(w,plant,slots,"dark","PlantVerticalSlots")
	_named_detail(w,plant,rails,"silver","PlantRailsAndSafetyHoops")

static func _branding(w:Node3D,drum:StaticBody3D) -> void:
	# Build curved raised letters from Godot's bundled outline font. This is
	# readable architectural lettering, not a copied Westfield logo asset.
	var lettering:=_st();var font:=ThemeDB.fallback_font;var word:="Westfield";var widths:Array[float]=[];var total:=0.0
	for letter in word:
		var width:=font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,48).x*0.07
		widths.append(width);total+=width
	for yaw in [0.0,120.0,240.0]:
		var cursor:=-total*0.5
		for i in word.length():
			var glyph:=TextMesh.new();glyph.text=word.substr(i,1);glyph.font=font;glyph.font_size=48;glyph.pixel_size=0.07;glyph.depth=0.17;glyph.curve_step=2.0
			var a:=deg_to_rad(yaw)+(cursor+widths[i]*0.5)/9.06
			var outward:=Vector3(sin(a),0,cos(a));var tangent:=Vector3(cos(a),0,-sin(a))
			var basis:=Basis(tangent,tangent*0.26+Vector3.UP*1.65,outward)
			lettering.append_from(glyph,0,Transform3D(basis,outward*9.06+Vector3.UP*273.3))
			cursor+=widths[i]
	_named_detail(w,drum,lettering,"red","RaisedCurvedLettering")

static func build(w:Node3D) -> void:
	if w.has_meta("sydney_tower_landmark"):return
	for row:Array in [["gold","b59c57"],["edge","d3c17c"],["shaft","5e5550"],["cable","aea89b"],["dark","203240"],["silver","c1c9c7"],["roof","777b76"],["red","c22a35"],["podium","3e3c37"],["platform_glass","75968d"]]:
		w._mat("sydney_tower_"+row[0],Color(row[1]),0.38 if row[0] in ["gold","edge","dark"] else 0.64,0.45 if row[0] in ["gold","edge","cable"] else 0.15)
	var platform_glass:StandardMaterial3D=w.materials["sydney_tower_platform_glass"]
	platform_glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	platform_glass.albedo_color=Color(0.46,0.61,0.57,0.45);platform_glass.roughness=0.18
	Geo._glazing(w,"sydney_tower_office",Color("334e61"),Color("b7c0c1"),Vector2(1.55,4.1),Vector2(0.07,0.07),14)
	var outline:=Geo.polygon(BASE_POINTS)
	for level in 12:
		var low:=level*BASE_ROOF/12.0;var high:=(level+1)*BASE_ROOF/12.0
		var body:StaticBody3D=w._structure_mesh("sydney_tower/base/%02d"%level,Geo.prism(outline,low,high),CENTER,"sydney_tower_podium" if level<2 else "sydney_tower_office",180000)
		var fins:=_st()
		for sample:Dictionary in Geo._perimeter_samples(outline,4.65 if level<2 else 1.55):
			var p:Vector3=sample.position+sample.outward*0.12;p.y=(low+high)*0.5
			Geo._append_box(fins,p,Vector3(0.18 if level<2 else 0.075,high-low,0.48),sample.basis)
		Geo._commit_detail(w,body,fins,"sydney_tower_silver")
		# Ten office bands above the retail transition; cap each floor with a
		# shallow spandrel edge, leaving the mapped base footprint untouched.
		if level>=2:Geo._detail(w,body,Geo.prism(Geo._scaled(outline,1.001),high-0.14,high),"sydney_tower_silver")
		if level<2:
			var shopglass:=_st();var lintels:=_st()
			for sample:Dictionary in Geo._perimeter_samples(outline,4.65):
				var pos:Vector3=sample.position+sample.outward*0.06;pos.y=(low+high)*0.5
				Geo._append_box(shopglass,pos,Vector3(3.5,high-low-1.15,0.07),sample.basis)
			for i in outline.size():
				var a:=outline[i];var b:=outline[(i+1)%outline.size()]
				Geo._append_beam(lintels,Vector3(a.x,high-0.12,a.y),Vector3(b.x,high-0.12,b.y),0.4,0.28)
			_named_detail(w,body,shopglass,"dark","RetailDisplayBays")
			_named_detail(w,body,lintels,"silver","RetailCornice")
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
	var underside:=_solid(w,"turret_underside",[Vector2(3.6,234.0),Vector2(4.15,234.5),Vector2(4.15,235.0),Vector2(12.2,238.9),Vector2(15.5,239.6),Vector2(15.5,240.0)],"shaft")
	var soffit:=_st()
	for i in 28:
		var a:=TAU*i/28;var radial:=Vector3(cos(a),0,sin(a))
		Geo._append_beam(soffit,radial*4.1+Vector3.UP*234.82,radial*12.25+Vector3.UP*238.68,0.17,0.20)
		Geo._append_beam(soffit,radial*12.25+Vector3.UP*238.68,radial*15.3+Vector3.UP*239.43,0.17,0.20)
	for radius_y in [Vector2(4.2,234.75),Vector2(12.25,238.8),Vector2(15.5,239.7)]:_ring(soffit,radius_y.x,radius_y.y,0.19,56)
	_named_detail(w,underside,soffit,"silver","TurretRadialSoffit")
	for level in 4:
		var low:=240+level*6.0
		var body:=_solid(w,"turret/%02d"%level,[Vector2(15.5,low),Vector2(15.5,low+6)],"gold")
		var glass:=_st();var ribs:=_st()
		# 4×105 physical dark window panels reproduce the documented 420 total.
		for i in 105:
			var a:=TAU*(i+0.5)/105;var radial:=Vector3(cos(a),0,sin(a));var frame:=Basis.looking_at(-radial,Vector3.UP)
			Geo._append_box(glass,radial*15.53+Vector3.UP*(low+3.4),Vector3(0.82,3.55,0.07),frame)
			# Put mullions at bay boundaries; the old model accidentally put
			# another bar through every pane's centre, doubling the visual grid.
			var edge_angle:=TAU*i/105;var edge_radial:=Vector3(cos(edge_angle),0,sin(edge_angle))
			Geo._append_box(ribs,edge_radial*15.61+Vector3.UP*(low+3.0),Vector3(0.068,6,0.13),Basis.looking_at(-edge_radial,Vector3.UP))
		_ring(ribs,15.65,low+0.16,0.17);_ring(ribs,15.65,low+5.8,0.17)
		_named_detail(w,body,glass,"dark","TurretWindowPanels");_named_detail(w,body,ribs,"edge","TurretMullions")
	var top:=_solid(w,"turret_roof",[Vector2(15.5,264),Vector2(15.7,264.14),Vector2(15.7,264.5),Vector2(8.94,264.5)],"silver")
	_roof_detail(w,top)
	var drum:=_solid(w,"upper_drum",[Vector2(8.8,264.9),Vector2(8.8,279.6)],"gold")
	var trim:=_st()
	for i in 84:
		var a:=TAU*i/84;Geo._append_beam(trim,Vector3(cos(a)*8.84,265,sin(a)*8.84),Vector3(cos(a)*8.84,279.6,sin(a)*8.84),0.05,0.05)
	for y in [268.0,279.65]:_ring(trim,8.94,y,0.18)
	Geo._commit_detail(w,drum,trim,"sydney_tower_edge")
	_skywalk(w,drum)
	_branding(w,drum)
	var plant:=_solid(w,"plant",[Vector2(6.3,279.6),Vector2(6.3,285.2),Vector2(7.6,285.4),Vector2(7.6,285.65),Vector2(5.6,287.8)],"silver")
	_plant_detail(w,plant)
	_solid(w,"spire/lower",[Vector2(1.05,287.8),Vector2(0.7,299)],"shaft")
	_solid(w,"spire/upper",[Vector2(0.7,299),Vector2(0.18,308.7)],"silver")
	_solid(w,"beacon",[Vector2(0.19,308.7),Vector2(0.19,309.0)],"red")
	w.set_meta("sydney_tower_landmark",metadata())
	w.set_meta("sydney_tower_geometry",{"cables":56,"cable_families":2,"windows":420,"shaft_diameter_m":6.7,"turret_diameter_m":31.0,"tip_height_m":309.0,"base_roof_estimate_m":55.0,"skywalk_glass_platforms":2,"skywalk_gallery_levels":2,"office_bands":10,"retail_damage_bands":2,"roof_radial_ribs":70,"plant_safety_hoops":14})
