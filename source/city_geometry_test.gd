extends SceneTree
const City=preload("res://scripts/city_map.gd")
class LocalWorld extends "res://scripts/harbor_world.gd":
	func _ready() -> void:
		_make_materials()
		map_snapshot=CityMap.data()
		map_snapshot.buildings=map_snapshot.buildings.filter(func(b): return b.id in ["way/191626163","relation/174778"] or b.has("roof_surface"))
		CityMap.build_buildings(self,map_snapshot)
		_build_structure_batches()
		_ready_complete=true
var failures:=0
var checks:=0
func check(name:String, okay:bool):
	checks+=1
	print("CITY_GEOMETRY ",name," ","PASS" if okay else "FAIL")
	if not okay: failures+=1
func _initialize(): call_deferred("run")
func frame_pair():
	await physics_frame
	await physics_frame
func vertices(cell:Dictionary,near:bool=false) -> int:
	var mesh:Mesh=cell.detail.mesh if near else cell.instance.mesh
	var count:=0
	if mesh:
		for i in mesh.get_surface_count(): count+=mesh.surface_get_array_len(i)
	return count
func run():
	var world:=LocalWorld.new()
	root.add_child(world)
	await frame_pair()
	var id:="osm/way/191626163/storey_group/0"
	var item:Dictionary=world.structures[id]
	check("mapped solids retain CPU surfaces and independent collision",item.surfaces.size()==2 and item.node.get_child(0) is CollisionShape3D)
	var cell:Dictionary=world._visual_cells[item.cell]
	var before:=vertices(cell)
	var relief:=vertices(cell,true)
	check("actual footprint creates rendered base and near facade",before>0 and relief>0)
	var bad:=0
	for surface in item.surfaces:
		var a:Array=surface.arrays
		for i in range(0,a[Mesh.ARRAY_INDEX].size(),3):
			var ai:int=a[Mesh.ARRAY_INDEX][i];var bi:int=a[Mesh.ARRAY_INDEX][i+1];var ci:int=a[Mesh.ARRAY_INDEX][i+2]
			var cross:Vector3=(a[Mesh.ARRAY_VERTEX][bi]-a[Mesh.ARRAY_VERTEX][ai]).cross(a[Mesh.ARRAY_VERTEX][ci]-a[Mesh.ARRAY_VERTEX][ai])
			if cross.dot(a[Mesh.ARRAY_NORMAL][ai])>0.00001 or cross.length_squared()<1e-14: bad+=1
	check("CPU extrusion and facade winding point outward",bad==0)
	var roofs:=0
	var invalid:=0
	for component in world.structures:
		if not component.ends_with("/roof"):continue
		roofs+=1
		var roof:Dictionary=world.structures[component]
		var arrays:Array=roof.surfaces[0].arrays
		var faces:PackedVector3Array=roof.node.get_child(0).shape.get_faces()
		if faces.size()!=arrays[Mesh.ARRAY_INDEX].size():invalid+=1
		for i in range(0,arrays[Mesh.ARRAY_INDEX].size(),3):
			var ai:int=arrays[Mesh.ARRAY_INDEX][i];var bi:int=arrays[Mesh.ARRAY_INDEX][i+1];var ci:int=arrays[Mesh.ARRAY_INDEX][i+2]
			var cross:Vector3=(arrays[Mesh.ARRAY_VERTEX][bi]-arrays[Mesh.ARRAY_VERTEX][ai]).cross(arrays[Mesh.ARRAY_VERTEX][ci]-arrays[Mesh.ARRAY_VERTEX][ai])
			if cross.dot(arrays[Mesh.ARRAY_NORMAL][ai])>0.00001 or cross.length_squared()<1e-14:invalid+=1
	check("tagged roof profiles have matching physical faces and winding",roofs>400 and invalid==0)
	world.partial_damage[id]=0.5
	world._mark_visual_dirty(id)
	await frame_pair()
	var scar:=false
	for i in cell.instance.mesh.get_surface_count():
		if cell.instance.mesh.surface_get_material(i)==world.materials.rubble: scar=true
	check("partial damage appears on the rendered CPU batch",scar)
	world._destroy_component(id,item.position,0,false)
	await frame_pair()
	check("destruction removes collision",item.node.get_child(0).disabled)
	check("destruction removes base and near facade together",vertices(cell)<before and vertices(cell,true)<relief)
	var saved:=world.get_state()
	world.apply_state(JSON.parse_string(JSON.stringify(saved)))
	await frame_pair()
	check("saved city damage restores physical and visual holes",world.destroyed.has(id) and item.node.get_child(0).disabled and vertices(cell)<before)
	world.repair_all()
	await frame_pair()
	check("repair restores exact base and relief geometry",vertices(cell)==before and vertices(cell,true)==relief and not item.node.get_child(0).disabled)
	print("CITY_GEOMETRY_COMPLETE checks=",checks," failures=",failures)
	quit(failures)
