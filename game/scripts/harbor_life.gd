class_name HarborLife
extends Node3D
## The persistent local economy and five repeatable spatial activities.
## All object identifiers are stable across scene construction and save reload.

const CargoScript = preload("res://scripts/harbor_cargo.gd")
const NpcScript = preload("res://scripts/harbor_npc.gd")
signal notification(text: String)
signal money_changed(value: int)
signal activity_changed

var money: int = 1200
var active_job: Dictionary = {}
var status_text: String = "Visit the Harbour Exchange for work, or explore at your own pace."
var owned_assets: Dictionary = {"workshop": true, "bicycle_tools": true}
var completed_jobs: Dictionary = {}
var lifetime_earnings: int = 0
var anchors: Dictionary = {}
var sandbox: bool = false
var cargo: Array[HarborCargo] = []
var npcs: Array[HarborNPC] = []
var carried_cargo: HarborCargo
var _player_pos := Vector3.ZERO
var _player_vehicle: String = ""
var _speed: float = 0.0
var _last_player_pos := Vector3.ZERO
var _carry_direction := Vector3.FORWARD
var _marker: Node3D
var _marker_label: Label3D
var _marker_material: StandardMaterial3D
var _marker_phase: float = 0.0
var _ready_to_work: bool = false
var _mission_crate_id: String = ""
var _jobs_started: int = 0
var _hint_timer: float = 0.0
var _board_node: Node3D

func setup(world_anchors: Dictionary, sandbox_mode: bool) -> void:
	_ready_to_work = false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	cargo.clear()
	npcs.clear()
	carried_cargo = null
	active_job = {}
	completed_jobs = {}
	owned_assets = {"workshop": true, "bicycle_tools": true}
	lifetime_earnings = 0
	_jobs_started = 0
	_mission_crate_id = ""
	anchors = world_anchors.duplicate(true)
	sandbox = sandbox_mode
	money = 50000 if sandbox else 1200
	_build_board()
	_build_cargo()
	_build_npcs()
	_build_marker()
	_ready_to_work = true
	status_text = "自由沙盒 · 全部载具免费使用。世界独立保存。" if sandbox else "你的海港工作室已准备好。按 J 找工作，获得收入并维护载具。"

func _point(key: String, fallback: Vector3) -> Vector3:
	var value: Variant = anchors.get(key, fallback)
	if value is Vector3:
		return value
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback

func _route(key: String, fallback: Array) -> Array:
	var value: Variant = anchors.get(key, fallback)
	if value is Array and not value.is_empty():
		var result: Array = []
		for point in value:
			if point is Vector3:
				result.append(point)
			elif point is Array and point.size() == 3:
				result.append(Vector3(float(point[0]), float(point[1]), float(point[2])))
		if not result.is_empty():
			return result
	return fallback

func _home() -> Vector3:
	return _point("home", Vector3(-100, 4.5, 400))

func _delivery() -> Vector3:
	return _point("cargo_delivery", _home() + Vector3(3, 0, 5))

func _board() -> Vector3:
	return _point("job_board", _home() + Vector3(9, 0, 1))

func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.7
	if emission > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission
	return result

func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	instance.mesh = shape
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _build_board() -> void:
	_board_node = Node3D.new()
	_board_node.name = "Life_Harbour_Exchange"
	_board_node.position = _board()
	add_child(_board_node)
	var dark := _material(Color("193840"))
	var brass := _material(Color("bc9760"))
	_box(_board_node, Vector3(0, 1.5, 0), Vector3(2.8, 1.7, 0.18), dark)
	for x in [-1.18, 1.18]:
		_box(_board_node, Vector3(x, 0.7, 0), Vector3(0.075, 1.4, 0.075), brass)
	for y in [0.64, 2.36]:
		_box(_board_node, Vector3(0, y, 0), Vector3(2.88, 0.055, 0.22), brass)
	var label := Label3D.new()
	label.text = "HARBOUR EXCHANGE\n──────────────\nFIELDWORK · SALVAGE · SURVEY\n\nE  Browse local work"
	label.position = Vector3(0, 1.52, 0.102)
	label.font_size = 40
	label.pixel_size = 0.002
	label.modulate = Color("f1ead8")
	label.outline_size = 2
	_board_node.add_child(label)
	var back := Label3D.new()
	back.text = "HARBOUR\nEXCHANGE\nE  Local work"
	back.position = Vector3(0, 1.5, -0.102)
	back.rotation.y = PI
	back.font_size = 40
	back.pixel_size = 0.005
	back.modulate = Color("f1ead8")
	_board_node.add_child(back)
	var home_sign := Label3D.new()
	home_sign.name = "Life_Workshop_Sign"
	home_sign.text = "YOUR WORKSHOP\nStorage · Recovery · Fleet"
	home_sign.position = _home() + Vector3(0, 3.2, 0)
	home_sign.font_size = 28
	home_sign.pixel_size = 0.012
	home_sign.modulate = Color("cbd8cb")
	home_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(home_sign)

func _build_cargo() -> void:
	var recovery := _point("salvage", _home() + Vector3(65, 0, -28))
	var positions := _route("cargo_spawns", [recovery + Vector3(0, 0.55, 0),
		recovery + Vector3(3.0, 0.55, -1.0), recovery + Vector3(-2.5, 0.55, 2),
		_home() + Vector3(5, 0.55, 3), _home() + Vector3(6.3, 0.55, 3)])
	for i in positions.size():
		var item := CargoScript.new() as HarborCargo
		item.configure("life_cargo_%02d" % i, positions[i])
		add_child(item)
		cargo.append(item)

func _build_npcs() -> void:
	var board := _board()
	var home := _home()
	var quay := _point("quay", Vector3(80, 4.5, 260))
	var opera := _point("opera", Vector3(410, 4.5, -370))
	var north := _point("north", Vector3(20, 4.5, -1080))
	var defaults := [
		[board + Vector3(-3, 0, 3), board + Vector3(-7, 0, 3)],
		[home + Vector3(7, 0, 7), home + Vector3(7, 0, 11)],
		[quay + Vector3(0, 0, 4), quay + Vector3(14, 0, 4)],
		[north + Vector3(0, 0, 5), north + Vector3(14, 0, 5)],
		[board + Vector3(4, 0, -3), board + Vector3(8, 0, -3)],
		[opera + Vector3(-15, 0, 20), opera + Vector3(-30, 0, 20)],
		[quay + Vector3(25, 0, 7), quay + Vector3(45, 0, 7)],
		[quay + Vector3(-12, 0, 12), quay + Vector3(-38, 0, 12)],
		[north + Vector3(-8, 0, 12), north + Vector3(-29, 0, 12)],
		[home + Vector3(15, 0, 20), home + Vector3(30, 0, 20)],
		[opera + Vector3(-20, 0, 45), opera + Vector3(15, 0, 45)],
		[quay + Vector3(5, 0, 20), quay + Vector3(27, 0, 20)]]
	var routes: Variant = anchors.get("npc_routes", defaults)
	if not routes is Array or routes.is_empty():
		routes = defaults
	var names := ["Mia", "Rafi", "Claire", "Noah", "Alex", "June", "Sam", "Priya", "Leo", "Asha", "Finn", "Mei"]
	var roles := ["Local photographer", "Recovery crew", "Wharf inspector", "Aerial observer", "Motoring club", "Harbour walker", "Ferry regular", "Neighbour", "Dog walker", "Workshop neighbour", "Visitor", "Harbour regular"]
	var assignments := ["photo", "salvage", "harbor", "air", "race", "", "", "", "", "", "", ""]
	for i in mini(routes.size(), 30):
		var npc := NpcScript.new() as HarborNPC
		npc.configure("life_npc_%02d" % i, names[i % names.size()], roles[i % roles.size()], routes[i], fposmod(float(i) * 0.173 + 0.09, 1.0), assignments[i % assignments.size()])
		add_child(npc)
		npcs.append(npc)

func _build_marker() -> void:
	_marker = Node3D.new()
	_marker.name = "Life_Activity_Marker"
	add_child(_marker)
	_marker_material = _material(Color("e5b96c"), 0.7)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.7
	torus.outer_radius = 2.0
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = _marker_material
	_marker.add_child(ring)
	_marker_label = Label3D.new()
	_marker_label.position.y = 4
	_marker_label.font_size = 40
	_marker_label.pixel_size = 0.03
	_marker_label.outline_size = 8
	_marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker_label.modulate = Color("f0c884")
	_marker.add_child(_marker_label)
	_marker.visible = false

func job_catalog() -> Array:
	return [
		{"id": "photo", "title": "海港摄影漫步", "description": "步行到三个滨水观景点，站稳后按 E 拍照。", "reward": 240, "mode": "ON FOOT", "duration": "4–8 min"},
		{"id": "salvage", "title": "旧物回收", "description": "按 G 拿起实体货箱，自选运输方式，送回工作室后按 E 卸货。", "reward": 360, "mode": "CARGO / ANY TRANSPORT", "duration": "3–6 min"},
		{"id": "harbor", "title": "码头巡检", "description": "驾驶船只到三个海港站点，每站低于 3 m/s 停留两秒。", "reward": 420, "mode": "BOAT", "duration": "4–7 min"},
		{"id": "air", "title": "空中观察", "description": "使用直升机、滑翔机或客机，依次飞过海港上空的三个观察区域。", "reward": 620, "mode": "AIRCRAFT", "duration": "3–6 min"},
		{"id": "race", "title": "两岸计时赛", "description": "驾驶汽车或摩托车依次穿过大桥检查点，速度与安全表现决定奖金。", "reward": 380, "mode": "CAR / MOTORCYCLE", "duration": "3–5 min"}]

func start_job(job_id: String) -> String:
	if not active_job.is_empty():
		return "Finish or cancel your current activity before taking another."
	var definition: Dictionary = {}
	for entry in job_catalog():
		if str(entry.id) == job_id:
			definition = entry
			break
	if definition.is_empty():
		return "That activity is not available."
	_jobs_started += 1
	active_job = {"id": job_id, "title": definition.title, "reward": definition.reward,
		"stage": 0, "elapsed": 0.0, "dwell": 0.0, "incidents": 0, "hint": "", "instance": _jobs_started}
	if job_id == "salvage":
		_prepare_salvage()
	_update_hint()
	activity_changed.emit()
	var response := "Started: " + str(definition.title) + ". " + str(active_job.hint)
	notification.emit(response)
	return response

func cancel_job() -> String:
	if active_job.is_empty():
		return "No activity is currently running."
	active_job = {}
	_marker.visible = false
	status_text = "Activity cancelled. Your cargo and world remain where you left them."
	activity_changed.emit()
	return status_text

func _prepare_salvage() -> void:
	# Reuse stable physical objects; repeated jobs do not leak bodies into the world.
	var recovery := _point("salvage", _home() + Vector3(65, 0, -28))
	var selected: HarborCargo
	for item in cargo:
		if item != carried_cargo and not item.stored and item.global_position.distance_to(_delivery()) > 12.0:
			selected = item
			break
	if not is_instance_valid(selected):
		for item in cargo:
			if item != carried_cargo and not item.stored:
				selected = item
				break
	if not is_instance_valid(selected):
		selected = CargoScript.new() as HarborCargo
		selected.configure("life_cargo_%02d" % cargo.size(), recovery + Vector3.UP * 0.65)
		add_child(selected)
		cargo.append(selected)
	# A crate already stored or carried is never teleported by job creation.
	if selected.global_position.distance_to(_delivery()) < 12.0 or selected.global_position.y < -10.0:
		selected.freeze = false
		selected.global_position = recovery + Vector3.UP * 0.65
		selected.linear_velocity = Vector3.ZERO
	selected.cargo_kind = "salvage"
	_mission_crate_id = selected.stable_id
	active_job["cargo_id"] = selected.stable_id

func _job_route(job_id: String) -> Array:
	match job_id:
		"photo": return _route("photo_route", [_point("opera", Vector3(390, 4.5, -370)) + Vector3(-20, 0, 40), _point("quay", Vector3(80, 4.5, 260)), _point("north", Vector3(20, 4.5, -1080))])
		"harbor": return _route("harbor_route", [Vector3(160, 0.5, 40), Vector3(450, 0.5, -660), Vector3(-250, 0.5, -650)])
		"air": return _route("air_route", [Vector3(500, 120, -220), Vector3(-150, 150, -550), Vector3(300, 135, -1250)])
		"race": return _route("race_route", [_home() + Vector3(0, 0, 40), Vector3(-160, 5, 260), Vector3(-430, 25, -120), Vector3(-440, 52, -670), Vector3(-450, 25, -1200)])
	return []

func get_objective() -> Dictionary:
	if active_job.is_empty():
		return {}
	var id := str(active_job.id)
	if id == "salvage":
		var item := _find_cargo(str(active_job.get("cargo_id", "")))
		if int(active_job.stage) == 0 and is_instance_valid(item):
			return {"position": item.global_position, "label": "Recover case · G", "kind": "cargo"}
		return {"position": _delivery(), "label": "Workshop · E unload", "kind": "delivery"}
	var route := _job_route(id)
	var stage := int(active_job.stage)
	if stage >= route.size():
		return {}
	var label := "VIEWPOINT · E PHOTO" if id == "photo" else "INSPECTION · SLOW BOAT" if id == "harbor" else "SURVEY AREA" if id == "air" else "TIME TRIAL GATE"
	return {"position": route[stage], "label": "%s  %d/%d" % [label, stage + 1, route.size()], "kind": id}

func tick_context(player_pos: Vector3, player_vehicle: String, speed: float, delta: float) -> void:
	if not _ready_to_work:
		return
	_player_pos = player_pos
	_player_vehicle = player_vehicle.to_lower()
	_speed = absf(speed)
	var movement := player_pos - _last_player_pos
	movement.y = 0
	if movement.length() > 0.02 and movement.length() < 100.0:
		_carry_direction = _carry_direction.lerp(movement.normalized(), minf(delta * 6.0, 1.0)).normalized()
	_last_player_pos = player_pos
	if is_instance_valid(carried_cargo):
		var offset := Vector3.UP * 1.0 + _carry_direction * 1.05
		if not _on_foot():
			offset = Vector3.UP * 0.7 - _carry_direction * 1.2
		carried_cargo.global_position = player_pos + offset
		carried_cargo.rotation.y = atan2(_carry_direction.x, _carry_direction.z)
	for item in cargo:
		item.update_visibility(player_pos)
	for npc in npcs:
		npc.update_context(player_pos, player_vehicle, speed)
	_hint_timer += delta
	if active_job.is_empty():
		_marker.visible = false
		return
	active_job["elapsed"] = float(active_job.get("elapsed", 0.0)) + delta
	var objective := get_objective()
	if not objective.is_empty():
		_marker.visible = true
		_marker.global_position = objective.position + Vector3.UP * 0.15
		_marker_phase += delta
		_marker.rotation.y += delta * 0.16
		_marker_label.global_position = _marker.global_position + Vector3.UP * (4.0 + sin(_marker_phase) * 0.25)
		var distance := player_pos.distance_to(objective.position)
		_marker_label.text = str(objective.label) + "\n%d m" % int(distance)
		_marker_label.visible = distance < 1100.0
		_marker.scale = Vector3.ONE * (8.0 if str(active_job.id) == "air" else 2.0 if str(active_job.id) == "harbor" else 1.0)
	_update_job(delta)
	if _hint_timer > 0.4:
		_hint_timer = 0.0
		_update_hint()

func _on_foot() -> bool:
	return _player_vehicle in ["", "foot", "walk", "walking", "none", "on_foot"]

func _is_boat() -> bool:
	return "boat" in _player_vehicle or "yacht" in _player_vehicle or "launch" in _player_vehicle

func _is_aircraft() -> bool:
	return "helicopter" in _player_vehicle or "glider" in _player_vehicle or "plane" in _player_vehicle or "airliner" in _player_vehicle or "jet" in _player_vehicle or "paraglid" in _player_vehicle

func _is_road() -> bool:
	return "car" in _player_vehicle or "motor" in _player_vehicle or "coupe" in _player_vehicle or "roadster" in _player_vehicle

func _update_job(delta: float) -> void:
	if active_job.is_empty():
		return
	var id := str(active_job.id)
	if id == "salvage":
		var item := _find_cargo(str(active_job.get("cargo_id", "")))
		if is_instance_valid(item) and item.carried:
			active_job["stage"] = 1
		return
	if id == "photo":
		return
	var objective := get_objective()
	if objective.is_empty():
		return
	var distance := _player_pos.distance_to(objective.position)
	var valid := false
	var dwell_required := 0.0
	match id:
		"harbor":
			valid = _is_boat() and distance < 27.0 and _speed < 3.0
			dwell_required = 2.0
		"air":
			valid = _is_aircraft() and distance < 85.0 and _player_pos.y > 45.0
			dwell_required = 0.15
		"race":
			valid = _is_road() and distance < 21.0 and _speed > 1.0
			dwell_required = 0.05
	if valid:
		active_job["dwell"] = float(active_job.get("dwell", 0.0)) + delta
		if float(active_job.dwell) >= dwell_required:
			_advance_stage()
	else:
		active_job["dwell"] = 0.0

func _advance_stage() -> void:
	var id := str(active_job.id)
	active_job["stage"] = int(active_job.stage) + 1
	active_job["dwell"] = 0.0
	if int(active_job.stage) >= _job_route(id).size():
		_complete_job()
	else:
		notification.emit("%s · checkpoint %d complete" % [str(active_job.title), int(active_job.stage)])
		_update_hint()
		activity_changed.emit()

func _complete_job() -> void:
	var id := str(active_job.id)
	var reward := int(active_job.reward)
	var time := float(active_job.elapsed)
	var bonus := 0
	if id == "race":
		bonus = maxi(0, int((240.0 - time) * 1.5))
		bonus = maxi(0, bonus - int(active_job.get("incidents", 0)) * 60)
	if id == "salvage":
		var item := _find_cargo(str(active_job.get("cargo_id", "")))
		if is_instance_valid(item):
			reward = int(float(reward) * (0.7 + 0.3 * item.integrity))
	reward += bonus
	money += reward
	lifetime_earnings += reward
	completed_jobs[id] = int(completed_jobs.get(id, 0)) + 1
	for npc in npcs:
		if npc.job_id == id:
			npc.memories["jobs_completed"] = int(npc.memories.get("jobs_completed", 0)) + 1
	status_text = "%s complete · +$%d · %d:%02d" % [str(active_job.title), reward, int(time) / 60, int(time) % 60]
	if bonus > 0:
		status_text += " · $%d time bonus" % bonus
	active_job = {}
	_marker.visible = false
	notification.emit(status_text)
	money_changed.emit(money)
	activity_changed.emit()

func _update_hint() -> void:
	if active_job.is_empty():
		return
	var id := str(active_job.id)
	var stage := int(active_job.stage)
	var objective := get_objective()
	var distance := 0
	if not objective.is_empty():
		distance = int(_player_pos.distance_to(objective.position))
	var hint := ""
	match id:
		"photo": hint = "Viewpoint %d/%d · %d m · On foot, stop and press E to take a photo." % [stage + 1, _job_route(id).size(), distance]
		"salvage": hint = "Recover marked case · %d m · G to carry. Any transport is allowed." % distance if stage == 0 else "Bring case to workshop · %d m · E to unload within 7 m." % distance
		"harbor": hint = "Station %d/%d · %d m · In a boat, slow below 3 m/s for 2 seconds." % [stage + 1, _job_route(id).size(), distance]
		"air": hint = "Survey %d/%d · %d m · Fly through the amber area above 45 m." % [stage + 1, _job_route(id).size(), distance]
		"race": hint = "Gate %d/%d · %d m · %d:%02d elapsed · Car or motorcycle." % [stage + 1, _job_route(id).size(), distance, int(active_job.elapsed) / 60, int(active_job.elapsed) % 60]
	active_job["hint"] = hint
	status_text = str(active_job.title) + "\n" + hint

func available_actions(player_pos: Vector3) -> String:
	if not active_job.is_empty() and str(active_job.id) == "photo":
		var target := get_objective()
		if not target.is_empty() and player_pos.distance_to(target.position) < 16.0:
			return "E  Photograph viewpoint · Stop on foot"
	if player_pos.distance_to(_delivery()) < 7.0 and (is_instance_valid(carried_cargo) or (not active_job.is_empty() and str(active_job.id)=="salvage")):
		return "E  Unload at workshop   G  Put down case"
	if player_pos.distance_to(_board()) < 6.0:
		return "E  Harbour Exchange · Choose work"
	var npc := _nearest_npc(player_pos)
	if is_instance_valid(npc):
		return "E  Talk to " + npc.display_name
	if player_pos.distance_to(_home()) < 8.0:
		return "E  Workshop storage · %d cases stored" % stored_count()
	if is_instance_valid(carried_cargo):
		return "G  Put down case · Transport it with any vehicle"
	var item := _nearest_cargo(player_pos)
	if is_instance_valid(item):
		return "G  Carry salvage case · 32 kg"
	return ""

func interact(player_pos: Vector3) -> String:
	_player_pos = player_pos
	if not active_job.is_empty() and str(active_job.id) == "photo":
		var target := get_objective()
		if not target.is_empty() and player_pos.distance_to(target.position) < 16.0:
			if not _on_foot():
				return "Step out of the vehicle to compose this photograph."
			if _speed > 1.2:
				return "Hold still for a clear harbour photograph."
			_advance_stage()
			return "Photograph captured. " + ("The next viewpoint is marked." if not active_job.is_empty() else "Your photo set is complete.")
	if player_pos.distance_to(_delivery()) < 7.0 and (is_instance_valid(carried_cargo) or (not active_job.is_empty() and str(active_job.id)=="salvage")):
		return deposit_cargo(player_pos)
	if player_pos.distance_to(_board()) < 6.0:
		return "OPEN_JOBS"
	var npc := _nearest_npc(player_pos)
	if is_instance_valid(npc):
		return npc.talk(active_job, completed_jobs)
	if player_pos.distance_to(_home()) < 8.0:
		for item in cargo:
			if item.stored:
				carried_cargo = item
				item.set_carried(true)
				return "Retrieved a case from your workshop. G puts it down; E stores it again."
		return "Your workshop · %d cases stored. Carry a case here and press E to store it. Use your fleet panel for repairs and recovery." % stored_count()
	var nearby := _nearest_cargo(player_pos)
	if is_instance_valid(nearby):
		return toggle_carry(player_pos)
	return "No one or nothing close enough to interact with. Move closer to a person, the exchange or a case."

func toggle_carry(player_pos: Vector3) -> String:
	if is_instance_valid(carried_cargo):
		var item := carried_cargo
		carried_cargo = null
		item.set_carried(false)
		item.linear_velocity = _carry_direction * minf(_speed, 12.0)
		return "Case released. It remains a physical object in this world."
	var item := _nearest_cargo(player_pos)
	if not is_instance_valid(item):
		return "No case within 3.5 m. The amber recovery marker shows your assigned case."
	carried_cargo = item
	item.set_carried(true)
	if not active_job.is_empty() and str(active_job.get("cargo_id", "")) == item.stable_id:
		active_job["stage"] = 1
		_update_hint()
	return "Carrying 32 kg case. Enter any vehicle to transport it; G releases it."

func deposit_cargo(player_pos: Vector3) -> String:
	if player_pos.distance_to(_delivery()) >= 7.0:
		return "Bring the case to the workshop unloading point."
	if not is_instance_valid(carried_cargo):
		# A freely dropped case also counts: the delivery depends on the object,
		# not on the carrier flag or a menu action.
		if not active_job.is_empty() and str(active_job.id) == "salvage":
			var loose := _find_cargo(str(active_job.get("cargo_id", "")))
			if is_instance_valid(loose) and loose.global_position.distance_to(_delivery()) < 7.0 and loose.linear_velocity.length() < 2.0:
				_complete_job()
				return status_text
		return "Carry a case to the unloading point, then press E."
	var item := carried_cargo
	carried_cargo = null
	var storage_index := stored_count()
	item.stow(_home() + Vector3(2.5 + float(storage_index % 3) * 1.0, 0.4 + float(storage_index / 3) * 0.72, 2.0))
	if not active_job.is_empty() and str(active_job.id) == "salvage" and str(active_job.get("cargo_id", "")) == item.stable_id:
		# Recovered freight is sold to the exchange. The case remains visible at
		# the unloading area and is reused by later jobs instead of duplicating.
		item.stored = false
		item.freeze = false
		_complete_job()
		return status_text
	return "Case stored in your workshop. It will be here when you return."

func stored_count() -> int:
	var result := 0
	for item in cargo:
		if item.stored:
			result += 1
	return result

func _nearest_npc(player_pos: Vector3) -> HarborNPC:
	var best: HarborNPC
	var distance := 3.2
	for npc in npcs:
		var next := npc.global_position.distance_to(player_pos)
		if next < distance:
			best = npc
			distance = next
	return best

func _nearest_cargo(player_pos: Vector3) -> HarborCargo:
	var best: HarborCargo
	var distance := 3.5
	for item in cargo:
		if item.carried:
			continue
		var next := item.global_position.distance_to(player_pos)
		if next < distance:
			best = item
			distance = next
	return best

func _find_cargo(object_id: String) -> HarborCargo:
	for item in cargo:
		if item.stable_id == object_id:
			return item
	return null

func purchase(asset: String, cost: int) -> bool:
	if cost < 0:
		return false
	if money < cost and not sandbox:
		notification.emit("You need $%d more. Harbour work pays for ownership and repairs." % (cost - money))
		return false
	if not sandbox:
		money -= cost
	owned_assets[asset] = true
	money_changed.emit(money)
	return true

func spend(cost: int, reason: String = "") -> bool:
	if cost < 0 or (not sandbox and money < cost):
		return false
	if not sandbox:
		money -= cost
	money_changed.emit(money)
	if not reason.is_empty():
		notification.emit(reason + (" · Free in sandbox" if sandbox else " · $%d" % cost))
	return true

func recover_cargo() -> String:
	var recovered := 0
	for item in cargo:
		if item == carried_cargo or item.stored:
			continue
		if item.global_position.y < -4.0 or item.global_position.distance_to(_home()) > 2500.0:
			item.freeze = false
			item.global_position = _home() + Vector3(4.0 + recovered, 1.0, 5)
			item.linear_velocity = Vector3.ZERO
			item.angular_velocity = Vector3.ZERO
			recovered += 1
	return "%d lost cases recovered to your workshop." % recovered

func on_incident(pos: Vector3, severity: float) -> void:
	for npc in npcs:
		npc.witness_incident(pos, severity)
	if not active_job.is_empty() and severity > 8.0:
		active_job["incidents"] = int(active_job.get("incidents", 0)) + 1

func get_state() -> Dictionary:
	var cargo_states: Array = []
	for item in cargo:
		cargo_states.append(item.get_state())
	var npc_states: Array = []
	for npc in npcs:
		npc_states.append(npc.get_state())
	return {"version": 2, "money": money, "active_job": active_job.duplicate(true),
		"owned_assets": owned_assets.duplicate(true), "completed_jobs": completed_jobs.duplicate(true),
		"lifetime_earnings": lifetime_earnings, "jobs_started": _jobs_started,
		"cargo": cargo_states, "npcs": npc_states}

func apply_state(state: Dictionary) -> void:
	money = maxi(0, int(state.get("money", 50000 if sandbox else 1200)))
	active_job = state.get("active_job", {}).duplicate(true)
	owned_assets = state.get("owned_assets", {"workshop": true}).duplicate(true)
	completed_jobs = state.get("completed_jobs", {}).duplicate(true)
	lifetime_earnings = maxi(0, int(state.get("lifetime_earnings", 0)))
	_jobs_started = int(state.get("jobs_started", 0))
	carried_cargo = null
	for cargo_state in state.get("cargo", []):
		if not cargo_state is Dictionary:
			continue
		var object_id := str(cargo_state.get("id", ""))
		if not object_id.begins_with("life_cargo_"):
			continue
		var item := _find_cargo(object_id)
		if not is_instance_valid(item):
			item = CargoScript.new() as HarborCargo
			item.configure(object_id, _home() + Vector3.UP)
			add_child(item)
			cargo.append(item)
		item.apply_state(cargo_state)
		if item.carried:
			if not is_instance_valid(carried_cargo):
				carried_cargo = item
			else:
				item.set_carried(false)
	for npc_state in state.get("npcs", []):
		if not npc_state is Dictionary:
			continue
		for npc in npcs:
			if npc.stable_id == str(npc_state.get("id", "")):
				npc.apply_state(npc_state)
	if not active_job.is_empty():
		if str(active_job.get("id", "")) == "salvage" and not is_instance_valid(_find_cargo(str(active_job.get("cargo_id", "")))):
			_prepare_salvage()
		_update_hint()
	money_changed.emit(money)
	activity_changed.emit()
