extends "res://scripts/blocks/block.gd"

const SHOW_DISTANCE := 12.0
const POLE := Vector3(0.08, 2.0, 0.08)
const CLOTH := Vector3(0.5, 0.7, 0.03)

var troop_id: int = 0


func _configure() -> void:
	super()
	needs_support = true
	collision_layer = 64
	collision_mask = 0
	add_to_group("banner")
	troop_id = int(block_type.trim_prefix("banner_"))


func _build() -> void:
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.32, 0.24, 0.16)
	pole_mat.roughness = 1.0
	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.albedo_color = Color(0.5, 0.17, 0.15)
	cloth_mat.roughness = 1.0
	cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var pole := MeshInstance3D.new()
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = POLE
	pole_mesh.material = pole_mat
	pole.mesh = pole_mesh
	pole.position = Vector3(0.0, 0.5, 0.0)
	visual.add_child(pole)

	var cloth := MeshInstance3D.new()
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = CLOTH
	cloth_mesh.material = cloth_mat
	cloth.mesh = cloth_mesh
	cloth.position = Vector3(0.29, 1.05, 0.0)
	visual.add_child(cloth)

	var cap := MeshInstance3D.new()
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(0.14, 0.14, 0.14)
	cap_mesh.material = pole_mat
	cap.mesh = cap_mesh
	cap.position = Vector3(0.0, 1.55, 0.0)
	visual.add_child(cap)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 2.0, 0.3)
	col.shape = box
	col.position = Vector3(0.0, 0.5, 0.0)
	add_child(col)
	visual.visible = false


func _process(delta: float) -> void:
	super(delta)
	if dying:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	visual.visible = cam.global_position.distance_to(global_position + Vector3(0.0, 0.5, 0.0)) < SHOW_DISTANCE


func covers(p: Vector3) -> bool:
	var d := p - global_position
	return absf(d.x) < 0.6 and absf(d.z) < 0.6 and d.y > -0.6 and d.y < 1.6


func stand_cell() -> Vector3i:
	return Vector3i(floori(global_position.x), floori(global_position.y), floori(global_position.z))


func vanish() -> void:
	if dying:
		return
	dying = true
	remove_from_group("resource")
	remove_from_group("banner")
	collision_layer = 0
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)
