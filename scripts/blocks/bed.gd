extends "res://scripts/blocks/block.gd"

const FRAME_H := 0.38


func _build() -> void:
	var frame_mat := TileArt.uv_material("plank", Color(0.72, 0.55, 0.32), Vector3.ONE)
	var frame := MeshInstance3D.new()
	frame.mesh = TileArt.box_mesh(Vector3(0.96, FRAME_H, 0.96), frame_mat)
	frame.position = Vector3(0.0, -0.5 + FRAME_H * 0.5, 0.0)
	visual.add_child(frame)
	body_mesh = frame

	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.albedo_color = Color(0.45, 0.16, 0.15)
	cloth_mat.roughness = 1.0
	var cloth := MeshInstance3D.new()
	cloth.mesh = TileArt.box_mesh(Vector3(0.88, 0.12, 0.6), cloth_mat)
	cloth.position = Vector3(0.0, -0.5 + FRAME_H + 0.05, 0.14)
	visual.add_child(cloth)

	var pillow_mat := StandardMaterial3D.new()
	pillow_mat.albedo_color = Color(0.72, 0.68, 0.6)
	pillow_mat.roughness = 1.0
	var pillow := MeshInstance3D.new()
	pillow.mesh = TileArt.box_mesh(Vector3(0.7, 0.1, 0.24), pillow_mat)
	pillow.position = Vector3(0.0, -0.5 + FRAME_H + 0.1, -0.3)
	visual.add_child(pillow)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.96, FRAME_H + 0.1, 0.96)
	col.shape = box
	col.position = Vector3(0.0, -0.5 + (FRAME_H + 0.1) * 0.5, 0.0)
	add_child(col)
	add_to_group("bed")
	set_process(false)
