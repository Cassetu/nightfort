extends RefCounted

const SIZE := 16

static var materials: Dictionary = {}
static var textures: Dictionary = {}


static func apply(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			_skin(child as MeshInstance3D)
		apply(child)


static func _skin(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var source: Material = mi.get_surface_override_material(0)
	if source == null:
		source = mi.mesh.surface_get_material(0)
	if not (source is StandardMaterial3D):
		return
	var base := source as StandardMaterial3D
	if base.albedo_texture != null:
		return
	var key := "%d_%d_%d" % [roundi(base.albedo_color.r * 255.0), roundi(base.albedo_color.g * 255.0), roundi(base.albedo_color.b * 255.0)]
	if not materials.has(key):
		materials[key] = _make(base, _kind(base.albedo_color))
	mi.set_surface_override_material(0, materials[key])


static func _kind(c: Color) -> String:
	var hi := maxf(c.r, maxf(c.g, c.b))
	var lo := minf(c.r, minf(c.g, c.b))
	if c.r > c.g * 2.0 and c.r > c.b * 2.0:
		return "cloth"
	if c.r > 0.55 and c.b < c.r * 0.45:
		return "gold"
	if c.r > 0.6 and c.b > c.r * 0.55 and c.r > c.g:
		return "skin"
	if c.g > c.r and c.g > c.b:
		return "cloth"
	if c.r > c.g and c.b < c.r * 0.8:
		return "leather"
	if hi - lo < 0.1 and hi > 0.45:
		return "metal"
	if hi < 0.35:
		return "cloth"
	return "metal"


static func _make(base: StandardMaterial3D, kind: String) -> StandardMaterial3D:
	var m := base.duplicate() as StandardMaterial3D
	m.albedo_texture = _texture(kind)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	match kind:
		"metal":
			m.metallic = 0.3
			m.roughness = 0.5
		"gold":
			m.metallic = 0.45
			m.roughness = 0.45
		_:
			m.metallic = 0.0
			m.roughness = 0.9
	return m


static func _texture(kind: String) -> ImageTexture:
	if textures.has(kind):
		return textures[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var img := Image.create(SIZE, SIZE, true, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var v := 0.9 + rng.randf_range(-0.05, 0.05)
			match kind:
				"metal":
					v += (0.04 if y % 4 == 0 else 0.0) + rng.randf_range(-0.04, 0.04)
					if x == 0 or y == 0 or x == SIZE - 1 or y == SIZE - 1:
						v -= 0.18
					if (x == 2 or x == SIZE - 3) and (y == 2 or y == SIZE - 3):
						v -= 0.3
					if rng.randf() < 0.03:
						v -= 0.25
				"gold":
					v += (0.06 if (x + y) % 5 == 0 else 0.0)
					if x == 0 or y == 0 or x == SIZE - 1 or y == SIZE - 1:
						v -= 0.15
					if rng.randf() < 0.05:
						v += 0.1
				"cloth":
					v -= 0.08 if (x + y) % 2 == 0 else 0.0
					if y % 6 == 0:
						v -= 0.06
					if rng.randf() < 0.04:
						v -= 0.18
				"leather":
					v += (-0.1 if x % 3 == 0 else 0.0) + rng.randf_range(-0.05, 0.05)
					if rng.randf() < 0.03:
						v -= 0.2
				"skin":
					v += rng.randf_range(-0.04, 0.04)
					if rng.randf() < 0.02:
						v -= 0.12
			v = clampf(v, 0.2, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	textures[kind] = tex
	return tex
