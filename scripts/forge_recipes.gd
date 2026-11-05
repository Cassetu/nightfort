extends RefCounted

const LIST := [
	{"id": "stone_pickaxe", "cost": {"stone": 3, "plank": 2}, "coal": 1, "strikes": 3, "zone": 0.24, "speed": 0.9},
	{"id": "stone_axe", "cost": {"stone": 3, "plank": 2}, "coal": 1, "strikes": 3, "zone": 0.24, "speed": 0.9},
	{"id": "stone_shovel", "cost": {"stone": 1, "plank": 2}, "coal": 1, "strikes": 2, "zone": 0.26, "speed": 0.9},
	{"id": "stone_sword", "cost": {"stone": 2, "plank": 1}, "coal": 1, "strikes": 3, "zone": 0.22, "speed": 1.0},
	{"id": "stone_helmet", "cost": {"stone": 5}, "coal": 1, "strikes": 3, "zone": 0.22, "speed": 1.0},
	{"id": "stone_chestplate", "cost": {"stone": 8}, "coal": 2, "strikes": 4, "zone": 0.22, "speed": 1.0},
	{"id": "stone_leggings", "cost": {"stone": 7}, "coal": 1, "strikes": 4, "zone": 0.22, "speed": 1.0},
	{"id": "stone_boots", "cost": {"stone": 4}, "coal": 1, "strikes": 3, "zone": 0.22, "speed": 1.0},
	{"id": "iron_pickaxe", "cost": {"iron": 3, "plank": 2}, "coal": 2, "strikes": 5, "zone": 0.16, "speed": 1.35},
	{"id": "iron_axe", "cost": {"iron": 3, "plank": 2}, "coal": 2, "strikes": 5, "zone": 0.16, "speed": 1.35},
	{"id": "iron_shovel", "cost": {"iron": 1, "plank": 2}, "coal": 2, "strikes": 4, "zone": 0.18, "speed": 1.3},
	{"id": "iron_sword", "cost": {"iron": 2, "plank": 1}, "coal": 2, "strikes": 5, "zone": 0.15, "speed": 1.4},
	{"id": "iron_helmet", "cost": {"iron": 5}, "coal": 2, "strikes": 5, "zone": 0.15, "speed": 1.4},
	{"id": "iron_chestplate", "cost": {"iron": 8}, "coal": 3, "strikes": 6, "zone": 0.14, "speed": 1.45},
	{"id": "iron_leggings", "cost": {"iron": 7}, "coal": 2, "strikes": 6, "zone": 0.14, "speed": 1.45},
	{"id": "iron_boots", "cost": {"iron": 4}, "coal": 2, "strikes": 5, "zone": 0.16, "speed": 1.4},
]


static func by_id(id: String) -> Dictionary:
	for r in LIST:
		if r["id"] == id:
			return r
	return {}


static func can_afford(r: Dictionary) -> bool:
	if Inventory.get_count("coal") < int(r["coal"]):
		return false
	var cost: Dictionary = r["cost"]
	for id in cost:
		if Inventory.get_count(id) < int(cost[id]):
			return false
	return true


static func cost_text(r: Dictionary) -> String:
	var parts: Array = []
	var cost: Dictionary = r["cost"]
	for id in cost:
		parts.append("%d %s" % [int(cost[id]), Inventory.item_name(id)])
	parts.append("%d Coal" % int(r["coal"]))
	return ", ".join(parts)
