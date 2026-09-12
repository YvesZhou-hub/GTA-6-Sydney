extends RefCounted
## Sweep the complete moving hull before Jolt resolves contacts. Destroyed bodies
## get one-frame collision exceptions while their deferred shape removal flushes.
const MAX_CONTACTS := 48
var _exceptions: Array[WeakRef] = []
var _effect_cooldown := 0.0
var hits := 0
var _hulls: Array = []

func clear(body: RigidBody3D) -> void:
	for reference in _exceptions:
		var other = reference.get_ref()
		if is_instance_valid(other): body.remove_collision_exception_with(other)
	_exceptions.clear()

func _physical_hulls(body:RigidBody3D) -> Array:
	if not _hulls.is_empty(): return _hulls
	var sole:=INF
	for node in body.get_children():
		if node is CollisionShape3D and node.shape!=null:
			var bounds:AABB=node.transform*node.shape.get_debug_mesh().get_aabb()
			sole=minf(sole,bounds.position.y)
	for node in body.get_children():
		if not node is CollisionShape3D or node.shape==null: continue
		var shape:Shape3D=node.shape
		var pose:Transform3D=node.transform
		if body.kind=="tank":
			# Crop the physical hull above the tread contact plane. Never use the
			# decorative gun's cached spawn envelope as a forward battering ram.
			var points:PackedVector3Array=shape.get_debug_mesh().get_faces()
			var clipped:=PackedVector3Array()
			var highest:=-INF
			for point:Vector3 in points:
				var p:Vector3=pose*point
				highest=maxf(highest,p.y)
				p.y=maxf(p.y,sole+0.32)
				clipped.append(p)
			if highest<=sole+0.33: continue
			var convex:=ConvexPolygonShape3D.new()
			convex.points=clipped
			shape=convex;pose=Transform3D.IDENTITY
		_hulls.append({"shape":shape,"pose":pose})
	return _hulls

func tick(body: RigidBody3D, game: Node3D, delta: float) -> void:
	clear(body)
	_effect_cooldown = maxf(0.0,_effect_cooldown-delta)
	if not is_instance_valid(game) or not body.occupied or body.linear_velocity.length()<0.8: return
	var query := PhysicsShapeQueryParameters3D.new()
	query.margin=0.01
	query.collision_mask=15
	query.exclude=[body.get_rid()]
	var motion := body.linear_velocity*delta*1.25
	var space := body.get_world_3d().direct_space_state
	var broken := 0
	var impact_point := body.global_position
	for hull:Dictionary in _physical_hulls(body):
		if query.exclude.size()>=MAX_CONTACTS: break
		query.shape=hull.shape
		var start:Transform3D=body.global_transform*hull.pose
		for iteration in MAX_CONTACTS:
			query.transform=start
			query.motion=Vector3.ZERO
			var contacts := space.intersect_shape(query,MAX_CONTACTS)
			if contacts.is_empty():
				query.motion=motion
				var fraction := space.cast_motion(query)
				if fraction.size()<2 or fraction[0]>=1.0: break
				query.transform.origin+=motion*minf(1.0,fraction[1]+0.001)
				query.motion=Vector3.ZERO
				contacts=space.intersect_shape(query,MAX_CONTACTS)
				if contacts.is_empty(): break
			var rest:=space.get_rest_info(query)
			for contact in contacts:
				var other = contact.collider
				var exclusions := query.exclude
				if contact.rid in exclusions: continue
				exclusions.append(contact.rid)
				query.exclude=exclusions
				if not is_instance_valid(other): continue
				var point:Vector3=rest.point if rest.get("rid")==contact.rid else query.transform.origin
				if game.break_combat_contact(body,other,point):
					broken+=1
					hits+=1
					impact_point=point
					if other is PhysicsBody3D:
						body.add_collision_exception_with(other)
						_exceptions.append(weakref(other))
			if query.exclude.size()>=MAX_CONTACTS: break
	if broken>0 and _effect_cooldown<=0.0:
		_effect_cooldown=0.14
		game.combat_ram_feedback(body,impact_point,broken)
