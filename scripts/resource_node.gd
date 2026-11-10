extends StaticBody3D

const ChipBurst = preload("res://scripts/chip_burst.gd")

const Sfx = preload("res://scripts/core/sfx.gd")
const STONE_TYPES := ["stone", "basalt", "diorite", "granite", "limestone", "sandstone", "stone_brick", "basalt_brick", "diorite_brick", "granite_brick", "limestone_brick", "fortified_brick", "ruined_brick", "stone_forge", "iron_block"]
const CHOP_TYPES := ["wood", "plank", "scaffold", "door", "ladder", "chest", "workbench", "barricade"]

signal harvested(resource_type: String, amount: int)

@export var max_health: int = 5
@export var resource_type: String = "wood"
@export var resource_amount: int = 4

var current_health: int = 0
var dying: bool = false
var chip_color: Color = Color(0.5, 0.5, 0.5)
var chip_tile: String = ""
var visual: Node3D
var shake_tween: Tween


func _ready() -> void:
	_configure()
	add_to_group("resource")
	current_health = max_health
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_build()


func _configure() -> void:
	pass


func _build() -> void:
	pass


func take_damage(amount: int, hit_position: Vector3 = Vector3.INF) -> void:
	if dying:
		return
	current_health -= amount
	if CHOP_TYPES.has(resource_type):
		Sfx.play(self, "chop", global_position, -2.0)
	elif STONE_TYPES.has(resource_type):
		Sfx.play(self, "stone_break" if current_health <= 0 else "stone_hit", global_position, -2.0)
	_spawn_chips(hit_position)
	if current_health <= 0:
		_die()
	else:
		_shake()


func _die() -> void:
	dying = true
	remove_from_group("resource")
	collision_layer = 0
	if shake_tween:
		shake_tween.kill()
	harvested.emit(resource_type, resource_amount)
	if is_in_group("tree"):
		get_tree().call_group("missions", "on_event", "tree")
	var world := get_tree().current_scene
	if world != null and world.has_method("spawn_drop"):
		world.spawn_drop(resource_type, resource_amount, global_position + Vector3(0.0, 0.9, 0.0))
	_play_death()


func _play_death() -> void:
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _shake() -> void:
	if shake_tween:
		shake_tween.kill()
	visual.rotation = Vector3.ZERO
	var kick := randf_range(0.05, 0.09) * (1.0 if randf() > 0.5 else -1.0)
	shake_tween = create_tween()
	shake_tween.tween_property(visual, "rotation", Vector3(kick, 0.0, -kick), 0.05)
	shake_tween.tween_property(visual, "rotation", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _spawn_chips(hit_position: Vector3) -> void:
	var origin: Vector3 = global_position + Vector3(0.0, 1.0, 0.0)
	if hit_position.is_finite():
		origin = hit_position
	ChipBurst.spawn(self, origin, chip_tile, chip_color, 10, 0.1, 0.6, 70.0)
