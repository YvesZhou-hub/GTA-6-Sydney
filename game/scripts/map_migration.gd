extends RefCounted
## One-time safety migration when loading a world made before real city geometry.
const REVISION := 6 # Photo-refined buildings, walkable foyers and marine access.
const Spawn=preload("res://scripts/vehicle_spawn.gd")
const City=preload("res://scripts/city_map.gd")

static func _custom_id(id:String) -> bool:
	return id.begins_with("city/") or id.begins_with("bank/") or id.begins_with("manly/") or id.begins_with("quay/") or id.begins_with("metro/") or id.begins_with("darling_square/") or id.begins_with("cyber/") or id.begins_with("icc/") or id.begins_with("sydney_tower/") or id.begins_with("circular_quay/") or id.begins_with("darling_detail/") or id.begins_with("opera/")

static func _geometry(world:Node3D) -> Dictionary:
	if world.has_meta("map_migration_cache"):return world.get_meta("map_migration_cache")
	var mapped:Array=[]
	for item in world.map_snapshot.buildings:
		if City._reserved(world,item):continue
		var center:=Vector2(item.center[0],item.center[1])
		var poly:=City.polygon(item.outline)
		if poly.is_empty():continue
		for i in poly.size():poly[i]+=center
		var box:=Rect2(poly[0],Vector2.ZERO)
		for point in poly:box=box.expand(point)
		var holes:Array=[]
		for hole in item.get("holes",[]):
			var court:=City.polygon(hole)
			for i in court.size():court[i]+=center
			holes.append(court)
		var wall_height:float=item.get("wall_height",item.height)
		var roof_triangles:Array=[]
		var roof_high:float=world.GROUND+wall_height
		var surface:Array=item.get("roof_surface",[])
		for i in range(0,surface.size(),3):
			var a:=Vector3(center.x+surface[i][0],world.GROUND+surface[i][1],center.y+surface[i][2])
			var b:=Vector3(center.x+surface[i+1][0],world.GROUND+surface[i+1][1],center.y+surface[i+1][2])
			var c:=Vector3(center.x+surface[i+2][0],world.GROUND+surface[i+2][1],center.y+surface[i+2][2])
			var normal:Vector3=(b-a).cross(c-a)
			# Vertical gable infills have zero projected area. Roof occupancy is
			# the actual pitched surface down to its eave, not its bounding prism.
			if absf(normal.y)<0.00001:continue
			var triangle:=PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
			var rectangle:=Rect2(triangle[0],Vector2.ZERO).expand(triangle[1]).expand(triangle[2])
			roof_triangles.append({"poly":triangle,"rect":rectangle,"a":a,"normal":normal})
			roof_high=maxf(roof_high,maxf(a.y,maxf(b.y,c.y)))
		mapped.append({"id":item.id,"poly":poly,"holes":holes,"rect":box,"low":world.GROUND+item.base,"high":world.GROUND+wall_height,"groups":maxi(1,mini(8,int(ceil((wall_height-item.base)/18.0)))),"roof_high":roof_high,"roof_triangles":roof_triangles})
	var custom:Array=[]
	for id in world.structures:
		if not _custom_id(str(id)):continue
		var part:Dictionary=world.structures[id]
		var bounds: AABB=Transform3D(part.basis,part.position)*AABB(-part.half,part.half*2)
		custom.append({"id":str(id),"bounds":bounds,"node":part.node})
	var result:={"mapped":mapped,"custom":custom}
	world.set_meta("map_migration_cache",result)
	return result

static func _live_height(world:Node3D,item:Dictionary,bounds:AABB) -> bool:
	for level in int(item.groups):
		var low:float=lerpf(item.low,item.high,float(level)/item.groups)
		var high:float=lerpf(item.low,item.high,float(level+1)/item.groups)
		if bounds.position.y>=high-0.015 or bounds.end.y<=low+0.015:continue
		var id:String="osm/%s/storey_group/%s"%[item.id,level]
		if world.structures.has(id) and not world.destroyed.has(id):return true
	return false

static func overlaps_new_building(world: Node3D, bounds: AABB) -> bool:
	var rectangle:=Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))
	var corners:=PackedVector2Array([rectangle.position,rectangle.position+Vector2(rectangle.size.x,0),rectangle.end,rectangle.position+Vector2(0,rectangle.size.y)])
	var geometry:=_geometry(world)
	for item in geometry.mapped:
		if bounds.position.y>=item.roof_high-.015 or bounds.end.y<=item.low+.015:continue
		if not rectangle.intersects(item.rect):continue
		if Geometry2D.intersect_polygons(corners,item.poly).is_empty():continue
		var inside_court:=false
		for court in item.holes:
			# Corner-only containment misses masonry protruding into concave courts.
			if Geometry2D.clip_polygons(corners,court).is_empty():inside_court=true;break
		if inside_court:continue
		if _live_height(world,item,bounds) or _roof_overlap(world,item,bounds,rectangle,corners):return true
	return _overlaps_custom(world,bounds,geometry.custom)

static func _roof_overlap(world:Node3D,item:Dictionary,bounds:AABB,rectangle:Rect2,corners:PackedVector2Array) -> bool:
	var id:String="osm/%s/roof"%item.id
	if item.roof_triangles.is_empty() or not world.structures.has(id) or world.destroyed.has(id):return false
	if bounds.end.y<=item.high+.015 or bounds.position.y>=item.roof_high-.015:return false
	for face:Dictionary in item.roof_triangles:
		if not rectangle.intersects(face.rect):continue
		for clipped:PackedVector2Array in Geometry2D.intersect_polygons(corners,face.poly):
			for p:Vector2 in clipped:
				var height:float=face.a.y-(face.normal.x*(p.x-face.a.x)+face.normal.z*(p.y-face.a.z))/face.normal.y
				if bounds.position.y<height-.015:return true
	return false

static func _overlaps_custom(world:Node3D,bounds:AABB,parts:Array) -> bool:
	var candidates:Array=[]
	for part in parts:
		if not world.destroyed.has(part.id) and bounds.intersects(part.bounds):candidates.append(part)
	if candidates.is_empty():return false
	# The physical box query catches crossing a solid primitive or a mesh wall.
	var shape:=BoxShape3D.new();shape.size=bounds.size
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape;query.transform.origin=bounds.get_center();query.collision_mask=15;query.margin=.001
	for hit in world.get_world_3d().direct_space_state.intersect_shape(query,128):
		var collider=hit.collider
		if collider.has_meta("damage_id"):
			var id:String=str(collider.get_meta("damage_id"))
			if _custom_id(id) and not world.destroyed.has(id):return true
	# A trimesh collider is only a shell. Detect complete containment in closed
	# authored solids too; raised buildings and open halls remain traversable.
	var points:Array[Vector3]=[bounds.get_center()]
	for i in 8:points.append(bounds.get_endpoint(i))
	for part in candidates:
		for collision in part.node.get_children():
			if not collision is CollisionShape3D or not collision.shape is ConcavePolygonShape3D:continue
			var faces:PackedVector3Array=collision.shape.get_faces()
			if not collision.has_meta("migration_closed"):
				collision.set_meta("migration_closed",_closed_mesh(faces))
			if not collision.get_meta("migration_closed"):continue
			for point in points:
				if _inside_mesh(collision.global_transform.affine_inverse()*point,faces):return true
	return false

static func _closed_mesh(faces:PackedVector3Array) -> bool:
	var edges:Dictionary={}
	for i in range(0,faces.size(),3):
		for side in 3:
			var a:String=str(faces[i+side].snapped(Vector3.ONE*.001))
			var b:String=str(faces[i+(side+1)%3].snapped(Vector3.ONE*.001))
			if a==b:continue
			var key:String=a+"|"+b if a<b else b+"|"+a
			edges[key]=int(edges.get(key,0))+1
	if edges.is_empty():return false
	for count in edges.values():
		if count!=2:return false
	return true

static func _inside_mesh(point:Vector3,faces:PackedVector3Array) -> bool:
	var endpoint:=point+Vector3(17003.7,2911.3,4317.9)
	var distances:Array[float]=[]
	for i in range(0,faces.size(),3):
		var hit=Geometry3D.segment_intersects_triangle(point,endpoint,faces[i],faces[i+1],faces[i+2])
		if hit is Vector3:distances.append(point.distance_to(hit))
	distances.sort()
	var crossings:=0
	var previous:=-INF
	for distance in distances:
		if distance-previous>.001:crossings+=1;previous=distance
	return crossings%2==1

static func _player_needs_relocation(game:Node3D,at:Vector3) -> bool:
	var bounds:=AABB(at+Vector3(-.32,0,-.32),Vector3(.64,1.8,.64))
	if not overlaps_new_building(game.world,bounds):return false
	# A standing capsule clears an uphill tread while the corners of its AABB
	# enter the slope. Use the actual registered support and production capsule to verify standing.
	var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.12,at-Vector3.UP*.25,15,[game.player.get_rid()])
	var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y<.9:return true
	var id:String=str(hit.collider.get_meta("damage_id",""))
	if not _custom_id(id) or not game.world.structures.has(id):return true
	# The controller capsule begins 10mm above its foot origin. Jolt can settle
	# that origin up to 10mm below either a flat floor or a sloping support.
	# A real floor hit alone is insufficient: the capsule and closed torso/head
	# tests below must both be clear, including complete containment in a mesh.
	var foot_allowance:=.01
	if game.world.destroyed.has(id) or at.y<hit.position.y-foot_allowance or at.y-hit.position.y>.10:return true
	var capsule:CollisionShape3D=null
	for child in game.player.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			capsule=child;break
	if capsule==null:return true
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=capsule.shape;query.transform=capsule.global_transform
	query.transform.origin+=at-game.player.global_position
	query.collision_mask=15;query.exclude=[game.player.get_rid()];query.margin=0.0
	if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return true
	# Retain closed-solid containment checks for the torso/head. Only the empty
	# AABB corners below the rounded capsule foot may overlap its support slope.
	return overlaps_new_building(game.world,AABB(at+Vector3(-.32,.25,-.32),Vector3(.64,1.55,.64)))

static func _player_pose(game: Node3D, near: Vector3) -> Vector3:
	var capsule:=CapsuleShape3D.new()
	capsule.radius=0.34
	capsule.height=1.8
	for ring in range(0,45):
		for step in 16:
			var angle:=step*TAU/16.0
			var p:=near+Vector3(cos(angle),0,sin(angle))*ring*4.0
			var ray:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*80,p-Vector3.UP*100,15,[game.player.get_rid()])
			var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
			if not Spawn._ground_allowed(hit): continue
			p=hit.position+Vector3.UP*0.04
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=capsule
			query.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*0.91)
			query.collision_mask=15
			query.exclude=[game.player.get_rid()]
			if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
			if overlaps_new_building(game.world,AABB(p+Vector3(-.34,0,-.34),Vector3(.68,1.82,.68))):continue
			return p
	return Vector3.INF

static func apply(game: Node3D) -> int:
	var shifted:=0
	var saved_player:Vector3=game.player.global_position
	var saved_yaw:float=game.yaw
	for body in game.vehicles:
		var bounds:AABB=body.global_transform*Spawn.envelope(body)
		if not overlaps_new_building(game.world,bounds): continue
		# Search relative to each stored copy, never gather a distant fleet around
		# the player. IDs, health, fuel, ownership and all unrelated saves survive.
		game.player.global_position=body.global_position
		game.yaw=body.rotation.y
		var placement:=Spawn.find_spawn(game,body)
		if placement.is_empty(): continue
		body.global_transform=placement.transform
		body.stop_motion_after_relocation()
		body.freeze=bool(placement.get("airborne",false)) or body.freeze
		body.reset_physics_interpolation()
		shifted+=1
	game.player.global_position=saved_player
	game.yaw=saved_yaw
	if _player_needs_relocation(game,saved_player):
		var replacement:=_player_pose(game,saved_player)
		if replacement.is_finite():
			game.player.global_position=replacement
			game.player.last_safe=replacement
			game.player.reset_physics_interpolation()
			shifted+=1
	return shifted

static func _on_old_north_approach(contact:Vector3) -> bool:
	# v0.1.1's retired straight ramp, retained solely for save compatibility.
	var start:=Vector3(-83,54,-662)+Vector3(232,0,-447).normalized()*503.0
	var end:=Vector3(353.49108752,4.5,-1502.99791431)
	var delta:=Vector2(end.x-start.x,end.z-start.z)
	var relative:=Vector2(contact.x-start.x,contact.z-start.z)
	var fraction:=relative.dot(delta)/delta.length_squared()
	if fraction<0 or fraction>1:return false
	return relative.distance_to(delta*fraction)<25.5 and absf(contact.y-lerpf(start.y,end.y,fraction))<1.6

static func _near_support(game:Node3D,contact:Vector3,excluded:Array[RID]) -> bool:
	var ray:=PhysicsRayQueryParameters3D.create(contact+Vector3.UP*.4,contact+Vector3.DOWN*.6,15,excluded)
	return not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

static func repair_old_approach(game:Node3D,occupied_id:String) -> int:
	var shifted:=_repair_old_south_approach(game,occupied_id)
	for body in game.vehicles:
		if not body.kind in ["car","motorcycle","airliner"]:continue
		if body.kind=="airliner" and (body.linear_velocity.length()>1.0 or body.angular_velocity.length()>0.2 or absf(body.rotation.x)>0.15 or absf(body.rotation.z)>0.15):continue
		var contact:Vector3=body.global_position+Vector3.UP*Spawn.envelope(body).position.y
		if not _on_old_north_approach(contact):continue
		if _near_support(game,contact,[body.get_rid(),game.player.get_rid()]):continue
		var placement:=Spawn.find_spawn(game,body,false,body.global_transform)
		if placement.is_empty():continue
		body.global_transform=placement.transform
		body.stop_motion_after_relocation()
		body.reset_physics_interpolation()
		shifted+=1
	if occupied_id.is_empty() and _on_old_north_approach(game.player.global_position) and not _near_support(game,game.player.global_position,[game.player.get_rid()]):
		var replacement:=_player_pose(game,game.player.global_position)
		if replacement.is_finite():
			game.player.global_position=replacement
			game.player.last_safe=replacement
			game.player.reset_physics_interpolation()
			shifted+=1
	return shifted

static func _on_old_south_approach(contact:Vector3) -> bool:
	# Exact v0.1.1 south support plane, not a broad area around the harbour.
	var start:=Vector3(-325.70848036,4.5,-194.3677124)
	var end:=Vector3(-83,54,-662)
	var delta:=Vector2(end.x-start.x,end.z-start.z)
	var relative:=Vector2(contact.x-start.x,contact.z-start.z)
	var fraction:=relative.dot(delta)/delta.length_squared()
	if fraction<0.0 or fraction>1.0:return false
	return relative.distance_to(delta*fraction)<25.5 and absf(contact.y-lerpf(start.y,end.y,fraction))<1.6

static func _old_south_has_support(game:Node3D,contact:Vector3,excluded:Array[RID]) -> bool:
	var ray:=PhysicsRayQueryParameters3D.create(contact+Vector3.UP*.4,contact+Vector3.DOWN*.6,15,excluded)
	var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
	# A ray from inside the new bridge skin can hit its downward-facing bottom.
	# That is not a surviving road or legitimate platform under the saved wheels.
	return Spawn._ground_allowed(hit)

static func _new_south_surface(contact:Vector3) -> Dictionary:
	var bridge=preload("res://scripts/bridge_landmark.gd")
	var start:Vector3=bridge.SOUTH_ENTRY
	var end:Vector3=bridge.pos(0)
	var delta:=Vector2(end.x-start.x,end.z-start.z)
	var relative:=Vector2(contact.x-start.x,contact.z-start.z)
	var fraction:=relative.dot(delta)/delta.length_squared()
	if fraction<0.0 or fraction>1.0:return {}
	var frame:Basis=bridge.ramp_basis("south",fraction)
	# Preserve X/Z where the revised support still passes under the old parking
	# place. Only the reference plane's height and orientation need adjustment.
	var point:=Vector3(contact.x,lerpf(start.y,end.y,fraction),contact.z)
	return {"point":point,"normal":frame.y.normalized()}

static func _repair_old_south_approach(game:Node3D,occupied_id:String) -> int:
	var shifted:=0
	for body in game.vehicles:
		if not body.kind in ["car","motorcycle","airliner"]:continue
		if body.linear_velocity.length()>1.0 or body.angular_velocity.length()>0.2:continue
		if absf(body.rotation.x)>0.15 or absf(body.rotation.z)>0.15:continue
		var bounds:AABB=Spawn.envelope(body)
		var contact:Vector3=body.global_position+Vector3.UP*bounds.position.y
		if not _on_old_south_approach(contact):continue
		if _old_south_has_support(game,contact,[body.get_rid(),game.player.get_rid()]):continue
		var surface:=_new_south_surface(contact)
		var placement:Dictionary={}
		if not surface.is_empty() and _old_south_has_support(game,surface.point,[body.get_rid(),game.player.get_rid()]):
			var normal:Vector3=surface.normal
			var forward:Vector3=(-body.global_basis.z).slide(normal).normalized()
			var basis:=Basis.looking_at(forward,normal)
			var pose:=Transform3D(basis,surface.point-normal*bounds.position.y+normal*.12)
			if Spawn.clear_envelope(game,body,pose):placement={"transform":pose}
		if placement.is_empty():placement=Spawn.find_spawn(game,body,false,body.global_transform)
		if placement.is_empty():continue
		body.global_transform=placement.transform
		body.reset_physics_interpolation()
		shifted+=1
	if not occupied_id.is_empty() or game.player.velocity.length()>1.0:return shifted
	var saved:Vector3=game.player.global_position
	if not _on_old_south_approach(saved) or _old_south_has_support(game,saved,[game.player.get_rid()]):return shifted
	var surface:=_new_south_surface(saved)
	var replacement:=Vector3.INF
	if not surface.is_empty() and _old_south_has_support(game,surface.point,[game.player.get_rid()]):
		var candidate:Vector3=surface.point+Vector3.UP*.04
		var capsule:=CapsuleShape3D.new();capsule.radius=.34;capsule.height=1.8
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=capsule;query.transform.origin=candidate+Vector3.UP*.91
		query.collision_mask=15;query.exclude=[game.player.get_rid()];query.margin=.001
		if game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():replacement=candidate
	if not replacement.is_finite():replacement=_player_pose(game,saved)
	if replacement.is_finite():
		game.player.global_position=replacement
		game.player.last_safe=replacement
		game.player.reset_physics_interpolation()
		shifted+=1
	return shifted
