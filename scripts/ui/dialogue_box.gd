extends CanvasLayer

signal line_started(index: int, line: Dictionary)
signal line_event(event_name: String)
signal finished
signal _advanced

const TYPE_SPEED := 40.0
const VOICE_PATH := "res://audio/voice/%s_%02d.mp3"
const NARRATION_COLOR := Color(0.62, 0.62, 0.66)
const DEFAULT_COLOR := Color(0.45, 0.75, 1.0)
const SKIP_TIME := 1.1
const RING_RADIUS := 20.0
const RING_CENTER := Vector2(28.0, 28.0)
const SLANT := Transform2D(Vector2(1.0, 0.0), Vector2(0.22, 1.0), Vector2.ZERO)

static var speaker_colors: Dictionary = {
	"You": Color(0.92, 0.92, 0.96),
	"Odrick": Color(1.0, 0.78, 0.35),
	"Gaius": Color(0.6, 0.88, 0.58),
	"???": Color(0.45, 0.75, 1.0),
}

@onready var panel: Control = %Dialogue
@onready var speaker_name: Label = %SpeakerName
@onready var speaker_text: Label = %SpeakerText
@onready var arrow: Label = %Arrow
@onready var voice: AudioStreamPlayer = %Voice
@onready var ring: Control = %SkipRing

var typed: float = 0.0
var typing: bool = false
var waiting: bool = false
var arrow_tween: Tween
var italic_font: FontVariation
var skip_hold: float = 0.0
var skipping: bool = false


static func register_speaker(speaker: String, color: Color) -> void:
	speaker_colors[speaker] = color


func _ready() -> void:
	voice.bus = "Voice"
	var base := speaker_text.get_theme_font("font")
	if base != null:
		italic_font = FontVariation.new()
		italic_font.base_font = base
		italic_font.variation_transform = SLANT
	ring.draw.connect(_draw_ring)


func play(lines: Array, id: String = "", hide_after: bool = true) -> void:
	for i in lines.size():
		var line := _normalize(lines[i])
		line_started.emit(i, line)
		if line.get("event", "") != "":
			line_event.emit(String(line["event"]))
		if skipping:
			continue
		await _say(line, _voice_for(line, id, i))
	skipping = false
	skip_hold = 0.0
	ring.visible = false
	if hide_after:
		await hide_box()
	finished.emit()


func hide_box() -> void:
	waiting = false
	typing = false
	voice.stop()
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.7)
	await tween.finished
	panel.visible = false


func _normalize(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		return raw
	var pair: Array = raw
	return {"who": String(pair[0]), "text": String(pair[1])}


func _voice_for(line: Dictionary, id: String, index: int) -> String:
	if line.has("voice"):
		return String(line["voice"])
	if id == "" or String(line.get("who", "")) == "":
		return ""
	var path := VOICE_PATH % [id, index + 1]
	return path if ResourceLoader.exists(path) else ""


func _say(line: Dictionary, voice_path: String) -> void:
	var who := String(line.get("who", ""))
	var narration := who == ""
	speaker_name.text = who
	speaker_name.visible = not narration
	speaker_name.add_theme_color_override("font_color", speaker_colors.get(who, DEFAULT_COLOR))
	if narration:
		speaker_text.add_theme_color_override("font_color", NARRATION_COLOR)
		if italic_font != null:
			speaker_text.add_theme_font_override("font", italic_font)
	else:
		speaker_text.remove_theme_color_override("font_color")
		speaker_text.remove_theme_font_override("font")
	speaker_text.text = String(line.get("text", ""))
	speaker_text.visible_characters = 0
	typed = 0.0
	typing = true
	waiting = true
	arrow.visible = false
	voice.stop()
	if voice_path != "" and ResourceLoader.exists(voice_path):
		voice.stream = load(voice_path)
		voice.play()
	if not panel.visible:
		panel.visible = true
		panel.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.4)
	await _advanced


func _process(delta: float) -> void:
	_update_skip(delta)
	if not typing:
		return
	typed += delta * TYPE_SPEED
	speaker_text.visible_characters = int(typed)
	if int(typed) >= speaker_text.text.length():
		_finish_typing()


func _update_skip(delta: float) -> void:
	var active := waiting or typing
	var held := active and (Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER))
	if held:
		skip_hold = minf(skip_hold + delta / SKIP_TIME, 1.0)
	else:
		skip_hold = maxf(skip_hold - delta * 3.0, 0.0)
	ring.visible = skip_hold > 0.0
	ring.queue_redraw()
	if skip_hold >= 1.0 and not skipping:
		skipping = true
		typing = false
		waiting = false
		arrow.visible = false
		voice.stop()
		_advanced.emit()


func _draw_ring() -> void:
	ring.draw_arc(RING_CENTER, RING_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.15), 4.0, true)
	if skip_hold > 0.0:
		ring.draw_arc(RING_CENTER, RING_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * skip_hold, 48, Color(0.85, 0.82, 0.78, 0.95), 4.0, true)


func _finish_typing() -> void:
	typing = false
	speaker_text.visible_characters = -1
	arrow.visible = true
	if arrow_tween != null:
		arrow_tween.kill()
	arrow_tween = create_tween().set_loops()
	arrow_tween.tween_property(arrow, "modulate:a", 0.35, 0.6)
	arrow_tween.tween_property(arrow, "modulate:a", 1.0, 0.6)


func _input(event: InputEvent) -> void:
	if not waiting:
		return
	var pressed = (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if typing:
		_finish_typing()
		return
	waiting = false
	arrow.visible = false
	_advanced.emit()
