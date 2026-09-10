extends SceneTree
var failures := 0
func verify(value: bool,message: String):
	if value: print("PASS ",message)
	else:
		failures += 1
		push_error("FAIL "+message)
func _initialize(): call_deferred("check")
func check():
	var airport = load("res://scripts/airport_world.gd").new()
	root.add_child(airport)
	airport.setup()
	verify(airport.runway_data.size()==3,"three runway pairs built")
	var lengths := [3962.0,2438.0,2530.0]
	for i in 3:
		verify(absf(airport.runway_data[i].a.distance_to(airport.runway_data[i].b)-lengths[i])<0.1,"runway %d exact published length"%i)
	verify(airport.anchors.runway_start.z>11000,"34L start is geographic south threshold")
	verify(airport.runway_heading>0.18 and airport.runway_heading<0.24,"34L points northwest at true348deg")
	verify(airport.anchors.has("hangar") and airport.anchors.has("terminal"),"usable airport anchors exposed")
	await physics_frame
	var space = airport.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(airport.anchors.runway_start+Vector3.UP*10,airport.anchors.runway_start-Vector3.UP*10)
	var hit = space.intersect_ray(query)
	verify(not hit.is_empty(),"runway has ground collision under aircraft start")
	for ground_point in [Vector3(0,20,4000),Vector3(-3120,20,10200),Vector3(-1550,20,12200)]:
		var land_query = PhysicsRayQueryParameters3D.create(ground_point,ground_point-Vector3.UP*40)
		var land_hit = space.intersect_ray(land_query)
		verify(not land_hit.is_empty(), "terrain top collider at "+str(ground_point))
		if not land_hit.is_empty(): print("terrain_normal=",land_hit.normal," collider=",land_hit.collider.name)
	# Sweep all runway wheel lanes and crossing seams against actual colliders.
	for runway in airport.runway_data:
		var max_error := 0.0
		var missing := 0
		for station in range(1,int(runway.length),10):
			for lane in [-10.0,0.0,10.0]:
				var sample: Vector3 = runway.a + runway.direction*station + runway.right*lane
				var seam_query = PhysicsRayQueryParameters3D.create(sample+Vector3.UP*1.0,sample-Vector3.UP*1.0)
				var seam_hit = space.intersect_ray(seam_query)
				if seam_hit.is_empty(): missing+=1
				else:
					max_error=maxf(max_error,absf(seam_hit.position.y-airport.PAVEMENT_TOP))
					if absf(seam_hit.position.y-airport.PAVEMENT_TOP)>0.002: print("SEAM_ERROR ",runway.id," station=",station," lane=",lane," position=",seam_hit.position," collider=",seam_hit.collider.name)
		verify(missing==0 and max_error<0.002,"flush runway wheel lanes "+str(runway.id)+" max_error="+str(max_error))
	for label in ["International_Apron","Domestic_Apron","Hangar_Apron"]:
		var apron = airport.get_node(label)
		var apron_query = PhysicsRayQueryParameters3D.create(apron.global_position+Vector3.UP,apron.global_position-Vector3.UP)
		var apron_hit = space.intersect_ray(apron_query)
		verify(not apron_hit.is_empty() and absf(apron_hit.position.y-airport.PAVEMENT_TOP)<0.002,"flush apron "+label)
	var physical_taxi_count := 0
	var taxi_max_error := 0.0
	for candidate in airport.get_children():
		if candidate is StaticBody3D and "_pavement_" in str(candidate.name):
			physical_taxi_count += 1
			for child in candidate.get_children():
				if child is CollisionShape3D and child.shape is BoxShape3D:
					var top = candidate.global_position.y+child.shape.size.y*0.5
					taxi_max_error=maxf(taxi_max_error,absf(top-airport.PAVEMENT_TOP))
	verify(physical_taxi_count>20 and taxi_max_error<0.002,"all taxi and exit colliders flush count="+str(physical_taxi_count))
	var seam_sample := Vector3(-2929.39,7.5,10689.63)
	var impact_query = PhysicsRayQueryParameters3D.create(seam_sample,seam_sample-Vector3.UP*2)
	var impact_hit = space.intersect_ray(impact_query)
	verify(not impact_hit.is_empty() and absf(impact_hit.position.y-airport.PAVEMENT_TOP)<0.002,"reported takeoff seam now flush")
	verify(absf(airport.anchors.runway_start.y-airport.PAVEMENT_TOP)<0.002 and absf(airport.anchors.runway_end.y-airport.PAVEMENT_TOP)<0.002,"runway spawn anchors use physical surface datum")
	var at = airport._panels.values()[0].node.global_position
	var count = airport.apply_impact(at,90)
	verify(count>0,"airport collision removes local facade geometry")
	var state = JSON.parse_string(JSON.stringify(airport.get_state()))
	airport.apply_state({})
	verify(airport.damaged.is_empty(),"new world restores airport panels")
	airport.apply_state(state)
	verify(airport.damaged.size()==state.damaged.size(),"airport damage restores from JSON")
	verify(airport._fragments.size()==state.fragments.size() and airport._fragments.size()>0,"important airport debris survives JSON save")
	for i in 30: await physics_frame
	print("AIRPORT CHECK COMPLETE failures=",failures," nodes=",airport.get_child_count())
	quit(failures)
