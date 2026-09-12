extends SceneTree
const Lighting=preload("res://scripts/public_lighting.gd")
const ICC=preload("res://scripts/icc_landmarks.gd")
const Opera=preload("res://scripts/opera_landmark.gd")
const Bridge=preload("res://scripts/bridge_landmark.gd")
class LocalWorld:
	extends "res://scripts/harbor_world.gd"
	func _ready():
		_make_materials();ICC.build(self);Opera.build(self);Bridge.build(self)
		_flush_batches();_build_structure_batches()
class Game:
	extends Node3D
	var world:Node3D
	var city_clock=null
var checks:Array=[]
func check(name:String,passed:bool):
	checks.append({"name":name,"passed":passed})
	print("PASS " if passed else "FAIL ",name)
func _initialize():call_deferred("run")
func run():
	var game:=Game.new();root.add_child(game)
	var world:=LocalWorld.new();game.world=world;game.add_child(world)
	await physics_frame;await physics_frame
	var lighting:=Lighting.new();game.add_child(lighting);lighting.setup(game)
	check("fixed finite light budget includes production ICC, Opera and bridge owners",lighting.snapshot().count==34 and lighting.snapshot().count<=Lighting.MAX_LIGHTS)
	check("all light sources use existing intact damage owners",lighting.snapshot().lights.all(func(r):return r.intact))
	var initial_count:=lighting.get_child_count();lighting.setup(game)
	check("setup replaces old nodes instead of accumulating lights",lighting.get_child_count()==initial_count and lighting.snapshot().count==34)
	var before:Dictionary={}
	for row:Dictionary in lighting._lights:before[row.id]=[row.node.get_instance_id(),row.node.global_transform,row.node.visible,row.node.shadow_enabled,row.node.spot_range,row.node.spot_angle]
	for i in 101:lighting.apply_cycle({"night_factor":i/100.0})
	var fixed:=true
	for row:Dictionary in lighting._lights:
		fixed=fixed and before[row.id]==[row.node.get_instance_id(),row.node.global_transform,row.node.visible,row.node.shadow_enabled,row.node.spot_range,row.node.spot_angle]
	check("101 cycle updates change no positions, node identities or light feature flags",fixed)
	check("all new lights keep shadows disabled and stay visible",lighting.snapshot().lights.all(func(r):return r.visible and not r.shadows))
	check("night lights have finite positive energies",lighting.snapshot().lights.all(func(r):return is_finite(r.energy) and r.energy>0))
	lighting.apply_cycle({"night_factor":0.0})
	check("architectural and bridge lights have zero energy in daylight",lighting.snapshot().lights.filter(func(r):return not r.id.begins_with("icc")).all(func(r):return r.energy==0))
	check("public indoor lamps remain active during day",lighting.snapshot().lights.filter(func(r):return r.id.begins_with("icc")).all(func(r):return r.energy>0))
	var material:ShaderMaterial=world.materials.icc_theatre_floor
	check("foyer shader uses transformed venue axes and original non-emissive finish",material.get_shader_parameter("venue_origin")==ICC.THEATRE and material.get_shader_parameter("venue_east")==ICC.EAST and not "EMISSION" in material.shader.code)
	check("auditorium dark region remains outside explicit foyer boundary", "x<42.20 || z< -36.0 || z>36.0" in material.shader.code)
	var body:StaticBody3D=world.structures["icc/theatre/floor"].node
	var shape:ConcavePolygonShape3D
	for child in body.get_children():
		if child is CollisionShape3D:shape=child.shape
	var expected:PackedVector3Array=ICC.Geo.prism(ICC._poly(487371417,ICC.THEATRE),-.215,.035).get_faces()
	check("original theatre slab collision vertices and old damage ID are unchanged",shape.get_faces()==expected and body.get_meta("damage_id")=="icc/theatre/floor")
	var space:=world.get_world_3d().direct_space_state
	for x in [42.5,48.6,54.8]:
		var floor_ok:=true;var cone_ok:=true
		for z in [-21.0,-5.0,11.0]:
			var p:=ICC.point(ICC.THEATRE,Vector3(x,.035,z))
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.3,p-Vector3.UP*.2))
			floor_ok=floor_ok and not hit.is_empty() and hit.collider==body and hit.normal.dot(Vector3.UP)>.999 and absf(hit.position.y-p.y)<.001
			var lamp:=ICC.point(ICC.THEATRE,Vector3(x,8.55,z))
			var down:=space.intersect_ray(PhysicsRayQueryParameters3D.create(lamp,p-Vector3.UP*.02))
			cone_ok=cone_ok and not down.is_empty() and down.collider==body
		check("foyer floor row x=%s has physical upward support at original level"%x,floor_ok)
		check("existing ceiling strip x=%s has unobstructed downward light path"%x,cone_ok)
	for row:Dictionary in lighting._lights:
		if not row.id.begins_with("opera"):continue
		var query:=PhysicsShapeQueryParameters3D.new();var probe:=SphereShape3D.new();probe.radius=.27;query.shape=probe;query.transform.origin=row.position
		var floor_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(row.position,row.position-Vector3.UP*.8))
		check(row.id+" is above an intact upper platform, not buried in podium",space.intersect_shape(query).is_empty() and not floor_hit.is_empty() and floor_hit.collider.get_meta("damage_id","")==row.owner)
		var wash_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(row.position,row.position+row.position.direction_to(row.target)*row.node.spot_range))
		var wash_id:String=wash_hit.collider.get_meta("damage_id","") if not wash_hit.is_empty() else ""
		print("OPERA_WASH_FIRST_HIT ",row.id," ",wash_id)
		check(row.id+" reaches a roof surface without passing through the podium",wash_id.begins_with("opera/shell/"))
	lighting.apply_cycle({"night_factor":1.0})
	world._destroy_component("icc/theatre/foyer_west",ICC.THEATRE,1e9,false)
	lighting._process(.21)
	check("destroyed ceiling support extinguishes all 12 foyer lights without clock tick",lighting.snapshot().lights.filter(func(r):return r.id.begins_with("icc_foyer")).all(func(r):return r.energy==0))
	check("other venues are unaffected by local damage",lighting.snapshot().lights.filter(func(r):return r.id.begins_with("icc_convention")).all(func(r):return r.energy>0))
	world._destroy_component("icc/theatre/floor",ICC.THEATRE,1e9,false)
	await physics_frame;await physics_frame
	var p:=ICC.point(ICC.THEATRE,Vector3(54.8,.035,-5))
	var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.2,p-Vector3.UP*.3))
	check("old destroyed floor ID still removes real support, no hidden overlay remains",hit.is_empty())
	world.repair_all();lighting._process(.21)
	check("repair restores ceiling light energies",lighting.snapshot().lights.filter(func(r):return r.id.begins_with("icc_foyer")).all(func(r):return r.energy>0))
	check("repair preserves the dedicated foyer material",body.get_child(0).material_override==material)
	var snapshot:=lighting.snapshot();lighting.clear()
	check("clear removes all owned fixtures and references",lighting.get_child_count()==0 and lighting.snapshot().count==0 and lighting._world==null)
	var hashes:={}
	for path in ["source/public_lighting_test.gd","game/scripts/public_lighting.gd","game/scripts/icc_landmarks.gd","game/scripts/opera_landmark.gd","game/scripts/bridge_landmark.gd","game/scripts/city_landmarks.gd","game/scripts/harbor_world.gd","game/assets/icc_geometry.json","game/shaders/opera_tiles.gdshader"]:
		hashes[path]=FileAccess.get_sha256("res://../"+path)
	var passed:=checks.all(func(r):return r.passed)
	var report:={"passed":passed,"count":checks.size(),"checks":checks,"hashes":hashes,"headless":DisplayServer.get_name()=="headless","native_brightness_validated":false,"user_saves_touched":false,"fixture":"production ICC / Opera / bridge geometry in isolated LocalWorld; no full city","lights":snapshot}
	FileAccess.open("res://../reports/public-lighting/checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PUBLIC_LIGHTING_COMPLETE ",checks.size()," passed=",passed)
	quit(0 if passed else 1)
