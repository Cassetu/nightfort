extends Node3D

const TreeScript = preload("res://scripts/tree.gd")
const RockScript = preload("res://scripts/rock.gd")

signal block_broken(cell: Vector3i)

const CHUNK := 16
const PAD := CHUNK + 2
const LAYER := PAD * PAD
const Y_MIN := -32
const Y_MAX := 160
const Y_BASE := Y_MIN - 1
const Y_LAYERS := Y_MAX - Y_BASE + 1
const FAR := 1 << 20

const B_AIR := 0
const B_GRASS := 1
const B_DIRT := 2
const B_STONE := 3
const B_BEDROCK := 4
const B_SAND := 5
const B_SNOW := 6
const B_COAL := 7
const B_IRON := 8

const AO_LEVELS := [0.55, 0.7, 0.85, 1.0]

const COL_DRY := Color(0.62, 0.60, 0.28)
const COL_LUSH := Color(0.18, 0.46, 0.16)
const COL_SAND := Color(0.76, 0.68, 0.45)
const COL_DIRT := Color(0.42, 0.29, 0.18)
const COL_ROCK := Color(0.50, 0.50, 0.53)
const COL_STONE := Color(0.44, 0.44, 0.47)
const COL_SNOW := Color(0.92, 0.94, 0.97)
const COL_BEDROCK := Color(0.12, 0.12, 0.14)
const COL_COAL := Color(0.15, 0.15, 0.17)
const COL_IRON := Color(0.72, 0.50, 0.38)

const BASE_COL := [COL_DIRT, COL_DIRT, COL_DIRT, COL_STONE, COL_BEDROCK, COL_SAND, COL_SNOW, COL_COAL, COL_IRON]
const HARDNESS := [0.0, 2.0, 2.0, 5.0, -1.0, 1.0, 1.0, 6.0, 8.0]
const DROP_ITEM := ["", "dirt", "dirt", "stone", "", "sand", "snow", "coal", "iron"]
const DROP_AMOUNT := [0, 1, 1, 1, 0, 1, 1, 1, 1]

const FACE_CORNERS := [
	[Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)],
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	[Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)],
	[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)],
]
const FACE_NORMALS := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
const FACE_DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const FACE_DY := [0, 0, 1, -1, 0, 0]
const FACE_DCOL := [1, -1, 0, 0, PAD, -PAD]

@export_group("World")
@export var world_seed: int = 1337
@export var world_radius: float = 1500.0
@export var base_height: int = 1

@export_group("Streaming")
@export var view_distance: int = 7
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

@export_group("Underground")
@export var caves_enabled: bool = true
@export var cave_cover: int = 5
@export var tunnel_width: float = 0.07
@export var chamber_threshold: float = 0.66
@export var coal_threshold: float = 0.62
@export var iron_threshold: float = 0.64
@export var core_protect_radius: float = 9.0

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
	var mi: MeshInstance3D
	var body: StaticBody3D
	var objects: Node3D
	var faces: PackedVector3Array
	var trees: Array
	var rocks: Array

class MeshBuf:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()

var n_cont: FastNoiseLite
var n_hills: FastNoiseLite
var n_ridge: FastNoiseLite
var n_rough: FastNoiseLite
var n_detail: FastNoiseLite
var n_moist: FastNoiseLite
var n_forest: FastNoiseLite
var n_cave_a: FastNoiseLite
var n_cave_b: FastNoiseLite
var n_chamber: FastNoiseLite
var n_coal: FastNoiseLite
var n_iron: FastNoiseLite

var material: StandardMaterial3D
var player = null
var core_node: Node3D = null
var chunks: Dictionary = {}
var requested: Dictionary = {}
var results: Dictionary = {}
var depleted: Dictionary = {}
var edit_chunks: Dictionary = {}
var remesh_queue: Dictionary = {}
var wants: Array = []
var want_index: int = 0
var mutex := Mutex.new()
var last_center := Vector2i(2147483647, 0)
var pin_active: bool = false
var pin_chunk := Vector2i.ZERO
var pin_radius2: int = 0
var levels_dirty: bool = true
var face_ao: Array = []

var crack: MeshInstance3D
var crack_materials: Array = []
var crack_cell := Vector3i(0, -1000, 0)
var crack_progress: float = 0.0
var crack_time: int = 0


func _ready() -> void:
	add_to_group("terrain")
	player = get_node_or_null("../Player")

	var spawn := Vector3.ZERO
	view_distance = int(Game.settings["view_distance"])
	if Game.has_session:
		world_seed = Game.world_seed
		_import_state(Game.pending.get("terrain", {}))
		var saved: Dictionary = Game.pending.get("player", {})
		if saved.has("pos"):
			spawn = Vector3(saved["pos"][0], saved["pos"][1], saved["pos"][2])
	Game.settings_changed.connect(_on_settings_changed)

	_setup_noise()
	_setup_material()
	_setup_fog()
	_build_ao_tables()
	_setup_crack()

	var center := _chunk_of(spawn)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var coord := center + Vector2i(dx, dz)
			var chunk := _finalize(coord, _build(coord, _edit_snapshot(coord), true))
			_add_collision(chunk)
			_add_objects(chunk)


func export_state() -> Dictionary:
	var edits: Array = []
	for cc in edit_chunks:
		var d: Dictionary = edit_chunks[cc]
		for key: Vector3i in d:
			edits.append([key.x, key.y, key.z, d[key]])
	var gone: Array = []
	for key: Vector3i in depleted:
		gone.append([key.x, key.y, key.z])
	return {"edits": edits, "depleted": gone}


func _import_state(d: Dictionary) -> void:
	for e in d.get("edits", []):
		var cell := Vector3i(int(e[0]), int(e[1]), int(e[2]))
		var cc := _chunk_key(cell.x, cell.z)
		if not edit_chunks.has(cc):
			edit_chunks[cc] = {}
		var edits: Dictionary = edit_chunks[cc]
		edits[cell] = int(e[3])
	for g in d.get("depleted", []):
		depleted[Vector3i(int(g[0]), int(g[1]), int(g[2]))] = true


func _on_settings_changed() -> void:
	var vd := int(Game.settings["view_distance"])
	if vd == view_distance:
		return
	view_distance = vd
	_setup_fog()
	last_center = Vector2i(2147483647, 0)


func _exit_tree() -> void:
	for id in requested.values():
		WorkerThreadPool.wait_for_task_completion(id)
	requested.clear()


func height_at(world_x: float, world_z: float) -> float:
	return float(_height(floori(world_x), floori(world_z)))


func column_height(x: int, z: int) -> int:
	return _height(x, z)


func surface_y(x: int, z: int) -> int:
	var h := _height(x, z)
	if not edit_chunks.has(_chunk_key(x, z)):
		return h
	for iy in range(h + 4, Y_MIN - 1, -1):
		if block_at(x, iy, z) != B_AIR:
			return iy + 1
	return Y_MIN


func pin(world_pos: Vector3, chunk_radius: int) -> void:
	pin_active = true
	pin_chunk = _chunk_of(world_pos)
	pin_radius2 = chunk_radius * chunk_radius
	last_center = Vector2i(2147483647, 0)


func _pinned(coord: Vector2i) -> bool:
	return pin_active and _dist2(coord, pin_chunk) <= pin_radius2


func collision_ready(world_pos: Vector3) -> bool:
	var coord := _chunk_of(world_pos)
	if not chunks.has(coord):
		return false
	var chunk: Chunk = chunks[coord]
	return chunk.body != null


func block_at(x: int, iy: int, z: int) -> int:
	var key := Vector3i(x, iy, z)
	var cc := _chunk_key(x, z)
	if edit_chunks.has(cc):
		var edits: Dictionary = edit_chunks[cc]
		if edits.has(key):
			return edits[key]
	if iy < Y_MIN:
		return B_BEDROCK
	var h := _height(x, z)
	return _gen_block(x, iy, z, h, _surface_id(h, _moisture(x + 0.5, z + 0.5)))


func cell_from_hit(pos: Vector3, normal: Vector3) -> Vector3i:
	var p := pos - normal * 0.5
	return Vector3i(floori(p.x), floori(p.y), floori(p.z))


func hit_block(cell: Vector3i, damage: float) -> Dictionary:
	var id := block_at(cell.x, cell.y, cell.z)
	if id == B_AIR:
		return {"state": "none"}
	if id == B_BEDROCK or _is_protected(cell):
		return {"state": "locked"}

	if cell != crack_cell:
		crack_cell = cell
		crack_progress = 0.0
	crack_progress += damage
	crack_time = Time.get_ticks_msec()

	var center := Vector3(cell) + Vector3(0.5, 0.5, 0.5)
	_spawn_chips(center, BASE_COL[id])

	var hardness: float = HARDNESS[id]
	if crack_progress >= hardness:
		_clear_crack()
		_set_edit(cell, B_AIR)
		_release_support(cell)
		block_broken.emit(cell)
		return {"state": "broken", "item": DROP_ITEM[id], "amount": DROP_AMOUNT[id]}

	_show_crack(cell, crack_progress / hardness)
	return {"state": "damaged"}


func _process(_delta: float) -> void:
	if crack_cell.y > -1000 and Time.get_ticks_msec() - crack_time > 900:
		_clear_crack()

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

	if p.y < float(Y_MIN) - 28.0:
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
	n_cave_a = _make_noise(8, 0.035, 1)
	n_cave_b = _make_noise(9, 0.035, 1)
	n_chamber = _make_noise(10, 0.03, 1)
	n_coal = _make_noise(11, 0.16, 1)
	n_iron = _make_noise(12, 0.18, 1)


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


func _build_ao_tables() -> void:
	face_ao.clear()
	for f in 6:
		var n: Vector3i = FACE_DIRS[f]
		var normal_axis := 0
		for axis in 3:
			if n[axis] != 0:
				normal_axis = axis
		var table: Array = []
		for k in 4:
			var corner: Vector3 = FACE_CORNERS[f][k]
			var dirs: Array = []
			for axis in 3:
				if axis == normal_axis:
					continue
				var e := Vector3i.ZERO
				e[axis] = 2 * int(corner[axis]) - 1
				dirs.append(e)
			var u: Vector3i = dirs[0]
			var v: Vector3i = dirs[1]
			var offsets := PackedInt32Array()
			offsets.append(_delta(n + u))
			offsets.append(_delta(n + v))
			offsets.append(_delta(n + u + v))
			table.append(offsets)
		face_ao.append(table)


func _delta(v: Vector3i) -> int:
	return v.x + v.y * LAYER + v.z * PAD


func _setup_crack() -> void:
	for stage in 10:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		var threshold := 0.05 + 0.065 * float(stage)
		for py in 16:
			for px in 16:
				if _hash3(px, py, 77) < threshold:
					img.set_pixel(px, py, Color(0.0, 0.0, 0.0, 0.7))
				else:
					img.set_pixel(px, py, Color(0.0, 0.0, 0.0, 0.0))
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		crack_materials.append(mat)

	crack = MeshInstance3D.new()
	crack.name = "Crack"
	crack.mesh = _make_cube_mesh()
	crack.top_level = true
	crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crack.visible = false
	add_child(crack)


func _make_cube_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var corner_uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	var order := [0, 1, 2, 0, 2, 3]
	for f in 6:
		for k in order:
			var corner: Vector3 = FACE_CORNERS[f][k]
			verts.append((corner - Vector3(0.5, 0.5, 0.5)) * 1.01)
			norms.append(FACE_NORMALS[f])
			uvs.append(corner_uv[k])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _show_crack(cell: Vector3i, fraction: float) -> void:
	var stage := clampi(int(fraction * 10.0), 0, 9)
	crack.material_override = crack_materials[stage]
	crack.global_position = Vector3(cell) + Vector3(0.5, 0.5, 0.5)
	crack.visible = true


func _clear_crack() -> void:
	crack.visible = false
	crack_cell = Vector3i(0, -1000, 0)
	crack_progress = 0.0


func _spawn_chips(origin: Vector3, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0

	var chip := BoxMesh.new()
	chip.size = Vector3(0.12, 0.12, 0.12)
	chip.material = mat

	var burst := CPUParticles3D.new()
	burst.mesh = chip
	burst.amount = 10
	burst.lifetime = 0.6
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.direction = Vector3.UP
	burst.spread = 80.0
	burst.gravity = Vector3(0.0, -12.0, 0.0)
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 4.5
	burst.emitting = false
	get_tree().current_scene.add_child(burst)
	burst.global_position = origin
	burst.emitting = true
	get_tree().create_timer(1.2).timeout.connect(burst.queue_free)


func _is_protected(cell: Vector3i) -> bool:
	if core_node == null or not is_instance_valid(core_node):
		core_node = get_tree().get_first_node_in_group("Core") as Node3D
	if core_node == null:
		return false
	var c: Vector3 = core_node.global_position
	return Vector2(cell.x + 0.5 - c.x, cell.z + 0.5 - c.z).length() < core_protect_radius


func _chunk_key(x: int, z: int) -> Vector2i:
	return Vector2i(floori(float(x) / CHUNK), floori(float(z) / CHUNK))


func _set_edit(cell: Vector3i, id: int) -> void:
	var cc := _chunk_key(cell.x, cell.z)
	if not edit_chunks.has(cc):
		edit_chunks[cc] = {}
	var edits: Dictionary = edit_chunks[cc]
	edits[cell] = id

	var lx := cell.x - cc.x * CHUNK
	var lz := cell.z - cc.y * CHUNK
	var xs := [0]
	var zs := [0]
	if lx == 0:
		xs.append(-1)
	if lx == CHUNK - 1:
		xs.append(1)
	if lz == 0:
		zs.append(-1)
	if lz == CHUNK - 1:
		zs.append(1)
	for dx in xs:
		for dz in zs:
			remesh_queue[cc + Vector2i(dx, dz)] = true


func _release_support(cell: Vector3i) -> void:
	var cc := _chunk_key(cell.x, cell.z)
	if not chunks.has(cc):
		return
	var chunk: Chunk = chunks[cc]
	if chunk.objects == null:
		return
	for child in chunk.objects.get_children():
		if not child.is_in_group("resource") or child.dying:
			continue
		var p: Vector3 = child.position
		if cc.x * CHUNK + floori(p.x) == cell.x and cc.y * CHUNK + floori(p.z) == cell.z and floori(p.y) - 1 == cell.y:
			child.take_damage(100000)


func _support_gone(coord: Vector2i, d: Dictionary) -> bool:
	if not edit_chunks.has(coord):
		return false
	var edits: Dictionary = edit_chunks[coord]
	return edits.has(Vector3i(coord.x * CHUNK + floori(d["x"]), floori(d["y"]) - 1, coord.y * CHUNK + floori(d["z"])))


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
		var pinned := _pinned(coord)
		if d > unload2 and not pinned:
			chunk.root.queue_free()
			chunks.erase(coord)
			continue
		if chunk.body != null and d > drop_collision2 and not pinned:
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
	if pin_active:
		var pr := int(ceil(sqrt(float(pin_radius2))))
		for dz in range(-pr, pr + 1):
			for dx in range(-pr, pr + 1):
				var coord := pin_chunk + Vector2i(dx, dz)
				if not _pinned(coord) or not _in_world(coord) or chunks.has(coord) or requested.has(coord):
					continue
				var d2 := _dist2(coord, center)
				if d2 <= r2:
					continue
				wants.append([d2, coord])
	wants.sort_custom(func(a, b): return a[0] < b[0])
	levels_dirty = true


func _edit_snapshot(coord: Vector2i) -> Dictionary:
	var snap := {}
	if edit_chunks.is_empty():
		return snap
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := coord + Vector2i(dx, dz)
			if edit_chunks.has(key):
				snap.merge(edit_chunks[key])
	return snap


func _dispatch() -> void:
	for coord: Vector2i in remesh_queue.keys():
		if not chunks.has(coord):
			remesh_queue.erase(coord)
			continue
		if requested.has(coord):
			continue
		remesh_queue.erase(coord)
		requested[coord] = WorkerThreadPool.add_task(_worker.bind(coord, _edit_snapshot(coord), false), false, "terrain remesh")

	while requested.size() < max_in_flight and want_index < wants.size():
		var coord: Vector2i = wants[want_index][1]
		want_index += 1
		if chunks.has(coord) or requested.has(coord):
			continue
		requested[coord] = WorkerThreadPool.add_task(_worker.bind(coord, _edit_snapshot(coord), true), false, "terrain chunk")


func _worker(coord: Vector2i, snapshot: Dictionary, with_objects: bool) -> void:
	var data := _build(coord, snapshot, with_objects)
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
	if chunks.has(best):
		_apply_remesh(chunks[best], data)
	elif not data["remesh"] and (best_d <= (view_distance + 1) * (view_distance + 1) or _pinned(best)):
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
		var need_collision := chunk.body == null and (d <= c2 or _pinned(chunk.coord))
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


func _make_mesh(data: Dictionary) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["verts"]
	arrays[Mesh.ARRAY_NORMAL] = data["norms"]
	arrays[Mesh.ARRAY_COLOR] = data["cols"]

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


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

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _make_mesh(data)
	root.add_child(mi)
	chunk.mi = mi

	chunks[coord] = chunk
	return chunk


func _apply_remesh(chunk: Chunk, data: Dictionary) -> void:
	chunk.faces = data["verts"]
	chunk.mi.mesh = _make_mesh(data)
	if chunk.body != null:
		var col: CollisionShape3D = chunk.body.get_child(0)
		col.shape = _make_shape(chunk.faces)


func _make_shape(faces: PackedVector3Array) -> ConcavePolygonShape3D:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	return shape


func _add_collision(chunk: Chunk) -> void:
	var col := CollisionShape3D.new()
	col.shape = _make_shape(chunk.faces)

	var body := StaticBody3D.new()
	body.name = "Collision"
	body.add_to_group("terrain_body")
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
		var d: Dictionary = chunk.trees[i]
		if depleted.has(key) or _support_gone(chunk.coord, d):
			continue
		var tree = TreeScript.new()
		tree.size_factor = d["size"]
		tree.variant = d["variant"]
		tree.position = Vector3(d["x"], d["y"], d["z"])
		tree.rotation.y = d["rot"]
		tree.harvested.connect(_on_depleted.bind(key))
		holder.add_child(tree)

	for i in chunk.rocks.size():
		var key := Vector3i(chunk.coord.x, chunk.coord.y, 1000 + i)
		var d: Dictionary = chunk.rocks[i]
		if depleted.has(key) or _support_gone(chunk.coord, d):
			continue
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

	return clampi(base_height + roundi(maxf(relief, 0.0) * blend + wall), 1, Y_MAX - 2)


func _moisture(x: float, z: float) -> float:
	var m := n_moist.get_noise_2d(x, z) * 0.5 + 0.5
	return clampf((m - 0.5) * 1.8 + 0.5, 0.0, 1.0)


func _top_color(h: int, moist: float) -> Color:
	var hf := float(h)
	var c := COL_DRY.lerp(COL_LUSH, moist)
	var sand_t := (1.0 - smoothstep(0.05, 0.22, moist)) * (1.0 - smoothstep(2.0, rock_line - 4.0, hf))
	c = c.lerp(COL_SAND, sand_t)
	c = c.lerp(COL_ROCK, smoothstep(rock_line, rock_line + 5.0, hf))
	return c.lerp(COL_SNOW, smoothstep(snow_line, snow_line + 3.0, hf))


func _surface_id(h: int, moist: float) -> int:
	var hf := float(h)
	if hf >= snow_line + 2.0:
		return B_SNOW
	if hf >= rock_line + 3.0:
		return B_STONE
	var sand_t := (1.0 - smoothstep(0.05, 0.22, moist)) * (1.0 - smoothstep(2.0, rock_line - 4.0, hf))
	if sand_t > 0.5:
		return B_SAND
	return B_GRASS


func _hash3(x: int, y: int, z: int) -> float:
	var n := (x * 73856093) ^ (y * 83492791) ^ (z * 19349663) ^ (world_seed * 2654435761)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n >> 8) & 0xFFFF) / 65535.0


func _is_cave(x: int, iy: int, z: int) -> bool:
	var fx := x + 0.5
	var fy := iy + 0.5
	var fz := z + 0.5
	if absf(n_cave_a.get_noise_3d(fx, fy, fz)) < tunnel_width and absf(n_cave_b.get_noise_3d(fx, fy, fz)) < tunnel_width:
		return true
	if iy < -6 and n_chamber.get_noise_3d(fx, fy, fz) > chamber_threshold:
		return true
	return false


func _gen_block(x: int, iy: int, z: int, h: int, surf: int) -> int:
	if iy >= h:
		return B_AIR
	if iy <= Y_MIN:
		return B_BEDROCK
	if iy == Y_MIN + 1 and _hash3(x, iy, z) > 0.5:
		return B_BEDROCK
	var depth := h - 1 - iy
	if depth == 0:
		return surf
	if caves_enabled and depth >= cave_cover and iy > Y_MIN + 1 and _is_cave(x, iy, z):
		return B_AIR
	if surf == B_GRASS and depth <= 3:
		return B_DIRT
	if surf == B_SAND:
		if depth <= 1:
			return B_SAND
		if depth <= 3:
			return B_DIRT
	if depth >= 4:
		var fx := x + 0.5
		var fy := iy + 0.5
		var fz := z + 0.5
		if iy < 0 and n_iron.get_noise_3d(fx, fy, fz) > iron_threshold:
			return B_IRON
		if n_coal.get_noise_3d(fx, fy, fz) > coal_threshold:
			return B_COAL
	return B_STONE


func _max_step(heights: PackedInt32Array, i: int, h: int) -> int:
	return maxi(maxi(absi(h - heights[i + 1]), absi(h - heights[i - 1])), maxi(absi(h - heights[i + PAD]), absi(h - heights[i - PAD])))


func _emit_face(buf: MeshBuf, vol: PackedByteArray, i: int, f: int, origin: Vector3, c_top: Color, c_bot: Color, light: float) -> void:
	var table: Array = face_ao[f]
	var corners: Array = FACE_CORNERS[f]
	var pos: Array = []
	var col: Array = []
	var ao: Array = []
	for k in 4:
		var o: PackedInt32Array = table[k]
		var s1 := 1 if vol[i + o[0]] != 0 else 0
		var s2 := 1 if vol[i + o[1]] != 0 else 0
		var c := 1 if vol[i + o[2]] != 0 else 0
		var level := 0 if (s1 == 1 and s2 == 1) else 3 - (s1 + s2 + c)
		var a: float = AO_LEVELS[level]
		var corner: Vector3 = corners[k]
		var base: Color = c_top if corner.y > 0.5 else c_bot
		var k2 := a * light
		pos.append(origin + corner)
		col.append(Color(base.r * k2, base.g * k2, base.b * k2))
		ao.append(a)

	var order: Array = [0, 1, 2, 0, 2, 3]
	if ao[0] + ao[2] > ao[1] + ao[3]:
		order = [1, 2, 3, 1, 3, 0]

	var n: Vector3 = FACE_NORMALS[f]
	for k in order:
		buf.verts.append(pos[k])
		buf.norms.append(n)
		buf.cols.append(col[k])


func _build(coord: Vector2i, snapshot: Dictionary, with_objects: bool) -> Dictionary:
	var ox := coord.x * CHUNK - 1
	var oz := coord.y * CHUNK - 1

	var heights := PackedInt32Array()
	heights.resize(PAD * PAD)
	for z in PAD:
		for x in PAD:
			heights[z * PAD + x] = _height(ox + x, oz + z)

	var moist := PackedFloat32Array()
	moist.resize(CHUNK * CHUNK)
	var top_cols := PackedColorArray()
	top_cols.resize(CHUNK * CHUNK)
	var surf := PackedByteArray()
	surf.resize(CHUNK * CHUNK)
	for lz in CHUNK:
		for lx in CHUNK:
			var h := heights[(lz + 1) * PAD + lx + 1]
			var m := _moisture(coord.x * CHUNK + lx + 0.5, coord.y * CHUNK + lz + 0.5)
			var ci := lz * CHUNK + lx
			moist[ci] = m
			top_cols[ci] = _top_color(h, m)
			surf[ci] = _surface_id(h, m)

	var vol := PackedByteArray()
	vol.resize(LAYER * Y_LAYERS)
	vol.fill(0)
	var cmin := PackedInt32Array()
	cmin.resize(LAYER)
	cmin.fill(FAR)
	var cmax := PackedInt32Array()
	cmax.resize(LAYER)
	cmax.fill(-FAR)

	for z in PAD:
		for x in PAD:
			var col := z * PAD + x
			var h := heights[col]
			var wx := ox + x
			var wz := oz + z
			var s := B_GRASS
			if x > 0 and x < PAD - 1 and z > 0 and z < PAD - 1:
				s = surf[(z - 1) * CHUNK + x - 1]
			vol[col] = B_BEDROCK
			for iy in range(Y_MIN, h):
				var id := _gen_block(wx, iy, wz, h, s)
				vol[(iy - Y_BASE) * LAYER + col] = id
				if id == B_AIR:
					cmin[col] = mini(cmin[col], iy)
					cmax[col] = maxi(cmax[col], iy)

	for key: Vector3i in snapshot:
		var lx := key.x - coord.x * CHUNK + 1
		var lz := key.z - coord.y * CHUNK + 1
		if lx < 0 or lx >= PAD or lz < 0 or lz >= PAD:
			continue
		if key.y < Y_MIN or key.y >= Y_MAX:
			continue
		var col := lz * PAD + lx
		vol[(key.y - Y_BASE) * LAYER + col] = snapshot[key]
		cmin[col] = mini(cmin[col], key.y)
		cmax[col] = maxi(cmax[col], key.y)

	var buf := MeshBuf.new()
	for lz in CHUNK:
		for lx in CHUNK:
			var col := (lz + 1) * PAD + lx + 1
			var h := heights[col]
			var a1 := h - 1
			var a0 := mini(a1, mini(mini(heights[col - 1], heights[col + 1]), mini(heights[col - PAD], heights[col + PAD])))
			a0 = maxi(a0, Y_MIN)
			var c0 := mini(mini(mini(cmin[col], cmin[col - 1]), mini(cmin[col + 1], cmin[col - PAD])), cmin[col + PAD])
			var c1 := maxi(maxi(maxi(cmax[col], cmax[col - 1]), maxi(cmax[col + 1], cmax[col - PAD])), cmax[col + PAD])
			var has_c := c1 >= c0
			var lo := a0
			if has_c:
				c0 = maxi(c0 - 1, Y_MIN)
				c1 = mini(c1 + 1, a1)
				has_c = c1 >= c0
				if has_c:
					lo = mini(lo, c0)

			var wx := coord.x * CHUNK + lx
			var wz := coord.y * CHUNK + lz
			var top_col: Color = top_cols[lz * CHUNK + lx]

			for iy in range(lo, a1 + 1):
				if iy < a0 and (not has_c or iy < c0 or iy > c1):
					continue
				var i := (iy - Y_BASE) * LAYER + col
				var id := vol[i]
				if id == 0:
					continue

				var mask := 0
				if vol[i + 1] == 0:
					mask |= 1
				if vol[i - 1] == 0:
					mask |= 2
				if vol[i + LAYER] == 0:
					mask |= 4
				if vol[i - LAYER] == 0:
					mask |= 8
				if vol[i + PAD] == 0:
					mask |= 16
				if vol[i - PAD] == 0:
					mask |= 32
				if mask == 0:
					continue

				var shade := 0.92 + 0.16 * _hash3(wx, iy, wz)
				var base: Color = BASE_COL[id]
				var ct := base
				var cs := base
				if iy == a1:
					ct = top_col
					if id == B_GRASS:
						cs = base.lerp(top_col, 0.5)
				ct = Color(ct.r * shade, ct.g * shade, ct.b * shade)
				cs = Color(cs.r * shade, cs.g * shade, cs.b * shade)
				var cb := Color(cs.r * 0.8, cs.g * 0.8, cs.b * 0.8)
				var origin := Vector3(lx, iy, lz)

				for f in 6:
					if (mask & (1 << f)) == 0:
						continue
					var air_depth: int = heights[col + FACE_DCOL[f]] - (iy + FACE_DY[f])
					var light := 1.0
					if air_depth > 1:
						light = 1.0 - 0.7 * smoothstep(1.0, 10.0, float(air_depth))
					if f == 2:
						_emit_face(buf, vol, i, f, origin, ct, ct, light)
					elif f == 3:
						_emit_face(buf, vol, i, f, origin, cb, cb, light)
					else:
						_emit_face(buf, vol, i, f, origin, cs, cb, light)

	var trees: Array = []
	var rocks: Array = []
	if with_objects:
		var rng := RandomNumberGenerator.new()
		rng.seed = (coord.x * 73856093) ^ (coord.y * 19349663) ^ (world_seed * 83492791)
		var placed: Array = []
		var origin2 := Vector2(coord.x * CHUNK, coord.y * CHUNK)

		for _t in tree_attempts:
			var px := rng.randf_range(2.0, CHUNK - 2.0)
			var pz := rng.randf_range(2.0, CHUNK - 2.0)
			var lx := int(px)
			var lz := int(pz)
			var i := (lz + 1) * PAD + lx + 1
			var h := heights[i]
			if h > tree_line or _max_step(heights, i, h) > 1:
				continue
			var world := origin2 + Vector2(px, pz)
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
			var world := origin2 + Vector2(px, pz)
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
			var floor_y := mini(mini(h, heights[i + 1]), mini(mini(heights[i - 1], heights[i + PAD]), heights[i - PAD]))
			var size := rng.randf_range(0.6, 1.1)
			if boulder:
				size = rng.randf_range(1.5, 2.1)
			rocks.append({
				"x": pos.x,
				"y": float(floor_y),
				"z": pos.y,
				"size": size,
				"variant": rng.randi_range(0, 2),
				"rot": rng.randf() * TAU,
				"seed": rng.randi(),
			})

	return {"verts": buf.verts, "norms": buf.norms, "cols": buf.cols, "trees": trees, "rocks": rocks, "remesh": not with_objects}
