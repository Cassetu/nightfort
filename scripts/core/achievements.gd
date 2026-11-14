extends Node

signal unlocked(id: String)
signal progressed(id: String)

const SAVE_PATH := "user://achievements.cfg"
const ICON_DIR := "res://art/achievements/"
const LOCKED_ICON := "res://art/achievements/locked.png"

const DEFS := [
	{"id": "defender", "name": "Defender of the Overworld", "req": "Kill 100 gloom", "msg": "\"Ugly bastards\" - Odrick", "hidden": false, "goal": 100, "key": "kills", "icon": "defender"},
	{"id": "highway", "name": "Highway to Hell", "req": "Lose Odrick", "msg": "Have you heard of AC/DC?", "hidden": true, "goal": 1, "key": "highway", "icon": "highway"},
	{"id": "revive", "name": "If at first you don't succeed", "req": "Come back to life 5 times", "msg": "Try and try again.", "hidden": false, "goal": 5, "key": "revives", "icon": "revive"},
	{"id": "militia", "name": "Small Militia", "req": "Get your first troop", "msg": "Rally up soldiers!", "hidden": false, "goal": 1, "key": "militia", "icon": "militia"},
	{"id": "graverobber", "name": "Graverobber", "req": "Obtain a soul gem", "msg": "They won't miss this.", "hidden": false, "goal": 1, "key": "graverobber", "icon": "graverobber"},
	{"id": "ironman", "name": "Iron Man", "req": "Wear a full set of iron armor", "msg": "Genius, billionaire, playboy, philanthropist.", "hidden": false, "goal": 1, "key": "ironman", "icon": "ironman"},
	{"id": "smith", "name": "It's still usable, right?", "req": "Fail while smithing", "msg": "Waste of coal.", "hidden": false, "goal": 1, "key": "smith", "icon": "smith"},
	{"id": "night", "name": "That was easy.", "req": "Survive your second night", "msg": "Gloom ain't so gloomy.", "hidden": false, "goal": 2, "key": "nights", "icon": "night"},
	{"id": "orb", "name": "I can do that?", "req": "Walk into your anchor orb", "msg": "Shiny blue orb!", "hidden": true, "goal": 1, "key": "orb", "icon": "orb"},
	{"id": "charged", "name": "Charged up", "req": "Upgrade your anchor orb", "msg": "Soul eater", "hidden": false, "goal": 1, "key": "charged", "icon": "charged"},
]

const IRON_SET := {"head": "iron_helmet", "chest": "iron_chestplate", "legs": "iron_leggings", "feet": "iron_boots"}

static var instance: Node = null

var counters: Dictionary = {}
var done: Dictionary = {}
var icon_cache: Dictionary = {}


func _enter_tree() -> void:
	instance = self
	_load()


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func progress(key: String, amount: int = 1) -> void:
	if instance != null:
		instance.add_progress(key, amount)


static func set_progress(key: String, value: int) -> void:
	if instance != null:
		instance.put_progress(key, value)


func check_iron_set() -> void:
	for slot_name in IRON_SET:
		var item: Dictionary = Inventory.equipment.get(slot_name, {})
		if item.is_empty() or item.get("id", "") != IRON_SET[slot_name]:
			return
	put_progress("ironman", 1)


static func defs() -> Array:
	return DEFS


func add_progress(key: String, amount: int) -> void:
	put_progress(key, int(counters.get(key, 0)) + amount)


func put_progress(key: String, value: int) -> void:
	var old: int = int(counters.get(key, 0))
	if value <= old:
		return
	counters[key] = value
	for def: Dictionary in DEFS:
		if def["key"] != key or done.has(def["id"]):
			continue
		progressed.emit(def["id"])
		if value >= int(def["goal"]):
			done[def["id"]] = true
			unlocked.emit(def["id"])
	_save()


func is_done(id: String) -> bool:
	return done.has(id)


func value_of(def: Dictionary) -> int:
	return mini(int(counters.get(def["key"], 0)), int(def["goal"]))


func count_done() -> int:
	return done.size()


func icon_for(def: Dictionary, hidden_view: bool = false) -> Texture2D:
	var name: String = LOCKED_ICON if hidden_view else ICON_DIR + String(def["icon"]) + ".png"
	if not icon_cache.has(name):
		icon_cache[name] = load(name) if ResourceLoader.exists(name) else null
	return icon_cache[name]


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("achievements", "counters", counters)
	cfg.set_value("achievements", "done", done.keys())
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var saved: Dictionary = cfg.get_value("achievements", "counters", {})
	for key in saved:
		counters[String(key)] = int(saved[key])
	for id in cfg.get_value("achievements", "done", []):
		done[String(id)] = true
