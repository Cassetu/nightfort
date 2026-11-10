extends RefCounted

const MAX_STOCK := 64

static var stock: Dictionary = {}


static func take(key: String, factory: Callable) -> Node:
	var list: Array = stock.get(key, [])
	while not list.is_empty():
		var node = list.pop_back()
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			return node
	return factory.call()


static func give(key: String, node: Node) -> void:
	if not is_instance_valid(node):
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	var list: Array = stock.get(key, [])
	if list.size() >= MAX_STOCK:
		node.queue_free()
		return
	list.append(node)
	stock[key] = list
