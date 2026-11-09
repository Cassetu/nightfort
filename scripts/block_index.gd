extends RefCounted

static var list: Array = []
static var slots: Dictionary = {}
static var version: int = 0


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
