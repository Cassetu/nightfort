extends "res://scripts/resource_node.gd"

const GOLDEN := 1.618034

const CORNERS := [
	Vector3(-1.0, GOLDEN, 0.0), Vector3(1.0, GOLDEN, 0.0),
	Vector3(-1.0, -GOLDEN, 0.0), Vector3(1.0, -GOLDEN, 0.0),
	Vector3(0.0, -1.0, GOLDEN), Vector3(0.0, 1.0, GOLDEN),
	Vector3(0.0, -1.0, -GOLDEN), Vector3(0.0, 1.0, -GOLDEN),
	Vector3(GOLDEN, 0.0, -1.0), Vector3(GOLDEN, 0.0, 1.0),
	Vector3(-GOLDEN, 0.0, -1.0), Vector3(-GOLDEN, 0.0, 1.0),
]

const FACES := [
	[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
	[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
	[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
	[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
]

const TINTS := [
	Color(0.52, 0.52, 0.55),
	Color(0.56, 0.50, 0.44),
	Color(0.45, 0.50, 0.57),
]

var rock_seed: int = 0
var size_factor: float = 1.0
var variant: int = 0

static var _material: StandardMaterial3D


func _configure() -> void:
	resource_type = "stone"
	chip_color = Color(0.55, 0.55, 0.58)
	max_health = maxi(4, roundi(6.0 * size_factor * size_factor))
	resource_amount = maxi(2, roundi(2.5 * size_factor))
	add_to_group("rock")


func _build() -> void:
	_ensure_material()

	var rng := RandomNumberGenerator.new()
	rng.seed = rock_seed

	var stretch := Vector3(
		rng.randf_range(0.9, 1.3),
		rng.randf_range(0.65, 0.95),
		rng.randf_range(0.9, 1.3)
	) * size_factor

	var points: Array[Vector3] = []
	var lowest := INF
	for corner: Vector3 in CORNERS:
		var p: Vector3 = corner.normalized() * rng.randf_range(0.78, 1.0) * stretch
		points.append(p)
		lowest = minf(lowest, p.y)

	var lift := -lowest - 0.15 * size_factor
	var center := Vector3.ZERO
	for i in points.size():
		points[i].y += lift
		center += points[i]
	center /= float(points.size())

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tint: Color = TINTS[variant % TINTS.size()]

	for face: Array in FACES:
		var a: Vector3 = points[face[0]]
		var b: Vector3 = points[face[1]]
		var c: Vector3 = points[face[2]]
		var centroid := (a + b + c) / 3.0
		var n := (b - a).cross(c - a).normalized()
		var outward := n
		if n.dot(centroid - center) > 0.0:
			var t := b
			b = c
			c = t
		else:
			outward = -n

		var shade := 0.82 + rng.randf() * 0.3 + maxf(outward.y, 0.0) * 0.15
		var col := Color(tint.r * shade, tint.g * shade, tint.b * shade)
		for v: Vector3 in [a, b, c]:
			st.set_normal(outward)
			st.set_color(col)
			st.add_vertex(v)

	var mesh := st.commit()
	mesh.surface_set_material(0, _material)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	visual.add_child(mi)

	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_convex_shape()
	add_child(shape)


static func _ensure_material() -> void:
	if _material != null:
		return
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.95
