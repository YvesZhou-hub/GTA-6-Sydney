extends SceneTree
## Export the production synthesizer's samples for matching trailer sound cues.
func _initialize():
	var folder := "res://../reports/promo-audio"
	DirAccess.make_dir_recursive_absolute(folder)
	var synth = load("res://scripts/weapon_audio.gd")
	for kind in ["tank", "fighter", "impact"]:
		var stream: AudioStreamWAV = synth.stream(kind)
		var result := stream.save_to_wav(folder + "/" + kind + ".wav")
		if result != OK: quit(1); return
	print("PROMO_PRODUCTION_AUDIO_EXPORTED")
	quit()
