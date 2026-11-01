extends PanelContainer

signal back_requested

@onready var rows = %Rows
@onready var fullscreen = %Fullscreen
@onready var back_button = %Back


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	fullscreen.toggled.connect(_on_fullscreen)
	visibility_changed.connect(_on_visibility)
	refresh()


func refresh() -> void:
	for row in rows.get_children():
		row.refresh()
	fullscreen.set_pressed_no_signal(Game.settings["fullscreen"])


func _on_visibility() -> void:
	if is_visible_in_tree():
		refresh()
	else:
		Game.save_settings()


func _on_fullscreen(on: bool) -> void:
	Game.set_setting("fullscreen", on)


func _on_back() -> void:
	back_requested.emit()
