extends Node3D

const BLOCK_SCENE_PATH := "res://scenes/block.tscn"
const TORCH_SCENE_PATH := "res://scenes/torch.tscn"
const DROP_SCENE_PATH := "res://scenes/item_drop.tscn"
const Recipes = preload("res://scripts/recipes.gd")
const ForgeUIScene = preload("res://scenes/forge_ui.tscn")
const CreativeUIScene = preload("res://scenes/creative_ui.tscn")
const RuinsScript = preload("res://scripts/ruins.gd")
const StabilityScript = preload("res://scripts/stability.gd")
const WildSpawnerScript = preload("res://scripts/wild_spawner.gd")
const WeatherScript = preload("res://scripts/weather.gd")
const AttackMarkerScene = preload("res://scenes/attack_marker.tscn")

@onready var sun = $Sun
@onready var terrain = $Terrain
@onready var player = $Player
@onready var core = $Core
@onready var ui = $GameUI
@onready var flow = $FlowField
@onready var spawner = $WaveSpawner
@onready var enemies = $Enemies
@onready var intro = $Intro
@onready var inv_ui = $InventoryUI

var intro_playing: bool = false
var inventory_open: bool = false


func _ready() -> void:
	terrain.pin(core.global_position, 4)
	flow.setup(terrain, core)
	spawner.setup(terrain, flow, core, player, sun, enemies)
	spawner.status_changed.connect(ui.on_wave_status)
	var stability = Node.new()
	stability.name = "Stability"
	stability.set_script(StabilityScript)
	add_child(stability)
	stability.setup(terrain)
	var wild_spawner = Node.new()
	wild_spawner.name = "WildSpawner"
	wild_spawner.set_script(WildSpawnerScript)
	add_child(wild_spawner)
	wild_spawner.setup(terrain, core, player, sun, enemies)
	var attack_marker = AttackMarkerScene.instantiate()
	add_child(attack_marker)
	attack_marker.setup(spawner, core, terrain)
	var weather = Node.new()
	weather.name = "Weather"
	weather.set_script(WeatherScript)
	add_child(weather)
	weather.setup(sun, $WorldEnvironment.environment, player, terrain)
	_place_torches()
	player.notice.connect(ui.show_notice)
	inv_ui.setup(player, ui, self)
	inv_ui.toggled.connect(_on_inventory_toggled)
	player.workbench_used.connect(inv_ui.open_table)
	var forge_ui = ForgeUIScene.instantiate()
	add_child(forge_ui)
	forge_ui.setup(player, self, inv_ui)
	player.forge_used.connect(forge_ui.open_forge)
	if Game.gamemode == "creative":
		var creative_ui = CreativeUIScene.instantiate()
		add_child(creative_ui)
		creative_ui.setup(player, ui, self, inv_ui)
		creative_ui.toggled.connect(_on_inventory_toggled)
		player.died.connect(creative_ui.force_close)
		core.destroyed.connect(creative_ui.force_close)
	player.died.connect(forge_ui.force_close)
	core.destroyed.connect(forge_ui.force_close)
	Inventory.recipes_unlocked.connect(_on_recipes_unlocked)
	player.died.connect(inv_ui.force_close)
	core.destroyed.connect(inv_ui.force_close)
	ui.setup(player, core, self)
	player.died.connect(ui.on_player_died)
	core.destroyed.connect(ui.on_core_destroyed)

	var state := Game.take_pending()
	if state.is_empty():
		RuinsScript.generate(self, terrain, terrain.world_seed)
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


func _on_recipes_unlocked(ids: Array) -> void:
	var names: Array = []
	for id in ids:
		names.append(Inventory.item_name(Recipes.by_id(id)["out"]))
	ui.show_notice("Recipe unlocked: " + ", ".join(names))


func _on_inventory_toggled(is_open: bool) -> void:
	inventory_open = is_open


func spawn_drop(id: String, amount: int, pos: Vector3, merge: bool = true) -> void:
	if id == "" or amount <= 0:
		return
	var cap := Inventory.max_stack(id)
	var remaining := amount
	if merge:
		for d in get_tree().get_nodes_in_group("item_drop"):
			if remaining <= 0:
				break
			if d.id == id and d.count < cap and d.global_position.distance_to(pos) < 1.5:
				var put := mini(cap - d.count, remaining)
				d.count += put
				remaining -= put
	var scene: PackedScene = load(DROP_SCENE_PATH)
	while remaining > 0:
		var n := mini(remaining, cap)
		remaining -= n
		var drop = scene.instantiate()
		drop.id = id
		drop.count = n
		add_child(drop)
		drop.global_position = pos
		drop.linear_velocity = Vector3(randf_range(-1.2, 1.2), randf_range(2.0, 3.5), randf_range(-1.2, 1.2))


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
			torch.fixture = true
			add_child(torch)
			var top: int = terrain.surface_y(cx, cz)
			torch.global_position = Vector3(cx + 0.5, top + 0.5, cz + 0.5)


func restore_block(block_type: String, pos: Vector3, yaw: float = 0.0) -> Node:
	if not Inventory.BLOCK_TYPES.has(block_type):
		return null
	var scene_path: String = Inventory.BLOCK_TYPES[block_type].get("scene", BLOCK_SCENE_PATH)
	var scene: PackedScene = load(scene_path)
	var block = scene.instantiate()
	block.block_type = block_type
	add_child(block)
	block.global_position = pos
	block.rotation.y = yaw
	return block


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
		blocks.append({"type": node.block_type, "pos": [p.x, p.y, p.z], "hp": node.current_health, "yaw": node.rotation.y, "open": node.get("is_open") == true})

	var drops: Array = []
	for node in get_tree().get_nodes_in_group("item_drop"):
		var dp: Vector3 = node.global_position
		drops.append({"id": node.id, "count": node.count, "pos": [dp.x, dp.y, dp.z]})

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
		"drops": drops,
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
	for dd in d.get("drops", []):
		if Inventory.ITEMS.has(dd["id"]):
			spawn_drop(dd["id"], int(dd["count"]), Vector3(dd["pos"][0], dd["pos"][1], dd["pos"][2]), false)

	for b in d.get("blocks", []):
		var block_type := str(b["type"])
		if not Inventory.BLOCK_TYPES.has(block_type):
			continue
		var scene_path: String = Inventory.BLOCK_TYPES[block_type].get("scene", BLOCK_SCENE_PATH)
		var scene: PackedScene = load(scene_path)
		var block = scene.instantiate()
		block.block_type = block_type
		add_child(block)
		block.global_position = Vector3(b["pos"][0], b["pos"][1], b["pos"][2])
		block.rotation.y = float(b.get("yaw", 0.0))
		block.current_health = int(b["hp"])
		if block.has_method("set_open"):
			block.set_open(bool(b.get("open", false)), true)
