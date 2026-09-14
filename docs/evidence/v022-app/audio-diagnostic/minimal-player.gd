extends SceneTree
var player: AudioStreamPlayer
var last_mix := 0.0
var cycles := 0
var playback: WeakRef
var wave: WeakRef
func _initialize() -> void: call_deferred("run")
func sample() -> void:
	var since := AudioServer.get_time_since_last_mix()
	if since < last_mix: cycles += 1
	last_mix = since
func run() -> void:
	print("AUDIO_MINIMAL_BEGIN ",JSON.stringify({"native":DisplayServer.get_name(),"devices":AudioServer.get_output_device_list(),"output":AudioServer.output_device,"mix_rate":AudioServer.get_mix_rate(),"arguments":OS.get_cmdline_args(),"driver_methods":AudioServer.get_method_list().filter(func(m):return "driver" in m.name)}))
	player=AudioStreamPlayer.new();root.add_child(player)
	var stream := AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050
	var bytes:=PackedByteArray();bytes.resize(44100);stream.data=bytes;stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=22050
	player.stream=stream;wave=weakref(stream);stream=null;player.play();playback=weakref(player.get_stream_playback())
	last_mix=AudioServer.get_time_since_last_mix()
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<3000:
		await process_frame;sample()
	print("AUDIO_MINIMAL_PLAY ",JSON.stringify({"elapsed_ms":Time.get_ticks_msec()-start,"mix_cycles":cycles,"since":AudioServer.get_time_since_last_mix(),"next":AudioServer.get_time_to_next_mix(),"has_playback":player.has_stream_playback()}))
	player.stop();player.stream=null
	var stop_start := Time.get_ticks_msec()
	while playback.get_ref()!=null and Time.get_ticks_msec()-stop_start<1000:
		await process_frame;sample()
	print("AUDIO_MINIMAL_STOP ",JSON.stringify({"elapsed_ms":Time.get_ticks_msec()-stop_start,"mix_cycles":cycles,"since":AudioServer.get_time_since_last_mix(),"next":AudioServer.get_time_to_next_mix(),"playback_alive":playback.get_ref()!=null,"wave_alive":wave.get_ref()!=null}))
	player.queue_free();await process_frame;await process_frame;quit()
