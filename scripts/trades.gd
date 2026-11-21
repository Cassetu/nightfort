extends RefCounted

const POOL := [
	{"give": "wood", "give_n": 6, "get": "stone", "get_n": 4},
	{"give": "stone", "give_n": 6, "get": "plank", "get_n": 6},
	{"give": "bow", "give_n": 1, "get": "sword", "get_n": 1},
	{"give": "sword", "give_n": 1, "get": "bow", "get_n": 1},
	{"give": "fiber", "give_n": 6, "get": "arrow", "get_n": 6},
	{"give": "coal", "give_n": 4, "get": "iron", "get_n": 2},
	{"give": "iron", "give_n": 3, "get": "stone_brick", "get_n": 8},
	{"give": "plank", "give_n": 8, "get": "roof", "get_n": 4},
	{"give": "stone_brick", "give_n": 8, "get": "stone_stairs", "get_n": 4},
	{"give": "stick", "give_n": 8, "get": "fiber", "get_n": 8},
	{"give": "sand", "give_n": 8, "get": "dirt", "get_n": 8},
	{"give": "stone", "give_n": 10, "get": "coal", "get_n": 3},
]
const PER_FOLK := 4


static func roll(rng: RandomNumberGenerator) -> Array:
	var idx: Array = range(POOL.size())
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
	var out: Array = []
	for i in PER_FOLK:
		out.append(POOL[idx[i]])
	return out
