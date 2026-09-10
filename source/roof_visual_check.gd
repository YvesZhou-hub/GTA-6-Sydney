extends SceneTree
## Production-scene visual evidence for OSM-tagged roof profiles. This does not
## replace the exhaustive CPU geometry checks or claim surveyed roof dimensions.
const City = preload("res://scripts/city_map.gd")
const TARGETS = [
	["manly_gabled", "way/585589163"],
	["manly_hipped", "way/586181625"],
	["manly_complex", "way/1067236342"],
	["manly_town_hall", "way/223784548"],
	["manly_skillion", "way/682193579"],
	["darling_pyramidal", "way/553843778"],
	["jones_terrace", "way/1046973320"]
]
var started_usec := 0
var failures := 0

func _initialize():
	call_deferred("run")

func run():
	started_usec = Time.get_ticks_usec()
	root.size = Vector2i(1440, 900)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame
	if not game.world._ready_complete:
		push_error("ROOF_CAPTURE_ABORT: production world did not reach READY")
		quit(1)
		return
	var startup_ms: float = (Time.get_ticks_usec() - started_usec) / 1000.0
	game.qa_running = true
	game.set_process(false)
	game.canvas.hide()
	var snapshot: Dictionary = game.world.map_snapshot
	var counts := {"total": 0, "region": {}, "shape": {}, "rendered": 0, "reserved_profiles": [], "flattened_profiles": []}
	var by_id := {}
	for building in snapshot.buildings:
		by_id[building.id] = building
		if not building.has("roof_surface"): continue
		counts.total += 1
		var region: String = building.region
		var shape: String = building.tags.get("roof:shape", "")
		counts.region[region] = counts.region.get(region, 0) + 1
		counts.shape[shape] = counts.shape.get(shape, 0) + 1
		if game.world.structures.has("osm/%s/roof" % building.id): counts.rendered += 1
		else: counts.reserved_profiles.append(building.id)
		# A real regression found by the first visual pass: valid footprint area
		# and a valid height envelope still allowed hip roofs to collapse flat.
		var peak: float = building.wall_height
		for vertex in building.roof_surface: peak = maxf(peak, vertex[1])
		if building.height - building.wall_height > 0.3 and peak - building.wall_height < 0.03:
			counts.flattened_profiles.append(building.id)
			failures += 1
	print("ROOF_CAPTURE_READY ", JSON.stringify(counts))
	var shots: Array[Dictionary] = [
		{"name": "manly_roofscape_far", "camera": Vector3(7600, 210, -6420), "target": Vector3(7150, 13, -6450)},
		{"name": "manly_fairy_bower_street", "camera": Vector3(7423, 6.3, -6380), "target": Vector3(7398, 13, -6355)},
		{"name": "jones_terrace_street", "camera": Vector3(-1163, 6.3, 2302), "target": Vector3(-1188, 12, 2299)}
	]
	for choice in TARGETS:
		if not by_id.has(choice[1]):
			push_error("ROOF_TARGET_MISSING: " + choice[1])
			failures += 1
			continue
		var item: Dictionary = by_id[choice[1]]
		if not game.world.structures.has("osm/%s/roof" % item.id):
			push_error("ROOF_TARGET_RESERVED_OR_UNBUILT: " + item.id)
			failures += 1
			continue
		var bounds := Rect2(Vector2(item.outline[0][0], item.outline[0][1]), Vector2.ZERO)
		for vertex in item.outline:
			bounds = bounds.expand(Vector2(vertex[0], vertex[1]))
		var radius: float = maxf(bounds.size.x, bounds.size.y)
		var center := Vector3(item.center[0], game.world.GROUND, item.center[1])
		var aim := center + Vector3(bounds.get_center().x, lerpf(item.wall_height, item.height, 0.5), bounds.get_center().y)
		for side in [1, -1]:
			var distance: float = maxf(10, radius * 0.93)
			var eye := aim + Vector3(distance * side, maxf(7, radius * 0.45), distance * side)
			shots.append({"name": choice[0] + ("_front" if side == 1 else "_reverse"), "camera": eye, "target": aim, "item": item})
	var folder := ProjectSettings.globalize_path("res://../reports/roof-review")
	if "--after-fix" in OS.get_cmdline_user_args(): folder += "/after-fix"
	DirAccess.make_dir_recursive_absolute(folder)
	var frames: Array[Dictionary] = []
	for shot in shots:
		game.camera.global_position = shot.camera
		game.camera.look_at(shot.target)
		for i in 12: await process_frame
		RenderingServer.force_draw(false)
		var png: String = folder + "/" + shot.name + ".png"
		var error := root.get_texture().get_image().save_png(png)
		if error != OK: failures += 1
		var evidence := {"view": shot.name, "png": png, "captured_utc": Time.get_datetime_string_from_system(true), "ready": true, "camera": _vector(shot.camera), "target": _vector(shot.target), "center_ray": _ray(game, shot.camera, shot.target), "saved": error == OK}
		if shot.has("item"):
			var item: Dictionary = shot.item
			evidence["osm_id"] = item.id
			evidence["roof_tags"] = item.tags
			evidence["roof_profile_source"] = item.roof_profile_source
			evidence["height_source"] = item.height_source
			evidence["eave_above_ground"] = item.wall_height
			evidence["ridge_above_ground"] = item.height
			var peak: float = item.wall_height
			for vertex in item.roof_surface: peak = maxf(peak, vertex[1])
			evidence["actual_mesh_peak_above_ground"] = peak
		frames.append(evidence)
		print("ROOF_FRAME ", shot.name, " ", JSON.stringify(evidence.center_ray))
	var report := {"captured_utc": Time.get_datetime_string_from_system(true), "startup_ms": startup_ms, "scope": "Only dataset roof_surface entries derived from OSM roof:shape; visual sample only; rise and slope inferred unless explicit tags", "counts": counts, "frames": frames, "failures": failures}
	FileAccess.open(folder + "/capture-evidence.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("ROOF_CAPTURE_COMPLETE frames=", frames.size(), " failures=", failures)
	game.active = false
	quit(1 if failures else 0)

func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _ray(game: Node3D, eye: Vector3, target: Vector3) -> Dictionary:
	var direction := (target - eye).normalized()
	var query := PhysicsRayQueryParameters3D.create(eye, target + direction * 2)
	query.hit_from_inside = true
	var hit: Dictionary = game.world.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return {"hit": false}
	return {"hit": true, "position": _vector(hit.position), "damage_id": hit.collider.get_meta("damage_id", ""), "node": str(hit.collider.get_path())}
