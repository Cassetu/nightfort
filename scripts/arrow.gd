extends Node3D

const Sfx = preload("res://scripts/sfx.gd")
const Pool = preload("res://scripts/pool.gd")

const SPEED := 34.0
const GRAVITY := 4.0
const LIFE := 2.5
const HIT_MASK := 3
const LAND_LIFE := 90.0
const PICKUP_DELAY := 0.5
const PICKUP_RANGE := 1.7
const LENGTH := 0.55
const EMBED := 0.14

var velocity := Vector3.ZERO
var damage: int = 2
var age: float = 0.0
var ignore: Array = []
var pickable: bool = false
var landed: bool = false
var landed_age: float = 0.0
var stuck_on = null
var player_ref = null

static var shaft_mesh: BoxMesh
static var head_mesh: BoxMesh
static var vane_mesh: BoxMesh


static func fetch() -> Node3D:
	var arrow: Node3D = Pool.take("arrow", func() -> Node:
		var node := Node3D.new()
		node.set_script(load("res://scripts/arrow.gd"))
		return node)
	arrow.reset()
	return arrow


func reset() -> void:
	velocity = Vector3.ZERO
	damage = 2
	age = 0.0
	ignore = []
	pickable = false
	landed = false
	landed_age = 0.0
	stuck_on = null


func _recycle() -> void:
	set_physics_process(false)
	Pool.give("arrow", self)


func _ready() -> void:
	if shaft_mesh == null:
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.62, 0.48, 0.3)
		wood.roughness = 1.0
		var flint := StandardMaterial3D.new()
		flint.albedo_color = Color(0.42, 0.43, 0.46)
		flint.roughness = 0.9
		var feather := StandardMaterial3D.new()
		feather.albedo_color = Color(0.82, 0.8, 0.74)
		feather.roughness = 1.0
		feather.cull_mode = BaseMaterial3D.CULL_DISABLED
		shaft_mesh = BoxMesh.new()
		shaft_mesh.size = Vector3(0.025, 0.025, LENGTH)
		shaft_mesh.material = wood
		head_mesh = BoxMesh.new()
		head_mesh.size = Vector3(0.055, 0.055, 0.09)
		head_mesh.material = flint
		vane_mesh = BoxMesh.new()
		vane_mesh.size = Vector3(0.1, 0.004, 0.14)
		vane_mesh.material = feather
	if get_child_count() > 0:
		return
	_add_part(shaft_mesh, Vector3.ZERO, 0.0)
	_add_part(head_mesh, Vector3(0.0, 0.0, -LENGTH * 0.5 - 0.03), 0.0)
	_add_part(vane_mesh, Vector3(0.0, 0.0, LENGTH * 0.5 - 0.08), 0.0)
	_add_part(vane_mesh, Vector3(0.0, 0.0, LENGTH * 0.5 - 0.08), PI * 0.5)


func _add_part(mesh: Mesh, pos: Vector3, roll: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.z = roll
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func launch(from: Vector3, dir: Vector3, dmg: int, speed: float = SPEED) -> void:
	set_physics_process(true)
	global_position = from
	velocity = dir.normalized() * speed
	damage = dmg
	if velocity.length() > 0.1:
		look_at(from + velocity, Vector3.UP)


func _physics_process(delta: float) -> void:
	if landed:
		_resting(delta)
		return
	age += delta
	if age > LIFE:
		_recycle()
		return
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
	query.exclude = ignore
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target = hit["collider"]
		if target.is_in_group("enemy") or target.is_in_group("wild_gloom") or target.is_in_group("gloom_bird"):
			target.take_damage(damage, from - velocity.normalized() * 2.0)
			_recycle()
			return
		if pickable:
			_land(hit)
			return
		_recycle()
		return
	global_position = to
	velocity.y -= GRAVITY * delta
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)


func _land(hit: Dictionary) -> void:
	landed = true
	stuck_on = hit["collider"]
	var dir := velocity.normalized()
	global_position = hit["position"] - dir * (LENGTH * 0.5 + 0.03 - EMBED)
	if dir.length() > 0.1:
		look_at(global_position + dir, Vector3.UP)


func _resting(delta: float) -> void:
	landed_age += delta
	if landed_age > LAND_LIFE:
		_recycle()
		return
	if stuck_on != null and (not is_instance_valid(stuck_on) or (stuck_on.has_method("take_damage") and stuck_on.get("dying") == true)):
		var world := get_tree().current_scene
		if world != null and world.has_method("spawn_drop"):
			world.spawn_drop("arrow", 1, global_position)
		_recycle()
		return
	if landed_age < PICKUP_DELAY:
		return
	if player_ref == null or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		if player_ref == null:
			return
	var reach: Vector3 = player_ref.global_position + Vector3(0.0, 0.7, 0.0)
	if reach.distance_to(global_position) > PICKUP_RANGE:
		return
	if Inventory.add_item("arrow", 1) > 0:
		return
	Sfx.play(self, "pickup", global_position, -4.0)
	_recycle()
