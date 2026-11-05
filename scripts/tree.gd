extends "res://scripts/resource_node.gd"

const TileArt = preload("res://scripts/tile_art.gd")

const LEAF_COLORS := [
	Color(0.13, 0.36, 0.17),
	Color(0.17, 0.42, 0.20),
	Color(0.11, 0.30, 0.16),
	Color(0.22, 0.42, 0.14),
	Color(0.10, 0.33, 0.24),
]

const TRUNK_COLOR := Color(0.30, 0.20, 0.12)
const TRUNK_HEIGHT := 2.4
const TRUNK_RADIUS := 0.28

var size_factor: float = 1.0
var variant: int = 0

static var _meshes: Array = []
static var _material: StandardMaterial3D
static var _trunk_material: StandardMaterial3D


func _configure() -> void:
	resource_type = "wood"
	chip_color = Color(0.45, 0.3, 0.16)
	max_health = maxi(3, roundi(4.0 * size_factor))
	resource_amount = maxi(3, roundi(3.5 * size_factor))
	add_to_group("tree")


func _build() -> void:
	_ensure_meshes()

	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[variant % _meshes.size()]
	mi.scale = Vector3.ONE * size_factor
	visual.add_child(mi)

	var shape := CylinderShape3D.new()
	shape.radius = TRUNK_RADIUS * size_factor * 1.1
	shape.height = TRUNK_HEIGHT * size_factor
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = TRUNK_HEIGHT * size_factor * 0.5
	add_child(col)


func _play_death() -> void:
	var tween := create_tween()
	tween.tween_property(visual, "rotation:x", 1.45, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "scale", Vector3.ZERO, 0.25)
	tween.tween_callback(queue_free)


static func _ensure_meshes() -> void:
	if not _meshes.is_empty():
		return

	_material = TileArt.uv_material("leaves", LEAF_COLORS[0], Vector3(4.0, 3.0, 1.0), true)

	_trunk_material = TileArt.uv_material("wood", TRUNK_COLOR, Vector3(2.0, 2.0, 1.0))

	for leaf: Color in LEAF_COLORS:
		_meshes.append(_make_mesh(leaf))


static func _make_mesh(leaf: Color) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var tint := Color.from_hsv(leaf.h, 0.22, 0.95)
	var base := TRUNK_HEIGHT * 0.6
	_append_part(verts, norms, cols, uvs, indices, 0.0, 1.7, 2.4, base + 1.2, tint)
	_append_part(verts, norms, cols, uvs, indices, 0.0, 1.3, 2.2, base + 2.3, tint.lightened(0.07))
	_append_part(verts, norms, cols, uvs, indices, 0.0, 0.9, 2.0, base + 3.4, tint.lightened(0.14))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _trunk_arrays())
	mesh.surface_set_material(0, _trunk_material)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(1, _material)
	return mesh


static func _trunk_arrays() -> Array:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = TRUNK_RADIUS * 0.75
	cylinder.bottom_radius = TRUNK_RADIUS
	cylinder.height = TRUNK_HEIGHT
	cylinder.radial_segments = 8
	cylinder.rings = 1
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	var arrays := cylinder.get_mesh_arrays()
	var part_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in part_verts.size():
		part_verts[i] += Vector3(0.0, TRUNK_HEIGHT * 0.5, 0.0)
	arrays[Mesh.ARRAY_VERTEX] = part_verts
	return arrays


static func _append_part(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, uvs: PackedVector2Array, indices: PackedInt32Array, top_radius: float, bottom_radius: float, height: float, center_y: float, color: Color) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top_radius
	cylinder.bottom_radius = bottom_radius
	cylinder.height = height
	cylinder.radial_segments = 8
	cylinder.rings = 1
	cylinder.cap_top = false
	cylinder.cap_bottom = false

	var arrays := cylinder.get_mesh_arrays()
	var part_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var part_norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var part_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var part_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	var offset := verts.size()
	for i in part_verts.size():
		verts.append(part_verts[i] + Vector3(0.0, center_y, 0.0))
		norms.append(part_norms[i])
		cols.append(color)
		uvs.append(part_uvs[i])
	for index in part_indices:
		indices.append(offset + index)
