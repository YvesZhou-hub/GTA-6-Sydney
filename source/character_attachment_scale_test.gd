extends SceneTree
## Actual imported resident, hand bone and production blaster; no city or saves.
const Player = preload("res://scripts/harbor_player.gd")
const Survival = preload("res://scripts/harbor_survival.gd")
const STATES := ["idle", "idle_armed", "walk", "run", "run_armed", "fire", "hit", "air", "death"]
var checks: Array = []
var samples: Dictionary = {}
var failures := 0
var host: Fixture

class Fixture:
	extends Node3D
	var player: Node3D

func _init() -> void: call_deferred("run")

func check(label: String, passed: bool, evidence: Dictionary = {}) -> void:
	checks.append({"name":label, "passed":passed, "evidence":evidence})
	if not passed: failures += 1
	print("ATTACHMENT ", "PASS " if passed else "FAIL ", label, " ", JSON.stringify(evidence))

func vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func gun_bounds(gun: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh: MeshInstance3D in gun.get_children():
		var box: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

func finish() -> void:
	var report := {"passed":failures == 0, "checks":checks, "samples":samples,
		"scope":"Imported casual resident, actual Wrist.R bone attachment and production survival blaster across nine animations; no world or player saves",
		"native_ios":false, "source_sha256":FileAccess.get_sha256("res://scripts/character_visual.gd")}
	var directory := ProjectSettings.globalize_path("res://../reports/character-attachment-scale")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	# Also free on an early failure, so a missing model/bone never leaves a
	# running fixture or continues into gameplay callbacks with a partial host.
	if is_instance_valid(host): host.free()
	print("CHARACTER_ATTACHMENT_COMPLETE checks=", checks.size(), " failures=", failures)
	quit(1 if failures else 0)

func run() -> void:
	host = Fixture.new()
	root.add_child(host)
	host.player = Player.new()
	host.add_child(host.player)
	host.player.set_physics_process(false)
	host.player.visual.set_process(false)
	var animation: AnimationPlayer = host.player.visual._player
	check("Production resident has an imported animation rig", is_instance_valid(animation))
	if not is_instance_valid(animation): finish(); return
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var director := Survival.new()
	host.add_child(director)
	director.set_physics_process(false)
	director.set_process(false)
	director.game = host
	director._build_blaster()
	var gun: Node3D = director._gun
	var attachment := gun.get_parent()
	check("Production blaster mounts on the actual right wrist", attachment is BoneAttachment3D and attachment.bone_name == "Wrist.R")
	if not attachment is BoneAttachment3D: finish(); return
	var skeleton: Skeleton3D = attachment.get_parent()
	var bone := skeleton.find_bone("Wrist.R")
	check("Repeated mount requests reuse the same attachment", host.player.visual.mount("Wrist.R") == attachment)
	var first_pose := Transform3D.IDENTITY
	var last_pose := Transform3D.IDENTITY
	var saw_scaled_bone := false
	for state: String in STATES:
		var clip: String = host.player.visual._clip(state)
		check(state + " resolves a real animation clip", not clip.is_empty())
		if clip.is_empty(): continue
		host.player.visual.set_state(state, 1.0, true)
		# Finish the production 0.18-second crossfade before seeking samples;
		# seek alone would retain the previous clip's blend pose at zero time.
		animation.advance(.2)
		await process_frame
		var length := animation.get_animation(clip).length
		var poses: Array = []
		var size_ok := true
		var offset_ok := true
		var follows_bone := true
		for sample in 3:
			# Include a translated and rotated resident: a world-space scale
			# correction must still carry the weapon along with the hand.
			host.player.position = Vector3(321, 17, -456) if sample == 2 else Vector3.ZERO
			host.player.rotation.y = .83 if sample == 2 else 0.0
			animation.seek(length * [.05, .35, .75][sample], true)
			animation.advance(0.0)
			await process_frame
			var bone_pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone)
			saw_scaled_bone = saw_scaled_bone or bone_pose.basis.get_scale().length() > 20.0
			var expected := Transform3D(bone_pose.basis.orthonormalized(), bone_pose.origin) * gun.transform
			var bounds := gun_bounds(gun)
			var scale_error := gun.global_basis.get_scale().distance_to(Vector3.ONE)
			var offset := gun.global_position.distance_to(bone_pose.origin)
			var position_error := gun.global_position.distance_to(expected.origin)
			var basis_error := maxf(gun.global_basis.x.distance_to(expected.basis.x), maxf(gun.global_basis.y.distance_to(expected.basis.y), gun.global_basis.z.distance_to(expected.basis.z)))
			size_ok = size_ok and bounds.size.is_finite() and bounds.size.length() < 1.35 and scale_error < .001
			offset_ok = offset_ok and offset < .20 and position_error < .002
			follows_bone = follows_bone and attachment.global_position.distance_to(bone_pose.origin) < .002 and basis_error < .001
			poses.append({"world_size_m":vector(bounds.size), "scale_error":scale_error, "wrist_offset_m":offset, "position_error_m":position_error, "basis_error":basis_error})
			if state == "idle" and sample == 0: first_pose = gun.global_transform
			last_pose = gun.global_transform
		samples[state] = poses
		check(state + " keeps the blaster below human scale through the clip", size_ok, {"samples":poses})
		check(state + " keeps authored gun offsets in metres at the wrist", offset_ok)
		check(state + " preserves animated bone position and rotation", follows_bone)
	check("Fixture exercises the original imported bone scale rather than a unit-scale substitute", saw_scaled_bone)
	check("Weapon follows animation and resident motion instead of staying at one fixed pose", not first_pose.is_equal_approx(last_pose))
	finish()
