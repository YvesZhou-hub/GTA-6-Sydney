extends RefCounted
## Photo-referenced, metre-scale original Opera House exterior. See docs/OPERA_REFERENCE.md.
## Both halves of every roof are cut from an equal-radius sphere and meet at a sharp ridge.
## Geometry and its closed collider are the same mesh; ribs live on their damage component.

# OSM relation/9596872 outer-ring centroid and minimum-area long-axis bearing.
# These align the authored reconstruction, not a claim that every shell is surveyed.
const CENTER := Vector3(427.2947742677, 4.5, -321.4544052467)
const ANGLE := -13.232864688
const PODIUM_HEIGHT := 11.2
const SPHERE_RADIUS := 75.2
const SHELL_THICKNESS := 0.32
const BANDS := 8
const BAND_STEPS := 3
const LONG_STEPS := 24
const TILE_SHADER = preload("res://shaders/opera_tiles.gdshader")

# x, z, half width, depth, height over podium, yaw relative to site, hall group.
# Successive north-facing roofs rise towards the centre; the southern foyer faces the steps.
const ROOFS := [
	[-27.0,-52.0,22.0,37.0,28.0,-3.0,"concert"],
	[-27.0,-29.0,24.0,53.0,39.0,-3.0,"concert"],
	[-26.0,0.0,25.2,68.0,50.15,-3.0,"concert"],
	[-24.0,44.0,20.0,43.0,26.0,177.0,"concert"],
	[24.0,-41.0,18.5,34.0,23.0,3.0,"joan_sutherland"],
	[24.0,-20.0,20.0,46.0,32.0,3.0,"joan_sutherland"],
	[23.0,5.0,21.0,57.0,41.0,3.0,"joan_sutherland"],
	[21.5,43.0,17.0,36.0,22.0,183.0,"joan_sutherland"],
	[-41.0,72.0,11.0,22.0,15.0,0.0,"bennelong"],
	[-41.0,86.0,11.0,21.0,14.0,180.0,"bennelong"]
]

static func site_basis() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(ANGLE))

static func build(world: Node3D) -> void:
	var basis := site_basis()
	var tile := ShaderMaterial.new()
	tile.shader = TILE_SHADER
	world.materials["opera_tiles"] = tile
	world._mat("opera_granite", Color("b5a18b"), 0.86)
	world._mat("opera_edge", Color("d4cbbb"), 0.72)
	world._mat("opera_bronze", Color("594d38"), 0.34, 0.64)
	var glass: StandardMaterial3D = world._mat("opera_glass", Color("344c4b"), 0.40, 0.12)
	glass.metallic_specular = 0.25
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	world._mat("opera_recess", Color("333b38"), 0.85)
	_build_podium(world, basis)
	for index in range(ROOFS.size()):
		var spec: Array = ROOFS[index]
		var origin := CENTER + basis * Vector3(spec[0], PODIUM_HEIGHT, spec[1])
		var roof_basis := basis * Basis(Vector3.UP, deg_to_rad(spec[5]))
		for side in [-1, 1]:
			var surface := sphere_patch(spec[2], spec[3], spec[4], side)
			for band in range(BANDS):
				var from := float(band) / BANDS
				var to := float(band + 1) / BANDS
				var id := "opera/shell/%s/%s" % [index, band + (BANDS if side > 0 else 0)]
				var body: StaticBody3D = world._structure_mesh(id, shell_mesh(surface, from, to), origin, "opera_tiles", 180000.0, roof_basis)
				body.set_meta("shell_group", spec[6])
				body.set_meta("sphere_radius", SPHERE_RADIUS)
				body.set_meta("surface_center", surface.center)
				_add_ribs(world, body, surface, from, to)
		if index in [0,3,4,7,8,9]:
			_build_foyer(world, index, spec, origin, roof_basis)
	_build_promenade(world, basis)
	world.set_meta("opera_shell_pairs", ROOFS.size())
	world.set_meta("opera_reference_revision", "spherical-pairs-2026-09")

static func sphere_patch(width: float, depth: float, height: float, side: int) -> Dictionary:
	var a := Vector3(0.0, height, -depth * 0.5)
	var b := Vector3(0.0, 0.8, depth * 0.5)
	var c := Vector3(width * side, 0.0, -depth * 0.18)
	var ab := b-a
	var ac := c-a
	var cross := ab.cross(ac)
	var normal := cross.normalized()
	if normal.dot(Vector3(side, 1.0, 0.0)) < 0.0: normal = -normal
	var circum := a + (ac.length_squared() * cross.cross(ab) + ab.length_squared() * ac.cross(cross)) / (2.0 * cross.length_squared())
	var radius_squared := circum.distance_squared_to(a)
	assert(radius_squared < SPHERE_RADIUS * SPHERE_RADIUS, "Roof triangle must fit the common sphere")
	var center := circum - normal * sqrt(SPHERE_RADIUS * SPHERE_RADIUS - radius_squared)
	var tangent := ab.normalized()
	return {"a":a, "b":b, "c":c, "center":center, "normal":normal, "tangent":tangent, "bitangent":normal.cross(tangent)}

static func shell_point(surface: Dictionary, u: float, v: float, inset: float = 0.0) -> Vector3:
	# The ridge is the sphere's exact intersection with x=0. Spherical interpolation
	# from that circular ridge to the springing point gives rounded outer shoulders.
	# Normalizing a planar triangle would pull the two ridge halves apart.
	var radius := sqrt(SPHERE_RADIUS*SPHERE_RADIUS-float(surface.center.x)*float(surface.center.x))
	var start := atan2(float(surface.a.z)-float(surface.center.z),float(surface.a.y)-float(surface.center.y))
	var end := atan2(float(surface.b.z)-float(surface.center.z),float(surface.b.y)-float(surface.center.y))
	var angle := lerp_angle(start,end,v)
	var ridge := Vector3(0.0,float(surface.center.y)+cos(angle)*radius,float(surface.center.z)+sin(angle)*radius)
	var ridge_direction: Vector3 = (ridge-surface.center).normalized()
	var toe_direction: Vector3 = (surface.c-surface.center).normalized()
	return surface.center + ridge_direction.slerp(toe_direction,u) * (SPHERE_RADIUS-inset)

static func _uv(surface: Dictionary, point: Vector3) -> Vector2:
	var direction: Vector3 = (point - surface.center).normalized()
	return Vector2(atan2(direction.dot(surface.tangent), direction.dot(surface.normal)), atan2(direction.dot(surface.bitangent), direction.dot(surface.normal))) * SPHERE_RADIUS

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, surface: Dictionary = {}, inner: bool = false) -> void:
	if (b-a).cross(c-a).length_squared() < 0.00000001: return
	var points := [a, b, c]
	# Godot fronts are clockwise; geometric cross points away from the rendered front.
	if (b-a).cross(c-a).dot(normal) > 0.0: points = [a, c, b]
	for point: Vector3 in points:
		st.set_color(Color(0.72,0.705,0.66,0.0) if inner else Color.WHITE)
		if surface.is_empty():
			st.set_normal(normal)
			st.set_uv(Vector2(point.x, point.z))
		else:
			st.set_normal((point - surface.center).normalized() * (-1.0 if inner else 1.0))
			st.set_uv(_uv(surface, point))
		st.add_vertex(point)

static func shell_mesh(surface: Dictionary, from: float, to: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(2):
		var inner := layer == 1
		var inset := SHELL_THICKNESS if inner else 0.0
		for column in range(BAND_STEPS):
			for row in range(LONG_STEPS):
				var u0 := lerpf(from, to, float(column)/BAND_STEPS)
				var u1 := lerpf(from, to, float(column+1)/BAND_STEPS)
				var v0 := float(row)/LONG_STEPS
				var v1 := float(row+1)/LONG_STEPS
				var a := shell_point(surface,u0,v0,inset)
				var b := shell_point(surface,u1,v0,inset)
				var c := shell_point(surface,u0,v1,inset)
				var d := shell_point(surface,u1,v1,inset)
				var normal: Vector3 = ((a+b+c)/3.0-surface.center).normalized() * (-1.0 if inner else 1.0)
				_triangle(st,a,b,c,normal,surface,inner)
				_triangle(st,c,b,d,normal,surface,inner)
	# Close all four boundaries so roof chunks have thickness and reliable two-sided impacts.
	for edge in range(4):
		var count := LONG_STEPS if edge < 2 else BAND_STEPS
		for j in range(count):
			var t0 := float(j)/count
			var t1 := float(j+1)/count
			var p0 := Vector2(from if edge==0 else to, t0) if edge<2 else Vector2(lerpf(from,to,t0),0.0 if edge==2 else 1.0)
			var p1 := Vector2(from if edge==0 else to, t1) if edge<2 else Vector2(lerpf(from,to,t1),0.0 if edge==2 else 1.0)
			var a := shell_point(surface,p0.x,p0.y)
			var b := shell_point(surface,p1.x,p1.y)
			var c := shell_point(surface,p0.x,p0.y,SHELL_THICKNESS)
			var d := shell_point(surface,p1.x,p1.y,SHELL_THICKNESS)
			var middle := shell_point(surface, (from+to)*0.5, 0.5, SHELL_THICKNESS*0.5)
			var normal := (b-a).cross(c-a).normalized()
			if normal.dot((a+b+c+d)*0.25-middle)<0.0: normal = -normal
			_triangle(st,a,b,c,normal)
			_triangle(st,c,b,d,normal)
	return st.commit()

static func _add_ribs(world: Node3D, body: Node3D, surface: Dictionary, from: float, to: float) -> void:
	# Thin rim and fan ribs are one mesh per chunk, so destruction cannot leave floating ribs.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for rib in range(13):
		var v := float(rib)/12.0
		for j in range(4):
			var u0 := lerpf(from,to,float(j)/4.0)
			var u1 := lerpf(from,to,float(j+1)/4.0)
			var p0 := shell_point(surface,u0,v,-0.027)
			var p1 := shell_point(surface,u1,v,-0.027)
			if p0.distance_to(p1)<0.001: continue
			var delta := (p1-p0).normalized()
			var normal: Vector3 = ((p0+p1)*0.5-surface.center).normalized()
			var offset := normal.cross(delta).normalized() * (0.70 if rib==0 else (0.32 if rib==12 else 0.037))
			_triangle(st,p0-offset,p1-offset,p0+offset,normal)
			_triangle(st,p0+offset,p1-offset,p1+offset,normal)
			# Broad concrete fan ribs on the visible soffit, attached to the same roof band.
			var q0 := shell_point(surface,u0,v,SHELL_THICKNESS+0.07)
			var q1 := shell_point(surface,u1,v,SHELL_THICKNESS+0.07)
			var rib_edge := normal.cross(delta).normalized()*0.21
			_triangle(st,q0-rib_edge,q1-rib_edge,q0+rib_edge,-normal)
			_triangle(st,q0+rib_edge,q1-rib_edge,q1+rib_edge,-normal)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = world.materials["opera_edge"]
	body.add_child(mi)

static func _build_foyer(world: Node3D, index: int, spec: Array, origin: Vector3, basis: Basis) -> void:
	var surface := sphere_patch(spec[2],spec[3],spec[4],1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curves: Array[Vector3] = []
	for i in range(25):
		var lateral := (i-12.0)/12.0
		var point := shell_point(surface, absf(lateral), 0.0)
		point.x = absf(point.x) * signf(lateral)
		point.x *= 0.95
		# The bronze curtain sits behind the concrete arch and its deep ribbed soffit.
		point.y = maxf(0.2,point.y-2.2-float(spec[4])*0.055*(1.0-absf(lateral)))
		point.z += 2.5+4.0*(1.0-absf(lateral))
		curves.append(point)
	for i in range(24):
		var a: Vector3 = curves[i]
		var b: Vector3 = curves[i+1]
		var ba := Vector3(a.x,0.25,a.z-4.0*(1.0-absf(a.x)/float(spec[2])))
		var bb := Vector3(b.x,0.25,b.z-4.0*(1.0-absf(b.x)/float(spec[2])))
		if maxf(a.y,b.y)<0.5: continue
		_triangle(st,ba,bb,a,Vector3.FORWARD)
		_triangle(st,a,bb,b,Vector3.FORWARD)
	var id := "opera/glass/%s"%index
	var body: Node3D = world._structure_mesh(id,st.commit(),origin,"opera_glass",105000.0,basis)
	# Bronze mullions follow the splayed inclined curtain, rather than filling an unrelated triangle.
	var frames := SurfaceTool.new()
	frames.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,24):
		var top: Vector3 = curves[i]
		if top.y<1.0: continue
		var bottom := Vector3(top.x,0.25,top.z-4.0*(1.0-absf(top.x)/float(spec[2])))
		_beam_mesh(frames,bottom,top,0.16)
	for row in range(1,6):
		for i in range(24):
			var t := float(row)/6.0
			var a: Vector3 = curves[i]
			var b: Vector3 = curves[i+1]
			var ba := Vector3(a.x,0.25,a.z-4.0*(1.0-absf(a.x)/float(spec[2])))
			var bb := Vector3(b.x,0.25,b.z-4.0*(1.0-absf(b.x)/float(spec[2])))
			_beam_mesh(frames,ba.lerp(a,t),bb.lerp(b,t),0.10)
	var mullions := MeshInstance3D.new()
	mullions.mesh = frames.commit()
	mullions.material_override = world.materials["opera_bronze"]
	body.add_child(mullions)

static func _beam_mesh(st: SurfaceTool, a: Vector3, b: Vector3, width: float) -> void:
	if a.distance_to(b)<0.001: return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width,width,a.distance_to(b))
	var facing := Basis.looking_at((b-a).normalized(),Vector3.RIGHT if absf((b-a).normalized().y)>0.97 else Vector3.UP)
	st.append_from(mesh,0,Transform3D(facing,(a+b)*0.5))

static func _prism(poly: PackedVector2Array, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ix := Geometry2D.triangulate_polygon(poly)
	for i in range(0,ix.size(),3):
		for top in [false,true]:
			var y := height if top else 0.0
			_triangle(st,Vector3(poly[ix[i]].x,y,poly[ix[i]].y),Vector3(poly[ix[i+1]].x,y,poly[ix[i+1]].y),Vector3(poly[ix[i+2]].x,y,poly[ix[i+2]].y),Vector3.UP if top else Vector3.DOWN)
	for i in range(poly.size()):
		var a := Vector3(poly[i].x,0.0,poly[i].y)
		var b := Vector3(poly[(i+1)%poly.size()].x,0.0,poly[(i+1)%poly.size()].y)
		var normal := Vector3((a+b).x,0.0,(a+b).z).normalized()
		_triangle(st,a,b,a+Vector3.UP*height,normal)
		_triangle(st,a+Vector3.UP*height,b,b+Vector3.UP*height,normal)
	return st.commit()

static func _build_podium(world: Node3D, basis: Basis) -> void:
	var base := PackedVector2Array([Vector2(-60,-76),Vector2(-47,-89),Vector2(41,-89),Vector2(60,-71),Vector2(60,66),Vector2(49,72),Vector2(-52,72),Vector2(-60,57)])
	world._structure_mesh("opera/podium/0",_prism(base,3.0),CENTER,"opera_granite",2400000.0,basis)
	var upper := PackedVector2Array([Vector2(-56,-72),Vector2(-44,-83),Vector2(38,-83),Vector2(56,-67),Vector2(56,61),Vector2(48,66),Vector2(-51,66),Vector2(-56,55)])
	var podium: Node3D = world._structure_mesh("opera/podium/1",_prism(upper,PODIUM_HEIGHT-3.0),CENTER+Vector3.UP*3.0,"opera_granite",2200000.0,basis)
	# Long inset foyer windows and cantilevered sunshades articulate the harbour face.
	for level in range(2):
		for hall in [-27.0,24.0]:
			world._box(podium,Vector3(hall,1.8+level*2.1,-82.8),Vector3(35,1.05,0.15),"opera_recess")
			world._box(podium,Vector3(hall,2.45+level*2.1,-83.2),Vector3(37,0.35,1.2),"opera_edge")
	# 48 shallow treads, eight removable ramp segments. No tall box steps to snag walking.
	for segment in range(8):
		var z0 := 95.76-segment*3.72
		var z1 := z0-3.72
		var y0 := segment*1.4
		var y1 := (segment+1)*1.4
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a := Vector3(-48.5,y0,z0)
		var b := Vector3(48.5,y0,z0)
		var c := Vector3(-48.5,y1,z1)
		var d := Vector3(48.5,y1,z1)
		var normal := (b-a).cross(c-a).normalized()
		if normal.y<0: normal = -normal
		_triangle(st,a,b,c,normal)
		_triangle(st,c,b,d,normal)
		var body: Node3D = world._structure_mesh("opera/steps/%s"%segment,st.commit(),CENTER,"opera_granite",360000.0,basis)
		# Replace the sloping visual with actual horizontal treads; retain the unobstructed smooth collider.
		body.get_child(0).mesh = _steps_mesh(segment)
	# Southwest restaurant rests above the lower southern podium extension.
	world._structure_box("opera/podium/restaurant",CENTER+basis*Vector3(-41,PODIUM_HEIGHT*0.5,82),Vector3(26,PODIUM_HEIGHT,36),"opera_granite",1600000.0,basis)
	for side in [-1,1]:
		for z in range(-70,65,9):
			world._box(podium,Vector3(side*56.03,3.4,z),Vector3(0.08,7.7,0.09),"opera_edge")
		for z in range(-60,55,5):
			world._box(podium,Vector3(side*56.06,1.1,z),Vector3(0.1,1.55,4.4),"opera_glass")
			world._box(podium,Vector3(side*56.18,0.3,z+2.3),Vector3(0.28,2.6,0.24),"opera_bronze")
		world._box(podium,Vector3(side*56.5,2.05,-2.5),Vector3(1.5,0.25,119),"opera_edge")

static func _steps_mesh(segment: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in range(segment*6,segment*6+6):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(97.0,1.4/6.0,0.62)
		st.append_from(mesh,0,Transform3D(Basis.IDENTITY,Vector3(0,(step+0.5)*1.4/6.0,95.45-step*0.62)))
	return st.commit()

static func _build_promenade(world: Node3D, basis: Basis) -> void:
	for z in range(-70,100,14):
		for side in [-1,1]:
			var pos := CENTER+basis*Vector3(side*63.0,0.0,z)
			world._batch_box(pos+Vector3.UP*0.65,Vector3(0.2,1.3,0.2),"opera_bronze",basis)
			if z<86:
				world._batch_box(pos+basis*Vector3(0,1.25,7),Vector3(0.13,0.13,14),"opera_bronze",basis)
	for x in [-36.0,-16.0,16.0,36.0]:
		world._bench(CENTER+basis*Vector3(x,0,115),deg_to_rad(ANGLE))
	world._sign(Vector3(415,6.6,-151),"SYDNEY OPERA HOUSE  /  BENNELONG POINT",0.0,Color("3b4c4e"))
