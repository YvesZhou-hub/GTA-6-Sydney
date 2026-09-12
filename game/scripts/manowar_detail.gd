extends RefCounted
## Actual OSM pier polygons, original authored fittings from operator photos.
## Heights stay estimates in the flat world. See docs/MANOWAR_REFERENCE.md.
const Geo=preload("res://scripts/city_landmarks.gd")
const PIER_Y:=4.58
const FLOAT_Y:=2.55
const REPLACED_ROADS:=["way/547383204","way/1218228843","way/1218228844","way/1218228845","way/1218228846","way/1218228847","way/1218228848","way/1218228849"]
const GANGWAYS:=[
	["north",Vector3(490.182,PIER_Y,-230.065),Vector3(495.800,FLOAT_Y,-237.980)],
	["east",Vector3(493.407,PIER_Y,-215.916),Vector3(503.349,FLOAT_Y,-212.989)]]

static func metadata() -> Array[Dictionary]:
	return [
		{"id":"manowar_north","name":"Man O’War Steps · North Jetty","arrival":Vector3(499.1,FLOAT_Y,-242.7),"map_position":Vector3(500.5,FLOAT_Y,-244.65),"source":"https://api.openstreetmap.org/api/0.6/way/354759944/full","confidence":"Mapped pontoon and gangway; estimated fixed water datum and fittings"},
		{"id":"manowar_east","name":"Man O’War Steps · East Jetty","arrival":Vector3(507.5,FLOAT_Y,-211.8),"map_position":Vector3(508.2,FLOAT_Y,-211.55),"source":"https://api.openstreetmap.org/api/0.6/way/392403849/full","confidence":"Mapped pontoon and gangway; estimated fixed water datum and fittings"}]

static func pier_data() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/manowar_piers.json")).piers

static func _surface() -> SurfaceTool:
	var s:=SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES);return s

static func _beam(s:SurfaceTool,a:Vector3,b:Vector3,width:float,depth:float):
	var delta:=b-a
	Geo._append_box(s,(a+b)*.5,Vector3(width,depth,delta.length()),Basis.looking_at(delta,Vector3.UP if absf(delta.normalized().y)<.99 else Vector3.RIGHT))

static func build(w:Node3D):
	if w.has_meta("manowar_detail"):return
	w._mat("mw_stone",Color("b2a78d"),.96)
	w._mat("mw_cap",Color("d0c6ad"),.91)
	w._mat("mw_paving",Color("505954"),.96)
	w._mat("mw_timber",Color("756c58"),.88)
	w._mat("mw_mortar",Color("847e6f"),.98)
	w._mat("mw_metal",Color("758885"),.46,.48)
	w._mat("mw_blue",Color("183b80"),.73)
	for data in pier_data():
		var poly:=Geo.polygon(data.points)
		var floating:bool=data.tags.get("floating","")=="yes"
		var top:=FLOAT_Y if floating else PIER_Y
		var body:StaticBody3D=w._structure_mesh("quay/manowar/pier/%s"%int(data.id),Geo.prism(poly,top-.75 if floating else -1.1,top),Vector3.ZERO,"mw_timber" if floating else "mw_stone",24000000)
		body.set_meta("source_osm","way/%s"%int(data.id))
		body.set_meta("source_outline",data.points)
		Geo._detail(w,body,Geo.prism(poly,top-.035,top+.008),"mw_cap" if floating else "mw_paving")
		var trim:=_surface();var joints:=_surface()
		for i in poly.size():
			var a:=Vector3(poly[i].x,top,poly[i].y);var b:=Vector3(poly[(i+1)%poly.size()].x,top,poly[(i+1)%poly.size()].y)
			# The cap is flush: an actual pedestrian can step through both gangway mouths.
			_beam(trim,a-Vector3.UP*.055,b-Vector3.UP*.055,.14,.12)
			if not floating:
				for y in [-.6,.0,.6,1.2,1.8,2.4,3.0,3.6,4.2]:
					_beam(joints,Vector3(a.x,y,a.z),Vector3(b.x,y,b.z),.019,.022)
				var length:=a.distance_to(b)
				for row in 8:
					for n in range(1,int(length/1.8)):
						var p:=a.lerp(b,(n*1.8+(.8 if row%2 else 0))/length)
						_beam(joints,Vector3(p.x,-.5+row*.6,p.z),Vector3(p.x,.06+row*.6,p.z),.019,.022)
		Geo._commit_detail(w,body,trim,"mw_cap")
		if not floating:Geo._commit_detail(w,body,joints,"mw_mortar")
		else:_pontoon_fittings(w,body,poly)
	for gangway in GANGWAYS:_gangway(w,gangway)
	_stone_steps(w)
	_entrance(w)
	for item in metadata():w.anchors[item.id]=item.arrival
	w.set_meta("manowar_detail",metadata())

static func _pontoon_fittings(w:Node3D,body:StaticBody3D,poly:PackedVector2Array):
	var dark:=_surface();var pale:=_surface();var steel:=_surface()
	# Four white-capped mooring piles around each pontoon, clear of its shoreward mouth.
	var corners:Array=[]
	for i in poly.size():
		var a:Vector2=poly[(i+poly.size()-1)%poly.size()]-poly[i]
		var b:Vector2=poly[(i+1)%poly.size()]-poly[i]
		if absf(a.normalized().cross(b.normalized()))>.4:corners.append(poly[i])
	for p:Vector2 in corners:
		Geo._append_box(dark,Vector3(p.x,1.55,p.y),Vector3(.48,5.1,.48),Basis.IDENTITY)
		Geo._append_box(pale,Vector3(p.x,4.35,p.y),Vector3(.51,1.3,.51),Basis.IDENTITY)
	# Slender edge posts and rail only at the back corners, never across the berth.
	for p:Vector2 in corners:
		Geo._append_box(steel,Vector3(p.x,FLOAT_Y+.32,p.y),Vector3(.13,.65,.13),Basis.IDENTITY)
	Geo._commit_detail(w,body,dark,"mw_timber")
	Geo._commit_detail(w,body,pale,"white")
	Geo._commit_detail(w,body,steel,"mw_metal")

static func _gangway(w:Node3D,data:Array):
	var a:Vector3=data[1];var b:Vector3=data[2]
	# Closed wedge with a genuinely sloping walk surface and horizontal end seams.
	var direction:=Vector3(b.x-a.x,0,b.z-a.z).normalized()
	var side:=Vector3(-direction.z,0,direction.x)*1.15
	a-=direction*.20;b+=direction*.20
	# North's mapped bridge begins inside the masonry footprint. Keep its
	# apron level until the whole width clears the pier, then descend.
	var knee:Vector3=a.lerp(b,.42 if data[0]=="north" else .04);knee.y=a.y
	var top:Array[Vector3]=[a+side,knee+side,b+side,b-side,knee-side,a-side]
	var faces:Array=[[0,1,4,5],[1,2,3,4],[6,11,10,7],[7,10,9,8]]
	for i in 6:faces.append([i,i+6,(i+1)%6+6,(i+1)%6])
	var s:=_surface()
	for face_index in faces.size():
		var face:Array=faces[face_index]
		var vertices:Array[Vector3]=[]
		for index in face:vertices.append(top[index%6]-(Vector3.UP*.32 if index>=6 else Vector3.ZERO))
		var n:Vector3=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
		# Orient every face away from the centre; Geo handles Godot clockwise winding.
		if (face_index<2 and n.y<0) or (face_index in [2,3] and n.y>0) or (face_index>=4 and n.dot(vertices[0]-((a+b)*.5-Vector3.UP*.16))<0):n=-n
		Geo._triangle(s,vertices[0],vertices[1],vertices[2],n,Vector2.ZERO,Vector2.ONE,Vector2.ONE)
		Geo._triangle(s,vertices[0],vertices[2],vertices[3],n,Vector2.ZERO,Vector2.ONE,Vector2.ZERO)
	var body:StaticBody3D=w._structure_mesh("quay/manowar/gangway/"+data[0],s.commit(),Vector3.ZERO,"mw_timber",24000000)
	var rails:=_surface();var seams:=_surface()
	for sign_value:int in [-1,1]:
		var edge:=side*sign_value
		for height in [.48,1.08]:
			_beam(rails,a+edge+Vector3.UP*height,knee+edge+Vector3.UP*height,.045,.045)
			_beam(rails,knee+edge+Vector3.UP*height,b+edge+Vector3.UP*height,.045,.045)
		for i in 7:
			var p:=_profile_point(a,knee,b,i/6.0)+edge
			_beam(rails,p,p+Vector3.UP*1.1,.05,.05)
	for i in range(1,int(a.distance_to(b)/.23)):
		var p:=_profile_point(a,knee,b,i*.23/a.distance_to(b))+Vector3.UP*.012
		_beam(seams,p-side*.98,p+side*.98,.009,.009)
	Geo._commit_detail(w,body,rails,"mw_metal")
	Geo._commit_detail(w,body,seams,"mw_mortar")
	# Handrails are actual side barriers; their ends do not cap the walking route.
	for sign_value:int in [-1,1]:
		for section:Array in [[a,knee],[knee,b]]:
			var start:Vector3=section[0]+side*sign_value+Vector3.UP*.55;var finish:Vector3=section[1]+side*sign_value+Vector3.UP*.55
			w._extra_box_collision(body,(start+finish)*.5,Vector3(.07,1.1,start.distance_to(finish)))
			var collision:CollisionShape3D=body.get_child(body.get_child_count()-1)
			collision.basis=Basis.looking_at(finish-start)

static func _profile_point(a:Vector3,knee:Vector3,b:Vector3,fraction:float) -> Vector3:
	var p:=a.lerp(b,fraction)
	var flat_length:=Vector2(a.x-knee.x,a.z-knee.z).length()
	var along:=Vector2(p.x-a.x,p.z-a.z).length()
	var run:=Vector2(b.x-knee.x,b.z-knee.z).length()
	p.y=a.y if along<=flat_length else lerpf(knee.y,b.y,(along-flat_length)/run)
	return p

static func _stone_steps(w:Node3D):
	var high:=Vector3(485.46,PIER_Y,-225.178);var low:=Vector3(484.943,PIER_Y-1.2,-228.685)
	var flat:=Vector3(low.x-high.x,0,low.z-high.z);var basis:=Basis.looking_at(flat)
	for i in 6:
		var p:=high.lerp(low,(i+.5)/6.0);var top:=PIER_Y-(i+1)*.20
		w._structure_box("quay/manowar/stone_step/%d"%i,Vector3(p.x,(top-1.1)*.5,p.z),Vector3(2.25,top+1.1,flat.length()/6.0+.02),"mw_stone",24000000,basis)

static func _entrance(w:Node3D):
	var along:=Vector3(479.639-473.920,0,-195.767+190.379).normalized()
	var side:=Vector3(-along.z,0,along.x)
	for index:int in [-1,1]:
		var pos:=Vector3(474.25,PIER_Y,-190.70)+side*index*2.22
		var pillar:StaticBody3D=w._structure_box("quay/manowar/entrance/%d"%index,pos+Vector3.UP*.72,Vector3(.62,1.44,.62),"mw_stone",800000)
		w._box(pillar,Vector3(0,.78,0),Vector3(.75,.18,.75),"mw_cap")
	var p:=Vector3(492.0,PIER_Y,-223.70)
	var sign:StaticBody3D=w._structure_box("quay/manowar/sign",p+Vector3.UP*1.2,Vector3(.58,2.4,.14),"mw_blue",180000)
	w._box(sign,Vector3(0,1.0,0),Vector3(2.1,.45,.16),"mw_blue")
	var text:=Label3D.new();text.text="Man O’War Steps";text.font_size=80;text.pixel_size=.0029;text.position=Vector3(0,1.0,.09);text.outline_size=0;text.modulate=Color.WHITE;sign.add_child(text)

static func capture_views() -> Array:
	return [["manowar-overview",Vector3(530,27,-187),Vector3(490,3,-220)],["manowar-gangway",Vector3(478,7.2,-209),Vector3(502,3.7,-215)]]

static func walk_routes() -> Array:
	var route:=[Vector3(473.92,PIER_Y,-190.379),Vector3(479.639,PIER_Y,-195.767),Vector3(490.154,PIER_Y,-216.874)]
	return [
		{"name":"manowar_north_jetty","points":route+[Vector3(489.119,PIER_Y,-222.963),GANGWAYS[0][1],GANGWAYS[0][2],metadata()[0].arrival]},
		{"name":"manowar_east_jetty","points":route+[GANGWAYS[1][1],GANGWAYS[1][2],metadata()[1].arrival]}]
