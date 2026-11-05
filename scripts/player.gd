extends CharacterBody3D

signal health_changed(current, maximum)
signal damaged(amount)
signal died
signal notice(text)
signal workbench_used
signal forge_used

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MINE_REACH = 3.5
const PLACE_REACH = 5.0
const MINE_DAMAGE = 1
const TileArt = preload("res://scripts/tile_art.gd")
const AXE_RESOURCES = ["wood", "plank", "cactus", "door", "workbench", "torch"]
const SHOVEL_RESOURCES = ["dirt", "sand", "snow"]
const SHOVEL_BLOCKS = [1, 2, 5, 6]
const MINE_COOLDOWN = 0.35
const CACTUS_PUNCH_DAMAGE = 3
const AIR_ACCEL = 7.0
const AIR_DRAG = 1.5
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
var shown_tool: String = ""
var tool_tween: Tween

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var ghost_block = $GhostBlock
@onready var sword_holder = $Head/Camera3D/SwordHolder
@onready var tool_sprite = $Head/Camera3D/ToolSprite
@onready var torch_holder = $Head/Camera3D/TorchHolder
@onready var torch_light = $Head/Camera3D/TorchHolder/Light
@export var block_scene: PackedScene


func _ready():
	add_to_group("player")
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
		ghost_block.hide()
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if not is_on_floor():
		var flat := Vector2(velocity.x, velocity.z)
		if direction:
			flat = flat.move_toward(Vector2(direction.x, direction.z) * SPEED, AIR_ACCEL * delta)
		else:
			flat = flat.move_toward(Vector2.ZERO, AIR_DRAG * delta)
		velocity.x = flat.x
		velocity.z = flat.y
	elif direction:
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
	_update_tool_sprite()
	var holding_torch = Inventory.held_block_type() == "torch"
	torch_holder.visible = holding_torch
	if holding_torch:
		var t = Time.get_ticks_msec() / 1000.0
		torch_light.light_energy = 1.8 * (1.0 + 0.1 * sin(t * 9.0) + 0.06 * sin(t * 23.0))

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
	var taken: float = maxf(1.0, float(amount) * (1.0 - Inventory.armor_reduction()))
	health = maxf(health - taken, 0.0)
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


func block_height(type):
	return int(Inventory.BLOCK_TYPES[type].get("height", 1))


func probe_empty(cell):
	probe_query.transform = Transform3D(Basis.IDENTITY, cell)
	return get_world_3d().direct_space_state.intersect_shape(probe_query, 1).is_empty()


func has_support(cell):
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain != null and terrain.block_at(floori(cell.x), floori(cell.y) - 1, floori(cell.z)) != 0:
		return true
	return not probe_empty(cell - Vector3(0.0, 1.0, 0.0))


func can_place(type, cell):
	var height = block_height(type)
	for i in height:
		if in_core_zone(cell + Vector3(0.0, i, 0.0)):
			return false
	if Inventory.selected_count() < Inventory.BLOCK_COST:
		return false
	for i in height:
		if not probe_empty(cell + Vector3(0.0, i, 0.0)):
			return false
	if Inventory.BLOCK_TYPES[type].get("needs_support", false) and not has_support(cell):
		return false
	return true


func update_ghost(hit):
	var type = Inventory.held_block_type()
	if type == "" or hit.is_empty():
		ghost_block.hide()
		return
	var cell = cell_center(hit)
	var height = block_height(type)
	var gs: Vector3 = Inventory.BLOCK_TYPES[type].get("ghost", Vector3.ONE)
	ghost_block.scale = Vector3(1.002 * gs.x, 1.002 * height * gs.y, 1.002 * gs.z)
	ghost_block.global_position = cell + Vector3(0.0, (height - 1) * 0.5, 0.0)
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
	target.take_damage(maxi(1, roundi(MINE_DAMAGE * Inventory.tool_power(resource_category(target)))), hit.position)
	_tool_swing()
	if target.is_in_group("cactus"):
		take_damage(CACTUS_PUNCH_DAMAGE)


func holds_repair_item():
	var item = Inventory.selected_item()
	return not item.is_empty() and item["id"] == "stone_brick"


func repair_slot(slot):
	if not holds_repair_item():
		notice.emit("Repair this with Stone Bricks")
		return
	if slot.global_position.distance_to(camera.global_position) > PLACE_REACH:
		return
	Inventory.consume_selected(1)
	var world = get_tree().current_scene
	world.restore_block("stone_brick", slot.global_position)
	slot.remove_from_group("ruin_slot")
	slot.queue_free()


func repair_ruined(block):
	if not holds_repair_item():
		notice.emit("Repair this with Stone Bricks")
		return
	Inventory.consume_selected(1)
	var world = get_tree().current_scene
	var pos = block.global_position
	block.dying = true
	block.remove_from_group("block")
	block.remove_from_group("resource")
	block.queue_free()
	world.restore_block("stone_brick", pos)


func resource_category(target):
	var kind = str(target.resource_type)
	if kind in AXE_RESOURCES:
		return "axe"
	if kind in SHOVEL_RESOURCES:
		return "shovel"
	return "pickaxe"


func _update_tool_sprite():
	var info = Inventory.held_tool()
	var id = ""
	if not info.is_empty():
		id = Inventory.selected_item()["id"]
	if id == shown_tool:
		return
	shown_tool = id
	tool_sprite.visible = id != ""
	if id != "":
		tool_sprite.texture = TileArt.icon(id, "")


func _tool_swing():
	if shown_tool == "":
		return
	if tool_tween:
		tool_tween.kill()
	tool_sprite.rotation = Vector3(0.0, 0.0, -0.3)
	tool_tween = create_tween()
	tool_tween.tween_property(tool_sprite, "rotation", Vector3(-0.9, 0.0, -0.3), 0.08)
	tool_tween.tween_property(tool_sprite, "rotation", Vector3(0.0, 0.0, -0.3), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func mine_terrain(hit):
	if hit.position.distance_to(camera.global_position) > MINE_REACH:
		return
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain == null:
		return
	mine_timer = MINE_COOLDOWN
	var cell = terrain.cell_from_hit(hit.position, hit.normal)
	var category = "shovel" if terrain.block_at(cell.x, cell.y, cell.z) in SHOVEL_BLOCKS else "pickaxe"
	var result = terrain.hit_block(cell, MINE_DAMAGE * Inventory.tool_power(category))
	_tool_swing()
	if result["state"] == "broken":
		get_tree().current_scene.spawn_drop(result["item"], result["amount"], Vector3(cell) + Vector3(0.5, 0.5, 0.5))


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
		if struck.has(target) or not (target.is_in_group("enemy") or target.is_in_group("wild_gloom")):
			continue
		struck[target] = true
		target.take_damage(weapon["damage"], global_position)


func try_place(hit):
	if not hit.is_empty() and hit.collider.is_in_group("workbench"):
		workbench_used.emit()
		return
	if not hit.is_empty() and hit.collider.is_in_group("ruin_slot"):
		repair_slot(hit.collider)
		return
	if not hit.is_empty() and hit.collider.is_in_group("block") and hit.collider.block_type == "ruined_brick":
		repair_ruined(hit.collider)
		return
	if not hit.is_empty() and hit.collider.is_in_group("forge"):
		forge_used.emit(hit.collider)
		return
	if not hit.is_empty() and hit.collider.is_in_group("door"):
		hit.collider.toggle()
		return
	var type = Inventory.held_block_type()
	if type == "" or hit.is_empty():
		return
	var cell = cell_center(hit)
	if in_core_zone(cell) or in_core_zone(cell + Vector3(0.0, block_height(type) - 1, 0.0)):
		notice.emit("You can't build this close to the Core")
		return
	if not can_place(type, cell):
		return
	Inventory.consume_selected(Inventory.BLOCK_COST)
	var scene: PackedScene = block_scene
	var scene_path: String = Inventory.BLOCK_TYPES[type].get("scene", "")
	if scene_path != "":
		scene = load(scene_path)
	var block = scene.instantiate()
	block.block_type = type
	get_tree().current_scene.add_child(block)
	block.global_position = cell
	if block_height(type) > 1:
		block.rotation.y = snappedf(rotation.y, PI * 0.5)
