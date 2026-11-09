extends RefCounted

const ENABLED := true
const CHUNK := 16

class Group:
	var key: String
	var node: MultiMeshInstance3D
	var multimesh: MultiMesh
	var members: Array = []
	var pending: bool = false

	func rebuild() -> void:
		pending = false
		if node == null or not is_instance_valid(node):
			return
		var count := members.size()
		if count == 0:
			node.queue_free()
			node = null
			return
		if multimesh.instance_count < count or multimesh.instance_count > count * 3:
			multimesh.instance_count = maxi(count + count / 2, 8)
		multimesh.visible_instance_count = count
		for i in count:
			var b: Node3D = members[i]
			multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, b.global_position))


static var groups: Dictionary = {}
static var owner_of: Dictionary = {}


static func add(block: Node3D, material: Material, tag: String) -> bool:
	if not ENABLED or not block.is_inside_tree():
		return false
	var scene := block.get_tree().current_scene
	if scene == null:
		return false
	var p := block.global_position
	var key := "%d,%d,%s" % [floori(p.x / CHUNK), floori(p.z / CHUNK), tag]
	var group: Group = groups.get(key)
	if group == null or group.node == null or not is_instance_valid(group.node):
		group = Group.new()
		group.key = key
		var mesh := BoxMesh.new()
		mesh.material = material
		group.multimesh = MultiMesh.new()
		group.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		group.multimesh.mesh = mesh
		group.multimesh.instance_count = 8
		group.multimesh.visible_instance_count = 0
		group.node = MultiMeshInstance3D.new()
		group.node.multimesh = group.multimesh
		scene.add_child(group.node)
		groups[key] = group
	group.members.append(block)
	owner_of[block.get_instance_id()] = group
	_schedule(group)
	return true


static func remove(block: Node) -> void:
	var id := block.get_instance_id()
	var group: Group = owner_of.get(id)
	if group == null:
		return
	owner_of.erase(id)
	var idx := group.members.find(block)
	if idx >= 0:
		group.members.remove_at(idx)
	if group.members.is_empty() and groups.get(group.key) == group:
		groups.erase(group.key)
	_schedule(group)


static func has(block: Node) -> bool:
	return owner_of.has(block.get_instance_id())


static func _schedule(group: Group) -> void:
	if group.pending:
		return
	group.pending = true
	group.rebuild.call_deferred()
