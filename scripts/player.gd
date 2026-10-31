extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002
const MINE_REACH = 3.5
const PLACE_REACH = 5.0
const MINE_DAMAGE = 1
const MINE_COOLDOWN = 0.35

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var mine_timer = 0.0
var ghost_valid_mat
var ghost_blocked_mat
var probe_query

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var ghost_block = $GhostBlock
@export var block_scene: PackedScene


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ghost_block.top_level = true
	ghost_block.scale = Vector3.ONE * 1.002
	ghost_valid_mat = make_ghost_material(Color(0.43, 1.0, 1.0, 0.35))
	ghost_blocked_mat = make_ghost_material(Color(1.0, 0.3, 0.3, 0.35))

	var probe_shape = BoxShape3D.new()
	probe_shape.size = Vector3(0.9, 0.9, 0.9)
	probe_query = PhysicsShapeQueryParameters3D.new()
	probe_query.shape = probe_shape

	add_mouse_action("mine", MOUSE_BUTTON_LEFT)
	add_mouse_action("place", MOUSE_BUTTON_RIGHT)


func add_mouse_action(action, button):
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var click = InputEventMouseButton.new()
	click.button_index = button
	InputMap.action_add_event(action, click)


func make_ghost_material(color):
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	if event is InputEventKey and event.pressed and not event.echo:
		var slot = event.physical_keycode - KEY_1
		if slot >= 0 and slot < Inventory.SLOT_COUNT:
			Inventory.select_slot(slot)

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

	mine_timer = maxf(mine_timer - delta, 0.0)
	var hit = look_hit()
	update_ghost(hit)

	if Input.is_action_pressed("mine") and mine_timer <= 0.0:
		try_mine(hit)
	if Input.is_action_just_pressed("place"):
		try_place(hit)


func look_hit():
	var from = camera.global_position
	var to = from - camera.global_transform.basis.z * PLACE_REACH
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func cell_center(hit):
	var p = hit.position + hit.normal * 0.5
	return Vector3(floor(p.x) + 0.5, floor(p.y) + 0.5, floor(p.z) + 0.5)


func can_place(type, cell):
	var info = Inventory.BLOCK_TYPES[type]
	if Inventory.get_count(info["resource"]) < Inventory.BLOCK_COST:
		return false
	probe_query.transform = Transform3D(Basis.IDENTITY, cell)
	return get_world_3d().direct_space_state.intersect_shape(probe_query, 1).is_empty()


func update_ghost(hit):
	var type = Inventory.held_block_type()
	if type == "" or hit.is_empty():
		ghost_block.hide()
		return
	var cell = cell_center(hit)
	ghost_block.global_position = cell
	if can_place(type, cell):
		ghost_block.material_override = ghost_valid_mat
	else:
		ghost_block.material_override = ghost_blocked_mat
	ghost_block.show()


func try_mine(hit):
	if hit.is_empty():
		return
	var target = hit.collider
	if not target.is_in_group("resource"):
		return
	if hit.position.distance_to(camera.global_position) > MINE_REACH:
		return
	mine_timer = MINE_COOLDOWN
	if not target.harvested.is_connected(_on_harvested):
		target.harvested.connect(_on_harvested)
	target.take_damage(MINE_DAMAGE, hit.position)


func try_place(hit):
	var type = Inventory.held_block_type()
	if type == "" or hit.is_empty():
		return
	var cell = cell_center(hit)
	if not can_place(type, cell):
		return
	Inventory.spend(Inventory.BLOCK_TYPES[type]["resource"], Inventory.BLOCK_COST)
	var block = block_scene.instantiate()
	block.block_type = type
	get_tree().current_scene.add_child(block)
	block.global_position = cell


func _on_harvested(resource_type, amount):
	Inventory.add(resource_type, amount)
