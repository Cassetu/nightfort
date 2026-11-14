extends CanvasLayer

@export var item_scene: PackedScene

@onready var stack: VBoxContainer = %Stack

var manager


func bind(mgr) -> void:
	manager = mgr
	manager.unlocked.connect(_on_unlocked)


func _on_unlocked(id: String) -> void:
	for def: Dictionary in manager.defs():
		if def["id"] != id:
			continue
		var item := item_scene.instantiate()
		stack.add_child(item)
		item.show_for(def, manager.icon_for(def))
		return
