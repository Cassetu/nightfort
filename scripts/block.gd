extends "res://scripts/resource_node.gd"

const TileArt = preload("res://scripts/tile_art.gd")

const SUPPORT_INTERVAL := 0.25

var block_type: String = "wood"
var needs_support: bool = false
var support_timer: float = 0.0
var terrain

static var _materials: Dictionary = {}


func _configure() -> void:
	var info: Dictionary = Inventory.BLOCK_TYPES[block_type]
	resource_type = info["resource"]
	resource_amount = Inventory.BLOCK_COST
	max_health = info["health"]
	chip_color = info["color"]
	add_to_group("block")
	terrain = get_tree().get_first_node_in_group("terrain")


func _build() -> void:
	var mesh := BoxMesh.new()
	mesh.material = _material_for(block_type)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	visual.add_child(mi)

	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	add_child(col)


func _process(delta: float) -> void:
	if not needs_support or dying:
		return
	support_timer += delta
	if support_timer < SUPPORT_INTERVAL:
		return
	support_timer = 0.0
	if not _supported():
		take_damage(max_health)


func _supported() -> bool:
	var cx := floori(global_position.x)
	var cy := floori(global_position.y)
	var cz := floori(global_position.z)
	if terrain != null and terrain.block_at(cx, cy - 1, cz) != 0:
		return true
	var below := Vector3(cx + 0.5, cy - 0.5, cz + 0.5)
	for n in get_tree().get_nodes_in_group("block"):
		if n != self and not n.dying and n.covers(below):
			return true
	return false


func covers(p: Vector3) -> bool:
	var d := (p - global_position).abs()
	return d.x < 0.6 and d.y < 0.6 and d.z < 0.6


static func _material_for(type: String) -> StandardMaterial3D:
	if not _materials.has(type):
		var info: Dictionary = Inventory.BLOCK_TYPES[type]
		_materials[type] = TileArt.block_material(info.get("tile", type), info["color"])
	return _materials[type]
