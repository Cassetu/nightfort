extends CanvasLayer

signal finished

const FADE_IN := 1.4
const HOLD := 1.4
const FINAL_HOLD := 2.0
const TEXT_OUT := 1.4
const WORLD_IN := 2.5

@onready var black: ColorRect = %Black
@onready var lines_box: VBoxContainer = %Lines
@onready var lines: Array = [%Died, %Line1, %Line2, %Line3, %Line4, %Line5]

var tween: Tween
var done: bool = false


func play() -> void:
	tween = create_tween()
	tween.tween_interval(0.8)
	for line: Label in lines:
		tween.tween_property(line, "modulate:a", 1.0, FADE_IN)
		tween.tween_interval(HOLD)
	tween.tween_interval(FINAL_HOLD)
	tween.tween_property(lines_box, "modulate:a", 0.0, TEXT_OUT)
	tween.tween_interval(0.5)
	tween.tween_property(black, "color:a", 0.0, WORLD_IN)
	tween.tween_callback(_finish)


func _input(event: InputEvent) -> void:
	if done:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_skip()


func _skip() -> void:
	if tween != null:
		tween.kill()
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(lines_box, "modulate:a", 0.0, 0.3)
	tween.tween_property(black, "color:a", 0.0, 1.0)
	tween.chain().tween_callback(_finish)


func _finish() -> void:
	if done:
		return
	done = true
	finished.emit()
	queue_free()
