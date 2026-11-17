extends "res://scripts/blocks/block.gd"

const MOVE_LAYER := 1024
const BAR := 0.16
const TOP := 0.2


func _build() -> void:
	var mat := TileArt.uv_material("stone_brick", Color(0.55, 0.55, 0.6), Vector3.ONE)
	var top := MeshInstance3D.new()
	top.mesh = TileArt.box_mesh(Vector3(1.0, TOP, 1.0), mat)
	top.position = Vector3(0.0, 0.5 - TOP * 0.5, 0.0)
	visual.add_child(top)

	var bar_mesh := TileArt.box_mesh(Vector3(BAR, 1.0 - TOP, BAR), mat)
	var offset := 0.5 - BAR * 0.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var bar := MeshInstance3D.new()
			bar.mesh = bar_mesh
			bar.position = Vector3(sx * offset, -TOP * 0.5, sz * offset)
			visual.add_child(bar)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	col.shape = box
	add_child(col)
	collision_layer = MOVE_LAYER
