extends Node3D

const TreeScript = preload("res://scripts/tree.gd")
const RockScript = preload("res://scripts/rock.gd")

const CHUNK := 16
const PAD := CHUNK + 2
const AO_LEVELS := [0.55, 0.7, 0.85, 1.0]

const GRASS_DRY := Color(0.62, 0.60, 0.28)
const GRASS_LUSH := Color(0.18, 0.46, 0.16)
const SAND := Color(0.76, 0.68, 0.45)
const DIRT := Color(0.42, 0.29, 0.18)
const ROCK := Color(0.50, 0.50, 0.53)
const ROCK_DARK := Color(0.36, 0.36, 0.39)
const SNOW := Color(0.92, 0.94, 0.97)

@export_group("World")
@export var world_seed: int = 1337
@export var world_radius: float = 1500.0
@export var base_height: int = 1

@export_group("Streaming")
@export var view_distance: int = 8
@export var collision_distance: int = 3
@export var detail_distance: int = 5
@export var frame_budget_ms: float = 4.0
@export var max_in_flight: int = 6

@export_group("Shape")
@export var plateau_radius: float = 14.0
@export var plateau_blend: float = 26.0
@export var hill_amplitude: float = 12.0
@export var mountain_amplitude: float = 46.0
@export var border_width: float = 140.0
@export var border_height: float = 70.0
@export var rock_line: float = 17.0
@export var snow_line: float = 32.0

@export_group("Trees")
@export var tree_attempts: int = 48
@export var tree_spacing: float = 3.0
@export var tree_clear_radius: float = 40.0
@export var tree_line: int = 24

@export_group("Rocks")
@export var rock_attempts: int = 8
@export var rock_spacing: float = 2.2
@export var rock_clear_radius: float = 9.0
@export var boulder_chance: float = 0.12

class Chunk:
	var coord: Vector2i
	var root: Node3D
	var body: StaticBody3D
	var objects: Node3D
	var faces: PackedVector3Array
	var trees: Array
	var rocks: Array

var n_cont: FastNoiseLite
var n_hills: FastNoiseLite
var n_ridge: FastNoiseLite
var n_rough: FastNoiseLite
var n_detail: FastNoiseLite
var n_moist: FastNoiseLite
var n_forest: FastNoiseLite

var material: StandardMaterial3D
var player = null
var chunks: Dictionary = {}
var requested: Dictionary = {}
var results: Dictionary = {}
var depleted: Dictionary = {}
var wants: Array = []
var want_index: int = 0
var mutex := Mutex.new()
var last_center := Vector2i(2147483647, 0)
var levels_dirty: bool = true


func _ready() -> void:
	add_to_group("terrain")
	player = get_node_or_null("../Player")
	_setup_noise()
	_setup_material()
	_setup_fog()

	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var coord := Vector2i(dx, dz)
			var chunk := _finalize(coord, _generate(coord))
			_add_collision(chunk)
			_add_objects(chunk)


func _exit_tree() -> void:
	for id in requested.values():
		WorkerThreadPool.wait_for_task_completion(id)
	requested.clear()


func height_at(world_x: float, world_z: float) -> float:
	return float(_height(floori(world_x), floori(world_z)))


func _process(_delta: float) -> void:
	if player == null:
		return

	var center := _chunk_of(player.global_position)
	if center != last_center:
		last_center = center
		_refresh(center)

	_dispatch()

	var start := Time.get_ticks_usec()
	var budget := int(frame_budget_ms * 1000.0)
	while Time.get_ticks_usec() - start < budget:
		if _consume(center):
			continue
		if levels_dirty and _upgrade_one(center):
			continue
		break


func _physics_process(_delta: float) -> void:
	if player == null:
		return

	var p: Vector3 = player.global_position
	var flat := Vector2(p.x, p.z)
	var limit := world_radius - 6.0
	if flat.length() > limit:
		flat = flat.normalized() * limit
		player.global_position = Vector3(flat.x, p.y, flat.y)
		var v: Vector3 = player.velocity
		v.x = 0.0
		v.z = 0.0
		player.velocity = v

	if p.y < -40.0:
		player.global_position = Vector3(p.x, height_at(p.x, p.z) + 3.0, p.z)
		player.velocity = Vector3.ZERO


func _setup_noise() -> void:
	n_cont = _make_noise(1, 0.0025, 2)
	n_hills = _make_noise(2, 0.022, 3)
	n_ridge = _make_noise(3, 0.006, 1)
	n_rough = _make_noise(4, 0.035, 3)
	n_detail = _make_noise(5, 0.09, 2)
	n_moist = _make_noise(6, 0.005, 2)
	n_forest = _make_noise(7, 0.03, 1)


func _make_noise(seed_offset: int, frequency: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = world_seed + seed_offset
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	if octaves > 1:
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = octaves
	else:
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
	return n


func _setup_material() -> void:
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0


func _setup_fog() -> void:
	var we = get_node_or_null("../WorldEnvironment")
	if we == null or we.environment == null:
		return
	var env: Environment = we.environment
	var far := float(view_distance * CHUNK)
	env.fog_enabled = true
	if env.get("fog_mode") != null:
		env.set("fog_mode", 1)
		env.set("fog_depth_begin", far * 0.3)
		env.set("fog_depth_end", far * 0.95)
		env.set("fog_depth_curve", 1.4)
	else:
		env.fog_density = 2.0 / far


func _chunk_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CHUNK), floori(pos.z / CHUNK))


func _dist2(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return d.x * d.x + d.y * d.y


func _in_world(coord: Vector2i) -> bool:
	var c := Vector2((coord.x + 0.5) * CHUNK, (coord.y + 0.5) * CHUNK)
	return c.length() <= world_radius + CHUNK


func _refresh(center: Vector2i) -> void:
	var unload2 := (view_distance + 1) * (view_distance + 1)
	var drop_collision2 := (collision_distance + 1) * (collision_distance + 1)
	var drop_objects2 := (detail_distance + 1) * (detail_distance + 1)

	for coord: Vector2i in chunks.keys():
		var chunk: Chunk = chunks[coord]
		var d := _dist2(coord, center)
		if d > unload2:
			chunk.root.queue_free()
			chunks.erase(coord)
			continue
		if chunk.body != null and d > drop_collision2:
			chunk.body.queue_free()
			chunk.body = null
		if chunk.objects != null and d > drop_objects2:
			chunk.objects.queue_free()
			chunk.objects = null

	wants.clear()
	want_index = 0
	var r2 := view_distance * view_distance
	for dz in range(-view_distance, view_distance + 1):
		for dx in range(-view_distance, view_distance + 1):
			var d2 := dx * dx + dz * dz
			if d2 > r2:
				continue
			var coord := center + Vector2i(dx, dz)
			if not _in_world(coord) or chunks.has(coord) or requested.has(coord):
				continue
			wants.append([d2, coord])
	wants.sort_custom(func(a, b): return a[0] < b[0])
	levels_dirty = true


func _dispatch() -> void:
	while requested.size() < max_in_flight and want_index < wants.size():
		var coord: Vector2i = wants[want_index][1]
		want_index += 1
		if chunks.has(coord) or requested.has(coord):
			continue
		requested[coord] = WorkerThreadPool.add_task(_worker.bind(coord), false, "terrain chunk")


func _worker(coord: Vector2i) -> void:
	var data := _generate(coord)
	mutex.lock()
	results[coord] = data
	mutex.unlock()


func _consume(center: Vector2i) -> bool:
	var best = null
	var best_d := 1 << 30
	var data = null

	mutex.lock()
	for coord: Vector2i in results.keys():
		var d := _dist2(coord, center)
		if d < best_d:
			best_d = d
			best = coord
	if best != null:
		data = results[best]
		results.erase(best)
	mutex.unlock()

	if best == null:
		return false

	WorkerThreadPool.wait_for_task_completion(requested[best])
	requested.erase(best)
	if not chunks.has(best) and best_d <= (view_distance + 1) * (view_distance + 1):
		_finalize(best, data)
		levels_dirty = true
	return true


func _upgrade_one(center: Vector2i) -> bool:
	var best: Chunk = null
	var best_d := 1 << 30
	var wants_collision := false
	var c2 := collision_distance * collision_distance
	var o2 := detail_distance * detail_distance

	for chunk: Chunk in chunks.values():
		var d := _dist2(chunk.coord, center)
		if d >= best_d:
			continue
		var need_collision := chunk.body == null and d <= c2
		var need_objects := chunk.objects == null and d <= o2
		if need_collision or need_objects:
			best = chunk
			best_d = d
			wants_collision = need_collision

	if best == null:
		levels_dirty = false
		return false

	if wants_collision:
		_add_collision(best)
	else:
		_add_objects(best)
	return true


func _finalize(coord: Vector2i, data: Dictionary) -> Chunk:
	var chunk := Chunk.new()
	chunk.coord = coord
	chunk.faces = data["verts"]
	chunk.trees = data["trees"]
	chunk.rocks = data["rocks"]

	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [coord.x, coord.y]
	root.position = Vector3(coord.x * CHUNK, 0.0, coord.y * CHUNK)
	add_child(root)
	chunk.root = root

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["verts"]
	arrays[Mesh.ARRAY_NORMAL] = data["norms"]
	arrays[Mesh.ARRAY_COLOR] = data["cols"]

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	root.add_child(mi)

	chunks[coord] = chunk
	return chunk


func _add_collision(chunk: Chunk) -> void:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(chunk.faces)
	shape.backface_collision = true

	var col := CollisionShape3D.new()
	col.shape = shape

	var body := StaticBody3D.new()
	body.name = "Collision"
	body.add_child(col)
	chunk.root.add_child(body)
	chunk.body = body


func _add_objects(chunk: Chunk) -> void:
	var holder := Node3D.new()
	holder.name = "Objects"
	chunk.root.add_child(holder)
	chunk.objects = holder

	for i in chunk.trees.size():
		var key := Vector3i(chunk.coord.x, chunk.coord.y, i)
		if depleted.has(key):
			continue
		var d: Dictionary = chunk.trees[i]
		var tree = TreeScript.new()
		tree.size_factor = d["size"]
		tree.variant = d["variant"]
		tree.position = Vector3(d["x"], d["y"], d["z"])
		tree.rotation.y = d["rot"]
		tree.harvested.connect(_on_depleted.bind(key))
		holder.add_child(tree)

	for i in chunk.rocks.size():
		var key := Vector3i(chunk.coord.x, chunk.coord.y, 1000 + i)
		if depleted.has(key):
			continue
		var d: Dictionary = chunk.rocks[i]
		var rock = RockScript.new()
		rock.rock_seed = d["seed"]
		rock.size_factor = d["size"]
		rock.variant = d["variant"]
		rock.position = Vector3(d["x"], d["y"], d["z"])
		rock.rotation.y = d["rot"]
		rock.harvested.connect(_on_depleted.bind(key))
		holder.add_child(rock)


func _on_depleted(_resource_type, _amount, key) -> void:
	depleted[key] = true


func _height(x: int, z: int) -> int:
	var fx := x + 0.5
	var fz := z + 0.5
	var cont := clampf(n_cont.get_noise_2d(fx, fz) * 0.5 + 0.5, 0.0, 1.0)
	var hills := clampf(n_hills.get_noise_2d(fx, fz) * 0.5 + 0.5, 0.0, 1.0)
	var ridge := 1.0 - absf(n_ridge.get_noise_2d(fx, fz))
	var rough := n_rough.get_noise_2d(fx, fz) * 0.5 + 0.5

	var hill_scale := 0.22 + 0.78 * smoothstep(0.34, 0.6, cont)
	var mount := smoothstep(0.54, 0.74, cont)
	var massif := mount * (0.45 + 0.55 * ridge) * (0.75 + 0.5 * rough)
	var detail := n_detail.get_noise_2d(fx, fz) * 1.6 * (0.4 + 0.6 * hill_scale)
	var relief := pow(hills, 1.4) * hill_amplitude * hill_scale + massif * mountain_amplitude + detail

	var dist := Vector2(fx, fz).length()
	var blend := smoothstep(plateau_radius, plateau_radius + plateau_blend, dist)
	var wall := pow(clampf((dist - (world_radius - border_width)) / border_width, 0.0, 1.0), 2.0) * border_height

	return maxi(base_height + roundi(maxf(relief, 0.0) * blend + wall), 0)


func _moisture(x: float, z: float) -> float:
	var m := n_moist.get_noise_2d(x, z) * 0.5 + 0.5
	return clampf((m - 0.5) * 1.8 + 0.5, 0.0, 1.0)


func _top_color(h: int, moist: float) -> Color:
	var hf := float(h)
	var c := GRASS_DRY.lerp(GRASS_LUSH, moist)
	var sand_t := (1.0 - smoothstep(0.05, 0.22, moist)) * (1.0 - smoothstep(2.0, rock_line - 4.0, hf))
	c = c.lerp(SAND, sand_t)
	c = c.lerp(ROCK, smoothstep(rock_line, rock_line + 5.0, hf))
	return c.lerp(SNOW, smoothstep(snow_line, snow_line + 3.0, hf))


func _wall_color(h: int) -> Color:
	return DIRT.lerp(ROCK_DARK, smoothstep(rock_line - 4.0, rock_line + 2.0, float(h)))


func _shaded(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k)


func _hash(x: int, z: int) -> float:
	var n := (x * 73856093) ^ (z * 19349663) ^ (world_seed * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n >> 8) & 0xFFFF) / 65535.0


func _ao(heights: PackedInt32Array, i: int, h: int, cx: int, cz: int) -> float:
	var s1 := 1 if heights[i + cx] > h else 0
	var s2 := 1 if heights[i + cz * PAD] > h else 0
	var c := 1 if heights[i + cx + cz * PAD] > h else 0
	var level := 0 if (s1 == 1 and s2 == 1) else 3 - (s1 + s2 + c)
	return AO_LEVELS[level]


func _max_step(heights: PackedInt32Array, i: int, h: int) -> int:
	return maxi(maxi(absi(h - heights[i + 1]), absi(h - heights[i - 1])), maxi(absi(h - heights[i + PAD]), absi(h - heights[i - PAD])))


func _add_top(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, x: float, z: float, y: float, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	var a := Vector3(x, y, z)
	var b := Vector3(x + 1.0, y, z)
	var c := Vector3(x + 1.0, y, z + 1.0)
	var d := Vector3(x, y, z + 1.0)
	verts.append(a)
	verts.append(b)
	verts.append(c)
	verts.append(a)
	verts.append(c)
	verts.append(d)
	for k in 6:
		norms.append(Vector3.UP)
	cols.append(ca)
	cols.append(cb)
	cols.append(cc)
	cols.append(ca)
	cols.append(cc)
	cols.append(cd)


func _add_wall(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, ax: float, az: float, bx: float, bz: float, h: float, nh: float, n: Vector3, top_col: Color, bottom_col: Color) -> void:
	var a := Vector3(ax, h, az)
	var b := Vector3(bx, h, bz)
	var c := Vector3(bx, nh, bz)
	var d := Vector3(ax, nh, az)
	verts.append(a)
	verts.append(d)
	verts.append(c)
	verts.append(a)
	verts.append(c)
	verts.append(b)
	for k in 6:
		norms.append(n)
	cols.append(top_col)
	cols.append(bottom_col)
	cols.append(bottom_col)
	cols.append(top_col)
	cols.append(bottom_col)
	cols.append(top_col)


func _generate(coord: Vector2i) -> Dictionary:
	var ox := coord.x * CHUNK - 1
	var oz := coord.y * CHUNK - 1

	var heights := PackedInt32Array()
	heights.resize(PAD * PAD)
	for z in PAD:
		for x in PAD:
			heights[z * PAD + x] = _height(ox + x, oz + z)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var moist := PackedFloat32Array()
	moist.resize(CHUNK * CHUNK)

	for lz in CHUNK:
		for lx in CHUNK:
			var i := (lz + 1) * PAD + lx + 1
			var h := heights[i]
			var wx := coord.x * CHUNK + lx
			var wz := coord.y * CHUNK + lz
			var m := _moisture(wx + 0.5, wz + 0.5)
			moist[lz * CHUNK + lx] = m

			var shade := 0.9 + 0.2 * _hash(wx, wz)
			var top := _shaded(_top_color(h, m), shade)
			var fx := float(lx)
			var fz := float(lz)
			var fh := float(h)

			_add_top(verts, norms, cols, fx, fz, fh,
				_shaded(top, _ao(heights, i, h, -1, -1)),
				_shaded(top, _ao(heights, i, h, 1, -1)),
				_shaded(top, _ao(heights, i, h, 1, 1)),
				_shaded(top, _ao(heights, i, h, -1, 1)))

			var wall_top := _shaded(_wall_color(h), shade)
			var wall_bottom := _shaded(wall_top, 0.6)

			var nh := heights[i + 1]
			if nh < h:
				_add_wall(verts, norms, cols, fx + 1.0, fz, fx + 1.0, fz + 1.0, fh, float(nh), Vector3.RIGHT, wall_top, wall_bottom)
			nh = heights[i - 1]
			if nh < h:
				_add_wall(verts, norms, cols, fx, fz + 1.0, fx, fz, fh, float(nh), Vector3.LEFT, wall_top, wall_bottom)
			nh = heights[i + PAD]
			if nh < h:
				_add_wall(verts, norms, cols, fx + 1.0, fz + 1.0, fx, fz + 1.0, fh, float(nh), Vector3.BACK, wall_top, wall_bottom)
			nh = heights[i - PAD]
			if nh < h:
				_add_wall(verts, norms, cols, fx, fz, fx + 1.0, fz, fh, float(nh), Vector3.FORWARD, wall_top, wall_bottom)

	var rng := RandomNumberGenerator.new()
	rng.seed = (coord.x * 73856093) ^ (coord.y * 19349663) ^ (world_seed * 83492791)

	var trees: Array = []
	var rocks: Array = []
	var placed: Array = []
	var origin := Vector2(coord.x * CHUNK, coord.y * CHUNK)

	for _t in tree_attempts:
		var px := rng.randf_range(2.0, CHUNK - 2.0)
		var pz := rng.randf_range(2.0, CHUNK - 2.0)
		var lx := int(px)
		var lz := int(pz)
		var i := (lz + 1) * PAD + lx + 1
		var h := heights[i]
		if h > tree_line or _max_step(heights, i, h) > 1:
			continue
		var world := origin + Vector2(px, pz)
		if world.length() < tree_clear_radius:
			continue
		var density := smoothstep(-0.7, 0.2, n_forest.get_noise_2d(world.x, world.y)) * (0.55 + 0.45 * moist[lz * CHUNK + lx])
		if rng.randf() > density:
			continue
		var pos := Vector2(lx + 0.5 + rng.randf_range(-0.15, 0.15), lz + 0.5 + rng.randf_range(-0.15, 0.15))
		var blocked := false
		for other: Vector2 in placed:
			if other.distance_squared_to(pos) < tree_spacing * tree_spacing:
				blocked = true
				break
		if blocked:
			continue
		placed.append(pos)
		trees.append({
			"x": pos.x,
			"y": float(h),
			"z": pos.y,
			"size": rng.randf_range(0.8, 1.4),
			"variant": rng.randi_range(0, 4),
			"rot": rng.randf() * TAU,
		})

	for _r in rock_attempts:
		var px := rng.randf_range(2.0, CHUNK - 2.0)
		var pz := rng.randf_range(2.0, CHUNK - 2.0)
		var lx := int(px)
		var lz := int(pz)
		var i := (lz + 1) * PAD + lx + 1
		var h := heights[i]
		var world := origin + Vector2(px, pz)
		if world.length() < rock_clear_radius:
			continue
		var chance := clampf(0.2 + float(h) / 30.0 + 0.25 * (1.0 - moist[lz * CHUNK + lx]), 0.0, 0.8)
		if rng.randf() > chance:
			continue
		var boulder := rng.randf() < boulder_chance
		var spacing := rock_spacing
		if boulder:
			spacing = rock_spacing * 1.6
		var pos := Vector2(lx + 0.5 + rng.randf_range(-0.25, 0.25), lz + 0.5 + rng.randf_range(-0.25, 0.25))
		var blocked := false
		for other: Vector2 in placed:
			if other.distance_squared_to(pos) < spacing * spacing:
				blocked = true
				break
		if blocked:
			continue
		placed.append(pos)
		var base := mini(mini(h, heights[i + 1]), mini(mini(heights[i - 1], heights[i + PAD]), heights[i - PAD]))
		var size := rng.randf_range(0.6, 1.1)
		if boulder:
			size = rng.randf_range(1.5, 2.1)
		rocks.append({
			"x": pos.x,
			"y": float(base),
			"z": pos.y,
			"size": size,
			"variant": rng.randi_range(0, 2),
			"rot": rng.randf() * TAU,
			"seed": rng.randi(),
		})

	return {"verts": verts, "norms": norms, "cols": cols, "trees": trees, "rocks": rocks}
