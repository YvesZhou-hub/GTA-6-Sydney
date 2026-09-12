extends Node
## A fixed average Sydney summer, scaled at 12 game seconds / real second.
signal changed(state:Dictionary)
const BASELINE_PATH:="res://assets/sydney_summer.json"
var baseline:Dictionary={}
var hour:=16.0
var speed:=12.0
var running:=true
var cycles:=0
var _game:Node3D
var _apply_clock:=0.0

func setup(game:Node3D):
	_game=game
	baseline=JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
	_apply(true)

func solar_state(at:float=hour) -> Dictionary:
	if baseline.is_empty(): baseline=JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
	var latitude:=deg_to_rad(float(baseline.latitude))
	var declination:float=baseline.declination_radians
	var angle:=deg_to_rad((at-float(baseline.solar_noon_hour))*15.0)
	var east:float=-cos(declination)*sin(angle)
	var north:float=cos(latitude)*sin(declination)-sin(latitude)*cos(declination)*cos(angle)
	var up:float=sin(latitude)*sin(declination)+cos(latitude)*cos(declination)*cos(angle)
	var direction:=Vector3(east,up,-north).normalized()
	var elevation:=rad_to_deg(asin(clampf(up,-1,1)))
	return {"hour":fposmod(at,24),"sun_direction":direction,"elevation_deg":elevation,"night_factor":1.0-smoothstep(-8.0,3.0,elevation),"sunrise_hour":baseline.sunrise_hour,"sunset_hour":baseline.sunset_hour}

func _process(delta:float):
	if not is_instance_valid(_game) or not _game.active or _game.paused: return
	advance(delta)
	_apply_clock-=delta
	if _apply_clock<=0.0:
		_apply_clock=0.1
		_apply()

func advance(real_seconds:float):
	if not running or not is_finite(real_seconds) or real_seconds<0:return
	var total:=hour+real_seconds*speed/3600.0
	cycles+=int(floor(total/24.0))
	hour=fposmod(total,24.0)

func set_hour(value:float):
	if not is_finite(value):return
	hour=fposmod(value,24.0)
	_apply(true)

func set_speed(value:float):
	if not is_finite(value):return
	speed=clampf(value,1.0,120.0)
	changed.emit(get_state())

func jump(preset:String):
	if baseline.is_empty():solar_state()
	match preset:
		"sunrise":set_hour(baseline.sunrise_hour)
		"noon":set_hour(baseline.solar_noon_hour)
		"sunset":set_hour(baseline.sunset_hour)
		"golden":set_hour(float(baseline.sunset_hour)-0.55)
		"night":set_hour(22.0)

func _apply(force_sky:=false):
	if not is_instance_valid(_game):return
	var state:=solar_state()
	state["force_sky"]=force_sky
	var lighting=load("res://scripts/daylight_environment.gd")
	if lighting.has_method("apply_cycle"):
		lighting.apply_cycle(_game.environment.environment,_game.sun,state)
	RenderingServer.global_shader_parameter_set("city_night_amount",state.night_factor)
	# Runtime submission witness also works when the script is compiled into a
	# release PCK. This records the submitted value, not a GPU readback.
	var previous_write:Dictionary=get_meta("night_window_write",{})
	set_meta("night_window_write",{"name":"city_night_amount","value":state.night_factor,"hour":hour,"frame":Engine.get_process_frames(),"sequence":int(previous_write.get("sequence",0))+1})
	changed.emit(get_state())

func display_time() -> String:
	var minutes:=int(hour*60)%1440
	return "%02d:%02d"%[minutes/60,minutes%60]

func get_state() -> Dictionary:
	return {"version":1,"season":"sydney_average_summer","hour":hour,"speed":speed,"running":running,"cycles":cycles}

func apply_state(data:Dictionary):
	hour=fposmod(_saved_number(data,"hour",16.0),24.0)
	speed=clampf(_saved_number(data,"speed",12.0),1.0,120.0)
	running=data.get("running",true) if data.get("running",true) is bool else true
	cycles=int(clampf(_saved_number(data,"cycles",0),0,1000000000))
	_apply(true)

func _saved_number(data:Dictionary,key:String,fallback:float) -> float:
	var value=data.get(key,fallback)
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback
