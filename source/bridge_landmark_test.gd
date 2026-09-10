extends SceneTree
## Probe actual colliders, not an algebraic reimplementation of bridge geometry.
const BRIDGE = preload("res://scripts/bridge_landmark.gd")
var failures := 0
var probes := 0
var obstruction_examples: Array[String] = []

func verify(value: bool, message: String) -> void:
	if value: print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var world = load("res://scripts/harbor_world.gd").new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	verify(world.get_meta("bridge_geometry_version", 0) == 2, "reference-led bridge is integrated")
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var routes := [
		["south approach", BRIDGE.SOUTH_ENTRY, BRIDGE.pos(0)],
		["main span", BRIDGE.pos(0), BRIDGE.pos(BRIDGE.SPAN)],
		["north approach", BRIDGE.pos(BRIDGE.SPAN), BRIDGE.NORTH_ENTRY]
	]
	for route in routes:
		var missing_road := 0
		var blocked_road := 0
		var missing_walk := 0
		var blocked_walk := 0
		var max_floor_error := 0.0
		var a: Vector3 = route[1]
		var b: Vector3 = route[2]
		var basis := BRIDGE.basis_at(a, b)
		var route_length := a.distance_to(b)
		if route[0] == "north approach":
			route_length=0.0
			for segment in range(28): route_length+=BRIDGE.ramp_position("north",float(segment)/28.0).distance_to(BRIDGE.ramp_position("north",float(segment+1)/28.0))
		var count := ceili(route_length / 1.5)
		for i in range(count + 1):
			var fraction := clampf(float(i) / count, 0.001, 0.999)
			var center := a.lerp(b, fraction)
			if route[0] != "main span":
				var label := "south" if route[0] == "south approach" else "north"
				center = BRIDGE.ramp_position(label, fraction)
				basis = BRIDGE.ramp_basis(label, fraction)
			for lane in BRIDGE.ROAD_LANES:
				var at: Vector3 = center + basis.x * lane
				var floor_hit := _floor(space, at)
				if floor_hit.is_empty(): missing_road += 1
				else:
					var error: float = absf((floor_hit.position - at).dot(basis.y))
					if error > 0.06 and obstruction_examples.size() < 10: print("FLOOR_ERROR at=", at, " hit=", floor_hit.position, " normal=", floor_hit.normal, " collider=", floor_hit.collider.name)
					max_floor_error = maxf(max_floor_error, error)
				if not _clear(space, at, basis, Vector3(2.4, 5.5, 1.0), 0.13): blocked_road += 1
			for across in BRIDGE.WALK_X:
				var at: Vector3 = center + basis.x * across + basis.y * 0.24
				var floor_hit := _floor(space, at)
				if floor_hit.is_empty(): missing_walk += 1
				else:
					var error: float = absf((floor_hit.position - at).dot(basis.y))
					if error > 0.06 and obstruction_examples.size() < 10: print("FLOOR_ERROR at=", at, " hit=", floor_hit.position, " normal=", floor_hit.normal, " collider=", floor_hit.collider.name)
					max_floor_error = maxf(max_floor_error, error)
				if not _clear(space, at, basis, Vector3(0.85, 2.0, 0.65), 0.13): blocked_walk += 1
		verify(missing_road == 0, "%s all eight road lanes have continuous ground (%d missing)" % [route[0], missing_road])
		verify(blocked_road == 0, "%s 2.4m vehicle width and 5.5m height are unobstructed (%d blocked)" % [route[0], blocked_road])
		verify(missing_walk == 0, "%s both footways remain continuous (%d missing)" % [route[0], missing_walk])
		verify(blocked_walk == 0, "%s pedestrian/camera envelope remains unobstructed (%d blocked)" % [route[0], blocked_walk])
		verify(max_floor_error < 0.06, "%s collision planes remain flush (max %.4fm)" % [route[0], max_floor_error])
	# Densely sample the two join faces, where opposing cross-sections can leave a
	# wedge-shaped crack invisible in a coarse centreline-only road test.
	for end in [0.0, BRIDGE.SPAN]:
		var gaps := 0
		var collisions := 0
		for longitudinal in range(-20, 21):
			for across in BRIDGE.ROAD_LANES + BRIDGE.WALK_X:
				var at: Vector3 = BRIDGE.pos(end + longitudinal * 0.05, BRIDGE.DECK_Y, across)
				var hit := _floor(space, at)
				if hit.is_empty(): gaps += 1
				elif absf(hit.position.y - BRIDGE.DECK_Y) > 0.7: gaps += 1
				elif not _clear(space, hit.position, BRIDGE.basis_at(BRIDGE.pos(0), BRIDGE.pos(BRIDGE.SPAN)), Vector3(0.65, 2.0, 0.20), 0.14): collisions += 1
		verify(gaps == 0, "dense %.0fm ramp/span join collision continuity (%d gaps)" % [end, gaps])
		verify(collisions == 0, "dense %.0fm ramp/span join body clearance (%d blocked)" % [end, collisions])
	# Ground exits must lead away from each ramp without colliding with a house.
	for route in [[BRIDGE.SOUTH_ENTRY, BRIDGE.SOUTH_EXIT], [BRIDGE.SOUTH_EXIT, Vector3(-310, 4.5, -170)], [BRIDGE.NORTH_ENTRY, BRIDGE.NORTH_EXIT]]:
		var blocked := 0
		var missing := 0
		var a: Vector3 = route[0]
		var b: Vector3 = route[1]
		var basis := BRIDGE.basis_at(a, b)
		for step in range(2, ceili(a.distance_to(b)) + 1):
			for offset in [-8.0, 0.0, 8.0]:
				var at: Vector3 = a + (b - a).normalized() * step + basis.x * offset
				if _floor(space, at).is_empty(): missing += 1
				if not _clear(space, at, basis, Vector3(2.4, 2.5, 1.0), 0.15): blocked += 1
		verify(missing == 0 and blocked == 0, "ground exit %s reaches local streets, missing=%d blocked=%d" % [a, missing, blocked])
	# Continuous support must still break into real holes and restore with saves.
	var deck_station := 20.5 * BRIDGE.SPAN / 42.0
	var deck_probe := BRIDGE.pos(deck_station, BRIDGE.DECK_Y, 2.15)
	var ramp_fraction := 12.5 / 28.0
	var ramp_probe := BRIDGE.ramp_position("north", ramp_fraction) + BRIDGE.ramp_basis("north", ramp_fraction).x * 2.15
	world._destroy_component("bridge/deck/20", deck_probe, 0.0, false)
	for frame in range(3): await physics_frame
	verify(_floor(space, deck_probe).is_empty(), "destroyed bridge deck opens a real collision hole")
	verify(_floor(space, BRIDGE.pos(deck_station, BRIDGE.DECK_Y + 0.24, 23.15)).is_empty(), "destroyed deck removes its continuous footway support")
	verify(not _floor(space, BRIDGE.pos(18.5 * BRIDGE.SPAN / 42.0, BRIDGE.DECK_Y, 2.15)).is_empty(), "neighbouring intact deck retains support")
	world.apply_state({"destroyed": ["bridge/deck/20", "bridge/ramp/north/12"]})
	for frame in range(3): await physics_frame
	verify(_floor(space, deck_probe).is_empty() and _floor(space, ramp_probe).is_empty(), "saved deck and ramp damage rebuild both actual collision holes")
	world.repair_all()
	for frame in range(3): await physics_frame
	verify(not _floor(space, deck_probe).is_empty() and not _floor(space, ramp_probe).is_empty(), "repair restores the complete drive surface")
	verify(world.get_meta("bridge_drive_runs", 0) == 1, "undamaged bridge has one welded continuous support run")
	for example in obstruction_examples: print("OBSTRUCTION ", example)
	if "--capture" in OS.get_cmdline_user_args():
		await _capture(world)
	print("BRIDGE CHECK COMPLETE failures=", failures, " shape_probes=", probes)
	quit(failures)

func _floor(space: PhysicsDirectSpaceState3D, at: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.6, at - Vector3.UP * 1.2))

func _clear(space: PhysicsDirectSpaceState3D, at: Vector3, basis: Basis, size: Vector3, lift: float) -> bool:
	probes += 1
	var shape := BoxShape3D.new()
	shape.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(basis, at + basis.y * (size.y * 0.5 + lift))
	query.margin = 0.015
	var hits := space.intersect_shape(query, 6)
	if not hits.is_empty() and obstruction_examples.size() < 18:
		var names: Array[String] = []
		for hit in hits: names.append(str(hit.collider.name))
		obstruction_examples.append("at=%s size=%s hits=%s" % [at, size, names])
	return hits.is_empty()

func _capture(world: Node3D) -> void:
	root.size = Vector2i(1440, 900)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("93b4ca")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c6d6dd")
	environment.ambient_light_energy = 0.60
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, -35, 0)
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 1200.0
	world.add_child(sun)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 4500.0
	var views := [
		["bridge-profile", Vector3(600, 128, -675), BRIDGE.pos(251.5, 66.0)],
		["bridge-road", BRIDGE.pos(68, 56.2, 2.15), BRIDGE.pos(245, 70, 2.15)],
		["bridge-pylon", BRIDGE.PYLON_CENTERS[1]+Vector3(75,75,45), BRIDGE.PYLON_CENTERS[1]+Vector3.UP*62],
		["bridge-north-exit", Vector3(470,300,-1400), Vector3(170,25,-1370)]
	]
	DirAccess.make_dir_recursive_absolute("res://../reports/bridge-refinement")
	for view in views:
		camera.global_position = view[1]
		camera.look_at(view[2])
		for i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var output: String = "res://../reports/bridge-refinement/%s.png" % view[0]
		root.get_texture().get_image().save_png(output)
		print("CAPTURE ", ProjectSettings.globalize_path(output))
