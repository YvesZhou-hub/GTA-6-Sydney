extends SceneTree
## Exercises production HUD methods with bounded fixtures; no city or save I/O.
const Profile=preload("res://scripts/mobile_profile.gd")
class Host extends "res://scripts/main.gd":
	var nearest_calls:=0
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _notification(_what): pass
	func nearest_vehicle(): nearest_calls+=1;return null
	func camera_accepts_mouse() -> bool: return active and not paused
class World extends Node3D:
	var anchors:={"quay":Vector3.ZERO,"opera":Vector3(414,5,-151)}
class Person extends CharacterBody3D:
	var stamina:=87.0
	var health:=72.0
	var max_health:=120.0
	var swimming:=false
class Life extends Node3D:
	var money:=1250
	var status_text:="Current objective"
	var action_calls:=0
	func available_actions(_point): action_calls+=1;return "E  Interact"
class PanelSystem extends Node:
	var calls:=0
	func update_panel(): calls+=1
class Survival extends "res://scripts/harbor_survival.gd":
	var snapshot_calls:=0
	func _physics_process(_delta): pass
	func hud_state() -> Dictionary:
		snapshot_calls+=1
		return {"aim_hit":aim_hit_active()}
class Vehicle extends RigidBody3D:
	var kind:="car"
	var health:=68.0
	var occupied:=true
	var throttle:=.8
	var stalled:=true
	func is_boosting() -> bool: return true
	func effective_top_speed_kmh() -> float: return 180.0
class Weapons extends Node3D:
	func aim_point(): return Vector3(0,10,-100)
	func aim_status() -> Dictionary: return {"ready":false,"cooldown_remaining":2.5,"elevation_deg":12.0}
var checks:Array=[]
var failures:=0
func _initialize(): call_deferred("run")
func check(label:String,ok:bool):
	checks.append({"name":label,"passed":ok})
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func reset_hidden(game):
	for item in [game.mode_label,game.activity_label,game.context_hint,game.landmark_marker,game.fire_button]: item.text="unchanged"
	for item in [game.activity_panel,game.landmark_marker,game.fire_button]: item.visible=false
	game.fire_button.disabled=false
	game.vehicle_panel.position=Vector2(550,560)
	game.vehicle_panel.size=Vector2(280,100)
	game.campaign.calls=0;game.districts.calls=0;game.life.action_calls=0;game.nearest_calls=0;game.survival.snapshot_calls=0
func visible_state(game) -> Dictionary:
	return {"info":game.info.text,"region":game.region_label.text,"speed":game.speed_label.text,"vehicle_visible":game.vehicle_panel.visible,"reticle_visible":game.combat_reticle.visible,"reticle_position":game.combat_reticle.position,"reticle_color":game.combat_reticle.modulate}
func update(game):
	game.update_landmark_marker()
	game.update_hud()
	game.update_combat_reticle(.16)
func run():
	var saved:Dictionary=Profile._cached_current
	var desktop:=Profile.detect("macOS",[],[])
	var mobile:=Profile.detect("iOS",["mobile"],[])
	Profile._cached_current=desktop
	var game:=Host.new();root.add_child(game)
	game.active=true;game.qa_running=true
	game.world=World.new();game.add_child(game.world)
	game.player=Person.new();game.add_child(game.player)
	game.life=Life.new();game.add_child(game.life)
	game.survival=Survival.new();game.add_child(game.survival)
	game.campaign=PanelSystem.new();game.add_child(game.campaign)
	game.districts=PanelSystem.new();game.add_child(game.districts)
	game.weapons=Weapons.new();game.add_child(game.weapons)
	game.camera=Camera3D.new();game.add_child(game.camera);game.camera.current=true
	game.hud=Control.new();game.add_child(game.hud);game.hud.size=Vector2(1560,720)
	for field in ["info","context_hint","activity_label","region_label","speed_label","mode_label","landmark_marker","combat_reticle"]:
		var item:=Label.new();game.set(field,item);game.hud.add_child(item)
	for field in ["activity_panel","vehicle_panel","hint_panel","modal"]:
		var item:=PanelContainer.new();game.set(field,item);game.hud.add_child(item)
	game.map_panel=Control.new();game.hud.add_child(game.map_panel)
	game.modal.visible=false;game.map_panel.visible=false
	game.hint_panel.position=Vector2(28,650);game.hint_panel.size=Vector2(1180,44)
	game.fire_button=Button.new();game.hud.add_child(game.fire_button)
	game.landmark_target_key="quay";game.landmark_target_name="Quay";game.landmark_target_position=Vector3(120,5,100)
	for label:String in ["foot","swim","car","motorcycle","hoverboard","airliner","tank","fighter"]:
		game.player.swimming=label=="swim"
		game.player.global_position=Vector3(-1000,5,8000) if label=="airliner" else Vector3(10,5,10)
		if label not in ["foot","swim"]:
			var vehicle:=Vehicle.new();vehicle.kind=label;vehicle.freeze=true;game.add_child(vehicle)
			vehicle.global_position=game.player.global_position+Vector3.UP*12
			vehicle.linear_velocity=Vector3(0,0,-10)
			vehicle.set_meta("road_handling",{"drifting":true})
			game.current_vehicle=vehicle
		game.survival._hit_flash=.3
		Profile._cached_current=desktop;reset_hidden(game);update(game)
		var expected:=visible_state(game)
		check("desktop retains hidden-panel update contract: "+label,game.mode_label.text.begins_with("HARBOURLIFE") and game.activity_label.text==game.life.status_text and game.activity_panel.visible and game.context_hint.text!="unchanged" and game.campaign.calls==1 and game.districts.calls==1 and game.landmark_marker.text!="unchanged")
		Profile._cached_current=mobile;reset_hidden(game)
		var rect:Rect2=game.vehicle_panel.get_rect()
		update(game)
		check("mobile visible labels and reticle match desktop: "+label,visible_state(game)==expected)
		check("mobile does not update hidden text or show hidden panels: "+label,game.mode_label.text=="unchanged" and game.activity_label.text=="unchanged" and game.context_hint.text=="unchanged" and game.landmark_marker.text=="unchanged" and game.fire_button.text=="unchanged" and not game.activity_panel.visible and not game.landmark_marker.visible and not game.fire_button.visible and not game.fire_button.disabled)
		check("mobile preserves layout and skips panel/action/enemy work: "+label,game.vehicle_panel.get_rect()==rect and game.campaign.calls==0 and game.districts.calls==0 and game.nearest_calls==0 and game.life.action_calls==0 and game.survival.snapshot_calls==0)
		if is_instance_valid(game.current_vehicle):game.current_vehicle.free();game.current_vehicle=null
	game.player.swimming=false
	for amount:float in [0.3,0.0,-0.1]:
		game.survival._hit_flash=amount
		game.update_combat_reticle(.016)
		check("lightweight hit flag preserves crosshair feedback at %s"%amount,game.survival.aim_hit_active()==(amount>0) and game.combat_reticle.modulate==(Color("96ddc7") if amount>0 else Color.WHITE) and game.survival.snapshot_calls==0)
	game.player.health=0;game.update_combat_reticle(.016)
	check("dead player's mobile reticle remains hidden",not game.combat_reticle.visible)
	game.player.health=72;game.paused=true;game.update_combat_reticle(.016)
	check("paused mobile reticle remains hidden",not game.combat_reticle.visible)
	Profile._cached_current=saved
	game.free()
	var path:=ProjectSettings.globalize_path("res://../reports/mobile-hud-updates.json")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures==0,"count":checks.size(),"failures":failures,"checks":checks,"full_city_or_device_benchmark":false},"\t"))
	print("MOBILE_HUD_UPDATES_COMPLETE checks=",checks.size()," failures=",failures)
	quit(1 if failures else 0)
