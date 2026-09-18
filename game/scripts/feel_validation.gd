extends Node
## Evidence for how a fight feels and how hard it is: difficulty scaling on real
## spawned enemies, knockback, camera shake, recoil and the damage arcs.
const OUTPUT := "user://feel-qa"
const Progression = preload("res://scripts/combat_progression.gd")
var game: Node
var survival: Node
var feel: Node
var checks: Array[Dictionary] = []
var native := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func check(title: String, okay: bool, detail: Dictionary = {}) -> void:
	checks.append({"name": title, "passed": okay, "detail": detail})
	print("FEEL_QA ", "PASS " if okay else "FAIL ", title, " ", JSON.stringify(detail))

func frames(count: int = 3) -> void:
	for _i in count: await get_tree().process_frame

func physics(count: int = 10) -> void:
	for _i in count: await get_tree().physics_frame

func capture(name: String) -> void:
	if not native: return
	await frames(3)
	var started := Time.get_ticks_msec()
	var target := Engine.get_frames_drawn() + 1
	while Engine.get_frames_drawn() < target and Time.get_ticks_msec() - started < 30000: await get_tree().process_frame
	get_tree().root.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png"))

func spawn(kind: String, offset: Vector3) -> Node3D:
	return survival.spawn_enemy(kind, game.player.global_position + offset, -1.0, 1)

func run(host: Node) -> void:
	game = host
	survival = game.survival
	feel = game.combat_feel
	native = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await frames(3)
	if not game.world._ready_complete:
		check("production world assembled", false)
		return finish()
	game.qa_running = true
	game.new_world("life", "Feel QA - no save", false)
	survival.auto_spawn = false
	await frames(20)
	survival.clear_enemies()

	# Difficulty scales the reinforcements a player actually meets.
	var stats := {}
	for index in 3:
		game.settings.combat_difficulty = index
		survival.clear_enemies()
		var enemy: Node3D = spawn("roamer", Vector3(6, 0, 0))
		await frames(2)
		stats[index] = {"health": enemy.max_health, "damage": float(enemy.spec.damage), "reward": int(enemy.spec.reward),
			"wanted": survival.desired_enemies(), "level": survival.encounter_level()}
	check("easier enemies have less health, hardcore more",
		float(stats[0].health) < float(stats[1].health) and float(stats[1].health) < float(stats[2].health), stats)
	check("difficulty scales the damage they deal",
		float(stats[0].damage) < float(stats[1].damage) and float(stats[1].damage) < float(stats[2].damage))
	check("hardcore pays more per kill", int(stats[2].reward) > int(stats[1].reward) and int(stats[0].reward) < int(stats[1].reward))
	check("hardcore keeps more of them around", int(stats[2].wanted) > int(stats[1].wanted) and int(stats[0].wanted) <= int(stats[1].wanted), stats)
	check("the level shifts with difficulty", int(stats[0].level) <= int(stats[1].level) and int(stats[2].level) >= int(stats[1].level))
	game.settings.combat_difficulty = 1
	survival.reset_mode(true)
	var standard_grace: float = survival.grace
	game.settings.combat_difficulty = 0
	survival.reset_mode(true)
	check("easy gives longer entry protection", survival.grace > standard_grace, {"easy": survival.grace, "standard": standard_grace})
	game.settings.combat_difficulty = 1
	survival.reset_mode(true)
	survival.auto_spawn = false

	# Liberating districts is part of the pressure, not only cleared waves.
	var before_level: int = survival.encounter_level()
	game.districts.liberated["quay"] = true
	game.districts.liberated["rocks"] = true
	check("taking districts back raises the encounter level", survival.encounter_level() > before_level,
		{"before": before_level, "after": survival.encounter_level()})
	game.districts.reset()

	# A hit shoves a light enemy and barely moves a brute.
	survival.clear_enemies()
	var runner: Node3D = spawn("runner", Vector3(8, 0, 0))
	var brute: Node3D = spawn("brute", Vector3(-8, 0, 0))
	await physics(4)
	var runner_start: Vector3 = runner.global_position
	var brute_start: Vector3 = brute.global_position
	runner.take_damage(40.0, runner.global_position + Vector3(-1.2, 0, 0))
	brute.take_damage(40.0, brute.global_position + Vector3(1.2, 0, 0))
	await physics(14)
	var runner_moved: float = runner_start.distance_to(runner.global_position)
	var brute_moved: float = brute_start.distance_to(brute.global_position)
	check("a hit knocks a light Nailong back", runner_moved > 0.25, {"moved": snappedf(runner_moved, 0.01)})
	check("a brute shrugs the same hit off", brute_moved < runner_moved, {"brute": snappedf(brute_moved, 0.01), "runner": snappedf(runner_moved, 0.01)})
	survival.clear_enemies()

	# Feedback: shake, recoil, damage arcs and the low-health rim.
	feel.trauma = 0.0
	feel.recoil = 0.0
	survival.fire_blaster()
	check("firing kicks the view", feel.recoil > 0.0 and feel.trauma > 0.0, {"recoil": snappedf(feel.recoil, 0.001), "trauma": snappedf(feel.trauma, 0.001)})
	var camera: Camera3D = game.camera
	feel.shake(1.0)
	var before_position: Vector3 = camera.global_position
	for i in 6: feel.apply_camera(camera, 0.016)
	check("shake moves the camera and nothing else", before_position.distance_to(camera.global_position) > 0.002,
		{"offset": snappedf(before_position.distance_to(camera.global_position), 0.001)})
	feel.trauma = 0.0
	feel._offset = Vector3.ZERO
	game.player.health = 120.0
	game.player.take_damage(24.0, game.player.global_position + Vector3(0, 0, -9))
	await frames(2)
	check("being hit shakes the view", feel.trauma > 0.0, {"trauma": snappedf(feel.trauma, 0.001)})
	check("an arc records where the hit came from", feel.hits().size() == 1, {"hits": feel.hits().size()})
	check("the rim only appears when health is low", feel.health_ratio() > feel.VIGNETTE_AT)
	game.player.health = 30.0
	check("low health crosses the rim threshold", feel.health_ratio() < feel.VIGNETTE_AT, {"ratio": snappedf(feel.health_ratio(), 0.01)})
	await capture("low-health")
	await get_tree().create_timer(feel.HIT_SECONDS + 0.4, true, false, true).timeout
	check("arcs fade away on their own", feel.hits().is_empty())
	check("shake settles back to nothing", feel.trauma < 0.05, {"trauma": snappedf(feel.trauma, 0.001)})
	game.player.reset_health()
	finish()

func finish() -> void:
	var passed := not checks.is_empty() and checks.all(func(row: Dictionary): return row.passed)
	var file := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"passed": passed, "native": native, "checks": checks}, "\t"))
	print("FEEL_QA COMPLETE checks=%d failures=%d" % [checks.size(), checks.filter(func(row: Dictionary): return not row.passed).size()])
	game.active = false
	game.finish_quit(0 if passed else 1)
