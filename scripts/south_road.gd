extends RefCounted

const TORCH_SCENE := "res://scenes/torch.tscn"
const ARCH_S := 312
const ARCH_HEIGHT := 12
const WAYSTONE_FIRST := 100
const WAYSTONE_EVERY := 55
const WAYSTONE_HEIGHT := 4
const TOWER_S := 150
const TOWER_SIZE := 5
const TOWER_HEIGHT := 7


static func generate(world, terrain, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x3a9d11b7
	_arch(world, terrain, rng)
	_tower(world, terrain, rng)
	var s := WAYSTONE_FIRST
	var side := 1
	while s < terrain.SFORT_S - 90:
		_waystone(world, terrain, rng, s, side)
		side = -side
		s += WAYSTONE_EVERY


static func _stack(world, terrain, x: int, z: int, top_y: int, type: String) -> void:
	var base: int = terrain.surface_y(x, z)
	for y in range(base, top_y):
		world.restore_block(type, Vector3(x + 0.5, y + 0.5, z + 0.5))


static func _arch(world, terrain, rng: RandomNumberGenerator) -> void:
	var z0 := ARCH_S
	var floor_y := roundi(terrain.south_road_height(float(ARCH_S)))
	var top := floor_y + ARCH_HEIGHT
	for dz in 3:
		var z := z0 + dz
		for x in range(-5, 5):
			var pillar := x <= -3 or x >= 2
			if pillar:
				var edge := x == -5 or x == -3 or x == 2 or x == 4 or dz != 1
				if edge:
					_stack(world, terrain, x, z, top - 2, "stone_brick")
				else:
					_stack(world, terrain, x, z, floor_y + 4, "stone_brick")
			for y in [top - 2, top - 1]:
				world.restore_block("stone_brick", Vector3(x + 0.5, y + 0.5, z + 0.5))
		for x in [-2, 1]:
			world.restore_block("stone_brick", Vector3(x + 0.5, top - 3 + 0.5, z + 0.5))
	for x in range(-5, 5):
		if x % 2 == 0:
			continue
		world.restore_block("merlon", Vector3(x + 0.5, top + 0.5, z0 + 0.5))
	for x in [-6, 5]:
		for z in [z0 - 1, z0 + 3]:
			_torch(world, terrain, x, z)


static func _torch(world, terrain, x: int, z: int) -> void:
	var torch = load(TORCH_SCENE).instantiate()
	torch.fixture = true
	world.add_child(torch)
	torch.global_position = Vector3(x + 0.5, terrain.surface_y(x, z) + 0.5, z + 0.5)


static func _waystone(world, terrain, rng: RandomNumberGenerator, s: int, side: int) -> void:
	var c: float = terrain.south_center(float(s))
	var x := roundi(c) + side * 6
	var z := s
	var floor_y := roundi(terrain.south_road_height(float(s)))
	var base: int = terrain.surface_y(x, z)
	if base > floor_y + 6:
		return
	for y in range(base, maxi(base, floor_y) + WAYSTONE_HEIGHT):
		var ruined := y >= maxi(base, floor_y) + WAYSTONE_HEIGHT - 1 and rng.randf() < 0.5
		world.restore_block("ruined_brick" if ruined else "stone_brick", Vector3(x + 0.5, y + 0.5, z + 0.5))
	var torch = load(TORCH_SCENE).instantiate()
	torch.fixture = true
	world.add_child(torch)
	torch.global_position = Vector3(x + 0.5, maxi(base, floor_y) + WAYSTONE_HEIGHT + 0.5, z + 0.5)


static func _tower(world, terrain, rng: RandomNumberGenerator) -> void:
	var cx := -12
	var cz := TOWER_S
	var base := -1000
	for dx in TOWER_SIZE:
		for dz in TOWER_SIZE:
			base = maxi(base, terrain.surface_y(cx + dx, cz + dz))
	var last := TOWER_SIZE - 1
	for dx in TOWER_SIZE:
		for dz in TOWER_SIZE:
			var edge := dx == 0 or dx == last or dz == 0 or dz == last
			if not edge:
				continue
			var x := cx + dx
			var z := cz + dz
			var ground: int = terrain.surface_y(x, z)
			for y in range(ground, base):
				world.restore_block("stone_brick", Vector3(x + 0.5, y + 0.5, z + 0.5))
			var door := dz == last and dx == last / 2
			for layer in TOWER_HEIGHT:
				if door and layer < 2:
					continue
				var roll := rng.randf()
				if layer >= TOWER_HEIGHT - 2 and roll < 0.5:
					continue
				var ruined := layer >= TOWER_HEIGHT - 3 and rng.randf() < 0.5
				world.restore_block("ruined_brick" if ruined else "stone_brick", Vector3(x + 0.5, base + layer + 0.5, z + 0.5))
	_torch(world, terrain, cx + last / 2, cz + TOWER_SIZE + 1)
