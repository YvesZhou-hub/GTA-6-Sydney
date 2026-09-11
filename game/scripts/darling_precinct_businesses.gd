extends RefCounted
## Directory completeness is distinct from geometrical completeness.
## New retail frames are original, inferred geometry on mapped street walls.
const Fronts=preload("res://scripts/darling_square_frontages.gd")
const SOURCE="res://assets/darling_precinct_frontages.json"
const DIRECTORY="res://assets/darling_precinct_directory.json"
static func frontages() -> Array:return JSON.parse_string(FileAccess.get_file_as_string(SOURCE)).shops
static func directory() -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY))
static func metadata() -> Array[Dictionary]:
	var out:Array[Dictionary]=[]
	for item in frontages():
		var p:=Vector3(item.front[0],4.5,item.front[1]);var n:=Vector3(item.normal[0],0,item.normal[1]);var right:=Vector3.UP.cross(n)
		var door_side:float=1.0 if item.id=="darling_business_bendigo_bank" else -1.0
		var arrival:Vector3=p+n*1.65+right*(door_side*item.width*.32)
		out.append({"id":item.id,"name":item.name,"center":p,"map_position":p,"arrival":arrival,"position":arrival,"source":item.source,"precision":item.confidence,"model_status":"mapped_inferred_frontage","osm":item.osm,"building":item.building})
	for item in directory().tenants:
		if item.model_status!="exchange_building_directory":continue
		if item.id=="darling_business_haidilao_hotpot":continue # existing exchange_haidilao destination
		# Floor-specific services navigate to the same real public building edge,
		# never a fake street counter or a position inside the existing solid floor.
		var p:=Vector3(-768.495,4.5,1993.502)
		var arrival:=Vector3(-748.0,4.5,1998.5)
		out.append({"id":item.id,"name":item.name+" · Exchange 楼栋入口","center":p,"map_position":p,"arrival":arrival,"position":arrival,"source":item.source,"precision":item.location_precision,"level":item.get("level",""),"model_status":item.model_status,"building":"way/614603737"})
	return out
static func capture_views() -> Array:
	return [["darling_steam_mill_new",Vector3(-850,6.6,2052),Vector3(-850,6.5,2044)],["darling_puppuccino_lillianna",Vector3(-867,6.4,2056),Vector3(-863,6.5,2050)],["darling_tumbalong_restaurants",Vector3(-787,7,2016),Vector3(-800,6.5,2017)],["darling_little_pier_shops",Vector3(-705,7.0,1973),Vector3(-697,6.4,1988)],["darling_harbour_street_shops",Vector3(-656,7,2041),Vector3(-672,6.5,2045)],["darling_little_hay_shops",Vector3(-708,6.8,2083),Vector3(-706,6.5,2073)],["darling_bendigo_detail",Vector3(-669,6.4,1999),Vector3(-676,6.4,2000)],["darling_tattoo_detail",Vector3(-697,6.7,2080),Vector3(-696,6.6,2075)],["darling_bubu_detail",Vector3(-822,6.5,2035),Vector3(-820,6.5,2041)]]
static func walk_routes() -> Array:return []
static func build(w:Node3D):
	if w.has_meta("darling_precinct_businesses"):return
	for key in Fronts.COLORS:w._mat("ds_"+key,Color(Fronts.COLORS[key]),.32 if key=="glass" else .76,.32 if key in ["glass","frame","gold"] else 0.0)
	for item in frontages():
		var n:=Vector3(item.normal[0],0,item.normal[1]);var p:=Vector3(item.front[0],w.GROUND+.025,item.front[1])
		w._batch_box(p+n*1.3,Vector3(item.width+.24,.035,2.9),"paving",Basis(Vector3.UP.cross(n),Vector3.UP,n))
		var f=Fronts.Frontage.new(w,item)
		_fitout(f,item)
		f.finish()
		for child in f.body.get_children():
			if child is MeshInstance3D:child.set_meta("intact_material",child.material_override)
		f.body.set_meta("model_status","mapped_inferred_frontage")
		f.body.set_meta("source_precision",item.confidence)
	for item in metadata():w.anchors[item.id]=item.arrival
	w.set_meta("darling_precinct_businesses",metadata())
	w.set_meta("darling_precinct_directory",directory())

static func _fitout(f,item:Dictionary):
	if item.id=="darling_business_bar_bubu":_bubu(f);return
	if item.id=="darling_business_bendigo_bank":_bendigo(f);return
	if item.id=="darling_business_thirteen_feet_tattoo":_tattoo(f);return
	var width:float=f.width
	var accent:String=item.accent
	var style:String=item.style
	var door_x:float=-width*.32
	f.door(door_x,minf(1.15,width*.29))
	var display_x:float=width*.16
	var display_width:float=width*.56
	f.window(display_x,display_width,.35,3.12,"glass" if style in ["clinic","bank","optics"] else "warm_glass")
	for x in [-width*.5,width*.5]:f.box(Vector3(x,2.20,.12),Vector3(.17,4.4,.2),"frame")
	f.box(Vector3(0,3.48,.22),Vector3(width-.1,.62,.2),accent)
	f.box(Vector3(0,4.15,.18),Vector3(width,.12,.24),"coal")
	# Small textual identifiers, not invented oversized corporate logo signage.
	var label:String=item.name
	if label.length()>22:label=label.replace(" Specialty","").replace(" by Taste of Shanghai","").replace(" On The Rocks","")
	var font_height:float=minf(.23,(width-.45)/maxf(1,label.length())*1.40)
	f.text(label,Vector3(0,3.50,.335),font_height,Color("313633") if accent in ["white","cream","gold","peach"] else Color("eee8d6"))
	f.box(Vector3(display_x,.52,.30),Vector3(display_width,.16,.13),accent)
	if style in ["gifts","toys","convenience","pet","optics"]:
		_shelves(f,display_x,display_width,style,accent)
	elif style in ["clinic","bank","tattoo"]:
		_services(f,display_x,display_width,style,accent)
	else:
		_food(f,display_x,display_width,style,accent)
	# Threshold and brushed push plate retain an unobstructed public approach.
	f.box(Vector3(door_x,.035,.22),Vector3(minf(1.15,width*.29),.07,.36),"slate")
	f.box(Vector3(door_x+.25,1.10,.30),Vector3(.05,.35,.055),"gold")

static func _shelves(f,x:float,width:float,style:String,accent:String):
	if style=="pet":
		# This yellow/white partition and lower wood panel are visible in the
		# operator's specifically labelled Darling Square interior photograph.
		# The exterior frame remains inferred, not asserted as photo verified.
		for col in 20:f.box(Vector3(x-width*.47+col*width*.049,1.93,.27),Vector3(width*.049,2.8,.035),"gold" if col%2 else "white")
		f.box(Vector3(x,.50,.29),Vector3(width,.53,.05),"wood")
	for row in 4:
		var y:float=.8+row*.49
		f.box(Vector3(x,y,.35),Vector3(width-.12,.06,.28),"wood")
		for col in 7:
			var sx:float=x-width*.43+col*width*.14
			match style:
				"gifts":
					var gift:String=["blue","peach","cream","green","pink_stone","purple","white"][col%7]
					f.box(Vector3(sx,y+.17,.39),Vector3(width*.115,.28,.15),gift)
					f.box(Vector3(sx,y+.17,.474),Vector3(.016,.28,.014),"cream")
					f.box(Vector3(sx,y+.17,.478),Vector3(width*.115,.02,.014),"cream")
					f.cylinder(Vector3(sx,y+.055,.52),.034,.1,"cream")
					for stem in 3:f.beam(Vector3(sx-.016+stem*.016,y+.1,.52),Vector3(sx-.03+stem*.03,y+.29,.52),.007,"wood")
				"optics":
					for side in [-1,1]:
						for i in 12:
							var a:=Vector3(sx+side*.045+cos(i*TAU/12)*.036,y+.11+sin(i*TAU/12)*.029,.50)
							var b:=Vector3(sx+side*.045+cos((i+1)*TAU/12)*.036,y+.11+sin((i+1)*TAU/12)*.029,.50)
							f.beam(a,b,.009,"coal")
					f.beam(Vector3(sx-.015,y+.12,.5),Vector3(sx+.015,y+.12,.5),.01,"gold")
				"toys":
					f.box(Vector3(sx,y+.15,.39),Vector3(width*.105,.25,.18),["peach","cream","pink_stone","matcha"][col%4])
					f.disc(Vector3(sx,y+.16,.487),.035,"white")
				"pet":
					f.box(Vector3(sx,y+.14,.4),Vector3(width*.09,.25,.16),"cream" if col%2 else "blue")
					f.disc(Vector3(sx,y+.16,.49),.036,"ochre")
				_:
					f.cylinder(Vector3(sx,y+.12,.4),.044,.22,["green","red","cream"][col%3])
	if style=="pet":
		f.disc(Vector3(-f.width*.35,2.80,.33),.10,"ochre")
		for k in 4:f.disc(Vector3(-f.width*.35-.13+k*.087,2.94+.035*sin(k),.33),.038,"ochre")

static func _services(f,x:float,width:float,style:String,accent:String):
	if style=="bank":
		f.box(Vector3(x,.94,.42),Vector3(.76,1.52,.26),"slate")
		f.box(Vector3(x,1.28,.558),Vector3(.46,.31,.015),"blue")
		f.box(Vector3(x,.90,.57),Vector3(.31,.055,.06),"coal")
		f.text("ATM",Vector3(x,1.65,.565),.09)
	elif style=="clinic":
		for row in 12:f.box(Vector3(x,.73+row*.09,.36),Vector3(width-.15,.048,.018),"cream")
		f.box(Vector3(x,2.19,.36),Vector3(.11,.60,.035),"white")
		f.box(Vector3(x,2.19,.36),Vector3(.55,.11,.035),"white")
		f.text("RECEPTION",Vector3(x,1.99,.39),.07)
	else:
		f.box(Vector3(x,1.67,.34),Vector3(width-.15,1.45,.03),"cream")
		for i in 5:
			var sx:float=x-width*.36+i*width*.18
			f.disc(Vector3(sx,1.83,.38),.08,"coal")
			f.beam(Vector3(sx-.08,1.50,.38),Vector3(sx+.08,1.73,.38),.015,"coal")

static func _food(f,x:float,width:float,style:String,accent:String):
	if style in ["cafe","bar"]:
		f.box(Vector3(x,.82,.37),Vector3(width-.12,.10,.32),"wood")
		for i in 7:f.cylinder(Vector3(x-width*.4+i*width*.13,1.08,.43),.04,.37,"green" if style=="bar" else "white")
		if style=="cafe":
			f.box(Vector3(x,1.09,.41),Vector3(.63,.31,.25),"steel" if Fronts.COLORS.has("steel") else "slate")
			for side in [-1,1]:f.cylinder(Vector3(x+side*.16,.88,.55),.06,.13,"white")
	elif style in ["bakery","dessert","tea"]:
		f.box(Vector3(x,.95,.43),Vector3(width-.15,.57,.26),accent)
		for row in 2:
			for i in 7:
				var sx:float=x-width*.40+i*width*.13
				f.cylinder(Vector3(sx,1.17+row*.2,.48),.055,.11,"ochre" if style=="bakery" else "cream")
		f.box(Vector3(x,1.54,.44),Vector3(width-.14,.035,.28),"glass")
	else:
		f.box(Vector3(x,1.16,.36),Vector3(width-.13,.72,.10),"wood")
		for i in 8:f.box(Vector3(x-width*.44+i*width*.125,1.16,.421),Vector3(.025,.7,.02),"frame")
		for i in 3:
			var sx:float=x-width*.3+i*width*.3
			f.disc(Vector3(sx,2.62,.35),.13,accent)
			f.beam(Vector3(sx,2.78,.34),Vector3(sx,3.11,.34),.019,"frame")
	# Menu is behind glazing; pavement stays empty where exact table leases
	# and current outdoor seating cannot be established from the directory.
	f.box(Vector3(x,2.24,.37),Vector3(minf(1.2,width*.65),.6,.028),"coal")
	for row in 5:f.box(Vector3(x,2.42-row*.084,.39),Vector3(minf(.81,width*.52),.012,.012),"cream")

static func _brick_pier(f,x:float,width:float):
	f.box(Vector3(x,2.2,.22),Vector3(width,4.4,.15),"coal")
	for row in 40:
		f.box(Vector3(x,.07+row*.11,.305),Vector3(width,.016,.012),"stone")
		for col in ceili(width/.32):f.box(Vector3(x-width*.5+.16+(col+(row%2)*.5)*.32,.12+row*.11,.305),Vector3(.012,.10,.012),"stone")

static func _bubu(f):
	# Kera Wong's 2025 official precinct photograph shows an open black
	# lift-up glass front, yellow fluted counter, red high stools and gallery wall.
	var width:float=f.width
	f.box(Vector3(0,2.05,.06),Vector3(width,4.1,.05),"ochre")
	f.box(Vector3(0,3.94,.25),Vector3(width,.3,.20),"red")
	for x in [-width*.5,width*.5]:f.box(Vector3(x,2,.28),Vector3(.14,4,.15),"frame")
	f.door(-width*.32,1.02)
	f.box(Vector3(.45,1.01,.62),Vector3(width*.66,.12,.48),"wood")
	for i in 20:f.box(Vector3(-width*.18+i*width*.032,.51,.77),Vector3(width*.020,.95,.055),"gold")
	for row in 3:
		for col in 5:
			var x:float=-.55+col*.56;var y:float=1.38+row*.55
			f.box(Vector3(x,y,.30),Vector3(.49,.035,.21),"wood")
			f.box(Vector3(x-.23,y+.24,.30),Vector3(.03,.50,.21),"wood")
			for j in 3:f.cylinder(Vector3(x-.14+j*.14,y+.16,.38),.042,.29,"green" if (col+j)%2 else "red")
	for col in 7:
		var x:float=-width*.40+col*width*.13
		f.box(Vector3(x,3.32+.08*sin(col),.26),Vector3(width*.11,.54,.06),"coal")
		f.box(Vector3(x,3.32+.08*sin(col),.30),Vector3(width*.092,.44,.025),["peach","cream","pink_stone"][col%3])
		# Original abstract artwork; no copyrighted photographed poster reproduced.
		f.disc(Vector3(x,3.37,.322),.06,"red")
	for x in [-.30,.47,1.24]:
		f.box(Vector3(x,.73,1.02),Vector3(.39,.07,.40),"red")
		for a in [-1,1]:
			for b in [-1,1]:f.beam(Vector3(x+a*.18,.03,1.02+b*.19),Vector3(x+a*.15,.72,1.02+b*.15),.036,"red")
		for j in 5:f.beam(Vector3(x-.16+j*.08,.75,1.19),Vector3(x-.16+j*.08,1.20,1.27),.026,"red")
	f.box(Vector3(0,3.65,.85),Vector3(width-.20,.045,1.25),"glass",Basis(Vector3.RIGHT,-.2))
	for x in [-width*.47,0.0,width*.47]:f.beam(Vector3(x,3.77,.12),Vector3(x,3.53,1.44),.04,"frame")
	f.text("BAR BUBU",Vector3(-width*.32,2.95,.36),.11)

static func _bendigo(f):
	# Jodie Dang Architects' completed branch exterior: bronze curved glazing,
	# dark brick plinth, continuous upper louvres, right door and vertical sign.
	var width:float=f.width
	_brick_pier(f,-width*.48,.25);_brick_pier(f,width*.48,.30)
	var door_x:float=width*.32
	f.door(door_x,1.08)
	f.box(Vector3(-.65,.49,.23),Vector3(width*.69,.98,.14),"coal")
	for row in 9:
		f.box(Vector3(-.65,.06+row*.105,.31),Vector3(width*.69,.012,.012),"stone")
		for col in 12:f.box(Vector3(-width*.46+(col+(row%2)*.5)*width*.057,.105+row*.105,.31),Vector3(.012,.10,.012),"stone")
	for col in 12:
		var x:float=-width*.45+col*width*.056
		var depth:float=.25+.21*pow((x+.55)/(width*.45),2)
		f.box(Vector3(x,2.0,depth),Vector3(width*.06,1.93,.07),"warm_glass")
		if col%3==0:f.box(Vector3(x,2.0,depth+.055),Vector3(.047,1.99,.07),"frame")
	for row in 7:f.box(Vector3(0,3.18+row*.105,.27),Vector3(width-.20,.058,.17),"frame")
	f.box(Vector3(door_x-.72,2.29,.37),Vector3(.41,2.67,.15),"coal")
	var label:=Label3D.new();label.text="Bendigo Bank";label.font_size=96;label.pixel_size=.0024;label.outline_size=0;label.position=Vector3(door_x-.72,.05,.46);label.rotation.z=-PI*.5;label.modulate=Color("f3f2ed");label.visibility_range_end=140;f.body.add_child(label)
	f.disc(Vector3(door_x-.72,3.38,.458),.15,"white")
	f.text("B",Vector3(door_x-.72,3.38,.47),.19,Color("343b3a"))
	for i in 4:f.box(Vector3(-1.50+i*.55,1.14,.43),Vector3(.30,.28,.025),"cream")

static func _tattoo(f):
	# Branch facade photograph published by its waste-management supplier:
	# black brick, brass serif fascia, left door, flash sheets and projecting neon.
	var width:float=f.width
	_brick_pier(f,-width*.45,width*.20);_brick_pier(f,width*.46,width*.14)
	f.door(-width*.23,1.12)
	f.window(width*.17,width*.44,.54,2.74,"glass")
	f.box(Vector3(0,3.15,.27),Vector3(width-.24,.43,.12),"green")
	f.text("13 FEET TATTOO",Vector3(0,3.16,.34),.23,Color("ceb770"))
	for row in 6:f.box(Vector3(0,3.50+row*.105,.25),Vector3(width-.24,.055,.17),"frame")
	for row in 4:
		var x:float=-width*.45;var y:float=.59+row*.61
		f.box(Vector3(x,y,.33),Vector3(width*.18,.55,.06),"frame")
		f.box(Vector3(x,y,.37),Vector3(width*.16,.49,.035),"cream")
		for mark in 3:
			var sx:float=x-width*.05+mark*width*.05
			for segment in 12:
				var a:=Vector3(sx+sin(segment*.6)*.045,y-.17+segment*.027,.393)
				var b:=Vector3(sx+sin((segment+1)*.6)*.045,y-.17+(segment+1)*.027,.393)
				f.beam(a,b,.013,"coal")
	f.text("13",Vector3(width*.17,2.30,.31),.31,Color("e97958"))
	f.text("Feet",Vector3(width*.17,1.99,.31),.23,Color("71b8eb"))
	f.text("TATTOO",Vector3(width*.17,1.67,.31),.21,Color("d8bd56"))
	var blade:=Vector3(width*.42,3.53,.85)
	f.box(blade,Vector3(.045,.75,.67),"coal")
	for side in [-1,1]:
		var basis:=Basis(Vector3.UP,side*PI*.5)
		for a in [-1,1]:
			f.box(blade+basis*Vector3(a*.29,0,.029),Vector3(.024,.67,.025),"matcha",basis)
			f.box(blade+basis*Vector3(0,a*.33,.029),Vector3(.61,.024,.025),"matcha",basis)
		f.text("13\nTATTOO",blade+Vector3(side*.037,0,0),.12,Color("dfa651"),side*PI*.5)
	f.bench(width*.17,width*.43,"wood")
