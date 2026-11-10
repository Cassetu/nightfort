extends CanvasLayer

const ForgeRecipes = preload("res://scripts/forge/forge_recipes.gd")
const RECIPE_ROW := preload("res://scenes/recipe_row.tscn")
const SessionScene := preload("res://scenes/forge_minigame.tscn")

@onready var root: Control = $Root
@onready var recipe_list: VBoxContainer = %RecipeList
@onready var close_button: Button = %CloseButton

var player
var world
var inv_ui
var forge
var session
var open: bool = false
var current: Dictionary = {}
var rows: Dictionary = {}


func _ready() -> void:
	root.visible = false
	close_button.pressed.connect(close)
	session = SessionScene.instantiate()
	add_child(session)
	session.finished.connect(_on_finished)


func setup(p, w, inventory_ui) -> void:
	player = p
	world = w
	inv_ui = inventory_ui


func open_forge(f) -> void:
	if open or session.active or not inv_ui.can_open():
		return
	forge = f
	open = true
	root.visible = true
	player.frozen = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_list()


func close() -> void:
	if not open:
		return
	open = false
	root.visible = false
	player.frozen = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func force_close() -> void:
	if session.active:
		session.abort()
	if open:
		open = false
		root.visible = false
		player.frozen = false
	if player != null and player.dead:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _input(event: InputEvent) -> void:
	if open and event.is_action_pressed("ui_cancel"):
		close()
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
		row.modulate = Color(1, 1, 1, 1) if ForgeRecipes.can_afford(r) else Color(1, 1, 1, 0.5)
		row.pressed.connect(_on_row_pressed.bind(r["id"]))
		recipe_list.add_child(row)
		rows[r["id"]] = row


func _on_row_pressed(id: String) -> void:
	var r := ForgeRecipes.by_id(id)
	if r.is_empty() or not ForgeRecipes.can_afford(r):
		return
	var cost: Dictionary = r["cost"]
	for mat in cost:
		Inventory.take_item(mat, int(cost[mat]))
	Inventory.take_item("coal", int(r["coal"]))
	current = r
	open = false
	root.visible = false
	session.begin(player, forge, r)


func _on_finished(result: String) -> void:
	var id: String = current["id"]
	if result == "won":
		get_tree().call_group("missions", "on_event", "forged")
		var left := Inventory.add_item(id, 1)
		if left > 0:
			world.spawn_drop(id, left, player.global_position + Vector3(0.0, 1.0, 0.0))
		return
	var cost: Dictionary = current["cost"]
	for mat in cost:
		var left := Inventory.add_item(mat, int(cost[mat]))
		if left > 0:
			world.spawn_drop(mat, left, player.global_position + Vector3(0.0, 1.0, 0.0))
