extends RefCounted

static var list: Array = []
static var slots: Dictionary = {}
static var version: int = 0
static var cell_map: Dictionary = {}
static var map_version: int = -1


static func add(block: Node) -> void:
	var id := block.get_instance_id()
	if slots.has(id):
		return
	slots[id] = list.size()
	list.append(block)
	version += 1


static func remove(block: Node) -> void:
	var id := block.get_instance_id()
	if not slots.has(id):
		return
	var idx: int = slots[id]
	var last: Node = list[list.size() - 1]
	list[idx] = last
	slots[last.get_instance_id()] = idx
	list.pop_back()
	slots.erase(id)
	version += 1


static func bump() -> void:
	version += 1


static func at(cell: Vector3i) -> Node:
	if map_version != version:
		_rebuild()
	return cell_map.get(cell)


static func _rebuild() -> void:
	cell_map.clear()
	for n in list:
		if not is_instance_valid(n) or n.dying or n.falling_now:
			continue
		for c: Vector3i in n.cells():
			cell_map[c] = n
	map_version = version
