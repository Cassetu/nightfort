extends Node3D

const BileSack = preload("res://scripts/enemies/bile_sack.gd")

const NEAR := 7.0
const REACH := 0.95
const POOL_REACH := 0.75
const POOL_TOP := 0.35
const POOL_DEPTH := -0.6
const BODY_HEIGHT := 1.8
const BLOCK_SLACK := 0.05

var blocks := PackedVector3Array()
var pools := PackedVector3Array()
var timer: float = 0.0
var player


func _physics_process(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	timer = BileSack.TICK
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	if player.dead:
		return
	var local := to_local(player.global_position)
	if Vector2(local.x, local.z).length() > NEAR:
		return
	if _touching(local):
		player.take_damage(BileSack.TICK_PLAYER, global_position)


func _touching(local: Vector3) -> bool:
	for b in blocks:
		if absf(local.x - b.x) < REACH and absf(local.z - b.z) < REACH and local.y < b.y + 0.5 + BLOCK_SLACK and local.y + BODY_HEIGHT > b.y - 0.5:
			return true
	for p in pools:
		if absf(local.x - p.x) < POOL_REACH and absf(local.z - p.z) < POOL_REACH and local.y < POOL_TOP and local.y > POOL_DEPTH:
			return true
	return false
