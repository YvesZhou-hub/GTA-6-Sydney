extends Node
## Genuine production-world trailer takes. Explicit run(game), never auto-runs.
## Authored camera, scripted player inputs and fixed-step controller simulation;
## no substitute geometry, fake damage, user-save load, or startup movie writer.
const Opera = preload("res://scripts/opera_interiors.gd")
const FPS := 30
const SHOTS := [
	{"id":"01_tank_impact","seconds":5}, {"id":"02_harbour_hero","seconds":5},
	{"id":"03_street_drive","seconds":6}, {"id":"04_fighter_rocket","seconds":6},
	{"id":"05_opera_steps","seconds":5}, {"id":"06_public_interior","seconds":5},
	{"id":"07_summer_sunset","seconds":6}]
var game
var peer := StreamPeerTCP.new()
var connected := false
var failures:Array[String]=[]
var frame := 0
var shot_id := ""
var events:Array[Dictionary]=[]
var actor:RigidBody3D
var aim_target := Vector3.ZERO
var camera_start := Vector3.ZERO
var camera_end := Vector3.ZERO
var camera_target := Vector3.ZERO
var actor_start := Vector3.ZERO
var start_destroyed:Array=[]
var shot_start_stats:Dictionary={}
var max_speed := 0.0
var max_live_projectiles := 0
var size := Vector2i(1920,1080)
var observed_delta_min := INF
var observed_delta_max := 0.0
var tree_bounds:Array[AABB]=[]
var shot_failure_start := 0
var impact_eye := Vector3.ZERO
var impact_target := Vector3.ZERO
var impact_camera_active := false

func _arg(prefix:String, fallback:String="") -> String:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):return arg.trim_prefix(prefix)
	return fallback

func _check(ok:bool, message:String) -> void:
	if not ok:failures.append(message);push_error("TRAILER_CAPTURE: "+message)

func _packet(kind:int,data:PackedByteArray) -> void:
	if not connected:return
	peer.put_u8(kind);peer.put_u32(data.size())
	if peer.put_data(data)!=OK:
		connected=false;_check(false,"Loopback stream disconnected")

func _event(data:Dictionary) -> void:_packet(1,JSON.stringify(data).to_utf8_buffer())
func _v(v:Vector3) -> Array:return [v.x,v.y,v.z]

func run(owner_game:Node3D) -> void:
	game=owner_game
	_check(game.qa_running,"Main must set qa_running before setup; recorder never opens existing saves")
	_check(DisplayServer.get_name()!="headless","Capture requires native renderer")
	# Engine-consumed command-line switches are absent from get_cmdline_args.
	# Validate the resulting simulation delta, not the presence of a string.
	for sample in 3:
		await get_tree().process_frame
		_check(absf(get_process_delta_time()-1.0/FPS)<.0001,"Actual simulation step must be 1/30 second")
	var port:=int(_arg("--trailer-port=","0"))
	_check(port>1024 and port<65536,"Valid loopback receiver port required")
	if not failures.is_empty():await game.finish_quit(1);return
	peer.big_endian=true
	peer.connect_to_host("127.0.0.1",port)
	for attempt in 300:
		peer.poll()
		if peer.get_status()==StreamPeerTCP.STATUS_CONNECTED:connected=true;break
		await get_tree().process_frame
	if not connected:push_error("TRAILER_CAPTURE: no local receiver");await game.finish_quit(1);return
	if "--trailer-preview" in OS.get_cmdline_user_args():size=Vector2i(960,540)
	get_window().size=size;get_window().content_scale_size=size
	game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false)
	game.active=false # new_world otherwise autosaves an already-active session.
	game.new_world("sandbox","TRAILER · unsaved isolated production world",false)
	game.world_id="qa_trailer_unsaved"
	game.close_panel();game.paused=false;get_tree().paused=false
	game.canvas.hide();game.camera.current=true;game.camera.fov=63
	game.camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	game.city_clock.running=false;game.city_clock.set_process(false)
	game.life.set_process(false);game.life.set_physics_process(false)
	game.weapons.set_physics_process(false)
	# The recorder drives genuine effects at exact output-frame times; interpolating
	# this subtree again would smear MultiMesh flashes between unrelated ticks.
	game.weapons.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	game.player.enabled=false;game.player.visible=false
	_freeze_fleet()
	_check(game.world._ready_complete,"Full production world READY guard")
	RenderingServer.render_loop_enabled=false
	_event({"event":"hello","width":size.x,"height":size.y,"fps":FPS,"world_ready":game.world._ready_complete,"save_policy":"new_world(save_now=false), active false before setup, qa_running; no user-save load/write","simulation":"30 fixed process steps, production 60 Hz rigidbody physics; weapon controller stepped twice per output frame; authored camera"})
	var selected:=_arg("--trailer-shots=").split(",",false)
	for definition:Dictionary in SHOTS:
		if not selected.is_empty() and not definition.id in selected:continue
		shot_id=definition.id
		shot_failure_start=failures.size()
		if not await _setup_shot():
			_event({"event":"shot_skip","id":shot_id,"passed":false,"failures":failures.slice(shot_failure_start)})
			continue
		var count:=int(definition.seconds)*FPS
		_check(await game.world.prepare_view(game.camera.global_position),"Production facade detail preparation completed")
		for warmup in 16:
			await get_tree().process_frame
			RenderingServer.force_draw(false)
		# Warm-up is never included in media. Motion only starts after prewarming.
		if is_instance_valid(actor):
			actor_start=actor.global_position
			if shot_id=="03_street_drive":actor.freeze=false;Input.action_press("forward")
			if shot_id=="04_fighter_rocket":
				actor.freeze=false;actor.linear_velocity=-actor.global_basis.z*140.0;actor.throttle=140.0/(2000.0/3.6)
		if shot_id=="05_opera_steps":game.player.enabled=true;Input.action_press("forward")
		_event({"event":"shot_begin","id":shot_id,"frames":count,"seconds":definition.seconds,"clock":game.city_clock.solar_state(),"camera_start":_v(game.camera.global_position),"actor_kind":actor.kind if is_instance_valid(actor) else "foot" if shot_id=="05_opera_steps" else "none"})
		for index in count:
			frame=index
			await get_tree().process_frame
			observed_delta_min=minf(observed_delta_min,get_process_delta_time())
			observed_delta_max=maxf(observed_delta_max,get_process_delta_time())
			_tick_shot(float(index)/float(count-1))
			_step_weapons()
			RenderingServer.force_draw(false)
			var image:=get_viewport().get_texture().get_image()
			if image.get_size()!=size:
				_check(false,"Viewport dimensions differ from transport header");break
			image.convert(Image.FORMAT_RGB8)
			_packet(2,image.get_data())
			if not connected:break
		_end_shot(count)
		if not connected:break
	_release_inputs();_freeze_fleet();game.weapons.clear();game.active=false
	_check(observed_delta_max<1.0/FPS+.0001 and observed_delta_min>1.0/FPS-.0001,"Recorded simulation frames preserve fixed 30fps delta")
	_event({"event":"complete","passed":failures.is_empty(),"failures":failures,"user_saves_touched":false,"simulation_delta_min":observed_delta_min,"simulation_delta_max":observed_delta_max})
	print("TRAILER_CAPTURE_COMPLETE passed=",failures.is_empty())
	await game.finish_quit(0 if failures.is_empty() else 1)

func _freeze_fleet() -> void:
	for vehicle in game.vehicles:
		vehicle.freeze=true;vehicle.linear_velocity=Vector3.ZERO;vehicle.angular_velocity=Vector3.ZERO

func _release_inputs() -> void:
	for action in ["forward","back","left","right","rise","fall","brake","sprint"]:
		if InputMap.has_action(action):Input.action_release(action)

func _ray(a:Vector3,b:Vector3,exclude:Array[RID]=[]) -> Dictionary:
	return game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,15,exclude))

func _camera(position:Vector3,target:Vector3) -> void:
	game.camera.global_position=position;game.camera.look_at(target);game.camera.reset_physics_interpolation()

func _setup_shot() -> bool:
	_release_inputs();_freeze_fleet();game.weapons.clear()
	if is_instance_valid(game.current_vehicle):game.current_vehicle.occupied=false
	game.current_vehicle=null;actor=null;events=[];max_speed=0;max_live_projectiles=0
	impact_camera_active=false
	game.player.enabled=false;game.player.visible=false
	game.city_clock.jump("golden")
	shot_start_stats=game.weapons.stats().duplicate(true)
	start_destroyed=game.world.get_state().get("destroyed",[]).duplicate()
	match shot_id:
		"01_tank_impact":
			game.city_clock.set_hour(16.0)
			# Stage a real safe-spawn request on the open northern end of the block,
			# rather than beneath the trees beside the usual Quay arrival marker.
			game.player.global_position=game.world.anchors.quay+Vector3(0,1,-35)
			_camera(game.player.global_position+Vector3(0,5,14),game.player.global_position)
			actor=game.request_vehicle("tank")
			if not is_instance_valid(actor):_check(false,"Tank safe request failed");return false
			_freeze_fleet()
			var target:=_tank_target()
			if target.is_empty():_check(false,"No unobstructed real OSM facade target");return false
			aim_target=target.point
			actor.set_meta("weapon_aim_offsets",{})
			_camera(actor._moving.barrel.global_position,aim_target)
			for step in 180:game.weapons.update_aim(1.0/60.0)
			var forward:Vector3=(aim_target-actor.global_position).normalized()
			var right:=forward.cross(Vector3.UP).normalized()
			camera_target=actor.global_position+Vector3.UP*1.7
			_cache_nearby_tree_bounds(actor.global_position)
			# Physics rays do not hit the decorative foliage. Check the exact
			# production crown transforms as well, without removing any scenery.
			var found:=false
			for height in [12.0,16.0,20.0,7.0,4.2]:
				for side in [-1.0,1.0]:
					for along in [-6.0,6.0,-12.0]:
						var eye:Vector3=actor.global_position+forward*along+right*side*12.0+Vector3.UP*height
						if _tank_eye_clear(eye,forward,right) and _tank_eye_clear(eye+right,forward,right):camera_start=eye;found=true;break
					if found:break
				if found:break
			if not found:_check(false,"Tank cinematic eye obstructed by actual geometry");return false
			camera_end=camera_start+right
			_camera(camera_start,camera_target)
			events.append({"event":"target_selected","frame":0,"id":target.id,"position":_v(aim_target)})
		"02_harbour_hero","07_summer_sunset":
			camera_start=Vector3(980,105,-680);camera_end=Vector3(855,90,-660);camera_target=Vector3(230,35,-570)
			_camera(camera_start,camera_target)
		"03_street_drive":
			game.city_clock.set_hour(16.0)
			game.player.global_position=Vector3(-329.08,6.0,1090)
			_camera(game.player.global_position+Vector3(0,5,16),Vector3(-329.08,6,980))
			actor=game.request_vehicle("car")
			if not is_instance_valid(actor):_check(false,"Street car safe request failed");return false
			_freeze_fleet()
			_camera(actor.global_position+actor.global_basis*Vector3(0,2.2,8),actor.global_position+Vector3.UP)
		"04_fighter_rocket":
			game.city_clock.set_hour(17.3)
			game.player.global_position=Vector3(1000,6,-500)
			_camera(Vector3(1020,15,-490),Vector3(1000,8,-600))
			actor=game.request_vehicle("fighter")
			if not is_instance_valid(actor):_check(false,"Fighter safe request failed");return false
			_freeze_fleet()
			# Initial shot staging only, then actual production FighterMotion/rigidbody.
			actor.global_transform=Transform3D(Basis.looking_at(Vector3(-.75,0,.66).normalized()),Vector3(1050,340,-700))
			actor.reset_physics_interpolation()
			_camera(actor.global_position+actor.global_basis*Vector3(14,10,32),actor.global_position-actor.global_basis.z*45-Vector3.UP*15)
		"05_opera_steps":
			game.city_clock.set_hour(16.0)
			var start:=Opera.point(Vector3(14,35,87))
			var floor_hit:=_ray(start,start-Vector3.UP*45,[game.player.get_rid()])
			if floor_hit.is_empty():_check(false,"Opera steps actual support absent");return false
			game.player.global_position=floor_hit.position+Vector3.UP*.04
			game.player.velocity=Vector3.ZERO;game.player.yaw=deg_to_rad(Opera.ANGLE)
			game.player.collision_layer=2;game.player.collision_mask=15;game.player.visible=true
			game.player.reset_physics_interpolation();actor_start=game.player.global_position
			_camera(actor_start+Opera.basis()*Vector3(7,4,11),actor_start+Vector3.UP*1.5)
		"06_public_interior":
			game.city_clock.set_hour(16.0)
			camera_start=Opera.point(Vector3(-26,22.5,-29));camera_end=Opera.point(Vector3(-23,22.0,-27))
			camera_target=Opera.point(Vector3(-26,19,17));_camera(camera_start,camera_target)
	return true

func _cache_nearby_tree_bounds(origin:Vector3) -> void:
	tree_bounds.clear()
	for tree:Dictionary in game.world.map_snapshot.get("trees",[]):
		var p:=Vector3(tree.point[0],game.world.GROUND,tree.point[1])
		if Vector2(p.x-origin.x,p.z-origin.z).length()>150:continue
		var height:=8.0
		if str(tree.tags.get("height","")).is_valid_float():height=clampf(float(tree.tags.height),2,27)
		var scale:=height/8.0
		for crown:Transform3D in game.world._tree_crowns(p,scale):tree_bounds.append((crown*AABB(-Vector3.ONE,Vector3.ONE*2)).grow(.35))
		tree_bounds.append(AABB(p-Vector3(.5,0,.5)*scale,Vector3(1,6.2,1)*scale))

func _tank_eye_clear(eye:Vector3,forward:Vector3,right:Vector3) -> bool:
	var subjects:Array[Vector3]=[actor.global_position+Vector3.UP*1.0,actor.global_position+Vector3.UP*3.0,
		actor.global_position+forward*3+Vector3.UP*2,actor.global_position-forward*3+Vector3.UP*2,
		actor.global_position+right*2+Vector3.UP*2,actor.global_position-right*2+Vector3.UP*2]
	if not _ray(eye,eye+Vector3.UP*15,[actor.get_rid(),game.player.get_rid()]).is_empty():return false
	for point:Vector3 in subjects:
		if not _ray(eye,point,[actor.get_rid(),game.player.get_rid()]).is_empty():return false
		for bounds:AABB in tree_bounds:
			if bounds.intersects_segment(eye,point):return false
	return true

func _choose_impact_camera(point:Vector3) -> void:
	# Editorial cut responds to the real sweep hit; never manufactures an impact.
	var outward:Vector3=(actor.global_position-point).normalized()
	var right:=outward.cross(Vector3.UP).normalized()
	for height in [5.0,9.0,14.0]:
		for side in [0.0,8.0,-8.0]:
			var eye:Vector3=point+outward*20+right*side+Vector3.UP*height
			var end:=point+outward*1.5
			if not _ray(eye,end,[actor.get_rid(),game.player.get_rid()]).is_empty():continue
			if not _ray(eye,eye+Vector3.UP*10,[actor.get_rid(),game.player.get_rid()]).is_empty():continue
			var blocked:=false
			for bounds:AABB in tree_bounds:
				if bounds.intersects_segment(eye,end):blocked=true;break
			if blocked:continue
			impact_eye=eye;impact_target=point+Vector3.UP*2;impact_camera_active=true
			events.append({"event":"camera_cut","frame":frame,"time_s":float(frame)/FPS,"eye":_v(eye),"target":_v(impact_target),"reason":"Close view triggered by actual production collision"})
			return
	_check(false,"Real impact lacked an unobstructed close capture eye")

func _tank_target() -> Dictionary:
	var origin:Vector3=actor._moving.barrel.global_position
	var candidates:Array[Dictionary]=[]
	for id in game.world.structures:
		if not str(id).begins_with("osm/") or not "/storey_group/" in str(id):continue
		var item:Dictionary=game.world.structures[id]
		var point:Vector3=item.position
		var distance:=origin.distance_to(point)
		if distance>30 and distance<240 and point.y>origin.y+1 and point.y<origin.y+90:candidates.append({"id":id,"point":point,"distance":distance})
	candidates.sort_custom(func(a,b):return a.distance<b.distance)
	for row:Dictionary in candidates:
		var hit:=_ray(origin,row.point,[actor.get_rid(),game.player.get_rid()])
		if not hit.is_empty() and hit.position.distance_to(origin)>20:
			var id:=str(hit.collider.get_meta("damage_id",""))
			if id.begins_with("osm/"):return {"id":id,"point":hit.position}
	return {}

func _tick_shot(t:float) -> void:
	if is_instance_valid(actor):max_speed=maxf(max_speed,actor.linear_velocity.length())
	match shot_id:
		"01_tank_impact":
			_camera(impact_eye,impact_target) if impact_camera_active else _camera(camera_start.lerp(camera_end,t),camera_target)
			if frame==24:_fire()
		"03_street_drive":
			_camera(actor.global_position+actor.global_basis*Vector3(0,2.2,8),actor.global_position-actor.global_basis.z*8+Vector3.UP)
		"04_fighter_rocket":
			_camera(actor.global_position+actor.global_basis*Vector3(14+3*t,10,32),actor.global_position-actor.global_basis.z*45-Vector3.UP*15)
			if frame in [30,55,80]:_fire()
		"07_summer_sunset":
			if frame<=120 and frame%10==0:
				var hour:=lerpf(float(game.city_clock.baseline.sunset_hour)-.55,22.0,minf(float(frame)/120.0,1.0))
				game.city_clock.set_hour(hour)
				events.append({"event":"clock_seek","frame":frame,"time_s":float(frame)/FPS,"hour":hour,"scope":"Actual production time-slider API; compressed time-remap, not natural 12x clock playback"})
			_camera(camera_start.lerp(camera_end,t),camera_target)
		"05_opera_steps":
			_camera(game.player.global_position+Opera.basis()*Vector3(7,4,11),game.player.global_position+Vector3.UP*1.5)
		_:_camera(camera_start.lerp(camera_end,t),camera_target)
	game.world.stream_view(game.camera.global_position,actor.linear_velocity if is_instance_valid(actor) else Vector3.ZERO,1.0/FPS)

func _fire() -> void:
	var camera_pose:Transform3D=game.camera.global_transform
	if actor.kind=="tank":_camera(actor._moving.barrel.global_position,aim_target)
	var muzzle:Node3D=actor._moving.get("muzzle") if actor.kind=="tank" else actor._moving.get("weapon_muzzle")
	var success:bool=game.weapons.fire_current()
	_check(success,"Actual production fire_current rejected "+shot_id)
	if success:events.append({"event":"fire","frame":frame,"time_s":float(frame)/FPS,"kind":actor.kind,"muzzle":_v(muzzle.global_position),"forward":_v(-muzzle.global_basis.z),"source_velocity":_v(actor.linear_velocity)})
	game.camera.global_transform=camera_pose

func _step_weapons() -> void:
	var camera_pose:Transform3D=game.camera.global_transform
	if is_instance_valid(actor) and actor.kind=="tank":_camera(actor._moving.barrel.global_position,aim_target)
	for substep in 2:
		var before:int=game.weapons.stats().hits
		game.weapons._physics_process(1.0/60.0)
		var stats:Dictionary=game.weapons.stats()
		max_live_projectiles=maxi(max_live_projectiles,int(stats.active_projectiles))
		if int(stats.hits)>before:
			var pool=game.weapons.effects
			var slot:Dictionary=pool._slots[(pool._cursor-1+pool.CAPACITY)%pool.CAPACITY]
			events.append({"event":"impact","frame":frame,"substep":substep,"time_s":float(frame)/FPS+float(substep)/60.0,"position":_v(slot.node.global_position),"destroyed_count":game.world.get_state().get("destroyed",[]).size()})
			if shot_id=="01_tank_impact" and not impact_camera_active:_choose_impact_camera(slot.node.global_position)
	game.camera.global_transform=camera_pose
	if impact_camera_active and shot_id=="01_tank_impact":_camera(impact_eye,impact_target)

func _end_shot(count:int) -> void:
	_release_inputs()
	var end:Vector3=actor.global_position if is_instance_valid(actor) else game.player.global_position
	var destroyed:Array=[]
	for id in game.world.get_state().get("destroyed",[]):
		if not id in start_destroyed:destroyed.append(id)
	var stats:Dictionary=game.weapons.stats()
	if shot_id=="01_tank_impact":
		_check(int(stats.hits)>int(shot_start_stats.hits),"Tank shot did not really hit")
		_check(not destroyed.is_empty(),"Tank shot did not destroy production building components")
	if shot_id=="04_fighter_rocket":
		_check(max_live_projectiles>0,"Fighter did not have an actual flying projectile")
		_check(end.distance_to(actor_start)>300,"Fighter did not physically travel")
	if shot_id=="03_street_drive":_check(end.distance_to(actor_start)>10,"Car failed to physically drive ten metres")
	if shot_id=="05_opera_steps":_check(end.distance_to(actor_start)>15 and end.y>actor_start.y+4,"Player did not actually climb stairs")
	_event({"event":"shot_end","id":shot_id,"events":events,"passed":failures.size()==shot_failure_start,"failures":failures.slice(shot_failure_start),"frames":count,"actor_start":_v(actor_start),"actor_end":_v(end),"max_speed_m_s":max_speed,"max_live_projectiles":max_live_projectiles,"new_destroyed_ids":destroyed,"weapon_stats":stats,"clock":game.city_clock.solar_state()})
