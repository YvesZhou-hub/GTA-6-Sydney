extends RefCounted
## Original geometry; photographed Darling Quarter equipment at mapped OSM points.
## The adjoining square and playground are separate places, not interchangeable.
const CpuMesh = preload("res://scripts/cpu_mesh.gd")
const Geo=preload("res://scripts/city_landmarks.gd")
const DATA="res://assets/darling_public_facilities.json"
const GROUND=4.5
const COLORS={"stone":"c9c7b8","sand":"b59b72","mulch":"8b7654","rubber":"a49978","steel":"aeb7b5","blue":"274f96","dark":"343b3a","wood":"88735c","water":"63b1bf","jet":"b6dbe3","leaf":"53795a","cream":"e6ddc5"}

static func data() -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(DATA))
static func excluded_way_ids() -> Array[int]:return [1136058496,1241018456,1241018457,1241018458]
static func point(id:String) -> Vector3:
	for item in data().equipment:
		if item.id==id:return Vector3(item.point[0],GROUND,item.point[1])
	return Vector3.ZERO
static func metadata() -> Array[Dictionary]:
	var out:Array[Dictionary]=[]
	for r in [
		["darling_quarter_waterplay","戏水区 · Darling Quarter Water Play",Vector3(-815.6,GROUND,1662.8),Vector3(-801.0,GROUND,1669.0)],
		["darling_quarter_octanet","儿童攀爬网 · Darling Quarter Giant Octanet",point("node/10590136162"),Vector3(-857.3,GROUND,1630.0)],
		["darling_quarter_slide","宽滑梯 · Darling Quarter Wide Slide",point("node/10590136159"),Vector3(-852.0,GROUND,1649.0)],
		["tumbalong_fountains","喷泉 · Tumbalong Park Southern Fountains",Vector3(-817.6,GROUND,1848.8),Vector3(-802.0,GROUND,1847.0)]
	]:out.append({"id":r[0],"name":r[1],"center":r[2],"map_position":r[2],"arrival":r[3],"position":r[3],"source":"https://www.darlingharbour.com/see-do-stay/darling-harbour-children-s-playground","precision":"Mapped OSM equipment or water outline; photo-estimated fittings and flat game terrain","precinct":"Darling Quarter / Tumbalong Park; distinct from Darling Square"})
	return out
static func capture_views() -> Array:
	return [["darling_waterplay",Vector3(-791,12,1679),Vector3(-816,5.8,1657)],["darling_octanet",Vector3(-866,8.1,1642),Vector3(-847,10,1625)],["darling_wide_slide",Vector3(-852,7,1657),Vector3(-842,6,1645)],["tumbalong_fountains",Vector3(-797,9,1875),Vector3(-816,5,1848)],["darling_playground_plan",Vector3(-867,75,1706),Vector3(-842,5,1651)]]
static func walk_routes() -> Array:
	var slide:=point("node/10590136159");var basis:=Basis(Vector3.UP,-.48)
	return [{"id":"tumbalong_fountain_perimeter","name":"Tumbalong fountain public edge","points":[Vector3(-802,GROUND,1874),Vector3(-802,GROUND,1847),Vector3(-802,GROUND,1824)]},{"id":"darling_playground_perimeter","name":"Darling Quarter playground west approach","points":[Vector3(-857.3,GROUND,1630),Vector3(-858.8,GROUND,1642),Vector3(-852,GROUND,1649),Vector3(-844.2,GROUND,1660)]},{"id":"darling_wide_slide_stairs","name":"Wide slide rear steps and slope","points":[slide+basis*Vector3(0,0,-7.9),slide+basis*Vector3(0,2.68,-2.9),slide+basis*Vector3(0,0,4.0)]}]

static func build(w:Node3D):
	if w.has_meta("darling_public_facilities"):return
	for key in COLORS:w._mat("dp_"+key,Color(COLORS[key]),.22 if key in ["water","steel"] else .84,.55 if key=="steel" else 0)
	_water_material(w)
	var source=data()
	var boundary:=Geo.polygon(source.playground_outline)
	w._structure_mesh("darling_detail/playground/ground",Geo.prism(boundary,.015,.055),Vector3.UP*GROUND,"dp_mulch",2800000)
	for area in source.areas:
		if area.kind=="splash_pad":_fountain(w,area)
		elif area.kind=="water":
			w._structure_mesh("darling_detail/waterplay/paving",Geo.prism(Geo.polygon(area.points),.06,.09),Vector3.UP*GROUND,"dp_stone",1200000)
	_octanet(w)
	_climbing_valley(w)
	_slide(w,point("node/10590136159"),8.0,5.8,2.55,"wide",-.48)
	_slide(w,point("node/10590136176"),1.4,4.2,1.65,"east",.25)
	_slide(w,point("node/10590136179"),1.3,3.8,1.35,"middle",.25)
	_swing(w,point("node/10590136175"),true)
	_swing(w,point("node/10590136157"),false)
	_waterplay(w,source)
	_shelters(w,source)
	for i in 6:
		var p:=Vector3(-800.0-i*.48,GROUND,1646+i*5.0)
		var part:=Part.new(w,"edge_bench/%d"%i,p)
		part.box(Vector3(0,.23,0),Vector3(.70,.46,3.1),"stone",true)
		for slat in 6:part.box(Vector3(-.30+slat*.12,.48,0),Vector3(.105,.07,3.02),"wood")
		part.finish()
	# No invented palm grove: production OSM vegetation remains the authoritative
	# tree layout. These equipment parts do not duplicate the mapped street trees.
	for item in metadata():w.anchors[item.id]=item.arrival
	w.set_meta("darling_public_facilities",metadata())
	w.set_meta("darling_public_facilities_sources",source)

static func _shelters(w:Node3D,source:Dictionary):
	for item in source.mapped_shelters:
		var at:=Vector3(item.center[0],GROUND,item.center[1])
		var poly:=Geo.polygon(item.outline)
		if item.id=="way/1241018458":
			var triangles:=Geometry2D.triangulate_polygon(poly)
			var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			# OSM's unusual canopy outline is retained. The saddle height is an
			# estimate from the photographed tensioned fabric, not tagged elevation.
			for i in range(0,triangles.size(),3):
				var vertices:Array[Vector3]=[]
				for j in 3:
					var p:Vector2=poly[triangles[i+j]]
					vertices.append(Vector3(p.x,5.4+.32*sin(p.y*.31)+.16*p.x,p.y))
				var n:Vector3=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
				for j in [0,2,1]:st.set_normal(n);st.add_vertex(vertices[j])
				for j in [0,1,2]:st.set_normal(-n);st.add_vertex(vertices[j]-Vector3.UP*.025)
			var body=w._structure_mesh("darling_detail/shelter/membrane",CpuMesh.commit(st),at,"dp_cream",160000)
			body.set_meta("source_osm",item.id)
			var p:=Part.new(w,"shelter/membrane_posts",at)
			for v in [poly[0],poly[6],poly[15],poly[21]]:p.cylinder(Vector3(v.x,3.3,v.y),.075,6.6,"steel",Basis.IDENTITY,true)
			p.finish()
		elif item.id=="way/1136058496":
			var body=w._structure_mesh("darling_detail/shelter/picnic_roof",Geo.prism(poly,3.6,3.85),at,"dp_wood",160000)
			body.set_meta("source_osm",item.id)
			var p:=Part.new(w,"shelter/picnic_posts",at)
			for v in [Vector3(-2.8,0,-1.0),Vector3(2.5,0,-1.0),Vector3(-1.6,0,2.0),Vector3(2.5,0,2.0)]:p.cylinder(v+Vector3.UP*1.8,.075,3.6,"steel",Basis.IDENTITY,true)
			for i in 16:p.box(Vector3(-3+i*.40,3.59,0),Vector3(.07,.035,5.0),"dark")
			p.finish()
		else:
			var body=w._structure_mesh("darling_detail/shelter/"+item.id.replace("way/",""),Geo.prism(poly,0,2.9),at,"dp_stone",160000)
			body.set_meta("source_osm",item.id)
			var face:=Part.new(w,"shelter/door/"+item.id.replace("way/",""),at)
			face.box(Vector3(0,1.15,2.56),Vector3(1.0,2.3,.05),"dark")
			face.box(Vector3(.32,1.10,2.61),Vector3(.035,.25,.045),"steel")
			if item.id=="way/1241018457":
				for x in [-.20,.20]:face.cylinder(Vector3(x,1.85,2.62),.055,.10,"cream",Basis(Vector3.RIGHT,PI*.5));face.box(Vector3(x,1.58,2.62),Vector3(.085,.33,.018),"cream")
			face.finish()

class Part:
	var w:Node3D
	var body:StaticBody3D
	var surfaces:Dictionary={}
	var elements:=0
	func _init(owner:Node3D,id:String,origin:Vector3):
		w=owner
		# Small foundation is real solid support, not a large invisible obstruction.
		body=w._structure_box("darling_detail/"+id,origin+Vector3.DOWN*.07,Vector3(.3,.14,.3),"dp_stone",110000)
		body.set_meta("facility_origin",origin)
	func box(p:Vector3,size:Vector3,key:String,collide:=false,basis:=Basis.IDENTITY):
		if not surfaces.has(key):
			var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surfaces[key]=surface
		var vertices:Array[Vector3]=[]
		for v in [Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,1,-1),Vector3(-1,1,-1),Vector3(-1,-1,1),Vector3(1,-1,1),Vector3(1,1,1),Vector3(-1,1,1)]:vertices.append(p+Vector3.UP*.07+basis*(v*size*.5))
		for face in [[4,5,6,7],[1,0,3,2],[0,4,7,3],[5,1,2,6],[3,7,6,2],[0,1,5,4]]:
			var normal:Vector3=(vertices[face[1]]-vertices[face[0]]).cross(vertices[face[2]]-vertices[face[0]]).normalized()
			for i in [0,2,1,0,3,2]:surfaces[key].set_normal(normal);surfaces[key].set_uv(Vector2.ZERO);surfaces[key].add_vertex(vertices[face[i]])
		elements+=1
		if collide:
			var c:=CollisionShape3D.new();var s:=BoxShape3D.new();s.size=size;c.shape=s;c.transform=Transform3D(basis,p+Vector3.UP*.07);body.add_child(c)
	func cylinder(p:Vector3,r:float,h:float,key:String,basis:=Basis.IDENTITY,collide:=false):
		var mesh:=CylinderMesh.new();mesh.top_radius=r;mesh.bottom_radius=r;mesh.height=h;mesh.radial_segments=12;mesh.rings=1
		append(mesh,Transform3D(basis,p+Vector3.UP*.07),key)
		if collide:
			var c:=CollisionShape3D.new();var s:=CylinderShape3D.new();s.radius=r;s.height=h;c.shape=s;c.transform=Transform3D(basis,p+Vector3.UP*.07);body.add_child(c)
	func beam(a:Vector3,b:Vector3,d:float,key:String,collide:=false):
		if a.distance_to(b)<.001:return
		var up:=Vector3.FORWARD if absf((b-a).normalized().y)>.98 else Vector3.UP
		box((a+b)*.5,Vector3(d,d,a.distance_to(b)),key,collide,Basis.looking_at(b-a,up))
	func append(mesh:Mesh,t:Transform3D,key:String):
		if not surfaces.has(key):var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);surfaces[key]=st
		Geo._append_mesh_triangles(surfaces[key],mesh,t);elements+=1
	func finish():
		var bounds:=AABB(Vector3(-.15,0,-.15),Vector3(.3,.14,.3))
		for key in surfaces:
			var m:=MeshInstance3D.new();m.mesh=CpuMesh.commit(surfaces[key]);m.material_override=w.materials["dp_"+key];m.set_meta("intact_material",m.material_override);m.visibility_range_end=400;body.add_child(m)
			bounds=bounds.merge(m.mesh.get_aabb())
		var id:String=body.get_meta("damage_id")
		w.structures[id].position=body.position+bounds.get_center()
		w.structures[id].half=bounds.size*.5
		body.set_meta("detail_elements",elements)

static func _fountain(w:Node3D,area:Dictionary):
	var poly:=Geo.polygon(area.points)
	var id:String=area.id.replace("way/","")
	# Photo-supported paved margin. Its 1.4m width is an explicit approximation;
	# existing mapped road/pedestrian surfaces remain vertically above it.
	for apron in Geometry2D.offset_polygon(poly,1.4,Geometry2D.JOIN_ROUND):
		w._structure_mesh("darling_detail/fountain_apron/"+id,Geo.prism(apron,.025,.035),Vector3.UP*GROUND,"dp_stone",550000)
	var floor_body:StaticBody3D=w._structure_mesh("darling_detail/fountain/"+id,Geo.prism(poly,.10,.16),Vector3.UP*GROUND,"dp_stone",550000)
	floor_body.set_meta("osm_outline",area.id)
	var water:=MeshInstance3D.new();water.mesh=Geo.prism(poly,.163,.164);water.material_override=w.materials.dp_water;water.set_meta("intact_material",water.material_override);floor_body.add_child(water)
	# The two southern mapped rectangles are flush splash fountains; western
	# narrow pools follow their irregular OSM outlines rather than a made-up oval.
	var aabb:=Rect2(poly[0],Vector2.ZERO)
	for p in poly:aabb=aabb.expand(p)
	var jets:=SurfaceTool.new();jets.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count:=0
	for x in range(ceili(aabb.position.x),floori(aabb.end.x),3):
		for z in range(ceili(aabb.position.y),floori(aabb.end.y),3):
			var p:=Vector2(x,z)
			if not Geometry2D.is_point_in_polygon(p,poly):continue
			var height:=.75+.35*sin(x*.7+z*.2)
			var jet:=CylinderMesh.new();jet.top_radius=.025;jet.bottom_radius=.065;jet.height=height;jet.radial_segments=6;jet.rings=1
			jets.append_from(jet,0,Transform3D(Basis.IDENTITY,Vector3(x,.17+height*.5,z)))
			count+=1
	if count:
		var m:=MeshInstance3D.new();m.mesh=CpuMesh.commit(jets);m.material_override=w.materials.dp_jet;m.set_meta("intact_material",m.material_override);floor_body.add_child(m)
	floor_body.set_meta("jet_count",count)

static func _octanet(w:Node3D):
	var p:=Part.new(w,"playground/octanet",point("node/10590136162"))
	p.cylinder(Vector3(0,5.5,0),.13,11.0,"steel",Basis.IDENTITY,true)
	# Eight radial cable sectors with repeated horizontal/diagonal meshes.
	# The 11m apex is supplier-documented; base spread is photograph-estimated.
	for side in 8:
		var a:=Vector3(cos(side*TAU/8),0,sin(side*TAU/8))*7.6
		var b:=Vector3(cos((side+1)*TAU/8),0,sin((side+1)*TAU/8))*7.6
		p.beam(a+Vector3.UP*.15,Vector3(0,10.7,0),.055,"blue")
		p.cylinder(a+Vector3.UP*.25,.10,.5,"steel",Basis.IDENTITY,true)
		for row in 16:
			var t:float=(row+1)/18.0
			var r:float=pow(1.0-t,.82)
			var start:=a*r+Vector3.UP*(t*10.7)
			var end:=b*r+Vector3.UP*(t*10.7)
			p.beam(start,end,.027,"blue")
			for col in 6:
				var q0:Vector3=start.lerp(end,col/6.0)
				var q1:Vector3=(a*pow(1.0-t-.045,.82)).lerp(b*pow(1.0-t-.045,.82),(col+1)/6.0)+Vector3.UP*((t+.045)*10.7)
				p.beam(q0,q1,.022,"blue")
	# Low traverse ropes are solid at the same visible positions; no invisible
	# staircase to the apex or claim of a complete rope-climbing controller.
	for side in 4:
		var angle:=side*PI*.5
		var a:=Vector3(cos(angle),0,sin(angle))*6.2
		var b:=Vector3(cos(angle+PI*.5),0,sin(angle+PI*.5))*6.2
		p.beam(a+Vector3.UP*.45,b+Vector3.UP*.45,.13,"blue",true)
	p.finish()

static func _climbing_valley(w:Node3D):
	var p:=Part.new(w,"playground/climbing_valley",point("node/10590136169"))
	for side in [-1,1]:
		for row in 4:p.cylinder(Vector3(side*2.4,1.75,-4.5+row*3),.075,3.5,"steel",Basis.IDENTITY,true)
	for row in 24:
		var z:float=-4.5+row*9.0/23
		var y:float=.75+.32*cos(z*.8)
		p.beam(Vector3(-2.4,y,z),Vector3(2.4,y,z),.043,"blue")
		for side in [-1,1]:p.beam(Vector3(side*2.4,y,z),Vector3(side*2.4,2.7,z),.031,"blue")
	for col in 13:
		var x:float=-2.4+col*.4
		for row in 23:
			var z:float=-4.5+row*9.0/23;var nz:float=z+9.0/23
			p.beam(Vector3(x,.75+.32*cos(z*.8),z),Vector3(x,.75+.32*cos(nz*.8),nz),.031,"blue")
	p.finish()

static func _slide(w:Node3D,origin:Vector3,width:float,length:float,height:float,id:String,angle:float):
	var basis:=Basis(Vector3.UP,angle)
	var p:=Part.new(w,"playground/slide/"+id,origin)
	var polys:=PackedVector3Array()
	# Extruded sloped concrete structure with a walkable rear stair and curved
	# sliding face. Top collision exactly follows the visible ramp triangles.
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
	for row in 20:
		var z0:float=-length*.5+row*length/20;var z1:float=z0+length/20
		var y0:float=.13+height*pow(1.0-row/20.0,1.6);var y1:float=.13+height*pow(1.0-(row+1)/20.0,1.6)
		var a:=basis*Vector3(-width*.5,y0,z0);var b:=basis*Vector3(width*.5,y0,z0);var c:=basis*Vector3(width*.5,y1,z1);var d:=basis*Vector3(-width*.5,y1,z1)
		for v in [a,b,c,a,c,d]:polys.append(v)
		p.beam(b+Vector3.UP*.13,c+Vector3.UP*.13,.22,"stone",true)
		p.beam(a+Vector3.UP*.13,d+Vector3.UP*.13,.22,"stone",true)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,polys.size(),3):
		var normal:Vector3=-(polys[i+1]-polys[i]).cross(polys[i+2]-polys[i]).normalized()
		for j in 3:st.set_normal(normal);st.add_vertex(polys[i+j]+Vector3.UP*.07)
	var mesh=CpuMesh.commit(st);p.append(mesh,Transform3D.IDENTITY,"steel")
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(polys);shape.backface_collision=true
	var collision:=CollisionShape3D.new();collision.shape=shape;collision.position.y=.07;p.body.add_child(collision)
	for row in ceili(height/.17):
		var riser:float=height/ceili(height/.17)
		var n:int=ceili(height/.17)
		p.box(basis*Vector3(0,(row+1)*riser*.5,-length*.5-.35-(n-row-1)*.29),Vector3(minf(2.2,width),maxf(.1,(row+1)*riser),.30),"stone",true,basis)
	p.finish()

static func _swing(w:Node3D,origin:Vector3,basket:bool):
	var p:=Part.new(w,"playground/"+("basket_swing" if basket else "swing"),origin)
	for side in [-1,1]:
		for sign in [-1,1]:p.beam(Vector3(side*2.3,0,sign*1.5),Vector3(side*2.1,3.5,0),.13,"steel",true)
	p.beam(Vector3(-2.2,3.5,0),Vector3(2.2,3.5,0),.17,"steel")
	for side in [-1,1]:p.beam(Vector3(side*.65,3.45,0),Vector3(side*.65,.65,0),.026,"dark")
	if basket:
		for i in 32:
			var a:=Vector3(cos(i*TAU/32),0,sin(i*TAU/32))*.78+Vector3.UP*.65
			var b:=Vector3(cos((i+1)*TAU/32),0,sin((i+1)*TAU/32))*.78+Vector3.UP*.65
			p.beam(a,b,.105,"dark")
		for i in 9:p.beam(Vector3(-.58+i*.145,.59,-.5),Vector3(-.58+i*.145,.59,.5),.035,"blue")
	else:p.box(Vector3(0,.62,0),Vector3(1.25,.14,.45),"dark",true)
	p.finish()

static func _waterplay(w:Node3D,source:Dictionary):
	var center:=Vector3(-815.6,GROUND,1662.8)
	var p:=Part.new(w,"waterplay/channels",center)
	# Mapped meandering channel from the public pump, then photo-informed
	# shallow stepping-stone river within the mapped water-play area.
	var line:Array[Vector3]=[]
	for area in source.areas:
		if area.kind=="water_channel":
			for v in area.points:line.append(Vector3(v[0],GROUND,v[1])-center)
	line.append_array([Vector3(-806,GROUND,1650)-center,Vector3(-812,GROUND,1655)-center,Vector3(-818,GROUND,1662)-center,Vector3(-818,GROUND,1670)-center,Vector3(-824,GROUND,1678)-center])
	for i in range(line.size()-1):
		var a:Vector3=line[i];var b:Vector3=line[i+1];var axis:Vector3=(b-a).normalized();var right:=Vector3(axis.z,0,-axis.x);var basis:=Basis.looking_at(axis,Vector3.UP)
		p.box((a+b)*.5+Vector3.UP*.11,Vector3(1.02,.04,a.distance_to(b)+.05),"water",false,basis)
		for side in [-1,1]:p.box((a+b)*.5+right*side*.63+Vector3.UP*.18,Vector3(.24,.36,a.distance_to(b)+.08),"stone",true,basis)
	for i in 9:
		var at:=Vector3(-813+(i%3)*2.7,GROUND,1659+(i/3)*3.3)-center
		p.cylinder(at+Vector3.UP*.18,.65,.36,"stone",Basis.IDENTITY,true)
	p.finish()
	var pump:=Part.new(w,"waterplay/pump",point("node/10696013709"))
	pump.box(Vector3(0,.13,0),Vector3(4.1,.26,3.2),"wood",true)
	for i in 25:pump.box(Vector3(-2+i*.165,.265,0),Vector3(.015,.008,3.2),"dark")
	for i in 3:
		var x:float=-1.2+i*1.2
		pump.cylinder(Vector3(x,.86,0),.09,1.45,"steel",Basis.IDENTITY,true)
		pump.cylinder(Vector3(x,1.52,0),.22,.45,"steel")
		pump.beam(Vector3(x,1.38,0),Vector3(x,1.10,.75),.09,"steel")
		pump.cylinder(Vector3(x,.70,.57),.27,.11,"steel")
	pump.finish()
	var wheel:=Part.new(w,"waterplay/wheel",point("node/10696013714"))
	for side in [-1,1]:wheel.cylinder(Vector3(0,.60,side*.37),.07,1.2,"steel",Basis.IDENTITY,true)
	var wb:=Basis(Vector3.RIGHT,PI*.5)
	wheel.cylinder(Vector3(0,.97,0),.73,.17,"steel",wb)
	for i in 16:
		var angle:float=i*TAU/16
		wheel.beam(Vector3(0,.97,.15),Vector3(cos(angle)*.68,.97+sin(angle)*.68,.15),.035,"dark")
	wheel.finish()
	var screw:=Part.new(w,"waterplay/archimedes_screw",point("node/10696013713"))
	var a:=Vector3(-1.3,.20,0);var b:=Vector3(1.3,1.35,0)
	screw.beam(a,b,.10,"steel",true)
	var sb:=Basis.looking_at(b-a,Vector3.UP)
	for i in 160:
		var t:float=i/160.0;var nt:float=(i+1)/160.0
		var q:Vector3=a.lerp(b,t)+sb*Vector3(cos(t*TAU*7)*.23,sin(t*TAU*7)*.23,0)
		var nq:Vector3=a.lerp(b,nt)+sb*Vector3(cos(nt*TAU*7)*.23,sin(nt*TAU*7)*.23,0)
		screw.beam(q,nq,.05,"steel")
	for x in [-1.3,1.3]:screw.cylinder(Vector3(x,.55,0),.08,1.1,"steel",Basis.IDENTITY,true)
	screw.finish()

static func _water_material(w:Node3D):
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float v=.5+.5*sin(world_position.x*6.0+world_position.z*4.0+TIME*2.0); ALBEDO=mix(vec3(.28,.46,.47),vec3(.52,.67,.66),v*.25); ROUGHNESS=.22; METALLIC=.16;}
"""
	var material:=ShaderMaterial.new();material.shader=shader;w.materials.dp_water=material
