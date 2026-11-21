extends Node

const BlockIndex = preload("res://scripts/block_index.gd")
const BlockBatch = preload("res://scripts/block_batch.gd")
const INTERVAL := 0.4
const EDGE_MARGIN := 64.0

var terrain
var timer: float = 0.0
var seen: Dictionary = {}


func setup(t) -> void:
	terrain = t
	timer = INTERVAL


func _managed(x: float, z: float) -> bool:
	return Vector2(x, z).length() <= terrain.world_radius + EDGE_MARGIN


func _loaded(coord: Vector2i) -> bool:
	if seen.has(coord):
		return seen[coord]
	var ok: bool = terrain.chunks.has(coord)
	seen[coord] = ok
	return ok


func _process(delta: float) -> void:
	if terrain == null:
		return
	timer += delta
	if timer < INTERVAL:
		return
	timer = 0.0
	seen.clear()
	for key: String in BlockBatch.groups.keys():
		var group = BlockBatch.groups[key]
		if group == null or group.node == null or not is_instance_valid(group.node):
			continue
		var parts := key.split(",")
		if parts.size() < 2:
			continue
		var gx: int = int(parts[0])
		var gz: int = int(parts[1])
		var vis := true
		if _managed((float(gx) + 0.5) * BlockBatch.CHUNK, (float(gz) + 0.5) * BlockBatch.CHUNK):
			vis = _loaded(Vector2i(gx, gz))
		if group.node.visible != vis:
			group.node.visible = vis
	for n in BlockIndex.list:
		if not is_instance_valid(n):
			continue
		_apply(n)
	for n in get_tree().get_nodes_in_group("scenery_cull"):
		if n is Node3D:
			_apply(n)


func _apply(n: Node3D) -> void:
	var pos: Vector3 = n.global_position
	var vis := true
	if _managed(pos.x, pos.z):
		vis = _loaded(terrain._chunk_of(pos))
	if n.visible != vis:
		n.visible = vis
