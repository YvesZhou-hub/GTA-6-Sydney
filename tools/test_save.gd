extends SceneTree
const Store=preload("res://scripts/save_store.gd")
var failures=0
func _init():
	var id="qa_store_"+str(Time.get_ticks_usec())
	var data={"name":"Persistence QA","mode":"life","life":{"money":1200},"world":{"destroyed":["opera/shell/1/2"]},"vehicles":[{"id":"car","position":[1,2,3]}],"player":[1,2,3]}
	check("atomic write",Store.write(id,data))
	check("read data",Store.read(id).world.destroyed==data.world.destroyed)
	data.life.money=843
	check("overwrite",Store.write(id,data))
	check("previous recovery copy",Store.read(id,true).life.money==1200)
	var copy=Store.duplicate_world(id)
	check("independent copy",copy!=id and Store.read(copy).life.money==843)
	var invalid=FileAccess.open(Store.ROOT+id+".json",FileAccess.WRITE)
	invalid.store_string("{broken")
	invalid.close()
	check("corrupt rejected",Store.read(id).is_empty())
	check("backup preserved",Store.read(id,true).life.money==1200)
	var future=data.duplicate(true)
	future.version=999
	invalid=FileAccess.open(Store.ROOT+id+".json",FileAccess.WRITE)
	invalid.store_string(JSON.stringify(future))
	invalid.close()
	check("future version rejected",Store.read(id).is_empty())
	quit(failures)
func check(title:String,ok:bool):
	print("SAVE_TEST "+title+" "+("PASS" if ok else "FAIL"))
	if not ok: failures+=1
