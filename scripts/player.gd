extends CharacterBody3D

signal health_changed(current, maximum)
signal damaged(amount)
signal died
signal notice(text)

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MINE_REACH = 3.5
const PLACE_REACH = 5.0
const MINE_DAMAGE = 1
const MINE_COOLDOWN = 0.35
const FALL_SAFE_SPEED = 13.0
const FALL_DAMAGE = 5.0
const REGEN_DELAY = 6.0
const REGEN_RATE = 3.0

@export var max_health: int = 100

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var mine_timer = 0.0
var attack_timer = 0.0
var frozen = false
var ghost_valid_mat
var ghost_blocked_mat
var probe_query
var health: float = 100.0
var dead: bool = false
var since_damage: float = 0.0
var was_on_floor: bool = true
var shown_health: int = 100

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var ghost_block = $GhostBlock
@onready var sword_holder = $Head/Camera3D/SwordHolder
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

	health = max_health
	shown_health = max_health
	Game.settings_changed.connect(_apply_settings)
	_apply_settings()


func _apply_settings():
	camera.fov = Game.settings["fov"]


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
	if dead or frozen:
		return

	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var sensitivity = Game.settings["mouse_sensitivity"]
		rotate_y(-event.relative.x * sensitivity)
		head.rotate_x(-event.relative.y * sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	if event is InputEventKey and event.pressed and not event.echo:
		var slot = event.physical_keycode - KEY_1
		if slot >= 0 and slot < Inventory.SLOT_COUNT:
			Inventory.select_slot(slot)


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if dead or frozen:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

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

	var impact = velocity.y
	move_and_slide()
	if is_on_floor() and not was_on_floor and impact < -FALL_SAFE_SPEED:
		take_damage(roundi((-impact - FALL_SAFE_SPEED) * FALL_DAMAGE))
	was_on_floor = is_on_floor()

	since_damage += delta
	if health < max_health and since_damage > REGEN_DELAY:
		health = minf(health + REGEN_RATE * delta, float(max_health))
		_emit_health()

	mine_timer = maxf(mine_timer - delta, 0.0)
	attack_timer = maxf(attack_timer - delta, 0.0)
	var hit = look_hit()
	update_ghost(hit)
	sword_holder.visible = not Inventory.held_weapon().is_empty()

	if Input.is_action_pressed("mine") and attack_timer <= 0.0:
		var weapon: Dictionary = Inventory.held_weapon()
		if not weapon.is_empty():
			swing(weapon)

	if Input.is_action_pressed("mine") and mine_timer <= 0.0:
		try_mine(hit)
	if Input.is_action_just_pressed("place"):
		try_place(hit)


func take_damage(amount, _hit_position = Vector3.INF):
	if dead or amount <= 0:
		return
	health = maxf(health - amount, 0.0)
	since_damage = 0.0
	damaged.emit(amount)
	_emit_health(true)
	if health <= 0.0:
		_die()


func heal(amount):
	if dead:
		return
	health = minf(health + amount, float(max_health))
	_emit_health()


func _emit_health(force = false):
	var value = ceili(health)
	if force or value != shown_health:
		shown_health = value
		health_changed.emit(value, max_health)


func _die():
	dead = true
	ghost_block.hide()
	died.emit()


func respawn(pos):
	global_position = pos
	velocity = Vector3.ZERO
	health = max_health
	dead = false
	since_damage = 0.0
	was_on_floor = false
	_emit_health(true)


func export_state():
	return {
		"pos": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y,
		"pitch": head.rotation.x,
		"health": health,
	}


func import_state(d):
	var p = d["pos"]
	global_position = Vector3(p[0], p[1], p[2])
	rotation.y = float(d["yaw"])
	head.rotation.x = float(d["pitch"])
	health = clampf(float(d["health"]), 1.0, float(max_health))
	velocity = Vector3.ZERO
	was_on_floor = false
	since_damage = 0.0
	_emit_health(true)


func look_hit():
	var from = camera.global_position
	var to = from - camera.global_transform.basis.z * PLACE_REACH
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func cell_center(hit):
	var p = hit.position + hit.normal * 0.5
	return Vector3(floor(p.x) + 0.5, floor(p.y) + 0.5, floor(p.z) + 0.5)


func in_core_zone(cell):
	var core = get_tree().get_first_node_in_group("Core")
	return core != null and core.blocks_building(cell)


func can_place(type, cell):
	if in_core_zone(cell):
		return false
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
	if target.is_in_group("terrain_body"):
		mine_terrain(hit)
		return
	if not target.is_in_group("resource"):
		return
	if hit.position.distance_to(camera.global_position) > MINE_REACH:
		return
	mine_timer = MINE_COOLDOWN
	if not target.harvested.is_connected(_on_harvested):
		target.harvested.connect(_on_harvested)
	target.take_damage(MINE_DAMAGE, hit.position)


func mine_terrain(hit):
	if hit.position.distance_to(camera.global_position) > MINE_REACH:
		return
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain == null:
		return
	mine_timer = MINE_COOLDOWN
	var cell = terrain.cell_from_hit(hit.position, hit.normal)
	var result = terrain.hit_block(cell, MINE_DAMAGE)
	if result["state"] == "broken":
		Inventory.add(result["item"], result["amount"])


func swing(weapon):
	attack_timer = weapon["cooldown"]

	var holder_tween = create_tween()
	sword_holder.rotation = Vector3(0.0, 0.0, 0.0)
	holder_tween.tween_property(sword_holder, "rotation", Vector3(-1.2, 0.0, -0.5), 0.09)
	holder_tween.tween_property(sword_holder, "rotation", Vector3.ZERO, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var shape = SphereShape3D.new()
	shape.radius = 1.1
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 2
	query.transform = Transform3D(Basis.IDENTITY, camera.global_position - camera.global_transform.basis.z * weapon["reach"] * 0.6)
	var found = get_world_3d().direct_space_state.intersect_shape(query, 8)
	var struck = {}
	for entry in found:
		var target = entry["collider"]
		if struck.has(target) or not target.is_in_group("enemy"):
			continue
		struck[target] = true
		target.take_damage(weapon["damage"], global_position)


func try_place(hit):
	var type = Inventory.held_block_type()
	if type == "" or hit.is_empty():
		return
	var cell = cell_center(hit)
	if in_core_zone(cell):
		notice.emit("You can't build this close to the Core")
		return
	if not can_place(type, cell):
		return
	Inventory.spend(Inventory.BLOCK_TYPES[type]["resource"], Inventory.BLOCK_COST)
	var block = block_scene.instantiate()
	block.block_type = type
	get_tree().current_scene.add_child(block)
	block.global_position = cell


func _on_harvested(resource_type, amount):
	Inventory.add(resource_type, amount)
