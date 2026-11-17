extends MeshInstance3D

const SHADER_PATH := "res://resources/stars.gdshader"
const NIGHT_START := 0.05
const NIGHT_FULL := -0.2
const COVER_BLOCK := 0.9
const DARK_BLOCK := 0.6
const HIDE_BELOW := 0.005

var sun
var weather
var material: ShaderMaterial


func setup(s, w) -> void:
	sun = s
	weather = w


func _ready() -> void:
	name = "Stars"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mesh = quad
	material = ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	material.render_priority = -10
	material_override = material
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func _process(_delta: float) -> void:
	if sun == null:
		return
	var night := 1.0 - smoothstep(NIGHT_FULL, NIGHT_START, float(sun.elevation))
	var block := 0.0
	if weather != null:
		block = clampf(float(weather.cover) * COVER_BLOCK + float(weather.dark) * DARK_BLOCK, 0.0, 1.0)
	var level := night * (1.0 - block)
	visible = level > HIDE_BELOW
	if not visible:
		return
	material.set_shader_parameter("strength", level)
	material.set_shader_parameter("rotation", float(sun.day_phase) * TAU)
