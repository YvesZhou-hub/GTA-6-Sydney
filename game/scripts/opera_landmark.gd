extends RefCounted
## Photo-referenced, metre-scale original Opera House exterior. See docs/OPERA_REFERENCE.md.
## Both halves of every roof are cut from an equal-radius sphere and meet at a sharp ridge.
## Geometry and its closed collider are the same mesh; ribs live on their damage component.

# OSM relation/9596872 outer-ring centroid and minimum-area long-axis bearing.
# These align the authored reconstruction, not a claim that every shell is surveyed.
const CENTER := Vector3(427.2947742677, 4.5, -321.4544052467)
const ANGLE := -13.232864688
const PODIUM_HEIGHT := 11.2
const STAIR_HALF_WIDTH := 48.5
const STAIR_FOOT_Z := 95.76
const STAIR_HEAD_Z := 66.0
const STAIR_TREADS := 48
const STAIR_BAYS := 8
const STAIR_COURSES := 8
const STAIR_FINISH_THICKNESS := 0.04
const SPHERE_RADIUS := 75.2
const SHELL_THICKNESS := 0.32
const BANDS := 8
const BAND_STEPS := 3
const LONG_STEPS := 24
const Geo = preload("res://scripts/city_landmarks.gd")
const TILE_SHADER = preload("res://shaders/opera_tiles.gdshader")
static var _roof_fields:Array=[]

# x, z, half width, ridge length, north/front ridge height, yaw, group,
# rear ridge height, springing-point longitudinal fraction. Metres over upper podium.
# CMP sections distinguish rising north roof groups, the long dominant hall roof,
# and a reversed southern foyer hood. Rear ridges remain elevated; they are not
# repeated full-height petals falling to the podium at every seam.
const ROOFS := [
	[-26.0,-60.0,22.4,36.0,21.5,0.0,"concert",18.0,0.26],
	[-26.0,-27.5,25.5,63.0,33.0,0.0,"concert",31.0,-0.04],
	[-26.0,5.0,28.0,78.0,43.1,0.0,"concert",32.0,0.25],
	[-26.0,54.0,21.0,20.0,24.0,180.0,"concert",32.0,0.10],
	[23.0,-46.0,18.0,32.0,18.0,0.0,"joan_sutherland",14.5,0.26],
	[23.0,-24.0,21.0,64.0,27.0,0.0,"joan_sutherland",25.0,0.05],
	[23.0,7.0,23.0,68.0,36.5,0.0,"joan_sutherland",23.0,0.25],
	[23.0,49.0,18.4,16.0,20.0,180.0,"joan_sutherland",23.0,0.10],
	[-41.0,72.0,11.0,22.0,15.0,0.0,"bennelong",7.5,0.20],
	[-41.0,86.0,11.0,21.0,14.0,180.0,"bennelong",7.5,0.20]
]

static func site_basis() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(ANGLE))

static func build(world: Node3D) -> void:
	var basis := site_basis()
	_prepare_fields()
	var tile := ShaderMaterial.new()
	tile.shader = TILE_SHADER
	world.materials["opera_tiles"] = tile
	world._mat("opera_granite", Color("b5a18b"), 0.86)
	world._mat("opera_edge", Color("d4cbbb"), 0.72)
	world._mat("opera_bronze", Color("877457"), 0.43, 0.28)
	world._mat("opera_mullion", Color("875b43"), 0.39, 0.42)
	var glass: StandardMaterial3D = world._mat("opera_glass", Color(0.33,0.39,0.35,0.27), 0.23, 0.03)
	glass.metallic_specular = 0.35
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	world._mat("opera_recess", Color("6d6659"), 0.73)
	_build_podium(world, basis)
	for index in range(ROOFS.size()):
		var spec: Array = ROOFS[index]
		var origin := CENTER + basis * Vector3(spec[0], PODIUM_HEIGHT, spec[1])
		var roof_basis := basis * Basis(Vector3.UP, deg_to_rad(spec[5]))
		for side in [-1, 1]:
			var surface := surface_for(spec, side)
			for band in range(BANDS):
				var from := float(band) / BANDS
				var to := float(band + 1) / BANDS
				var id := "opera/shell/%s/%s" % [index, band + (BANDS if side > 0 else 0)]
				var body: StaticBody3D = world._structure_mesh(id, shell_mesh(surface, from, to,index), origin, "opera_tiles", 180000.0, roof_basis)
				body.set_meta("shell_group", spec[6])
				body.set_meta("sphere_radius", SPHERE_RADIUS)
				body.set_meta("surface_center", surface.center)
				_add_ribs(world, body, surface, from, to,index)
		if index in [0,3,4,7,8,9]:
			_build_foyer(world, index, spec, origin, roof_basis)
		else:
			_build_interstitial(world,index,spec,origin,roof_basis)
	_build_rear_joint(world,2,3)
	_build_rear_joint(world,6,7)
	_build_promenade(world, basis)
	world.set_meta("opera_shell_pairs", ROOFS.size())
	world.set_meta("opera_reference_revision", "cmp-stepped-ridges-open-foyers-v014")

static func surface_for(spec: Array, side: int) -> Dictionary:
	return sphere_patch(spec[2],spec[3],spec[4],side,spec[7],spec[8])

static func sphere_patch(width: float, depth: float, height: float, side: int, rear_height: float = 0.8, toe_fraction: float = -0.18) -> Dictionary:
	var a := Vector3(0.0, height, -depth * 0.5)
	var b := Vector3(0.0, rear_height, depth * 0.5)
	var c := Vector3(width * side, 0.0, depth * toe_fraction)
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

static func shell_mesh(surface: Dictionary, from: float, to: float, roof_index:int=-1) -> ArrayMesh:
	if roof_index>=0:return _trimmed_shell_mesh(surface,from,to,roof_index)
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

static func _add_ribs(world: Node3D, body: Node3D, surface: Dictionary, from: float, to: float,roof_index:int=-1) -> void:
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
			if roof_index>=0 and (not _exposed(roof_index,p0) or not _exposed(roof_index,p1)):continue
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

static func _foyer_base(top:Vector3,spec:Array,index:int) -> Vector3:
	if index in [0,4]:
		# The lower northern curtain projects out from the roof, with a near-vertical
		# public-height base and the pronounced outward-canted upper glazing of CMP.
		var lateral:=clampf(absf(top.x)/(float(spec[2])*.95),0.0,1.0)
		var z:=lerpf(-float(spec[3])*.5-3.0,float(spec[3])*float(spec[8]),pow(lateral,8.0))
		return Vector3(top.x*1.08,.02,z)
	return Vector3(top.x,.02,top.z-4.0*(1.0-absf(top.x)/float(spec[2])))

static func _foyer_point(top:Vector3,spec:Array,index:int,t:float) -> Vector3:
	var bottom:=_foyer_base(top,spec,index)
	if index in [0,4]:
		var knee:=Vector3(bottom.x,minf(4.0,top.y),bottom.z)
		return bottom.lerp(knee,t/.30) if t<=.30 else knee.lerp(top,(t-.30)/.70)
	return bottom.lerp(top,t)

static func _build_foyer(world: Node3D, index: int, spec: Array, origin: Vector3, basis: Basis) -> void:
	var surface:=surface_for(spec,1);var south_entry:=index in [3,7]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curves:Array[Vector3]=[]
	for i in range(49):
		var lateral:float=(i-24.0)/24.0
		var point:=shell_point(surface,absf(lateral),0.0)
		point.x=absf(point.x)*signf(lateral)*.95
		point.y=maxf(.15,point.y-.65)
		point.z+=2.5+4.0*(1.0-absf(lateral))
		curves.append(point)
	var frames:=SurfaceTool.new();frames.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels:Array=[0.0,.30,.44,.58,.72,.86,1.0] if index in [0,4] else [0.0,.17,.34,.51,.68,.85,1.0]
	for i in range(48):
		var top_a:Vector3=curves[i];var top_b:Vector3=curves[i+1]
		for row in range(levels.size()-1):
			var a:=_foyer_point(top_a,spec,index,levels[row]);var b:=_foyer_point(top_b,spec,index,levels[row])
			var c:=_foyer_point(top_a,spec,index,levels[row+1]);var d:=_foyer_point(top_b,spec,index,levels[row+1])
			if south_entry and minf(a.x,b.x)<6.2 and maxf(a.x,b.x)>-6.2:
				if maxf(c.y,d.y)<3.65:continue
				if a.y<3.65:a=a.lerp(c,clampf((3.65-a.y)/maxf(c.y-a.y,.001),0.0,1.0))
				if b.y<3.65:b=b.lerp(d,clampf((3.65-b.y)/maxf(d.y-b.y,.001),0.0,1.0))
			_triangle(st,a,b,c,Vector3.FORWARD);_triangle(st,c,b,d,Vector3.FORWARD)
			if not south_entry or minf(c.y,d.y)>=3.65 or minf(c.x,d.x)>6.3 or maxf(c.x,d.x)<-6.3:_beam_mesh(frames,c,d,.08)
	for i in range(1,48,2):
		var top:Vector3=curves[i]
		for j in range(levels.size()-1):
			var a:=_foyer_point(top,spec,index,levels[j]);var b:=_foyer_point(top,spec,index,levels[j+1])
			if south_entry and absf(top.x)<6.3:
				if b.y<3.65:continue
				if a.y<3.65:a=a.lerp(b,clampf((3.65-a.y)/maxf(b.y-a.y,.001),0.0,1.0))
			# The built Hall/Arup curtain has deep bronze-clad mullion blades,
			# not wire-thin square bars (official CMP 4.114 and 2025 foyer photos).
			# Keep the actual glass/collider and door cutouts unchanged.
			if index in [0,4] and minf(a.y,b.y)>=3.95:
				_blade_mesh(frames,a,b,.09,.72)
				var depth_axis:Vector3=(Vector3.BACK-(b-a).normalized()*Vector3.BACK.dot((b-a).normalized())).normalized()
				_beam_mesh(frames,a+depth_axis*.73,b+depth_axis*.73,.12)
			else:_beam_mesh(frames,a,b,.15)
	# Visible braced transom at the north curtain's change of angle. All new
	# details are above the public headroom and die with their glazing component.
	if index in [0,4]:
		for i in range(1,45,2):
			var a:=_foyer_point(curves[i],spec,index,.30)
			var b:=_foyer_point(curves[i+2],spec,index,.30)
			if minf(a.y,b.y)<3.9:continue
			var inward:=Vector3(0,.26,.68)
			_beam_mesh(frames,a+inward,b+inward,.11)
			_beam_mesh(frames,a,b+inward,.047)
			_beam_mesh(frames,a+inward,b,.047)
	var body:Node3D=world._structure_mesh("opera/glass/%s"%index,st.commit(),origin,"opera_glass",105000,basis)
	var mullions:=MeshInstance3D.new();mullions.name="BronzeCurtainBlades";mullions.mesh=frames.commit();mullions.material_override=world.materials.opera_mullion;body.add_child(mullions)
	body.set_meta("curtain_blade_depth",.72 if index in [0,4] else .15)

static func _prepare_fields() -> void:
	_roof_fields.clear()
	for spec:Array in ROOFS:
		var field:Dictionary={"basis":Basis(Vector3.UP,deg_to_rad(spec[5])),"origin":Vector3(spec[0],PODIUM_HEIGHT,spec[1]),"sides":[]}
		for side in [-1,1]:
			var surface:=surface_for(spec,side);var outline:=PackedVector2Array()
			for j in range(25):
				var q:=shell_point(surface,0.0,float(j)/24.0);outline.append(Vector2(q.x,q.z))
			for j in range(1,25):
				var q:=shell_point(surface,float(j)/24.0,1.0);outline.append(Vector2(q.x,q.z))
			for j in range(23,-1,-1):
				var q:=shell_point(surface,float(j)/24.0,0.0);outline.append(Vector2(q.x,q.z))
			field.sides.append({"surface":surface,"outline":outline})
		_roof_fields.append(field)

static func _field_height(index:int,site_point:Vector3) -> float:
	if _roof_fields.is_empty():_prepare_fields()
	var field:Dictionary=_roof_fields[index]
	var p:Vector3=field.basis.inverse()*(site_point-field.origin)
	var side:Dictionary=field.sides[1 if p.x>=0.0 else 0]
	if not Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),side.outline):return -INF
	var center:Vector3=side.surface.center
	var remaining:=SPHERE_RADIUS*SPHERE_RADIUS-pow(p.x-center.x,2)-pow(p.z-center.z,2)
	if remaining<0.0:return -INF
	return center.y+sqrt(remaining)+PODIUM_HEIGHT

static func _roof_height_at(spec:Array,site_point:Vector3) -> float:
	return _field_height(ROOFS.find(spec),site_point)

static func _exposed(index:int,p:Vector3) -> bool:
	var field:Dictionary=_roof_fields[index]
	var site:Vector3=field.origin+field.basis*p
	if site.y<_room_clearance(site)+SHELL_THICKNESS:return false
	for other in range(ROOFS.size()):
		if other==index or ROOFS[other][6]!=ROOFS[index][6]:continue
		if _field_height(other,site)>site.y+.035:return false
	return true

static func _trimmed_shell_mesh(surface:Dictionary,from:float,to:float,index:int) -> ArrayMesh:
	# Each adjacent shell contributes only the exposed part of the outer envelope.
	# Marching cell boundaries are capped with the same 320mm inner skin, removing
	# buried roof fragments that would otherwise cut through the occupied hall.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var boundaries:Dictionary={}
	for col in BAND_STEPS:
		for row in LONG_STEPS:
			var u0:=lerpf(from,to,float(col)/BAND_STEPS);var u1:=lerpf(from,to,float(col+1)/BAND_STEPS)
			var v0:=float(row)/LONG_STEPS;var v1:=float(row+1)/LONG_STEPS
			var square:Array[Vector2]=[Vector2(u0,v0),Vector2(u1,v0),Vector2(u1,v1),Vector2(u0,v1)]
			var poly:Array[Vector2]=[]
			for k in 4:
				var a:=square[k];var b:=square[(k+1)%4]
				var ai:=_exposed(index,shell_point(surface,a.x,a.y));var bi:=_exposed(index,shell_point(surface,b.x,b.y))
				if ai:poly.append(a)
				if ai!=bi:
					var low:=a;var high:=b
					for iteration in 15:
						var mid:Vector2=(low+high)*.5
						if _exposed(index,shell_point(surface,mid.x,mid.y))==ai:low=mid
						else:high=mid
					poly.append((low+high)*.5)
			if poly.size()<3:continue
			for layer in 2:
				var inner:=layer==1;var inset:=SHELL_THICKNESS if inner else 0.0
				var a:=shell_point(surface,poly[0].x,poly[0].y,inset)
				for k in range(1,poly.size()-1):
					var b:=shell_point(surface,poly[k].x,poly[k].y,inset);var c:=shell_point(surface,poly[k+1].x,poly[k+1].y,inset)
					var n:Vector3=((a+b+c)/3.0-surface.center).normalized()*(-1.0 if inner else 1.0)
					_triangle(st,a,b,c,n,surface,inner)
			for k in poly.size():
				var a:=poly[k];var b:=poly[(k+1)%poly.size()]
				var pa:=shell_point(surface,a.x,a.y);var pb:=shell_point(surface,b.x,b.y)
				var ak:=Vector3i((pa*10000).round());var bk:=Vector3i((pb*10000).round())
				if ak==bk:continue
				var key:=str(ak)+"/"+str(bk) if str(ak)<str(bk) else str(bk)+"/"+str(ak)
				if boundaries.has(key):boundaries.erase(key)
				else:boundaries[key]=[a,b]
	for edge:Array in boundaries.values():
		var a:=shell_point(surface,edge[0].x,edge[0].y);var b:=shell_point(surface,edge[1].x,edge[1].y)
		var c:=shell_point(surface,edge[0].x,edge[0].y,SHELL_THICKNESS);var d:=shell_point(surface,edge[1].x,edge[1].y,SHELL_THICKNESS)
		var n:Vector3=(b-a).cross(c-a).normalized()
		_triangle(st,a,b,c,n);_triangle(st,c,b,d,n)
	return st.commit()

static func _room_clearance(p:Vector3) -> float:
	# Acoustic chamber envelopes are shared with the independent interior module.
	# The small allowance covers the wooden roof thickness and avoids coplanar faces.
	if p.x>=-44.4 and p.x<=-7.6 and p.z>=-37.5 and p.z<=31.5:
		var progress:=smoothstep(-37.0,14.0,p.z)
		var crown:=lerpf(28.9,37.1,progress);var edge:=lerpf(24.0,28.0,progress)
		return crown-(crown-edge)*pow(clampf(absf(p.x+26)/18.0,0,1),3.2)+.75
	if p.x>=7.4 and p.x<=38.6 and p.z>=-39.5 and p.z<=34.5:return 24.65
	return 0.0

static func _build_interstitial(world:Node3D,index:int,spec:Array,origin:Vector3,basis:Basis) -> void:
	# CMP 4.7.3: bronze louvres deeply recessed between shell groups. The lower
	# edge follows the preceding roof instead of duplicating another glass arch.
	# Where the lower roof ends, enclosure starts above the public circulation band;
	# the independently authored hall walls/foyers enclose the occupied lower space.
	var panel:=SurfaceTool.new();panel.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blades:=SurfaceTool.new();blades.begin(Mesh.PRIMITIVE_TRIANGLES)
	var surface:=surface_for(spec,1)
	var previous:Array=ROOFS[index-1]
	var rows:Array=[]
	for j in range(193):
		var t:float=(j-96.0)/96.0
		var top:=shell_point(surface,absf(t),0.0,SHELL_THICKNESS+.16)
		top.x=absf(top.x)*signf(t)
		top.z+=1.15
		var local_basis:=Basis(Vector3.UP,deg_to_rad(spec[5]))
		var site:Vector3=Vector3(spec[0],PODIUM_HEIGHT,spec[1])+local_basis*top
		var lower:=maxf(4.0,_roof_height_at(previous,site)-PODIUM_HEIGHT-.12)
		lower=maxf(lower,_room_clearance(site)-PODIUM_HEIGHT+1.0)
		rows.append([top,Vector3(top.x,minf(lower,top.y),top.z)])
	for j in range(192):
		var a:Vector3=rows[j][0];var b:Vector3=rows[j+1][0]
		var lo_a:Vector3=rows[j][1];var lo_b:Vector3=rows[j+1][1]
		if maxf(a.y-lo_a.y,b.y-lo_b.y)<.01:continue
		_triangle(panel,lo_a,lo_b,a,Vector3.FORWARD)
		_triangle(panel,a,lo_b,b,Vector3.FORWARD)
		for y in range(4,ceili(maxf(a.y,b.y)*4.0)):
			var h:=float(y)*.25
			if h<maxf(lo_a.y,lo_b.y) or h>minf(a.y,b.y):continue
			# Folded louvre lips have a real angled face and shadowed underside,
			# replacing the former square rods painted onto a flat infill.
			var p:=Vector3(a.x,h+.05,a.z-.24);var q:=Vector3(b.x,h+.05,b.z-.24)
			var r:=Vector3(a.x,h-.06,a.z-.055);var s:=Vector3(b.x,h-.06,b.z-.055)
			var normal:=Vector3(0,.185,.11).normalized()
			_triangle(blades,p,q,r,normal);_triangle(blades,r,q,s,normal)
			_triangle(blades,p,r,q,-normal);_triangle(blades,r,s,q,-normal)
	var body:Node3D=world._structure_mesh("opera/infill/louvres/"+str(index),panel.commit(),origin,"opera_recess",140000,basis)
	var mesh:=MeshInstance3D.new();mesh.mesh=blades.commit();mesh.material_override=world.materials.opera_bronze;body.add_child(mesh)

static func _build_rear_joint(world:Node3D,main_index:int,foyer_index:int) -> void:
	# Opposing southern roofs meet at the same elevated ridge. A recessed curved
	# bronze infill joins their two trailing edges down to the separate springings.
	var main:Array=ROOFS[main_index];var foyer:Array=ROOFS[foyer_index]
	for side in [-1,1]:
		var left:=surface_for(main,side);var right:=surface_for(foyer,-side)
		var first:=Basis(Vector3.UP,deg_to_rad(main[5]));var second:=Basis(Vector3.UP,deg_to_rad(foyer[5]))
		var a_origin:=Vector3(main[0],PODIUM_HEIGHT,main[1]);var b_origin:=Vector3(foyer[0],PODIUM_HEIGHT,foyer[1])
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in range(32):
			var u0:=float(j)/32;var u1:=float(j+1)/32
			var a:=a_origin+first*shell_point(left,u0,1.0,SHELL_THICKNESS)
			var b:=a_origin+first*shell_point(left,u1,1.0,SHELL_THICKNESS)
			var c:=b_origin+second*shell_point(right,u0,1.0,SHELL_THICKNESS)
			var d:=b_origin+second*shell_point(right,u1,1.0,SHELL_THICKNESS)
			_triangle(st,a,b,c,Vector3(side,0,0));_triangle(st,c,b,d,Vector3(side,0,0))
		world._structure_mesh("opera/infill/rear/%d/%d"%[main_index,side],st.commit(),CENTER,"opera_bronze",140000,site_basis())

static func _beam_mesh(st: SurfaceTool, a: Vector3, b: Vector3, width: float) -> void:
	if a.distance_to(b)<0.001: return
	var facing := Basis.looking_at((b-a).normalized(),Vector3.RIGHT if absf((b-a).normalized().y)>0.97 else Vector3.UP)
	# CPU box: a BoxMesh per beam forced blocking Metal uploads and readbacks.
	Geo._append_box(st,(a+b)*0.5,Vector3(width,width,a.distance_to(b)),facing)

static func _blade_mesh(st:SurfaceTool,a:Vector3,b:Vector3,width:float,depth:float) -> void:
	var along:=(b-a).normalized()
	var inward:=(Vector3.BACK-along*Vector3.BACK.dot(along)).normalized()
	var across:=along.cross(inward).normalized()
	Geo._append_box(st,(a+b)*.5+inward*(depth*.5+.01),Vector3(width,a.distance_to(b),depth),Basis(across,along,inward))

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
	# Hollow podium, based on CMP ground/upper plans. Interior owns its intermediate
	# box-office slabs and stairs; these surfaces never occupy the rooms as a solid box.
	var base := PackedVector2Array([Vector2(-60,-76),Vector2(-47,-89),Vector2(41,-89),Vector2(60,-71),Vector2(60,66),Vector2(49,72),Vector2(-52,72),Vector2(-60,57)])
	world._structure_mesh("opera/podium/ground",Geo.prism(base,-.35,0.0),CENTER,"opera_granite",2400000.0,basis)
	# Split the upper floor into rectangular cells before clipping to the podium,
	# so holes are real absent triangles in both rendering and collision.
	var upper_base := PackedVector2Array([Vector2(-60,-76),Vector2(-47,-89),Vector2(41,-89),Vector2(60,-71),Vector2(60,66),Vector2(-52,66),Vector2(-60,57)])
	var xs := [-60.0,-10.5,-3.5,15.0,31.0,60.0]
	var zs := [-89.0,4.0,8.0,37.0,59.5,72.0]
	for ix in xs.size()-1:
		for iz in zs.size()-1:
			var mid := Vector2((xs[ix]+xs[ix+1])*.5,(zs[iz]+zs[iz+1])*.5)
			if (mid.x>-10.5 and mid.x< -3.5 and mid.y>37.0 and mid.y<59.5) or (mid.x>15 and mid.x<31 and mid.y>4 and mid.y<8):continue
			var cell := PackedVector2Array([Vector2(xs[ix],zs[iz]),Vector2(xs[ix+1],zs[iz]),Vector2(xs[ix+1],zs[iz+1]),Vector2(xs[ix],zs[iz+1])])
			for poly in Geometry2D.intersect_polygons(upper_base,cell):
				world._structure_mesh("opera/podium/upper/%d/%d"%[ix,iz],Geo.prism(poly,PODIUM_HEIGHT-.28,PODIUM_HEIGHT),CENTER,"opera_granite",500000.0,basis)
	# Four accessible Western Foyer doors. Higher granite fascia spans the doors.
	var west_breaks := [-76.0,-42.0,-36.0,-10.0,-4.0,25.0,33.0,49.0,57.0,66.0]
	for j in range(0,west_breaks.size()-1,2):
		var lo:float=west_breaks[j];var hi:float=west_breaks[j+1]
		world._structure_box("opera/podium/west/wall/%d"%j,CENTER+basis*Vector3(-59.78,1.65,(lo+hi)*.5),Vector3(.44,3.3,hi-lo),"opera_granite",180000,basis)
	world._structure_box("opera/podium/west/fascia",CENTER+basis*Vector3(-59.78,7.25,-5),Vector3(.44,7.9,142),"opera_granite",360000,basis)
	for z in [-39.0,-7.0,29.0,53.0]:
		world._batch_box(CENTER+basis*Vector3(-60.32,3.36,z),Vector3(1.0,.12,7.0),"opera_edge",basis)
	# Remaining podium perimeter, with the eastern Utzon/public opening preserved.
	for zrange in [[-71.0,42.0],[49.0,66.0]]:
		world._structure_box("opera/podium/east/wall/"+str(zrange[0]),CENTER+basis*Vector3(59.78,5.6,(zrange[0]+zrange[1])*.5),Vector3(.44,11.2,zrange[1]-zrange[0]),"opera_granite",300000,basis)
	world._structure_box("opera/podium/east/lintel",CENTER+basis*Vector3(59.78,9.95,45.5),Vector3(.44,2.5,7.0),"opera_granite",160000,basis)
	for j in [0,1,2,4,6]:
		var a:=Vector3(base[j].x,5.6,base[j].y);var b:=Vector3(base[(j+1)%base.size()].x,5.6,base[(j+1)%base.size()].y)
		world._structure_box("opera/podium/perimeter/"+str(j),CENTER+basis*((a+b)*.5),Vector3(.38,11.2,a.distance_to(b)),"opera_granite",250000,basis*Basis.looking_at(b-a,Vector3.UP))
	world._structure_box("opera/podium/south/stair_back",CENTER+basis*Vector3(0,5.4,65.8),Vector3(97,10.8,.3),"opera_granite",600000,basis)
	_build_monumental_stair(world,basis)
	# Bennelong is an independent hollow base; no solid volume beneath the shells.
	world._structure_box("opera/podium/restaurant_floor",CENTER+basis*Vector3(-41,11.06,82),Vector3(26,.28,36),"opera_granite",600000,basis)
	for x in [-54.0,-28.0]:world._structure_box("opera/podium/restaurant_side/"+str(x),CENTER+basis*Vector3(x,5.5,82),Vector3(.3,11.0,36),"opera_granite",240000,basis)
	world.set_meta("opera_exterior_openings",{"western":[[-42,-36],[-10,-4],[25,33],[49,57]],"upper_stair":Rect2(-10.5,37,7,22.5),"orchestra_pit":Rect2(15,4,16,4),"ground_y":0.0,"upper_y":11.2})

static func _build_monumental_stair(world:Node3D,basis:Basis) -> void:
	# Retire opera/steps/0..7: each old ID removed an entire 97m-wide thin strip.
	# apply_state preserves those retired damage IDs without deleting these new
	# load-bearing solids. No save payload is changed or discarded here.
	var run:=STAIR_FOOT_Z-STAIR_HEAD_Z
	var rise:=PODIUM_HEIGHT/STAIR_TREADS
	var tread:=run/STAIR_TREADS
	var core_profile:=PackedVector2Array([Vector2(STAIR_FOOT_Z,-.35)])
	for step in STAIR_TREADS:
		var y:float=(step+1)*rise-STAIR_FINISH_THICKNESS
		core_profile.append(Vector2(STAIR_FOOT_Z-step*tread,y))
		core_profile.append(Vector2(STAIR_FOOT_Z-(step+1)*tread,y))
	# The exposed core's last tread continues 80mm beneath the upper slab.
	# Its surface is 40mm below the finished landing, never coplanar with it.
	core_profile.append(Vector2(STAIR_HEAD_Z-.08,PODIUM_HEIGHT-STAIR_FINISH_THICKNESS))
	core_profile.append(Vector2(STAIR_HEAD_Z-.08,-.35))
	var core_collision:=PackedVector2Array([
		Vector2(STAIR_FOOT_Z,-.35),Vector2(STAIR_FOOT_Z,-STAIR_FINISH_THICKNESS),
		Vector2(STAIR_HEAD_Z,PODIUM_HEIGHT-STAIR_FINISH_THICKNESS),
		Vector2(STAIR_HEAD_Z-.08,PODIUM_HEIGHT-STAIR_FINISH_THICKNESS),
		Vector2(STAIR_HEAD_Z-.08,-.35)])
	for bay in STAIR_BAYS:
		var x0:=lerpf(-STAIR_HALF_WIDTH,STAIR_HALF_WIDTH,float(bay)/STAIR_BAYS)
		var x1:=lerpf(-STAIR_HALF_WIDTH,STAIR_HALF_WIDTH,float(bay+1)/STAIR_BAYS)
		# Closed granite stair foundations remain visible when the finish breaks.
		# Smooth support approximates each real tread by at most one 233mm riser,
		# as on the original walking ramps; it is not a detached collision bridge.
		var core:Node3D=world._structure_mesh("opera/steps/foundation/%d"%bay,_stair_profile_mesh(core_collision,x0,x1),CENTER,"opera_granite",24000000.0,basis)
		core.get_child(0).mesh=_stair_profile_mesh(core_profile,x0,x1)
		core.set_meta("load_bearing_stair",true)
		for course in STAIR_COURSES:
			var z0:=STAIR_FOOT_Z-float(course)*run/STAIR_COURSES
			var z1:=STAIR_FOOT_Z-float(course+1)*run/STAIR_COURSES
			var y0:=float(course)*PODIUM_HEIGHT/STAIR_COURSES
			var y1:=float(course+1)*PODIUM_HEIGHT/STAIR_COURSES
			var finish_collision:=PackedVector2Array([
				Vector2(z0,y0-STAIR_FINISH_THICKNESS),Vector2(z0,y0),
				Vector2(z1,y1),Vector2(z1,y1-STAIR_FINISH_THICKNESS)])
			var finish:Node3D=world._structure_mesh("opera/steps/tread/%d/%d"%[bay,course],_stair_profile_mesh(finish_collision,x0,x1),CENTER,"opera_granite",360000.0,basis)
			finish.get_child(0).mesh=_steps_mesh(course,x0,x1)

static func _stair_profile_mesh(profile:PackedVector2Array,x0:float,x1:float) -> ArrayMesh:
	# Extrude the (z,y) stair section across x, including both end caps and base.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices:=Geometry2D.triangulate_polygon(profile)
	for x in [x0,x1]:
		for i in range(0,indices.size(),3):
			var a:Vector2=profile[indices[i]];var b:Vector2=profile[indices[i+1]];var c:Vector2=profile[indices[i+2]]
			_triangle(st,Vector3(x,a.y,a.x),Vector3(x,b.y,b.x),Vector3(x,c.y,c.x),Vector3.LEFT if x==x0 else Vector3.RIGHT)
	var area:=0.0
	for i in profile.size():area+=profile[i].cross(profile[(i+1)%profile.size()])
	for i in profile.size():
		var a:Vector2=profile[i];var b:Vector2=profile[(i+1)%profile.size()]
		var normal:=Vector3(0,a.x-b.x,b.y-a.y).normalized()*signf(area)
		var p:=Vector3(x0,a.y,a.x);var q:=Vector3(x0,b.y,b.x)
		var r:=Vector3(x1,b.y,b.x);var s:=Vector3(x1,a.y,a.x)
		_triangle(st,p,q,r,normal);_triangle(st,p,r,s,normal)
	return st.commit()

static func _steps_mesh(segment: int,x0:float=-STAIR_HALF_WIDTH,x1:float=STAIR_HALF_WIDTH) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rise:=PODIUM_HEIGHT/STAIR_TREADS
	var tread:=(STAIR_FOOT_Z-STAIR_HEAD_Z)/STAIR_TREADS
	var per_course:=STAIR_TREADS/STAIR_COURSES
	for step in range(segment*per_course,(segment+1)*per_course):
		Geo._append_box(st,Vector3((x0+x1)*.5,(step+1)*rise-STAIR_FINISH_THICKNESS*.5,STAIR_FOOT_Z-(step+.5)*tread),Vector3(x1-x0,STAIR_FINISH_THICKNESS,tread),Basis.IDENTITY)
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

static func capture_views() -> Array:
	var views := [
		["opera-harbour",Vector3(-155,60,-148),Vector3(-4,28,-3)],
		["opera-monumental-steps",Vector3(4,17,156),Vector3(0,26,12)],
		["opera-roof-plan",Vector3(-105,210,118),Vector3(-1,22,-2)],
		["opera-north-facade",Vector3(8,29,-155),Vector3(-2,25,-48)],
		["opera-north-curtain-detail",Vector3(-64,28,-95),Vector3(-30,24,-72)],
		["opera-louvre-detail",Vector3(-72,38,-36),Vector3(-34,34,-28)]
	]
	var out:Array=[]
	for v in views:out.append([v[0],CENTER+site_basis()*v[1],CENTER+site_basis()*v[2]])
	return out
