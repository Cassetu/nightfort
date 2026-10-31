extends Node

signal changed(item: String, count: int)

var items: Dictionary = {}


func add(item: String, amount: int) -> void:
	items[item] = get_count(item) + amount
	changed.emit(item, items[item])


func get_count(item: String) -> int:
	return items.get(item, 0)


func spend(item: String, amount: int) -> bool:
	if get_count(item) < amount:
		return false
	items[item] = get_count(item) - amount
	changed.emit(item, items[item])
	return true
