extends StaticBody3D

const ChipBurst = preload("res://scripts/chip_burst.gd")

const MAX_HEALTH := 10
const STAGE_SPIKES := [7, 5, 3, 1]
const BONE := Color(0.78, 0.74, 0.62)
const PICK_LAYER := 512
const SHAPE_RADIUS := 0.6
const SHAPE_HEIGHT := 0.9

var resource_type: String = "bone"
var health: int = MAX_HEALTH
var dead: bool = false
var dying: bool = false
var batches: Array = []
var slot: int = 0
var rest: Transform3D = Transform3D.IDENTITY
var stage: int = 0


func setup(multimeshes: Array, index: int, transform_in: Transform3D) -> void:
	batches = multimeshes
	slot = index
	rest = transform_in
	stage = 0
	batches[0].set_instance_transform(slot, rest)
	collision_layer = PICK_LAYER
	collision_mask = 0
	add_to_group("bone_barricade")
	add_to_group("resource")
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = SHAPE_RADIUS
	cyl.height = SHAPE_HEIGHT
	cs.shape = cyl
	cs.position = Vector3(0.0, SHAPE_HEIGHT * 0.5, 0.0)
	add_child(cs)


func take_damage(amount, _from: Vector3 = Vector3.INF) -> void:
	if dead or amount <= 0:
		return
	health -= int(amount)
	ChipBurst.spawn(self, global_position + Vector3(0.0, 0.3, 0.0), "bone", BONE, 4, 0.08, 0.5, 80.0)
	if health <= 0:
		_break()
		return
	_update_stage()


func _update_stage() -> void:
	var stages: int = STAGE_SPIKES.size()
	var next: int = clampi(stages - int(ceil(float(health) / float(MAX_HEALTH) * float(stages))), 0, stages - 1)
	if next == stage:
		return
	batches[stage].set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	stage = next
	batches[stage].set_instance_transform(slot, rest)


func _break() -> void:
	dead = true
	dying = true
	collision_layer = 0
	remove_from_group("bone_barricade")
	remove_from_group("resource")
	ChipBurst.spawn(self, global_position + Vector3(0.0, 0.3, 0.0), "bone", BONE, 12, 0.12, 0.8, 160.0)
	if not batches.is_empty():
		batches[stage].set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	queue_free()
