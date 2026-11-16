extends RefCounted

const Sfx = preload("res://scripts/core/sfx.gd")

const KEY := "footstep_dirt"
const MIN_SPEED := 0.6
const HEARD_RANGE := 30.0
const DIRT_BLOCKS := [1, 2]

var node: CharacterBody3D
var stride: float
var volume_db: float
var positional: bool
var travelled: float = 0.0
var terrain: Node
var player: Node3D


func _init(body: CharacterBody3D, stride_length: float, vol_db: float, spatial: bool = true) -> void:
	node = body
	stride = stride_length
	volume_db = vol_db
	positional = spatial


func update(delta: float, allowed: bool = true) -> void:
	if not node.is_on_floor():
		return
	var speed := Vector2(node.velocity.x, node.velocity.z).length()
	if speed < MIN_SPEED:
		return
	travelled += speed * delta
	if travelled < stride:
		return
	travelled = fmod(travelled, stride)
	if not allowed:
		return
	if positional and not _near():
		return
	if not _on_dirt():
		return
	Sfx.play(node, KEY, node.global_position if positional else Vector3.INF, volume_db)


func _near() -> bool:
	if player == null or not is_instance_valid(player):
		player = node.get_tree().get_first_node_in_group("player") as Node3D
		if player == null:
			return true
	return player.global_position.distance_squared_to(node.global_position) <= HEARD_RANGE * HEARD_RANGE


func _feet_y() -> float:
	for child in node.get_children():
		if child is CollisionShape3D:
			var cs := child as CollisionShape3D
			var shape := cs.shape
			if shape is CapsuleShape3D:
				return node.global_position.y + cs.position.y - (shape as CapsuleShape3D).height * 0.5
			if shape is BoxShape3D:
				return node.global_position.y + cs.position.y - (shape as BoxShape3D).size.y * 0.5
			if shape is SphereShape3D:
				return node.global_position.y + cs.position.y - (shape as SphereShape3D).radius
			if shape is CylinderShape3D:
				return node.global_position.y + cs.position.y - (shape as CylinderShape3D).height * 0.5
	return node.global_position.y - 0.9


func _on_dirt() -> bool:
	if terrain == null or not is_instance_valid(terrain):
		terrain = node.get_tree().get_first_node_in_group("terrain")
		if terrain == null:
			return false
	var pos := node.global_position
	var id: int = terrain.block_at(floori(pos.x), floori(_feet_y() - 0.15), floori(pos.z))
	return DIRT_BLOCKS.has(id)
