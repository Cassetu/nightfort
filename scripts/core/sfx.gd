extends RefCounted


static func play(node: Node, key: String, pos: Vector3 = Vector3.INF, vol_db: float = 0.0) -> void:
	if node == null or not node.is_inside_tree():
		return
	var manager = node.get_tree().get_first_node_in_group("audio_manager")
	if manager != null:
		manager.play(key, pos, vol_db)
