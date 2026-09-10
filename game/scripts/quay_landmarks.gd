extends RefCounted
## Real Circular Quay exteriors; see docs/QUAY_REFERENCE.md for precision limits.
const Geo=preload("res://scripts/city_landmarks.gd")
const QQT_HEIGHT:=206.0
const SALESFORCE_HEIGHT:=263.0

static func metadata() -> Array[Dictionary]:
	return [
		{"id":"quay_quarter","name":"Quay Quarter Tower · AMP / Deloitte","address":"50 Bridge Street, Sydney NSW 2000","center":QQT_CENTER,"lat":-33.86296098,"lon":151.21152674,"height_m":QQT_HEIGHT,"height_confidence":"206m architect-published; five mapped plan outlines retained, individual block and floor elevations inferred","footprint_confidence":"OSM geometry explicitly marked estimated; not a survey or BIM","osm_ids":[312373859,387782063,1120046335,1120046336,1120046337,1120046338],"source":"https://www.bvn.com.au/project/quay-quarter/"},
		{"id":"salesforce","name":"Salesforce Tower at Sydney Place","address":"180 George Street, Sydney NSW 2000","center":SALESFORCE_CENTER,"lat":-33.86237223,"lon":151.20863972,"height_m":SALESFORCE_HEIGHT,"height_confidence":"263m and 55 storeys published by developer; brace nodes and crown step inferred from architect elevations and actual photographs","footprint_confidence":"OSM mapped footprint; no survey precision claimed","osm_ids":[1116329930],"source":"https://www.sydneyplace.com/workplace/workplace/"}
	]

static func excluded_way_ids() -> Array[int]:
	return [312373859,387782063,1120046335,1120046336,1120046337,1120046338,1116329930]

static func footprints() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	for points: Array in [QQT_BASE_POINTS,QQT_PODIUM_POINTS,QQT_TWO_POINTS,QQT_THREE_POINTS,QQT_FOUR_POINTS,QQT_FIVE_POINTS,SALESFORCE_POINTS]:
		var poly:=Geo.polygon(points)
		var center:=SALESFORCE_CENTER if points==SALESFORCE_POINTS else QQT_CENTER
		for i in poly.size():poly[i]+=Vector2(center.x,center.z)
		result.append(poly)
	return result

static func build(world: Node3D) -> void:
	_materials(world)
	_quay_quarter(world)
	_salesforce(world)
	world.set_meta("quay_landmarks",metadata())

static func _materials(world: Node3D) -> void:
	world._mat("quay_ivory",Color("c7c7be"),0.60,0.25)
	world._mat("quay_bronze",Color("877567"),0.54,0.42)
	world._mat("quay_white",Color("e0e4e1"),0.45,0.36)
	world._mat("quay_steel",Color("697577"),0.52,0.58)
	world._mat("quay_concrete",Color("b2b3b0"),0.88)
	world._mat("quay_stone",Color("b4a58b"),0.9)
	world._mat("quay_dark",Color("29383d"),0.62,0.3)
	world._mat("quay_green",Color("486348"),0.96)
	Geo._glazing(world,"quay_qqt_glass",Color("526a74"),Color("485154"),Vector2(1.45,194.0/49.0),Vector2(0.035,0.12),12.0)
	Geo._glazing(world,"quay_sf_glass",Color("284650"),Color("39434a"),Vector2(1.48,235.0/54.0),Vector2(0.025,0.11),14.0)
	Geo._glazing(world,"quay_lobby",Color("5b7a7f"),Color("637072"),Vector2(2.2,6.0),Vector2(0.045,0.06))
	Geo._glazing(world,"quay_elevator",Color("405e69"),Color("889291"),Vector2(1.25,4.35),Vector2(0.025,0.04),14.0)

static func qqt_blocks() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var index:=0
	for points: Array in [QQT_BASE_POINTS,QQT_TWO_POINTS,QQT_THREE_POINTS,QQT_FOUR_POINTS,QQT_FIVE_POINTS]:
		var count:=9 if index==0 else 10
		var first:=0 if index==0 else 9+(index-1)*10
		result.append({"poly":Geo.polygon(points),"first":first,"count":count,"low":12.0+first*194.0/49.0,"high":12.0+(first+count)*194.0/49.0})
		index+=1
	return result

static func _quay_quarter(world: Node3D) -> void:
	var podium_poly:=Geo.polygon(QQT_PODIUM_POINTS)
	var podium: StaticBody3D=world._structure_mesh("quay/qqt/podium",Geo.prism(podium_poly,4.8,8.0),QQT_CENTER,"quay_stone",240000.0)
	Geo._detail(world,podium,Geo.prism(podium_poly,7.8,8.0),"quay_ivory")
	var n:=0
	for sample in Geo._perimeter_samples(podium_poly,10.0):
		world._structure_box("quay/qqt/podium_column/%02d"%n,QQT_CENTER+sample.position+Vector3.UP*2.4,Vector3(0.6,4.8,0.6),"quay_stone",95000)
		n+=1
	var lobby: StaticBody3D=world._structure_mesh("quay/qqt/lobby",Geo.prism(Geo.polygon(QQT_BASE_POINTS),0.0,12.0),QQT_CENTER,"quay_lobby",250000)
	var lobby_frames:=_surface()
	for sample in Geo._perimeter_samples(Geo.polygon(QQT_BASE_POINTS),4.5):
		Geo._append_box(lobby_frames,sample.position+Vector3.UP*6.0,Vector3(0.16,12.0,0.32),sample.basis)
	Geo._commit_detail(world,lobby,lobby_frames,"quay_bronze")
	var block_index:=0
	for block in qqt_blocks():
		var poly: PackedVector2Array=block.poly
		for floor_index in range(block.count):
			var low: float=block.low+floor_index*194.0/49.0
			var high:=low+194.0/49.0
			var roof_floor: bool=block_index==4 and floor_index==block.count-1
			var body: StaticBody3D=world._structure_mesh("quay/qqt/block/%d/floor/%02d"%[block_index,floor_index],Geo.prism(poly,low,high-2.3 if roof_floor else high),QQT_CENTER,"quay_qqt_glass",190000.0)
			body.set_meta("architectural_block",block_index)
			var frames:=_surface()
			var bronze:=_surface()
			for edge_index in poly.size():
				var a:=poly[edge_index]
				var b:=poly[(edge_index+1)%poly.size()]
				var length:=a.distance_to(b)
				if length<2.0:continue
				var outward:=_outward(poly,a,b)
				# The architect's deep staggered frames alternate direction by
				# village. They are geometry, not a randomly coloured facade.
				_edge_box(frames,a,b,high-0.22,0.34,1.08,outward,0.36)
				_edge_box(bronze,a,b,high-0.46,0.08,0.91,outward,0.37)
				var bays:=maxi(1,roundi(length/5.8))
				var pitch:=length/float(bays)
				var direction:=1.0 if block_index%2==0 else -1.0
				var offset:=fposmod(float(floor_index)*direction*0.5,1.0)
				for bay_index in range(bays+1):
					var t:=(float(bay_index)+offset)/float(bays)
					if t>1.0:continue
					var p:=a.lerp(b,t)
					Geo._append_box(frames,Vector3(p.x,(low+high)*0.5,p.y)+outward*0.36,Vector3(0.22,high-low,1.08),Basis.looking_at(-outward,Vector3.UP))
					var start:=clampf(t+direction*pitch/length*0.035,0.0,1.0)
					var finish:=clampf(t+direction*pitch/length*0.48,0.0,1.0)
					if absf(start-finish)>0.005:_edge_box(frames,a.lerp(b,start),a.lerp(b,finish),high-0.08,0.16,1.20,outward,0.45)
			Geo._commit_detail(world,body,frames,"quay_ivory")
			Geo._commit_detail(world,body,bronze,"quay_bronze")
			if floor_index==block.count-1:
				# Thick folded perimeter reveals each cantilevered volume.
				var border:=_surface()
				for i in poly.size():
					var a:=poly[i];var b:=poly[(i+1)%poly.size()]
					_edge_box(border,a,b,high-0.42,0.83,1.28,_outward(poly,a,b),0.26)
				Geo._commit_detail(world,body,border,"quay_ivory")
				if block_index<4:_terrace(world,body,poly,qqt_blocks()[block_index+1].poly,high)
		block_index+=1
	# Recessed crown plant, behind the highest frame: no generic roof spike.
	var roof_poly:=Geo.polygon(QQT_FIVE_POINTS)
	world._structure_mesh("quay/qqt/roof_parapet",_ring_mesh(roof_poly,0.945,203.7,206.0),QQT_CENTER,"quay_ivory",150000)
	var crown: StaticBody3D=world._structure_mesh("quay/qqt/crown",Geo.prism(Geo._scaled(roof_poly,0.72),204.4,205.9),QQT_CENTER,"quay_dark",160000)
	var crown_ribs:=_surface()
	for sample in Geo._perimeter_samples(Geo._scaled(roof_poly,0.80),1.6):
		Geo._append_box(crown_ribs,sample.position+Vector3.UP*205.45,Vector3(0.08,1.1,0.22),sample.basis)
	Geo._commit_detail(world,crown,crown_ribs,"quay_steel")

static func _terrace(world: Node3D, body: StaticBody3D, lower: PackedVector2Array, upper: PackedVector2Array, height: float) -> void:
	var rails:=_surface()
	var planting:=_surface()
	var supported:=false
	for sample in Geo._perimeter_samples(lower,2.2):
		var p: Vector3=sample.position-sample.outward*0.85
		if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),upper):continue
		# Only uncovered ledges get guards and planting; no rails inside the
		# next village or floating along a facade where no terrace exists.
		Geo._append_box(rails,p+Vector3.UP*(height+0.5),Vector3(0.045,1.0,0.045),sample.basis)
		Geo._append_box(rails,p+Vector3.UP*(height+1.0),Vector3(2.16,0.045,0.045),sample.basis)
		Geo._append_box(planting,p-sample.outward*0.9+Vector3.UP*(height+0.16),Vector3(1.5,0.32,0.8),sample.basis)
		supported=true
	if supported:
		Geo._commit_detail(world,body,rails,"quay_steel")
		Geo._commit_detail(world,body,planting,"quay_green")

static func salesforce_branches() -> Array[PackedVector2Array]:
	var paths: Array[PackedVector2Array]=[]
	# x is fraction of a northern face from the twin apex columns; y is
	# metres. Six unequal branches are traced from the Foster north elevation.
	for heights: Array in [[0.0,32.0,44.0],[31.0,59.0,72.0],[59.0,87.0,99.0],[86.0,123.0,139.0],[120.0,174.0,191.0],[168.0,230.0,248.0]]:
		paths.append(PackedVector2Array([Vector2(0,heights[0]),Vector2(0.30,heights[1]),Vector2(0.56,heights[2]),Vector2(1.0,heights[2])]))
	return paths

static func _salesforce(world: Node3D) -> void:
	var poly:=Geo.polygon(SALESFORCE_POINTS)
	var lobby: StaticBody3D=world._structure_mesh("quay/salesforce/lobby",Geo.prism(poly,0.0,14.0),SALESFORCE_CENTER,"quay_lobby",260000)
	_salesforce_detail(world,lobby,0.0,14.0,poly)
	for i in range(54):
		var low:=14.0+i*235.0/54.0
		var high:=low+235.0/54.0
		var body: StaticBody3D=world._structure_mesh("quay/salesforce/floor/%02d"%i,Geo.prism(poly,low,high),SALESFORCE_CENTER,"quay_sf_glass",210000)
		_salesforce_detail(world,body,low,high,poly)
	# The real roof has a raised, glazed crown; the outer shaded wings end
	# below it. The local proportions here are photo-derived, not surveyed.
	var back:=poly[13].lerp(poly[6],0.5)
	var crown_poly:=PackedVector2Array([poly[0],poly[2],poly[2].lerp(poly[4],0.63),back.lerp(poly[6],0.28),back.lerp(poly[13],0.28),poly[0].lerp(poly[14],0.63)])
	var crown: StaticBody3D=world._structure_mesh("quay/salesforce/crown",Geo.prism(crown_poly,249.0,261.5),SALESFORCE_CENTER,"quay_sf_glass",180000)
	world._structure_mesh("quay/salesforce/roof_parapet",_ring_mesh(crown_poly,0.94,261.5,263.0),SALESFORCE_CENTER,"quay_sf_glass",130000)
	var ribs:=_surface()
	for sample in Geo._perimeter_samples(crown_poly,2.0):
		Geo._append_box(ribs,sample.position+Vector3.UP*256.0,Vector3(0.08,14.0,0.17),sample.basis)
	for p in [poly[0],poly[2]]:Geo._append_box(ribs,Vector3(p.x,256.0,p.y),Vector3(0.9,14.0,0.9),Basis.IDENTITY)
	Geo._commit_detail(world,crown,ribs,"quay_white")
	var plant_poly:=Geo._scaled(crown_poly,0.65)
	Geo._detail(world,crown,Geo.prism(plant_poly,261.5,262.7),"quay_dark")

static func _salesforce_detail(world: Node3D, body: StaticBody3D, low: float, high: float, poly: PackedVector2Array) -> void:
	var branches:=_surface()
	var shades:=_surface()
	var concrete:=_surface()
	var elevator:=_surface()
	for face: Array in [[poly[0],poly[14]],[poly[2],poly[4]]]:
		var a: Vector2=face[0];var b: Vector2=face[1]
		var outward:=Vector3((a.y+b.y)*0.5,0,-(a.x+b.x)*0.5)
		var tangent:=(b-a).normalized()
		outward=Vector3(tangent.y,0,-tangent.x)
		if outward.dot(Vector3(a.x+b.x,0,a.y+b.y))<0.0:outward=-outward
		# Each branch is clipped to its owning floor for consistent damage.
		for path in salesforce_branches():
			for n in range(path.size()-1):
				var clipped:=_clip_y(path[n],path[n+1],low,high)
				if clipped.size()!=2:continue
				var p:=a.lerp(b,clipped[0].x)
				var q:=a.lerp(b,clipped[1].x)
				_facade_beam(branches,Vector3(p.x,clipped[0].y,p.y)+outward*0.65,Vector3(q.x,clipped[1].y,q.y)+outward*0.65,outward,0.95,0.5)
		Geo._append_box(branches,Vector3(a.x,(low+high)*0.5,a.y)+outward*0.46,Vector3(1.1,high-low,0.70),Basis.looking_at(-outward,Vector3.UP))
		if low>=14:
			var fraction:=_shade_cutoff(high)
			_edge_box(shades,a.lerp(b,fraction),b,high-0.36,0.24,0.9,outward,0.31)
			_edge_box(shades,a,b,high-0.36,0.11,0.15,outward,0.06)
		# Fine structural pins run behind the horizontal sunshade blades.
		for t in [0.28,0.56,0.98]:
			var p:=a.lerp(b,t)
			Geo._append_box(shades,Vector3(p.x,(low+high)*0.5,p.y)+outward*0.12,Vector3(0.06,high-low,0.08),Basis.looking_at(-outward,Vector3.UP))
	# Four pale core piers book-end three clear lift banks on the south
	# facade, respecting the mapped diagonal rear edge of the half-hexagon.
	var a:=poly[13];var b:=poly[6]
	var outward:=Vector3(-(b-a).y,0,(b-a).x).normalized()
	var length:=a.distance_to(b)
	for pi in range(4):
		var t:=float(pi)/3.0
		var width:=0.105
		var start:=clampf(t-width*0.5,0.0,1.0)
		var finish:=clampf(t+width*0.5,0.0,1.0)
		_edge_box(concrete,a.lerp(b,start),a.lerp(b,finish),(low+high)*0.5,high-low,0.65,outward,0.17)
		var joints:=int((high-low)/1.1)
		for j in range(joints):
			_edge_box(shades,a.lerp(b,start),a.lerp(b,finish),low+(j+1)*1.1,0.025,0.04,outward,0.52)
	for lift in range(3):
		var start:=(float(lift)/3.0)+0.058
		var finish:=(float(lift+1)/3.0)-0.058
		_edge_box(elevator,a.lerp(b,start),a.lerp(b,finish),(low+high)*0.5,high-low-0.015,0.08,outward,0.51)
		for car in range(3):
			var t:=lerpf(start,finish,(float(car)+0.5)/3.0)
			var p:=a.lerp(b,t)
			Geo._append_box(shades,Vector3(p.x,(low+high)*0.5,p.y)+outward*0.58,Vector3(0.055,high-low,0.10),Basis.looking_at(-outward,Vector3.UP))
	# Unbraced east/west end faces have ordinary thin floor-edge blades.
	for edge: Array in [[4,6],[13,14]]:
		var p:=poly[edge[0]];var q:=poly[edge[1]]
		_edge_box(shades,p,q,high-0.33,0.20,0.67,_outward(poly,p,q),0.19)
	Geo._commit_detail(world,body,branches,"quay_white")
	Geo._commit_detail(world,body,shades,"quay_steel")
	Geo._commit_detail(world,body,concrete,"quay_concrete")
	Geo._commit_detail(world,body,elevator,"quay_elevator")

static func _shade_cutoff(height: float) -> float:
	for path in salesforce_branches():
		if height>path[2].y:continue
		for i in range(2):
			if height<=path[i+1].y:
				return clampf(lerpf(path[i].x,path[i+1].x,(height-path[i].y)/(path[i+1].y-path[i].y)),0.0,0.56)
	return 0.56

static func _clip_y(a: Vector2, b: Vector2, low: float, high: float) -> PackedVector2Array:
	if absf(a.y-b.y)<0.00001:
		return PackedVector2Array([a,b]) if a.y>=low and a.y<high else PackedVector2Array()
	if b.y<=low or a.y>=high:return PackedVector2Array()
	return PackedVector2Array([a.lerp(b,clampf((low-a.y)/(b.y-a.y),0.0,1.0)),a.lerp(b,clampf((high-a.y)/(b.y-a.y),0.0,1.0))])

static func _facade_beam(surface: SurfaceTool, a: Vector3, b: Vector3, normal: Vector3, width: float, depth: float) -> void:
	var delta:=b-a
	if delta.length()<0.001:return
	var right:=normal.cross(delta).normalized()
	var up:=delta.normalized()
	Geo._append_box(surface,(a+b)*0.5,Vector3(width,delta.length(),depth),Basis(right,up,right.cross(up)))

static func _edge_box(surface: SurfaceTool, a: Vector2, b: Vector2, y: float, height: float, depth: float, outward: Vector3, offset: float) -> void:
	if a.distance_to(b)<0.001:return
	Geo._append_box(surface,Vector3((a.x+b.x)*0.5,y,(a.y+b.y)*0.5)+outward*offset,Vector3(a.distance_to(b),height,depth),Basis.looking_at(-outward,Vector3.UP))

static func _outward(poly: PackedVector2Array, a: Vector2, b: Vector2) -> Vector3:
	return Vector3(b.y-a.y,0,a.x-b.x).normalized()*Geo._area_sign(poly)

static func _surface() -> SurfaceTool:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface

static func _ring_mesh(outline: PackedVector2Array, inset_scale: float, low: float, high: float) -> ArrayMesh:
	var surface:=_surface()
	var inside:=Geo._scaled(outline,inset_scale)
	for i in outline.size():
		var next: int=(i+1)%outline.size()
		var a:=outline[i];var b:=outline[next]
		var c:=inside[next];var d:=inside[i]
		for y in [low,high]:
			var normal:=Vector3.DOWN if y==low else Vector3.UP
			Geo._triangle(surface,Vector3(a.x,y,a.y),Vector3(b.x,y,b.y),Vector3(c.x,y,c.y),normal,a,b,c)
			Geo._triangle(surface,Vector3(a.x,y,a.y),Vector3(c.x,y,c.y),Vector3(d.x,y,d.y),normal,a,c,d)
		for edge: Array in [[a,b,_outward(outline,a,b)],[d,c,-_outward(inside,d,c)]]:
			var p: Vector2=edge[0];var q: Vector2=edge[1];var normal: Vector3=edge[2]
			Geo._triangle(surface,Vector3(p.x,low,p.y),Vector3(q.x,low,q.y),Vector3(q.x,high,q.y),normal,Vector2(0,low),Vector2(p.distance_to(q),low),Vector2(p.distance_to(q),high))
			Geo._triangle(surface,Vector3(p.x,low,p.y),Vector3(q.x,high,q.y),Vector3(p.x,high,p.y),normal,Vector2(0,low),Vector2(p.distance_to(q),high),Vector2(0,high))
	return surface.commit()

const QQT_CENTER:=Vector3(94.871112,4.5,329.616717)
const QQT_BASE_POINTS:=[
	[-27.169632,30.202919],
	[-26.763072,30.470087],
	[-26.227152,30.559143],
	[3.747408,33.219691],
	[13.920648,31.627815],
	[18.512928,28.154631],
	[25.452168,-36.544553],
	[26.034288,-41.976969],
	[-22.022952,-20.403153],
	[-27.391392,29.178775],
	[-27.372912,29.735375],
]

const QQT_PODIUM_POINTS:=[
	[-22.022952,-20.403153],
	[26.034288,-41.976969],
	[27.799128,-42.255269],
	[28.519848,-47.398253],
	[26.995248,-47.520705],
	[23.622648,-47.787873],
	[22.227408,-48.244285],
	[21.220248,-49.301825],
	[20.915328,-50.459553],
	[21.164808,-51.761997],
	[21.950208,-53.064441],
	[23.280768,-53.543117],
	[29.490048,-54.422545],
	[30.312408,-60.367033],
	[31.079328,-65.921901],
	[16.433928,-66.645481],
	[15.352848,-63.361541],
	[14.872368,-62.393057],
	[14.114688,-61.669477],
	[13.264608,-61.446837],
	[12.220488,-61.591553],
	[11.481288,-62.181549],
	[11.120928,-63.027581],
	[11.019288,-66.934913],
	[-3.653832,-67.402457],
	[-4.938192,-62.504377],
	[-5.437152,-61.446837],
	[-6.120912,-60.912501],
	[-7.072632,-60.856841],
	[-7.839552,-61.201933],
	[-8.412432,-62.025701],
	[-10.223472,-68.170565],
	[-23.113272,-68.426601],
	[-23.870952,-54.734241],
	[-21.570192,-48.299945],
	[-21.477792,-47.654289],
	[-21.523992,-46.952973],
	[-21.773472,-46.218261],
	[-22.170792,-45.650529],
	[-22.669752,-45.338833],
	[-24.628632,-44.626385],
	[-26.282592,-28.061969],
	[-22.909992,-24.989537],
	[-23.214912,-21.816917],
	[-26.994072,-20.013533],
	[-31.734192,34.243835],
	[-31.530912,35.011943],
	[-31.161312,35.646467],
	[-30.745512,36.136275],
	[-30.154152,36.525895],
	[-29.451912,36.737403],
	[-28.601832,36.704007],
	[3.128328,33.831951],
	[3.747408,33.219691],
	[-26.227152,30.559143],
	[-26.763072,30.470087],
	[-27.169632,30.202919],
	[-27.372912,29.735375],
	[-27.391392,29.178775],
]

const QQT_TWO_POINTS:=[
	[-27.169632,30.202919],
	[-26.763072,30.470087],
	[-26.227152,30.559143],
	[3.747408,33.219691],
	[13.920648,31.627815],
	[18.512928,28.154631],
	[25.452168,-36.544553],
	[-21.579432,-24.499729],
	[-22.022952,-20.403153],
	[-27.391392,29.178775],
	[-27.372912,29.735375],
]

const QQT_THREE_POINTS:=[
	[13.920648,31.627815],
	[17.579688,-4.061377],
	[19.473888,-22.495969],
	[20.314728,-30.622329],
	[-21.052752,-29.386677],
	[-21.579432,-24.499729],
	[-22.022952,-20.403153],
	[-27.391392,29.178775],
	[-27.372912,29.735375],
	[-27.169632,30.202919],
	[-26.763072,30.470087],
	[-26.227152,30.559143],
	[3.747408,33.219691],
]

const QQT_FOUR_POINTS:=[
	[-27.169632,30.202919],
	[-26.763072,30.470087],
	[-26.227152,30.559143],
	[3.747408,33.219691],
	[13.920648,31.627815],
	[17.579688,-4.061377],
	[19.473888,-22.495969],
	[-20.128752,-37.891525],
	[-21.052752,-29.386677],
	[-21.579432,-24.499729],
	[-22.022952,-20.403153],
	[-27.391392,29.178775],
	[-27.372912,29.735375],
]

const QQT_FIVE_POINTS:=[
	[-27.169632,30.202919],
	[-26.763072,30.470087],
	[-26.227152,30.559143],
	[3.747408,33.219691],
	[13.920648,31.627815],
	[17.579688,-4.061377],
	[-19.555872,-43.179225],
	[-20.128752,-37.891525],
	[-21.052752,-29.386677],
	[-21.579432,-24.499729],
	[-22.022952,-20.403153],
	[-27.391392,29.178775],
	[-27.372912,29.735375],
]

const SALESFORCE_CENTER:=Vector3(-171.890096,4.5,264.077195)
const SALESFORCE_POINTS:=[
	[-13.815424,-17.648111],
	[-10.720024,-14.954167],
	[-10.396624,-17.826223],
	[-8.788864,-17.659243],
	[36.810536,-13.173047],
	[35.332136,-0.215399],
	[34.713056,5.294941],
	[24.715376,7.732849],
	[14.726936,10.170757],
	[4.738496,12.608665],
	[-5.249944,15.046573],
	[-18.370744,18.285985],
	[-24.931144,19.900125],
	[-31.491544,21.514265],
	[-34.272784,5.862673],
	[-28.774984,-0.460303],
	[-24.931144,-4.868575],
	[-22.833664,-7.284219],
	[-20.736184,-9.699863],
	[-17.271184,-13.673987],
]
