extends Node3D

const BLOCK_SCENE_PATH := "res://scenes/block.tscn"
const TORCH_SCENE_PATH := "res://scenes/torch.tscn"
const DROP_SCENE_PATH := "res://scenes/item_drop.tscn"
const Recipes = preload("res://scripts/player/recipes.gd")
const ForgeUIScene = preload("res://scenes/forge_ui.tscn")
const CreativeUIScene = preload("res://scenes/creative_ui.tscn")
const LoadingScene = preload("res://scenes/ui/loading_screen.tscn")
const DebugOverlayScene = preload("res://scenes/debug/debug_overlay.tscn")
const RuinsScript = preload("res://scripts/ruins.gd")
const RoofMapScript = preload("res://scripts/roof_map.gd")
const AudioScript = preload("res://scripts/core/audio_manager.gd")
const OutpostsScript = preload("res://scripts/outposts.gd")
const StabilityScript = preload("res://scripts/stability.gd")
const WildSpawnerScript = preload("res://scripts/enemies/wild_spawner.gd")
const WeatherScript = preload("res://scripts/core/weather.gd")
const TerritoryScript = preload("res://scripts/territory.gd")
const TroopScene = preload("res://scenes/troop.tscn")
const TroopScript = preload("res://scripts/troop.gd")
const MinimapScene = preload("res://scenes/minimap.tscn")
const WetSurfacesScript = preload("res://scripts/wet_surfaces.gd")
const BirdsScript = preload("res://scripts/birds.gd")
const CoreUIScene = preload("res://scenes/core_ui.tscn")
const GloomFogScript = preload("res://scripts/enemies/gloom_fog.gd")
const FogOverlayScene = preload("res://scenes/fog_overlay.tscn")
const AttackMarkerScene = preload("res://scenes/attack_marker.tscn")
const Pool = preload("res://scripts/core/pool.gd")
const BlockIndex = preload("res://scripts/block_index.gd")
const MissionsScene = preload("res://scenes/missions_board.tscn")
const PrologueScript = preload("res://scripts/prologue.gd")

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
@onready var hud_node = $HUD

var intro_playing: bool = false
var inventory_open: bool = false
var territory
var troops: Array = []
var next_troop_id: int = 1
var outposts: Array = []
var missions
var minimap_node
var prologue_pending: bool = false


func _ready() -> void:
	var loading = LoadingScene.instantiate()
	add_child(loading)
	loading.begin(terrain, player)
	Inventory.clear_banners()
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
	territory = Node3D.new()
	territory.name = "Territory"
	territory.set_script(TerritoryScript)
	add_child(territory)
	territory.setup(terrain, core)
	var attack_marker = AttackMarkerScene.instantiate()
	add_child(attack_marker)
	attack_marker.setup(spawner, core, terrain)
	var fog_overlay = FogOverlayScene.instantiate()
	add_child(fog_overlay)
	var gloom_fog = Node3D.new()
	gloom_fog.name = "GloomFog"
	gloom_fog.set_script(GloomFogScript)
	add_child(gloom_fog)
	gloom_fog.setup(spawner, core, player, terrain, fog_overlay)
	var minimap = MinimapScene.instantiate()
	add_child(minimap)
	minimap_node = minimap
	minimap.setup(player, core, terrain)
	missions = MissionsScene.instantiate()
	add_child(missions)
	missions.setup(self, player)
	var weather = Node.new()
	weather.name = "Weather"
	weather.set_script(WeatherScript)
	add_child(weather)
	var roof_map = Node.new()
	roof_map.name = "RoofMap"
	roof_map.set_script(RoofMapScript)
	add_child(roof_map)
	roof_map.setup(terrain, player)
	weather.roof_map = roof_map
	weather.setup(sun, $WorldEnvironment.environment, player, terrain)
	var audio = Node.new()
	audio.name = "Audio"
	audio.set_script(AudioScript)
	add_child(audio)
	audio.setup(player, terrain, weather, roof_map, sun)
	var wet_surfaces = Node.new()
	wet_surfaces.name = "WetSurfaces"
	wet_surfaces.set_script(WetSurfacesScript)
	add_child(wet_surfaces)
	wet_surfaces.setup(terrain)
	var birds = Node3D.new()
	birds.name = "Birds"
	birds.set_script(BirdsScript)
	add_child(birds)
	birds.setup(player, sun, weather)
	_place_torches()
	player.notice.connect(ui.show_notice)
	inv_ui.setup(player, ui, self)
	inv_ui.toggled.connect(_on_inventory_toggled)
	player.workbench_used.connect(inv_ui.open_table)
	var forge_ui = ForgeUIScene.instantiate()
	add_child(forge_ui)
	forge_ui.setup(player, self, inv_ui)
	player.forge_used.connect(forge_ui.open_forge)
	player.troop_used.connect(inv_ui.open_troop)
	player.chest_used.connect(inv_ui.open_chest)
	var core_ui = CoreUIScene.instantiate()
	add_child(core_ui)
	core_ui.setup(player, core, terrain, inv_ui)
	player.core_used.connect(core_ui.open_core)
	player.died.connect(core_ui.force_close)
	core.destroyed.connect(core_ui.force_close)
	if Game.gamemode == "creative":
		var creative_ui = CreativeUIScene.instantiate()
		add_child(creative_ui)
		creative_ui.setup(player, ui, self, inv_ui)
		creative_ui.toggled.connect(_on_inventory_toggled)
		player.died.connect(creative_ui.force_close)
		core.destroyed.connect(creative_ui.force_close)
	var debug_overlay = DebugOverlayScene.instantiate()
	add_child(debug_overlay)
	debug_overlay.setup(self, player)
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
		OutpostsScript.generate(self, terrain, terrain.world_seed)
	if not state.is_empty():
		apply_state(state)
		intro.queue_free()
	elif Game.has_session:
		intro.queue_free()
		prologue_pending = Game.gamemode != "creative"
	else:
		intro.queue_free()
	if troops.is_empty():
		spawn_troop({})
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if prologue_pending:
		var prologue := Node.new()
		prologue.name = "Prologue"
		prologue.set_script(PrologueScript)
		add_child(prologue)
		await loading.finished
		prologue.begin(self)


func spawn_troop(data: Dictionary) -> Node:
	var used: Array = []
	for t in troops:
		if is_instance_valid(t):
			used.append(t.display_name)
	var info := data.duplicate()
	if not info.has("id"):
		info["id"] = next_troop_id
		info["rest_index"] = troops.size()
	if not info.has("name"):
		var pool: Array = []
		for n in TroopScript.NAMES:
			if not used.has(n):
				pool.append(n)
		if pool.is_empty():
			pool = TroopScript.NAMES
		info["name"] = pool[randi() % pool.size()]
	next_troop_id = maxi(next_troop_id, int(info["id"]) + 1)
	var troop = TroopScene.instantiate()
	add_child(troop)
	troop.setup(self, terrain, core, info)
	troops.append(troop)
	return troop


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
		var drop = Pool.take("item_drop", func() -> Node: return scene.instantiate())
		drop.id = id
		drop.count = n
		add_child(drop)
		if drop.built:
			drop.reuse()
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
	for node in BlockIndex.list:
		if node.dying:
			continue
		var p: Vector3 = node.global_position
		blocks.append({"type": node.block_type, "pos": [p.x, p.y, p.z], "hp": node.current_health, "yaw": node.rotation.y, "open": node.get("is_open") == true, "items": node.get("items")})

	var drops: Array = []
	for node in get_tree().get_nodes_in_group("item_drop"):
		var dp: Vector3 = node.global_position
		drops.append({"id": node.id, "count": node.count, "pos": [dp.x, dp.y, dp.z]})

	var q: Quaternion = sun.basis.get_rotation_quaternion()
	var core_hp := 0
	var core_level := 1
	if is_instance_valid(core):
		core_hp = core.current_health
		core_level = core.level

	var troop_data: Array = []
	for t in troops:
		if is_instance_valid(t):
			troop_data.append(t.export_state())

	var outpost_data: Array = []
	for o in outposts:
		outpost_data.append([o.x, o.y, o.z])

	return {
		"troops": troop_data,
		"sun": {"quat": [q.x, q.y, q.z, q.w], "phase": sun.day_phase},
		"player": player.export_state(),
		"core": {"hp": core_hp, "level": core_level},
		"inventory": Inventory.export_state(),
		"terrain": terrain.export_state(),
		"blocks": blocks,
		"waves": spawner.export_state(),
		"drops": drops,
		"outposts": outpost_data,
		"missions": missions.export_state(),
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
	if is_instance_valid(core):
		core.set_level(int(c.get("level", 1)))
	if c.has("hp") and is_instance_valid(core):
		core.set_health(int(c["hp"]))

	for td in d.get("troops", []):
		spawn_troop(td)
	Inventory.import_state(d.get("inventory", {}))
	outposts.clear()
	for o in d.get("outposts", []):
		outposts.append(Vector3(o[0], o[1], o[2]))
	missions.import_state(d.get("missions", {}))
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
		var saved_items = b.get("items")
		if block.get("items") != null and typeof(saved_items) == TYPE_ARRAY:
			for i in mini(saved_items.size(), block.items.size()):
				block.items[i] = Inventory._clean(saved_items[i])
