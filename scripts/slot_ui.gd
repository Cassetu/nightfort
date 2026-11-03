extends Panel

const TileArt = preload("res://scripts/tile_art.gd")

@export var index: int = -1
@export var equip: String = ""
@export var number: int = 0
@export var craft: int = -1
@export var is_result: bool = false

@onready var icon: ColorRect = %Icon
@onready var art: TextureRect = %Art
@onready var count_label: Label = %Count
@onready var number_label: Label = %Number
@onready var hint_label: Label = %Hint

var variation: StringName = &"SlotPanel"


func _ready() -> void:
	variation = theme_type_variation
	number_label.text = str(number) if number > 0 else ""
	hint_label.text = equip.capitalize()
	show_item({})


func show_item(item: Dictionary) -> void:
	if item.is_empty():
		icon.visible = false
		art.visible = false
		count_label.text = ""
		hint_label.visible = equip != ""
		return

	hint_label.visible = false
	var info: Dictionary = Inventory.ITEMS.get(item["id"], {})
	var tex := TileArt.icon(item["id"], info.get("tile", ""))
	art.texture = tex
	art.visible = tex != null
	icon.visible = tex == null
	icon.color = info.get("color", Color.WHITE)
	if info.get("kind", "") == "weapon":
		icon.size = Vector2(8.0, 38.0)
		icon.position = Vector2(28.0, 13.0)
		icon.pivot_offset = icon.size * 0.5
		icon.rotation = 0.785
	else:
		icon.size = Vector2(28.0, 28.0)
		icon.position = Vector2(18.0, 18.0)
		icon.pivot_offset = icon.size * 0.5
		icon.rotation = 0.0
	var count := int(item["count"])
	count_label.text = str(count) if count > 1 else ""


func set_state(is_selected: bool, is_hover: bool) -> void:
	var wanted: StringName = &"SlotPanel"
	if is_selected:
		wanted = &"SlotSelected"
	elif is_hover:
		wanted = &"SlotHover"
	if wanted != variation:
		variation = wanted
		theme_type_variation = wanted
