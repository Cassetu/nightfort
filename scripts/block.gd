extends "res://scripts/resource_node.gd"

const TileArt = preload("res://scripts/tile_art.gd")

const SUPPORT_INTERVAL := 0.25

var block_type: String = "wood"
var needs_support: bool = false
var support_timer: float = 0.0
var terrain
var structural: bool = true
var falls: bool = false
var weight: int = 2
var max_load: int = 99
var collapsing: bool = false
var falling_now: bool = false

static var _materials: Dictionary = {}


func _configure() -> void:
	var info: Dictionary = Inventory.BLOCK_TYPES[block_type]
	resource_type = info["resource"]
	resource_amount = Inventory.BLOCK_COST
	max_health = info["health"]
	chip_color = info["color"]
	add_to_group("block")
	terrain = get_tree().get_first_node_in_group("terrain")
	structural = info.get("structural", true)
	falls = info.get("falls", false)
	weight = int(info.get("weight", 2))
	max_load = int(info.get("max_load", 99))
	_mark_stability()


func _build() -> void:
	var mesh := BoxMesh.new()
	mesh.material = _material_for(block_type)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	visual.add_child(mi)

	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	add_child(col)


func _process(delta: float) -> void:
	if not needs_support or dying:
		return
	support_timer += delta
	if support_timer < SUPPORT_INTERVAL:
		return
	support_timer = 0.0
	if not _supported():
		take_damage(max_health)


func _supported() -> bool:
	var cx := floori(global_position.x)
	var cy := floori(global_position.y)
	var cz := floori(global_position.z)
	if terrain != null and terrain.block_at(cx, cy - 1, cz) != 0:
		return true
	var below := Vector3(cx + 0.5, cy - 0.5, cz + 0.5)
	for n in get_tree().get_nodes_in_group("block"):
		if n != self and not n.dying and n.covers(below):
			return true
	return false


func cells() -> Array:
	var base := Vector3i(floori(global_position.x), floori(global_position.y), floori(global_position.z))
	var height := int(Inventory.BLOCK_TYPES[block_type].get("height", 1))
	var out: Array = []
	for i in height:
		out.append(base + Vector3i(0, i, 0))
	return out


func _mark_stability() -> void:
	if is_inside_tree():
		get_tree().call_group("stability", "mark_dirty")


func _die() -> void:
	super()
	_mark_stability()


func _exit_tree() -> void:
	if structural and is_inside_tree():
		_mark_stability()


func begin_collapse(delay: float) -> void:
	if collapsing or dying:
		return
	collapsing = true
	var tween := create_tween().set_loops(int(delay / 0.12) + 1)
	tween.tween_property(visual, "rotation:z", 0.04, 0.06)
	tween.tween_property(visual, "rotation:z", -0.04, 0.06)
	get_tree().create_timer(delay).timeout.connect(_finish_collapse.bind(tween))


func _finish_collapse(tween: Tween) -> void:
	if tween != null:
		tween.kill()
	if dying or not is_inside_tree():
		return
	visual.rotation = Vector3.ZERO
	var stability := get_tree().get_first_node_in_group("stability")
	if stability != null and not stability.is_unstable(self):
		collapsing = false
		return
	if randf() < 0.5:
		resource_amount = 0
	take_damage(max_health)


func fall_to(target_cell: Vector3i) -> void:
	if falling_now or dying:
		return
	falling_now = true
	var target_y := float(target_cell.y) + 0.5
	var drop := maxf(global_position.y - target_y, 0.0)
	var time := maxf(sqrt(2.0 * drop / 22.0), 0.12)
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", target_y, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_landed)


func _landed() -> void:
	falling_now = false
	_mark_stability()


func covers(p: Vector3) -> bool:
	var d := (p - global_position).abs()
	return d.x < 0.6 and d.y < 0.6 and d.z < 0.6


static func _material_for(type: String) -> StandardMaterial3D:
	if not _materials.has(type):
		var info: Dictionary = Inventory.BLOCK_TYPES[type]
		_materials[type] = TileArt.block_material(info.get("tile", type), info["color"])
	return _materials[type]
