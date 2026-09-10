extends RefCounted
## Public architectural reconstruction; mapped OSM footprint, public venue plans
## and completed-building photographs. This is not a complete BIM or event fitout.
const Geo = preload("res://scripts/city_landmarks.gd")
const DATA = preload("res://assets/icc_geometry.json")
const GROUND := 4.5
const EAST := Vector3(0.9789748, 0, -0.2039948)
const SOUTH := Vector3(0.2039948, 0, 0.9789748)
const FRAME := Basis(EAST, Vector3.UP, SOUTH)
const CONVENTION := Vector3(-1052.659, GROUND, 1497.201)
const EXHIBITION := Vector3(-982.25, GROUND, 1724.131)
const THEATRE := Vector3(-905.81, GROUND, 1881.019)
const THEATRE_HALL_HEIGHT := 37.1
const THEATRE_DOOR_WIDTH := 6.0
const THEATRE_DOOR_HEIGHT := 3.6
const HEIGHTS := {"convention": 44.0, "exhibition": 36.0, "theatre": 38.0}

static func metadata() -> Array[Dictionary]:
	return [
		{"id":"icc_convention", "name":"ICC Sydney · Convention Centre", "address":"14 Darling Drive · northern venue", "center":CONVENTION, "arrival":point(CONVENTION,Vector3(72,0,10)), "building_center":CONVENTION, "height_m":44.0, "interior":"Ground foyer, registration, timber stair and mezzanine; other rooms closed", "confidence":"OSM outline + architect photos + public Ground/Level 1 plans; vertical elevations estimated", "source":"https://iccsydney.com.au/organisers/organiser-toolkit/floor-plans/"},
		{"id":"icc_exhibition", "name":"ICC Sydney · Exhibition Centre", "address":"14 Darling Drive · Tumbalong Boulevard", "center":EXHIBITION, "arrival":point(EXHIBITION,Vector3(72,0,-75)), "building_center":EXHIBITION, "height_m":36.0, "interior":"Ground entry, stairs, Level 1 foyer and four lower exhibition halls; upper areas closed", "confidence":"OSM outline + architect photos + public Level 1 plan; 10.5m hall clear height; floor elevations estimated", "source":"https://iccsydney.com.au/organisers/organiser-toolkit/floor-plans/"},
		{"id":"tiktok_entertainment", "name":"TikTok Entertainment Centre · theatre", "address":"14 Darling Drive · Moriarty Walk / Tumbalong Boulevard", "center":THEATRE, "arrival":point(THEATRE,Vector3(35,0,-51)), "building_center":THEATRE, "height_m":38.0, "interior":"Public foyer, side aisle, fan auditorium, stage and three raked seating tiers; simplified seat count", "confidence":"OSM outline + public seating plan + Sydney Symphony interior photo; tier elevations estimated", "source":"https://iccsydney.com.au/Theatre-Seating-Plan"}
	]

static func excluded_way_ids() -> Array[int]:
	return [501890909,488447518,488447519,23646745,1116329939,487371417,1098953175]

static func footprints() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for part: Dictionary in DATA.data.parts:
		if part.id == "way/501890909": continue
		var poly := Geo.polygon(part.outline)
		for i in poly.size(): poly[i] += Vector2(part.center[0],part.center[1])
		result.append(poly)
	return result

static func point(origin: Vector3, local: Vector3) -> Vector3:
	return origin + FRAME * local

static func _part(id: int) -> Dictionary:
	for p: Dictionary in DATA.data.parts:
		if p.id == "way/%d" % id: return p
	return {}

static func _poly(id: int, origin: Vector3) -> PackedVector2Array:
	var part := _part(id)
	var poly := PackedVector2Array()
	for p: Array in part.outline:
		var delta := Vector3(p[0]+part.center[0],GROUND,p[1]+part.center[1])-origin
		poly.append(Vector2(delta.dot(EAST),delta.dot(SOUTH)))
	return poly

static func build(world: Node3D) -> void:
	if world.has_meta("icc_landmarks"): return
	_materials(world)
	_convention(world)
	_exhibition(world)
	_theatre(world)
	world.set_meta("icc_landmarks",metadata())
	world.set_meta("icc_public_routes",routes())

static func _materials(w: Node3D) -> void:
	for row: Array in [["stone","c7c7bb"],["floor","b4b4a9"],["wood","b88248"],["wood_light","d1a36c"],["dark","262b30"],["black","111820"],["metal","adb7ba"],["red","bd3f42"],["seat_grey","8e9494"],["seat_dark","555c62"],["cream","d9cfb7"],["white","ebeee5"],["plant","54705a"],["screen","315268"],["stripe","d8be72"],["blue","203c76"],["light","fff0cd"],["carpet","737c7e"]]:
		w._mat("icc_"+row[0],Color(row[1]),0.76 if row[0] not in ["metal","screen"] else 0.38)
	w._mat("icc_glass",Color(0.34,0.53,0.59,0.30),0.24,0.20)
	var glass: StandardMaterial3D = w.materials.icc_glass
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	var floor_shader:=Shader.new()
	floor_shader.code="""shader_type spatial;
varying vec3 p;
void vertex(){ p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 vec2 uv=p.xz/vec2(1.2,0.6); vec2 d=min(fract(uv),1.0-fract(uv));
 vec2 aa=max(fwidth(uv),vec2(0.001));
 float joint=1.0-smoothstep(0.003-aa.x,0.003+aa.x,d.x)*smoothstep(0.004-aa.y,0.004+aa.y,d.y);
 float n=fract(sin(dot(floor(uv),vec2(31.7,43.1)))*17519.5);
 ALBEDO=mix(vec3(0.53,0.53,0.48)*(0.97+n*0.055),vec3(0.36,0.36,0.33),joint*0.45); ROUGHNESS=0.65; }
"""
	var floor_mat:=ShaderMaterial.new();floor_mat.shader=floor_shader;w.materials.icc_floor=floor_mat
	w.materials.icc_light.emission_enabled=true;w.materials.icc_light.emission=Color("fbe9c7");w.materials.icc_light.emission_energy_multiplier=0.75
	Geo._glazing(w,"icc_crystal",Color("456f7c"),Color("a6b4b9"),Vector2(2.3,4.3),Vector2(0.075,0.075))

static func _box(w: Node3D, id: String, o: Vector3, p: Vector3, size: Vector3, key: String, basis: Basis=Basis.IDENTITY) -> StaticBody3D:
	return w._structure_box("icc/"+id,point(o,p),size,"icc_"+key,180000.0,FRAME*basis)

static func _slab(w: Node3D, id: String, o: Vector3, poly: PackedVector2Array, low: float, high: float, key: String) -> StaticBody3D:
	return w._structure_mesh("icc/"+id,Geo.prism(poly,low,high),o,"icc_"+key,220000.0,FRAME)

static func _start() -> Dictionary:
	return {}

static func _detail(batch: Dictionary, key: String, p: Vector3, size: Vector3, basis: Basis=Basis.IDENTITY) -> void:
	if not batch.has(key):
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); batch[key]=st
	Geo._append_box(batch[key],p,size,basis)

static func _triangle(batch: Dictionary, key: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Keep unindexed sheet vertices separate from indexed BoxMesh append batches.
	key += "_sheet"
	if not batch.has(key):
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); batch[key]=st
	var st: SurfaceTool=batch[key]
	var normal := (b-a).cross(c-a).normalized()
	# Clockwise front faces; folded cladding is a thin two-sided sheet.
	for side in [1.0,-1.0]:
		Geo._triangle(st,a,b,c,normal*side,Vector2(a.x,a.y),Vector2(b.x,b.y),Vector2(c.x,c.y))

static func _flush(w: Node3D, parent: Node3D, batch: Dictionary) -> void:
	# One GPU mesh per material, not one mesh per seat, fin or tread.
	for key: String in batch:
		var mesh := MeshInstance3D.new(); mesh.mesh=batch[key].commit()
		mesh.material_override=w.materials["icc_"+key.trim_suffix("_sheet")]; parent.add_child(mesh)

static func _root(w: Node3D, name: String, o: Vector3) -> Node3D:
	var node := Node3D.new();node.name=name;node.transform=Transform3D(FRAME,o);w.add_child(node);return node

static func _text(w: Node3D, parent: Node3D, value: String, p: Vector3, size: float, yaw: float=90.0) -> void:
	var label := Label3D.new();label.text=value;label.position=p;label.rotation_degrees.y=yaw
	label.font_size=64;label.pixel_size=size/64.0;label.modulate=Color("f1f2e9")
	label.outline_size=5;label.outline_modulate=Color("17212c");label.no_depth_test=false
	label.double_sided=false;label.visibility_range_end=700;parent.add_child(label)

static func _edge_wall(w: Node3D, id: String, o: Vector3, a: Vector2, b: Vector2, low: float, high: float, key: String, width: float=0.28) -> void:
	if b.distance_to(a)<0.05 or high-low<0.05:return
	var d: Vector2=(b-a).normalized()
	var basis := Basis(Vector3(d.x,0,d.y),Vector3.UP,Vector3(-d.y,0,d.x))
	if key=="crystal":
		# Physical-metre UVs preserve window rhythm on arbitrarily long edges.
		var n:=Vector2(-d.y,d.x)*width*0.5
		var strip:=PackedVector2Array([a+n,b+n,b-n,a-n])
		_slab(w,id,o,strip,low,high,key)
	else:
		_box(w,id,o,Vector3((a.x+b.x)*0.5,(low+high)*0.5,(a.y+b.y)*0.5),Vector3(a.distance_to(b),high-low,width),key,basis)

static func _shell(w: Node3D,id: String,o: Vector3,poly: PackedVector2Array,height: float,doors: Array,style: String,batch: Dictionary) -> void:
	for i in poly.size():
		var a:=poly[i];var b:=poly[(i+1)%poly.size()]
		var door: Dictionary={}
		for candidate: Dictionary in doors:
			if candidate.edge==i:door=candidate
		var lower:=5.5 if style=="crystal" else 7.0
		if not door.is_empty():
			var half: float=door.width/(a.distance_to(b)*2)
			var ta: float=maxf(0,door.t-half);var tb: float=minf(1,door.t+half)
			_edge_wall(w,id+"/wall/%d/a"%i,o,a,a.lerp(b,ta),0,lower,"glass")
			_edge_wall(w,id+"/wall/%d/b"%i,o,a.lerp(b,tb),b,0,lower,"glass")
			_edge_wall(w,id+"/wall/%d/lintel"%i,o,a.lerp(b,ta),a.lerp(b,tb),4.2,lower,"glass")
		else:
			_edge_wall(w,id+"/wall/%d/ground"%i,o,a,b,0,lower,"glass" if (a.x+b.x)*0.5>20 else "dark")
		_edge_wall(w,id+"/wall/%d/upper"%i,o,a,b,lower,height,"crystal" if style=="crystal" else ("glass" if (a.x+b.x)*0.5>40 else "dark"))
		var d: Vector2=(b-a).normalized();var normal:=Vector2(d.y,-d.x)
		var basis:=Basis(Vector3(d.x,0,d.y),Vector3.UP,Vector3(-d.y,0,d.x))
		var count:=maxi(1,ceili(a.distance_to(b)/3.1))
		for j in range(count+1):
			var p:=a.lerp(b,float(j)/count)
			_detail(batch,"metal",Vector3(p.x,height*0.5,p.y),Vector3(0.10,height,0.16),basis)
		if style=="crystal":
			# Alternating diagonal silver fins recreate the photograph's crystalline
			# light/dark facets without using a closed solid building volume.
			for y in [9.5,18.1,26.7,35.3]:
				for j in range(count):
					var p:=a.lerp(b,(float(j)+0.5)/count)
					var lean:=Basis(Vector3.RIGHT,deg_to_rad(10 if (i+j)%2==0 else -10))
					_detail(batch,"metal",Vector3(p.x,y,p.y),Vector3(0.23,7.9,0.65),basis*lean)
		for y in [lower,height]:
			_detail(batch,"metal",Vector3((a.x+b.x)*0.5,y,(a.y+b.y)*0.5),Vector3(a.distance_to(b),0.20,0.34),basis)

static func _stairs(w: Node3D,id: String,o: Vector3,a: Vector3,b: Vector3,width: float,batch: Dictionary,key: String="wood") -> void:
	var delta:=b-a;var horizontal:=Vector3(delta.x,0,delta.z);var along:=delta.normalized()
	var right:=Vector3(horizontal.z,0,-horizontal.x).normalized()
	var up:=along.cross(right).normalized();var basis:=Basis(right,up,along)
	# Smooth inclined Box support avoids physics seams; visible risers remain.
	_box(w,id+"/ramp",o,(a+b)*0.5-up*0.15,Vector3(width,0.30,delta.length()+0.02),key,basis)
	var steps:=ceili(absf(delta.y)/0.17)
	var flat_basis:=Basis(right,Vector3.UP,horizontal.normalized())
	for i in range(steps):
		var p:=a.lerp(b,(i+0.5)/steps)
		_detail(batch,key,p-Vector3.UP*0.09,Vector3(width,0.16,horizontal.length()/steps+0.012),flat_basis)
		_detail(batch,"stripe",p+horizontal.normalized()*horizontal.length()/steps*0.45,Vector3(width,0.018,0.035),flat_basis)
	for side in [-1,1]:
		_detail(batch,"metal",(a+b)*0.5+right*(width*0.5+0.12)*side+Vector3.UP*1.05,Vector3(0.055,0.055,delta.length()),basis)
		for i in range(steps/5+1):
			var p: Vector3=a.lerp(b,minf(1,float(i)*5/steps))+right*(width*0.5+0.12)*side
			_detail(batch,"metal",p+Vector3.UP*0.52,Vector3(0.055,1.05,0.055))

static func _convention(w: Node3D) -> void:
	var root:=_root(w,"ICCConventionDetails",CONVENTION);var batch:=_start()
	var poly:=_poly(488447518,CONVENTION)
	_shell(w,"convention",CONVENTION,poly,39.0,[{"edge":17,"t":0.50,"width":10.0}],"crystal",batch)
	_slab(w,"convention/floor",CONVENTION,poly,-0.215,0.035,"floor")
	_slab(w,"convention/roof",CONVENTION,poly,38.8,39.4,"cream")
	# Faceted roof crown visible in the architects' north-front photographs.
	for i in poly.size():
		var a:=poly[i];var b:=poly[(i+1)%poly.size()]
		var crown_a:=Vector3(a.x*1.002,41.0+2.0*clampf((-a.y+30)/75,0,1),a.y*1.002)
		var crown_b:=Vector3(b.x*1.002,41.0+2.0*clampf((-b.y+30)/75,0,1),b.y*1.002)
		_triangle(batch,"cream",Vector3(a.x,37.8,a.y),Vector3(b.x,37.8,b.y),crown_b)
		_triangle(batch,"cream",Vector3(a.x,37.8,a.y),crown_b,crown_a)
		_triangle(batch,"cream",crown_a,crown_b,Vector3(-3,44,-8))
	# Ground foyer is 5.5m high in the public plan; retain the double-height stair void.
	_box(w,"convention/rear_boundary",CONVENTION,Vector3(-18,2.75,0),Vector3(0.3,5.5,69),"wood")
	# A cut-out in the public mezzanine accompanies the main timber staircase.
	_box(w,"convention/mezzanine_north",CONVENTION,Vector3(24,5.45,-25),Vector3(67,0.2,9),"floor")
	_box(w,"convention/mezzanine_west",CONVENTION,Vector3(-9,5.45,2),Vector3(14,0.2,44),"floor")
	# Split the lower ceiling around the actual stair void.
	_box(w,"convention/ceiling_front",CONVENTION,Vector3(36,5.65,9),Vector3(43,0.2,52),"cream")
	_box(w,"convention/ceiling_rear",CONVENTION,Vector3(-6,10.9,0),Vector3(24,0.24,53),"cream")
	_stairs(w,"convention/grand_stair",CONVENTION,Vector3(8,0,-1),Vector3(8,5.55,-19),8,batch)
	_box(w,"convention/stair_top",CONVENTION,Vector3(8,5.43,-22),Vector3(9,0.24,6),"floor")
	_box(w,"convention/closed_upper",CONVENTION,Vector3(8,8.2,-27),Vector3(29,5.2,0.3),"wood")
	for z in [-19.0,19.0]:
		_box(w,"convention/column/%s"%z,CONVENTION,Vector3(32,2.75,z),Vector3(1.2,5.5,1.2),"stone")
	_box(w,"convention/registration",CONVENTION,Vector3(27,0.55,24),Vector3(16,1.1,1.3),"wood")
	_text(w,root,"ICC SYDNEY",Vector3(65,4.9,10),2.0)
	_text(w,root,"CONVENTION CENTRE",Vector3(44,3.4,24),1.1,0)
	_text(w,root,"REGISTRATION",Vector3(27,2.2,24),0.55,0)
	_text(w,root,"PUBLIC FOYER  ·  G → 1",Vector3(8,3.8,-4),0.75,0)
	_text(w,root,"其余会议室尚未复刻\nOther meeting rooms closed",Vector3(8,7.6,-26.8),0.52,0)
	for z in range(-18,25,6):
		_detail(batch,"white",Vector3(40,5.47,z),Vector3(22,0.035,0.08))
	for x in [45.0,52.0]:
		_detail(batch,"wood",Vector3(x,0.45,-13),Vector3(4,0.5,1.1))
		_detail(batch,"plant",Vector3(x,1.0,30),Vector3(2,1.7,1.0))
	for z in range(-31,34):
		_detail(batch,"wood_light",Vector3(-17.83,2.65,z),Vector3(0.018,5.1,0.022))
	for z in [-19.0,19.0]:
		for y in [1.35,2.75,4.15]:_detail(batch,"metal",Vector3(32,y,z),Vector3(1.215,0.015,1.215))
	_convention_fitout(w,root,batch)
	_flush(w,root,batch)
	# Southern conference/theatre wing is externally independent; rooms closed.
	var wing:=_poly(488447519,CONVENTION)
	_slab(w,"convention/south_wing",CONVENTION,wing,0,28,"crystal")
	var wingroot:=_root(w,"ICCConventionWing",CONVENTION);var wingbatch:=_start()
	for i in wing.size():
		var a:=wing[i];var b:=wing[(i+1)%wing.size()]
		for y in [6.0,12.0,18.0,24.0,28.0]:
			var d: Vector2=(b-a).normalized();var basis:=Basis(Vector3(d.x,0,d.y),Vector3.UP,Vector3(-d.y,0,d.x))
			_detail(wingbatch,"metal",Vector3((a.x+b.x)*0.5,y,(a.y+b.y)*0.5),Vector3(a.distance_to(b),0.27,0.35),basis)
	_flush(w,wingroot,wingbatch)

static func _exhibition(w: Node3D) -> void:
	var root:=_root(w,"ICCExhibitionDetails",EXHIBITION);var batch:=_start()
	var poly:=_poly(23646745,EXHIBITION)
	_shell(w,"exhibition",EXHIBITION,poly,19.0,[{"edge":5,"t":0.172,"width":9.0},{"edge":9,"t":0.5,"width":8.0}],"dark",batch)
	_slab(w,"exhibition/ground_floor",EXHIBITION,poly,-0.215,0.035,"floor")
	# Ground is car parking in the real venue. Only the public entry strip is open.
	_box(w,"exhibition/closed_parking",EXHIBITION,Vector3(40,3.05,-4),Vector3(0.3,6.1,179),"dark")
	_box(w,"exhibition/hall_floor",EXHIBITION,Vector3(-13,6.35,0),Vector3(108,0.3,183),"floor")
	_box(w,"exhibition/foyer_floor_inside",EXHIBITION,Vector3(46,6.35,-4),Vector3(11,0.3,179),"floor")
	_box(w,"exhibition/foyer_floor_outer",EXHIBITION,Vector3(62.3,6.35,-4),Vector3(4.4,0.3,179),"floor")
	for row: Array in [[-84.75,14.5], [22.0,144.0]]:
		_box(w,"exhibition/foyer_floor/%s"%row[0],EXHIBITION,Vector3(55.8,6.35,row[0]),Vector3(8.6,0.3,row[1]),"floor")
	_stairs(w,"exhibition/entry_stair",EXHIBITION,Vector3(56,0,-77),Vector3(56,6.5,-50),6.8,batch,"stone")
	_stairs(w,"exhibition/south_stair",EXHIBITION,Vector3(74,0,78),Vector3(56,6.5,53),6.8,batch,"stone")
	_box(w,"exhibition/hall_ceiling",EXHIBITION,Vector3(-13,17.15,0),Vector3(108,0.3,183),"dark")
	# Four real lower halls, north to south; operable partitions shown retracted
	# around 8m connecting doorways so all four spaces can be explored.
	var centers := [-68.0,-22.5,23.0,68.5]
	for i in 4:
		var z: float=centers[i]
		for row: Array in [[-33.0,65.0],[25.0,27.0]]:
			if i>0:_box(w,"exhibition/partition/%d/%s"%[i,row[0]],EXHIBITION,Vector3(row[0],11.75,z-22.75),Vector3(row[1],10.5,0.18),"stone")
		# Open hall entrances in the long public foyer.
		for offset in [-15.0,15.0]:
			_box(w,"exhibition/hall_wall/%d/%s"%[i,offset],EXHIBITION,Vector3(41,11.75,z+offset),Vector3(0.25,10.5,15.0),"wood")
		_box(w,"exhibition/hall_lintel/%d"%i,EXHIBITION,Vector3(41,15.5,z),Vector3(0.25,3,15),"wood")
		_box(w,"exhibition/registration/%d"%i,EXHIBITION,Vector3(43,7.05,z-11),Vector3(1.4,1.1,9),"wood")
		for y in [6.8,7.1,7.4]:_detail(batch,"metal",Vector3(43.72,y,z-11),Vector3(0.025,0.055,9))
		_text(w,root,"%d"%(i+1),Vector3(41.2,10.5,z-11),2.1)
		_text(w,root,"HALL %d"%(i+1),Vector3(41.3,12.3,z),1.8)
		_text(w,root,"%d"%(i+1),Vector3(-65.5,11.5,z),4.4,-90)
		for zz in range(5):
			var zzv:=z-17.0+zz*8.5
			_detail(batch,"metal",Vector3(-13,16.2,zzv),Vector3(106,0.20,0.18))
			_detail(batch,"white",Vector3(-13,16.0,zzv),Vector3(83,0.05,0.14))
		for x in [-49.0,-22.0,5.0]:
			for zz in [-11.0,11.0]:_detail(batch,"metal",Vector3(x,6.505,z+zz),Vector3(0.7,0.008,0.7))
	for z in range(-88,91):
		_detail(batch,"wood",Vector3(53,11.75,z),Vector3(21,0.18,0.14))
	for x in [47.0,58.0]:_detail(batch,"white",Vector3(x,11.6,0),Vector3(0.08,0.045,177))
	# Upper hall envelope uses its independently mapped footprint, set back.
	var upper:=_poly(1116329939,EXHIBITION)
	_slab(w,"exhibition/upper_halls",EXHIBITION,upper,19,35,"dark")
	_slab(w,"exhibition/event_deck",EXHIBITION,poly,18.7,19,"stone")
	# Alternating timber-lined projecting meeting pods, as photographed.
	for row in range(2):
		for i in range(4):
			var z: float=-67+i*38+(15 if row==1 else 0)
			var y: float=13.5+row*12.2
			# All projections remain on the footprint side of the public boulevard.
			_detail(batch,"dark",Vector3(58,y,z),Vector3(9,8.5,22))
			_detail(batch,"wood",Vector3(62.56,y,z),Vector3(0.10,8.2,21.4))
			_detail(batch,"black",Vector3(62.7,y,z),Vector3(0.14,6.5,17.8))
			_detail(batch,"wood_light",Vector3(63,y+3.25,z),Vector3(2.0,0.30,19.4))
			_detail(batch,"wood",Vector3(63,y-3.25,z),Vector3(2.0,0.30,19.4))
			for dz in [-9.7,9.7]:_detail(batch,"wood",Vector3(63,y,z+dz),Vector3(2.0,6.8,0.26))
	for y in [7.0,19.2,31.2]:
		_detail(batch,"stone",Vector3(64,y,-8),Vector3(2.5,0.38,171))
	_text(w,root,"ICC SYDNEY\nEXHIBITION CENTRE",Vector3(68.6,5.3,-74),1.1)
	_text(w,root,"LEVEL 1  ·  HALLS 1–4",Vector3(45,9.8,-79),0.7)
	_text(w,root,"停车场及上层展区尚未复刻\nParking / upper halls closed",Vector3(40.2,2.6,-65),0.46)
	_exhibition_fitout(w,root,batch)
	_flush(w,root,batch)

static func _theatre(w: Node3D) -> void:
	var root:=_root(w,"TikTokTheatreDetails",THEATRE);var batch:=_start()
	var poly:=_poly(487371417,THEATRE)
	_shell(w,"theatre",THEATRE,poly,37.3,[{"edge":16,"t":0.2,"width":10.0},{"edge":12,"t":0.5,"width":9.0}],"dark",batch)
	_slab(w,"theatre/floor",THEATRE,poly,-0.215,0.035,"dark")
	_slab(w,"theatre/roof",THEATRE,poly,37.1,38.0,"dark")
	# Black faceted zinc envelope: asymmetrical triangular folds and red reveals.
	for i in range(poly.size()):
		var a:=poly[i];var b:=poly[(i+1)%poly.size()]
		var mid:=a.lerp(b,0.47)
		var apex:=Vector3(mid.x*1.012,22+(i%3)*4,mid.y*1.012)
		_triangle(batch,"black",Vector3(a.x*1.006,7,a.y*1.006),Vector3(b.x*1.006,7,b.y*1.006),apex)
		_triangle(batch,"dark",Vector3(a.x*1.006,37.3,a.y*1.006),apex,Vector3(b.x*1.006,37.3,b.y*1.006))
	# Keep the east foyer's tall glass window open visually; dark folds surround it.
	for y in [7.3,18.0,28.0]:
		_detail(batch,"red",Vector3(59.1,y,-31),Vector3(0.12,0.20,27))
	# Northern 'birds-mouth' entrance screens above Moriarty Walk, not offices.
	_detail(batch,"screen",Vector3(35,5.9,-47.3),Vector3(17,3.0,0.18),Basis(Vector3.UP,deg_to_rad(4)))
	_text(w,root,"TikTok\nENTERTAINMENT CENTRE",Vector3(35,6.0,-47.6),0.78,180)
	_text(w,root,"THEATRE  ·  PUBLIC FOYER",Vector3(62.2,5.0,0),0.92)
	# Independent opaque acoustic room inside the public glazed envelope.
	# Public plans/photos establish separation, but these exact wall/door
	# dimensions are a circulation-safe reconstruction, not measured drawings.
	# North wall is outside the widest seat extent (~33.7m) and the GA aisle
	# at z=-34. Door openings remain 6.0m wide by 3.6m high.
	var h:=THEATRE_HALL_HEIGHT
	for row: Array in [
		["foyer_west",Vector3(42,h*0.5,4),Vector3(0.36,h,64)],
		["acoustic/east_north_return",Vector3(42,h*0.5,-35),Vector3(0.36,h,2)],
		["acoustic/east_door_lintel",Vector3(42,(h+THEATRE_DOOR_HEIGHT)*0.5,-31),Vector3(0.36,h-THEATRE_DOOR_HEIGHT,THEATRE_DOOR_WIDTH)],
		["acoustic/north_west",Vector3(-4.5,h*0.5,-36),Vector3(73,h,0.36)],
		["acoustic/north_east",Vector3(40.09,h*0.5,-36),Vector3(4.18,h,0.36)],
		["acoustic/north_door_lintel",Vector3(35,(h+THEATRE_DOOR_HEIGHT)*0.5,-36),Vector3(THEATRE_DOOR_WIDTH,h-THEATRE_DOOR_HEIGHT,0.36)],
		["south_auditorium_wall",Vector3(0.5,h*0.5,36),Vector3(83.36,h,0.36)],
		["backstage_boundary",Vector3(-41,h*0.5,0),Vector3(0.36,h,72.36)]
	]:
		var wall:=_box(w,"theatre/"+row[0],THEATRE,row[1],row[2],"black")
		wall.set_meta("icc_acoustic_enclosure",true)
	# Warm veneer belongs only to the foyer face; the audience sees charcoal
	# acoustic lining. The upper foyer remains lit through exterior glazing.
	_detail(batch,"wood",Vector3(42.20,4.5,4),Vector3(0.035,9,64))
	_detail(batch,"wood",Vector3(42.20,4.5,-35),Vector3(0.035,9,2))
	_detail(batch,"wood",Vector3(42.20,6.3,-31),Vector3(0.035,5.4,6))
	_box(w,"theatre/foyer_desk",THEATRE,Vector3(54,0.55,28),Vector3(8,1.1,1.6),"wood")
	_text(w,root,"BOX OFFICE",Vector3(54,2.6,28),0.65,0)
	_text(w,root,"AUDITORIUM  ←",Vector3(43,4.25,-31),0.70,90)
	_text(w,root,"AUDITORIUM  ·  GA ENTRY",Vector3(35,4.25,-36.22),0.55,180)
	# Horizontal acoustic panel joints give the new rear wall a visible finish
	# without crossing the two public door openings or any seating aisles.
	for y in [10.0,17.5,25.0,32.5]:
		_detail(batch,"dark",Vector3(41.80,y,0),Vector3(0.03,0.075,71.4))
	# Stage dimension comes from the public ground plan: 18.3 × 12.2 m @1.524m.
	_box(w,"theatre/stage",THEATRE,Vector3(-31,0.762,0),Vector3(12.2,1.524,18.3),"black")
	_box(w,"theatre/stage_back",THEATRE,Vector3(-39,12.0,0),Vector3(0.25,24,30),"black")
	_stairs(w,"theatre/stage_steps",THEATRE,Vector3(-31,0,-16),Vector3(-31,1.524,-9.15),2.8,batch,"dark")
	# Three fan tiers with red/grey seating and generous radial aisles. The
	# photographed pattern is procedural; this is not the ticketing seat map.
	var seat_count:=0
	for tier in range(3):
		var first_r: float=26.0+tier*17.0
		var base_y: float=0.0+tier*8.5
		for row in range(12):
			var radius:=first_r+row*1.05
			var y:=base_y+row*0.43
			var angle_max: float=deg_to_rad(44.0 if tier==0 else (35.0 if tier==1 else 28.0))
			var seats:=int(radius*angle_max*2/0.73)
			for seat in range(seats):
				var angle:=lerpf(-angle_max,angle_max,(seat+0.5)/seats)
				# Three radial aisles stay clear at every tier.
				if absf(angle)<0.032 or absf(angle-0.28)<0.028 or absf(angle+0.28)<0.028:continue
				var p:=Vector3(-39+cos(angle)*radius,y,sin(angle)*radius)
				var basis:=Basis(Vector3.UP,PI*0.5-angle)
				var key: String="red" if (seat*13+row*7+tier*3)%11< (8 if tier==0 else 4) else ("seat_grey" if seat%3!=0 else "seat_dark")
				_detail(batch,key,p+Vector3.UP*0.43,Vector3(0.57,0.13,0.48),basis)
				_detail(batch,key,p+basis*Vector3(0,0.80,0.24),Vector3(0.57,0.64,0.13),basis)
				_detail(batch,"black",p+Vector3.UP*0.22,Vector3(0.06,0.4,0.06),basis)
				seat_count+=1
			# Annular treads are real collision surfaces, leaving the ground side aisle.
			var strip:=PackedVector2Array()
			for j in range(33):
				var a:=lerpf(-angle_max,angle_max,float(j)/32);strip.append(Vector2(-39+cos(a)*(radius+0.62),sin(a)*(radius+0.62)))
			for j in range(32,-1,-1):
				var a:=lerpf(-angle_max,angle_max,float(j)/32);strip.append(Vector2(-39+cos(a)*(radius-0.55),sin(a)*(radius-0.55)))
			_slab(w,"theatre/tier/%d/row/%d"%[tier,row],THEATRE,strip,y-0.18,y,"dark")
		for angle in [-0.28,0.0,0.28]:
			var a:=Vector3(-39+cos(angle)*(first_r-0.55),base_y-0.01,sin(angle)*(first_r-0.55))
			var b:=Vector3(-39+cos(angle)*(first_r+11.6),base_y+4.74,sin(angle)*(first_r+11.6))
			_stairs(w,"theatre/tier/%d/aisle/%s"%[tier,angle],THEATRE,a,b,1.6,batch,"dark")
		# Balcony front parapet only visual, leaving radial aisles as openings.
		if tier>0:
			for j in range(48):
				var angle:=lerpf(-0.60,0.60,float(j)/47)
				if absf(angle)<0.055 or absf(absf(angle)-0.28)<0.055:continue
				var p:=Vector3(-39+cos(angle)*(first_r-0.75),base_y+0.50,sin(angle)*(first_r-0.75))
				_detail(batch,"black",p,Vector3(0.2,0.9,first_r*1.2/47+0.1),Basis(Vector3.UP,-angle))
	# Truss grid, acoustic baffles and lights recreate the photographed volume.
	for x in range(-44,37,10):
		_detail(batch,"metal",Vector3(x,31.6,0),Vector3(0.15,0.15,64))
		_detail(batch,"metal",Vector3(x,32.5,0),Vector3(0.15,0.15,64))
		for z in range(-30,31,4):
			_detail(batch,"metal",Vector3(x,32.05,z),Vector3(0.10,1.05,0.10),Basis(Vector3.RIGHT,deg_to_rad(31)))
			_detail(batch,"white",Vector3(x,31.45,z),Vector3(0.15,0.08,0.22))
	for z in [-32.0,32.0]:
		for x in range(-44,39,5):_detail(batch,"black",Vector3(x,23,z),Vector3(4.6,13,0.6),Basis(Vector3.UP,deg_to_rad(7 if x%2==0 else -7)))
	_text(w,root,"舞台及观众厅可步行参观\n座椅为示意数量 · 上层包厢未开放",Vector3(36,3.2,-30),0.55,180)
	_theatre_fitout(w,root,batch)
	_flush(w,root,batch)
	root.set_meta("modeled_seats",seat_count)
	w.set_meta("icc_modeled_seats",seat_count)
	# Mapped rear parking volume, independent from the hollow auditorium.
	_slab(w,"theatre/rear_parking",THEATRE,_poly(1098953175,THEATRE),0,8.0,"dark")

static func routes() -> Dictionary:
	return {
		"convention":[point(CONVENTION,Vector3(74,0,10)),point(CONVENTION,Vector3(56,0,10)),point(CONVENTION,Vector3(22,0,2)),point(CONVENTION,Vector3(8,0,2)),point(CONVENTION,Vector3(8,0,-1)),point(CONVENTION,Vector3(8,5.55,-19)),point(CONVENTION,Vector3(8,5.55,-22))],
		"exhibition":[point(EXHIBITION,Vector3(74,0,-75)),point(EXHIBITION,Vector3(64,0,-75)),point(EXHIBITION,Vector3(64,0,-81)),point(EXHIBITION,Vector3(56,0,-81)),point(EXHIBITION,Vector3(56,0,-77)),point(EXHIBITION,Vector3(56,6.5,-50)),point(EXHIBITION,Vector3(56,6.5,-47)),point(EXHIBITION,Vector3(46,6.5,-47)),point(EXHIBITION,Vector3(46,6.5,-22.5)),point(EXHIBITION,Vector3(16,6.5,-22.5)),point(EXHIBITION,Vector3(0,6.5,-22.5))],
		"theatre":[point(THEATRE,Vector3(35,0,-53)),point(THEATRE,Vector3(35,0,-34)),point(THEATRE,Vector3(-28,0,-34)),point(THEATRE,Vector3(-28,0,-14)),point(THEATRE,Vector3(-20,0,-14)),point(THEATRE,Vector3(-20,0,0)),point(THEATRE,Vector3(-20,0,-16)),point(THEATRE,Vector3(-31,0,-16)),point(THEATRE,Vector3(-31,1.524,-9.15)),point(THEATRE,Vector3(-31,1.524,0))]
	}

static func theatre_foyer_route() -> Array[Vector3]:
	var result:Array[Vector3]=[]
	for p:Vector3 in [Vector3(72,0,0),Vector3(54,0,0),Vector3(54,0,-31),Vector3(39,0,-31),Vector3(35,0,-34)]:
		result.append(point(THEATRE,p))
	return result


static func _screen_bank(w:Node3D,root:Node3D,batch:Dictionary,origin:Vector3,count:int,yaw:float=0) -> void:
	var frame:=Basis(Vector3.UP,deg_to_rad(yaw))
	for i in count:
		var p:=origin+frame*Vector3((i-(count-1)*0.5)*1.86,0,0)
		_detail(batch,"black",p,Vector3(1.8,1.02,0.13),frame)
		_detail(batch,"screen",p+frame*Vector3(0,0,0.074),Vector3(1.66,0.88,0.022),frame)
		# Reconstruct permanent wayfinding, not the photographed temporary show.
		_detail(batch,"white",p+frame*Vector3(-0.49,0.09,0.09),Vector3(0.35,0.035,0.01),frame)
		_detail(batch,"white",p+frame*Vector3(0.24,0.18,0.09),Vector3(0.66,0.06,0.01),frame)
		_detail(batch,"metal",p+frame*Vector3(0.24,-0.12,0.09),Vector3(0.66,0.035,0.01),frame)

static func _peak_wall(batch:Dictionary,x:float,low:float,high:float,z0:float,z1:float) -> void:
	# Photograph confirms alternating spotted-gum peaks. 0.12m sampling is an
	# explicitly coarser rendering choice than the supplier's 42+15mm system.
	var n:=ceili((z1-z0)/0.12)
	for i in n:
		var z:=lerpf(z0,z1,(i+0.5)/n)
		var x_tip:=x+0.07
		var a:=Vector3(x,low,z-0.047);var b:=Vector3(x,high,z-0.047)
		var c:=Vector3(x_tip,high,z);var d:=Vector3(x_tip,low,z)
		_triangle(batch,"wood_light" if i%2==0 else "wood",a,b,c)
		_triangle(batch,"wood_light" if i%2==0 else "wood",a,c,d)
		var e:=Vector3(x,low,z+0.047);var f:=Vector3(x,high,z+0.047)
		_triangle(batch,"wood",d,c,f);_triangle(batch,"wood",d,f,e)

static func _ceiling_field(batch:Dictionary,center:Vector3,size:Vector2,axis:bool=false) -> void:
	# Suspended silver battens, black plenums and paired recessed luminaires.
	_detail(batch,"dark",center+Vector3.UP*0.10,Vector3(size.x,0.05,size.y))
	var n:=ceili((size.y if axis else size.x)/0.24)
	for i in n:
		var p:=center+Vector3(0,0,(i+0.5)*0.24-size.y*0.5) if axis else center+Vector3((i+0.5)*0.24-size.x*0.5,0,0)
		_detail(batch,"metal",p,Vector3(size.x,0.10,0.085) if axis else Vector3(0.085,0.10,size.y))
	for x in range(2,int(size.x)-1,6):
		for z in range(2,int(size.y)-1,6):
			var p:=center+Vector3(x-size.x*0.5,-0.063,z-size.y*0.5)
			_detail(batch,"black",p,Vector3(0.40,0.035,0.24))
			for dx in [-0.10,0.10]:_detail(batch,"light",p+Vector3(dx,-0.025,0),Vector3(0.105,0.018,0.12))

static func _convention_fitout(w:Node3D,root:Node3D,batch:Dictionary) -> void:
	_ceiling_field(batch,Vector3(36,5.43,8),Vector2(42,49))
	_ceiling_field(batch,Vector3(-6,10.68,0),Vector2(23,51),true)
	_peak_wall(batch,-17.79,0.18,5.3,-33,33)
	# The registration counter has stone cladding, a recessed toe and actual
	# worktops/monitors; photographed fixture language, estimated positions.
	_detail(batch,"stone",Vector3(27,0.61,23.30),Vector3(16.2,1.0,0.18))
	_detail(batch,"black",Vector3(27,0.13,23.34),Vector3(15.5,0.16,0.12))
	_detail(batch,"stone",Vector3(27,1.16,24),Vector3(16.3,0.12,1.55))
	for x in [21.0,25.0,29.0,33.0]:
		_detail(batch,"black",Vector3(x,1.37,24.35),Vector3(0.06,0.44,0.06))
		_detail(batch,"dark",Vector3(x,1.64,24.35),Vector3(0.70,0.41,0.07),Basis(Vector3.RIGHT,deg_to_rad(-8)))
		_detail(batch,"screen",Vector3(x,1.64,24.30),Vector3(0.63,0.34,0.015),Basis(Vector3.RIGHT,deg_to_rad(-8)))
		_detail(batch,"white",Vector3(x+0.8,1.23,23.80),Vector3(0.28,0.02,0.35))
	_screen_bank(w,root,batch,Vector3(27,3.45,24.1),7,180)
	# Glazed mezzanine guard stops before the timber stair landing opening.
	for row:Array in [[Vector3(35,6.05,-20.36),Vector3(43,1,0.035)],[Vector3(-1.85,6.05,4),Vector3(0.035,1,40)]]:
		_detail(batch,"glass",row[0],row[1])
		_detail(batch,"metal",row[0]+Vector3.UP*0.54,Vector3(row[1].x,0.055,row[1].z))
	for z in range(-14,23,3):_detail(batch,"metal",Vector3(-1.82,6.03,z),Vector3(0.055,1.18,0.055))
	# Real internal wayfinding rather than floating game annotations.
	_detail(batch,"blue",Vector3(20,3.3,-19.8),Vector3(10,0.90,0.14))
	_text(w,root,"← MEETING ROOMS   1   →",Vector3(20,3.3,-19.70),0.39,0)
	for x in [45.0,52.0]:
		for dx in [-1.65,1.65]:_detail(batch,"metal",Vector3(x+dx,0.20,-13),Vector3(0.12,0.4,0.7))
		_detail(batch,"wood_light",Vector3(x,0.73,-13.45),Vector3(4,0.42,0.12))
	w.set_meta("icc_convention_fitout",{"ceiling_battens":true,"registration_workstations":4,"digital_screens":7,"mezzanine_guards":true})

static func _exhibition_fitout(w:Node3D,root:Node3D,batch:Dictionary) -> void:
	# The long foyer follows the official Level 1 plan; individual concession
	# modules use the installed blue surrounds, pale counter and timber peaks.
	_ceiling_field(batch,Vector3(53,11.51,-4),Vector2(21,174),true)
	for i in 4:
		var z:float=-68+i*45.5
		_peak_wall(batch,41.19,6.62,11.40,z-22.4,z-7.6)
		_peak_wall(batch,41.19,6.62,11.40,z+7.6,z+22.4)
		_detail(batch,"blue",Vector3(41.38,9.25,z-12),Vector3(0.22,3.55,10))
		_detail(batch,"dark",Vector3(41.53,8.85,z-12),Vector3(0.025,2.4,9.3))
		for y in range(8):_detail(batch,"metal",Vector3(41.56,7.8+y*0.26,z-12),Vector3(0.018,0.019,9.1))
		_detail(batch,"stone",Vector3(43.77,7.14,z-11),Vector3(0.16,1.12,9.2))
		_detail(batch,"stone",Vector3(43,7.68,z-11),Vector3(1.65,0.12,9.2))
		_screen_bank(w,root,batch,Vector3(41.75,10.65,z-12),5,90)
		for zz in [z-7.4,z+7.4]:_detail(batch,"blue",Vector3(41.3,9.2,zz),Vector3(0.20,5.4,0.20))
		_detail(batch,"blue",Vector3(41.30,11.85,z),Vector3(0.20,0.32,15.0))
		# Overhead main trusses, suspension rods and ventilation runners are
		# architectural fabric; hall floors stay in the empty-event configuration.
		for zz in [z-17,z,z+17]:
			for y in [15.55,16.65]:_detail(batch,"metal",Vector3(-13,y,zz),Vector3(105,0.16,0.16))
			for x in range(-62,38,4):
				_detail(batch,"metal",Vector3(x,16.1,zz),Vector3(0.10,1.47,0.10),Basis(Vector3.FORWARD,deg_to_rad(42 if x%8==0 else -42)))
		for x in [-53.0,-27.0,-1.0,25.0]:
			_detail(batch,"dark",Vector3(x,16.72,z),Vector3(0.65,0.40,44))
			for dz in [-16.0,0.0,16.0]:
				_detail(batch,"black",Vector3(x,16.2,z+dz),Vector3(0.50,0.24,0.5))
				_detail(batch,"white",Vector3(x,16.065,z+dz),Vector3(0.35,0.035,0.35))
		for zz in [z-20,z+20]:
			_detail(batch,"blue",Vector3(-65.75,8.4,zz),Vector3(0.18,3.8,2.5))
			_detail(batch,"metal",Vector3(-65.62,7.6,zz),Vector3(0.04,0.08,1.9))
			_detail(batch,"plant",Vector3(-65.63,10.62,zz),Vector3(0.05,0.32,1.1))
	w.set_meta("icc_exhibition_fitout",{"concessions":4,"digital_screens":20,"structural_trusses":12,"empty_event_halls":true})

static func _theatre_fitout(w:Node3D,root:Node3D,batch:Dictionary) -> void:
	_peak_wall(batch,42.24,0.18,8.8,-27.8,35)
	_ceiling_field(batch,Vector3(52,8.8,3),Vector2(18,60),true)
	_detail(batch,"stone",Vector3(54,0.61,27.13),Vector3(8.2,1.0,0.14))
	_detail(batch,"stone",Vector3(54,1.15,28),Vector3(8.2,0.12,1.85))
	_screen_bank(w,root,batch,Vector3(54,3.5,28.8),4,180)
	for x in [51.0,54.0,57.0]:
		_detail(batch,"black",Vector3(x,1.4,28.4),Vector3(0.07,0.5,0.07))
		_detail(batch,"screen",Vector3(x,1.65,28.4),Vector3(0.64,0.39,0.05))
	# The narrow north/auditorium entry stays unobstructed; seats and trusses
	# remain the existing three-tier reconstruction, not a full seating survey.
	for z in [5.0,17.0]:
		_box(w,"theatre/foyer_bench/%s"%z,THEATRE,Vector3(44.2,0.4,z),Vector3(1.15,0.8,4.2),"wood")
		_detail(batch,"wood_light",Vector3(43.7,0.95,z),Vector3(0.13,0.52,4.2))
	w.set_meta("icc_theatre_fitout",{"box_office_workstations":3,"digital_screens":4,"foyer_battens":true})
