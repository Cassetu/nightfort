extends Node3D

const ChipBurst = preload("res://scripts/chip_burst.gd")

const MAX_HEALTH := 24
const BONE := Color(0.78, 0.74, 0.62)

var health: int = MAX_HEALTH
var dead: bool = false
var batch: MultiMesh
var slot: int = 0


func setup(multimesh: MultiMesh, index: int) -> void:
	batch = multimesh
	slot = index
	add_to_group("bone_barricade")


func take_damage(amount, from: Vector3 = Vector3.INF) -> void:
	if dead or amount <= 0:
		return
	health -= int(amount)
	ChipBurst.spawn(self, global_position + Vector3(0.0, 0.3, 0.0), "", BONE, 4, 0.08, 0.5, 80.0, 1.5, 3.5, 8.0)
	if health <= 0:
		_break()


func _break() -> void:
	dead = true
	remove_from_group("bone_barricade")
	ChipBurst.spawn(self, global_position + Vector3(0.0, 0.3, 0.0), "", BONE, 12, 0.12, 0.8, 160.0, 2.5, 5.5, 12.0)
	if batch != null:
		batch.set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	queue_free()
