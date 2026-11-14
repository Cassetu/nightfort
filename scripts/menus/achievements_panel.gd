extends Control

signal closed

@export var entry_scene: PackedScene

@onready var grid: GridContainer = %Grid
@onready var total: Label = %Total
@onready var back: Button = %Back


func _ready() -> void:
	back.pressed.connect(close)


func open() -> void:
	for child in grid.get_children():
		child.queue_free()
	var mgr = Game.achievements
	for def: Dictionary in mgr.defs():
		var entry := entry_scene.instantiate()
		grid.add_child(entry)
		entry.setup(def)
	total.text = "%d / %d" % [mgr.count_done(), mgr.defs().size()]
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
