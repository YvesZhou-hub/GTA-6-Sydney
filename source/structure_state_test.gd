extends SceneTree
## Geometry revisions must not silently erase a saved component's damage history.
class FixtureWorld extends "res://scripts/harbor_world.gd":
	func _ready():
		_make_materials()
		_structure_box("fixture/current",Vector3.ZERO,Vector3.ONE,"sandstone",1000)
var checks:Array=[]
func _initialize():call_deferred("run")
func check(name:String,passed:bool):
	checks.append({"name":name,"passed":passed})
	print("STRUCTURE_STATE ","PASS " if passed else "FAIL ",name)
func run():
	var world:=FixtureWorld.new();root.add_child(world)
	await physics_frame;await physics_frame
	var legacy:={"destroyed":["fixture/current","opera/podium/0"],"partial":{"opera/podium/1":.55},"rubble":[]}
	world.apply_state(legacy)
	await physics_frame
	var state:Dictionary=world.get_state()
	check("existing component still receives saved destruction",not world.structures["fixture/current"].node.visible)
	check("retired Opera component ID remains in exported state","opera/podium/0" in state.destroyed)
	check("retired partial damage remains intact",is_equal_approx(float(state.partial.get("opera/podium/1",0)),.55))
	world.apply_state(state)
	await physics_frame
	check("repeat restoration preserves known and retired damage",world.get_state().destroyed.size()==2 and world.get_state().partial==legacy.partial)
	world.repair_all();await physics_frame
	check("explicit repair clears current and retired damage",world.get_state().destroyed.is_empty() and world.get_state().partial.is_empty() and world.structures["fixture/current"].node.visible)
	var passed:bool=checks.all(func(item):return item.passed)
	FileAccess.open("res://../reports/structure-state.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"user_saves_touched":false,"scope":"Small production-world subclass; retired IDs are retained, not geometrically remapped to new model components."},"\t"))
	quit(0 if passed else 1)
