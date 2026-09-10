extends SceneTree

const Opera = preload("res://scripts/opera_landmark.gd")
var failures := 0

class ProbeWorld extends "res://scripts/harbor_world.gd":
	func _ready() -> void:
		_make_materials()
		Opera.build(self)
		_flush_batches()
		for id in structures:
			for child in structures[id].node.get_children():
				if child is MeshInstance3D: child.set_meta("intact_material",child.material_override)
		_build_structure_batches()
		_ready_complete = true

func verify(value: bool, message: String) -> void:
	if value: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var world := ProbeWorld.new()
	root.add_child(world)
	verify(world.get_meta("opera_shell_pairs",0)==10,"ten roof pairs grouped in two unequal halls and southwest restaurant")
	verify(Opera.CENTER.distance_to(Vector3(427.294774,4.5,-321.454405))<0.001 and absf(Opera.ANGLE+13.232864688)<0.00001,"geographic reference matches mapped Opera House centroid and axis")
	var sphere_error := 0.0
	var mirrored_error := 0.0
	var ridge_gap := 0.0
	var toe_error := 0.0
	var triangle_count := 0
	var reversed_normals := 0
	var degenerate := 0
	var highest := -INF
	for spec: Array in Opera.ROOFS:
		var right := Opera.sphere_patch(spec[2],spec[3],spec[4],1)
		var left := Opera.sphere_patch(spec[2],spec[3],spec[4],-1)
		for u in [0.0,0.17,0.5,0.89,1.0]:
			for v in [0.0,0.21,0.5,0.87,1.0]:
				var rp := Opera.shell_point(right,u,v)
				var lp := Opera.shell_point(left,u,v)
				sphere_error = maxf(sphere_error,absf(rp.distance_to(right.center)-Opera.SPHERE_RADIUS))
				mirrored_error = maxf(mirrored_error,rp.distance_to(Vector3(-lp.x,lp.y,lp.z)))
				if u==0.0: ridge_gap = maxf(ridge_gap,rp.distance_to(lp))
				if u==1.0: toe_error = maxf(toe_error,rp.distance_to(right.c))
	verify(sphere_error<0.00003,"roof samples lie on common 75.2m sphere error="+str(sphere_error))
	verify(mirrored_error<0.00003,"paired shells mirror exactly across sharp central ridge error="+str(mirrored_error))
	verify(ridge_gap<0.00003,"opposing shell halves meet at the same ridge without a longitudinal gap")
	verify(toe_error<0.00003,"all shell feet meet their podium springing points")
	var shell_ids: Array = []
	for id: String in world.structures:
		if not id.begins_with("opera/shell/"): continue
		shell_ids.append(id)
		var body: StaticBody3D = world.structures[id].node
		var mesh: ArrayMesh = body.get_child(0).mesh
		var arrays := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		triangle_count += verts.size()/3
		for i in range(0,verts.size(),3):
			var cross := (verts[i+1]-verts[i]).cross(verts[i+2]-verts[i])
			if cross.length_squared()<0.00000001: degenerate += 1
			if cross.dot(normals[i]+normals[i+1]+normals[i+2])>0.0001: reversed_normals += 1
		for point in verts:
			highest = maxf(highest,(body.transform*point).y)
	verify(shell_ids.size()==160,"160 independently removable thick spherical shell bands")
	verify(triangle_count>30000 and triangle_count<100000,"curved roof triangle budget="+str(triangle_count))
	verify(degenerate==0,"no degenerate shell faces")
	verify(reversed_normals==0,"all shell outer, inner and edge triangles face their supplied normals")
	var boundary_edges := 0
	for side in [-1,1]:
		var surface := Opera.sphere_patch(25.2,68.0,50.15,side)
		for band in [0,7]:
			var mesh := Opera.shell_mesh(surface,float(band)/8.0,float(band+1)/8.0)
			var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var edges: Dictionary = {}
			var bins: Dictionary = {}
			var welded: Array[Vector3] = []
			var indices: Array[int] = []
			for point in points: indices.append(weld_index(point,bins,welded))
			for i in range(0,points.size(),3):
				for e in range(3):
					var a := indices[i+e]
					var b := indices[i+(e+1)%3]
					var key := Vector2i(mini(a,b),maxi(a,b))
					edges[key] = edges.get(key,0)+1
			for key: Vector2i in edges:
				if edges[key]!=2:
					boundary_edges+=1
	verify(boundary_edges==0,"ridge and springing-point chunks are closed two-manifold solids nonmanifold="+str(boundary_edges))
	verify(highest>=66.9 and highest<68.0,"roof silhouette reaches approximately 67m above water high="+str(highest))
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var hits := 0
	var inner_hits := 0
	var expected := 0
	for index in range(Opera.ROOFS.size()):
		var spec: Array = Opera.ROOFS[index]
		var surface := Opera.sphere_patch(spec[2],spec[3],spec[4],1)
		var basis := Opera.site_basis()*Basis(Vector3.UP,deg_to_rad(spec[5]))
		var origin := Opera.CENTER+Opera.site_basis()*Vector3(spec[0],Opera.PODIUM_HEIGHT,spec[1])
		var sample := Opera.shell_point(surface,0.46,0.55)
		var normal: Vector3 = (sample-surface.center).normalized()
		var at := origin+basis*sample
		var outward := basis*normal
		var query := PhysicsRayQueryParameters3D.create(at+outward*0.15,at-outward*0.15)
		var hit := space.intersect_ray(query)
		expected += 1
		if not hit.is_empty() and str(hit.collider.get_meta("damage_id","")).begins_with("opera/shell/") and hit.position.distance_to(at)<0.05: hits += 1
		var inner_query := PhysicsRayQueryParameters3D.create(at-outward*0.55,at-outward*0.2)
		var inner_hit := space.intersect_ray(inner_query)
		if not inner_hit.is_empty() and str(inner_hit.collider.get_meta("damage_id","")).begins_with("opera/shell/") and absf(inner_hit.position.distance_to(at)-Opera.SHELL_THICKNESS)<0.05: inner_hits += 1
	verify(hits==expected,"roof colliders follow visible spherical skin hits=%s/%s"%[hits,expected])
	verify(inner_hits==expected,"roof interior has collision at actual 320mm thickness hits=%s/%s"%[inner_hits,expected])
	var stairs := 0
	for step in range(48):
		var at := Opera.CENTER+Opera.site_basis()*Vector3(0,20,95.45-step*0.62)
		var query := PhysicsRayQueryParameters3D.create(at,at-Vector3.UP*25)
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and str(hit.collider.get_meta("damage_id","")).begins_with("opera/steps/"): stairs += 1
	verify(stairs==48,"whole monumental stair route has smooth physical support")
	var destroyed_id: String = shell_ids[37]
	world._destroy_component(destroyed_id,Vector3.ZERO,0,false)
	await physics_frame
	verify(world.destroyed.has(destroyed_id) and not world.structures[destroyed_id].node.visible and world.structures[destroyed_id].node.get_child(1).disabled,"shell damage removes matching roof, ribs and collider")
	world.apply_state({})
	await physics_frame
	verify(not world.destroyed.has(destroyed_id) and not world.structures[destroyed_id].node.get_child(1).disabled,"new world restores damaged roof collider")
	if "--visual" in OS.get_cmdline_user_args():
		await capture(world)
	print("OPERA CHECK COMPLETE failures=",failures," shell_triangles=",triangle_count)
	quit(failures)

func weld_index(point: Vector3, bins: Dictionary, welded: Array[Vector3]) -> int:
	var cell := Vector3i((point*1000.0).floor())
	for x in range(-1,2):
		for y in range(-1,2):
			for z in range(-1,2):
				for index: int in bins.get(cell+Vector3i(x,y,z),[]):
					if point.distance_to(welded[index])<0.00005: return index
	var index := welded.size()
	welded.append(point)
	if not bins.has(cell): bins[cell] = []
	bins[cell].append(index)
	return index

func capture(world: Node3D) -> void:
	root.size = Vector2i(1440,900)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8ab9ce")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bfd4dc")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-35,0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	world.add_child(sun)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 50
	camera.far = 2000
	var views := {"northwest":Vector3(235,40,-500),"aerial":Vector3(421,270,-222),"steps":Vector3(440,8,-174),"tiles":Vector3(391,70,-345)}
	DirAccess.make_dir_recursive_absolute("/tmp/harbourlife-opera-review")
	for label: String in views:
		camera.position = views[label]
		camera.look_at(Opera.CENTER+Vector3(0,25,0))
		for i in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/harbourlife-opera-review/"+label+".png")
