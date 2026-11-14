extends Control

@onready var trophy: Button = %Trophy
@onready var panel = %Panel


func _ready() -> void:
	trophy.pressed.connect(panel.open)
