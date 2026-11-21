extends CanvasLayer

signal finished

const Stage = preload("res://branding/intro_stage.gd")
const SPACING_WIDE := 26
const SPACING_FINAL := 3
const SCALE_START := 1.06
const SKIP_FADE := 0.35

@export var credit_text: String = "A Cassetu Production."
@export var skippable: bool = true
@export var free_when_done: bool = true
@export var hide_mouse: bool = true
@export var stinger: AudioStream
@export var tech_color: Color = Color(0.35, 0.85, 1.0)
@export var nature_color: Color = Color(0.55, 0.9, 0.5)
@export var warm_color: Color = Color(1.0, 0.78, 0.45)
@export var seed_value: int = 1337

@onready var root_control: Control = $Root
@onready var stage: Control = %Stage
@onready var credit: Label = %Credit

var time: float = 0.0
var leaving: bool = false
var done: bool = false
var credit_font: FontVariation
var previous_mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	stage.tech = tech_color
	stage.nature = nature_color
	stage.warm = warm_color
	stage.seed_value = seed_value
	credit.text = credit_text
	credit.modulate.a = 0.0
	credit_font = FontVariation.new()
	credit_font.base_font = credit.get_theme_default_font()
	credit_font.spacing_glyph = SPACING_WIDE
	credit.add_theme_font_override("font", credit_font)
	credit.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
	root_control.resized.connect(_layout)
	_layout.call_deferred()
	previous_mouse = Input.mouse_mode
	if hide_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if stinger != null:
		var player := AudioStreamPlayer.new()
		player.stream = stinger
		add_child(player)
		player.play()


func _layout() -> void:
	var view: Vector2 = root_control.size
	var font_size: int = clampi(roundi(view.y * 0.058), 22, 110)
	credit.add_theme_font_size_override("font_size", font_size)
	var width: float = credit_font.get_string_size(credit.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	width += float(credit.text.length() * SPACING_FINAL)
	stage.text_rect = Rect2(view * 0.5 - Vector2(width * 0.5, float(font_size) * 0.55), Vector2(width, float(font_size) * 1.1))
	credit.pivot_offset = credit.size * 0.5


func _process(delta: float) -> void:
	if leaving or done:
		return
	time += minf(delta, 0.05)
	stage.t = time
	stage.queue_redraw()
	var text_u: float = smoothstep(Stage.TEXT_IN, Stage.TEXT_IN + 1.1, time)
	credit.modulate.a = text_u
	credit.scale = Vector2.ONE * lerpf(SCALE_START, 1.0, text_u)
	credit_font.spacing_glyph = roundi(lerpf(float(SPACING_WIDE), float(SPACING_FINAL), text_u))
	if time >= Stage.TOTAL:
		_finish()
	elif time >= Stage.OUT_START:
		root_control.modulate.a = 1.0 - smoothstep(Stage.OUT_START, Stage.TOTAL, time)


func _input(event: InputEvent) -> void:
	if not skippable or leaving or done:
		return
	var pressed: bool = false
	if event is InputEventKey:
		var key := event as InputEventKey
		pressed = key.pressed and not key.echo
	elif event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventJoypadButton:
		pressed = (event as InputEventJoypadButton).pressed
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	leaving = true
	var tween := create_tween()
	tween.tween_property(root_control, "modulate:a", 0.0, SKIP_FADE)
	tween.tween_callback(_finish)


func _finish() -> void:
	if done:
		return
	done = true
	if hide_mouse:
		Input.mouse_mode = previous_mouse
	finished.emit()
	if free_when_done:
		queue_free()
