extends RefCounted
## Original, reference-led Sydney Harbour Bridge geometry; dimensions in metres.
## Photographs are references only. See docs/BRIDGE_REFERENCE.md.

const SPAN := 503.0
const DECK_Y := 54.0
const WIDTH := 49.0
const ARCH_X := 15.0
const PANELS := 28
const SOUTH_ENTRY := Vector3(-325.70848036, 4.5, -194.3677124)
const NORTH_ENTRY := Vector3(353.49108752, 4.5, -1502.99791431)
const SOUTH_EXIT := Vector3(-336.75, 4.5, -173.06)
const ROAD_LANES := [-10.8, -6.5, -2.15, 2.15, 6.5, 10.8, 17.65, 20.55]
const WALK_X := [-23.15, 23.15]

static func pos(t: float, y: float = DECK_Y, across: float = 0.0) -> Vector3:
	var direction := Vector3(232, 0, -447).normalized()
	return Vector3(-83, y, -662) + direction * t + Vector3(-direction.z, 0, direction.x) * across

static func basis_at(a: Vector3, b: Vector3) -> Basis:
	return Basis.looking_at((b - a).normalized(), Vector3.UP)

static func build(world: Node3D) -> void:
	_make_materials(world)
	var basis := basis_at(pos(0), pos(SPAN))
	# Save-compatible deck IDs; decoration belongs to its removable deck component.
	for i in range(42):
		_deck_piece(world, "bridge/deck/%02d" % i, pos((i + 0.5) * SPAN / 42.0), basis, SPAN / 42.0, 5.0, true)
	_arch(world)
	for end in [0.0, SPAN]:
		for side in [-1, 1]:
			_pylon(world, end, side, basis)
	_ramp(world, SOUTH_ENTRY, pos(0), "south")
	_ramp(world, pos(SPAN), NORTH_ENTRY, "north")
	# Broad ground connections meet all road lanes. Both footways reach ground.
	world._road(SOUTH_ENTRY + Vector3.UP * 0.09, SOUTH_EXIT + Vector3.UP * 0.09, WIDTH)
	world._road(SOUTH_EXIT + Vector3.UP * 0.09, Vector3(-310, 4.59, -170), WIDTH)
	world._road(NORTH_ENTRY + Vector3.UP * 0.09, Vector3(370, 4.59, -1580), WIDTH)
	for station in range(18, 490, 36):
		_lamp(world, pos(station, DECK_Y, 23.95), basis)
		_lamp(world, pos(station, DECK_Y, -23.95), basis)
	_summit(world, basis)
	refresh_drive_collision(world)
	world.set_meta("bridge_geometry_version", 2)
	world.set_meta("bridge_min_road_clearance", 6.2)

static func _make_materials(world: Node3D) -> void:
	world._mat("bridge_steel", Color("4e5558"), 0.66, 0.60)
	world._mat("bridge_edge", Color("646c6d"), 0.55, 0.68)
	world._mat("bridge_rivet", Color("737c7d"), 0.50, 0.70)
	world._mat("bridge_granite", Color("95998e"), 0.96)
	world._mat("bridge_coping", Color("b0b2a6"), 0.94)
	world._mat("bridge_recess", Color("343d3e"), 0.97)
	world._mat("bridge_ballast", Color("747770"), 1.0)
	world._mat("bridge_signal", Color("79d293"), 0.6)
	# Deterministic original granite block pattern; no photographic textures bundled.
	var granite: StandardMaterial3D = world.materials["bridge_granite"]
	granite.albedo_texture = world._surface_texture("sandstone")
	granite.uv1_triplanar = true
	granite.uv1_scale = Vector3(0.28, 0.20, 0.28)
	var signal_mat: StandardMaterial3D = world.materials["bridge_signal"]
	signal_mat.emission_enabled = true
	signal_mat.emission = Color("79d293")
	signal_mat.emission_energy_multiplier = 0.7

static func _deck_piece(world: Node3D, id: String, surface: Vector3, basis: Basis, length: float, depth: float, span_piece: bool) -> void:
	# Exact top planes and a tiny longitudinal overlap avoid tilted lip steps.
	var deck: StaticBody3D = world._structure_box(id, surface - basis.y * depth * 0.5, Vector3(WIDTH, depth, length + 0.08), "bridge_steel" if span_piece else "concrete", 2800000.0, basis)
	# Continuous long support boxes below provide floors. Per-piece box end faces
	# catch spherical wheels even when the visible top planes are coplanar.
	var original_floor: CollisionShape3D = deck.get_child(1)
	deck.remove_child(original_floor)
	original_floor.free()
	var top := depth * 0.5
	world._box(deck, Vector3(4.1, top + 0.026, 0), Vector3(35.3, 0.052, length + 0.015), "road")
	# A protected median makes the eastern arch visibly separate from the lanes.
	world._box(deck, Vector3(15.0, top + 0.10, 0), Vector3(2.65, 0.20, length + 0.08), "concrete")
	world._extra_box_collision(deck, Vector3(15.0, top + 0.10, 0), Vector3(2.65, 0.20, length + 0.08))
	for edge in [13.52, 16.48]:
		world._box(deck, Vector3(edge, top + 0.060, 0), Vector3(0.12, 0.01, length), "yellow")
	# Two railway tracks on the western side; six road lanes lie between the arches, with two more on the east.
	world._box(deck, Vector3(-19.0, top + 0.032, 0), Vector3(5.9, 0.064, length), "bridge_ballast")
	for track in [-20.6, -17.5]:
		for rail in [-0.7175, 0.7175]:
			world._box(deck, Vector3(track + rail, top + 0.17, 0), Vector3(0.09, 0.15, length + 0.01), "bridge_edge")
		for sleeper in range(0, int(length), 2):
			world._box(deck, Vector3(track, top + 0.078, sleeper - length * 0.5 + 0.5), Vector3(2.6, 0.10, 0.26), "wood")
	# Raised walk/cycle paths have matching actual colliders on bridge AND approaches.
	for side in [-1, 1]:
		world._box(deck, Vector3(side * 23.15, top + 0.12, 0), Vector3(2.2, 0.24, length + 0.08), "paving")
		world._box(deck, Vector3(side * 24.32, top + 0.8, 0), Vector3(0.16, 1.60, length), "bridge_steel")
		world._extra_box_collision(deck, Vector3(side * 24.32, top + 0.8, 0), Vector3(0.16, 1.60, length + 0.08))
		for wire in range(5):
			world._box(deck, Vector3(side * 24.24, top + 1.65 + wire * 0.15, 0), Vector3(0.04, 0.035, length), "bridge_edge")
		world._box(deck, Vector3(side * 24.24, top + 2.32, 0), Vector3(0.16, 0.12, length), "bridge_edge")
		for post in range(0, int(length), 3):
			world._box(deck, Vector3(side * 24.24, top + 1.2, post - length * 0.5 + 0.7), Vector3(0.13, 2.4, 0.13), "bridge_edge")
		# Narrow separators stay outside drivable road and the 2.2m wide paths.
		world._box(deck, Vector3(side * 21.95, top + 0.60, 0), Vector3(0.28, 1.2, length), "bridge_steel")
		world._extra_box_collision(deck, Vector3(side * 21.95, top + 0.60, 0), Vector3(0.28, 1.2, length + 0.08))
	world._box(deck, Vector3(-13.63, top + 0.62, 0), Vector3(0.28, 1.24, length), "bridge_steel")
	world._extra_box_collision(deck, Vector3(-13.63, top + 0.62, 0), Vector3(0.28, 1.24, length + 0.08))
	for lane_edge in [-8.65, -4.325, 0.0, 4.325, 8.65, 19.1]:
		world._box(deck, Vector3(lane_edge, top + 0.057, 0), Vector3(0.10, 0.010, minf(4.2, length * 0.45)), "white")
	for edge in [-13.30, 13.30, 16.2, 21.85]:
		world._box(deck, Vector3(edge, top + 0.057, 0), Vector3(0.14, 0.010, length), "white")
	if span_piece:
		# Floor beams are under the carriageway, never suspended at wheel height.
		world._box(deck, Vector3(0, -depth * 0.5 + 0.6, 0), Vector3(48.0, 1.20, 0.60), "bridge_edge")
		for across in [-18.0, -10.0, 0.0, 10.0, 18.0]:
			world._box(deck, Vector3(across, -depth * 0.5 + 0.45, 0), Vector3(0.38, 0.90, length), "bridge_edge")

static func _lower(u: float) -> float:
	return 6.0 + 108.9 * maxf(0.0, 4.0 * u * (1.0 - u))

static func _upper(u: float) -> float:
	return 63.0 + 69.9 * maxf(0.0, 4.0 * u * (1.0 - u))

static func _arch(world: Node3D) -> void:
	for j in range(PANELS):
		var a := float(j) / PANELS
		var b := float(j + 1) / PANELS
		var la := _lower(a)
		var lb := _lower(b)
		var ua := _upper(a)
		var ub := _upper(b)
		for side in [-1, 1]:
			var x: float = side * ARCH_X
			var p1 := pos(a * SPAN, la, x)
			var p2 := pos(b * SPAN, lb, x)
			var p3 := pos(a * SPAN, ua, x)
			var p4 := pos(b * SPAN, ub, x)
			_member(world, "bridge/arch/%s/%s/lower" % [side, j], p1, p2, 2.20, 1200000, true)
			_member(world, "bridge/arch/%s/%s/upper" % [side, j], p3, p4, 2.10, 1200000, true)
			# Pratt-like diagonals switch direction at midspan; no X drawn through the road.
			_member(world, "bridge/arch/%s/%s/diag" % [side, j], p1 if j < 14 else p3, p4 if j < 14 else p2, 1.05, 650000, true)
			if j < PANELS:
				_member(world, "bridge/arch/%s/%s/upright" % [side, j], p2, p4, 0.95, 650000, true)
			if lb > DECK_Y + 1.6 and j < PANELS - 1:
				_member(world, "bridge/hanger/%s/%s" % [side, j], pos(b * SPAN, DECK_Y - 2.3, x), p2, 0.64, 420000, true)
			# Articulated bearing and granite bed at each springing.
			if j == 0 or j == PANELS - 1:
				var station := 0.0 if j == 0 else SPAN
				world._structure_box("bridge/bearing/%s/%s" % [side, j], pos(station, 4.5, x), Vector3(5.6, 3.0, 8.0), "bridge_granite", 2200000)
				if j == 0:
					_member(world, "bridge/arch/%s/endpost" % side, pos(0, _lower(0), x), pos(0, _upper(0), x), 1.2, 950000, true)
		# Lateral wind bracing is restricted to a safe volume. Near-end panels used
		# to cross the 54m road; those panels now have only their side arch members.
		if minf(ua, ub) - 0.50 >= DECK_Y + 6.2:
			_member(world, "bridge/wind/%s/a" % j, pos(a * SPAN, ua, -ARCH_X), pos(b * SPAN, ub, ARCH_X), 0.65, 550000)
			_member(world, "bridge/wind/%s/b" % j, pos(a * SPAN, ua, ARCH_X), pos(b * SPAN, ub, -ARCH_X), 0.65, 550000)
			_member(world, "bridge/wind/%s/transverse" % j, pos(a * SPAN, ua, -ARCH_X), pos(a * SPAN, ua, ARCH_X), 0.75, 550000)
		if j > 2 and j < PANELS - 3:
			# Deck-level side lattice creates the recognisable lower horizontal ribbon.
			for side in [-1, 1]:
				_member(world, "bridge/under/%s/%s" % [side, j], pos(a * SPAN, 49.2, side * 23.0), pos(b * SPAN, 49.2, side * 23.0), 0.50, 550000)
	for station in [54.0, 198.0, 342.0, 450.0]:
		# Lane-control gantries remain more than 6.2m above road and use narrow side legs.
		var frame := _member(world, "bridge/gantry/%s" % int(station), pos(station, 62.0, -13.3), pos(station, 62.0, 21.5), 0.45, 250000)
		for lane in ROAD_LANES:
			var at := pos(station, 61.4, lane)
			var local := frame.to_local(at)
			world._box(frame, local, Vector3(0.72, 0.10, 0.72), "bridge_recess")
			# Each hanging signal is above the guaranteed clearance envelope.
			world._box(frame, local + Vector3(0, -0.075, 0), Vector3(0.22, 0.08, 0.38), "bridge_signal")

static func _member(world: Node3D, id: String, a: Vector3, b: Vector3, width: float, strength: float, detail: bool = false) -> StaticBody3D:
	var delta := b - a
	if delta.length() < 0.05:
		return null
	var basis := Basis.looking_at(delta.normalized(), Vector3.UP if absf(delta.normalized().y) < 0.98 else Vector3.RIGHT)
	var body: StaticBody3D = world._structure_box(id, (a + b) * 0.5, Vector3(width, width, delta.length() + 0.08), "bridge_steel", strength, basis)
	if detail:
		# Flange strips, splice plates and rivet heads are part of the same damage
		# component and ultimately merged into spatial batches by harbor_world.
		for side in [-1, 1]:
			world._box(body, Vector3(side * width * 0.48, 0, 0), Vector3(width * 0.12, width * 1.10, delta.length()), "bridge_edge")
		for end in [-1, 1]:
			var z: float = end * maxf(0.0, delta.length() * 0.5 - 0.8)
			world._box(body, Vector3(0, 0, z), Vector3(width * 1.15, width * 1.14, minf(1.6, delta.length())), "bridge_edge")
			for face in [-1, 1]:
				for rivet in [-0.4, 0.0, 0.4]:
					world._box(body, Vector3(face * width * 0.60, rivet * width, z), Vector3(0.11, 0.11, 0.11), "bridge_rivet")
	return body

static func ramp_position(label: String, fraction: float) -> Vector3:
	var start := SOUTH_ENTRY if label == "south" else pos(SPAN)
	var end := pos(0) if label == "south" else NORTH_ENTRY
	return start.lerp(end, clampf(fraction, 0.0, 1.0))

static func ramp_basis(label: String, _fraction: float) -> Basis:
	var start := SOUTH_ENTRY if label == "south" else pos(SPAN)
	var end := pos(0) if label == "south" else NORTH_ENTRY
	return basis_at(start, end)

static func _ramp(world: Node3D, _a: Vector3, _b: Vector3, label: String) -> void:
	# Collinear approaches share the exact span transverse direction. The small
	# ground-end correction removes both outer-lane wedge cracks and wheel snags
	# at angled support joins; the surveyed arch endpoints remain unchanged.
	for i in range(28):
		var a := ramp_position(label, float(i) / 28.0)
		var b := ramp_position(label, float(i + 1) / 28.0)
		var p := (a + b) * 0.5
		var basis := Basis.looking_at((b - a).normalized(), ramp_basis(label, (i + 0.5) / 28.0).y)
		_deck_piece(world, "bridge/ramp/%s/%s" % [label, i], p, basis, a.distance_to(b), 2.0, false)
		if minf(a.y, b.y) > 14.0:
			for side in [-1, 1]:
				var lower_a: Vector3 = a + basis.x * side * ARCH_X - Vector3.UP * 7.0
				var lower_b: Vector3 = b + basis.x * side * ARCH_X - Vector3.UP * 7.0
				var upper_b: Vector3 = b + basis.x * side * ARCH_X - Vector3.UP * 2.0
				_member(world, "bridge/approach_truss/%s/%s/%s/lower" % [label, side, i], lower_a, lower_b, 0.5, 500000)
				_member(world, "bridge/approach_truss/%s/%s/%s/diagonal" % [label, side, i], lower_a, upper_b, 0.38, 450000)
				_member(world, "bridge/approach_truss/%s/%s/%s/upright" % [label, side, i], lower_b, upper_b, 0.40, 450000)
		if i % 5 == 3 and p.y > 12.0:
			for side in [-1, 1]:
				var support_top := p.y - 2.2
				world._structure_box("bridge/support/%s/%s/%s" % [label, i, side], Vector3(p.x, (support_top + 4.5) * 0.5, p.z) + basis.x * side * 18.0, Vector3(4.0, support_top - 4.5, 6.0), "bridge_granite", 3200000, Basis(Vector3.UP, basis.get_euler().y))
		if i % 4 == 0:
			for side in [-1, 1]:
				_lamp(world, p + basis.x * side * 23.95, basis)

static func _pylon(world: Node3D, station: float, side: int, basis: Basis) -> void:
	var center := pos(station, 0, side * 36.0)
	var prefix := "bridge/pylon/%s/%s" % [int(station), side]
	# Tapered, granite-faced concrete pylons. Their flat, restrained crown and
	# single large arched opening follow the Destination NSW close-up reference.
	var base: StaticBody3D = world._structure_mesh(prefix + "/0", _taper_mesh(world, Vector2(22.6, 29.0), Vector2(21.0, 26.5), 13.5), center + Vector3.UP * 11.25, "bridge_granite", 3600000, basis)
	world._box(base, Vector3(0, 6.45, 0), Vector3(21.5, 0.6, 27.0), "bridge_coping")
	var main: StaticBody3D = world._structure_mesh(prefix + "/1", _taper_mesh(world, Vector2(21.0, 26.5), Vector2(16.7, 21.9), 53.0), center + Vector3.UP * 44.5, "bridge_granite", 3600000, basis)
	var upper: StaticBody3D = world._structure_mesh(prefix + "/2", _taper_mesh(world, Vector2(16.7, 21.9), Vector2(15.4, 20.5), 14.0), center + Vector3.UP * 78.0, "bridge_granite", 3600000, basis)
	var cornice: StaticBody3D = world._structure_box(prefix + "/3", center + Vector3.UP * 85.8, Vector3(16.0, 1.6, 21.1), "bridge_coping", 2200000, basis)
	for face in [-1, 1]:
		# Pylon face has a single recessed round-headed window with a balcony,
		# narrow slits above and below, and projecting corner pilasters.
		_window(world, main, Vector3(0, 17.4, face * 12.03), face)
		world._box(main, Vector3(0, 11.8, face * 12.8), Vector3(7.6, 0.85, 2.1), "bridge_coping")
		world._box(main, Vector3(0, 13.0, face * 13.6), Vector3(7.6, 1.55, 0.35), "bridge_granite")
		for slit in [-1.35, 1.35]:
			world._box(main, Vector3(slit, -5.5, face * 12.8), Vector3(0.65, 6.2, 0.12), "bridge_recess")
			world._box(upper, Vector3(slit, -0.2, face * 10.9), Vector3(0.62, 6.6, 0.12), "bridge_recess")
		for edge in [-1, 1]:
			world._local_beam(main, Vector3(edge * 9.8, -26.5, face * 13.1), Vector3(edge * 7.65, 26.5, face * 10.8), 0.46, "bridge_coping")
			world._local_beam(upper, Vector3(edge * 7.65, -7.0, face * 10.8), Vector3(edge * 7.0, 7.0, face * 10.2), 0.38, "bridge_coping")
		# Two smaller round-headed side apertures, safely outside the carriageway.
		for longitudinal in [-5.3, 5.3]:
			world._box(main, Vector3(face * 9.0, 14.0, longitudinal), Vector3(0.12, 5.0, 1.8), "bridge_recess")
	# Low lookout parapet, flat roof and discreet metal railing terminate at 89m.
	var roof: StaticBody3D = world._structure_box(prefix + "/lookout", center + Vector3.UP * 87.0, Vector3(15.1, 0.8, 20.1), "bridge_granite", 1700000, basis)
	for face in [-1, 1]:
		world._box(roof, Vector3(face * 7.25, 0.85, 0), Vector3(0.5, 1.7, 20.1), "bridge_granite")
		world._box(roof, Vector3(0, 0.85, face * 9.8), Vector3(15.0, 1.7, 0.5), "bridge_granite")
		world._box(roof, Vector3(face * 7.0, 1.75, 0), Vector3(0.09, 0.14, 19.2), "bridge_steel")
		world._box(roof, Vector3(0, 1.75, face * 9.55), Vector3(14.0, 0.14, 0.09), "bridge_steel")

static func _taper_mesh(world: Node3D, bottom: Vector2, top: Vector2, height: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for tier in range(2):
		var size := bottom if tier == 0 else top
		var y := -height * 0.5 if tier == 0 else height * 0.5
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			vertices.append(Vector3(corner.x * size.x * 0.5, y, corner.y * size.y * 0.5))
	var indices := PackedInt32Array([0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7, 0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5, 2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	# Unique triangle vertices keep adjacent masonry faces flat shaded.
	for index in indices:
		surface.set_uv(Vector2(vertices[index].x, vertices[index].y) * 0.05)
		surface.add_vertex(vertices[index])
	# Keep explicit indices: world cell batching consumes indexed surfaces.
	for index in range(indices.size()): surface.add_index(index)
	surface.generate_normals()
	return surface.commit()

static func _window(world: Node3D, parent: Node3D, center: Vector3, face: int) -> void:
	# Deep arched recess silhouette and individually modelled radial voussoirs.
	world._box(parent, center + Vector3(0, -1.1, 0), Vector3(2.6, 5.8, 0.11), "bridge_recess")
	for j in range(12):
		var angle := float(j) / 11.0 * PI
		var at := center + Vector3(cos(angle) * 1.38, 1.80 + sin(angle) * 1.38, face * 0.045)
		var stone: MeshInstance3D = world._box(parent, at, Vector3(0.48, 0.64, 0.22), "bridge_coping")
		stone.rotation.z = angle - PI * 0.5
	for side in [-1, 1]:
		world._box(parent, center + Vector3(side * 1.54, -1.25, face * 0.045), Vector3(0.34, 6.2, 0.22), "bridge_coping")
	world._box(parent, center + Vector3(0, -4.30, face * 0.05), Vector3(3.7, 0.35, 0.5), "bridge_coping")
	# Dark half-disk fills the crown rather than leaving a square hole.
	for j in range(10):
		var x := (j + 0.5) / 10.0 * 2.6 - 1.3
		var height := sqrt(maxf(0.0, 1.3 * 1.3 - x * x))
		world._box(parent, center + Vector3(x, 1.8 + height * 0.5, 0), Vector3(0.27, height, 0.105), "bridge_recess")

static func _lamp(world: Node3D, at: Vector3, basis: Basis) -> void:
	# Outboard lamp poles leave the entire walkway centre unobstructed.
	world._batch_cylinder(at + Vector3.UP * 3.8, 0.085, 7.6, "bridge_steel")
	world._batch_box(at + Vector3.UP * 7.65, Vector3(1.1, 0.18, 0.48), "bridge_edge", basis)
	world._batch_box(at + Vector3.UP * 7.52, Vector3(0.9, 0.055, 0.34), "lamp", basis)

static func _summit(world: Node3D, basis: Basis) -> void:
	# The two flags are recognisable summit details. Small original geometric flags.
	for side in [-1, 1]:
		var p := pos(SPAN * 0.5, 134.0, side * 7.5)
		world._batch_cylinder(p + Vector3.UP * 4.7, 0.06, 9.4, "bridge_edge")
		if side == -1:
			world._batch_box(p + basis.x * 2.4 + Vector3.UP * 8.0, Vector3(4.8, 2.4, 0.04), "navy", basis)
			world._batch_box(p + basis.x * 1.0 + Vector3.UP * 8.6, Vector3(1.8, 0.22, 0.055), "white", basis)
			world._batch_box(p + basis.x * 1.0 + Vector3.UP * 8.6, Vector3(0.22, 1.1, 0.06), "white", basis)
		else:
			world._batch_box(p + basis.x * 2.4 + Vector3.UP * 8.6, Vector3(4.8, 1.2, 0.04), "darksteel", basis)
			world._batch_box(p + basis.x * 2.4 + Vector3.UP * 7.4, Vector3(4.8, 1.2, 0.04), "coral", basis)
			world._batch_cylinder(p + basis.x * 2.4 + Vector3.UP * 8.0 + basis.z * 0.05, 0.63, 0.045, "yellow", basis * Basis(Vector3.RIGHT, PI * 0.5))

static func refresh_drive_collision(world: Node3D) -> void:
	var container := world.get_node_or_null("BridgeDriveSurface")
	if container == null:
		container = Node3D.new()
		container.name = "BridgeDriveSurface"
		world.add_child(container)
	# Called deferred after damage/repair, outside the physics query flush.
	for old in container.get_children():
		container.remove_child(old)
		old.free()
	var stations: Array[Dictionary] = []
	var component_ids: Array[String] = []
	for i in range(29):
		var t := float(i) / 28.0
		stations.append({"p": ramp_position("south", t), "right": ramp_basis("south", t).x})
		if i < 28: component_ids.append("bridge/ramp/south/%s" % i)
	for i in range(1, 43):
		stations.append({"p": pos(float(i) * SPAN / 42.0), "right": basis_at(pos(0), pos(SPAN)).x})
		component_ids.append("bridge/deck/%02d" % (i - 1))
	for i in range(1, 29):
		var t := float(i) / 28.0
		stations.append({"p": ramp_position("north", t), "right": ramp_basis("north", t).x})
		component_ids.append("bridge/ramp/north/%s" % (i - 1))
	# The two exact shared join stations use the main span transverse direction.
	stations[28].right = basis_at(pos(0), pos(SPAN)).x
	stations[70].right = basis_at(pos(0), pos(SPAN)).x
	var run_count := 0
	# One long box per intact approach/span run avoids Godot Physics ghost
	# contacts at both concave triangle edges and convex-hull end polygons.
	# Each region has its own shallow underside, keeping the harbour below open.
	for region in [[0, 28], [28, 70], [70, 98]]:
		var first := -1
		for i in range(region[0], region[1] + 1):
			var intact: bool = i < region[1] and not world.destroyed.has(component_ids[i])
			if intact and first < 0: first = i
			if not intact and first >= 0:
				var body := StaticBody3D.new()
				body.name = "BridgeDriveRun_%s" % run_count
				body.add_to_group("world_structure")
				body.set_meta("bridge_drive_run", true)
				body.set_meta("bridge_drive_region", region[0])
				body.set_meta("damage_id", "bridge/deck/continuous_run_%s" % run_count)
				container.add_child(body)
				var flat: bool = region[0] == 28
				_add_drive_shape(body, stations, first, i, -WIDTH * 0.5, WIDTH * 0.5, 0.0, -2.0)
				if flat:
					_add_drive_shape(body, stations, first, i, -WIDTH * 0.5, WIDTH * 0.5, -2.0, -5.0)
				for across in WALK_X:
					_add_drive_shape(body, stations, first, i, across - 1.1, across + 1.1, 0.24, 0.0)

				run_count += 1
				first = -1
	world.set_meta("bridge_drive_runs", run_count)

static func _add_drive_shape(body: StaticBody3D, stations: Array[Dictionary], first: int, last: int, left: float, right: float, top: float, bottom: float) -> void:
	var collision := CollisionShape3D.new()
	var a: Vector3 = stations[first].p
	var b: Vector3 = stations[last].p
	var basis := basis_at(a, b)
	var shape := BoxShape3D.new()
	shape.size = Vector3(right - left, top - bottom, a.distance_to(b) + 0.02)
	collision.shape = shape
	collision.transform = Transform3D(basis, (a + b) * 0.5 + basis.x * (left + right) * 0.5 + basis.y * (top + bottom) * 0.5)
	body.add_child(collision)
