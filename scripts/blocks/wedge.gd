extends "res://scripts/blocks/block.gd"

const WedgeMesh = preload("res://scripts/blocks/wedge_mesh.gd")


func _build() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = WedgeMesh.build(_material_for(block_type))
	visual.add_child(mi)
	body_mesh = mi
	var col := CollisionShape3D.new()
	col.shape = WedgeMesh.shape()
	add_child(col)
	set_process(false)


func _decal_shape() -> Mesh:
	return WedgeMesh.build(_get_decal_material())
