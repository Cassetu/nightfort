extends Node

signal changed(item: String, count: int)
signal selection_changed(index: int)

const SLOT_COUNT := 6
const BLOCK_COST := 1

const BLOCK_TYPES := {
	"wood": {"name": "Wood Block", "resource": "wood", "health": 3, "color": Color(0.58, 0.40, 0.22)},
	"stone": {"name": "Stone Block", "resource": "stone", "health": 6, "color": Color(0.62, 0.62, 0.65)},
}

var items: Dictionary = {}
var hotbar: Array = [
	{"kind": "block", "type": "wood"},
	{"kind": "block", "type": "stone"},
	{},
	{},
	{},
	{},
]
var selected: int = 0


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


func select_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT or index == selected:
		return
	selected = index
	selection_changed.emit(index)


func get_selected() -> Dictionary:
	return hotbar[selected]


func held_block_type() -> String:
	var slot: Dictionary = hotbar[selected]
	if slot.get("kind", "") == "block":
		return slot["type"]
	return ""
