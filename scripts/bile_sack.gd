extends Node3D

const ChipBurst = preload("res://scripts/chip_burst.gd")
const BlockIndex = preload("res://scripts/block_index.gd")

const GRAVITY := 22.0
const SPLASH_RADIUS := 3.2
const SPLASH_BLOCK := 5
const SPLASH_UNIT := 7
const SPLASH_PLAYER := 9
const SPLASH_CORE := 14
const PUDDLE_TIME := 6.0
const PUDDLE_RADIUS := 2.2
const TICK := 0.5
const TICK_BLOCK := 1
const TICK_UNIT := 2
const TICK_PLAYER := 2
const BILE := Color(0.36, 0.2, 0.46)

static var sack_material: StandardMaterial3D
static var puddle_material: StandardMaterial3D

var velocity := Vector3.ZERO
var landed: bool = false
var life: float = 0.0
var tick_left: float = TICK
var sack_mesh: MeshInstance3D
var puddle_mesh: MeshInstance3D


static func drop(host: Node, pos: Vector3, start_velocity: Vector3 = Vector3.ZERO) -> void:
	if host == null or not host.is_inside_tree():
		return
	var sack := Node3D.new()
	sack.set_script(load("res://scripts/bile_sack.gd"))
	host.get_tree().current_scene.add_child(sack)
	sack.global_position = pos
	sack.velocity = start_velocity


static func splash(host: Node, pos: Vector3, radius: float, block_damage: int, unit_damage: int, player_damage: int, core_damage: int) -> void:
	if host == null or not host.is_inside_tree():
		return
	var r2 := radius * radius
	for b in BlockIndex.list.duplicate():
		if not is_instance_valid(b) or b.dying or not b.structural or b.is_in_group("torch"):
			continue
		if b.global_position.distance_squared_to(pos) <= r2:
			b.take_damage(block_damage, pos)
	var tree := host.get_tree()
	for t in tree.get_nodes_in_group("troop"):
		if is_instance_valid(t) and t.global_position.distance_squared_to(pos) <= r2:
			t.take_damage(unit_damage, pos)
	var player = tree.get_first_node_in_group("player")
	if player != null and not player.dead:
		if (player.global_position + Vector3(0.0, 0.9, 0.0)).distance_squared_to(pos) <= r2:
			player.take_damage(player_damage, pos)
	if core_damage > 0:
		var core = tree.get_first_node_in_group("Core")
		if core != null and core.global_position.distance_to(pos) <= radius + 3.0:
			core.take_damage(core_damage, pos)


static func _ensure_materials() -> void:
	if sack_material != null:
		return
	sack_material = StandardMaterial3D.new()
	sack_material.albedo_color = Color(0.2, 0.1, 0.26)
	sack_material.emission_enabled = true
	sack_material.emission = BILE
	sack_material.emission_energy_multiplier = 0.7
	sack_material.roughness = 0.3
	puddle_material = StandardMaterial3D.new()
	puddle_material.albedo_color = Color(0.14, 0.06, 0.2, 0.85)
	puddle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puddle_material.emission_enabled = true
	puddle_material.emission = BILE
	puddle_material.emission_energy_multiplier = 0.5
	puddle_material.roughness = 0.15


func _ready() -> void:
	_ensure_materials()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	sphere.radial_segments = 10
	sphere.rings = 5
	sphere.material = sack_material
	sack_mesh = MeshInstance3D.new()
	sack_mesh.mesh = sphere
	sack_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sack_mesh)


func _physics_process(delta: float) -> void:
	life += delta
	if landed:
		_puddle(delta)
		return
	if global_position.y < -70.0 or life > 12.0:
		queue_free()
		return
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		return
	_land(hit["position"])


func _land(pos: Vector3) -> void:
	landed = true
	life = 0.0
	global_position = pos + Vector3(0.0, 0.04, 0.0)
	sack_mesh.visible = false
	ChipBurst.spawn(self, global_position + Vector3(0.0, 0.2, 0.0), "", BILE, 14, 0.14, 0.8, 85.0, 2.0, 5.0, 12.0)
	splash(self, global_position, SPLASH_RADIUS, SPLASH_BLOCK, SPLASH_UNIT, SPLASH_PLAYER, SPLASH_CORE)
	var disc := CylinderMesh.new()
	disc.top_radius = PUDDLE_RADIUS
	disc.bottom_radius = PUDDLE_RADIUS
	disc.height = 0.04
	disc.radial_segments = 14
	disc.rings = 1
	disc.material = puddle_material
	puddle_mesh = MeshInstance3D.new()
	puddle_mesh.mesh = disc
	puddle_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(puddle_mesh)


func _puddle(delta: float) -> void:
	if life > PUDDLE_TIME:
		queue_free()
		return
	var fade := clampf((PUDDLE_TIME - life) / 1.5, 0.0, 1.0)
	puddle_mesh.scale = Vector3(1.0, 1.0, 1.0) * lerpf(0.4, 1.0, fade)
	tick_left -= delta
	if tick_left > 0.0:
		return
	tick_left = TICK
	splash(self, global_position, PUDDLE_RADIUS, TICK_BLOCK, TICK_UNIT, TICK_PLAYER, 0)
