extends RefCounted

const RADIUS := 10
const WALL_HEIGHT := 3
const TOWER_HEIGHT := 5
const TOWER_SIZE := 5
const FLOOR_LAYER := 4
const LADDER_TOP := 5
const GATE_HALF := 1
const INTACT_CHANCE := 0.3


static func generate(world, terrain, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x5bd1e995
	var origin: Vector3 = world.core.global_position
	var ox := floori(origin.x)
	var oz := floori(origin.z)

	for x in range(-RADIUS, RADIUS + 1):
		for z in range(-RADIUS, RADIUS + 1):
			if maxi(absi(x), absi(z)) != RADIUS:
				continue
			var along := z if absi(x) == RADIUS else x
			if absi(along) <= GATE_HALF:
				continue
			var in_tower := absi(x) > RADIUS - TOWER_SIZE and absi(z) > RADIUS - TOWER_SIZE
			if in_tower:
				continue
			_column(world, terrain, rng, ox + x, oz + z, WALL_HEIGHT)

	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_tower(world, terrain, rng, ox, oz, sx, sz)


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


static func _column(world, terrain, rng: RandomNumberGenerator, x: int, z: int, height: int) -> void:
	var base: int = terrain.surface_y(x, z)
	var roll := rng.randf()
	var standing := 0
	if roll < INTACT_CHANCE:
		standing = height
	elif roll < 0.58:
		standing = maxi(height - 1, 0)
	elif roll < 0.84:
		standing = maxi(height / 2, 1)
	else:
		standing = 0

	for layer in height:
		var pos := Vector3(x + 0.5, base + layer + 0.5, z + 0.5)
		if layer < standing:
			var top_layer := layer == standing - 1 and standing < height
			var intact := standing == height or (not top_layer and rng.randf() < 0.55)
			world.restore_block("stone_brick" if intact else "ruined_brick", pos)
