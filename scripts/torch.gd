extends "res://scripts/block.gd"

const WIND_SCALE := 1.1

@export var base_energy: float = 1.8
@export var fill_energy: float = 0.32

var fixture: bool = false
var time: float = 0.0

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


func _build() -> void:
	if fixture:
		remove_from_group("resource")
	time = randf() * 10.0
	base_mesh.mesh = TileArt.box_mesh(Vector3(0.125, 1.0, 0.125), TileArt.uv_material("torch_base", Color(0.2, 0.18, 0.17), Vector3.ONE))


func _play_death() -> void:
	queue_free()


func _process(delta: float) -> void:
	super(delta)
	time += delta
	light.light_energy = base_energy * (1.0 + 0.12 * sin(time * 9.0) + 0.08 * sin(time * 23.0))
	fill.light_energy = fill_energy * (1.0 + 0.06 * sin(time * 9.0) + 0.04 * sin(time * 23.0))
	var t := Time.get_ticks_msec() / 1000.0
	var phase := global_position.x * 0.45 + global_position.z * 0.35
	var gust := sin(t * 1.6 + phase) + 0.5 * sin(t * 3.68 + phase * 1.7)
	particles.gravity = Vector3(gust * WIND_SCALE, 1.2, 0.6 * cos(t * 1.28 + phase) * WIND_SCALE)
