extends Node

const CaveScript = preload("res://scripts/prologue_cave.gd")
const UIScene = preload("res://scenes/prologue_ui.tscn")
const BossScene = preload("res://scenes/bile_dreadnaught.tscn")
const BlockIndex = preload("res://scripts/block_index.gd")
const PitScript = preload("res://scripts/blood_world.gd")
const LoadingScene = preload("res://scenes/ui/loading_screen.tscn")

const ORIGIN := Vector3(3000.0, -400.0, 3000.0)
const PIT_ORIGIN := Vector3(-3000.0, -400.0, 3000.0)
const QUIET := ["Sun", "WaveSpawner", "FlowField", "Weather", "RoofMap", "Audio", "WetSurfaces", "Birds", "GloomFog", "WildSpawner", "Stability", "Territory"]
const GROUPED := ["Stability", "Territory"]
const SLOT_ITEMS := [
	{"id": "iron_sword", "count": 1},
	{"id": "iron_pickaxe", "count": 1},
	{"id": "iron_axe", "count": 1},
	{"id": "iron_shovel", "count": 1},
	{"id": "stone", "count": 3},
	{"id": "bow", "count": 1},
]
const ARROWS := 60
const ARMOR := {"head": "iron_helmet", "chest": "iron_chestplate", "legs": "iron_leggings", "feet": "iron_boots", "bauble": "lantern"}
const STONE_SLOT := 4
const PICKAXE_SLOT := 1
const LANDING_LINES := [
	["Odrick", "There you are at last."],
	["You", "Are the troops ready?"],
	["Odrick", "They fight on your command."],
	["Odrick", "We will keep you safe."],
	["You", "Worry more of the heart, and less of me."],
	["", "Odrick nods, and rejoins the ranks."],
]
const LEAVE_LINE := "I can't abandon the fight now."
const COMMAND_PROMPT := "F: Command Attack"
const FALL_TRIGGER := 9.0
const LEAVE_RADIUS := 235.0
const BACKUP_DISTANCE := 22.0
const HEAL_INTERVAL := 0.5
const HEAL_AMOUNT := 2.5
const FALL_HEIGHT := 14.0
const FALL_DROP_TIME := 1.5
const BOSS_DISTANCE := 26.0
const DOOM_SPAWN_DISTANCE := 9.0
const LINES := [
	["You", "Hello?.."],
	["???", "Hush. You cannot perish now."],
	["You", "Am I… Dead?"],
	["???", "Not for long. Wake, warrior, and fight the darkness."],
	["You", "Wait!"],
]
const LIGHT_LINE := 3
const LIGHT_TIME := 9.0
const FALL_TIME := 1.7
const SHAKE_DECAY := 2.2
const SHAKE_SCALE := 0.07
const CHAMBER_Z := 30.0
const STAIR_TOP_Y := 12.5
const LEDGE_Y := 4.5

var world
var player
var terrain
var ui
var root: Node3D
var cave: Dictionary = {}
var boss
var pit
var origin: Vector3 = ORIGIN
var start_position := Vector3.ZERO
var start_yaw: float = 0.0
var saved_modes: Dictionary = {}
var env: Environment
var shake: float = 0.0
var died_flag: bool = false
var boss_awake: bool = false
var doomed: bool = false
var running: bool = false
var swing_pressed: bool = false


func begin(w) -> void:
	world = w
	player = w.player
	terrain = w.terrain
	ui = UIScene.instantiate()
	world.add_child(ui)
	player.frozen = true
	world.intro_playing = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	ui.choice_made.connect(_on_choice)
	ui.show_choice()


func _on_choice(play: bool) -> void:
	ui.hide_choice()
	if play:
		_run()
	else:
		_skip()


func _skip() -> void:
	ui.black.modulate.a = 1.0
	player.frozen = false
	world.intro_playing = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	await ui.fade_black(0.0, 1.6)
	ui.queue_free()
	queue_free()


func _wait(seconds: float) -> bool:
	if not is_inside_tree():
		return false
	await get_tree().create_timer(seconds).timeout
	return is_inside_tree()


var guard_fall: bool = false


func _until(check: Callable) -> bool:
	while is_inside_tree():
		if check.call():
			return true
		if guard_fall and player != null and not cave.is_empty() and player.global_position.y < origin.y - 40.0:
			player.global_position = cave["spawn"]
			player.velocity = Vector3.ZERO
		await get_tree().process_frame
	return false


func _run() -> void:
	running = true
	Game.prologue_active = true
	await ui.fade_black(1.0, 0.7)
	_enter()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _wait(0.4)
	guard_fall = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	player.frozen = false
	world.intro_playing = false
	await ui.fade_black(0.0, 1.8)
	if not await _tutorial():
		return
	guard_fall = false
	if not await _crack():
		return
	if not await _descend():
		return
	if not await _landing_dialogue():
		return
	if not await _command():
		return
	if not await _siege():
		return
	if not await _emerge():
		return
	if not await _death():
		return
	if not await _dialogue():
		return
	await _finale()


func _enter() -> void:
	start_position = player.global_position
	start_yaw = player.rotation.y
	for node_name: String in QUIET:
		var node = world.get_node_or_null(node_name)
		if node == null:
			continue
		saved_modes[node_name] = node.process_mode
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if GROUPED.has(node_name):
			node.remove_from_group(node_name.to_lower())
	terrain.player = null
	world.sun.visible = false
	if world.sun.moon != null:
		world.sun.moon.visible = false
	env = _make_environment()
	player.camera.environment = env
	root = Node3D.new()
	root.name = "PrologueArea"
	world.add_child(root)
	cave = CaveScript.build(root, world, origin)
	world.minimap_node.set_blank(true)
	world.core.marker_label.visible = false
	world.core.set_process(false)
	world.missions.visible = false
	world.ui.set_prologue(true)
	world.hud_node.get_node("TimeBar").visible = false
	world.hud_node.get_node("Counts").visible = false
	_loadout()
	player.global_position = cave["spawn"]
	player.rotation.y = PI
	player.head.rotation.x = 0.0
	player.velocity = Vector3.ZERO
	player.died.connect(_on_died)


func _make_environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.0, 0.0, 0.0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.4, 0.55)
	e.ambient_light_energy = 0.22
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.02, 0.02, 0.035)
	e.fog_density = 0.012
	return e


func _loadout() -> void:
	Inventory.reset()
	for i in SLOT_ITEMS.size():
		Inventory.slots[i] = SLOT_ITEMS[i].duplicate()
	for slot_name: String in ARMOR:
		Inventory.equipment[slot_name] = {"id": ARMOR[slot_name], "count": 1}
	Inventory.add_item("arrow", ARROWS)
	Inventory.selected = 0
	Inventory.changed.emit()
	Inventory.selection_changed.emit(0)


func _step(text: String, check: Callable) -> bool:
	ui.set_tutorial(text)
	if not await _until(check):
		return false
	await ui.complete_tutorial()
	return true


func _tutorial() -> bool:
	var p0: Vector3 = player.global_position
	if not await _step("WASD: Move", func() -> bool: return player.global_position.distance_to(p0) > 3.0):
		return false
	if not await _step("Shift: Crouch", func() -> bool: return player.crouching):
		return false
	if not await _step("Space: Jump", func() -> bool: return player.velocity.y > 2.0):
		return false
	if not await _step("Left Click: Swing", func() -> bool: return Input.is_action_just_pressed("mine")):
		return false
	if not await _step("5: Hold Stone", func() -> bool: return Inventory.selected == STONE_SLOT):
		return false
	if not await _step("Right Click: Place", func() -> bool: return Inventory.get_count("stone") <= 2):
		return false
	if not await _step("Climb", func() -> bool: return player.global_position.y > origin.y + LEDGE_Y):
		return false
	if not await _until(func() -> bool: return player.global_position.z > origin.z + CHAMBER_Z):
		return false
	if not await _step("2: Hold Pickaxe", func() -> bool: return Inventory.selected == PICKAXE_SLOT):
		return false
	if not await _step("Hold Left Click: Mine", func() -> bool: return _mined() > 0):
		return false
	ui.set_tutorial("Climb")
	if not await _until(func() -> bool: return player.global_position.y > origin.y + STAIR_TOP_Y):
		return false
	ui.clear_tutorial()
	return true


func _mined() -> int:
	var gone := 0
	for b in cave["stones"]:
		if not is_instance_valid(b) or b.dying:
			gone += 1
	return gone


func _crack() -> bool:
	var crack: Vector3 = cave["crack"]
	return await _until(func() -> bool:
		return player.global_position.y < crack.y - FALL_TRIGGER)


func _clear_cave() -> void:
	for b in BlockIndex.list.duplicate():
		if is_instance_valid(b) and b.global_position.y < origin.y + 200.0:
			b.queue_free()
	for d in get_tree().get_nodes_in_group("item_drop"):
		if is_instance_valid(d) and d.global_position.y < origin.y + 200.0:
			d.queue_free()
	if is_instance_valid(root):
		root.queue_free()


func _descend() -> bool:
	await ui.fade_black(1.0, 1.0)
	if not is_inside_tree():
		return false
	player.frozen = true
	_clear_cave()
	var loading = LoadingScene.instantiate()
	add_child(loading)
	loading.begin(null, player)
	await get_tree().process_frame
	await get_tree().process_frame
	pit = PitScript.new()
	pit.build(world, player, PIT_ORIGIN)
	player.camera.environment = pit.env
	player.global_position = pit.landing
	player.rotation.y = PI
	player.head.rotation.x = 0.0
	player.velocity = Vector3.ZERO
	pit.army_changed.connect(ui.set_army)
	await loading.finished
	if not is_inside_tree():
		return false
	var cam: Camera3D = player.camera
	var base := cam.position
	cam.position = base + Vector3(0.0, FALL_HEIGHT, 0.0)
	await _wait(0.5)
	if not is_inside_tree():
		return false
	ui.fade_black(0.0, 1.0)
	var tween := create_tween()
	tween.tween_property(cam, "position", base, FALL_DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	shake = 2.4
	var dip := create_tween()
	dip.tween_property(cam, "position", base + Vector3(0.0, -0.35, 0.0), 0.1)
	dip.tween_property(cam, "position", base, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return await _wait(1.4)


func _landing_dialogue() -> bool:
	for i in LANDING_LINES.size():
		if not is_inside_tree():
			return false
		if i == LANDING_LINES.size() - 1:
			pit.odrick_rejoin()
		await ui.say(LANDING_LINES[i][0], LANDING_LINES[i][1])
	await ui.hide_dialogue()
	return await _until(func() -> bool: return not pit.odrick_walking())


func _command() -> bool:
	ui.show_prompt(COMMAND_PROMPT)
	if not await _until(func() -> bool: return Input.is_physical_key_pressed(KEY_F)):
		return false
	ui.hide_prompt()
	pit.command()
	ui.show_army(pit.alive_count())
	if not await _until(func() -> bool: return not Input.is_physical_key_pressed(KEY_F)):
		return false
	player.frozen = false
	return true


func _siege() -> bool:
	var heal_timer := 0.0
	var leaving := false
	while is_inside_tree():
		await get_tree().process_frame
		var delta := get_process_delta_time()
		if pit.alive_count() <= 0:
			return true
		if (not player.dead and pit.doom_reached(player.global_position)) or pit.army_breached():
			doomed = true
			return true
		heal_timer += delta
		if heal_timer >= HEAL_INTERVAL:
			heal_timer = 0.0
			if not player.dead and player.health < float(player.max_health):
				player.heal(HEAL_AMOUNT)
				ui.pulse_heal()
		if not leaving and not player.dead and pit.distance_from_heart(player.global_position) > LEAVE_RADIUS:
			leaving = true
			await _turn_back()
			leaving = false
	return false


func _turn_back() -> void:
	player.frozen = true
	player.velocity = Vector3.ZERO
	await ui.say("You", LEAVE_LINE)
	await ui.hide_dialogue()
	var from: Vector3 = player.global_position
	var toward: Vector3 = pit.heart_position - from
	toward.y = 0.0
	var to: Vector3 = from + toward.normalized() * BACKUP_DISTANCE
	to.y = pit.origin.y + pit.gen.height(to.x - pit.origin.x, to.z - pit.origin.z) + 0.4
	var tween := create_tween()
	tween.tween_property(player, "global_position", to, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	player.velocity = Vector3.ZERO
	player.frozen = false


func _emerge() -> bool:
	ui.hide_army()
	shake = 3.0
	pit.pulse_heart(9.0)
	var from: Vector3 = player.global_position
	var to_heart: Vector3 = pit.heart_position - from
	to_heart.y = 0.0
	var at: Vector3 = pit.heart_position
	if doomed:
		pit.wipe_army()
		if not await _wait(0.8):
			return false
		at = from + to_heart.normalized() * DOOM_SPAWN_DISTANCE
		at.y = pit.origin.y + pit.gen.height(at.x - pit.origin.x, at.z - pit.origin.z) + 0.6
	else:
		if not await _wait(1.6):
			return false
		if to_heart.length() > 40.0:
			at = from + to_heart.normalized() * BOSS_DISTANCE
			at.y = pit.origin.y + pit.gen.height(at.x - pit.origin.x, at.z - pit.origin.z) + 0.6
		else:
			at += Vector3(0.0, 6.0, 0.0)
	boss = BossScene.instantiate()
	world.add_child(boss)
	boss.global_position = at
	boss.stomp.connect(_on_stomp)
	boss.health_changed.connect(ui.set_boss)
	boss.wake(player)
	if doomed:
		boss.rush()
	boss_awake = true
	ui.show_boss()
	return await _until(func() -> bool: return died_flag)


func _on_died() -> void:
	if boss_awake:
		died_flag = true
		return
	if is_instance_valid(pit):
		player.respawn(pit.landing)
	else:
		player.respawn(cave["spawn"])


func _on_stomp(power: float) -> void:
	shake = maxf(shake, power)


func _process(delta: float) -> void:
	if not running or not is_instance_valid(player):
		return
	var cam: Camera3D = player.camera
	if shake > 0.001 and not died_flag:
		cam.h_offset = randf_range(-1.0, 1.0) * shake * SHAKE_SCALE
		cam.v_offset = randf_range(-1.0, 1.0) * shake * SHAKE_SCALE
		shake = move_toward(shake, 0.0, delta * SHAKE_DECAY)
	elif cam.h_offset != 0.0 or cam.v_offset != 0.0:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func _fade_targets() -> Array:
	var out: Array = []
	for child in world.hud_node.get_children():
		if child is Control:
			out.append(child)
	out.append(world.ui.get_node("UI/PlayerBar"))
	out.append(world.minimap_node.get_node("Root"))
	return out


func _death() -> bool:
	boss.freeze()
	ui.hide_boss()
	ui.hide_army()
	player.held.visible = false
	var cam: Camera3D = player.camera
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(cam, "position", cam.position + Vector3(0.0, -1.3, 1.1), FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(cam, "rotation:x", cam.rotation.x + 1.25, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(cam, "rotation:z", 0.35, FALL_TIME)
	for c: Control in _fade_targets():
		tween.tween_property(c, "modulate:a", 0.0, 1.0)
	ui.show_red(1.0)
	await tween.finished
	if not is_inside_tree():
		return false
	await ui.blur_out(2.0)
	ui.hide_red(0.8)
	return await _wait(0.8)


func _dialogue() -> bool:
	await ui.show_orb()
	await _wait(0.6)
	for i in LINES.size():
		if not is_inside_tree():
			return false
		if i == LIGHT_LINE:
			ui.grow_light(LIGHT_TIME)
		await ui.say(LINES[i][0], LINES[i][1])
	await ui.hide_dialogue()
	await ui.finish_light()
	return true


func _finale() -> void:
	await _wait(1.2)
	await ui.show_title(2.6)
	await _wait(2.2)
	await ui.hide_title(0.9)
	_exit()
	await _wait(0.5)
	await ui.fade_white_out(2.8)
	ui.queue_free()
	queue_free()


func _exit() -> void:
	ui.clear_layers()
	if is_instance_valid(boss):
		boss.queue_free()
	_clear_cave()
	if is_instance_valid(pit):
		pit.queue_free()
	for node_name: String in saved_modes:
		var node = world.get_node_or_null(node_name)
		if node == null:
			continue
		node.process_mode = saved_modes[node_name]
		if GROUPED.has(node_name):
			node.add_to_group(node_name.to_lower())
	var cam: Camera3D = player.camera
	cam.environment = null
	cam.position = Vector3.ZERO
	cam.rotation = Vector3.ZERO
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	player.held.visible = true
	for c: Control in _fade_targets():
		c.modulate.a = 1.0
	world.sun.visible = true
	if world.sun.moon != null:
		world.sun.moon.visible = true
	terrain.player = player
	Inventory.reset()
	world.missions.visible = true
	world.missions.import_state({"done": 0})
	world.minimap_node.set_blank(false)
	world.core.set_process(true)
	world.ui.set_prologue(false)
	world.hud_node.get_node("TimeBar").visible = true
	world.hud_node.get_node("Counts").visible = true
	player.died.disconnect(_on_died)
	player.respawn(start_position)
	player.rotation.y = start_yaw
	player.head.rotation.x = 0.0
	player.frozen = false
	Game.prologue_active = false
	running = false


func _exit_tree() -> void:
	Game.prologue_active = false
