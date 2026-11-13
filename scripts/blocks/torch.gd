extends "res://scripts/blocks/block.gd"

const WIND_SCALE := 1.1
const TILT := 0.38
const WALL_OFFSET := 0.28
const HEIGHT := 0.875

@export var base_energy: float = 1.8
@export var fill_energy: float = 0.32

var fixture: bool = false
var wall_normal: Vector3 = Vector3.ZERO
var mount: Node3D
var time: float = 0.0
var near: bool = true
var shadow_locked: bool = false

@onready var light: OmniLight3D = %Light
@onready var fill: OmniLight3D = %Fill
@onready var particles: CPUParticles3D = %Particles
@onready var base_mesh: MeshInstance3D = %Base


func _init() -> void:
	block_type = "torch"


func _configure() -> void:
	super()
	add_to_group("torch")
	needs_support = not fixture
	if fixture:
		remove_from_group("block")
		BlockIndex.remove(self)


func _build() -> void:
	if fixture:
		remove_from_group("resource")
	time = randf() * 10.0
	base_mesh.mesh = TileArt.box_mesh(Vector3(0.125, HEIGHT, 0.125), TileArt.uv_material("torch_base", Color(0.2, 0.18, 0.17), Vector3.ONE))
	if wall_normal != Vector3.ZERO:
		_build_mount()


func _build_mount() -> void:
	mount = Node3D.new()
	mount.name = "Mount"
	add_child(mount)
	mount.transform = Transform3D(mount_basis(wall_normal), -wall_normal * WALL_OFFSET)
	for child in [base_mesh, $Flame, particles, $CollisionShape3D, light, fill]:
		child.reparent(mount, false)


static func mount_basis(normal: Vector3) -> Basis:
	if normal == Vector3.ZERO:
		return Basis.IDENTITY
	var axis := Vector3.UP.cross(normal).normalized()
	return Basis(axis, TILT)


func _supported() -> bool:
	if wall_normal == Vector3.ZERO:
		return super()
	var w := global_position - wall_normal
	if terrain != null and terrain.block_at(floori(w.x), floori(w.y), floori(w.z)) != 0:
		return true
	var behind := BlockIndex.at(Vector3i(floori(w.x), floori(w.y), floori(w.z)))
	return behind != null and behind != self and behind.block_type != "torch"


func _play_death() -> void:
	queue_free()


func set_shadowed(on: bool) -> void:
	if shadow_locked or light == null:
		return
	if light.shadow_enabled != on:
		light.shadow_enabled = on


func _process(delta: float) -> void:
	super(delta)
	time += delta
	if not near:
		return
	light.light_energy = base_energy * (1.0 + 0.12 * sin(time * 9.0) + 0.08 * sin(time * 23.0))
	fill.light_energy = fill_energy * (1.0 + 0.06 * sin(time * 9.0) + 0.04 * sin(time * 23.0))
	var t := Time.get_ticks_msec() / 1000.0
	var phase := global_position.x * 0.45 + global_position.z * 0.35
	var gust := sin(t * 1.6 + phase) + 0.5 * sin(t * 3.68 + phase * 1.7)
	particles.gravity = Vector3(gust * WIND_SCALE, 1.2, 0.6 * cos(t * 1.28 + phase) * WIND_SCALE)
