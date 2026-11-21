extends Node3D

const Folk = preload("res://scripts/north_folk.gd")
const House = preload("res://scripts/village_house.gd")
const TORCH_SCENE := "res://scenes/torch.tscn"
const WALK_RANGE := 240.0
const SHOW_RANGE := 260.0
const HOUSE_RINGS := [47.0, 57.0]
const RING_GUARDS := 22
const PARAPET_GUARDS := 12
const VILLAGERS := 14
const HOUSE_CAP := 14

var terrain
var player
var floor_y: int = 0
var scenery: Node3D
var actors: Node3D
var center: Vector3 = Vector3.ZERO
var check: float = 0.0
var rects: Array = []
var place_houses: bool = false


func setup(terrain_node, player_node, seed_value: int) -> void:
	terrain = terrain_node
	player = player_node
	floor_y = terrain.sfort_floor
	center = Vector3(0.5, float(floor_y), float(terrain.SFORT_S) + 0.5)
	scenery = Node3D.new()
	scenery.name = "Scenery"
	add_child(scenery)
	actors = Node3D.new()
	actors.name = "Actors"
	add_child(actors)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x51ed270b
	_build_houses(rng)
	_build_guards()
	_build_villagers()


func _process(delta: float) -> void:
	check -= delta
	if check > 0.0:
		return
	check = 0.5
	if player == null or not is_instance_valid(player):
		return
	var d: float = Vector2(player.global_position.x - center.x, player.global_position.z - center.z).length()
	scenery.visible = d < SHOW_RANGE
	var live := d < WALK_RANGE
	actors.visible = live
	actors.process_mode = Node.PROCESS_MODE_INHERIT if live else Node.PROCESS_MODE_DISABLED


func _build_houses(rng: RandomNumberGenerator) -> void:
	for ring_r: float in HOUSE_RINGS:
		var placed_count := 0
		var angle := rng.randf() * 0.3
		while angle < TAU - 0.2:
			var w := 5 + 2 * rng.randi_range(0, 1)
			var d := 5 + 2 * rng.randi_range(0, 1)
			var step := float(maxi(w, d) + 4) / ring_r
			var px := cos(angle) * ring_r
			var pz := sin(angle) * ring_r
			angle += step
			if pz < 0.0 and absf(px) < 12.0:
				continue
			if rng.randf() < 0.2:
				continue
			if placed_count >= HOUSE_CAP / 2:
				continue
			placed_count += 1
			var pos := Vector3(center.x + px, float(floor_y), center.z + pz)
			if place_houses:
				var inward := Vector2(-px, -pz)
				var door_dir := Vector2i(0, 0)
				if absf(inward.x) > absf(inward.y):
					door_dir = Vector2i(int(signf(inward.x)), 0)
				else:
					door_dir = Vector2i(0, int(signf(inward.y)))
				House.build_blocks(self.get_parent(), floori(pos.x), floori(pos.z), floor_y, w, d, door_dir)
			var half := float(maxi(w, d)) * 0.5 + 1.4
			rects.append(Rect2(pos.x - half, pos.z - half, half * 2.0, half * 2.0))


func _guard(kind: String, x: int, dz: int, face: Vector3) -> void:
	var cell_z: int = terrain.SFORT_S + dz
	var top: float = float(terrain.surface_y(x, cell_z))
	var guard := Node3D.new()
	guard.set_script(Folk)
	actors.add_child(guard)
	guard.position = Vector3(float(x) + 0.5, 0.0, float(cell_z) + 0.5)
	guard.setup(kind, top, face, false, [], Vector2.ZERO, Vector2.ZERO)


func _build_guards() -> void:
	var ring_r := float(terrain.SFORT_R_O) - 1.5
	for i in RING_GUARDS:
		var a := TAU * (float(i) + 0.5) / float(RING_GUARDS)
		var x := floori(cos(a) * ring_r)
		var dz := floori(sin(a) * ring_r)
		if dz < 0 and absi(x) <= 11:
			continue
		if terrain.sfort_kind(x, terrain.SFORT_S + dz) != 2:
			continue
		_guard("soldier" if i % 2 == 0 else "archer", x, dz, Vector3(cos(a), 0.0, sin(a)))
	var par_r = terrain.SFORT_PAR_IN + 1.5
	for i in PARAPET_GUARDS:
		var a := TAU * (float(i) + 0.25) / float(PARAPET_GUARDS)
		var x := floori(cos(a) * par_r)
		var dz := floori(sin(a) * par_r)
		if dz < 0 and absi(x) <= 6:
			continue
		if terrain.sfort_kind(x, terrain.SFORT_S + dz) != 5:
			continue
		_guard("archer" if i % 2 == 0 else "soldier", x, dz, Vector3(-cos(a), 0.0, -sin(a)))


func _build_villagers() -> void:
	var c2 := Vector2(center.x, center.z)
	for i in VILLAGERS:
		var a := randf() * TAU
		var rad := randf_range(43.0, 60.0)
		var folk := Node3D.new()
		folk.set_script(Folk)
		actors.add_child(folk)
		folk.position = Vector3(center.x + cos(a) * rad, 0.0, center.z + sin(a) * rad)
		folk.setup("archer", float(floor_y), Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)), true, rects, Vector2.ZERO, Vector2.ZERO)
		folk.set_ring(c2, 43.0, 60.0)


static func _torch(world, pos: Vector3, normal: Vector3) -> void:
	var torch = load(TORCH_SCENE).instantiate()
	torch.fixture = normal == Vector3.ZERO
	torch.wall_normal = normal
	world.add_child(torch)
	torch.global_position = pos


static func _kind(terrain, x: int, dz: int) -> int:
	return terrain.sfort_kind(x, terrain.SFORT_S + dz)


static func _outside(terrain, x: int, dz: int) -> Vector2i:
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _kind(terrain, x + dir.x, dz + dir.y) == 0:
			return dir
	return Vector2i.ZERO


static func build_blocks(world, terrain) -> void:
	var f: int = terrain.sfort_floor
	_gate(world, terrain, f)
	_ladders(world, terrain, f)
	_merlons(world, terrain)
	_scaffolds(world, terrain)


static func _gate(world, terrain, f: int) -> void:
	var h: int = terrain.SFORT_WALL_H
	for row in [-terrain.SFORT_R_O, -(terrain.SFORT_R_O - 4)]:
		var z: int = terrain.SFORT_S + row
		for x in [-1, 0]:
			world.restore_block("reinforced_door", Vector3(x + 0.5, f + 0.5, z + 0.5), 0.0)
			world.restore_block("stone_brick", Vector3(x + 0.5, f + 2.5, z + 0.5))
			for y in [h - 2, h - 1]:
				world.restore_block("stone_brick", Vector3(x + 0.5, f + y + 0.5, z + 0.5))
		for x in [-2, 1]:
			for y in h:
				world.restore_block("stone_brick", Vector3(x + 0.5, f + y + 0.5, z + 0.5))
			_torch(world, Vector3(x + 0.5, f + h + 0.5, z + 0.5), Vector3.ZERO)


static func _ladder(world, terrain, f: int, x: int, dz: int, yaw: float, normal: Vector3) -> void:
	var z: int = terrain.SFORT_S + dz
	for k in terrain.SFORT_WALL_H:
		world.restore_block("ladder", Vector3(x + 0.5, f + k + 0.5, z + 0.5), yaw)
	var side := Vector3(normal.z, 0.0, -normal.x)
	var tx := x + roundi(side.x)
	var tz := z + roundi(side.z)
	var ty := f + 3
	if terrain.block_at(tx - roundi(normal.x), ty, tz - roundi(normal.z)) == 0:
		return
	if terrain.block_at(tx, ty, tz) != 0:
		return
	_torch(world, Vector3(tx + 0.5, ty + 0.5, tz + 0.5), normal)


static func _ladders(world, terrain, f: int) -> void:
	var limit: int = terrain.SFORT_R_O
	for lat in [-14, 14]:
		for dz in range(-50, -limit - 1, -1):
			if _kind(terrain, lat, dz) == 2:
				_ladder(world, terrain, f, lat, dz + 1, 0.0, Vector3(0, 0, 1))
				break
		for dz in range(50, limit + 1):
			if _kind(terrain, lat, dz) == 2:
				_ladder(world, terrain, f, lat, dz - 1, PI, Vector3(0, 0, -1))
				break
		for x in range(50, limit + 1):
			if _kind(terrain, x, lat) == 2:
				_ladder(world, terrain, f, x - 1, lat, -PI * 0.5, Vector3(-1, 0, 0))
				break
		for x in range(-50, -limit - 1, -1):
			if _kind(terrain, x, lat) == 2:
				_ladder(world, terrain, f, x + 1, lat, PI * 0.5, Vector3(1, 0, 0))
				break


static func _merlons(world, terrain) -> void:
	var limit: int = terrain.SFORT_R_O
	for x in range(-limit, limit + 1):
		for dz in range(-limit, limit + 1):
			var kind := _kind(terrain, x, dz)
			if kind != 2 and kind != 5:
				continue
			var z: int = terrain.SFORT_S + dz
			var top: int = terrain.surface_y(x, z)
			if kind == 2:
				var out := _outside(terrain, x, dz)
				if out == Vector2i.ZERO or (x + dz) % 2 != 0:
					continue
				var yaw := 0.0 if out.y != 0 else PI * 0.5
				world.restore_block("merlon", Vector3(x + 0.5, top + 0.5, z + 0.5), yaw)
				continue
			var r := Vector2(x + 0.5, dz + 0.5).length()
			if r > terrain.SFORT_PAR_IN + 1.0:
				continue
			if (x + dz) % 2 == 0:
				world.restore_block("merlon", Vector3(x + 0.5, top + 0.5, z + 0.5), 0.0)
			elif (x * 7 + dz * 5) % 13 == 0:
				_torch(world, Vector3(x + 0.5, top + 0.5, z + 0.5), Vector3.ZERO)


static func _scaffolds(world, terrain) -> void:
	var limit: int = terrain.SFORT_R_O
	var inner := float(terrain.SFORT_R_O - terrain.SFORT_WALL) + 1.2
	for x in range(-limit, limit + 1):
		for dz in range(-limit, limit + 1):
			if _kind(terrain, x, dz) != 2:
				continue
			if Vector2(x + 0.5, dz + 0.5).length() > inner:
				continue
			if posmod(x * 3 + dz * 5, 23) != 0:
				continue
			var z: int = terrain.SFORT_S + dz
			var top: int = terrain.surface_y(x, z)
			for k in 2:
				world.restore_block("scaffold", Vector3(x + 0.5, top + k + 0.5, z + 0.5))
