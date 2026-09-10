extends SceneTree
## --local is a lightweight production-controller fixture; default uses actual Sydney.
const Validation=preload("res://scripts/air_vehicle_validation.gd")
## Exercises production request_vehicle -> finish_vehicle_spawn -> enter_vehicle.
class FixtureWorld extends "res://scripts/harbor_world.gd":
 func _ready():
  anchors={"home":Vector3(0,5,0),"marina":Vector3(1000,1,1000),"north":Vector3(6000,5,6000),"helipad":Vector3(400,5,400)}
  set_meta("map_migration_cache",{"mapped":[],"custom":[]})
  _ready_complete=true
 func _process(_delta):pass
class FixtureGame extends "res://scripts/main.gd":
 func _ready():
  qa_running=true;setup_input()
  world=FixtureWorld.new();add_child(world)
  player=Player.new();add_child(player)
  camera=Camera3D.new();add_child(camera)
  life=load("res://scripts/harbor_life.gd").new();add_child(life)
  audio=Sound.new();add_child(audio)
  setup_ui();set_process(false);set_physics_process(false)
func _initialize():call_deferred("run")
func run():
 var game=FixtureGame.new() if "--local" in OS.get_cmdline_user_args() else load("res://scripts/main.gd").new()
 game.qa_running=true;root.add_child(game)
 if not game.get_children().any(func(child):return child.get_script()==Validation):game.add_child(Validation.new())
