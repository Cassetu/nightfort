extends CharacterBody3D

const PathScript = preload("res://scripts/troop_path.gd")
const ArrowScript = preload("res://scripts/arrow.gd")

const NAMES := ["Garrick", "Mina", "Torvald", "Edda", "Bram", "Isolde", "Corwin", "Hesper", "Dunstan", "Wren", "Alaric", "Odette", "Rurik", "Nessa", "Osric", "Tamsin", "Leofric", "Maren", "Cael", "Brigid", "Ansel", "Verity", "Hollis", "Sabine"]
const EQUIP_SLOTS := ["weapon", "head", "chest", "legs", "feet"]
const SPEED := 3.2
const CLIMB_SPEED := 2.6
const JUMP_VELOCITY := 5.2
const BASE_RANGE := 20.0
const WILD_RANGE := 13.0
const BASE_DAMAGE := 2
const BASE_COOLDOWN := 1.5
const EYE_HEIGHT := 1.5
const THINK_INTERVAL := 0.5
const STUCK_TIME := 2.5
const MAX_REPATH := 3
const MOOD_RATE := 0.05
const REST_RADIUS := 3.6
const MAX_HEALTH := 40.0
const REGEN_DELAY := 6.0
const REGEN_RATE := 1.0

var troop_id: int = 0
var display_name: String = ""
var mood: float = 0.65
var equipment: Dictionary = {}
var banner_issued: bool = false
var rest_index: int = 0

var world
var terrain
var core
var sun
var pathfinder
var path: Array = []
var path_i: int = 0
var path_goal := Vector3i.ZERO
var path_has_goal: bool = false
var ladder_cells: Dictionary = {}
var think_timer: float = 0.0
var stuck_timer: float = 0.0
var repaths: int = 0
var fire_timer: float = 1.0
var threat: bool = false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var model: Node3D
var bow_node: Node3D
var recoil: float = 0.0
var health: float = MAX_HEALTH
var since_hit: float = 99.0


func _ready() -> void:
	add_to_group("troop")
	collision_layer = 4
	collision_mask = 1
	for slot_name in EQUIP_SLOTS:
		equipment[slot_name] = {}
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.85, 0.0)
	add_child(col)
	_build_model()
	sun = get_node_or_null("../Sun")


func setup(w, t, c, data: Dictionary) -> void:
	world = w
	terrain = t
	core = c
	troop_id = int(data.get("id", 1))
	display_name = str(data.get("name", NAMES[randi() % NAMES.size()]))
	mood = clampf(float(data.get("mood", 0.65)), 0.0, 1.0)
	banner_issued = bool(data.get("banner_issued", false))
	rest_index = int(data.get("rest_index", 0))
	var saved: Dictionary = data.get("equipment", {})
	for slot_name in EQUIP_SLOTS:
		var item: Dictionary = Inventory._clean(saved.get(slot_name, {}))
		equipment[slot_name] = item
	Inventory.register_banner(troop_id, display_name)
	if data.has("pos"):
		var p: Array = data["pos"]
		global_position = Vector3(p[0], p[1], p[2])
	else:
		var cell := rest_cell()
		global_position = Vector3(cell.x + 0.5, cell.y + 0.1, cell.z + 0.5)


func banner_type() -> String:
	return "banner_%d" % troop_id


func export_state() -> Dictionary:
	return {
		"id": troop_id,
		"name": display_name,
		"mood": mood,
		"banner_issued": banner_issued,
		"rest_index": rest_index,
		"equipment": equipment,
		"pos": [global_position.x, global_position.y, global_position.z],
	}


func take_damage(amount, _hit_position = Vector3.INF) -> void:
	if amount <= 0:
		return
	health -= float(amount)
	since_hit = 0.0
	mood = maxf(mood - 0.03, 0.0)
	if health <= 0.0:
		_go_down()


func _go_down() -> void:
	health = MAX_HEALTH
	since_hit = 99.0
	mood = maxf(mood - 0.3, 0.0)
	path.clear()
	path_i = 0
	path_has_goal = false
	velocity = Vector3.ZERO
	var cell := rest_cell()
	global_position = Vector3(cell.x + 0.5, cell.y + 0.1, cell.z + 0.5)


func set_equip(slot_name: String, item: Dictionary) -> void:
	equipment[slot_name] = item


func mood_name() -> String:
	if mood >= 0.8:
		return "Content"
	if mood >= 0.55:
		return "Steady"
	if mood >= 0.3:
		return "Uneasy"
	return "Afraid"


func defense_total() -> int:
	var total := 0
	for slot_name in ["head", "chest", "legs", "feet"]:
		var item: Dictionary = equipment[slot_name]
		if not item.is_empty():
			total += int(Inventory.ITEMS.get(item["id"], {}).get("defense", 0))
	return total


func weapon_info() -> Dictionary:
	var item: Dictionary = equipment["weapon"]
	if item.is_empty():
		return {}
	return Inventory.ITEMS.get(item["id"], {})


func find_banner():
	for b in get_tree().get_nodes_in_group("banner"):
		if is_instance_valid(b) and not b.dying and b.block_type == banner_type():
			return b
	return null


func issue_banner() -> String:
	var old = find_banner()
	if old != null:
		old.vanish()
	var key := banner_type()
	var held := Inventory.get_count(key)
	if held > 0:
		Inventory.take_item(key, held)
	banner_issued = true
	path.clear()
	path_has_goal = false
	return key


func rest_cell() -> Vector3i:
	var a := PI * 0.75 + float(rest_index) * 0.75
	var x := floori(core.global_position.x + cos(a) * REST_RADIUS)
	var z := floori(core.global_position.z + sin(a) * REST_RADIUS)
	return Vector3i(x, terrain.surface_y(x, z), z)


func feet_cell() -> Vector3i:
	return Vector3i(floori(global_position.x), floori(global_position.y + 0.15), floori(global_position.z))


func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	var cloth := _mat(Color(0.2, 0.25, 0.2))
	var dark := _mat(Color(0.14, 0.14, 0.15))
	var skin := _mat(Color(0.6, 0.52, 0.45))
	var wood := _mat(Color(0.4, 0.28, 0.16))
	_part(Vector3(0.16, 0.6, 0.18), Vector3(-0.11, 0.3, 0.0), dark)
	_part(Vector3(0.16, 0.6, 0.18), Vector3(0.11, 0.3, 0.0), dark)
	_part(Vector3(0.46, 0.6, 0.26), Vector3(0.0, 0.9, 0.0), cloth)
	_part(Vector3(0.3, 0.3, 0.3), Vector3(0.0, 1.35, 0.0), skin)
	_part(Vector3(0.34, 0.2, 0.34), Vector3(0.0, 1.52, 0.0), dark)
	_part(Vector3(0.12, 0.5, 0.12), Vector3(-0.3, 0.92, 0.0), cloth)
	_part(Vector3(0.12, 0.12, 0.45), Vector3(0.3, 1.1, -0.2), cloth)
	_part(Vector3(0.16, 0.5, 0.1), Vector3(0.0, 0.95, 0.18), wood)
	bow_node = Node3D.new()
	bow_node.position = Vector3(0.3, 1.1, -0.45)
	model.add_child(bow_node)
	var limb_a := MeshInstance3D.new()
	limb_a.mesh = _box(Vector3(0.04, 0.45, 0.04), wood)
	limb_a.position = Vector3(0.0, 0.2, 0.05)
	limb_a.rotation.x = -0.35
	bow_node.add_child(limb_a)
	var limb_b := MeshInstance3D.new()
	limb_b.mesh = _box(Vector3(0.04, 0.45, 0.04), wood)
	limb_b.position = Vector3(0.0, -0.2, 0.05)
	limb_b.rotation.x = 0.35
	bow_node.add_child(limb_b)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m


func _box(size: Vector3, mat: StandardMaterial3D) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	return mesh


func _part(size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _box(size, mat)
	mi.position = pos
	model.add_child(mi)


func _face(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		return
	var target := atan2(-flat.x, -flat.z)
	model.rotation.y = lerp_angle(model.rotation.y, target, 0.25)


func _physics_process(delta: float) -> void:
	if terrain == null or not terrain.collision_ready(global_position):
		return
	_update_mood(delta)
	since_hit += delta
	if since_hit > REGEN_DELAY and health < MAX_HEALTH:
		health = minf(health + REGEN_RATE * delta, MAX_HEALTH)
	think_timer -= delta
	if think_timer <= 0.0:
		think_timer = THINK_INTERVAL
		_think()
	_move(delta)
	_shoot(delta)
	recoil = maxf(recoil - delta * 4.0, 0.0)
	bow_node.position.z = -0.45 + recoil * 0.08


func _update_mood(delta: float) -> void:
	var night := 0.0
	if sun != null:
		night = 1.0 - smoothstep(-0.2, 0.05, sun.elevation)
	var target := 0.62 + minf(float(defense_total()) * 0.03, 0.15)
	if not weapon_info().is_empty():
		target += 0.1
	if find_banner() != null and path_i >= path.size():
		target += 0.08
	target -= 0.2 * night
	if threat:
		target -= 0.25
	mood = move_toward(mood, clampf(target, 0.0, 1.0), MOOD_RATE * delta)


func _think() -> void:
	var banner = find_banner()
	var goal: Vector3i
	if banner != null:
		goal = banner.stand_cell()
	else:
		goal = rest_cell()
	if path_has_goal and goal == path_goal:
		return
	path_goal = goal
	if feet_cell() == goal:
		path.clear()
		path_i = 0
		path_has_goal = true
		return
	_repath(goal, banner)


func _repath(goal: Vector3i, banner) -> void:
	var stability = get_tree().get_first_node_in_group("stability")
	if stability == null:
		return
	if pathfinder == null:
		pathfinder = PathScript.new()
	pathfinder.setup(terrain, stability, get_tree())
	ladder_cells = pathfinder.ladders.duplicate()
	var found: Array = pathfinder.find(feet_cell(), goal)
	path_goal = goal
	path_has_goal = true
	stuck_timer = 0.0
	if found.is_empty():
		path.clear()
		path_i = 0
		if banner != null:
			banner.vanish()
			if world != null and world.ui != null:
				world.ui.show_notice("Unreachable")
		return
	path = found
	path_i = 1 if found.size() > 1 else 0


func _move(delta: float) -> void:
	var on_ladder := false
	var want := Vector3.ZERO
	var climb := 0.0
	if path_i < path.size():
		var target_cell: Vector3i = path[path_i]
		var prev_cell: Vector3i = path[path_i - 1] if path_i > 0 else feet_cell()
		var tp := Vector3(target_cell.x + 0.5, float(target_cell.y), target_cell.z + 0.5)
		var flat := Vector2(tp.x - global_position.x, tp.z - global_position.z)
		var vertical := target_cell.x == prev_cell.x and target_cell.z == prev_cell.z and target_cell.y != prev_cell.y
		if vertical and (ladder_cells.has(target_cell) or ladder_cells.has(prev_cell)):
			on_ladder = true
			climb = signf(float(target_cell.y) - global_position.y) * CLIMB_SPEED
			want = Vector3(flat.x, 0.0, flat.y) * 4.0
			if absf(float(target_cell.y) - global_position.y) < 0.15:
				path_i += 1
				stuck_timer = 0.0
		else:
			if flat.length() > 0.05:
				want = Vector3(flat.x, 0.0, flat.y).normalized()
			if target_cell.y > global_position.y + 0.4 and is_on_floor():
				velocity.y = JUMP_VELOCITY
			elif is_on_wall() and is_on_floor() and flat.length() > 0.3:
				velocity.y = JUMP_VELOCITY
			if flat.length() < 0.22 and absf(global_position.y - float(target_cell.y)) < 0.7:
				path_i += 1
				stuck_timer = 0.0
		stuck_timer += delta
		if stuck_timer > STUCK_TIME:
			stuck_timer = 0.0
			repaths += 1
			if repaths > MAX_REPATH:
				repaths = 0
				path.clear()
				path_i = 0
				var banner = find_banner()
				if banner != null:
					banner.vanish()
					if world != null and world.ui != null:
						world.ui.show_notice("Unreachable")
			else:
				path_has_goal = false
				think_timer = 0.0
	else:
		repaths = 0
	if on_ladder:
		velocity.y = climb
	elif not is_on_floor():
		velocity.y -= gravity * delta
	var planar := want
	if planar.length() > 1.0:
		planar = planar.normalized()
	velocity.x = planar.x * SPEED
	velocity.z = planar.z * SPEED
	move_and_slide()
	if planar.length() > 0.1 and not threat:
		_face(planar)


func _nearest_target() -> Dictionary:
	var best = null
	var best_d := INF
	var weapon := weapon_info()
	var reach: float = float(weapon.get("range", BASE_RANGE))
	var eye := global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var any_close := false
	for group in ["enemy", "wild_gloom"]:
		var limit: float = reach if group == "enemy" else minf(reach, WILD_RANGE)
		for g in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(g) or g.dying:
				continue
			var d: float = eye.distance_to(g.global_position)
			if d < 14.0:
				any_close = true
			if d > limit or d >= best_d:
				continue
			var aim: Vector3 = g.global_position + Vector3(0.0, 0.8, 0.0)
			var query := PhysicsRayQueryParameters3D.create(eye, aim, 1)
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				continue
			best = g
			best_d = d
	threat = any_close
	if best == null:
		return {}
	return {"node": best, "dist": best_d}


func _shoot(delta: float) -> void:
	fire_timer -= delta
	if fire_timer > 0.0:
		return
	var found := _nearest_target()
	if found.is_empty():
		fire_timer = 0.25
		return
	var target: Node3D = found["node"]
	var dist: float = found["dist"]
	var eye := global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var aim := target.global_position + Vector3(0.0, 0.8, 0.0)
	var flight := dist / ArrowScript.SPEED
	aim.y += 0.5 * ArrowScript.GRAVITY * flight * flight
	var dir := aim - eye
	_face(dir)
	var weapon := weapon_info()
	var damage: int = BASE_DAMAGE + int(weapon.get("damage", 0))
	var cooldown: float = float(weapon.get("cooldown", BASE_COOLDOWN))
	cooldown *= 1.4 - 0.6 * mood
	var arrow := Node3D.new()
	arrow.set_script(ArrowScript)
	get_tree().current_scene.add_child(arrow)
	arrow.launch(eye + dir.normalized() * 0.6, dir, damage)
	recoil = 1.0
	fire_timer = cooldown
