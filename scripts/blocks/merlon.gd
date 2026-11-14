extends "res://scripts/blocks/block.gd"

const MerlonMesh = preload("res://scripts/blocks/merlon_mesh.gd")


func _build() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MerlonMesh.build(_material_for(block_type))
	visual.add_child(mi)
	body_mesh = mi
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	add_child(col)
	set_process(false)
