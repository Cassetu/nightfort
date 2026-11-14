extends "res://scripts/blocks/block.gd"

const Hub = preload("res://scripts/allies/barricade_hub.gd")

const VARIANTS := 8
const ENEMY_DAMAGE := 4
const FRIENDLY_DAMAGE := 3
const MAX_DURABILITY := 80
const SPIKE_STAGES := [9, 7, 5, 3, 1]
const BASE_SIZE := Vector3(0.95, 0.22, 0.95)

var durability: int = MAX_DURABILITY
var variant: int = 0
var stage: int = 0
var model: MeshInstance3D

static var meshes: Dictionary = {}


func _configure() -> void:
	super()
	needs_support = true
	collision_layer = 64
	collision_mask = 0
	add_to_group("barricade")
	set_physics_process(false)
	support_timer = randf() * SUPPORT_INTERVAL
	_register.call_deferred()


func _register() -> void:
	if dying or not is_inside_tree():
		return
	Hub.register(self)


func _exit_tree() -> void:
	Hub.unregister(self)
	super()


func _supported() -> bool:
	var cx := floori(global_position.x)
	var cy := floori(global_position.y)
	var cz := floori(global_position.z)
	if terrain != null and terrain.block_at(cx, cy - 1, cz) != 0:
		return true
	var stability := get_tree().get_first_node_in_group("stability")
	if stability != null:
		var below = stability.cell_map.get(Vector3i(cx, cy - 1, cz))
		if below != null and is_instance_valid(below) and not below.dying:
			return true
	return super()


static func _append(st: SurfaceTool, mesh: Mesh, xform: Transform3D) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if order.is_empty():
		order = PackedInt32Array(range(verts.size()))
	for i in order:
		st.set_normal(xform.basis * norms[i])
		st.set_uv(uvs[i])
		st.add_vertex(xform * verts[i])


static func _variant_mesh(variant: int, count: int) -> ArrayMesh:
	var cache_key := variant * 16 + count
	if meshes.has(cache_key):
		return meshes[cache_key]
	var wood := TileArt.uv_material("wood", Color(0.45, 0.32, 0.18), Vector3.ONE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (variant + 1)

	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.07
	cone.height = 0.95
	cone.radial_segments = 6
	cone.rings = 1

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spike_index := 0
	for gx in 3:
		for gz in 3:
			var pos := Vector3((gx - 1) * 0.3 + rng.randf_range(-0.05, 0.05), -0.5 + 0.475, (gz - 1) * 0.3 + rng.randf_range(-0.05, 0.05))
			var rot := Vector3(rng.randf_range(-0.28, 0.28), rng.randf() * TAU, rng.randf_range(-0.28, 0.28))
			spike_index += 1
			if spike_index > count:
				continue
			_append(st, cone, Transform3D(Basis.from_euler(rot), pos))
	var rail_mesh := TileArt.box_mesh(Vector3(0.98, 0.08, 0.1), wood)
	for z in [-0.28, 0.28]:
		_append(st, rail_mesh, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.22, z)))
	var brace_mesh := TileArt.box_mesh(Vector3(0.1, 0.08, 0.98), wood)
	_append(st, brace_mesh, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.34, 0.0)))
	var mesh := st.commit()
	mesh.surface_set_material(0, wood)
	meshes[cache_key] = mesh
	return mesh


func _build() -> void:
	variant = absi(hash(Vector3i(floori(global_position.x), floori(global_position.y), floori(global_position.z)))) % VARIANTS
	model = MeshInstance3D.new()
	model.mesh = _variant_mesh(variant, SPIKE_STAGES[0])
	visual.add_child(model)

	var base := CollisionShape3D.new()
	var base_shape := BoxShape3D.new()
	base_shape.size = BASE_SIZE
	base.shape = base_shape
	base.position = Vector3(0.0, -0.5 + BASE_SIZE.y * 0.5, 0.0)
	add_child(base)


func strike(body: Node) -> void:
	if dying:
		return
	var spot := global_position + Vector3(0.0, 0.2, 0.0)
	if body.is_in_group("enemy") or body.is_in_group("wild_gloom"):
		if body.dying:
			return
		body.take_damage(ENEMY_DAMAGE, spot)
		durability -= ENEMY_DAMAGE
	elif body.is_in_group("player") or body.is_in_group("troop"):
		body.take_damage(FRIENDLY_DAMAGE, spot)
	if durability <= 0:
		_wear_out()
	else:
		_update_spikes()


func _update_spikes() -> void:
	var stages: int = SPIKE_STAGES.size()
	var next: int = clampi(stages - int(ceil(float(durability) / float(MAX_DURABILITY) * float(stages))), 0, stages - 1)
	if next == stage or model == null:
		return
	stage = next
	model.mesh = _variant_mesh(variant, SPIKE_STAGES[stage])


func _wear_out() -> void:
	if dying:
		return
	dying = true
	Hub.unregister(self)
	remove_from_group("resource")
	remove_from_group("barricade")
	collision_layer = 0
	_spawn_chips(global_position)
	_play_death()
