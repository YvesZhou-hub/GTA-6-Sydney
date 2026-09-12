extends SceneTree
## Actual generated road triangles, independent point-in-triangle coverage, and
## excavation intersections. No production world or graphics device is needed.
const City = preload("res://scripts/city_map.gd")
class RoadWorld extends Node3D:
	const GROUND = 4.5
	var materials := {"road": StandardMaterial3D.new(), "lightstone": StandardMaterial3D.new()}
	var road_segments := []
	var markings := []
	func _batch_box(pos: Vector3, size: Vector3, key: String, basis: Basis = Basis.IDENTITY) -> void:
		markings.append([pos, size, key, basis])
var failures := 0
var checks := []
func _initialize(): call_deferred("run")
func check(label: String, okay: bool, detail = ""):
	checks.append({"name": label, "passed": okay, "detail": detail})
	print("PASS " if okay else "FAIL ", label, " ", detail)
	if not okay: failures += 1
func new_world(snapshot: Dictionary) -> RoadWorld:
	var world := RoadWorld.new()
	root.add_child(world)
	City.build_roads(world, snapshot)
	return world
func triangles(world: RoadWorld, material: String = "") -> Array:
	var output := []
	for view in world.get_children():
		if not view is MeshInstance3D: continue
		if not material.is_empty() and view.material_override != world.materials[material]: continue
		var arrays: Array = view.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, indices.size(), 3):
			var tri := PackedVector2Array()
			for j in 3:
				var point: Vector3 = vertices[indices[i + j]] + view.position
				tri.append(Vector2(point.x, point.z))
			output.append(tri)
	return output
func covered(point: Vector2, faces: Array) -> bool:
	for tri in faces:
		var a: float = (tri[1] - tri[0]).cross(point - tri[0])
		var b: float = (tri[2] - tri[1]).cross(point - tri[1])
		var c: float = (tri[0] - tri[2]).cross(point - tri[2])
		if a >= -.0002 and b >= -.0002 and c >= -.0002: return true
		if a <= .0002 and b <= .0002 and c <= .0002: return true
	return false
func old_strip_contains(point: Vector2, segments: Array) -> bool:
	for segment in segments:
		var axis: Vector2 = segment[1] - segment[0]
		var along: float = (point - segment[0]).dot(axis.normalized())
		if along >= -.02 and along <= axis.length() + .02 and absf(axis.normalized().cross(point - segment[0])) <= segment[2] * .5: return true
	return false
func area(poly: PackedVector2Array) -> float:
	var result := 0.0
	for i in poly.size(): result += (poly[i] - poly[0]).cross(poly[(i + 1) % poly.size()] - poly[0])
	return absf(result) * .5
func material_overlap(world: RoadWorld) -> float:
	var asphalt := triangles(world, "road")
	var paving := triangles(world, "lightstone")
	var indexed := {}
	var area_sum := 0.0
	for i in asphalt.size():
		var tri: PackedVector2Array = asphalt[i]
		var bounds := Rect2(tri[0], Vector2.ZERO).expand(tri[1]).expand(tri[2])
		for x in range(floori(bounds.position.x/16), floori(bounds.end.x/16)+1):
			for z in range(floori(bounds.position.y/16), floori(bounds.end.y/16)+1):
				var key := Vector2i(x,z)
				if not indexed.has(key): indexed[key] = []
				indexed[key].append(i)
	for tri in paving:
		var bounds := Rect2(tri[0], Vector2.ZERO).expand(tri[1]).expand(tri[2])
		var visited := {}
		for x in range(floori(bounds.position.x/16), floori(bounds.end.x/16)+1):
			for z in range(floori(bounds.position.y/16), floori(bounds.end.y/16)+1):
				for index in indexed.get(Vector2i(x,z), []):
					if visited.has(index): continue
					visited[index] = true
					for overlap in Geometry2D.intersect_polygons(tri, asphalt[index]): area_sum += area(overlap)
	return area_sum

func run():
	var fixture := {"roads": [
		{"tags": {"highway": "residential", "width": "8"}, "points": [[-20, 0], [0, 0]]},
		{"tags": {"highway": "residential", "width": "8"}, "points": [[0, 0], [-12, 8]]},
		{"tags": {"highway": "residential", "width": "12"}, "points": [[0, 0], [15, 4]]}
	]}
	var synthetic := new_world(fixture)
	var faces := triangles(synthetic)
	var missing := 0
	for i in 128:
		if not covered(Vector2.from_angle(TAU * i / 128.0) * 5.85, faces): missing += 1
	check("shared OSM node joins separate ways and different widths", missing == 0, missing)
	check("dead-end butt cap does not grow into unmapped land", not covered(Vector2(-21, 0), faces))
	check("centerlines remain identical to the source", synthetic.road_segments == [[Vector2(-20,0),Vector2.ZERO,8.0],[Vector2.ZERO,Vector2(-12,8),8.0],[Vector2.ZERO,Vector2(15,4),12.0]])
	check("local road join uses spatial material batches", synthetic.get_meta("real_road_draw_groups") <= 4)
	synthetic.free()
	var cut_fixture := fixture.duplicate(true)
	cut_fixture.excavations = [{"polygon": [[-1,-1],[1,-1],[1,1],[-1,1]]}]
	var cut_world := new_world(cut_fixture)
	var cut_faces := triangles(cut_world)
	var intrusion := 0.0
	var hole := City.polygon(cut_fixture.excavations[0].polygon)
	for tri in cut_faces:
		for overlap in Geometry2D.intersect_polygons(tri, hole): intrusion += area(overlap)
	check("hole fully inside a road junction remains actually open", intrusion < .0001, intrusion)
	check("excavation clipping preserves surrounding pavement", covered(Vector2(0,2), cut_faces) and covered(Vector2(2,0), cut_faces))
	cut_world.free()
	var crossing := fixture.duplicate(true)
	crossing.roads.append({"tags":{"highway":"footway","width":"4"},"points":[[-5,-10],[-5,10]]})
	var crossing_world := new_world(crossing)
	check("overlapping pedestrian and asphalt surfaces are geometrically disjoint", material_overlap(crossing_world) < .0001)
	check("pedestrian approach survives outside carriageway", covered(Vector2(-5,-8), triangles(crossing_world,"lightstone")))
	crossing_world.free()
	# Explicit area geometry must fill the plaza, retain its surveyed footprint,
	# and contribute no false road around its perimeter to vehicle placement.
	var plaza := {"id":"way/qa_plaza","tags":{"highway":"pedestrian","area":"yes"},"points":[[-10,-10],[10,-10],[10,10],[-10,10],[-10,-10]],"surface_geometry":"area","surface_triangles":[[-10,-10],[10,-10],[10,10],[-10,-10],[10,10],[-10,10]]}
	var plaza_fixture := {"roads":[plaza,{"tags":{"highway":"footway","width":"4"},"points":[[-20,0],[20,0]]}]}
	var plaza_world := new_world(plaza_fixture)
	var plaza_faces := triangles(plaza_world, "lightstone")
	var paved_area := 0.0
	for face in plaza_faces: paved_area += area(face)
	check("mapped plaza interior is filled and its boundary is not buffered", covered(Vector2(0,8),plaza_faces) and not covered(Vector2(10.1,8),plaza_faces))
	check("plaza and crossing footway have no double-painted area", absf(paved_area-480.0)<.001,paved_area)
	check("plaza does not invent perimeter vehicle spawn segments",plaza_world.road_segments==[[Vector2(-20,0),Vector2(20,0),4.0]])
	check("connecting footway survives outside the mapped area",covered(Vector2(-18,0),plaza_faces) and covered(Vector2(18,0),plaza_faces))
	plaza_world.free()
	var plaza_crossing := plaza_fixture.duplicate(true)
	plaza_crossing.roads.append({"tags":{"highway":"residential","width":"6"},"points":[[0,-30],[0,30]]})
	plaza_crossing.excavations=[{"polygon":[[5,5],[7,5],[7,7],[5,7]]}]
	var plaza_cut := new_world(plaza_crossing)
	check("mapped plaza yields to carriageway without coplanar overlap",material_overlap(plaza_cut)<.0001)
	check("mapped plaza retains a real excavation opening",not covered(Vector2(6,6),triangles(plaza_cut)))
	plaza_cut.free()
	var snapshot := City.data()
	for site in [["Fairy Bower Road", Vector2(7418,-6372), 110.0],["Darling pyramidal street",Vector2(-612.303,1973.009),110.0]]:
		var roads := []
		for road in snapshot.roads:
			var near := false
			for point in road.points:
				if Vector2(point[0],point[1]).distance_to(site[1]) < site[2]: near = true; break
			if near and road.tags.get("highway", "") not in ["pedestrian","footway","path","steps","cycleway"]: roads.append(road)
		var world := new_world({"roads": roads, "excavations": snapshot.excavations})
		faces = triangles(world)
		var old_gaps := 0
		var new_gaps := 0
		var joins := {}
		for segment in world.road_segments:
			for at in [segment[0],segment[1]]:
				if not joins.has(at): joins[at] = {"count": 0, "width": 0.0}
				joins[at].count += 1
				joins[at].width = maxf(joins[at].width, segment[2])
		for point in joins:
			if joins[point].count < 2: continue
			for angle in 64:
				var probe: Vector2 = point + Vector2.from_angle(TAU * angle / 64.0) * joins[point].width * .48
				if not old_strip_contains(probe, world.road_segments):
					old_gaps += 1
					if not covered(probe, faces): new_gaps += 1
		check(site[0] + " source fixture reproduces old strip gaps", old_gaps > 4, old_gaps)
		check(site[0] + " every reproduced gap is paved", new_gaps == 0, new_gaps)
		world.free()
	var mixed_roads := []
	for road in snapshot.roads:
		for point in road.points:
			if Vector2(point[0],point[1]).distance_to(Vector2(-612.303,1973.009)) < 110:
				mixed_roads.append(road)
				break
	var mixed := new_world({"roads":mixed_roads,"excavations":snapshot.excavations})
	var mixed_area := material_overlap(mixed)
	check("Darling street native artifact has no coplanar material overlap", mixed_area < .001, mixed_area)
	mixed.free()
	var start := Time.get_ticks_msec()
	var full := new_world(snapshot)
	var expected_areas := 0
	for road in snapshot.roads:
		if road.get("surface_geometry", "") == "area" and not road.surface_triangles.is_empty(): expected_areas += 1
	check("full city renders every nonempty mapped pedestrian area",expected_areas>100 and full.get_meta("real_pedestrian_areas")==expected_areas,expected_areas)
	var build_ms := Time.get_ticks_msec() - start
	var bad_heights := 0
	var bad_winding := 0
	var triangle_count := 0
	var excavation_area := 0.0
	for view in full.get_children():
		var arrays: Array = view.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for p in vertices:
			if absf(p.y - 4.585) > .00001: bad_heights += 1
		for i in range(0, indices.size(), 3):
			var a: Vector3 = vertices[indices[i]] + view.position
			var b: Vector3 = vertices[indices[i+1]] + view.position
			var c: Vector3 = vertices[indices[i+2]] + view.position
			if (b-a).cross(c-a).y >= 0: bad_winding += 1
			triangle_count += 1
			var tri := PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
			var bounds := Rect2(tri[0],Vector2.ZERO).expand(tri[1]).expand(tri[2])
			for excavation in snapshot.excavations:
				var ring := City.polygon(excavation.polygon)
				var eb := Rect2(ring[0],Vector2.ZERO)
				for p in ring: eb = eb.expand(p)
				if bounds.intersects(eb):
					for overlap in Geometry2D.intersect_polygons(tri,ring): excavation_area += area(overlap)
	check("all city roads keep the original 4.585m visible surface", bad_heights == 0, bad_heights)
	check("all city road triangles face upward without degenerates", bad_winding == 0, bad_winding)
	check("both real metro holes contain no road or join triangles", excavation_area < .005, excavation_area)
	check("all city roads batch below original segment instance count", full.get_meta("real_road_draw_groups") < full.road_segments.size() / 8)
	var stats := {"build_ms": build_ms, "segments": full.road_segments.size(), "joins": full.get_meta("real_road_joins"), "draw_groups": full.get_meta("real_road_draw_groups"), "triangles": triangle_count}
	print("ROAD_JOIN_STATS ", JSON.stringify(stats))
	var output := ProjectSettings.globalize_path("res://../reports/road-joins")
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output + "/geometry.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"stats":stats,"passed":failures == 0},"\t"))
	full.free()
	print("ROAD_JOIN_COMPLETE failures=", failures)
	quit(1 if failures else 0)
