extends Node
## Production request/entry and native integration; never reads or writes a user save.
var checks:Array=[]
var scenarios:Array=[]
var game
func _ready():call_deferred("run")
func check(label:String,pass_value:bool,detail:Dictionary={}):
 checks.append({"name":label,"passed":pass_value,"detail":detail})
 print("AIR_FLIGHT ","PASS " if pass_value else "FAIL ",label," ",JSON.stringify(detail))
func run():
 game=get_parent()
 game.qa_running=true
 game.new_world("sandbox","Flight regression fixture - never saved",false)
 game.set_process(false);game.player.enabled=false
 for parked in game.vehicles:parked.freeze=true
 await get_tree().physics_frame
 await get_tree().physics_frame
 for kind in ["glider","paraglider"]:
  game.current_vehicle=null;game.player.global_position=game.world.anchors.get("marina",Vector3(0,5,0));game.yaw=0
  var wing=game.request_vehicle(kind)
  check("production request immediately occupies "+kind,wing!=null and wing==game.current_vehicle and wing.occupied and not wing.freeze)
  if wing==null:continue
  var start:Vector3=wing.global_position
  var immediate_state:Dictionary=JSON.parse_string(JSON.stringify(wing.get_state()))
  var initial_speed:float=Vector3(immediate_state.velocity[0],immediate_state.velocity[1],immediate_state.velocity[2]).length()
  check("saving before first integration retains launch energy "+kind,initial_speed>(27 if kind=="glider" else 9),{"saved_speed":initial_speed})
  var metrics:Array=[]
  var lowest_speed:=INF;var worst_sink:=0.0;var max_roll:=0.0
  var first_second_loss:=0.0;var first_three_seconds_loss:=0.0;var stalled_frames:=0
  var initial_energy:=0.0
  for frame in range(900):
   await get_tree().physics_frame
   if frame==2:initial_energy=9.81*wing.position.y+0.5*wing.linear_velocity.length_squared()
   if frame>2:
    lowest_speed=minf(lowest_speed,wing.linear_velocity.length())
    worst_sink=minf(worst_sink,wing.linear_velocity.y)
    max_roll=maxf(max_roll,absf(wing.rotation.z))
    if wing.stalled:stalled_frames+=1
   if frame==59:first_second_loss=start.y-wing.position.y
   if frame==179:first_three_seconds_loss=start.y-wing.position.y
   if frame in [0,1,2,59,179,299,599,899]:metrics.append({"frame":frame+1,"position":[wing.position.x,wing.position.y,wing.position.z],"velocity":[wing.linear_velocity.x,wing.linear_velocity.y,wing.linear_velocity.z],"stalled":wing.stalled})
  var distance:=Vector2(wing.position.x-start.x,wing.position.z-start.z).length()
  var final_energy:float=9.81*wing.position.y+.5*wing.linear_velocity.length_squared()
  check("newly summoned wing has sustainable launch speed "+kind,lowest_speed>(14 if kind=="glider" else 6),{"initial_speed":initial_speed,"lowest_speed":lowest_speed})
  check("spawn provides usable flying height "+kind,start.y>=(180 if kind=="glider" else 120),{"height":start.y})
  check("launch immediately settles into glide without a drop "+kind,first_second_loss<.8 and first_three_seconds_loss<3.5 and stalled_frames==0,{"first_second_loss":first_second_loss,"first_three_seconds_loss":first_three_seconds_loss,"stalled_frames_after_activation":stalled_frames})
  check("fifteen seconds unpowered stable flight "+kind,wing.health==100 and wing.position.y>start.y-22 and distance>(220 if kind=="glider" else 100) and worst_sink>-2 and max_roll<.2,{"altitude_lost":start.y-wing.position.y,"distance":distance,"worst_sink":worst_sink,"max_roll":max_roll,"health":wing.health})
  check("gliding does not add mechanical energy "+kind,final_energy<initial_energy*1.01,{"initial":initial_energy,"final":final_energy})
  scenarios.append({"kind":kind,"samples":metrics})
  var before_reentry:Vector3=wing.linear_velocity
  wing.occupied=false;wing.prepare_for_boarding(false);wing.occupied=true
  check("ordinary reboarding adds no launch energy "+kind,not wing._launch_pending and wing.linear_velocity==before_reentry)
  var saved_live:Dictionary=JSON.parse_string(JSON.stringify(wing.get_state()))
  var restored:RigidBody3D=load("res://scripts/harbor_vehicle.gd").new()
  restored.configure(kind,"restore_"+kind);restored.apply_state(saved_live)
  game.add_child(restored);restored.add_collision_exception_with(wing);wing.add_collision_exception_with(restored);restored.occupied=true
  wing.freeze=true;wing.occupied=false
  await get_tree().physics_frame;await get_tree().physics_frame;await get_tree().physics_frame
  check("airborne save preserves live motion through activation "+kind,restored.linear_velocity.distance_to(before_reentry)<.30 and restored.health==100,{"saved_velocity":[before_reentry.x,before_reentry.y,before_reentry.z],"restored_velocity":[restored.linear_velocity.x,restored.linear_velocity.y,restored.linear_velocity.z]})
  restored.queue_free()
  var just_spawned:RigidBody3D=load("res://scripts/harbor_vehicle.gd").new()
  just_spawned.configure(kind,"restore_pending_"+kind);just_spawned.apply_state(immediate_state);game.add_child(just_spawned);just_spawned.occupied=true
  await get_tree().physics_frame;await get_tree().physics_frame;await get_tree().physics_frame
  check("immediate summon save reload has launch speed "+kind,just_spawned.linear_velocity.length()>(27 if kind=="glider" else 9))
  just_spawned.queue_free()
  wing.freeze=true;wing.occupied=false
 var report={"physics_engine":ProjectSettings.get_setting("physics/3d/physics_engine"),"checks":checks,"scenarios":scenarios,"user_saves_touched":false}
 report["full_world"]=game.world._ready_complete
 DirAccess.make_dir_recursive_absolute("user://air-vehicle-qa")
 FileAccess.open("user://air-vehicle-qa/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 game.active=false;game.finish_quit(0 if checks.all(func(c):return c.passed) else 1)
