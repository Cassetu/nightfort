extends "res://scripts/blocks/torch.gd"

const CAP_SIZE := Vector3(0.36, 0.1, 0.36)


func _init() -> void:
	block_type = "lantern"


func _build() -> void:
	super()
	base_mesh.mesh = TileArt.box_mesh(Vector3(0.125, 0.62, 0.125), TileArt.uv_material("torch_base", Color(0.2, 0.18, 0.17), Vector3.ONE))
	base_mesh.position = Vector3(0.0, -0.08, 0.0)
	var flame: Node3D = get_node("Flame")
	flame.position = Vector3(0.0, 0.3, 0.0)
	particles.position = Vector3(0.0, 0.33, 0.0)
	light.position = Vector3(0.0, 0.2, 0.0)
	fill.position = Vector3(0.0, 0.2, 0.0)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.55, 0.57, 0.62)
	iron.metallic = 0.7
	iron.roughness = 0.4
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = CAP_SIZE
	cap_mesh.material = iron
	for y in [-0.45, 0.45]:
		var cap := MeshInstance3D.new()
		cap.mesh = cap_mesh
		cap.position = Vector3(0.0, y, 0.0)
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(cap)
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(0.03, 0.8, 0.03)
	bar_mesh.material = iron
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var bar := MeshInstance3D.new()
			bar.mesh = bar_mesh
			bar.position = Vector3(sx * 0.15, 0.0, sz * 0.15)
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			visual.add_child(bar)
