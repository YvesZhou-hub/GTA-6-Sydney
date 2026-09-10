extends SceneTree
const Store=preload("res://scripts/save_store.gd")
const LegacyV012=preload("res://../source/fixtures/save_store_v012.gd")
const LEGACY_SHA256="da9a206bdd26938774f91353aafb7db701ca7658b7f45498a31d590c0609918d"
var failures=0
var checks:Array=[]
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
	version_compatibility(id+"_compat")
	var report={"passed":failures==0,"checks":checks,"current_format":Store.VERSION,"legacy_reader":{"format":LegacyV012.VERSION,"source":"source/fixtures/save_store_v012.gd","commit":"d6ddb4d","sha256":LEGACY_SHA256,"provenance":"Byte-identical save_store.gd from the v0.1.2 final build manifest"},"user_saves_touched":false,"qa_fixtures_retained":true,"scope":"Actual production save API and immutable v0.1.2 reader; unique qa_store files only; no slots() calls or non-QA save access."}
	var output:=FileAccess.open("res://../reports/save-v013-format5.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"));output.close()
	print("SAVE_TEST COMPLETE checks=",checks.size()," failures=",failures," format=",Store.VERSION)
	quit(failures)
func check(title:String,ok:bool):
	checks.append({"name":title,"passed":ok})
	print("SAVE_TEST "+title+" "+("PASS" if ok else "FAIL"))
	if not ok: failures+=1

func version_compatibility(prefix:String):
	# This is the shipped v0.1.2 implementation, not the current reader with a
	# test-only version override. Preserve its original bytes for reproducibility.
	var source:=FileAccess.get_file_as_bytes("res://../source/fixtures/save_store_v012.gd")
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(source)
	check("legacy reader matches actual v012 source digest",hash.finish().hex_encode()==LEGACY_SHA256 and LegacyV012.VERSION==4)
	var car={"kind":"car","id":"qa_legacy_car","position":[12,5.3,30],"health":63,"fuel":41}
	var loaded_v4:Dictionary={}
	var original_v4:=PackedByteArray()
	var v4_id:=""
	for version in [1,2,3,4]:
		var id:=prefix+"_v"+str(version)
		var old={"version":version,"name":"Version compatibility QA","mode":"sandbox","life":{"money":4321},"world":{"destroyed":["opera/shell/1/2"]},"vehicles":[car.duplicate(true)],"player":[12,5.3,30],"owned":["car"],"navigation":{"key":"map_pin","title":"QA marker","position":[300,4.5,400]}}
		var path:String=Store.ROOT+id+".json"
		var writer:=FileAccess.open(path,FileAccess.WRITE);writer.store_string(JSON.stringify(old,"\t"));writer.close()
		var before:=FileAccess.get_file_as_bytes(path)
		var expected:Dictionary=JSON.parse_string(JSON.stringify(old))
		var loaded:Dictionary=Store.read(id)
		check("format %d loads into v5 without rewriting source or losing existing state"%version,loaded.get("version",0)==5 and loaded.get("vehicles",[])==expected.vehicles and loaded.get("life",{})==expected.life and loaded.get("world",{})==expected.world and loaded.get("navigation",{})==expected.navigation and FileAccess.get_file_as_bytes(path)==before)
		if version==4:loaded_v4=loaded;original_v4=before;v4_id=id
	var old_reader_control:Dictionary=LegacyV012.read(v4_id)
	var expected_car:Dictionary=JSON.parse_string(JSON.stringify(car))
	check("actual v012 reader accepts valid v4 control",not old_reader_control.is_empty() and old_reader_control.version==4 and old_reader_control.vehicles==[expected_car])
	# Ordinary play can add several new-class copies after loading an old world.
	var boards:Array=[]
	for i in 2:
		boards.append({"kind":"hoverboard","id":"qa_hover_copy_"+str(i),"position":[100+i*10,42+i,300],"quaternion":[0,0,0,1],"velocity":[15,0,-2],"angular_velocity":[0,.1,0],"health":81-i,"fuel":100,"throttle":.4,"frozen":false,"hover_lift_offset":35+i*12,"dents":[[.2,.1,.4]]})
	loaded_v4.vehicles.append_array(boards)
	loaded_v4.owned.append("hoverboard")
	loaded_v4.vehicle=boards[1].id
	loaded_v4.spawn_target=boards[0].id
	var path:String=Store.ROOT+v4_id+".json"
	check("saving an upgraded v4 world emits format 5",Store.write(v4_id,loaded_v4) and JSON.parse_string(FileAccess.get_file_as_string(path)).version==5)
	var upgraded:Dictionary=Store.read(v4_id)
	var expected_boards:Array=JSON.parse_string(JSON.stringify(boards))
	check("v5 reload preserves both independent hoverboards and occupied target",upgraded.vehicles.size()==3 and upgraded.vehicles[0]==expected_car and upgraded.vehicles[1]==expected_boards[0] and upgraded.vehicles[2]==expected_boards[1] and upgraded.vehicle==boards[1].id and upgraded.spawn_target==boards[0].id)
	check("upgrade retains the exact original v4 recovery bytes",FileAccess.get_file_as_bytes(path+".bak")==original_v4)
	var new_bytes:=FileAccess.get_file_as_bytes(path)
	var backup_bytes:=FileAccess.get_file_as_bytes(path+".bak")
	check("actual shipped v012 reader refuses format 5",LegacyV012.read(v4_id).is_empty() and LegacyV012.last_error=="This world was saved by a newer version.")
	check("old-reader rejection preserves new save and recovery bytes",FileAccess.get_file_as_bytes(path)==new_bytes and FileAccess.get_file_as_bytes(path+".bak")==backup_bytes)
	var copy:String=Store.duplicate_world(v4_id)
	var copied:Dictionary=Store.read(copy)
	check("copying a v5 world keeps format and independent new-class data",not copy.is_empty() and copy!=v4_id and copied.version==5 and copied.vehicles==upgraded.vehicles and FileAccess.get_file_as_bytes(path)==new_bytes)
