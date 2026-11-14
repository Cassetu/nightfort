extends PanelContainer

const HOLD := 10.0
const FADE_IN := 0.35
const FADE_OUT := 0.6

@onready var icon: TextureRect = %Icon
@onready var title: Label = %Title


func show_for(def: Dictionary, texture: Texture2D) -> void:
	icon.texture = texture
	title.text = String(def["name"])
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	tween.tween_interval(HOLD)
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	tween.tween_callback(queue_free)
