extends CanvasLayer

signal toggled(is_open: bool)

const Recipes = preload("res://scripts/player/recipes.gd")
const TileArt = preload("res://scripts/tile_art.gd")
const RECIPE_ROW := preload("res://scenes/recipes/recipe_row.tscn")
const RECIPE_INGREDIENT := preload("res://scenes/recipes/recipe_ingredient.tscn")
const MISSING_COLOR := Color(1.0, 0.3, 0.3)
const DOUBLE_CLICK_TIME := 0.35
const CRAFT_CELLS := 9

@onready var root: Control = $Root
@onready var title: Label = %Title
@onready var item_name: Label = %ItemName
@onready var cursor_slot: Panel = %CursorSlot
@onready var craft_grid: GridContainer = %CraftGrid
@onready var recipe_panel: PanelContainer = %RecipePanel
@onready var recipe_list: VBoxContainer = %RecipeList
@onready var recipe_button: Button = %RecipeButton
@onready var equip_col: VBoxContainer = %Equip
@onready var craft_col: VBoxContainer = %Craft
@onready var troop_panel: VBoxContainer = %TroopPanel
@onready var mood_label: Label = %MoodLabel
@onready var mood_bar: ProgressBar = %MoodBar
@onready var station_button: Button = %StationButton
@onready var chest_panel: VBoxContainer = %ChestPanel

var slot_nodes: Array = []
const DROP_HOLD_DELAY := 0.35
const DROP_REPEAT := 0.06

var open: bool = false
var table_mode: bool = false
var troop = null
var chest_node = null
var craft_size: int = 2
var craft_items: Array = []
var current_recipe: Dictionary = {}
var player
var game_ui
var world
var cursor: Dictionary = {}
var pending: bool = false
var drag_slots: Array = []
var preview: Dictionary = {}
var preview_left: int = 0
var last_click_time: float = -10.0
var last_click_slot = null
var hovered = null
var drop_hold: float = -1.0
var drop_repeat: float = 0.0
var flash_text: String = ""
var flash_time: float = 0.0


func _ready() -> void:
	_ensure_action()
	root.visible = false
	recipe_panel.visible = false
	for i in CRAFT_CELLS:
		craft_items.append({})
	for group: Node in [%Hotbar, %Backpack, %Equip, %CraftGrid, %ResultBox, %TroopEquip, %ChestGrid]:
		for child in group.get_children():
			if child.has_method("show_item"):
				slot_nodes.append(child)
	recipe_button.pressed.connect(_toggle_recipes)
	station_button.pressed.connect(_on_station)
	troop_panel.visible = false
	chest_panel.visible = false
	Inventory.changed.connect(_on_inventory_changed)
	Inventory.selection_changed.connect(_refresh)
	_refresh()


func setup(p, ui, w) -> void:
	player = p
	game_ui = ui
	world = w


func _ensure_action() -> void:
	if InputMap.has_action("inventory"):
		return
	InputMap.add_action("inventory")
	for key in [KEY_E, KEY_TAB]:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event("inventory", ev)


func _drop_tick(delta: float) -> void:
	if not Input.is_physical_key_pressed(KEY_Q):
		drop_hold = -1.0
		return
	if player == null or world == null or Game.gamemode == "creative" or not Game.in_world:
		return
	if drop_hold < 0.0:
		drop_hold = 0.0
		drop_repeat = 0.0
		_drop_one()
		return
	drop_hold += delta
	if drop_hold < DROP_HOLD_DELAY:
		return
	drop_repeat -= delta
	if drop_repeat <= 0.0:
		drop_repeat = DROP_REPEAT
		_drop_one()


func _drop_one() -> void:
	if player.dead or game_ui.game_over or game_ui.dead or game_ui.pause_overlay.visible:
		return
	var item: Dictionary = {}
	var s = null
	if open:
		s = hovered
		if s == null or s.is_result:
			return
		item = _get(s)
	else:
		if player.frozen or world.intro_playing:
			return
		item = Inventory.slots[Inventory.selected]
	if item.is_empty():
		return
	var id: String = item["id"]
	item["count"] = int(item["count"]) - 1
	if int(item["count"]) <= 0:
		if s != null:
			_set_slot(s, {})
		else:
			Inventory.set_slot(Inventory.selected, {})
	elif s != null:
		_set_slot(s, item)
	else:
		Inventory.set_slot(Inventory.selected, item)
	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var origin: Vector3 = player.global_position + Vector3(0.0, 1.3, 0.0) + forward * 0.6
	world.spawn_drop(id, 1, origin, false, forward * 4.5 + Vector3(0.0, 1.5, 0.0))


func can_open() -> bool:
	if player == null or player.dead or player.frozen:
		return false
	if game_ui.game_over or game_ui.dead or game_ui.pause_overlay.visible:
		return false
	return not world.intro_playing


func open_table() -> void:
	if not open and can_open():
		open_ui(true)


func open_troop(t) -> void:
	if open or not can_open():
		return
	troop = t
	chest_node = null
	chest_panel.visible = false
	table_mode = false
	equip_col.visible = false
	craft_col.visible = false
	troop_panel.visible = true
	title.text = t.display_name
	current_recipe = {}
	_enter()


func open_chest(c) -> void:
	if open or not can_open():
		return
	troop = null
	chest_node = c
	table_mode = false
	equip_col.visible = false
	craft_col.visible = false
	troop_panel.visible = false
	chest_panel.visible = true
	title.text = "Chest"
	current_recipe = {}
	_enter()


func _enter() -> void:
	open = true
	root.visible = true
	player.frozen = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	toggled.emit(true)
	_refresh()


func _on_station() -> void:
	if troop == null or not is_instance_valid(troop):
		return
	var key: String = troop.issue_banner()
	if Inventory.add_item(key, 1) > 0:
		world.spawn_drop(key, 1, player.global_position + Vector3(0.0, 1.0, 0.0))
	_flash(Inventory.item_name(key))


func open_ui(table: bool = false) -> void:
	troop = null
	chest_node = null
	chest_panel.visible = false
	equip_col.visible = true
	craft_col.visible = true
	troop_panel.visible = false
	table_mode = table
	craft_size = 3 if table else 2
	craft_grid.columns = craft_size
	var cells := craft_grid.get_children()
	for i in cells.size():
		cells[i].visible = i < craft_size * craft_size
	title.text = "Workbench" if table else "Inventory"
	current_recipe = {}
	open = true
	root.visible = true
	player.frozen = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	toggled.emit(true)
	_refresh()


func close() -> void:
	if not open:
		return
	if not cursor.is_empty():
		_give_back(cursor)
		cursor = {}
	_return_craft_items()
	pending = false
	drag_slots.clear()
	preview.clear()
	open = false
	troop = null
	chest_node = null
	chest_panel.visible = false
	root.visible = false
	recipe_panel.visible = false
	player.frozen = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	toggled.emit(false)


func force_close() -> void:
	if not open:
		return
	close()
	if player != null and player.dead:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _give_back(item: Dictionary) -> void:
	var left := Inventory.add_item(item["id"], int(item["count"]))
	if left > 0 and player != null:
		world.spawn_drop(item["id"], left, player.global_position + Vector3(0.0, 1.0, 0.0))


func _return_craft_items() -> void:
	for i in CRAFT_CELLS:
		var item: Dictionary = craft_items[i]
		craft_items[i] = {}
		if not item.is_empty():
			_give_back(item)
	current_recipe = {}


func _input(event: InputEvent) -> void:
	if Game.gamemode == "creative" and open and not table_mode and troop == null and chest_node == null:
		if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
			return
	if event.is_action_pressed("inventory") and not event.is_echo():
		if open:
			close()
			get_viewport().set_input_as_handled()
		elif Game.gamemode == "creative":
			return
		elif can_open():
			open_ui(false)
			get_viewport().set_input_as_handled()
		return
	if not open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index >= MOUSE_BUTTON_WHEEL_UP and event.button_index <= MOUSE_BUTTON_WHEEL_RIGHT:
			return
		var over := get_viewport().gui_get_hovered_control()
		if over is BaseButton:
			return
		get_viewport().set_input_as_handled()
		var s = _slot_at(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_left_press(s)
			else:
				_left_release()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_right_press(s)
	elif event is InputEventMouseMotion:
		_drag_motion(event.position)


func _process(delta: float) -> void:
	_drop_tick(delta)
	if not open:
		return
	var mouse := get_viewport().get_mouse_position()
	cursor_slot.position = mouse - cursor_slot.size * 0.5
	if chest_node != null and not is_instance_valid(chest_node):
		close()
		return
	if troop != null:
		if not is_instance_valid(troop):
			close()
			return
		mood_label.text = troop.mood_name()
		mood_bar.value = troop.mood * 100.0
		station_button.text = "Restation" if troop.banner_issued else "Station"
	var s = _slot_at(mouse)
	if s != hovered:
		hovered = s
		_refresh()

	if flash_time > 0.0:
		flash_time -= delta
		item_name.text = flash_text
		return
	if s == null:
		item_name.text = ""
		return
	var item := _get(s)
	if item.is_empty():
		item_name.text = s.equip.capitalize() if s.equip != "" else ""
	else:
		item_name.text = Inventory.item_name(item["id"])


func _flash(text: String) -> void:
	flash_text = text
	flash_time = 1.6


func _slot_at(pos: Vector2):
	for s in slot_nodes:
		if s.is_visible_in_tree() and s.get_global_rect().has_point(pos):
			return s
	return null


func _get(s) -> Dictionary:
	if s.is_in_group("troop_slot"):
		if troop == null or not is_instance_valid(troop):
			return {}
		return troop.equipment[s.equip]
	if s.chest >= 0:
		if chest_node == null or not is_instance_valid(chest_node):
			return {}
		return chest_node.items[s.chest]
	if s.index >= 0:
		return Inventory.slots[s.index]
	if s.craft >= 0:
		return craft_items[s.craft]
	if s.is_result:
		if current_recipe.is_empty():
			return {}
		return {"id": current_recipe["out"], "count": int(current_recipe["count"])}
	return Inventory.equipment[s.equip]


func _set_slot(s, item: Dictionary) -> void:
	if s.is_in_group("troop_slot"):
		if troop != null and is_instance_valid(troop):
			troop.set_equip(s.equip, item)
		return
	if s.chest >= 0:
		if chest_node != null and is_instance_valid(chest_node):
			chest_node.items[s.chest] = item
	elif s.index >= 0:
		Inventory.set_slot(s.index, item)
	elif s.craft >= 0:
		craft_items[s.craft] = item
		_craft_changed()
	else:
		Inventory.set_equip(s.equip, item)


func _accepts(s, item: Dictionary) -> bool:
	if s.is_result:
		return false
	if s.equip == "":
		return true
	var info: Dictionary = Inventory.ITEMS.get(item["id"], {})
	return info.get("slot", "") == s.equip and int(item["count"]) == 1


func _is_spreadable(s) -> bool:
	return s.index >= 0 or s.craft >= 0 or s.chest >= 0


func _left_press(s) -> void:
	if s == null:
		return
	if s.is_result:
		_take_result()
		return
	var now := Time.get_ticks_msec() / 1000.0
	var is_double: bool = (now - last_click_time) < DOUBLE_CLICK_TIME and last_click_slot == s
	last_click_time = now
	last_click_slot = s

	if is_double:
		last_click_time = -10.0
		if not cursor.is_empty():
			_click(s)
		if cursor.is_empty() and s.index >= 0 and not _get(s).is_empty():
			Inventory.combine_into(s.index)
		return

	var item := _get(s)
	var can_drag: bool = not cursor.is_empty() and _is_spreadable(s) and (item.is_empty() or item["id"] == cursor["id"])
	if can_drag:
		pending = true
		drag_slots = [s]
		_update_preview()
	else:
		_click(s)


func _left_release() -> void:
	if not pending:
		return
	pending = false
	if drag_slots.size() <= 1:
		_click(drag_slots[0])
	else:
		_distribute()
	drag_slots.clear()
	preview.clear()
	_refresh()


func _drag_motion(pos: Vector2) -> void:
	if not pending:
		return
	var s = _slot_at(pos)
	if s == null or not _is_spreadable(s) or drag_slots.has(s):
		return
	var item := _get(s)
	if item.is_empty() or item["id"] == cursor["id"]:
		drag_slots.append(s)
		_update_preview()


func _plan() -> Dictionary:
	var n := int(cursor["count"])
	var k := drag_slots.size()
	var cap := Inventory.max_stack(cursor["id"])
	var base := n / k
	var rem := n % k
	var puts: Array = []
	var used := 0
	for i in k:
		var want := base + (1 if i < rem else 0)
		var cur := _get(drag_slots[i])
		var have := 0 if cur.is_empty() else int(cur["count"])
		var put := maxi(mini(want, cap - have), 0)
		puts.append(put)
		used += put
	return {"puts": puts, "left": n - used}


func _update_preview() -> void:
	preview.clear()
	var plan := _plan()
	var puts: Array = plan["puts"]
	for i in drag_slots.size():
		var s = drag_slots[i]
		var cur := _get(s)
		var have := 0 if cur.is_empty() else int(cur["count"])
		if puts[i] > 0:
			preview[s] = {"id": cursor["id"], "count": have + int(puts[i])}
	preview_left = int(plan["left"])
	_refresh()


func _distribute() -> void:
	var plan := _plan()
	var puts: Array = plan["puts"]
	for i in drag_slots.size():
		if puts[i] <= 0:
			continue
		var s = drag_slots[i]
		var cur := _get(s)
		var have := 0 if cur.is_empty() else int(cur["count"])
		_set_slot(s, {"id": cursor["id"], "count": have + int(puts[i])})
	var left := int(plan["left"])
	if left <= 0:
		cursor = {}
	else:
		cursor["count"] = left


func _click(s) -> void:
	var item := _get(s)
	if cursor.is_empty():
		if item.is_empty():
			return
		cursor = item
		_set_slot(s, {})
		return
	if not _accepts(s, cursor):
		return
	if item.is_empty():
		_set_slot(s, cursor)
		cursor = {}
	elif item["id"] == cursor["id"]:
		var cap := Inventory.max_stack(item["id"])
		var move := mini(cap - int(item["count"]), int(cursor["count"]))
		item["count"] = int(item["count"]) + move
		cursor["count"] = int(cursor["count"]) - move
		if int(cursor["count"]) <= 0:
			cursor = {}
		_set_slot(s, item)
	else:
		_set_slot(s, cursor)
		cursor = item


func _right_press(s) -> void:
	if s == null:
		return
	if s.is_result:
		_take_result()
		return
	var item := _get(s)
	if cursor.is_empty():
		if item.is_empty():
			return
		var take := (int(item["count"]) + 1) / 2
		cursor = {"id": item["id"], "count": take}
		item["count"] = int(item["count"]) - take
		if int(item["count"]) <= 0:
			_set_slot(s, {})
		else:
			_set_slot(s, item)
		return
	var one := {"id": cursor["id"], "count": 1}
	if not _accepts(s, one):
		return
	if item.is_empty():
		_set_slot(s, one)
	elif item["id"] == cursor["id"] and int(item["count"]) < Inventory.max_stack(item["id"]):
		item["count"] = int(item["count"]) + 1
		_set_slot(s, item)
	else:
		return
	cursor["count"] = int(cursor["count"]) - 1
	if int(cursor["count"]) <= 0:
		cursor = {}


func _craft_changed() -> void:
	var cells: Array = []
	for i in craft_size * craft_size:
		var item: Dictionary = craft_items[i]
		cells.append("" if item.is_empty() else item["id"])
	current_recipe = Recipes.match_grid(cells, craft_size)
	if not current_recipe.is_empty() and Recipes.needs_table(current_recipe) and not table_mode:
		current_recipe = {}
	_refresh()
	if recipe_panel.visible:
		_refresh_recipes()


func _take_result() -> void:
	if current_recipe.is_empty():
		return
	var out_id: String = current_recipe["out"]
	var n := int(current_recipe["count"])
	if Input.is_key_pressed(KEY_SHIFT):
		_take_all_results(out_id, n)
		return
	if not cursor.is_empty():
		if cursor["id"] != out_id or int(cursor["count"]) + n > Inventory.max_stack(out_id):
			return
		cursor["count"] = int(cursor["count"]) + n
	else:
		cursor = {"id": out_id, "count": n}
	for i in craft_size * craft_size:
		var item: Dictionary = craft_items[i]
		if item.is_empty():
			continue
		item["count"] = int(item["count"]) - 1
		if int(item["count"]) <= 0:
			craft_items[i] = {}
	Inventory.discover(out_id)
	Inventory.item_added.emit(out_id, n)
	_craft_changed()


func _take_all_results(out_id: String, per_craft: int) -> void:
	var times := 0
	var cells: Array = []
	for i in craft_size * craft_size:
		if not craft_items[i].is_empty():
			cells.append(i)
	if cells.is_empty():
		return
	times = int(craft_items[cells[0]]["count"])
	for i in cells:
		times = mini(times, int(craft_items[i]["count"]))
	if times <= 0:
		return
	for i in cells:
		var item: Dictionary = craft_items[i]
		item["count"] = int(item["count"]) - times
		if int(item["count"]) <= 0:
			craft_items[i] = {}
	var total := times * per_craft
	_give_back({"id": out_id, "count": total})
	_craft_changed()


func _grid_count(id: String) -> int:
	var total := 0
	for item in craft_items:
		if not item.is_empty() and item["id"] == id:
			total += int(item["count"])
	return total


func _can_craft(r: Dictionary) -> bool:
	if Recipes.needs_table(r) and not table_mode:
		return false
	var counts := Recipes.ingredient_counts(r)
	for id in counts:
		if Inventory.get_count(id) + _grid_count(id) < int(counts[id]):
			return false
	return true


func _fill_needs(row: Button, r: Dictionary) -> void:
	var needs: HBoxContainer = row.get_node("Box/Info/Needs")
	var counts := Recipes.ingredient_counts(r)
	for id in counts:
		var want := int(counts[id])
		var entry: HBoxContainer = RECIPE_INGREDIENT.instantiate()
		(entry.get_node("Icon") as TextureRect).texture = TileArt.icon(id)
		var count_label: Label = entry.get_node("Count")
		var lacking: bool = Inventory.get_count(id) + _grid_count(id) < want
		count_label.text = "" if want <= 1 and not lacking else str(want)
		if lacking:
			count_label.add_theme_color_override("font_color", MISSING_COLOR)
		needs.add_child(entry)
	if Recipes.needs_table(r):
		var table_entry: HBoxContainer = RECIPE_INGREDIENT.instantiate()
		(table_entry.get_node("Icon") as TextureRect).texture = TileArt.icon("workbench")
		(table_entry.get_node("Count") as Label).text = ""
		needs.add_child(table_entry)


func _toggle_recipes() -> void:
	recipe_panel.visible = not recipe_panel.visible
	if recipe_panel.visible:
		_refresh_recipes()


func _on_inventory_changed() -> void:
	_refresh()
	if open and recipe_panel.visible:
		_refresh_recipes()


func _refresh_recipes() -> void:
	for child in recipe_list.get_children():
		recipe_list.remove_child(child)
		child.queue_free()
	for r in Recipes.LIST:
		if not Recipes.known(r, Inventory.discovered):
			continue
		var can := _can_craft(r)
		var row: Button = RECIPE_ROW.instantiate()
		(row.get_node("Box/Icon") as TextureRect).texture = TileArt.icon(r["out"])
		(row.get_node("Box/Info/Title") as Label).text = "%s x%d" % [Inventory.item_name(r["out"]), int(r["count"])]
		_fill_needs(row, r)
		row.set_pressed_no_signal(can)
		row.modulate = Color(1, 1, 1, 1) if can else Color(1, 1, 1, 0.5)
		row.pressed.connect(_on_recipe_pressed.bind(r["id"], row, can))
		recipe_list.add_child(row)


func _on_recipe_pressed(id: String, row: Button, can: bool) -> void:
	row.set_pressed_no_signal(can)
	var r := Recipes.by_id(id)
	if not can:
		if Recipes.needs_table(r) and not table_mode:
			_flash("Needs a workbench")
		else:
			_flash("Missing ingredients")
		return
	if not current_recipe.is_empty() and current_recipe["id"] == id and _add_set(r):
		return
	_autofill(r)


func _layout(r: Dictionary) -> Dictionary:
	var out := {}
	if r.has("shapeless"):
		var i := 0
		for id in r["shapeless"]:
			out[i] = id
			i += 1
	else:
		var shape: Array = r["shape"]
		for row in shape.size():
			for col in shape[row].size():
				var id: String = shape[row][col]
				if id != "":
					out[row * craft_size + col] = id
	return out


func _autofill(r: Dictionary) -> void:
	_return_craft_items()
	var layout := _layout(r)
	for index in layout:
		var id: String = layout[index]
		if Inventory.take_item(id, 1):
			craft_items[index] = {"id": id, "count": 1}
	_craft_changed()


func _add_set(r: Dictionary) -> bool:
	var layout := _layout(r)
	for index in layout:
		var item: Dictionary = craft_items[index]
		if item.is_empty() or item["id"] != layout[index]:
			return false
	var counts := Recipes.ingredient_counts(r)
	for id in counts:
		if Inventory.get_count(id) < int(counts[id]):
			_flash("Missing ingredients")
			return true
	for index in layout:
		if int(craft_items[index]["count"]) >= Inventory.max_stack(layout[index]):
			_flash("Slot full")
			return true
	for index in layout:
		if Inventory.take_item(layout[index], 1):
			craft_items[index]["count"] = int(craft_items[index]["count"]) + 1
	_craft_changed()
	return true


func _refresh(_index: int = 0) -> void:
	if slot_nodes.is_empty():
		return
	for s in slot_nodes:
		var item: Dictionary = preview.get(s, _get(s))
		s.show_item(item)
		var is_selected: bool = s.index >= 0 and s.index == Inventory.selected
		s.set_state(is_selected, s == hovered)
	if pending and drag_slots.size() > 1:
		if preview_left > 0:
			cursor_slot.show_item({"id": cursor["id"], "count": preview_left})
		else:
			cursor_slot.show_item({})
	else:
		cursor_slot.show_item(cursor)
