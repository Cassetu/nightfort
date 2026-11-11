extends CharacterBody3D

signal fell(unit: Node3D)

const ArrowScript = preload("res://scripts/arrow.gd")
const ChipBurst = preload("res://scripts/chip_burst.gd")

const SPEED := 3.5
const TURN := 8.0
const SEEK := 18.0
const MELEE_REACH := 2.1
const MELEE_DAMAGE := 9
const MELEE_COOLDOWN := 0.7
const MINE_DAMAGE := 6
const MINE_COOLDOWN := 0.8
const WALL_STOP := 3.6
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
	collision_mask = 1
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


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(TURN * delta, 1.0))


func _physics_process(delta: float) -> void:
	if dead:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	cooldown = maxf(cooldown - delta, 0.0)
	var move := Vector3.ZERO
	mining = false
	if has_goto:
		move = _approach(goto_point, 0.8, delta)
		if move == Vector3.ZERO:
			has_goto = false
			var turn := create_tween()
			turn.tween_property(self, "rotation:y", rotation.y + angle_difference(rotation.y, end_yaw), 0.5)
	elif active and arena != null:
		match role:
			"soldier":
				move = _soldier(delta)
			_:
				move = _support(delta)
	elif follow_node != null and is_instance_valid(follow_node):
		move = _approach(follow_node.global_position, 4.0, delta)
	velocity.x = move_toward(velocity.x, move.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, move.z, 30.0 * delta)
	move_and_slide()
	_animate(delta, Vector2(velocity.x, velocity.z).length())


func _approach(point: Vector3, stop: float, delta: float) -> Vector3:
	var to := point - global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= stop:
		return Vector3.ZERO
	var dir := to / dist
	_face(dir, delta)
	return dir * SPEED


func _soldier(delta: float) -> Vector3:
	var foe = arena.nearest_gloom(global_position, SEEK)
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
	var ring: int = arena.ring_for(global_position)
	if ring < 0 or ring >= 1:
		_set_weapon(false)
		return _approach(arena.hold_point(global_position), HOLD_STOP, delta)
	var wall = arena.nearest_wall(ring, global_position)
	if wall == null:
		return Vector3.ZERO
	if wall.dead:
		_set_weapon(false)
		var radial: Vector3 = wall.global_position - arena.heart_position
		radial.y = 0.0
		radial = radial.normalized()
		var unit_d: float = arena.distance_from_heart(global_position)
		var wall_d: float = arena.distance_from_heart(wall.global_position)
		if unit_d > wall_d + 1.0:
			var stage: Vector3 = wall.global_position + radial * 4.0
			var gap := stage - global_position
			gap.y = 0.0
			if gap.length() > 1.5:
				return _approach(stage, 1.0, delta)
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
	var foe = arena.nearest_gloom(global_position, BOW_RANGE)
	if foe == null:
		foe = arena.nearest_spitter(global_position, BOW_RANGE)
	var anchor: Vector3 = arena.support_point(global_position, ARCHER_GAP if role == "archer" else ARCHER_GAP * 0.6)
	if foe != null and role == "archer":
		var to = foe.global_position - global_position
		to.y = 0.0
		_face(to.normalized(), delta)
		if cooldown <= 0.0:
			cooldown = BOW_COOLDOWN
			swing = 1.0
			_shoot(foe)
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
