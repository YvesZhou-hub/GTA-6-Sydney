extends SceneTree
## Real CPU building meshes, collision, shop approaches, destruction and migration.
const City=preload("res://scripts/city_map.gd")
const Migration=preload("res://scripts/map_migration.gd")
const Fronts=preload("res://scripts/darling_square_frontages.gd")
const Details=preload("res://scripts/darling_square_detail.gd")
class LocalSquare extends "res://scripts/harbor_world.gd":
 func _ready():
  _make_materials();map_snapshot=CityMap.data()
  map_snapshot.buildings=map_snapshot.buildings.filter(func(b):return Vector2(b.center[0]+780,b.center[1]-2040).length()<250)
  CityMap.build_terrain(self,map_snapshot);CityMap.build_buildings(self,map_snapshot)
  Fronts.build(self);Details.build(self)
  _build_structure_batches();_ready_complete=true
var checks:Array=[]
func _initialize():call_deferred("run")
func check(name:String,passed:bool):
 checks.append({"name":name,"passed":passed});print(("PASS " if passed else "FAIL ")+name)
func frames():await physics_frame;await physics_frame
func run():
 var world:=LocalSquare.new();root.add_child(world);await frames()
 var id:="osm/way/614603732/storey_group/0"
 check("tagged 0-18 m Darling Square podium exists",world.structures.has(id))
 if not world.structures.has(id):quit(1);return
 var parent:Dictionary=world.structures[id]
 var arrays:Array=parent.surfaces[0].arrays
 var low:=INF;var high:=-INF
 for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:low=minf(low,point.y);high=maxf(high,point.y)
 check("base has rendered physical volume from ground through 18 m",is_equal_approx(low,0) and is_equal_approx(high,18) and parent.node.get_child(0).shape.get_faces().size()>0)
 var child_ids:=["way/614603733","way/614603734","way/614603735","way/614603736"]
 var correct_parts:=true
 for child:String in child_ids:
  var key:="osm/"+child+"/storey_group/0"
  correct_parts=correct_parts and world.structures.has(key)
  if world.structures.has(key):
   var part:Dictionary=world.structures[key]
   correct_parts=correct_parts and is_equal_approx(part.position.y-part.half.y,world.GROUND+18)
 check("all four residential parts retain their original 18 m base",correct_parts)
 var exchange=world.map_snapshot.buildings.filter(func(b):return b.id=="way/614603737")[0]
 check("custom Exchange wins over a retained-base policy",exchange.parent_geometry_policy.mode=="preserve_tagged_base" and City._reserved(world,exchange) and not world.structures.has("osm/way/614603737/storey_group/0"))
 var suppressed=world.map_snapshot.buildings.filter(func(b):return b.id=="way/614603728")[0]
 check("overlapping or inferred neighbouring parent remains suppressed",City._reserved(world,suppressed))
 var mapped:Array=Migration._geometry(world).mapped
 check("migration uses exactly the same retained podium geometry",mapped.any(func(b):return b.id=="way/614603732" and is_equal_approx(b.low,4.5) and is_equal_approx(b.high,22.5)))
 var inside:=AABB(Vector3(-707,10,2029),Vector3.ONE)
 check("old save inside new podium is detected",Migration.overlaps_new_building(world,inside))
 var shape:=CapsuleShape3D.new();shape.radius=.32;shape.height=1.8
 var space=world.get_world_3d().direct_space_state
 for shop in Fronts.metadata()+Details.metadata():
  var body:StaticBody3D=world.structures["darling_square/"+shop.id+"/frontage"].node
  var at:Vector3=body.get_meta("door_approach")
  # Stand above the actual public paving, whose top is 12 cm above the
  # generic terrain. The capsule represents feet-to-head player clearance.
  var support_query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,world.GROUND+2,at.z),Vector3(at.x,world.GROUND-1,at.z))
  var support:Dictionary=space.intersect_ray(support_query)
  var walkable:bool=not support.is_empty() and support.normal.y>.95 and support.position.y<=world.GROUND+.3
  at.y=(support.position.y if walkable else world.GROUND)+shape.height*.5+.1
  var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=at
  var hits:Array=space.intersect_shape(query)
  if not hits.is_empty():
   var ids:=[]
   for hit in hits:ids.append(str(hit.collider.get_meta("damage_id",hit.collider.name)))
   print("PODIUM_DOOR_CONTACT ",shop.id," at=",at," colliders=",ids)
  check(shop.id+" door approach remains physically clear",walkable and hits.is_empty())
 for shop in Details.metadata():
  var normal:=Vector3(shop.normal[0],0,shop.normal[1]);var point:Vector3=shop.center+Vector3.UP*10
  var query:=PhysicsRayQueryParameters3D.create(point+normal*3,point-normal*3)
  var hit:Dictionary=space.intersect_ray(query)
  check(shop.id+" has a solid podium behind its frontage",not hit.is_empty() and str(hit.collider.get_meta("damage_id","")).begins_with("osm/way/614603732/"))
 world._destroy_component(id,Vector3.ZERO,0,false);await frames()
 check("destroyed podium no longer traps saved occupants",not Migration.overlaps_new_building(world,inside) and parent.node.get_child(0).disabled)
 var saved:Dictionary=JSON.parse_string(JSON.stringify(world.get_state()))
 world.repair_all();await frames()
 check("repair restores the physical podium",Migration.overlaps_new_building(world,inside) and not parent.node.get_child(0).disabled)
 world.apply_state(saved);await frames()
 check("saved destruction restores only the podium hole",not Migration.overlaps_new_building(world,inside) and world.structures.has("osm/way/614603734/storey_group/0"))
 var okay:bool=checks.all(func(c):return c.passed)
 FileAccess.open("res://../reports/city-parent-base.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":okay,"checks":checks,"user_saves_touched":false},"  "))
 print("CITY_PARENT_BASE checks=",checks.size()," passed=",okay)
 quit(0 if okay else 1)
