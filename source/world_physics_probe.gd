extends SceneTree
var world
func _initialize(): call_deferred("run")
func run():
 world=load("res://scripts/harbor_world.gd").new()
 root.add_child(world)
 await physics_frame
 await physics_frame
 for key in world.anchors:
  var p=world.anchors[key]
  var query=PhysicsRayQueryParameters3D.create(p+Vector3(0,60,0),p-Vector3(0,10,0))
  var hit=world.get_world_3d().direct_space_state.intersect_ray(query)
  print("ANCHOR ",key," hit=",hit.get("position",Vector3.INF))
 for i in range(11):
  var p=Vector3(-83,54,-662).lerp(Vector3(149,54,-1109),i/10.0)
  var hit=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*3,p-Vector3.UP*8))
  print("BRIDGE ",i," hit=",hit.get("position",Vector3.INF))
 var pre=world.get_state()
 world.damage_at(Vector3(-335,6,-19),1000000,4)
 await physics_frame
 var state=world.get_state()
 print("DAMAGE destroyed=",state.destroyed.size()," rubble=",state.rubble.size())
 world.apply_state(state)
 var after=world.get_state()
 print("RESTORE destroyed_equal=",after.destroyed==state.destroyed," partial_equal=",after.partial==state.partial," rubble_count=",after.rubble.size())
 world.repair_all()
 print("REPAIR ",world.get_state().destroyed.size())
 quit()
