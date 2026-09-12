extends Node3D
## Bounded, fixed lights at authored public fixtures. Numeric energy only at runtime.
## This is a readability reconstruction, not a surveyed photometric installation.
const ICC=preload("res://scripts/icc_landmarks.gd")
const Opera=preload("res://scripts/opera_landmark.gd")
const Bridge=preload("res://scripts/bridge_landmark.gd")
const MAX_LIGHTS:=40
var _game:Node3D
var _world:Node3D
var _lights:Array[Dictionary]=[]
var _last_night:=0.0
var _damage_refresh:=0.0

func setup(game:Node3D) -> void:
	clear()
	_game=game;_world=game.world
	if not is_instance_valid(_world):return
	# Three sampled runs of the four EXISTING 62.6 m linear ceiling strips.
	# A small fixed set approximates their broad distributed light; no light per LED.
	if _world.structures.has("icc/theatre/foyer_west"):
		for x in [42.5,48.6,54.8]:
			for z in [-21.0,-5.0,11.0,27.0]:
				_spot("icc_foyer_%s_%s"%[x,z],ICC.point(ICC.THEATRE,Vector3(x,8.55,z)),ICC.point(ICC.THEATRE,Vector3(x,.035,z)),15.5,58,2.6,2.6,"icc/theatre/foyer_west","existing red-ceiling linear strip",180)
	# Existing paired recessed luminaires. Grouped sources stand in for the
	# much denser photographed fittings, without creating hundreds of lights.
	if _world.structures.has("icc/convention/floor"):
		for x in [24.0,42.0]:
			for z in [-10.0,14.0]:
				_spot("icc_convention_%s_%s"%[x,z],ICC.point(ICC.CONVENTION,Vector3(x,5.23,z)),ICC.point(ICC.CONVENTION,Vector3(x,0,z)),13,65,1.4,1.4,"icc/convention/floor","grouped existing recessed ceiling fittings",160)
	if _world.structures.has("icc/exhibition/event_deck"):
		for z in [-65.0,-20.0,25.0,70.0]:
			_spot("icc_exhibition_%s"%z,ICC.point(ICC.EXHIBITION,Vector3(53,11.28,z)),ICC.point(ICC.EXHIBITION,Vector3(53,6.50,z)),21,67,2,2,"icc/exhibition/event_deck","grouped existing recessed ceiling fittings",180)
	# Bridge sources coincide with already modeled lamp heads and depend on
	# their local deck component. They do not act as an artificial moon/sun.
	for station in [18.0,126.0,234.0,342.0,450.0]:
		var owner:="bridge/deck/%02d"%floori(station/Bridge.SPAN*42.0)
		if not _world.structures.has(owner):continue
		for side in [-23.95,23.95]:
			var p:=Bridge.pos(station,Bridge.DECK_Y+7.50,side)
			_spot("bridge_%s_%s"%[station,side],p,p-Vector3.UP*7.5,23,66,0,2.1,owner,"existing bridge lamp head",1400)
	# Restrained white architectural wash. Exact projector coordinates/power
	# are estimated, with visible housings at the outer podium edges.
	for row:Array in [[-58,-26,"0/0"],[-58,21,"0/2"],[58,-23,"4/0"],[58,19,"4/2"]]:
		var owner:String="opera/podium/upper/"+str(row[2])
		if not _world.structures.has(owner):continue
		var p:=(Opera.CENTER+Opera.site_basis()*Vector3(row[0],Opera.PODIUM_HEIGHT+.5,row[1]))
		var target:=(Opera.CENTER+Opera.site_basis()*Vector3(-26 if row[0]<0 else 23,39,row[1]))
		_spot("opera_wash_%s_%s"%[row[0],row[1]],p,target,115,40,0,1.7,owner,"estimated architectural wash at outer podium",1400)
		_housing(p,target)
	if game.get("city_clock")!=null:apply_cycle(game.city_clock.solar_state())
	else:apply_cycle({"night_factor":0.0})

func _spot(id:String,p:Vector3,target:Vector3,radius:float,angle:float,day:float,night:float,owner:String,source:String,fade:float) -> void:
	assert(_lights.size()<MAX_LIGHTS)
	var light:=SpotLight3D.new();light.name=id;add_child(light)
	light.global_position=p
	light.look_at(target,Vector3.FORWARD if absf((target-p).normalized().dot(Vector3.UP))>.98 else Vector3.UP)
	light.spot_range=radius;light.spot_angle=angle;light.spot_attenuation=.65;light.spot_angle_attenuation=.55
	light.light_color=Color("ffe8cc") if id.begins_with("icc") else Color("f1e5d0")
	light.light_specular=.25;light.light_energy=0
	light.shadow_enabled=false
	light.distance_fade_enabled=true;light.distance_fade_begin=fade;light.distance_fade_length=80
	light.set_meta("support_id",owner)
	_lights.append({"id":id,"node":light,"owner":owner,"source":source,"day":day,"night":night,"position":p,"target":target})

func _housing(p:Vector3,target:Vector3) -> void:
	var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.48,.24,.30);mesh.mesh=box
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("363c3e");mat.roughness=.8;mesh.material_override=mat
	add_child(mesh);mesh.global_position=p-Vector3.UP*.12;mesh.look_at(target)
	var base:=MeshInstance3D.new();var pedestal:=BoxMesh.new();pedestal.size=Vector3(.30,.38,.25)
	base.mesh=pedestal;base.material_override=mat;add_child(base);base.global_position=p-Vector3.UP*.31

func apply_cycle(state:Dictionary) -> void:
	_last_night=clampf(float(state.get("night_factor",0.0)),0,1)
	for row:Dictionary in _lights:
		var intact:=_owner_intact(row.owner)
		# Do not toggle visible, shadows or material features on clock ticks.
		var energy:float=lerpf(row.day,row.night,_last_night) if intact else 0.0
		if not is_equal_approx(row.node.light_energy,energy):row.node.light_energy=energy

func _process(delta:float) -> void:
	_damage_refresh-=delta
	if _damage_refresh<=0:
		_damage_refresh=.2
		apply_cycle({"night_factor":_last_night})

func _owner_intact(id:String) -> bool:
	return is_instance_valid(_world) and _world.structures.has(id) and not _world.destroyed.has(id) and is_instance_valid(_world.structures[id].node)

func snapshot() -> Dictionary:
	var entries:Array=[];var energy:=0.0
	for row:Dictionary in _lights:
		var light:SpotLight3D=row.node
		energy+=light.light_energy
		entries.append({"id":row.id,"owner":row.owner,"source":row.source,"position":[row.position.x,row.position.y,row.position.z],"target":[row.target.x,row.target.y,row.target.z],"energy":light.light_energy,"range":light.spot_range,"angle":light.spot_angle,"visible":light.visible,"shadows":light.shadow_enabled,"intact":_owner_intact(row.owner)})
	return {"lights":entries,"count":entries.size(),"max_lights":MAX_LIGHTS,"total_energy":energy,"night_factor":_last_night,"fixed_positions":true,"runtime_changes":"numeric light_energy only","photometric_survey":false}

func clear() -> void:
	_lights.clear()
	for child in get_children():remove_child(child);child.queue_free()
	_world=null;_game=null
