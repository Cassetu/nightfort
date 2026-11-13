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
static var _conifer_material: ShaderMaterial
static var _trunk_material: StandardMaterial3D
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


static func mesh_count() -> int:
	_ensure_meshes()
	return _meshes.size()


static func far_mesh(index: int) -> ArrayMesh:
	_ensure_meshes()
	return _meshes[index % _meshes.size()]


static func _ensure_meshes() -> void:
	if not _meshes.is_empty():
		return

	_leaf_shader = load("res://resources/leaf_cards.gdshader")
	_material = _card_material(_leaf_texture())
	_conifer_material = _card_material(_conifer_texture())
	_trunk_material = TileArt.uv_material("wood", TRUNK_COLOR, Vector3(2.0, 2.0, 1.0))

	for i in LEAF_COLORS.size():
		_meshes.append(_make_crown(LEAF_COLORS[i], i))
	for i in SPRUCE_COLORS.size():
		_meshes.append(_make_spruce(SPRUCE_COLORS[i], i))


static func _card_material(tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _leaf_shader
	m.set_shader_parameter("card_tex", tex)
	return m


static func _leaf_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var src := TileArt.tile_image("leaves", Color(0.2, 0.4, 0.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for n in 120:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 27.0
		var cx := 32.0 + cos(a) * r
		var cy := 32.0 + sin(a) * r * 0.85
		var radius := rng.randf_range(2.2, 4.6)
		var depth := clampf((cy - 4.0) / 56.0, 0.0, 1.0)
		var shade := lerpf(1.18, 0.62, depth) * rng.randf_range(0.88, 1.1)
		var base := src.get_pixel(rng.randi() % src.get_width(), rng.randi() % src.get_height())
		var col := Color(base.r * shade, base.g * shade, base.b * shade, 1.0)
		for y in range(int(cy - radius) - 1, int(cy + radius) + 2):
			for x in range(int(cx - radius) - 1, int(cx + radius) + 2):
				if x < 0 or y < 0 or x >= size or y >= size:
					continue
				var d := Vector2(float(x) - cx, float(y) - cy).length()
				if d <= radius:
					var rim := 0.82 if d > radius - 1.0 else 1.0
					img.set_pixel(x, y, Color(col.r * rim, col.g * rim, col.b * rim, 1.0))
	return ImageTexture.create_from_image(img)


static func _conifer_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var src := TileArt.tile_image("leaves", Color(0.2, 0.4, 0.2))
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for y in size:
		var band := float(y % 14) / 14.0
		var half := 3.0 + float(y) * 0.44 + (1.0 - band) * 4.5
		for x in size:
			var dx := absf(float(x) - 31.5)
			var jag := rng.randf() * 2.2
			if dx > half - jag:
				continue
			var base := src.get_pixel((x * 3) % src.get_width(), (y * 3) % src.get_height())
			var shade := lerpf(1.15, 0.6, clampf(band * 0.9 + dx / 70.0, 0.0, 1.0)) * rng.randf_range(0.9, 1.08)
			img.set_pixel(x, y, Color(base.r * shade, base.g * shade, base.b * shade, 1.0))
	return ImageTexture.create_from_image(img)


static func _card(buf: Dictionary, center: Vector3, right: Vector3, up: Vector3, half_w: float, half_h: float, normal: Vector3, color: Color) -> void:
	var verts: PackedVector3Array = buf["verts"]
	var norms: PackedVector3Array = buf["norms"]
	var cols: PackedColorArray = buf["cols"]
	var uvs: PackedVector2Array = buf["uvs"]
	var indices: PackedInt32Array = buf["indices"]
	var o := verts.size()
	verts.append(center - right * half_w + up * half_h)
	verts.append(center + right * half_w + up * half_h)
	verts.append(center + right * half_w - up * half_h)
	verts.append(center - right * half_w - up * half_h)
	uvs.append(Vector2(0.0, 0.0))
	uvs.append(Vector2(1.0, 0.0))
	uvs.append(Vector2(1.0, 1.0))
	uvs.append(Vector2(0.0, 1.0))
	for i in 4:
		norms.append(normal)
		cols.append(color)
	indices.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))
	buf["verts"] = verts
	buf["norms"] = norms
	buf["cols"] = cols
	buf["uvs"] = uvs
	buf["indices"] = indices


static func _new_buf() -> Dictionary:
	return {"verts": PackedVector3Array(), "norms": PackedVector3Array(), "cols": PackedColorArray(), "uvs": PackedVector2Array(), "indices": PackedInt32Array()}


static func _buf_arrays(buf: Dictionary) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = buf["verts"]
	arrays[Mesh.ARRAY_NORMAL] = buf["norms"]
	arrays[Mesh.ARRAY_COLOR] = buf["cols"]
	arrays[Mesh.ARRAY_TEX_UV] = buf["uvs"]
	arrays[Mesh.ARRAY_INDEX] = buf["indices"]
	return arrays


static func _finish_mesh(buf: Dictionary, material: ShaderMaterial) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _trunk_arrays())
	mesh.surface_set_material(0, _trunk_material)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _buf_arrays(buf))
	mesh.surface_set_material(1, material)
	return mesh


static func _make_crown(leaf: Color, index: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + index
	var buf := _new_buf()
	var tint := Color.from_hsv(leaf.h, 0.22, 0.95)
	var crown := Vector3(0.0, TRUNK_HEIGHT * 0.6 + 2.0, 0.0)
	var layers := [[5, 1.15, 0.7, 1.15], [4, 0.85, 1.7, 1.0], [2, 0.4, 2.65, 0.85]]
	for layer: Array in layers:
		var count: int = layer[0]
		for i in count:
			var a := TAU * (float(i) + rng.randf() * 0.6) / float(count)
			var r: float = float(layer[1]) * rng.randf_range(0.8, 1.1)
			var c := Vector3(cos(a) * r, TRUNK_HEIGHT * 0.6 + float(layer[2]) + rng.randf_range(-0.15, 0.15), sin(a) * r)
			var half: float = float(layer[3]) * rng.randf_range(0.9, 1.15)
			var height_k := clampf((c.y - TRUNK_HEIGHT * 0.6) / 3.0, 0.0, 1.0)
			var color := tint.lightened(0.14 * height_k)
			var outward := (c - crown).normalized()
			var yaw := rng.randf() * PI
			var right_a := Vector3(cos(yaw), 0.0, sin(yaw))
			var right_b := Vector3(-sin(yaw), 0.0, cos(yaw))
			_card(buf, c, right_a, Vector3.UP, half, half * 0.9, outward, color)
			_card(buf, c, right_b, Vector3.UP, half, half * 0.9, outward, color)
			var flat_right := Vector3(cos(yaw + 0.8), 0.0, sin(yaw + 0.8))
			var flat_up := Vector3(-sin(yaw + 0.8), 0.0, cos(yaw + 0.8))
			_card(buf, c + Vector3(0.0, 0.08, 0.0), flat_right, flat_up, half, half, Vector3.UP, color.lightened(0.05))
	return _finish_mesh(buf, _material)


static func _make_spruce(leaf: Color, index: int) -> ArrayMesh:
	var buf := _new_buf()
	var tiers := 5 + index % 2
	var base := 0.9
	var step := 0.95
	for t in tiers:
		var k := float(t) / float(tiers - 1)
		var radius := lerpf(1.55, 0.45, k)
		var height := 1.9
		var cy := base + height * 0.5 + float(t) * step
		var color := leaf.lerp(SNOW_TINT, 0.2 + 0.3 * k)
		for n in 3:
			var yaw := PI * float(n) / 3.0 + float(t) * 0.5
			var right := Vector3(cos(yaw), 0.0, sin(yaw))
			_card(buf, Vector3(0.0, cy, 0.0), right, Vector3.UP, radius, height * 0.5, Vector3.UP, color)
	return _finish_mesh(buf, _conifer_material)


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
