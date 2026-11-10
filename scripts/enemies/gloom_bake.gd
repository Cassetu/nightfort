extends RefCounted

const ENABLED := true
const PARTS := ["Body/Torso", "Body/Head", "Body/ArmL/Mesh", "Body/ArmR/Mesh", "Body/LegL/Mesh", "Body/LegR/Mesh"]
const KEEP_GROUP := "no_bake"

static var cache: Dictionary = {}


static func bake(gloom: Node3D) -> void:
	if not ENABLED:
		return
	for path: String in PARTS:
		var root := gloom.get_node_or_null(path)
		if root == null:
			continue
		var mesh: ArrayMesh = cache.get(path)
		if mesh == null:
			mesh = _merge(root)
			cache[path] = mesh
		for child in root.get_children():
			if child is MeshInstance3D and not child.is_in_group(KEEP_GROUP):
				root.remove_child(child)
				child.queue_free()
		if mesh == null:
			continue
		var baked := MeshInstance3D.new()
		baked.name = "Baked"
		baked.mesh = mesh
		root.add_child(baked)


static func _merge(root: Node) -> ArrayMesh:
	var tools: Dictionary = {}
	var order: Array = []
	for child in root.get_children():
		if not (child is MeshInstance3D) or child.is_in_group(KEEP_GROUP):
			continue
		var source := child as MeshInstance3D
		if source.mesh == null:
			continue
		var material: Material = source.mesh.surface_get_material(0)
		if not tools.has(material):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[material] = st
			order.append(material)
		_append(tools[material], source.mesh, source.transform)
	if order.is_empty():
		return null
	var merged := ArrayMesh.new()
	for material in order:
		(tools[material] as SurfaceTool).commit(merged)
		merged.surface_set_material(merged.get_surface_count() - 1, material)
	return merged


static func _append(st: SurfaceTool, mesh: Mesh, xform: Transform3D) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var order: PackedInt32Array = PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		order = arrays[Mesh.ARRAY_INDEX]
	if order.is_empty():
		order = PackedInt32Array(range(verts.size()))
	for i in order:
		st.set_normal((xform.basis * norms[i]).normalized())
		st.set_uv(uvs[i])
		st.add_vertex(xform * verts[i])
