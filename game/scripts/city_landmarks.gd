extends RefCounted
## Four independently researched exteriors. OSM defines positions and footprints;
## public architecture references define massing. See docs/CITY_REFERENCE.md for
## the distinction between measured map data and inferred facade dimensions.

const TOWER_PODIUM_CENTER := Vector3(-775.00336,4.5,427.86918)
const TOWER_PODIUM_POINTS := [[48.49912,47.23345],[-2.441,26.90642],[-46.63592,6.95788],[-50.18408,-34.9875],[-11.1266,-38.6054],[-4.39988,-35.2992],[-6.137,-31.77035],[32.21824,-14.96103],[42.67792,-11.0203],[45.52384,15.15103]]
const TOWER_CENTER := Vector3(-773.42078,4.5,430.78483)
const TOWER_POINTS := [[-7.71958,-34.686],[-13.16194,-21.71722],[-9.24418,-20.09195],[-10.96282,-16.08443],[-25.22014,-22.34062],[-26.70778,-22.68571],[-28.42642,-22.86382],[-30.0157,-22.86382],[-31.68814,-22.73024],[-33.13882,-22.34062],[-34.67266,-21.85081],[-35.99398,-21.28308],[-37.39846,-20.44818],[-38.54422,-19.56875],[-39.9025,-18.34423],[-40.9651,-17.00839],[-41.80594,-15.78387],[-42.59134,-14.28105],[-43.16422,-12.96747],[-43.8295,-11.3756],[-44.30998,-9.92844],[-44.7073,-8.29203],[-44.83666,-6.80034],[-44.83666,-5.30866],[-44.7535,-3.76131],[-44.48554,-2.26962],[-43.95886,-0.98944],[-43.25662,0.45772],[-42.37882,1.96054],[-41.31622,3.31864],[-40.0873,4.5543],[-38.85838,5.56731],[-37.70338,6.30202],[-36.3451,6.9922],[-34.71886,7.71578],[17.0159,30.74789],[19.75094,31.95015],[22.54142,32.86297],[25.66454,33.02995],[28.2887,32.74052],[30.7373,32.00581],[33.07502,30.80355],[35.00618,29.21168],[36.42914,27.56414],[37.39934,26.02792],[38.24942,24.42492],[39.10874,22.55474],[39.84794,20.43966],[40.17134,18.7142],[40.40234,17.10006],[40.40234,15.3412],[40.17134,13.62688],[39.75554,11.96821],[39.24734,10.53218],[38.55434,9.09615],[37.67654,7.78258],[36.52154,6.41334],[35.45894,5.40033],[34.02674,4.42071],[32.4467,3.686],[30.6449,2.8511],[19.03946,-2.23622],[20.97986,-6.67789],[25.09166,-4.93017],[30.63566,-17.87668]]
const BOC_CENTER := Vector3(-610.63647,4.5,1027.06210)
const BOC_POINTS := [[-13.48857,-23.32306],[-9.26589,22.21796],[16.01475,19.42382],[14.36079,-1.35962],[7.25523,-1.92735],[5.82303,-24.78135]]
const RIBBON_CENTER := Vector3(-811.46936,4.5,1507.24868)
const RIBBON_POINTS := [[-62.1172,10.79989],[-58.21792,25.09338],[-53.48704,42.43704],[-30.01744,30.28089],[-13.01584,22.80019],[3.98576,15.31948],[20.0726,9.08556],[32.71292,4.18748],[54.122,-4.79604],[51.01736,-14.9039],[45.6674,-29.0304],[45.05756,-30.63341],[53.82632,-39.38316],[47.885,-51.20535],[33.3782,-37.85808],[22.30868,-28.77437],[10.6478,-20.29178],[4.8266,-16.7852],[-4.43188,-11.20807],[-12.76636,-7.08923],[-19.40992,-3.80529],[-30.655,0.59185],[-40.36624,4.38786]]
const RIBBON_ANGLE := 29.0
const TOWER_HEIGHT := 217.0
const BOC_HEIGHT := 58.0 # Estimated from the documented 15 storeys; no survey height found.
const RIBBON_HEIGHT := 90.0
const EXCHANGE_CENTER := Vector3(-768.49507,4.5,1993.50219)
const EXCHANGE_POINTS := [[0.41083,-19.52029],[-5.80769,-18.65199],[-11.43485,-15.85786],[-15.87929,-11.41619],[-18.68825,-5.80566],[-19.57529,0.41713],[-18.44801,6.59539],[-15.42653,12.09459],[-10.80653,16.35815],[-5.08697,18.92964],[1.15927,19.297],[7.15603,17.77191],[10.03891,16.54739],[12.64459,14.85533],[14.91763,12.74025],[16.79335,10.22442],[18.20707,7.40802],[19.09411,4.40238],[19.43599,1.28542],[18.88159,-4.95963],[16.32211,-10.70374],[12.07171,-15.32352],[6.58315,-18.37369]]
const EXCHANGE_HEIGHT := 30.0 # Envelope estimate; the primary BCA report gives 25.55m effective height, not roof height.
const EXCHANGE_LEVELS := [0.0,4.3,7.4,11.9,16.4,21.0,25.55,30.0]
const EXCHANGE_RADII := [15.5,16.9,17.8,17.0,16.1,18.0,16.9]
const EXCHANGE_OFFSETS := [[0.0,0.0],[-0.6,0.7],[-1.1,-0.4],[0.8,-1.0],[1.1,0.8],[-0.3,0.5],[-1.2,-0.6]]

# UV is in physical metres. Filtered window/facade patterns remain stable at
# flying distance; no third-party raster textures or invented logos are used.
const GLAZING_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 glass_color : source_color = vec4(0.23,0.37,0.43,1.0);
uniform vec4 frame_color : source_color = vec4(0.48,0.52,0.53,1.0);
uniform vec2 bay = vec2(1.4,4.12);
uniform vec2 frame = vec2(0.055,0.10);
uniform float base_height = 0.0;
varying vec3 local_normal;
void vertex(){ local_normal=NORMAL; }
void fragment(){
    vec2 cell=(UV-vec2(0.0,base_height))/bay;
    vec2 edge=min(fract(cell),1.0-fract(cell))*bay;
    vec2 aa=max(fwidth(UV),vec2(0.006));
    float lines=1.0-smoothstep(frame.x-aa.x,frame.x+aa.x,edge.x)*smoothstep(frame.y-aa.y,frame.y+aa.y,edge.y);
    float rnd=fract(sin(dot(floor(cell),vec2(12.9898,78.233)))*43758.5453);
    float blinds=step(0.74,rnd)*0.12;
    vec3 glazing=glass_color.rgb*(0.90+0.17*rnd)+vec3(blinds);
    float relief=0.05*sin(UV.y*0.7)+0.04*cos(UV.x*0.11);
    glazing+=vec3(relief*0.4,relief*0.7,relief);
    ALBEDO=mix(glazing,frame_color.rgb,lines);
    ROUGHNESS=mix(0.23,0.72,lines);
    METALLIC=mix(0.38,0.12,lines);
    if(abs(local_normal.y)>0.7){ALBEDO=frame_color.rgb*0.72;ROUGHNESS=0.78;METALLIC=0.1;}
}
"""

static func metadata() -> Array[Dictionary]:
	return [
		{"id":"tower_one","name":"International Tower One · HSBC Australia headquarters","address":"100 Barangaroo Avenue, Barangaroo NSW 2000","lat":-33.8638697883,"lon":151.2021296452,"center":TOWER_CENTER,"height_m":217.0,"height_confidence":"CTBUH and OSM tagged; architectural height","levels":49,"osm_ids":[468557019,581013659],"footprint_confidence":"OSM surveyed/map outline; not cadastral survey","facade_confidence":"reconstruction from real exterior photographs; individual shading fins approximated","source":"https://www.about.hsbc.com.au/"},
		{"id":"boc","name":"Bank of China Australia headquarters","address":"140 Sussex Street, Sydney NSW 2000","lat":-33.8692262136,"lon":151.2038913802,"center":BOC_CENTER,"height_m":58.0,"height_confidence":"estimated from 15 documented levels; not a measured building height","levels":15,"osm_ids":[544307818],"footprint_confidence":"OSM mapped outline; curved facade bay approximated","facade_confidence":"existing exterior reconstructed from 2016 photo; 2019 rooftop refurbishment referenced, layout approximate","source":"https://www.bankofchina.com/au/en/bocinfo/bi1/201907/t20190710_15913196.html"},
		{"id":"ribbon","name":"W Sydney · The Ribbon","address":"31 Wheat Road, Sydney NSW 2000","lat":-33.8735397834,"lon":151.2017178641,"center":RIBBON_CENTER,"height_m":90.0,"height_confidence":"CTBUH architectural height","levels":25,"osm_ids":[614461305],"footprint_confidence":"OSM mapped podium outline; curved upper envelope reconstructed","facade_confidence":"photo-based curved elevation and glazing rhythm; no detailed architectural plans","source":"https://www.marriott.com/en-us/hotels/sydwh-w-sydney/overview/"},
		{"id":"exchange_haidilao","name":"The Exchange · Haidilao Darling Square (Level 5)","address":"1 Little Pier Street, Haymarket NSW 2000","lat":-33.8779078529,"lon":151.2021829537,"center":EXCHANGE_CENTER,"height_m":30.0,"height_confidence":"roof envelope estimate; NSW BCA report records effective occupied height25.55m; OSM15m tag rejected","levels":7,"osm_ids":[614603737],"footprint_confidence":"OSM mapped circular envelope; staggered floor plates reconstructed","facade_confidence":"architect's completed-building photo; irregular timber facade recreated procedurally, floor offsets estimated","source":"https://kkaa.co.jp/en/project/the-exchange/"}
	]

static func excluded_way_ids() -> Array[int]:
	return [468557019,581013659,544307818,614461305,614603737]

static func footprints() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for item: Array in [[TOWER_PODIUM_POINTS,TOWER_PODIUM_CENTER],[TOWER_POINTS,TOWER_CENTER],[BOC_POINTS,BOC_CENTER],[RIBBON_POINTS,RIBBON_CENTER],[EXCHANGE_POINTS,EXCHANGE_CENTER]]:
		var poly := polygon(item[0])
		for i in poly.size(): poly[i]+=Vector2(item[1].x,item[1].z)
		result.append(poly)
	return result

static func polygon(points: Array) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for p: Array in points: poly.append(Vector2(p[0],p[1]))
	return poly

static func _scaled(poly: PackedVector2Array, factor: float) -> PackedVector2Array:
	var result := poly.duplicate()
	for i in result.size(): result[i]*=factor
	return result

static func build(world: Node3D) -> void:
	_materials(world)
	_tower_one(world)
	_bank_of_china(world)
	_ribbon(world)
	_exchange(world)
	world.set_meta("city_landmarks",metadata())

static func _materials(world: Node3D) -> void:
	world._mat("city_landmark_metal",Color("b2b8b6"),0.38,0.52)
	world._mat("city_landmark_red",Color("a54e3d"),0.5,0.32)
	world._mat("city_landmark_gold",Color("b8a071"),0.38,0.6)
	world._mat("city_landmark_stone",Color("bcb8ac"),0.83)
	world._mat("city_landmark_dark",Color("293739"),0.52,0.28)
	world._mat("city_landmark_roof",Color("697675"),0.85)
	world._mat("city_exchange_wood",Color("c8bd9f"),0.88)
	world._mat("city_exchange_wood_light",Color("ded3b9"),0.89)
	_glazing(world,"city_tower_glass",Color("456474"),Color("a1aaa7"),Vector2(1.38,202.0/49.0),Vector2(0.052,0.095),15.0)
	_glazing(world,"city_boc_glass",Color("526267"),Color("bdb8ac"),Vector2(3.05,3.6),Vector2(0.37,0.56),5.4)
	_glazing(world,"city_lobby_glass",Color("3a555d"),Color("a6acaa"),Vector2(2.25,5.4),Vector2(0.06,0.13))
	_glazing(world,"city_ribbon_glass",Color("536f7a"),Color("9bacae"),Vector2(1.9,76.0/25.0),Vector2(0.047,0.078),14.0)
	_glazing(world,"city_exchange_glass",Color("526a6a"),Color("aaa9a0"),Vector2(1.8,4.45),Vector2(0.05,0.08))

static func _glazing(world: Node3D, key: String, glass: Color, frame_color: Color, bay: Vector2, frame: Vector2, base_height: float = 0.0) -> void:
	var shader := Shader.new()
	shader.code = GLAZING_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("glass_color",glass)
	material.set_shader_parameter("frame_color",frame_color)
	material.set_shader_parameter("bay",bay)
	material.set_shader_parameter("frame",frame)
	material.set_shader_parameter("base_height",base_height)
	world.materials[key] = material

static func _tower_one(world: Node3D) -> void:
	var outline := polygon(TOWER_POINTS)
	var podium_outline := polygon(TOWER_PODIUM_POINTS)
	for floor_index in range(3):
		var low := float(floor_index)*5.0
		var podium: StaticBody3D = world._structure_mesh("city/tower_one/podium/%02d"%floor_index,prism(podium_outline,low,low+5.0),TOWER_PODIUM_CENTER,"city_lobby_glass",220000.0)
		_detail(world,podium,prism(_scaled(podium_outline,1.001),low+4.56,low+5.0),"city_landmark_metal")
	var floor_height := (TOWER_HEIGHT-15.0)/49.0
	for floor_index in range(49):
		var low := 15.0+float(floor_index)*floor_height
		var high := low+floor_height
		var village := floor_index in [15,16,31,32]
		var floor_outline := _scaled(outline,0.956) if village else outline
		var body: StaticBody3D = world._structure_mesh("city/tower_one/floor/%02d"%floor_index,prism(floor_outline,low,high),TOWER_CENTER,"city_landmark_dark" if village else "city_tower_glass",185000.0)
		_detail(world,body,prism(_scaled(outline,1.002),low,low+0.19),"city_landmark_metal")
		var fins := SurfaceTool.new()
		fins.begin(Mesh.PRIMITIVE_TRIANGLES)
		var silver := SurfaceTool.new()
		silver.begin(Mesh.PRIMITIVE_TRIANGLES)
		for frame in _perimeter_samples(outline,2.7):
			var p: Vector3 = frame.position
			var outward: Vector3 = frame.outward
			# Real tower's warm coloured sunshades run the glazed perimeter.
			# The north core is solid service architecture, with no false logos.
			var core_side := p.z < -13 and p.x > -13
			if village:
				_append_box(silver,Vector3(p.x,low+floor_height*0.5,p.z),Vector3(0.30,floor_height,0.30),frame.basis)
			elif not core_side:
				_append_box(fins,Vector3(p.x,low+floor_height*0.5,p.z)+outward*0.29,Vector3(0.12,floor_height-0.3,0.67),frame.basis)
			else:
				_append_box(silver,Vector3(p.x,low+floor_height*0.5,p.z)+outward*0.12,Vector3(0.38,floor_height-0.2,0.25),frame.basis)
		_commit_detail(world,body,fins,"city_landmark_red")
		_commit_detail(world,body,silver,"city_landmark_metal")
	# The roof plant remains inside the surveyed main footprint and height.
	var roof: StaticBody3D = world.structures["city/tower_one/floor/48"].node
	_detail(world,roof,prism(_scaled(outline,0.92),TOWER_HEIGHT-0.13,TOWER_HEIGHT),"city_landmark_roof")

static func boc_outline() -> PackedVector2Array:
	var source := polygon(BOC_POINTS)
	var result := PackedVector2Array()
	var a := source[0]
	var b := source[1]
	var outward := Vector2(-0.9957,0.0923)
	# The outward middle bay is visible in the real Sussex Street photo.
	# OSM's coarser outline has no such articulation; its depth is estimated.
	for i in range(25):
		var t := float(i)/24.0
		var bay_weight := pow(maxf(0.0,1.0-absf(t-0.5)/0.19),0.65)
		result.append(a.lerp(b,t)+outward*1.05*bay_weight)
	for i in range(2,source.size()): result.append(source[i])
	return result

static func _bank_of_china(world: Node3D) -> void:
	var outline := boc_outline()
	var lobby: StaticBody3D = world._structure_mesh("city/boc/lobby",prism(outline,0,5.4),BOC_CENTER,"city_lobby_glass",190000.0)
	var piers := SurfaceTool.new()
	piers.begin(Mesh.PRIMITIVE_TRIANGLES)
	for item in _perimeter_samples(polygon(BOC_POINTS),5.4):
		_append_box(piers,Vector3(item.position.x,2.7,item.position.z),Vector3(0.50,5.4,0.64),item.basis)
	_commit_detail(world,lobby,piers,"city_landmark_stone")
	for floor_index in range(14):
		var low := 5.4+float(floor_index)*3.6
		var body: StaticBody3D = world._structure_mesh("city/boc/floor/%02d"%floor_index,prism(outline,low,low+3.6),BOC_CENTER,"city_boc_glass",155000.0)
		_detail(world,body,prism(_scaled(outline,1.005),low,low+0.44),"city_landmark_stone")
		var pilasters := SurfaceTool.new()
		pilasters.begin(Mesh.PRIMITIVE_TRIANGLES)
		var front_a := Vector2(BOC_POINTS[0][0],BOC_POINTS[0][1])
		var front_b := Vector2(BOC_POINTS[1][0],BOC_POINTS[1][1])
		for t in [0.0,0.245,0.755,1.0]:
			var p := front_a.lerp(front_b,t)
			_append_box(pilasters,Vector3(p.x-0.14,low+1.8,p.y),Vector3(0.58,3.6,0.52),Basis(Vector3.UP,deg_to_rad(-5.3)))
		_commit_detail(world,body,pilasters,"city_landmark_stone")
	var roof: StaticBody3D = world._structure_mesh("city/boc/roof_terrace",prism(outline,55.8,56.1),BOC_CENTER,"city_landmark_stone",130000.0)
	var details := SurfaceTool.new()
	details.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Refurbishment engineers document rooftop pergolas, but not their layout.
	# These small additions express that use without asserting an as-built plan.
	_append_box(details,Vector3(4,57.0,-10),Vector3(10,2.0,9),Basis.IDENTITY)
	for x in [-7.0,4.0]:
		for z in [5.0,16.0]: _append_box(details,Vector3(x,56.9,z),Vector3(0.18,1.6,0.18),Basis.IDENTITY)
	for z in range(5,17,2): _append_box(details,Vector3(-1.5,57.85,float(z)),Vector3(11.3,0.17,0.22),Basis.IDENTITY)
	_commit_detail(world,roof,details,"city_landmark_metal")
	var ledges := SurfaceTool.new()
	ledges.begin(Mesh.PRIMITIVE_TRIANGLES)
	for item in _perimeter_samples(outline,2.6):
		_append_box(ledges,Vector3(item.position.x,56.62,item.position.z),Vector3(2.65,1.04,0.17),item.basis)
	_commit_detail(world,roof,ledges,"city_landmark_stone")

static func ribbon_profile() -> PackedVector2Array:
	var result := PackedVector2Array([Vector2(-57,14)])
	_curve(result,Vector2(-57,14),Vector2(-67,14),Vector2(-68,20),Vector2(-63,28),12)
	_curve(result,Vector2(-63,28),Vector2(-44,67),Vector2(3,90),Vector2(39,90),42)
	_curve(result,Vector2(39,90),Vector2(62,90),Vector2(70,80),Vector2(65,60),20)
	_curve(result,Vector2(65,60),Vector2(61,44),Vector2(55,24),Vector2(48,14),18)
	# Include the exact architectural apex at a horizontal tangent.
	return result

static func _curve(points: PackedVector2Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2, steps: int) -> void:
	for i in range(1,steps+1):
		var t := float(i)/float(steps)
		points.append(a*pow(1.0-t,3)+b*3.0*t*pow(1.0-t,2)+c*3.0*t*t*(1.0-t)+d*t*t*t)

static func _ribbon(world: Node3D) -> void:
	var basis := Basis(Vector3.UP,deg_to_rad(RIBBON_ANGLE))
	var footprint := polygon(RIBBON_POINTS)
	for level in range(3):
		var low := float(level)*14.0/3.0
		var podium: StaticBody3D = world._structure_mesh("city/ribbon/podium/%02d"%level,prism(footprint,low,low+14.0/3.0),RIBBON_CENTER,"city_landmark_dark" if level==0 else "city_lobby_glass",220000.0)
		_detail(world,podium,prism(_scaled(footprint,1.001),low+4.30,low+14.0/3.0),"city_landmark_metal")
	var profile := ribbon_profile()
	var floor_height := 76.0/25.0
	for floor_index in range(25):
		var low := 14.0+float(floor_index)*floor_height
		var high := low+floor_height
		var clip := PackedVector2Array([Vector2(-100,low),Vector2(100,low),Vector2(100,high),Vector2(-100,high)])
		var pieces := Geometry2D.intersect_polygons(profile,clip)
		if pieces.is_empty(): continue
		var body: StaticBody3D = world._structure_mesh("city/ribbon/floor/%02d"%floor_index,profile_solid(pieces[0],20.0),RIBBON_CENTER,"city_ribbon_glass",175000.0,basis)
		var frame := SurfaceTool.new()
		frame.begin(Mesh.PRIMITIVE_TRIANGLES)
		var roof_panels := SurfaceTool.new()
		roof_panels.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Warm metal follows the real continuous outline, never outlining the
		# horizontal damage slices; each visible piece disappears with its body.
		for i in range(profile.size()):
			var a := profile[i]
			var b := profile[(i+1)%profile.size()]
			var segment := _clip_line_y(a,b,low,high)
			if segment.size()!=2: continue
			for z in [-20.1,20.1]:
				_append_beam(frame,Vector3(segment[0].x,segment[0].y,z),Vector3(segment[1].x,segment[1].y,z),0.92,0.47)
			var normal := Vector3(b.y-a.y,a.x-b.x,0).normalized()*_area_sign(profile)
			if normal.y>0.70 and (a.x+b.x)*0.5>-35.0 and (a.x+b.x)*0.5<51.0:
				var p := Vector3(segment[0].x,segment[0].y,-7.5)+normal*0.06
				var q := Vector3(segment[1].x,segment[1].y,-7.5)+normal*0.06
				var r := Vector3(segment[1].x,segment[1].y,7.5)+normal*0.06
				var s := Vector3(segment[0].x,segment[0].y,7.5)+normal*0.06
				_triangle(roof_panels,p,q,r,normal,Vector2.ZERO,Vector2(0,1),Vector2.ONE)
				_triangle(roof_panels,p,r,s,normal,Vector2.ZERO,Vector2.ONE,Vector2(1,0))
				for z in [-7.6,7.6]:
					_append_beam(frame,Vector3(segment[0].x,segment[0].y,z)+normal*0.15,Vector3(segment[1].x,segment[1].y,z)+normal*0.15,0.23,0.23)
		_commit_detail(world,body,frame,"city_landmark_gold")
		_commit_detail(world,body,roof_panels,"city_landmark_roof")
	# Small rooftop pool volume exists in the hotel description. The publicly
	# visible curved silhouette stays the architectural envelope; no guessed
	# branded signs or interior storefronts are attached to it.

static func _clip_line_y(a: Vector2, b: Vector2, low: float, high: float) -> PackedVector2Array:
	if maxf(a.y,b.y)<low or minf(a.y,b.y)>high: return PackedVector2Array()
	if is_equal_approx(a.y,b.y):
		if a.distance_to(b)<0.001: return PackedVector2Array()
		return PackedVector2Array([a,b])
	var t0 := clampf((low-a.y)/(b.y-a.y),0,1)
	var t1 := clampf((high-a.y)/(b.y-a.y),0,1)
	var p := a.lerp(b,minf(t0,t1))
	var q := a.lerp(b,maxf(t0,t1))
	if p.distance_to(q)<0.001: return PackedVector2Array()
	return PackedVector2Array([p,q])

static func _exchange(world: Node3D) -> void:
	for floor_index in range(7):
		var low: float = EXCHANGE_LEVELS[floor_index]
		var high: float = EXCHANGE_LEVELS[floor_index+1]
		var radius: float = EXCHANGE_RADII[floor_index]
		var offset := Vector2(EXCHANGE_OFFSETS[floor_index][0],EXCHANGE_OFFSETS[floor_index][1])
		var outline := PackedVector2Array()
		var terrace := PackedVector2Array()
		for i in range(96):
			var theta := float(i)*TAU/96.0
			outline.append(offset+Vector2(cos(theta),sin(theta))*radius)
			terrace.append(offset+Vector2(cos(theta),sin(theta))*(radius+0.85))
		var body: StaticBody3D = world._structure_mesh("city/exchange/floor/%02d"%floor_index,prism(outline,low,high),EXCHANGE_CENTER,"city_exchange_glass",165000.0)
		_detail(world,body,prism(terrace,high-0.23,high),"city_landmark_stone")
		var timber := SurfaceTool.new()
		timber.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pale_timber := SurfaceTool.new()
		pale_timber.begin(Mesh.PRIMITIVE_TRIANGLES)
		var supports := SurfaceTool.new()
		supports.begin(Mesh.PRIMITIVE_TRIANGLES)
		var start_y := maxf(2.7,low+0.18)
		var batten_count := maxi(1,int((high-start_y)/0.18))
		for band in range(batten_count):
			var y := start_y+(float(band)+0.5)*(high-start_y)/float(batten_count)
			var phase := float(band)*0.73+floor_index*1.44
			var amplitude := minf(0.30,minf(y-low,high-y)*0.68)
			var points: Array[Vector3] = []
			for i in range(97):
				var angle := float(i)*TAU/96.0
				var r := radius+0.83+0.24*sin(angle*3.0+phase)
				var h := y+amplitude*sin(angle*2.0+phase)+amplitude*0.13*sin(angle*5.0-phase)
				points.append(Vector3(offset.x+cos(angle)*r,h,offset.y+sin(angle)*r))
			_timber_strip(timber if band%3==0 else pale_timber,points,0.105+0.035*sin(phase),0.14)
		for i in range(36):
			var theta := float(i)*TAU/36.0
			var r := radius+0.73
			_append_box(supports,Vector3(offset.x+cos(theta)*r,(low+high)*0.5,offset.y+sin(theta)*r),Vector3(0.08,high-low,0.08),Basis.IDENTITY)
		_commit_detail(world,body,timber,"city_exchange_wood")
		_commit_detail(world,body,pale_timber,"city_exchange_wood_light")
		_commit_detail(world,body,supports,"city_landmark_dark")

static func _timber_strip(surface: SurfaceTool, points: Array[Vector3], height: float, depth: float) -> void:
	for i in range(points.size()-1):
		var a := points[i]
		var b := points[i+1]
		var side := Vector3(b.z-a.z,0,a.x-b.x).normalized()*depth*0.5
		var up := Vector3.UP*height*0.5
		var corners: Array[Vector3] = [a-side-up,a+side-up,a+side+up,a-side+up,b-side-up,b+side-up,b+side+up,b-side+up]
		for face: Array in [[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
			var p := corners[face[0]]
			var q := corners[face[1]]
			var r := corners[face[2]]
			var s := corners[face[3]]
			var normal := ((p+q+r+s)*0.25-(a+b)*0.5).normalized()
			_triangle(surface,p,q,r,normal,Vector2.ZERO,Vector2(1,0),Vector2.ONE)
			_triangle(surface,p,r,s,normal,Vector2.ZERO,Vector2.ONE,Vector2(0,1))

static func _perimeter_samples(poly: PackedVector2Array, spacing: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var sign_area := _area_sign(poly)
	var distance := 0.0
	var next_sample := spacing*0.5
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i+1)%poly.size()]
		var length := a.distance_to(b)
		var outward := Vector3(b.y-a.y,0,a.x-b.x).normalized()*sign_area
		while next_sample<distance+length:
			var p := a.lerp(b,(next_sample-distance)/length)
			result.append({"position":Vector3(p.x,0,p.y),"outward":outward,"basis":Basis.looking_at(-outward,Vector3.UP)})
			next_sample+=spacing
		distance+=length
	return result

static func _area_sign(poly: PackedVector2Array) -> float:
	var twice_area := 0.0
	for i in poly.size(): twice_area+=poly[i].cross(poly[(i+1)%poly.size()])
	return signf(twice_area)

static func prism(poly: PackedVector2Array, low: float, high: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := Geometry2D.triangulate_polygon(poly)
	for i in range(0,triangles.size(),3):
		for y in [low,high]:
			var points: Array[Vector3] = []
			for j in range(3):
				var p := poly[triangles[i+j]]
				points.append(Vector3(p.x,y,p.y))
			_triangle(surface,points[0],points[1],points[2],Vector3.DOWN if y==low else Vector3.UP,Vector2(points[0].x,points[0].z),Vector2(points[1].x,points[1].z),Vector2(points[2].x,points[2].z))
	var offset := 0.0
	var sign_area := _area_sign(poly)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i+1)%poly.size()]
		var length := a.distance_to(b)
		var normal := Vector3(b.y-a.y,0,a.x-b.x).normalized()*sign_area
		var p := Vector3(a.x,low,a.y)
		var q := Vector3(b.x,low,b.y)
		var r := Vector3(b.x,high,b.y)
		var s := Vector3(a.x,high,a.y)
		_triangle(surface,p,q,r,normal,Vector2(offset,low),Vector2(offset+length,low),Vector2(offset+length,high))
		_triangle(surface,p,r,s,normal,Vector2(offset,low),Vector2(offset+length,high),Vector2(offset,high))
		offset+=length
	return surface.commit()

static func profile_solid(poly: PackedVector2Array, half_depth: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := Geometry2D.triangulate_polygon(poly)
	for z in [-half_depth,half_depth]:
		for i in range(0,triangles.size(),3):
			var a := poly[triangles[i]]
			var b := poly[triangles[i+1]]
			var c := poly[triangles[i+2]]
			_triangle(surface,Vector3(a.x,a.y,z),Vector3(b.x,b.y,z),Vector3(c.x,c.y,z),Vector3.BACK if z>0 else Vector3.FORWARD,a,b,c)
	var sign_area := _area_sign(poly)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i+1)%poly.size()]
		var normal := Vector3(b.y-a.y,a.x-b.x,0).normalized()*sign_area
		var p := Vector3(a.x,a.y,-half_depth)
		var q := Vector3(b.x,b.y,-half_depth)
		var r := Vector3(b.x,b.y,half_depth)
		var s := Vector3(a.x,a.y,half_depth)
		_triangle(surface,p,q,r,normal,Vector2(-half_depth,a.y),Vector2(-half_depth,b.y),Vector2(half_depth,b.y))
		_triangle(surface,p,r,s,normal,Vector2(-half_depth,a.y),Vector2(half_depth,b.y),Vector2(half_depth,a.y))
	return surface.commit()

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	if (b-a).cross(c-a).length_squared()<0.0000000001: return
	# Godot front faces are clockwise when seen from outside.
	if (b-a).cross(c-a).dot(normal)>0:
		var point_swap := b; b=c; c=point_swap
		var uv_swap := ub; ub=uc; uc=uv_swap
	surface.set_normal(normal)
	surface.set_uv(ua); surface.add_vertex(a)
	surface.set_uv(ub); surface.add_vertex(b)
	surface.set_uv(uc); surface.add_vertex(c)

static func _append_box(surface: SurfaceTool, position: Vector3, size: Vector3, basis: Basis) -> void:
	var box := BoxMesh.new()
	box.size=size
	surface.append_from(box,0,Transform3D(basis,position))

static func _append_beam(surface: SurfaceTool, a: Vector3, b: Vector3, width: float, depth: float) -> void:
	var delta := b-a
	if delta.length()<0.001: return
	var basis := Basis.looking_at(delta.normalized(),Vector3.FORWARD)
	_append_box(surface,(a+b)*0.5,Vector3(width,depth,delta.length()+0.03),basis)

static func _commit_detail(world: Node3D, body: StaticBody3D, surface: SurfaceTool, key: String) -> void:
	var mesh := surface.commit()
	if mesh!=null and mesh.get_surface_count()>0: _detail(world,body,mesh,key)

static func _detail(world: Node3D, body: StaticBody3D, mesh: ArrayMesh, key: String) -> void:
	var view := MeshInstance3D.new()
	view.mesh=mesh
	view.material_override=world.materials[key]
	body.add_child(view)
