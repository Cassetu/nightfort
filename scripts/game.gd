extends Node

signal settings_changed

const SAVE_DIR := "user://saves"
const SETTINGS_PATH := "user://settings.cfg"
const SLOT_COUNT := 3
const MENU_SCENE := "res://scenes/main_menu.tscn"
const WORLD_SCENE := "res://scenes/world.tscn"
const SEED_LIMIT := 2000000000
const BACKUP_COUNT := 5
const AUTOSAVE_INTERVAL := 300.0
const DEFAULT_NAME := "New World"

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
var gamemode: String = "survival"
var world_name: String = DEFAULT_NAME
var autosave_timer: float = 0.0


func _ready() -> void:
	load_settings()
	apply_settings()


func _process(delta: float) -> void:
	if in_world:
		play_time += delta
		autosave_timer += delta
		if autosave_timer >= AUTOSAVE_INTERVAL:
			autosave_timer = 0.0
			autosave()


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


func new_game(seed_text: String, mode: String = "survival", name_text: String = "") -> bool:
	Inventory.reset()
	world_name = _clean_name(name_text)
	autosave_timer = 0.0
	gamemode = mode if mode in ["survival", "creative"] else "survival"
	world_seed = seed_from_text(seed_text)
	has_session = true
	in_world = true
	pending = {}
	play_time = 0.0
	current_slot = -1
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)
	return true


func load_game(slot: int, backup: bool = false) -> bool:
	var data = _read_slot(slot, backup)
	if data == null:
		return false
	Inventory.reset()
	world_seed = int(data.get("seed", 1337))
	gamemode = str(data.get("mode", "survival"))
	has_session = true
	in_world = true
	pending = data.get("state", {})
	play_time = float(data.get("play_time", 0.0))
	current_slot = -1 if backup else slot
	world_name = _clean_name(str(data.get("name", "")))
	autosave_timer = 0.0
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


func _clean_name(text: String) -> String:
	var t := text.strip_edges()
	if t.is_empty():
		return DEFAULT_NAME
	return t.substr(0, 28)


func slot_path(slot: int, backup: bool = false) -> String:
	if backup:
		return "%s/backup_%d.json" % [SAVE_DIR, slot]
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func _snapshot():
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("collect_state"):
		return null
	return {
		"version": 1,
		"name": world_name,
		"seed": world_seed,
		"mode": gamemode,
		"play_time": play_time,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"unix": Time.get_unix_time_from_system(),
		"state": scene.collect_state(),
	}


func _write(path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(temp, path) == OK


func save_game(slot: int) -> bool:
	var data = _snapshot()
	if data == null:
		return false
	if not _write(slot_path(slot), data):
		return false
	current_slot = slot
	return true


func autosave() -> bool:
	var scene := get_tree().current_scene
	if scene == null or get_tree().paused:
		return false
	var hero = scene.get("player")
	if hero != null and hero.get("dead") == true:
		return false
	var data = _snapshot()
	if data == null:
		return false
	var target := 0
	var oldest := INF
	for i in BACKUP_COUNT:
		var info := slot_info(i, true)
		if not info["exists"]:
			target = i
			break
		if info["unix"] < oldest:
			oldest = info["unix"]
			target = i
	return _write(slot_path(target, true), data)


func delete_slot(slot: int, backup: bool = false) -> void:
	var path := slot_path(slot, backup)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _read_slot(slot: int, backup: bool = false):
	var path := slot_path(slot, backup)
	if not FileAccess.file_exists(path):
		return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return data


func slot_info(slot: int, backup: bool = false) -> Dictionary:
	var data = _read_slot(slot, backup)
	if data == null:
		return {"exists": false}
	return {
		"exists": true,
		"name": str(data.get("name", DEFAULT_NAME)),
		"seed": int(data.get("seed", 0)),
		"mode": str(data.get("mode", "survival")),
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
