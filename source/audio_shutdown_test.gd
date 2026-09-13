extends SceneTree
## Native audio lifecycle probe. Choose a driver explicitly at the command line;
## the production helper never selects Dummy or changes the output device.
const Shutdown = preload("res://scripts/audio_shutdown.gd")
const Vehicle = preload("res://scripts/harbor_vehicle.gd")
var checks: Array=[]
var stage: Node3D
var mix_boundaries:=0
var previous_mix_time:=0.0
var expect_timeout:=false

func _initialize() -> void: call_deferred("run")
func check(title: String, passed: bool, detail: Dictionary={}) -> void:
	checks.append({"name":title,"passed":passed,"detail":detail})
	print("AUDIO_EXIT_TEST ","PASS " if passed else "FAIL ",title," ",JSON.stringify(detail))
func sample_mix() -> void:
	var now:=AudioServer.get_time_since_last_mix()
	if now<previous_mix_time: mix_boundaries+=1
	previous_mix_time=now
func remaining(references: Array[WeakRef]) -> int:
	var total:=0
	for reference in references:
		if reference.get_ref()!=null: total+=1
	return total
func tone() -> AudioStreamWAV:
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050
	var bytes:=PackedByteArray();bytes.resize(44100);stream.data=bytes
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=22050
	return stream

func run() -> void:
	expect_timeout="--expect-timeout" in OS.get_cmdline_user_args()
	check("probe requires native audio players instead of headless early return",DisplayServer.get_name()!="headless")
	if DisplayServer.get_name()=="headless":quit(1);return
	for action in ["forward","back","left","right","rise","fall","brake","boost","drift","sprint","jump","fire"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	RenderingServer.render_loop_enabled=false
	stage=Node3D.new();root.add_child(stage)
	var camera:=Camera3D.new();camera.position=Vector3(0,5,10);stage.add_child(camera)
	var vehicles: Array=[]
	for index in 22:
		var vehicle:=Vehicle.new();vehicle.configure("car","audio_shutdown_fixture_"+str(index))
		vehicle.position=Vector3(index*10,0,0);vehicle.freeze=true;stage.add_child(vehicle)
		vehicle.set_physics_process(false);vehicles.append(vehicle)
	for index in 5:await process_frame
	var weak_playbacks: Array[WeakRef]=[]
	for vehicle in vehicles:
		if vehicle._engine.has_stream_playback():weak_playbacks.append(weakref(vehicle._engine.get_stream_playback()))
	check("all 22 production vehicle engine players actually own playback",weak_playbacks.size()==22 and remaining(weak_playbacks)==22)
	previous_mix_time=AudioServer.get_time_since_last_mix();process_frame.connect(sample_mix)
	var result:Dictionary=await Shutdown.stop_and_drain(stage)
	process_frame.disconnect(sample_mix)
	check("drain tracks every active production engine using weak references",result.tracked==22)
	check("engine and collision audio streams are stopped and detached",vehicles.all(func(v):return v._engine.stream==null and v._hit_audio.stream==null and not v._engine.has_stream_playback()))
	check("returned remaining count agrees with independent playback weak references",result.remaining==remaining(weak_playbacks),result)
	if expect_timeout:
		check("inactive mixer times out honestly without hanging or claiming release",not result.complete and result.remaining==22 and result.elapsed_ms>=1000 and result.elapsed_ms<1500 and mix_boundaries==0,{"drain":result,"mix_boundaries":mix_boundaries})
	else:
		check("native mixer releases all 22 playback references before exit",result.complete and result.remaining==0 and remaining(weak_playbacks)==0 and mix_boundaries>0,{"drain":result,"mix_boundaries":mix_boundaries})
	var empty:Dictionary=await Shutdown.stop_and_drain(stage)
	check("repeated shutdown with no active playback returns immediately",empty.complete and empty.tracked==0 and empty.remaining==0 and empty.elapsed_ms<50,empty)
	# All three player classes share the same shutdown contract. Vehicle engines
	# above cover 3D; add plain and 2D playback without keeping strong references.
	var plain:=AudioStreamPlayer.new();plain.stream=tone();stage.add_child(plain);plain.play()
	var planar:=AudioStreamPlayer2D.new();planar.stream=tone();stage.add_child(planar);planar.play()
	for index in 5:await process_frame
	var other_refs: Array[WeakRef]=[]
	for speaker in [plain,planar]:
		other_refs.append(weakref(speaker.get_stream_playback()))
	var other:Dictionary=await Shutdown.stop_and_drain(stage)
	check("plain and 2D players are included and detached",other.tracked==2 and plain.stream==null and planar.stream==null and other.remaining==remaining(other_refs),other)
	check("all player classes report the actual completion or timeout",(not other.complete and other.remaining==2 and other.elapsed_ms>=1000) if expect_timeout else (other.complete and other.remaining==0),other)
	# An expired deadline deterministically exercises the incomplete result without
	# disabling the host mixer or retaining a strong playback reference ourselves.
	var deadline_speaker:=AudioStreamPlayer.new();deadline_speaker.stream=tone();stage.add_child(deadline_speaker);deadline_speaker.play()
	var deadline_refs: Array[WeakRef]=[]
	deadline_refs.append(weakref(deadline_speaker.get_stream_playback()))
	var expired:Dictionary=await Shutdown.stop_and_drain(stage,0)
	check("expired real-time deadline returns incomplete without waiting",expired.tracked==1 and expired.remaining==1 and not expired.complete and expired.elapsed_ms<50,expired)
	var cleanup_started:=Time.get_ticks_msec()
	while remaining(deadline_refs)>0 and Time.get_ticks_msec()-cleanup_started<1000:
		await process_frame
	check("deadline result did not retain a hidden strong playback reference",remaining(deadline_refs)==(1 if expect_timeout else 0),{"remaining":remaining(deadline_refs),"elapsed_ms":Time.get_ticks_msec()-cleanup_started})
	var passed:bool=checks.all(func(item):return item.passed)
	var report={"passed":passed,"count":checks.size(),"checks":checks,"native":true,"expect_inactive_mixer_timeout":expect_timeout,"vehicle_drain":result,"other_player_drain":other,"expired_deadline":expired,"mix_boundaries_during_vehicle_drain":mix_boundaries,"audio_output_device":AudioServer.output_device,"listening_verified":false,"production_driver_changed":false,"physics_hz":Engine.physics_ticks_per_second,"shutdown_source_sha256":FileAccess.get_sha256("res://scripts/audio_shutdown.gd"),"scope":"22 actual production vehicle engines plus plain/2D audio players; physical driver chosen only by invocation. Fast process frames, real wall-clock deadline and independently watched playback references. Does not verify audible output or repair an inactive host driver."}
	var path:="res://../reports/audio-shutdown-timeout.json" if expect_timeout else "res://../reports/audio-shutdown.json"
	var output:=FileAccess.open(path,FileAccess.WRITE);output.store_string(JSON.stringify(report,"  "));output.close()
	stage.queue_free();await process_frame;await process_frame
	quit(0 if passed else 1)
