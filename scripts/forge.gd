extends "res://scripts/block.gd"

const HeldItem = preload("res://scripts/held_item.gd")
const ITEM_SCALE := 1.3
const ANVIL_SIDE := Vector3(1.0, 0.0, 0.0)
const ITEM_POS := Vector3(1.0, 0.25, 0.0)
const CAM_POS := Vector3(1.0, 1.3, 0.0)
const IDLE_ENERGY := 0.55
const ACTIVE_ENERGY := 3.2

var active: bool = false
var time: float = 0.0
var mouth_material: StandardMaterial3D
var light: OmniLight3D
var sparks: CPUParticles3D
var item_holder: Node3D
var item_node: MeshInstance3D
var smoke: CPUParticles3D


func _configure() -> void:
	super()
	add_to_group("forge")


func _build() -> void:
	time = randf() * 10.0
	var brick := TileArt.uv_material("stone_brick", Color(0.45, 0.45, 0.48), Vector3.ONE)
	var base := _part(Vector3(0.0, 0.0, 0.0), Vector3(1.0, 1.0, 1.0), brick)
	base.name = "Base"
	_part(Vector3(0.0, 1.0, 0.0), Vector3(0.78, 1.0, 0.78), brick)
	_part(Vector3(0.0, 1.44, 0.0), Vector3(0.94, 0.12, 0.94), brick)

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.06)
	dark.roughness = 1.0
	_part(Vector3(0.0, -0.1, 0.5), Vector3(0.62, 0.5, 0.06), dark)
	_part(Vector3(0.0, 0.2, 0.52), Vector3(0.78, 0.1, 0.1), TileArt.uv_material("iron_block", Color(0.5, 0.5, 0.55), Vector3.ONE))

	mouth_material = StandardMaterial3D.new()
	mouth_material.albedo_color = Color(0.9, 0.35, 0.08)
	mouth_material.emission_enabled = true
	mouth_material.emission = Color(1.0, 0.45, 0.1)
	mouth_material.emission_energy_multiplier = IDLE_ENERGY
	_part(Vector3(0.0, -0.22, 0.545), Vector3(0.5, 0.22, 0.05), mouth_material)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 2.0, 1.0)
	shape.shape = box
	shape.position = Vector3(0.0, 0.5, 0.0)
	add_child(shape)

	_part(Vector3(1.0, -0.2, 0.0), Vector3(1.0, 0.6, 1.0), brick)
	_part(Vector3(1.0, 0.14, 0.0), Vector3(0.74, 0.08, 0.74), TileArt.uv_material("iron_block", Color(0.5, 0.5, 0.55), Vector3.ONE))
	var anvil_shape := CollisionShape3D.new()
	var anvil_box := BoxShape3D.new()
	anvil_box.size = Vector3(1.0, 0.68, 1.0)
	anvil_shape.shape = anvil_box
	anvil_shape.position = Vector3(1.0, -0.16, 0.0)
	add_child(anvil_shape)

	item_holder = Node3D.new()
	item_holder.position = ITEM_POS
	item_holder.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(item_holder)

	light = OmniLight3D.new()
	light.position = Vector3(0.0, 0.0, 1.2)
	light.light_color = Color(1.0, 0.55, 0.22)
	light.light_energy = 0.4
	light.omni_range = 4.0
	light.shadow_enabled = false
	visual.add_child(light)

	sparks = CPUParticles3D.new()
	sparks.position = Vector3(0.0, -0.2, 0.55)
	sparks.amount = 14
	sparks.lifetime = 0.8
	sparks.emitting = false
	sparks.direction = Vector3(0.0, 1.0, 0.6)
	sparks.spread = 30.0
	sparks.initial_velocity_min = 0.8
	sparks.initial_velocity_max = 1.8
	sparks.gravity = Vector3(0.0, -2.0, 0.0)
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.04, 0.04, 0.04)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.albedo_color = Color(1.0, 0.7, 0.2)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1.0, 0.6, 0.15)
	spark_mat.emission_energy_multiplier = 3.0
	spark_mesh.material = spark_mat
	sparks.mesh = spark_mesh
	visual.add_child(sparks)

	smoke = CPUParticles3D.new()
	smoke.position = Vector3(0.0, 1.55, 0.0)
	smoke.amount = 10
	smoke.lifetime = 2.4
	smoke.emitting = false
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 0.9
	smoke.gravity = Vector3(0.3, 0.2, 0.0)
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.2
	var smoke_mesh := QuadMesh.new()
	smoke_mesh.size = Vector2(0.4, 0.4)
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(0.2, 0.2, 0.22, 0.45)
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mesh.material = smoke_mat
	smoke.mesh = smoke_mesh
	visual.add_child(smoke)


func _part(pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = TileArt.box_mesh(size, material)
	mi.position = pos
	visual.add_child(mi)
	return mi


func extra_cells() -> Array:
	var yaw := rotation.y
	var side := Vector3i(roundi(cos(yaw)), 0, roundi(-sin(yaw)))
	return [side, side + Vector3i.UP]


func covers(p: Vector3) -> bool:
	var d := to_local(p)
	return d.x > -0.6 and d.x < 1.6 and absf(d.z) < 0.6 and d.y > -0.6 and d.y < 1.6


func show_item(id: String) -> void:
	if item_node != null:
		item_node.queue_free()
		item_node = null
	if id == "":
		return
	item_node = MeshInstance3D.new()
	item_node.mesh = HeldItem.mesh_for(id)
	item_node.scale = Vector3.ONE * ITEM_SCALE
	item_holder.add_child(item_node)


func set_active(value: bool) -> void:
	active = value
	if sparks != null:
		sparks.emitting = value
		smoke.emitting = value


func _process(delta: float) -> void:
	super(delta)
	if light == null:
		return
	time += delta
	var flick := 0.85 + 0.15 * sin(time * 9.0) + 0.1 * sin(time * 23.0)
	var target_energy := ACTIVE_ENERGY if active else IDLE_ENERGY
	mouth_material.emission_energy_multiplier = lerpf(mouth_material.emission_energy_multiplier, target_energy * flick, minf(delta * 6.0, 1.0))
	light.light_energy = (1.6 if active else 0.4) * flick
