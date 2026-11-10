extends "res://scripts/blocks/block.gd"

const RAIL_X := 0.3
const DEPTH := 0.16


func _init() -> void:
	block_type = "ladder"


func _configure() -> void:
	super()
	add_to_group("ladder")
	needs_support = true
	collision_layer = 16
	collision_mask = 0


func _build() -> void:
	var mat := TileArt.uv_material("plank", Color(0.72, 0.55, 0.32), Vector3.ONE)
	var back := -0.5
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.mesh = TileArt.box_mesh(Vector3(0.09, 1.0, 0.07), mat)
		rail.position = Vector3(side * RAIL_X, 0.0, back + 0.05)
		visual.add_child(rail)
	for i in 4:
		var rung := MeshInstance3D.new()
		rung.mesh = TileArt.box_mesh(Vector3(RAIL_X * 2.0, 0.07, 0.05), mat)
		rung.position = Vector3(0.0, -0.375 + 0.25 * i, back + 0.06)
		visual.add_child(rung)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.0, DEPTH)
	col.shape = box
	col.position = Vector3(0.0, 0.0, back + DEPTH * 0.5)
	add_child(col)


func _supported() -> bool:
	var behind := global_position - global_transform.basis.z
	var cell := Vector3i(floori(behind.x), floori(behind.y), floori(behind.z))
	if terrain != null and terrain.block_at(cell.x, cell.y, cell.z) != 0:
		return true
	for n in BlockIndex.list:
		if n != self and not n.dying and n.covers(behind):
			return true
	return false
