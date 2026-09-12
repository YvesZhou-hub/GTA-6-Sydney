extends RefCounted
## Photo-referenced public Grand Walk; see docs/QVB_REFERENCE.md.
const G = preload("res://scripts/city_landmarks.gd")
const CENTER := Vector3(-352.277,4.5,1309.448)
const ANGLE := 0.0431
# Nominal above-ground levels: official 58 m cupola / 19 m outer diameter,
# with intermediate ratios from the City's 1892 longitudinal section (~±1 m).
# These are separate architectural levels, never a uniform building stretch.
const HEIGHT := {"first_floor":5.7,"second_floor":10.9,"eaves":15.8,"glass_lower":17.0,"glass_upper":21.4,"ridge":23.0,"spacer_low":21.5,"inner_spring":26.5,"inner_crown":32.4,"drum_low":26.5,"copper_low":35.4,"lantern_low":47.9,"lantern_cap":53.1,"lantern_crown":57.0,"spire":58.0,"end_eaves":23.9,"minor_end_tip":31.0,"minor_middle_tip":28.0}
const OUTER_RADIUS := 9.5
const INNER_RADIUS := 5.65
const PARTS := [{"id":"way/40717424","center":[-352.277,1309.448],"outline":[[-10.19,94.954],[3.171,94.297],[18.722,93.819],[17.992,75.25],[14.823,2.948],[11.635,-76.579],[10.979,-93.377],[-3.953,-93.01],[-19.088,-92.197],[-18.423,-75.232],[-14.8,2.336],[-10.92,76.419]],"height":14.6},{"id":"way/568422314","center":[-348.407,1393.207],"outline":[[-14.06,11.195],[14.852,10.06],[14.122,-8.509],[8.828,-8.297],[8.661,-12.327],[-9.329,-11.626],[-9.172,-7.562],[-14.79,-7.34]],"height":15.75},{"id":"way/568422315","center":[-355.965,1225.863],"outline":[[-15.4,-8.612],[14.667,-9.792],[15.323,7.006],[7.848,7.295],[7.968,10.346],[-6.252,10.902],[-6.372,8.03],[-14.735,8.353]],"height":15.75},{"id":"way/568422316","center":[-366.971,1220.785],"outline":[[-0.328,-3.3],[-1.409,-3.0],[-2.287,-2.399],[-2.925,-1.542],[-3.267,-0.529],[-3.267,0.529],[-2.925,1.542],[-2.287,2.399],[-1.4,3.0],[-0.374,3.29],[0.688,3.245],[1.677,2.856],[2.536,2.132],[3.1,1.175],[3.312,0.073],[3.146,-1.029],[2.629,-2.02],[1.806,-2.777],[0.781,-3.223]],"height":18.9},{"id":"way/568422317","center":[-366.51,1230.209],"outline":[[-0.734,-3.374],[0.421,-3.429],[1.493,-3.118],[2.417,-2.472],[3.073,-1.57],[3.415,-0.501],[3.396,0.623],[3.018,1.68],[2.325,2.56],[1.382,3.172],[0.301,3.439],[-0.845,3.35],[-1.907,2.883],[-2.748,2.103],[-3.284,1.079],[-3.45,-0.056],[-3.247,-1.192],[-2.674,-2.194],[-1.806,-2.951]],"height":18.9},{"id":"way/568422318","center":[-344.812,1229.435],"outline":[[2.488,-2.11],[1.685,-2.8],[0.668,-3.201],[-0.422,-3.245],[-1.457,-2.922],[-2.335,-2.277],[-2.954,-1.386],[-3.25,-0.34],[-3.176,0.751],[-2.76,1.753],[-2.03,2.555],[-1.097,3.078],[-0.053,3.267],[1.001,3.111],[1.943,2.621],[2.683,1.853],[3.135,0.896],[3.265,-0.162],[3.034,-1.197]],"height":18.9},{"id":"way/568422319","center":[-345.423,1220.096],"outline":[[0.697,-3.313],[-0.421,-3.357],[-1.484,-3.046],[-2.38,-2.4],[-3.027,-1.509],[-3.35,-0.452],[-3.322,0.65],[-2.934,1.686],[-2.232,2.543],[-1.29,3.133],[-0.218,3.378],[0.9,3.266],[1.917,2.788],[2.721,2.008],[3.229,1.006],[3.386,-0.107],[3.164,-1.209],[2.591,-2.177],[1.741,-2.901]],"height":18.9},{"id":"way/568422320","center":[-358.716,1400.373],"outline":[[-0.221,-3.285],[-1.302,-3.029],[-2.198,-2.461],[-2.864,-1.626],[-3.233,-0.635],[-3.261,0.422],[-2.965,1.446],[-2.346,2.304],[-1.496,2.938],[-0.489,3.261],[0.574,3.25],[1.581,2.894],[2.449,2.203],[3.041,1.268],[3.29,0.188],[3.17,-0.925],[2.68,-1.915],[1.895,-2.706],[0.888,-3.173]],"height":18.9},{"id":"way/568422321","center":[-359.19,1389.549],"outline":[[0.262,-3.27],[-0.856,-3.159],[-1.798,-2.736],[-2.565,-2.034],[-3.064,-1.133],[-3.267,-0.12],[-3.138,0.905],[-2.704,1.84],[-1.992,2.597],[-1.087,3.086],[-0.061,3.276],[0.955,3.131],[1.962,2.619],[2.739,1.795],[3.182,0.771],[3.256,-0.353],[2.942,-1.444],[2.286,-2.346],[1.353,-2.98]],"height":18.9},{"id":"way/568422322","center":[-338.112,1388.793],"outline":[[0.177,-3.471],[-0.968,-3.349],[-2.003,-2.848],[-2.816,-2.046],[-3.334,-1.011],[-3.482,0.124],[-3.251,1.249],[-2.668,2.239],[-1.791,2.985],[-0.728,3.408],[0.427,3.453],[1.416,3.175],[2.284,2.629],[2.949,1.839],[3.356,0.904],[3.476,-0.121],[3.282,-1.134],[2.811,-2.046],[2.09,-2.781],[1.185,-3.271]],"height":18.9},{"id":"way/568422323","center":[-337.468,1399.689],"outline":[[0.605,-3.269],[-0.365,-3.302],[-1.298,-3.057],[-2.12,-2.556],[-2.767,-1.844],[-3.174,-0.975],[-3.322,-0.018],[-3.192,0.928],[-2.786,1.808],[-2.148,2.531],[-1.335,3.043],[-0.356,3.31],[0.661,3.255],[1.612,2.91],[2.416,2.286],[2.989,1.451],[3.294,0.483],[3.285,-0.541],[2.962,-1.499],[2.37,-2.334],[1.557,-2.935]],"height":18.9},{"id":"way/568422324","center":[-360.436,1359.085],"outline":[[1.739,-2.595],[0.806,-3.018],[-0.201,-3.118],[-1.218,-2.873],[-2.095,-2.317],[-2.742,-1.504],[-3.084,-0.513],[-3.084,0.522],[-2.733,1.513],[-2.086,2.325],[-1.208,2.882],[-0.201,3.116],[0.815,3.015],[1.739,2.592],[2.478,1.902],[2.959,1.0],[3.125,-0.001],[2.959,-1.003],[2.478,-1.905]],"height":15.75},{"id":"way/568422325","center":[-360.88,1349.265],"outline":[[0.659,-3.05],[-0.367,-3.095],[-1.356,-2.805],[-2.197,-2.215],[-2.788,-1.391],[-3.093,-0.412],[-3.056,0.612],[-2.696,1.57],[-2.039,2.36],[-1.162,2.895],[-0.164,3.117],[0.853,2.995],[1.777,2.561],[2.516,1.837],[2.978,0.924],[3.116,-0.1],[2.913,-1.113],[2.396,-2.004],[1.61,-2.671]],"height":15.75},{"id":"way/568422327","center":[-339.771,1348.896],"outline":[[-0.326,-3.126],[-1.324,-2.859],[-2.183,-2.269],[-2.802,-1.434],[-3.116,-0.432],[-3.088,0.603],[-2.719,1.583],[-2.054,2.384],[-1.167,2.93],[-0.141,3.141],[0.894,3.019],[1.818,2.573],[2.548,1.85],[3.01,0.926],[3.139,-0.098],[2.945,-1.111],[2.428,-2.002],[1.652,-2.681],[0.7,-3.071]],"height":15.75},{"id":"way/568422329","center":[-339.415,1359.006],"outline":[[3.227,0.612],[3.245,-0.512],[2.885,-1.57],[2.247,-2.394],[1.388,-2.973],[0.39,-3.262],[-0.654,-3.217],[-1.624,-2.85],[-2.437,-2.193],[-3.001,-1.325],[-3.269,-0.323],[-3.204,0.723],[-2.779,1.747],[-2.031,2.582],[-1.051,3.117],[0.058,3.284],[1.157,3.072],[2.118,2.516],[2.839,1.658]],"height":15.75},{"id":"way/568422332","center":[-365.765,1260.928],"outline":[[1.229,-2.778],[0.305,-3.023],[-0.656,-2.967],[-1.617,-2.567],[-2.394,-1.865],[-2.893,-0.941],[-3.04,0.094],[-2.828,1.118],[-2.283,2.009],[-1.46,2.665],[-0.472,2.999],[0.572,2.988],[1.469,2.654],[2.226,2.064],[2.753,1.274],[3.012,0.35],[2.975,-0.607],[2.633,-1.509],[2.032,-2.255]],"height":15.75},{"id":"way/568422333","center":[-365.181,1270.784],"outline":[[-0.085,-3.094],[-1.065,-2.905],[-1.97,-2.393],[-2.645,-1.602],[-3.033,-0.634],[-3.07,0.401],[-2.765,1.392],[-2.146,2.227],[-1.287,2.817],[-0.289,3.084],[0.746,3.006],[1.67,2.605],[2.409,1.938],[2.908,1.069],[3.093,0.079],[2.955,-0.912],[2.511,-1.803],[1.8,-2.515],[0.903,-2.961]],"height":15.75},{"id":"way/568422336","center":[-342.793,1270.496],"outline":[[2.696,-1.637],[1.994,-2.45],[1.116,-2.951],[0.137,-3.151],[-0.861,-3.029],[-1.776,-2.606],[-2.506,-1.916],[-2.977,-1.025],[-3.153,-0.034],[-3.005,0.957],[-2.552,1.858],[-1.785,2.604],[-0.815,3.049],[0.248,3.15],[1.283,2.882],[2.17,2.292],[2.807,1.435],[3.131,0.422],[3.084,-0.646]],"height":15.75},{"id":"way/568422339","center":[-343.167,1260.452],"outline":[[2.728,-1.668],[2.017,-2.469],[1.13,-2.992],[0.114,-3.193],[-0.912,-3.059],[-1.836,-2.614],[-2.575,-1.89],[-3.047,-0.966],[-3.194,0.058],[-3.01,1.071],[-2.511,1.972],[-1.716,2.696],[-0.737,3.108],[0.335,3.175],[1.361,2.896],[2.239,2.284],[2.867,1.416],[3.172,0.392],[3.126,-0.677]],"height":15.75},{"id":"way/568422341","center":[-341.552,1299.734],"outline":[[2.823,-1.876],[2.037,-2.711],[1.076,-3.223],[-0.005,-3.39],[-1.086,-3.212],[-2.047,-2.7],[-2.804,-1.91],[-3.266,-0.919],[-3.386,0.172],[-3.155,1.241],[-2.601,2.176],[-1.779,2.888],[-0.716,3.322],[0.43,3.367],[1.52,3.033],[2.444,2.354],[3.091,1.408],[3.377,0.305],[3.294,-0.83]],"height":18.9},{"id":"way/568422343","center":[-340.952,1319.44],"outline":[[3.35,0.815],[3.433,-0.287],[3.175,-1.356],[2.583,-2.291],[1.659,-3.025],[0.541,-3.404],[-0.642,-3.393],[-1.75,-2.981],[-2.647,-2.213],[-3.238,-1.189],[-3.451,-0.02],[-3.256,1.149],[-2.73,2.118],[-1.917,2.863],[-0.919,3.32],[0.172,3.442],[1.253,3.209],[2.195,2.652],[2.925,1.828]],"height":18.9},{"id":"way/568422345","center":[-362.831,1319.803],"outline":[[3.293,-0.583],[2.915,-1.641],[2.203,-2.52],[1.288,-3.088],[0.244,-3.333],[-0.828,-3.244],[-1.807,-2.809],[-2.611,-2.097],[-3.138,-1.162],[-3.341,-0.104],[-3.202,0.953],[-2.74,1.922],[-1.946,2.723],[-0.929,3.213],[0.189,3.347],[1.288,3.09],[2.24,2.489],[2.933,1.61],[3.303,0.541]],"height":18.9},{"id":"way/568422347","center":[-363.764,1301.098],"outline":[[0.891,-3.252],[-0.209,-3.363],[-1.281,-3.118],[-2.232,-2.528],[-2.935,-1.66],[-3.313,-0.602],[-3.332,0.511],[-2.981,1.58],[-2.297,2.47],[-1.364,3.083],[-0.274,3.361],[0.835,3.261],[1.842,2.827],[2.656,2.081],[3.182,1.112],[3.367,0.021],[3.201,-1.059],[2.683,-2.038],[1.889,-2.795]],"height":18.9},{"id":"way/568422349","center":[-352.176,1309.888],"outline":[[-8.683,-6.676],[-9.773,-4.928],[-10.531,-3.013],[-10.91,-0.999],[-10.901,1.061],[-10.512,3.087],[-9.755,4.99],[-8.646,6.727],[-7.242,8.23],[-5.569,9.432],[-3.712,10.312],[-1.716,10.824],[0.335,10.957],[2.377,10.701],[4.327,10.067],[6.138,9.076],[7.718,7.773],[9.039,6.182],[10.028,4.389],[10.582,2.809],[10.887,1.172],[10.934,-0.498],[10.73,-2.156],[10.278,-3.759],[9.585,-5.284],[8.679,-6.676],[7.561,-7.912],[6.267,-8.969],[4.835,-9.826],[3.283,-10.439],[1.657,-10.817],[-0.007,-10.951],[-1.67,-10.817],[-3.296,-10.439],[-4.839,-9.826],[-6.281,-8.969],[-7.565,-7.912]],"height":28.35},{"id":"way/568422351","center":[-352.331,1310.06],"outline":[[-0.092,-2.484],[-0.923,-2.306],[-1.644,-1.861],[-2.171,-1.204],[-2.448,-0.402],[-2.439,0.444],[-2.152,1.245],[-1.607,1.891],[-0.877,2.325],[-0.046,2.481],[0.731,2.369],[1.442,2.013],[2.006,1.468],[2.357,0.755],[2.477,-0.024],[2.348,-0.803],[1.978,-1.493],[1.405,-2.039],[0.694,-2.384]],"height":34.65}]

static func point(p:Vector3) -> Vector3:
	return CENTER+Basis(Vector3.UP,ANGLE)*p

static func excluded_way_ids() -> Array[int]:
	var result:Array[int]=[]
	for part in PARTS:result.append(int(part.id.get_slice("/",1)))
	return result

static func legacy_damage_ids() -> Array[String]:
	var result:Array[String]=[]
	for part in PARTS:
		for level in maxi(1,mini(8,ceili(part.height/18.0))):result.append("osm/%s/storey_group/%s"%[part.id,level])
	return result

static func footprints() -> Array[PackedVector2Array]:
	var poly:=G.polygon(PARTS[0].outline)
	for i in poly.size():poly[i]+=Vector2(CENTER.x,CENTER.z)
	return [poly]

static func metadata() -> Array[Dictionary]:
	return [{"id":"qvb_public","name":"Queen Victoria Building · Ground Floor Grand Walk","address":"455 George Street, Sydney NSW 2000","center":CENTER,"map_position":CENTER,"position":point(Vector3(0,.04,-98)),"arrival":point(Vector3(0,.04,-98)),"height_m":HEIGHT.spire,"height_confidence":"official nominal cupola58m; intermediate levels from1892 City archival section ±1m, not modern survey","height_levels":HEIGHT,"height_source":"https://news.cityofsydney.nsw.gov.au/articles/celebrating-120-years-of-the-queen-victoria-building","height_intermediate_source":"https://images.ctfassets.net/kcmyw5u53voi/5K8mkfjyEgaoeoKKWUU8wE/53754d59ae1f8ed1138aefac81082c51/QVB_2.jpg","osm_ids":excluded_way_ids(),"source":"https://www.qvb.com.au/about","facade_confidence":"Urbis 2018 photos in 2019 CMP; geometry dimensions estimated inside OSM footprint","public_scope":"ground-floor north/south arcade and central George/York crossings; no private tenancies or basement reconstruction"}]

static func capture_views() -> Array:
	return [["qvb-george-dome",point(Vector3(83,47,58)),point(Vector3(0,28,0))],["qvb-market-entry",point(Vector3(4.5,3,-111)),point(Vector3(0,6,-87))],["qvb-grand-walk",point(Vector3(3.6,2.2,-57)),point(Vector3(3,11,-9))],["qvb-central-dome",point(Vector3(0,2.4,-4)),point(Vector3(0,29,0))]]

static func walk_routes() -> Array:
	return [{"name":"qvb_market_druitt_grand_walk","points":[point(Vector3(0,.04,-98)),point(Vector3(0,.04,-84)),point(Vector3(3.6,.04,-72)),point(Vector3(3.6,.04,-35)),point(Vector3(0,.04,0)),point(Vector3(3.6,.04,35)),point(Vector3(3.6,.04,72)),point(Vector3(0,.04,84)),point(Vector3(0,.04,98))]},{"name":"qvb_george_york_public_crossing","points":[point(Vector3(19,.04,0)),point(Vector3(10,.04,0)),point(Vector3(0,.04,0)),point(Vector3(-10,.04,0)),point(Vector3(-19,.04,0))]}]

static func _surface() -> SurfaceTool:
	var s:=SurfaceTool.new();s.begin(Mesh.PRIMITIVE_TRIANGLES);return s

static func _append_mesh(s:SurfaceTool,mesh:Mesh,surface_index:int,pose:Transform3D) -> void:
	# SurfaceTool cannot mix indexed primitives and unindexed procedural faces:
	# an existing index buffer would silently omit later unindexed vertices.
	# Emit one uniform triangle stream, including every primitive face.
	var arrays:=mesh.surface_get_arrays(surface_index)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
	var count:=indices.size() if not indices.is_empty() else vertices.size()
	for i in count:
		var at:int=indices[i] if not indices.is_empty() else i
		s.set_normal((pose.basis*normals[at]).normalized())
		s.set_uv(uv[at] if at<uv.size() else Vector2(vertices[at].x,vertices[at].z))
		s.add_vertex(pose*vertices[at])

static func _box(s:SurfaceTool,p:Vector3,size:Vector3,basis:=Basis.IDENTITY) -> void:
	var m:=BoxMesh.new();m.size=size;_append_mesh(s,m,0,Transform3D(basis,p))

static func _beam(s:SurfaceTool,a:Vector3,b:Vector3,w:float,d:float) -> void:
	var delta:=b-a
	if delta.length()<.001:return
	var up:=Vector3.UP if absf(delta.normalized().y)<.95 else Vector3.RIGHT
	_box(s,(a+b)*.5,Vector3(w,d,delta.length()),Basis.looking_at(delta.normalized(),up))

static func _cylinder(s:SurfaceTool,p:Vector3,r:float,h:float,top:float=-1.0) -> void:
	var m:=CylinderMesh.new();m.bottom_radius=r;m.top_radius=r if top<0 else top;m.height=h;m.radial_segments=16;m.rings=1
	_append_mesh(s,m,0,Transform3D(Basis.IDENTITY,p))

static func _commit(world:Node3D,owner:StaticBody3D,s:SurfaceTool,key:String) -> void:
	G._commit_detail(world,owner,s,key)

static func _arch(s:SurfaceTool,p:Vector3,r:float,thick:float,depth:float,basis:=Basis.IDENTITY) -> void:
	# Explicit annular faces avoid reliance on a triangulated concave outline.
	for i in 18:
		var a:=PI*i/18.0;var b:=PI*(i+1)/18.0
		var ia:=Vector3(cos(a)*r,sin(a)*r,0);var ib:=Vector3(cos(b)*r,sin(b)*r,0)
		var oa:=Vector3(cos(a)*(r+thick),sin(a)*(r+thick),0);var ob:=Vector3(cos(b)*(r+thick),sin(b)*(r+thick),0)
		for sign_z in [-1.0,1.0]:
			var dz:=Vector3(0,0,sign_z*depth*.5)
			_quad(s,p+basis*(ia+dz),p+basis*(ib+dz),p+basis*(ob+dz),p+basis*(oa+dz),basis*Vector3(0,0,sign_z))
		var dz:=Vector3(0,0,depth*.5)
		_quad(s,p+basis*(oa-dz),p+basis*(ob-dz),p+basis*(ob+dz),p+basis*(oa+dz),basis*(oa+ob).normalized())
		_quad(s,p+basis*(ia+dz),p+basis*(ib+dz),p+basis*(ib-dz),p+basis*(ia-dz),-(basis*(ia+ib).normalized()))
		if i==0:_quad(s,p+basis*(ia-dz),p+basis*(oa-dz),p+basis*(oa+dz),p+basis*(ia+dz),basis*Vector3.DOWN)
		if i==17:_quad(s,p+basis*(ib+dz),p+basis*(ob+dz),p+basis*(ob-dz),p+basis*(ib-dz),basis*Vector3.DOWN)

static func _arch_window(s:SurfaceTool,p:Vector3,r:float,stem:float,depth:float,basis:=Basis.IDENTITY) -> void:
	var profile:=PackedVector2Array([Vector2(-r,-stem),Vector2(r,-stem)])
	for i in 19:profile.append(Vector2(cos(PI*i/18.0),sin(PI*i/18.0))*r)
	_append_mesh(s,G.profile_solid(profile,depth*.5),0,Transform3D(basis,p))

static func _spandrel(s:SurfaceTool,p:Vector3,r:float,half_width:float,high:float,depth:float,basis:=Basis.IDENTITY) -> void:
	var profile:=PackedVector2Array([Vector2(-half_width,0),Vector2(-half_width,high),Vector2(half_width,high),Vector2(half_width,0),Vector2(r,0)])
	for i in range(1,19):profile.append(Vector2(cos(PI*i/18.0),sin(PI*i/18.0))*r)
	_append_mesh(s,G.profile_solid(profile,depth*.5),0,Transform3D(basis,p))

static func _edge_x(z:float,side:float) -> float:
	var points:=_local_outline(PARTS[0]);var xs:Array[float]=[]
	for i in points.size():
		var a:=points[i];var b:=points[(i+1)%points.size()]
		if (a.y<=z and b.y>z) or (b.y<=z and a.y>z):xs.append(lerpf(a.x,b.x,(z-a.y)/(b.y-a.y)))
	return xs.max() if side>0 else xs.min()

static func _quad(s:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3,n:Vector3) -> void:
	G._triangle(s,a,b,c,n,Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z))
	G._triangle(s,a,c,d,n,Vector2(a.x,a.z),Vector2(c.x,c.z),Vector2(d.x,d.z))

static func _local_outline(part:Dictionary) -> PackedVector2Array:
	var poly:=PackedVector2Array()
	for v in part.outline:
		var p:=Basis(Vector3.UP,ANGLE).inverse()*(Vector3(part.center[0]+v[0],4.5,part.center[1]+v[1])-CENTER)
		poly.append(Vector2(p.x,p.z))
	return poly

static func _clipped_block(s:SurfaceTool,poly:PackedVector2Array,x0:float,x1:float,z0:float,z1:float,low:float,high:float) -> void:
	var rect:=PackedVector2Array([Vector2(x0,z0),Vector2(x1,z0),Vector2(x1,z1),Vector2(x0,z1)])
	for piece in Geometry2D.intersect_polygons(poly,rect):
		if piece.size()>2:_append_mesh(s,G.prism(piece,low,high),0,Transform3D.IDENTITY)

static func _body(world:Node3D,id:String,s:SurfaceTool,key:String) -> StaticBody3D:
	var body:StaticBody3D=world._structure_mesh(id,s.commit(),CENTER,key,320000.0,Basis(Vector3.UP,ANGLE))
	body.set_meta("qvb_public",true)
	return body

static func build(world:Node3D) -> void:
	_materials(world)
	var main_poly:=_local_outline(PARTS[0])
	# Legacy OSM components are kept, but their solids become actual shells and
	# roof parts. They no longer extrude the central dome down through shoppers.
	for part in PARTS:
		var id:String=part.id
		var poly:=_local_outline(part)
		var count:=maxi(1,mini(8,ceili(part.height/18.0)))
		for level in count:
			var s:=_surface()
			var key:="qvb_stone"
			if id=="way/40717424" or id in ["way/568422314","way/568422315"]:
				# Four shop wings leave a longitudinal arcade and central cross-entry.
				for side in [-1,1]:
					for half in [-1,1]:
						_clipped_block(s,poly,6.3 if side>0 else -25.0,25.0 if side>0 else -6.3,4.4 if half>0 else -110.0,110.0 if half>0 else -4.4,0.0,HEIGHT.eaves if id=="way/40717424" else HEIGHT.end_eaves)
				if id!="way/40717424":
					var z:float=(Basis(Vector3.UP,ANGLE).inverse()*(Vector3(part.center[0],4.5,part.center[1])-CENTER)).z
					# The physical end ceiling is above the entrance arch crown.
					# A thin lobby ceiling and separate roof replace the previous
					# deep solid plug behind the entry arch.
					_box(s,Vector3(0,7.48,z),Vector3(12.6,.36,14.5))
					_box(s,Vector3(0,HEIGHT.end_eaves-.12,z),Vector3(12.6,.24,14.5))
					var end_z:float=-93.0 if id=="way/568422315" else 94.3
					_spandrel(s,Vector3(0,3.3,end_z),3.65,6.3,4.0,.65)
					for side in [-1.0,1.0]:_box(s,Vector3(side*4.98,1.65,end_z),Vector3(2.66,3.3,.65))
					_box(s,Vector3(0,(7.3+HEIGHT.end_eaves)*.5,end_z),Vector3(12.6,HEIGHT.end_eaves-7.3,.55))
			elif id=="way/568422349":
				if level==0:_drum(s,OUTER_RADIUS,HEIGHT.drum_low,HEIGHT.copper_low,0.65)
				else:_dome(s,Vector3(0,HEIGHT.copper_low,0),OUTER_RADIUS,HEIGHT.lantern_low-HEIGHT.copper_low,0.28);key="qvb_copper"
			elif id=="way/568422351":
				if level==0:
					for i in 12:_cylinder(s,Vector3(cos(TAU*i/12)*2.0,(HEIGHT.lantern_low+HEIGHT.lantern_cap)*.5,sin(TAU*i/12)*2.0),.15,HEIGHT.lantern_cap-HEIGHT.lantern_low)
					_cylinder(s,Vector3(0,HEIGHT.lantern_low,0),2.2,.25)
					_cylinder(s,Vector3(0,HEIGHT.lantern_cap-.12,0),2.2,.25)
				else:
					_dome(s,Vector3(0,HEIGHT.lantern_cap,0),2.2,HEIGHT.lantern_crown-HEIGHT.lantern_cap,.18)
					_cylinder(s,Vector3(0,(HEIGHT.lantern_crown+HEIGHT.spire)*.5,0),.15,HEIGHT.spire-HEIGHT.lantern_crown,.03)
				key="qvb_copper"
			else:
				var c:=Basis(Vector3.UP,ANGLE).inverse()*(Vector3(part.center[0],4.5,part.center[1])-CENTER)
				var r:=0.0
				for p in poly:r=maxf(r,p.distance_to(Vector2(c.x,c.z)))
				var tip:float=HEIGHT.minor_middle_tip if count==1 else HEIGHT.minor_end_tip
				var dome_base:float=tip-3.7
				if level==0:
					_box(s,Vector3(c.x,(HEIGHT.eaves+HEIGHT.end_eaves)*.5,c.z),Vector3(r*1.78,HEIGHT.end_eaves-HEIGHT.eaves,r*1.78))
					_cylinder(s,Vector3(c.x,(HEIGHT.end_eaves+dome_base)*.5,c.z),r*.94,maxf(.3,dome_base-HEIGHT.end_eaves))
				if count==1 or level==1:
					_dome(s,Vector3(c.x,dome_base,c.z),r,3.45,.16)
					_cylinder(s,Vector3(c.x,tip-.125,c.z),.13,.25,.05)
					if level==1:key="qvb_copper"
			if id in ["way/568422349","way/568422351"]:
				var shifted:=_surface()
				var source_center:=Basis(Vector3.UP,ANGLE).inverse()*(Vector3(part.center[0],4.5,part.center[1])-CENTER)
				_append_mesh(shifted,s.commit(),0,Transform3D(Basis.IDENTITY,source_center));s=shifted
			var body:=_body(world,"osm/%s/storey_group/%s"%[id,level],s,key)
			if id=="way/40717424":_facades(world,body);_arcade(world,body)
			if id=="way/568422349":_dome_detail(world,body,level)
			if not id in ["way/40717424","way/568422314","way/568422315","way/568422349","way/568422351"]:_minor_detail(world,body,part,level,count)
	var floor_body:StaticBody3D=world._structure_mesh("city/qvb/public_floor",G.prism(G.polygon(PARTS[0].outline),-.18,.04),CENTER,"qvb_tile",320000.0)
	floor_body.set_meta("qvb_public",true)
	_roof_enclosure(world)
	world.set_meta("qvb_public",metadata())

static func _materials(world:Node3D) -> void:
	for row in [["qvb_stone","be935e"],["qvb_trim","dcc4a0"],["qvb_darkstone","565d50"],["qvb_cream","f0e2c7"],["qvb_red","923b35"],["qvb_copper","729988"],["qvb_iron","293c35"],["qvb_glass","748e83"],["qvb_amber","c5b052"],["qvb_green","557860"]]:world._mat(row[0],Color(row[1]),.75)
	# Thin glazing is seen from both the public arcade and the street/roof side.
	for key in ["qvb_glass","qvb_amber","qvb_green"]:world.materials[key].cull_mode=BaseMaterial3D.CULL_DISABLED
	world._mat("qvb_lamp",Color("ffdfaa"),.45)
	world.materials.qvb_lamp.emission_enabled=true;world.materials.qvb_lamp.emission=Color("f6c989");world.materials.qvb_lamp.emission_energy_multiplier=.65
	var shader:=Shader.new();shader.code="""shader_type spatial;
void fragment(){
 vec2 p=UV*vec2(1.7,1.0);vec2 grid=vec2(p.x+p.y,p.x-p.y);
 float pattern=mod(floor(grid.x)+floor(grid.y),2.0);
 vec3 cream=vec3(.76,.66,.47);vec3 dark=vec3(.24,.24,.18);
 float border=step(4.8,abs(UV.x));
 vec2 motif=vec2(abs(UV.x)-3.6,mod(UV.y+9.0,18.0)-9.0);
 float r=length(motif);float rings=step(.92,r)-step(1.03,r)+step(1.19,r)-step(1.32,r);
 vec3 tiled=mix(cream,dark,pattern*.65);tiled=mix(tiled,cream,1.0-step(.90,r));
 ALBEDO=mix(mix(tiled,dark,clamp(rings,0.0,1.0)),dark,border*.7);ROUGHNESS=.68;
}"""
	var m:=ShaderMaterial.new();m.shader=shader;world.materials.qvb_tile=m

static func _drum(s:SurfaceTool,r:float,low:float,high:float,t:float) -> void:
	for i in 64:
		var a:=TAU*i/64;var b:=TAU*(i+1)/64
		var pa:=Vector3(cos(a),0,sin(a));var pb:=Vector3(cos(b),0,sin(b))
		_quad(s,pa*r+Vector3.UP*low,pb*r+Vector3.UP*low,pb*r+Vector3.UP*high,pa*r+Vector3.UP*high,(pa+pb).normalized())
		_quad(s,pa*(r-t)+Vector3.UP*high,pb*(r-t)+Vector3.UP*high,pb*(r-t)+Vector3.UP*low,pa*(r-t)+Vector3.UP*low,-(pa+pb).normalized())
		for y in [low,high]:_quad(s,pa*r+Vector3.UP*y,pb*r+Vector3.UP*y,pb*(r-t)+Vector3.UP*y,pa*(r-t)+Vector3.UP*y,Vector3.UP if y==high else Vector3.DOWN)

static func _dome(s:SurfaceTool,c:Vector3,r:float,h:float,t:float) -> void:
	# Closed copper roof skin, with a separate inner glass dome below.
	for row in 8:
		for i in 32:
			var a:=TAU*i/32;var b:=TAU*(i+1)/32;var lo:=PI*.5*row/8;var hi:=PI*.5*(row+1)/8
			var p:=Vector3(cos(a)*r*cos(lo),h*sin(lo),sin(a)*r*cos(lo));var q:=Vector3(cos(b)*r*cos(lo),h*sin(lo),sin(b)*r*cos(lo));var v:=Vector3(cos(b)*r*cos(hi),h*sin(hi),sin(b)*r*cos(hi));var u:=Vector3(cos(a)*r*cos(hi),h*sin(hi),sin(a)*r*cos(hi))
			var n:=(p+q+u+v).normalized()
			_quad(s,c+p,c+q,c+v,c+u,n)
			_quad(s,c+p-Vector3.UP*t,c+u-Vector3.UP*t,c+v-Vector3.UP*t,c+q-Vector3.UP*t,-n)
			if row==0:_quad(s,c+p,c+p-Vector3.UP*t,c+q-Vector3.UP*t,c+q,Vector3.DOWN)

static func _facades(world:Node3D,owner:StaticBody3D) -> void:
	var trim:=_surface();var glass:=_surface();var dark:=_surface();var green:=_surface();var amber:=_surface()
	for side in [-1.0,1.0]:
		var facing:=Basis(Vector3.UP,PI*.5)
		for z in range(-87,90,6):
			if abs(z)<8:continue
			var edge:=_edge_x(float(z),side)
			var face:float=edge+side*.18
			for dz in [-1.22,1.22]:
				_arch_window(glass,Vector3(face,13.1,z+dz),.98,7.4,.12,facing)
				_arch(trim,Vector3(edge+side*.40,13.1,z+dz),1.0,.27,.40,facing)
				for border in [-1.0,1.0]:_cylinder(trim,Vector3(edge+side*.42,9.4,z+dz+border*1.04),.14,7.4)
			_arch(trim,Vector3(edge+side*.48,12.75,z),2.5,.36,.42,facing)
			# Strong full-height outer pilasters separate real paired window bays.
			for dz in [-2.83,2.83]:
				_box(trim,Vector3(edge+side*.24,10.1,z+dz),Vector3(.48,10.2,.25))
				_cylinder(dark,Vector3(edge+side*.15,2.3,z+dz),.20,4.6)
			_box(trim,Vector3(edge+side*.32,HEIGHT.second_floor,z),Vector3(.24,.13,5.2))
			_box(dark,Vector3(face,2.15,z),Vector3(.13,4.1,5.2))
			for j in 8:_box(amber if j%2==0 else green,Vector3(edge+side*.29,3.95,z-2.3+j*.65),Vector3(.08,.68,.53))
		for z in [-87.0,-81.0,81.0,87.0]:
			var edge:=_edge_x(z,side)
			for dz in [-1.2,1.2]:
				_arch_window(glass,Vector3(edge+side*.20,21.2,z+dz),.9,4.6,.12,facing)
				_arch(trim,Vector3(edge+side*.40,21.2,z+dz),.95,.25,.32,facing)
				for border in [-1.0,1.0]:_cylinder(trim,Vector3(edge+side*.40,18.9,z+dz+border*.98),.12,4.6)
			_box(trim,Vector3(edge+side*.27,23.65,z),Vector3(.55,.28,6.1))
		for y in [5.0,15.1,15.65]:_box(trim,Vector3(side*15.05,y,0),Vector3(.70,.30,185))
		_box(dark,Vector3(side*15.45,4.75,0),Vector3(2.2,.20,185))
		var edge:=_edge_x(0.0,side)
		for z in [-3.65,3.65]:
			_cylinder(dark,Vector3(edge+side*.2,1.8,z),.44,3.6)
			_cylinder(trim,Vector3(edge+side*.2,.22,z),.62,.44)
			_cylinder(trim,Vector3(edge+side*.2,3.55,z),.62,.30)
		_arch(trim,Vector3(edge+side*.38,3.7,0),3.3,.48,.65,facing)
		_wheel(glass,trim,Vector3(edge+side*.50,10.65,0),3.05,facing)
		# Projected wheel-window surrounds remain in front of the wall plane.
		_arch(trim,Vector3(edge+side*.49,10.65,0),3.12,.38,.48,facing)
		_arch(trim,Vector3(edge+side*.49,10.65,0),3.12,.38,.48,Basis(Vector3.UP,PI*.5)*Basis(Vector3.FORWARD,PI))
	for end in [-1.0,1.0]:
		var end_z:float=-93.55 if end<0 else 94.85
		for side in [-1.0,1.0]:
			for j in 9:_box(dark,Vector3(side*3.5,1.4,end_z-end*(.3+j*.17)),Vector3(.04,2.8,.04))
			for y in [.35,2.5]:_box(dark,Vector3(side*3.5,y,end_z-end*.98),Vector3(.07,.07,1.55))
			_cylinder(dark,Vector3(side*3.85,1.75,end_z),.40,3.5)
			_cylinder(trim,Vector3(side*3.85,3.45,end_z),.60,.30)
			_box(trim,Vector3(side*5.9,HEIGHT.end_eaves*.5,end_z),Vector3(.5,HEIGHT.end_eaves,.45))
			for x in [side*8.6,side*11.3]:
				_arch_window(glass,Vector3(x,19.3,end_z),.88,11.7,.10)
				_arch(trim,Vector3(x,19.3,end_z+end*.12),.93,.28,.30)
				for dx in [-1.0,1.0]:_cylinder(trim,Vector3(x+dx*.95,13.4,end_z+end*.10),.12,11.8)
		_arch(trim,Vector3(0,3.3,end_z),3.65,.44,.65)
		_arch(trim,Vector3(0,3.3,end_z+end*.09),4.17,.22,.55)
		# Only George/York have wheel windows. The short elevations have
		# two recessed arches, each containing paired full-height windows.
		for group in [-3.1,3.1]:
			for dx in [-1.13,1.13]:
				_arch_window(glass,Vector3(group+dx,19.3,end_z+end*.12),.92,11.7,.10)
				_arch(trim,Vector3(group+dx,19.3,end_z+end*.26),.96,.22,.28)
				for border in [-1.0,1.0]:_cylinder(trim,Vector3(group+dx+border*.97,13.4,end_z+end*.25),.12,11.8)
			_arch(trim,Vector3(group,19.55,end_z+end*.24),2.4,.3,.30)
		for y in [7.35,21.95,23.7]:_box(trim,Vector3(0,y,end_z),Vector3(29.0,.28,.4))
		var lobby_z:float=-83.7 if end<0 else 83.8
		_box(trim,Vector3(0,7.27,lobby_z),Vector3(12.4,.045,14.3))
		for side in [-1.0,1.0]:
			_box(trim,Vector3(side*6.275,3.6,lobby_z),Vector3(.045,7.2,14.3))
		# Inward-splayed shopfront glass at the real street approaches; closed
		# behind it, no new private shop interior or speculative tenant is added.
		for side in [-1.0,1.0]:
			for j in 6:
				var z:float=end_z-end*(1.0+j*.8);var x:float=side*(3.9+j*.20)
				_box(glass,Vector3(x,1.6,z),Vector3(.08,3.0,.78))
	_commit(world,owner,trim,"qvb_trim");_commit(world,owner,glass,"qvb_glass");_commit(world,owner,dark,"qvb_darkstone");_commit(world,owner,amber,"qvb_amber");_commit(world,owner,green,"qvb_green")

static func _wheel(glass:SurfaceTool,frame:SurfaceTool,c:Vector3,r:float,b:Basis) -> void:
	for i in 24:
		var a:=Vector3(cos(TAU*i/24)*r,sin(TAU*i/24)*r,0);var v:=Vector3(cos(TAU*(i+1)/24)*r,sin(TAU*(i+1)/24)*r,0)
		G._triangle(glass,c,c+b*a,c+b*v,b*Vector3.BACK,Vector2.ZERO,Vector2.ONE,Vector2.RIGHT)
		_beam(frame,c+b*a,c+b*v,.13,.13)
		if i%2==0:_beam(frame,c,c+b*a,.12,.12)

static func _arcade(world:Node3D,owner:StaticBody3D) -> void:
	var cream:=_surface();var iron:=_surface();var glass:=_surface();var amber:=_surface();var lamps:=_surface()
	for side in [-1.0,1.0]:
		for z in range(-75,79,6):
			if abs(z)<12:continue
			for y in [0.0,HEIGHT.first_floor,HEIGHT.second_floor]:
				var x:float=side*6.16
				_cylinder(cream,Vector3(x,y+1.45,z),.28,2.9)
				_cylinder(cream,Vector3(x,y+.16,z),.41,.32)
				_box(cream,Vector3(x,y+2.85,z),Vector3(.75,.3,.75))
				_arch(cream,Vector3(side*5.92,y+2.95,z+3),2.3,.30,.55,Basis(Vector3.UP,PI*.5))
				_arch_window(glass,Vector3(side*6.25,y+2.90,z+3),2.23,2.78,.08,Basis(Vector3.UP,PI*.5))
				for j in 8:_box(amber,Vector3(side*6.25,y+3.5,z+.85+j*.60),Vector3(.03,.5,.58))
			if abs(z)>15:
				_cylinder(iron,Vector3(side*5.0,4.15,z+3),.025,1.5)
				_cylinder(lamps,Vector3(side*5.0,3.5,z+3),.19,.40,.27)
		for y in [HEIGHT.first_floor,HEIGHT.second_floor]:
			for half in [-1.0,1.0]:
				_box(cream,Vector3(side*5.6,y,half*44),Vector3(1.4,.35,66))
				_box(iron,Vector3(side*4.95,y+1.0,half*44),Vector3(.09,.09,66))
				for z in range(12,78):_box(iron,Vector3(side*4.95,y+.53,half*z),Vector3(.035,.9,.035))
	# Central red drum and inner stained-glass dome are separate from copper.
	for x in [-7.0,7.0]:
		for z in [-9.0,9.0]:_cylinder(cream,Vector3(x,3.0,z),.62,6.0)
	for z in [-10.0,10.0]:
		_arch(cream,Vector3(0,7,z),6.1,.55,.75)
		_arch(cream,Vector3(0,16.6,z),6.1,.50,.65)
	_commit(world,owner,cream,"qvb_cream");_commit(world,owner,iron,"qvb_iron");_commit(world,owner,glass,"qvb_glass");_commit(world,owner,amber,"qvb_amber");_commit(world,owner,lamps,"qvb_lamp")

static func _minor_detail(world:Node3D,owner:StaticBody3D,part:Dictionary,level:int,count:int) -> void:
	var c:=Basis(Vector3.UP,ANGLE).inverse()*(Vector3(part.center[0],4.5,part.center[1])-CENTER)
	var r:=0.0
	for p in _local_outline(part):r=maxf(r,p.distance_to(Vector2(c.x,c.z)))
	var tip:float=HEIGHT.minor_middle_tip if count==1 else HEIGHT.minor_end_tip
	var base:float=tip-3.7
	if count==1:
		# Copper cladding follows the existing single retained solid component.
		var copper:=_surface();_dome(copper,c+Vector3.UP*(base+.012),r,3.45,.012)
		_commit(world,owner,copper,"qvb_copper")
	if level!=0:return
	var frames:=_surface();var windows:=_surface()
	for i in 8:
		var a:=TAU*i/8.0;var p:=c+Vector3(cos(a)*r*.951,base-.35,sin(a)*r*.951)
		var basis:=Basis(Vector3.UP,-a+PI*.5)
		_arch_window(windows,p,.36,maxf(.3,base-HEIGHT.end_eaves-.45),.10,basis)
		_arch(frames,p,.40,.12,.18,basis)
	for y in [HEIGHT.end_eaves,base-.04]:
		var collar:=_surface();_drum(collar,r*1.015,y-.10,y+.10,.18)
		_append_mesh(frames,collar.commit(),0,Transform3D(Basis.IDENTITY,c))
	_commit(world,owner,frames,"qvb_trim");_commit(world,owner,windows,"qvb_glass")

static func _dome_detail(world:Node3D,owner:StaticBody3D,level:int) -> void:
	var ribs:=_surface();var glazing:=_surface();var green:=_surface();var outer_glass:=_surface();var lead:=_surface()
	for i in 32:
		var a:=TAU*i/32
		if level==0:
			var p:=Vector3(cos(a)*(OUTER_RADIUS+.05),HEIGHT.copper_low-1.45,sin(a)*(OUTER_RADIUS+.05))
			var frame:=Basis(Vector3.UP,-a+PI*.5)
			_arch_window(outer_glass,p,.44,5.6,.12,frame)
			_arch(ribs,p,.49,.15,.22,frame)
			_cylinder(ribs,Vector3(cos(a+.075)*(OUTER_RADIUS+.10),(HEIGHT.drum_low+HEIGHT.copper_low)*.5,sin(a+.075)*(OUTER_RADIUS+.10)),.13,7.9)
		else:
			for j in 16:
				var lo:=PI*.5*j/16;var hi:=PI*.5*(j+1)/16
				_beam(ribs,Vector3(cos(a)*(OUTER_RADIUS+.025)*cos(lo),HEIGHT.copper_low+.025+12.5*sin(lo),sin(a)*(OUTER_RADIUS+.025)*cos(lo)),Vector3(cos(a)*(OUTER_RADIUS+.025)*cos(hi),HEIGHT.copper_low+.025+12.5*sin(hi),sin(a)*(OUTER_RADIUS+.025)*cos(hi)),.085,.085)
	if level==0:
		_drum(ribs,OUTER_RADIUS+.55,HEIGHT.copper_low-.35,HEIGHT.copper_low-.10,.35)
		for i in 48:
			var a:=TAU*i/48;var b:=TAU*(i+1)/48
			for j in 12:
				var lo:=PI*.5*j/12;var hi:=PI*.5*(j+1)/12
				var rise:float=HEIGHT.inner_crown-HEIGHT.inner_spring
				var p:=Vector3(cos(a)*INNER_RADIUS*cos(lo),HEIGHT.inner_spring+rise*sin(lo),sin(a)*INNER_RADIUS*cos(lo));var q:=Vector3(cos(b)*INNER_RADIUS*cos(lo),HEIGHT.inner_spring+rise*sin(lo),sin(b)*INNER_RADIUS*cos(lo));var u:=Vector3(cos(a)*INNER_RADIUS*cos(hi),HEIGHT.inner_spring+rise*sin(hi),sin(a)*INNER_RADIUS*cos(hi));var v:=Vector3(cos(b)*INNER_RADIUS*cos(hi),HEIGHT.inner_spring+rise*sin(hi),sin(b)*INNER_RADIUS*cos(hi))
				_quad(green if (i+j)%3!=0 else glazing,p,q,v,u,Vector3.DOWN)
				_beam(lead,p-Vector3.UP*.025,u-Vector3.UP*.025,.045,.045);_beam(lead,p-Vector3.UP*.025,q-Vector3.UP*.025,.045,.045)
	var offset:=Basis(Vector3.UP,ANGLE).inverse()*(Vector3(-352.176,4.5,1309.888)-CENTER)
	for row in [[ribs,"qvb_trim"],[glazing,"qvb_amber"],[green,"qvb_green"],[outer_glass,"qvb_glass"],[lead,"qvb_iron"]]:
		var mesh:Mesh=row[0].commit()
		if mesh==null or mesh.get_surface_count()==0:continue
		var aligned:=_surface();_append_mesh(aligned,mesh,0,Transform3D(Basis.IDENTITY,offset));_commit(world,owner,aligned,row[1])

static func _roof_enclosure(world:Node3D) -> void:
	# Real closed glass skins, not isolated linework against the outdoor sky.
	world._mat("qvb_roof_glass",Color("b8cbd0"),.30,.12)
	world.materials.qvb_roof_glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	var roof:=_surface();var ribs:=_surface()
	# Segmented glazed slopes and raised central clerestory follow the actual
	# 2018 interior photographs; heights are independently calibrated levels.
	var line:=PackedVector2Array([Vector2(-6.37,HEIGHT.eaves),Vector2(-6.37,HEIGHT.glass_lower),Vector2(-1.6,HEIGHT.glass_upper),Vector2(-1.6,22.45),Vector2(0,HEIGHT.ridge),Vector2(1.6,22.45),Vector2(1.6,HEIGHT.glass_upper),Vector2(6.37,HEIGHT.glass_lower),Vector2(6.37,HEIGHT.eaves)])
	var strips:=Geometry2D.offset_polyline(line,.07,Geometry2D.JOIN_MITER,Geometry2D.END_BUTT)
	var profile:PackedVector2Array=strips[0]
	for half in [-1.0,1.0]:
		var low:float=10.0 if half>0 else -94.0
		var high:float=94.7 if half>0 else -10.0
		_append_mesh(roof,G.profile_solid(profile,(high-low)*.5),0,Transform3D(Basis.IDENTITY,Vector3(0,0,(low+high)*.5)))
		for row in 15:
			var z:float=lerpf(low,high,row/14.0)
			for i in line.size()-1:
				var a:=line[i];var b:=line[i+1]
				_beam(ribs,Vector3(a.x,a.y-.24,z),Vector3(b.x,b.y-.24,z),.14,.14)
			# Exposed lattice ties beneath the panes, not hidden above the glass.
			_beam(ribs,Vector3(-6.25,16.35,z),Vector3(6.25,16.35,z),.09,.09)
			for side in [-1.0,1.0]:
				_beam(ribs,Vector3(side*6.25,16.35,z),Vector3(side*1.6,HEIGHT.glass_upper-.25,z),.075,.075)
				_beam(ribs,Vector3(0,16.35,z),Vector3(side*4.0,18.9,z),.07,.07)
		for i in range(1,line.size()-1):
			var a:=line[i]
			_beam(ribs,Vector3(a.x,a.y-.25,low),Vector3(a.x,a.y-.25,high),.09,.09)
		# Narrow pane divisions on each sloping roof face.
		for z in range(ceili(low),floori(high),2):
			for i in line.size()-1:
				var a:=line[i];var b:=line[i+1]
				_beam(ribs,Vector3(a.x,a.y-.19,z),Vector3(b.x,b.y-.19,z),.035,.035)
	var glass_body:=_body(world,"city/qvb/roof_glazing",roof,"qvb_roof_glass")
	_commit(world,glass_body,ribs,"qvb_cream")
	# Square outer core to circular inner-dome opening. The ring closes all
	# former sky gaps while the entire coloured glass dome remains visible.
	var transition:=_surface();var finish:=_surface();var interior:=_surface()
	var offset:=Basis(Vector3.UP,ANGLE).inverse()*(Vector3(-352.176,4.5,1309.888)-CENTER)
	var inner:=INNER_RADIUS;var low:float=HEIGHT.spacer_low;var high:float=HEIGHT.inner_spring
	for i in 64:
		var a:=TAU*i/64.0;var b:=TAU*(i+1)/64.0
		var ia:=offset+Vector3(cos(a)*inner,0,sin(a)*inner)
		var ib:=offset+Vector3(cos(b)*inner,0,sin(b)*inner)
		var la:=offset+Vector3(cos(a)*9.5,0,sin(a)*9.5)
		var lb:=offset+Vector3(cos(b)*9.5,0,sin(b)*9.5)
		var oa:=_core_outer(offset,a);var ob:=_core_outer(offset,b)
		_quad(transition,ia+Vector3.UP*high,ib+Vector3.UP*high,ob+Vector3.UP*high,oa+Vector3.UP*high,Vector3.UP)
		_quad(transition,la+Vector3.UP*low,oa+Vector3.UP*low,ob+Vector3.UP*low,lb+Vector3.UP*low,Vector3.DOWN)
		_quad(transition,la+Vector3.UP*low,lb+Vector3.UP*low,ib+Vector3.UP*high,ia+Vector3.UP*high,-Vector3(cos((a+b)*.5),.77,sin((a+b)*.5)).normalized())
		var na:=Vector3(cos(a),0,sin(a));var nb:=Vector3(cos(b),0,sin(b))
		_quad(interior,la-na*.014+Vector3.UP*low,lb-nb*.014+Vector3.UP*low,ib-nb*.014+Vector3.UP*high,ia-na*.014+Vector3.UP*high,-Vector3(cos((a+b)*.5),.77,sin((a+b)*.5)).normalized())
		_quad(transition,oa+Vector3.UP*high,ob+Vector3.UP*high,ob+Vector3.UP*low,oa+Vector3.UP*low,Vector3(cos((a+b)*.5),0,sin((a+b)*.5)))
		_beam(finish,ia+Vector3.UP*(high-.08),ib+Vector3.UP*(high-.08),.18,.18)
		_beam(finish,la+Vector3.UP*(low+.08),lb+Vector3.UP*(low+.08),.18,.18)
	var masonry:=_body(world,"city/qvb/roof_transition",transition,"qvb_stone")
	_commit(world,masonry,finish,"qvb_trim");_commit(world,masonry,interior,"qvb_red")
	# Central George / York upper-wall surround: keep the public street arch
	# open below and a real round glass opening above, not four missing walls.
	var portals:=_surface();var portal_trim:=_surface()
	for side in [-1.0,1.0]:
		var edge:=_edge_x(0.0,side)
		var frame:=Basis(Vector3.UP,PI*.5)
		_spandrel(portals,Vector3(edge,3.7,0),3.3,4.4,3.5,.55,frame)
		for z in [-3.85,3.85]:_box(portals,Vector3(edge,1.85,z),Vector3(.55,3.7,1.1))
		_round_window_panel(portals,Vector3(edge,10.9,0),4.4,3.7,3.07,.55,frame)
		for y in [7.25,14.45]:_box(portal_trim,Vector3(edge,y,0),Vector3(.7,.22,8.8))
	# Keep this closed portal component distinct from the four closed shop
	# wings so coincident internal edges cannot break containment classification.
	for side in [-1.0,1.0]:
		_box(portals,Vector3(side*10.15,(HEIGHT.eaves+HEIGHT.spacer_low)*.5,0),Vector3(.40,HEIGHT.spacer_low-HEIGHT.eaves,20.3))
		for x in [-8.25,8.25]:_box(portals,Vector3(x,(HEIGHT.eaves+HEIGHT.spacer_low)*.5,side*10.15),Vector3(3.8,HEIGHT.spacer_low-HEIGHT.eaves,.40))
		# Roof over the public transverse entry beyond the central square core.
		_box(portals,Vector3(side*12.55,HEIGHT.eaves-.12,0),Vector3(5.1,.24,8.8))
	var entrance:=_body(world,"city/qvb/entry_shell",portals,"qvb_stone")
	_commit(world,entrance,portal_trim,"qvb_trim")

static func _core_outer(offset:Vector3,a:float) -> Vector3:
	var d:=Vector3(cos(a),0,sin(a));var tx:=INF;var tz:=INF
	if absf(d.x)>.00001:tx=((10.15 if d.x>0 else -10.15)-offset.x)/d.x
	if absf(d.z)>.00001:tz=((10.15 if d.z>0 else -10.15)-offset.z)/d.z
	return offset+d*minf(tx,tz)

static func _round_window_panel(s:SurfaceTool,c:Vector3,half_width:float,half_height:float,r:float,depth:float,basis:Basis) -> void:
	for i in 64:
		var a:=TAU*i/64.0;var b:=TAU*(i+1)/64.0
		var da:=Vector3(cos(a),sin(a),0);var db:=Vector3(cos(b),sin(b),0)
		var ra:=minf(half_width/maxf(absf(da.x),.000001),half_height/maxf(absf(da.y),.000001));var rb:=minf(half_width/maxf(absf(db.x),.000001),half_height/maxf(absf(db.y),.000001))
		var ia:=da*r;var ib:=db*r;var oa:=da*ra;var ob:=db*rb
		for side in [-1.0,1.0]:
			var dz:=Vector3(0,0,side*depth*.5)
			_quad(s,c+basis*(ia+dz),c+basis*(ib+dz),c+basis*(ob+dz),c+basis*(oa+dz),basis*Vector3(0,0,side))
		var dz:=Vector3(0,0,depth*.5)
		_quad(s,c+basis*(ia+dz),c+basis*(ib+dz),c+basis*(ib-dz),c+basis*(ia-dz),-(basis*(da+db).normalized()))
		_quad(s,c+basis*(oa-dz),c+basis*(ob-dz),c+basis*(ob+dz),c+basis*(oa+dz),basis*(da+db).normalized())
