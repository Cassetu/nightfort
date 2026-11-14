extends RefCounted

const STAGES := 10
const SIZE := 1.01
const SALT := 77
const BASE_THRESHOLD := 0.05
const STEP_THRESHOLD := 0.065
const CRACK_COLOR := Color(0.0, 0.0, 0.0, 0.7)

static var stage_materials: Array = []
static var cube: BoxMesh


static func _hash(x: int, y: int, z: int) -> float:
	var n := (x * 73856093) ^ (y * 83492791) ^ (z * 19349663) ^ (SALT * 2654435761)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n >> 8) & 0xFFFF) / 65535.0


static func materials() -> Array:
	if not stage_materials.is_empty():
		return stage_materials
	for stage in STAGES:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		var threshold := BASE_THRESHOLD + STEP_THRESHOLD * float(stage)
		for py in 16:
			for px in 16:
				if _hash(px, py, SALT) < threshold:
					img.set_pixel(px, py, CRACK_COLOR)
				else:
					img.set_pixel(px, py, Color(0.0, 0.0, 0.0, 0.0))
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		stage_materials.append(mat)
	return stage_materials


static func stage_for(fraction: float) -> int:
	return clampi(int(fraction * float(STAGES)), 0, STAGES - 1)


static func show(parent: Node3D, existing: MeshInstance3D, fraction: float) -> MeshInstance3D:
	var mats := materials()
	var node := existing
	if node == null or not is_instance_valid(node):
		if cube == null:
			cube = BoxMesh.new()
			cube.size = Vector3.ONE * SIZE
		node = MeshInstance3D.new()
		node.mesh = cube
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
	node.material_override = mats[stage_for(fraction)]
	return node
