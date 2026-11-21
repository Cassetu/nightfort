extends Node3D

const Folk = preload("res://scripts/north_folk.gd")
const House = preload("res://scripts/village_house.gd")
const TORCH_SCENE := "res://scenes/torch.tscn"
const ORB_COLOR := Color(0.62, 0.82, 1.0)
const WALK_RANGE := 240.0
const SHOW_RANGE := 260.0
const HOUSE_GRID := 13
const GUARD_EVERY := 20
const VILLAGERS := 14
const HOUSE_CAP := 14

var terrain
var player
var floor_y: int = 0
var scenery: Node3D
var actors: Node3D
var orb: Node3D
var orb_base: float = 0.0
var time: float = 0.0
var check: float = 0.0
var center: Vector3 = Vector3.ZERO
var rects: Array = []
var place_houses: bool = false


func setup(terrain_node, player_node, seed_value: int) -> void:
	terrain = terrain_node
	player = player_node
	floor_y = terrain.fort_floor
	center = Vector3(0.5, float(floor_y), float(-terrain.FORT_S) + 0.5)
	scenery = Node3D.new()
	scenery.name = "Scenery"
	add_child(scenery)
	actors = Node3D.new()
	actors.name = "Actors"
	add_child(actors)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x7f4a7c15
	_build_orb()
	_build_houses(rng)
	_build_guards()
	_build_villagers(rng)


func _process(delta: float) -> void:
	time += delta
	check -= delta
	if check <= 0.0:
		check = 0.5
		if player != null and is_instance_valid(player):
			var d: float = Vector2(player.global_position.x - center.x, player.global_position.z - center.z).length()
			scenery.visible = d < SHOW_RANGE
			var live := d < WALK_RANGE
			actors.visible = live
			actors.process_mode = Node.PROCESS_MODE_INHERIT if live else Node.PROCESS_MODE_DISABLED
	if orb != null and scenery.visible:
		orb.position.y = orb_base + sin(time * 1.1) * 0.18
		orb.rotation.y = time * 0.3


func _wz(dz: int) -> float:
	return float(dz - terrain.FORT_S) + 0.5


func _build_orb() -> void:
	orb = Node3D.new()
	orb.name = "Anchor"
	orb.add_to_group("scenery_cull")
	scenery.add_child(orb)
	orb_base = float(floor_y) + 3.0
	orb.position = Vector3(center.x, orb_base, center.z)
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = ORB_COLOR
	core_mat.emission_enabled = true
	core_mat.emission = ORB_COLOR
	core_mat.emission_energy_multiplier = 2.4
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.6
	sphere.material = core_mat
	core.mesh = sphere
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.add_child(core)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(ORB_COLOR.r, ORB_COLOR.g, ORB_COLOR.b, 0.22)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glow := MeshInstance3D.new()
	var shell := SphereMesh.new()
	shell.radius = 1.25
	shell.height = 2.5
	shell.material = glow_mat
	glow.mesh = shell
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.add_child(glow)
	var light := OmniLight3D.new()
	light.light_color = ORB_COLOR
	light.light_energy = 2.4
	light.omni_range = 18.0
	light.shadow_enabled = false
	orb.add_child(light)
	var motes := CPUParticles3D.new()
	motes.amount = 28
	motes.lifetime = 4.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 1.4
	motes.direction = Vector3.UP
	motes.spread = 25.0
	motes.gravity = Vector3(0.0, 0.25, 0.0)
	motes.initial_velocity_min = 0.1
	motes.initial_velocity_max = 0.35
	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.0
	var mote_mat := StandardMaterial3D.new()
	mote_mat.albedo_color = ORB_COLOR
	mote_mat.emission_enabled = true
	mote_mat.emission = ORB_COLOR
	mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.04
	mote_mesh.height = 0.08
	mote_mesh.material = mote_mat
	motes.mesh = mote_mesh
	orb.add_child(motes)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.85
	shape.shape = s
	body.add_child(shape)
	orb.add_child(body)


func _house_sites(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var lo: int = terrain.FORT_R_I + 5
	var hi: int = terrain.FORT_R_O - terrain.FORT_WALL - 4
	for gx in range(-5, 6):
		for gz in range(-5, 6):
			var w := 5 + 2 * rng.randi_range(0, 1)
			var d := 5 + 2 * rng.randi_range(0, 1)
			var jx := rng.randi_range(-1, 1)
			var jz := rng.randi_range(-1, 1)
			var side := rng.randi_range(0, 3)
			var keep := rng.randf() < 0.8
			var cx := gx * HOUSE_GRID + jx
			var cz := gz * HOUSE_GRID + jz
			if not keep:
				continue
			var near := maxi(absi(cx) - w / 2, absi(cz) - d / 2)
			var far := maxi(absi(cx) + w / 2, absi(cz) + d / 2)
			if near < lo or far > hi:
				continue
			if cz > 0 and absi(cx) <= 6 + w / 2:
				continue
			out.append({"x": cx, "z": cz, "w": w, "d": d, "side": side})
	return out


func _build_houses(rng: RandomNumberGenerator) -> void:
	var sites: Array = _house_sites(rng)
	var stride := maxi(1, ceili(float(sites.size()) / float(HOUSE_CAP)))
	for i in range(0, sites.size(), stride):
		_house(sites[i])
	var inner := float(terrain.FORT_R_I + 2)
	rects.append(Rect2(center.x - inner, center.z - inner, inner * 2.0 + 1.0, inner * 2.0 + 1.0))


func _house(site: Dictionary) -> void:
	var w: int = site["w"]
	var d: int = site["d"]
	var cx: float = center.x + float(site["x"])
	var cz: float = center.z + float(site["z"])
	if place_houses:
		var dirs: Array = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
		var door_dir: Vector2i = dirs[site["side"]]
		House.build_blocks(get_parent(), floori(cx), floori(cz), floor_y, w, d, door_dir)
	var fw := float(w)
	var fd := float(d)
	var pad := 1.2
	rects.append(Rect2(cx - fw * 0.5 - pad, cz - fd * 0.5 - pad, fw + pad * 2.0, fd + pad * 2.0))


func _deck_y(x: int, dz: int) -> float:
	return float(terrain.surface_y(x, dz - terrain.FORT_S))


func _build_guards() -> void:
	for ring in [terrain.FORT_R_O, terrain.FORT_R_I]:
		var edge: int = ring - 1
		for side in 4:
			var count := int(float(ring * 2) / float(GUARD_EVERY))
			for i in count:
				var l = -ring + GUARD_EVERY / 2 + i * GUARD_EVERY
				var x := 0
				var dz := 0
				var face := Vector3.ZERO
				match side:
					0:
						x = l
						dz = edge
						face = Vector3(0, 0, 1)
					1:
						x = l
						dz = -edge
						face = Vector3(0, 0, -1)
					2:
						x = edge
						dz = l
						face = Vector3(1, 0, 0)
					_:
						x = -edge
						dz = l
						face = Vector3(-1, 0, 0)
				if side == 0 and absi(x) <= 10:
					continue
				var kind := "soldier" if (i + side) % 2 == 0 else "archer"
				var guard := Node3D.new()
				guard.set_script(Folk)
				actors.add_child(guard)
				guard.position = Vector3(float(x) + 0.5, 0.0, _wz(dz))
				guard.setup(kind, _deck_y(x, dz), face, false, [], Vector2.ZERO, Vector2.ZERO)


func _build_villagers(rng: RandomNumberGenerator) -> void:
	var half: float = float(terrain.FORT_R_O - terrain.FORT_WALL - 2)
	var lo := Vector2(center.x - half, center.z - half)
	var hi := Vector2(center.x + half, center.z + half)
	for i in VILLAGERS:
		var p := Vector3(rng.randf_range(lo.x, hi.x), 0.0, rng.randf_range(lo.y, hi.y))
		var tries := 0
		while tries < 20 and _spot_blocked(p):
			p = Vector3(rng.randf_range(lo.x, hi.x), 0.0, rng.randf_range(lo.y, hi.y))
			tries += 1
		var folk := Node3D.new()
		folk.set_script(Folk)
		actors.add_child(folk)
		folk.position = Vector3(p.x, 0.0, p.z)
		folk.setup("archer", float(floor_y), Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)), true, rects, lo, hi)


func _spot_blocked(p: Vector3) -> bool:
	for r: Rect2 in rects:
		if r.has_point(Vector2(p.x, p.z)):
			return true
	return false


static func build_blocks(world, terrain) -> void:
	var floor_y: int = terrain.fort_floor
	var rings := [
		{"r": terrain.FORT_R_O, "h": terrain.FORT_WALL_H},
		{"r": terrain.FORT_R_I, "h": terrain.FORT_INNER_H},
	]
	for entry: Dictionary in rings:
		var r: int = entry["r"]
		var h: int = entry["h"]
		_gate(world, terrain, r, h, floor_y)
		_merlons(world, terrain, r)
		_scaffolds(world, terrain, r)
	var out_face: int = terrain.FORT_R_O - terrain.FORT_WALL
	for lat in [-20, 20]:
		_ladder(world, terrain, lat, out_face, terrain.FORT_WALL_H, PI, Vector3(0, 0, -1), floor_y)
		_ladder(world, terrain, lat, -out_face, terrain.FORT_WALL_H, 0.0, Vector3(0, 0, 1), floor_y)
		_ladder(world, terrain, out_face, lat, terrain.FORT_WALL_H, -PI * 0.5, Vector3(-1, 0, 0), floor_y)
		_ladder(world, terrain, -out_face, lat, terrain.FORT_WALL_H, PI * 0.5, Vector3(1, 0, 0), floor_y)
	var gap_face: int = terrain.FORT_R_I + 1
	for lat in [-8, 8]:
		_ladder(world, terrain, lat, gap_face, terrain.FORT_INNER_H, 0.0, Vector3(0, 0, 1), floor_y)
		_ladder(world, terrain, lat, -gap_face, terrain.FORT_INNER_H, PI, Vector3(0, 0, -1), floor_y)
		_ladder(world, terrain, gap_face, lat, terrain.FORT_INNER_H, PI * 0.5, Vector3(1, 0, 0), floor_y)
		_ladder(world, terrain, -gap_face, lat, terrain.FORT_INNER_H, -PI * 0.5, Vector3(-1, 0, 0), floor_y)
	var yard_face: int = terrain.FORT_R_I - terrain.FORT_WALL
	for lat in [-6, 6]:
		_ladder(world, terrain, lat, yard_face, terrain.FORT_INNER_H, PI, Vector3(0, 0, -1), floor_y)
		_ladder(world, terrain, lat, -yard_face, terrain.FORT_INNER_H, 0.0, Vector3(0, 0, 1), floor_y)
		_ladder(world, terrain, yard_face, lat, terrain.FORT_INNER_H, -PI * 0.5, Vector3(-1, 0, 0), floor_y)
		_ladder(world, terrain, -yard_face, lat, terrain.FORT_INNER_H, PI * 0.5, Vector3(1, 0, 0), floor_y)


static func _cell_z(terrain, dz: int) -> int:
	return dz - terrain.FORT_S


static func _torch(world, pos: Vector3, normal: Vector3) -> void:
	var torch = load(TORCH_SCENE).instantiate()
	torch.fixture = normal == Vector3.ZERO
	torch.wall_normal = normal
	world.add_child(torch)
	torch.global_position = pos


static func _ladder(world, terrain, x: int, dz: int, h: int, yaw: float, normal: Vector3, floor_y: int) -> void:
	var z := _cell_z(terrain, dz)
	for k in h:
		world.restore_block("ladder", Vector3(x + 0.5, floor_y + k + 0.5, z + 0.5), yaw)
	var side := Vector3(normal.z, 0.0, -normal.x)
	var torch_cell := Vector3(x + 0.5, floor_y + 3.5, z + 0.5) + side
	_torch(world, torch_cell, normal)


static func _gate(world, terrain, ring: int, h: int, floor_y: int) -> void:
	for row in [ring, ring - terrain.FORT_WALL + 1]:
		var z := _cell_z(terrain, row)
		for x in [-1, 0]:
			world.restore_block("reinforced_door", Vector3(x + 0.5, floor_y + 0.5, z + 0.5), 0.0)
			world.restore_block("stone_brick", Vector3(x + 0.5, floor_y + 2.5, z + 0.5))
			for y in [h - 2, h - 1]:
				world.restore_block("stone_brick", Vector3(x + 0.5, floor_y + y + 0.5, z + 0.5))
		for x in [-2, 1]:
			for y in h:
				world.restore_block("stone_brick", Vector3(x + 0.5, floor_y + y + 0.5, z + 0.5))
			_torch(world, Vector3(x + 0.5, floor_y + h + 0.5, z + 0.5), Vector3.ZERO)


static func _perimeter(ring: int) -> Array:
	var cells: Array = []
	for i in range(-ring, ring + 1):
		cells.append(Vector2i(i, ring))
		cells.append(Vector2i(i, -ring))
	for i in range(-ring + 1, ring):
		cells.append(Vector2i(ring, i))
		cells.append(Vector2i(-ring, i))
	return cells


static func _merlons(world, terrain, ring: int) -> void:
	for c: Vector2i in _perimeter(ring):
		if (c.x + c.y) % 2 != 0:
			continue
		var z := _cell_z(terrain, c.y)
		if terrain.fort_kind(c.x, z) != 2:
			continue
		var top: int = terrain.surface_y(c.x, z)
		var yaw := 0.0 if absi(c.y) == ring else PI * 0.5
		world.restore_block("merlon", Vector3(c.x + 0.5, top + 0.5, z + 0.5), yaw)


static func _scaffolds(world, terrain, ring: int) -> void:
	var inner: int = ring - terrain.FORT_WALL + 1
	for l in range(-ring + 3, ring - 2):
		if posmod(l, 20) >= 2:
			continue
		for cell: Vector2i in [Vector2i(l, inner), Vector2i(l, -inner), Vector2i(inner, l), Vector2i(-inner, l)]:
			var z := _cell_z(terrain, cell.y)
			if terrain.fort_kind(cell.x, z) != 2:
				continue
			var top: int = terrain.surface_y(cell.x, z)
			for k in 2:
				world.restore_block("scaffold", Vector3(cell.x + 0.5, top + k + 0.5, z + 0.5))
