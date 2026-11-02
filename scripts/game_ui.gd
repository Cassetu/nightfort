extends CanvasLayer

const DEATH_DELAY := 3.0

@onready var vignette = %Vignette
@onready var player_bar = %PlayerBar
@onready var player_label = $UI/PlayerBar/Label
@onready var wave_label = %WaveLabel
@onready var core_bar = %CoreBar
@onready var core_label = $UI/CoreBar/Label
@onready var death_overlay = %DeathOverlay
@onready var death_label = %DeathLabel
@onready var pause_overlay = %PauseOverlay
@onready var pause_main = %PauseMain
@onready var seed_label = %SeedLabel
@onready var pause_settings_panel = %PauseSettingsPanel
@onready var pause_slots_panel = %PauseSlotsPanel
@onready var over_overlay = %OverOverlay
@onready var over_main = %OverMain
@onready var over_slots_panel = %OverSlotsPanel

var player
var core
var world
var flash: float = 0.0
var pulse_time: float = 0.0
var death_left: float = 0.0
var dead: bool = false
var game_over: bool = false
var pause_view: String = "none"


func _ready() -> void:
	%Resume.pressed.connect(close_pause)
	%SaveGame.pressed.connect(_pause_save)
	%PauseLoad.pressed.connect(_pause_load)
	%PauseSettings.pressed.connect(_pause_settings)
	%PauseMenu.pressed.connect(Game.go_to_menu)
	%PauseQuit.pressed.connect(get_tree().quit)
	%OverLoad.pressed.connect(_over_load)
	%OverMenu.pressed.connect(Game.go_to_menu)
	pause_settings_panel.back_requested.connect(_pause_main)
	pause_slots_panel.back_requested.connect(_pause_main)
	over_slots_panel.back_requested.connect(_over_main)


func setup(p, c, w) -> void:
	player = p
	core = c
	world = w
	player.health_changed.connect(_on_player_health)
	player.damaged.connect(_on_player_damaged)
	core.health_changed.connect(_on_core_health)
	_on_player_health(ceili(player.health), player.max_health)
	_on_core_health(core.current_health, core.max_health)


func _process(delta: float) -> void:
	if player == null:
		return
	flash = move_toward(flash, 0.0, delta * 1.6)
	pulse_time += delta
	var low := 0.0
	if not dead and player.health > 0.0 and player.health <= player.max_health * 0.3:
		low = 0.3 + 0.18 * sin(pulse_time * 5.0)
	vignette.modulate.a = clampf(maxf(flash, low), 0.0, 1.0)

	if dead:
		death_left -= delta
		death_label.text = "Respawning at the Core in %d" % maxi(ceili(death_left), 0)
		if death_left <= 0.0:
			_respawn()


func _on_player_health(current, maximum) -> void:
	player_bar.max_value = maximum
	player_bar.value = current
	player_label.text = "HP  %d / %d" % [current, maximum]


func _on_player_damaged(amount) -> void:
	flash = clampf(0.45 + float(amount) / 80.0, 0.0, 0.9)


func _on_core_health(current, maximum) -> void:
	core_bar.max_value = maximum
	core_bar.value = current
	core_label.text = "CORE  %d / %d" % [current, maximum]


func on_wave_status(text: String) -> void:
	wave_label.text = text


func on_player_died() -> void:
	if game_over:
		return
	dead = true
	death_left = DEATH_DELAY
	death_overlay.visible = true


func _respawn() -> void:
	dead = false
	death_overlay.visible = false
	world.respawn_player()


func on_core_destroyed() -> void:
	game_over = true
	dead = false
	death_overlay.visible = false
	pause_overlay.visible = false
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	over_overlay.visible = true
	_over_main()


func _over_main() -> void:
	over_main.visible = true
	over_slots_panel.visible = false


func _over_load() -> void:
	over_main.visible = false
	over_slots_panel.open("load")


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if dead or game_over:
		return
	get_viewport().set_input_as_handled()
	if not pause_overlay.visible:
		open_pause()
	elif pause_view != "main":
		_pause_main()
	else:
		close_pause()


func open_pause() -> void:
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	pause_overlay.visible = true
	_pause_main()


func close_pause() -> void:
	pause_overlay.visible = false
	pause_view = "none"
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _pause_main() -> void:
	pause_view = "main"
	seed_label.text = "World seed  %d" % Game.world_seed
	pause_main.visible = true
	pause_settings_panel.visible = false
	pause_slots_panel.visible = false


func _pause_save() -> void:
	pause_view = "save"
	pause_main.visible = false
	pause_settings_panel.visible = false
	pause_slots_panel.open("save")


func _pause_load() -> void:
	pause_view = "load"
	pause_main.visible = false
	pause_settings_panel.visible = false
	pause_slots_panel.open("load")


func _pause_settings() -> void:
	pause_view = "settings"
	pause_main.visible = false
	pause_slots_panel.visible = false
	pause_settings_panel.visible = true
