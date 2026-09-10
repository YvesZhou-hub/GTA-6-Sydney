extends SceneTree
func _initialize():
 var p=PackedVector2Array([Vector2(0,0),Vector2(100,0),Vector2(100,100),Vector2(0,100)])
 var tri=Geometry2D.triangulate_polygon(p)
 print(tri)
 var st=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for v in p:st.add_vertex(Vector3(v.x,0,v.y))
 for i in tri:st.add_index(i)
 st.generate_normals()
 var m=st.commit()
 print(m.surface_get_arrays(0)[Mesh.ARRAY_NORMAL])
 quit()
