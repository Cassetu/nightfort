extends CharacterBody3D

const GloomBake = preload("res://scripts/enemies/gloom_bake.gd")
const ChipBurst = preload("res://scripts/chip_burst.gd")
const BloodTerrain = preload("res://scripts/blood_terrain.gd")

const MAX_HEALTH := 16
const SPEED := 3.1
const WAKE_RANGE := 26.0
const LEASH := 34.0
const REACH := 1.9
const DAMAGE := 15
const COOLDOWN := 1.3
const TURN := 9.0
const BILE := Color(0.36, 0.2, 0.46)
const RETARGET := 0.35

static var pressure: float = 0.0

var health: float = MAX_HEALTH
var dying: bool = false
var awake: bool = false
var target
var cooldown: float = 0.0
var swing_left: bool = false
var knock := Vector3.ZERO
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed_mult: float = 1.0
var retarget: float = 0.0

@onready var body: Node3D = $Body
@onready var anim: AnimationPlayer = $Anim


func _ready() -> void:
	GloomBake.bake(self)
	add_to_group("enemy")
	add_to_group("pit_gloom")
	collision_layer = 2
	collision_mask = 1
	speed_mult = randf_range(0.9, 1.1)
	cooldown = randf_range(0.2, 0.8)
	health = MAX_HEALTH * (1.0 + pressure * 0.5)
	anim.play("idle")


func take_damage(amount, from: Vector3 = Vector3.INF) -> void:
	if dying or amount <= 0:
		return
	health -= float(amount)
	awake = true
	if from.is_finite():
		var away := global_position - from
		away.y = 0.0
		knock = away.normalized() * 4.0
	ChipBurst.spawn(self, global_position + Vector3(0.0, 1.0, 0.0), "gloom_flesh", BILE, 6, 0.1, 0.5, 80.0, 2.0, 4.5, 10.0)
	if health <= 0.0:
		_die()


func _die() -> void:
	dying = true
	remove_from_group("enemy")
	remove_from_group("pit_gloom")
	collision_layer = 0
	ChipBurst.spawn(self, global_position + Vector3(0.0, 1.0, 0.0), "gloom_flesh", BILE, 14, 0.14, 0.9, 180.0, 3.0, 6.5, 14.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(body, "rotation:x", -1.4, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(body, "position:y", -0.7, 0.5)
	await tween.finished
	if not is_inside_tree():
		return
	await get_tree().create_timer(1.2).timeout
	queue_free()


func _nearest_ally() -> Node3D:
	var best: Node3D = null
	var best_d := WAKE_RANGE * WAKE_RANGE
	var my_band: int = BloodTerrain.band(global_position)
	for a in get_tree().get_nodes_in_group("ally_unit"):
		if not is_instance_valid(a) or BloodTerrain.band(a.global_position) != my_band:
			continue
		var d := global_position.distance_squared_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _physics_process(delta: float) -> void:
	if dying:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	cooldown = maxf(cooldown - delta, 0.0)
	knock = knock.move_toward(Vector3.ZERO, 14.0 * delta)
	var move := Vector3.ZERO
	retarget -= delta
	if retarget <= 0.0 or not is_instance_valid(target):
		retarget = RETARGET + randf() * 0.15
		target = _nearest_ally()
	if target != null:
		awake = true
	if awake and target != null:
		var to = target.global_position - global_position
		to.y = 0.0
		var dist = to.length()
		var dir = to / maxf(dist, 0.001)
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(TURN * delta, 1.0))
		if dist > REACH:
			move = dir * SPEED * speed_mult * (1.0 + pressure * 0.3)
			if anim.current_animation != "walk":
				anim.play("walk")
		else:
			if cooldown <= 0.0:
				_strike()
			elif anim.current_animation == "walk":
				anim.play("idle")
	elif anim.current_animation != "idle" and not anim.current_animation.begins_with("swipe"):
		anim.play("idle")
	velocity.x = move.x + knock.x
	velocity.z = move.z + knock.z
	move_and_slide()


func _strike() -> void:
	cooldown = COOLDOWN
	swing_left = not swing_left
	anim.play("swipe_l" if swing_left else "swipe_r")
	await get_tree().create_timer(0.3).timeout
	if dying or not is_inside_tree() or not is_instance_valid(target):
		return
	if target.global_position.distance_to(global_position) <= REACH + 0.9:
		target.take_damage(roundi(DAMAGE * (1.0 + pressure * 0.4)), global_position)
