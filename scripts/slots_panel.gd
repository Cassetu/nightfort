extends PanelContainer

signal back_requested

var mode: String = "load"

@onready var title_label = %Title
@onready var status_label = %Status
@onready var rows = %Rows
@onready var back_button = %Back


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	for row in rows.get_children():
		row.action_pressed.connect(_on_action)
		row.delete_pressed.connect(_on_delete)


func open(new_mode: String) -> void:
	mode = new_mode
	title_label.text = "Save Game" if mode == "save" else "Load Game"
	status_label.text = ""
	refresh()
	show()


func refresh() -> void:
	for row in rows.get_children():
		row.show_info(Game.slot_info(row.slot), mode)


func _on_action(slot: int) -> void:
	if mode == "save":
		if Game.save_game(slot):
			status_label.text = "Saved to slot %d." % (slot + 1)
		else:
			status_label.text = "Save failed."
		refresh()
		return
	if not Game.load_game(slot):
		status_label.text = "That save could not be read."


func _on_delete(slot: int) -> void:
	Game.delete_slot(slot)
	status_label.text = "Deleted slot %d." % (slot + 1)
	refresh()


func _on_back() -> void:
	back_requested.emit()
