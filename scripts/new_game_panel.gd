extends PanelContainer

signal back_requested
signal start_requested(seed_text)

@onready var seed_edit = %Seed
@onready var start_button = %Start
@onready var back_button = %Back


func _ready() -> void:
	start_button.pressed.connect(_on_start)
	back_button.pressed.connect(_on_back)
	seed_edit.text_submitted.connect(_on_submitted)
	visibility_changed.connect(_on_visibility)


func _on_visibility() -> void:
	if is_visible_in_tree():
		seed_edit.clear()
		seed_edit.grab_focus()


func _on_start() -> void:
	start_requested.emit(seed_edit.text)


func _on_submitted(text: String) -> void:
	start_requested.emit(text)


func _on_back() -> void:
	back_requested.emit()
