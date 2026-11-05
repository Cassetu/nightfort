extends Node

const MAX_DIST := 5
const TICK := 0.2
const DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const BASE_REACH := 4

var terrain
var dirty: bool = true
var timer: float = 0.0
var cell_map: Dictionary = {}
var state: Dictionary = {}
var unstable: Dictionary = {}


func _ready() -> void:
	add_to_group("stability")


func setup(t) -> void:
	terrain = t


func mark_dirty() -> void:
	dirty = true


func is_unstable(node) -> bool:
	return unstable.has(node)


func reach_of(node) -> int:
	if node.falls:
		return MAX_DIST
	return maxi(0, BASE_REACH - node.weight)


func _process(delta: float) -> void:
	if terrain == null or not dirty:
		return
	timer += delta
	if timer < TICK:
		return
	timer = 0.0
	_recompute()


func _relax(v, nd: int, ncap: int, dist: Dictionary, cap: Dictionary, levels: Array) -> void:
	if nd > MAX_DIST:
		return
	if not dist.has(v) or nd < dist[v] or (nd == dist[v] and ncap > cap[v]):
		dist[v] = nd
		cap[v] = ncap
		levels[nd].append(v)


func _recompute() -> void:
	dirty = false
	cell_map.clear()
	state.clear()
	unstable.clear()

	var nodes: Array = []
	for n in get_tree().get_nodes_in_group("block"):
		if n.dying or not n.structural or n.falling_now:
			continue
		nodes.append(n)
		for c: Vector3i in n.cells():
			cell_map[c] = n

	var dist: Dictionary = {}
	var cap: Dictionary = {}
	var levels: Array = []
	for i in MAX_DIST + 1:
		levels.append([])

	for n in nodes:
		var base: Vector3i = n.cells()[0]
		if terrain.block_at(base.x, base.y - 1, base.z) != 0:
			dist[n] = 0
			cap[n] = reach_of(n)
			levels[0].append(n)

	for d in levels.size():
		var list: Array = levels[d]
		var i := 0
		while i < list.size():
			var u = list[i]
			i += 1
			if dist[u] != d or d > cap[u]:
				continue
			for c: Vector3i in u.cells():
				var above = cell_map.get(c + Vector3i.UP)
				if above != null and above != u and above.weight <= u.max_load:
					_relax(above, d, mini(cap[u], reach_of(above)), dist, cap, levels)
				if u.falls:
					continue
				for dir: Vector3i in DIRS:
					var side = cell_map.get(c + dir)
					if side != null and side != u and not side.falls and side.weight <= u.max_load:
						_relax(side, d + 1, mini(cap[u], reach_of(side)), dist, cap, levels)

	var solid: Dictionary = {}
	for n in nodes:
		if dist.has(n) and dist[n] <= cap[n]:
			state[n] = Vector2i(dist[n], cap[n])
			for c: Vector3i in n.cells():
				solid[c] = true
		else:
			unstable[n] = true

	var sands: Array = []
	for n in unstable:
		if n.falls:
			sands.append(n)
		else:
			n.begin_collapse(randf_range(0.5, 1.2))

	sands.sort_custom(func(a, b) -> bool: return a.cells()[0].y < b.cells()[0].y)
	for n in sands:
		var base: Vector3i = n.cells()[0]
		var y := base.y - 1
		while y > terrain.Y_MIN:
			if terrain.block_at(base.x, y, base.z) != 0 or solid.has(Vector3i(base.x, y, base.z)):
				break
			y -= 1
		if y <= terrain.Y_MIN:
			n.take_damage(n.max_health)
			continue
		var target := Vector3i(base.x, y + 1, base.z)
		solid[target] = true
		n.fall_to(target)


func evaluate(type: String, cell: Vector3i) -> int:
	if dirty:
		_recompute()
	var info: Dictionary = Inventory.BLOCK_TYPES[type]
	if not info.get("structural", true):
		return 0
	var falls: bool = info.get("falls", false)
	var my_weight: int = int(info.get("weight", 2))
	var reach := MAX_DIST if falls else maxi(0, BASE_REACH - my_weight)
	if terrain.block_at(cell.x, cell.y - 1, cell.z) != 0:
		return 0
	var best := -1
	var below = cell_map.get(cell + Vector3i.DOWN)
	if below != null and state.has(below) and my_weight <= below.max_load:
		var s: Vector2i = state[below]
		if s.x <= mini(s.y, reach):
			best = s.x
	if falls:
		return best
	for dir: Vector3i in DIRS:
		var side = cell_map.get(cell + dir)
		if side == null or not state.has(side) or my_weight > side.max_load:
			continue
		var t: Vector2i = state[side]
		var d := t.x + 1
		if d <= mini(t.y, reach) and (best < 0 or d < best):
			best = d
	return best


func reach_for_type(type: String) -> int:
	var info: Dictionary = Inventory.BLOCK_TYPES[type]
	if info.get("falls", false):
		return MAX_DIST
	return maxi(0, BASE_REACH - int(info.get("weight", 2)))
