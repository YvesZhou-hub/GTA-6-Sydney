extends SceneTree
## Source-only regression for the v0.1.4 airport connector correction.
## Provenance: source/map-data/city.json way/3770421, terminal node/18802172,
## George Street (Redfern), -33.8925376 / 151.2021819. Complete OSM way extends
## 59.846m south of the importer query boundary (-33.892 / world z=3562.24).
## The remaining road is a fictional game connection through simplified land;
## it is not a surveyed Sydney airport route. No imagery or user saves used.
const Airport=preload("res://scripts/airport_world.gd")
var airport:Node3D
var checks:Array=[]
var evidence:Dictionary={}
func _initialize():call_deferred("run")
func verify(okay:bool,name:String,detail:Variant=null):
	checks.append({"name":name,"passed":okay,"detail":detail})
	print("PASS " if okay else "FAIL ",name," ",detail if detail!=null else "")
func polygon(points:Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for p in points:result.append(Vector2(p[0],p[1]))
	return result
func vector(p:Vector3) -> Array:return [p.x,p.y,p.z]
func triangle_height(p:Vector3,a:Vector3,b:Vector3,c:Vector3) -> float:
	var v0:=Vector2(b.x-a.x,b.z-a.z);var v1:=Vector2(c.x-a.x,c.z-a.z);var q:=Vector2(p.x-a.x,p.z-a.z)
	var determinant:float=v0.cross(v1)
	var u:float=q.cross(v1)/determinant;var v:float=v0.cross(q)/determinant
	if u>=-.0001 and v>=-.0001 and u+v<=1.0001:return a.y+u*(b.y-a.y)+v*(c.y-a.y)
	return INF
func run():
	var source_dir:String=get_script().resource_path.get_base_dir()
	var raw:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_dir.path_join("map-data/city.json")))
	var source_way:Dictionary={}
	for item in raw.elements:
		if item.type=="way" and int(item.id)==3770421:source_way=item;break
	verify(not source_way.is_empty(),"connector is backed by the retained raw OSM way")
	var end:Dictionary=source_way.geometry[-1]
	var projected:=Vector3((float(end.lon)-151.2105)*92400,4.5,(-33.86-float(end.lat))*111320)
	verify(projected.distance_to(Airport.CONNECTOR_ENTRY)<.001,"entry equals raw source terminal node within projection rounding",vector(projected))
	verify(int(source_way.nodes[-1])==18802172,"provenance names the actual final OSM node")
	verify(source_way.tags.highway=="residential" and source_way.tags.get("oneway","no")=="no" and source_way.tags.get("motor_vehicle","yes")!="no" and source_way.tags.get("bridge","no")=="no" and source_way.tags.get("tunnel","no")=="no","source is a ground motor road, not the adjacent cycleway")
	var snapshot:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/city_map.json"))
	var compiled:Dictionary={}
	for road in snapshot.roads:
		if road.id=="way/3770421":compiled=road;break
	verify(not compiled.is_empty() and Vector2(compiled.points[-1][0],compiled.points[-1][1]).distance_to(Vector2(Airport.CONNECTOR_ENTRY.x,Airport.CONNECTOR_ENTRY.z))<.001,"entry meets the road actually rendered in the compiled city")
	var sections:=Airport.connector_sections();var edges:=Airport.connector_edges(sections)
	var tangent:Vector3=(Airport.CONNECTOR_ENTRY-Airport.CONNECTOR_PREVIOUS).normalized()
	var first:Vector3=sections[1].point-sections[0].point;first.y=0
	verify(first.normalized().dot(tangent)>.999999,"initial extension preserves the source street terminal tangent")
	verify(sections[0].width==7.0 and sections[1].width==7.0,"7m motor road continuation preserves separation from cycleway")
	var minimum_z:=INF
	var road_polygons:Array=[]
	for i in range(edges.size()-1):
		var outline:=PackedVector2Array()
		for p in [edges[i][0],edges[i+1][0],edges[i+1][1],edges[i][1]]:
			outline.append(Vector2(p.x,p.z));minimum_z=minf(minimum_z,p.z)
		road_polygons.append(outline)
	verify(minimum_z>3562.24,"entire artificial road ribbon is beyond detailed city south boundary",minimum_z)
	var facilities:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/darling_public_facilities.json"))
	for area in facilities.areas:
		if area.points.size()<4:continue
		var conflicts:=0
		for outline in road_polygons:
			if not Geometry2D.intersect_polygons(outline,polygon(area.points)).is_empty():conflicts+=1
		verify(conflicts==0,"no artificial airport road through Darling facility "+area.id)
	var playground_conflicts:=0
	for outline in road_polygons:
		if not Geometry2D.intersect_polygons(outline,polygon(facilities.playground_outline)).is_empty():playground_conflicts+=1
	verify(playground_conflicts==0,"no artificial airport road through mapped playground perimeter")
	var buildings_hit:Array=[]
	for building in snapshot.buildings:
		if float(building.center[1])<minimum_z-100:continue
		var outline:=PackedVector2Array()
		for p in building.outline:outline.append(Vector2(p[0]+building.center[0],p[1]+building.center[1]))
		for road_outline in road_polygons:
			if not Geometry2D.intersect_polygons(outline,road_outline).is_empty():buildings_hit.append(building.id);break
	verify(buildings_hit.is_empty(),"new connection does not cut retained OSM building footprints",buildings_hit)
	airport=Airport.new();root.add_child(airport);airport.setup()
	verify(airport.anchors.airport_connector==Airport.connector_route(),"map line uses the exact corrected physical route stations")
	var giant_labels:Array=[]
	for node in airport.find_children("*","Label3D",true,false):
		if "AIRPORT CONNECTOR" in node.text:giant_labels.append(str(node.get_path()))
	verify(giant_labels.is_empty(),"obsolete giant development label is absent in production scene")
	verify(airport.has_node("Connector_Road") and not airport.has_node("Connector_Road_0"),"old city-crossing box roads replaced by one joined ribbon")
	verify(Airport.connector_route()[-1].distance_to(Vector3(-4400,Airport.PAVEMENT_TOP,8460))<.001,"connection still reaches the original airport-side road endpoint")
	await physics_frame;await physics_frame
	var space:=airport.get_world_3d().direct_space_state
	var missing:=0;var max_error:=0.0;var bad_normal:=0;var samples:=0;var wrong_body:=0;var unexpected:Array=[]
	for i in range(sections.size()-1):
		var length:float=sections[i].point.distance_to(sections[i+1].point)
		for station in range(1,ceili(length/8.0)):
			var t:float=float(station)/ceili(length/8.0)
			for lane in [.08,.5,.92]:
				var left:Vector3=edges[i][0].lerp(edges[i+1][0],t)
				var right:Vector3=edges[i][1].lerp(edges[i+1][1],t)
				var sample:Vector3=left.lerp(right,lane)
				# Mitered sloping quads are not bilinear surfaces. Compare the
				# physics hit to the analytic plane of the actual two top faces.
				var expected:float=triangle_height(sample,edges[i][0],edges[i+1][0],edges[i+1][1])
				if is_inf(expected):expected=triangle_height(sample,edges[i][0],edges[i+1][1],edges[i][1])
				var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(sample+Vector3.UP*.4,sample-Vector3.UP*.4))
				samples+=1
				if hit.is_empty():missing+=1
				else:
					max_error=maxf(max_error,absf(hit.position.y-expected))
					if hit.collider!=airport.get_node("Connector_Road"):wrong_body+=1
					if absf(hit.position.y-expected)>.004 and unexpected.size()<8:unexpected.append({"segment":i,"sample":vector(sample),"hit":vector(hit.position),"body":str(hit.collider.name)})
					if hit.normal.y<.995:bad_normal+=1
	verify(missing==0 and max_error<.004 and bad_normal==0 and wrong_body==0,"three actual collision lanes remain continuous to airport",{"samples":samples,"missing":missing,"max_height_error":max_error,"bad_normals":bad_normal,"wrong_body":wrong_body,"unexpected":unexpected})
	var join_failures:Array=[]
	for i in range(1,sections.size()-1):
		for before in [-.15,0.0,.15]:
			var direction:Vector3=(sections[i+1].point-sections[i-1].point).normalized()
			var sample:Vector3=sections[i].point+direction*before
			var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(sample+Vector3.UP*.4,sample-Vector3.UP*.4))
			if hit.is_empty() or hit.collider!=airport.get_node("Connector_Road") or hit.normal.y<.995:join_failures.append({"station":i,"offset":before})
	verify(join_failures.is_empty(),"downward rays hit the connector at and beside every bend seam",join_failures)
	# Source boundary uses the same flat physical datum as CityMap.build_terrain.
	# This fixture supplies only the incoming real-road support, not extra support
	# underneath the new connector. Actual production car crosses with inputs.
	var approach:=StaticBody3D.new();approach.position=Airport.CONNECTOR_ENTRY-tangent*22-Vector3.UP*.5
	approach.rotation.y=atan2(tangent.x,tangent.z)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(7,1,44);shape.shape=box;approach.add_child(shape);root.add_child(approach)
	for action in ["forward","back","left","right","rise","fall","brake"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	await physics_frame
	await drive_entry(tangent,false)
	await drive_entry(tangent,true)
	await drive_bend()
	await walk_entry(tangent)
	var okay:bool=checks.all(func(item):return item.passed)
	evidence={"passed":okay,"checks":checks,"count":checks.size(),"source":Airport.CONNECTOR_SOURCE,"entry":vector(Airport.CONNECTOR_ENTRY),"simplified_route":Airport.connector_route().map(func(p):return vector(p)),"scope":"Local production airport, raw/compiled OSM alignment, road/landmark intersections, physical surface sweeps and actual input-driven production car in both directions across city boundary; not full-city road or airport-route realism certification.","user_saves_touched":false}
	FileAccess.open(source_dir.path_join("../reports/airport-connector-v014.json"),FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t"))
	print("AIRPORT_CONNECTOR_COMPLETE ",checks.size()," checks passed=",okay)
	quit(0 if okay else 1)
func drive_entry(tangent:Vector3,reverse:bool):
	var car=load("res://scripts/harbor_vehicle.gd").new();car.configure("car","airport_join_probe")
	var forward:Vector3=-tangent if reverse else tangent
	car.position=Airport.CONNECTOR_ENTRY+tangent*(60.0 if reverse else -22.0)+Vector3.UP*.9
	car.rotation.y=atan2(-forward.x,-forward.z);root.add_child(car)
	for i in 90:await physics_frame
	car.occupied=true;Input.action_press("forward")
	var reached:=false;var peak_y_velocity:=0.0
	for i in 900:
		await physics_frame
		peak_y_velocity=maxf(peak_y_velocity,absf(car.linear_velocity.y))
		var along:float=(car.position-Airport.CONNECTOR_ENTRY).dot(tangent)
		if (reverse and along< -15) or (not reverse and along>60):reached=true;break
	Input.action_release("forward")
	verify(reached and car.health>99.99,"production car crosses city join "+("airport to city" if reverse else "city to airport"),{"reached":reached,"health":car.health,"peak_y_velocity":peak_y_velocity,"position":vector(car.position)})
	car.queue_free();await physics_frame

func drive_bend():
	var route:Array=[Airport.CONNECTOR_ENTRY+(Airport.CONNECTOR_ENTRY-Airport.CONNECTOR_PREVIOUS).normalized()*30,Airport.connector_sections()[1].point,Airport.connector_sections()[2].point]
	var car=load("res://scripts/harbor_vehicle.gd").new();car.configure("car","airport_bend_probe")
	var direction:Vector3=(route[1]-route[0]).normalized()
	car.position=route[0]+Vector3.UP*.9;car.rotation.y=atan2(-direction.x,-direction.z);root.add_child(car)
	for i in 90:await physics_frame
	car.occupied=true
	var section:=0;var reached:=false;var airborne:=0;var wrong_support:=0;var max_deviation:=0.0
	for frame in 2400:
		var a:Vector3=route[section];var b:Vector3=route[section+1]
		var d:Vector3=(b-a).normalized();var along:float=(car.position-a).dot(d)
		if section==0 and along>a.distance_to(b)-7:section=1;continue
		if section==1 and along>a.distance_to(b)-4:reached=true;break
		var target:Vector3=a+d*clampf(along+9,0,a.distance_to(b))
		var toward:Vector3=target-car.position
		var error:float=wrapf(atan2(-toward.x,-toward.z)-car.rotation.y,-PI,PI)
		var steering:float=clampf(-error*2.1+car.angular_velocity.y*.35,-.75,.75)
		for action in ["left","right","forward","brake"]:Input.action_release(action)
		Input.action_press("right" if steering>0 else "left",absf(steering))
		if car.linear_velocity.length()<11:Input.action_press("forward",.6)
		elif car.linear_velocity.length()>12.5:Input.action_press("brake",.15)
		await physics_frame
		if not car.grounded:airborne+=1
		var query:=PhysicsRayQueryParameters3D.create(car.position,car.position-Vector3.UP*2);query.exclude=[car.get_rid()]
		var ground:Dictionary=car.get_world_3d().direct_space_state.intersect_ray(query)
		if ground.is_empty() or ground.collider!=airport.get_node("Connector_Road"):wrong_support+=1
		var planar:=Vector3(car.position.x,a.y,car.position.z)
		max_deviation=maxf(max_deviation,(planar-(a+d*clampf((planar-a).dot(d),0,a.distance_to(b)))).length())
	for action in ["left","right","forward","brake"]:Input.action_release(action)
	verify(reached and car.health>99.99 and airborne==0 and wrong_support==0,"production car drives the first widening bend on its real collider",{"reached":reached,"health":car.health,"airborne_frames":airborne,"wrong_support_frames":wrong_support,"maximum_deviation":max_deviation,"position":vector(car.position)})
	car.queue_free();await physics_frame
func walk_entry(tangent:Vector3):
	for action in ["sprint","jump"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	var player=load("res://scripts/harbor_player.gd").new();root.add_child(player)
	player.position=Airport.CONNECTOR_ENTRY-tangent*5+Vector3.UP*.1;player.last_safe=player.position;player.enabled=true
	for i in 30:await physics_frame
	var target:Vector3=Airport.CONNECTOR_ENTRY+tangent*7
	var reached:=false;var airborne:=0
	for frame in 420:
		var delta:Vector3=target-player.position
		if Vector2(delta.x,delta.z).length()<.3:reached=true;break
		player.yaw=atan2(-delta.x,-delta.z);Input.action_press("forward")
		await physics_frame
		if not player.is_on_floor():airborne+=1
	Input.action_release("forward")
	verify(reached and airborne==0 and player.position.y>4.49,"production Player continuously walks across the real city join",{"reached":reached,"airborne_frames":airborne,"position":vector(player.position)})
	player.queue_free();await physics_frame
