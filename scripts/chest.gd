extends "res://scripts/blocks/block.gd"

const SLOT_TOTAL := 18

var items: Array = []


func _configure() -> void:
	super()
	add_to_group("chest")
	items.clear()
	for i in SLOT_TOTAL:
		items.append({})


func _build() -> void:
	super()
	body_mesh.scale = Vector3(0.94, 0.62, 0.94)
	body_mesh.position = Vector3(0.0, -0.19, 0.0)
	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(0.98, 0.3, 0.98)
	lid_mesh.material = TileArt.block_material("chest_top", Color(0.5, 0.34, 0.18))
	lid.mesh = lid_mesh
	lid.position = Vector3(0.0, 0.27, 0.0)
	visual.add_child(lid)
	var latch := MeshInstance3D.new()
	var latch_mesh := BoxMesh.new()
	latch_mesh.size = Vector3(0.16, 0.2, 0.05)
	var latch_mat := StandardMaterial3D.new()
	latch_mat.albedo_color = Color(0.62, 0.64, 0.68)
	latch_mat.metallic = 0.6
	latch_mat.roughness = 0.4
	latch_mesh.material = latch_mat
	latch.mesh = latch_mesh
	latch.position = Vector3(0.0, 0.14, 0.48)
	visual.add_child(latch)


func _die() -> void:
	var world := get_tree().current_scene
	if world != null and world.has_method("spawn_drop"):
		for item: Dictionary in items:
			if not item.is_empty():
				world.spawn_drop(item["id"], int(item["count"]), global_position + Vector3(0.0, 0.9, 0.0))
	items.clear()
	for i in SLOT_TOTAL:
		items.append({})
	super()
