extends SceneTree
const Factory=preload("res://scripts/vehicle_factory.gd")
var checks:=0
var failures:=0
var models:={}
var measurements:={}
var scene:Node3D
func _init():call_deferred("run")
func check(value:bool,label:String):
 checks+=1
 print(("PASS " if value else "FAIL ")+label)
 if not value:failures+=1
func visible_meshes(node: Node3D, result: Array):
 for child in node.get_children():
  if child.is_queued_for_deletion() or not child is Node3D: continue
  if not child.visible: continue
  if child is MeshInstance3D: result.append(child)
  visible_meshes(child,result)

func measure(body: Node3D) -> Dictionary:
 var meshes: Array = []
 visible_meshes(body,meshes)
 var bounds := AABB()
 var first := true
 var triangles := 0
 var invalid := 0
 var bad_normals := 0
 for mesh: MeshInstance3D in meshes:
  var relative := body.global_transform.affine_inverse()*mesh.global_transform
  var box := relative*mesh.mesh.get_aabb()
  bounds = box if first else bounds.merge(box)
  first = false
  for surface in mesh.mesh.get_surface_count():
   var arrays := mesh.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
   var count := indices.size() if not indices.is_empty() else vertices.size()
   triangles += count/3
   for point: Vector3 in vertices:
    if not point.is_finite(): invalid += 1
   for i in range(0,count,3):
    var a := indices[i] if not indices.is_empty() else i
    var c := indices[i+1] if not indices.is_empty() else i+1
    var d := indices[i+2] if not indices.is_empty() else i+2
    if a >= vertices.size() or c >= vertices.size() or d >= vertices.size(): invalid += 1
    elif (vertices[c]-vertices[a]).cross(vertices[d]-vertices[a]).dot(normals[a]+normals[c]+normals[d]) > .000001: bad_normals += 1
 var collision_low := INF
 var colliders := 0
 for child in body.get_children():
  if child is CollisionShape3D:
   colliders += 1
   var shape_bounds: AABB = child.transform*child.shape.get_debug_mesh().get_aabb()
   collision_low = minf(collision_low,shape_bounds.position.y)
 return {"bounds":bounds,"meshes":meshes.size(),"triangles":triangles,"invalid":invalid,"bad_normals":bad_normals,"collision_low":collision_low,"colliders":colliders}

func run():
 scene=Node3D.new();root.add_child(scene)
 for kind in ["glider","paraglider","helicopter"]:
  var body:=RigidBody3D.new();body.freeze=true;scene.add_child(body)
  var moving:=Factory.build(body,kind)
  if moving.rider!=null:moving.rider.visible=true
  models[kind]={"body":body,"moving":moving}
 await process_frame;await process_frame
 for kind in models:
  var body:Node3D=models[kind].body;var info:Dictionary=body.get_meta("vehicle_model",{})
  var metrics:=measure(body);measurements[kind]=metrics
  check(info.size()>0 and info.features.size()>=8,kind+" reference and distinct authored features")
  check(metrics.invalid==0 and metrics.bad_normals==0,kind+" finite exterior geometry and winding")
  check(absf(metrics.collision_low-float(info.ground))<.006,kind+" retained save contact plane")
  check(metrics.meshes<75 and metrics.triangles<105000,kind+" merged render and geometry budget")
  var okay:=false
  if kind=="glider":okay=absf(metrics.bounds.size.x-18.0)<.015 and absf(metrics.bounds.size.z-6.85)<.015 and models[kind].moving.wheels.size()==2
  if kind=="paraglider":okay=absf(metrics.bounds.size.x-9.4)<.02 and info.cells==48 and models[kind].moving.rider!=null and metrics.bounds.end.y>7.0
  if kind=="helicopter":okay=absf(metrics.bounds.size.z-15.67)<.07 and models[kind].moving.rotors.size()==1 and models[kind].moving.propellers.size()==1 and models[kind].moving.wheels.size()==4
  check(okay,kind+" manufacturer scale silhouette and motion assemblies")
  print("AIR_MODEL_METRICS ",kind," ",metrics)
 check(is_equal_approx(models.helicopter.body.get_node("Swept_rotor_collision").shape.radius,6.7),"13.4m swept rotor envelope participates in real collision and safe spawn")
 await physics_frame
 var helicopter:RigidBody3D=models.helicopter.body
 var exclusions:Array[RID]=[models.glider.body.get_rid(),models.paraglider.body.get_rid()]
 var aperture_clear:=true
 for y in [1.10,2.20]:
  var ray:=PhysicsRayQueryParameters3D.create(Vector3(-2,y,7.48),Vector3(2,y,7.48),1,exclusions)
  aperture_clear=aperture_clear and helicopter.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
 check(aperture_clear,"Fenestron aperture is not filled by an invisible tail-fin collider")
 var ring_ray:=PhysicsRayQueryParameters3D.create(Vector3(-2,2.74,7.48),Vector3(2,2.74,7.48),1,exclusions)
 check(not helicopter.get_world_3d().direct_space_state.intersect_ray(ring_ray).is_empty(),"Fenestron perimeter retains solid collision")
 if "--visual" in OS.get_cmdline_user_args():await capture()
 var file:=FileAccess.open("res://../reports/air-vehicle-models.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"models":measurements},"  "));file.close()
 print("AIR MODELS COMPLETE checks=",checks," failures=",failures)
 quit(failures)
func capture() -> void:
 root.size=Vector2i(1600,1000)
 var env_node := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode=Environment.BG_COLOR
 env.background_color=Color("8dabbc")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color=Color("d5e3ed")
 env.ambient_light_energy=.72
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 env_node.environment=env
 scene.add_child(env_node)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-37,-38,0)
 sun.light_energy=1.4
 sun.shadow_enabled=true
 scene.add_child(sun)
 var floor_mesh := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size=Vector2(180,180)
 floor_mesh.mesh=plane
 floor_mesh.material_override=Factory.material(Color("879092"),0,.93)
 scene.add_child(floor_mesh)
 var camera := Camera3D.new()
 camera.current=true
 camera.fov=48
 camera.far=500
 scene.add_child(camera)
 var directory := ProjectSettings.globalize_path("res://../reports/air-vehicle-models")
 DirAccess.make_dir_recursive_absolute(directory)
 for shot in [["glider-front","glider",Vector3(14,6,-13),Vector3(0,.3,0)],["glider-rear","glider",Vector3(-12,5,14),Vector3(0,.5,0)],["glider-cockpit","glider",Vector3(2.5,1.6,-4.7),Vector3(0,.1,-1.6)],["paraglider-front","paraglider",Vector3(11,8,-14),Vector3(0,3.7,.3)],["paraglider-rear","paraglider",Vector3(-10,7,13),Vector3(0,3.7,.3)],["helicopter-front","helicopter",Vector3(15,6,-16),Vector3(0,.8,1)],["helicopter-rear","helicopter",Vector3(-15,6,18),Vector3(0,1,2)],["helicopter-side","helicopter",Vector3(18,3,1),Vector3(0,1,2)]]:
  for kind:String in models:models[kind].body.visible=kind==shot[1]
  floor_mesh.position.y=float(models[shot[1]].body.get_meta("vehicle_model").ground)-.02
  camera.position=shot[2];camera.look_at(shot[3])
  for frame in 12:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(directory.path_join(str(shot[0])+".png"))
  print("AIR_MODEL_CAPTURE ",shot[0])
