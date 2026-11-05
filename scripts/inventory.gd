extends Node

signal changed
signal selection_changed(index: int)
signal recipes_unlocked(ids: Array)

const Recipes = preload("res://scripts/recipes.gd")

const SLOT_COUNT := 6
const BACKPACK_SIZE := 12
const STORAGE_SIZE := SLOT_COUNT + BACKPACK_SIZE
const MAX_STACK := 100
const BLOCK_COST := 1
const EQUIP_SLOTS := ["head", "chest", "legs", "feet", "bauble"]

const BLOCK_TYPES := {
	"wood": {"name": "Wood Block", "resource": "wood", "tile": "wood", "health": 3, "color": Color(0.58, 0.40, 0.22)},
	"stone": {"name": "Stone Block", "resource": "stone", "tile": "stone", "health": 6, "color": Color(0.62, 0.62, 0.65)},
	"dirt": {"name": "Dirt Block", "resource": "dirt", "tile": "dirt", "health": 2, "color": Color(0.42, 0.29, 0.18)},
	"plank": {"name": "Planks", "resource": "plank", "tile": "plank", "health": 4, "color": Color(0.72, 0.55, 0.32)},
	"stone_brick": {"name": "Stone Bricks", "resource": "stone_brick", "tile": "stone_brick", "health": 8, "color": Color(0.55, 0.55, 0.6)},
	"sandstone": {"name": "Sandstone", "resource": "sandstone", "tile": "sandstone", "health": 5, "color": Color(0.8, 0.72, 0.5)},
	"iron_block": {"name": "Iron Block", "resource": "iron_block", "tile": "iron_block", "health": 14, "color": Color(0.78, 0.78, 0.82)},
	"fortified_brick": {"name": "Fortified Bricks", "resource": "fortified_brick", "tile": "fortified_brick", "health": 16, "color": Color(0.4, 0.42, 0.5)},
	"workbench": {"name": "Workbench", "resource": "workbench", "tile": "workbench_side", "health": 5, "color": Color(0.5, 0.33, 0.16), "scene": "res://scenes/workbench.tscn"},
	"diorite": {"name": "Diorite", "resource": "diorite", "tile": "diorite", "health": 5, "color": Color(0.62, 0.62, 0.60)},
	"diorite_brick": {"name": "Diorite Bricks", "resource": "diorite_brick", "tile": "diorite_brick", "health": 8, "color": Color(0.62, 0.62, 0.60)},
	"granite": {"name": "Granite", "resource": "granite", "tile": "granite", "health": 6, "color": Color(0.55, 0.40, 0.36)},
	"granite_brick": {"name": "Granite Bricks", "resource": "granite_brick", "tile": "granite_brick", "health": 9, "color": Color(0.55, 0.40, 0.36)},
	"basalt": {"name": "Basalt", "resource": "basalt", "tile": "basalt", "health": 8, "color": Color(0.20, 0.20, 0.23)},
	"basalt_brick": {"name": "Basalt Bricks", "resource": "basalt_brick", "tile": "basalt_brick", "health": 11, "color": Color(0.20, 0.20, 0.23)},
	"limestone": {"name": "Limestone", "resource": "limestone", "tile": "limestone", "health": 4, "color": Color(0.72, 0.68, 0.58)},
	"limestone_brick": {"name": "Limestone Bricks", "resource": "limestone_brick", "tile": "limestone_brick", "health": 7, "color": Color(0.72, 0.68, 0.58)},
	"door": {"name": "Door", "resource": "door", "health": 6, "color": Color(0.45, 0.3, 0.17), "scene": "res://scenes/door.tscn", "height": 2, "needs_support": true},
	"ruined_brick": {"name": "Ruined Bricks", "resource": "stone", "tile": "ruined_brick", "health": 3, "color": Color(0.36, 0.38, 0.33)},
	"stone_forge": {"name": "Stone Forge", "resource": "stone_forge", "tile": "stone_brick", "health": 14, "color": Color(0.5, 0.5, 0.52), "scene": "res://scenes/forge.tscn", "height": 2},
	"torch": {"name": "Torch", "resource": "torch", "health": 1, "color": Color(0.9, 0.6, 0.25), "scene": "res://scenes/torch.tscn", "needs_support": true, "ghost": Vector3(0.25, 1.0, 0.25)},
}

const ITEMS := {
	"sword": {"name": "Sword", "kind": "weapon", "max_stack": 1, "damage": 3, "cooldown": 0.45, "reach": 2.6, "color": Color(0.78, 0.84, 0.92)},
	"wood": {"name": "Wood", "kind": "block", "tile": "wood", "color": Color(0.58, 0.40, 0.22)},
	"stone": {"name": "Stone", "kind": "block", "tile": "stone", "color": Color(0.62, 0.62, 0.65)},
	"dirt": {"name": "Dirt", "kind": "block", "tile": "dirt", "color": Color(0.42, 0.29, 0.18)},
	"cactus": {"name": "Cactus", "kind": "material", "tile": "cactus", "color": Color(0.3, 0.45, 0.28)},
	"sand": {"name": "Sand", "kind": "material", "tile": "sand", "color": Color(0.76, 0.68, 0.45)},
	"snow": {"name": "Snow", "kind": "material", "tile": "snow", "color": Color(0.92, 0.94, 0.97)},
	"coal": {"name": "Coal", "kind": "material", "color": Color(0.27, 0.27, 0.32)},
	"iron": {"name": "Iron", "kind": "material", "color": Color(0.72, 0.50, 0.38)},
	"plank": {"name": "Planks", "kind": "block", "tile": "plank", "color": Color(0.72, 0.55, 0.32)},
	"stone_brick": {"name": "Stone Bricks", "kind": "block", "tile": "stone_brick", "color": Color(0.55, 0.55, 0.6)},
	"sandstone": {"name": "Sandstone", "kind": "block", "tile": "sandstone", "color": Color(0.8, 0.72, 0.5)},
	"iron_block": {"name": "Iron Block", "kind": "block", "tile": "iron_block", "color": Color(0.78, 0.78, 0.82)},
	"fortified_brick": {"name": "Fortified Bricks", "kind": "block", "tile": "fortified_brick", "color": Color(0.4, 0.42, 0.5)},
	"workbench": {"name": "Workbench", "kind": "block", "tile": "workbench_side", "color": Color(0.5, 0.33, 0.16)},
	"diorite": {"name": "Diorite", "kind": "block", "tile": "diorite", "color": Color(0.62, 0.62, 0.60)},
	"diorite_brick": {"name": "Diorite Bricks", "kind": "block", "tile": "diorite_brick", "color": Color(0.62, 0.62, 0.60)},
	"granite": {"name": "Granite", "kind": "block", "tile": "granite", "color": Color(0.55, 0.40, 0.36)},
	"granite_brick": {"name": "Granite Bricks", "kind": "block", "tile": "granite_brick", "color": Color(0.55, 0.40, 0.36)},
	"basalt": {"name": "Basalt", "kind": "block", "tile": "basalt", "color": Color(0.20, 0.20, 0.23)},
	"basalt_brick": {"name": "Basalt Bricks", "kind": "block", "tile": "basalt_brick", "color": Color(0.20, 0.20, 0.23)},
	"limestone": {"name": "Limestone", "kind": "block", "tile": "limestone", "color": Color(0.72, 0.68, 0.58)},
	"limestone_brick": {"name": "Limestone Bricks", "kind": "block", "tile": "limestone_brick", "color": Color(0.72, 0.68, 0.58)},
	"door": {"name": "Door", "kind": "block", "color": Color(0.45, 0.3, 0.17)},
	"torch": {"name": "Torch", "kind": "block", "color": Color(0.9, 0.6, 0.25)},
	"stone_forge": {"name": "Stone Forge", "kind": "block", "color": Color(0.5, 0.5, 0.52)},
	"stone_pickaxe": {"name": "Stone Pickaxe", "kind": "tool", "tool": "pickaxe", "power": 2.0, "max_stack": 1, "color": Color(0.55, 0.57, 0.52)},
	"stone_axe": {"name": "Stone Axe", "kind": "tool", "tool": "axe", "power": 2.0, "max_stack": 1, "color": Color(0.55, 0.57, 0.52)},
	"stone_shovel": {"name": "Stone Shovel", "kind": "tool", "tool": "shovel", "power": 2.0, "max_stack": 1, "color": Color(0.55, 0.57, 0.52)},
	"stone_sword": {"name": "Stone Sword", "kind": "weapon", "max_stack": 1, "damage": 4, "cooldown": 0.45, "reach": 2.6, "color": Color(0.55, 0.57, 0.52)},
	"stone_helmet": {"name": "Stone Helmet", "kind": "armor", "slot": "head", "defense": 1, "max_stack": 1, "color": Color(0.55, 0.57, 0.52)},
	"stone_chestplate": {"name": "Stone Chestplate", "kind": "armor", "slot": "chest", "defense": 2, "max_stack": 1, "color": Color(0.55, 0.57, 0.52)},
	"stone_leggings": {"name": "Stone Leggings", "kind": "armor", "slot": "legs", "defense": 2, "max_stack": 1, "color": Color(0.55, 0.57, 0.52)},
	"stone_boots": {"name": "Stone Boots", "kind": "armor", "slot": "feet", "defense": 1, "max_stack": 1, "color": Color(0.55, 0.57, 0.52)},
	"iron_pickaxe": {"name": "Iron Pickaxe", "kind": "tool", "tool": "pickaxe", "power": 3.4, "max_stack": 1, "color": Color(0.72, 0.78, 0.84)},
	"iron_axe": {"name": "Iron Axe", "kind": "tool", "tool": "axe", "power": 3.4, "max_stack": 1, "color": Color(0.72, 0.78, 0.84)},
	"iron_shovel": {"name": "Iron Shovel", "kind": "tool", "tool": "shovel", "power": 3.4, "max_stack": 1, "color": Color(0.72, 0.78, 0.84)},
	"iron_sword": {"name": "Iron Sword", "kind": "weapon", "max_stack": 1, "damage": 6, "cooldown": 0.4, "reach": 2.6, "color": Color(0.72, 0.78, 0.84)},
	"iron_helmet": {"name": "Iron Helmet", "kind": "armor", "slot": "head", "defense": 2, "max_stack": 1, "color": Color(0.72, 0.78, 0.84)},
	"iron_chestplate": {"name": "Iron Chestplate", "kind": "armor", "slot": "chest", "defense": 4, "max_stack": 1, "color": Color(0.72, 0.78, 0.84)},
	"iron_leggings": {"name": "Iron Leggings", "kind": "armor", "slot": "legs", "defense": 3, "max_stack": 1, "color": Color(0.72, 0.78, 0.84)},
	"iron_boots": {"name": "Iron Boots", "kind": "armor", "slot": "feet", "defense": 2, "max_stack": 1, "color": Color(0.72, 0.78, 0.84)},
}

var slots: Array = []
var equipment: Dictionary = {}
var discovered: Dictionary = {}
var selected: int = 0


func _init() -> void:
	reset()


func reset() -> void:
	slots = []
	for i in STORAGE_SIZE:
		slots.append({})
	equipment = {}
	for slot_name in EQUIP_SLOTS:
		equipment[slot_name] = {}
	slots[0] = {"id": "sword", "count": 1}
	slots[1] = {"id": "torch", "count": 4}
	discovered = {"sword": true, "torch": true}
	selected = 0
	changed.emit()
	selection_changed.emit(0)


func export_state() -> Dictionary:
	return {"slots": slots, "equipment": equipment, "selected": selected, "discovered": discovered.keys()}


func import_state(d: Dictionary) -> void:
	reset()
	if d.has("slots"):
		var saved: Array = d["slots"]
		for i in mini(saved.size(), STORAGE_SIZE):
			slots[i] = _clean(saved[i])
		var saved_equip: Dictionary = d.get("equipment", {})
		for slot_name in EQUIP_SLOTS:
			equipment[slot_name] = _clean(saved_equip.get(slot_name, {}))
	elif d.has("items"):
		var legacy: Dictionary = d["items"]
		for key in legacy:
			if ITEMS.has(key):
				add_item(key, int(legacy[key]))
	for id in d.get("discovered", []):
		if ITEMS.has(id):
			discovered[id] = true
	for item in slots:
		if not item.is_empty():
			discovered[item["id"]] = true
	selected = clampi(int(d.get("selected", 0)), 0, SLOT_COUNT - 1)
	changed.emit()
	selection_changed.emit(selected)


func _clean(item) -> Dictionary:
	if typeof(item) != TYPE_DICTIONARY or not item.has("id") or not ITEMS.has(item["id"]):
		return {}
	var count := int(item.get("count", 0))
	if count <= 0:
		return {}
	return {"id": str(item["id"]), "count": mini(count, max_stack(item["id"]))}


func max_stack(id: String) -> int:
	return int(ITEMS.get(id, {}).get("max_stack", MAX_STACK))


func item_name(id: String) -> String:
	return str(ITEMS.get(id, {}).get("name", id.capitalize()))


func set_slot(index: int, item: Dictionary) -> void:
	slots[index] = item
	changed.emit()


func set_equip(slot_name: String, item: Dictionary) -> void:
	equipment[slot_name] = item
	changed.emit()


func add_item(id: String, amount: int) -> int:
	var left := amount
	var cap := max_stack(id)
	for i in STORAGE_SIZE:
		if left <= 0:
			break
		var s: Dictionary = slots[i]
		if not s.is_empty() and s["id"] == id and int(s["count"]) < cap:
			var put := mini(cap - int(s["count"]), left)
			s["count"] = int(s["count"]) + put
			left -= put
	for i in STORAGE_SIZE:
		if left <= 0:
			break
		if slots[i].is_empty():
			var put := mini(cap, left)
			slots[i] = {"id": id, "count": put}
			left -= put
	if left != amount:
		discover(id)
		changed.emit()
	return left


func discover(id: String) -> void:
	if discovered.has(id):
		return
	var was_known: Dictionary = {}
	for r in Recipes.LIST:
		was_known[r["id"]] = Recipes.known(r, discovered)
	discovered[id] = true
	var fresh: Array = []
	for r in Recipes.LIST:
		if not was_known[r["id"]] and Recipes.known(r, discovered):
			fresh.append(r["id"])
	if not fresh.is_empty():
		recipes_unlocked.emit(fresh)


func take_item(id: String, amount: int) -> bool:
	if get_count(id) < amount:
		return false
	var left := amount
	for i in range(STORAGE_SIZE - 1, -1, -1):
		if left <= 0:
			break
		var s: Dictionary = slots[i]
		if s.is_empty() or s["id"] != id:
			continue
		var take := mini(int(s["count"]), left)
		s["count"] = int(s["count"]) - take
		left -= take
		if int(s["count"]) <= 0:
			slots[i] = {}
	changed.emit()
	return true


func can_accept(id: String) -> bool:
	var cap := max_stack(id)
	for i in STORAGE_SIZE:
		var s: Dictionary = slots[i]
		if s.is_empty() or (s["id"] == id and int(s["count"]) < cap):
			return true
	return false


func get_count(id: String) -> int:
	var total := 0
	for i in STORAGE_SIZE:
		var s: Dictionary = slots[i]
		if not s.is_empty() and s["id"] == id:
			total += int(s["count"])
	return total


func combine_into(index: int) -> void:
	var target: Dictionary = slots[index]
	if target.is_empty():
		return
	var cap := max_stack(target["id"])
	for i in STORAGE_SIZE:
		if i == index:
			continue
		if int(target["count"]) >= cap:
			break
		var s: Dictionary = slots[i]
		if s.is_empty() or s["id"] != target["id"]:
			continue
		var move := mini(cap - int(target["count"]), int(s["count"]))
		target["count"] = int(target["count"]) + move
		s["count"] = int(s["count"]) - move
		if int(s["count"]) <= 0:
			slots[i] = {}
	changed.emit()


func select_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT or index == selected:
		return
	selected = index
	selection_changed.emit(index)


func selected_item() -> Dictionary:
	return slots[selected]


func selected_count() -> int:
	var s: Dictionary = slots[selected]
	if s.is_empty():
		return 0
	return int(s["count"])


func consume_selected(amount: int) -> bool:
	var s: Dictionary = slots[selected]
	if s.is_empty() or int(s["count"]) < amount:
		return false
	s["count"] = int(s["count"]) - amount
	if int(s["count"]) <= 0:
		slots[selected] = {}
	changed.emit()
	return true


func held_weapon() -> Dictionary:
	var s: Dictionary = slots[selected]
	if s.is_empty():
		return {}
	var info: Dictionary = ITEMS.get(s["id"], {})
	if info.get("kind", "") == "weapon":
		return info
	return {}


func held_tool() -> Dictionary:
	var s: Dictionary = slots[selected]
	if s.is_empty():
		return {}
	var info: Dictionary = ITEMS.get(s["id"], {})
	if info.get("kind", "") == "tool":
		return info
	return {}


func tool_power(category: String) -> float:
	var info := held_tool()
	if info.is_empty() or info.get("tool", "") != category:
		return 1.0
	return float(info.get("power", 1.0))


func armor_reduction() -> float:
	var total := 0
	for slot_name in EQUIP_SLOTS:
		var item: Dictionary = equipment.get(slot_name, {})
		if item.is_empty():
			continue
		total += int(ITEMS.get(item["id"], {}).get("defense", 0))
	return clampf(float(total) * 0.04, 0.0, 0.6)


func held_block_type() -> String:
	var s: Dictionary = slots[selected]
	if s.is_empty() or not BLOCK_TYPES.has(s["id"]):
		return ""
	return s["id"]
