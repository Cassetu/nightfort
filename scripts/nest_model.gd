extends RefCounted

const TileArt = preload("res://scripts/tile_art.gd")

const FLESH_TINT := Color(0.72, 0.5, 0.56)
const BILE_GLOW := Color(0.6, 0.3, 0.8)
const BILE_ENERGY := 0.7
const MOUTH_RADIUS := 1.35
const LIP_INNER := 1.25
const LIP_OUTER := 2.15
const OUTER_TEETH := 16
const INNER_TEETH := 10
const EGG_MIN_R := 0.9
const EGG_MAX_R := 2.4
const MOUTH_EGG_MIN_R := 2.5
const MOUTH_EGG_MAX_R := 3.1
const RADIUS := 3.6
const HEIGHT := 4.4
const RIB_COUNT := 10
const RIB_STEPS := 6
const GAP_HALF_ARC := 0.5
const LUMP_COUNT := 11
const EGG_COUNT := 6
const NEST_ROT_STEP := 0.7

static var flesh_material: StandardMaterial3D
static var bone_material: StandardMaterial3D
static var bile_material: StandardMaterial3D
static var void_material: StandardMaterial3D
static var lump_mesh: SphereMesh
static var rib_mesh: CylinderMesh
static var egg_mesh: SphereMesh
static var pool_mesh: CylinderMesh
static var lip_mesh: TorusMesh
static var tooth_mesh: CylinderMesh
static var void_mesh: CylinderMesh


static func _ensure() -> void:
	if flesh_material != null:
		return
	flesh_material = (TileArt.block_material("gloom_flesh", Color(0.45, 0.14, 0.2)) as StandardMaterial3D).duplicate()
	flesh_material.albedo_color = FLESH_TINT
	flesh_material.roughness = 0.7
	bone_material = TileArt.block_material("bone", Color(0.78, 0.74, 0.62))
	bile_material = (TileArt.block_material("bile", Color(0.36, 0.2, 0.46)) as StandardMaterial3D).duplicate()
	bile_material.emission_enabled = true
	bile_material.emission_texture = bile_material.albedo_texture
	bile_material.emission = BILE_GLOW
	bile_material.emission_energy_multiplier = BILE_ENERGY
	bile_material.roughness = 0.3
	void_material = StandardMaterial3D.new()
	void_material.albedo_color = Color(0.0, 0.0, 0.0)
	void_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lump_mesh = SphereMesh.new()
	lump_mesh.radius = 0.8
	lump_mesh.height = 1.2
	lump_mesh.radial_segments = 8
	lump_mesh.rings = 4
	rib_mesh = CylinderMesh.new()
	rib_mesh.top_radius = 0.6
	rib_mesh.bottom_radius = 1.0
	rib_mesh.height = 1.0
	rib_mesh.radial_segments = 5
	rib_mesh.rings = 1
	egg_mesh = SphereMesh.new()
	egg_mesh.radius = 0.5
	egg_mesh.height = 1.0
	egg_mesh.radial_segments = 8
	egg_mesh.rings = 4
	pool_mesh = CylinderMesh.new()
	pool_mesh.top_radius = RADIUS - 0.2
	pool_mesh.bottom_radius = RADIUS
	pool_mesh.height = 0.1
	pool_mesh.radial_segments = 14
	pool_mesh.rings = 1
	lip_mesh = TorusMesh.new()
	lip_mesh.inner_radius = LIP_INNER
	lip_mesh.outer_radius = LIP_OUTER
	lip_mesh.rings = 14
	lip_mesh.ring_segments = 6
	tooth_mesh = CylinderMesh.new()
	tooth_mesh.top_radius = 0.0
	tooth_mesh.bottom_radius = 0.13
	tooth_mesh.height = 0.6
	tooth_mesh.radial_segments = 4
	tooth_mesh.rings = 1
	void_mesh = CylinderMesh.new()
	void_mesh.top_radius = MOUTH_RADIUS
	void_mesh.bottom_radius = MOUTH_RADIUS
	void_mesh.height = 0.02
	void_mesh.radial_segments = 20
	void_mesh.rings = 1


static func _rib_point(t: float, angle: float) -> Vector3:
	var radius := RADIUS * (1.0 - pow(t, 1.7)) + 0.45
	var height := HEIGHT * sin(t * PI * 0.5)
	return Vector3(cos(angle) * radius, height, sin(angle) * radius)


static func _angle_gap(a: float, b: float) -> float:
	return absf(wrapf(a - b, -PI, PI))


static func _commit(host: Node3D, tool: SurfaceTool, material: Material, name_text: String) -> void:
	var mesh := tool.commit()
	if mesh == null:
		return
	mesh.surface_set_material(0, material)
	var mi := MeshInstance3D.new()
	mi.name = name_text
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)


static func build(parent: Node3D, local: Vector3, seed: int, mouth: bool = false) -> Node3D:
	_ensure()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var root := Node3D.new()
	root.name = "PitNest"
	root.position = local
	root.rotation.y = rng.randf() * TAU
	parent.add_child(root)

	var flesh := SurfaceTool.new()
	var bone := SurfaceTool.new()
	var bile := SurfaceTool.new()
	flesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	bone.begin(Mesh.PRIMITIVE_TRIANGLES)
	bile.begin(Mesh.PRIMITIVE_TRIANGLES)

	bile.append_from(pool_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 0.0)))

	if mouth:
		flesh.append_from(lip_mesh, 0, Transform3D(Basis.from_scale(Vector3(1.0, 0.55, 1.0)), Vector3(0.0, 0.22, 0.0)))
		for t in OUTER_TEETH:
			var ta := TAU * float(t) / float(OUTER_TEETH) + rng.randf_range(-0.08, 0.08)
			var tr := LIP_INNER + rng.randf_range(0.0, 0.12)
			var lean := Vector3(-cos(ta), 0.0, -sin(ta)) * 0.55 + Vector3(0.0, 1.0, 0.0)
			var tq := Quaternion(Vector3.UP, lean.normalized())
			var ts := rng.randf_range(0.85, 1.3)
			bone.append_from(tooth_mesh, 0, Transform3D(Basis(tq) * Basis.from_scale(Vector3(ts, ts, ts)), Vector3(cos(ta) * tr, 0.32, sin(ta) * tr)))
		for t2 in INNER_TEETH:
			var ta2 := TAU * (float(t2) + 0.5) / float(INNER_TEETH)
			var tr2 := MOUTH_RADIUS * 0.62
			var lean2 := Vector3(-cos(ta2), 0.0, -sin(ta2)) * 0.9 + Vector3(0.0, 0.7, 0.0)
			var tq2 := Quaternion(Vector3.UP, lean2.normalized())
			bone.append_from(tooth_mesh, 0, Transform3D(Basis(tq2) * Basis.from_scale(Vector3(0.7, 0.8, 0.7)), Vector3(cos(ta2) * tr2, 0.2, sin(ta2) * tr2)))
	else:
		flesh.append_from(lump_mesh, 0, Transform3D(Basis.from_scale(Vector3(2.0, 1.3, 2.0)), Vector3(0.0, 0.35, 0.0)))
	for i in LUMP_COUNT:
		var a := TAU * float(i) / float(LUMP_COUNT) + rng.randf_range(-0.12, 0.12)
		var r := RADIUS + rng.randf_range(-0.1, 0.5)
		var s := rng.randf_range(0.85, 1.3)
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, rng.randf_range(0.6, 0.95), s))
		flesh.append_from(lump_mesh, 0, Transform3D(basis, Vector3(cos(a) * r, 0.2, sin(a) * r)))

	var gap_angle := PI * 0.5
	for i in RIB_COUNT:
		var a := TAU * float(i) / float(RIB_COUNT) + rng.randf_range(-0.08, 0.08)
		if _angle_gap(a, gap_angle) < GAP_HALF_ARC:
			continue
		var lean := rng.randf_range(0.85, 1.1)
		for k in RIB_STEPS:
			var t0 := float(k) / float(RIB_STEPS) * lean
			var t1 := float(k + 1) / float(RIB_STEPS) * lean
			var p0 := _rib_point(t0, a)
			var p1 := _rib_point(t1, a)
			var span := p1 - p0
			var mid := (p0 + p1) * 0.5
			var width := lerpf(0.34, 0.12, t0)
			var quat := Quaternion(Vector3.UP, span.normalized())
			var xf := Transform3D(Basis(quat) * Basis.from_scale(Vector3(width, span.length() * 1.08, width)), mid)
			bone.append_from(rib_mesh, 0, xf)

	for i in EGG_COUNT:
		var a2 := TAU * float(i) / float(EGG_COUNT) + rng.randf_range(-0.3, 0.3)
		var r2 := rng.randf_range(MOUTH_EGG_MIN_R, MOUTH_EGG_MAX_R) if mouth else rng.randf_range(EGG_MIN_R, EGG_MAX_R)
		var s2 := rng.randf_range(0.7, 1.15)
		var basis2 := Basis.from_scale(Vector3(s2, s2 * rng.randf_range(1.0, 1.4), s2))
		bile.append_from(egg_mesh, 0, Transform3D(basis2, Vector3(cos(a2) * r2, 0.55 * s2 + 0.2, sin(a2) * r2)))

	_commit(root, flesh, flesh_material, "Flesh")
	_commit(root, bone, bone_material, "Ribs")
	_commit(root, bile, bile_material, "Bile")

	if mouth:
		var hole := MeshInstance3D.new()
		hole.name = "Mouth"
		hole.mesh = void_mesh
		hole.material_override = void_material
		hole.position = Vector3(0.0, 0.16, 0.0)
		hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(hole)
		return root

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = 1.7
	shape.height = 1.6
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, 0.8, 0.0)
	body.add_child(cs)
	root.add_child(body)
	return root
