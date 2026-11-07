extends "res://scripts/block.gd"

const TICK := 0.5
const ENEMY_DAMAGE := 4
const FRIENDLY_DAMAGE := 3
const MAX_DURABILITY := 80
const ZONE_SIZE := Vector3(0.9, 0.9, 0.9)
const BASE_SIZE := Vector3(0.95, 0.22, 0.95)
const ZONE_MASK := 7

var durability: int = MAX_DURABILITY
var zone: Area3D
var tick_timer: float = 0.0


func _configure() -> void:
	super()
	needs_support = true
	collision_layer = 64
	collision_mask = 0
	add_to_group("barricade")


func _build() -> void:
	var wood := TileArt.uv_material("wood", Color(0.45, 0.32, 0.18), Vector3.ONE)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(floori(global_position.x), floori(global_position.y), floori(global_position.z)))

	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.07
	cone.height = 0.95
	cone.radial_segments = 6
	cone.rings = 1
	cone.material = wood
	for gx in 3:
		for gz in 3:
			var stake := MeshInstance3D.new()
			stake.mesh = cone
			stake.position = Vector3((gx - 1) * 0.3 + rng.randf_range(-0.05, 0.05), -0.5 + 0.475, (gz - 1) * 0.3 + rng.randf_range(-0.05, 0.05))
			stake.rotation = Vector3(rng.randf_range(-0.28, 0.28), rng.randf() * TAU, rng.randf_range(-0.28, 0.28))
			visual.add_child(stake)

	for z in [-0.28, 0.28]:
		var rail := MeshInstance3D.new()
		rail.mesh = TileArt.box_mesh(Vector3(0.98, 0.08, 0.1), wood)
		rail.position = Vector3(0.0, -0.22, z)
		visual.add_child(rail)
	var brace := MeshInstance3D.new()
	brace.mesh = TileArt.box_mesh(Vector3(0.1, 0.08, 0.98), wood)
	brace.position = Vector3(0.0, -0.34, 0.0)
	visual.add_child(brace)

	var base := CollisionShape3D.new()
	var base_shape := BoxShape3D.new()
	base_shape.size = BASE_SIZE
	base.shape = base_shape
	base.position = Vector3(0.0, -0.5 + BASE_SIZE.y * 0.5, 0.0)
	add_child(base)

	zone = Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = ZONE_MASK
	zone.monitorable = false
	var zone_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = ZONE_SIZE
	zone_shape.shape = box
	zone.add_child(zone_shape)
	add_child(zone)


func _physics_process(delta: float) -> void:
	if dying or zone == null:
		return
	tick_timer += delta
	if tick_timer < TICK:
		return
	tick_timer = 0.0
	var spot := global_position + Vector3(0.0, 0.2, 0.0)
	for body in zone.get_overlapping_bodies():
		if not is_instance_valid(body):
			continue
		if body.is_in_group("enemy") or body.is_in_group("wild_gloom"):
			if body.dying:
				continue
			body.take_damage(ENEMY_DAMAGE, spot)
			durability -= ENEMY_DAMAGE
		elif body.is_in_group("player") or body.is_in_group("troop"):
			body.take_damage(FRIENDLY_DAMAGE, spot)
	if durability <= 0:
		_wear_out()


func _wear_out() -> void:
	if dying:
		return
	dying = true
	remove_from_group("resource")
	remove_from_group("barricade")
	collision_layer = 0
	_spawn_chips(global_position)
	_play_death()
