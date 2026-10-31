extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002
const HARVEST_REACH = 3.5
const HARVEST_DAMAGE = 1
const HARVEST_COOLDOWN = 0.35

var harvest_timer = 0.0

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

	harvest_timer = maxf(harvest_timer - delta, 0.0)
	if Input.is_action_pressed("harvest") and harvest_timer <= 0.0:
		try_harvest()

func try_harvest():
	var from = camera.global_position
	var to = from - camera.global_transform.basis.z * HARVEST_REACH
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var target = hit.collider
	if not target.is_in_group("resource"):
		return
	harvest_timer = HARVEST_COOLDOWN
	if not target.harvested.is_connected(_on_harvested):
		target.harvested.connect(_on_harvested)
	target.take_damage(HARVEST_DAMAGE, hit.position)

func _on_harvested(resource_type, amount):
	Inventory.add(resource_type, amount)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ghost_block.top_level = true
	if not InputMap.has_action("harvest"):
		InputMap.add_action("harvest")
		var click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("harvest", click)

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
