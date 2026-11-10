extends Node3D

const EDGE_WIDTH := 1.0
const DEFAULT_RANGE := 20.0
const EYE_HEIGHT := 1.5
const LIFT := 0.05
const REBUILD_INTERVAL := 0.15
const BLUE := Color(0.25, 0.55, 1.0)
const YELLOW := Color(1.0, 0.85, 0.2)
const MAX_CACHE := 30000

static var heights: Dictionary = {}

var terrain
var blue_node: MultiMeshInstance3D
var yellow_node: MultiMeshInstance3D
var key: String = ""
var cooldown: float = 0.0


func _ready() -> void:
	top_level = true
	terrain = get_tree().get_first_node_in_group("terrain")
	blue_node = _make_layer(BLUE, 0.14)
	yellow_node = _make_layer(YELLOW, 0.18)
	hide()


func _make_layer(color: Color, radius: float) -> MultiMeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	mesh.radial_segments = 8
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)


func clear() -> void:
	if visible:
		hide()
	key = ""


func show_for(banner_type: String, ref: Vector3) -> void:
	if banner_type == "" or not ref.is_finite() or terrain == null:
		clear()
		return
	var reach := _range_for(banner_type)
	var cell := Vector3i(floori(ref.x), floori(ref.y), floori(ref.z))
	var new_key := "%d,%d,%d|%.1f" % [cell.x, cell.y, cell.z, reach]
	if new_key == key:
		if not visible:
			show()
		return
	if cooldown > 0.0 and visible:
		return
	cooldown = REBUILD_INTERVAL
	key = new_key
	_rebuild(cell, reach)
	show()


func _range_for(banner_type: String) -> float:
	var id := int(banner_type.trim_prefix("banner_"))
	for t in get_tree().get_nodes_in_group("troop"):
		if is_instance_valid(t) and int(t.troop_id) == id:
			return float(t.weapon_info().get("range", DEFAULT_RANGE))
	return DEFAULT_RANGE


func _ground(x: int, z: int) -> float:
	var k := Vector2i(x, z)
	if heights.has(k):
		return heights[k]
	if heights.size() > MAX_CACHE:
		heights.clear()
	var h := float(terrain.surface_y(x, z))
	heights[k] = h
	return h


func _rebuild(cell: Vector3i, reach: float) -> void:
	var eye := Vector3(float(cell.x) + 0.5, float(cell.y) + EYE_HEIGHT, float(cell.z) + 0.5)
	var blue: Array = []
	var yellow: Array = []
	var r := int(ceil(reach)) + 1
	var limit := (reach + 1.0) * (reach + 1.0)
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > limit:
				continue
			var x := cell.x + dx
			var z := cell.z + dz
			var p := Vector3(float(x) + 0.5, _ground(x, z) + LIFT, float(z) + 0.5)
			var d := eye.distance_to(p)
			if d > reach:
				continue
			if d >= reach - EDGE_WIDTH:
				yellow.append(p)
			elif posmod(x, 2) == 0 and posmod(z, 2) == 0:
				blue.append(p)
	_fill(blue_node, blue)
	_fill(yellow_node, yellow)


func _fill(node: MultiMeshInstance3D, points: Array) -> void:
	var mm := node.multimesh
	mm.instance_count = points.size()
	for i in points.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, points[i]))
