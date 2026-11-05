extends RefCounted

const RADIUS := 10
const WALL_HEIGHT := 3
const TOWER_HEIGHT := 5
const TOWER_SIZE := 3
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
			for dx in TOWER_SIZE:
				for dz in TOWER_SIZE:
					var x: int = sx * (RADIUS - dx)
					var z: int = sz * (RADIUS - dz)
					_column(world, terrain, rng, ox + x, oz + z, TOWER_HEIGHT)


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
