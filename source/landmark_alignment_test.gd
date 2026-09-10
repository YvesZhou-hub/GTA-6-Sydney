extends SceneTree
## Independent raw-OSM projection checks plus actual production-world arrival physics.
const Bridge = preload("res://scripts/bridge_landmark.gd")
const Opera = preload("res://scripts/opera_landmark.gd")
const ICC = preload("res://scripts/icc_landmarks.gd")
const MODELS := ["city_landmarks","bank_landmarks","quay_landmarks","cyber_landmarks","manly_landmarks","icc_landmarks","sydney_tower_landmark"]
var failures := 0
var assertions := 0
var raw: Dictionary = {}
var evidence: Dictionary = {"footprints":[],"arrivals":[]}
func verify(ok: bool, message: String) -> void:
	assertions += 1
	if ok: print("PASS ",message)
	else: failures += 1; push_error("FAIL "+message)
func _initialize() -> void: call_deferred("check")
func projected(geometry: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p: Dictionary in geometry: result.append(Vector2((float(p.lon)-151.2105)*92400.0,(-33.86-float(p.lat))*111320.0))
	if result.size()>1 and result[0].distance_to(result[-1])<0.001: result.resize(result.size()-1)
	return result
func centroid(poly: PackedVector2Array) -> Vector2:
	var twice_area := 0.0
	var x := 0.0
	var z := 0.0
	# Shift before shoelace integration so kilometre coordinates do not cancel.
	var origin := poly[0]
	for i in poly.size():
		var a := poly[i]-origin
		var b := poly[(i+1)%poly.size()]-origin
		var cross := float(a.x)*float(b.y)-float(b.x)*float(a.y)
		twice_area += cross
		x += float(a.x+b.x)*cross
		z += float(a.y+b.y)*cross
	return origin+Vector2(x,z)/(3.0*twice_area)
func point_edge_distance(point: Vector2, poly: PackedVector2Array) -> float:
	var result := INF
	for i in poly.size(): result = minf(result,point.distance_to(Geometry2D.get_closest_point_to_segment(point,poly[i],poly[(i+1)%poly.size()])))
	return result
func outline_error(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var result := 0.0
	for p in a: result=maxf(result,point_edge_distance(p,b))
	for p in b: result=maxf(result,point_edge_distance(p,a))
	return result
func relation_outer_ring(element: Dictionary) -> PackedVector2Array:
	var lines: Array[PackedVector2Array] = []
	for member: Dictionary in element.members:
		if member.get("role", "") == "outer" and member.has("geometry"): lines.append(projected(member.geometry))
	var ring := lines.pop_back() as PackedVector2Array
	while not lines.is_empty():
		var found := false
		for i in lines.size():
			var line := lines[i]
			if ring[-1].distance_to(line[-1])<0.002: line.reverse()
			if ring[-1].distance_to(line[0])<0.002:
				for j in range(1,line.size()): ring.append(line[j])
				lines.remove_at(i);found=true;break
		if not found: return PackedVector2Array()
	if ring[0].distance_to(ring[-1])<0.002: ring.resize(ring.size()-1)
	return ring
func long_axis_bearing(poly: PackedVector2Array) -> float:
	var minimum_area := INF
	var long_direction := Vector2.ZERO
	for edge in poly.size():
		var u := (poly[(edge+1)%poly.size()]-poly[edge]).normalized()
		var v := Vector2(-u.y,u.x)
		var low := Vector2(INF,INF)
		var high := Vector2(-INF,-INF)
		for p in poly:
			var projected_point := Vector2((p-poly[0]).dot(u),(p-poly[0]).dot(v))
			low=low.min(projected_point);high=high.max(projected_point)
		var extent := high-low
		if extent.x*extent.y<minimum_area:
			minimum_area=extent.x*extent.y
			long_direction=u if extent.x>extent.y else v
	return fposmod(rad_to_deg(atan2(long_direction.x,-long_direction.y)),180.0)
func _source_x(ids:Array,z:float) -> float:
	for id in ids:
		var points:=projected(raw["way/%d"%int(id)].geometry)
		for i in range(points.size()-1):
			var a:=points[i];var b:=points[i+1]
			if z>=minf(a.y,b.y)-0.001 and z<=maxf(a.y,b.y)+0.001:
				return lerpf(a.x,b.x,(z-a.y)/(b.y-a.y))
	return INF
func check() -> void:
	for file in ["city.json","north.json","manly.json","building_relations.json","manly_landmark_detail.json","metro_entrance_geometry.json"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../source/map-data/"+file))
		for element: Dictionary in data.get("elements",[]):
			raw["%s/%d"%[element.type,int(element.id)]]=element
			if element.type=="relation":
				for member: Dictionary in element.get("members",[]):
					if member.type=="way" and member.has("geometry") and not raw.has("way/%d"%int(member.ref)): raw["way/%d"%int(member.ref)]=member
	var footprint_count := 0
	var max_error := 0.0
	for name: String in MODELS:
		var model = load("res://scripts/"+name+".gd")
		var source_polys: Array[Dictionary] = []
		for id: int in model.excluded_way_ids():
			if raw.has("way/%s"%id) and raw["way/%s"%id].has("geometry"):
				source_polys.append({"id":id,"poly":projected(raw["way/%s"%id].geometry)})
		var model_max := 0.0
		for poly: PackedVector2Array in model.footprints():
			var best := INF
			var matched := 0
			for candidate: Dictionary in source_polys:
				var error := outline_error(poly,candidate.poly)
				if error<best: best=error; matched=candidate.id
			footprint_count += 1
			max_error=maxf(max_error,best);model_max=maxf(model_max,best)
			evidence.footprints.append({"model":name,"osm":"way/%s"%matched,"max_boundary_error_m":best})
		verify(model_max<0.006,"%s visible base footprints match independent raw OSM projection (max %.6fm)"%[name,model_max])
	var pylon_ids := [142518161,142518160,142518163,142518162]
	var mapped_bridge_mid := Vector2.ZERO
	for i in pylon_ids.size():
		var center := centroid(projected(raw["way/%s"%pylon_ids[i]].geometry))
		mapped_bridge_mid += center*0.25
		verify(center.distance_to(Vector2(Bridge.PYLON_CENTERS[i].x,Bridge.PYLON_CENTERS[i].z))<0.002,"bridge pylon %s sits at its mapped footprint centroid"%pylon_ids[i])
	var span_mid := Bridge.pos(Bridge.SPAN*0.5)
	verify(mapped_bridge_mid.distance_to(Vector2(span_mid.x,span_mid.z))<0.002,"503m arch midpoint aligns with the four mapped pylons")
	verify(Bridge.PYLON_CENTERS[0].distance_to(Bridge.PYLON_CENTERS[1])>40.0 and Bridge.PYLON_CENTERS[0].distance_to(Bridge.PYLON_CENTERS[1])<42.0,"pylon pair separation matches actual mapped ~41m, correcting former72m")
	verify(absf((Bridge.SOUTH_ENTRY-Bridge.ARCH_SOUTH).dot(Vector3(-Bridge.AXIS.z,0,Bridge.AXIS.x)))<0.001,"south gameplay approach shares corrected span axis")
	var north_source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/bridge_north_approach.json"))
	var curve_error:=0.0
	for i in north_source.points.size():
		var p: Array=north_source.points[i]
		var mean_x:=(_source_x(north_source.northbound_osm_way_ids,p[1])+_source_x(north_source.southbound_osm_way_ids,p[1]))*0.5
		curve_error=maxf(curve_error,absf(mean_x-p[0]))
	verify(curve_error<0.10,"curved north approach follows independently projected Bradfield carriageway midpoint (max %.4fm, includes arch connection)"%curve_error)
	verify(Bridge.NORTH_ENTRY.x<145.0 and Bridge.NORTH_ENTRY.z<=-1599.0,"north approach reaches mapped Bradfield route instead of former eastern ground endpoint")
	var opera_outline := relation_outer_ring(raw["relation/9596872"])
	verify(opera_outline.size()>10,"raw Opera multipolygon outer ways join into one independent footprint")
	var opera_centroid := centroid(opera_outline)
	verify(opera_centroid.distance_to(Vector2(Opera.CENTER.x,Opera.CENTER.z))<0.002 and absf(Opera.ANGLE+long_axis_bearing(opera_outline))<0.002,"Opera reconstruction uses independently computed mapped centroid and long-axis bearing")
	for item: Dictionary in ICC.metadata():
		verify(item.has("arrival") and item.center==item.building_center and item.arrival.distance_to(item.center)>30,"%s separates model reference and original public arrival"%item.id)
	var world = load("res://scripts/harbor_world.gd").new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	verify(world._ready_complete,"production world reached READY before arrival physics")
	var catalog: Dictionary=world.get_meta("landmark_geography",{})
	verify(catalog.size()>=22,"runtime exposes geographic catalogue with map/arrival separation")
	var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	var arrivals:Array=[]
	for key in catalog:
		if key==str(catalog[key].id):arrivals.append(catalog[key])
	for record: Dictionary in arrivals:
		var item: Dictionary=catalog[record.id]
		var map_point: Vector3=item.map_position
		var at: Vector3=item.arrival
		verify(world.anchors[record.id].distance_to(at)<0.001,"%s navigation anchor resolves public arrival, not building centre"%record.id)
		var ground:=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*1.2,at-Vector3.UP*0.7))
		var supported:bool=not ground.is_empty() and absf(ground.position.y-at.y)<0.5 and ground.normal.y>0.8
		var blocked:=false
		var names:Array=[]
		var capsule:=CapsuleShape3D.new();capsule.radius=0.42;capsule.height=1.85
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.margin=0.015
		if supported:
			query.transform=Transform3D(Basis.IDENTITY,ground.position+Vector3.UP*1.055)
			var hits:=space.intersect_shape(query,12)
			blocked=not hits.is_empty()
			for hit in hits:names.append(str(hit.collider.name))
		verify(supported and not blocked,"%s public arrival has ground + unobstructed human/camera capsule (hits=%s)"%[record.id,names])
		evidence.arrivals.append({"id":record.id,"map_position":[map_point.x,map_point.y,map_point.z],"arrival":[at.x,at.y,at.z],"supported":supported,"blocked":blocked,"hits":names})
	for id in ["icc_convention","icc_exhibition","tiktok_entertainment"]:
		for item:Dictionary in ICC.metadata():
			if item.id==id:verify(world.anchors[id].distance_to(item.arrival)<0.001,"%s service arrival preserved exactly"%id)
	evidence["footprint_count"]=footprint_count;evidence["max_boundary_error_m"]=max_error
	evidence["assertions"]=assertions;evidence["failures"]=failures
	FileAccess.open("res://../reports/geographic-alignment.json",FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t"))
	print("LANDMARK ALIGNMENT COMPLETE assertions=",assertions," failures=",failures," footprints=",footprint_count," max_boundary_error_m=",max_error)
	quit(failures)
