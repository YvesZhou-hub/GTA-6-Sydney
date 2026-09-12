extends RefCounted
## Reproducible real footprint/centerline map. Heights and facade confidence are
## explicitly retained in city_map.json. Ordinary exteriors are reconstructions.
const DATA_PATH := "res://assets/city_map.json"
const FACADE := preload("res://shaders/city_facade.gdshader")
const DARLING_FACILITY_IDS := ["way/1136058496","way/1241018456","way/1241018457","way/1241018458"]
const CUSTOM_IDS := ["way/408117953","way/408117952","way/408117951","way/408117950","way/408117949","way/408117948","way/51065527","way/581013659","way/468557019","way/544307818","way/614461305","way/614603737","way/7981564","way/1326239876","way/223786812","way/552008767","relation/7889573","way/120926554","way/335696788","way/544300934","way/544300935","way/544300936","way/544300937","way/544300938","way/183246899","way/183246900","way/312373859","way/387782063","way/1120046335","way/1120046336","way/1120046337","way/1120046338","way/1116329930","way/1521293802","way/335699164","way/335699165","way/1521293801","way/386563854","way/386563852","way/501890909","way/488447518","way/488447519","way/23646745","way/1116329939","way/487371417","way/1098953175","way/197801072","way/197801073","way/197801074","way/273960049","way/270803850","way/354270479","way/354270481","way/354270484","way/354270487","way/1269027215","way/1269027216","way/1269027221","way/1269027222","way/1269027236","way/1269027237","way/1295125146","way/1295125147","way/1295125149","way/1295125150","way/1295125151","way/1295125161","way/1295125162","way/1295125163","way/1295125164","way/1295125165","way/1295125168","way/1295125169","way/1295125170","way/1295125194","way/1295125195","way/1295125196","way/1295125197"]
const STREET_WIDTH := {"motorway":13.0,"trunk":12.0,"primary":10.5,"secondary":10.0,"tertiary":9.0,"residential":7.0,"unclassified":7.0,"service":4.0,"living_street":5.5,"pedestrian":9.0,"footway":2.0,"path":2.0,"cycleway":2.8,"steps":2.0}

static func data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))

static func polygon(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points: result.append(Vector2(p[0],p[1]))
	return result

static func _flat_mesh(triangles: Array, y: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,triangles.size(),3):
		var a := Vector3(triangles[i][0],y,triangles[i][1])
		var b := Vector3(triangles[i+1][0],y,triangles[i+1][1])
		var c := Vector3(triangles[i+2][0],y,triangles[i+2][1])
		if (b-a).cross(c-a).y>0:
			var swap := b; b=c; c=swap
		for p in [a,b,c]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(p.x,p.z)*0.05)
			surface.add_vertex(p)
	surface.index()
	return surface.commit()

static func build_terrain(world: Node3D, snapshot: Dictionary) -> void:
	for i in snapshot.land.size():
		var land: Dictionary = snapshot.land[i]
		var mesh := _flat_mesh(land.triangles,world.GROUND)
		var body := StaticBody3D.new()
		body.name = "OSM_Land_%s"%i
		world.add_child(body)
		var view := MeshInstance3D.new()
		view.mesh=mesh
		view.material_override=world.materials.north_landcover
		body.add_child(view)
		var shape := CollisionShape3D.new()
		shape.shape=mesh.create_trimesh_shape()
		body.add_child(shape)
	# Beaches keep their real polygons and a gently sloping visual edge. The
	# flat terrain datum remains documented; this does not claim a terrain survey.
	world._mat("map_sand",Color("d7c899"),0.99)
	for collection in [snapshot.beaches,snapshot.parks]:
		for item in collection:
			var poly := polygon(item.points)
			if Geometry2D.triangulate_polygon(poly).is_empty(): continue
			var view := MeshInstance3D.new()
			view.name = "OSM_Area_%s"%str(item.id).replace("/","_")
			view.mesh=_flat_mesh(item.surface_triangles,world.GROUND) if item.has("surface_triangles") else world._land_mesh(poly)
			view.position.y=0.026 if collection==snapshot.beaches else 0.021
			view.material_override=world.materials.map_sand if collection==snapshot.beaches else world.materials.grass
			world.add_child(view)

static func build_roads(world: Node3D, snapshot: Dictionary) -> void:
	var batches := {}
	var road_masks := {}
	var paving := []
	var nodes := {}
	var excavations := _road_excavations(snapshot)
	var rendered := 0
	for road in snapshot.roads:
		# These mapped paths are now solid stone pier / sloping gangway geometry.
		if road.get("id", "") in preload("res://scripts/manowar_detail.gd").REPLACED_ROADS:continue
		var tags: Dictionary = road.tags
		var kind: String = tags.get("highway", "")
		# Keep the original mapped centreline and elevation filtering. A ground
		# ribbon is not a reconstruction of an elevated road or underground rail.
		if tags.get("bridge", "no") != "no" or tags.get("tunnel", "no") != "no" or float(tags.get("layer", "0")) != 0: continue
		if kind not in STREET_WIDTH: continue
		var width: float = STREET_WIDTH[kind]
		if str(tags.get("width", "")).is_valid_float(): width = clampf(float(tags.width), 1.0, 35.0)
		elif str(tags.get("lanes", "")).is_valid_float() and kind in ["primary", "secondary", "tertiary", "trunk", "motorway"]: width = float(tags.lanes) * 3.15
		var pedestrian := kind in ["pedestrian", "footway", "path", "steps", "cycleway"]
		var material := "lightstone" if pedestrian else "road"
		if road.has("surface_triangles") and road.surface_triangles.is_empty(): continue
		if road.has("surface_triangles"):
			for i in range(0, road.surface_triangles.size(), 3):
				_road_register_surface(batches, polygon(road.surface_triangles.slice(i, i + 3)), material, excavations, world.GROUND + 0.085, road_masks, paving)
		for i in range(road.points.size() - 1):
			var a := Vector2(road.points[i][0], road.points[i][1])
			var b := Vector2(road.points[i + 1][0], road.points[i + 1][1])
			var delta := b - a
			if delta.length() < 0.08: continue
			world.road_segments.append([a, b, width])
			var perpendicular := Vector2(-delta.y, delta.x).normalized() * width * 0.5
			if not road.has("surface_triangles"):
				_road_register_surface(batches, PackedVector2Array([a + perpendicular, b + perpendicular, b - perpendicular, a - perpendicular]), material, excavations, world.GROUND + 0.085, road_masks, paving)
			for endpoint in [[a, delta.normalized()], [b, -delta.normalized()]]:
				# Projected source nodes retain millimetres. Shared nodes between
				# separate OSM ways receive the same join as a bend within one way.
				var node_key := "%s/%s/%s" % [material, roundi(endpoint[0].x * 1000), roundi(endpoint[0].y * 1000)]
				if not nodes.has(node_key): nodes[node_key] = {"point": endpoint[0], "width": width, "min_width": width, "min_length": delta.length(), "directions": [], "material": material}
				nodes[node_key].width = maxf(nodes[node_key].width, width)
				nodes[node_key].min_width = minf(nodes[node_key].min_width, width)
				nodes[node_key].min_length = minf(nodes[node_key].min_length, delta.length())
				nodes[node_key].directions.append(endpoint[1])
			if not pedestrian and width >= 7 and not road.has("surface_triangles"):
				var av := Vector3(a.x, world.GROUND + 0.055, a.y)
				var bv := Vector3(b.x, world.GROUND + 0.055, b.y)
				var basis := Basis.looking_at((bv - av).normalized(), Vector3.UP)
				for n in range(2, int(delta.length()) - 2, 12):
					world._batch_box(av + (bv - av).normalized() * n + Vector3.UP * 0.038, Vector3(0.10, 0.012, 3), "white", basis)
			rendered += 1
	var joined := 0
	for entry in nodes.values():
		if entry.directions.size() < 2: continue
		if entry.directions.size() == 2 and entry.directions[0].dot(entry.directions[1]) < -0.99999: continue
		# A round join fills the outside wedge left by two butt-ended strips.
		# It never extends farther than half the tagged/derived road width from
		# the actual node. Single-ended streets retain their original butt cap.
		var ring := _road_join_outline(entry)
		_road_register_surface(batches, ring, entry.material, excavations, world.GROUND + 0.085, road_masks, paving)
		joined += 1
	# Road carriageways own their footprint. Coplanar pedestrian ribbons are
	# geometrically subtracted here, preventing competing white/asphalt pixels
	# at crossings and beside rounded road edges without raising either surface.
	for outline in paving:
		for piece in _road_paving_pieces(outline, road_masks):
			_road_add_polygon(batches, piece, "lightstone", excavations, world.GROUND + 0.085)
	var draw_groups := 0
	for material in batches:
		for cell in batches[material]:
			var surface: SurfaceTool = batches[material][cell]
			surface.index()
			var view := MeshInstance3D.new()
			view.name = "OSM_Road_%s_%s_%s" % [material, cell.x, cell.y]
			view.mesh = surface.commit()
			view.material_override = world.materials[material]
			view.position = Vector3(cell.x * 160.0, 0, cell.y * 160.0)
			view.visibility_range_end = 1200.0
			view.visibility_range_end_margin = 120.0
			world.add_child(view)
			draw_groups += 1
	world.set_meta("real_road_segments", rendered)
	world.set_meta("real_road_joins", joined)
	world.set_meta("real_road_draw_groups", draw_groups)

static func _road_register_surface(batches: Dictionary, outline: PackedVector2Array, material: String, excavations: Array, y: float, masks: Dictionary, paving: Array) -> void:
	if material == "lightstone":
		paving.append(outline)
		return
	_road_add_polygon(batches, outline, material, excavations, y)
	# Two millimetres of pavement trim absorb float rounding at kilometre-scale
	# projected coordinates. The asphalt footprint and all elevations stay put.
	var expanded := Geometry2D.offset_polygon(outline, 0.002, Geometry2D.JOIN_MITER)
	if not expanded.is_empty(): outline = expanded[0]
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline: bounds = bounds.expand(point)
	var item := {"polygon": outline, "bounds": bounds, "id": masks.size()}
	# A reference ID, rather than a polygon hash, deduplicates masks spanning
	# several cells. All surfaces stay at the same original street elevation.
	item.id = int(masks.get("next_id", 0))
	masks.next_id = item.id + 1
	for x in range(floori(bounds.position.x / 64.0), floori(bounds.end.x / 64.0) + 1):
		for z in range(floori(bounds.position.y / 64.0), floori(bounds.end.y / 64.0) + 1):
			var cell := Vector2i(x, z)
			if not masks.has(cell): masks[cell] = []
			masks[cell].append(item)

static func _road_paving_pieces(outline: PackedVector2Array, masks: Dictionary) -> Array:
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline: bounds = bounds.expand(point)
	var candidates := {}
	for x in range(floori(bounds.position.x / 64.0), floori(bounds.end.x / 64.0) + 1):
		for z in range(floori(bounds.position.y / 64.0), floori(bounds.end.y / 64.0) + 1):
			for item in masks.get(Vector2i(x, z), []):
				if bounds.intersects(item.bounds): candidates[item.id] = item
	var pieces := [outline]
	for item in candidates.values():
		var remaining := []
		for piece in pieces: remaining.append_array(_road_subtract_convex(piece, item.polygon))
		pieces = remaining
		if pieces.is_empty(): break
	return pieces

static func _road_join_outline(entry: Dictionary) -> PackedVector2Array:
	var ring := PackedVector2Array()
	var radius: float = entry.width * 0.5
	if entry.directions.size() == 2 and absf(entry.width - entry.min_width) < 0.001 and entry.min_length > radius:
		# The strips already cover the inside of an ordinary bend. Tessellate
		# only its missing exterior sector, rather than 32 overlapping triangles
		# at every near-straight source node across the entire city.
		var first: Vector2 = entry.directions[0]
		var second: Vector2 = entry.directions[1]
		var start := first.orthogonal()
		var finish := second.orthogonal()
		if start.dot(second) > 0: start = -start
		if finish.dot(first) > 0: finish = -finish
		var angle := start.angle_to(finish)
		var steps := maxi(1, ceili(absf(angle) / (PI / 16.0)))
		ring.append(entry.point)
		for i in steps + 1: ring.append(entry.point + start.rotated(angle * i / steps) * radius)
	else:
		for i in 32:
			var angle := TAU * i / 32.0
			ring.append(entry.point + Vector2(cos(angle), sin(angle)) * radius)
	return ring

static func _road_excavations(snapshot: Dictionary) -> Array:
	var result := []
	for hole in snapshot.get("excavations", []):
		var ring := polygon(hole.polygon)
		var bounds := Rect2(ring[0], Vector2.ZERO)
		for point in ring: bounds = bounds.expand(point)
		var indices := Geometry2D.triangulate_polygon(ring)
		for i in range(0, indices.size(), 3):
			result.append({"bounds": bounds, "triangle": PackedVector2Array([ring[indices[i]], ring[indices[i + 1]], ring[indices[i + 2]]])})
	return result

static func _road_subtract_convex(subject: PackedVector2Array, cutter: PackedVector2Array) -> Array:
	# Partition rather than returning an outer polygon with an unhandled hole.
	# Every returned piece is convex, including when a cut lies wholly inside
	# a wide road. This protects metro openings from both ribbons AND new joins.
	if Geometry2D.intersect_polygons(subject, cutter).is_empty(): return [subject]
	var remains := subject
	var result := []
	var sign_value := 1.0 if (cutter[1] - cutter[0]).cross(cutter[2] - cutter[0]) > 0 else -1.0
	for i in cutter.size():
		if remains.size() < 3: break
		var inside := PackedVector2Array()
		var outside := PackedVector2Array()
		var origin := cutter[i]
		var edge := cutter[(i + 1) % cutter.size()] - origin
		for j in remains.size():
			var a := remains[j]
			var b := remains[(j + 1) % remains.size()]
			var da := edge.cross(a - origin) * sign_value
			var db := edge.cross(b - origin) * sign_value
			if da >= 0: inside.append(a)
			if da <= 0: outside.append(a)
			if (da > 0 and db < 0) or (da < 0 and db > 0):
				var intersection := a.lerp(b, da / (da - db))
				inside.append(intersection)
				outside.append(intersection)
		if outside.size() >= 3: result.append(outside)
		remains = inside
	return result

static func _road_add_polygon(batches: Dictionary, outline: PackedVector2Array, material: String, excavations: Array, y: float) -> void:
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline: bounds = bounds.expand(point)
	var pieces := [outline]
	for hole in excavations:
		if not bounds.intersects(hole.bounds): continue
		var remaining := []
		for piece in pieces: remaining.append_array(_road_subtract_convex(piece, hole.triangle))
		pieces = remaining
	if not batches.has(material): batches[material] = {}
	for piece in pieces:
		for i in range(1, piece.size() - 1):
			var a: Vector2 = piece[0]
			var b: Vector2 = piece[i]
			var c: Vector2 = piece[i + 1]
			var cross := (b - a).cross(c - a)
			if absf(cross) < 0.0001 or minf(a.distance_to(b), minf(b.distance_to(c), c.distance_to(a))) < 0.001: continue
			if cross < 0:
				var swap := b; b = c; c = swap
			var center := (a + b + c) / 3.0
			var cell := Vector2i(floori(center.x / 160.0), floori(center.y / 160.0))
			if not batches[material].has(cell):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				batches[material][cell] = surface
			var surface: SurfaceTool = batches[material][cell]
			for point in [a, b, c]:
				surface.set_normal(Vector3.UP)
				surface.set_uv(point * 0.05)
				surface.add_vertex(Vector3(point.x - cell.x * 160.0, y, point.y - cell.y * 160.0))

static func _material(world: Node3D, item: Dictionary) -> String:
	var tags: Dictionary=item.tags
	var kind: String=tags.get("building",tags.get("building:part","yes"))
	var material: String=tags.get("building:material","")
	var style := "glass" if material=="glass" or (item.height>45 and kind in ["office","commercial","yes"]) else "brick" if material=="brick" or kind in ["house","terrace","detached"] else "stone" if material in ["stone","sandstone"] or kind in ["church","cathedral"] else "concrete"
	var tagged_color: String=tags.get("building:colour","")
	var key := "map_facade_"+style+tagged_color
	if world.materials.has(key): return key
	var shader := ShaderMaterial.new()
	shader.shader=FACADE
	var wall_color: Color={"glass":Color("6c7d81"),"brick":Color("a7836c"),"stone":Color("b3a68c"),"concrete":Color("aba99f")}[style]
	if not tagged_color.is_empty(): wall_color=Color.from_string(tagged_color,wall_color)
	shader.set_shader_parameter("wall_color",wall_color)
	shader.set_shader_parameter("glazing",0.86 if style=="glass" else 0.49)
	shader.set_shader_parameter("masonry",1.0 if style=="brick" else 0.0)
	shader.set_shader_parameter("bay_width",2.3 if style=="glass" else 3.0)
	world.materials[key]=shader
	return key

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, uv: Array) -> void:
	var points := [a,b,c]
	if (b-a).cross(c-a).dot(normal)>0:
		points=[a,c,b]; uv=[uv[0],uv[2],uv[1]]
	for i in 3:
		surface.set_normal(normal)
		surface.set_uv(uv[i])
		surface.add_vertex(points[i])

static func _extrusion(item: Dictionary, bottom: float, top: float) -> Array:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = [item.outline]
	rings.append_array(item.holes)
	for ring in rings:
		var poly := polygon(ring)
		var clockwise := Geometry2D.is_polygon_clockwise(poly)
		for i in poly.size():
			var p:=poly[i]; var q:=poly[(i+1)%poly.size()]
			var delta:=q-p
			var normal:=Vector3(delta.y,0,-delta.x).normalized()
			if clockwise: normal=-normal
			if ring!=item.outline: normal=-normal
			var a:=Vector3(p.x,bottom,p.y); var b:=Vector3(q.x,bottom,q.y)
			var c:=Vector3(q.x,top,q.y); var d:=Vector3(p.x,top,p.y)
			var u:=delta.length()
			_triangle(surface,a,b,c,normal,[Vector2(0,bottom),Vector2(u,bottom),Vector2(u,top)])
			_triangle(surface,a,c,d,normal,[Vector2(0,bottom),Vector2(u,top),Vector2(0,top)])
	for i in range(0,item.roof.size(),3):
		for y in [bottom,top]:
			var vertices: Array=[]
			var uv: Array=[]
			for k in 3:
				var p:=Vector2(item.roof[i+k][0],item.roof[i+k][1])
				vertices.append(Vector3(p.x,y,p.y)); uv.append(p*0.05)
			_triangle(surface,vertices[0],vertices[1],vertices[2],Vector3.UP if y==top else Vector3.DOWN,uv)
	surface.index()
	return surface.commit_to_arrays()

static func _facade_relief(item: Dictionary, bottom: float, top: float) -> Array:
	# Geometric floor ledges and recessed-window framing follow each actual
	# footprint edge. They are inferred architectural detailing, not surveyed bays.
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var poly:=polygon(item.outline)
	var clockwise:=Geometry2D.is_polygon_clockwise(poly)
	var floor_height:=3.4
	var pieces := 0
	if float(item.tags.get("building:levels",0))>0:
		floor_height=clampf((item.height-item.base)/float(item.tags["building:levels"]),2.7,4.5)
	for i in poly.size():
		var p:=poly[i]; var q:=poly[(i+1)%poly.size()]
		var d:=q-p
		if d.length()<1.2: continue
		var normal:=Vector3(d.y,0,-d.x).normalized()
		if clockwise: normal=-normal
		var basis:=Basis.looking_at(Vector3(d.x,0,d.y).normalized(),Vector3.UP)
		var middle:=Vector3((p.x+q.x)*0.5,0,(p.y+q.y)*0.5)
		for level in range(int(ceil(bottom/floor_height)),int(floor(top/floor_height))+1):
			var y:float=level*floor_height
			if y<1.5: continue
			var pose:=Transform3D(basis.scaled_local(Vector3(0.30,0.15,d.length())),middle+Vector3.UP*y+normal*0.07)
			_relief_box(surface,pose)
			pieces+=1
		if item.height>35:
			var bays:=maxi(1,int(d.length()/3.0))
			for bay in range(1,bays):
				var at:=p.lerp(q,float(bay)/bays)
				var pose:=Transform3D(basis.scaled_local(Vector3(0.15,top-bottom,0.10)),Vector3(at.x,(top+bottom)*0.5,at.y)+normal*0.08)
				_relief_box(surface,pose)
				pieces+=1
	if pieces==0:
		var empty: Array=[]
		empty.resize(Mesh.ARRAY_MAX)
		return empty
	surface.index()
	return surface.commit_to_arrays()

static func _roof_arrays(item: Dictionary) -> Array:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,item.roof_surface.size(),3):
		var a:=Vector3(item.roof_surface[i][0],item.roof_surface[i][1],item.roof_surface[i][2])
		var b:=Vector3(item.roof_surface[i+1][0],item.roof_surface[i+1][1],item.roof_surface[i+1][2])
		var c:=Vector3(item.roof_surface[i+2][0],item.roof_surface[i+2][1],item.roof_surface[i+2][2])
		var cross:Vector3=(b-a).cross(c-a)
		if cross.length_squared()<0.00000001: continue
		var normal:=cross.normalized()
		if normal.y<0: normal=-normal
		if absf(normal.y)<0.00001:
			var middle:Vector3=(a+b+c)/3.0+normal*0.02
			var inside:=Geometry2D.is_point_in_polygon(Vector2(middle.x,middle.z),polygon(item.outline))
			for hole in item.holes:
				if Geometry2D.is_point_in_polygon(Vector2(middle.x,middle.z),polygon(hole)): inside=false
			if inside: normal=-normal
		_triangle(surface,a,b,c,normal,[Vector2(a.x,a.z)*.1,Vector2(b.x,b.z)*.1,Vector2(c.x,c.z)*.1])
	surface.index()
	return surface.commit_to_arrays()

static func _relief_box(surface: SurfaceTool, pose: Transform3D) -> void:
	for axis in 3:
		for side in [-1.0,1.0]:
			var normal:=Vector3.ZERO
			normal[axis]=side
			var a:=Vector3.ZERO; var b:=Vector3.ZERO
			a[(axis+1)%3]=0.5; b[(axis+2)%3]=0.5
			var vertices: Array[Vector3]=[]
			for local in [normal*0.5-a-b,normal*0.5+a-b,normal*0.5+a+b,normal*0.5-a+b]: vertices.append(pose*local)
			var transformed:Vector3=(pose.basis*normal).normalized()
			_triangle(surface,vertices[0],vertices[1],vertices[2],transformed,[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE])
			_triangle(surface,vertices[0],vertices[2],vertices[3],transformed,[Vector2.ZERO,Vector2.ONE,Vector2.DOWN])

static func _reserved(world: Node3D, item: Dictionary) -> bool:
	# These mapped shelters and service rooms are rebuilt by the playground
	# module; the generic office-like extrusion would seal the open picnic space.
	if item.id in CUSTOM_IDS or item.id in DARLING_FACILITY_IDS: return true
	# A tagged podium below every explicitly raised part is a distinct solid,
	# not the duplicate full-height outline suppressed by the S3DB rule.
	if not item.get("parts",[]).is_empty() and item.get("parent_geometry_policy",{}).get("mode","")!="preserve_tagged_base": return true
	var p:=Vector2(item.center[0],item.center[1])
	# Existing playable interiors and bridge approaches remain explicit game
	# adjustments. An OSM block must not seal an old save's front door or roadway.
	if p.distance_to(Vector2(-350,-28))<42 or p.distance_to(Vector2(-410,420))<55: return true
	if p.distance_to(Vector2(421,-326))<115: return true
	if p.distance_to(Vector2(-547.947,-47.452))<24: return true
	for vertex in item.outline:
		if world._in_bridge_corridor(p+Vector2(vertex[0],vertex[1]),2): return true
	return false

static func build_buildings(world: Node3D, snapshot: Dictionary) -> void:
	var count := 0
	var skipped := 0
	for item in snapshot.buildings:
		if _reserved(world,item): skipped+=1; continue
		var center:=Vector3(item.center[0],world.GROUND,item.center[1])
		var bounds:=AABB(center+Vector3(item.outline[0][0],item.base,item.outline[0][1]),Vector3.ZERO)
		for vertex in item.outline:
			bounds=bounds.expand(center+Vector3(vertex[0],item.base,vertex[1]))
			bounds=bounds.expand(center+Vector3(vertex[0],item.height,vertex[1]))
		world._building_plots.append(bounds)
		var key:=_material(world,item)
		var wall_height:float=item.get("wall_height",item.height)
		var levels:=maxi(1,mini(8,int(ceil((wall_height-item.base)/18.0))))
		for level in levels:
			var bottom: float=lerpf(item.base,wall_height,float(level)/levels)
			var top: float=lerpf(item.base,wall_height,float(level+1)/levels)
			var arrays:=_extrusion(item,bottom,top)
			var id: String="osm/%s/storey_group/%s"%[item.id,level]
			var body: StaticBody3D=world._structure_arrays(id,arrays,center,key,200000+(top-bottom)*14000)
			body.set_meta("osm_id",item.id)
			body.set_meta("height_source",item.height_source)
			body.set_meta("map_building",true)
			if item.height>9.0 and top-bottom>2.7:
				var relief:=_facade_relief(item,bottom,top)
				if relief[Mesh.ARRAY_VERTEX]!=null and not relief[Mesh.ARRAY_VERTEX].is_empty():
					world.structures[id].surfaces.append({"arrays":relief,"material":world.materials.steel if item.height>35 else world.materials.lightstone,"near":true})
		if item.has("roof_surface"):
			var color_name:String=item.tags.get("roof:colour","8b7661" if item.tags.get("roof:material","")=="roof_tiles" else "727a79")
			var roof_key:="mapped_roof_"+color_name
			if not world.materials.has(roof_key): world._mat(roof_key,Color.from_string(color_name,Color("727a79")),0.9)
			world._structure_arrays("osm/%s/roof"%item.id,_roof_arrays(item),center,roof_key,220000)
		count+=1
	world._building_count+=count
	world.set_meta("map_buildings",count)
	world.set_meta("map_reserved_buildings",skipped)
	print("CITY_MAP buildings=",count," reserved=",skipped," roads=",world.get_meta("real_road_segments",0))

static func build_places(world: Node3D, snapshot: Dictionary) -> void:
	var named := 0
	var authored_ids: Array=["node/4928549541","node/12869436878"]
	for path:String in ["res://assets/darling_square_frontages.json","res://assets/darling_precinct_frontages.json"]:
		for shop:Dictionary in JSON.parse_string(FileAccess.get_file_as_string(path)).shops:
			if not str(shop.get("osm","")).is_empty():authored_ids.append(shop.osm)
	for place in snapshot.places:
		if place.id in authored_ids: continue
		var tags: Dictionary=place.tags
		var name: String=tags.get("name","")
		var railway: String=tags.get("railway","")
		var shop: bool = tags.has("shop") or tags.get("amenity","") in ["restaurant","cafe","bank","pub","bar","pharmacy"]
		var station := railway in ["subway_entrance","station","halt"]
		if place.id in ["node/11445399049","node/11553917358","node/11553917357"]: continue
		if not shop and not station: continue
		var p:=Vector3(place.point[0],world.GROUND,place.point[1])
		var label:=Label3D.new()
		label.text=name
		label.font_size=34
		label.pixel_size=0.015
		label.position=p+Vector3.UP*(3.6 if shop else 4.7)
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test=false
		label.visibility_range_end=65 if shop else 170
		label.modulate=Color("eadcc4") if shop else Color("74c9bd")
		world.add_child(label)
		if station and railway=="subway_entrance":
			# Exact mapped entrance point and name; no fictitious surface station
			# building or promise of a finished underground transit simulator.
			world._batch_cylinder(p+Vector3.UP*1.6,0.07,3.2,"darksteel")
			world._batch_box(p+Vector3.UP*3.3,Vector3(0.7,0.7,0.18),"teal")
			world.anchors["station_"+str(place.id)]=p
		label.set_meta("osm_id",place.id)
		named+=1
	world.set_meta("mapped_place_labels",named)

static func build_vegetation(world: Node3D, snapshot: Dictionary) -> void:
	var count := 0
	var helipad_omissions:Array=[]
	for tree in snapshot.get("trees",[]):
		var point:=Vector2(tree.point[0],tree.point[1])
		if point.x>6000 and point.y < -5000: continue # Manly's species-specific model.
		if world._in_bridge_corridor(point,3.5): continue
		var height:=8.0
		if str(tree.tags.get("height","")).is_valid_float(): height=clampf(float(tree.tags.height),2,27)
		var position:=Vector3(point.x,world.GROUND,point.y)
		if world._tree_canopy_intersects_helipad(position,height/8.0):
			helipad_omissions.append({"id":tree.id,"point":tree.point,"rendered_scale":height/8.0})
			continue
		if world._tree(position,height/8.0):count+=1
	world.set_meta("mapped_trees",count)
	world.set_meta("helipad_vegetation_adjustment",{"radius_m":world.HELIPAD_TREE_CLEAR_RADIUS,"reason":"Authored game helipad operation area; complete rendered crown bounds excluded, original OSM snapshot unchanged.","omitted_mapped_trees":helipad_omissions})
