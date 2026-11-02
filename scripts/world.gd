extends Node3D

const BLOCK_SCENE_PATH := "res://scenes/block.tscn"
const TORCH_SCENE_PATH := "res://scenes/torch.tscn"

@onready var sun = $Sun
@onready var terrain = $Terrain
@onready var player = $Player
@onready var core = $Core
@onready var ui = $GameUI
@onready var flow = $FlowField
@onready var spawner = $WaveSpawner
@onready var enemies = $Enemies
@onready var intro = $Intro

var intro_playing: bool = false


func _ready() -> void:
	terrain.pin(core.global_position, 4)
	flow.setup(terrain, core)
	spawner.setup(terrain, flow, core, player, sun, enemies)
	spawner.status_changed.connect(ui.on_wave_status)
	_place_torches()
	player.notice.connect(ui.show_notice)
	ui.setup(player, core, self)
	player.died.connect(ui.on_player_died)
	core.destroyed.connect(ui.on_core_destroyed)

	var state := Game.take_pending()
	if not state.is_empty():
		apply_state(state)
		intro.queue_free()
	elif Game.has_session:
		intro_playing = true
		player.frozen = true
		intro.finished.connect(_on_intro_finished)
		intro.play()
	else:
		intro.queue_free()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_intro_finished() -> void:
	intro_playing = false
	player.frozen = false


func _place_torches() -> void:
	var scene: PackedScene = load(TORCH_SCENE_PATH)
	var lo: int = terrain.PLATFORM_MIN
	var hi: int = terrain.PLATFORM_MAX
	for cx in [lo, hi]:
		for cz in [lo, hi]:
			var torch = scene.instantiate()
			add_child(torch)
			var top: int = terrain.surface_y(cx, cz)
			torch.global_position = Vector3(cx + 0.5, top + 0.5, cz + 0.5)


func respawn_position() -> Vector3:
	if is_instance_valid(core):
		return core.global_position + Vector3(0.0, 1.2, 6.0)
	return Vector3(0.0, terrain.height_at(0.0, 6.0) + 2.0, 6.0)


func respawn_player() -> void:
	player.respawn(respawn_position())


func collect_state() -> Dictionary:
	var blocks: Array = []
	for node in get_tree().get_nodes_in_group("block"):
		if node.dying:
			continue
		var p: Vector3 = node.global_position
		blocks.append({"type": node.block_type, "pos": [p.x, p.y, p.z], "hp": node.current_health})

	var q: Quaternion = sun.basis.get_rotation_quaternion()
	var core_hp := 0
	if is_instance_valid(core):
		core_hp = core.current_health

	return {
		"sun": {"quat": [q.x, q.y, q.z, q.w], "phase": sun.day_phase},
		"player": player.export_state(),
		"core": {"hp": core_hp},
		"inventory": Inventory.export_state(),
		"terrain": terrain.export_state(),
		"blocks": blocks,
		"waves": spawner.export_state(),
	}


func apply_state(d: Dictionary) -> void:
	var s: Dictionary = d.get("sun", {})
	if s.has("quat"):
		var q: Array = s["quat"]
		sun.basis = Basis(Quaternion(q[0], q[1], q[2], q[3]))
		sun.day_phase = float(s["phase"])

	if d.has("player"):
		player.import_state(d["player"])

	var c: Dictionary = d.get("core", {})
	if c.has("hp") and is_instance_valid(core):
		core.set_health(int(c["hp"]))

	Inventory.import_state(d.get("inventory", {}))
	spawner.import_state(d.get("waves", {}))

	var scene: PackedScene = load(BLOCK_SCENE_PATH)
	for b in d.get("blocks", []):
		var block = scene.instantiate()
		block.block_type = str(b["type"])
		add_child(block)
		block.global_position = Vector3(b["pos"][0], b["pos"][1], b["pos"][2])
		block.current_health = int(b["hp"])
