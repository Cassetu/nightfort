extends CanvasLayer

signal choice_made(play: bool)
signal advanced

const TYPE_SPEED := 40.0
const YOU_COLOR := Color(0.92, 0.92, 0.96)
const VOICE_COLOR := Color(0.45, 0.75, 1.0)
const ODRICK_COLOR := Color(1.0, 0.78, 0.35)
const DONE_COLOR := Color(0.45, 1.0, 0.5)
const LIGHT_SCALE := 3.2

@onready var blur: ColorRect = %Blur
@onready var vignette: TextureRect = %Vignette
@onready var orb: TextureRect = %Orb
@onready var tutorial: Label = %Tutorial
@onready var prompt: Label = %Prompt
@onready var army_label: Label = %ArmyLabel
@onready var heal_glow: TextureRect = %HealGlow
@onready var boss_box: Control = %BossBox
@onready var boss_bar: ProgressBar = %BossBar
@onready var dialogue: Control = %Dialogue
@onready var speaker_name: Label = %SpeakerName
@onready var speaker_text: Label = %SpeakerText
@onready var arrow: Label = %Arrow
@onready var light: TextureRect = %Light
@onready var white: ColorRect = %White
@onready var title_box: Control = %TitleBox
@onready var title_mask: TextureRect = %TitleMask
@onready var black: ColorRect = %Black
@onready var choice: Control = %Choice
@onready var play_button: Button = %PlayButton
@onready var skip_button: Button = %SkipButton

var typed: float = 0.0
var typing: bool = false
var waiting: bool = false
var light_tween: Tween
var arrow_tween: Tween
var orb_tween: Tween
var tutorial_tween: Tween


func _ready() -> void:
	play_button.pressed.connect(func() -> void: choice_made.emit(true))
	skip_button.pressed.connect(func() -> void: choice_made.emit(false))


func show_choice() -> void:
	choice.visible = true
	play_button.grab_focus()


func hide_choice() -> void:
	choice.visible = false


func fade_black(to_alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(black, "modulate:a", to_alpha, seconds)
	await tween.finished


func set_tutorial(text: String) -> void:
	if tutorial_tween != null:
		tutorial_tween.kill()
	tutorial.text = text
	tutorial.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	tutorial_tween = create_tween()
	tutorial_tween.tween_property(tutorial, "modulate:a", 1.0, 0.3)


func complete_tutorial() -> void:
	if tutorial_tween != null:
		tutorial_tween.kill()
	tutorial.add_theme_color_override("font_color", DONE_COLOR)
	tutorial_tween = create_tween()
	tutorial_tween.tween_interval(0.5)
	tutorial_tween.tween_property(tutorial, "modulate:a", 0.0, 0.35)
	await tutorial_tween.finished


func clear_tutorial() -> void:
	if tutorial_tween != null:
		tutorial_tween.kill()
	tutorial.modulate.a = 0.0


func show_prompt(text: String) -> void:
	prompt.text = text
	var tween := create_tween()
	tween.tween_property(prompt, "modulate:a", 1.0, 0.5)


func hide_prompt() -> void:
	var tween := create_tween()
	tween.tween_property(prompt, "modulate:a", 0.0, 0.3)
	await tween.finished


func show_army(count: int) -> void:
	set_army(count)
	var tween := create_tween()
	tween.tween_property(army_label, "modulate:a", 1.0, 0.6)


func set_army(count: int) -> void:
	army_label.text = "Army: %d" % count


func hide_army() -> void:
	var tween := create_tween()
	tween.tween_property(army_label, "modulate:a", 0.0, 0.4)


func pulse_heal() -> void:
	var tween := create_tween()
	tween.tween_property(heal_glow, "modulate:a", 0.55, 0.18)
	tween.tween_property(heal_glow, "modulate:a", 0.0, 0.7)


func show_boss() -> void:
	var tween := create_tween()
	tween.tween_property(boss_box, "modulate:a", 1.0, 0.8)


func hide_boss() -> void:
	var tween := create_tween()
	tween.tween_property(boss_box, "modulate:a", 0.0, 0.4)


func set_boss(current: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	var tween := create_tween()
	tween.tween_property(boss_bar, "value", current, 0.15)


func show_red(seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(vignette, "modulate:a", 1.0, seconds)


func blur_out(seconds: float) -> void:
	blur.visible = true
	var mat := blur.material as ShaderMaterial
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(mat, "shader_parameter/blur", 1.0, seconds)
	tween.tween_property(mat, "shader_parameter/dark", 1.0, seconds).set_delay(seconds * 0.35)
	tween.tween_property(mat, "shader_parameter/red", 1.0, seconds * 0.5)
	await tween.finished


func show_orb() -> void:
	var tween := create_tween()
	tween.tween_property(orb, "modulate:a", 1.0, 1.6)
	await tween.finished
	orb_tween = create_tween().set_loops()
	orb_tween.tween_property(orb, "scale", Vector2(1.07, 1.07), 1.4).set_trans(Tween.TRANS_SINE)
	orb_tween.tween_property(orb, "scale", Vector2(0.94, 0.94), 1.4).set_trans(Tween.TRANS_SINE)


func say(speaker: String, text: String) -> void:
	speaker_name.text = speaker
	speaker_name.visible = speaker != ""
	var tint := VOICE_COLOR
	if speaker == "You":
		tint = YOU_COLOR
	elif speaker == "Odrick":
		tint = ODRICK_COLOR
	speaker_name.add_theme_color_override("font_color", tint)
	speaker_text.text = text
	speaker_text.visible_characters = 0
	typed = 0.0
	typing = true
	waiting = true
	arrow.visible = false
	if not dialogue.visible:
		dialogue.visible = true
		dialogue.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(dialogue, "modulate:a", 1.0, 0.4)
	await advanced


func hide_dialogue() -> void:
	waiting = false
	var tween := create_tween()
	tween.tween_property(dialogue, "modulate:a", 0.0, 0.7)
	await tween.finished
	dialogue.visible = false


func grow_light(seconds: float) -> void:
	light.visible = true
	light.scale = Vector2(0.02, 0.02)
	light_tween = create_tween()
	light_tween.tween_property(light, "scale", Vector2(LIGHT_SCALE, LIGHT_SCALE), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	light_tween.tween_property(white, "modulate:a", 1.0, 0.8)


func finish_light() -> void:
	if light_tween != null:
		light_tween.kill()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(light, "scale", Vector2(LIGHT_SCALE, LIGHT_SCALE), 1.0)
	tween.tween_property(white, "modulate:a", 1.0, 1.0).set_delay(0.6)
	await tween.finished


func show_title(seconds: float) -> void:
	title_mask.position.x = -300.0
	title_box.visible = true
	var tween := create_tween()
	tween.tween_property(title_mask, "position:x", 900.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func hide_title(seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(title_box, "modulate:a", 0.0, seconds)
	await tween.finished
	title_box.visible = false


func clear_layers() -> void:
	if orb_tween != null:
		orb_tween.kill()
	blur.visible = false
	vignette.modulate.a = 0.0
	orb.modulate.a = 0.0
	light.visible = false
	dialogue.visible = false
	boss_box.modulate.a = 0.0
	tutorial.modulate.a = 0.0
	prompt.modulate.a = 0.0
	army_label.modulate.a = 0.0
	heal_glow.modulate.a = 0.0


func fade_white_out(seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(white, "modulate:a", 0.0, seconds)
	await tween.finished


func _process(delta: float) -> void:
	if not typing:
		return
	typed += delta * TYPE_SPEED
	var total := speaker_text.text.length()
	speaker_text.visible_characters = int(typed)
	if int(typed) >= total:
		_finish_typing()


func _finish_typing() -> void:
	typing = false
	speaker_text.visible_characters = -1
	arrow.visible = true
	arrow.position.y = 0.0
	if arrow_tween != null:
		arrow_tween.kill()
	arrow_tween = create_tween().set_loops()
	arrow_tween.tween_property(arrow, "modulate:a", 0.35, 0.6)
	arrow_tween.tween_property(arrow, "modulate:a", 1.0, 0.6)


func _input(event: InputEvent) -> void:
	if not waiting:
		return
	var pressed = event is InputEventMouseButton and event.pressed
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if typing:
		_finish_typing()
		return
	waiting = false
	arrow.visible = false
	advanced.emit()
