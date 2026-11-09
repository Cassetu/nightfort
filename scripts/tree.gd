extends "res://scripts/resource_node.gd"

const TileArt = preload("res://scripts/tile_art.gd")

const LEAF_COLORS := [
	Color(0.13, 0.36, 0.17),
	Color(0.17, 0.42, 0.20),
	Color(0.11, 0.30, 0.16),
	Color(0.22, 0.42, 0.14),
	Color(0.10, 0.33, 0.24),
]

const SPRUCE_COLORS := [
	Color(0.52, 0.72, 0.68),
	Color(0.46, 0.66, 0.66),
	Color(0.58, 0.74, 0.64),
]
const SNOW_TINT := Color(0.93, 0.95, 0.98)

const TRUNK_COLOR := Color(0.30, 0.20, 0.12)
const TRUNK_HEIGHT := 2.4
const TRUNK_RADIUS := 0.28

var size_factor: float = 1.0
var variant: int = 0

static var _meshes: Array = []
static var _material: ShaderMaterial
static var _trunk_material: StandardMaterial3D
static var _snow_material: ShaderMaterial
static var _leaf_shader: Shader


func _configure() -> void:
	resource_type = "wood"
	chip_color = Color(0.45, 0.3, 0.16)
	chip_tile = "wood"
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

	_leaf_shader = load("res://resources/leaves.gdshader")
	_material = _shader_material("leaves", LEAF_COLORS[0], Vector2(4.0, 3.0), true)

	_trunk_material = TileArt.uv_material("wood", TRUNK_COLOR, Vector3(2.0, 2.0, 1.0))

	_snow_material = _shader_material("snow", SNOW_TINT, Vector2(2.0, 2.0), false)

	for leaf: Color in LEAF_COLORS:
		_meshes.append(_make_mesh(leaf))
	for i in SPRUCE_COLORS.size():
		_meshes.append(_make_spruce(SPRUCE_COLORS[i], i))


static func _shader_material(tile_name: String, fallback: Color, uv_scale: Vector2, leafy: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _leaf_shader
	m.set_shader_parameter("albedo_tex", TileArt.uv_material(tile_name, fallback, Vector3(1.0, 1.0, 1.0), true).albedo_texture)
	m.set_shader_parameter("uv_scale", uv_scale)
	m.set_shader_parameter("ragged", 1.0 if leafy else 0.0)
	return m


static func _make_spruce(leaf: Color, index: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var s_verts := PackedVector3Array()
	var s_norms := PackedVector3Array()
	var s_cols := PackedColorArray()
	var s_uvs := PackedVector2Array()
	var s_indices := PackedInt32Array()

	var tiers := 5 + index % 2
	var base := 0.9
	var step := 0.95
	for t in tiers:
		var k := float(t) / float(tiers - 1)
		var radius := lerpf(1.55, 0.45, k)
		var height := 1.9
		var cy := base + height * 0.5 + float(t) * step
		var shade := leaf.lightened(0.05 * k)
		_append_part(verts, norms, cols, uvs, indices, 0.0, radius, height, cy, shade)
		var cap_h := height * 0.55
		_append_part(s_verts, s_norms, s_cols, s_uvs, s_indices, 0.0, radius * 0.55 * 1.08, cap_h, cy + height * 0.5 - cap_h * 0.5 + 0.02, SNOW_TINT)

	var needle_arrays := []
	needle_arrays.resize(Mesh.ARRAY_MAX)
	needle_arrays[Mesh.ARRAY_VERTEX] = verts
	needle_arrays[Mesh.ARRAY_NORMAL] = norms
	needle_arrays[Mesh.ARRAY_COLOR] = cols
	needle_arrays[Mesh.ARRAY_TEX_UV] = uvs
	needle_arrays[Mesh.ARRAY_INDEX] = indices

	var snow_arrays := []
	snow_arrays.resize(Mesh.ARRAY_MAX)
	snow_arrays[Mesh.ARRAY_VERTEX] = s_verts
	snow_arrays[Mesh.ARRAY_NORMAL] = s_norms
	snow_arrays[Mesh.ARRAY_COLOR] = s_cols
	snow_arrays[Mesh.ARRAY_TEX_UV] = s_uvs
	snow_arrays[Mesh.ARRAY_INDEX] = s_indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _trunk_arrays())
	mesh.surface_set_material(0, _trunk_material)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, needle_arrays)
	mesh.surface_set_material(1, _material)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, snow_arrays)
	mesh.surface_set_material(2, _snow_material)
	return mesh


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
	cylinder.radial_segments = 12
	cylinder.rings = 3
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
