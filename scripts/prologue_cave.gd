extends RefCounted

const TileArt = preload("res://scripts/tile_art.gd")

const TORCH_SCENE := "res://scenes/torch.tscn"
const DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

const CAVE_ONE := {"min": Vector3i(0, 0, 0), "max": Vector3i(21, 9, 21)}
const EXIT_TUNNEL := {"min": Vector3i(10, 4, 22), "max": Vector3i(12, 6, 29)}
const CHAMBER := {"min": Vector3i(4, 4, 30), "max": Vector3i(18, 12, 42)}
const STAIR_X := [10, 11]
const STAIR_Z := 43
const STAIR_STEPS := 10
const STAIR_BASE_Y := 4
const END_TUNNEL := {"min": Vector3i(10, 13, 53), "max": Vector3i(11, 15, 53)}
const ARENA := {"min": Vector3i(0, 11, 54), "max": Vector3i(19, 21, 75)}
const PILLARS := []
const CRACK_CENTER := Vector3(9.5, 11.0, 66.0)
const CRACK_LENGTH := 9.0
const CAVE_PILLARS := [Vector3i(4, 5, 2), Vector3i(16, 5, 2), Vector3i(5, 15, 2), Vector3i(15, 14, 2), Vector3i(10, 10, 2)]
const BEDROCK_TINT := Color(0.62, 0.62, 0.7)
const ARENA_TORCH_Y := 14
const CAVE_TORCH_Y := 4


static func build(root: Node3D, world: Node3D, origin: Vector3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	var air: Dictionary = {}
	_carve(air, CAVE_ONE)
	_carve(air, EXIT_TUNNEL)
	_carve(air, CHAMBER)
	for k in STAIR_STEPS:
		for x in STAIR_X:
			for y in range(STAIR_BASE_Y + k, STAIR_BASE_Y + k + 3):
				air[Vector3i(x, y, STAIR_Z + k)] = true
	_carve(air, END_TUNNEL)
	_carve(air, ARENA)
	for p in CAVE_PILLARS:
		_fill(air, Vector3i(p.x, 0, p.y), Vector3i(p.x + p.z - 1, CAVE_ONE["max"].y, p.y + p.z - 1))
	for p in PILLARS:
		var a: Vector3i = ARENA["min"]
		_fill(air, Vector3i(a.x + p.x, a.y, a.z + p.y), Vector3i(a.x + p.x + p.z - 1, ARENA["max"].y, a.z + p.y + p.z - 1))
	_roughen(air, rng)

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
	_wall_torches(air, torches, CAVE_ONE, 6, CAVE_TORCH_Y)
	_wall_torches(air, torches, EXIT_TUNNEL, 4, CAVE_TORCH_Y + 1)
	_wall_torches(air, torches, CHAMBER, 5, CHAMBER["min"].y + 2)
	_wall_torches(air, torches, ARENA, 8, ARENA_TORCH_Y)
	for p in PILLARS:
		var a: Vector3i = ARENA["min"]
		var lo := Vector3i(a.x + p.x, 0, a.z + p.y)
		var hi := Vector3i(lo.x + p.z - 1, 0, lo.z + p.z - 1)
		var mid_x := lo.x + 1
		var mid_z := lo.z + 1
		for n in [[Vector3i(mid_x, ARENA_TORCH_Y, lo.z - 1), Vector3i(0, 0, -1)], [Vector3i(mid_x, ARENA_TORCH_Y, hi.z + 1), Vector3i(0, 0, 1)], [Vector3i(lo.x - 1, ARENA_TORCH_Y, mid_z), Vector3i(-1, 0, 0)], [Vector3i(hi.x + 1, ARENA_TORCH_Y, mid_z), Vector3i(1, 0, 0)]]:
			_try_torch(air, torches, n[0], n[1])
	var scene: PackedScene = load(TORCH_SCENE)
	for t in torches:
		var cell: Vector3i = t["cell"]
		var normal: Vector3 = Vector3(t["normal"])
		var torch = scene.instantiate()
		torch.fixture = true
		torch.wall_normal = normal
		root.add_child(torch)
		torch.global_position = origin + Vector3(cell) + Vector3(0.5, 0.5, 0.5)
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
	var base := TileArt.block_material("bedrock", Color(0.12, 0.12, 0.14))
	var m := base.duplicate() as StandardMaterial3D
	m.albedo_color = BEDROCK_TINT
	return m


static func _carve(air: Dictionary, box: Dictionary) -> void:
	var lo: Vector3i = box["min"]
	var hi: Vector3i = box["max"]
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				air[Vector3i(x, y, z)] = true


static func _fill(air: Dictionary, lo: Vector3i, hi: Vector3i) -> void:
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				air.erase(Vector3i(x, y, z))


static func _roughen(air: Dictionary, rng: RandomNumberGenerator) -> void:
	var keep: Dictionary = {}
	for box in [EXIT_TUNNEL, END_TUNNEL]:
		var lo: Vector3i = box["min"]
		var hi: Vector3i = box["max"]
		for x in range(lo.x - 1, hi.x + 2):
			for y in range(lo.y - 1, hi.y + 2):
				for z in range(lo.z - 1, hi.z + 2):
					keep[Vector3i(x, y, z)] = true
	for k in STAIR_STEPS:
		for x in range(STAIR_X[0] - 1, STAIR_X[1] + 2):
			for y in range(STAIR_BASE_Y + k - 1, STAIR_BASE_Y + k + 4):
				keep[Vector3i(x, y, STAIR_Z + k)] = true
	for box in [CAVE_ONE, CHAMBER, ARENA]:
		var lo: Vector3i = box["min"]
		var hi: Vector3i = box["max"]
		for x in range(lo.x, hi.x + 1):
			for z in range(lo.z, hi.z + 1):
				var depth := rng.randi_range(0, 2)
				for d in depth:
					var y: int = hi.y - d
					var cell := Vector3i(x, y, z)
					if not keep.has(cell):
						air.erase(cell)
		for y in range(lo.y + 1, hi.y):
			for side in [lo.x, hi.x]:
				for z in range(lo.z, hi.z + 1):
					if rng.randf() < 0.14:
						var cell := Vector3i(side, y, z)
						if not keep.has(cell):
							air.erase(cell)
			for side in [lo.z, hi.z]:
				for x in range(lo.x, hi.x + 1):
					if rng.randf() < 0.14:
						var cell := Vector3i(x, y, side)
						if not keep.has(cell):
							air.erase(cell)


static func _wall_torches(air: Dictionary, out: Array, box: Dictionary, spacing: int, y: int) -> void:
	var lo: Vector3i = box["min"]
	var hi: Vector3i = box["max"]
	var x := lo.x + int(spacing * 0.5)
	while x <= hi.x:
		_try_torch(air, out, Vector3i(x, y, lo.z), Vector3i(0, 0, 1))
		_try_torch(air, out, Vector3i(x, y, hi.z), Vector3i(0, 0, -1))
		x += spacing
	var z := lo.z + int(spacing * 0.5)
	while z <= hi.z:
		_try_torch(air, out, Vector3i(lo.x, y, z), Vector3i(1, 0, 0))
		_try_torch(air, out, Vector3i(hi.x, y, z), Vector3i(-1, 0, 0))
		z += spacing


static func _try_torch(air: Dictionary, out: Array, cell: Vector3i, normal: Vector3i) -> void:
	if not air.has(cell) or air.has(cell - normal):
		return
	for t in out:
		if Vector3i(t["cell"]).distance_squared_to(cell) < 9:
			return
	out.append({"cell": cell, "normal": Vector3(normal)})


static func _mesh(air: Dictionary) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for cell: Vector3i in air:
		for n: Vector3i in DIRS:
			if air.has(cell + n):
				continue
			var nf := Vector3(n)
			var u := Vector3.UP if absf(nf.y) < 0.5 else Vector3.RIGHT
			var v := nf.cross(u)
			var a := Vector3(cell) + Vector3(0.5, 0.5, 0.5) + nf * 0.5 - u * 0.5 - v * 0.5
			var base := verts.size()
			verts.append(a)
			verts.append(a + u)
			verts.append(a + u + v)
			verts.append(a + v)
			for i in 4:
				norms.append(-nf)
			idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material())
	return mesh
