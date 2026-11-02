extends CharacterBody3D

signal died(enemy)

const SPEED := 3.4
const JUMP_VELOCITY := 6.2
const AGGRO_RANGE := 14.0
const PLAYER_REACH := 1.9
const CORE_REACH := 2.7
const PLAYER_DAMAGE := 10
const CORE_DAMAGE := 5
const BLOCK_DAMAGE := 1
const ATTACK_INTERVAL := 1.1
const KNOCKBACK := 6.0
const BASE_HEALTH := 8.0
const ARM_REST := 1.25

var health: float = BASE_HEALTH
var flow
var core
var player
var terrain
var attack_timer: float = 0.0
var stun: float = 0.0
var knock := Vector3.ZERO
var anim_time: float = 0.0
var lunge_time: float = 0.0
var speed_mult: float = 1.0
var yaw: float = 0.0
var dying: bool = false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var body: Node3D = $Body
@onready var arm_l: Node3D = $Body/ArmL
@onready var arm_r: Node3D = $Body/ArmR
@onready var leg_l: Node3D = $Body/LegL
@onready var leg_r: Node3D = $Body/LegR


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 2
	collision_mask = 1
	terrain = get_tree().get_first_node_in_group("terrain")
	speed_mult = randf_range(0.9, 1.1)
	anim_time = randf() * TAU
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
		queue_free()
		return
	if terrain != null and not terrain.collision_ready(global_position):
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	attack_timer = maxf(attack_timer - delta, 0.0)
	stun = maxf(stun - delta, 0.0)
	knock = knock.move_toward(Vector3.ZERO, 18.0 * delta)

	var desired := Vector3.ZERO
	var facing := Vector3.ZERO

	var chase_player := false
	var to_player := Vector3.ZERO
	if is_instance_valid(player) and not player.dead:
		to_player = player.global_position - global_position
		chase_player = to_player.length() < AGGRO_RANGE

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
		if flat_dist > CORE_REACH or absf(to_core.y) > 3.5:
			desired = flow.direction_at(global_position)
			facing = desired
		elif attack_timer <= 0.0:
			core.take_damage(CORE_DAMAGE, global_position)
			attack_timer = ATTACK_INTERVAL
			_lunge()

	var move := desired * SPEED * speed_mult
	if stun > 0.0:
		move = Vector3.ZERO
	velocity.x = move.x + knock.x
	velocity.z = move.z + knock.z

	if is_on_floor() and desired != Vector3.ZERO and is_on_wall() and stun <= 0.0:
		velocity.y = JUMP_VELOCITY

	move_and_slide()

	if attack_timer <= 0.0:
		for i in get_slide_collision_count():
			var hit := get_slide_collision(i)
			var other = hit.get_collider()
			if other != null and other.is_in_group("block"):
				other.take_damage(BLOCK_DAMAGE, hit.get_position())
				attack_timer = ATTACK_INTERVAL * 0.7
				_lunge()
				break

	_animate(delta, facing)


func _animate(delta: float, facing: Vector3) -> void:
	if facing.length() > 0.01:
		var target := atan2(-facing.x, -facing.z)
		yaw = lerp_angle(yaw, target, minf(delta * 10.0, 1.0))
		body.rotation.y = yaw

	var speed := Vector2(velocity.x, velocity.z).length()
	anim_time += delta * (2.0 + speed * 2.2)
	var swing := sin(anim_time)
	var amount := clampf(speed / SPEED, 0.0, 1.0)
	arm_l.rotation.x = ARM_REST + swing * 0.25 * amount
	arm_r.rotation.x = ARM_REST - swing * 0.25 * amount
	lunge_time = maxf(lunge_time - delta, 0.0)
	if lunge_time > 0.0:
		arm_l.rotation.x = 2.2
		arm_r.rotation.x = 2.2
	leg_l.rotation.x = swing * 0.7 * amount
	leg_r.rotation.x = -swing * 0.7 * amount
	body.position.y = absf(swing) * 0.05 * amount


func take_damage(amount, from_pos = Vector3.INF) -> void:
	if dying:
		return
	health -= float(amount)
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
	collision_layer = 0
	_chips()
	died.emit(self)
	_shrink(0.3)


func dissolve() -> void:
	if dying:
		return
	dying = true
	remove_from_group("enemy")
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
	lunge_time = 0.25


func _chips() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.1, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.1, 0.7)

	var chip := BoxMesh.new()
	chip.size = Vector3(0.12, 0.12, 0.12)
	chip.material = mat

	var burst := CPUParticles3D.new()
	burst.mesh = chip
	burst.amount = 12
	burst.lifetime = 0.7
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.direction = Vector3.UP
	burst.spread = 80.0
	burst.gravity = Vector3(0.0, -10.0, 0.0)
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 5.0
	burst.emitting = false
	get_tree().current_scene.add_child(burst)
	burst.global_position = global_position + Vector3(0.0, 0.4, 0.0)
	burst.emitting = true
	get_tree().create_timer(1.4).timeout.connect(burst.queue_free)
