extends "res://scripts/resource_node.gd"

const TileArt = preload("res://scripts/tile_art.gd")

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
		var info: Dictionary = Inventory.BLOCK_TYPES[type]
		_materials[type] = TileArt.block_material(info.get("tile", type), info["color"])
	return _materials[type]
