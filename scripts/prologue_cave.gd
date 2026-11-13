extends RefCounted

const TileArt = preload("res://scripts/tile_art.gd")

const TORCH_SCENE := "res://scenes/torch.tscn"
const DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

const CAVE_ONE := {"min": Vector3i(0, 0, 0), "max": Vector3i(21, 9, 21)}
const EXIT_TUNNEL := {"min": Vector3i(10, 4, 18), "max": Vector3i(12, 6, 32)}
const CHAMBER := {"min": Vector3i(4, 4, 30), "max": Vector3i(18, 12, 42)}
const STAIR_LANDING := {"min": Vector3i(10, 4, 39), "max": Vector3i(11, 7, 42)}
const STAIR_X := [10, 11]
const STAIR_Z := 43
const STAIR_STEPS := 10
const STAIR_BASE_Y := 4
const END_TUNNEL := {"min": Vector3i(10, 13, 53), "max": Vector3i(11, 15, 56)}
const ARENA := {"min": Vector3i(0, 11, 54), "max": Vector3i(19, 21, 75)}
const CRACK_CENTER := Vector3(9.5, 11.0, 66.0)
const CRACK_LENGTH := 9.0
const CAVE_PILLARS := [Vector3i(4, 5, 2), Vector3i(16, 5, 2), Vector3i(5, 15, 2), Vector3i(15, 14, 2), Vector3i(10, 10, 2)]
const BEDROCK_TINT := Color(0.62, 0.62, 0.7)
const AO_LEVELS := [0.55, 0.72, 0.87, 1.0]
const SHAPE_POWER := 3.0
const SHAPE_NOISE := 0.24
const KEEP_CLEAR := [
	{"min": Vector2(7.0, 12.0), "max": Vector2(14.0, 22.0)},
	{"min": Vector2(8.0, 29.0), "max": Vector2(13.0, 44.0)},
	{"min": Vector2(7.0, 53.0), "max": Vector2(13.0, 60.0)},
	{"min": Vector2(5.0, 62.0), "max": Vector2(14.0, 70.0)},
]


static func build(root: Node3D, world: Node3D, origin: Vector3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	var shape_noise := FastNoiseLite.new()
	shape_noise.seed = 7311
	shape_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	shape_noise.frequency = 0.13
	shape_noise.fractal_octaves = 3
	var air: Dictionary = {}
	_room(air, CAVE_ONE, shape_noise)
	_room(air, CHAMBER, shape_noise)
	_room(air, ARENA, shape_noise)
	_carve(air, EXIT_TUNNEL)
	_carve(air, STAIR_LANDING)
	for k in STAIR_STEPS:
		for x in STAIR_X:
			for y in range(STAIR_BASE_Y + k, STAIR_BASE_Y + k + 3):
				air[Vector3i(x, y, STAIR_Z + k)] = true
	_carve(air, END_TUNNEL)
	for p in CAVE_PILLARS:
		_column(air, Vector2(float(p.x) + float(p.z) * 0.5, float(p.y) + float(p.z) * 0.5), float(p.z) * 0.8, CAVE_ONE["min"].y, shape_noise)
	_formations(air, CAVE_ONE, rng, 9, 14)
	_formations(air, CHAMBER, rng, 5, 9)
	_formations(air, ARENA, rng, 7, 11)

	var body := StaticBody3D.new()
	body.name = "Bedrock"
	root.add_child(body)
	body.global_position = origin
	var mesh := _mesh(air)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var shape := mesh.create_trimesh_shape() as ConcavePolygonShape3D
	shape.backface_collision = true
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)

	var torches: Array = []
	_ring_torches(air, torches, Vector3(10.5, 4.5, 6.5), 12)
	_ring_torches(air, torches, Vector3(11.5, 5.5, 36.5), 8)
	_ring_torches(air, torches, Vector3(9.5, 14.5, 64.5), 8)
	for z in [22.5, 28.5]:
		_ray_torch(air, torches, Vector3(11.5, 5.5, z), Vector3(-1.0, 0.0, 0.0))
	for k in [2, 6]:
		_ray_torch(air, torches, Vector3(10.5, float(STAIR_BASE_Y + k) + 2.5, float(STAIR_Z + k) + 0.5), Vector3(-1.0, 0.0, 0.0))
	var scene: PackedScene = load(TORCH_SCENE)
	for t in torches:
		var cell: Vector3i = t["cell"]
		var normal: Vector3 = Vector3(t["normal"])
		var torch = scene.instantiate()
		torch.fixture = true
		torch.wall_normal = normal
		root.add_child(torch)
		torch.global_position = origin + Vector3(cell) + Vector3(0.5, 0.5, 0.5)
		torch.shadow_locked = true
		torch.light.shadow_enabled = false

	var stones: Array = []
	for k in STAIR_STEPS:
		for x in STAIR_X:
			for y in [STAIR_BASE_Y + k, STAIR_BASE_Y + k + 1]:
				var pos := origin + Vector3(x + 0.5, y + 0.5, STAIR_Z + k + 0.5)
				var block = world.restore_block("stone", pos)
				if block != null:
					stones.append(block)

	var crack_pos := origin + CRACK_CENTER
	_make_crack(root, crack_pos)
	return {
		"spawn": origin + Vector3(11.0, 1.0, 3.5),
		"stones": stones,
		"crack": crack_pos,
		"origin": origin,
	}


static func _make_crack(root: Node3D, pos: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4410
	var steps := 14
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var sway := 0.0
	for i in steps + 1:
		var z := -CRACK_LENGTH * 0.5 + CRACK_LENGTH * float(i) / float(steps)
		var taper := sin(PI * float(i) / float(steps))
		var width := (0.25 + rng.randf() * 0.5) * (0.4 + taper) * 0.5
		sway += rng.randf_range(-0.3, 0.3)
		sway = clampf(sway, -0.9, 0.9)
		verts.append(Vector3(sway - width, 0.04, z))
		verts.append(Vector3(sway + width, 0.04, z))
		norms.append(Vector3.UP)
		norms.append(Vector3.UP)
	for i in steps:
		var a := i * 2
		idx.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.0, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.12, 0.08)
	mat.emission_energy_multiplier = 4.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var node := MeshInstance3D.new()
	node.name = "Crack"
	node.mesh = mesh
	root.add_child(node)
	node.global_position = pos
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.15, 0.1)
	light.light_energy = 3.0
	light.omni_range = 14.0
	light.shadow_enabled = false
	root.add_child(light)
	light.global_position = pos + Vector3(0.0, 1.2, 0.0)


static func _material() -> StandardMaterial3D:
	return TileArt.uv_material("bedrock", Color(0.12, 0.12, 0.14), Vector3.ONE, true)


static func _carve(air: Dictionary, box: Dictionary) -> void:
	var lo: Vector3i = box["min"]
	var hi: Vector3i = box["max"]
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				air[Vector3i(x, y, z)] = true


static func _room(air: Dictionary, box: Dictionary, noise: FastNoiseLite) -> void:
	var lo: Vector3i = box["min"]
	var hi: Vector3i = box["max"]
	var size := Vector3(hi - lo + Vector3i.ONE)
	for x in range(lo.x - 2, hi.x + 3):
		for y in range(lo.y, hi.y + 3):
			for z in range(lo.z - 2, hi.z + 3):
				var nx: float = absf((float(x) + 0.5 - float(lo.x)) / size.x * 2.0 - 1.0)
				var ny: float = (float(y) + 0.5 - float(lo.y)) / size.y
				var nz: float = absf((float(z) + 0.5 - float(lo.z)) / size.z * 2.0 - 1.0)
				var d: float = pow(pow(nx, SHAPE_POWER) + pow(ny, SHAPE_POWER) + pow(nz, SHAPE_POWER), 1.0 / SHAPE_POWER)
				d += noise.get_noise_3d(float(x), float(y), float(z)) * SHAPE_NOISE
				if d < 1.0:
					air[Vector3i(x, y, z)] = true


static func _ceiling(air: Dictionary, x: int, z: int, floor_y: int) -> int:
	var y := floor_y
	while air.has(Vector3i(x, y, z)) and y < floor_y + 40:
		y += 1
	return y


static func _column(air: Dictionary, center: Vector2, base_radius: float, floor_y: int, noise: FastNoiseLite) -> void:
	var cx := floori(center.x)
	var cz := floori(center.y)
	var top := _ceiling(air, cx, cz, floor_y)
	var span := float(maxi(top - floor_y, 1))
	for y in range(floor_y, top + 1):
		var t: float = float(y - floor_y) / span
		var r: float = base_radius * (0.7 + 0.8 * pow(absf(t * 2.0 - 1.0), 2.0))
		var reach := ceili(r + 1.0)
		for x in range(cx - reach, cx + reach + 1):
			for z in range(cz - reach, cz + reach + 1):
				var dx := float(x) + 0.5 - center.x
				var dz := float(z) + 0.5 - center.y
				var wobble: float = noise.get_noise_3d(float(x) * 2.0, float(y), float(z) * 2.0) * 0.5
				if sqrt(dx * dx + dz * dz) < r + wobble:
					air.erase(Vector3i(x, y, z))


static func _clear_spot(x: float, z: float) -> bool:
	for zone in KEEP_CLEAR:
		var lo: Vector2 = zone["min"]
		var hi: Vector2 = zone["max"]
		if x >= lo.x - 1.5 and x <= hi.x + 1.5 and z >= lo.y - 1.5 and z <= hi.y + 1.5:
			return false
	return true


static func _cone(air: Dictionary, x: float, z: float, from_y: int, length: int, radius: float, down: bool) -> void:
	for i in length:
		var r: float = radius * (1.0 - float(i) / float(length))
		var y := from_y - i if down else from_y + i
		var reach := ceili(r)
		for cx in range(floori(x) - reach, floori(x) + reach + 1):
			for cz in range(floori(z) - reach, floori(z) + reach + 1):
				var dx := float(cx) + 0.5 - x
				var dz := float(cz) + 0.5 - z
				if sqrt(dx * dx + dz * dz) <= r:
					air.erase(Vector3i(cx, y, cz))


static func _formations(air: Dictionary, box: Dictionary, rng: RandomNumberGenerator, ups: int, downs: int) -> void:
	var lo: Vector3i = box["min"]
	var hi: Vector3i = box["max"]
	for i in ups + downs:
		var x := rng.randf_range(float(lo.x) + 1.5, float(hi.x) - 0.5)
		var z := rng.randf_range(float(lo.z) + 1.5, float(hi.z) - 0.5)
		var radius := rng.randf_range(1.0, 1.9)
		var length := rng.randi_range(2, 5)
		var down := i >= ups
		if not _clear_spot(x, z):
			continue
		var floor_cell := Vector3i(floori(x), lo.y, floori(z))
		if not air.has(floor_cell):
			continue
		if down:
			var top := _ceiling(air, floor_cell.x, floor_cell.z, lo.y)
			_cone(air, x, z, top - 1, length, radius, true)
		else:
			_cone(air, x, z, lo.y, length, radius, false)


static func _ray_torch(air: Dictionary, out: Array, from: Vector3, dir: Vector3) -> void:
	if not air.has(Vector3i(floori(from.x), floori(from.y), floori(from.z))):
		return
	var step := dir.normalized() * 0.25
	var pos := from
	var last := Vector3i(floori(from.x), floori(from.y), floori(from.z))
	for i in 160:
		pos += step
		var cell := Vector3i(floori(pos.x), floori(pos.y), floori(pos.z))
		if not air.has(cell):
			break
		last = cell
	var sx := int(signf(dir.x))
	var sz := int(signf(dir.z))
	var options: Array = [Vector3i(sx, 0, 0), Vector3i(0, 0, sz)]
	if absf(dir.x) < absf(dir.z):
		options = [Vector3i(0, 0, sz), Vector3i(sx, 0, 0)]
	var axis := Vector3.ZERO
	var found := false
	for o: Vector3i in options:
		if o != Vector3i.ZERO and not air.has(last + o):
			axis = -Vector3(o)
			found = true
			break
	if not found:
		return
	for t in out:
		if Vector3i(t["cell"]).distance_squared_to(last) < 16:
			return
	out.append({"cell": last, "normal": axis})


static func _ring_torches(air: Dictionary, out: Array, center: Vector3, count: int) -> void:
	for i in count:
		var a := TAU * float(i) / float(count) + 0.3
		_ray_torch(air, out, center, Vector3(cos(a), 0.0, sin(a)))


static func _solid(air: Dictionary, cell: Vector3i) -> bool:
	return not air.has(cell)


static func _hash01(cell: Vector3i, face: int) -> float:
	var h: int = (cell.x * 73856093) ^ (cell.y * 19349663) ^ (cell.z * 83492791) ^ (face * 2654435)
	return float(h & 1023) / 1023.0


static func _mesh(air: Dictionary) -> ArrayMesh:
	var tint := FastNoiseLite.new()
	tint.seed = 17
	tint.noise_type = FastNoiseLite.TYPE_SIMPLEX
	tint.frequency = 0.12
	tint.fractal_octaves = 3
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var corner_ab := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]
	for cell: Vector3i in air:
		for f in DIRS.size():
			var n: Vector3i = DIRS[f]
			if air.has(cell + n):
				continue
			var axis := 0
			if n.y != 0:
				axis = 1
			elif n.z != 0:
				axis = 2
			var ua := (axis + 1) % 3
			var va := (axis + 2) % 3
			var u := Vector3i.ZERO
			u[ua] = 1
			var v := Vector3i.ZERO
			v[va] = 1
			var base := Vector3(cell)
			if n[axis] > 0:
				base[axis] += 1.0
			var shade: float = (0.9 + 0.2 * _hash01(cell, f)) * lerpf(0.7, 1.0, tint.get_noise_3d(float(cell.x), float(cell.y), float(cell.z)) * 0.5 + 0.5)
			if n.y > 0:
				shade *= 0.8
			var o := verts.size()
			var order: Array = [0, 1, 2, 3]
			if n[axis] < 0:
				order = [0, 3, 2, 1]
			for k: int in order:
				var ab: Vector2i = corner_ab[k]
				var su := u if ab.x == 1 else -u
				var sv := v if ab.y == 1 else -v
				var s1 := 1 if _solid(air, cell + su) else 0
				var s2 := 1 if _solid(air, cell + sv) else 0
				var c := 1 if _solid(air, cell + su + sv) else 0
				var level := 0 if (s1 == 1 and s2 == 1) else 3 - (s1 + s2 + c)
				var k2: float = shade * AO_LEVELS[level]
				verts.append(base + Vector3(u) * float(ab.x) + Vector3(v) * float(ab.y))
				norms.append(-Vector3(n))
				cols.append(Color(BEDROCK_TINT.r * k2, BEDROCK_TINT.g * k2, BEDROCK_TINT.b * k2))
				uvs.append(Vector2(float(ab.x), 1.0 - float(ab.y)))
			idx.append_array(PackedInt32Array([o, o + 1, o + 2, o, o + 2, o + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material())
	return mesh
