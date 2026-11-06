extends RefCounted


static func build(thickness: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var lo := -0.5 - thickness * 0.5
	var hi := 0.5 + thickness * 0.5
	var mid_lo := -0.5 + thickness * 0.5
	var mid_hi := 0.5 - thickness * 0.5
	var bars: Array = []
	for a in [0, 1]:
		for b in [0, 1]:
			var p: float = lo if a == 0 else mid_hi
			var q: float = lo if b == 0 else mid_hi
			var pe: float = mid_lo if a == 0 else hi
			var qe: float = mid_lo if b == 0 else hi
			bars.append([Vector3(lo, p, q), Vector3(hi, pe, qe)])
			bars.append([Vector3(p, lo, q), Vector3(pe, hi, qe)])
			bars.append([Vector3(p, q, lo), Vector3(pe, qe, hi)])
	for bar: Array in bars:
		_add_box(verts, normals, indices, bar[0], bar[1])
	var data: Array = []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = verts
	data[Mesh.ARRAY_NORMAL] = normals
	data[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	return mesh


static func _add_box(verts: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, a: Vector3, b: Vector3) -> void:
	var faces := [
		[Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z), Vector3(0, 0, 1)],
		[Vector3(b.x, a.y, a.z), Vector3(a.x, a.y, a.z), Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(0, 0, -1)],
		[Vector3(a.x, a.y, a.z), Vector3(a.x, a.y, b.z), Vector3(a.x, b.y, b.z), Vector3(a.x, b.y, a.z), Vector3(-1, 0, 0)],
		[Vector3(b.x, a.y, b.z), Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(1, 0, 0)],
		[Vector3(a.x, b.y, b.z), Vector3(b.x, b.y, b.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z), Vector3(0, 1, 0)],
		[Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z), Vector3(0, -1, 0)],
	]
	for face: Array in faces:
		var base := verts.size()
		for i in 4:
			verts.push_back(face[i])
			normals.push_back(face[4])
		for offset: int in [0, 1, 2, 0, 2, 3]:
			indices.push_back(base + offset)
