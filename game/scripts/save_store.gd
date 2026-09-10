extends RefCounted

const VERSION = 2
const ROOT = "user://worlds/"
static var last_error = ""

static func slots() -> Array:
	DirAccess.make_dir_recursive_absolute(ROOT)
	var result: Array = []
	for file in DirAccess.get_files_at(ROOT):
		if file.ends_with(".json") and not file.begins_with("qa_"):
			var item = read(file.trim_suffix(".json"))
			if not item.is_empty():
				result.append({"id":file.trim_suffix(".json"),"name":item.get("name","World"),"mode":item.get("mode","life"),"saved":item.get("saved",""),"money":item.get("life",{}).get("money",0)})
	result.sort_custom(func(a,b): return a.saved > b.saved)
	return result

static func write(id: String, data: Dictionary) -> bool:
	last_error = ""
	DirAccess.make_dir_recursive_absolute(ROOT)
	if not id.is_valid_filename():
		last_error = "Invalid world identifier"
		return false
	data["version"] = VERSION
	data["saved"] = Time.get_datetime_string_from_system()
	var path = ROOT + id + ".json"
	var temp = path + ".tmp"
	var f = FileAccess.open(temp, FileAccess.WRITE)
	if not f:
		last_error = "Unable to write save file: " + str(FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.flush()
	f.close()
	if JSON.parse_string(FileAccess.get_file_as_string(temp)) == null:
		last_error = "Save validation failed"
		return false
	if FileAccess.file_exists(path):
		var backup_error = DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			last_error = "Unable to preserve recovery copy"
			return false
	var err = DirAccess.rename_absolute(temp, path)
	if err != OK:
		last_error = "Atomic save failed: " + str(err)
	return err == OK

static func read(id: String, backup: bool = false) -> Dictionary:
	last_error = ""
	if not id.is_valid_filename(): return {}
	var path = ROOT + id + ".json" + (".bak" if backup else "")
	if not FileAccess.file_exists(path): return {}
	var parser=JSON.new()
	var result=parser.parse(FileAccess.get_file_as_string(path))
	var data=parser.data if result==OK else null
	if not data is Dictionary:
		last_error = "Invalid save. The previous recovery copy may still be available."
		return {}
	for key in ["world", "life", "airport", "settings"]:
		if data.has(key) and not data[key] is Dictionary:
			last_error = "Invalid world section: " + key
			return {}
	if data.has("vehicles") and not data.vehicles is Array:
		last_error = "Invalid vehicle list"
		return {}
	if data.has("player") and (not data.player is Array or data.player.size() != 3):
		last_error = "Invalid player position"
		return {}
	if data.has("owned") and not data.owned is Array:
		last_error = "Invalid ownership list"
		return {}
	for vehicle in data.get("vehicles",[]):
		if not vehicle is Dictionary or not vehicle.get("position",[]) is Array or vehicle.get("position",[]).size()!=3:
			last_error = "Invalid vehicle state"
			return {}
	for coordinate in data.get("player",[]):
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)):
			last_error = "Invalid player coordinate"
			return {}
	var version = int(data.get("version",1))
	if version > VERSION:
		last_error = "This world was saved by a newer version."
		return {}
	if version == 1:
		data["version"] = 2
		data["settings"] = data.get("settings",{})
	return data

static func duplicate_world(id: String) -> String:
	var data = read(id)
	if data.is_empty(): return ""
	data["name"] = str(data.get("name","World")) + " · Copy"
	var new_id = "world_" + str(Time.get_unix_time_from_system()).replace(".","_")
	return new_id if write(new_id,data) else ""
