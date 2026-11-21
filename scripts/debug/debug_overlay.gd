extends CanvasLayer

const BlockIndex = preload("res://scripts/block_index.gd")
const HISTORY: int = 150
const INTERVAL: float = 0.25
const BUDGET_MS: float = 16.7
const GRAPH_MAX_MS: float = 33.3
const TIME_STEP: float = 0.125
const STATE_NAMES: PackedStringArray = ["Clear", "Cloudy", "Rain", "Fog", "Storm"]
const ACTION_KEYS: Array[int] = [KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10]

@onready var root: Control = $Root
@onready var text: Label = %Text
@onready var graph: Control = %Graph

var world
var terrain
var player
var frames: PackedFloat32Array = PackedFloat32Array()
var timer: float = 0.0
var key_was_down: bool = false
var held: Dictionary = {}
var god: bool = false
var last_action: String = "-"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	graph.draw.connect(_draw_graph)


func setup(w, p) -> void:
	world = w
	player = p
	terrain = w.terrain


func _toggle() -> void:
	root.visible = not root.visible
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), root.visible)


func _process(delta: float) -> void:
	var down: bool = Input.is_physical_key_pressed(KEY_F3)
	if down and not key_was_down:
		_toggle()
	key_was_down = down
	_poll_actions()
	if god and is_instance_valid(player) and not player.dead:
		player.health = float(player.max_health)
	if not root.visible:
		return
	frames.append(delta * 1000.0)
	if frames.size() > HISTORY:
		frames.remove_at(0)
	graph.queue_redraw()
	timer -= delta
	if timer > 0.0:
		return
	timer = INTERVAL
	text.text = _report()


func _poll_actions() -> void:
	for key in ACTION_KEYS:
		var down: bool = Input.is_physical_key_pressed(key)
		var was: bool = bool(held.get(key, false))
		held[key] = down
		if down and not was and root.visible:
			_run_action(key)


func _run_action(key: int) -> void:
	match key:
		KEY_F4:
			_cycle_weather()
		KEY_F5:
			_skip_time()
		KEY_F6:
			_visit("NorthFortress")
		KEY_F7:
			_visit("SouthFortress")
		KEY_F8:
			_refurnish()
		KEY_F9:
			god = not god
			last_action = "God On" if god else "God Off"
		KEY_F10:
			_give_kit()


func _weather() -> Node:
	if not is_instance_valid(world):
		return null
	return world.get_node_or_null("Weather")


func _cycle_weather() -> void:
	var w: Node = _weather()
	if w == null:
		return
	w.state = (int(w.state) + 1) % STATE_NAMES.size()
	w.state_left = 600.0
	last_action = "Weather %s" % STATE_NAMES[w.state]


func _skip_time() -> void:
	if not is_instance_valid(world) or world.sun == null:
		return
	world.sun.rotate_x(TAU * TIME_STEP)
	world.sun.day_phase = wrapf(world.sun.day_phase + TIME_STEP, 0.0, 1.0)
	last_action = "Time Skipped"


func _visit(village_name: String) -> void:
	if not is_instance_valid(world) or not is_instance_valid(player):
		return
	var village: Node = world.get_node_or_null(village_name)
	if village == null:
		last_action = "No %s" % village_name
		return
	var c: Vector3 = village.center
	player.global_position = Vector3(c.x, c.y + 3.0, c.z)
	player.velocity = Vector3.ZERO
	last_action = "Went To %s" % village_name.replace("Fortress", "")


func _refurnish() -> void:
	if not is_instance_valid(world):
		return
	world._furnish_villages()
	last_action = "Villages Furnished"


func _give_kit() -> void:
	for id in Inventory.ITEMS:
		var item: Dictionary = Inventory.ITEMS[id]
		var amount: int = 64 if str(item.get("kind", "")) == "block" else 1
		Inventory.add_item(str(id), amount)
	last_action = "Kit Given"


func _report() -> String:
	var vp: RID = get_viewport().get_viewport_rid()
	var avg: float = 0.0
	var worst: float = 0.0
	for ms in frames:
		avg += ms
		worst = maxf(worst, ms)
	avg /= float(maxi(frames.size(), 1))
	var cpu: float = RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
	var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("FPS %d   Avg %.1f ms   Worst %.1f ms" % [Engine.get_frames_per_second(), avg, worst])
	lines.append("Script %.1f ms   Physics %.1f ms" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	lines.append("Render CPU %.1f ms   GPU %.1f ms" % [cpu, gpu])
	lines.append("Draws %d   Tris %dk   Objects %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	lines.append("Video %.0f MB   Memory %.0f MB" % [Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	lines.append("Nodes %d   Orphans %d" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	lines.append("Bodies %d   Pairs %d" % [Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)])
	lines.append(_terrain_line())
	lines.append(_world_line())
	lines.append(_player_line())
	lines.append(_tools_line())
	return "\n".join(lines)


func _terrain_line() -> String:
	if not is_instance_valid(terrain):
		return "Terrain -"
	var solid: int = 0
	var objects: int = 0
	var real: int = 0
	var far: int = 0
	for chunk in terrain.chunks.values():
		if chunk.body != null:
			solid += 1
		if chunk.objects != null:
			objects += 1
			if chunk.trees_real:
				real += 1
			else:
				far += 1
	return "Chunks %d   Solid %d   Objects %d\nTrees real %d   Far %d\nQueue %d   Wants %d   View %d" % [terrain.chunks.size(), solid, objects, real, far, terrain.requested.size(), terrain.wants.size() - terrain.want_index, terrain.view_distance]


func _world_line() -> String:
	var tree: SceneTree = get_tree()
	var lit: int = 0
	var torches: Array = tree.get_nodes_in_group("torch")
	for t in torches:
		if is_instance_valid(t) and t.light != null and t.light.shadow_enabled:
			lit += 1
	return "Blocks %d   Torches %d   Shadowed %d\nGloom %d   Wild %d   Resources %d" % [BlockIndex.list.size(), torches.size(), lit, tree.get_node_count_in_group("enemy"), tree.get_node_count_in_group("wild_gloom"), tree.get_node_count_in_group("resource")]


func _tools_line() -> String:
	var w: Node = _weather()
	var weather_name: String = "-"
	var wet: float = 0.0
	if w != null:
		weather_name = STATE_NAMES[int(w.state)]
		wet = w.wet
	return "Weather %s   Wet %.2f   God %s\nLast %s" % [weather_name, wet, "On" if god else "Off", last_action]


func _player_line() -> String:
	if not is_instance_valid(player):
		return "Player -"
	var p: Vector3 = player.global_position
	var cx: int = floori(p.x / 16.0)
	var cz: int = floori(p.z / 16.0)
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var day: float = 0.0
	if is_instance_valid(world) and world.sun != null:
		day = world.sun.day_phase
	return "Pos %.1f %.1f %.1f\nChunk %d %d   Speed %.1f\nDay %.2f   Mode %s" % [p.x, p.y, p.z, cx, cz, speed, day, Game.gamemode]


func _draw_graph() -> void:
	var size: Vector2 = graph.size
	graph.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.35))
	if frames.is_empty():
		return
	var step: float = size.x / float(HISTORY)
	for i in frames.size():
		var ms: float = frames[i]
		var h: float = clampf(ms / GRAPH_MAX_MS, 0.0, 1.0) * size.y
		var color: Color = Color(0.4, 0.75, 0.45)
		if ms > 25.0:
			color = Color(0.85, 0.3, 0.3)
		elif ms > BUDGET_MS:
			color = Color(0.85, 0.7, 0.3)
		graph.draw_rect(Rect2(float(i) * step, size.y - h, maxf(step - 0.5, 1.0), h), color)
	var line_y: float = size.y - BUDGET_MS / GRAPH_MAX_MS * size.y
	graph.draw_line(Vector2(0.0, line_y), Vector2(size.x, line_y), Color(1.0, 1.0, 1.0, 0.35), 1.0)
