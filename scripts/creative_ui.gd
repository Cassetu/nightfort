extends CanvasLayer

signal toggled(is_open: bool)

const TileArt = preload("res://scripts/tile_art.gd")
const CELL := Vector2(64, 64)
const KIND_ORDER := {"block": 0, "material": 1, "tool": 2, "weapon": 3, "armor": 4}

@onready var root: Control = $Root
@onready var search: LineEdit = %Search
@onready var grid: GridContainer = %Grid
@onready var item_name: Label = %ItemName
@onready var hotbar_row: HBoxContainer = %HotbarRow

var player
var game_ui
var world
var inv_ui
var open: bool = false
var buttons: Dictionary = {}
var hotbar_buttons: Array = []


func _ready() -> void:
	root.visible = false
	search.text_changed.connect(_filter)
	search.text_submitted.connect(_on_submitted)
	_build_grid()
	_build_hotbar()
	Inventory.changed.connect(_refresh_hotbar)
	_refresh_hotbar()


func setup(p, ui, w, inventory_ui) -> void:
	player = p
	game_ui = ui
	world = w
	inv_ui = inventory_ui


func _sorted_ids() -> Array:
	var ids: Array = Inventory.ITEMS.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ka: int = KIND_ORDER.get(Inventory.ITEMS[a].get("kind", "material"), 9)
		var kb: int = KIND_ORDER.get(Inventory.ITEMS[b].get("kind", "material"), 9)
		if ka != kb:
			return ka < kb
		return Inventory.item_name(a) < Inventory.item_name(b))
	return ids


func _make_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = CELL
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = true
	b.clip_text = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	return b


func _apply_icon(b: Button, id: String) -> void:
	var info: Dictionary = Inventory.ITEMS[id]
	var tex: Texture2D = TileArt.icon(id, str(info.get("tile", "")))
	if tex != null:
		b.icon = tex
		b.text = ""
	else:
		b.icon = null
		b.text = Inventory.item_name(id)
		b.add_theme_font_size_override("font_size", 11)


func _build_grid() -> void:
	for id: String in _sorted_ids():
		var b := _make_button()
		_apply_icon(b, id)
		b.gui_input.connect(_on_cell_input.bind(id))
		b.mouse_entered.connect(_on_hover.bind(id))
		b.mouse_exited.connect(_on_hover.bind(""))
		grid.add_child(b)
		buttons[id] = b


func _build_hotbar() -> void:
	for i in Inventory.SLOT_COUNT:
		var b := _make_button()
		b.custom_minimum_size = Vector2(52, 52)
		b.pressed.connect(_clear_slot.bind(i))
		hotbar_row.add_child(b)
		hotbar_buttons.append(b)


func _refresh_hotbar() -> void:
	for i in hotbar_buttons.size():
		var b: Button = hotbar_buttons[i]
		var item: Dictionary = Inventory.slots[i]
		if item.is_empty():
			b.icon = null
			b.text = ""
			continue
		_apply_icon(b, item["id"])
		if b.icon != null:
			b.text = str(item["count"])
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			b.text = "%s %d" % [Inventory.item_name(item["id"]), item["count"]]


func _clear_slot(index: int) -> void:
	Inventory.set_slot(index, {})


func _on_cell_input(event: InputEvent, id: String) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_give(id, Inventory.max_stack(id))
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_give(id, 1)


func _give(id: String, amount: int) -> void:
	var left := Inventory.add_item(id, amount)
	if left >= amount:
		item_name.text = "Inventory full"


func _on_hover(id: String) -> void:
	item_name.text = " " if id == "" else Inventory.item_name(id)


func _filter(text: String) -> void:
	var needle := text.strip_edges().to_lower()
	for id: String in buttons:
		buttons[id].visible = needle.is_empty() or Inventory.item_name(id).to_lower().contains(needle) or id.contains(needle)


func _on_submitted(_text: String) -> void:
	search.release_focus()


func can_open() -> bool:
	if open or player == null or player.dead or player.frozen:
		return false
	if game_ui.game_over or game_ui.dead or game_ui.pause_overlay.visible:
		return false
	if inv_ui.open:
		return false
	return not world.intro_playing


func open_menu() -> void:
	open = true
	root.visible = true
	player.frozen = true
	search.clear()
	_filter("")
	item_name.text = " "
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	toggled.emit(true)


func close() -> void:
	if not open:
		return
	search.release_focus()
	open = false
	root.visible = false
	player.frozen = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	toggled.emit(false)


func force_close() -> void:
	if not open:
		return
	close()
	if player != null and player.dead:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not event.is_echo():
		if open:
			if search.has_focus():
				return
			close()
			get_viewport().set_input_as_handled()
		elif can_open():
			open_menu()
			get_viewport().set_input_as_handled()
		return
	if open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
