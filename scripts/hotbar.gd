extends Control

@onready var title: Label = $Title
@onready var slot_nodes: Array = $Slots.get_children()


func _ready() -> void:
	Inventory.changed.connect(_refresh)
	Inventory.selection_changed.connect(_refresh)
	_refresh()


func _refresh(_index: int = 0) -> void:
	for i in slot_nodes.size():
		slot_nodes[i].show_item(Inventory.slots[i])
		slot_nodes[i].set_state(i == Inventory.selected, false)
	var item: Dictionary = Inventory.slots[Inventory.selected]
	if item.is_empty():
		title.text = ""
	else:
		title.text = Inventory.item_name(item["id"])
