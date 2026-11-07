extends Node

const SIZE := 96
const COLUMNS_PER_FRAME := 420
const IDLE := 0.4
const UNKNOWN := -1000.0

var terrain
var player
var data := PackedFloat32Array()
var next := PackedFloat32Array()
var origin := Vector2i.ZERO
var next_origin := Vector2i.ZERO
var cursor: int = 0
var building: bool = false
var idle: float = 0.0
var texture: ImageTexture
var ready_flag: bool = false


func setup(t, p) -> void:
	terrain = t
	player = p
	data.resize(SIZE * SIZE)
	next.resize(SIZE * SIZE)
	data.fill(UNKNOWN)
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RF)
	texture = ImageTexture.create_from_image(img)
	if terrain.material != null:
		terrain.material.set_shader_parameter("roof_map", texture)
		terrain.material.set_shader_parameter("roof_size", float(SIZE))
		terrain.material.set_shader_parameter("roof_ready", 0.0)


func _process(delta: float) -> void:
	if terrain == null or player == null or not is_instance_valid(player):
		return
	if not building:
		idle += delta
		if idle < IDLE and ready_flag:
			return
		var p: Vector3 = player.global_position
		next_origin = Vector2i(floori(p.x), floori(p.z)) - Vector2i(SIZE / 2, SIZE / 2)
		cursor = 0
		building = true
	var end := mini(cursor + COLUMNS_PER_FRAME, SIZE * SIZE)
	for idx in range(cursor, end):
		var x := next_origin.x + idx % SIZE
		var z := next_origin.y + idx / SIZE
		next[idx] = float(terrain.surface_y(x, z))
	cursor = end
	if cursor >= SIZE * SIZE:
		_finish()


func _finish() -> void:
	for n in get_tree().get_nodes_in_group("block"):
		if n.dying:
			continue
		var info: Dictionary = Inventory.BLOCK_TYPES.get(n.block_type, {})
		if not info.get("structural", true):
			continue
		for c: Vector3i in n.cells():
			var i := c.x - next_origin.x
			var j := c.z - next_origin.y
			if i < 0 or j < 0 or i >= SIZE or j >= SIZE:
				continue
			var idx := j * SIZE + i
			next[idx] = maxf(next[idx], float(c.y + 1))
	var tmp := data
	data = next
	next = tmp
	origin = next_origin
	var img := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RF, data.to_byte_array())
	texture.update(img)
	ready_flag = true
	building = false
	idle = 0.0
	if terrain.material != null:
		terrain.material.set_shader_parameter("roof_origin", Vector2(origin))
		terrain.material.set_shader_parameter("roof_ready", 1.0)


func height_at(x: float, z: float) -> float:
	if not ready_flag:
		return UNKNOWN
	var i := floori(x) - origin.x
	var j := floori(z) - origin.y
	if i < 0 or j < 0 or i >= SIZE or j >= SIZE:
		return UNKNOWN
	return data[j * SIZE + i]
