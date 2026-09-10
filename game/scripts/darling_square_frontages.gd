extends RefCounted
## Original geometry based on individually documented Darling Square shopfronts.
## Photographs are references only; no third-party pixels are bundled.
## Placement is an OSM point projected onto its actual ground-level building edge.
const SOURCE_FILE:="res://assets/darling_square_frontages.json"
const COLORS={"coal":"282b2b","frame":"363b39","glass":"6a807c","warm_glass":"756d54","wood":"9a7050","cream":"e5dcc5","white":"f0e9d8","gold":"b79852","peach":"b97f66","pink_stone":"ad8374","green":"3d514a","matcha":"849975","red":"ae382d","purple":"754569","blue":"33485c","ochre":"b5843e","slate":"626462","leaf":"547747","stone":"bdb8a3"}

static func metadata() -> Array:
	var source=JSON.parse_string(FileAccess.get_file_as_string(SOURCE_FILE))
	return source.get("shops",[]) if source is Dictionary else []

static func build(world:Node3D) -> void:
	if world.has_meta("darling_square_frontages"): return
	for key in COLORS: world._mat("ds_"+key,Color(COLORS[key]),0.3 if key=="glass" else 0.76,0.35 if key in ["gold","frame","glass"] else 0.0)
	var entries:Array=metadata()
	_pedestrian_paving(world)
	for item in entries: _shop(world,item)
	world.set_meta("darling_square_frontages",entries)

static func _pedestrian_paving(world:Node3D):
	# OSM pedestrian centre-lines plus photographed paved street edges. Widths
	# fill the public lane between the mapped facades; no invented road link.
	for line in [
		[Vector3(-879.46,0,2064.47),Vector3(-868.93,0,2056.67),Vector3(-797.20,0,2028.71),Vector3(-792.41,0,2026.84)],
		[Vector3(-736.55,0,2071.96),Vector3(-674.00,0,2084.17),Vector3(-661.13,0,2083.13)],
		[Vector3(-747.24,0,1978.12),Vector3(-742.38,0,2015.62),Vector3(-736.55,0,2071.96)]
	]:
		for i in range(line.size()-1):
			var a:Vector3=line[i]
			var b:Vector3=line[i+1]
			world._batch_box((a+b)*.5+Vector3.UP*(world.GROUND+.01),Vector3(8.8,.035,a.distance_to(b)+.10),"paving",Basis.looking_at((b-a).normalized(),Vector3.UP))

class Frontage:
	var surfaces:Dictionary={}
	var body:StaticBody3D
	var world:Node3D
	var width:float
	var item:Dictionary
	var element_count:=0
	func _init(owner_world:Node3D,record:Dictionary):
		world=owner_world
		item=record
		width=float(record.width)
		var normal:=Vector3(record.normal[0],0,record.normal[1])
		var frame:=Basis(Vector3.UP.cross(normal),Vector3.UP,normal)
		# Keep authored glazing in front of the ordinary building's shallow
		# procedural cornices, which otherwise cut across the shop windows.
		var front:=Vector3(record.front[0],world.GROUND,record.front[1])+normal*0.42
		# A closed shopfront sits against the existing exterior. Door approaches stay
		# clear; no pretend playable interior is placed inside a solid OSM volume.
		body=world._structure_box("darling_square/"+record.id+"/frontage",front+Vector3.UP*2.2,Vector3(width,4.4,0.08),"ds_coal",95000,frame)
		body.set_meta("frontage_id",record.id)
		body.set_meta("source_evidence",record.evidence)
		body.set_meta("osm_shop_id",record.osm)
		body.set_meta("door_approach",front+normal*1.0)
		body.set_meta("frontage_normal",normal)
		body.set_meta("frontage_width",width)
		world.anchors["shop_"+record.id]=front+normal*1.3
	func surface(key:String) -> SurfaceTool:
		if not surfaces.has(key):
			var tool:=SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[key]=tool
		return surfaces[key]
	func box(at:Vector3,dimensions:Vector3,key:String,basis:=Basis.IDENTITY):
		var tool:=surface(key)
		var half:=dimensions*0.5
		var vertices:Array[Vector3]=[]
		for v in [Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,1,-1),Vector3(-1,1,-1),Vector3(-1,-1,1),Vector3(1,-1,1),Vector3(1,1,1),Vector3(-1,1,1)]: vertices.append(at+Vector3.DOWN*2.2+basis*(v*half))
		for face in [[4,5,6,7],[1,0,3,2],[0,4,7,3],[5,1,2,6],[3,7,6,2],[0,1,5,4]]:
			var normal:Vector3=(vertices[face[1]]-vertices[face[0]]).cross(vertices[face[2]]-vertices[face[0]]).normalized()
			for i in [0,2,1,0,3,2]:
				tool.set_normal(normal)
				tool.add_vertex(vertices[face[i]])
		element_count+=1
	func disc(at:Vector3,radius:float,key:String,basis:=Basis.IDENTITY):
		var tool:=surface(key)
		for i in range(32):
			for p in [Vector3.ZERO,Vector3(cos(TAU*(i+1)/32),sin(TAU*(i+1)/32),0)*radius,Vector3(cos(TAU*i/32),sin(TAU*i/32),0)*radius]:
				tool.set_normal(basis*Vector3.BACK)
				tool.add_vertex(at+Vector3.DOWN*2.2+basis*p)
		element_count+=1
	func beam(a:Vector3,b:Vector3,radius:float,key:String):
		var direction:=b-a
		if direction.length()<0.001: return
		var up:=Vector3.FORWARD if absf(direction.normalized().dot(Vector3.UP))>0.98 else Vector3.UP
		box((a+b)*0.5,Vector3(radius,radius,direction.length()),key,Basis.looking_at(direction.normalized(),up))
	func cylinder(at:Vector3,radius:float,height:float,key:String,segments:=16):
		var tool:=surface(key)
		var center:=at+Vector3.DOWN*2.2
		for i in segments:
			var a:=Vector3(cos(TAU*i/segments)*radius,0,sin(TAU*i/segments)*radius)
			var b:=Vector3(cos(TAU*(i+1)/segments)*radius,0,sin(TAU*(i+1)/segments)*radius)
			var top_a:=center+a+Vector3.UP*height*0.5
			var top_b:=center+b+Vector3.UP*height*0.5
			var bottom_a:=top_a-Vector3.UP*height
			var bottom_b:=top_b-Vector3.UP*height
			for vertex in [bottom_a,top_b,top_a,bottom_a,bottom_b,top_b]:
				tool.set_normal((a+b).normalized())
				tool.add_vertex(vertex)
			for vertex in [center+Vector3.UP*height*0.5,top_a,top_b]:
				tool.set_normal(Vector3.UP)
				tool.add_vertex(vertex)
			for vertex in [center-Vector3.UP*height*0.5,bottom_b,bottom_a]:
				tool.set_normal(Vector3.DOWN)
				tool.add_vertex(vertex)
		element_count+=1
	func text(value:String,at:Vector3,height:float,color:=Color("efe9d7"),rotation_y:=0.0):
		var sign:=Label3D.new()
		sign.name="Sign_"+str(body.get_child_count())
		sign.text=value
		sign.font_size=96
		sign.pixel_size=height/96.0
		sign.outline_size=0
		sign.modulate=color
		sign.position=at+Vector3.DOWN*2.2
		sign.rotation.y=rotation_y
		sign.no_depth_test=false
		sign.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		sign.visibility_range_end=150
		body.add_child(sign)
	func window(x:float,w:float,bottom:=0.4,top:=3.25,key:="glass"):
		box(Vector3(x,(bottom+top)*0.5,0.14),Vector3(w,top-bottom,0.10),key)
		for edge in [-1,1]: box(Vector3(x+edge*w*.5,(bottom+top)*.5,0.24),Vector3(.07,top-bottom+.08,.22),"frame")
		for y in [bottom,top]: box(Vector3(x,y,.24),Vector3(w+.08,.075,.22),"frame")
		# Small reflection ribs and sill give glass real depth, rather than a label on a box.
		box(Vector3(x-w*.3,(bottom+top)*.5,.197),Vector3(.025,top-bottom-.15,.016),"cream")
	func door(x:float,w:=1.1,key:="frame"):
		window(x,w,0.06,2.7,"glass")
		box(Vector3(x-w*.36,1.25,.40),Vector3(.045,.82,.05),"gold")
		box(Vector3(x,.13,.25),Vector3(w,.16,.22),key)
		var normal:Vector3=body.get_meta("frontage_normal")
		body.set_meta("door_approach",body.to_global(Vector3(x,-1.3,0))+normal*1.0)
	func awning(x:float,w:float,y:float,depth:float,key:String):
		box(Vector3(x,y,depth*.5),Vector3(w,.09,depth),key,Basis(Vector3.RIGHT,deg_to_rad(8)))
		box(Vector3(x,y-.12,depth),Vector3(w,.24,.055),key)
		for side in [-1,1]: beam(Vector3(x+side*w*.44,y-.65,.1),Vector3(x+side*w*.44,y,depth*.86),.035,"frame")
	func bench(x:float,w:float,key:="wood"):
		for z in [.45,.59,.73,.87]: box(Vector3(x,.49,z),Vector3(w,.095,.12),key)
		for end in [-1,1]: box(Vector3(x+end*w*.4,.23,.66),Vector3(.16,.46,.52),"stone")
	func stool(x:float,z:float,key:String):
		box(Vector3(x,.47,z),Vector3(.34,.065,.34),key)
		for a in [-1,1]:
			for b in [-1,1]: box(Vector3(x+a*.13,.235,z+b*.13),Vector3(.036,.47,.036),key)
	func table(x:float,z:float,key:="white"):
		cylinder(Vector3(x,.74,z),.31,.055,key)
		cylinder(Vector3(x,.36,z),.028,.70,key,8)
		for a in [-1,1]: beam(Vector3(x,.05,z),Vector3(x+a*.26,.02,z+a*.18),.036,key)
	func finish():
		for key in surfaces:
			var view:=MeshInstance3D.new()
			view.name="Facade_"+key
			view.mesh=surfaces[key].commit()
			view.material_override=world.materials["ds_"+key]
			view.visibility_range_end=220
			view.visibility_range_end_margin=25
			body.add_child(view)
		body.set_meta("detail_elements",element_count)

static func _shop(world:Node3D,item:Dictionary):
	var f:=Frontage.new(world,item)
	match str(item.style):
		"matcha": _matcha(f)
		"nakano": _nakano(f)
		"pork_roll": _pork_roll(f)
		"kuki": _kuki(f)
		"kwang": _kwang(f)
		"wingboy": _wingboy(f)
		"edition": _edition(f)
		"holy_basil": _holy_basil(f)
		"messina": _messina(f)
		"kurtosh": _kurtosh(f)
		"dopa": _dopa(f)
		"shortstop": _shortstop(f)
	f.finish()

static func _matcha(f:Frontage):
	f.window(-1.0,1.95,.1,3.0,"warm_glass")
	f.door(1.05,1.75)
	f.awning(0,4.38,3.48,.66,"coal")
	f.text("M A T C H A — Y A",Vector3(0,3.45,.75),.20)
	for x in range(10):
		for z in range(2): f.box(Vector3(-2+x*.43,.025,.20+z*.14),Vector3(.38,.026,.12),"matcha" if (x+z)%3 else "cream")
	for i in range(6): f.beam(Vector3(-1.86+i*.30,2.1+(i%2)*.38,.205),Vector3(-1.56+i*.30,2.1+((i+1)%2)*.38,.205),.028,"white")
	f.box(Vector3(-1.0,.90,.29),Vector3(1.93,.10,.20),"wood")
	f.text("まっちゃ家",Vector3(1.99,3.06,.3),.16)

static func _nakano(f:Frontage):
	for row in range(30): f.box(Vector3(-.68,.18+row*.104,.16),Vector3(f.width-1.75,.075,.19),"coal")
	f.door(f.width*.33,1.35)
	f.bench(-.78,3.4)
	for i in range(3):
		f.box(Vector3(f.width*.33-.42+i*.42,2.36,.44),Vector3(.40,.58,.045),"gold")
		f.cylinder(Vector3(-1.65+i*1.22,3.58,.42),.17,.45,"cream")
		f.beam(Vector3(-1.65+i*1.22,3.81,.42),Vector3(-1.65+i*1.22,4.05,.42),.018,"coal")
	f.text("NAKANO DARLING",Vector3(-.58,4.17,.22),.22)
	f.text("中野ダーリン",Vector3(f.width*.33,2.38,.48),.14,Color("302d25"))
	f.box(Vector3(-2.52,1.67,.36),Vector3(.30,1.10,.05),"wood")
	f.text("O\nP\nE\nN",Vector3(-2.52,1.68,.40),.17,Color("252621"))

static func _pork_roll(f:Frontage):
	f.window(0,3.08,.85,3.0,"warm_glass")
	f.box(Vector3(0,.8,.38),Vector3(3.1,.8,.35),"red")
	f.box(Vector3(0,1.24,.48),Vector3(3.2,.10,.48),"cream")
	f.text("MARRICKVILLE",Vector3(0,3.34,.22),.22)
	f.text("PORK ROLL",Vector3(0,2.76,.26),.29,Color("f8e4c1"))
	for i in range(8): f.box(Vector3(-1.35+i*.37,1.47,.22),Vector3(.23,.14,.08),"ochre")
	f.text("BÁNH MÌ",Vector3(0,.74,.58),.28)
	for side in [-1,1]: f.box(Vector3(side*1.58,2.1,.26),Vector3(.13,2.35,.25),"red")
	# The Darling Square branch has a dark brick surround, unlike the original
	# Illawarra Road shop's broad red awning.
	for y in range(12):
		for side in [-1,1]: f.box(Vector3(side*1.73,.24+y*.28,.18),Vector3(.12,.012,.04),"slate")

static func _kuki(f:Frontage):
	f.window(-1.32,1.43,1.0,3.1,"warm_glass")
	f.window(1.0,2.32,1.0,3.38,"warm_glass")
	f.box(Vector3(1.0,2.9,.27),Vector3(2.28,.87,.18),"peach")
	f.box(Vector3(-1.32,3.30,.27),Vector3(1.56,.42,.22),"cream")
	f.text("KUKI",Vector3(-1.32,3.31,.41),.27,Color("756342"))
	f.awning(-1.32,1.55,2.71,.63,"peach")
	f.text("ORDER HERE",Vector3(-1.32,2.57,.70),.14)
	for x in [-1.32,1.0]:
		f.box(Vector3(x,1.03,.39),Vector3(1.55 if x<0 else 2.37,.33,.60),"pink_stone")
		for i in range(7): f.beam(Vector3(x-.63+i*.18,.92,.702),Vector3(x-.43+i*.18,1.10,.703),.017,"cream")
	for x in range(8): f.box(Vector3(-1.99+x*.18,.45,.25),Vector3(.10,.82,.24),"wood")
	f.box(Vector3(2.09,2.22,.42),Vector3(.38,.49,.14),"peach")
	f.text("KU\nKI",Vector3(2.09,2.22,.51),.17)
	f.text("SOFT SERVE + COOKIES",Vector3(1.0,2.60,.38),.11)

static func _kwang(f:Frontage):
	f.window(-2.2,1.92,.28,3.16,"glass")
	f.window(-.22,1.65,.28,3.16,"glass")
	f.window(2.63,1.22,.28,3.16,"glass")
	f.door(1.18,1.02)
	f.awning(0,f.width,3.62,.91,"cream")
	f.box(Vector3(-2.77,1.82,.35),Vector3(.54,2.55,.12),"coal")
	f.text("광\n장\n포\n차",Vector3(-2.77,1.83,.43),.31,Color("d65a3f"))
	f.text("KWANG JANG POCHA",Vector3(0,3.68,.98),.27,Color("684d3b"))
	for i in range(11): f.box(Vector3(-3.12+i*.59,3.28,.99),Vector3(.25,.47,.026),["red","blue","cream"][i%3])
	for x in [-2.25,-.95,2.65]: f.stool(x,.81,"red" if x<0 else "ochre")

static func _wingboy(f:Frontage):
	for x in [-2.4,-.43,2.35]: f.window(x,1.72,1.03,3.35,"warm_glass")
	f.door(1.06,1.05)
	for i in range(28):
		var x:float=-3.48+i*.25
		if absf(x-1.06)>.70: f.box(Vector3(x,.50,.25),Vector3(.215,.95,.18),"green")
	f.box(Vector3(-1.46,1.01,.36),Vector3(4.05,.10,.34),"wood")
	f.box(Vector3(2.80,1.01,.36),Vector3(1.55,.10,.34),"wood")
	f.box(Vector3(0,3.79,.25),Vector3(4.24,.59,.20),"coal")
	f.text("WINGBOY",Vector3(0,3.8,.37),.43)
	f.text("WINGS · BEER",Vector3(-1.46,2.61,.25),.18,Color("ed7052"))
	f.box(Vector3(1.88,1.67,.37),Vector3(.57,.95,.07),"coal")
	f.text("WINGBOY\nMENU",Vector3(1.88,1.80,.42),.13)
	for i in range(6): f.box(Vector3(1.88,1.61-i*.081,.42),Vector3(.39,.014,.01),"cream")

static func _edition(f:Frontage):
	f.window(-2.65,1.06,.25,3.78,"coal")
	f.window(2.04,2.28,.25,3.78,"glass")
	f.box(Vector3(0,2.02,.23),Vector3(1.4,4.04,.27),"slate")
	for y in [1.10,2.92]: f.box(Vector3(0,y,.375),Vector3(1.41,.027,.025),"frame")
	f.door(-1.49,1.1)
	f.bench(1.44,3.45)
	f.text("EDITION COFFEE ROASTERS",Vector3(0,2.03,.40),.09,Color("292d2b"))
	f.box(Vector3(0,2.31,.40),Vector3(.25,.23,.03),"coal")
	f.text("E",Vector3(0,2.32,.43),.18,Color("8d8a7c"))
	for i in range(9): f.box(Vector3(-3.15+i*.34,3.95,.60),Vector3(.23,.055,1.2),"coal")

static func _holy_basil(f:Frontage):
	for x in [-2.73,-.91,2.73]: f.window(x,1.63,.55,3.3,"warm_glass")
	f.door(.93,1.28)
	f.box(Vector3(0,3.36,.3),Vector3(f.width,.47,.27),"gold")
	f.text("HOLY BASIL",Vector3(0,3.38,.47),.34,Color("ede3be"))
	for i in range(5):
		var x:float=-3.14+i*1.57
		f.box(Vector3(x,2.0,.34),Vector3(.13,2.68,.23),"gold")
		f.cylinder(Vector3(x,3.94,.43),.24,.47,"cream")
	for x in [-2.75,2.8]:
		f.box(Vector3(x,.82,.39),Vector3(1.21,.78,.28),"purple")
		f.box(Vector3(x,.43,.66),Vector3(1.22,.20,.62),"purple")

static func _messina(f:Frontage):
	for x in [-3.75,-1.25,3.75]: f.window(x,2.26,.1,3.98,"warm_glass")
	f.door(1.18,1.6)
	f.window(1.18,2.26,2.87,3.98,"warm_glass")
	f.box(Vector3(0,2.78,.30),Vector3(f.width,.15,.25),"frame")
	f.text("MESSINA",Vector3(0,3.53,.37),.56)
	for x in [-3.6,-1.45,3.60]:
		f.table(x,.90)
		f.stool(x-.50,.88,"white")
		_umbrella(f,Vector3(x,0,.90),.92)
	for x in [-4.62,4.6]:
		f.box(Vector3(x,.45,.78),Vector3(.60,.83,.55),"wood")
		for i in range(5): f.beam(Vector3(x,.89,.78),Vector3(x-.25+i*.11,1.14+(i%2)*.15,.67+(i%2)*.22),.045,"leaf")

static func _umbrella(f:Frontage,at:Vector3,radius:float):
	f.cylinder(at+Vector3.UP*1.22,.025,2.44,"white",8)
	for i in range(16):
		var a:=Vector3(cos(TAU*i/16)*radius,2.18,sin(TAU*i/16)*radius)
		var b:=Vector3(cos(TAU*(i+1)/16)*radius,2.18,sin(TAU*(i+1)/16)*radius)
		var tool:=f.surface("ochre" if i%2==0 else "white")
		var points:=[at+Vector3(0,2.5,0),at+a,at+b]
		var normal:Vector3=-(points[1]-points[0]).cross(points[2]-points[0]).normalized()
		for vertex in points:
			tool.set_normal(normal)
			tool.add_vertex(vertex+Vector3.DOWN*2.2)

static func _kurtosh(f:Frontage):
	f.window(-1.12,2.88,.34,3.33,"warm_glass")
	f.door(1.78,1.1)
	f.box(Vector3(-1.10,1.1,.39),Vector3(2.85,.22,.4),"wood")
	for row in range(3):
		for col in range(7): f.box(Vector3(-2.26+col*.35,.28+row*.21,.29),Vector3(.30,.17,.15),"ochre" if col%2 else "cream")
	f.box(Vector3(0,3.72,.23),Vector3(4.94,.58,.23),"cream")
	f.text("kürtősh",Vector3(0,3.75,.37),.43,Color("745836"))
	for i in range(7): f.cylinder(Vector3(-2.28+i*.37,1.32,.28),.105,.32,"ochre",10)
	f.text("HOUSE No. 5",Vector3(-1.12,2.74,.24),.14)

static func _dopa(f:Frontage):
	f.door(-2.82,1.44)
	f.window(1.13,4.85,.42,3.25,"warm_glass")
	f.box(Vector3(-1.49,1.78,.28),Vector3(.80,3.58,.30),"frame")
	f.text("D\nO\nP\nA",Vector3(-1.49,2.13,.46),.18,Color("dac28d"))
	for y in range(5):
		for x in range(17): f.box(Vector3(-1.03+x*.275,.29+y*.18,.26),Vector3(.245,.155,.13),"red")
	for x in [0.04,2.91]:
		f.table(x,.82)
		f.stool(x+.54,.86,"white")

static func _shortstop(f:Frontage):
	# Nick De Lorenzo's Darling Square photograph shows a small left entry,
	# right display pane, timber jambs and a tall glazed transom.
	f.door(-.77,1.36,"wood")
	f.window(.95,1.56,.89,2.82,"warm_glass")
	f.window(0,3.62,3.02,4.12,"glass")
	for x in [-1.84,-.03,1.79]: f.box(Vector3(x,1.45,.32),Vector3(.16,2.86,.25),"wood")
	for y in [.76,2.91]: f.box(Vector3(.92,y,.33),Vector3(1.66,.16,.25),"wood")
	for i in range(11): f.box(Vector3(.17+i*.15,.42,.30),Vector3(.12,.75,.21),"wood")
	f.box(Vector3(.92,1.0,.36),Vector3(1.55,.15,.36),"wood")
	for i in range(4): f.cylinder(Vector3(.38+i*.34,1.14,.31),.11,.09,"ochre",10)
	f.beam(Vector3(-.55,3.90,.16),Vector3(-.55,3.90,1.02),.065,"frame")
	for side in [-1,1]:
		f.disc(Vector3(-.55+side*.035,3.58,.76),.34,"blue",Basis(Vector3.UP,side*PI*.5))
		f.text("SHORT\nSTOP\n•",Vector3(-.55+side*.04,3.58,.76),.13,Color("f0e9d8"),side*PI*.5)
	for x in [-1.82,1.83]:
		f.box(Vector3(x,1.14,.38),Vector3(.29,1.05,.03),"coal")
		for i in range(7): f.beam(Vector3(x-.10,.74+i*.13,.40),Vector3(x+.10,.94+i*.13,.40),.014,["blue","ochre","matcha"][i%3])
	f.table(1.58,.97,"blue")
	f.bench(1.03,1.0)
