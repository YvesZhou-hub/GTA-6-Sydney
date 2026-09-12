extends RefCounted
## Original deterministic PCM; no recordings or external sound assets.
const RATE := 24000
static var _streams: Dictionary = {}

static func stream(kind: String) -> AudioStreamWAV:
	if _streams.has(kind): return _streams[kind]
	var seconds := 2.3 if kind == "impact" else (1.8 if kind == "tank" else .9)
	var samples := int(seconds * RATE)
	var bytes := PackedByteArray(); bytes.resize(samples * 2)
	var rng := RandomNumberGenerator.new(); rng.seed = 18791 + kind.hash()
	var low := 0.0
	var mid := 0.0
	for index in samples:
		var t := float(index) / RATE
		var white := rng.randf_range(-1,1)
		low = lerpf(low,white,.025)
		mid = lerpf(mid,white,.22)
		var signal_value := 0.0
		if kind == "tank":
			var crack := white * exp(-t*105.0) * .68
			var punch := sin(TAU*(68.0*t+1.0*(1.0-exp(-t*14.0)))) * exp(-t*9.0) * .50
			var pressure := mid*exp(-t*13.0)*.45+low*exp(-t*2.8)*1.3
			var echo_t := maxf(0,t-.17)
			var reflection := mid*exp(-echo_t*8.0)*.15*(1.0-exp(-echo_t*90.0))
			signal_value=crack+punch+pressure+reflection
		elif kind == "impact":
			var strike := white*exp(-t*52.0)*.48+sin(TAU*48.0*t)*exp(-t*6.7)*.4
			var rumble := low*exp(-t*2.2)*2.2
			var fragments := mid*exp(-t*3.6)*(.13+.17*pow(sin(t*57.0),8.0))
			signal_value=strike+rumble+fragments
		else:
			signal_value=mid*exp(-t*6.0)*.55+white*exp(-t*65.0)*.18+sin(TAU*110.0*t)*exp(-t*12.0)*.22
		# Bounded soft saturation, short anti-click attack and quiet tail.
		var attack := minf(1.0,t*1800.0)
		var tail := minf(1.0,(seconds-t)*14.0)
		var value := tanh(signal_value*1.25)*.89*attack*tail
		bytes.encode_s16(index*2,int(value*32767.0))
	var result := AudioStreamWAV.new()
	result.format=AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate=RATE
	result.data=bytes
	_streams[kind]=result
	return result
