extends SceneTree
const Tower=preload("res://scripts/sydney_tower_landmark.gd")
class TowerWorld extends "res://scripts/harbor_world.gd":
	func _ready()->void:
		_make_materials()
		_box(self,Tower.CENTER-Vector3.UP*0.3,Vector3(500,0.6,500),"paving",true)
		Tower.build(self)
		for part in structures.values():
			for child in part.node.get_children():
				if child is MeshInstance3D:child.set_meta("intact_material",child.material_override)
		_flush_batches()
		_build_structure_batches()
var failures:=0
var count:=0
func verify(ok:bool,label:String)->void:
	count+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error(label)
func batched_vertices(w:Node3D,material:Material)->int:
	var total:=0
	for cell:Dictionary in w._visual_cells.values():
		var mesh:ArrayMesh=cell.instance.mesh
		if mesh==null:continue
		for surface in mesh.get_surface_count():
			if mesh.surface_get_material(surface)!=material:continue
			# Cell batches are indexed; count drawn corners so the result matches get_faces().
			var corners:=mesh.surface_get_array_index_len(surface)
			total+=corners if corners>0 else mesh.surface_get_array_len(surface)
	return total
func _initialize()->void:call_deferred("run")
func run()->void:
	var w:=TowerWorld.new();root.add_child(w)
	await physics_frame;await physics_frame
	verify(w.has_meta("sydney_tower_landmark"),"Sydney Tower model builds with canonical metadata")
	var n:=w.structures.size();Tower.build(w);verify(n==w.structures.size(),"Tower build is idempotent")
	var expected_ids:Array[String]=["anchor_ring","turret_underside","turret_roof","upper_drum","plant","spire/lower","spire/upper","beacon"]
	for i in 12:expected_ids.append("base/%02d"%i)
	for i in 9:expected_ids.append("shaft/%02d"%i)
	for i in 4:expected_ids.append("turret/%02d"%i)
	var ids_match:=n==expected_ids.size()
	for id in expected_ids:ids_match=ids_match and w.structures.has("sydney_tower/"+id)
	verify(ids_match,"all 33 pre-existing damage IDs survive the detail revision")
	verify(Tower.excluded_way_ids()==[197801072,197801073,197801074,273960049],"four source OSM pieces are replaced; surrounding mall not suppressed")
	var m:Dictionary=Tower.metadata()[0]
	verify((Vector3((m.lon-151.2105)*92400,4.5,(-33.86-m.lat)*111320)-Tower.CENTER).length()<0.002,"Tower centroid projects to mapped OSM turret center")
	verify(not Geometry2D.is_point_in_polygon(Vector2(Tower.ARRIVAL.x,Tower.ARRIVAL.z),Tower.footprints()[0]),"Market Street arrival lies outside office footprint")
	var degenerate:=0;var reversed:=0;var triangles:=0;var max_y:=-INF;var collision_mismatch:=0
	for part in w.structures.values():
		var body:StaticBody3D=part.node
		for child in body.get_children():
			if not child is MeshInstance3D:continue
			for surface in child.mesh.get_surface_count():
				var ar:Array=child.mesh.surface_get_arrays(surface);var vs:PackedVector3Array=ar[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=ar[Mesh.ARRAY_NORMAL]
				var ix:PackedInt32Array=ar[Mesh.ARRAY_INDEX] if ar[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				for v in vs:max_y=maxf(max_y,v.y)
				var num:=ix.size() if not ix.is_empty() else vs.size();triangles+=num/3
				for i in range(0,num,3):
					var a:=ix[i] if not ix.is_empty() else i;var b:=ix[i+1] if not ix.is_empty() else i+1;var c:=ix[i+2] if not ix.is_empty() else i+2
					var cross:=(vs[b]-vs[a]).cross(vs[c]-vs[a])
					if cross.length_squared()<0.00000000001:degenerate+=1
					if cross.dot(normals[a]+normals[b]+normals[c])>0.00001:reversed+=1
		var collider:CollisionShape3D=body.get_child(1)
		if collider.shape is ConcavePolygonShape3D and collider.shape.get_faces()!=body.get_child(0).mesh.get_faces():collision_mismatch+=1
	verify(degenerate==0,"all tower geometry triangles are nondegenerate")
	verify(reversed==0,"tower winding matches exterior normals")
	verify(collision_mismatch==0,"damage solids and physics geometry match")
	verify(absf(max_y-309.0)<0.002,"modeled navigation beacon tops out at official 309m")
	verify(w.get_meta("sydney_tower_geometry").cables==56,"two families contain the documented 56 visible stabilising cables")
	var window_panels:=0
	for i in 4:window_panels+=w.structures["sydney_tower/turret/%02d"%i].node.get_node("TurretWindowPanels").mesh.get_faces().size()/36
	verify(window_panels==420,"turret has 420 distinct modeled window panels")
	var drum:StaticBody3D=w.structures["sydney_tower/upper_drum"].node
	var gallery:MeshInstance3D=drum.get_node("SkywalkGalleryDecks")
	var glass:MeshInstance3D=drum.get_node("SkywalkGlassPlatforms")
	var frame:MeshInstance3D=drum.get_node("SkywalkPlatformFrames")
	var clusters:=[0,0];var stray_floor_vertices:=0
	for point in glass.mesh.get_faces():
		if point.y>Tower.SKYWALK_Y+0.001:continue
		var angle:=atan2(point.z,point.x);var cluster:=-1
		for i in Tower.SKYWALK_PLATFORM_ANGLES.size():
			if absf(wrapf(angle-deg_to_rad(Tower.SKYWALK_PLATFORM_ANGLES[i]),-PI,PI))<0.28:cluster=i
		if cluster<0 or Vector2(point.x,point.z).length()<10.4:stray_floor_vertices+=1
		else:clusters[cluster]+=1
	verify(clusters[0]>0 and clusters[0]==clusters[1] and stray_floor_vertices==0,"glass floor geometry forms two discrete rectangular outward platforms")
	verify(absf(gallery.mesh.get_aabb().end.y-268.0)<0.001 and gallery.mesh.get_aabb().position.y<266.0,"two stacked galleries include the official 268m visitor level")
	verify(frame.mesh.get_aabb().position.y<264.6 and frame.mesh.get_aabb().end.y>267.9,"platform support geometry connects the turret roof to the deck frames")
	var top:StaticBody3D=w.structures["sydney_tower/turret_roof"].node
	verify(top.has_node("RoofRadialRibsAndTrack") and top.has_node("RoofPerimeterGuard") and top.has_node("RoofGlassParapet"),"roof carries radial ribs, cleaning track and separate parapet geometry")
	var plant:StaticBody3D=w.structures["sydney_tower/plant"].node
	verify(plant.has_node("PlantVerticalSlots") and plant.has_node("PlantRailsAndSafetyHoops"),"upper plant enclosure has modeled slots and safety hoops")
	verify(w.structures["sydney_tower/base/01"].color=="sydney_tower_podium" and w.structures["sydney_tower/base/02"].color=="sydney_tower_office","retail podium is distinct from the ten office facade bands")
	verify(drum.has_node("RaisedCurvedLettering") and drum.get_node("RaisedCurvedLettering").mesh.get_aabb().size.y>4.0,"raised Westfield letters follow the drum in physical geometry")
	verify(Tower.capture_views().size()==3 and Tower.capture_views()[1][1].y>Tower.CENTER.y+268,"three native capture views include an elevated Skywalk close-up")
	verify(triangles<130000,"tower detail remains within triangle budget: "+str(triangles))
	var space:=w.get_world_3d().direct_space_state
	for y in [100.0,220.0,243.0,275.0]:
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Tower.CENTER+Vector3(50,y,0),Tower.CENTER+Vector3(0,y,0)))
		verify(not hit.is_empty(),"tower physical shell exists at height "+str(y))
	var q:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=0.34;capsule.height=1.8;q.shape=capsule;q.transform.origin=Tower.ARRIVAL+Vector3.UP*1.02
	verify(space.intersect_shape(q).is_empty(),"public arrival fits standing pedestrian")
	var id:="sydney_tower/turret/02";w._destroy_component(id,Vector3.ZERO,0,false);await physics_frame
	verify(w.destroyed.has(id) and w.structures[id].node.get_child(1).disabled,"turret damage removes the corresponding solid and attached window detail")
	w.apply_state({});await physics_frame
	verify(not w.structures[id].node.get_child(1).disabled,"repair restores tower collision")
	var glass_material:Material=w.materials.sydney_tower_platform_glass
	var intact_glass_vertices:=batched_vertices(w,glass_material)
	w._destroy_component("sydney_tower/upper_drum",Vector3.ZERO,0,false);await physics_frame;await physics_frame
	verify(w.destroyed.has("sydney_tower/upper_drum") and intact_glass_vertices-batched_vertices(w,glass_material)==glass.mesh.get_faces().size(),"destroying the existing drum ID removes precisely the platform glass from rendered batches")
	w.apply_state({});await physics_frame;await physics_frame
	verify(not drum.get_child(1).disabled and batched_vertices(w,glass_material)==intact_glass_vertices,"drum repair restores collision and all platform glazing in rendered batches")
	if "--capture" in OS.get_cmdline_user_args():await capture(w)
	print("SYDNEY TOWER CHECK COMPLETE checks=",count," failures=",failures," triangles=",triangles," structures=",n)
	quit(failures)
func capture(w:Node3D)->void:
	root.size=Vector2i(1440,1000)
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("96bacd");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("d3e2e8");env.ambient_light_energy=0.67;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var e:=WorldEnvironment.new();e.environment=env;w.add_child(e)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.2;sun.shadow_enabled=true;w.add_child(sun)
	var cam:=Camera3D.new();w.add_child(cam);cam.current=true;cam.far=1800;cam.fov=45
	var folder:=ProjectSettings.globalize_path("res://../reports/sydney-tower-v016");DirAccess.make_dir_recursive_absolute(folder)
	for row:Array in [["whole",Vector3(-295,167,375),Vector3(0,150,0)],["turret",Vector3(-55,282,88),Vector3(0,265,0)],["cable_net",Vector3(-50,140,100),Vector3(0,163,0)],["street",Vector3(-90,4,110),Vector3(-6,59,0)],["base_aerial",Vector3(-110,96,90),Vector3(-6,34,0)]]:
		cam.position=Tower.CENTER+row[1];cam.look_at(Tower.CENTER+row[2])
		for i in 7:await process_frame
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png(folder+"/"+row[0]+".png");print("TOWER FRAME ",row[0])
