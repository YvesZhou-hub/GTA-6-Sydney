extends RefCounted
## Original photo-based exterior reconstructions; footprint and uncertainty notes in docs/CYBER_REFERENCE.md.
const Geo=preload("res://scripts/city_landmarks.gd")
const MARKET_OUTLINE := [[-610.9488,1150.53673],[-602.48496,1149.70183],[-583.8756,1148.05429],[-583.57068,1151.41616],[-579.68064,1151.07106],[-579.40344,1154.25482],[-576.1602,1153.96538],[-575.5134,1161.23458],[-565.04448,1160.29949],[-564.73032,1163.82834],[-560.9142,1163.48324],[-560.60004,1167.02322],[-557.09808,1166.71152],[-557.56932,1162.2142],[-552.9678,1161.79118],[-553.95648,1150.62578],[-537.13968,1149.1341],[-532.18704,1205.02787],[-549.02232,1206.36371],[-585.74208,1209.81463],[-585.92688,1206.48616],[-598.81668,1206.60861],[-600.56304,1206.24126],[-602.42028,1205.48428],[-603.86172,1204.38221],[-605.15532,1202.83486],[-606.08856,1201.44336],[-606.54132,1199.473],[-607.18812,1186.55988],[-606.62448,1186.49309],[-609.18396,1157.56102],[-609.27636,1156.39216],[-610.59768,1156.42556]]
const MARKET_TOWER := [[-609.18396,1157.56102],[-605.39556,1157.22706],[-605.70972,1153.64256],[-602.1708,1153.33086],[-602.48496,1149.70183],[-583.8756,1148.05429],[-583.57068,1151.41616],[-579.68064,1151.07106],[-579.40344,1154.25482],[-576.1602,1153.96538],[-575.5134,1161.23458],[-565.04448,1160.29949],[-564.73032,1163.82834],[-560.9142,1163.48324],[-560.60004,1167.02322],[-557.09808,1166.71152],[-554.77884,1192.60456],[-554.4462,1196.35604],[-557.85576,1196.6566],[-557.5416,1200.09639],[-561.45012,1200.45262],[-561.1452,1203.91467],[-578.9322,1205.49541],[-579.23712,1202.12242],[-582.88692,1202.44524],[-583.21032,1198.79395],[-587.44224,1199.17244],[-588.04284,1192.39305],[-598.71504,1193.33927],[-599.06616,1189.39854],[-602.80836,1189.7325],[-603.11328,1186.18139],[-606.62448,1186.49309]]
const MARKET_FORECOURT := [[-553.95648,1150.62578],[-537.13968,1149.1341],[-532.18704,1205.02787],[-549.01308,1206.51956],[-549.02232,1206.36371],[-550.27896,1192.19267],[-552.9678,1161.79118]]
const MARKET_LINK := [[-557.56932,1162.2142],[-557.09808,1166.71152],[-554.77884,1192.60456],[-550.27896,1192.19267],[-552.9678,1161.79118]]
const GEORGE_OUTLINE := [[-312.05328,921.10621],[-313.929,920.8613],[-316.31292,953.41127],[-315.81396,955.53748],[-314.33556,957.30747],[-312.312,958.69897],[-310.99992,959.19991],[-288.4266,961.91612],[-278.53056,959.0552],[-278.62296,962.76215],[-266.8512,964.26497],[-264.4488,939.05099],[-259.3206,933.40707],[-258.26724,923.93374],[-257.01984,912.74608],[-281.30256,910.05213],[-285.73776,909.55119],[-310.85208,905.37669]]
const GEORGE_TOWER := [[-308.58828,906.03348],[-309.57696,916.57548],[-310.7874,917.18774],[-311.33256,918.61264],[-311.4804,921.56262],[-310.7412,922.72035],[-308.64372,922.86506],[-308.5236,923.63317],[-282.87336,954.43542],[-282.80868,956.08295],[-281.83848,957.40766],[-278.27184,957.67483],[-277.32936,957.15162],[-276.42384,955.86031],[-268.86552,956.60616],[-266.14896,927.47371],[-263.2938,924.69071],[-261.3072,921.70734],[-259.23744,921.21753],[-257.6574,920.47168],[-256.57632,919.2583],[-255.80016,918.23415],[-255.17184,916.6868],[-255.07944,915.38436],[-255.486,913.71456],[-256.41924,912.234],[-257.6574,911.36571],[-259.39452,910.48628],[-261.17784,910.54194],[-262.96116,911.14307],[-264.6798,909.58459],[-267.38712,908.27101],[-269.42916,907.70328],[-272.36748,907.66988],[-274.37256,908.21535],[-276.045,909.16157],[-277.97616,910.48628],[-279.62088,908.62724]]
const MARKET_HEIGHT:=83.0
const GEORGE_HEIGHT:=131.0
const MARKET_CENTER:=Vector3(-579.0,4.5,1177.0)
const GEORGE_CENTER:=Vector3(-282.0,4.5,931.0)
const FRONT_A:=Vector3(-308.5236,0,923.6333)
const FRONT_B:=Vector3(-282.87336,0,954.43512)
const PAVILION_BASE:=[[ -313.10,926.50],[-315.35,950.70],[-315.40,952.50],[-314.80,954.50],[-313.20,956.10],[-310.80,957.40],[-289.50,960.00],[-289.00,958.30],[-300.30,944.50],[-309.20,934.00]]

static func metadata() -> Array[Dictionary]:
	return [
		{"id":"cybercx_sydney","name":"CyberCX · Sydney office","address":"Level 23, 2 Market Street, Sydney NSW 2000","center":MARKET_CENTER,"arrival":Vector3(-579,4.5,1214),"lat":-33.8705731225,"lon":151.2042337662,"height_m":83.0,"height_confidence":"CVU/CTBUH architectural height; individual roof steps and adjoining 7-level forecourt height estimated from official photographs","osm_ids":[1521293802,335699164,335699165,1521293801],"source":"https://cybercx.com.au/contact-us/","scope":"building exterior; CyberCX NSW office, not its Melbourne headquarters"},
		{"id":"cloudflare_sydney","name":"Cloudflare · Sydney office","address":"388 George Street, Sydney NSW 2000","center":GEORGE_CENTER,"arrival":Vector3(-316.5,4.5,924.0),"lat":-33.8683632770,"lon":151.2074480520,"height_m":131.0,"height_confidence":"CVU/CTBUH architectural height; curved 5-storey pavilion is a photo-based reconstruction within the mapped parent footprint","osm_ids":[386563854,386563852],"source":"https://www.cloudflare.com/en-ca/about-overview/","scope":"building exterior and public arcade; no private office interiors or invented company facade logos"}
	]

static func excluded_way_ids() -> Array[int]:
	return [1521293802,335699164,335699165,1521293801,386563854,386563852]

static func footprints() -> Array[PackedVector2Array]:
	return [Geo.polygon(MARKET_OUTLINE),Geo.polygon(MARKET_TOWER),Geo.polygon(MARKET_FORECOURT),Geo.polygon(MARKET_LINK),Geo.polygon(GEORGE_OUTLINE),Geo.polygon(GEORGE_TOWER)]

static func build(world: Node3D) -> void:
	_materials(world)
	_market(world)
	_george(world)
	# Site paving is a visual finish above the city's shared continuous ground
	# collider. It does not add coplanar collision seams to the public arcade.
	for item: Array in [["cyber/market/tower/00",MARKET_OUTLINE,MARKET_CENTER],["cyber/george/tower/00",GEORGE_OUTLINE,GEORGE_CENTER]]:
		Geo._detail(world,world.structures[item[0]].node,Geo.prism(_relative(Geo.polygon(item[1]),item[2]),0.005,0.025),"paving")
	world.set_meta("cyber_landmarks",metadata())

static func _materials(world: Node3D) -> void:
	for row: Array in [["cyber_silver","a5b3b7",0.48,0.58],["cyber_stone","c7c5b5",0.9,0.02],["cyber_dark","233238",0.52,0.32],["cyber_bronze","837058",0.45,0.52],["cyber_timber","b89967",0.78,0.02],["cyber_warm","d4c29b",0.82,0.0]]:
		world._mat(row[0],Color(row[1]),row[2],row[3])
	_shader(world,"cyber_market_glass",Color("203b54"),Color("9dacb0"),Vector2(1.6,83.0/21.0),Vector2(0.032,0.48))
	_shader(world,"cyber_market_darkglass",Color("142d45"),Color("43576a"),Vector2(1.6,83.0/21.0),Vector2(0.019,0.025))
	_shader(world,"cyber_forecourt_glass",Color("3e5a67"),Color("93a0a1"),Vector2(1.7,4.15),Vector2(0.035,0.19))
	_shader(world,"cyber_george_glass",Color("3b656d"),Color("a5b1b0"),Vector2(1.6,4.0),Vector2(0.052,0.12))
	_shader(world,"cyber_pavilion_glass",Color("3b5255"),Color("9b8f73"),Vector2(1.65,4.1),Vector2(0.038,0.06))
	var glass: StandardMaterial3D=world._mat("cyber_clear",Color(0.43,0.66,0.69,0.22),0.16,0.17)
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	var ceiling: StandardMaterial3D=world._mat("cyber_ceiling",Color("e0d9bd"),0.64)
	ceiling.emission_enabled=true;ceiling.emission=Color("b9a87b");ceiling.emission_energy_multiplier=0.32

static func _shader(world: Node3D,key: String,color: Color,frame: Color,bay: Vector2,width: Vector2) -> void:
	var shader:=Shader.new();shader.code=Geo.GLAZING_SHADER
	var mat:=ShaderMaterial.new();mat.shader=shader
	mat.set_shader_parameter("glass_color",color);mat.set_shader_parameter("frame_color",frame)
	mat.set_shader_parameter("bay",bay);mat.set_shader_parameter("frame",width)
	world.materials[key]=mat

static func _relative(points: PackedVector2Array,center: Vector3) -> PackedVector2Array:
	var result:=points.duplicate()
	for i in result.size():result[i]-=Vector2(center.x,center.z)
	return result

static func _solid(world: Node3D,id: String,poly: PackedVector2Array,low: float,high: float,center: Vector3,key: String) -> StaticBody3D:
	return world._structure_mesh(id,Geo.prism(_relative(poly,center),low,high),center,key,200000)

static func _surface() -> SurfaceTool:
	var s:=SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES);return s

# Build repeated facade trim directly on CPU; never instantiate and read back a
# temporary GPU BoxMesh for every small mullion.
static func _box(s: SurfaceTool, p: Vector3, size: Vector3, basis: Basis=Basis.IDENTITY) -> void:
	var h:=size*0.5
	for face: Array in [[Vector3.RIGHT,Vector3.BACK,Vector3.UP,h.x,h.z,h.y],[Vector3.LEFT,Vector3.FORWARD,Vector3.UP,h.x,h.z,h.y],[Vector3.UP,Vector3.RIGHT,Vector3.BACK,h.y,h.x,h.z],[Vector3.DOWN,Vector3.LEFT,Vector3.BACK,h.y,h.x,h.z],[Vector3.BACK,Vector3.LEFT,Vector3.UP,h.z,h.x,h.y],[Vector3.FORWARD,Vector3.RIGHT,Vector3.UP,h.z,h.x,h.y]]:
		var n: Vector3=basis*face[0];var u: Vector3=basis*face[1]*face[4];var v: Vector3=basis*face[2]*face[5];var c: Vector3=p+n*face[3]
		Geo._triangle(s,c-u-v,c+u-v,c+u+v,n,Vector2.ZERO,Vector2(1,0),Vector2.ONE)
		Geo._triangle(s,c-u-v,c+u+v,c-u+v,n,Vector2.ZERO,Vector2.ONE,Vector2(0,1))

static func _beam(s: SurfaceTool,a: Vector3,b: Vector3,width: float,depth: float) -> void:
	var z: Vector3=(b-a).normalized()
	var up:=Vector3.UP if absf(z.y)<0.95 else Vector3.RIGHT
	_box(s,(a+b)*0.5,Vector3(width,depth,a.distance_to(b)),Basis.looking_at(z,up))

static func _cylinder(s: SurfaceTool,p: Vector3,radius: float,height: float) -> void:
	for i in range(20):
		var t0:=TAU*i/20.0;var t1:=TAU*(i+1)/20.0
		var a:=p+Vector3(cos(t0)*radius,-height*0.5,sin(t0)*radius)
		var b:=p+Vector3(cos(t1)*radius,-height*0.5,sin(t1)*radius)
		var c:=b+Vector3.UP*height;var d:=a+Vector3.UP*height
		var normal:=Vector3(cos((t0+t1)*0.5),0,sin((t0+t1)*0.5))
		Geo._triangle(s,a,b,c,normal,Vector2(0,0),Vector2(1,0),Vector2(1,height))
		Geo._triangle(s,a,c,d,normal,Vector2(0,0),Vector2(1,height),Vector2(0,height))
		Geo._triangle(s,p-Vector3.UP*height*0.5,b,a,Vector3.DOWN,Vector2.ZERO,Vector2.ONE,Vector2.RIGHT)
		Geo._triangle(s,p+Vector3.UP*height*0.5,d,c,Vector3.UP,Vector2.ZERO,Vector2.RIGHT,Vector2.ONE)

static func _clip_x(poly: PackedVector2Array,limit: float) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for i in poly.size():
		var a:=poly[i];var b:=poly[(i+1)%poly.size()]
		if a.x<=limit:result.append(a)
		if (a.x<=limit)!=(b.x<=limit):result.append(a.lerp(b,(limit-a.x)/(b.x-a.x)))
	return result

static func _market(world: Node3D) -> void:
	var tower:=Geo.polygon(MARKET_TOWER)
	var floor_height:=MARKET_HEIGHT/21.0
	for level in range(21):
		var low:=level*floor_height;var high:=low+floor_height
		var poly:=_clip_x(tower,-550.0 if level<17 else (-565.0 if level<19 else -578.0))
		var body:=_solid(world,"cyber/market/tower/%02d"%level,poly,low,high,MARKET_CENTER,"cyber_market_glass")
		var pillars:=_surface();var strips:=_surface()
		for i in poly.size():
			var a:=poly[i];var b:=poly[(i+1)%poly.size()];var length:=a.distance_to(b)
			if length<16.0:continue
			var normal:=Vector3(b.y-a.y,0,a.x-b.x).normalized()*Geo._area_sign(poly)
			var x: Vector3=Vector3(b.x-a.x,0,b.y-a.y).normalized()
			var center:=Vector3((a.x+b.x)*0.5-MARKET_CENTER.x,(low+high)*0.5,(a.y+b.y)*0.5-MARKET_CENTER.z)+normal*0.035
			_box(strips,center,Vector3(length*0.54,high-low,0.045),Basis(x,Vector3.UP,x.cross(Vector3.UP)))
			for sign_value in [-1,1]:_cylinder(pillars,center+x*sign_value*length*0.28,0.47,high-low)
		Geo._commit_detail(world,body,strips,"cyber_market_darkglass")
		Geo._commit_detail(world,body,pillars,"cyber_silver")
	var forecourt:=Geo.polygon(MARKET_FORECOURT)
	for level in range(7):
		var body:=_solid(world,"cyber/market/forecourt/%02d"%level,forecourt,level*4.15,(level+1)*4.15,MARKET_CENTER,"cyber_forecourt_glass")
		var trim:=_surface()
		for point: Vector2 in forecourt:
			_box(trim,Vector3(point.x-MARKET_CENTER.x,level*4.15+2.075,point.y-MARKET_CENTER.z),Vector3(0.42,4.15,0.42))
		Geo._commit_detail(world,body,trim,"cyber_silver")
	var roof: StaticBody3D=_solid(world,"cyber/market/forecourt/roof",forecourt,29.05,29.5,MARKET_CENTER,"cyber_silver")
	var roof_fins:=_surface()
	for p: Vector2 in [forecourt[0],forecourt[1],forecourt[2],forecourt[3]]:
		_box(roof_fins,Vector3(p.x-MARKET_CENTER.x,31.0,p.y-MARKET_CENTER.z),Vector3(0.55,3.0,0.55))
	Geo._commit_detail(world,roof,roof_fins,"cyber_silver")
	_solid(world,"cyber/market/atrium_link",Geo.polygon(MARKET_LINK),0.0,27.0,MARKET_CENTER,"cyber_forecourt_glass")
	# Market Street entry portal, contained within the existing parent outline.
	var portal: StaticBody3D=world._structure_box("cyber/market/entry_canopy",Vector3(-575,9.0,1205.6),Vector3(18.8,0.35,3.7),"cyber_bronze",110000,Basis(Vector3.UP,-0.092))
	_label(portal,"2 MARKET STREET",Vector3(0,-0.65,1.90),0.012)

static func pavilion_polygon() -> PackedVector2Array:
	var poly:=Geo.polygon(PAVILION_BASE)
	# Two corner-cut passes produce the visibly curving concrete band profile.
	for iteration in range(2):
		var next:=PackedVector2Array()
		for i in poly.size():
			next.append(poly[i].lerp(poly[(i+1)%poly.size()],0.18))
			next.append(poly[i].lerp(poly[(i+1)%poly.size()],0.82))
		poly=next
	return poly

static func arcade_path() -> Array[Vector3]:
	var normal:=Vector3(-0.768419,0,0.639947)
	return [Vector3(-315.3,4.5,923.5),FRONT_A+normal*3.1+Vector3.UP*4.5,FRONT_B+normal*3.1+Vector3.UP*4.5,Vector3(-285.0,4.5,963.4)]

static func _george(world: Node3D) -> void:
	var tower:=Geo.polygon(GEORGE_TOWER)
	var direction: Vector3=(FRONT_B-FRONT_A).normalized()
	var normal:=Vector3(-direction.z,0,direction.x)
	var center: Vector3=(FRONT_A+FRONT_B)*0.5
	var cut:=PackedVector2Array()
	for q: Vector3 in [center-direction*13.2+normal*0.5,center+direction*13.2+normal*0.5,center+direction*13.2-normal*6.0,center-direction*13.2-normal*6.0]:cut.append(Vector2(q.x,q.z))
	var notched: PackedVector2Array=Geometry2D.clip_polygons(tower,cut)[0]
	for floor_index in range(32):
		var atrium:=floor_index>=4 and (floor_index-4)%6<4
		var low:=float(floor_index)*4.0;var high:=low+4.0
		var body:=_solid(world,"cyber/george/tower/%02d"%floor_index,notched if atrium else tower,low,high,GEORGE_CENTER,"cyber_george_glass")
		var stone:=_surface();var joints:=_surface()
		for endpoint: Vector3 in [FRONT_A,FRONT_B]:
			var p:=endpoint+normal*0.5-Vector3(GEORGE_CENTER.x,0,GEORGE_CENTER.z)+Vector3.UP*((low+high)*0.5)
			_cylinder(stone,p,1.55,4.0)
			_cylinder(joints,p+Vector3.UP*1.96,1.565,0.055)
			var pier_shape:=CylinderShape3D.new();pier_shape.radius=1.55;pier_shape.height=4.0
			var pier_collision:=CollisionShape3D.new();pier_collision.shape=pier_shape;pier_collision.position=p
			body.add_child(pier_collision)
		if floor_index in [14,15]:
			_box(stone,center+normal*0.08-GEORGE_CENTER+Vector3.UP*((low+high)*0.5+4.5),Vector3(FRONT_A.distance_to(FRONT_B),4.0,0.10),Basis(direction,Vector3.UP,normal))
		Geo._commit_detail(world,body,stone,"cyber_stone")
		Geo._commit_detail(world,body,joints,"cyber_dark")
		if atrium:
			var rails:=_surface()
			_beam(rails,FRONT_A-GEORGE_CENTER+Vector3.UP*(high+4.5),FRONT_B-GEORGE_CENTER+Vector3.UP*(high+4.5),0.13,0.14)
			Geo._commit_detail(world,body,rails,"cyber_silver")
	_solid(world,"cyber/george/roof",tower,128,131,GEORGE_CENTER,"cyber_stone")
	for group in range(5):
		var low:=16.0+group*24.0;var high:=low+16.0
		var face:=_surface();var glass_face:=_surface();var warm:=_surface()
		var a: Vector3=center-direction*13.0-GEORGE_CENTER+Vector3.UP*4.5
		var b: Vector3=center+direction*13.0-GEORGE_CENTER+Vector3.UP*4.5
		Geo._triangle(glass_face,a+Vector3.UP*low,b+Vector3.UP*low,b+Vector3.UP*high,normal,Vector2.ZERO,Vector2(26,0),Vector2(26,16))
		Geo._triangle(glass_face,a+Vector3.UP*low,b+Vector3.UP*high,a+Vector3.UP*high,normal,Vector2.ZERO,Vector2(26,16),Vector2(0,16))
		var body: StaticBody3D=world.structures["cyber/george/tower/%02d"%(4+group*6)].node
		for column in range(13):
			var p:=a.lerp(b,(column+0.5)/13.0)
			_beam(face,p+Vector3.UP*low,p+Vector3.UP*high,0.07,0.08)
		for row in range(1,4):_beam(face,a+Vector3.UP*(low+row*4.0),b+Vector3.UP*(low+row*4.0),0.08,0.08)
		# A recessed lit soffit gives each four-storey atrium physical depth.
		var ceiling: Vector3=center-normal*3.0-GEORGE_CENTER+Vector3.UP*(high+4.5-0.18)
		_box(warm,ceiling,Vector3(26,0.12,5.8),Basis(direction,Vector3.UP,direction.cross(Vector3.UP)))
		Geo._commit_detail(world,body,glass_face,"cyber_clear")
		Geo._commit_detail(world,body,face,"cyber_silver")
		Geo._commit_detail(world,body,warm,"cyber_ceiling")
	_pavilion(world,direction,normal)

static func _pavilion(world: Node3D,direction: Vector3,normal: Vector3) -> void:
	var poly:=pavilion_polygon()
	for floor_index in range(5):
		var low:=0.0 if floor_index==0 else 5.4+(floor_index-1)*4.1
		var high:=5.4+floor_index*4.1
		var body:=_solid(world,"cyber/george/pavilion/%02d"%floor_index,poly,low,high,GEORGE_CENTER,"cyber_pavilion_glass")
		var stone_outline: PackedVector2Array=Geometry2D.offset_polygon(poly,0.18)[0]
		Geo._detail(world,body,Geo.prism(_relative(stone_outline,GEORGE_CENTER),high-0.66,high),"cyber_stone")
		var mullions:=_surface();var louvres:=_surface()
		for sample: Dictionary in Geo._perimeter_samples(_relative(poly,GEORGE_CENTER),1.4):
			_box(mullions,sample.position+Vector3.UP*((low+high)*0.5),Vector3(0.11,high-low-0.55,0.17),sample.basis)
			for offset in [0.8,1.0,1.2]:
				_box(louvres,sample.position+sample.outward*0.22+Vector3.UP*(high-offset),Vector3(1.34,0.055,0.38),sample.basis)
		Geo._commit_detail(world,body,mullions,"cyber_bronze");Geo._commit_detail(world,body,louvres,"cyber_bronze")
	var roof: StaticBody3D=_solid(world,"cyber/george/pavilion/roof_terrace",poly,21.8,22.05,GEORGE_CENTER,"cyber_stone")
	var rail:=_surface()
	for sample: Dictionary in Geo._perimeter_samples(_relative(poly,GEORGE_CENTER),1.1):
		_box(rail,sample.position+Vector3.UP*22.62,Vector3(1.08,1.05,0.06),sample.basis)
	Geo._commit_detail(world,roof,rail,"cyber_clear")
	# A glass-and-timber arcade canopy bridges the preserved public passage;
	# every beam stays well above standing head height.
	var frame:=_surface();var timber:=_surface();var glass:=_surface()
	for bay in range(9):
		var a: Vector3=FRONT_A+direction*(2.0+bay*4.0)+Vector3.UP*6.4-GEORGE_CENTER+Vector3.UP*4.5
		var b:=a+direction*4.0
		var c:=a+normal*5.0+direction*2.0
		_beam(frame,a,c,0.20,0.25);_beam(frame,c,b,0.20,0.25);_beam(frame,a,b,0.13,0.16)
		Geo._triangle(timber,a,c,b,Vector3.DOWN,Vector2.ZERO,Vector2(2,5),Vector2(4,0))
		var d:=c+direction*2.0
		Geo._triangle(glass,b,c,d,Vector3.UP,Vector2.ZERO,Vector2(2,5),Vector2(4,5))
	Geo._commit_detail(world,roof,frame,"cyber_stone");Geo._commit_detail(world,roof,timber,"cyber_timber");Geo._commit_detail(world,roof,glass,"cyber_clear")
	var plaque: StaticBody3D=world._structure_box("cyber/george/pavilion/address",Vector3(-313.7,7.2,926.9),Vector3(0.15,1.0,2.2),"cyber_stone",95000)
	_label(plaque,"THE PAVILION\n388 GEORGE STREET",Vector3(-0.09,0,0),0.0038,Basis(Vector3.UP,-PI*0.5),Color("80724e"))

static func _label(parent: Node3D,text_value: String,p: Vector3,size: float,basis: Basis=Basis.IDENTITY,color: Color=Color("dad3bb")) -> void:
	var label:=Label3D.new();label.text=text_value;label.position=p;label.basis=basis
	label.font_size=48;label.pixel_size=size;label.outline_size=0;label.modulate=color;label.visibility_range_end=100
	parent.add_child(label)
