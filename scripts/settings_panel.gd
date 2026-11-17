extends PanelContainer

signal back_requested

@onready var rows = %Rows
@onready var fullscreen = %Fullscreen
@onready var head_bob = %HeadBob
@onready var back_button = %Back


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	fullscreen.toggled.connect(_on_fullscreen)
	head_bob.toggled.connect(_on_head_bob)
	visibility_changed.connect(_on_visibility)
	refresh()


func refresh() -> void:
	for row in rows.get_children():
		if row.has_method("refresh"):
			row.refresh()
	fullscreen.set_pressed_no_signal(Game.settings["fullscreen"])
	head_bob.set_pressed_no_signal(Game.settings["head_bob"])


func _on_visibility() -> void:
	if is_visible_in_tree():
		refresh()
	else:
		Game.save_settings()


func _on_fullscreen(on: bool) -> void:
	Game.set_setting("fullscreen", on)


func _on_head_bob(on: bool) -> void:
	Game.set_setting("head_bob", on)


func _on_back() -> void:
	back_requested.emit()
