extends RefCounted
## Larger replacement models may no longer fit an old parking berth.
## Relocate only parked legacy copies; preserve identities, damage, fuel and live flight.
const Spawn=preload("res://scripts/vehicle_spawn.gd")
const REVISION:=3
static func apply(game:Node3D,occupied_id:String) -> Array:
	var adjustments:Array=[]
	var previous=game.current_vehicle
	for v in game.vehicles:
		if v.vehicle_id==occupied_id:game.current_vehicle=v;break
	for v in game.vehicles:
		if int(v.get_meta("loaded_model_revision",REVISION))>=REVISION:continue
		if not v.kind in ["car","motorcycle","airliner","yacht","helicopter"]:continue
		if v.linear_velocity.length()>1.0 or v.angular_velocity.length()>0.2:continue
		if absf(v.rotation.x)>0.15 or absf(v.rotation.z)>0.15:continue
		var before:Transform3D=v.global_transform
		var placement:Dictionary
		if v.kind=="yacht":
			placement=Spawn._water_pose(game,v,before.origin,v.rotation.y)
		else:
			# Start near the old wheel contact, never above an overhead bridge.
			# Unsupported parked-looking aircraft/free-falling cars keep their flight pose.
			var contact:Vector3=before.origin+Vector3.UP*Spawn.envelope(v).position.y
			var ray:=PhysicsRayQueryParameters3D.create(contact+Vector3.UP*0.5,contact+Vector3.DOWN*0.75,15,[v.get_rid(),game.player.get_rid()])
			var support:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
			if support.is_empty():continue
			placement=Spawn._ground_pose(game,v,before.origin,v.rotation.y,support.position.y)
		if placement.is_empty():
			placement=Spawn.find_spawn(game,v,false,before)
		if placement.is_empty():continue
		v.global_transform=placement.transform
		v.reset_physics_interpolation()
		if before.origin.distance_to(v.global_position)>0.35:
			adjustments.append({"id":v.vehicle_id,"kind":v.kind,"before":[before.origin.x,before.origin.y,before.origin.z],"after":[v.global_position.x,v.global_position.y,v.global_position.z]})
	game.current_vehicle=previous
	return adjustments
