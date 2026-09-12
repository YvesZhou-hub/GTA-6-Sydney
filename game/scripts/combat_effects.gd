extends Node3D
## Original bounded staged discharge/impact. World owns persistent destruction.
## Cards use shared immutable mesh/shader/audio resources, never per-shot builds.
const Audio = preload("res://scripts/weapon_audio.gd")
const CloudShader = preload("res://shaders/combat_cloud.gdshader")
const PressureShader = preload("res://shaders/combat_pressure.gdshader")
const CAPACITY := 12
const MUZZLE_CAPACITY := 8
const DURATION := 3.4
const MUZZLE_DURATION := 1.4
const SMOKE_COUNT := 18
const DUST_COUNT := 24
const FIRE_COUNT := 14
const SPARK_COUNT := 32
const DEBRIS_COUNT := 20
var _slots: Array[Dictionary] = []
var _muzzles: Array[Dictionary] = []
var _cursor := 0
var _muzzle_cursor := 0
var _sequence := 0
var _discharges := 0

func _ready() -> void: prepare()

func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

func _instances(mesh: Mesh, material: Material, count: int, parent: Node3D) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = count
	multi.custom_aabb = AABB(Vector3.ONE * -140, Vector3.ONE * 280)
	var view := MultiMeshInstance3D.new()
	view.multimesh = multi
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
	return view

func _light(parent: Node3D, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0,.58,.26)
	light.shadow_enabled = false
	light.omni_range = radius
	light.light_energy = 0.0
	light.visible = false
	parent.add_child(light)
	return light

func _speaker(parent: Node3D, kind: String) -> AudioStreamPlayer3D:
	var speaker := AudioStreamPlayer3D.new()
	speaker.stream = Audio.stream(kind)
	speaker.unit_size = 32.0
	speaker.max_distance = 650.0
	speaker.max_db = -2.0
	speaker.volume_db = -2.0
	speaker.attenuation_filter_cutoff_hz = 5500.0
	speaker.max_polyphony = 1
	parent.add_child(speaker)
	return speaker

func prepare() -> void:
	if not _slots.is_empty(): return
	var card := QuadMesh.new(); card.size = Vector2(2,2)
	var chip := PrismMesh.new(); chip.size = Vector3.ONE
	var ember := BoxMesh.new(); ember.size = Vector3.ONE
	var fire := ShaderMaterial.new(); fire.shader = CloudShader; fire.set_shader_parameter("incandescent",true)
	var smoke := ShaderMaterial.new(); smoke.shader = CloudShader
	smoke.set_shader_parameter("cloud_texture",load("res://assets/fx/artillery_smoke.png"))
	var pressure := ShaderMaterial.new(); pressure.shader = PressureShader
	var sparks := _material(Color(1.0,.52,.12),3.0)
	var debris := _material(Color(.48,.42,.33))
	for index in CAPACITY:
		var node := Node3D.new(); node.name = "PooledBlast_%02d" % index
		add_child(node); node.visible = false
		var ring := MeshInstance3D.new(); ring.mesh = card; ring.material_override = pressure
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(ring)
		_slots.append({"node":node,"age":DURATION,"scale":1.0,"seed":0,"normal":Vector3.UP,
			"core":_instances(card,fire,FIRE_COUNT,node),"ring":ring,"light":_light(node,42.0),
			"smoke":_instances(card,smoke,SMOKE_COUNT,node),"dust":_instances(card,smoke,DUST_COUNT,node),
			"sparks":_instances(ember,sparks,SPARK_COUNT,node),"debris":_instances(chip,debris,DEBRIS_COUNT,node),
			"sound":_speaker(node,"impact")})
	var pool := Node3D.new(); pool.name = "PooledDischarges"; add_child(pool)
	for index in MUZZLE_CAPACITY:
		var node := Node3D.new(); node.name = "Discharge_%02d" % index; pool.add_child(node); node.visible = false
		_muzzles.append({"node":node,"age":MUZZLE_DURATION,"kind":"tank","seed":0,
			"core":_instances(card,fire,10,node),"smoke":_instances(card,smoke,8,node),
			"light":_light(node,19.0),"sound":_speaker(node,"tank")})
	# Warm both PCM variations outside the first successful gameplay shot.
	Audio.stream("fighter")

func _play(slot: Dictionary) -> void:
	slot.sound.stop()
	if DisplayServer.get_name() != "headless": slot.sound.play()

func emit_blast(point: Vector3, size: float = 1.0, normal: Vector3 = Vector3.UP) -> void:
	if not point.is_finite() or not is_finite(size): return
	prepare()
	var slot: Dictionary = _slots[_cursor]
	_cursor = (_cursor + 1) % CAPACITY
	_sequence += 1
	slot.age = 0.0; slot.scale = clampf(size,.25,2.5); slot.seed = _sequence
	slot.normal = normal.normalized() if normal.is_finite() and normal.length_squared() > .01 else Vector3.UP
	slot.node.global_position = point + slot.normal * .08
	slot.node.visible = true
	_play(slot); _render_slot(slot)

func emit_muzzle(point: Vector3, direction: Vector3, kind: String) -> void:
	if not point.is_finite() or not direction.is_finite() or direction.length_squared() < .01: return
	prepare()
	var slot: Dictionary = _muzzles[_muzzle_cursor]
	_muzzle_cursor = (_muzzle_cursor+1) % MUZZLE_CAPACITY
	_discharges += 1
	slot.age=0.0; slot.kind=kind; slot.seed=_discharges
	var up := Vector3.RIGHT if absf(direction.normalized().y) > .98 else Vector3.UP
	slot.node.global_transform=Transform3D(Basis.looking_at(direction.normalized(),up),point)
	slot.node.visible=true
	slot.sound.stream=Audio.stream("tank" if kind=="tank" else "fighter")
	_play(slot); _render_muzzle(slot)

func _direction(index: int, seed_value: int) -> Vector3:
	var phase := float(index)*2.399963+float(seed_value%29)*.63
	var lift := .15+.76*float((index*13+seed_value*7)%31)/30.0
	return Vector3(cos(phase),lift,sin(phase)).normalized()

func _card(multi: MultiMesh, index: int, point: Vector3, extent: Vector2, color: Color, seed_value: float, age: float) -> void:
	multi.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3(maxf(.001,extent.x),maxf(.001,extent.y),1)),point))
	multi.set_instance_color(index,color)
	multi.set_instance_custom_data(index,Color(fposmod(seed_value,1),age,0,0))

func _set_particle_pose(multi: MultiMesh, index: int, pose: Transform3D) -> void:
	multi.set_instance_transform(index,pose)

func _render_slot(slot: Dictionary) -> void:
	var age: float = slot.age
	var size: float = slot.scale
	var normal: Vector3 = slot.normal
	var surface := Basis(Quaternion(Vector3.UP,normal))
	# The bright phase is broken into outward tongues; no closed glowing sphere.
	slot.core.visible = age < .38
	for index in (FIRE_COUNT if slot.core.visible else 0):
		var t := maxf(0,age-float(index%3)*.018)
		var d := surface*_direction(index,slot.seed)
		var p := d*size*(.35+6.0*(1-exp(-t*9)))
		var radius := size*(.40+sin(minf(1,t/.38)*PI)*1.7)
		var alpha := pow(maxf(0,1-age/.38),1.5)*.74
		_card(slot.core.multimesh,index,p,Vector2(radius,radius*1.15),Color(1,1,1,alpha),index*.137+slot.seed*.031,age)
	var light: OmniLight3D = slot.light
	light.visible=age < .26
	light.position=normal*1.2
	light.light_energy=18.0*pow(maxf(0,1-age/.26),3)
	var ring: MeshInstance3D = slot.ring
	ring.visible=age < .55
	var radius := size*(.35+age*42.0)
	# Quad normal is +Z, unlike the old horizontal torus on every wall impact.
	ring.basis=Basis(Quaternion(Vector3.BACK,normal)).scaled_local(Vector3(radius,radius,1))
	ring.position=normal*.13
	ring.transparency=clampf(age/.55,0,1)
	var smoke: MultiMesh = slot.smoke.multimesh
	for index in SMOKE_COUNT:
		var delay := .04+float(index%5)*.035
		var t := maxf(0,age-delay)
		var d := surface*_direction(index+31,slot.seed)
		var p := d*size*(1.1+4.8*(1-exp(-t*1.5)))+Vector3.UP*size*t*1.7
		var r := size*(.6+t*(1.15+float(index%3)*.22))
		var alpha := clampf((age-delay)/.22,0,1)*pow(maxf(0,1-age/DURATION),1.35)*.43
		var tone := .36+float(index%4)*.042
		_card(smoke,index,p,Vector2(r,r*1.12),Color(tone,tone*.96,tone*.9,alpha),index*.173+slot.seed*.037,t)
	var dust: MultiMesh = slot.dust.multimesh
	slot.dust.visible = age < 2.15
	for index in DUST_COUNT:
		var phase: float = float(index)*TAU/DUST_COUNT+float(slot.seed)*.43
		var t := maxf(0,age-.025*float(index%3))
		var along := Vector3(cos(phase),0,sin(phase))
		var travel := size*(.5+12.5*(1-exp(-t*2.8)))
		var p := surface*(along*travel+Vector3.UP*size*(.15+t*.65))
		var r := size*(.28+minf(t,1.5)*1.25)
		var alpha := minf(1,t*16)*pow(maxf(0,1-age/2.15),1.6)*.36
		_card(dust,index,p,Vector2(r*1.35,r*.66),Color(.57,.50,.39,alpha),index*.123+slot.seed*.011,t)
	var sparks: MultiMesh = slot.sparks.multimesh
	slot.sparks.visible=age<1.15
	for index in (SPARK_COUNT if slot.sparks.visible else 0):
		var d := surface*_direction(index+7,slot.seed)
		var speed := 17.0+float(index%7)*3.4
		var p := d*speed*age*size+Vector3.DOWN*8.0*age*age
		var velocity := d*speed*size+Vector3.DOWN*16*age
		var up := Vector3.RIGHT if absf(velocity.normalized().y)>.98 else Vector3.UP
		# Preserve the velocity-facing local Z axis when stretching the streak.
		var basis := Basis.looking_at(velocity.normalized(),up).scaled_local(Vector3(.028,.028,.6+speed*.035)*size)
		_set_particle_pose(sparks,index,Transform3D(basis,p))
		sparks.set_instance_color(index,Color(1,.72,.25,pow(maxf(0,1-age/1.15),1.3)))
	var debris: MultiMesh = slot.debris.multimesh
	for index in DEBRIS_COUNT:
		var d := surface*_direction(index+19,slot.seed)
		var p := d*size*(7.0+index%5)*age+Vector3.DOWN*4.9*age*age
		# Only a horizontal impact has a known ground plane; wall chips must fall.
		if normal.y>.8: p.y=maxf(.07,p.y)
		var extent := size*(.10+float(index%5)*.07)
		var basis := Basis.from_euler(Vector3(age*4,float(index),age*2.3)).scaled_local(Vector3(extent,extent*.55,extent*1.4))
		_set_particle_pose(debris,index,Transform3D(basis,p))
		debris.set_instance_color(index,Color(1,1,1,minf(1,maxf(0,(DURATION-age)/.7))))

func _render_muzzle(slot: Dictionary) -> void:
	var age: float=slot.age
	var size := 1.0 if slot.kind=="tank" else .46
	slot.core.visible=age<.16
	for index in (10 if slot.core.visible else 0):
		var radial := float(index)*2.39996
		var travel := .45+float(index%4)*.78+age*12
		var p := Vector3(cos(radial),sin(radial),0)*size*(.15+float(index%3)*.17)
		p.z=-travel*size
		var r := size*(.50+float(index%3)*.16)*(1+age*5)
		_card(slot.core.multimesh,index,p,Vector2(r,r*.77),Color(1,1,1,pow(maxf(0,1-age/.16),1.4)*.91),index*.143+slot.seed*.037,age)
	slot.light.visible=age<.13
	slot.light.position=Vector3(0,0,-1)
	slot.light.light_energy=13.0*size*pow(maxf(0,1-age/.13),2)
	for index in 8:
		var t := maxf(0,age-.015*float(index%3))
		var phase := float(index)*2.399
		var p := Vector3(cos(phase)*(.18+t),sin(phase)*(.18+t)+t*.45,-(.4+index*.36+t*2.8))*size
		var r := size*(.24+t*.87)
		var alpha := minf(1,t*18)*pow(maxf(0,1-age/MUZZLE_DURATION),1.7)*.34
		_card(slot.smoke.multimesh,index,p,Vector2(r,r),Color(.58,.55,.49,alpha),index*.193+slot.seed*.017,t)

func tick(delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	for slot: Dictionary in _slots:
		if slot.age>=DURATION: continue
		slot.age=minf(DURATION,slot.age+delta)
		if slot.age>=DURATION: _hide(slot)
		else: _render_slot(slot)
	for slot: Dictionary in _muzzles:
		if slot.age>=MUZZLE_DURATION: continue
		slot.age=minf(MUZZLE_DURATION,slot.age+delta)
		if slot.age>=MUZZLE_DURATION:
			# The PCM tail may finish independently; clear/world reset stops it.
			slot.node.visible=false; slot.light.visible=false; slot.light.light_energy=0
		else: _render_muzzle(slot)

func _hide(slot: Dictionary) -> void:
	slot.node.visible=false; slot.light.visible=false; slot.light.light_energy=0

func clear() -> void:
	for slot: Dictionary in _slots:
		slot.age=DURATION; _hide(slot); slot.sound.stop()
	for slot: Dictionary in _muzzles:
		slot.age=MUZZLE_DURATION; _hide(slot); slot.sound.stop()

func stats() -> Dictionary:
	var active := 0
	var discharges := 0
	for slot: Dictionary in _slots:
		if slot.age<DURATION: active+=1
	for slot: Dictionary in _muzzles:
		if slot.age<MUZZLE_DURATION: discharges+=1
	return {"capacity":CAPACITY,"allocated":_slots.size(),"active":active,
		"muzzle_capacity":MUZZLE_CAPACITY,"muzzle_allocated":_muzzles.size(),"active_muzzles":discharges,
		"particle_instances_per_blast":SMOKE_COUNT+DUST_COUNT+FIRE_COUNT+SPARK_COUNT+DEBRIS_COUNT,
		"emitted":_sequence,"discharges":_discharges,"physical_debris_bodies":0,
		"audio_players":_slots.size()+_muzzles.size(),"stage_seconds":{"flash":.38,"pressure":.55,"dust":2.15,"smoke":DURATION}}
