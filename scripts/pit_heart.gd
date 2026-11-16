extends StaticBody3D

signal health_changed(current: int, maximum: int)

const MAX_HEALTH := 600

var health: int = MAX_HEALTH


func _ready() -> void:
	add_to_group("pit_heart")


func take_damage(amount, _from: Vector3 = Vector3.INF) -> void:
	if health <= 0 or amount <= 0:
		return
	health = maxi(health - int(amount), 0)
	health_changed.emit(health, MAX_HEALTH)
