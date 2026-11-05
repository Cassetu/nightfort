extends Control

@onready var main_buttons = %MainButtons
@onready var continue_button = %Continue
@onready var new_button = %NewGame
@onready var load_button = %LoadGame
@onready var settings_button = %Settings
@onready var quit_button = %Quit
@onready var new_panel = %NewGamePanel
@onready var new_page = %NewWorldPage
@onready var main_center = %Center
@onready var load_panel = %LoadPanel
@onready var settings_panel = %SettingsPanel
@onready var error_label = %ErrorLabel
@onready var loading = %Loading

var current_view: String = "main"


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	Game.in_world = false

	continue_button.pressed.connect(_on_continue)
	new_button.pressed.connect(show_new_game)
	load_button.pressed.connect(show_load)
	settings_button.pressed.connect(show_settings)
	quit_button.pressed.connect(get_tree().quit)

	new_panel.back_requested.connect(show_main)
	new_panel.start_requested.connect(_start_new)
	load_panel.back_requested.connect(show_main)
	settings_panel.back_requested.connect(show_main)
	show_main()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and current_view != "main":
		get_viewport().set_input_as_handled()
		show_main()


func _set_view(view: String) -> void:
	current_view = view
	error_label.text = ""
	main_buttons.visible = view == "main"
	new_page.visible = view == "new"
	main_center.visible = view != "new"
	load_panel.visible = view == "load"
	settings_panel.visible = view == "settings"


func show_main() -> void:
	continue_button.disabled = Game.latest_slot() < 0
	_set_view("main")


func show_new_game() -> void:
	_set_view("new")


func show_load() -> void:
	load_panel.open("load")
	_set_view("load")


func show_settings() -> void:
	_set_view("settings")


func _on_continue() -> void:
	_launch(Game.load_game.bind(Game.latest_slot()))


func _start_new(seed_text: String) -> void:
	_launch(Game.new_game.bind(seed_text))


func _launch(action: Callable) -> void:
	loading.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	var ok = action.call()
	if ok == false:
		loading.visible = false
		error_label.text = "That save could not be read."
