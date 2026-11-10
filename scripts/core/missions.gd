extends CanvasLayer

const EntryScene = preload("res://scenes/mission_entry.tscn")
const BlockIndex = preload("res://scripts/block_index.gd")

const MAX_VISIBLE := 2
const RUINS_INDEX := 7
const ARROWS := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
const MARGIN := Vector2(90.0, 70.0)
const MARKER_LIFT := 6.0
const RETARGET := 1.0

const LIST := [
	{"title": "Take down a tree", "desc": "Left click to punch a tree", "event": "tree"},
	{"title": "Craft a workbench", "desc": "Craft with 4 wood", "item": "workbench", "needs": {"wood": 4}},
	{"title": "Craft a wooden pickaxe", "desc": "Craft with fiber (from breaking plants), sticks, and planks", "item": "wooden_pickaxe", "needs": {"plank": 3, "fiber": 2, "stick": 2}},
	{"title": "Gather stone", "desc": "Find a mountain, go underground, or break rocks", "item": "stone"},
	{"title": "Craft a stone pickaxe", "desc": "Same as wood, but this time with stone", "item": "stone_pickaxe", "needs": {"stone": 3, "fiber": 2, "stick": 2}},
	{"title": "Craft a forge", "desc": "Behind the core should be a mountain, explore the mountain for a cave opening. Mine coal to craft a forge", "item": "stone_forge", "needs": {"stone_brick": 8, "coal": 1}},
	{"title": "Craft an iron item with the forge", "desc": "To forge successfully, you need to click the circles before they disappear", "event": "forged"},
	{"title": "Gather a soul crystal", "desc": "Head to the marked ruins, typically 90-170 units out", "item": "soul_gem"},
]

@onready var list: VBoxContainer = %List
@onready var marker: Label = %Marker

var world
var player
var done: int = 0
var entries: Dictionary = {}
var target := Vector3.INF
var retarget_timer: float = 0.0


func _ready() -> void:
	add_to_group("missions")
	Inventory.item_added.connect(_on_item_added)
	Inventory.changed.connect(_update_progress)


func setup(w, p) -> void:
	world = w
	player = p
	_sync()


func export_state() -> Dictionary:
	return {"done": done}


func import_state(d: Dictionary) -> void:
	done = clampi(int(d.get("done", 0)), 0, LIST.size())
	for idx in entries.keys():
		entries[idx].queue_free()
	entries.clear()
	_sync()


func on_event(id: String) -> void:
	for i in LIST.size():
		if i >= done and str(LIST[i].get("event", "")) == id:
			_complete(i)
			return


func _on_item_added(id: String, _amount: int) -> void:
	for i in range(done, LIST.size()):
		if str(LIST[i].get("item", "")) == id:
			_complete(i)
			return


func _complete(index: int) -> void:
	if index < done:
		return
	done = index + 1
	_sync()


func _sync() -> void:
	if list == null:
		return
	for idx in entries.keys():
		if idx < done:
			_retire(idx)
	for idx in range(done, mini(done + MAX_VISIBLE, LIST.size())):
		if not entries.has(idx):
			_add_entry(idx)
	_update_progress()


func _add_entry(idx: int) -> void:
	var entry: Control = EntryScene.instantiate()
	list.add_child(entry)
	var data: Dictionary = LIST[idx]
	(entry.get_node("Box/Title") as Label).text = str(data["title"])
	(entry.get_node("Box/Desc") as Label).text = str(data["desc"])
	entry.modulate.a = 0.0
	create_tween().tween_property(entry, "modulate:a", 1.0, 0.3)
	entries[idx] = entry


func _retire(idx: int) -> void:
	var entry: Control = entries[idx]
	entries.erase(idx)
	var bar: ProgressBar = entry.get_node("Box/Bar")
	var tween := create_tween()
	tween.tween_property(bar, "value", 1.0, 0.25)
	tween.tween_interval(0.6)
	tween.tween_property(entry, "modulate:a", 0.0, 0.4)
	tween.tween_callback(entry.queue_free)


func _progress(idx: int) -> float:
	var needs: Dictionary = LIST[idx].get("needs", {})
	if needs.is_empty():
		return 0.0
	var have := 0
	var total := 0
	for id in needs:
		total += int(needs[id])
		have += mini(Inventory.get_count(id), int(needs[id]))
	return float(have) / float(maxi(total, 1)) * 0.9


func _update_progress() -> void:
	for idx in entries:
		var bar: ProgressBar = entries[idx].get_node("Box/Bar")
		bar.value = _progress(idx)


func _process(delta: float) -> void:
	if done != RUINS_INDEX or not is_instance_valid(player):
		marker.visible = false
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		marker.visible = false
		return
	retarget_timer -= delta
	if retarget_timer <= 0.0 or target == Vector3.INF:
		retarget_timer = RETARGET
		target = _nearest_ruins()
	if target == Vector3.INF:
		marker.visible = false
		return
	_place(cam, target + Vector3(0.0, MARKER_LIFT, 0.0))


func _nearest_ruins() -> Vector3:
	var from: Vector3 = player.global_position
	var best := Vector3.INF
	var best_d := INF
	var sites: Array = world.outposts if world != null else []
	for s in sites:
		var d := from.distance_squared_to(s)
		if d < best_d:
			best_d = d
			best = s
	if best != Vector3.INF:
		return best
	for b in BlockIndex.list:
		if is_instance_valid(b) and b.block_type == "soul_block":
			var p: Vector3 = b.global_position
			var d := from.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = p
	return best


func _place(cam: Camera3D, p: Vector3) -> void:
	var dist := cam.global_position.distance_to(p)
	var view := get_viewport().get_visible_rect().size
	var center := view * 0.5
	var behind := cam.is_position_behind(p)
	var sp := cam.unproject_position(p)
	if behind:
		sp = center - (sp - center)
	var on_screen := not behind and sp.x > MARGIN.x and sp.x < view.x - MARGIN.x and sp.y > MARGIN.y and sp.y < view.y - MARGIN.y
	var arrow := "▼"
	if not on_screen:
		var dir := sp - center
		if dir.length() < 1.0:
			dir = Vector2.UP
		var k := minf((center.x - MARGIN.x) / maxf(absf(dir.x), 0.001), (center.y - MARGIN.y) / maxf(absf(dir.y), 0.001))
		sp = center + dir * k
		var slot := int(roundf(dir.angle() / (TAU / 8.0)))
		arrow = ARROWS[posmod(slot, 8)]
	var text := "Ruins %du\n%s" % [roundi(dist), arrow]
	if text != marker.text:
		marker.text = text
		marker.reset_size()
	marker.visible = true
	if on_screen:
		marker.position = sp - Vector2(marker.size.x * 0.5, marker.size.y)
	else:
		marker.position = sp - marker.size * 0.5
