extends "res://scripts/resource_node.gd"

var block_type: String = "wood"

static var _materials: Dictionary = {}


func _configure() -> void:
	var info: Dictionary = Inventory.BLOCK_TYPES[block_type]
	resource_type = info["resource"]
	resource_amount = Inventory.BLOCK_COST
	max_health = info["health"]
	chip_color = info["color"]
	add_to_group("block")


func _build() -> void:
	var mesh := BoxMesh.new()
	mesh.material = _material_for(block_type)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	visual.add_child(mi)

	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	add_child(col)


static func _material_for(type: String) -> StandardMaterial3D:
	if not _materials.has(type):
		var m := StandardMaterial3D.new()
		m.albedo_color = Inventory.BLOCK_TYPES[type]["color"]
		m.roughness = 0.9
		_materials[type] = m
	return _materials[type]
