extends RefCounted

const SITE_COUNT := 7
const MIN_DISTANCE := 85.0
const MAX_DISTANCE := 190.0
const HALF := 3
const WALL_HEIGHT := 3
const MAX_SLOPE := 3
const TRIES := 14
const GATE_HALF := 1
const LOOT := [
	{"id": "plank", "min": 4, "max": 10},
	{"id": "stone_brick", "min": 3, "max": 8},
	{"id": "coal", "min": 2, "max": 6},
	{"id": "iron", "min": 1, "max": 4},
	{"id": "fiber", "min": 2, "max": 6},
	{"id": "arrow", "min": 4, "max": 10},
	{"id": "torch", "min": 2, "max": 5},
]


static func generate(world, terrain, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x1f3d5b79
	var core_pos: Vector3 = world.core.global_position
	var phase := rng.randf() * TAU
	for i in SITE_COUNT:
		var angle := phase + TAU * float(i) / float(SITE_COUNT) + rng.randf_range(-0.25, 0.25)
		var dist := rng.randf_range(MIN_DISTANCE, MAX_DISTANCE)
		var cx := floori(core_pos.x + cos(angle) * dist)
		var cz := floori(core_pos.z + sin(angle) * dist)
		var site := _find_site(terrain, rng, cx, cz)
		if site.is_empty():
			continue
		_build_site(world, terrain, rng, site["x"], site["z"])


static func _find_site(terrain, rng: RandomNumberGenerator, cx: int, cz: int) -> Dictionary:
	for t in TRIES:
		var x := cx + rng.randi_range(-12, 12)
		var z := cz + rng.randi_range(-12, 12)
		var lo := 9999
		var hi := -9999
		for dx in range(-HALF, HALF + 1):
			for dz in range(-HALF, HALF + 1):
				var h: int = terrain.surface_y(x + dx, z + dz)
				lo = mini(lo, h)
				hi = maxi(hi, h)
		if hi - lo <= MAX_SLOPE:
			return {"x": x, "z": z}
	return {}


static func _build_site(world, terrain, rng: RandomNumberGenerator, x: int, z: int) -> void:
	var gate_side := rng.randi_range(0, 3)
	world.outposts.append(Vector3(x + 0.5, terrain.surface_y(x, z), z + 0.5))
	for dx in range(-HALF, HALF + 1):
		for dz in range(-HALF, HALF + 1):
			if maxi(absi(dx), absi(dz)) != HALF:
				continue
			if _in_gate(dx, dz, gate_side):
				continue
			_wall_column(world, terrain, rng, x + dx, z + dz)

	var floor_y: int = terrain.surface_y(x, z)
	var chest = world.restore_block("chest", Vector3(x + 0.5, floor_y + 0.5, z + 0.5), float(rng.randi_range(0, 3)) * PI * 0.5)
	if chest != null and chest.get("items") != null:
		_fill_chest(chest, rng)

	var spots := [Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(2, 2)]
	var soul_count := rng.randi_range(1, 2)
	for k in soul_count:
		var pick := rng.randi_range(0, spots.size() - 1)
		var s: Vector2i = spots[pick]
		spots.remove_at(pick)
		var sy: int = terrain.surface_y(x + s.x, z + s.y)
		world.restore_block("soul_block", Vector3(x + s.x + 0.5, sy + 0.5, z + s.y + 0.5))


static func _in_gate(dx: int, dz: int, side: int) -> bool:
	if side == 0:
		return dz == -HALF and absi(dx) <= GATE_HALF
	if side == 1:
		return dz == HALF and absi(dx) <= GATE_HALF
	if side == 2:
		return dx == -HALF and absi(dz) <= GATE_HALF
	return dx == HALF and absi(dz) <= GATE_HALF


static func _wall_column(world, terrain, rng: RandomNumberGenerator, x: int, z: int) -> void:
	var base: int = terrain.surface_y(x, z)
	var roll := rng.randf()
	var standing := WALL_HEIGHT
	if roll > 0.35:
		standing = rng.randi_range(1, WALL_HEIGHT - 1)
	if roll > 0.85:
		standing = 0
	for layer in standing:
		var pos := Vector3(x + 0.5, base + layer + 0.5, z + 0.5)
		var ruined := layer == standing - 1 and standing < WALL_HEIGHT
		world.restore_block("ruined_brick" if ruined or rng.randf() < 0.3 else "stone_brick", pos)


static func _fill_chest(chest, rng: RandomNumberGenerator) -> void:
	var slots: Array = []
	for i in chest.items.size():
		slots.append(i)
	slots.shuffle()
	var gems := rng.randi_range(1, 2)
	chest.items[slots.pop_back()] = {"id": "soul_gem", "count": gems}
	var extras := rng.randi_range(2, 4)
	for k in extras:
		var entry: Dictionary = LOOT[rng.randi_range(0, LOOT.size() - 1)]
		var count := rng.randi_range(int(entry["min"]), int(entry["max"]))
		chest.items[slots.pop_back()] = {"id": entry["id"], "count": count}
