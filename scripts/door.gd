extends "res://scripts/block.gd"

const CLOSED_LAYER := 1
const OPEN_LAYER := 8
const HINGE := Vector3(0.4, -0.5, -0.4)
const LEAF_CENTER := Vector3(-0.4, 1.0, 0.0)
const SWING_TIME := 0.18

var is_open: bool = false
var leaf: Node3D
var col: CollisionShape3D
var swing: Tween


func _configure() -> void:
	super()
	add_to_group("door")
	needs_support = true


func _build() -> void:
	leaf = Node3D.new()
	leaf.position = HINGE
	visual.add_child(leaf)
	leaf.add_child(_half("door_bottom", 0.5))
	leaf.add_child(_half("door_top", 1.5))

	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 2.0, 0.2)
	col = CollisionShape3D.new()
	col.shape = box
	add_child(col)
	_apply(false, true)


func _half(tile: String, y: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = TileArt.box_mesh(Vector3(1.0, 1.0, 0.2), TileArt.uv_material(tile, Color(0.45, 0.3, 0.17), Vector3.ONE))
	mi.position = Vector3(-0.4, y, 0.0)
	return mi


func covers(p: Vector3) -> bool:
	var d := p - global_position
	return absf(d.x) < 0.6 and absf(d.z) < 0.6 and d.y > -0.6 and d.y < 1.6


func toggle() -> void:
	Sfx.play(self, "door_close" if is_open else "door_open", global_position)
	_apply(not is_open, false)


func set_open(value: bool, instant: bool = false) -> void:
	_apply(value, instant)


func _apply(open: bool, instant: bool) -> void:
	is_open = open
	var angle := PI * 0.5 if open else 0.0
	var rot := Basis(Vector3.UP, angle)
	col.transform = Transform3D(rot, HINGE + rot * LEAF_CENTER)
	collision_layer = OPEN_LAYER if open else CLOSED_LAYER
	if swing:
		swing.kill()
	if instant:
		leaf.rotation.y = angle
		return
	swing = create_tween()
	swing.tween_property(leaf, "rotation:y", angle, SWING_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
