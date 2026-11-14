extends StaticBody3D

const ChipBurst = preload("res://scripts/chip_burst.gd")

const MAX_HP := 8
const BILE := Color(0.36, 0.2, 0.46)
const CrackOverlay = preload("res://scripts/crack_overlay.gd")


var hp: int = MAX_HP
var dead: bool = false
var dying: bool = false
var resource_type: String = "flesh"
var resource_amount: int = 0
var ring: int = 0
var column: int = 0
var layer: int = 0
var batch: MultiMesh
var slot: int = 0
var rider
var depth: int = 0
var next_block
var on_break: Callable
var punch: Tween
var crack: MeshInstance3D


func setup(shape: Shape3D, multimesh: MultiMesh, index: int, ring_index: int, column_index: int, layer_index: int) -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("resource")
	add_to_group("flesh_block")
	batch = multimesh
	slot = index
	ring = ring_index
	column = column_index
	layer = layer_index
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)


func take_damage(amount, from: Vector3 = Vector3.INF) -> void:
	if dead or amount <= 0:
		return
	hp -= int(amount)
	var at := global_position
	if from.is_finite():
		var toward := from - global_position
		toward.y = 0.0
		at += toward.normalized() * 1.0
	ChipBurst.spawn(self, at, "gloom_flesh", BILE, 5, 0.12, 0.5, 80.0, 2.0, 4.5, 10.0)
	if hp <= 0:
		_break()
	else:
		_show_crack()


func _show_crack() -> void:
	crack = CrackOverlay.show(self, crack, 1.0 - float(hp) / float(MAX_HP))


func _break() -> void:
	if crack != null:
		crack.queue_free()
		crack = null
	dead = true
	dying = true
	remove_from_group("resource")
	remove_from_group("flesh_block")
	collision_layer = 0
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	if on_break.is_valid():
		on_break.call(self)
	if is_instance_valid(rider):
		rider.take_damage(999)
	ChipBurst.spawn(self, global_position, "gloom_flesh", BILE, 18, 0.18, 1.0, 180.0, 3.0, 7.0, 14.0)
	batch.set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
