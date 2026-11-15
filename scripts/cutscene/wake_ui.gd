extends CanvasLayer

@onready var white: ColorRect = %White
@onready var black: ColorRect = %Black
@onready var eyes: ColorRect = %Eyes
@onready var prompt: Label = %Prompt


func fade(rect: CanvasItem, to_alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", to_alpha, seconds)
	await tween.finished


func show_prompt(text: String) -> void:
	prompt.text = text
	await fade(prompt, 1.0, 0.8)


func hide_prompt() -> void:
	await fade(prompt, 0.0, 0.4)


func set_eyes(open: float, blur: float) -> void:
	var mat := eyes.material as ShaderMaterial
	mat.set_shader_parameter("open", open)
	mat.set_shader_parameter("blur", blur)


func tween_eyes(open: float, blur: float, seconds: float, blur_seconds: float = -1.0) -> void:
	var mat := eyes.material as ShaderMaterial
	var from_open: float = mat.get_shader_parameter("open")
	var from_blur: float = mat.get_shader_parameter("blur")
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("open", v), from_open, open, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("blur", v), from_blur, blur, seconds if blur_seconds < 0.0 else blur_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
