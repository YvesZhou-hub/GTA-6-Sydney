extends RefCounted
## Near facade geometry is built on one CPU worker, then uploaded on the main
## thread. Base city shells/collision/save IDs stay resident for fast flight.
const City=preload("res://scripts/city_map.gd")
const MAX_RESIDENT:=64
const LOAD_RADIUS:=560.0
const RETAIN_RADIUS:=780.0
var world:Node3D
var resident:Dictionary={}
var wanted:Array[Vector2i]=[]
var _task: int=-1
var _task_cell:=Vector2i.ZERO
var _output:Array=[]
var _worker_ms:=0.0
var _mutex:=Mutex.new()
var _clock:=0.0
var builds:=0
var evictions:=0
var last_worker_ms:=0.0
var last_upload_ms:=0.0
var max_upload_ms:=0.0

func setup(owner_world:Node3D): world=owner_world

func _produce(parts:Array) -> void:
	var started:=Time.get_ticks_usec()
	var results:Array=[]
	for part:Dictionary in parts:
		var arrays:=City._facade_relief(part.item,part.bottom,part.top)
		if arrays[Mesh.ARRAY_VERTEX]==null or arrays[Mesh.ARRAY_VERTEX].is_empty():continue
		results.append({"id":part.id,"index":part.index,"arrays":arrays})
	_mutex.lock()
	_output=results
	_worker_ms=(Time.get_ticks_usec()-started)/1000.0
	_mutex.unlock()

func _commit_ready():
	if _task<0 or not WorkerThreadPool.is_task_completed(_task): return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task=-1
	_mutex.lock()
	var output:=_output
	_output=[]
	last_worker_ms=_worker_ms
	_mutex.unlock()
	if not _task_cell in wanted: return
	# Retained cells can fill the budget between the 150 ms planning ticks.
	# Reserve a slot before uploading, including rapid direction changes.
	if not resident.has(_task_cell) and resident.size()>=MAX_RESIDENT:
		for cell:Vector2i in resident.keys():
			if not cell in wanted:
				_evict(cell)
				break
		if resident.size()>=MAX_RESIDENT:return
	var started:=Time.get_ticks_usec()
	for item:Dictionary in output:
		if not world.structures.has(item.id): continue
		world.structures[item.id].surfaces[item.index]["arrays"]=item.arrays
	resident[_task_cell]=true
	world._rebuild_visual_cell(_task_cell,false,true)
	# The combined mesh now owns the uploaded data; keep only tiny descriptors.
	for item:Dictionary in output:
		if world.structures.has(item.id): world.structures[item.id].surfaces[item.index].erase("arrays")
	last_upload_ms=(Time.get_ticks_usec()-started)/1000.0
	max_upload_ms=maxf(max_upload_ms,last_upload_ms)
	builds+=1

func _evict(cell:Vector2i):
	resident.erase(cell)
	world._visual_cells[cell].detail.mesh=null
	evictions+=1

func invalidate(cell:Vector2i):
	# Re-enter the queue using the current destroyed/partial-damage dictionaries.
	if resident.has(cell):
		resident.erase(cell)
		world._visual_cells[cell].detail.mesh=null

func tick(position:Vector3,velocity:Vector3,delta:float):
	if not is_instance_valid(world): return
	_clock-=delta
	if _clock<=0.0:
		_clock=0.15
		var here:=Vector2(position.x,position.z)
		var ahead:=here+Vector2(velocity.x,velocity.z).limit_length(560)*0.65
		var candidates:Array=[]
		for cell:Vector2i in world._visual_cells:
			var data:Dictionary=world._visual_cells[cell]
			if not data.get("has_near",false):continue
			var center:Vector2=(Vector2(cell)+Vector2(.5,.5))*160
			var distance:=minf(center.distance_to(here),center.distance_to(ahead))
			if distance<LOAD_RADIUS and position.y<900: candidates.append({"cell":cell,"distance":distance})
		candidates.sort_custom(func(a,b): return a.distance<b.distance)
		wanted.clear()
		for item:Dictionary in candidates.slice(0,MAX_RESIDENT): wanted.append(item.cell)
		for cell:Vector2i in resident.keys():
			var center:Vector2=(Vector2(cell)+Vector2(.5,.5))*160
			if (not cell in wanted and (center.distance_to(here)>RETAIN_RADIUS or resident.size()>=MAX_RESIDENT)) or position.y>=900:
				_evict(cell)
	_commit_ready()
	if _task>=0: return
	for cell:Vector2i in wanted:
		if resident.has(cell): continue
		var parts:Array=[]
		for id:String in world._visual_cells[cell].ids:
			if world.destroyed.has(id):continue
			var surfaces:Array=world.structures[id].get("surfaces",[])
			for index in surfaces.size():
				var surface:Dictionary=surfaces[index]
				if surface.has("deferred_facade"):
					parts.append({"id":id,"index":index,"item":surface.deferred_facade,"bottom":surface.bottom,"top":surface.top})
		_task_cell=cell
		_task=WorkerThreadPool.add_task(_produce.bind(parts),false,"Nearby facade geometry")
		break

func stats() -> Dictionary:
	var cells:Array=[]
	for cell:Vector2i in resident: cells.append([cell.x,cell.y])
	return {"enabled":true,"scope":"near_facade_only","cell_size_m":160,"resident":resident.size(),"limit":MAX_RESIDENT,"resident_cells":cells,"wanted":wanted.size(),"pending_worker":int(_task>=0),"builds":builds,"evictions":evictions,"last_worker_ms":last_worker_ms,"last_upload_ms":last_upload_ms,"max_upload_ms":max_upload_ms,"base_collision_resident":true}

func close():
	if _task>=0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task=-1
	_output.clear()
	world=null
