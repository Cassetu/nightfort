extends CharacterBody3D

signal fell(unit: Node3D)

const ArrowScript = preload("res://scripts/arrow.gd")
const ChipBurst = preload("res://scripts/chip_burst.gd")
const AllySkin = preload("res://scripts/ally_skin.gd")

const SPEED := 3.5
const TURN := 8.0
const SEEK := 18.0
const MELEE_REACH := 2.1
const MELEE_DAMAGE := 9
const MELEE_COOLDOWN := 0.7
const MINE_DAMAGE := 6
const MINE_COOLDOWN := 0.8
const WALL_STOP := 1.7
const HOLE_FUNNEL := 1.2
const BONE_SEEK := 5.5
const BONE_REACH := 2.0
const BONE_STEER := 1.6
const BONE_REFRESH := 0.3
const BOW_RANGE := 30.0
const BOW_COOLDOWN := 1.5
const BOW_DAMAGE := 4
const BOW_SPEED := 32.0
const ARCHER_GAP := 9.0
const INNER_MARGIN := 6.0
const BILE := Color(0.36, 0.2, 0.46)
const MODELS := {
	"soldier": preload("res://scenes/soldier.tscn"),
	"archer": preload("res://scenes/archer.tscn"),
	"commander": preload("res://scenes/commander.tscn"),
}
const HOLD_STOP := 2.0
const JUMP_SPEED := 5.6
const STEP_HEIGHT := 1.1
const STEP_PROBE := 0.7
const JUMP_COOLDOWN := 0.5
const FOE_REFRESH := 0.18
const WALL_REFRESH := 0.6
const THINK := 0.08
const FAR_THINK := 0.25
const FAR_DIST := 70.0
const STUCK_TIME := 0.45
const SIDESTEP_TIME := 0.7
const SIDESTEP_ANGLE := 1.2
const KITE_RANGE := 6.0
const FOE_SWITCH := 1.69

var role: String = "soldier"
var arena
var hp: float = 70.0
var max_hp: float = 70.0
var active: bool = false
var dead: bool = false
var cooldown: float = 0.0
var phase: float = 0.0
var mining: bool = false
var swing: float = 0.0
var hold_point := Vector3.ZERO
var follow_node: Node3D
var goto_point := Vector3.ZERO
var has_goto: bool = false
var end_yaw: float = PI
var foe_cache
var jump_timer: float = 0.0
var foe_timer: float = randf() * 0.18
var wall_cache
var bone_cache
var bone_timer: float = randf() * 0.3
var wall_ring: int = -1
var wall_timer: float = randf() * 0.4
var think_timer: float = randf() * 0.08
var think_accum: float = 0.0
var desired := Vector3.ZERO
var face_dir := Vector3.ZERO
var far: bool = false
var last_pos := Vector3.ZERO
var stuck_time: float = 0.0
var sidestep: float = 0.0
var sidestep_sign: float = 1.0
var claim_key = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var model: Node3D
var arm_r: Node3D
var arm_l: Node3D
var leg_r: Node3D
var leg_l: Node3D
var sword_node: Node3D
var pick_node: Node3D
var bow_node: Node3D


func setup(unit_role: String, world_arena) -> void:
	role = unit_role
	arena = world_arena
	match role:
		"archer":
			max_hp = 40.0
		"commander":
			max_hp = 120.0
		_:
			max_hp = 70.0
	hp = max_hp
	collision_layer = 8
	collision_mask = 1 | 8
	add_to_group("ally_unit")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0.0, 0.9, 0.0)
	add_child(cs)
	_build_model()


func _build_model() -> void:
	model = (MODELS[role] as PackedScene).instantiate()
	add_child(model)
	arm_r = model.get_node_or_null("ArmR")
	arm_l = model.get_node_or_null("ArmL")
	leg_r = model.get_node_or_null("LegR")
	leg_l = model.get_node_or_null("LegL")
	sword_node = model.get_node_or_null("ArmR/Sword")
	pick_node = model.get_node_or_null("ArmR/Pick")
	bow_node = model.get_node_or_null("ArmL/Bow")
	AllySkin.apply(model)
	if pick_node != null:
		pick_node.visible = false


func command() -> void:
	active = true


func take_damage(amount, from: Vector3 = Vector3.INF) -> void:
	if dead or amount <= 0:
		return
	hp -= float(amount)
	if from.is_finite():
		var away := global_position - from
		away.y = 0.0
		velocity += away.normalized() * 3.0
	ChipBurst.spawn(self, global_position + Vector3(0.0, 1.2, 0.0), "gloom_flesh", Color(0.7, 0.1, 0.12), 5, 0.08, 0.5, 80.0, 2.0, 4.0, 10.0)
	if hp <= 0.0:
		_fall()


func _fall() -> void:
	dead = true
	if arena != null:
		arena.release_wall(self)
	remove_from_group("ally_unit")
	collision_layer = 0
	fell.emit(self)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(model, "rotation:x", -1.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(model, "position:y", -0.5, 0.5)
	await tween.finished
	if not is_inside_tree():
		return
	await get_tree().create_timer(6.0).timeout
	queue_free()


func _face(dir: Vector3, _delta: float = 0.0) -> void:
	if dir.length() < 0.01:
		return
	face_dir = dir


func _physics_process(delta: float) -> void:
	if dead:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	cooldown = maxf(cooldown - delta, 0.0)
	think_accum += delta
	think_timer -= delta
	if think_timer <= 0.0:
		_think(think_accum)
		think_accum = 0.0
		think_timer = (FAR_THINK if far else THINK) + randf() * 0.03
	if face_dir.length_squared() > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(-face_dir.x, -face_dir.z), minf(TURN * delta, 1.0))
	velocity.x = move_toward(velocity.x, desired.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z, 30.0 * delta)
	jump_timer = maxf(jump_timer - delta, 0.0)
	if desired != Vector3.ZERO and jump_timer <= 0.0 and is_on_floor() and is_on_wall() and not mining:
		_try_hop(desired)
	if desired != Vector3.ZERO or not is_on_floor() or velocity.length_squared() > 0.01:
		move_and_slide()
	if far:
		swing = 0.0
	else:
		_animate(delta, Vector2(velocity.x, velocity.z).length())


func _think(dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	far = cam != null and cam.global_position.distance_squared_to(global_position) > FAR_DIST * FAR_DIST
	var move := Vector3.ZERO
	mining = false
	if has_goto:
		move = _approach(goto_point, 0.8, dt)
		if move == Vector3.ZERO:
			has_goto = false
			var turn := create_tween()
			turn.tween_property(self, "rotation:y", rotation.y + angle_difference(rotation.y, end_yaw), 0.5)
	elif active and arena != null:
		match role:
			"soldier":
				move = _soldier(dt)
			_:
				move = _support(dt)
	elif follow_node != null and is_instance_valid(follow_node):
		move = _approach(follow_node.global_position, 4.0, dt)
	desired = _unstick(move, dt)


func _unstick(move: Vector3, dt: float) -> Vector3:
	var moved := Vector2(global_position.x - last_pos.x, global_position.z - last_pos.z).length()
	last_pos = global_position
	if move == Vector3.ZERO:
		stuck_time = 0.0
		sidestep = maxf(sidestep - dt, 0.0)
		return move
	if sidestep > 0.0:
		sidestep -= dt
		return move.rotated(Vector3.UP, sidestep_sign * SIDESTEP_ANGLE)
	if is_on_floor() and moved < move.length() * dt * 0.15:
		stuck_time += dt
	else:
		stuck_time = maxf(stuck_time - dt, 0.0)
	if stuck_time > STUCK_TIME:
		stuck_time = 0.0
		sidestep = SIDESTEP_TIME
		sidestep_sign = 1.0 if randf() < 0.5 else -1.0
	return move


func _try_hop(move: Vector3) -> void:
	var dir := Vector3(move.x, 0.0, move.z).normalized() * STEP_PROBE
	if not test_move(global_transform, dir):
		return
	var raised := global_transform
	raised.origin.y += STEP_HEIGHT
	if test_move(raised, dir):
		return
	velocity.y = JUMP_SPEED
	jump_timer = JUMP_COOLDOWN


func _approach(point: Vector3, stop: float, delta: float) -> Vector3:
	var to := point - global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= stop:
		return Vector3.ZERO
	var dir := to / dist
	if arena != null:
		var push: Vector3 = arena.bone_push(global_position)
		if push != Vector3.ZERO:
			dir = (dir + push * BONE_STEER).normalized()
	_face(dir, delta)
	return dir * SPEED


func _foe(radius: float, delta: float):
	foe_timer -= delta
	var stale: bool = foe_cache == null or not is_instance_valid(foe_cache) or foe_cache.dying
	if foe_timer <= 0.0 or stale:
		foe_timer = FOE_REFRESH + randf() * 0.1
		var fresh = arena.nearest_gloom(global_position, radius)
		if fresh == null and role != "soldier":
			fresh = arena.nearest_spitter(global_position, radius)
		if stale or fresh == null or foe_cache == fresh:
			foe_cache = fresh
		elif global_position.distance_squared_to(foe_cache.global_position) > global_position.distance_squared_to(fresh.global_position) * FOE_SWITCH:
			foe_cache = fresh
	elif global_position.distance_squared_to(foe_cache.global_position) > radius * radius * 1.4:
		foe_cache = null
	return foe_cache


func _bone(delta: float):
	bone_timer -= delta
	var stale: bool = bone_cache != null and (not is_instance_valid(bone_cache) or bone_cache.dead)
	if bone_timer <= 0.0 or stale:
		bone_timer = BONE_REFRESH + randf() * 0.15
		bone_cache = arena.nearest_barricade(global_position, BONE_SEEK)
	return bone_cache


func _wall(ring: int, delta: float):
	wall_timer -= delta
	var valid: bool = wall_cache != null and is_instance_valid(wall_cache) and wall_ring == ring
	var stale: bool = not valid or (wall_cache.dead and wall_cache.next_block != null)
	var near := false
	if valid and not wall_cache.dead:
		var flat: Vector3 = wall_cache.global_position - global_position
		flat.y = 0.0
		near = flat.length_squared() < WALL_STOP * WALL_STOP * 2.0
	if stale or (wall_timer <= 0.0 and not near):
		wall_timer = WALL_REFRESH + randf() * 0.2
		wall_ring = ring
		wall_cache = arena.nearest_wall(ring, global_position, self)
	return wall_cache


func _soldier(delta: float) -> Vector3:
	var foe = _foe(SEEK, delta)
	if foe != null:
		var to = foe.global_position - global_position
		to.y = 0.0
		if to.length() <= MELEE_REACH:
			_face(to.normalized(), delta)
			_set_weapon(false)
			if cooldown <= 0.0:
				cooldown = MELEE_COOLDOWN
				swing = 1.0
				foe.take_damage(MELEE_DAMAGE, global_position)
			return Vector3.ZERO
		_set_weapon(false)
		return _approach(foe.global_position, MELEE_REACH - 0.3, delta)
	var bone = _bone(delta)
	if bone != null:
		var to_bone: Vector3 = bone.global_position - global_position
		to_bone.y = 0.0
		_set_weapon(false)
		if to_bone.length() <= BONE_REACH:
			_face(to_bone.normalized(), delta)
			if cooldown <= 0.0:
				cooldown = MELEE_COOLDOWN
				swing = 1.0
				bone.take_damage(MELEE_DAMAGE, global_position)
			return Vector3.ZERO
		return _approach(bone.global_position, BONE_REACH - 0.2, delta)
	var ring: int = arena.ring_for(global_position)
	if ring < 0 or ring >= 2:
		_set_weapon(false)
		return _approach(arena.hold_point(global_position), HOLD_STOP, delta)
	var wall = _wall(ring, delta)
	if wall == null:
		return Vector3.ZERO
	if wall.dead:
		_set_weapon(false)
		var radial: Vector3 = wall.global_position - arena.heart_position
		radial.y = 0.0
		radial = radial.normalized()
		var unit_d: float = arena.distance_from_heart(global_position)
		var wall_d: float = arena.distance_from_heart(wall.global_position)
		if unit_d > wall_d + HOLE_FUNNEL:
			return _approach(wall.global_position, 0.5, delta)
		return _approach(wall.global_position - radial * INNER_MARGIN, 0.8, delta)
	var to_wall = wall.global_position - global_position
	to_wall.y = 0.0
	if to_wall.length() > WALL_STOP:
		_set_weapon(false)
		return _approach(wall.global_position, WALL_STOP, delta)
	_face(to_wall.normalized(), delta)
	_set_weapon(true)
	mining = true
	if cooldown <= 0.0:
		cooldown = MINE_COOLDOWN
		swing = 1.0
		wall.take_damage(MINE_DAMAGE, global_position)
	return Vector3.ZERO


func _support(delta: float) -> Vector3:
	var foe = _foe(BOW_RANGE, delta)
	var anchor: Vector3 = arena.support_point(global_position, ARCHER_GAP if role == "archer" else ARCHER_GAP * 0.6)
	if foe != null and role == "archer":
		var to = foe.global_position - global_position
		to.y = 0.0
		_face(to.normalized(), delta)
		if cooldown <= 0.0:
			cooldown = BOW_COOLDOWN
			swing = 1.0
			_shoot(foe)
		if to.length() < KITE_RANGE:
			return -to.normalized() * SPEED * 0.8
	elif foe != null and role == "commander":
		var close = foe.global_position - global_position
		close.y = 0.0
		if close.length() < MELEE_REACH + 1.0 and cooldown <= 0.0:
			cooldown = MELEE_COOLDOWN
			swing = 1.0
			_face(close.normalized(), delta)
			foe.take_damage(MELEE_DAMAGE, global_position)
	return _approach(anchor, 1.5, delta)


func _shoot(foe) -> void:
	var from := global_position + Vector3(0.0, 1.5, 0.0)
	var aim = foe.global_position + Vector3(0.0, 1.0, 0.0)
	var offset = aim - from
	var flat := Vector2(offset.x, offset.z).length()
	var drop := 0.5 * 4.0 * pow(flat / BOW_SPEED, 2.0)
	aim.y += drop
	var arrow := ArrowScript.fetch()
	get_tree().current_scene.add_child(arrow)
	arrow.launch(from, aim - from, BOW_DAMAGE, BOW_SPEED)


func _set_weapon(pick: bool) -> void:
	if pick_node != null:
		pick_node.visible = pick
	if role == "soldier" and sword_node != null:
		sword_node.visible = not pick


func _pose(node: Node3D, angle: float, delta: float = 0.0) -> void:
	if node == null:
		return
	if delta > 0.0:
		node.rotation.x = lerpf(node.rotation.x, angle, minf(8.0 * delta, 1.0))
	else:
		node.rotation.x = angle


func _exit_tree() -> void:
	if arena != null and is_instance_valid(arena):
		arena.release_wall(self)


func _animate(delta: float, speed: float) -> void:
	if speed > 0.3:
		phase += delta * speed * 2.6
		var s := sin(phase) * 0.7
		_pose(leg_r, s)
		_pose(leg_l, -s)
		_pose(arm_l, s * 0.5)
	else:
		_pose(leg_r, 0.0, delta)
		_pose(leg_l, 0.0, delta)
		_pose(arm_l, 0.0, delta)
	swing = maxf(swing - delta * 3.0, 0.0)
	var raise := -0.5 if (mining or role == "archer") else 0.0
	_pose(arm_r, raise - sin(swing * PI) * 1.6)
	if role == "archer":
		_pose(arm_l, -1.3)
