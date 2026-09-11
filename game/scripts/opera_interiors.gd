extends RefCounted
## Original public-space reconstruction from official 2024 plans and photographs.
## Room circulation, fitting counts and decorative dimensions remain game estimates.
const Geo = preload("res://scripts/city_landmarks.gd")
const CENTER := Vector3(427.2947742677,4.5,-321.4544052467)
const ANGLE := -13.232864688
const BOX_OFFICE := 5.4864
const UPPER := 11.2
const STAGE := 12.1
const CONCERT_X := -26.0
const JST_X := 23.0
static var _seat_count:int=0

static func basis() -> Basis:return Basis(Vector3.UP,deg_to_rad(ANGLE))
static func point(p:Vector3) -> Vector3:return CENTER+basis()*p
static func metadata() -> Array[Dictionary]:
	var records:Array[Dictionary]=[
		{"id":"opera_box_office","name":"悉尼歌剧院 · 票务大厅 / Box Office Foyer","p":Vector3(-37,BOX_OFFICE,54),"map":Vector3(0,0,51)},
		{"id":"opera_concert_hall","name":"悉尼歌剧院 · 音乐厅 / Concert Hall","p":Vector3(-12,UPPER,13),"map":Vector3(-26,0,-5)},
		{"id":"opera_joan_sutherland","name":"悉尼歌剧院 · Joan Sutherland 歌剧厅 / Theatre","p":Vector3(35,UPPER,6),"map":Vector3(23,0,-5)},
		{"id":"opera_northern_foyer","name":"悉尼歌剧院 · 北侧门厅 / Concert Hall Northern Foyer","p":Vector3(-9,UPPER,-64),"map":Vector3(-26,0,-67)}]
	for row:Dictionary in records:
		row.arrival=point(row.p);row.map_position=point(row.map);row.center=row.map_position
		row.source="https://www.sydneyoperahouse.com/visit/our-venues"
		row.detail="Public plans and photos · interior dimensions and circulation partly approximated"
		row.erase("p");row.erase("map")
	return records

static func _route(name:String,points:Array) -> Dictionary:
	var result:Array[Vector3]=[]
	for p:Vector3 in points:result.append(point(p))
	return {"name":name,"points":result}
static func walk_routes() -> Array[Dictionary]:
	return [
		_route("Covered concourse to ticket foyer and upper south foyer",[Vector3(-62,0,53),Vector3(-60,0,53),Vector3(-40,BOX_OFFICE,53),Vector3(-35,BOX_OFFICE,59),Vector3(-7,BOX_OFFICE,59),Vector3(-7,UPPER,37),Vector3(-7,UPPER,34)]),
		_route("Concert Hall south entrance to front stalls",[Vector3(-24,UPPER,64),Vector3(-24,UPPER,45),Vector3(-24,UPPER,34.5),Vector3(-6,UPPER,34.5),Vector3(-6,UPPER,13),Vector3(-12,UPPER,13),Vector3(-12,UPPER,11.3),Vector3(-26,UPPER,11.3)]),
		_route("Concert Hall harbour promenade through northern foyer",[Vector3(-24,UPPER,64),Vector3(-24,UPPER,45),Vector3(-24,UPPER,34.5),Vector3(-6,UPPER,34.5),Vector3(-7.5,UPPER,-62.5),Vector3(-9,UPPER,-64),Vector3(-9,UPPER,-75.5),Vector3(-26,UPPER,-75.5),Vector3(-26,UPPER+2.2,-63)]),
		_route("Joan Sutherland Theatre entrance to front side aisle",[Vector3(22,UPPER,64),Vector3(22,UPPER,45),Vector3(22,UPPER,34.5),Vector3(39.5,UPPER,33.5),Vector3(39.5,UPPER,6),Vector3(35,UPPER,6),Vector3(35,UPPER,3.4),Vector3(23,UPPER,3.4)]),
		_route("Joan Sutherland Theatre northern harbour foyer",[Vector3(22,UPPER,64),Vector3(22,UPPER,45),Vector3(22,UPPER,34.5),Vector3(39.5,UPPER,33.5),Vector3(39.5,UPPER,6),Vector3(38.5,UPPER,-37),Vector3(37.5,UPPER,-50.5),Vector3(35.5,UPPER,-54),Vector3(35.6,UPPER,-60.5),Vector3(23,UPPER,-60.5),Vector3(23,UPPER+2.2,-51)])]
static func capture_views() -> Array:
	var views:Array=[
		["opera-box-office",Vector3(-33,7.25,58),Vector3(14,7.0,44)],
		["opera-entry-stairs",Vector3(-15,7.4,60),Vector3(-7,13.0,37)],
		["opera-concert-hall",Vector3(-26,22.5,-29),Vector3(-26,19,17)],
		["opera-concert-stage",Vector3(-26,14.0,19),Vector3(-26,18,-20)],
		["opera-concert-organ",Vector3(-35,14,3),Vector3(-26,20,27)],
		["opera-joan-sutherland",Vector3(23,22,-34),Vector3(23,14,12)],
		["opera-concert-northern-foyer",Vector3(-37,13.0,-58),Vector3(-21,14,-74)],
		["opera-jst-northern-foyer",Vector3(12,13.0,-47),Vector3(29,13.5,-58)]]
	for view:Array in views:view[1]=point(view[1]);view[2]=point(view[2])
	return views

static func build(w:Node3D) -> void:
	if w.has_meta("opera_interiors"):return
	_materials(w)
	_seat_count=0
	var batch:Dictionary={}
	_box_office(w,batch)
	_attach_batch(w,"boxoffice/floor",batch)
	_concert(w,batch)
	w.set_meta("opera_concert_seats",_seat_count)
	_attach_batch(w,"concert/ceiling",batch)
	_jst(w,batch)
	w.set_meta("opera_jst_seats",_seat_count-int(w.get_meta("opera_concert_seats")))
	_attach_batch(w,"jst/ceiling",batch)
	_foyers(w,batch)
	var detail:=Node3D.new();detail.name="OperaInteriorFittings";detail.transform=Transform3D(basis(),CENTER);w.add_child(detail)
	_flush(w,detail,batch)
	w.set_meta("opera_interiors",metadata())
	w.set_meta("opera_interior_routes",walk_routes())
	w.set_meta("opera_interior_revision","public-2024-plans-2026-09")

static func _materials(w:Node3D) -> void:
	for row:Array in [["stone","b5a08b"],["concrete","bcb6a6"],["brushbox","aa7140"],["birch","dbb875"],["woodlight","c58c48"],["wooddark","684222"],["bronze","514537"],["black","131819"],["jst_wall","2d2927"],["magenta","a62d69"],["red","922f28"],["purple","673c76"],["reflector","e45087"],["pipe","c3b98d"],["light","ffefcd"]]:
		w._mat("opi_"+row[0],Color(row[1]),.76 if row[0]!="pipe" else .29,.65 if row[0]=="pipe" else .0)
	w.materials.opi_light.emission_enabled=true;w.materials.opi_light.emission=Color("ffe9bf");w.materials.opi_light.emission_energy_multiplier=.75
	# Original metre-scaled brushbox seams; no downloaded texture pixels.
	var shader:=Shader.new();shader.code="""shader_type spatial;
void fragment(){float seam=smoothstep(0.007,0.017,abs(fract(UV.x/0.19)-0.5)); float grain=sin(UV.y*9.0+sin(UV.x*35.0))*0.026;ALBEDO=vec3(0.61,0.37,0.18)*(0.83+seam*0.17+grain);ROUGHNESS=0.7;}"""
	var wood:=ShaderMaterial.new();wood.shader=shader;w.materials.opi_brushbox=wood

static func _box(w:Node3D,id:String,p:Vector3,size:Vector3,key:String,frame:Basis=Basis.IDENTITY) -> StaticBody3D:
	return w._structure_box("opera/interior/"+id,point(p),size,"opi_"+key,125000,basis()*frame)
static func _slab(w:Node3D,id:String,poly:PackedVector2Array,low:float,high:float,key:String) -> StaticBody3D:
	return w._structure_mesh("opera/interior/"+id,Geo.prism(poly,low,high),CENTER,"opi_"+key,180000,basis())
static func _st(batch:Dictionary,key:String) -> SurfaceTool:
	if not batch.has(key):
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);batch[key]=st
	return batch[key]
static func _tri(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,n:Vector3) -> void:
	Geo._triangle(st,a,b,c,n,Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z))
static func _detail(batch:Dictionary,key:String,p:Vector3,size:Vector3,frame:Basis=Basis.IDENTITY) -> void:
	# CPU vertices avoid per-chair mesh uploads/readbacks before the final batch.
	var st:=_st(batch,key)
	for normal:Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:
		var u:=Vector3.UP if absf(normal.y)<.9 else Vector3.RIGHT
		var v:=normal.cross(u)
		var a:=p+frame*((normal-u-v)*size*.5);var b:=p+frame*((normal+u-v)*size*.5)
		var c:=p+frame*((normal-u+v)*size*.5);var d:=p+frame*((normal+u+v)*size*.5)
		_tri(st,a,b,c,frame*normal);_tri(st,c,b,d,frame*normal)
static func _beam(batch:Dictionary,key:String,a:Vector3,b:Vector3,width:float) -> void:
	var direction:Vector3=(b-a).normalized()
	_detail(batch,key,(a+b)*.5,Vector3(width,width,a.distance_to(b)),Basis.looking_at(direction,Vector3.RIGHT if absf(direction.y)>.95 else Vector3.UP))
static func _cylinder(batch:Dictionary,key:String,p:Vector3,radius:float,height:float,frame:Basis=Basis.IDENTITY,segments:int=12) -> void:
	var st:=_st(batch,key)
	for i in segments:
		var t:=TAU*i/segments;var q:=TAU*(i+1)/segments
		var a:=Vector3(cos(t)*radius,-height*.5,sin(t)*radius);var b:=Vector3(cos(q)*radius,-height*.5,sin(q)*radius)
		var c:=a+Vector3.UP*height;var d:=b+Vector3.UP*height
		var n:=frame*Vector3(cos((t+q)*.5),0,sin((t+q)*.5))
		_tri(st,p+frame*a,p+frame*b,p+frame*c,n);_tri(st,p+frame*c,p+frame*b,p+frame*d,n)
		_tri(st,p+frame*Vector3(0,-height*.5,0),p+frame*b,p+frame*a,-frame.y)
		_tri(st,p+frame*Vector3(0,height*.5,0),p+frame*c,p+frame*d,frame.y)
static func _flush(w:Node3D,parent:Node3D,batch:Dictionary) -> void:
	for key:String in batch:
		var view:=MeshInstance3D.new();view.mesh=batch[key].commit();view.material_override=w.materials["opi_"+key];parent.add_child(view)
		view.transform=parent.global_transform.affine_inverse()*Transform3D(basis(),CENTER)
static func _attach_batch(w:Node3D,id:String,batch:Dictionary) -> void:
	_flush(w,w.structures["opera/interior/"+id].node,batch);batch.clear()
static func _label(w:Node3D,text:String,p:Vector3,height:float=.35,yaw:float=0.0) -> void:
	var label:=Label3D.new();label.text=text;label.font_size=72;label.pixel_size=height/72;label.outline_size=3;label.position=point(p);label.rotation.y=deg_to_rad(ANGLE)+yaw;label.modulate=Color("eadfc7");label.outline_modulate=Color("332d2a");label.double_sided=false;label.visibility_range_end=200;w.add_child(label)
static func _light(w:Node3D,p:Vector3,radius:float,energy:float=1.1) -> void:
	var light:=OmniLight3D.new();light.position=point(p);light.omni_range=radius;light.light_color=Color("ffe0b0");light.light_energy=energy;light.shadow_enabled=false;light.distance_fade_enabled=true;light.distance_fade_begin=130;light.distance_fade_length=40;w.add_child(light)
static func _stairs(w:Node3D,batch:Dictionary,id:String,a:Vector3,b:Vector3,width:float,key:String="stone") -> void:
	var direction:Vector3=(b-a).normalized();var across:=Vector3(direction.z,0,-direction.x).normalized();var up:=direction.cross(across).normalized()
	var frame:=Basis(across,up,direction)
	var support:=_box(w,id,(a+b)*.5-up*.14,Vector3(width,.28,a.distance_to(b)+.03),key,frame)
	support.get_child(0).visible=false
	support.get_child(0).set_meta("collision_only",true)
	var stair_detail:Dictionary={}
	var steps:=maxi(1,ceili(absf(b.y-a.y)/.16))
	var flat:Vector3=Vector3(b.x-a.x,0,b.z-a.z)
	var horizontal_frame:=Basis(across,Vector3.UP,flat.normalized())
	for i in steps:
		var top:Vector3=a.lerp(b,float(i+1)/steps)
		_detail(stair_detail,key,Vector3(top.x,top.y-.075,top.z)-flat/steps*.5,Vector3(width,.15,flat.length()/steps+.006),horizontal_frame)
	for side in [-1,1]:
		_beam(stair_detail,"bronze",a+across*(width*.5-.1)*side+Vector3.UP*.92,b+across*(width*.5-.1)*side+Vector3.UP*.92,.055)
		for i in 7:
			var p:Vector3=a.lerp(b,float(i)/6)+across*(width*.5-.1)*side
			_beam(stair_detail,"bronze",p,p+Vector3.UP*.92,.035)
	_flush(w,support,stair_detail)

static func _box_office(w:Node3D,b:Dictionary) -> void:
	_box(w,"boxoffice/floor",Vector3(4,BOX_OFFICE-.16,50),Vector3(88,.32,24),"stone")
	_box(w,"boxoffice/floor_west_north",Vector3(-41,BOX_OFFICE-.16,44),Vector3(2,.32,12),"stone")
	_box(w,"boxoffice/floor_west_south",Vector3(-41,BOX_OFFICE-.16,59),Vector3(2,.32,6),"stone")
	_stairs(w,b,"boxoffice/west_stairs",Vector3(-60,0,53),Vector3(-40,BOX_OFFICE,53),5.6)
	_stairs(w,b,"boxoffice/upper_stairs",Vector3(-7,BOX_OFFICE,59),Vector3(-7,UPPER,37),6.4)
	_box(w,"boxoffice/counter",Vector3(22,BOX_OFFICE+.5,43),Vector3(23,1,1.1),"wooddark")
	_detail(b,"bronze",Vector3(22,BOX_OFFICE+1.06,43),Vector3(23.4,.13,1.35))
	for x in [13,17.5,22,26.5,31]:
		_detail(b,"black",Vector3(x,BOX_OFFICE+1.37,43),Vector3(.52,.36,.10))
		_cylinder(b,"bronze",Vector3(x,BOX_OFFICE+1.16,43),.045,.25)
		_detail(b,"light",Vector3(x,BOX_OFFICE+2.45,41.6),Vector3(3.1,.03,.38))
	for x in range(-38,47,4):
		# Folded ceiling ribs terminate at the actual upper-stair slab opening.
		var rib_cut:bool=x> -10.81 and x< -3.19
		_detail(b,"concrete",Vector3(x,10.18,60.75 if rib_cut else 50.0),Vector3(.62,.85,2.5 if rib_cut else 24.0))
		var light_cut:bool=x+1.7> -10.64 and x+1.7< -3.36
		_detail(b,"light",Vector3(x+1.7,10.59,60.25 if light_cut else 50.0),Vector3(.28,.07,1.5 if light_cut else 22.0))
	for x in [-31,10,33]:_light(w,Vector3(x,8.8,52),20,.9)
	_label(w,"BOX OFFICE",Vector3(22,BOX_OFFICE+2.8,41.9),.48)
	_label(w,"CONCERT HALL   /   JOAN SUTHERLAND THEATRE  ↑",Vector3(-7,UPPER+2.5,35.5),.34)
	for x in [-29,3,40]:
		_box(w,"boxoffice/bench_%s"%x,Vector3(x,BOX_OFFICE+.4,60.7),Vector3(5,.8,.9),"wooddark")

static func _chair(b:Dictionary,p:Vector3,yaw:float,seat:String) -> void:
	_seat_count+=1
	var frame:=Basis(Vector3.UP,yaw)
	_detail(b,seat,p+frame*Vector3(0,.47,.02),Vector3(.44,.12,.43),frame)
	_detail(b,"bronze",p+frame*Vector3(0,.25,-.05),Vector3(.055,.5,.05),frame)
	# One continuous curved back, with rounded upper corners and inset upholstery.
	for key in ["birch",seat]:
		var surface:=_st(b,key)
		var half:float=.245 if key=="birch" else .212
		for i in 8:
			var x0:float=lerpf(-half,half,float(i)/8);var x1:float=lerpf(-half,half,float(i+1)/8)
			var y0:float=1.005-.09*pow(absf(x0)/half,6);var y1:float=1.005-.09*pow(absf(x1)/half,6)
			if key==seat:y0-=.035;y1-=.035
			var face_z:float=-.24 if key=="birch" else -.205
			var a:=p+frame*Vector3(x0,.55,face_z+x0*x0*.85)
			var c:=p+frame*Vector3(x0,y0,face_z+x0*x0*.85-.09)
			var d:=p+frame*Vector3(x1,y1,face_z+x1*x1*.85-.09)
			var e:=p+frame*Vector3(x1,.55,face_z+x1*x1*.85)
			for direction in [-1,1]:
				var n:Vector3=frame*Vector3(0,.20,float(direction)).normalized()
				_tri(surface,a,c,d,n);_tri(surface,a,d,e,n)
	for side in [-1,1]:
		_detail(b,"birch",p+frame*Vector3(side*.254,.67,.015),Vector3(.047,.057,.43),frame)

static func _rows(w:Node3D,b:Dictionary,id:String,cx:float,rows:int,z0:float,spacing:float,y0:float,rise:float,half:float,seat:String) -> void:
	var total:=0
	for row in rows:
		var z:float=z0-row*spacing;var y:float=y0+row*rise
		var width:float=half-1.2+minf(row*.11,1.2)
		var poly:=PackedVector2Array()
		for i in range(17):
			var x:float=lerpf(-width,width,float(i)/16);poly.append(Vector2(cx+x,z+2.0*pow(x/width,2)-spacing*.5))
		for i in range(16,-1,-1):
			var x:float=lerpf(-width,width,float(i)/16);poly.append(Vector2(cx+x,z+2.0*pow(x/width,2)+spacing*.5))
		var row_body:=_slab(w,id+"/row_%s"%row,poly,UPPER-.02,y,"brushbox")
		var row_detail:Dictionary={}
		var count:=floori(width*2/.55)
		for index in count:
			var x:float=(index-(count-1)*.5)*.55
			var at:=Vector3(cx+x,y,z+2.0*pow(x/width,2))
			_chair(row_detail,at,-atan2(x,28.0),seat);total+=1
		# Row back/seat rails have real collision, with circulation via side aisles.
		w._extra_box_collision(row_body,Vector3(cx,y+.56,z-.16),Vector3(width*2,.74,.20))
		_flush(w,row_body,row_detail)
	w.set_meta("opera_"+id.replace("/","_")+"_seat_count",total)

static func _side_walls(w:Node3D,b:Dictionary,id:String,cx:float,half:float,z0:float,z1:float,height:float,door_z:float,key:String) -> void:
	for side in [-1,1]:
		var x:float=cx+side*half
		for segment:Array in [[z0,door_z-2],[door_z+2,z1]]:
			_box(w,id+"/side_%s_%s"%[side,segment[0]],Vector3(x,UPPER+height*.5,(segment[0]+segment[1])*.5),Vector3(.35,height,segment[1]-segment[0]),key).set_meta("opera_acoustic_enclosure",true)
		_box(w,id+"/door_head_%s"%side,Vector3(x,UPPER+(height+3.2)*.5,door_z),Vector3(.35,height-3.2,4),key).set_meta("opera_acoustic_enclosure",true)
		_detail(b,"bronze",Vector3(x-side*.19,UPPER+3.2,door_z),Vector3(.10,.1,4.1))
		_label(w,"EXIT",Vector3(x-side*.23,UPPER+2.85,door_z),.17,-side*PI*.5)

static func concert_half_width(z:float) -> float:
	# The CMP auditorium plan closes the northern rear corners. Keep every seat
	# terrace and aisle, which end south of this short tapered rear enclosure.
	return lerpf(16.5,18.0,clampf((z+37.0)/3.0,0.0,1.0))
static func _concert_ceiling_y(x:float,z:float) -> float:
	# Scaled from the public longitudinal section: lower rear ceiling, tall crown.
	var progress:=smoothstep(-37.0,14.0,z)
	var crown:=lerpf(28.9,37.1,progress)
	var edge:=lerpf(24.0,28.0,progress)
	return crown-(crown-edge)*pow(clampf(absf(x)/concert_half_width(z),0,1),3.2)
static func _concert_vault() -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in 2:
		var inset:float=layer*.28
		for column in 24:
			for row in 68:
				var z0:float=-37+row;var z1:float=z0+1
				var x0:float=lerpf(-1.0,1.0,float(column)/24)*concert_half_width(z0)
				var x1:float=lerpf(-1.0,1.0,float(column+1)/24)*concert_half_width(z0)
				var x2:float=lerpf(-1.0,1.0,float(column)/24)*concert_half_width(z1)
				var x3:float=lerpf(-1.0,1.0,float(column+1)/24)*concert_half_width(z1)
				var a:=Vector3(CONCERT_X+x0,_concert_ceiling_y(x0,z0)+inset,z0)
				var b:=Vector3(CONCERT_X+x1,_concert_ceiling_y(x1,z0)+inset,z0)
				var c:=Vector3(CONCERT_X+x2,_concert_ceiling_y(x2,z1)+inset,z1)
				var d:=Vector3(CONCERT_X+x3,_concert_ceiling_y(x3,z1)+inset,z1)
				var n:Vector3=(b-a).cross(c-a).normalized()*(1 if layer==0 else -1)
				_tri(st,a,b,c,n);_tri(st,c,b,d,n)
	return st.commit()
static func _concert_end_wall(w:Node3D,id:String,z:float) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1,1]:
		for i in 24:
			var x0:float=lerpf(-1.0,1.0,float(i)/24)*concert_half_width(z);var x1:float=lerpf(-1.0,1.0,float(i+1)/24)*concert_half_width(z)
			var a:=Vector3(CONCERT_X+x0,UPPER,z+side*.19);var b:=Vector3(CONCERT_X+x1,UPPER,z+side*.19)
			var c:=Vector3(a.x,_concert_ceiling_y(x0,z)+.28,a.z);var d:=Vector3(b.x,_concert_ceiling_y(x1,z)+.28,b.z)
			_tri(st,a,b,c,Vector3.BACK*side);_tri(st,c,b,d,Vector3.BACK*side)
	var body:StaticBody3D=w._structure_mesh("opera/interior/"+id,st.commit(),CENTER,"opi_brushbox",125000,basis())
	body.set_meta("opera_acoustic_enclosure",true)

static func _concert_side_wall(w:Node3D,side:int,z0:float,z1:float,bottom:float) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps:=ceili((z1-z0)/1.0)
	for face in [-1,1]:
		for i in steps:
			var za:=lerpf(z0,z1,float(i)/steps);var zb:=lerpf(z0,z1,float(i+1)/steps)
			var xa:float=CONCERT_X+side*concert_half_width(za)+face*.175
			var xb:float=CONCERT_X+side*concert_half_width(zb)+face*.175
			var a:=Vector3(xa,bottom,za);var b:=Vector3(xb,bottom,zb)
			var c:=Vector3(xa,_concert_ceiling_y(concert_half_width(za),za)+.28,za);var d:=Vector3(xb,_concert_ceiling_y(concert_half_width(zb),zb)+.28,zb)
			_tri(st,a,b,c,Vector3.RIGHT*face);_tri(st,c,b,d,Vector3.RIGHT*face)
	var body:StaticBody3D=w._structure_mesh("opera/interior/concert/side_%s_%s"%[side,z0],st.commit(),CENTER,"opi_brushbox",125000,basis())
	body.set_meta("opera_acoustic_enclosure",true)

static func _concert(w:Node3D,b:Dictionary) -> void:
	var cx:=CONCERT_X
	for side in [-1,1]:
		_concert_side_wall(w,side,-37,11,UPPER)
		_concert_side_wall(w,side,11,15,UPPER+3.2)
		_concert_side_wall(w,side,15,31,UPPER)
	_concert_end_wall(w,"concert/north",-37)
	_concert_end_wall(w,"concert/south",31)
	var ceiling:StaticBody3D=w._structure_mesh("opera/interior/concert/ceiling",_concert_vault(),CENTER,"opi_brushbox",180000,basis())
	ceiling.set_meta("opera_acoustic_enclosure",true)
	var stage_poly:=PackedVector2Array([Vector2(cx-7.25,12),Vector2(cx+7.25,12),Vector2(cx+8.0,15),Vector2(cx+6.9,24.3),Vector2(cx-6.9,24.3),Vector2(cx-8.0,15)])
	_slab(w,"concert/stage",stage_poly,UPPER,STAGE,"brushbox")
	_rows(w,b,"concert/stalls",cx,24,9.65,.85,UPPER+.03,.12,14.9,"magenta")
	_rows(w,b,"concert/circle",cx,15,-13.5,1.32,15.2,.36,15.0,"magenta")
	for side in [-1,1]:
		_stairs(w,b,"concert/aisle_%s"%side,Vector3(cx+side*16.45,UPPER,11),Vector3(cx+side*16.45,20.5,-34),2.15,"purple")
		_stairs(w,b,"concert/stage_stair_%s"%side,Vector3(cx+side*8.8,UPPER,12),Vector3(cx+side*8.8,STAGE,17),2.0,"brushbox")
		_box(w,"concert/stage_landing_%s"%side,Vector3(cx+side*8.0,STAGE-.15,18),Vector3(2.5,.30,3),"brushbox")
		for box in 6:
			var z:=8-box*6.0;var y:=14.0+box*.85
			var balcony:=_box(w,"concert/box_%s_%s"%[side,box],Vector3(cx+side*15.45,y-.14,z),Vector3(3.3,.28,5.5),"brushbox")
			var box_detail:Dictionary={}
			_detail(box_detail,"brushbox",Vector3(cx+side*13.7,y+.48,z),Vector3(.17,.95,5.5))
			for row in 3:
				for seat in 7:_chair(box_detail,Vector3(cx+side*(14.1+row*.70),y,z-2+seat*.56),-side*PI*.5,"magenta")
			_flush(w,balcony,box_detail)
	# Choir terraces behind the orchestra and the tall stepped pipe organ.
	for row in 5:
		var y:=STAGE+.55+row*.43;var z:=25.0+row*1.1
		var choir:=_box(w,"concert/choir_%s"%row,Vector3(cx,y-.15,z),Vector3(21,.30,1.1),"brushbox")
		var choir_detail:Dictionary={}
		for seat in 37:_chair(choir_detail,Vector3(cx+(seat-18)*.55,y,z),PI,"magenta")
		_flush(w,choir,choir_detail)
	var organ:=_box(w,"concert/organ_back",Vector3(cx,26.0,30.45),Vector3(17.8,17.0,.40),"wooddark")
	var organ_detail:Dictionary={}
	for group in range(9):
		var center_x:float=cx+(group-4)*1.80
		var height:float=11.0+6.0*(1.0-absf(group-4)/4.0)
		for pipe in 7:
			var h:float=height-.23*absf(pipe-3)
			_cylinder(organ_detail,"pipe",Vector3(center_x+(pipe-3)*.22,17.7+h*.5,30.08),.075,h,Basis.IDENTITY,10)
		_detail(organ_detail,"birch",Vector3(center_x,17.6,29.88),Vector3(1.65,.14,.25))
	_detail(organ_detail,"wooddark",Vector3(cx,16.25,27.6),Vector3(2.5,1.1,.8))
	for key in 36:_detail(organ_detail,"birch",Vector3(cx-1.13+key*.063,16.65,27.14),Vector3(.058,.04,.32))
	_flush(w,organ,organ_detail)
	# Longitudinal ceiling profile rises towards the crown above the stage.
	# Transverse folds fan towards that crown, instead of identical flat hoops.
	for z in range(-33,30,3):
		for side in [-1,1]:
			var path:Array[Vector3]=[]
			for section in range(13):
				var x:float=side*18.0*(1.0-float(section)/12)
				var at_z:float=lerpf(z,18.0,float(section)/12*.16)
				path.append(Vector3(cx+x,_concert_ceiling_y(x,at_z)-.22,at_z))
			for i in path.size()-1:_beam(b,"woodlight",path[i],path[i+1],.36)
			var toe:Vector3=path[0]
			_beam(b,"woodlight",Vector3(toe.x,16.5,toe.z),toe,.36)
	for x in [-14,-10,-6,-2,2,6,10,14]:
		for z in range(-34,29,4):
			var a:=Vector3(cx+x,_concert_ceiling_y(x,z)-.30,z)
			var end:=Vector3(cx+x,_concert_ceiling_y(x,z+4)-.30,z+4)
			_beam(b,"wooddark",a,end,.10)
			_detail(b,"light",a+Vector3.DOWN*.035,Vector3(.23,.04,.29))
	# 18 2022 magenta reflectors: 12 orchestra, 4 audience, 2 choir.
	for row in 3:
		for col in 4:
			var p:=Vector3(cx+(col-1.5)*3.3,STAGE+9.2+row*.85,14.4+row*3.5)
			_reflector(b,p,Vector3(1.38,.18,1.12),Basis(Vector3.RIGHT,deg_to_rad(26+row*12))*Basis(Vector3.FORWARD,deg_to_rad((col-1.5)*12)))
			_beam(b,"bronze",p+Vector3.UP*.1,Vector3(p.x,_concert_ceiling_y(p.x-cx,p.z)-.1,p.z),.027)
	for col in 4:
		var p:=Vector3(cx+(col-1.5)*4.4,STAGE+8.7,11.1)
		_reflector(b,p,Vector3(2.0,.20,1.5),Basis(Vector3.RIGHT,.54)*Basis(Vector3.FORWARD,(col-1.5)*.16))
		_beam(b,"bronze",p+Vector3.UP*.1,Vector3(p.x,_concert_ceiling_y(p.x-cx,p.z)-.1,p.z),.027)
	for side in [-1,1]:
		var p:=Vector3(cx+side*4.2,STAGE+11,27.0)
		_reflector(b,p,Vector3(1.5,.18,1.2),Basis(Vector3.RIGHT,-.50))
		_beam(b,"bronze",p+Vector3.UP*.1,Vector3(p.x,_concert_ceiling_y(p.x-cx,p.z)-.1,p.z),.027)
	w.set_meta("opera_concert_reflectors",18)
	for z in [-23,-4,15]:
		_light(w,Vector3(cx,23,z),29,1.45)
	var spot:=SpotLight3D.new();spot.position=point(Vector3(cx,31,18));spot.rotation_degrees.x=-90;spot.spot_angle=52;spot.spot_range=27;spot.light_energy=2.0;spot.light_color=Color("ffe4bc");spot.shadow_enabled=true;w.add_child(spot)
	_label(w,"CONCERT HALL",Vector3(-6,UPPER+2.6,16),.36,PI*.5)

static func _reflector(b:Dictionary,p:Vector3,size:Vector3,frame:Basis) -> void:
	var st:=_st(b,"reflector")
	for ring in range(7):
		var a0:=PI*ring/7;var a1:=PI*(ring+1)/7
		for segment in 24:
			var q0:=TAU*segment/24;var q1:=TAU*(segment+1)/24
			var a:=Vector3(sin(a0)*cos(q0),cos(a0),sin(a0)*sin(q0))*size
			var c:=Vector3(sin(a1)*cos(q0),cos(a1),sin(a1)*sin(q0))*size
			var d:=Vector3(sin(a1)*cos(q1),cos(a1),sin(a1)*sin(q1))*size
			var e:=Vector3(sin(a0)*cos(q1),cos(a0),sin(a0)*sin(q1))*size
			var n:Vector3=frame*((a+c+d)/3/size/size).normalized()
			_tri(st,p+frame*a,p+frame*c,p+frame*d,n);_tri(st,p+frame*a,p+frame*d,p+frame*e,n)

static func _jst(w:Node3D,b:Dictionary) -> void:
	var cx:=JST_X
	_side_walls(w,b,"jst",cx,14.7,-37,33,12.5,6,"jst_wall")
	_box(w,"jst/north",Vector3(cx,17.45,-37),Vector3(29.4,12.5,.36),"jst_wall").set_meta("opera_acoustic_enclosure",true)
	_box(w,"jst/ceiling",Vector3(cx,23.9,-2),Vector3(29.4,.4,70),"jst_wall").set_meta("opera_acoustic_enclosure",true)
	var stage:=PackedVector2Array([Vector2(cx-7.015,8),Vector2(cx+7.015,8),Vector2(cx+9.0,15),Vector2(cx+5.94,31.82),Vector2(cx-5.94,31.82),Vector2(cx-9.0,15)])
	_slab(w,"jst/stage",stage,UPPER,STAGE,"black")
	_box(w,"jst/proscenium_head",Vector3(cx,21.5,10),Vector3(26,4.6,.65),"black")
	for side in [-1,1]:_box(w,"jst/proscenium_%s"%side,Vector3(cx+side*9.35,15.65,10),Vector3(7.35,7.1,.65),"black")
	_box(w,"jst/stage_back",Vector3(cx,17.45,32.82),Vector3(29.4,12.5,.36),"black").set_meta("opera_acoustic_enclosure",true)
	# Model the orchestra pit as a real lower floor inside the exterior slab opening.
	_box(w,"jst/pit_floor",Vector3(cx,9.2,6),Vector3(16,.4,4),"black")
	for side in [-1,1]:_box(w,"jst/pit_side_%s"%side,Vector3(cx+side*8.0,10.3,6),Vector3(.18,2.2,4),"black")
	_box(w,"jst/pit_front",Vector3(cx,10.3,4),Vector3(16,2.2,.16),"black")
	for x in [-5,-2,1,4]:
		_cylinder(b,"bronze",Vector3(cx+x,10.0,6),.04,1.1)
		_detail(b,"black",Vector3(cx+x,10.6,6),Vector3(.5,.35,.08),Basis(Vector3.RIGHT,.25))
	# Continuous timber aisle finish bridges the triangulated podium's pit-edge
	# seam. Its 25mm surface stays outside the pit and below the first seat tier.
	_box(w,"jst/front_cross_aisle",Vector3(cx,UPPER-.065,3.46),Vector3(25.5,.18,.89),"brushbox")
	_rows(w,b,"jst/stalls",cx,22,.9,.86,UPPER+.03,.135,11.9,"red")
	_rows(w,b,"jst/circle",cx,12,-20.7,1.10,16.0,.35,12.0,"red")
	for side in [-1,1]:
		_stairs(w,b,"jst/aisle_%s"%side,Vector3(cx+side*13.35,UPPER,2),Vector3(cx+side*13.35,20.0,-35),1.85,"red")
		for level in 2:
			for box in 5:
				var z:=2-box*5.5;var y:=15.0+level*3.35+box*.16
				var balcony:=_box(w,"jst/box_%s_%s_%s"%[side,level,box],Vector3(cx+side*12.5,y-.12,z),Vector3(3.2,.24,4.9),"jst_wall")
				var box_detail:Dictionary={}
				_detail(box_detail,"brushbox",Vector3(cx+side*10.85,y+.52,z),Vector3(.17,1.05,4.9))
				for seat in 7:_chair(box_detail,Vector3(cx+side*12.0,y,z-1.8+seat*.54),-side*PI*.5,"red")
				_flush(w,balcony,box_detail)
		_stairs(w,b,"jst/stage_stair_%s"%side,Vector3(cx+side*8.8,UPPER,8),Vector3(cx+side*8.8,STAGE,13),1.9,"black")
	# Pleated rear drape and overhead stage battens are independent of a live show.
	for pleat in 58:
		var x:float=cx-5.8+pleat*.203
		_cylinder(b,"jst_wall",Vector3(x,16.8,27.6),.15,9.2,Basis.IDENTITY,8)
	for z in [13.0,17.0,21.0]:
		_beam(b,"bronze",Vector3(cx-6,21,z),Vector3(cx+6,21,z),.14)
		for x in [-4,-2,0,2,4]:_detail(b,"light",Vector3(cx+x,20.88,z),Vector3(.18,.06,.22))
	for z in [-25,-8,16]:_light(w,Vector3(cx,21,z),23,.85)
	_label(w,"JOAN SUTHERLAND THEATRE",Vector3(39.2,UPPER+2.6,13),.31,PI*.5)

static func _foyers(w:Node3D,b:Dictionary) -> void:
	for spec:Array in [[CONCERT_X,-59.0,-77.0,18.0,"purple"],[JST_X,-47.0,-62.0,14.0,"red"]]:
		var cx:float=spec[0];var south:float=spec[1];var north:float=spec[2];var half:float=spec[3];var carpet:String=spec[4]
		var name:="concert_foyer" if cx<0 else "jst_foyer"
		# Tiered broad carpet stairs and lower granite landing face the harbour glazing.
		_box(w,name+"/landing",Vector3(cx,UPPER-.12,(south+north)*.5),Vector3(half*2,.24,south-north),"stone")
		_stairs(w,b,name+"/broad_stairs",Vector3(cx,UPPER,north+2),Vector3(cx,UPPER+2.2,south-4),half*1.55,carpet)
		for side in [-1,1]:
			_box(w,name+"/lounge_%s"%side,Vector3(cx+side*(half-1.3),UPPER+.35,south-2),Vector3(2.2,.7,2.0),carpet)
		for x in [-half*.7,half*.7]:
			_box(w,name+"/bar_%s"%x,Vector3(cx+x,UPPER+.50,north+.5),Vector3(3,1,.75),"wooddark")
			_detail(b,"birch",Vector3(cx+x,UPPER+1.04,north+.5),Vector3(3.2,.12,.90))
		for z in [south-1,north+1]:_light(w,Vector3(cx,UPPER+5,z),19,.85)
		_label(w,"HARBOUR FOYER",Vector3(cx,UPPER+3,south-.3),.36,PI)
	# Wayfinding and furnishings in the two southern main foyers.
	for cx in [-24.0,22.0]:
		for side in [-1,1]:
			_box(w,"south_foyer/seat_%s_%s"%[cx,side],Vector3(cx+side*8,UPPER+.38,53),Vector3(4,.76,1),"wooddark")
		_light(w,Vector3(cx,UPPER+4.5,48),20,1.0)
