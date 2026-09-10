extends SceneTree
var world
var failures := 0
func _initialize(): call_deferred("run")
func check(label: String, good: bool):
	print("WORLD_DAMAGE ",label," ","PASS" if good else "FAIL")
	if not good: failures += 1
func wall_hit() -> bool:
	var p := Vector3(-340.5,6.9,-19)
	var query := PhysicsRayQueryParameters3D.create(p+Vector3(0,0,3),p-Vector3(0,0,3))
	var excluded: Array[RID] = []
	for node in world.rubble:
		if is_instance_valid(node): excluded.append(node.get_rid())
	query.exclude = excluded
	return not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func vertex_count() -> int:
	var key = world.structures["home/front/-1"].cell
	var mesh = world._visual_cells[key].instance.mesh
	var count := 0
	for s in range(mesh.get_surface_count()): count += mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size()
	return count
func run():
	world = load("res://scripts/harbor_world.gd").new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	check("wall_initially_collides",wall_hit())
	var vertices := vertex_count()
	world.damage_at(Vector3(-340.5,6.9,-19),800000,1.5)
	await physics_frame
	await physics_frame
	check("local_wall_removed",not wall_hit())
	check("local_mesh_vertices_removed",vertex_count()<vertices)
	check("neighbor_front_panel_retained",not world.destroyed.has("home/front/1"))
	var state = world.get_state()
	world.apply_state(state)
	await physics_frame
	await physics_frame
	check("restored_hole_stays_open",not wall_hit())
	check("restored_visual_hole",vertex_count()<vertices)
	check("destroyed_ids_roundtrip",world.get_state().destroyed==state.destroyed)
	world.repair_all()
	await physics_frame
	await physics_frame
	check("repair_restores_collision",wall_hit())
	check("repair_restores_geometry",vertex_count()==vertices)
	var wall = world.structures["home/front/-1"].node
	check("repair_restores_facade_shader",wall.get_child(0).material_override is ShaderMaterial)
	print("WORLD_DAMAGE_COMPLETE failures=",failures)
	quit(failures)
