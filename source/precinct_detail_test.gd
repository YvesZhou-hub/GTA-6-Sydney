extends SceneTree
const Square=preload("res://scripts/darling_square_detail.gd")
const Quay=preload("res://scripts/circular_quay_detail.gd")
const Fronts=preload("res://scripts/darling_square_frontages.gd")
class LocalPrecinct:
	extends "res://scripts/harbor_world.gd"
	func _ready():
		_make_materials()
		map_snapshot=CityMap.data().duplicate()
		map_snapshot.buildings=map_snapshot.buildings.filter(func(b):
			var p:=Vector2(b.center[0],b.center[1])
			return (p.distance_to(Vector2(-770,2020))<155 or p.distance_to(Vector2(70,80))<275) and not int(str(b.id).get_slice("/",1)) in Quay.excluded_way_ids())
		map_snapshot.roads=map_snapshot.roads.filter(func(b):
			for p in b.points:
				if Vector2(p[0]+770,p[1]-2020).length()<200 or Vector2(p[0]-70,p[1]-80).length()<300:return true
			return false)
		CityMap.build_terrain(self,map_snapshot)
		CityMap.build_roads(self,map_snapshot)
		CityMap.build_buildings(self,map_snapshot)
		# Include the existing Exchange model in landscape views; custom ordinary
		# footprints are intentionally suppressed by the production map builder.
		load("res://scripts/city_landmarks.gd")._materials(self)
		load("res://scripts/city_landmarks.gd")._exchange(self)
		Fronts.build(self)
		Square.build(self)
		Quay.build(self)
		_flush_batches()
		_ready_complete=true
var checks:Array=[]
var world:Node3D
var shape:=CapsuleShape3D.new()
func _initialize():call_deferred("run")
func verify(label:String,okay:bool,detail=""):
	checks.append({"name":label,"passed":okay,"detail":detail})
	print("PASS " if okay else "FAIL ",label," ",detail if not okay else "")
func clear_at(at:Vector3) -> bool:
	var q:=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.transform.origin=at+Vector3.UP*1.05
	var hits=world.get_world_3d().direct_space_state.intersect_shape(q)
	if not hits.is_empty():print("BLOCKED ",at," ",hits.map(func(h):return str(h.collider.get_meta("damage_id",h.collider.name))))
	return hits.is_empty()
func support_at(at:Vector3) -> bool:
	var q:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.4,at-Vector3.UP*.35)
	return not world.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
func run():
	shape.radius=.30;shape.height=1.8
	world=LocalPrecinct.new();root.add_child(world)
	await physics_frame;await physics_frame
	verify("READY reached with both mapped precincts",world._ready_complete)
	verify("Original 12 researched Darling frontages retained",Fronts.metadata().size()==12)
	verify("Three added Darling shops",Square.metadata().size()==3)
	verify("Five numbered piers, heritage station and three Quay restaurants",Quay.metadata().size()==9)
	verify("All 28 mapped canopy/kiosk replacements available",Quay.mapped_parts().size()==28)
	var before:int=world.structures.size();Square.build(world);Quay.build(world)
	verify("Both modules idempotent",world.structures.size()==before)
	verify("Mapped station has explicit replacement and raised railway floor",51065527 in Quay.excluded_way_ids() and world.structures.has("circular_quay/station/railway_floor"))
	verify("Station public concourse is open and supported",clear_at(Vector3(13.817,4.5,149.978)) and support_at(Vector3(13.817,4.5,149.978)))
	var base_found:=false
	for id in world.structures:
		if str(id).contains("614603732"):base_found=true
	verify("Three Nicolle shopfronts retain real ground-level host podium",base_found)
	for data in Square.metadata()+Quay.metadata():
		verify(data.id+" mapped anchor equals public arrival",world.anchors.has(data.id) and world.anchors[data.id].is_equal_approx(data.arrival))
		verify(data.id+" 1.8m capsule approach clear",clear_at(data.arrival),str(data.arrival))
		verify(data.id+" arrival has real floor support",support_at(data.arrival),str(data.arrival))
	for old in ["quay/pier/0","quay/pier/1","quay/pier/2","quay/pier/3","quay/pier/4","quay/transit_hall"]:verify("No legacy "+old,not world.structures.has(old))
	for d in Quay.WHARVES:
		var blocked:=0;var unsupported:=0
		for j in 41:
			var p:Vector3=d[1].lerp(d[2],.05+j*.021)
			if not clear_at(p):blocked+=1
			if not support_at(p):unsupported+=1
		verify("Wharf %d continuous 41-point walking route"%d[0],blocked==0 and unsupported==0,"blocked=%d unsupported=%d"%[blocked,unsupported])
	var roof_count:=0;var winding_bad:=0
	for id in world.structures:
		var body:Node3D=world.structures[id].node
		if str(id).begins_with("circular_quay/roof/"):
			roof_count+=1
			verify(str(body.get_meta("source_osm"))+" retained mapped canopy outline",body.get_meta("source_outline").size()>=4)
		if str(id).begins_with("circular_quay/") or str(id).begins_with("darling_detail/") or str(id) in ["darling_square/auvers/frontage","darling_square/hakatamon/frontage","darling_square/chinta_ria/frontage"]:
			for child in body.get_children():
				if child is MeshInstance3D:
					for s in child.mesh.get_surface_count():
						var arr=child.mesh.surface_get_arrays(s);var v=arr[Mesh.ARRAY_VERTEX];var n=arr[Mesh.ARRAY_NORMAL];var ix=arr[Mesh.ARRAY_INDEX]
						for j in range(0,ix.size() if ix!=null and not ix.is_empty() else v.size(),3):
							var a:int=ix[j] if ix!=null and not ix.is_empty() else j
							var b:int=ix[j+1] if ix!=null and not ix.is_empty() else j+1
							var c:int=ix[j+2] if ix!=null and not ix.is_empty() else j+2
							if not v[a].is_finite() or (v[b]-v[a]).cross(v[c]-v[a]).dot(n[a])>.0001:winding_bad+=1
	verify("All authored faces finite with outward winding",winding_bad==0,str(winding_bad))
	verify("14 individual mapped canopy roofs",roof_count==14,str(roof_count))
	for d in Quay.WHARVES:
		var fascia:Node3D=world.structures["circular_quay/wharf/%d/gate_sign"%d[0]].node
		verify("Wharf %d referenced round marker and divided sign"%d[0],fascia.get_meta("photo_details",[]).size()==3)
		# Walk directly between the revised ticket-reader bodies at several
		# offsets, not only along a single zero-width center line.
		var along:Vector3=(d[2]-d[1]).normalized()
		var side:=Vector3(-along.z,0,along.x)
		var clear:=true
		for x in [-.9,0.0,.9]:
			for z in [-.7,0.0,.7]:clear=clear and clear_at(d[1]+side*x+along*z)
		verify("Wharf %d entry remains capsule-clear across 1.8m route"%d[0],clear)
	var decorated_roofs:=0
	for id in world.structures:
		if str(id).begins_with("circular_quay/roof/") and world.structures[id].node.has_meta("soffit_fittings"):decorated_roofs+=1
	verify("All 14 roof soffits retain their individual mapped owner",decorated_roofs==14)
	var okay:=true
	for check in checks:
		if not check.passed:okay=false
	if "--capture" in OS.get_cmdline_user_args():await capture()
	var folder:=ProjectSettings.globalize_path("res://../reports/precinct-detail")
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder+"/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":okay,"checks":checks,"scope":"Local native physics of two true mapped precincts; private shop interiors not modeled","headless":DisplayServer.get_name()=="headless","new_shop_count":6,"retained_darling_shops":12,"wharf_count":5},"\t"))
	quit(0 if okay else 1)
func capture():
	root.size=Vector2i(1440,900)
	world._build_structure_batches()
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("a9bdca");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("d7e1e0");env.ambient_light_energy=.75;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var e:=WorldEnvironment.new();e.environment=env;world.add_child(e)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-52,-30,0);sun.light_energy=1.45;sun.shadow_enabled=true;world.add_child(sun)
	var camera:=Camera3D.new();camera.current=true;camera.far=800;camera.fov=65;world.add_child(camera)
	var views:Array=[]
	for item in Square.metadata()+Quay.metadata():
		if item.has("normal"):
			var n:=Vector3(item.normal[0],0,item.normal[1]);var c:Vector3=item.center+Vector3.UP*2.4
			views.append([item.id,c+n*item.width*.9+Vector3.UP*1.0,c])
	views.append_array([["darling_canopy",Vector3(-770,7.3,2070),Vector3(-777,8.5,2030)],["darling_square",Vector3(-760,22,2057),Vector3(-766,7,2015)],["quay_wharves",Vector3(-85,48,-30),Vector3(58,6,88)],["wharf_3",Vector3(85,6.8,137),Vector3(94,7.4,84)],["quay_station",Vector3(14,15,42),Vector3(14,11,145)]])
	views.append(Quay.capture_views()[0])
	var folder:=ProjectSettings.globalize_path("res://../reports/precinct-detail")
	DirAccess.make_dir_recursive_absolute(folder)
	for v in views:
		camera.position=v[1];camera.look_at(v[2]);await process_frame;await process_frame;RenderingServer.force_draw(false);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/"+v[0]+".png")
