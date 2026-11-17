extends Node

const WakeUIScene = preload("res://scenes/cutscene/wake_ui.tscn")
const DialogueScene = preload("res://scenes/ui/dialogue_box.tscn")
const Dialogues = preload("res://scripts/data/dialogues.gd")
const RuinsScript = preload("res://scripts/ruins.gd")
const PlayerScript = preload("res://scripts/player/player.gd")
const BlockIndex = preload("res://scripts/block_index.gd")

const PROMPT := "F: Wake up."
const GAIUS := "Gaius"
const FLY_TIME := 22.0
const FLY_START := 0.6
const FLY_SWEEP := 1.9
const FLY_RADIUS := 40.0
const FLY_CLOSE := 10.0
const FLY_HEIGHT := 16.0
const FLY_LOOK_DROP := 7.0
const GROUND_SPAN := 8.0
const GROUND_STEP := 4.0
const RISE_RATE := 2.2
const FADE_IN := 3.0
const FADE_OUT := 3.5
const SIT_DROP := 0.85
const SIT_WALL_LAYERS := 3
const STAND_TIME := 2.4
const HUD_LAYERS := ["hud_node", "ui", "minimap_node", "missions"]

var world
var player
var terrain
var ui
var box
var camera: Camera3D
var gaius
var hud_state: Dictionary = {}
var sit_cell := Vector2i.ZERO
var fly_y: float = 0.0
var fly_ready: bool = false
var fly_stamp: int = 0


func run(w, p, t, prologue_ui: Node) -> void:
	world = w
	player = p
	terrain = t
	Game.cutscene_active = true
	ui = WakeUIScene.instantiate()
	world.add_child(ui)
	prologue_ui.queue_free()
	_hide_hud()
	player.frozen = true
	player.held.visible = false
	_stage()
	_make_camera()
	var fly := create_tween()
	fly.set_parallel(true)
	fly.tween_method(_fly, 0.0, 1.0, FLY_TIME)
	fly.tween_property(ui.white, "modulate:a", 0.0, FADE_IN)
	fly.tween_property(ui.black, "modulate:a", 1.0, FADE_OUT).set_delay(FLY_TIME - FADE_OUT)
	await fly.finished
	camera.queue_free()
	await ui.show_prompt(PROMPT)
	while is_inside_tree() and not Input.is_physical_key_pressed(KEY_F):
		await get_tree().process_frame
	ui.set_eyes(0.0, 1.0)
	ui.eyes.visible = true
	ui.black.modulate.a = 0.0
	_sit()
	ui.prompt.modulate.a = 0.0
	await ui.tween_eyes(0.24, 1.0, 1.6)
	await get_tree().create_timer(0.9).timeout
	await ui.tween_eyes(0.0, 1.0, 0.55)
	await get_tree().create_timer(0.8).timeout
	ui.tween_eyes(1.0, 0.0, 2.2, 3.2)
	await get_tree().create_timer(2.4).timeout
	await _talk()
	_release()
	queue_free()


func _talk() -> void:
	box = DialogueScene.instantiate()
	world.add_child(box)
	box.line_event.connect(_on_event)
	await box.play(Dialogues.WAKE_UP, "wake")
	box.queue_free()


func _on_event(event_name: String) -> void:
	if event_name == "stand":
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(player.camera, "position", Vector3.ZERO, STAND_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(player.head, "rotation:x", 0.0, STAND_TIME)


func _stage() -> void:
	var core_pos: Vector3 = world.core.global_position
	var ox := floori(core_pos.x)
	var oz := floori(core_pos.z)
	var inner: int = RuinsScript.RADIUS - (RuinsScript.TOWER_SIZE - 1)
	sit_cell = Vector2i(ox + inner - 1, oz + inner + 1)
	var ground: int = terrain.surface_y(sit_cell.x, sit_cell.y)
	for z_shift in [-1, 0]:
		for layer in SIT_WALL_LAYERS:
			var cell := Vector3i(ox + inner, ground + layer, sit_cell.y + z_shift)
			if terrain.block_at(cell.x, cell.y, cell.z) == 0 and BlockIndex.at(cell) == null:
				world.restore_block("stone_brick", Vector3(cell.x + 0.5, cell.y + 0.5, cell.z + 0.5))
	player.global_position = _sit_position(0.0)
	player.velocity = Vector3.ZERO
	player.rotation.y = PI * 0.5
	player.head.rotation.x = -0.08
	_pose_gaius()


func _sit_position(dx: float) -> Vector3:
	var ground: int = terrain.surface_y(sit_cell.x, sit_cell.y)
	return Vector3(sit_cell.x + 0.5 + dx, float(ground) + PlayerScript.FEET_OFFSET + 0.05, sit_cell.y + 0.5)


func _pose_gaius() -> void:
	for troop in world.troops:
		if is_instance_valid(troop) and troop.display_name == GAIUS:
			gaius = troop
	if gaius == null and not world.troops.is_empty():
		gaius = world.troops[0]
		gaius.display_name = GAIUS
	if gaius == null:
		return
	var cx := sit_cell.x - 2
	var ground: int = terrain.surface_y(cx, sit_cell.y)
	gaius.path.clear()
	gaius.path_has_goal = false
	gaius.velocity = Vector3.ZERO
	gaius.global_position = Vector3(cx + 0.5, float(ground) + 0.1, sit_cell.y + 0.5)
	gaius._face(Vector3(1.0, 0.0, 0.0))
	gaius.set_physics_process(false)


func _sit() -> void:
	player.camera.position = Vector3(0.0, -SIT_DROP, 0.0)
	player.camera.make_current()


func _make_camera() -> void:
	camera = Camera3D.new()
	camera.fov = player.camera.fov
	camera.near = player.camera.near
	camera.far = player.camera.far
	world.add_child(camera)
	camera.make_current()
	_fly(0.0)


func _fly(t: float) -> void:
	var center: Vector3 = world.core.global_position
	var angle := FLY_START + FLY_SWEEP * t
	var radius := lerpf(FLY_RADIUS, FLY_CLOSE + 14.0, t)
	var pos := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	var goal := _ground_near(pos, center.y) + FLY_HEIGHT + sin(t * PI) * 3.0
	var now := Time.get_ticks_msec()
	if not fly_ready:
		fly_y = goal
		fly_ready = true
	else:
		var dt := clampf(float(now - fly_stamp) / 1000.0, 0.0, 0.1)
		fly_y = lerpf(fly_y, goal, 1.0 - exp(-RISE_RATE * dt))
	fly_stamp = now
	pos.y = fly_y
	camera.global_position = pos
	var ahead_angle := angle + 0.14
	var ahead := center + Vector3(cos(ahead_angle) * radius, 0.0, sin(ahead_angle) * radius)
	ahead.y = pos.y - FLY_LOOK_DROP
	var toward_core := center + Vector3(0.0, 2.0, 0.0)
	var target := ahead.lerp(toward_core, smoothstep(0.55, 1.0, t) * 0.55)
	camera.look_at(target)


func _ground_near(pos: Vector3, floor_y: float) -> float:
	var total := 0.0
	var peak := floor_y
	var count := 0
	var steps := int(GROUND_SPAN * 2.0 / GROUND_STEP)
	for i in range(steps + 1):
		for j in range(steps + 1):
			var h: float = terrain.height_at(pos.x - GROUND_SPAN + float(i) * GROUND_STEP, pos.z - GROUND_SPAN + float(j) * GROUND_STEP)
			total += h
			peak = maxf(peak, h)
			count += 1
	return maxf(lerpf(total / float(count), peak, 0.5), floor_y)


func _hide_hud() -> void:
	for key: String in HUD_LAYERS:
		var layer = world.get(key)
		if layer == null or not is_instance_valid(layer):
			continue
		hud_state[key] = layer.visible
		layer.visible = false


func _release() -> void:
	for key: String in hud_state:
		var layer = world.get(key)
		if layer != null and is_instance_valid(layer):
			layer.visible = hud_state[key]
	player.camera.position = Vector3.ZERO
	player.head.rotation.x = 0.0
	player.held.visible = true
	player.frozen = false
	if is_instance_valid(gaius):
		gaius.set_physics_process(true)
	ui.queue_free()
	Game.cutscene_active = false
