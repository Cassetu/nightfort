extends RefCounted

const LIST := [
	{"id": "workbench", "out": "workbench", "count": 1, "shape": [["wood", "wood"], ["wood", "wood"]]},
	{"id": "plank", "out": "plank", "count": 4, "shapeless": ["wood"]},
	{"id": "stone_brick", "out": "stone_brick", "count": 4, "shape": [["stone", "stone"], ["stone", "stone"]]},
	{"id": "sandstone", "out": "sandstone", "count": 4, "shape": [["sand", "sand"], ["sand", "sand"]]},
	{"id": "diorite_brick", "out": "diorite_brick", "count": 4, "shape": [["diorite", "diorite"], ["diorite", "diorite"]]},
	{"id": "granite_brick", "out": "granite_brick", "count": 4, "shape": [["granite", "granite"], ["granite", "granite"]]},
	{"id": "basalt_brick", "out": "basalt_brick", "count": 4, "shape": [["basalt", "basalt"], ["basalt", "basalt"]]},
	{"id": "limestone_brick", "out": "limestone_brick", "count": 4, "shape": [["limestone", "limestone"], ["limestone", "limestone"]]},
	{"id": "torch", "out": "torch", "count": 4, "shape": [["coal"], ["plank"]]},
	{"id": "chest", "out": "chest", "count": 1, "shape": [["plank", "plank", "plank"], ["plank", "", "plank"], ["plank", "plank", "plank"]]},
	{"id": "lantern", "out": "lantern", "count": 1, "shape": [["iron"], ["torch"], ["iron"]]},
	{"id": "door", "out": "door", "count": 1, "shape": [["plank", "plank"], ["plank", "plank"], ["plank", "plank"]]},
	{"id": "stick", "out": "stick", "count": 8, "shape": [["plank"], ["plank"]]},
	{"id": "ladder", "out": "ladder", "count": 3, "shape": [["stick"], ["stick"], ["stick"]]},
	{"id": "bow", "out": "bow", "count": 1, "shapeless": ["stick", "stick", "stick", "plank"]},
	{"id": "arrow", "out": "arrow", "count": 4, "shape": [["stone"], ["stick"]]},
	{"id": "wooden_pickaxe", "out": "wooden_pickaxe", "count": 1, "shape": [["plank", "plank", "plank"], ["fiber", "stick", "fiber"], ["", "stick", ""]]},
	{"id": "wooden_axe", "out": "wooden_axe", "count": 1, "shape": [["plank", "plank"], ["plank", "stick"], ["fiber", "stick"]]},
	{"id": "wooden_shovel", "out": "wooden_shovel", "count": 1, "shape": [["fiber", "plank"], ["", "stick"], ["", "stick"]]},
	{"id": "wooden_sword", "out": "wooden_sword", "count": 1, "shape": [["", "plank"], ["", "plank"], ["fiber", "stick"]]},
	{"id": "stone_pickaxe", "out": "stone_pickaxe", "count": 1, "shape": [["stone", "stone", "stone"], ["fiber", "stick", "fiber"], ["", "stick", ""]]},
	{"id": "stone_axe", "out": "stone_axe", "count": 1, "shape": [["stone", "stone"], ["stone", "stick"], ["fiber", "stick"]]},
	{"id": "stone_shovel", "out": "stone_shovel", "count": 1, "shape": [["fiber", "stone"], ["", "stick"], ["", "stick"]]},
	{"id": "stone_sword", "out": "stone_sword", "count": 1, "shape": [["", "stone"], ["", "stone"], ["fiber", "stick"]]},
	{"id": "scythe", "out": "scythe", "count": 1, "shape": [["stone", "stone", "fiber"], ["", "stick", ""], ["", "stick", ""]]},
	{"id": "stone_helmet", "out": "stone_helmet", "count": 1, "shape": [["stone", "stone", "stone"], ["stone", "fiber", "stone"]]},
	{"id": "stone_chestplate", "out": "stone_chestplate", "count": 1, "shape": [["stone", "fiber", "stone"], ["stone", "stone", "stone"], ["stone", "stone", "stone"]]},
	{"id": "stone_leggings", "out": "stone_leggings", "count": 1, "shape": [["stone", "stone", "stone"], ["stone", "fiber", "stone"], ["stone", "", "stone"]]},
	{"id": "stone_boots", "out": "stone_boots", "count": 1, "shape": [["stone", "", "stone"], ["stone", "fiber", "stone"]]},
	{"id": "barricade", "out": "barricade", "count": 1, "shape": [["wood", "wood", "wood"], ["wood", "wood", "wood"], ["wood", "wood", "wood"]]},
	{"id": "scaffold", "out": "scaffold", "count": 8, "shape": [["plank"], ["plank"], ["plank"]]},
	{"id": "iron_block", "out": "iron_block", "count": 1, "shape": [["iron", "iron", "iron"], ["iron", "iron", "iron"], ["iron", "iron", "iron"]]},
	{"id": "stone_forge", "out": "stone_forge", "count": 1, "shape": [["stone_brick", "stone_brick", "stone_brick"], ["stone_brick", "coal", "stone_brick"], ["stone_brick", "stone_brick", "stone_brick"]]},
	{"id": "fortified_brick", "out": "fortified_brick", "count": 4, "shape": [["stone_brick", "stone_brick", "stone_brick"], ["stone_brick", "", "stone_brick"], ["stone_brick", "stone_brick", "stone_brick"]]},
]


static func by_id(id: String) -> Dictionary:
	for r in LIST:
		if r["id"] == id:
			return r
	return {}


static func cells_of(r: Dictionary) -> Array:
	var out: Array = []
	if r.has("shapeless"):
		out.append_array(r["shapeless"])
	else:
		for row in r["shape"]:
			for id in row:
				if id != "":
					out.append(id)
	return out


static func ingredient_counts(r: Dictionary) -> Dictionary:
	var counts := {}
	for id in cells_of(r):
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


static func needs_table(r: Dictionary) -> bool:
	if r.get("table", false):
		return true
	if r.has("shapeless"):
		return r["shapeless"].size() > 4
	var shape: Array = r["shape"]
	return shape.size() > 2 or shape[0].size() > 2


static func known(r: Dictionary, discovered: Dictionary) -> bool:
	for id in ingredient_counts(r):
		if not discovered.has(id):
			return false
	return true


static func match_grid(cells: Array, size: int) -> Dictionary:
	var min_r := size
	var max_r := -1
	var min_c := size
	var max_c := -1
	for i in cells.size():
		if cells[i] != "":
			var r := i / size
			var c := i % size
			min_r = mini(min_r, r)
			max_r = maxi(max_r, r)
			min_c = mini(min_c, c)
			max_c = maxi(max_c, c)
	if max_r < 0:
		return {}

	var h := max_r - min_r + 1
	var w := max_c - min_c + 1
	var crop: Array = []
	var flat: Array = []
	for r in range(min_r, max_r + 1):
		var row: Array = []
		for c in range(min_c, max_c + 1):
			row.append(cells[r * size + c])
			if cells[r * size + c] != "":
				flat.append(cells[r * size + c])
		crop.append(row)
	flat.sort()

	for rec in LIST:
		if rec.has("shapeless"):
			var want: Array = rec["shapeless"].duplicate()
			want.sort()
			if want == flat:
				return rec
		else:
			var shape: Array = rec["shape"]
			if shape.size() != h or shape[0].size() != w:
				continue
			if _same(shape, crop, false) or _same(shape, crop, true):
				return rec
	return {}


static func _same(shape: Array, crop: Array, mirror: bool) -> bool:
	for r in shape.size():
		var width: int = shape[r].size()
		for c in width:
			var cc := width - 1 - c if mirror else c
			if shape[r][c] != crop[r][cc]:
				return false
	return true
