extends StaticBody3D

const REPAIR_ITEM := "stone_brick"
const REPAIR_TYPE := "stone_brick"
const SLOT_LAYER := 16

static var _material: StandardMaterial3D


func _ready() -> void:
	add_to_group("ruin_slot")
	collision_layer = SLOT_LAYER
	collision_mask = 0

	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(0.45, 0.85, 0.95, 0.22)
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.96, 0.96, 0.96)
	mesh.material = _material
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	add_child(shape)
