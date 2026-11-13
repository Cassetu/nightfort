extends Node

const MAX_SHADOWS: int = 4
const NEAR_RANGE: float = 42.0
const INTERVAL: float = 0.3

var timer: float = 0.0


func _process(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	timer = INTERVAL
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var origin: Vector3 = cam.global_position
	var ranked: Array = []
	for node in get_tree().get_nodes_in_group("torch"):
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_inside_tree():
			continue
		ranked.append([origin.distance_squared_to(node.global_position), node])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var rank: int = 0
	var near_sq: float = NEAR_RANGE * NEAR_RANGE
	for entry in ranked:
		var torch = entry[1]
		if torch.shadow_locked:
			torch.near = entry[0] < near_sq
			continue
		torch.set_shadowed(rank < MAX_SHADOWS)
		torch.near = entry[0] < near_sq
		rank += 1
