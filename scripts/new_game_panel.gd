extends PanelContainer

signal back_requested
signal start_requested(seed_text, mode, name_text, level)

@onready var seed_edit = %Seed
@onready var name_edit = %WorldName
@onready var start_button = %Start
@onready var back_button = %Back
@onready var survival_button = %Survival
@onready var creative_button = %Creative
@onready var easy_button = %Easy
@onready var normal_button = %Normal
@onready var hard_button = %Hard


func _ready() -> void:
	start_button.pressed.connect(_on_start)
	back_button.pressed.connect(_on_back)
	seed_edit.text_submitted.connect(_on_submitted)
	name_edit.text_submitted.connect(_on_submitted)
	visibility_changed.connect(_on_visibility)


func _on_visibility() -> void:
	if is_visible_in_tree():
		seed_edit.clear()
		name_edit.clear()
		survival_button.button_pressed = true
		normal_button.button_pressed = true
		name_edit.grab_focus()


func _on_start() -> void:
	start_requested.emit(seed_edit.text, _mode(), name_edit.text, _level())


func _on_submitted(text: String) -> void:
	start_requested.emit(seed_edit.text, _mode(), name_edit.text, _level())


func _on_back() -> void:
	back_requested.emit()


func _mode() -> String:
	return "creative" if creative_button.button_pressed else "survival"


func _level() -> String:
	if easy_button.button_pressed:
		return "easy"
	if hard_button.button_pressed:
		return "hard"
	return "normal"
