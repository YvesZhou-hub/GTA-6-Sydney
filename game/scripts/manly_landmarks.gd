extends RefCounted
## Original Manly exteriors reconstructed from map data and inspected photos.
## Map positions are sourced; heights and facade details are visual estimates.
## See docs/MANLY_REFERENCE.md.

const WHARF_FLOOR := 0.04 # Physical surface above coincident mapped ground.
const WHARF_CENTER := Vector3(6823.55121,4.5,-6681.92745)
const WHARF_POINTS := [[-12.9043,1.5029],[-2.9159,5.1542],[-2.768,4.6422],[0.5214,5.978],[-0.3009,8.171],[29.5535,19.3921],[29.3964,21.1954],[29.8122,21.9858],[30.4128,22.5535],[31.5771,22.9543],[31.0966,24.3903],[32.4364,24.9135],[32.3532,25.1362],[38.2021,27.2846],[37.4537,29.4442],[51.2398,34.5093],[52.4133,31.4814],[56.9039,33.2291],[57.3936,32.0269],[61.4592,33.5742],[62.3925,30.6354],[76.8438,36.0455],[78.3777,36.257],[79.6066,35.9787],[80.9464,35.4221],[92.598,20.6611],[92.5795,18.5349],[91.905,15.2176],[89.9461,15.6183],[91.2397,14.2268],[91.3414,12.5347],[90.2418,9.5959],[88.8466,7.4585],[58.1883,-20.0932],[40.0963,-26.572],[34.1458,-28.6982],[30.6531,-28.4978],[26.5782,-26.9171],[23.3627,-23.0209],[20.3597,-24.0895],[18.1513,-24.8354],[16.7191,-28.932],[18.3823,-29.778],[18.5025,-30.5906],[16.5343,-34.0193],[15.7305,-34.2642],[10.2696,-38.6836],[7.2297,-37.9711],[-0.6059,-39.1289],[-8.2289,-41.3553],[-13.8098,-43.9936],[-18.8918,-47.0215],[-21.7193,-50.2609],[-23.9923,-54.3797],[-25.0919,-58.788],[-30.7467,-58.3204],[-31.0332,-58.9104],[-31.911,-59.467],[-34.9879,-59.2555],[-36.2353,-58.2203],[-36.5217,-57.6303],[-37.6121,-57.5857],[-37.9355,-60.9142],[-41.7331,-60.3465],[-44.7546,-58.5208],[-46.8151,-55.3593],[-46.9999,-51.8527],[-46.1683,-47.9788],[-43.2577,-39.8858],[-44.0708,-39.5742],[-44.5605,-39.7634],[-46.2884,-34.9989],[-38.2496,-31.9933],[-38.8133,-30.2901],[-47.4619,-33.3625],[-47.7391,-32.7168],[-55.3436,-11.733],[-36.3739,-4.4416],[-35.376,-7.2134],[-30.5065,-5.4323],[-32.0773,-1.1688],[-32.7426,0.6458],[-33.6943,3.2395],[-44.3388,32.1271],[-47.7114,30.8803],[-48.968,30.435],[-55.5746,48.4243],[-55.9442,48.2907],[-59.9359,59.0442],[-64.6298,73.6049],[-60.4164,75.2413],[-62.6709,81.9984],[-45.0225,88.5663],[-42.731,82.1765],[-37.5289,83.991],[-37.2702,83.312],[-36.8451,82.1988],[-36.4109,81.0299],[-21.3959,41.1885],[-24.3065,40.053],[-26.8567,39.1625],[-14.1979,5.5104]]
const CORSO_CENTER := Vector3(7083.96084,4.5,-6935.78051)
const CORSO_POINTS := [[71.7262,-70.4665],[74.5813,-72.2365],[79.035,-74.9861],[85.9742,-60.9821],[90.8068,-50.7517],[86.0759,-47.9242],[84.1355,-46.7665],[82.1766,-45.3973],[71.5506,-38.2282],[63.9553,-32.7847],[60.1577,-30.0574],[56.8775,-27.7085],[42.038,-17.0663],[39.6264,-16.2314],[14.1979,1.8024],[-7.4422,16.3186],[-13.3096,20.7046],[-26.1624,29.7771],[-42.4248,41.2431],[-69.766,60.5237],[-76.659,65.1435],[-94.0856,77.3776],[-95.9798,78.7023],[-98.4469,75.2959],[-101.3852,71.1882],[-104.342,67.0693],[-107.5945,65.3661],[-112.9907,64.7873],[-115.1806,61.4032],[-62.3647,24.0108],[-42.8221,10.1737],[24.8609,-37.9054],[34.6645,-44.7405],[41.8163,-49.6831],[66.6996,-66.9711]]
const HOTEL_CENTER := Vector3(7130.82370,4.5,-7012.36963)
const HOTEL_POINTS := [[-27.6661,-21.7074],[-18.9528,21.7297],[-5.0466,24.9245],[20.4835,6.2896],[21.7587,3.3396],[9.4233,-34.576]]
const HOTEL_COURT := [[-10.0177,10.9539],[5.4408,0.5677],[-1.674,-21.8632],[-7.5599,-19.9819],[-8.0496,-21.1285],[-12.7065,-19.737],[-12.3277,-17.4216],[-12.2723,-14.839],[-12.9745,-12.5124],[-13.6213,-9.863],[-13.5659,-7.3805],[-13.1316,-5.8666],[-12.1614,-6.0892],[-11.2466,-0.9574],[-14.4806,-0.3674],[-14.2681,1.1466],[-11.8934,0.8238]]
const CORSO_ROUTE := [[-33.7983513,151.2860406],[-33.7983346,151.286069],[-33.7977726,151.2870193],[-33.7973452,151.2877529],[-33.7971767,151.2880456]]
const PROMENADE := [[-33.7941958,151.2874294],[-33.7942636,151.2874389],[-33.7945339,151.2875186],[-33.7947199,151.2875724],[-33.7952506,151.2877335],[-33.7954573,151.2877917],[-33.7960072,151.2879466],[-33.7967535,151.2882409],[-33.7970494,151.2883603],[-33.7976617,151.2886902],[-33.7979196,151.288859],[-33.7981498,151.2890096],[-33.7987093,151.2894126],[-33.7988894,151.289572]]
const HOTEL_ROOF_TRIANGLES := [[[-27.6661,-21.7074],[-18.9528,21.7297],[-14.4806,-0.3674]],[[-13.1316,-5.8666],[-11.2466,-0.9574],[-12.1614,-6.0892]],[[-12.9745,-12.5124],[-12.2723,-14.839],[-12.3277,-17.4216]],[[-8.0496,-21.1285],[-7.5599,-19.9819],[-1.674,-21.8632]],[[-10.0177,10.9539],[-11.8934,0.8238],[-14.2681,1.1466]],[[-14.2681,1.1466],[-14.4806,-0.3674],[-18.9528,21.7297]],[[5.4408,0.5677],[-5.0466,24.9245],[20.4835,6.2896]],[[-1.674,-21.8632],[21.7587,3.3396],[9.4233,-34.576]],[[-11.2466,-0.9574],[-13.1316,-5.8666],[-14.4806,-0.3674]],[[-27.6661,-21.7074],[-12.3277,-17.4216],[-12.7065,-19.737]],[[-10.0177,10.9539],[-14.2681,1.1466],[-18.9528,21.7297]],[[-13.5659,-7.3805],[-14.4806,-0.3674],[-13.1316,-5.8666]],[[-12.3277,-17.4216],[-27.6661,-21.7074],[-12.9745,-12.5124]],[[-5.0466,24.9245],[-10.0177,10.9539],[-18.9528,21.7297]],[[-14.4806,-0.3674],[-13.5659,-7.3805],[-27.6661,-21.7074]],[[-10.0177,10.9539],[-5.0466,24.9245],[5.4408,0.5677]],[[-27.6661,-21.7074],[-13.5659,-7.3805],[-13.6213,-9.863]],[[21.7587,3.3396],[5.4408,0.5677],[20.4835,6.2896]],[[-12.9745,-12.5124],[-27.6661,-21.7074],[-13.6213,-9.863]],[[5.4408,0.5677],[21.7587,3.3396],[-1.674,-21.8632]],[[-8.0496,-21.1285],[-27.6661,-21.7074],[-12.7065,-19.737]],[[-8.0496,-21.1285],[-1.674,-21.8632],[9.4233,-34.576]],[[-27.6661,-21.7074],[-8.0496,-21.1285],[9.4233,-34.576]]]

static func geo(lat: float, lon: float, y: float = 4.5) -> Vector3:
	return Vector3((lon-151.2105)*92400.0,y,-(lat+33.86)*111320.0)

static func polygon(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p: Array in points: result.append(Vector2(p[0],p[1]))
	return result

static func excluded_way_ids() -> Array[int]:
	return [7981564,1326239876,223786812,552008767]

static func footprints() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for item: Array in [[WHARF_POINTS,WHARF_CENTER],[HOTEL_POINTS,HOTEL_CENTER]]:
		var poly := polygon(item[0])
		for i in poly.size(): poly[i] += Vector2(item[1].x,item[1].z)
		result.append(poly)
	return result

static func metadata() -> Array[Dictionary]:
	# Navigation is canonical in the shared geography file. Keep map centroids
	# distinct from public arrivals; the world registry reads these same records.
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/landmark_geography.json"))
	var result: Array[Dictionary] = []
	for record: Dictionary in source.get("landmarks",[]):
		if record.get("group","") != "manly_landmarks": continue
		var item: Dictionary = record.duplicate(true)
		for field: String in ["map_position","arrival","model_reference"]:
			var values: Array = item[field]
			item[field] = Vector3(values[0],values[1],values[2])
		item["center"] = item.model_reference
		result.append(item)
	return result

static func build(world: Node3D) -> void:
	_materials(world)
	_wharf(world)
	_corso(world)
	_hotel(world)
	_beach_pines(world)
	_bus_stops(world)
	_public_bubblers(world)
	var navigation: Array[Dictionary] = metadata()
	world.set_meta("manly_landmarks",navigation)
	for item: Dictionary in navigation:
		world.anchors[item.id] = item.arrival
		for alias: String in item.get("aliases",[]):
			world.anchors[alias] = item.arrival

static func _materials(world: Node3D) -> void:
	for entry: Array in [["manly_white","ede9d9"],["manly_roof","677972"],["manly_brick","a47552"],["manly_frame","b8c8ac"],["manly_glass","334d4c"],["manly_paving","c9bc97"],["manly_paving_band","807f72"],["manly_pine","344a37"],["manly_palm","657645"],["manly_palm_old","7c7353"],["manly_bus","237b9e"],["manly_ferry","33845d"],["manly_steel","364448"],["manly_ceiling","9d7954"],["manly_light","f5ecd5"],["manly_tile","d7c9a4"]]:
		world._mat(entry[0],Color(entry[1]),0.93 if entry[0]!="manly_glass" else 0.26)
	world.materials.manly_palm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var brick: StandardMaterial3D = world.materials.manly_brick
	brick.albedo_texture = world._surface_texture("brick")
	brick.uv1_triplanar = true
	brick.uv1_scale = Vector3(0.72,0.72,0.72)

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var points := [a,b,c]
	if (b-a).cross(c-a).dot(normal)>0.0: points=[a,c,b]
	for p: Vector3 in points:
		st.set_normal(normal)
		st.set_uv(Vector2(p.x,p.y if absf(normal.y)<0.5 else p.z)*0.12)
		st.add_vertex(p)

static func _finish(st: SurfaceTool) -> ArrayMesh:
	# The world's destructive-component batching reads indexed triangle arrays.
	var mesh := st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var count: int = arrays[Mesh.ARRAY_VERTEX].size()
	var indices := PackedInt32Array()
	for i in count: indices.append(i)
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

static func prism(points: Array, low: float, high: float, hole: Array = [], roof_triangles: Array = []) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring: Array in [points,hole]:
		if ring.is_empty(): continue
		var poly := polygon(ring)
		var clockwise := Geometry2D.is_polygon_clockwise(poly)
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i+1)%poly.size()]
			var delta := b-a
			var n := Vector3(delta.y,0,-delta.x).normalized()
			if clockwise: n=-n
			if ring==hole: n=-n
			_triangle(st,Vector3(a.x,low,a.y),Vector3(b.x,low,b.y),Vector3(b.x,high,b.y),n)
			_triangle(st,Vector3(a.x,low,a.y),Vector3(b.x,high,b.y),Vector3(a.x,high,a.y),n)
	var triangles: Array = roof_triangles.duplicate()
	if triangles.is_empty():
		var poly := polygon(points)
		var indices := Geometry2D.triangulate_polygon(poly)
		for i in range(0,indices.size(),3):
			triangles.append([points[indices[i]],points[indices[i+1]],points[indices[i+2]]])
	for tri: Array in triangles:
		for y: float in [low,high]:
			_triangle(st,Vector3(tri[0][0],y,tri[0][1]),Vector3(tri[1][0],y,tri[1][1]),Vector3(tri[2][0],y,tri[2][1]),Vector3.UP if y==high else Vector3.DOWN)
	return _finish(st)

static func _local_box(world: Node3D, body: Node3D, p: Vector3, size: Vector3, key: String, basis: Basis = Basis.IDENTITY) -> void:
	var part: MeshInstance3D = world._box(body,p,size,key)
	part.basis = basis

static func _label(parent: Node3D, text_value: String, p: Vector3, size: float, basis: Basis = Basis.IDENTITY, color: Color = Color("e7e8d9")) -> void:
	var label := Label3D.new()
	label.text=text_value
	label.font_size=48
	label.pixel_size=size
	label.outline_size=0
	label.modulate=color
	label.transform=Transform3D(basis,p)
	label.visibility_range_end=200
	parent.add_child(label)

static func _edge_basis(a: Vector2, b: Vector2) -> Basis:
	var x := Vector3(b.x-a.x,0,b.y-a.y).normalized()
	return Basis(x,Vector3.UP,x.cross(Vector3.UP))

static func _wharf(world: Node3D) -> void:
	# Open concourse: a roof and platform, never one opaque terminal-sized box.
	world._structure_mesh("manly/wharf/platform",prism(WHARF_POINTS,-1.0,WHARF_FLOOR),WHARF_CENTER,"concrete",1200000)
	var roof: StaticBody3D = world._structure_mesh("manly/wharf/roof",prism(WHARF_POINTS,5.15,5.65),WHARF_CENTER,"manly_roof",620000)
	var poly := polygon(WHARF_POINTS)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i+1)%poly.size()]
		var length := a.distance_to(b)
		if length<0.7: continue
		var edge := _edge_basis(a,b)
		var midpoint := Vector3((a.x+b.x)*0.5,0,(a.y+b.y)*0.5)
		_local_box(world,roof,midpoint+Vector3.UP*5.10,Vector3(length+0.04,0.60,0.40),"manly_white",edge)
		# The broad curved north front is columned and open. Keep a second
		# west-side opening to the promenade and boarding concourse.
		var open_front := i>=46 and i<=55
		var open_west := i>=68 and i<=79
		if not open_front and not open_west and length>2.0:
			var wall: StaticBody3D = world._structure_box("manly/wharf/wall/%s"%i,WHARF_CENTER+midpoint+Vector3.UP*2.45,Vector3(length,4.9,0.30),"manly_glass",180000,edge)
			_local_box(world,wall,Vector3(0,-1.8,0),Vector3(length,1.3,0.42),"manly_white")
		for column in range(maxi(1,int(ceil(length/5.0)))):
			var t := float(column)/maxi(1,int(ceil(length/5.0)))
			var p := a.lerp(b,t)
			world._structure_box("manly/wharf/column/%s/%s"%[i,column],WHARF_CENTER+Vector3(p.x,2.6,p.y),Vector3(0.25,5.2,0.25),"manly_white",80000)
		# Real piers extend below the concrete deck into the harbour.
		for pier in range(maxi(1,int(length/9.0))):
			var p := a.lerp(b,(pier+0.5)/maxi(1,int(length/9.0)))
			world._batch_cylinder(WHARF_CENTER+Vector3(p.x,-3.0,p.y),0.36,6.0,"wood")
	# Original north-west clock-tower block, round clock and horizontal fins.
	var clock_p := geo(-33.799462,151.283989)
	var front := Basis(Vector3.UP,deg_to_rad(-22.0))
	var tower: StaticBody3D = world._structure_box("manly/wharf/clock",clock_p+Vector3.UP*6.6,Vector3(4.2,13.2,4.1),"manly_white",330000,front)
	for y in [3.85,4.30,4.75]:
		for side in [-1,1]:_local_box(world,tower,Vector3(side*1.92,y,0),Vector3(1.10,.18,4.60),"manly_roof")
	_local_box(world,tower,Vector3(0,6.60,0),Vector3(4.65,.22,4.55),"manly_roof")
	for x in [-1.75,-1.4,-1.05,-.70,-.35,0,.35,.70,1.05,1.4,1.75]:
		for face in [-1,1]:_local_box(world,tower,Vector3(x,-.2,face*2.061),Vector3(.028,11.5,.022),"manly_frame")
	for face in [-1,1]:
		var f := Basis(Vector3.UP,0.0 if face==1 else PI)
		var dial := MeshInstance3D.new()
		var dial_mesh := CylinderMesh.new()
		dial_mesh.top_radius=1.13; dial_mesh.bottom_radius=1.13; dial_mesh.height=0.06; dial_mesh.radial_segments=32
		dial.mesh=dial_mesh; dial.material_override=world.materials.manly_white
		dial.position=Vector3(0,4.8,face*2.09); dial.rotation.x=PI*0.5
		tower.add_child(dial)
		for mark in range(12):
			var angle := mark*TAU/12.0
			_local_box(world,tower,Vector3(sin(angle)*0.84,4.8+cos(angle)*0.84,face*2.14),Vector3(0.07,0.15,0.07),"manly_steel",Basis(Vector3.BACK,-angle))
		world._local_beam(tower,Vector3(0,4.8,face*2.17),Vector3(0,5.46,face*2.17),0.065,"manly_steel")
		world._local_beam(tower,Vector3(0,4.8,face*2.17),Vector3(0.45,4.63,face*2.17),0.08,"manly_steel")
		_label(tower,"MANLY",Vector3(0,1.5,face*2.18),0.012,f,Color("365349"))
	# The entrance fascia faces the Corso across the forecourt; clear below 4.4m.
	var label_p := geo(-33.799550,151.284167,11.85)
	_label(world,"MANLY WHARF",label_p,0.026,Basis(Vector3.UP,deg_to_rad(145)),Color("eee9dc"))
	# T-shaped clerestory marks the terminal's centre without sealing its floor.
	var clerestory: StaticBody3D = world._structure_box("manly/wharf/clerestory",WHARF_CENTER+Vector3(-9,6.5,-11),Vector3(14,1.7,63),"manly_glass",220000,Basis(Vector3.UP,deg_to_rad(-20)))
	_local_box(world,clerestory,Vector3(0,0.9,0),Vector3(15.3,0.3,64),"manly_roof")
	_wharf_public_hall(world,roof)

static func _corso(world: Node3D) -> void:
	world._structure_mesh("manly/corso/paving",prism(CORSO_POINTS,0.08,0.095),CORSO_CENTER,"manly_paving",1500000)
	var a := geo(CORSO_ROUTE[0][0],CORSO_ROUTE[0][1],4.596)
	var b := geo(CORSO_ROUTE[-1][0],CORSO_ROUTE[-1][1],4.596)
	var direction := (b-a).normalized()
	var right := Vector3(-direction.z,0,direction.x)
	var basis := Basis.looking_at(direction,Vector3.UP)
	for station in range(14,int(a.distance_to(b))-10,7):
		world._batch_box(a+direction*station,Vector3(20.0,0.007,0.28),"manly_paving_band",basis)
	# Circular timber seats around fan palms follow the inspected Corso photo.
	# Their spacing is reconstructed; the pedestrian polygon itself is mapped.
	for station in range(28,int(a.distance_to(b))-18,27):
		world._lamp(a+direction*(station+9)+right*10.0)
	_label(world,"THE CORSO",a+direction*19+right*10+Vector3.UP*2.2,0.018,Basis(Vector3.UP,atan2(-direction.x,-direction.z)),Color("435548"))

static func _ring_seat(world: Node3D, p: Vector3) -> void:
	for i in range(24):
		var angle := i*TAU/24.0
		var b := Basis(Vector3.UP,-angle)
		var q := p+Vector3(cos(angle)*1.35,0.56,sin(angle)*1.35)
		world._batch_box(q,Vector3(0.63,0.12,0.29),"wood",b)
		world._batch_box(q-Vector3.UP*0.20,Vector3(0.58,0.28,0.22),"manly_white",b)

static var _palm_mesh_cache: Dictionary = {}

# Every leaf lobe is a closed, folded strip, not a one-sided fan triangle.
static func _palm_strip(st:SurfaceTool,points:PackedVector3Array,side:Vector3,normal:Vector3,width:float) -> void:
	var rings:Array[PackedVector3Array]=[]
	for i in points.size():
		var t:float=float(i)/(points.size()-1)
		var half_width:float=maxf(.008,pow(sin(PI*t),.65)*width)
		var fold:float=.018+.025*sin(PI*t)
		var center:Vector3=points[i]
		rings.append(PackedVector3Array([center-side*half_width,center+normal*fold,center+side*half_width,center-normal*.018]))
	for i in range(rings.size()-1):
		for j in 4:
			var k:int=(j+1)%4
			var n:Vector3=((rings[i][j]+rings[i][k])*.5-points[i]).normalized()
			_triangle(st,rings[i][j],rings[i+1][j],rings[i+1][k],n)
			_triangle(st,rings[i][j],rings[i+1][k],rings[i][k],n)
	for endpoint in [0,rings.size()-1]:
		var axis:Vector3=(points[1]-points[0]).normalized() if endpoint==0 else (points[-1]-points[-2]).normalized()
		var n:Vector3=-axis if endpoint==0 else axis
		_triangle(st,rings[endpoint][0],rings[endpoint][1],rings[endpoint][2],n)
		_triangle(st,rings[endpoint][0],rings[endpoint][2],rings[endpoint][3],n)

static func _palm_stem(st:SurfaceTool,points:PackedVector3Array) -> void:
	var rings:Array[PackedVector3Array]=[]
	for i in points.size():
		var tangent:Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var side:Vector3=tangent.cross(Vector3.RIGHT).normalized()
		var normal:Vector3=tangent.cross(side).normalized()
		var ring:=PackedVector3Array()
		var radius:float=lerpf(.070,.027,float(i)/(points.size()-1))
		for j in 6:ring.append(points[i]+(side*cos(j*TAU/6)+normal*sin(j*TAU/6))*radius)
		rings.append(ring)
	for i in range(rings.size()-1):
		for j in 6:
			var k:int=(j+1)%6
			var n:Vector3=((rings[i][j]+rings[i][k])*.5-points[i]).normalized()
			_triangle(st,rings[i][j],rings[i+1][j],rings[i+1][k],n)
			_triangle(st,rings[i][j],rings[i+1][k],rings[i][k],n)
	for endpoint in [0,rings.size()-1]:
		var n:Vector3=(points[0]-points[1]).normalized() if endpoint==0 else (points[-1]-points[-2]).normalized()
		for j in range(1,5):_triangle(st,rings[endpoint][0],rings[endpoint][j],rings[endpoint][j+1],n)

static func palm_crown_geometry(height:float) -> Dictionary:
	if _palm_mesh_cache.has(height):return _palm_mesh_cache[height]
	var green:=SurfaceTool.new();green.begin(Mesh.PRIMITIVE_TRIANGLES)
	var old:=SurfaceTool.new();old.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profiles:Array[Dictionary]=[]
	# Dense split fan leaves with a folded midrib, curved stalk and hanging skirt.
	# Dimensions and species remain photo-informed estimates, not measured botany.
	for tier in 3:
		var count:int=[16,8,10][tier]
		for frond in count:
			var angle:float=frond*TAU/count+tier*.37
			var radial:=Vector3(sin(angle),0,cos(angle))
			var lateral:=Vector3(radial.z,0,-radial.x)
			var pitch:float=[-.12,.76,-.95][tier]+sin(frond*2.1)*.13
			var out:Vector3=radial*cos(pitch)+Vector3.UP*sin(pitch)
			var normal:Vector3=out.cross(lateral).normalized()
			var start:Vector3=Vector3.UP*(height+[.08,.32,-.22][tier])+radial*.12+lateral*.04
			var reach:float=[1.25,.66,.55][tier]
			var fan_start:Vector3=start+out*reach
			var st:SurfaceTool=old if tier==2 else green
			var stalk:=PackedVector3Array()
			for station in 7:
				var t:float=station/6.0
				stalk.append(start.lerp(fan_start,t)+normal*sin(PI*t)*.14)
			_palm_stem(st,stalk)
			var tips:=PackedVector3Array()
			for lobe in 13:
				var fan_angle:float=(lobe-6)*.17
				var direction:Vector3=out*cos(fan_angle)+lateral*sin(fan_angle)
				var side:Vector3=lateral*cos(fan_angle)-out*sin(fan_angle)
				var length:float=(1.82-.21*absf(fan_angle))*(.95+.05*sin(frond*1.7+lobe*.36))
				var points:=PackedVector3Array()
				for station in 6:
					var t:float=station/5.0
					points.append(fan_start+direction*(length*t)+normal*(sin(PI*t)*.23-t*t*.53))
				_palm_strip(st,points,side,normal,.13)
				tips.append(points[-1])
			profiles.append({"tier":tier,"start":start,"fan_start":fan_start,"tips":tips,"stalk":stalk})
	var result:Dictionary={"green":_finish(green),"old":_finish(old),"profiles":profiles}
	_palm_mesh_cache[height]=result
	return result

static func _palm(world: Node3D, p: Vector3, height: float) -> void:
	world._batch_cylinder(p+Vector3.UP*height*0.5,0.31,height,"bark")
	for y in range(1,int(height*3)):
		world._batch_cylinder(p+Vector3.UP*y/3.0,0.34,0.055,"manly_palm_old")
	var geometry:Dictionary=palm_crown_geometry(height)
	for key:String in ["green","old"]:
		var view:=MeshInstance3D.new()
		view.name="ManlyPalmCrown_"+key
		view.mesh=geometry[key]
		view.material_override=world.materials.manly_palm if key=="green" else world.materials.manly_palm_old
		view.position=p
		view.set_meta("manly_palm_crown",true)
		view.visibility_range_end=700
		world.add_child(view)

static func _hotel(world: Node3D) -> void:
	# The mapped multipolygon courtyard stays open through both storeys and
	# roof. Constrained triangulation was generated offline from the OSM rings.
	for level in range(2):
		var low := float(level)*4.7
		var body: StaticBody3D = world._structure_mesh("manly/steyne/floor/%s"%level,prism(HOTEL_POINTS,low,low+4.7,HOTEL_COURT,HOTEL_ROOF_TRIANGLES),HOTEL_CENTER,"manly_brick",430000)
		for i in range(HOTEL_POINTS.size()):
			var a := Vector2(HOTEL_POINTS[i][0],HOTEL_POINTS[i][1])
			var b := Vector2(HOTEL_POINTS[(i+1)%HOTEL_POINTS.size()][0],HOTEL_POINTS[(i+1)%HOTEL_POINTS.size()][1])
			var basis := _edge_basis(a,b)
			# The OSM ring is clockwise in XY map coordinates; local +Z faces outward.
			if not Geometry2D.is_polygon_clockwise(polygon(HOTEL_POINTS)): basis.z=-basis.z; basis.x=-basis.x
			var length := a.distance_to(b)
			var mid := Vector3((a.x+b.x)*0.5,0,(a.y+b.y)*0.5)
			var bays := maxi(1,int(length/3.5))
			for bay in bays:
				var q := a.lerp(b,(bay+0.5)/bays)
				var p := Vector3(q.x,low+2.5,q.y)+basis.z*0.04
				var width := minf(2.25,length/bays-0.55)
				_local_box(world,body,p,Vector3(width,3.1 if level==0 else 2.65,0.12),"manly_frame",basis)
				_local_box(world,body,p+basis.z*0.075,Vector3(width-0.19,2.9 if level==0 else 2.43,0.05),"manly_glass",basis)
				_local_box(world,body,p+basis.z*0.12,Vector3(0.075,2.55,0.055),"manly_frame",basis)
				if level==1:
					_local_box(world,body,p+Vector3.DOWN*1.33+basis.z*0.21,Vector3(width+0.25,0.17,0.65),"manly_white",basis)
					if i in [2,4]:
						_local_box(world,body,p+Vector3.DOWN*0.96+basis.z*0.57,Vector3(width+0.15,0.065,0.07),"manly_frame",basis)
						for rail in range(7):
							_local_box(world,body,p+basis.x*(rail-3)*width/7+Vector3.DOWN*1.11+basis.z*0.57,Vector3(0.04,0.43,0.04),"manly_frame",basis)
			if level==0 and i in [1,2]:
				_local_box(world,body,mid+Vector3.UP*3.9+basis.z*1.25,Vector3(length+0.05,0.20,2.8),"manly_white",basis)
				# Current contractor photo: plain cream awning with pale-green edge,
				# fine hanger rods, not an invented alternating striped fabric.
				for hanger in range(maxi(1,int(length/5.5))):
					var q:Vector3=mid+basis.x*((hanger+.5)*length/maxi(1,int(length/5.5))-length*.5)
					world._local_beam(body,q+Vector3.UP*6.0+basis.z*.22,q+Vector3.UP*4.08+basis.z*2.50,.045,"manly_white")

				_local_box(world,body,mid+Vector3.UP*3.65+basis.z*2.6,Vector3(length,0.46,0.12),"manly_frame",basis)
			if level==1:
				_local_box(world,body,mid+Vector3.UP*9.0+basis.z*0.13,Vector3(length+0.04,0.22,0.38),"manly_brick",basis)
				for merlon in range(maxi(1,int(length/1.15))):
					var p := a.lerp(b,(merlon+0.5)/maxi(1,int(length/1.15)))
					_local_box(world,body,Vector3(p.x,9.55,p.y),Vector3(0.72,0.4,0.45),"manly_brick",basis)
	var roof: StaticBody3D = world._structure_mesh("manly/steyne/roof",prism(HOTEL_POINTS,9.35,9.5,HOTEL_COURT,HOTEL_ROOF_TRIANGLES),HOTEL_CENTER,"manly_roof",260000)
	var a := Vector2(HOTEL_POINTS[2][0],HOTEL_POINTS[2][1])
	var b := Vector2(HOTEL_POINTS[3][0],HOTEL_POINTS[3][1])
	var basis := _edge_basis(a,b)
	if not Geometry2D.is_polygon_clockwise(polygon(HOTEL_POINTS)): basis.z=-basis.z; basis.x=-basis.x
	var sign_p := Vector3(b.x,10.45,b.y)-basis.x*5.1
	_local_box(world,roof,sign_p,Vector3(9.4,1.9,0.55),"manly_brick",basis)
	_label(roof,"HOTEL",sign_p+Vector3.UP*.52+basis.z*.32,.008,basis,Color("e9debb"))
	_label(roof,"STEYNE",sign_p+basis.z*.32,.022,basis,Color("e9debb"))
	_label(roof,"1859",sign_p+Vector3.DOWN*.64+basis.z*.34,.008,basis,Color("e9debb"))
	_steyne_public_details(world)

static func _beach_pines(world: Node3D) -> void:
	var count := 0
	var snapshot: Dictionary = world.map_snapshot
	var corso_polygon := polygon(CORSO_POINTS)
	for item: Dictionary in snapshot.get("trees",[]):
		var point := Vector2(item.point[0],item.point[1])
		if point.x<=6000 or point.y>=-5000: continue
		var p := Vector3(point.x,4.595,point.y)
		var tags: Dictionary = item.tags
		var species: String = str(tags.get("species","")).to_lower()
		var genus: String = str(tags.get("genus","")).to_lower()
		var on_corso := Geometry2D.is_point_in_polygon(point-Vector2(CORSO_CENTER.x,CORSO_CENTER.z),corso_polygon)
		if species.contains("araucaria") or genus=="araucaria" or str(tags.get("short_name","")).to_lower().contains("folk pine") or tags.get("leaf_type","")=="needleleaved":
			_pine(world,p,18.0+float(int(str(item.id).get_slice("/",1))%9))
		elif tags.get("family","")=="Arecaceae" or genus in ["washingtonia","phoenix","livistona"] or on_corso:
			_palm(world,p,11.0)
			if on_corso: _ring_seat(world,p)
		else:
			world._tree(p,1.25 if genus=="ficus" else 1.0)
		count+=1
	world.set_meta("manly_mapped_trees",count)

static func _pine(world: Node3D, p: Vector3, height: float) -> void:
	world._batch_cylinder(p+Vector3.UP*height*0.5,0.39,height,"bark")
	# Araucaria: clearly spaced horizontal branch whorls taper toward the crown.
	# Repeated flattened needle clusters follow the individual branches.
	for tier in range(11):
		var t := float(tier)/10.0
		var y := height*(0.26+0.72*t)
		var radius := lerpf(5.6,0.55,t)
		for arm in range(7):
			var angle := arm*TAU/7.0+tier*0.36
			var radial := Vector3(sin(angle),0,cos(angle))
			var direction := (radial+Vector3.UP*0.07).normalized()
			var basis := Basis.looking_at(direction,Vector3.UP)
			world._batch_box(p+Vector3.UP*y+radial*radius*0.50,Vector3(0.13,0.13,radius),"bark",basis)
			for spray in range(4):
				var dist := radius*(0.20+spray*0.22)
				var width := radius*(0.18-spray*0.026)
				var origin := p+Vector3.UP*(y+0.15+dist*0.05)+radial*dist
				if not world._batch_foliage.has("manly_pine"): world._batch_foliage["manly_pine"]=[]
				var foliage_basis := basis*Basis.from_scale(Vector3(width,0.35,radius*0.25))
				world._batch_foliage["manly_pine"].append(Transform3D(foliage_basis,origin))

static func _bus_stops(world: Node3D) -> void:
	for item: Array in [[-33.798861,151.2835032,"A",6388477486],[-33.7989238,151.2836342,"B",6388478985],[-33.7994474,151.2845739,"C",497623847]]:
		var p := geo(item[0],item[1],4.595)
		world._batch_cylinder(p+Vector3.UP*1.7,0.055,3.4,"steel")
		world._batch_box(p+Vector3.UP*3.35,Vector3(0.68,0.95,0.10),"manly_bus")
		world._batch_box(p+Vector3.UP*2.07,Vector3(0.50,1.13,0.12),"manly_white")
		_label(world,"B",p+Vector3(0,3.55,0.061),0.010)
		_label(world,"Manly Wharf\nStand "+item[2],p+Vector3(0,3.05,0.064),0.004)
		_label(world,"BUS STOP",p+Vector3(0,2.30,0.071),0.0035,Basis.IDENTITY,Color("354750"))

# Public-space details follow inspected references; fitting positions/heights are
# fitted to the mapped shell, not surveyed ticket-gate or tenancy plans.
static func _wharf_public_hall(world:Node3D,roof:StaticBody3D) -> void:
	var poly:=polygon(WHARF_POINTS)
	# Exposed timber roof boards and steel portals: DOCOMOMO describes ~8m bays.
	for z in range(-35,0,8):
		for x in [-18.0,10.0]:
			if not Geometry2D.is_point_in_polygon(Vector2(x,z),poly):continue
			world._structure_box("manly/wharf/public/portal/%s/%s"%[z,int(x)],WHARF_CENTER+Vector3(x,2.55,z),Vector3(.22,5.1,.22),"manly_steel",95000)
		_local_box(world,roof,Vector3(-4,4.85,z),Vector3(28,.34,.20),"manly_steel")
	for z in range(-36,0,2):
		_local_box(world,roof,Vector3(-4,5.01,z),Vector3(28,.07,1.94),"manly_ceiling")
		for x in [-16.0,-2.0,10.0]:_local_box(world,roof,Vector3(x,4.76,z),Vector3(.14,.10,.80),"manly_light")
	# Roof-edge white weatherboard fascia and a narrow glazed frieze above the
	# actual mapped arc entrance; columns/clear openings remain below 4.45m.
	for i in range(46,56):
		var a:Vector2=poly[i];var b:Vector2=poly[i+1];var basis:=_edge_basis(a,b)
		var mid:=Vector3((a.x+b.x)*.5,5.95,(a.y+b.y)*.5)
		_local_box(world,roof,mid,Vector3(a.distance_to(b)+.03,1.70,.22),"manly_white",basis)
		for y in [5.22,5.44,5.66,5.88,6.10,6.32,6.54]:
			_local_box(world,roof,Vector3(mid.x,y,mid.z)+basis.z*.12,Vector3(a.distance_to(b),.022,.018),"manly_frame",basis)
	# Public information/old-ticketing-side display; staff-only rooms are absent.
	var desk:StaticBody3D=world._structure_box("manly/wharf/public/information",WHARF_CENTER+Vector3(13,1.0,-25),Vector3(4.8,2.0,1.0),"manly_white",120000)
	_local_box(world,desk,Vector3(0,.27,-.52),Vector3(4.35,1.1,.06),"manly_glass")
	_label(desk,"INFORMATION",Vector3(0,.85,-.57),.007,Basis(Vector3.UP,PI),Color("344b41"))
	for side in [-1,1]:
		for z in [-29.0,-21.0,-13.0]:
			var at:=WHARF_CENTER+Vector3(-4+side*9,.44,z)
			var seat:StaticBody3D=world._structure_box("manly/wharf/public/seat/%s/%s"%[side,int(z)],at,Vector3(3.4,.16,.54),"manly_ceiling",45000)
			for x in [-1.3,1.3]:_local_box(world,seat,Vector3(x,-.22,0),Vector3(.09,.44,.38),"manly_steel")
			_local_box(world,seat,Vector3(0,.30,.25),Vector3(3.4,.50,.09),"manly_ceiling")
	var sign:StaticBody3D=world._structure_box("manly/wharf/public/wayfinding",WHARF_CENTER+Vector3(-4,3.65,-34),Vector3(8.0,.63,.10),"manly_ferry",40000)
	_label(sign,"FERRIES  /  WAITING HALL",Vector3(0,0,-.065),.0065,Basis(Vector3.UP,PI))
	_label(sign,"EXIT  /  THE CORSO",Vector3(0,0,.065),.0065)
	world.set_meta("manly_public_hall","Photo-informed public concourse only; boarding ramps, live ticketing and private tenancy interiors are not reconstructed")

static func _steyne_public_details(world:Node3D) -> void:
	var ground:StaticBody3D=world.structures["manly/steyne/floor/0"].node
	var upper:StaticBody3D=world.structures["manly/steyne/floor/1"].node
	for i in [1,2,4]:
		var a:=Vector2(HOTEL_POINTS[i][0],HOTEL_POINTS[i][1]);var b:=Vector2(HOTEL_POINTS[(i+1)%HOTEL_POINTS.size()][0],HOTEL_POINTS[(i+1)%HOTEL_POINTS.size()][1])
		var basis:=_edge_basis(a,b)
		if not Geometry2D.is_polygon_clockwise(polygon(HOTEL_POINTS)):basis.z=-basis.z;basis.x=-basis.x
		var length:float=a.distance_to(b);var mid:=Vector3((a.x+b.x)*.5,0,(a.y+b.y)*.5)
		# Small tile courses and raised surrounds seen in the 2022 restoration.
		for y in [.16,.31,.46]:_local_box(world,ground,mid+Vector3.UP*y+basis.z*.045,Vector3(length,.11,.025),"manly_tile",basis)
		for t in [.25,.70]:
			var q:Vector2=a.lerp(b,t);var p:=Vector3(q.x,5.2,q.y)
			_local_box(world,upper,p+basis.z*.90,Vector3(3.1,.23,1.9),"manly_brick",basis)
			_local_box(world,upper,p+Vector3.UP*.54+basis.z*1.75,Vector3(3.1,1.08,.20),"manly_brick",basis)
			for side in [-1,1]:_local_box(world,upper,p+Vector3.UP*.54+basis.x*side*1.45+basis.z*.85,Vector3(.20,1.08,1.8),"manly_brick",basis)
			_local_box(world,upper,p+Vector3.UP*3.50+basis.z*.9,Vector3(3.35,.18,2.15),"manly_white",basis)
			for side in [-1,1]:_local_box(world,upper,p+Vector3.UP*2.25+basis.x*side*1.42+basis.z*1.75,Vector3(.12,2.4,.12),"manly_frame",basis)

static func _public_bubblers(world:Node3D) -> void:
	for item:Array in [[1638701005,-33.798233,151.2860878],[1638695147,-33.7976369,151.2872951],[1638694159,-33.7972054,151.2878537]]:
		var p:=geo(item[1],item[2],4.595)
		var body:StaticBody3D=world._structure_box("manly/corso/bubbler/%s"%item[0],p+Vector3.UP*.52,Vector3(.32,1.04,.23),"manly_frame",45000)
		_local_box(world,body,Vector3(0,.51,.12),Vector3(.45,.08,.45),"manly_white")
		_local_box(world,body,Vector3(0,.565,.04),Vector3(.08,.05,.10),"manly_steel")
		_local_box(world,body,Vector3(0,.12,.13),Vector3(.24,.50,.04),"manly_ferry")
		body.set_meta("osm_node",item[0])

static func capture_views() -> Array:
	return [
		["manly_wharf_front_detail",WHARF_CENTER+Vector3(25,3,-96),WHARF_CENTER+Vector3(-10,6,-43)],
		["manly_wharf_public_hall",WHARF_CENTER+Vector3(-5,1.8,-31),WHARF_CENTER+Vector3(-4,3,-5)],
		["manly_corso_seating",CORSO_CENTER+Vector3(-74,2,47),CORSO_CENTER+Vector3(35,3,-20)],
		["manly_steyne_corso_detail",HOTEL_CENTER+Vector3(21,3,43),HOTEL_CENTER+Vector3(0,5,15)],
		["manly_steyne_beach_detail",HOTEL_CENTER+Vector3(55,4,10),HOTEL_CENTER+Vector3(12,5,-8)]
	]

static func walk_routes() -> Array[Dictionary]:
	var points:Array[Vector3]=[WHARF_CENTER+Vector3(-4,WHARF_FLOOR,-6),WHARF_CENTER+Vector3(-4,WHARF_FLOOR,-31),WHARF_CENTER+Vector3(-13,0,-44),WHARF_CENTER+Vector3(-17,0,-63)]
	# Existing mapped pedestrian links 135133937 and 7981630 lead across the
	# forecourt; the vehicle loop remains a real street, not newly paved over.
	for latlon:Array in [[-33.7992734,151.2845272],[-33.7992063,151.2846052],[-33.7990822,151.28476],[-33.7987861,151.2851497],[-33.7987456,151.285203],[-33.798600,151.285440],[-33.798425,151.285740]]:
		points.append(geo(latlon[0],latlon[1]))
	for latlon:Array in CORSO_ROUTE:points.append(geo(latlon[0],latlon[1],4.595))
	var reverse:Array[Vector3]=points.duplicate();reverse.reverse()
	return [{"name":"manly_wharf_hall_to_steyne","points":points},{"name":"manly_steyne_to_wharf_hall","points":reverse}]
