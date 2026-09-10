extends Node

var ambient: AudioStreamPlayer
var cue: AudioStreamPlayer
var step: AudioStreamPlayer3D
var source: Node3D
var clock_time = 0.0

func _ready():
	ambient = AudioStreamPlayer.new()
	ambient.stream = wave(8.0,0)
	ambient.volume_db = -22
	add_child(ambient)
	ambient.play()
	cue = AudioStreamPlayer.new()
	add_child(cue)
	step = AudioStreamPlayer3D.new()
	step.max_distance=30
	step.volume_db=-16
	add_child(step)

func wave(seconds:float,kind:int) -> AudioStreamWAV:
	var rate=22050
	var count=int(seconds*rate)
	var bytes=PackedByteArray()
	bytes.resize(count*2)
	var filter=0.0
	var rng=RandomNumberGenerator.new()
	rng.seed=417+kind
	for i in count:
		var t=float(i)/rate
		filter=lerpf(filter,rng.randf_range(-1,1),0.04 if kind==0 else 0.3)
		var sample=0.0
		if kind==0:
			sample=filter*(0.4+0.3*sin(t*1.57))+sin(t*120+sin(t*2))*0.008
		elif kind==1:
			sample=filter*exp(-t*35)*0.7+sin(t*180)*exp(-t*48)*0.12
		elif kind==2:
			sample=(sin(t*1100)+sin(t*1650))*exp(-t*7)*0.1
		elif kind==3:
			sample=(filter*0.75+sin(t*90)*0.15)*exp(-t*4)
		else:
			sample=filter*exp(-t*8)*0.5
		bytes.encode_s16(i*2,int(clampf(sample,-1,1)*32760))
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=rate
	stream.data=bytes
	if kind==0:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_end=count
	return stream

func footstep(water:bool,pos:Vector3):
	step.global_position=pos
	step.stream=wave(0.2,4 if water else 1)
	step.pitch_scale=randf_range(0.9,1.1)
	step.play()

func chime():
	cue.stream=wave(0.7,2)
	cue.volume_db=-12
	cue.play()

func crash(pos:Vector3):
	step.global_position=pos
	step.stream=wave(1.3,3)
	step.volume_db=-5
	step.play()
