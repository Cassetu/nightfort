extends RefCounted


static func build(material: Material) -> ArrayMesh:
	var a := Vector3(-0.5, -0.5, 0.5)
	var b := Vector3(0.5, -0.5, 0.5)
	var c := Vector3(0.5, -0.5, -0.5)
	var d := Vector3(-0.5, -0.5, -0.5)
	var e := Vector3(-0.5, 0.5, -0.5)
	var f := Vector3(0.5, 0.5, -0.5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slope := Vector3(0.0, 1.0, 1.0).normalized()
	_quad(st, [e, f, b, a], slope)
	_quad(st, [f, e, d, c], Vector3(0.0, 0.0, -1.0))
	_quad(st, [a, b, c, d], Vector3(0.0, -1.0, 0.0))
	_tri(st, [b, f, c], Vector3(1.0, 0.0, 0.0))
	_tri(st, [a, d, e], Vector3(-1.0, 0.0, 0.0))
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	return mesh


static func shape() -> ConvexPolygonShape3D:
	var s := ConvexPolygonShape3D.new()
	s.points = PackedVector3Array([
		Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5),
		Vector3(0.5, -0.5, -0.5), Vector3(-0.5, -0.5, -0.5),
		Vector3(-0.5, 0.5, -0.5), Vector3(0.5, 0.5, -0.5),
	])
	return s


static func _quad(st: SurfaceTool, v: Array, n: Vector3) -> void:
	var uv: Array = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(v[i])


static func _tri(st: SurfaceTool, v: Array, n: Vector3) -> void:
	var uv: Array = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]
	for i in 3:
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(v[i])
