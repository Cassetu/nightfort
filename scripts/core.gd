extends StaticBody3D

signal health_changed(current, maximum)
signal destroyed

@export var max_health: int = 100

var current_health: int
var dying: bool = false


func _ready():
	add_to_group("Core")
	current_health = max_health


func take_damage(amount: int, _hit_position = Vector3.INF):
	if dying or amount <= 0:
		return
	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	_pulse()
	if current_health <= 0:
		die()


func set_health(value: int):
	current_health = clampi(value, 0, max_health)
	health_changed.emit(current_health, max_health)


func die():
	dying = true
	destroyed.emit()
	queue_free()


func _pulse():
	var mesh = $MeshInstance3D
	var tween = create_tween()
	tween.tween_property(mesh, "scale", Vector3.ONE * 1.1, 0.05)
	tween.tween_property(mesh, "scale", Vector3.ONE, 0.2)
