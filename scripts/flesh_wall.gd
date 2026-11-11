extends StaticBody3D

const ChipBurst = preload("res://scripts/chip_burst.gd")

const MAX_HP := 140
const REGROW_DELAY := 28.0
const ALLY_RANGE := 16.0
const BILE := Color(0.36, 0.2, 0.46)

var hp: int = MAX_HP
var dead: bool = false
var dying: bool = false
var ring: int = 0
var visual: MeshInstance3D
var shape: CollisionShape3D
var full_scale := Vector3.ONE
var base_y: float = 0.0
var punch: Tween
var rider


func setup(ring_index: int, mesh: Mesh, size: Vector3) -> void:
	ring = ring_index
	collision_layer = 3
	collision_mask = 0
	add_to_group("enemy")
	add_to_group("flesh_wall")
	visual = MeshInstance3D.new()
	visual.mesh = mesh
	add_child(visual)
	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)


func take_damage(amount, from: Vector3 = Vector3.INF) -> void:
	if dead or amount <= 0:
		return
	hp -= int(amount)
	var at := global_position + Vector3(0.0, 2.0, 0.0)
	if from.is_finite():
		var toward := from - global_position
		toward.y = 0.0
		at += toward.normalized() * 1.7
	ChipBurst.spawn(self, at, "gloom_flesh", BILE, 5, 0.12, 0.5, 80.0, 2.0, 4.5, 10.0)
	if punch != null:
		punch.kill()
	visual.scale = Vector3.ONE
	punch = create_tween()
	punch.tween_property(visual, "scale", Vector3(1.0, 1.0, 1.04), 0.05)
	punch.tween_property(visual, "scale", Vector3.ONE, 0.1)
	if hp <= 0:
		_collapse()


func _collapse() -> void:
	dead = true
	dying = true
	remove_from_group("enemy")
	shape.set_deferred("disabled", true)
	if is_instance_valid(rider):
		rider.take_damage(999)
	ChipBurst.spawn(self, global_position + Vector3(0.0, 4.0, 0.0), "gloom_flesh", BILE, 30, 0.2, 1.2, 180.0, 3.0, 8.0, 14.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector3(1.0, 0.04, 1.0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "position:y", -4.8, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if not is_inside_tree():
		return
	visual.visible = false
	_regrow_later()


func _regrow_later() -> void:
	while is_inside_tree():
		await get_tree().create_timer(REGROW_DELAY).timeout
		if not is_inside_tree():
			return
		if not _ally_near():
			break
	hp = MAX_HP
	visual.visible = true
	visual.position.y = 0.0
	visual.scale = Vector3(1.0, 0.04, 1.0)
	visual.position.y = -4.8
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector3.ONE, 1.6)
	tween.tween_property(visual, "position:y", 0.0, 1.6)
	await tween.finished
	if not is_inside_tree():
		return
	shape.set_deferred("disabled", false)
	dead = false
	dying = false
	add_to_group("enemy")


func _ally_near() -> bool:
	for a in get_tree().get_nodes_in_group("ally_unit"):
		if is_instance_valid(a) and a.global_position.distance_to(global_position) < ALLY_RANGE:
			return true
	return false
