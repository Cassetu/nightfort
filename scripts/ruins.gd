extends RefCounted

const RADIUS := 10
const WALL_HEIGHT := 3
const TOWER_HEIGHT := 5
const TOWER_SIZE := 5
const FLOOR_LAYER := 4
const LADDER_TOP := 5
const RINGS := 4
const GATE_LO := -6
const GATE_HI := 5
const GATE_TOWER := 4
const GATE_TOWER_HEIGHT := 5
const TORCH_SCENE := "res://scenes/torch.tscn"
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const INTACT_CHANCE := 0.3


static func generate(world, terrain, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x5bd1e995
	var origin: Vector3 = world.core.global_position
	var ox := floori(origin.x)
	var oz := floori(origin.z)

	for ring in range(1, RINGS + 1):
		var radius := RADIUS * ring
		var intact := maxf(INTACT_CHANCE - 0.07 * float(ring - 1), 0.08)
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius:
					continue
				var along := z if absi(x) == radius else x
				if along >= GATE_LO and along <= GATE_HI:
					continue
				if ring == 1 and absi(x) > radius - TOWER_SIZE and absi(z) > radius - TOWER_SIZE:
					continue
				_column(world, terrain, rng, ox + x, oz + z, WALL_HEIGHT, intact)
		for dir: Vector2i in DIRS:
			_gatehouse(world, terrain, rng, ox, oz, dir, radius)

	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_tower(world, terrain, rng, ox, oz, sx, sz)


static func _cell(ox: int, oz: int, dir: Vector2i, along: int, radial: int) -> Vector2i:
	if dir.x == 0:
		return Vector2i(ox + along, oz + dir.y * radial)
	return Vector2i(ox + dir.x * radial, oz + along)


static func _gatehouse(world, terrain, rng: RandomNumberGenerator, ox: int, oz: int, dir: Vector2i, radius: int) -> void:
	var yaw := 0.0 if dir.x == 0 else PI * 0.5
	for along in [-1, 0]:
		var c := _cell(ox, oz, dir, along, radius)
		var ground: int = terrain.surface_y(c.x, c.y)
		world.restore_block("reinforced_door", Vector3(c.x + 0.5, ground + 0.5, c.y + 0.5), yaw)
		world.restore_block("stone_brick" if along == -1 else "ruined_brick", Vector3(c.x + 0.5, ground + 2.5, c.y + 0.5))

	for along in [-2, 1]:
		var c := _cell(ox, oz, dir, along, radius)
		var ground: int = terrain.surface_y(c.x, c.y)
		for layer in 3:
			var top = layer == 2 and along == 1
			world.restore_block("ruined_brick" if top else "stone_brick", Vector3(c.x + 0.5, ground + layer + 0.5, c.y + 0.5))
		var torch = load(TORCH_SCENE).instantiate()
		torch.fixture = true
		world.add_child(torch)
		torch.global_position = Vector3(c.x + 0.5, ground + 3.5, c.y + 0.5)

	for side in [-1, 1]:
		var first := 2 if side == 1 else -GATE_TOWER - 2
		for a in GATE_TOWER:
			for r in GATE_TOWER:
				var edge := a == 0 or a == GATE_TOWER - 1 or r == 0 or r == GATE_TOWER - 1
				if not edge:
					continue
				var c := _cell(ox, oz, dir, first + a, radius - 2 + r)
				if radius == RADIUS and absi(c.x - ox) > RADIUS - TOWER_SIZE and absi(c.y - oz) > RADIUS - TOWER_SIZE:
					continue
				var ground: int = terrain.surface_y(c.x, c.y)
				for layer in GATE_TOWER_HEIGHT:
					var roll := rng.randf()
					if layer == GATE_TOWER_HEIGHT - 1 and roll < 0.55:
						continue
					if layer == GATE_TOWER_HEIGHT - 2 and roll < 0.2:
						continue
					var ruined := layer >= GATE_TOWER_HEIGHT - 2 and rng.randf() < 0.5
					world.restore_block("ruined_brick" if ruined else "stone_brick", Vector3(c.x + 0.5, ground + layer + 0.5, c.y + 0.5))


static func _tower(world, terrain, rng: RandomNumberGenerator, ox: int, oz: int, sx: int, sz: int) -> void:
	var last := TOWER_SIZE - 1
	var base := -1000
	for dx in TOWER_SIZE:
		for dz in TOWER_SIZE:
			base = maxi(base, terrain.surface_y(ox + sx * (RADIUS - dx), oz + sz * (RADIUS - dz)))
	var mid := last / 2
	var ladder_dx := 1
	var yaw := atan2(float(-sx), 0.0)

	for dx in TOWER_SIZE:
		for dz in TOWER_SIZE:
			var x: int = ox + sx * (RADIUS - dx)
			var z: int = oz + sz * (RADIUS - dz)
			var ground: int = terrain.surface_y(x, z)
			for y in range(ground, base):
				world.restore_block("stone_brick", Vector3(x + 0.5, y + 0.5, z + 0.5))
			var edge := dx == 0 or dx == last or dz == 0 or dz == last
			var door := dx == last and dz == mid
			for layer in TOWER_HEIGHT:
				var pos := Vector3(x + 0.5, base + layer + 0.5, z + 0.5)
				if edge:
					if door and layer < 2:
						continue
					var top := layer == TOWER_HEIGHT - 1 and rng.randf() < 0.4
					world.restore_block("ruined_brick" if top else "stone_brick", pos)
				elif layer == FLOOR_LAYER and not (dx == ladder_dx and dz == mid):
					world.restore_block("scaffold", pos)
				elif dx == ladder_dx and dz == mid and layer <= LADDER_TOP:
					world.restore_block("ladder", pos, yaw)


static func _column(world, terrain, rng: RandomNumberGenerator, x: int, z: int, height: int, chance: float) -> void:
	var base: int = terrain.surface_y(x, z)
	var roll := rng.randf()
	var standing := 0
	if roll < chance:
		standing = height
	elif roll < chance + 0.28:
		standing = maxi(height - 1, 0)
	elif roll < chance + 0.54:
		standing = maxi(height / 2, 1)
	else:
		standing = 0

	for layer in height:
		var pos := Vector3(x + 0.5, base + layer + 0.5, z + 0.5)
		if layer < standing:
			var top_layer := layer == standing - 1 and standing < height
			var intact := standing == height or (not top_layer and rng.randf() < 0.55)
			world.restore_block("stone_brick" if intact else "ruined_brick", pos)
