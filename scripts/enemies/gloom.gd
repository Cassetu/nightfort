extends CharacterBody3D

const ChipBurst = preload("res://scripts/chip_burst.gd")
const Sfx = preload("res://scripts/core/sfx.gd")
const GloomBake = preload("res://scripts/enemies/gloom_bake.gd")

signal died(enemy)

const ATTACKS := ["swipe_r", "swipe_l", "slam", "bite"]
const BREAKS := ["bite", "bite", "slam", "swipe_r"]
const ONE_SHOTS := ["swipe_r", "swipe_l", "slam", "bite"]

const SPEED := 3.4
const JUMP_VELOCITY := 6.2
const AGGRO_RANGE := 14.0
const ALONE_DISTANCE := 30.0
const BLOCK_RANGE := 3.5
const PLAYER_REACH := 1.9
const CORE_REACH := 2.6
const FEET_OFFSET := 0.85
const PLAYER_DAMAGE := 10
const CORE_DAMAGE := 5
const BLOCK_DAMAGE := 1
const ATTACK_INTERVAL := 1.1
const KNOCKBACK := 6.0
const BASE_HEALTH := 8.0
const SIGHT_RANGE := 16.0
const RALLY_RANGE := 20.0
const SMELL_RANGE := 22.0
const WILD_INTERVAL := 0.85
const SIGHT_HEIGHT := 1.4
const WILD_SPEED := 0.65
const WILD_CORE_AVOID := 48.0
const WILD_ANGER := 14.0
const WILD_DAMAGE := 8
const CORE_CLOSE := 9.0
const ENGAGE_WIDTH := 1.1
const ENGAGE_HEIGHT := 1.6
const PLOW_RANGE := 3.2
const STEP_HEIGHT := 1.0
const PROBE_AHEAD := 0.95

var wild: bool = false
var surface: bool = false
var anger: float = 0.0
var wander_dir := Vector3.ZERO
var wander_timer: float = 0.0

var health: float = BASE_HEALTH
var flow
var core
var player
var terrain
var attack_timer: float = 0.0
var stun: float = 0.0
var knock := Vector3.ZERO
var speed_mult: float = 1.0
var yaw: float = 0.0
var dying: bool = false
var plowing: bool = false
var last_swing: String = ""
var smell_timer: float = 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var body: Node3D = $Body
@onready var anim: AnimationPlayer = $Anim


func _ready() -> void:
	GloomBake.bake(self)
	if wild:
		add_to_group("wild_gloom")
		_wild_look()
	else:
		add_to_group("enemy")
	collision_layer = 2
	collision_mask = 1
	terrain = get_tree().get_first_node_in_group("terrain")
	speed_mult = randf_range(0.9, 1.1)
	attack_timer = randf_range(0.2, 0.8)


func setup(f, c, p, night: int) -> void:
	flow = f
	core = c
	player = p
	health = BASE_HEALTH * (1.0 + 0.15 * float(night - 1))


func _physics_process(delta: float) -> void:
	if dying:
		return
	if global_position.y < -70.0:
		remove_from_group("enemy")
		remove_from_group("wild_gloom")
		queue_free()
		return
	if terrain != null and not terrain.collision_ready(global_position):
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	attack_timer = maxf(attack_timer - delta, 0.0)
	stun = maxf(stun - delta, 0.0)
	knock = knock.move_toward(Vector3.ZERO, 18.0 * delta)

	var ai: Array
	if wild:
		ai = _wild_ai(delta)
	else:
		ai = _hunt_ai()
	var desired: Vector3 = ai[0]
	var facing: Vector3 = ai[1]

	var move := desired * SPEED * speed_mult
	if wild and anger <= 0.0:
		move *= WILD_SPEED
	if stun > 0.0:
		move = Vector3.ZERO
	velocity.x = move.x + knock.x
	velocity.z = move.z + knock.z

	if is_on_floor() and desired != Vector3.ZERO and is_on_wall() and stun <= 0.0 and _can_hop(desired):
		velocity.y = JUMP_VELOCITY

	move_and_slide()

	if attack_timer <= 0.0 and not wild:
		for i in get_slide_collision_count():
			var hit := get_slide_collision(i)
			var other = hit.get_collider()
			if other != null and other.is_in_group("block"):
				if other.current_health <= BLOCK_DAMAGE:
					other.resource_amount = 0
				other.take_damage(BLOCK_DAMAGE, hit.get_position())
				attack_timer = ATTACK_INTERVAL * 0.7
				_smash()
				break

	_animate(delta, facing)


func _ray_hits(from: Vector3, dir: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * PROBE_AHEAD, 1)
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _can_hop(desired: Vector3) -> bool:
	var dir := Vector3(desired.x, 0.0, desired.z)
	if dir.length() < 0.01:
		return false
	dir = dir.normalized()
	var feet := global_position.y - FEET_OFFSET
	var origin := Vector3(global_position.x, 0.0, global_position.z)
	if not _ray_hits(Vector3(origin.x, feet + 0.4, origin.z), dir):
		return false
	if _ray_hits(Vector3(origin.x, feet + STEP_HEIGHT + 0.45, origin.z), dir):
		return false
	if _ray_hits(Vector3(origin.x, feet + STEP_HEIGHT + 1.3, origin.z), dir):
		return false
	return true


func _hunt_ai() -> Array:
	var desired := Vector3.ZERO
	var facing := Vector3.ZERO

	var chase_player := false
	var to_player := Vector3.ZERO
	if is_instance_valid(player) and not player.dead:
		to_player = player.global_position - global_position
		var flat_to_player := Vector3(to_player.x, 0.0, to_player.z)
		var player_alone := false
		if is_instance_valid(core):
			var from_core: Vector3 = player.global_position - core.global_position
			player_alone = Vector2(from_core.x, from_core.z).length() > ALONE_DISTANCE
		var flat_len := flat_to_player.length()
		var level := absf(to_player.y) < ENGAGE_HEIGHT
		var path_dir := Vector3.ZERO
		if flow != null:
			path_dir = flow.direction_at(global_position)
		var flat_dir := flat_to_player.normalized() if flat_len > 0.01 else Vector3.ZERO
		var ahead := flat_dir.dot(path_dir) if path_dir != Vector3.ZERO else 0.0
		var lateral := absf(flat_dir.cross(path_dir).y) * flat_len
		var in_the_way := level and flat_len < BLOCK_RANGE and (flat_len < 0.6 or (ahead > 0.7 and lateral < ENGAGE_WIDTH))
		var near_core := false
		if is_instance_valid(core):
			var to_core_flat: Vector3 = core.global_position - global_position
			near_core = Vector2(to_core_flat.x, to_core_flat.z).length() < CORE_CLOSE
		var close_fight := near_core and level and flat_len < PLAYER_REACH + 0.8
		var behind := path_dir != Vector3.ZERO and ahead < 0.0
		chase_player = in_the_way or close_fight or (player_alone and to_player.length() < AGGRO_RANGE and not behind)
		_set_plowing(not chase_player and not near_core and flat_len < PLOW_RANGE)
	else:
		_set_plowing(false)

	if chase_player:
		var flat := Vector3(to_player.x, 0.0, to_player.z)
		facing = flat
		if flat.length() > PLAYER_REACH:
			desired = flat.normalized()
		elif attack_timer <= 0.0 and absf(to_player.y) < 2.2:
			player.take_damage(PLAYER_DAMAGE, global_position)
			attack_timer = ATTACK_INTERVAL
			_lunge()
	elif is_instance_valid(core) and flow != null:
		var to_core: Vector3 = core.global_position - global_position
		var flat_dist := Vector2(to_core.x, to_core.z).length()
		facing = Vector3(to_core.x, 0.0, to_core.z)
		var level_ok: bool = core.melee_reachable(global_position.y - FEET_OFFSET)
		if flat_dist > CORE_REACH or not level_ok:
			desired = flow.direction_at(global_position)
			facing = desired
		elif attack_timer <= 0.0:
			core.take_damage(CORE_DAMAGE, global_position)
			attack_timer = ATTACK_INTERVAL
			_lunge()

	return [desired, facing]


func _set_plowing(value: bool) -> void:
	if value == plowing or not is_instance_valid(player):
		return
	plowing = value
	if plowing:
		add_collision_exception_with(player)
	else:
		remove_collision_exception_with(player)


func _rally() -> void:
	for other in get_tree().get_nodes_in_group("wild_gloom"):
		if other == self or other.dying:
			continue
		if other.global_position.distance_to(global_position) < RALLY_RANGE:
			other.anger = WILD_ANGER


func _wild_ai(delta: float) -> Array:
	anger = maxf(anger - delta, 0.0)
	var desired := Vector3.ZERO
	var facing := Vector3.ZERO

	if is_instance_valid(player) and not player.dead:
		if _sees_player():
			anger = WILD_ANGER
		elif anger <= 0.0:
			smell_timer -= delta
			if smell_timer <= 0.0:
				smell_timer = randf_range(3.0, 7.0)
				var apart: Vector3 = player.global_position - global_position
				if Vector2(apart.x, apart.z).length() < SMELL_RANGE and randf() < 0.5:
					anger = WILD_ANGER * 0.6

	if anger > 0.0 and is_instance_valid(player) and not player.dead:
		var to_player: Vector3 = player.global_position - global_position
		var flat := Vector3(to_player.x, 0.0, to_player.z)
		facing = flat
		if flat.length() > PLAYER_REACH:
			desired = flat.normalized()
		elif attack_timer <= 0.0 and absf(to_player.y) < 2.2:
			player.take_damage(WILD_DAMAGE, global_position)
			attack_timer = WILD_INTERVAL
			_lunge()
			_rally()
		return [desired, facing]

	if is_instance_valid(core):
		var from_core: Vector3 = global_position - core.global_position
		var flat_core := Vector3(from_core.x, 0.0, from_core.z)
		if flat_core.length() < WILD_CORE_AVOID:
			var away := flat_core.normalized() if flat_core.length() > 0.1 else Vector3.RIGHT
			return [away, away]

	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 5.5)
		if randf() < 0.35:
			wander_dir = Vector3.ZERO
		else:
			var a := randf() * TAU
			wander_dir = Vector3(cos(a), 0.0, sin(a))
	return [wander_dir, wander_dir]


func _sees_player() -> bool:
	var eye := global_position + Vector3(0.0, SIGHT_HEIGHT - 0.85, 0.0)
	var target: Vector3 = player.global_position
	if eye.distance_to(target) > SIGHT_RANGE:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _wild_look() -> void:
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.5, 0.9, 0.95)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.4, 0.9, 1.0)
	eye_mat.emission_energy_multiplier = 3.0
	var flesh_mat: StandardMaterial3D = null
	var tinted: Dictionary = {}
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for surface in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(surface) as StandardMaterial3D
			if base == null:
				continue
			if base.emission_energy_multiplier > 2.0:
				mi.set_surface_override_material(surface, eye_mat)
			elif base.resource_name.begins_with("detail"):
				if not tinted.has(base):
					var copy := base.duplicate() as StandardMaterial3D
					copy.albedo_color = base.albedo_color * Color(0.55, 0.85, 0.9)
					tinted[base] = copy
				mi.set_surface_override_material(surface, tinted[base])
			else:
				if flesh_mat == null:
					flesh_mat = base.duplicate() as StandardMaterial3D
					flesh_mat.albedo_color = Color(0.45, 0.8, 0.85)
					flesh_mat.emission = Color(0.04, 0.12, 0.13)
				mi.set_surface_override_material(surface, flesh_mat)


func _animate(delta: float, facing: Vector3) -> void:
	if facing.length() > 0.01:
		var target := atan2(-facing.x, -facing.z)
		yaw = lerp_angle(yaw, target, minf(delta * 10.0, 1.0))
		body.rotation.y = yaw

	var current := anim.current_animation
	if anim.is_playing() and ONE_SHOTS.has(current):
		return

	var speed := Vector2(velocity.x, velocity.z).length()
	var want := "walk" if speed > 0.4 else "idle"
	if current != want or not anim.is_playing():
		anim.play(want, 0.15)
	anim.speed_scale = clampf(speed / SPEED, 0.6, 1.8) if want == "walk" else 1.0


func take_damage(amount, from_pos = Vector3.INF) -> void:
	if dying:
		return
	health -= float(amount)
	if wild:
		anger = WILD_ANGER
		_rally()
	if from_pos.is_finite():
		var away: Vector3 = global_position - from_pos
		away.y = 0.0
		if away.length() > 0.01:
			knock = away.normalized() * KNOCKBACK
	if is_on_floor():
		velocity.y = 3.5
	stun = 0.25
	_chips()
	_punch()
	if health <= 0.0:
		_die()


func _die() -> void:
	dying = true
	remove_from_group("enemy")
	remove_from_group("wild_gloom")
	collision_layer = 0
	Sfx.play(self, "gloom_death", global_position, 0.0)
	_chips()
	died.emit(self)
	_shrink(0.3)


func dissolve() -> void:
	if dying:
		return
	dying = true
	remove_from_group("enemy")
	remove_from_group("wild_gloom")
	collision_layer = 0
	_chips()
	_shrink(0.8)


func _shrink(time: float) -> void:
	var tween := create_tween()
	tween.tween_property(body, "scale", Vector3.ZERO, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _punch() -> void:
	var tween := create_tween()
	body.scale = Vector3(1.25, 0.8, 1.25)
	tween.tween_property(body, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _lunge() -> void:
	Sfx.play(self, "gloom_attack", global_position, 0.0)
	anim.speed_scale = 1.0
	anim.play(_pick_swing(ATTACKS), 0.05)


func _pick_swing(options: Array) -> String:
	var choice: String = options[randi() % options.size()]
	if choice == last_swing:
		choice = options[randi() % options.size()]
	last_swing = choice
	return choice


func _smash() -> void:
	anim.speed_scale = 1.0
	anim.play(_pick_swing(BREAKS), 0.05)


func _chips() -> void:
	ChipBurst.spawn(self, global_position + Vector3(0.0, 0.4, 0.0), "", Color(0.34, 0.12, 0.55), 12, 0.12, 0.7, 80.0, 2.0, 5.0, 10.0)
