extends SceneTree
const FRONTAGES=preload("res://scripts/darling_square_frontages.gd")
class LocalSquare:
	extends "res://scripts/harbor_world.gd"
	func _ready():
		_make_materials()
		map_snapshot=CityMap.data()
		map_snapshot.buildings=map_snapshot.buildings.filter(func(item): return Vector2(item.center[0]+780,item.center[1]-2040).length()<250)
		map_snapshot.roads=map_snapshot.roads.filter(func(item):
			for p in item.points:
				if Vector2(p[0]+780,p[1]-2040).length()<350:return true
			return false)
		CityMap.build_terrain(self,map_snapshot)
		CityMap.build_roads(self,map_snapshot)
		CityMap.build_buildings(self,map_snapshot)
		FRONTAGES.build(self)
		_flush_batches()
		_ready_complete=true
var checks:Array=[]
func _initialize(): call_deferred("run")
func verify(name:String,result:bool):
	checks.append({"name":name,"passed":result})
	print("PASS " if result else "FAIL ",name)
func run():
	var world=LocalSquare.new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var records=FRONTAGES.metadata()
	verify("12 independently researched street frontage records",records.size()==12)
	var space=world.get_world_3d().direct_space_state
	var shape:=CapsuleShape3D.new();shape.radius=.32;shape.height=1.8
	var footprints:Dictionary={}
	var sign_text:Array=[]
	for item in records:
		var id:String="darling_square/"+item.id+"/frontage"
		verify(item.name+" integrated persistent structure",world.structures.has(id))
		var body:StaticBody3D=world.structures[id].node
		var at:Vector3=body.get_meta("door_approach")
		at.y=world.GROUND+1.0
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=at
		verify(item.name+" unobstructed door approach",space.intersect_shape(query).is_empty())
		verify(item.name+" projected to real outside building edge",float(item.projection_metres)<16.0 and str(item.building).begins_with("way/"))
		verify(item.name+" has authored geometry beyond signage",int(body.get_meta("detail_elements",0))>=20)
		var count:=0
		for child in body.get_children():
			if child is Label3D: sign_text.append(child.text)
			if child is MeshInstance3D and child.name.begins_with("Facade_"):
				count+=1
				var arrays=child.mesh.surface_get_arrays(0)
				var vertices=arrays[Mesh.ARRAY_VERTEX]
				var normals=arrays[Mesh.ARRAY_NORMAL]
				var okay:=true
				for i in range(0,vertices.size(),3):
					if (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).dot(normals[i])>0.0001:okay=false
				verify(item.id+" "+child.name+" outward winding",okay)
		footprints[item.id]=count
	verify("distinct material and geometry compositions",footprints.values().min()<footprints.values().max())
	verify("indoor Exchange tenants not transplanted onto lane",not "Haidilao" in sign_text and not "Bubble Nini" in sign_text)
	var lane_a:=Vector3(-868.93,world.GROUND+1.0,2056.67)
	var lane_b:=Vector3(-797.199,world.GROUND+1.0,2028.707)
	var blocked:=0
	for i in range(81):
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=lane_a.lerp(lane_b,i/80.0)
		if not space.intersect_shape(query).is_empty(): blocked+=1
	verify("81 Steam Mill Lane center walking probes clear",blocked==0)
	if "--capture" in OS.get_cmdline_user_args():
		world._build_structure_batches()
		await capture(world,records)
	var destroyed_id:="darling_square/kuki/frontage"
	world._destroy_component(destroyed_id,Vector3.ZERO,0,false)
	await physics_frame
	var damage_save:Dictionary=world.get_state()
	verify("frontage damage persists with unique shop ID",destroyed_id in damage_save.destroyed and not world.structures[destroyed_id].node.visible)
	world.repair_all()
	world.apply_state(damage_save)
	await physics_frame
	verify("frontage destruction restores from world state",world.destroyed.has(destroyed_id) and not world.structures[destroyed_id].node.visible)
	world.repair_all()
	await physics_frame
	var collision_restored:=false
	for child in world.structures[destroyed_id].node.get_children():
		if child is CollisionShape3D and not child.disabled:collision_restored=true
	verify("repair restores frontage geometry and collision",world.structures[destroyed_id].node.visible and collision_restored)
	var okay:=true
	for check in checks:
		if not check.passed:okay=false
	var file=FileAccess.open(ProjectSettings.globalize_path("res://../reports/darling-square-frontages.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":okay,"checks":checks,"composition_surfaces":footprints,"user_saves_touched":false},"\t"))
	file.close()
	quit(0 if okay else 1)
func capture(world:Node3D,records:Array):
	root.size=Vector2i(1440,900)
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("abc1ca")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("dbe5e5")
	environment.ambient_light_energy=.85
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var env:=WorldEnvironment.new();env.environment=environment;world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-57,-30,0);sun.light_energy=1.5;sun.shadow_enabled=true;world.add_child(sun)
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.far=800;camera.fov=72
	var folder:=ProjectSettings.globalize_path("res://../reports/darling-square-frontages")
	DirAccess.make_dir_recursive_absolute(folder)
	for record in records:
		var normal:=Vector3(record.normal[0],0,record.normal[1])
		var focus:=Vector3(record.front[0],world.GROUND+2.0,record.front[1])
		camera.global_position=focus+normal*5.0+Vector3.UP*.25
		camera.look_at(focus)
		for i in 3:await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(folder+"/"+record.id+".png")
	camera.global_position=Vector3(-791,world.GROUND+2.7,2027)
	camera.look_at(Vector3(-863,world.GROUND+2,2055))
	for i in 3:await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(folder+"/lane.png")
