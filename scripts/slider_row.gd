extends HBoxContainer

@export var title: String = ""
@export var key: String = ""
@export var min_value: float = 0.0
@export var max_value: float = 1.0
@export var step: float = 0.05
@export_enum("Percent", "Multiplier", "Number", "Chunks") var format: int = 0

@onready var name_label = $Name
@onready var slider = $Slider
@onready var value_label = $Value


func _ready() -> void:
	name_label.text = title
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value_changed.connect(_on_changed)
	refresh()


func refresh() -> void:
	slider.set_value_no_signal(float(Game.settings[key]))
	value_label.text = _format(slider.value)


func _on_changed(value: float) -> void:
	value_label.text = _format(value)
	if key == "view_distance":
		Game.set_setting(key, roundi(value))
	else:
		Game.set_setting(key, value)


func _format(value: float) -> String:
	match format:
		0:
			return "%d%%" % roundi(value * 100.0)
		1:
			return "%.2fx" % (value / 0.002)
		2:
			return "%d" % roundi(value)
	return "%d chunks" % roundi(value)
