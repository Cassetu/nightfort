extends Node3D
const TreeScript = preload("res://scripts/tree.gd")
const RockScript = preload("res://scripts/rock.gd")
const AO_LEVELS := [0.55, 0.7, 0.85, 1.0]

@export_group("World")
@export var world_seed: int = 1337
@export var size: int = 128
@export var base_height: int = 1

@export_group("Hills")
@export var hill_amplitude: float = 9.0
@export var hill_frequency: float = 0.018
@export var plateau_radius: float = 12.0
@export var plateau_blend: float = 18.0
@export var edge_wall_width: float = 12.0
@export var edge_wall_height: float = 16.0

@export_group("Trees")
@export var tree_count: int = 350
@export var tree_spacing: float = 3.0
@export var tree_clear_radius: float = 14.0
@export var tree_edge_margin: int = 14
@export var tree_line_height: int = 8
@export var forest_threshold: float = -0.15

@export_group("Rocks")
@export var rock_count: int = 140
@export var rock_spacing: float = 2.2
@export var rock_clear_radius: float = 9.0
@export var boulder_chance: float = 0.12

var heights := PackedInt32Array()
var half: float
var _grid := {}
var _cell := 3.0

var _verts := PackedVector3Array()
var _norms := PackedVector3Array()
var _cols := PackedColorArray()


func _ready() -> void:
	half = size / 2.0
	_generate_heights()
	_build_terrain()
	_cell = maxf(tree_spacing, rock_spacing * 1.6)
	_spawn_trees()
	_spawn_rocks()


func height_at(world_x: float, world_z: float) -> float:
	return float(_h(floori(world_x + half), floori(world_z + half)))



func _generate_heights() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.frequency = hill_frequency

	heights.resize(size * size)
	for z in size:
		for x in size:
			var wx := x - half + 0.5
			var wz := z - half + 0.5
			var dist := Vector2(wx, wz).length()
			var blend := smoothstep(plateau_radius, plateau_radius + plateau_blend, dist)
			var edge := mini(mini(x, size - 1 - x), mini(z, size - 1 - z))
			var wall := pow(clampf((edge_wall_width - edge) / edge_wall_width, 0.0, 1.0), 2.0) * edge_wall_height
			var h := base_height + roundi(noise.get_noise_2d(wx, wz) * hill_amplitude * blend + wall)
			heights[z * size + x] = maxi(h, 0)


func _h(x: int, z: int) -> int:
	if x < 0 or z < 0 or x >= size or z >= size:
		return -1
	return heights[z * size + x]


func _build_terrain() -> void:
	for z in size:
		for x in size:
			var h := _h(x, z)
			var x0 := x - half
			var z0 := z - half
			var x1 := x0 + 1.0
			var z1 := z0 + 1.0
			var shade := 0.9 + 0.2 * _hash(x, z)

			var top := _shaded(_top_color(h), shade)
			_quad(
				[Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, h, z1)],
				[
					_shaded(top, _ao(x, z, h, -1, -1)),
					_shaded(top, _ao(x, z, h, 1, -1)),
					_shaded(top, _ao(x, z, h, 1, 1)),
					_shaded(top, _ao(x, z, h, -1, 1)),
				],
				Vector3.UP)

			var wall_top := _shaded(_side_color(h), shade)
			var wall_bottom := _shaded(wall_top, 0.6)
			var nh := _h(x + 1, z)
			if nh < h:
				_wall(x1, z0, x1, z1, h, nh, Vector3.RIGHT, wall_top, wall_bottom)
			nh = _h(x - 1, z)
			if nh < h:
				_wall(x0, z1, x0, z0, h, nh, Vector3.LEFT, wall_top, wall_bottom)
			nh = _h(x, z + 1)
			if nh < h:
				_wall(x1, z1, x0, z1, h, nh, Vector3.BACK, wall_top, wall_bottom)
			nh = _h(x, z - 1)
			if nh < h:
				_wall(x0, z0, x1, z0, h, nh, Vector3.FORWARD, wall_top, wall_bottom)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _norms
	arrays[Mesh.ARRAY_COLOR] = _cols

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	var collider := CollisionShape3D.new()
	collider.shape = shape
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.add_child(collider)
	add_child(body)

	_verts = PackedVector3Array()
	_norms = PackedVector3Array()
	_cols = PackedColorArray()

func _ao(x: int, z: int, h: int, cx: int, cz: int) -> float:
	var s1 := 1 if _h(x + cx, z) > h else 0
	var s2 := 1 if _h(x, z + cz) > h else 0
	var c := 1 if _h(x + cx, z + cz) > h else 0
	var level := 0 if (s1 == 1 and s2 == 1) else 3 - (s1 + s2 + c)
	return AO_LEVELS[level]


func _wall(ax: float, az: float, bx: float, bz: float, h: int, nh: int, n: Vector3, top_col: Color, bottom_col: Color) -> void:
	_quad(
		[Vector3(ax, h, az), Vector3(bx, h, bz), Vector3(bx, nh, bz), Vector3(ax, nh, az)],
		[top_col, top_col, bottom_col, bottom_col],
		n)


func _quad(p: Array, c: Array, n: Vector3) -> void:
	var order := [0, 1, 2, 0, 2, 3]
	if (p[1] - p[0]).cross(p[2] - p[0]).dot(n) > 0.0:
		order = [0, 3, 2, 0, 2, 1]
	for i in order:
		_verts.append(p[i])
		_norms.append(n)
		_cols.append(c[i])


func _top_color(h: int) -> Color:
	var grass := Color(0.27, 0.52, 0.20).lerp(Color(0.40, 0.58, 0.24), clampf(h / 7.0, 0.0, 1.0))
	return grass.lerp(Color(0.52, 0.52, 0.55), clampf((h - 7.0) / 3.0, 0.0, 1.0))


func _side_color(h: int) -> Color:
	return Color(0.42, 0.29, 0.18).lerp(Color(0.36, 0.36, 0.39), clampf((h - 7.0) / 3.0, 0.0, 1.0))


func _shaded(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k)

func _hash(x: int, z: int) -> float:
	var n := (x * 73856093) ^ (z * 19349663) ^ (world_seed * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	return float((n >> 8) & 0xFFFF) / 65535.0

func _edge_distance(x: int, z: int) -> int:
	return mini(mini(x, size - 1 - x), mini(z, size - 1 - z))


func _cell_key(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / _cell), floori(pos.y / _cell))


func _occupy(pos: Vector2) -> void:
	var key := _cell_key(pos)
	if not _grid.has(key):
		_grid[key] = []
	_grid[key].append(pos)


func _too_close(pos: Vector2, min_dist: float) -> bool:
	var key := _cell_key(pos)
	var min_sq := min_dist * min_dist
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var cell: Array = _grid.get(key + Vector2i(dx, dz), [])
			for other: Vector2 in cell:
				if other.distance_squared_to(pos) < min_sq:
					return true
	return false


func _spawn_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed

	var forest := FastNoiseLite.new()
	forest.seed = world_seed + 1
	forest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	forest.frequency = 0.035

	var holder := Node3D.new()
	holder.name = "Trees"
	add_child(holder)

	var placed := 0
	var attempts := 0
	var max_attempts := tree_count * 40

	while placed < tree_count and attempts < max_attempts:
		attempts += 1
		var x := rng.randi_range(0, size - 1)
		var z := rng.randi_range(0, size - 1)
		if _edge_distance(x, z) < tree_edge_margin:
			continue
		var h := _h(x, z)
		if h > tree_line_height:
			continue
		var pos := Vector2(x - half + 0.5, z - half + 0.5)
		if pos.length() < tree_clear_radius:
			continue
		if forest.get_noise_2d(pos.x, pos.y) < forest_threshold:
			continue

		pos += Vector2(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.15, 0.15))
		if _too_close(pos, tree_spacing):
			continue
		_occupy(pos)

		var tree = TreeScript.new()
		tree.size_factor = rng.randf_range(0.8, 1.4)
		tree.variant = rng.randi_range(0, 4)
		tree.position = Vector3(pos.x, h, pos.y)
		tree.rotation.y = rng.randf() * TAU
		holder.add_child(tree)
		placed += 1


func _spawn_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 7

	var holder := Node3D.new()
	holder.name = "Rocks"
	add_child(holder)

	var placed := 0
	var attempts := 0
	var max_attempts := rock_count * 60

	while placed < rock_count and attempts < max_attempts:
		attempts += 1
		var x := rng.randi_range(0, size - 1)
		var z := rng.randi_range(0, size - 1)
		if _edge_distance(x, z) < 6:
			continue
		var h := _h(x, z)
		if rng.randf() > clampf(0.3 + h / 8.0, 0.0, 1.0):
			continue
		var pos := Vector2(x - half + 0.5, z - half + 0.5)
		if pos.length() < rock_clear_radius:
			continue

		pos += Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
		var boulder := rng.randf() < boulder_chance
		var spacing := rock_spacing
		if boulder:
			spacing = rock_spacing * 1.6
		if _too_close(pos, spacing):
			continue
		_occupy(pos)

		var base := mini(mini(h, _h(x + 1, z)), mini(mini(_h(x - 1, z), _h(x, z + 1)), _h(x, z - 1)))
		var rock = RockScript.new()
		rock.rock_seed = rng.randi()
		if boulder:
			rock.size_factor = rng.randf_range(1.5, 2.1)
		else:
			rock.size_factor = rng.randf_range(0.6, 1.1)
		rock.variant = rng.randi_range(0, 2)
		rock.position = Vector3(pos.x, base, pos.y)
		rock.rotation.y = rng.randf() * TAU
		holder.add_child(rock)
		placed += 1
