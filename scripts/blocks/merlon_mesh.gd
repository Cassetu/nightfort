extends RefCounted

const TileArt = preload("res://scripts/tile_art.gd")

const BASE_HEIGHT := 0.55
const TOOTH_SIZE := Vector3(0.34, 0.45, 0.34)
const TOOTH_OFFSET := 0.33


static func _append(st: SurfaceTool, mesh: Mesh, xform: Transform3D) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if order.is_empty():
		order = PackedInt32Array(range(verts.size()))
	for i in order:
		st.set_normal(xform.basis * norms[i])
		st.set_uv(uvs[i])
		st.add_vertex(xform * verts[i])


static func build(material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := TileArt.box_mesh(Vector3(1.0, BASE_HEIGHT, 1.0), material)
	_append(st, base, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.5 + BASE_HEIGHT * 0.5, 0.0)))
	var tooth := TileArt.box_mesh(TOOTH_SIZE, material)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_append(st, tooth, Transform3D(Basis.IDENTITY, Vector3(sx * TOOTH_OFFSET, 0.5 - TOOTH_SIZE.y * 0.5, sz * TOOTH_OFFSET)))
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	return mesh
