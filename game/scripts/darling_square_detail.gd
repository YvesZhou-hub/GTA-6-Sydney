extends RefCounted
## Additional photographed Nicolle Walk frontages and ASPECT's public garden.
## Plan positions are registered against three OSM landmarks; furniture sizes
## and canopy elevations are photo estimates, not a surveyed landscape model.
const Fronts=preload("res://scripts/darling_square_frontages.gd")
const Geo=preload("res://scripts/city_landmarks.gd")
const CANOPY_A:=Vector3(-780.912,4.5,2017.617)
const CANOPY_B:=Vector3(-772.525,4.5,2058.565)

static func metadata() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for data in [
		["auvers","Auvers · Darling Square",Vector2(-740.2197,2026.2798),9.0,"node/10590131122","https://www.auverscafe.com.au/reservations"],
		["hakatamon","Hakatamon Ramen",Vector2(-742.1580,2009.5517),11.8,"node/9480685417","https://harleyjohnston.com/project/hakatamon-ramen/"],
		["chinta_ria","Chinta Ria Buddha Love",Vector2(-738.6480,2039.8518),9.0,"node/11834192053","https://www.darlingsq.com/eat-drink-shop/chinta-ria/"]
	]:
		var center:=Vector3(data[2].x,4.5,data[2].y)
		var n:=Vector3(-0.9933613,0,0.1150364)
		# Left-hand door position is kept separate from the shop's map centre.
		var door_x:float=-data[3]*.38
		var arrival:=center+n*1.75+Vector3.UP.cross(n)*door_x
		result.append({"id":data[0],"name":data[1],"center":center,"map_position":center,"arrival":arrival,"position":arrival,"front":[center.x,center.z],"normal":[n.x,n.z],"width":data[3],"osm":data[4],"building":"way/614603732","source":data[5],"evidence":"Official precinct/operator address + OSM shop point projected onto ground-level building edge; actual branch exterior photograph viewed. Store width and small fittings estimated.","confidence":"mapped building edge; photograph-authored exterior; no public shop interior"})
	return result

static func excluded_way_ids() -> Array[int]: return []

static func build(world:Node3D) -> void:
	if world.has_meta("darling_square_detail"):return
	for key in Fronts.COLORS: world._mat("ds_"+key,Color(Fronts.COLORS[key]),.32 if key=="glass" else .76,.32 if key in ["glass","frame","gold"] else 0.0)
	for item in metadata():
		var f=Fronts.Frontage.new(world,item)
		_shell(f)
		match item.id:
			"auvers":_auvers(f)
			"hakatamon":_hakatamon(f)
			"chinta_ria":_chinta(f)
		f.finish()
		world.anchors[item.id]=item.arrival
		f.body.set_meta("public_arrival",item.arrival)
	_public_space(world)
	world.set_meta("darling_square_detail",metadata())
	world.set_meta("darling_square_landscape",{"source":"https://www.aspect-studios.com/projects/darling-square-2","plan":"https://mooool.com/en/darling-square-a-public-space-for-all-by-aspect-studios.html","registration":"Three existing mapped anchors: Exchange centre, Steam Mill/Tumbalong junction, Little Hay/Nicolle junction","precision":"Approximate plan registration; exact furniture/landscape elevations inferred","canopy_ends":[CANOPY_A,CANOPY_B]})

static func _shell(f):
	# Charcoal brick piers and pale mortar, matching the shared podium envelope.
	for x in [-f.width*.5,0.0,f.width*.5]:
		f.box(Vector3(x,2.2,.16),Vector3(.34,4.4,.25),"coal")
		for row in 42:f.box(Vector3(x,.06+row*.103,.294),Vector3(.35,.011,.012),"stone")
	f.box(Vector3(0,3.13,.26),Vector3(f.width,.16,.30),"frame")
	for x in range(ceil(f.width/.7)):
		f.beam(Vector3(-f.width*.5+x*.7,4.3,.10),Vector3(-f.width*.5+x*.7,4.15,1.75),.055,"frame")
	f.box(Vector3(0,4.20,.95),Vector3(f.width,.035,1.65),"glass")

static func _cafe_seat(f,x:float,z:float):
	f.stool(x,z,"frame")
	for side in [-1,1]:f.beam(Vector3(x+side*.14,.47,z-.14),Vector3(x+side*.16,.87,z-.18),.018,"frame")
	for i in 5:f.beam(Vector3(x-.16,.56+i*.07,z-.16),Vector3(x+.16,.56+i*.07,z-.16),.012,"frame")

static func _auvers(f):
	f.door(-f.width*.38,1.15)
	f.window(-.80,2.6,.30,3.06,"warm_glass")
	f.window(2.40,3.25,.30,3.06,"warm_glass")
	for x in [-.9,2.4]:
		# Visible timber gable outlines reflect the actual café's house motif.
		f.beam(Vector3(x-1.1,2.05,.30),Vector3(x,2.93,.30),.085,"wood")
		f.beam(Vector3(x,2.93,.30),Vector3(x+1.1,2.05,.30),.085,"wood")
		f.box(Vector3(x,.78,.34),Vector3(2.5,.09,.20),"wood")
	for x in [-.65,2.40]:
		f.box(Vector3(x,.76,1.16),Vector3(1.12,.08,.72),"wood")
		for side in [-1,1]:f.box(Vector3(x+side*.40,.38,1.16),Vector3(.045,.76,.52),"frame")
		_cafe_seat(f,x-.40,1.79);_cafe_seat(f,x+.40,1.79)
	# Tall black blade and white hexagon are geometry, not a copied logo texture.
	f.box(Vector3(-f.width*.43,3.52,.52),Vector3(.28,.87,.55),"coal")
	for side in [-1,1]:
		var b:=Basis(Vector3.UP,side*PI*.5)
		var at:=Vector3(-f.width*.43+side*.151,3.52,.57)
		for i in 6:f.beam(at+b*Vector3(cos(i*TAU/6),sin(i*TAU/6),0)*.21,at+b*Vector3(cos((i+1)*TAU/6),sin((i+1)*TAU/6),0)*.21,.035,"white")
	f.text("A U V E R S",Vector3(-.1,3.68,.29),.22)
	f.box(Vector3(-2.25,.6,.50),Vector3(.52,1.2,.30),"wood")
	f.text("CAFE · ART",Vector3(-2.25,.9,.665),.07)
	for x in [-1.9,3.85]:
		f.cylinder(Vector3(x,.32,1.56),.22,.64,"coal")
		f.cylinder(Vector3(x,1.35,1.56),.11,1.4,"frame")
		f.cylinder(Vector3(x,2.09,1.56),.28,.065,"slate")

static func _hakatamon(f):
	f.door(-f.width*.38,1.12)
	for x in [-2.03,2.85]:
		f.window(x,4.12,.66,3.10,"warm_glass")
		f.window(x,4.12,3.28,4.04,"glass")
		f.disc(Vector3(x,3.62,.36),.245,"red")
		for wave in 3:
			for i in 8:
				var a:=Vector3(x-.19+i*.047,3.53+wave*.063+sin(i*.8)*.026,.37)
				var b:=Vector3(x-.19+(i+1)*.047,3.53+wave*.063+sin((i+1)*.8)*.026,.37)
				f.beam(a,b,.021,"white")
		for i in 6:
			var sx:float=x-1.85+i*.73
			f.box(Vector3(sx,2.7,.31),Vector3(.69,.56,.055),"cream")
			f.box(Vector3(sx,2.30,.42),Vector3(.035,1.45,.045),"frame")
		f.box(Vector3(x,.79,.48),Vector3(4.1,.085,.50),"wood")
		for offset in [-1.5,-.5,.5,1.5]:
			f.box(Vector3(x+offset,.72,1.13),Vector3(.66,.065,.61),"wood")
			f.cylinder(Vector3(x+offset,.36,1.13),.034,.7,"frame",8)
			f.stool(x+offset,1.72,"coal")
	# The branch uses circular wave marks above each opening, not an invented fascia.
	f.text("HAKATAMON RAMEN",Vector3(-4.4,1.75,.37),.09)

static func _chinta(f):
	f.door(-f.width*.38,1.1)
	f.window(-.35,3.1,.28,3.02,"warm_glass")
	f.window(2.65,2.55,.28,3.02,"warm_glass")
	f.window(.55,6.15,3.31,4.03,"glass")
	f.text("CHINTA RIA",Vector3(.6,3.73,.38),.30,Color("c44332"))
	f.text("BUDDHA LOVE",Vector3(.6,3.42,.38),.115,Color("c44332"))
	for x in [-1.6,-.3,1.4,3.4]:
		f.beam(Vector3(x,2.92,.3),Vector3(x,2.15,.3),.027,"red")
		f.disc(Vector3(x,1.99,.32),.19,"ochre" if x<0 else "red")
		for t in [-.10,0.0,.10]:f.box(Vector3(x+t,1.99,.35),Vector3(.013,.33,.01),"cream")
	for x in [-1.2,1.0,3.0]:
		f.box(Vector3(x,.74,1.13),Vector3(1.0,.065,.67),"white")
		for side in [-1,1]:f.box(Vector3(x+side*.32,.37,1.13),Vector3(.035,.74,.46),"frame")
		_cafe_seat(f,x-.32,1.7);_cafe_seat(f,x+.32,1.7)

static func _public_space(w:Node3D):
	_paving_material(w)
	# Registered public-space perimeter. The original hard square and canopy
	# floor are paved; the lawn is the bounded green rectangle within them.
	var paving:=Geo.polygon([[-808.0,1972.0],[-745.8,1964.0],[-736.5,2072.0],[-788.0,2070.0]])
	w._structure_mesh("darling_detail/public_paving",Geo.prism(paving,.095,.12),Vector3.UP*w.GROUND,"ds_fan_pavers",1600000)
	var forward:Vector3=(CANOPY_B-CANOPY_A).normalized()
	var right:=Vector3(forward.z,0,-forward.x)
	var basis:=Basis(right,Vector3.UP,forward)
	# Fifty pale ribbons sag in the middle and rise toward the library, as built.
	for rib in 38:
		var x:float=-4.5+rib*.245
		for segment in 28:
			var t:float=segment/28.0
			var t2:float=(segment+1)/28.0
			var a:Vector3=CANOPY_A.lerp(CANOPY_B,t)+right*x+Vector3.UP*(4.65+1.6*pow(2*t-1,2)+.10*sin(rib*.27))
			var b:Vector3=CANOPY_A.lerp(CANOPY_B,t2)+right*x+Vector3.UP*(4.65+1.6*pow(2*t2-1,2)+.10*sin(rib*.27))
			w._batch_box((a+b)*.5,Vector3(.10,.23,a.distance_to(b)+.018),"ds_cream",Basis.looking_at(b-a,Vector3.UP))
	for row in 7:
		var t:float=row/6.0
		var p:Vector3=CANOPY_A.lerp(CANOPY_B,t)
		var high:float=4.42+1.6*pow(2*t-1,2)
		w._batch_box(p+Vector3.UP*high,Vector3(10.0,.24,.20),"ds_frame",basis)
		for side in [-1,1]:
			w._structure_box("darling_detail/canopy/post/%d/%d"%[row,side],p+right*side*4.48+Vector3.UP*high*.5,Vector3(.13,high,.13),"ds_frame",75000,basis)
	# Registered plan: lawn east of the canopy, grove at its southern end.
	var lawn_center:=Vector3(-755.8,w.GROUND+.15,2039.7)
	w._batch_box(lawn_center,Vector3(18.0,.07,24.0),"grass",basis)
	for side in [-1,1]:_bench(w,lawn_center+right*side*9.25-Vector3.UP*.15,22.0,forward,"lawn_%d"%side)
	for row in 4:
		var p:Vector3=CANOPY_A.lerp(CANOPY_B,.43+row*.15)
		_bench(w,p+right*.3,5.7,right,"canopy_%d"%row)
	for i in 8:
		var p:=Vector3(-766.7+(i%4)*5.0,w.GROUND,2057.5+(i/4)*5.0)
		_planter(w,p,i)
	# Landscape joint bands follow the mapped crossing; no new road centreline.
	for pair in [[Vector3(-792.413,0,2026.837),Vector3(-742.379,0,2015.616)],[Vector3(-736.548,0,2071.955),Vector3(-674,0,2084.17)]]:
		var a:Vector3=pair[0];var b:Vector3=pair[1]
		var dir:Vector3=(b-a).normalized();var r:=Vector3(dir.z,0,-dir.x)
		for side in [-1,1]:w._batch_box((a+b)*.5+r*side*1.36+Vector3.UP*(w.GROUND+.103),Vector3(.12,.014,a.distance_to(b)),"ds_slate",Basis.looking_at(dir,Vector3.UP))

static func _bench(w:Node3D,p:Vector3,length:float,along:Vector3,id:String):
	var basis:=Basis.looking_at(along,Vector3.UP)
	w._structure_box("darling_detail/bench/"+id,p+Vector3.UP*.23,Vector3(.68,.46,length),"ds_stone",58000,basis)
	for j in 6:w._batch_box(p+basis*Vector3(-.30+j*.12,.49,0),Vector3(.105,.07,length-.08),"ds_wood",basis)

static func _planter(w:Node3D,p:Vector3,index:int):
	w._structure_box("darling_detail/grove/"+str(index),p+Vector3.UP*.12,Vector3(1.6,.24,1.6),"ds_ochre",58000)
	w._batch_box(p+Vector3.UP*.255,Vector3(1.43,.03,1.43),"ds_leaf")
	_eucalyptus(w,p+Vector3.UP*.25,index)

static func _eucalyptus(w:Node3D,p:Vector3,index:int):
	# Narrow irregular crowns and small leaf clusters, not dense spherical street trees.
	w._batch_cylinder(p+Vector3.UP*3.3,.13,6.6,"bark")
	if not w.materials.has("tree_mesh"):
		var sphere:=SphereMesh.new();sphere.radius=1;sphere.height=2;sphere.radial_segments=10;sphere.rings=5;w.materials["tree_mesh"]=sphere
	for key in ["tree","tree_light"]:
		if not w._batch_foliage.has(key):w._batch_foliage[key]=[]
	for j in 12:
		var angle:float=j*2.399+index*.31
		var branch:=Vector3(cos(angle),0,sin(angle))*(.65+(j%3)*.42)
		var crown:Vector3=p+branch+Vector3.UP*(5.1+(j%4)*.65)
		var root:Vector3=p+Vector3.UP*(3.7+(j%4)*.48)
		w._batch_box((root+crown)*.5,Vector3(.065,.065,root.distance_to(crown)),"bark",Basis.looking_at(crown-root,Vector3.UP))
		var key:String="tree_light" if j%3==0 else "tree"
		w._batch_foliage[key].append(Transform3D(Basis.IDENTITY.scaled(Vector3(.55,.76,.67)),crown))

static func _paving_material(w:Node3D):
	if w.materials.has("ds_fan_pavers"):return
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
varying vec3 world_at;
void vertex(){world_at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=mat2(vec2(.9799,-.1996),vec2(.1996,.9799))*world_at.xz;
 vec2 q=mod(p,vec2(2.4,1.2)); q.x-=1.2;
 float radius=length(q); float angle=atan(q.x,max(q.y,.001));
 float radial=radius/.115; float cells=max(6.0,floor(radial)*2.9);
 float around=angle*cells/3.14159265;
 float edge=min(min(fract(radial),1.0-fract(radial))*.115,min(fract(around),1.0-fract(around))*.115);
 float variation=fract(sin(floor(radial)*71.17+floor(around)*37.89+floor(p.x/2.4)*5.13)*43758.5453);
 float aa=max(fwidth(edge),.0015);
 float stone=smoothstep(.004-aa,.004+aa,edge);
 ALBEDO=mix(vec3(.50,.50,.45),mix(vec3(.24,.255,.25),vec3(.40,.40,.36),variation),stone);
 ROUGHNESS=.94;
}
"""
	var mat:=ShaderMaterial.new();mat.shader=shader;w.materials["ds_fan_pavers"]=mat
