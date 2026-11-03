extends StaticBody3D

const TileArt = preload("res://scripts/tile_art.gd")

@export var base_energy: float = 1.8

var time: float = 0.0

@onready var light: OmniLight3D = $Light


func _ready() -> void:
	time = randf() * 10.0
	$Base.material_override = TileArt.block_material("torch_base", Color(0.2, 0.18, 0.17))


func _process(delta: float) -> void:
	time += delta
	light.light_energy = base_energy * (1.0 + 0.12 * sin(time * 9.0) + 0.08 * sin(time * 23.0))
