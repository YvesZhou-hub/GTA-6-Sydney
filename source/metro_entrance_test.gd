extends SceneTree
const METRO = preload("res://scripts/metro_entrances.gd")
class LocalMetro:
	extends "res://scripts/harbor_world.gd"
	func _ready() -> void:
		_make_materials()
		for name: String in ["barangaroo","martin_place"]:
			var f:=METRO._frame(name)
			var half: float=3.55 if name=="barangaroo" else 9.2
			var length: float=f.length
			var front: float=-0.12 if name=="barangaroo" else -1.0
			for rect: Array in [[Vector2((-35-half)*0.5,(length+3)*0.5),Vector2(35-half,length+47)],[Vector2((35+half)*0.5,(length+3)*0.5),Vector2(35-half,length+47)],[Vector2(0,(-22+front)*0.5),Vector2(half*2,front+22)],[Vector2(0,length+15.05),Vector2(half*2,19.9)]]:
				var center: Vector3=f.a+f.right*rect[0].x+f.forward*rect[0].y-Vector3.UP*0.25
				var slab:=_box(self,center,Vector3(rect[1].x,0.5,rect[1].y),"paving",true)
				slab.basis=f.basis
				# _box collision is a sibling and needs the same planar orientation.
				get_child(get_child_count()-1).basis=f.basis
		METRO.build(self)
		_flush_batches()
		_build_structure_batches()
var failures:=0
func verify(value: bool,text_value: String) -> void:
	if value:print("PASS ",text_value)
	else:failures+=1;push_error(text_value)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for action: String in ["forward","back","left","right","jump","sprint"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var world=LocalMetro.new() if not "--full-world" in OS.get_cmdline_user_args() else load("res://scripts/harbor_world.gd").new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	if "--full-world" in OS.get_cmdline_user_args() and not world._ready_complete:
		push_error("Production world initialization did not complete; metro integration results would be invalid")
		quit(1)
		return
	var space: PhysicsDirectSpaceState3D=world.get_world_3d().direct_space_state
	for name: String in ["barangaroo","martin_place"]:
		var gaps:=0;var blocked:=0;var shallow:=0
		var shape:=CapsuleShape3D.new();shape.radius=0.33;shape.height=1.8
		for row: Dictionary in METRO.ROUTES[name]:
			var a:=METRO.v(row.top);var b:=METRO.v(row.bottom)
			for i in range(1,80):
				var p:=a.lerp(b,float(i)/80)
				var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.30,p-Vector3.UP*0.4))
				if hit.is_empty():gaps+=1
				var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=p+Vector3.UP*1.0;query.margin=0.004
				var obstruction:=space.intersect_shape(query)
				if not obstruction.is_empty():
					blocked+=1
					if blocked<8:print("METRO_OBSTRUCTION ",row.osm_way," at ",p," ",obstruction.map(func(item):return item.collider.name))
				if i==40:
					var top_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,4.8,p.z),Vector3(p.x,-12,p.z)))
					if not top_hit.is_empty() and top_hit.position.y>p.y+0.35:shallow+=1
		verify(gaps==0,"%s all escalator collision support continuous: %s"%[name,gaps])
		verify(blocked==0,"%s human capsule and head clearance: %s"%[name,blocked])
		verify(shallow==0,"%s actual earth opening; no ground slab crosses stairs"%name)
		var f:=METRO._frame(name)
		verify(METRO.contains_dry_volume(f.b+Vector3.UP),"%s underground landing is a declared dry volume"%name)
		if name=="martin_place":check_street_approaches(space)
		if not "--geometry-only" in OS.get_cmdline_user_args():await walk_route(world,name)
	if "--capture" in OS.get_cmdline_user_args():await capture(world)
	print("METRO CHECK COMPLETE failures=",failures)
	quit(failures)
func check_street_approaches(space: PhysicsDirectSpaceState3D) -> void:
	var shape:=CapsuleShape3D.new();shape.radius=0.33;shape.height=1.8
	for entry: Array in [[Vector3(-33.2178,4.5,712.214228),Vector3(-2,0,-2),1],[Vector3(3.8808,4.5,715.665148),Vector3(2,0,-2),7]]:
		var node: Vector3=entry[0]
		var row: Dictionary=METRO.ROUTES.martin_place[entry[2]]
		var a:=METRO.v(row.top);var b:=METRO.v(row.bottom)
		var forward:=Vector3(b.x-a.x,0,b.z-a.z).normalized()
		var route: Array=[node+entry[1],node,node+(a-node).normalized()*2.0,a-forward*2.0]
		var blocked:=0
		for i in range(route.size()-1):
			for j in range(25):
				var p: Vector3=route[i].lerp(route[i+1],float(j)/24)
				var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=p+Vector3.UP*1.03
				var hits:=space.intersect_shape(query)
				if not hits.is_empty():
					blocked+=1
					if blocked<3:print("APPROACH_OBSTRUCTION ",p," ",hits.map(func(item):return item.collider.name))
		verify(blocked==0,"Martin Place mapped Hunter Street entrance %s reaches escalators: %s blocked"%[entry[2],blocked])

func walk_route(world: Node3D,name: String) -> void:
	var row: Dictionary=METRO.ROUTES[name][1]
	var a:=METRO.v(row.top);var b:=METRO.v(row.bottom)
	var direction:=Vector3(b.x-a.x,0,b.z-a.z).normalized()
	var player=load("res://scripts/harbor_player.gd").new()
	world.add_child(player)
	player.position=(a-direction*4.0 if name=="barangaroo" else Vector3(-35.2178,4.5,710.214228))+Vector3.UP*0.22;player.last_safe=player.position;player.enabled=true
	for i in range(20):await physics_frame
	if name=="martin_place":
		for target: Vector3 in [Vector3(-33.2178,4.5,712.214228),a-direction*2.0]:
			Input.action_press("forward")
			for frame in range(400):
				var toward:=Vector3(target.x-player.position.x,0,target.z-player.position.z)
				if toward.length()<0.35:break
				player.yaw=atan2(-toward.x,-toward.z)
				await physics_frame
			Input.action_release("forward")
	player.yaw=atan2(-direction.x,-direction.z)
	Input.action_press("forward")
	var swam:=false
	for i in range(480):
		await physics_frame
		swam=swam or player.swimming
		if Vector2(player.position.x-b.x,player.position.z-b.z).dot(Vector2(direction.x,direction.z))>1.9:break
	Input.action_release("forward")
	for i in range(25):await physics_frame
	verify(player.position.y<b.y+0.2 and player.position.y>b.y-0.15,"%s actual player reaches lower landing, y=%.3f"%[name,player.position.y])
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	for i in range(55):await physics_frame;swam=swam or player.swimming
	verify(not swam,"%s underground walking/jump never becomes swimming"%name)
	player.yaw=atan2(direction.x,direction.z)
	Input.action_press("forward")
	for i in range(480):
		await physics_frame
		if Vector2(player.position.x-a.x,player.position.z-a.z).dot(Vector2(direction.x,direction.z))< -1.4:break
	Input.action_release("forward")
	for i in range(20):await physics_frame
	verify(player.position.y>4.4 and player.position.y<4.8,"%s actual player walks back to street, y=%.3f"%[name,player.position.y])
	player.queue_free()
func capture(world: Node3D) -> void:
	root.size=Vector2i(1440,900)
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("92b4c8");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("c6d6dd");environment.ambient_light_energy=0.7
	var env:=WorldEnvironment.new();env.environment=environment;world.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-40,0);sun.light_energy=1.2;sun.shadow_enabled=true;world.add_child(sun)
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.far=900
	var f:=METRO._frame("barangaroo")
	var mf:=METRO._frame("martin_place")
	var views: Array=[["martin-front",Vector3(-45,10,681),Vector3(-15,15,728)],["martin-atrium",Vector3(-21,6.4,722),mf.b+Vector3.UP*1.7],["barangaroo-front",f.a+f.forward*-20+f.right*7+Vector3.UP*4,f.a+f.forward*6+Vector3.UP*2],["barangaroo-stairs",f.a+f.forward*-1+Vector3.UP*1.6,f.b+Vector3.UP*1.3],["barangaroo-landing",f.b+f.forward*2.9+Vector3.UP*1.6,f.a+Vector3.UP*2.2]]
	var folder:=ProjectSettings.globalize_path("res://../reports/metro-refinement"+("/full-world" if "--full-world" in OS.get_cmdline_user_args() else "/local"));DirAccess.make_dir_recursive_absolute(folder)
	for view: Array in views:
		camera.position=view[1];camera.look_at(view[2]);for i in range(5):await process_frame
		RenderingServer.force_draw(false);root.get_texture().get_image().save_png(folder+"/"+view[0]+".png");print("METRO FRAME ",view[0])
