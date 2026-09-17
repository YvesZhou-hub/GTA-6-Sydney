extends SceneTree
## The CPU unit-box path must reproduce the previous BoxMesh readback path vertex for vertex.
const Geo=preload("res://scripts/city_landmarks.gd")
var checks:Array=[]
func check(title:String,okay:bool):
	checks.append({"name":title,"passed":okay})
	print("BOX_EQUIVALENCE ","PASS " if okay else "FAIL ",title)
func legacy_box(st:SurfaceTool,position:Vector3,size:Vector3,basis:Basis):
	var box:=BoxMesh.new();box.size=size
	var expanded:=SurfaceTool.new();expanded.create_from(box,0);expanded.deindex()
	st.append_from(expanded.commit(),0,Transform3D(basis,position))
func manual_triangle(st:SurfaceTool):
	Geo._triangle(st,Vector3(10,0,0),Vector3(11,0,0),Vector3(10,1,0),Vector3.BACK,Vector2.ZERO,Vector2.RIGHT,Vector2.UP)
func build(use_legacy:bool,cases:Array) -> Array:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	manual_triangle(st)
	for item:Array in cases:
		if use_legacy:legacy_box(st,item[0],item[1],item[2])
		else:Geo._append_box(st,item[0],item[1],item[2])
	manual_triangle(st)
	return st.commit().surface_get_arrays(0)
func _initialize():
	var cases:=[
		[Vector3.ZERO,Vector3.ONE,Basis.IDENTITY],
		[Vector3(3,4,-2),Vector3(0.075,6,0.13),Basis.looking_at(Vector3(0.6,0,-0.8),Vector3.UP)],
		[Vector3(-12.5,273.3,9.06),Vector3(3.5,2.25,0.07),Basis(Vector3.UP,1.234)],
		[Vector3(1,2,3),Vector3(0.17,0.2,14.03),Basis.looking_at(Vector3(0.3,0.9,0.31).normalized(),Vector3.FORWARD)],
		[Vector3(-7,0.5,40),Vector3(18.8,0.3,0.65),Basis(Vector3(1,1,0).normalized(),-0.7)*Basis(Vector3.UP,2.1)],
	]
	var legacy:=build(true,cases)
	var current:=build(false,cases)
	var legacy_vertices:PackedVector3Array=legacy[Mesh.ARRAY_VERTEX]
	var current_vertices:PackedVector3Array=current[Mesh.ARRAY_VERTEX]
	check("same vertex count including manual triangles before and after boxes",legacy_vertices.size()==current_vertices.size() and current_vertices.size()==6+cases.size()*36)
	var worst_position:=0.0;var worst_normal:=0.0;var worst_uv:=0.0
	var legacy_normals:PackedVector3Array=legacy[Mesh.ARRAY_NORMAL];var current_normals:PackedVector3Array=current[Mesh.ARRAY_NORMAL]
	var legacy_uv:PackedVector2Array=legacy[Mesh.ARRAY_TEX_UV];var current_uv:PackedVector2Array=current[Mesh.ARRAY_TEX_UV]
	for i in mini(legacy_vertices.size(),current_vertices.size()):
		worst_position=maxf(worst_position,legacy_vertices[i].distance_to(current_vertices[i]))
		worst_normal=maxf(worst_normal,legacy_normals[i].distance_to(current_normals[i]))
		worst_uv=maxf(worst_uv,legacy_uv[i].distance_to(current_uv[i]))
	print("BOX_EQUIVALENCE worst position=%f normal=%f uv=%f" % [worst_position,worst_normal,worst_uv])
	check("positions match the legacy BoxMesh path in order within 0.1 mm",worst_position<0.0001)
	check("normals match the legacy path within compression tolerance",worst_normal<0.002)
	check("UVs match the legacy path",worst_uv<0.00001)
	var passed:=checks.all(func(item):return item.passed)
	DirAccess.make_dir_recursive_absolute("res://../reports/box-geometry-equivalence")
	FileAccess.open("res://../reports/box-geometry-equivalence/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"worst":{"position":worst_position,"normal":worst_normal,"uv":worst_uv},"checks":checks,"sha256":{"game/scripts/city_landmarks.gd":FileAccess.get_sha256("res://scripts/city_landmarks.gd"),"source/box_geometry_equivalence_test.gd":FileAccess.get_sha256("res://../source/box_geometry_equivalence_test.gd")}},"\t"))
	quit(0 if passed else 1)
