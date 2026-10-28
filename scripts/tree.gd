extends StaticBody3D
signal harvested(resource_type: String, amount: int)

const LEAF_COLORS := [
	Color(0.13, 0.36, 0.17),
	Color(0.17, 0.42, 0.20),
	Color(0.11, 0.30, 0.16),
	Color(0.22, 0.42, 0.14),
	Color(0.10, 0.33, 0.24),
]

@export var max_health: int = 5
@export var resource_type: String = "wood"
@export var resource_amount: int = 4

var size_factor: float = 1.0
var variant: int = 0

var current_health: int

static var _trunk_mat: StandardMaterial3D
static var _leaf_mats: Array = []


func _ready() -> void:
	_ensure_materials()
	add_to_group("resource")
	add_to_group("tree")
	current_health = max_health

	var s := size_factor
	var trunk_h := 2.4 * s
	var trunk_r := 0.28 * s

	_add_mesh(_make_cylinder(trunk_r * 0.75, trunk_r, trunk_h), _trunk_mat, trunk_h * 0.5)

	var tiers: Array = _leaf_mats[variant % _leaf_mats.size()]
	var base := trunk_h * 0.6
	_add_mesh(_make_cylinder(0.0, 1.7 * s, 2.4 * s), tiers[0], base + 1.2 * s)
	_add_mesh(_make_cylinder(0.0, 1.3 * s, 2.2 * s), tiers[1], base + 1.2 * s + 1.1 * s)
	_add_mesh(_make_cylinder(0.0, 0.9 * s, 2.0 * s), tiers[2], base + 2.4 * s + 1.0 * s)

	var shape := CylinderShape3D.new()
	shape.radius = trunk_r * 1.1
	shape.height = trunk_h
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = trunk_h * 0.5
	add_child(col)


func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		harvested.emit(resource_type, resource_amount)
		queue_free()


func _add_mesh(mesh: PrimitiveMesh, mat: Material, y: float) -> void:
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = y
	add_child(mi)


func _make_cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_radius
	c.bottom_radius = bottom_radius
	c.height = height
	c.radial_segments = 8
	c.rings = 1
	return c


static func _ensure_materials() -> void:
	if _trunk_mat != null:
		return
	_trunk_mat = _make_mat(Color(0.30, 0.20, 0.12))
	for c in LEAF_COLORS:
		var tiers := []
		for t in 3:
			tiers.append(_make_mat(c.lightened(0.07 * t)))
		_leaf_mats.append(tiers)


static func _make_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m
