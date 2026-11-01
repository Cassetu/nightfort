extends Node

signal settings_changed

const SAVE_DIR := "user://saves"
const SETTINGS_PATH := "user://settings.cfg"
const SLOT_COUNT := 3
const MENU_SCENE := "res://scenes/main_menu.tscn"
const WORLD_SCENE := "res://scenes/world.tscn"
const SEED_LIMIT := 2000000000

var settings := {
	"master_volume": 0.8,
	"mouse_sensitivity": 0.002,
	"fov": 75.0,
	"view_distance": 7,
	"fullscreen": true,
}

var has_session: bool = false
var in_world: bool = false
var world_seed: int = 1337
var pending: Dictionary = {}
var play_time: float = 0.0
var current_slot: int = -1


func _ready() -> void:
	load_settings()
	apply_settings()


func _process(delta: float) -> void:
	if in_world:
		play_time += delta


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key in settings.keys():
		settings[key] = cfg.get_value("settings", key, settings[key])
	settings["view_distance"] = clampi(int(settings["view_distance"]), 4, 10)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings.keys():
		cfg.set_value("settings", key, settings[key])
	cfg.save(SETTINGS_PATH)


func set_setting(key: String, value) -> void:
	settings[key] = value
	apply_settings()


func apply_settings() -> void:
	var volume: float = settings["master_volume"]
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))

	var want_fullscreen: bool = settings["fullscreen"]
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if want_fullscreen != is_fullscreen:
		if want_fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	settings_changed.emit()


func seed_from_text(text: String) -> int:
	var t := text.strip_edges()
	if t.is_empty():
		return randi() % SEED_LIMIT
	if t.is_valid_int():
		return absi(t.to_int()) % SEED_LIMIT
	return (t.hash() & 0x7FFFFFFF) % SEED_LIMIT


func new_game(seed_text: String) -> bool:
	Inventory.reset()
	world_seed = seed_from_text(seed_text)
	has_session = true
	in_world = true
	pending = {}
	play_time = 0.0
	current_slot = -1
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)
	return true


func load_game(slot: int) -> bool:
	var data = _read_slot(slot)
	if data == null:
		return false
	Inventory.reset()
	world_seed = int(data.get("seed", 1337))
	has_session = true
	in_world = true
	pending = data.get("state", {})
	play_time = float(data.get("play_time", 0.0))
	current_slot = slot
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)
	return true


func take_pending() -> Dictionary:
	var state := pending
	pending = {}
	return state


func go_to_menu() -> void:
	in_world = false
	has_session = false
	pending = {}
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func save_game(slot: int) -> bool:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("collect_state"):
		return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var data := {
		"version": 1,
		"seed": world_seed,
		"play_time": play_time,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"unix": Time.get_unix_time_from_system(),
		"state": scene.collect_state(),
	}

	var path := slot_path(slot)
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if DirAccess.rename_absolute(temp, path) != OK:
		return false
	current_slot = slot
	return true


func delete_slot(slot: int) -> void:
	var path := slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _read_slot(slot: int):
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return data


func slot_info(slot: int) -> Dictionary:
	var data = _read_slot(slot)
	if data == null:
		return {"exists": false}
	return {
		"exists": true,
		"seed": int(data.get("seed", 0)),
		"play_time": float(data.get("play_time", 0.0)),
		"saved_at": str(data.get("saved_at", "")),
		"unix": float(data.get("unix", 0.0)),
	}


func latest_slot() -> int:
	var best := -1
	var best_time := -1.0
	for slot in SLOT_COUNT:
		var info := slot_info(slot)
		if info["exists"] and info["unix"] > best_time:
			best = slot
			best_time = info["unix"]
	return best
