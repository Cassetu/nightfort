extends RefCounted

const DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const MAX_NODES := 9000
const MAX_FALL := 3
const MAX_SPREAD := 48

var terrain
var cells: Dictionary = {}
var ladders: Dictionary = {}
var avoid: Dictionary = {}
var solid_cache: Dictionary = {}


func setup(t, stability, tree: SceneTree) -> void:
	terrain = t
	cells = stability.cell_map
	ladders.clear()
	avoid.clear()
	solid_cache.clear()
	for b in tree.get_nodes_in_group("barricade"):
		if is_instance_valid(b) and not b.dying:
			avoid[_cell_of(b)] = true
	for n in tree.get_nodes_in_group("ladder"):
		if is_instance_valid(n) and not n.dying:
			ladders[Vector3i(floori(n.global_position.x), floori(n.global_position.y), floori(n.global_position.z))] = true


func _cell_of(n) -> Vector3i:
	return Vector3i(floori(n.global_position.x), floori(n.global_position.y), floori(n.global_position.z))


func solid(c: Vector3i) -> bool:
	if solid_cache.has(c):
		return solid_cache[c]
	var s: bool = terrain.block_at(c.x, c.y, c.z) != 0
	if not s:
		var n = cells.get(c)
		if n != null and is_instance_valid(n) and not n.dying:
			s = n.get("is_open") != true
	solid_cache[c] = s
	return s


func passable(c: Vector3i) -> bool:
	return not solid(c) and not solid(c + Vector3i.UP) and not avoid.has(c) and not avoid.has(c + Vector3i.UP)


func standable(c: Vector3i) -> bool:
	return passable(c) and (ladders.has(c) or solid(c + Vector3i.DOWN))


func neighbors(c: Vector3i) -> Array:
	var out: Array = []
	for d: Vector3i in DIRS:
		var n: Vector3i = c + d
		if standable(n):
			out.append(n)
			continue
		var up: Vector3i = n + Vector3i.UP
		if not solid(c + Vector3i(0, 2, 0)) and standable(up):
			out.append(up)
			continue
		if passable(n):
			var cur: Vector3i = n
			for k in MAX_FALL:
				cur += Vector3i.DOWN
				if not passable(cur):
					break
				if standable(cur):
					out.append(cur)
					break
	if ladders.has(c):
		var above: Vector3i = c + Vector3i.UP
		if ladders.has(above):
			out.append(above)
		var below: Vector3i = c + Vector3i.DOWN
		if ladders.has(below) or standable(below):
			out.append(below)
	return out


func find(start: Vector3i, goal: Vector3i) -> Array:
	if start == goal:
		return [start]
	var prev: Dictionary = {start: start}
	var queue: Array = [start]
	var head := 0
	while head < queue.size() and prev.size() < MAX_NODES:
		var c: Vector3i = queue[head]
		head += 1
		for n: Vector3i in neighbors(c):
			if prev.has(n):
				continue
			if absi(n.x - start.x) > MAX_SPREAD or absi(n.z - start.z) > MAX_SPREAD:
				continue
			prev[n] = c
			if n == goal:
				var path: Array = [n]
				var at: Vector3i = n
				while at != start:
					at = prev[at]
					path.push_front(at)
				return path
			queue.append(n)
	return []
