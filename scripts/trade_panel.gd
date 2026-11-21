extends CanvasLayer

var player
var folk
var is_open: bool = false

@onready var root: Control = %Root
@onready var title: Label = %Title
@onready var trades: VBoxContainer = %Trades
@onready var close_button: Button = %Close


func setup(p) -> void:
	player = p
	player.trader_used.connect(open_for)
	close_button.pressed.connect(close)


func open_for(f) -> void:
	if is_open or player == null or player.dead or player.frozen:
		return
	folk = f
	is_open = true
	title.text = f.display_name
	root.visible = true
	player.frozen = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh()


func close() -> void:
	if not is_open:
		return
	is_open = false
	root.visible = false
	player.frozen = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _refresh() -> void:
	for c in trades.get_children():
		c.queue_free()
	for t: Dictionary in folk.trades:
		var b := Button.new()
		var give_name: String = Inventory.ITEMS[t["give"]]["name"]
		var get_name: String = Inventory.ITEMS[t["get"]]["name"]
		b.text = "%s x%d  >  %s x%d" % [give_name, t["give_n"], get_name, t["get_n"]]
		b.disabled = Inventory.get_count(t["give"]) < int(t["give_n"])
		b.pressed.connect(_do_trade.bind(t))
		trades.add_child(b)


func _do_trade(t: Dictionary) -> void:
	if not Inventory.take_item(t["give"], int(t["give_n"])):
		_refresh()
		return
	var left := Inventory.add_item(t["get"], int(t["get_n"]))
	if left > 0:
		get_tree().current_scene.spawn_drop(t["get"], left, player.global_position + Vector3(0.0, 1.0, 0.0))
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
