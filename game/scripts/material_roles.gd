extends RefCounted
## One registry per world. Owns weak references, never copies a material.
## Registration is neutral; explicit role tuning changes numeric uniforms only.
const ROLES := ["glass","stone","concrete","metal","trim","light","wood","asphalt","vegetation","roof","cloth","rubber","soil"]
const ALIASES := {"vertical_fins":"metal","fins":"metal","steel":"metal","timber":"wood","lighting":"light"}
const PREFIXES := ["sydney_tower_","city_landmark_","city_tower_one_","city_exchange_","city_w_","bridge_","opera_","bank_","quay_","manly_","cyber_","metro_","qvb_","icc_","opi_","cq_","mw_","ds_","dp_","map_"]
const KEY_ROLES := {
	"glass":["glass","warm_glass","clear","platform_glass","roof_glass","crystal_face","crystal_light"],
	"stone":["sandstone","lightstone","stone","granite","paving","paving_band","pink_stone","coping","darkstone","ballast","mortar","rubble","tile"],
	"concrete":["concrete","pier","podium","soffit"],
	"metal":["metal","steel","darksteel","silver","bronze","copper","gold","iron","cable","rivet","mullion","frame","pipe","roof_rib"],
	"trim":["white","yellow","coral","teal","navy","red","blue","cream","black","dark","ivory","joint","edge","recess","trim","shell","petal","peach","green","matcha","purple","ochre","coal","warm","ceiling","sign","tactile","ferry_green","bus","ferry","stripe"],
	"light":["lamp","light","downlight","beacon","barometer","signal","amber_light","blue_light","green_light"],
	"wood":["wood","wood_light","timber","bark","brushbox","birch","woodlight","wooddark"],
	"asphalt":["road","asphalt","taxi"],
	"vegetation":["tree","tree_light","grass","hedge","pine","palm","palm_old","leaf","plant"],
	"roof":["roof","slate"],
	"cloth":["cloth","carpet","seat_grey","seat_dark","magenta"],
	"rubber":["rubber","fender"],
	"soil":["sand","mulch","scrub","shoulder"]
}
# Source-reviewed exceptions: colour words alone do not determine substance.
const EXACT := {"qvb_trim":"stone","qvb_cream":"stone","qvb_red":"stone","qvb_amber":"glass","qvb_green":"glass","quay_green":"vegetation","opera_edge":"stone","opera_recess":"stone","bridge_edge":"metal","bridge_recess":"stone","mw_cap":"stone","sydney_tower_shaft":"concrete","sydney_tower_edge":"metal","city_w_shell":"metal","cyber_ceiling":"light","manly_brick":"stone","icc_theatre_red":"cloth","opi_red":"cloth","opi_purple":"cloth","opi_reflector":"trim","opi_jst_wall":"wood"}
const UNMANAGED := ["water","dp_water","dp_jet","north_landcover","opera_tiles","city_tower_one_perforated"]
const FEATURE_STAMP := "material_roles_registered"
const FACADE_SHADERS := ["res://shaders/city_facade.gdshader","res://assets/world_facade.gdshader"]
const FACADE_PROPERTIES := {"glass":{"roughness":"glass_roughness","metallic":"glass_metallic"},"stone":{"roughness":"wall_roughness"}}
var _members: Dictionary = {} # instance_id -> weak, roles, originals per role
var _profiles: Dictionary = {}
var _generation:=0

static func canonical_role(role:String) -> String:
	var normalized:=role.strip_edges().to_lower()
	normalized=ALIASES.get(normalized,normalized)
	return normalized if normalized in ROLES else ""

static func classify_key(key:String) -> String:
	if key in UNMANAGED:return ""
	if EXACT.has(key):return EXACT[key]
	if key.begins_with("mapped_roof_"):return "roof"
	var suffix:=key
	for prefix:String in PREFIXES:
		if key.begins_with(prefix):suffix=key.trim_prefix(prefix);break
	for role:String in KEY_ROLES:
		if suffix in KEY_ROLES[role]:return role
	return ""

func register_material(material:Material,role:String,initialize_features:bool=false) -> bool:
	var semantic:=canonical_role(role)
	if semantic.is_empty() or _properties(material,semantic).is_empty():return false
	var id:=material.get_instance_id()
	if _members.has(id) and material is StandardMaterial3D and semantic not in _members[id].roles:return false
	# Only an explicit creation-time call may enable emission. Repeat calls,
	# role updates and registering existing resources never toggle features.
	if material is StandardMaterial3D and initialize_features and semantic=="light" and not material.has_meta(FEATURE_STAMP):
		material.emission_enabled=true
	material.set_meta(FEATURE_STAMP,true)
	if not _members.has(id):_members[id]={"weak":weakref(material),"roles":[],"originals":{}}
	if semantic not in _members[id].roles:
		_members[id].roles.append(semantic)
		_members[id].originals[semantic]=_read_values(material,semantic)
	_apply(material,semantic,_profiles.get(semantic,{}))
	return true

func register_key(material:Material,key:String,initialize_features:bool=false) -> bool:
	if _is_facade(material):
		var glass_ok:=register_material(material,"glass")
		var stone_ok:=register_material(material,"stone")
		return glass_ok and stone_ok
	return register_material(material,classify_key(key),initialize_features)

func _is_facade(material:Material) -> bool:
	return material is ShaderMaterial and material.shader!=null and material.shader.resource_path in FACADE_SHADERS

func _properties(material:Material,role:String) -> Dictionary:
	if material is StandardMaterial3D:
		var fields:={"roughness":"roughness","metallic":"metallic"}
		if role=="light":fields["emission_energy_multiplier"]="emission_energy_multiplier"
		return fields
	if _is_facade(material):return FACADE_PROPERTIES.get(role,{})
	return {}

func _read_values(material:Material,role:String) -> Dictionary:
	var fields:=_properties(material,role);var values:Dictionary={}
	for key:String in fields:
		# Shader getter returns the raw override, including null for defaults.
		values[key]=material.get_shader_parameter(fields[key]) if material is ShaderMaterial else material.get(fields[key])
	return values

func unregister_material(material:Material) -> void:
	if is_instance_valid(material):_members.erase(material.get_instance_id())

func set_role(role:String,tuning:Dictionary) -> Dictionary:
	var semantic:=canonical_role(role)
	if semantic.is_empty():return {"ok":false,"reason":"unknown_role","updated":0,"ignored":tuning.keys()}
	var values:Dictionary={};var ignored:Array=[];var clamped:Array=[]
	for input_key in tuning:
		var key:=str(input_key)
		if key=="energy":key="emission_energy_multiplier"
		if key not in ["metallic","roughness","emission_energy_multiplier"] or (key=="emission_energy_multiplier" and semantic!="light"):
			ignored.append(input_key);continue
		var value=tuning[input_key]
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):
			ignored.append(input_key);continue
		var bounded:=clampf(float(value),0.0,16.0 if key=="emission_energy_multiplier" else 1.0)
		if bounded!=float(value):clamped.append(input_key)
		values[key]=bounded
	if not _profiles.has(semantic):_profiles[semantic]={}
	_profiles[semantic].merge(values,true)
	var updated:=0
	for id in _members.keys():
		var material:Material=_members[id].weak.get_ref()
		if material==null:_members.erase(id);continue
		if semantic in _members[id].roles and _apply(material,semantic,values):updated+=1
	return {"ok":true,"updated":updated,"ignored":ignored,"clamped":clamped,"values":values.duplicate(true)}

func _apply(material:Material,role:String,values:Dictionary,exact:bool=false) -> bool:
	var changed:=false
	var fields:=_properties(material,role)
	for key:String in values:
		if not fields.has(key):continue
		var current=material.get_shader_parameter(fields[key]) if material is ShaderMaterial else material.get(fields[key])
		# Null and an explicit value equal to the default are distinct states.
		var equal:bool=current==values[key]
		if not exact and current!=null and values[key]!=null:equal=is_equal_approx(float(current),float(values[key]))
		if not equal:
			if material is ShaderMaterial:material.set_shader_parameter(fields[key],values[key])
			else:material.set(fields[key],values[key])
			changed=true
	return changed

func snapshot_role(role:String) -> Dictionary:
	var semantic:=canonical_role(role)
	if semantic.is_empty():return {"ok":false,"reason":"unknown_role"}
	var captured:Dictionary={}
	for id in _members.keys():
		var material:Material=_members[id].weak.get_ref()
		if material==null:_members.erase(id);continue
		if semantic in _members[id].roles:captured[id]=_read_values(material,semantic)
	return {"ok":true,"role":semantic,"registry_id":get_instance_id(),"generation":_generation,"has_profile":_profiles.has(semantic),"profile":_profiles.get(semantic,{}).duplicate(true),"materials":captured}

func restore_role(role:String,snapshot:Dictionary) -> Dictionary:
	var semantic:=canonical_role(role)
	if semantic.is_empty() or not snapshot.get("ok",false) or snapshot.get("role")!=semantic or snapshot.get("registry_id")!=get_instance_id() or snapshot.get("generation")!=_generation:
		return {"ok":false,"reason":"incompatible_snapshot","restored":0,"skipped":0}
	if not snapshot.get("materials") is Dictionary or not snapshot.get("profile") is Dictionary:
		return {"ok":false,"reason":"invalid_snapshot","restored":0,"skipped":0}
	var saved:Dictionary=snapshot.materials
	if not _valid_values(snapshot.profile,semantic,false):
		return {"ok":false,"reason":"invalid_snapshot","restored":0,"skipped":0}
	for id in saved:
		if not saved[id] is Dictionary or not _valid_values(saved[id],semantic,true):
			return {"ok":false,"reason":"invalid_snapshot","restored":0,"skipped":0}
		if _members.has(id):
			var existing:Material=_members[id].weak.get_ref()
			if existing is StandardMaterial3D and saved[id].values().has(null):
				return {"ok":false,"reason":"invalid_snapshot","restored":0,"skipped":0}
	var restored:=0;var late:=0;var matched:=0
	if snapshot.has_profile:_profiles[semantic]=snapshot.profile.duplicate(true)
	else:_profiles.erase(semantic)
	for id in _members.keys():
		var material:Material=_members[id].weak.get_ref()
		if material==null:_members.erase(id);continue
		if semantic not in _members[id].roles:continue
		var values:Dictionary
		if saved.has(id):
			values=saved[id];matched+=1
		else:
			# A material added during a preview returns to its authored baseline
			# plus the profile that existed before that preview began.
			values=_members[id].originals[semantic].duplicate(true)
			values.merge(snapshot.profile,true);late+=1
		if _apply(material,semantic,values,true):restored+=1
	return {"ok":true,"restored":restored,"skipped":saved.size()-matched,"late_members":late}

func _valid_values(values:Dictionary,role:String,allow_default:bool) -> bool:
	for key in values:
		if key not in ["roughness","metallic","emission_energy_multiplier"] or (key=="emission_energy_multiplier" and role!="light"):return false
		var value=values[key]
		if value==null and allow_default:continue
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):return false
	return true

func stats() -> Dictionary:
	var counts:Dictionary={}
	var shaders:=0
	for role:String in ROLES:counts[role]=0
	for id in _members.keys():
		if _members[id].weak.get_ref()==null:_members.erase(id)
		else:
			for role:String in _members[id].roles:counts[role]+=1
			if _is_facade(_members[id].weak.get_ref()):shaders+=1
	return {"resources":_members.size(),"roles":counts,"covered_shader_count":shaders,"current_overrides":_profiles.duplicate(true)}

func clear() -> void:
	_members.clear();_profiles.clear()
	_generation+=1
