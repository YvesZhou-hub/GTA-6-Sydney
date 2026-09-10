extends RefCounted
## Native bank headquarters exteriors; research confidence is in docs/BANK_REFERENCE.md.
const Geo = preload("res://scripts/city_landmarks.gd")

const WESTPAC_HEIGHT := 166.0
const CBA_HEIGHT := 43.2 # Inferred architectural envelope, not a published survey height.
const FACADE_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 glass_color:source_color=vec4(0.25,0.37,0.48,1.0);
uniform vec4 metal_color:source_color=vec4(0.38,0.42,0.44,1.0);
uniform vec2 bay=vec2(1.4,3.9);
uniform float base=12.0;
uniform float blinds=0.0;
uniform bool roof_glass=false;
varying vec3 local_normal;
void vertex(){local_normal=NORMAL;}
void fragment(){
 vec2 grid=(UV-vec2(0.0,base))/bay;
 vec2 edge=min(fract(grid),1.0-fract(grid))*bay;
 vec2 aa=max(fwidth(UV),vec2(0.006));
 float frame=1.0-smoothstep(0.04-aa.x,0.04+aa.x,edge.x)*smoothstep(0.085-aa.y,0.085+aa.y,edge.y);
 float rnd=fract(sin(dot(floor(grid),vec2(12.9898,78.233)))*43758.5453);
 vec3 glass=glass_color.rgb*(0.87+rnd*0.20);
 float slat_edge=min(fract(UV.y/0.135),1.0-fract(UV.y/0.135))*0.135;
 float slat=1.0-smoothstep(0.014-aa.y,0.014+aa.y,slat_edge);
 float closed=blinds*step(rnd,0.63)*smoothstep(0.4,0.7,edge.y);
 glass=mix(glass,vec3(0.49,0.43,0.32)*(0.9+0.1*slat),closed*0.69);
 ALBEDO=mix(glass,metal_color.rgb,frame);
 ROUGHNESS=mix(0.19,0.61,frame);METALLIC=mix(0.39,0.62,frame);
 if(abs(local_normal.y)>0.75&&!roof_glass){ALBEDO=metal_color.rgb;ROUGHNESS=0.7;METALLIC=0.1;}
}
"""

static func metadata() -> Array[Dictionary]:
	return [
		{"id":"westpac","name":"Westpac Place · Westpac Group headquarters","address":"275 Kent Street, Sydney NSW 2000","center":WESTPAC_PODIUM_CENTER,"lat":-33.8660600591,"lon":151.2039136697,"height_m":166.0,"height_confidence":"CTBUH architectural height including roof beacon; individual OSM part heights inferred from architect photos","osm_ids":[120926554,335696788,544300935,544300936,544300937,544300938],"source":"https://www.westpac.com.au/about-westpac/global-locations/westpac-australia/"},
		{"id":"cba_south","name":"Commonwealth Bank Place South · CBA headquarters","address":"11 Harbour Street, Sydney NSW 2000","center":CBA_SOUTH_CENTER,"lat":-33.8753175218,"lon":151.2029945561,"height_m":CBA_HEIGHT,"height_confidence":"43.2m estimated from nine mapped levels and photographed vaulted roof; no survey height found","osm_ids":[183246899],"source":"https://www.commbank.com.au/about-us/investors/enquiries.html"},
		{"id":"cba_north","name":"Commonwealth Bank Place North","address":"Darling Quarter, Harbour Street, Sydney NSW 2000","center":CBA_NORTH_CENTER,"height_m":CBA_HEIGHT,"height_confidence":"43.2m estimated companion campus building; not identified as the South headquarters address","osm_ids":[183246900],"source":"https://fjcstudio.com/projects/darling-quarter/"}
	]

static func excluded_way_ids() -> Array[int]:
	return [120926554,335696788,544300935,544300936,544300937,544300938,183246899,183246900]

static func footprints() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for item: Array in [[WESTPAC_PODIUM_POINTS,WESTPAC_PODIUM_CENTER],[WESTPAC_CORE_POINTS,WESTPAC_CORE_CENTER],[WESTPAC_WEST_POINTS,WESTPAC_WEST_CENTER],[WESTPAC_EAST_POINTS,WESTPAC_EAST_CENTER],[WESTPAC_BEACON_POINTS,WESTPAC_BEACON_CENTER],[WESTPAC_PLANT_POINTS,WESTPAC_PLANT_CENTER],[CBA_SOUTH_POINTS,CBA_SOUTH_CENTER],[CBA_NORTH_POINTS,CBA_NORTH_CENTER]]:
		var poly := Geo.polygon(item[0])
		for i in poly.size(): poly[i]+=Vector2(item[1].x,item[1].z)
		result.append(poly)
	return result

static func build(world: Node3D) -> void:
	_materials(world)
	_westpac(world)
	_cba(world,"cba_south",CBA_SOUTH_CENTER,Geo.polygon(CBA_SOUTH_POINTS))
	_cba(world,"cba_north",CBA_NORTH_CENTER,Geo.polygon(CBA_NORTH_POINTS))
	world.set_meta("bank_landmarks",metadata())

static func _materials(world: Node3D) -> void:
	world._mat("bank_metal",Color("909b9e"),0.41,0.63)
	world._mat("bank_dark",Color("313b43"),0.6,0.43)
	world._mat("bank_stone",Color("b1ac9a"),0.9)
	world._mat("bank_wood",Color("927658"),0.79)
	world._mat("bank_roof",Color("b5bdba"),0.57,0.24)
	var beacon: StandardMaterial3D = world._mat("bank_beacon",Color("d4e1dc"),0.36,0.18)
	beacon.emission_enabled=true
	beacon.emission=Color("789b96")
	beacon.emission_energy_multiplier=0.15
	var bars: StandardMaterial3D = world._mat("bank_barometer",Color("b42f38"),0.37,0.12)
	bars.emission_enabled=true
	bars.emission=Color("7d101b")
	bars.emission_energy_multiplier=0.24
	_shader(world,"bank_westpac_glass",Color("35516b"),Vector2(1.48,122.0/31.0),12.0,0.0)
	_shader(world,"bank_westpac_east_glass",Color("3b596a"),Vector2(1.43,129.0/33.0),12.0,0.0)
	_shader(world,"bank_cba_glass",Color("758b87"),Vector2(1.8,3.7),5.4,1.0)
	_shader(world,"bank_lobby_glass",Color("445f65"),Vector2(2.8,5.4),0.0,0.0)
	_shader(world,"bank_atrium_glass",Color("8caaa9"),Vector2(2.7,3.8),0.0,0.0,true)

static func _shader(world: Node3D, key: String, color: Color, bay: Vector2, base_height: float, blinds: float, roof_glass: bool = false) -> void:
	var shader := Shader.new()
	shader.code=FACADE_SHADER
	var material := ShaderMaterial.new()
	material.shader=shader
	material.set_shader_parameter("glass_color",color)
	material.set_shader_parameter("bay",bay)
	material.set_shader_parameter("base",base_height)
	material.set_shader_parameter("blinds",blinds)
	material.set_shader_parameter("roof_glass",roof_glass)
	world.materials[key]=material

static func _westpac(world: Node3D) -> void:
	var outline := Geo.polygon(WESTPAC_PODIUM_POINTS)
	# The architect explicitly raises the commercial mass over the public
	# ground. Preserve that accessible ground plane rather than filling it.
	var podium: StaticBody3D = world._structure_mesh("bank/westpac/podium",Geo.prism(outline,7.5,12.0),WESTPAC_PODIUM_CENTER,"bank_lobby_glass",280000.0)
	Geo._detail(world,podium,Geo.prism(outline,11.60,12.0),"bank_metal")
	var column_index := 0
	for item in Geo._perimeter_samples(outline,10.5):
		var p: Vector3=item.position
		world._structure_box("bank/westpac/pier/%02d"%column_index,WESTPAC_PODIUM_CENTER+p+Vector3.UP*3.75,Vector3(0.8,7.5,0.8),"bank_metal",135000.0)
		column_index+=1
	var core := Geo.polygon(WESTPAC_CORE_POINTS)
	for i in range(4):
		var low := float(i)*15.0
		var body: StaticBody3D=world._structure_mesh("bank/westpac/central/%02d"%i,Geo.prism(core,low,low+15.0),WESTPAC_CORE_CENTER,"bank_westpac_glass",240000.0)
		Geo._detail(world,body,Geo.prism(core,low+14.7,low+15.0),"bank_metal")
		var core_fins:=SurfaceTool.new()
		core_fins.begin(Mesh.PRIMITIVE_TRIANGLES)
		for sample in Geo._perimeter_samples(core,3.0):
			Geo._append_box(core_fins,sample.position+Vector3.UP*(low+7.5),Vector3(0.10,15.0,0.18),sample.basis)
		Geo._commit_detail(world,body,core_fins,"bank_metal")
	for spec: Array in [["west",WESTPAC_WEST_CENTER,WESTPAC_WEST_POINTS,31,134.0,"bank_westpac_glass"],["east",WESTPAC_EAST_CENTER,WESTPAC_EAST_POINTS,33,141.0,"bank_westpac_east_glass"]]:
		var poly := Geo.polygon(spec[2])
		var floor_height: float=(spec[4]-12.0)/spec[3]
		for i in range(spec[3]):
			var low := 12.0+float(i)*floor_height
			var body: StaticBody3D=world._structure_mesh("bank/westpac/%s/%02d"%[spec[0],i],Geo.prism(poly,low,low+floor_height),spec[1],spec[5],170000.0)
			var prominent := i%4==0 if spec[0]=="west" else true
			if prominent: Geo._detail(world,body,Geo.prism(Geo._scaled(poly,1.014),low,low+0.32),"bank_metal")
			var blades := SurfaceTool.new()
			blades.begin(Mesh.PRIMITIVE_TRIANGLES)
			for p in poly:
				Geo._append_box(blades,Vector3(p.x,low+floor_height*0.5,p.y),Vector3(0.34,floor_height,0.34),Basis.IDENTITY)
			Geo._commit_detail(world,body,blades,"bank_metal")
		# Slender raised edge blades give the tops the photographed plane-like outline.
		for n in [0,1]:
			var p: Vector2=poly[n]
			world._structure_box("bank/westpac/%s/roofblade/%d"%[spec[0],n],spec[1]+Vector3(p.x,spec[4]+1.5,p.y),Vector3(0.26,3.0,0.26),"bank_metal",85000.0)
	var plant: StaticBody3D=world._structure_mesh("bank/westpac/roof_plant",Geo.prism(Geo.polygon(WESTPAC_PLANT_POINTS),134.0,147.0),WESTPAC_PLANT_CENTER,"bank_dark",145000.0)
	var louvers := SurfaceTool.new()
	louvers.begin(Mesh.PRIMITIVE_TRIANGLES)
	for h in range(135,147):
		Geo._append_box(louvers,Vector3(0,float(h),-3.2),Vector3(8.5,0.12,0.18),Basis(Vector3.UP,deg_to_rad(5.4)))
	Geo._commit_detail(world,plant,louvers,"bank_metal")
	world._structure_mesh("bank/westpac/beacon_base",Geo.prism(Geo.polygon(WESTPAC_BEACON_POINTS),134.0,141.0),WESTPAC_BEACON_CENTER,"bank_dark",150000.0)
	for n in range(5):
		var low := 141.0+n*5.0
		var body: StaticBody3D=world._structure_mesh("bank/westpac/beacon/%d"%n,Geo.prism(Geo.polygon(WESTPAC_BEACON_POINTS),low,low+5.0),WESTPAC_BEACON_CENTER,"bank_beacon",130000.0)
		var frames := SurfaceTool.new()
		frames.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in Geo.polygon(WESTPAC_BEACON_POINTS): Geo._append_box(frames,Vector3(p.x,low+2.5,p.y),Vector3(0.12,5.0,0.12),Basis.IDENTITY)
		Geo._commit_detail(world,body,frames,"bank_metal")
		var lights := SurfaceTool.new()
		lights.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in range(8):
			var h := 143.0+j*2.9
			if h<low or h>=low+5.0: continue
			for z in [-4.45,4.45]: Geo._append_box(lights,Vector3(0,h,z),Vector3(8.3,0.23,0.13),Basis(Vector3.UP,deg_to_rad(5.4)))
		Geo._commit_detail(world,body,lights,"bank_barometer")

static func _cba(world: Node3D, key: String, center: Vector3, outline: PackedVector2Array) -> void:
	for floor_index in range(9):
		var low := 0.0 if floor_index==0 else 5.4+float(floor_index-1)*3.7
		var high := 5.4 if floor_index==0 else low+3.7
		var body: StaticBody3D=world._structure_mesh("bank/%s/floor/%02d"%[key,floor_index],Geo.prism(outline,low,high),center,"bank_lobby_glass" if floor_index==0 else "bank_cba_glass",220000.0)
		Geo._detail(world,body,Geo.prism(Geo._scaled(outline,1.002),high-0.21,high),"bank_dark")
		var wood := SurfaceTool.new()
		wood.begin(Mesh.PRIMITIVE_TRIANGLES)
		var frames := SurfaceTool.new()
		frames.begin(Mesh.PRIMITIVE_TRIANGLES)
		for item in Geo._perimeter_samples(outline,1.8):
			var p: Vector3=item.position
			if floor_index==0:
				Geo._append_box(wood,p+Vector3.UP*(high*0.5),Vector3(0.32,high,0.38),item.basis)
			else:
				# Deep warm mullions and real horizontal blind rhythm distinguish
				# this campus from the blue glass CBD towers.
				Geo._append_box(wood,p+Vector3.UP*((low+high)*0.5)+item.outward*0.04,Vector3(0.15,high-low-0.25,0.22),item.basis)
			Geo._append_box(frames,p+Vector3.UP*(high-0.5),Vector3(0.07,0.85,0.11),item.basis)
		Geo._commit_detail(world,body,wood,"bank_wood")
		Geo._commit_detail(world,body,frames,"bank_metal")
	var roof: StaticBody3D=world._structure_mesh("bank/%s/vaulted_roof"%key,vaulted_roof(outline),center,"bank_atrium_glass",240000.0)
	var ribs := SurfaceTool.new()
	ribs.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Thin vault ribs follow the actual footprint boundary. The roof subdivision
	# is geometric, so an aircraft sees a curved volume rather than a flat decal.
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		Geo._append_beam(ribs,Vector3(a.x,roof_height(a)+0.10,a.y),Vector3(b.x,roof_height(b)+0.10,b.y),0.23,0.23)
	for item in Geo._perimeter_samples(outline,4.0):
		var p: Vector3=item.position
		var inward: Vector3=-item.outward*5.0
		var q := p+inward
		Geo._append_beam(ribs,Vector3(p.x,roof_height(Vector2(p.x,p.z))+0.1,p.z),Vector3(q.x,roof_height(Vector2(q.x,q.z))+0.1,q.z),0.12,0.12)
	Geo._commit_detail(world,roof,ribs,"bank_roof")
	# Park-facing awning follows the concave frontage, and belongs to the lobby
	# damage component. No individual shop names or interiors are invented.
	var lobby: StaticBody3D=world.structures["bank/%s/floor/00"%key].node
	var canopy := SurfaceTool.new()
	canopy.begin(Mesh.PRIMITIVE_TRIANGLES)
	for item in Geo._perimeter_samples(outline,2.0):
		var p: Vector3=item.position
		if item.outward.x>-0.4: continue
		var a := p+Vector3.UP*4.7
		var b: Vector3=a+item.outward*3.0-Vector3.UP*0.4
		Geo._append_beam(canopy,a,b,0.20,0.19)
	Geo._commit_detail(world,lobby,canopy,"bank_wood")

static func roof_height(p: Vector2) -> float:
	return 35.2+8.0*pow(clampf(1.0-pow((p.x-1.0)/44.0,2),0,1),0.65)

static func roof_normal(p: Vector2) -> Vector3:
	var slope := (roof_height(p+Vector2(0.05,0))-roof_height(p-Vector2(0.05,0)))/0.1
	return Vector3(-slope,1,0).normalized()

static func vaulted_roof(outline: PackedVector2Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(outline)
	for i in range(0,indices.size(),3):
		var a := outline[indices[i]]
		var b := outline[indices[i+1]]
		var c := outline[indices[i+2]]
		Geo._triangle(surface,Vector3(a.x,35.0,a.y),Vector3(b.x,35.0,b.y),Vector3(c.x,35.0,c.y),Vector3.DOWN,a,b,c)
		for row in range(12):
			for column in range(12-row):
				var p := a+(b-a)*float(row)/12.0+(c-a)*float(column)/12.0
				var q := a+(b-a)*float(row+1)/12.0+(c-a)*float(column)/12.0
				var r := a+(b-a)*float(row)/12.0+(c-a)*float(column+1)/12.0
				_roof_triangle(surface,p,q,r)
				if column+row<11:
					var s := a+(b-a)*float(row+1)/12.0+(c-a)*float(column+1)/12.0
					_roof_triangle(surface,q,s,r)
	var sign_area := Geo._area_sign(outline)
	var perimeter_distance:=0.0
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		var normal := Vector3(b.y-a.y,0,a.x-b.x).normalized()*sign_area
		for j in range(12):
			var p := a.lerp(b,float(j)/12.0)
			var q := a.lerp(b,float(j+1)/12.0)
			var pa := Vector3(p.x,35.0,p.y)
			var pb := Vector3(q.x,35.0,q.y)
			var pc := Vector3(q.x,roof_height(q),q.y)
			var pd := Vector3(p.x,roof_height(p),p.y)
			var u:=perimeter_distance+a.distance_to(b)*float(j)/12.0
			var v:=perimeter_distance+a.distance_to(b)*float(j+1)/12.0
			Geo._triangle(surface,pa,pb,pc,normal,Vector2(u,35),Vector2(v,35),Vector2(v,pc.y))
			Geo._triangle(surface,pa,pc,pd,normal,Vector2(u,35),Vector2(v,pc.y),Vector2(u,pd.y))
		perimeter_distance+=a.distance_to(b)
	return surface.commit()

static func _roof_triangle(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2) -> void:
	var normal := roof_normal((a+b+c)/3.0)
	Geo._triangle(surface,Vector3(a.x,roof_height(a),a.y),Vector3(b.x,roof_height(b),b.y),Vector3(c.x,roof_height(c),c.y),normal,a,b,c)

const WESTPAC_PODIUM_CENTER := Vector3(-608.57692,4.5,674.60577)
const WESTPAC_PODIUM_POINTS := [[-30.55388,51.52345],[-10.79876,50.14309],[-11.70428,38.55467],[1.51816,37.33015],[7.70896,36.76242],[9.12268,51.4344],[30.39316,49.49743],[23.50012,-26.90149],[21.21784,-52.21565],[19.05568,-52.08207],[15.81244,-84.06431],[-2.70452,-70.10478],[1.33336,-27.64733],[2.6362,-13.9661],[-16.70312,-12.09593],[-17.47928,-18.89758],[-37.39148,-16.88269],[-34.67492,10.27939]]
const WESTPAC_CORE_CENTER := Vector3(-615.37076,4.5,678.64306)
const WESTPAC_CORE_POINTS := [[18.67004,22.94011],[-14.70484,25.66745],[-18.6688,-22.946],[14.70608,-25.6622]]
const WESTPAC_WEST_CENTER := Vector3(-615.06786,4.5,687.09745)
const WESTPAC_WEST_POINTS := [[9.12714,-26.45778],[-14.14842,-24.29817],[-9.18654,26.40809],[8.0091,24.83848],[14.1999,24.27074],[13.72866,19.60644]]
const WESTPAC_EAST_CENTER := Vector3(-595.12689,4.5,675.90020)
const WESTPAC_EAST_POINTS := [[-12.11667,-28.94175],[6.52965,-30.54476],[11.85189,29.32313],[-6.21231,30.80369]]
const WESTPAC_BEACON_CENTER := Vector3(-610.28814,4.5,691.71465)
const WESTPAC_BEACON_POINTS := [[-4.95726,-4.09101],[4.0887,-4.83685],[4.95726,4.09101],[-4.0887,4.83685]]
const WESTPAC_PLANT_CENTER := Vector3(-609.58714,4.5,698.81434)
const WESTPAC_PLANT_POINTS := [[-4.7897,-2.26283],[-4.29074,3.0026],[4.8199,2.25676],[4.25626,-3.00868]]
const CBA_SOUTH_CENTER := Vector3(-693.50302,4.5,1705.14453)
const CBA_SOUTH_POINTS := [[-29.49002,40.28627],[-28.47362,31.60331],[-28.2149,24.5011],[-28.52906,17.47681],[-29.8319,9.92931],[-31.50434,2.74917],[-33.99914,-4.37531],[-37.24238,-11.25489],[-41.6129,-18.3571],[-38.1479,-20.5835],[-39.23822,-22.43141],[-21.80234,-34.33152],[-20.73974,-32.69512],[-19.19666,-33.74153],[-20.35166,-35.40019],[-12.31286,-41.11091],[-17.25626,-47.93483],[-7.43414,-55.38213],[-0.38402,-61.10398],[1.3069,-58.95551],[4.53166,-61.38228],[8.72662,-56.06119],[12.3487,-50.17236],[18.00358,-40.10903],[22.52194,-29.8008],[25.9777,-20.56124],[29.08234,-9.71867],[31.42006,0.75654],[33.01858,13.45815],[33.29578,20.68282],[33.37894,30.80181],[32.69518,41.90041],[31.12438,51.75223],[27.33598,50.96186],[27.16042,51.99714],[7.04494,47.92283],[8.04286,42.52381],[-4.34798,40.54231],[-5.3459,45.62963],[-25.98806,41.77796],[-25.88642,40.90967]]
const CBA_NORTH_CENTER := Vector3(-758.71791,4.5,1622.03146)
const CBA_NORTH_POINTS := [[12.86511,51.57568],[15.78495,48.29174],[18.06723,49.83909],[49.63107,12.56915],[54.01083,7.40391],[55.23975,5.95675],[22.89051,-23.47626],[2.83971,-43.09085],[1.63851,-44.15952],[0.09543,-42.55651],[-0.98565,-41.17614],[-3.86853,-43.55839],[-26.19237,-35.37637],[-21.99741,-31.84753],[-27.33813,-26.38171],[-31.38525,-30.06641],[-33.35337,-27.48378],[-32.18913,-26.55983],[-33.11313,-25.60247],[-38.80497,-30.64527],[-58.74489,-23.454],[-61.34133,-22.41872],[-57.17409,-18.83422],[-60.23253,-15.33877]]
