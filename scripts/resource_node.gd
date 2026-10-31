extends StaticBody3D

signal harvested(resource_type: String, amount: int)

@export var max_health: int = 5
@export var resource_type: String = "wood"
@export var resource_amount: int = 4

var current_health: int = 0
var dying: bool = false
var chip_color: Color = Color(0.5, 0.5, 0.5)
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

	var mat := StandardMaterial3D.new()
	mat.albedo_color = chip_color
	mat.roughness = 1.0

	var chip := BoxMesh.new()
	chip.size = Vector3(0.1, 0.1, 0.1)
	chip.material = mat

	var burst := CPUParticles3D.new()
	burst.mesh = chip
	burst.amount = 10
	burst.lifetime = 0.6
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.direction = Vector3.UP
	burst.spread = 70.0
	burst.gravity = Vector3(0.0, -12.0, 0.0)
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 4.5
	burst.emitting = false
	get_tree().current_scene.add_child(burst)
	burst.global_position = origin
	burst.emitting = true
	get_tree().create_timer(1.2).timeout.connect(burst.queue_free)
