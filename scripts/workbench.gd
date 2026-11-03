extends "res://scripts/block.gd"


func _configure() -> void:
	super()
	add_to_group("workbench")


func _build() -> void:
	super()
	var top_mat: StandardMaterial3D = TileArt.block_material("workbench_top", Color(0.36, 0.22, 0.1))

	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(1.04, 0.14, 1.04)
	slab_mesh.material = top_mat
	slab.mesh = slab_mesh
	slab.position = Vector3(0.0, 0.5, 0.0)
	visual.add_child(slab)

	var tool_mat := StandardMaterial3D.new()
	tool_mat.albedo_color = Color(0.7, 0.72, 0.76)
	tool_mat.metallic = 0.7
	tool_mat.roughness = 0.35

	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.34, 0.12, 0.12)
	head_mesh.material = tool_mat
	head.mesh = head_mesh
	head.position = Vector3(-0.15, 0.63, 0.1)
	visual.add_child(head)

	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.08, 0.08, 0.4)
	handle_mesh.material = top_mat
	handle.mesh = handle_mesh
	handle.position = Vector3(0.12, 0.62, 0.1)
	visual.add_child(handle)
