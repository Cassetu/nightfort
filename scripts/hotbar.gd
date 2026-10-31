extends Control

const SLOT_SIZE := 64.0
const GAP := 4.0

var slots: Array = []
var title: Label


func _ready() -> void:
	var total := Inventory.SLOT_COUNT * SLOT_SIZE + (Inventory.SLOT_COUNT - 1) * GAP

	title = Label.new()
	title.position = Vector2(0.0, -30.0)
	title.size = Vector2(total, 24.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	add_child(title)

	for i in Inventory.SLOT_COUNT:
		slots.append(_make_slot(i))

	Inventory.changed.connect(_on_changed)
	Inventory.selection_changed.connect(_on_selection_changed)
	_refresh()


func _make_slot(index: int) -> Dictionary:
	var panel := Panel.new()
	panel.position = Vector2(index * (SLOT_SIZE + GAP), 0.0)
	panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var number := Label.new()
	number.text = str(index + 1)
	number.position = Vector2(6.0, 2.0)
	number.add_theme_font_size_override("font_size", 14)
	panel.add_child(number)

	var icon := ColorRect.new()
	icon.position = Vector2(18.0, 18.0)
	icon.size = Vector2(28.0, 28.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)

	var count := Label.new()
	count.position = Vector2(0.0, SLOT_SIZE - 24.0)
	count.size = Vector2(SLOT_SIZE - 6.0, 20.0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_font_size_override("font_size", 16)
	panel.add_child(count)

	return {"style": style, "icon": icon, "count": count}


func _on_changed(_item, _count) -> void:
	_refresh()


func _on_selection_changed(_index) -> void:
	_refresh()


func _refresh() -> void:
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var data: Dictionary = Inventory.hotbar[i]
		var style: StyleBoxFlat = slot["style"]
		var is_selected: bool = i == Inventory.selected

		style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
		if is_selected:
			style.border_color = Color(1.0, 0.8, 0.2, 1.0)
			style.set_border_width_all(4)
		else:
			style.border_color = Color(1.0, 1.0, 1.0, 0.25)
			style.set_border_width_all(2)

		var icon: ColorRect = slot["icon"]
		var count: Label = slot["count"]
		if data.is_empty():
			icon.visible = false
			count.text = ""
			if is_selected:
				title.text = ""
		else:
			var info: Dictionary = Inventory.BLOCK_TYPES[data["type"]]
			var have: int = Inventory.get_count(info["resource"])
			icon.visible = true
			icon.color = info["color"]
			count.text = str(have)
			if have >= Inventory.BLOCK_COST:
				count.modulate = Color(1.0, 1.0, 1.0)
			else:
				count.modulate = Color(1.0, 0.4, 0.4)
			if is_selected:
				title.text = info["name"]
