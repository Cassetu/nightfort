extends Node

const BlockScript = preload("res://scripts/block.gd")
const BlockIndex = preload("res://scripts/block_index.gd")
const DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const SKY_RANGE := 16
const PER_FRAME := 24
const LIST_REFRESH := 1.0
const WET_ON := 0.03

var terrain
var stability
var blocks: Array = []
var cursor: int = 0
var list_timer: float = 0.0
var was_wet: bool = false


func setup(t) -> void:
	terrain = t


func _process(delta: float) -> void:
	if terrain == null:
		return
	var wet := BlockScript.wet_level > WET_ON
	if not wet:
		if was_wet:
			was_wet = false
			for n in BlockIndex.list.duplicate():
				n.set_wet(false)
		return
	was_wet = true
	if stability == null:
		stability = get_tree().get_first_node_in_group("stability")
		if stability == null:
			return
	list_timer -= delta
	if list_timer <= 0.0 or cursor >= blocks.size():
		list_timer = LIST_REFRESH
		blocks = BlockIndex.list.duplicate()
		cursor = 0
	var end := mini(cursor + PER_FRAME, blocks.size())
	for i in range(cursor, end):
		var n = blocks[i]
		if is_instance_valid(n) and not n.dying and n.body_mesh != null:
			n.set_wet(_exposed(n.cells()[0]))
	cursor = end


func _sky_open(x: int, y: int, z: int) -> bool:
	if terrain.surface_y(x, z) > y + 1:
		return false
	for dy in range(1, SKY_RANGE + 1):
		if stability.cell_map.has(Vector3i(x, y + dy, z)):
			return false
	return true


func _exposed(c: Vector3i) -> bool:
	if _sky_open(c.x, c.y, c.z):
		return true
	for d: Vector3i in DIRS:
		var n: Vector3i = c + d
		if terrain.block_at(n.x, n.y, n.z) != 0 or stability.cell_map.has(n):
			continue
		if _sky_open(n.x, n.y, n.z):
			return true
	return false
