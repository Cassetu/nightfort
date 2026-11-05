extends CanvasLayer

const ForgeRecipes = preload("res://scripts/forge_recipes.gd")
const TileArt = preload("res://scripts/tile_art.gd")
const RECIPE_ROW := preload("res://scenes/recipe_row.tscn")
const MAX_MISSES := 3
const MARKER_WIDTH := 6.0

@onready var root: Control = $Root
@onready var recipe_list: VBoxContainer = %RecipeList
@onready var icon: TextureRect = %Icon
@onready var item_name: Label = %ItemName
@onready var info: Label = %Info
@onready var track: Control = %Track
@onready var zone: ColorRect = %Zone
@onready var marker: ColorRect = %Marker
@onready var progress: ProgressBar = %Progress
@onready var status: Label = %Status
@onready var start_button: Button = %StartButton
@onready var strike_button: Button = %StrikeButton
@onready var close_button: Button = %CloseButton

var player
var world
var inv_ui
var forge
var open: bool = false
var selected: Dictionary = {}
var forging: bool = false
var strikes_done: int = 0
var misses: int = 0
var phase: float = 0.0
var zone_center: float = 0.5
var rows: Dictionary = {}


func _ready() -> void:
	root.visible = false
	start_button.pressed.connect(_start)
	strike_button.pressed.connect(_strike)
	close_button.pressed.connect(close)
	zone.visible = false
	marker.visible = false


func setup(p, w, inventory_ui) -> void:
	player = p
	world = w
	inv_ui = inventory_ui


func open_forge(f) -> void:
	if open or not inv_ui.can_open():
		return
	forge = f
	open = true
	root.visible = true
	player.frozen = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	selected = {}
	forging = false
	status.text = ""
	progress.value = 0.0
	_build_list()
	_select(ForgeRecipes.LIST[0])


func close() -> void:
	if not open:
		return
	if forging:
		_refund_materials()
		forging = false
	if is_instance_valid(forge):
		forge.set_active(false)
	open = false
	root.visible = false
	player.frozen = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func force_close() -> void:
	if not open:
		return
	close()
	if player != null and player.dead:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _input(event: InputEvent) -> void:
	if not open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if forging and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		_strike()
		get_viewport().set_input_as_handled()


func _build_list() -> void:
	for child in recipe_list.get_children():
		recipe_list.remove_child(child)
		child.queue_free()
	rows.clear()
	for r in ForgeRecipes.LIST:
		var row: Button = RECIPE_ROW.instantiate()
		row.focus_mode = Control.FOCUS_NONE
		row.text = "%s\n%s" % [Inventory.item_name(r["id"]), ForgeRecipes.cost_text(r)]
		row.pressed.connect(_on_row_pressed.bind(r["id"]))
		recipe_list.add_child(row)
		rows[r["id"]] = row
	_update_rows()


func _update_rows() -> void:
	for id: String in rows:
		var row: Button = rows[id]
		var r := ForgeRecipes.by_id(id)
		row.set_pressed_no_signal(not selected.is_empty() and selected["id"] == id)
		row.modulate = Color(1, 1, 1, 1) if ForgeRecipes.can_afford(r) else Color(1, 1, 1, 0.5)


func _on_row_pressed(id: String) -> void:
	if forging:
		_update_rows()
		return
	_select(ForgeRecipes.by_id(id))


func _select(r: Dictionary) -> void:
	selected = r
	var id: String = r["id"]
	var data: Dictionary = Inventory.ITEMS.get(id, {})
	icon.texture = TileArt.icon(id, data.get("tile", ""))
	item_name.text = Inventory.item_name(id)

	var lines: Array = []
	match data.get("kind", ""):
		"tool":
			lines.append("Mining power x%.1f (%s)" % [float(data["power"]), str(data["tool"])])
		"weapon":
			lines.append("Damage %d" % int(data["damage"]))
		"armor":
			lines.append("Defense +%d  (%s slot)" % [int(data["defense"]), str(data["slot"])])
	lines.append("")
	var cost: Dictionary = r["cost"]
	for mat in cost:
		lines.append("%s  %d / %d" % [Inventory.item_name(mat), Inventory.get_count(mat), int(cost[mat])])
	lines.append("Coal (fuel)  %d / %d" % [Inventory.get_count("coal"), int(r["coal"])])
	lines.append("")
	lines.append("Good strikes needed: %d" % int(r["strikes"]))
	info.text = "\n".join(lines)
	progress.max_value = float(r["strikes"])
	progress.value = 0.0
	start_button.disabled = not ForgeRecipes.can_afford(r)
	_update_rows()


func _start() -> void:
	if forging or selected.is_empty() or not ForgeRecipes.can_afford(selected):
		return
	var cost: Dictionary = selected["cost"]
	for mat in cost:
		Inventory.take_item(mat, int(cost[mat]))
	Inventory.take_item("coal", int(selected["coal"]))
	forging = true
	strikes_done = 0
	misses = 0
	phase = 0.0
	progress.value = 0.0
	zone.visible = true
	marker.visible = true
	start_button.disabled = true
	strike_button.disabled = false
	if is_instance_valid(forge):
		forge.set_active(true)
	_new_zone()
	status.text = "The forge roars. Strike when the marker is in the glowing zone."
	_update_rows()


func _new_zone() -> void:
	var width: float = selected["zone"]
	zone_center = randf_range(width * 0.5 + 0.05, 1.0 - width * 0.5 - 0.05)


func _process(delta: float) -> void:
	if not open:
		return
	var width := track.size.x
	var zone_width: float = 0.2
	if not selected.is_empty():
		zone_width = selected["zone"]
	zone.position = Vector2((zone_center - zone_width * 0.5) * width, 0.0)
	zone.size = Vector2(zone_width * width, track.size.y)
	if not forging:
		return
	phase += delta * float(selected["speed"]) * 0.9
	var pos := pingpong(phase, 1.0)
	marker.position = Vector2(pos * (width - MARKER_WIDTH), 0.0)
	marker.size = Vector2(MARKER_WIDTH, track.size.y)


func _strike() -> void:
	if not forging:
		return
	var pos := pingpong(phase, 1.0)
	var width: float = selected["zone"]
	if absf(pos - zone_center) <= width * 0.5:
		strikes_done += 1
		progress.value = float(strikes_done)
		if strikes_done >= int(selected["strikes"]):
			_finish()
			return
		_new_zone()
		status.text = "Clean strike  (%d / %d)" % [strikes_done, int(selected["strikes"])]
	else:
		misses += 1
		status.text = "Cold strike!  Misses %d / %d" % [misses, MAX_MISSES]
		if misses >= MAX_MISSES:
			_ruin()


func _end_forging() -> void:
	forging = false
	zone.visible = false
	marker.visible = false
	strike_button.disabled = true
	if is_instance_valid(forge):
		forge.set_active(false)


func _finish() -> void:
	var id: String = selected["id"]
	_end_forging()
	var left := Inventory.add_item(id, 1)
	if left > 0:
		world.spawn_drop(id, left, player.global_position + Vector3(0.0, 1.0, 0.0))
	status.text = "Forged: %s" % Inventory.item_name(id)
	_select(selected)


func _ruin() -> void:
	_end_forging()
	_refund_materials()
	status.text = "The metal cracked. Materials recovered, the coal is gone."
	_select(selected)


func _refund_materials() -> void:
	var cost: Dictionary = selected["cost"]
	for mat in cost:
		var left := Inventory.add_item(mat, int(cost[mat]))
		if left > 0:
			world.spawn_drop(mat, left, player.global_position + Vector3(0.0, 1.0, 0.0))
