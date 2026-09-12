extends SceneTree
## Small production vehicle/weapon fixture; no city, native drawing or user saves.
const Effects = preload("res://scripts/combat_effects.gd")
const Weapons = preload("res://scripts/vehicle_weapons.gd")
const Factory = preload("res://scripts/vehicle_factory.gd")
const Sound = preload("res://scripts/weapon_audio.gd")
class ObservedEffects extends "res://scripts/combat_effects.gd":
	# Dummy RenderingServer returns identity transforms/white colors. Observe
	# the actual submission boundary, not fake a successful GPU readback.
	var submissions: Dictionary = {}
	var poses: Dictionary = {}
	func _set_particle_pose(multi: MultiMesh, index: int, pose: Transform3D) -> void:
		poses[str(multi.get_instance_id())+"/"+str(index)]=pose
		super._set_particle_pose(multi,index,pose)
	func pose_sample(multi: MultiMesh,index: int) -> Transform3D:
		return poses[str(multi.get_instance_id())+"/"+str(index)]
	func _card(multi: MultiMesh, index: int, point: Vector3, extent: Vector2, color: Color, seed_value: float, age: float) -> void:
		submissions[str(multi.get_instance_id())+"/"+str(index)]={"point":point,"extent":extent,"color":color,"seed":seed_value,"age":age}
		super._card(multi,index,point,extent,color,seed_value,age)
	func sample(multi: MultiMesh,index: int) -> Dictionary:
		return submissions[str(multi.get_instance_id())+"/"+str(index)]
class Game extends Node3D:
	var active := true
	var paused := false
	var current_vehicle: RigidBody3D
	var camera: Camera3D
	var impacts: Array[Dictionary] = []
	func can_fire_weapon(): return true
	func apply_combat_blast(point: Vector3, energy: float, radius: float, source: RigidBody3D):
		impacts.append({"point":point,"energy":energy,"radius":radius,"source":source})
var checks: Array[Dictionary]=[]
var game: Game
var weapons: Node3D
var observed: ObservedEffects

func _initialize(): call_deferred("run")
func check(title: String, result: bool, detail: Dictionary = {}):
	checks.append({"name":title,"passed":result,"detail":detail})
	print("COMBAT_EFFECTS ","PASS " if result else "FAIL ",title," ",JSON.stringify(detail))
func identity(node: Node, result: Array):
	result.append(node.get_instance_id())
	if node is GeometryInstance3D and node.material_override: result.append(node.material_override.get_instance_id())
	if node is MultiMeshInstance3D: result.append(node.multimesh.get_instance_id()); result.append(node.multimesh.mesh.get_instance_id())
	for child: Node in node.get_children(): identity(child,result)
func physical_count(node: Node) -> int:
	var count := 1 if node is PhysicsBody3D else 0
	for child: Node in node.get_children(): count += physical_count(child)
	return count
func snapshot(multi: MultiMesh) -> Array:
	var values: Array=[]
	for i in multi.instance_count:
		values.append(observed.sample(multi,i).duplicate(true))
	return values
func meshes(body: RigidBody3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D]=[]
	for child: Node in body._moving.barrel.get_children():
		if child is MeshInstance3D and not child.is_queued_for_deletion(): result.append(child)
	return result
func fixture_tank(id: String, at: Vector3) -> RigidBody3D:
	var body: RigidBody3D=Factory.make("tank",id)
	body.freeze=true; game.add_child(body); body.position=at
	body.occupied=true; body.set_physics_process(false)
	return body

func run():
	game=Game.new(); root.add_child(game)
	game.camera=Camera3D.new(); game.add_child(game.camera); game.camera.position=Vector3(0,40,20)
	weapons=Weapons.new(); game.add_child(weapons)
	observed=ObservedEffects.new(); weapons.add_child(observed); weapons.effects=observed
	weapons.setup(game); weapons.set_physics_process(false)
	var fx: Node3D=weapons.effects
	check("preallocated separate impact and discharge capacities",fx.stats().allocated==12 and fx.stats().muzzle_allocated==8 and fx.stats().audio_players==20)
	var original: Array=[]; identity(fx,original)
	for index in 120:
		fx.emit_blast(Vector3(index,40,0),1.0,Vector3.BACK)
		fx.emit_muzzle(Vector3(index,40,0),Vector3.FORWARD,"tank")
	var after: Array=[]; identity(fx,after)
	check("120 repeated emissions reuse exact Nodes Meshes MultiMeshes Materials",original==after)
	check("overflow remains bounded with no projectile or physical debris allocation",fx.stats().active==12 and fx.stats().active_muzzles==8 and physical_count(fx)==0 and game.impacts.is_empty())
	var emitted: int=fx.stats().emitted
	fx.emit_blast(Vector3(NAN,0,0)); fx.emit_blast(Vector3.ZERO,NAN)
	fx.emit_muzzle(Vector3.ZERO,Vector3.ZERO,"tank")
	check("nonfinite emissions rejected without consuming pool",fx.stats().emitted==emitted and fx.stats().discharges==120)
	var first: Dictionary=fx._slots[0]
	check("impact pressure surface follows wall normal",first.ring.basis.z.normalized().dot(Vector3.BACK)>.999)
	check("impact fire uses open textured cards instead of sphere",first.core.multimesh.mesh is QuadMesh and first.core.material_override is ShaderMaterial)
	check("smoke uses supplied alpha asset and bounded108particles",first.smoke.material_override.get_shader_parameter("cloud_texture") is Texture2D and fx.stats().particle_instances_per_blast==108)
	var light: OmniLight3D=first.light
	check("impact light is local no shadow map",not light.shadow_enabled and light.omni_range==42 and light.light_energy>0)
	fx.tick(.08)
	check("muzzle and impact bright stages overlap early",first.core.visible and fx._muzzles[0].core.visible and first.light.light_energy>0)
	fx.tick(.42)
	check("bright phase ends before sustained smoke",not first.core.visible and not light.visible and light.light_energy==0 and observed.sample(first.smoke.multimesh,0).color.a>.1)
	var dust_alpha: float=observed.sample(first.dust.multimesh,0).color.a
	check("dust perimeter is outside central hole",observed.sample(first.dust.multimesh,0).point.length()>8 and dust_alpha>0 and dust_alpha<.36,{"alpha":dust_alpha,"position":str(observed.sample(first.dust.multimesh,0).point)})
	check("smoke per-particle opacity is below .43",range(first.smoke.multimesh.instance_count).all(func(i):return observed.sample(first.smoke.multimesh,i).color.a<=.43),{"alpha":observed.sample(first.smoke.multimesh,0).color.a})
	var stable := snapshot(first.smoke.multimesh)
	fx.tick(0); fx.tick(NAN); fx.tick(-1)
	check("invalid or zero time never alters particle snapshot",stable==snapshot(first.smoke.multimesh))
	fx.tick(1.8)
	check("dust disappears while thin smoke continues",observed.sample(first.dust.multimesh,0).color.a==0 and observed.sample(first.smoke.multimesh,0).color.a>0,{"dust_alpha":observed.sample(first.dust.multimesh,0).color.a,"smoke_alpha":observed.sample(first.smoke.multimesh,0).color.a})
	fx.tick(2)
	check("all visual stages finish and lights extinguish",fx.stats().active==0 and fx.stats().active_muzzles==0 and light.light_energy==0)
	fx.emit_blast(Vector3.ZERO); fx.emit_muzzle(Vector3.ZERO,Vector3.FORWARD,"fighter"); fx.clear()
	check("clear silences both pools and hides every transient",fx.stats().active==0 and fx.stats().active_muzzles==0 and fx._slots.all(func(s):return not s.node.visible and not s.sound.playing) and fx._muzzles.all(func(s):return not s.node.visible and not s.sound.playing))
	for kind in ["tank","fighter","impact"]:
		var stream_value: AudioStreamWAV=Sound.stream(kind)
		var peak := 0.0; var square := 0.0; var sum := 0.0
		for i in stream_value.data.size()/2:
			var value := float(stream_value.data.decode_s16(i*2))/32768.0
			peak=maxf(peak,absf(value)); square+=value*value; sum+=value
		var count: float=stream_value.data.size()/2.0
		check(kind+" original PCM is audible bounded cached and DC stable",Sound.stream(kind)==stream_value and peak<.9 and peak>.4 and sqrt(square/count)>.025 and absf(sum/count)<.005,{"peak":peak,"rms":sqrt(square/count),"seconds":count/Sound.RATE})
	check("cannon and impact have distinct original waveforms",Sound.stream("tank").data!=Sound.stream("impact").data)
	var tank: RigidBody3D=fixture_tank("effects-cold",Vector3(0,40,0))
	var second: RigidBody3D=fixture_tank("effects-cached",Vector3(25,40,0))
	await physics_frame; await physics_frame; await process_frame
	game.current_vehicle=tank
	var first_meshes := meshes(tank); var second_meshes := meshes(second)
	check("cold and cached tank provide independent recoil mesh nodes",not first_meshes.is_empty() and not second_meshes.is_empty() and first_meshes[0]!=second_meshes[0] and second.get_meta("vehicle_factory_profile").cache_hit)
	var first_origins: Array=first_meshes.map(func(m):return m.position)
	var second_origins: Array=second_meshes.map(func(m):return m.position)
	var muzzle: Transform3D=tank._moving.muzzle.global_transform
	var barrel_pose: Transform3D=tank._moving.barrel.transform
	var saved: Dictionary=tank.get_state()
	var discharges: int=fx.stats().discharges
	check("real tank accepted shot starts discharge",weapons.fire_current() and fx.stats().discharges==discharges+1)
	check("cooldown rejection produces no phantom muzzle",not weapons.fire_current() and fx.stats().discharges==discharges+1)
	weapons._tick_recoil(.03)
	check("visible barrel retracts .30m while cached neighbour stays independent",absf((first_meshes[0].position-first_origins[0]).z-.30)<.001 and second_meshes.map(func(m):return m.position)==second_origins)
	check("recoil never changes logical chamber muzzle or aim",tank._moving.muzzle.global_transform==muzzle and tank._moving.barrel.transform==barrel_pose and tank.get_state()==saved)
	var before_pause: Vector3=first_meshes[0].position
	game.paused=true; weapons._physics_process(.4)
	check("game pause freezes recoil with projectiles and effects",first_meshes[0].position==before_pause)
	game.paused=false; game.current_vehicle=second
	weapons._tick_recoil(.5)
	check("switched-away vehicle finishes recoil without drift",first_meshes.map(func(m):return m.position)==first_origins and weapons.stats().active_recoils==0)
	check("second cached vehicle also fires independently",weapons.fire_current())
	weapons._tick_recoil(.04)
	check("clear restores active cached barrel to exact authored position",second_meshes[0].position!=second_origins[0])
	weapons.clear()
	check("clear restores poses plus sounds and keeps resources",second_meshes.map(func(m):return m.position)==second_origins and weapons.stats().active_recoils==0 and fx.stats().active_muzzles==0)
	# Freed vehicles do not leave strong references in the bounded visual queue.
	game.current_vehicle=tank; weapons.fire_current(); tank.queue_free(); await process_frame
	weapons._tick_recoil(.5)
	check("freed shooter can finish recoil safely",weapons.stats().active_recoils==0)
	weapons.clear()
	var recoil_fleet: Array[RigidBody3D]=[]
	var recoil_starts: Array[Vector3]=[]
	var successful := 0
	for index in 17:
		var body := fixture_tank("recoil-bound-"+str(index),Vector3(300+index*15,100,0))
		recoil_fleet.append(body); recoil_starts.append(meshes(body)[0].position)
		game.current_vehicle=body
		if weapons.fire_current(): successful+=1
		weapons._tick_recoil(.01)
	check("17 accepted distinct shots bound recoil to16 and restore evicted pose",successful==17 and weapons.stats().active_recoils==16 and meshes(recoil_fleet[0])[0].position==recoil_starts[0])
	weapons.clear()
	check("clear restores every surviving recoil after pool reuse",range(recoil_fleet.size()).all(func(i):return meshes(recoil_fleet[i])[0].position==recoil_starts[i]))
	# Observe production transforms and estimate velocity from actual submitted
	# positions on either side of the sample; no copied trajectory formula.
	var rng := RandomNumberGenerator.new(); rng.seed=181004
	var spark_max_angle := 0.0
	var projectile_max_angle := 0.0
	var ring_max_error := 0.0
	var chip_max_shear := 0.0
	var projectile_view := MeshInstance3D.new(); game.add_child(projectile_view)
	for sample_index in 12:
		var normal := Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		fx.emit_blast(Vector3(0,40,0),rng.randf_range(.4,2.2),normal)
		var slot: Dictionary=fx._slots[(fx._cursor+Effects.CAPACITY-1)%Effects.CAPACITY]
		slot.age=.219; fx._render_slot(slot)
		var before_poses: Array[Transform3D]=[]
		for i in Effects.SPARK_COUNT: before_poses.append(observed.pose_sample(slot.sparks.multimesh,i))
		slot.age=.221; fx._render_slot(slot)
		var after_poses: Array[Transform3D]=[]
		for i in Effects.SPARK_COUNT: after_poses.append(observed.pose_sample(slot.sparks.multimesh,i))
		slot.age=.220; fx._render_slot(slot)
		for i in Effects.SPARK_COUNT:
			var motion := after_poses[i].origin-before_poses[i].origin
			var basis: Basis=observed.pose_sample(slot.sparks.multimesh,i).basis
			spark_max_angle=maxf(spark_max_angle,rad_to_deg((-basis.z).angle_to(motion)))
		var ring_basis: Basis=slot.ring.basis
		ring_max_error=maxf(ring_max_error,absf(ring_basis.x.length()-ring_basis.y.length()))
		ring_max_error=maxf(ring_max_error,1.0-ring_basis.z.normalized().dot(normal))
		ring_max_error=maxf(ring_max_error,absf(ring_basis.x.normalized().dot(normal)))
		for i in Effects.DEBRIS_COUNT:
			var b: Basis=observed.pose_sample(slot.debris.multimesh,i).basis
			chip_max_shear=maxf(chip_max_shear,absf(b.x.normalized().dot(b.y.normalized())))
			chip_max_shear=maxf(chip_max_shear,absf(b.x.normalized().dot(b.z.normalized())))
			chip_max_shear=maxf(chip_max_shear,absf(b.z.normalized().dot(b.y.normalized())))
		# Use the actual production projectile presentation function and Node
		# transform, including arbitrary pitched/diagonal travelling directions.
		weapons._show_projectile({"view":projectile_view,"velocity":normal*1490,"position":Vector3(0,30,0)},1.0/60)
		projectile_max_angle=maxf(projectile_max_angle,rad_to_deg((-projectile_view.global_basis.z).angle_to(normal)))
	check("384 production spark long axes follow measured particle motion",spark_max_angle<.02,{"max_angle_degrees":spark_max_angle,"directions":384})
	check("12 arbitrary hit planes keep circular pressure ring tangent and normal",ring_max_error<.0001,{"max_axis_error":ring_max_error})
	check("240 tumbling chips retain perpendicular local axes without shear",chip_max_shear<.00001,{"max_normalized_axis_dot":chip_max_shear})
	check("12 production projectile meshes align long axis with velocity",projectile_max_angle<.001,{"max_angle_degrees":projectile_max_angle})
	projectile_view.queue_free(); weapons.clear()
	var passed := checks.all(func(c):return c.passed)
	var report := {"passed":passed,"count":checks.size(),"checks":checks,"headless":true,"engine":Engine.get_version_info().string,"scope":"Real cached/cold HarborVehicle tank, weapon pool and PCM/particle lifecycle. Particle assertions observe submitted values because Dummy RenderingServer getters return defaults. No native visual/audio listening claim, no full city or user saves.","source_sha256":{}}
	for path in ["res://scripts/vehicle_weapons.gd","res://scripts/combat_effects.gd","res://scripts/weapon_audio.gd","res://shaders/combat_cloud.gdshader","res://shaders/combat_pressure.gdshader","res://assets/fx/artillery_smoke.png","res://scripts/vehicle_factory.gd","res://../source/combat_effects_test.gd"]:
		report.source_sha256[path]=FileAccess.get_sha256(path)
	DirAccess.make_dir_recursive_absolute("res://../reports/combat-effects-v018")
	FileAccess.open("res://../reports/combat-effects-v018/headless.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("COMBAT_EFFECTS_COMPLETE ",checks.size()," passed=",passed)
	quit(0 if passed else 1)
