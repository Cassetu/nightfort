extends CanvasLayer

@onready var tint: ColorRect = %Tint

var shown: float = 0.0


func set_intensity(value: float) -> void:
	shown = clampf(value, 0.0, 1.0)
	tint.visible = shown > 0.002
	(tint.material as ShaderMaterial).set_shader_parameter("intensity", shown)
