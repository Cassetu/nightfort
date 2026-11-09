extends PanelContainer

signal back_requested

var mode: String = "load"
var tab: String = "saves"
var pending: Dictionary = {}

@onready var title_label = %Title
@onready var status_label = %Status
@onready var rows = %Rows
@onready var backup_rows = %BackupRows
@onready var tabs = %Tabs
@onready var saves_tab = %SavesTab
@onready var backups_tab = %BackupsTab
@onready var confirm = %Confirm
@onready var confirm_detail = %ConfirmDetail
@onready var yes_button = %Yes
@onready var no_button = %No
@onready var back_button = %Back


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	saves_tab.pressed.connect(_set_tab.bind("saves"))
	backups_tab.pressed.connect(_set_tab.bind("backups"))
	yes_button.pressed.connect(_on_yes)
	no_button.pressed.connect(_on_no)
	for row in rows.get_children():
		row.action_pressed.connect(_on_action)
		row.delete_pressed.connect(_on_delete)
	for row in backup_rows.get_children():
		row.action_pressed.connect(_on_action)
		row.delete_pressed.connect(_on_delete)


func open(new_mode: String) -> void:
	mode = new_mode
	tab = "saves"
	pending = {}
	title_label.text = "Save Game" if mode == "save" else "Load Game"
	status_label.text = ""
	saves_tab.button_pressed = true
	refresh()
	show()


func _set_tab(tab_name: String) -> void:
	tab = tab_name
	status_label.text = ""
	refresh()


func refresh() -> void:
	var asking := not pending.is_empty()
	for row in rows.get_children():
		row.show_info(Game.slot_info(row.slot, false), mode)
	for row in backup_rows.get_children():
		row.show_info(Game.slot_info(row.slot, true), mode)
	tabs.visible = mode == "load" and not asking
	rows.visible = tab == "saves" and not asking
	backup_rows.visible = tab == "backups" and mode == "load" and not asking
	status_label.visible = not asking
	back_button.visible = not asking
	confirm.visible = asking


func _slot_label(slot: int, backup: bool) -> String:
	var info: Dictionary = Game.slot_info(slot, backup)
	var prefix := "Backup" if backup else "Slot"
	var label := "%s %d" % [prefix, slot + 1]
	if info["exists"]:
		label += "  -  %s" % str(info["name"])
	return label


func _on_action(slot: int, backup: bool) -> void:
	if mode == "save":
		if Game.slot_info(slot, false)["exists"]:
			_ask("save", slot, backup, "Overwrite")
		else:
			_do_save(slot)
		return
	_ask("load", slot, backup, "Load")


func _ask(action: String, slot: int, backup: bool, verb: String) -> void:
	pending = {"action": action, "slot": slot, "backup": backup}
	confirm_detail.text = "%s  %s" % [verb, _slot_label(slot, backup)]
	refresh()
	no_button.grab_focus()


func _on_yes() -> void:
	var task := pending
	pending = {}
	refresh()
	if task.is_empty():
		return
	if task["action"] == "save":
		_do_save(int(task["slot"]))
	elif task["action"] == "delete":
		Game.delete_slot(int(task["slot"]), bool(task["backup"]))
		status_label.text = "Deleted %s %d." % ["backup" if bool(task["backup"]) else "slot", int(task["slot"]) + 1]
		refresh()
	else:
		if not Game.load_game(int(task["slot"]), bool(task["backup"])):
			status_label.text = "That save could not be read."


func _on_no() -> void:
	pending = {}
	refresh()


func _do_save(slot: int) -> void:
	if Game.save_game(slot):
		status_label.text = "Saved to slot %d." % (slot + 1)
	else:
		status_label.text = "Save failed."
	refresh()


func _on_delete(slot: int, backup: bool) -> void:
	_ask("delete", slot, backup, "Delete")


func _on_back() -> void:
	back_requested.emit()
