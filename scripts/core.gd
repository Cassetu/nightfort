extends StaticBody3D

@export var max_health: int = 100
var current_health: int

func _ready():
	add_to_group("Core")
	current_health = max_health

func take_damage(amount: int):
	current_health -= amount
	print("Core Health: ", current_health)
	
	var mat = $MeshInstance3D.material_override
	
	if current_health <= 0:
		die()

func die():
	print("GAME OVER! The Core was destroyed.")
	queue_free()
