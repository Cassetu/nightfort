extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal stomp(power: float)

const ChipBurst = preload("res://scripts/chip_burst.gd")

const MODEL_SCALE := 2.2
const MAX_HEALTH := 1000.0
const HEALTH_FLOOR := 0.9
const HIT_SCALE := 1.1
const HEAL_RATE := 14.0
const HEAL_DELAY := 1.2
const SPEED := 2.6
const TURN_RATE := 1.1
const STOP_DISTANCE := 3.9
const ATTACK_RANGE := 9.0
const SLAM_RADIUS := 8.5
const SWIPE_REACH := 8.5
const SLAM_DAMAGE := 40
const SWIPE_DAMAGE := 30
const LETHAL_DAMAGE := 999
const LETHAL_AFTER := 40.0
const SLAM_IMPACT := 0.9
const SWIPE_IMPACT := 0.65
const SLAM_LENGTH := 1.5
const SWIPE_LENGTH := 1.2
const ROAR_TIME := 2.4
const RUSH_ROAR := 0.9
const RUSH_SPEED := 3.2
const RUSH_TURN := 3.0
const ATTACK_PAUSE := 0.8
const STEP_TIMES := [0.4, 1.2]
const KNOCKBACK := 9.0
const DUST := Color(0.3, 0.3, 0.34)
const BILE := Color(0.36, 0.2, 0.46)

var health: float = MAX_HEALTH
var target: Node3D
var state: String = "dormant"
var state_time: float = 0.0
var attack_name: String = ""
var attack_hit: bool = false
var next_attack: String = "slam"
var pause: float = 0.0
var since_hit: float = 99.0
var fight_time: float = 0.0
var last_step_pos: float = 0.0
var last_shown: int = -1
var frozen: bool = false
var rushing: bool = false
var punch: Tween
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $Anim


func _ready() -> void:
	add_to_group("boss")
	anim.play("idle")


func wake(who: Node3D) -> void:
	if state != "dormant":
		return
	target = who
	state = "roar"
	state_time = 0.0
	anim.play("roar")
	stomp.emit(2.2)
	health_changed.emit(health, MAX_HEALTH)


func rush() -> void:
	rushing = true
	fight_time = LETHAL_AFTER + 1.0


func freeze() -> void:
	frozen = true
	velocity.x = 0.0
	velocity.z = 0.0
	anim.speed_scale = 0.0


func take_damage(amount, from: Vector3 = Vector3.INF) -> void:
	if state == "dormant" or frozen or amount <= 0:
		return
	health = maxf(health - float(amount) * HIT_SCALE, MAX_HEALTH * HEALTH_FLOOR)
	since_hit = 0.0
	_report()
	if punch != null:
		punch.kill()
	model.scale = Vector3.ONE * MODEL_SCALE
	punch = create_tween()
	punch.tween_property(model, "scale", Vector3.ONE * MODEL_SCALE * 1.025, 0.05)
	punch.tween_property(model, "scale", Vector3.ONE * MODEL_SCALE, 0.12)
	var at := global_position + Vector3(0.0, 3.0, 0.0)
	if from.is_finite():
		var toward := from - global_position
		toward.y = 0.0
		at += toward.normalized() * 1.8
	ChipBurst.spawn(self, at, "gloom_flesh", BILE, 6, 0.1, 0.5, 70.0, 2.0, 4.5, 10.0)


func _report() -> void:
	var shown := int(health)
	if shown != last_shown:
		last_shown = shown
		health_changed.emit(health, MAX_HEALTH)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	if frozen or state == "dormant" or not is_instance_valid(target):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	fight_time += delta
	since_hit += delta
	if since_hit > HEAL_DELAY and health < MAX_HEALTH:
		health = minf(health + HEAL_RATE * delta, MAX_HEALTH)
		_report()
	match state:
		"roar":
			state_time += delta
			velocity.x = 0.0
			velocity.z = 0.0
			if state_time >= (RUSH_ROAR if rushing else ROAR_TIME):
				_enter_chase()
		"chase":
			_chase(delta)
		"attack":
			_attack(delta)
	move_and_slide()


func _enter_chase() -> void:
	state = "chase"
	state_time = 0.0
	last_step_pos = 0.0
	anim.play("idle")


func _flat_to_target() -> Vector3:
	var to := target.global_position - global_position
	to.y = 0.0
	return to


func _turn(delta: float) -> void:
	var to := _flat_to_target()
	if to.length() < 0.01:
		return
	var want := atan2(-to.x, -to.z)
	var turn_rate := TURN_RATE * (RUSH_TURN if rushing else 1.0)
	rotation.y += clampf(angle_difference(rotation.y, want), -turn_rate * delta, turn_rate * delta)


func _chase(delta: float) -> void:
	_turn(delta)
	var dist := _flat_to_target().length()
	var forward := -global_transform.basis.z
	var moving := dist > STOP_DISTANCE
	if moving:
		var pace := SPEED * (RUSH_SPEED if rushing else 1.0)
		velocity.x = forward.x * pace
		velocity.z = forward.z * pace
		if anim.current_animation != "walk":
			anim.play("walk")
			last_step_pos = 0.0
		_track_steps()
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if anim.current_animation != "idle":
			anim.play("idle")
	if pause > 0.0:
		pause -= delta
		return
	if dist <= ATTACK_RANGE:
		_begin_attack()


func _track_steps() -> void:
	var pos := anim.current_animation_position
	if pos < last_step_pos:
		last_step_pos = -0.01
	for i in STEP_TIMES.size():
		var t: float = STEP_TIMES[i]
		if last_step_pos < t and pos >= t:
			_step(i)
	last_step_pos = pos


func _step(index: int) -> void:
	var side := -1.0 if index == 0 else 1.0
	var foot := global_transform * Vector3(side * 1.2, 0.1, -0.5)
	var dist := target.global_position.distance_to(global_position)
	stomp.emit(clampf(1.0 - dist / 32.0, 0.12, 0.7))
	ChipBurst.spawn(self, foot, "bedrock", DUST, 7, 0.13, 0.7, 80.0, 1.5, 3.2, 10.0)


func _begin_attack() -> void:
	state = "attack"
	state_time = 0.0
	attack_hit = false
	attack_name = next_attack
	next_attack = "swipe" if attack_name == "slam" else "slam"
	velocity.x = 0.0
	velocity.z = 0.0
	anim.play(attack_name)


func _attack(delta: float) -> void:
	state_time += delta
	velocity.x = 0.0
	velocity.z = 0.0
	var impact := SLAM_IMPACT if attack_name == "slam" else SWIPE_IMPACT
	var length := SLAM_LENGTH if attack_name == "slam" else SWIPE_LENGTH
	if not attack_hit and state_time >= impact:
		attack_hit = true
		_impact()
	if state_time >= length:
		state = "chase"
		state_time = 0.0
		pause = ATTACK_PAUSE
		anim.play("idle")


func _impact() -> void:
	var forward := -global_transform.basis.z
	if attack_name == "slam":
		var center := global_position + forward * 4.5
		_shockwave(center)
		stomp.emit(1.6)
		ChipBurst.spawn(self, center + Vector3(0.0, 0.2, 0.0), "bedrock", DUST, 16, 0.18, 0.9, 85.0, 2.5, 6.0, 10.0)
		var to := target.global_position - center
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length() <= SLAM_RADIUS and target.is_on_floor() and absf(to.y) < 2.5:
			_hurt(SLAM_DAMAGE, flat.normalized())
	else:
		stomp.emit(0.9)
		var to := _flat_to_target()
		if to.length() <= SWIPE_REACH and to.normalized().dot(Vector3(forward.x, 0.0, forward.z).normalized()) > 0.2:
			_hurt(SWIPE_DAMAGE, to.normalized())


func _hurt(amount: int, dir: Vector3) -> void:
	if target.get("dead") == true:
		return
	var dmg := amount
	if fight_time > LETHAL_AFTER:
		dmg = LETHAL_DAMAGE
	target.take_damage(dmg, global_position)
	target.velocity = Vector3(dir.x * KNOCKBACK, 5.0, dir.z * KNOCKBACK)


func _shockwave(center: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.5, 0.3, 0.62, 0.6)
	mesh.material = mat
	var ring := MeshInstance3D.new()
	ring.mesh = mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(ring)
	ring.global_position = center + Vector3(0.0, 0.15, 0.0)
	ring.scale = Vector3(0.4, 1.0, 0.4)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(SLAM_RADIUS, 1.0, SLAM_RADIUS), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(ring.queue_free)
