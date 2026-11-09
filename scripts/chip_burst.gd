extends RefCounted

const Pool = preload("res://scripts/pool.gd")
const TileArt = preload("res://scripts/tile_art.gd")

const POOL_KEY := "chip_burst"
const SHAPES := 3

static var meshes: Dictionary = {}
static var materials: Dictionary = {}


static func _material(tile: String, color: Color) -> StandardMaterial3D:
	var key := tile + "|" + color.to_html(false)
	if not materials.has(key):
		var mat: StandardMaterial3D
		if tile != "":
			mat = TileArt.uv_material(tile, color, Vector3.ONE)
		else:
			mat = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.roughness = 1.0
		materials[key] = mat
	return materials[key]


static func _mesh(shape: int, size: float, tile: String, color: Color) -> Mesh:
	var key := "%d|%.3f|%s|%s" % [shape, size, tile, color.to_html(false)]
	if not meshes.has(key):
		var mesh: Mesh
		if shape == 0:
			var box := BoxMesh.new()
			box.size = Vector3(size, size, size)
			mesh = box
		elif shape == 1:
			var prism := PrismMesh.new()
			prism.size = Vector3(size * 1.3, size * 1.5, size * 0.7)
			mesh = prism
		else:
			var slab := BoxMesh.new()
			slab.size = Vector3(size * 1.7, size * 0.35, size * 1.2)
			mesh = slab
		mesh.surface_set_material(0, _material(tile, color))
		meshes[key] = mesh
	return meshes[key]


static func _make_emitter() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.particle_flag_rotate_y = true
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -420.0
	p.angular_velocity_max = 420.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.emitting = false
	return p


static func spawn(host: Node, origin: Vector3, tile: String, color: Color, amount: int = 10, size: float = 0.11, life: float = 0.6, spread: float = 75.0, speed_min: float = 2.0, speed_max: float = 4.5, gravity: float = 12.0) -> void:
	var tree := host.get_tree()
	if tree == null or tree.current_scene == null:
		return
	var first := randi() % SHAPES
	var second := (first + 1 + randi() % (SHAPES - 1)) % SHAPES
	var split := [int(ceil(amount * 0.5)), int(floor(amount * 0.5))]
	var shapes := [first, second]
	for n in 2:
		if split[n] <= 0:
			continue
		var p: CPUParticles3D = Pool.take(POOL_KEY, _make_emitter)
		p.mesh = _mesh(shapes[n], size, tile, color)
		p.amount = split[n]
		p.lifetime = life
		p.spread = spread
		p.gravity = Vector3(0.0, -gravity, 0.0)
		p.initial_velocity_min = speed_min
		p.initial_velocity_max = speed_max
		tree.current_scene.add_child(p)
		p.global_position = origin
		p.restart()
		p.emitting = true
		tree.create_timer(life * 2.0).timeout.connect(func() -> void: Pool.give(POOL_KEY, p))
