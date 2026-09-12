extends SceneTree
const Geo=preload("res://scripts/city_landmarks.gd")
var checks:Array=[]
func check(title:String,okay:bool):
	checks.append({"name":title,"passed":okay})
	print("MESH_COMPOSITION ","PASS " if okay else "FAIL ",title)
func triangle(st:SurfaceTool):
	Geo._triangle(st,Vector3(10,0,0),Vector3(11,0,0),Vector3(10,1,0),Vector3.BACK,Vector2.ZERO,Vector2.RIGHT,Vector2.UP)
func stats(mesh:Mesh) -> Dictionary:
	var faces:=mesh.get_faces();var area:=0.0;var remote:=0
	for i in range(0,faces.size(),3):
		area+=(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length()*.5
		if faces[i].x>9 and faces[i+1].x>9 and faces[i+2].x>9:remote+=1
	return {"triangles":faces.size()/3,"area":area,"remote":remote}
func _initialize():
	var old:=SurfaceTool.new();old.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box:=BoxMesh.new();box.size=Vector3.ONE*2
	old.append_from(box,0,Transform3D.IDENTITY);triangle(old)
	check("legacy indexed primitive plus manual triangle reproduces missing face",stats(old.commit()).remote==0)
	for first in [true,false]:
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if first:triangle(st)
		Geo._append_box(st,Vector3.ZERO,Vector3.ONE*2,Basis(Vector3.UP,.4))
		if not first:triangle(st)
		var mesh:=st.commit();var found:=stats(mesh)
		check("both append orders preserve all 13 triangles "+str(first),found.triangles==13 and found.remote==1)
		check("cube and independent triangle retain 24.5 square metres "+str(first),absf(found.area-24.5)<.0001)
		var arrays:=mesh.surface_get_arrays(0)
		var valid:=true
		for normal:Vector3 in arrays[Mesh.ARRAY_NORMAL]:
			if not normal.is_finite() or absf(normal.length()-1.0)>.0001:valid=false
		check("transformed normals remain finite and normalized "+str(first),valid)
	var cylinder:=CylinderMesh.new();cylinder.height=2;cylinder.top_radius=.5;cylinder.bottom_radius=.5;cylinder.radial_segments=12
	var mixture:=SurfaceTool.new();mixture.begin(Mesh.PRIMITIVE_TRIANGLES)
	triangle(mixture);Geo._append_mesh_triangles(mixture,cylinder,Transform3D(Basis(Vector3.FORWARD,.5),Vector3(0,2,0)))
	var combined:=stats(mixture.commit());var original:=stats(cylinder)
	check("indexed cylinder retains every source face alongside manual geometry",combined.remote==1 and combined.triangles==original.triangles+1)
	check("cylinder transformation preserves surface area",absf(combined.area-original.area-.5)<.0001)
	var passed:=checks.all(func(item):return item.passed)
	DirAccess.make_dir_recursive_absolute("res://../reports/mesh-composition")
	FileAccess.open("res://../reports/mesh-composition/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"sha256":{"game/scripts/city_landmarks.gd":FileAccess.get_sha256("res://scripts/city_landmarks.gd"),"source/mesh_composition_test.gd":FileAccess.get_sha256("res://../source/mesh_composition_test.gd")}},"\t"))
	quit(0 if passed else 1)
