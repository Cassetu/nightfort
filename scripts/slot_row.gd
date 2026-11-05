extends HBoxContainer

signal action_pressed(slot)
signal delete_pressed(slot)

@export var slot: int = 0

@onready var info_label = $Info
@onready var action_button = $Action
@onready var delete_button = $Delete


func _ready() -> void:
	action_button.pressed.connect(_on_action)
	delete_button.pressed.connect(_on_delete)


func show_info(info: Dictionary, mode: String) -> void:
	info_label.text = "Slot %d     %s" % [slot + 1, _describe(info)]
	action_button.text = "Save" if mode == "save" else "Load"
	action_button.disabled = mode == "load" and not info["exists"]
	delete_button.disabled = not info["exists"]


func _describe(info: Dictionary) -> String:
	if not info["exists"]:
		return "Empty"
	var stamp: String = info["saved_at"]
	var mode: String = str(info.get("mode", "survival")).capitalize()
	return "%s  -  Seed %d  -  %s played  -  %s" % [mode, info["seed"], _format_time(info["play_time"]), stamp.substr(0, 16)]


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	if hours > 0:
		return "%dh %02dm" % [hours, minutes]
	return "%dm" % minutes


func _on_action() -> void:
	action_pressed.emit(slot)


func _on_delete() -> void:
	delete_pressed.emit(slot)
