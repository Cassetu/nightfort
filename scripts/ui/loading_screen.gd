extends CanvasLayer

signal finished

const MIN_TIME: float = 2.0
const MAX_TIME: float = 30.0
const TIP_TIME: float = 4.5
const FADE_OUT: float = 0.6
const LOAD_BUDGET_MS: float = 14.0
const SPIN_SPEED: float = 5.2
const SPINNER_CENTER := Vector2(36.0, 36.0)
const SPINNER_RADIUS: float = 30.0
const TIPS := [
	"Building your stone brick walls higher will further fortify each block.",
	"Position your units higher to stay out of reach of enemies.",
	"You are the most important defender of the core.",
	"Caves may be scary, but the ore inside is too good to pass up.",
	"Barricades cost lots of wood, but are crucial for good base defense!",
	"Don't stray too far from the core, otherwise when night comes, you cannot protect it.",
	"Put a lantern in your bauble slot for light that doesn’t require holding!",
	"To beat the forge minigame, just hit the orange circles!",
	"Inventory filled up? Build a chest!",
	"The rain is so calming… the thunder is so frightening!!",
	"Use ladders for quick and easy access to the top of your walls.",
	"Wanna just build an awesome fort without mining for eternity? Try creative mode!",
	"Remember to station all your troops.",
	"You can walk through the core!!",
]

@onready var root: Control = $Root
@onready var tip: Label = %Tip
@onready var spinner: Control = %Spinner

var terrain
var player
var order: Array = []
var tip_index: int = 0
var tip_timer: float = 0.0
var elapsed: float = 0.0
var holding: bool = false
var releasing: bool = false
var saved_budget: float = 4.0
var saved_frozen: bool = false
var tip_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	spinner.pivot_offset = SPINNER_CENTER
	spinner.draw.connect(_draw_spinner)
	order = TIPS.duplicate()
	order.shuffle()
	tip.text = order[0]


func begin(t, p) -> void:
	terrain = t
	player = p
	if terrain != null:
		saved_budget = terrain.frame_budget_ms
		terrain.frame_budget_ms = LOAD_BUDGET_MS
	if player != null:
		saved_frozen = player.frozen
		player.frozen = true


func cover() -> void:
	holding = true


func release() -> void:
	holding = false


func _draw_spinner() -> void:
	spinner.draw_arc(SPINNER_CENTER, SPINNER_RADIUS, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.12), 4.0, true)
	spinner.draw_arc(SPINNER_CENTER, SPINNER_RADIUS, 0.0, TAU * 0.28, 24, Color(0.85, 0.82, 0.78, 0.9), 4.0, true)


func _process(delta: float) -> void:
	spinner.rotation += delta * SPIN_SPEED
	elapsed += delta
	tip_timer += delta
	if tip_timer >= TIP_TIME:
		tip_timer = 0.0
		_next_tip()
	if releasing or holding:
		return
	var ready: bool = elapsed >= MIN_TIME
	if terrain != null and is_instance_valid(terrain):
		ready = ready and terrain.is_settled()
	if ready or elapsed >= MAX_TIME:
		_finish()


func _next_tip() -> void:
	tip_index = (tip_index + 1) % order.size()
	if tip_tween != null:
		tip_tween.kill()
	tip_tween = create_tween()
	tip_tween.tween_property(tip, "modulate:a", 0.0, 0.35)
	tip_tween.tween_callback(func() -> void: tip.text = order[tip_index])
	tip_tween.tween_property(tip, "modulate:a", 1.0, 0.35)


func _finish() -> void:
	releasing = true
	if terrain != null and is_instance_valid(terrain):
		terrain.frame_budget_ms = saved_budget
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 0.0, FADE_OUT)
	await tween.finished
	if player != null and is_instance_valid(player):
		player.frozen = saved_frozen
	finished.emit()
	queue_free()
