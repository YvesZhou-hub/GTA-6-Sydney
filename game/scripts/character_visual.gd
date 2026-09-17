extends Node3D
## Animated resident, pedestrian and enemy-facing character model.
## Gameplay code asks for a state ("walk", "run", "hit"); this picks the clip,
## loops the ones that should loop and keeps the model facing where it moves.
## Models are CC0 by Quaternius; see assets/thirdparty/SOURCES.md.

const MODELS := {
	"casual": "res://assets/thirdparty/characters/man_casual.glb",
	"hoodie": "res://assets/thirdparty/characters/man_hoodie.glb",
	"business": "res://assets/thirdparty/characters/man_business.glb",
	"worker": "res://assets/thirdparty/characters/man_worker.glb",
	"punk": "res://assets/thirdparty/characters/man_punk.glb",
	"beach": "res://assets/thirdparty/characters/man_beach.glb",
	"suit_woman": "res://assets/thirdparty/characters/woman_suit.glb",
	"worker_woman": "res://assets/thirdparty/characters/woman_worker.glb",
	"casual_woman": "res://assets/thirdparty/characters/woman_casual.glb",
	"punk_woman": "res://assets/thirdparty/characters/woman_punk.glb",
}
## Gameplay state to clip, in order of preference.
const STATES := {
	"idle": ["Idle"],
	"idle_armed": ["Idle_Gun", "Idle"],
	"walk": ["Walk"],
	"run": ["Run"],
	"run_armed": ["Run_Shoot", "Run"],
	"air": ["Roll", "Run"],
	"swim": ["Run", "Walk"],
	"fire": ["Gun_Shoot", "Punch_Right"],
	"punch": ["Punch_Right", "Gun_Shoot"],
	"hit": ["HitRecieve", "Idle"],
	"death": ["Death"],
	"wave": ["Wave", "Idle"],
	"interact": ["Interact", "Wave"],
	"sit": ["Idle_Neutral", "Idle"],
}
const LOOPING := ["idle", "idle_armed", "walk", "run", "run_armed", "swim", "sit"]
const PREFIX := "CharacterArmature|"

static var _scenes: Dictionary = {}

var model_key := ""
var state := ""
var _player: AnimationPlayer
var _model: Node3D
var _hold := 0.0


static func model_keys() -> Array:
	return MODELS.keys()


static func scene(key: String) -> PackedScene:
	var path: String = MODELS.get(key, MODELS.casual)
	if not _scenes.has(path): _scenes[path] = load(path)
	return _scenes[path]


## Builds the model. A height in metres rescales it; 0 keeps the model's own size.
func setup(key: String, height := 0.0) -> void:
	model_key = key if MODELS.has(key) else "casual"
	_model = scene(model_key).instantiate()
	add_child(_model)
	for found: AnimationPlayer in _model.find_children("*", "AnimationPlayer", true, false):
		_player = found
		break
	if is_instance_valid(_player):
		# Imported clips arrive without loop flags; the walk cycle must not stop.
		for name: String in LOOPING:
			var clip := _clip(name)
			if clip != "": _player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	if height > 0.0:
		var current := measure_height()
		if current > 0.1: _model.scale = Vector3.ONE * (height / current)
	set_state("idle")


## Skinned meshes carry a bone-space bounding box, so each mesh is measured in
## world space. Imported children are not owned by this node, hence owned = false.
func measure_height() -> float:
	if not is_inside_tree(): return 0.0
	var top := 0.0
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.get_global_transform() * mesh.get_aabb()
		top = maxf(top, box.position.y + box.size.y)
	return maxf(0.0, top - global_position.y)


func _clip(name: String) -> String:
	if not is_instance_valid(_player): return ""
	for candidate: String in STATES.get(name, []):
		if _player.has_animation(PREFIX + candidate): return PREFIX + candidate
		if _player.has_animation(candidate): return candidate
	return ""


## One-shot states (hit, fire, wave) hold until they finish, then fall back.
func set_state(next: String, speed := 1.0, force := false) -> void:
	if not is_instance_valid(_player): return
	if _hold > 0.0 and not force and next != state: return
	var clip := _clip(next)
	if clip == "": return
	_player.speed_scale = maxf(0.05, speed)
	if next == state and _player.is_playing(): return
	state = next
	_player.play(clip, 0.18)
	_hold = 0.0 if next in LOOPING else _player.get_animation(clip).length / maxf(0.05, speed)


func playing_one_shot() -> bool:
	return _hold > 0.0


func _process(delta: float) -> void:
	if _hold > 0.0: _hold = maxf(0.0, _hold - delta)


## Smoothly turns the model towards a travel direction on the ground plane.
func face(direction: Vector3, delta: float, speed := 12.0) -> void:
	if direction.length_squared() < 0.0004: return
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), clampf(delta * speed, 0.0, 1.0))


## A node that follows a bone, for held items. Created once per bone.
func mount(bone: String) -> Node3D:
	for skeleton: Skeleton3D in find_children("*", "Skeleton3D", true, false):
		if skeleton.find_bone(bone) < 0: continue
		for existing: BoneAttachment3D in skeleton.find_children("*", "BoneAttachment3D", false, false):
			if existing.bone_name == bone and existing.name.begins_with("Mount"): return existing
		var point := BoneAttachment3D.new()
		point.name = "Mount_" + bone
		skeleton.add_child(point)
		point.bone_name = bone
		return point
	return self
