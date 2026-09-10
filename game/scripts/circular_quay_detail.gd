extends RefCounted
## Existing wharves 2–6, not an unbuilt renewal proposal. Exact mapped roof
## outlines and individually projected restaurant facades; inferred elevations.
const City=preload("res://scripts/city_map.gd")
const Geo=preload("res://scripts/city_landmarks.gd")
const Fronts=preload("res://scripts/darling_square_frontages.gd")
const Darling=preload("res://scripts/darling_square_detail.gd")
const IDS:Array[int]=[270803850,354270479,354270481,354270484,354270487,1269027215,1269027216,1269027221,1269027222,1269027236,1269027237,1295125146,1295125147,1295125149,1295125150,1295125151,1295125161,1295125162,1295125163,1295125164,1295125165,1295125168,1295125169,1295125170,1295125194,1295125195,1295125196,1295125197]
const STATION_IDS:Array[int]=[51065527,408117948,408117949,408117950,408117951,408117952,408117953]
const WHARVES=[
	[2,Vector3(139.267,4.5,139.544),Vector3(143.014,4.5,62.0)],
	[3,Vector3(84.518,4.5,143.7),Vector3(96.20,4.5,55.5)],
	[4,Vector3(38.282,4.5,138.5),Vector3(49.0,4.5,50.0)],
	[5,Vector3(-8.061,4.5,134.0),Vector3(3.70,4.5,44.5)],
	[6,Vector3(-54.003,4.5,130.0),Vector3(-42.50,4.5,40.0)]
]

static func excluded_way_ids() -> Array[int]:return IDS+STATION_IDS

static func metadata() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for d in WHARVES:
		var arrive:Vector3=d[1]+(d[2]-d[1]).normalized()*3.5
		result.append({"id":"cq_wharf_%d"%d[0],"name":"Circular Quay · Wharf %d"%d[0],"center":(d[1]+d[2])*.5,"map_position":d[1],"arrival":arrive,"position":arrive,"source":"https://transportnsw.info/document/4688/circular-quay-stop-guide.pdf","confidence":"OSM actual roof outlines; 2–6 numbering checked against TfNSW. Platform height and roof elevations inferred; not a working ferry timetable."})
	result.append({"id":"cq_station","name":"Circular Quay Railway Station","center":Vector3(13.817,4.5,149.978),"map_position":Vector3(13.817,4.5,149.978),"arrival":Vector3(11.93,4.5,167.36),"position":Vector3(11.93,4.5,167.36),"source":"https://www.hms.heritage.nsw.gov.au/App/Item/ViewItem?itemId=4801109","confidence":"OSM outline; 2023 north-facade photograph and Heritage NSW description. Granite, galleries and two-level composition authored; elevations approximate. Public ground concourse only, no working railway."})
	for d in [
		["cq_eastbank","Eastbank Café · Bar · Pizzeria",Vector3(213.5632,4.5,71.8168),Vector3(-.9931766,0,-.1166199),15.0,"node/4242649492","way/23717454","https://eastbank.com.au/"],
		["cq_searock","Searock Grill",Vector3(218.5538,4.5,21.4607),Vector3(-.9931656,0,-.1167137),12.0,"node/4739109527","way/23717448","https://searock.com.au/"],
		["cq_city_extra","City Extra",Vector3(68.6112,4.5,143.5034),Vector3(.1075977,0,-.9941945),21.0,"node/4422281496","way/51065527","https://cityextra.com.au/"]
	]:
		var n:Vector3=d[3];var center:Vector3=d[2]
		var arrive:Vector3=center+n*1.85+Vector3.UP.cross(n)*(-float(d[4])*.38)
		result.append({"id":d[0],"name":d[1],"center":center,"map_position":center,"arrival":arrive,"position":arrive,"front":[center.x,center.z],"normal":[n.x,n.z],"width":d[4],"osm":d[5],"building":d[6],"source":d[7],"evidence":"Operator-confirmed address and actual street-front photograph; OSM point projected to mapped exterior edge","confidence":"Photograph-authored exterior; window and furniture dimensions estimated; private interior remains closed"})
	return result

static func mapped_parts() -> Array:
	var result:Array=[]
	for item in City.data().buildings:
		if int(str(item.id).get_slice("/",1)) in IDS:result.append(item)
	return result

static func _wharf_for(center:Vector2) -> int:
	var nearest:=0;var best:=INF
	for i in WHARVES.size():
		var d:float=center.distance_to(Vector2(WHARVES[i][1].x,center.y))
		if d<best:best=d;nearest=i
	return nearest

static func footprints() -> Array[PackedVector2Array]:
	var result:Array[PackedVector2Array]=[]
	for item in mapped_parts():
		var poly:=Geo.polygon(item.outline)
		for j in poly.size():poly[j]+=Vector2(item.center[0],item.center[1])
		result.append(poly)
	for item in City.data().buildings:
		if int(str(item.id).get_slice("/",1)) in STATION_IDS:
			var poly:=Geo.polygon(item.outline)
			for j in poly.size():poly[j]+=Vector2(item.center[0],item.center[1])
			result.append(poly)
	return result

static func build(w:Node3D) -> void:
	if w.has_meta("circular_quay_detail"):return
	for key in Fronts.COLORS:w._mat("ds_"+key,Color(Fronts.COLORS[key]),.32 if key=="glass" else .76,.3 if key in ["glass","frame","gold"] else 0.0)
	w._mat("cq_roof",Color("6d8e88"),.57,.43)
	w._mat("cq_roof_rib",Color("526e6b"),.51,.52)
	w._mat("cq_pier",Color("898b82"),.95)
	w._mat("cq_sign",Color("268448"),.7)
	w._mat("cq_tactile",Color("cfb642"),.9)
	w._mat("cq_granite",Color("c7b9af"),.67,.12)
	_station(w)
	var groups:Array=[[],[],[],[],[]]
	for item in mapped_parts():groups[_wharf_for(Vector2(item.center[0],item.center[1]))].append(item)
	for i in groups.size():_pier(w,WHARVES[i],groups[i])
	for item in metadata():
		w.anchors[item.id]=item.arrival
		if item.has("front"):_restaurant(w,item)
	_promenade(w)
	w.set_meta("circular_quay_detail",metadata())
	w.set_meta("circular_quay_geometry",{"roof_source":"OSM retained outlines (28 original roofs/kiosk footprints)","elevations":"flat-world platform datum 4.58m; roof heights inferred from builder photographs","operational_scope":"Public pier walking and exterior dining; no live ferry service or private shop interior","old_pier_ids_forbidden":["quay/pier/0","quay/pier/1","quay/pier/2","quay/pier/3","quay/pier/4","quay/transit_hall"]})

static func _pier(w:Node3D,d:Array,parts:Array):
	var along:Vector3=(d[2]-d[1]).normalized()
	var right:=Vector3(-along.z,0,along.x)
	var all:=PackedVector2Array()
	for item in parts:
		if item.tags.get("building","")!="roof":continue
		for p in item.outline:all.append(Vector2(p[0]+item.center[0],p[1]+item.center[1]))
	var hull:=Geometry2D.convex_hull(all)
	if hull.size()>1 and hull[0].is_equal_approx(hull[-1]):hull.resize(hull.size()-1)
	var expanded:=Geometry2D.offset_polygon(hull,.5)
	var deck:PackedVector2Array=expanded[0] if not expanded.is_empty() else hull
	# World-aligned top connects continuously to the retained real shoreline.
	var body=w._structure_mesh("circular_quay/wharf/%d/deck"%d[0],Geo.prism(deck,w.GROUND-.70,w.GROUND+.08),Vector3.ZERO,"cq_pier",1600000)
	body.set_meta("walkable_polygon",deck)
	body.set_meta("wharf_number",d[0])
	for item in parts:
		var at:=Vector3(item.center[0],w.GROUND,item.center[1])
		var poly:=Geo.polygon(item.outline)
		if item.tags.get("building","")=="roof":
			var height:=6.2 if d[0]==3 and int(str(item.id).get_slice("/",1))==270803850 else 3.85
			var roof=w._structure_mesh("circular_quay/roof/"+str(item.id),Geo.prism(poly,height,height+.15),at,"cq_roof",180000)
			roof.set_meta("source_outline",poly)
			roof.set_meta("source_osm",item.id)
			roof.set_meta("geometry_scope","Mapped plan outline, estimated roof elevation")
			_roof_ribs(w,roof,poly,right,along,height+.17)
		else:
			var shop=w._structure_mesh("circular_quay/kiosk/"+str(item.id),Geo.prism(poly,.08,2.95),at,"ds_stone",90000)
			shop.set_meta("source_osm",item.id)
			# Unverified tenant graphics are deliberately omitted; mapped kiosks
			# retain their real footprint and a restrained glazed service edge.
			for i in poly.size():
				var a:=poly[i];var b:=poly[(i+1)%poly.size()]
				if a.distance_to(b)<1.5:continue
				var center:=Vector3((a.x+b.x)*.5,1.76,(a.y+b.y)*.5)
				var axis:=Vector3(b.x-a.x,0,b.y-a.y)
				var view=w._box(shop,center,Vector3(.028,1.85,a.distance_to(b)-.24),"ds_glass")
				view.basis=Basis.looking_at(axis,Vector3.UP)
	# Column grids follow each pier's own axis. The middle stays open.
	var length:float=d[1].distance_to(d[2])
	for row in range(1,9):
		var p:Vector3=d[1].lerp(d[2],row/9.0)
		for side in [-1,1]:
			var c:Vector3=p+right*side*7.0
			var column_height:=6.18 if d[0]==3 and row>1 else 3.8
			w._structure_box("circular_quay/wharf/%d/column/%d/%d"%[d[0],row,side],c+Vector3.UP*column_height*.5,Vector3(.16,column_height,.16),"steel",70000)
			w._batch_cylinder(c+Vector3.DOWN*2.0,.26,5.0,"ds_stone")
	# Berth edges have rail gaps along the boarding sections, not impassable fences.
	for side in [-1,1]:
		for section in [[.02,.29],[.71,.94]]:
			var a:Vector3=d[1].lerp(d[2],section[0])+right*side*8.2
			var b:Vector3=d[1].lerp(d[2],section[1])+right*side*8.2
			_rail(w,a,b,"%d_%d_%s"%[d[0],side,str(section[0])])
		for t in [.43,.59]:
			var at:Vector3=d[1].lerp(d[2],t)+right*side*7.65
			w._batch_box(at+Vector3.UP*.094,Vector3(.48,.02,4.8),"cq_tactile",Basis.looking_at(along,Vector3.UP))
	var entry:Vector3=d[1]
	var facing:Vector3=-along
	var frame:=Basis(Vector3.UP.cross(facing),Vector3.UP,facing)
	var fascia=w._structure_box("circular_quay/wharf/%d/gate_sign"%d[0],entry+Vector3.UP*3.05,Vector3(12.5,.62,.12),"cq_sign",85000,frame)
	_label(fascia,"Wharf %d"%d[0],Vector3(0,0,.08),.35)
	# Passenger benches and ticket readers are outside a 2.4m-wide central route.
	for side in [-1,1]:
		for t in [.72,.84]:
			var at:Vector3=d[1].lerp(d[2],t)+right*side*5.5
			Darling._bench(w,at,2.6,along,"cq_%d_%d_%s"%[d[0],side,str(t)])
		w._structure_box("circular_quay/wharf/%d/reader/%d"%[d[0],side],entry+right*side*1.75+Vector3.UP*.57,Vector3(.19,1.14,.22),"steel",45000,frame)
		w._batch_box(entry+right*side*1.75+Vector3.UP*1.17,Vector3(.24,.13,.22),"ds_blue",frame)
	# Wharf 3's real two-level Manly shed is distinguished by a high clerestory.
	if d[0]==3:
		var mid:Vector3=d[1].lerp(d[2],.49)
		w._batch_box(mid+Vector3.UP*3.78,Vector3(12.5,.24,length*.64),"ds_frame",Basis.looking_at(along,Vector3.UP))
		for side in [-1,1]:w._batch_box(mid+right*side*6.25+Vector3.UP*4.6,Vector3(.10,1.3,length*.64),"ds_glass",Basis.looking_at(along,Vector3.UP))
		for j in 16:
			var p:Vector3=d[1].lerp(d[2],.17+j*.043)
			for side in [-1,1]:w._batch_box(p+right*side*6.3+Vector3.UP*4.6,Vector3(.11,1.5,.16),"ds_cream")

static func _roof_ribs(w:Node3D,body:Node3D,poly:PackedVector2Array,right:Vector3,along:Vector3,y:float):
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tangent:=Vector2(along.x,along.z)
	var cross_axis:=Vector2(right.x,right.z)
	var low:=INF;var high:=-INF
	for p in poly:low=minf(low,p.dot(tangent));high=maxf(high,p.dot(tangent))
	for i in range(ceil((high-low)/1.2)):
		var level:float=low+i*1.2
		var intersects:Array[Vector2]=[]
		for j in poly.size():
			var a:=poly[j];var b:=poly[(j+1)%poly.size()]
			var da:=a.dot(tangent)-level;var db:=b.dot(tangent)-level
			if da*db<0:intersects.append(a.lerp(b,da/(da-db)))
		if intersects.size()<2:continue
		intersects.sort_custom(func(a,b):return a.dot(cross_axis)<b.dot(cross_axis))
		var a:Vector2=intersects[0];var b:Vector2=intersects[-1]
		Geo._append_box(surface,Vector3((a.x+b.x)*.5,y,(a.y+b.y)*.5),Vector3(.035,.035,a.distance_to(b)),Basis.looking_at(Vector3(b.x-a.x,0,b.y-a.y),Vector3.UP))
	Geo._commit_detail(w,body,surface,"cq_roof_rib")

static func _rail(w:Node3D,a:Vector3,b:Vector3,id:String):
	var frame:=Basis.looking_at(b-a,Vector3.UP)
	for y in [.56,1.04]:w._batch_box((a+b)*.5+Vector3.UP*y,Vector3(.045,.045,a.distance_to(b)),"steel",frame)
	var count:=maxi(2,ceil(a.distance_to(b)/1.8))
	for j in count+1:
		var p:Vector3=a.lerp(b,float(j)/count)
		w._structure_box("circular_quay/rail/"+id+"/"+str(j),p+Vector3.UP*.51,Vector3(.065,1.02,.065),"steel",42000)

static func _label(parent:Node3D,value:String,at:Vector3,height:float):
	var text:=Label3D.new();text.text=value;text.font_size=96;text.pixel_size=height/96.0;text.outline_size=0;text.position=at;text.modulate=Color("f1eee0");text.visibility_range_end=250;parent.add_child(text)

static func _station(w:Node3D):
	var source:Dictionary={}
	for item in City.data().buildings:
		if item.id=="way/51065527":source=item;break
	if source.is_empty():return
	var center:=Vector3(source.center[0],w.GROUND,source.center[1])
	var poly:=Geo.polygon(source.outline)
	var frame:=Basis(Vector3(.9941945,0,.1075977),Vector3.UP,Vector3(-.1075977,0,.9941945))
	# Six separately mapped ground enclosures also sit beneath the station.
	# Retain their plans, cut a clear central public passage, and replace their
	# mistaken office-window extrusion with the photographed station palette.
	var corridor:=PackedVector2Array()
	for p in [Vector3(-3.2,0,-19),Vector3(3.2,0,-19),Vector3(3.2,0,19),Vector3(-3.2,0,19)]:
		var q:Vector3=center+frame*p;corridor.append(Vector2(q.x,q.z))
	for item in City.data().buildings:
		if not int(str(item.id).get_slice("/",1)) in STATION_IDS or item.id=="way/51065527":continue
		var outline:=Geo.polygon(item.outline)
		for j in outline.size():outline[j]+=Vector2(item.center[0],item.center[1])
		var clipped:=Geometry2D.clip_polygons(outline,corridor)
		for i in clipped.size():
			var poly_piece:PackedVector2Array=clipped[i]
			var core=w._structure_mesh("circular_quay/station/ground/"+str(item.id)+"/"+str(i),Geo.prism(poly_piece,.08,5.22),Vector3.UP*w.GROUND,"cq_granite",250000)
			core.set_meta("source_osm",item.id)
			for edge in poly_piece.size():
				var a:=poly_piece[edge];var b:=poly_piece[(edge+1)%poly_piece.size()]
				var delta:=Vector3(b.x-a.x,0,b.y-a.y)
				if delta.length()<1.3:continue
				var facing:=Basis.looking_at(delta,Vector3.UP)
				w._batch_box(Vector3((a.x+b.x)*.5,w.GROUND+2.52,(a.y+b.y)*.5),Vector3(.04,3.62,delta.length()-.65),"ds_glass",facing)
				for j in range(maxi(2,ceili(delta.length()/2.0))):
					var p:Vector2=a.lerp(b,float(j)/maxi(2,ceili(delta.length()/2.0)))
					w._batch_box(Vector3(p.x,w.GROUND+2.52,p.y),Vector3(.06,3.62,.10),"ds_frame",facing)
	# Retain the full mapped plan, but raise the railway floor over a genuinely
	# open public concourse. The previous solid generic 4-storey volume is gone.
	var ground=w._structure_mesh("circular_quay/station/concourse",Geo.prism(poly,.035,.08),center,"paving",1600000)
	ground.set_meta("source_osm","way/51065527")
	ground.set_meta("precision","Mapped outline; floor elevations inferred from photograph")
	w._structure_mesh("circular_quay/station/railway_floor",Geo.prism(poly,5.30,5.92),center,"cq_granite",1600000)
	w._structure_mesh("circular_quay/station/cahill_roof",Geo.prism(poly,12.20,12.62),center,"cq_granite",1600000)
	# Broad lower piers form the actual ground-level arcade rhythm. Keep every
	# restaurant approach and pier connection outside the stone pier solids.
	for side in [-1,1]:
		for j in 14:
			var x:float=-80+j*12.25
			var pos:Vector3=center+frame*Vector3(x,2.65,side*10.9)
			var skip:=false
			for target in metadata():
				var at:Vector3=target.arrival
				if Vector2(at.x-pos.x,at.z-pos.z).length()<1.8:skip=true
			if skip:continue
			w._structure_box("circular_quay/station/pier/%d/%d"%[side,j],pos,Vector3(1.30,5.30,1.45),"cq_granite",190000,frame)
		var north:bool=side==-1
		var outward:Vector3=frame*Vector3(0,0,side)
		var face:=Basis(Vector3.UP.cross(outward),Vector3.UP,outward)
		# A long, restrained name band over a single narrow steel-window strip.
		# Photographed pink granite forms a central pavilion; sides remain open galleries.
		for band in [[6.28,.72],[10.45,3.50]]:
			w._structure_box("circular_quay/station/facade/%d/%s"%[side,str(band[0])],center+frame*Vector3(0,band[0],side*11.4),Vector3(113.0,band[1],.38),"cq_granite",250000,frame)
		for x in [-55.8,55.8]:w._structure_box("circular_quay/station/cheek/%d/%s"%[side,str(x)],center+frame*Vector3(x,8.2,side*11.4),Vector3(1.5,3.8,.38),"cq_granite",170000,frame)
		var glass=w._structure_box("circular_quay/station/window_band/%d"%side,center+frame*Vector3(0,7.70,side*11.42),Vector3(110.0,1.78,.08),"ds_glass",150000,frame)
		for j in 54:
			var x:float=-54.5+j*2.05
			w._batch_box(center+frame*Vector3(x,7.70,side*11.49),Vector3(.075,1.78,.10),"ds_frame",frame)
		for y in [6.81,7.42,8.03,8.59]:w._batch_box(center+frame*Vector3(0,y,side*11.50),Vector3(110.0,.055,.11),"ds_frame",frame)
		for j in 7:w._batch_box(center+frame*Vector3(-46.3+j*15.4,7.70,side*11.53),Vector3(1.25,1.90,.22),"cq_granite",frame)
		# Fine stone joints are geometry, not a stretched photograph.
		for row in 7:
			var y:float=8.92+row*.46
			w._batch_box(center+frame*Vector3(0,y,side*11.605),Vector3(112.9,.010,.014),"ds_stone",frame)
		for j in 78:
			var x:float=-55.6+j*1.43
			w._batch_box(center+frame*Vector3(x,10.45,side*11.608),Vector3(.010,3.40,.014),"ds_stone",frame)
		var title:=Label3D.new();title.text="CIRCULAR   QUAY   RAILWAY   STATION";title.font_size=96;title.pixel_size=.020;title.outline_size=0;title.modulate=Color("3c3f3f");title.position=center+frame*Vector3(0,10.77,side*11.64);title.basis=face;title.visibility_range_end=500;w.add_child(title)
		# Open galleries at either end, with low parapets and slender metal columns.
		for end in [-1,1]:
			var middle:float=end*70.6
			w._structure_box("circular_quay/station/gallery_base/%d/%d"%[side,end],center+frame*Vector3(middle,6.17,side*11.1),Vector3(28.0,.50,.28),"cq_granite",200000,frame)
			for j in 8:
				var x:float=end*(57.4+j*3.8)
				w._batch_box(center+frame*Vector3(x,8.45,side*11.13),Vector3(.13,4.72,.13),"ds_frame",frame)
			for y in [6.9,8.65]:w._batch_box(center+frame*Vector3(middle,y,side*11.15),Vector3(27.8,.06,.08),"ds_frame",frame)
		# Entry lettering is on the lintel, above rather than across the clear opening.
		var sign:=Label3D.new();sign.text="CIRCULAR QUAY";sign.font_size=96;sign.pixel_size=.004;sign.modulate=Color("3c3f3f");sign.outline_size=0;sign.position=center+frame*Vector3(0,4.72,side*11.08);sign.basis=face;sign.visibility_range_end=200;w.add_child(sign)
	# The roof/track details convey the double-deck transport structure. They do
	# not join to an invented elevated road or advertise operating train service.
	for side in [-1,1]:
		w._batch_box(center+frame*Vector3(0,12.67,side*3.3),Vector3(169.0,.08,6.3),"road",frame)
		for trackside in [-1,1]:w._batch_box(center+frame*Vector3(0,6.06,side*3.3+trackside*.72),Vector3(169.0,.10,.07),"steel",frame)
		for y in [12.98,13.40]:w._batch_box(center+frame*Vector3(0,y,side*11.2),Vector3(169.0,.075,.09),"steel",frame)
		for j in 57:w._batch_box(center+frame*Vector3(-84+j*3.0,13.12,side*11.2),Vector3(.055,.80,.055),"steel",frame)
	for j in 110:w._batch_box(center+frame*Vector3(-84+j*1.53,5.98,0),Vector3(.22,.08,8.8),"ds_coal",frame)
	# Shallow soffit fixtures and service gates leave the central public crossing open.
	for x in [-62,-38,-14,14,38,62]:w._batch_box(center+frame*Vector3(x,5.19,0),Vector3(2.0,.055,.35),"lamp",frame)

static func _restaurant(w:Node3D,item:Dictionary):
	var f=Fronts.Frontage.new(w,item)
	var old:String="darling_square/"+item.id+"/frontage"
	var id:String="circular_quay/restaurant/"+item.id
	w.structures[id]=w.structures[old];w.structures.erase(old)
	f.body.set_meta("damage_id",id);f.body.name=id.replace("/","_")
	f.body.set_meta("public_arrival",item.arrival)
	f.door(-item.width*.38,1.25)
	match item.id:
		"cq_eastbank":_eastbank(f)
		"cq_searock":_searock(f)
		"cq_city_extra":_city_extra(f)
	f.finish()

static func _eastbank(f):
	for x in [-3.3,.45,4.2]:
		f.window(x,3.35,.12,4.20,"glass")
		f.window(x,3.35,4.3,6.1,"glass")
		f.box(Vector3(x,4.25,.26),Vector3(3.35,.16,.34),"slate")
	for x in [-7.35,6.55]:f.box(Vector3(x,3.1,.50),Vector3(.8,6.2,.95),"stone")
	f.text("E A S T B A N K",Vector3(.4,3.7,.35),.21)
	f.text("CAFE · BAR · PIZZERIA",Vector3(.4,3.38,.35),.10)
	for x in [-3.2,.4,4.0]:
		f.table(x,1.6,"slate")
		for s in [-1,1]:Darling._cafe_seat(f,x+s*.48,1.65)
	for x in [-4.4,5.6]:
		f.box(Vector3(x,.42,1.7),Vector3(.45,.84,.45),"stone")
		f.disc(Vector3(x,.94,1.7),.30,"leaf")

static func _searock(f):
	for x in [-2.1,1.5,4.1]:f.window(x,2.45,.50,3.9,"glass")
	for x in [-5.9,-.5,5.8]:
		f.box(Vector3(x,2.2,.30),Vector3(.48,4.4,.42),"slate")
		for j in 10:f.beam(Vector3(x-.2,j*.42,.52),Vector3(x+.20,j*.42+.2,.52),.018,"stone")
	for x in [-1.9,1.6,4.1]:
		f.box(Vector3(x,.64,.34),Vector3(2.20,.065,.31),"stone")
		for j in 6:
			f.cylinder(Vector3(x-.83+j*.3,.85,.40),.042,.38,"green",8)
			f.cylinder(Vector3(x-.83+j*.3,1.08,.40),.019,.13,"green",8)
	f.box(Vector3(-.5,3.20,.76),Vector3(.85,.95,.10),"white")
	f.text("SEAROCK\nGRILL",Vector3(-.5,3.24,.825),.13,Color("344651"))
	f.text("Steak & Seafood",Vector3(-.5,2.92,.825),.07,Color("344651"))
	for x in [1.4,4.0]:
		f.table(x,1.5,"wood")
		Darling._cafe_seat(f,x-.46,1.5);Darling._cafe_seat(f,x+.46,1.5)

static func _city_extra(f):
	for x in [-5.5,-1.9,1.7,5.3,8.9]:
		f.window(x,3.38,.16,3.15,"glass")
		f.window(x,3.38,4.0,5.70,"glass")
		f.awning(x,3.48,3.65,2.0,"red")
		for side in [-1,1]:f.beam(Vector3(x+side*1.58,5.92,.1),Vector3(x+side*1.58,3.36,2.1),.055,"slate")
	f.text("City Extra",Vector3(1.0,2.48,.38),.53,Color("e54742"))
	f.text("OPEN 24 HOURS",Vector3(1.0,1.9,.38),.12)
	for x in [-4.7,-1.3,2.1,5.5,8.5]:
		f.table(x,1.17,"white")
		Darling._cafe_seat(f,x-.40,1.6);Darling._cafe_seat(f,x+.4,1.6)
	# Lower hedge marks the actual outdoor dining edge while the left door remains clear.
	f.box(Vector3(2.0,.30,2.30),Vector3(15.0,.60,.40),"slate")
	for j in 40:f.box(Vector3(-5.3+j*.375,.76,2.30),Vector3(.40,.38,.44),"leaf")

static func _promenade(w:Node3D):
	# The western edge is the actual retained OSM coastline, not a rectangular
	# platform extended across the water. Only its landward public strip is paved.
	var shore:=Geo.polygon([[207.697,-93.62],[204.065,-82.633],[200.85,-71.534],[199.057,-59.89],[198.715,-51.786],[199.057,-42.101],[199.833,-35.578],[201.645,-28.965],[203.4,-21.34],[204.426,-13.158],[203.908,.256],[203.779,1.314],[203.65,2.405],[202.901,17.333],[202.8,18.49],[202.707,19.559],[195.463,92.373],[188.607,109.806],[186.491,112.645],[182.656,116.341],[244.0,124.0],[247.0,-94.0]])
	w._structure_mesh("circular_quay/east_prom_enade",Geo.prism(shore,.095,.115),Vector3.UP*w.GROUND,"paving",1500000)
	# Eastern foreshore: furniture sits landward of the through pedestrian route.
	# The true shore line remains supplied by CityMap; no fabricated road edges.
	for i in 7:
		var p:=Vector3(208.0+i*.65,w.GROUND,-49.0+i*21.0)
		if i in [3,6]:continue # leave restaurant terraces and openings clear
		Darling._bench(w,p,2.8,Vector3(.116,0,-.993),"cq_east_%d"%i)
		w._batch_cylinder(p+Vector3(0,.32,2.2),.23,.64,"ds_coal")
		w._batch_cylinder(p+Vector3(0,.66,2.2),.25,.055,"steel")
	# Bollards mark the mapped southern apron, spaced clear of each wharf gate.
	for i in 16:
		var p:=Vector3(-58+i*15.4,w.GROUND,140.0+i*1.53)
		var blocked:=false
		for d in WHARVES:
			if Vector2(p.x-d[1].x,p.z-d[1].z).length()<9.5:blocked=true
		if blocked:continue
		w._batch_cylinder(p+Vector3.UP*.38,.14,.76,"steel")
