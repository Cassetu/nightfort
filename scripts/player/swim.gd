extends RefCounted

const ChipBurst = preload("res://scripts/chip_burst.gd")
const Sfx = preload("res://scripts/core/sfx.gd")
const OVERLAY_SHADER = preload("res://resources/underwater.gdshader")

const FEET_OFFSET := 0.85
const BODY_HEIGHT := 1.8
const TIGHT_FEET_OFFSET := 0.4
const TIGHT_HEIGHT := 1.0
const SPRINT_SPEED := 5.0
const TAP_WINDOW_MS := 300
const SPRINT_MIN_SUBMERGE := 0.9
const ENTER_DEPTH := 0.55
const EXIT_DEPTH := 0.4
const SWIM_SPEED := 3.0
const RISE_SPEED := 3.4
const DIVE_SPEED := 2.8
const SINK_SPEED := 0.9
const CLIMB_OUT_SPEED := 5.4
const ACCEL := 16.0
const WADE_SLOW := 0.68
const FLOAT_EYE_ABOVE := 0.12
const STROKE_GAP := 1.8
const SPLASH_MIN_SPEED := 3.0
const OVERLAY_FADE := 7.0
const WATER_TILE_COLOR := Color(0.62, 0.8, 0.86, 0.85)

var player: CharacterBody3D
var terrain: Node
var layer: CanvasLayer
var rect: ColorRect
var swimming: bool = false
var head_under: bool = false
var submerged: float = 0.0
var surface: float = -INF
var stroke_clock: float = 0.0
var overlay_alpha: float = 0.0
var sprinting: bool = false
var last_tap_ms: int = -10000


func _init(p: CharacterBody3D) -> void:
	player = p
	layer = CanvasLayer.new()
	layer.layer = 4
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = OVERLAY_SHADER
	rect.material = mat
	rect.modulate.a = 0.0
	rect.visible = false
	layer.add_child(rect)
	player.add_child(layer)


func wade_factor() -> float:
	if swimming:
		return 1.0
	return lerpf(1.0, WADE_SLOW, clampf(submerged * 1.6, 0.0, 1.0))


func update(delta: float, eye_y: float) -> void:
	if terrain == null or not is_instance_valid(terrain):
		terrain = player.get_tree().get_first_node_in_group("terrain")
		if terrain == null:
			return
	var pos := player.global_position
	surface = terrain.water_surface_at(pos.x, pos.z)
	var was_swimming := swimming
	var was_under := head_under
	if surface == -INF:
		submerged = 0.0
		swimming = false
		head_under = false
	else:
		var feet := TIGHT_FEET_OFFSET if sprinting else FEET_OFFSET
		var body := TIGHT_HEIGHT if sprinting else BODY_HEIGHT
		submerged = clampf((surface - (pos.y - feet)) / body, 0.0, 1.0)
		swimming = submerged >= (EXIT_DEPTH if was_swimming else ENTER_DEPTH)
		head_under = eye_y < surface - 0.04
	_sprint_check()
	if swimming and not was_swimming:
		_entered()
	elif was_swimming and not swimming:
		_left()
	elif head_under != was_under and swimming:
		Sfx.play(player, "water_small", Vector3(pos.x, surface, pos.z), -6.0)
	_overlay(delta)


func _sprint_check() -> void:
	if sprinting:
		if not swimming or not head_under or not Input.is_action_pressed("ui_up"):
			sprinting = false
		return
	if not swimming or not Input.is_action_just_pressed("ui_up"):
		return
	var now := Time.get_ticks_msec()
	if now - last_tap_ms <= TAP_WINDOW_MS and head_under and submerged >= SPRINT_MIN_SUBMERGE:
		sprinting = true
		last_tap_ms = -10000
		stroke_clock = STROKE_GAP
		Sfx.play(player, "water_small", player.global_position, -6.0)
	else:
		last_tap_ms = now


func clear() -> void:
	sprinting = false
	if swimming or head_under or overlay_alpha > 0.0:
		swimming = false
		head_under = false
		submerged = 0.0
		overlay_alpha = 0.0
		rect.modulate.a = 0.0
		rect.visible = false
		_audio(false)


func _entered() -> void:
	var pos := player.global_position
	var speed := absf(player.velocity.y)
	player.velocity.y *= 0.3
	player.velocity.x *= 0.6
	player.velocity.z *= 0.6
	var point := Vector3(pos.x, surface, pos.z)
	if speed >= SPLASH_MIN_SPEED:
		Sfx.play(player, "water_splash", point, -2.0)
		ChipBurst.spawn(player, point, "", WATER_TILE_COLOR, 16, 0.09, 0.7, 60.0, 2.0, 5.0, 11.0)
	else:
		Sfx.play(player, "water_small", point, -4.0)
		ChipBurst.spawn(player, point, "", WATER_TILE_COLOR, 6, 0.07, 0.5, 70.0, 1.0, 2.4, 9.0)


func _left() -> void:
	var pos := player.global_position
	var point := Vector3(pos.x, maxf(surface, pos.y - FEET_OFFSET), pos.z)
	Sfx.play(player, "water_small", point, -5.0)
	ChipBurst.spawn(player, point, "", WATER_TILE_COLOR, 5, 0.06, 0.45, 65.0, 1.0, 2.0, 9.0)


func _overlay(delta: float) -> void:
	overlay_alpha = move_toward(overlay_alpha, 1.0 if head_under else 0.0, delta * OVERLAY_FADE)
	rect.visible = overlay_alpha > 0.001
	rect.modulate.a = overlay_alpha
	_audio(head_under)


func _audio(on: bool) -> void:
	var manager = player.get_tree().get_first_node_in_group("audio_manager")
	if manager != null:
		manager.set_underwater(on)


func move(delta: float, input_dir: Vector2, camera: Camera3D, rising: bool, diving: bool) -> void:
	var pos := player.global_position
	if sprinting:
		var look := -camera.global_transform.basis.z
		player.velocity = player.velocity.move_toward(look * SPRINT_SPEED * player.slow, ACCEL * delta)
		stroke_clock += delta
		if stroke_clock >= STROKE_GAP:
			stroke_clock = 0.0
			Sfx.play(player, "water_stroke", pos, -7.0)
		return
	var yaw_basis := player.global_transform.basis
	var dir: Vector3
	if head_under:
		var cb := camera.global_transform.basis
		dir = cb.x * input_dir.x + cb.z * input_dir.y
	else:
		dir = yaw_basis.x * input_dir.x + yaw_basis.z * input_dir.y
		dir.y = 0.0
	var target := Vector3.ZERO
	if input_dir != Vector2.ZERO:
		target = dir.normalized() * SWIM_SPEED
	target.x *= player.slow
	target.z *= player.slow
	var float_y = surface + FLOAT_EYE_ABOVE - player.head.position.y
	if rising:
		if player.is_on_wall() and pos.y - FEET_OFFSET > surface - 1.6:
			target.y = CLIMB_OUT_SPEED
		elif head_under or pos.y < float_y:
			target.y = RISE_SPEED
		else:
			target.y = clampf((float_y - pos.y) * 6.0, -1.0, 1.0)
	elif diving:
		target.y = -DIVE_SPEED
	elif head_under:
		if input_dir == Vector2.ZERO:
			target.y = -SINK_SPEED
	else:
		target.y = clampf((float_y - pos.y) * 5.0, -SINK_SPEED, 1.6)
	player.velocity = player.velocity.move_toward(target, ACCEL * delta)
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 1.2 or absf(player.velocity.y) > 1.5
	if moving:
		stroke_clock += delta
		if stroke_clock >= STROKE_GAP:
			stroke_clock = 0.0
			Sfx.play(player, "water_stroke", pos, -7.0)
	else:
		stroke_clock = STROKE_GAP * 0.6
