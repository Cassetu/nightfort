extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var build_ray = $Head/Camera3D/BuildRay
@onready var ghost_block = $GhostBlock
@export var block_scene: PackedScene

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ghost_block.top_level = true 

func _process(delta):
	if build_ray.is_colliding():
		ghost_block.show()
		
		var point = build_ray.get_collision_point()
		var normal = build_ray.get_collision_normal()
		
		var target_pos = point + (normal * 0.5)
		
		var snapped_pos = Vector3(
			floor(target_pos.x) + 0.5,
			floor(target_pos.y) + 0.5,
			floor(target_pos.z) + 0.5
		)
		
		ghost_block.global_position = snapped_pos
		if Input.is_action_just_pressed("build"):
			if ghost_block.global_position.distance_to(global_position) > 1.2:
				var new_block = block_scene.instantiate()
				get_tree().current_scene.add_child(new_block)
				new_block.global_position = ghost_block.global_position
	else:
		ghost_block.hide()
