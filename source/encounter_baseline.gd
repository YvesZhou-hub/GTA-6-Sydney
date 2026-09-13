extends SceneTree
## Read-only game-state probe: production city and automatic director, no saves.
const Main = preload("res://scripts/main.gd")
func _initialize(): call_deferred("run")
func run():
	var game = Main.new()
	game.qa_running = true
	root.add_child(game)
	await process_frame
	game.active = false
	game.new_world("life", "Unsaved encounter baseline", false)
	game.world_id = "qa_encounter_baseline_unsaved"
	game.set_process(false)
	game.survival._rng.seed = 20260913
	for vehicle in game.vehicles: vehicle.freeze = true
	var initial: Vector3 = game.player.global_position
	game.camera.global_position = initial + Vector3(0, 4, 8)
	game.camera.look_at(initial + Vector3(0, 1.5, -10))
	var first := -1.0
	var nearby := -1.0
	var damage := -1.0
	var closest := INF
	for frame in 3600:
		await physics_frame
		var elapsed := (frame + 1) / 60.0
		if not game.survival.enemies.is_empty() and first < 0.0: first = elapsed
		for enemy in game.survival.enemies:
			if is_instance_valid(enemy): closest = minf(closest, enemy.global_position.distance_to(game.player.global_position))
		if closest < 8.0 and nearby < 0.0: nearby = elapsed
		if game.player.health < 120.0 and damage < 0.0: damage = elapsed
	var report := {"scope":"Production default home, automatic encounters, 60 simulation seconds at fixed 60 Hz; no save reads/writes", "first_spawn_s":first,"first_within_8m_s":nearby,"first_damage_s":damage,"closest_m":closest if is_finite(closest) else -1,"remaining_health":game.player.health,"wave_spawned":game.survival.wave_spawned,"enemies":game.survival.enemies.size(),"initial":str(initial),"final":str(game.player.global_position)}
	DirAccess.make_dir_recursive_absolute("res://../reports/encounter-baseline")
	var output := FileAccess.open("res://../reports/encounter-baseline/report.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")); output.close()
	print("ENCOUNTER_BASELINE ",JSON.stringify(report))
	game.active = false
	game.finish_quit(0)
