extends StaticBody3D

var target
var resource_type: String = "plank"


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	add_to_group("resource")
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	add_child(shape)


func take_damage(amount: int, hit_position: Vector3 = Vector3.INF) -> void:
	if is_instance_valid(target):
		target.take_damage(amount, hit_position)
