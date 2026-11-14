extends CharacterBody3D

const BannerRangeScript = preload("res://scripts/allies/banner_range.gd")

signal health_changed(current, maximum)
signal damaged(amount)
signal died
signal notice(text)
signal workbench_used
signal forge_used
signal troop_used
signal core_used
signal chest_used

const OutlineMesh = preload("res://scripts/outline_mesh.gd")
const SPEED = 5.0
const CROUCH_SPEED = 0.45
const STAND_EYE = 0.6
const CROUCH_EYE = 0.15
const STAND_HEIGHT = 1.8
const CROUCH_HEIGHT = 1.3
const FEET_OFFSET = 0.85
const LEDGE_LOOK = 0.15
const LEDGE_DROP = 0.55
const CLIMB_SPEED = 3.0
const LADDER_TURN = 0.35
const GRAVITY_SCALE = 1.25
const JUMP_VELOCITY = 5.15
const MINE_REACH = 3.5
const PLACE_REACH = 5.0
const MINE_DAMAGE = 1
const TileArt = preload("res://scripts/tile_art.gd")
const ArrowScript = preload("res://scripts/arrow.gd")
const Sfx = preload("res://scripts/core/sfx.gd")
const DRAW_TIME = 0.9
const MIN_DRAW = 0.25
const ARROW_MIN_SPEED = 0.45
const ARROW_BASE_DAMAGE = 2
const AXE_RESOURCES = ["wood", "plank", "cactus", "door", "workbench", "torch", "scaffold"]
const SHOVEL_RESOURCES = ["dirt", "sand", "snow"]
const SHOVEL_BLOCKS = [1, 2, 5, 6]
const MINE_COOLDOWN = 0.35
const PLANT_COOLDOWN = 0.18
const CACTUS_PUNCH_DAMAGE = 3
const AIR_ACCEL = 15.0
const AIR_DRAG = 2.5
const AIR_TURN_BOOST = 1.5
const FALL_TRIGGER_DROP = 2.9
const LAND_STUN_DROP = 3.0
const LAND_STUN_MIN = 0.18
const LAND_STUN_MAX = 0.8
const LAND_SINK_MAX = 0.32
const FALL_FREE_DROP = 2.5
const FALL_DAMAGE = 12.0
const REGEN_DELAY = 6.0
const REGEN_RATE = 3.0

@export var max_health: int = 100

var gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity")) * GRAVITY_SCALE
var mine_timer = 0.0
var attack_timer = 0.0
var frozen = false
var slow: float = 1.0
var crouching: bool = false
var crouch_t: float = 0.0
var bauble_light: OmniLight3D
var place_cell := Vector3.INF
var banner_range
var ghost_valid_mat
var ghost_blocked_mat
var ghost_warn_mat
var aim_normal: Vector3 = Vector3.UP
const TorchScript = preload("res://scripts/blocks/torch.gd")
const SWEEP_ARC = 1.3
const SWEEP_ARC_COS = 0.267
var ladder_query: PhysicsShapeQueryParameters3D
var probe_query
var health: float = 100.0
var dead: bool = false
var since_damage: float = 0.0
var was_on_floor: bool = true
var stun_left: float = 0.0
var stun_total: float = 0.0
var stun_depth: float = 0.0
var shown_health: int = 100
var draw: float = 0.0
var bow_ready: bool = false

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var ghost_block = $GhostBlock
@onready var held = $Head/Camera3D/HeldItem
@export var block_scene: PackedScene


func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ghost_block.top_level = true
	ghost_block.layers = 2
	ghost_block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ladder_shape := BoxShape3D.new()
	ladder_shape.size = Vector3(0.9, 1.2, 0.9)
	ladder_query = PhysicsShapeQueryParameters3D.new()
	ladder_query.shape = ladder_shape
	ladder_query.collision_mask = 16
	ghost_block.mesh = OutlineMesh.build(0.03)
	ghost_block.scale = Vector3.ONE * 1.002
	ghost_valid_mat = make_ghost_material(Color(0.43, 1.0, 1.0, 1.0))
	ghost_blocked_mat = make_ghost_material(Color(1.0, 0.3, 0.3, 1.0))
	ghost_warn_mat = make_ghost_material(Color(1.0, 0.85, 0.3, 1.0))

	var probe_shape = BoxShape3D.new()
	probe_shape.size = Vector3(0.9, 0.9, 0.9)
	probe_query = PhysicsShapeQueryParameters3D.new()
	probe_query.shape = probe_shape

	if not InputMap.has_action("crouch"):
		InputMap.add_action("crouch")
		var shift_key = InputEventKey.new()
		shift_key.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("crouch", shift_key)
	add_mouse_action("mine", MOUSE_BUTTON_LEFT)
	add_mouse_action("place", MOUSE_BUTTON_RIGHT)

	health = max_health
	shown_health = max_health
	Game.settings_changed.connect(_apply_settings)
	_apply_settings()
	bauble_light = OmniLight3D.new()
	bauble_light.light_color = Color(1.0, 0.72, 0.4)
	bauble_light.light_energy = 3.2
	bauble_light.omni_range = 14.0
	bauble_light.omni_attenuation = 1.4
	bauble_light.shadow_enabled = false
	bauble_light.visible = false
	head.add_child(bauble_light)
	Inventory.changed.connect(_update_bauble)
	_update_bauble()


func _update_crouch(delta: float, on_ladder: bool) -> void:
	var want = Input.is_action_pressed("crouch") and not dead and not frozen and not on_ladder
	if crouching and not want and _ceiling_blocked():
		want = true
	if want != crouching:
		crouching = want
		var capsule: CapsuleShape3D = $CollisionShape3D.shape
		var h = CROUCH_HEIGHT if crouching else STAND_HEIGHT
		capsule.height = h
		$CollisionShape3D.position.y = -FEET_OFFSET + h * 0.5
	crouch_t = move_toward(crouch_t, 1.0 if crouching else 0.0, delta * 7.0)
	var eased = crouch_t * crouch_t * (3.0 - 2.0 * crouch_t)
	head.position.y = lerpf(STAND_EYE, CROUCH_EYE, eased) - _land_sink()


func _land_sink() -> float:
	if stun_left <= 0.0 or stun_total <= 0.0:
		return 0.0
	var t := 1.0 - stun_left / stun_total
	var curve := smoothstep(0.0, 0.18, t) if t < 0.18 else 1.0 - smoothstep(0.35, 1.0, t)
	return stun_depth * curve


func _begin_stun(drop: float) -> void:
	var k := clampf((drop - LAND_STUN_DROP) / 5.0, 0.0, 1.0)
	stun_total = lerpf(LAND_STUN_MIN, LAND_STUN_MAX, k)
	stun_left = stun_total
	stun_depth = lerpf(0.08, LAND_SINK_MAX, k)


func _ceiling_blocked() -> bool:
	var from = global_position + Vector3(0.0, 0.4, 0.0)
	var query = PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, 0.7, 0.0), 1)
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _ground_at(point: Vector3) -> bool:
	var from = point + Vector3(0.0, -FEET_OFFSET + 0.15, 0.0)
	var query = PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -(0.15 + LEDGE_DROP), 0.0), 1)
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _ledge_guard(delta: float) -> void:
	var step_x = Vector3(signf(velocity.x), 0.0, 0.0) * (absf(velocity.x) * delta + LEDGE_LOOK)
	var step_z = Vector3(0.0, 0.0, signf(velocity.z)) * (absf(velocity.z) * delta + LEDGE_LOOK)
	if absf(velocity.x) > 0.001 and not _ground_at(global_position + step_x):
		velocity.x = 0.0
	if absf(velocity.z) > 0.001 and not _ground_at(global_position + step_z):
		velocity.z = 0.0
	if absf(velocity.x) > 0.001 and absf(velocity.z) > 0.001 and not _ground_at(global_position + step_x + step_z):
		velocity.x = 0.0
		velocity.z = 0.0


func _update_bauble() -> void:
	var item: Dictionary = Inventory.equipment.get("bauble", {})
	bauble_light.visible = not item.is_empty() and item["id"] == "lantern"


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
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
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


func touching_ladder():
	ladder_query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, 0.05, 0.0))
	for r in get_world_3d().direct_space_state.intersect_shape(ladder_query, 4):
		if r["collider"].is_in_group("ladder"):
			return r["collider"]
	return null


func climb_sign(ladder):
	var outward = ladder.global_transform.basis.z
	var forward = -global_transform.basis.z
	if forward.dot(outward) > LADDER_TURN:
		return -1.0
	return 1.0


func _physics_process(delta):
	var ladder = null
	if not dead and not frozen:
		ladder = touching_ladder()
	var on_ladder = ladder != null
	_update_crouch(delta, on_ladder)
	var speed_now = SPEED * slow * (CROUCH_SPEED if crouching else 1.0)
	if not is_on_floor() and not on_ladder:
		velocity.y -= gravity * delta

	if dead or frozen:
		ghost_block.hide()
		velocity.x = 0.0
		velocity.z = 0.0
		held.set_motion(0.0)
		draw = 0.0
		held.set_draw(0.0)
		move_and_slide()
		return

	stun_left = maxf(stun_left - delta, 0.0)
	var stunned := stun_left > 0.0
	var jumped = false
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not stunned:
		velocity.y = JUMP_VELOCITY
		jumped = true

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if stunned:
		input_dir = Vector2.ZERO
	if on_ladder and not jumped:
		velocity.y = -input_dir.y * CLIMB_SPEED * slow * climb_sign(ladder)
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if not is_on_floor():
		var flat := Vector2(velocity.x, velocity.z)
		if direction:
			var wish := Vector2(direction.x, direction.z)
			var accel := AIR_ACCEL
			if flat.dot(wish) < 0.0:
				accel *= AIR_TURN_BOOST
			flat = flat.move_toward(wish * speed_now, accel * delta)
		else:
			flat = flat.move_toward(Vector2.ZERO, AIR_DRAG * delta)
		velocity.x = flat.x
		velocity.z = flat.y
	elif direction:
		velocity.x = direction.x * speed_now
		velocity.z = direction.z * speed_now
	else:
		velocity.x = move_toward(velocity.x, 0, speed_now)
		velocity.z = move_toward(velocity.z, 0, speed_now)

	if crouching and is_on_floor() and not on_ladder and not jumped:
		_ledge_guard(delta)

	var impact = velocity.y
	move_and_slide()
	if is_on_floor() and not was_on_floor and impact < 0.0:
		var drop = impact * impact / (2.0 * gravity)
		if drop >= LAND_STUN_DROP:
			_begin_stun(drop)
		if drop >= FALL_TRIGGER_DROP:
			take_damage(roundi((drop - FALL_FREE_DROP) * FALL_DAMAGE))
	was_on_floor = is_on_floor()

	since_damage += delta
	if health < max_health and since_damage > REGEN_DELAY:
		health = minf(health + REGEN_RATE * delta, float(max_health))
		_emit_health()

	mine_timer = maxf(mine_timer - delta, 0.0)
	attack_timer = maxf(attack_timer - delta, 0.0)
	var hit = look_hit()
	update_ghost(hit)
	_update_banner_range()
	held.set_item(held_visual_id())
	held.set_motion(Vector2(velocity.x, velocity.z).length() / SPEED if is_on_floor() else 0.0)

	var bow: Dictionary = Inventory.held_bow()
	_bow_update(delta, bow)

	if Input.is_action_pressed("mine") and attack_timer <= 0.0:
		var weapon: Dictionary = Inventory.held_weapon()
		if not weapon.is_empty():
			swing(weapon)

	if Input.is_action_pressed("mine") and mine_timer <= 0.0 and bow.is_empty():
		try_mine(hit)
	if Input.is_action_just_pressed("place"):
		try_place(hit)


func has_arrows():
	return Game.gamemode == "creative" or Inventory.get_count("arrow") > 0


func _bow_update(delta, bow):
	if bow.is_empty():
		draw = 0.0
		bow_ready = false
		held.set_draw(0.0)
		return
	if Input.is_action_just_pressed("mine"):
		bow_ready = has_arrows()
		if not bow_ready:
			notice.emit("No Arrows")
	if Input.is_action_pressed("mine") and bow_ready:
		draw = minf(draw + delta / DRAW_TIME, 1.0)
	else:
		if draw >= MIN_DRAW and bow_ready:
			fire_bow(bow, draw)
		draw = 0.0
		bow_ready = false
	held.set_draw(draw)


func fire_bow(bow, charge):
	Sfx.play(self, "arrow_release", global_position, -2.0)
	if Game.gamemode != "creative" and not Inventory.take_item("arrow", 1):
		return
	var dir = -camera.global_transform.basis.z
	var damage = maxi(1, roundi(float(ARROW_BASE_DAMAGE + int(bow.get("damage", 3))) * charge))
	var arrow = ArrowScript.fetch()
	get_tree().current_scene.add_child(arrow)
	arrow.ignore = [get_rid()]
	arrow.pickable = true
	arrow.launch(camera.global_position + dir * 0.7, dir, damage, ArrowScript.SPEED * (ARROW_MIN_SPEED + (1.0 - ARROW_MIN_SPEED) * charge))


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


func place_yaw():
	return snappedf(rotation.y, PI * 0.5)


func type_offsets(type):
	var out: Array = []
	var height = block_height(type)
	for i in height:
		out.append(Vector3(0.0, i, 0.0))
	if Inventory.BLOCK_TYPES[type].get("wide", false):
		var yaw = place_yaw()
		var side = Vector3(roundf(cos(yaw)), 0.0, roundf(-sin(yaw)))
		for i in height:
			out.append(side + Vector3(0.0, i, 0.0))
	return out


func probe_empty(cell):
	probe_query.transform = Transform3D(Basis.IDENTITY, cell)
	return get_world_3d().direct_space_state.intersect_shape(probe_query, 1).is_empty()


func has_support(cell):
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain != null and terrain.block_at(floori(cell.x), floori(cell.y) - 1, floori(cell.z)) != 0:
		return true
	return not probe_empty(cell - Vector3(0.0, 1.0, 0.0))


func full_block_below(cell) -> bool:
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain != null and terrain.block_at(floori(cell.x), floori(cell.y) - 1, floori(cell.z)) != 0:
		return true
	probe_query.transform = Transform3D(Basis.IDENTITY, cell - Vector3(0.0, 1.0, 0.0))
	for r in get_world_3d().direct_space_state.intersect_shape(probe_query, 8):
		var body = r["collider"]
		if body.is_in_group("block") and not body.dying and not Inventory.BLOCK_TYPES[body.block_type].has("scene"):
			return true
	return false


func in_territory(cell):
	var territory = get_tree().get_first_node_in_group("territory")
	return territory == null or territory.contains(cell)


func can_place(type, cell):
	if Inventory.BLOCK_TYPES[type].get("territory", false):
		for o in type_offsets(type):
			if not in_territory(cell + o):
				return false
	if type == "ladder" and absf(aim_normal.y) > 0.5:
		return false
	var offsets = type_offsets(type)
	for o in offsets:
		if in_core_zone(cell + o):
			return false
	if Inventory.selected_count() < Inventory.BLOCK_COST:
		return false
	for o in offsets:
		if not probe_empty(cell + o):
			return false
	if Inventory.BLOCK_TYPES[type].get("needs_support", false):
		if wall_aim(type):
			if not wall_support(cell):
				return false
		elif not has_support(cell):
			return false
	if type == "barricade" and not full_block_below(cell):
		return false
	if stability_of(type, cell) < 0:
		return false
	return true


func wall_aim(type) -> bool:
	return type == "torch" and absf(aim_normal.y) < 0.5


func wall_normal_of() -> Vector3:
	return Vector3(roundf(aim_normal.x), 0.0, roundf(aim_normal.z))


func wall_support(cell) -> bool:
	var w: Vector3 = cell - wall_normal_of()
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain != null and terrain.block_at(floori(w.x), floori(w.y), floori(w.z)) != 0:
		return true
	probe_query.transform = Transform3D(Basis.IDENTITY, w)
	for r in get_world_3d().direct_space_state.intersect_shape(probe_query, 8):
		var body = r["collider"]
		if body.is_in_group("block") and body.block_type != "torch":
			return true
	return false


func stability_of(type, cell):
	var stability = get_tree().get_first_node_in_group("stability")
	if stability == null:
		return 0
	return stability.evaluate(type, Vector3i(floori(cell.x), floori(cell.y), floori(cell.z)))


func _update_banner_range() -> void:
	if banner_range == null:
		banner_range = BannerRangeScript.new()
		get_tree().current_scene.add_child(banner_range)
	var held_type: String = Inventory.held_block_type()
	if held_type.begins_with("banner_") and ghost_block.visible and place_cell.is_finite():
		banner_range.show_for(held_type, place_cell)
		return
	var feet: Vector3 = global_position + Vector3(0.0, 0.5, 0.0)
	for b in get_tree().get_nodes_in_group("banner"):
		if is_instance_valid(b) and not b.dying and b.covers(feet):
			banner_range.show_for(b.block_type, b.global_position)
			return
	banner_range.clear()


func update_ghost(hit):
	var type = Inventory.held_block_type()
	if type == "" or hit.is_empty():
		ghost_block.hide()
		return
	aim_normal = hit.normal
	var cell = cell_center(hit)
	place_cell = cell
	var height = block_height(type)
	var gs: Vector3 = Inventory.BLOCK_TYPES[type].get("ghost", Vector3.ONE)
	var span = Vector3.ZERO
	if Inventory.BLOCK_TYPES[type].get("wide", false):
		var yaw = place_yaw()
		span = Vector3(roundf(cos(yaw)), 0.0, roundf(-sin(yaw)))
	ghost_block.global_position = cell + span * 0.5 + Vector3(0.0, (height - 1) * 0.5 - (1.0 - gs.y) * 0.5, 0.0)
	if wall_aim(type):
		var wn = wall_normal_of()
		ghost_block.global_position = cell - wn * TorchScript.WALL_OFFSET + Vector3(0.0, -(1.0 - gs.y) * 0.5, 0.0)
		ghost_block.basis = TorchScript.mount_basis(wn)
	else:
		ghost_block.basis = Basis.IDENTITY
	ghost_block.scale = Vector3(1.002 * gs.x * (1.0 + absf(span.x)), 1.002 * height * gs.y, 1.002 * gs.z * (1.0 + absf(span.z)))
	if can_place(type, cell):
		var stability = get_tree().get_first_node_in_group("stability")
		var reach = 0 if stability == null else stability.reach_for_type(type)
		if reach > 0 and stability_of(type, cell) == reach:
			ghost_block.material_override = ghost_warn_mat
		else:
			ghost_block.material_override = ghost_valid_mat
	else:
		ghost_block.material_override = ghost_blocked_mat
	ghost_block.show()


func try_break_plant(hit):
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain == null:
		return false
	var limit = INF if hit.is_empty() else hit.position.distance_to(camera.global_position)
	var plant = terrain.pick_plant(camera.global_position, -camera.global_transform.basis.z, MINE_REACH, limit)
	if plant.is_empty():
		return false
	mine_timer = PLANT_COOLDOWN
	var drop: Dictionary = terrain.break_plant(plant)
	if not drop.is_empty():
		var leftover: int = Inventory.add_item(drop["item"], int(drop["amount"]))
		if leftover > 0:
			get_tree().current_scene.spawn_drop(drop["item"], leftover, plant["center"])
	_tool_swing()
	return true


func try_mine(hit):
	if try_break_plant(hit):
		return
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


func held_visual_id():
	var item = Inventory.selected_item()
	if item.is_empty():
		return ""
	var kind = str(Inventory.ITEMS.get(item["id"], {}).get("kind", ""))
	if kind == "tool" or kind == "weapon" or kind == "bow" or item["id"] == "torch":
		return item["id"]
	return ""


func _tool_swing():
	held.play_swing()


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


func sweep(weapon):
	attack_timer = weapon["cooldown"]
	Sfx.play(self, "sword_swing", global_position, -2.0)
	held.play_swing()
	var forward = -camera.global_transform.basis.z
	var flat = Vector3(forward.x, 0.0, forward.z)
	if flat.length() < 0.01:
		flat = Vector3(0.0, 0.0, -1.0)
	flat = flat.normalized()
	var radius = float(weapon["reach"])
	var shape = SphereShape3D.new()
	shape.radius = radius
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 2
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, 0.4, 0.0))
	var struck = {}
	for entry in get_world_3d().direct_space_state.intersect_shape(query, 24):
		var target = entry["collider"]
		if struck.has(target) or not (target.is_in_group("enemy") or target.is_in_group("wild_gloom") or target.is_in_group("gloom_bird") or target.is_in_group("boss")):
			continue
		var off = target.global_position - global_position
		off.y = 0.0
		if off.length() > 1.0 and off.normalized().dot(flat) < SWEEP_ARC_COS:
			continue
		struck[target] = true
		target.take_damage(weapon["damage"], global_position)
	var terrain = get_tree().get_first_node_in_group("terrain")
	if terrain == null:
		return
	var result: Dictionary = terrain.sweep_plants(camera.global_position, forward, radius, SWEEP_ARC)
	var fiber = int(result["fiber"])
	if fiber > 0:
		var leftover: int = Inventory.add_item("fiber", fiber)
		if leftover > 0:
			get_tree().current_scene.spawn_drop("fiber", leftover, global_position + flat)


func swing(weapon):
	if weapon.get("sweep", false):
		sweep(weapon)
		return
	if weapon.get("thrust", false):
		_thrust(weapon)
		return
	attack_timer = weapon["cooldown"]
	Sfx.play(self, "sword_swing", global_position, -2.0)

	held.play_swing()

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
		if struck.has(target) or not (target.is_in_group("enemy") or target.is_in_group("wild_gloom") or target.is_in_group("gloom_bird") or target.is_in_group("boss")):
			continue
		struck[target] = true
		target.take_damage(weapon["damage"], global_position)


func _thrust(weapon) -> void:
	attack_timer = weapon["cooldown"]
	Sfx.play(self, "sword_swing", global_position, -2.0)
	held.play_swing()
	var reach: float = weapon["reach"]
	var forward: Vector3 = -camera.global_transform.basis.z
	var shape := CapsuleShape3D.new()
	shape.radius = 0.55
	shape.height = reach
	var basis := Basis.looking_at(forward, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 2
	query.transform = Transform3D(basis, camera.global_position + forward * reach * 0.5)
	var found = get_world_3d().direct_space_state.intersect_shape(query, 8)
	var struck = {}
	for entry in found:
		var target = entry["collider"]
		if struck.has(target) or not (target.is_in_group("enemy") or target.is_in_group("wild_gloom") or target.is_in_group("gloom_bird") or target.is_in_group("boss")):
			continue
		struck[target] = true
		target.set_meta("knock_scale", float(weapon.get("knockback", 1.0)))
		target.take_damage(weapon["damage"], global_position)
		if is_instance_valid(target) and target.has_meta("knock_scale"):
			target.remove_meta("knock_scale")


func try_place(hit):
	if not hit.is_empty() and hit.collider.is_in_group("Core"):
		core_used.emit(hit.collider)
		return
	if not hit.is_empty() and hit.collider.is_in_group("chest"):
		chest_used.emit(hit.collider)
		return
	if not hit.is_empty() and hit.collider.is_in_group("workbench"):
		workbench_used.emit()
		return
	if not hit.is_empty() and hit.collider.is_in_group("block") and hit.collider.block_type == "ruined_brick":
		repair_ruined(hit.collider)
		return
	if not hit.is_empty() and hit.collider.is_in_group("troop"):
		troop_used.emit(hit.collider)
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
	aim_normal = hit.normal
	for o in type_offsets(type):
		if in_core_zone(cell + o):
			notice.emit("You can't build this close to the Core")
			return
	if Inventory.BLOCK_TYPES[type].get("territory", false) and not in_territory(cell):
		notice.emit("Outside Territory")
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
	if wall_aim(type):
		block.wall_normal = wall_normal_of()
	get_tree().current_scene.add_child(block)
	block.global_position = cell
	Sfx.play(self, "block_place", cell, -2.0)
	if not wall_aim(type):
		var terrain_node = get_tree().get_first_node_in_group("terrain")
		if terrain_node != null:
			terrain_node.cover_ground(Vector3i(floori(cell.x), floori(cell.y), floori(cell.z)))
	if block_height(type) > 1:
		block.rotation.y = place_yaw()
	if type == "ladder":
		block.rotation.y = atan2(hit.normal.x, hit.normal.z)
