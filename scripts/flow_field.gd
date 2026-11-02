extends Node

const RADIUS := 48
const SIZE := RADIUS * 2 + 1
const MAX_UP := 1
const MAX_DOWN := 3
const BLOCK_EXTRA := 6.0
const OBSTACLE_EXTRA := 30.0
const REBUILD_INTERVAL := 1.0
const HEIGHT_SLICE := 700
const NONE := 255
const DX := [1, 1, 0, -1, -1, -1, 0, 1]
const DZ := [0, 1, 1, 1, 0, -1, -1, -1]

class Heap:
	var keys := PackedFloat32Array()
	var ids := PackedInt32Array()
	var count: int = 0
	var top_key: float = 0.0

	func push(key: float, id: int) -> void:
		if count == keys.size():
			keys.append(key)
			ids.append(id)
		else:
			keys[count] = key
			ids[count] = id
		var i := count
		count += 1
		while i > 0:
			var p := (i - 1) >> 1
			if keys[p] <= keys[i]:
				break
			var tk := keys[p]
			var ti := ids[p]
			keys[p] = keys[i]
			ids[p] = ids[i]
			keys[i] = tk
			ids[i] = ti
			i = p

	func pop() -> int:
		var result := ids[0]
		top_key = keys[0]
		count -= 1
		if count > 0:
			keys[0] = keys[count]
			ids[0] = ids[count]
			var i := 0
			while true:
				var l := i * 2 + 1
				var r := l + 1
				var s := i
				if l < count and keys[l] < keys[s]:
					s = l
				if r < count and keys[r] < keys[s]:
					s = r
				if s == i:
					break
				var tk := keys[s]
				var ti := ids[s]
				keys[s] = keys[i]
				ids[s] = ids[i]
				keys[i] = tk
				ids[i] = ti
				i = s
		return result


var terrain
var core
var origin := Vector2i.ZERO
var goal_cells := PackedInt32Array()
var heights := PackedInt32Array()
var extra := PackedFloat32Array()
var flow := PackedByteArray()
var job_flow := PackedByteArray()
var built: int = 0
var heights_ready: bool = false
var is_ready: bool = false
var dirty: bool = false
var job: int = -1
var timer: float = 0.0
var signature: int = 0


func setup(t, c) -> void:
	terrain = t
	core = c
	var cx := floori(core.global_position.x)
	var cz := floori(core.global_position.z)
	origin = Vector2i(cx - RADIUS, cz - RADIUS)
	heights.resize(SIZE * SIZE)
	extra.resize(SIZE * SIZE)
	flow.resize(SIZE * SIZE)
	flow.fill(NONE)
	goal_cells.clear()
	for dz in range(-1, 1):
		for dx in range(-1, 1):
			goal_cells.append((RADIUS + dz) * SIZE + RADIUS + dx)
	terrain.block_broken.connect(_on_block_broken)


func _exit_tree() -> void:
	if job != -1:
		WorkerThreadPool.wait_for_task_completion(job)
		job = -1


func direction_at(pos: Vector3) -> Vector3:
	if is_ready:
		var gx := floori(pos.x) - origin.x
		var gz := floori(pos.z) - origin.y
		if gx >= 0 and gz >= 0 and gx < SIZE and gz < SIZE:
			var d := flow[gz * SIZE + gx]
			if d != NONE:
				return Vector3(DX[d], 0.0, DZ[d]).normalized()
	if is_instance_valid(core):
		var to_core: Vector3 = core.global_position - pos
		to_core.y = 0.0
		return to_core.normalized()
	return Vector3.ZERO


func _on_block_broken(cell: Vector3i) -> void:
	var gx := cell.x - origin.x
	var gz := cell.z - origin.y
	if gx < 0 or gz < 0 or gx >= SIZE or gz >= SIZE:
		return
	heights[gz * SIZE + gx] = terrain.surface_y(cell.x, cell.z)
	dirty = true


func _process(delta: float) -> void:
	if terrain == null:
		return

	if not heights_ready:
		_build_heights()
		return

	if job != -1:
		if WorkerThreadPool.is_task_completed(job):
			WorkerThreadPool.wait_for_task_completion(job)
			job = -1
			flow = job_flow
			is_ready = true
		return

	timer += delta
	if not dirty and timer < REBUILD_INTERVAL:
		return
	timer = 0.0

	var sig := _collect_extra()
	if not dirty and sig == signature and is_ready:
		return
	signature = sig
	dirty = false
	job = WorkerThreadPool.add_task(_solve.bind(heights, extra, goal_cells), false, "flow field")


func _build_heights() -> void:
	var end := mini(built + HEIGHT_SLICE, SIZE * SIZE)
	for i in range(built, end):
		var gx := i % SIZE
		var gz := i / SIZE
		heights[i] = terrain.surface_y(origin.x + gx, origin.y + gz)
	built = end
	if built >= SIZE * SIZE:
		heights_ready = true
		dirty = true


func _collect_extra() -> int:
	extra.fill(0.0)
	var sig := 17
	var nodes: Array = get_tree().get_nodes_in_group("resource")
	nodes.append_array(get_tree().get_nodes_in_group("torch"))
	for node: Node in nodes:
		if node.get("dying"):
			continue
		var p: Vector3 = node.global_position
		var gx := floori(p.x) - origin.x
		var gz := floori(p.z) - origin.y
		if gx < 0 or gz < 0 or gx >= SIZE or gz >= SIZE:
			continue
		var idx := gz * SIZE + gx
		if node.is_in_group("block"):
			extra[idx] = maxf(extra[idx], BLOCK_EXTRA)
		else:
			extra[idx] = maxf(extra[idx], OBSTACLE_EXTRA)
		sig = sig * 31 + idx
	return sig


func _solve(h: PackedInt32Array, ex: PackedFloat32Array, goals: PackedInt32Array) -> void:
	var n := SIZE * SIZE
	var cost := PackedFloat32Array()
	cost.resize(n)
	cost.fill(INF)
	var out := PackedByteArray()
	out.resize(n)
	out.fill(NONE)
	var heap := Heap.new()

	for g in goals:
		cost[g] = 0.0
		heap.push(0.0, g)

	while heap.count > 0:
		var u := heap.pop()
		var ck := heap.top_key
		if ck > cost[u]:
			continue
		var ux := u % SIZE
		var uz := u / SIZE
		for d in 8:
			var vx: int = ux + DX[d]
			var vz: int = uz + DZ[d]
			if vx < 0 or vz < 0 or vx >= SIZE or vz >= SIZE:
				continue
			var v := vz * SIZE + vx
			var dh := h[u] - h[v]
			if dh > MAX_UP or dh < -MAX_DOWN:
				continue
			var step := 1.0
			if DX[d] != 0 and DZ[d] != 0:
				var a := h[vz * SIZE + ux] - h[v]
				var b := h[uz * SIZE + vx] - h[v]
				if a > MAX_UP or a < -MAX_DOWN or b > MAX_UP or b < -MAX_DOWN:
					continue
				step = 1.4142
			var nc := ck + step + ex[u] + 0.35 * absf(float(dh))
			if nc < cost[v]:
				cost[v] = nc
				out[v] = (d + 4) % 8
				heap.push(nc, v)

	job_flow = out
