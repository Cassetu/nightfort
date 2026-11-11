extends RigidBody3D

const TileArt = preload("res://scripts/tile_art.gd")
const Sfx = preload("res://scripts/core/sfx.gd")
const Pool = preload("res://scripts/core/pool.gd")

const PICKUP_RADIUS := 0.9
const MAGNET_RADIUS := 2.8
const MAGNET_SPEED := 9.0
const PICKUP_DELAY := 0.6
const LIFETIME := 300.0

var id: String = "dirt"
var count: int = 1
var age: float = 0.0
var player
var built: bool = false

@onready var visual: Node3D = $Visual
@onready var mesh: MeshInstance3D = $Visual/Mesh


func _ready() -> void:
	_setup()
	built = true


func reuse() -> void:
	age = 0.0
	sleeping = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	_setup()
	set_physics_process(true)


func _recycle() -> void:
	set_physics_process(false)
	Pool.give("item_drop", self)


func _setup() -> void:
	var info: Dictionary = Inventory.ITEMS.get(id, {})
	var color: Color = info.get("color", Color.WHITE)
	var tile_name: String = info.get("tile", "")
	var tex := TileArt.icon(id, tile_name)
	if tex != null:
		mesh.material_override = TileArt.texture_material(tex, tile_name == "")
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.25
	mesh.material_override = mat
	age = randf() * 0.2


func _process(delta: float) -> void:
	visual.rotation.y += delta * 2.0
	visual.position.y = 0.12 + sin(age * 3.0) * 0.05


func _physics_process(delta: float) -> void:
	age += delta
	if age > LIFETIME or global_position.y < -500.0:
		_recycle()
		return
	if age < PICKUP_DELAY:
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	if player.dead or player.frozen:
		return

	var target: Vector3 = player.global_position + Vector3(0.0, 0.4, 0.0)
	var dist := global_position.distance_to(target)
	if dist < PICKUP_RADIUS:
		var left := Inventory.add_item(id, count)
		if left < count:
			Sfx.play(self, "pickup_gem" if id == "soul_gem" else "pickup", global_position, -2.0)
		if left <= 0:
			_recycle()
		else:
			count = left
	elif dist < MAGNET_RADIUS and Inventory.can_accept(id):
		linear_velocity = (target - global_position).normalized() * MAGNET_SPEED
