extends RefCounted

const TILE := 64
const TILE_DIR := "res://art/tiles/"
const ITEM_DIR := "res://art/items/"

static var _images: Dictionary = {}
static var _icons: Dictionary = {}
static var _materials: Dictionary = {}


static func _load_image(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != TILE or img.get_height() != TILE:
		img.resize(TILE, TILE, Image.INTERPOLATE_NEAREST)
	return img


static func tile_image(tile_name: String, fallback: Color) -> Image:
	if _images.has(tile_name):
		return _images[tile_name]
	var img := _load_image(TILE_DIR + tile_name + ".png")
	if img == null:
		img = Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)
		img.fill(fallback)
	_images[tile_name] = img
	return img


static func tile_array(names: Array, fallbacks: Array) -> Texture2DArray:
	var images: Array[Image] = []
	for i in names.size():
		var copy := Image.new()
		copy.copy_from(tile_image(names[i], fallbacks[i]))
		copy.generate_mipmaps()
		images.append(copy)
	var arr := Texture2DArray.new()
	arr.create_from_images(images)
	return arr


static func texture_material(tex: Texture2D, scissor: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 50.0
	m.uv1_offset = Vector3(0.5, 0.5, 0.5)
	m.roughness = 0.95
	if scissor:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	return m


static func block_material(tile_name: String, fallback: Color) -> StandardMaterial3D:
	if _materials.has(tile_name):
		return _materials[tile_name]
	var img := Image.new()
	img.copy_from(tile_image(tile_name, fallback))
	img.generate_mipmaps()
	var m := texture_material(ImageTexture.create_from_image(img), false)
	_materials[tile_name] = m
	return m


static func uv_material(tile_name: String, fallback: Color, uv_scale: Vector3, vertex_tint: bool = false) -> StandardMaterial3D:
	var key := tile_name + "_uv" + ("_vc" if vertex_tint else "")
	if _materials.has(key):
		return _materials[key]
	var img := Image.new()
	img.copy_from(tile_image(tile_name, fallback))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_scale = uv_scale
	if vertex_tint:
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
	m.roughness = 0.95
	_materials[key] = m
	return m


static func texture(tile_name: String, fallback: Color) -> ImageTexture:
	return ImageTexture.create_from_image(tile_image(tile_name, fallback))


static func icon(item_id: String, tile_name: String = "") -> Texture2D:
	if _icons.has(item_id):
		return _icons[item_id]
	var img := _load_image(ITEM_DIR + item_id + ".png")
	if img == null and tile_name != "":
		img = _load_image(TILE_DIR + tile_name + ".png")
	var tex: Texture2D = null
	if img != null:
		tex = ImageTexture.create_from_image(img)
	_icons[item_id] = tex
	return tex


static func box_mesh(size: Vector3, material: Material) -> ArrayMesh:
	var h := size * 0.5
	var faces: Array = [
		[Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3(0, 0, 1), false],
		[Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(0, 0, -1), true],
		[Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(1, 0, 0), false],
		[Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-1, 0, 0), false],
		[Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(0, 1, 0), false],
		[Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(0, -1, 0), false],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var flip: bool = f[5]
		var uvs: Array = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		if flip:
			uvs = [Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(f[4])
			st.set_uv(uvs[i])
			st.add_vertex(f[i])
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	return mesh
