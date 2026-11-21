extends RefCounted

const TileArt = preload("res://scripts/tile_art.gd")
const NestHazard = preload("res://scripts/nest_hazard.gd")

const FLESH_TINT := Color(0.72, 0.5, 0.56)
const BILE_GLOW := Color(0.6, 0.3, 0.8)
const BILE_ENERGY := 0.7
const RADIUS := 3.6
const POOL_RADIUS := 2.4
const MOUTH_RADIUS := 1.6
const LIP_RADIUS := 2.4
const HEIGHT := 4.4
const RIB_COUNT := 10
const RIB_STEPS := 8
const GAP_HALF_ARC := 0.55
const EGG_COUNT := 6
const POOL_THICK := 0.1
const VOID_THICK := 0.04

static var flesh_material: StandardMaterial3D
static var bone_material: StandardMaterial3D
static var bile_material: StandardMaterial3D
static var void_material: StandardMaterial3D
static var cube_mesh: BoxMesh


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
	cube_mesh = BoxMesh.new()
	cube_mesh.size = Vector3.ONE


static func _rib_point(t: float, angle: float) -> Vector3:
	var radius := RADIUS * (1.0 - pow(t, 1.7)) + 0.45
	var height := HEIGHT * sin(t * PI * 0.5)
	return Vector3(cos(angle) * radius, height, sin(angle) * radius)


static func _angle_gap(a: float, b: float) -> float:
	return absf(wrapf(a - b, -PI, PI))


static func _commit(host: Node3D, tool: SurfaceTool, material: Material, name_text: String) -> void:
	var mesh := tool.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	mesh.surface_set_material(0, material)
	var mi := MeshInstance3D.new()
	mi.name = name_text
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)


static func _layout(rng: RandomNumberGenerator, mouth: bool, gap_angle: float) -> Dictionary:
	var cells: Dictionary = {}
	var reach := int(ceil(RADIUS))
	for i in range(-reach, reach + 1):
		for k in range(-reach, reach + 1):
			var d := Vector2(i, k).length()
			var a := atan2(float(k), float(i))
			if d > RADIUS:
				continue
			if d > LIP_RADIUS and (d <= RADIUS - 0.6 or rng.randf() < 0.5):
				cells[Vector3i(i, 0, k)] = "flesh"
			elif d > LIP_RADIUS:
				continue
			elif mouth:
				if d > MOUTH_RADIUS:
					cells[Vector3i(i, 0, k)] = "flesh"
				else:
					cells[Vector3i(i, 0, k)] = "void"
			elif d <= POOL_RADIUS:
				cells[Vector3i(i, 0, k)] = "pool"
			if not mouth and d <= 1.2:
				cells[Vector3i(i, 0, k)] = "flesh"
			if d > LIP_RADIUS + 0.2 and rng.randf() < 0.28 and _angle_gap(a, gap_angle) > GAP_HALF_ARC:
				cells[Vector3i(i, 1, k)] = "flesh"
	if not mouth:
		cells[Vector3i(0, 1, 0)] = "flesh"
	else:
		for i in range(-2, 3):
			for k in range(-2, 3):
				var d2 := Vector2(i, k).length()
				if d2 >= MOUTH_RADIUS - 0.1 and d2 <= LIP_RADIUS - 0.2 and (i + k) % 2 == 0 and rng.randf() < 0.75:
					cells[Vector3i(i, 1, k)] = "bone"

	for r in RIB_COUNT:
		var a := TAU * float(r) / float(RIB_COUNT) + rng.randf_range(-0.08, 0.08)
		if _angle_gap(a, gap_angle) < GAP_HALF_ARC:
			continue
		var lean := rng.randf_range(0.85, 1.1)
		for step in range(RIB_STEPS + 1):
			var t := float(step) / float(RIB_STEPS) * lean
			var p := _rib_point(t, a)
			var cell := Vector3i(roundi(p.x), floori(p.y), roundi(p.z))
			if cell.y < 0:
				continue
			if cell.y == 0 and cells.has(cell):
				continue
			cells[cell] = "bone"

	var eggs := 0
	var guard := 0
	while eggs < EGG_COUNT and guard < 80:
		guard += 1
		var ea := rng.randf() * TAU
		var er := rng.randf_range(2.5, 3.1) if mouth else rng.randf_range(0.0, POOL_RADIUS - 0.3)
		var cell := Vector3i(roundi(cos(ea) * er), 1 if mouth else 0, roundi(sin(ea) * er))
		if not mouth and cell.x == 0 and cell.z == 0:
			continue
		if cells.get(cell, "") == "bone":
			continue
		if mouth and not cells.has(Vector3i(cell.x, 0, cell.z)):
			continue
		cells[cell] = "bile"
		if rng.randf() < 0.3:
			cells[cell + Vector3i.UP] = "bile"
		eggs += 1
	return cells


static func build(parent: Node3D, local: Vector3, seed: int, mouth: bool = false) -> Node3D:
	_ensure()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var root := Node3D.new()
	root.name = "PitNest"
	root.position = Vector3(floorf(local.x) + 0.5, roundf(local.y), floorf(local.z) + 0.5)
	parent.add_child(root)

	var gap_angle := float(rng.randi() % 4) * PI * 0.5
	var cells := _layout(rng, mouth, gap_angle)

	var flesh := SurfaceTool.new()
	var bone := SurfaceTool.new()
	var bile := SurfaceTool.new()
	var hole := SurfaceTool.new()
	flesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	bone.begin(Mesh.PRIMITIVE_TRIANGLES)
	bile.begin(Mesh.PRIMITIVE_TRIANGLES)
	hole.begin(Mesh.PRIMITIVE_TRIANGLES)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shared := BoxShape3D.new()
	shared.size = Vector3.ONE
	var hazard_blocks := PackedVector3Array()
	var hazard_pools := PackedVector3Array()

	for cell: Vector3i in cells:
		var kind: String = cells[cell]
		var center := Vector3(cell.x, cell.y + 0.5, cell.z)
		match kind:
			"pool":
				bile.append_from(cube_mesh, 0, Transform3D(Basis.from_scale(Vector3(1.0, POOL_THICK, 1.0)), Vector3(cell.x, POOL_THICK * 0.5, cell.z)))
				hazard_pools.append(Vector3(cell.x, 0.0, cell.z))
				continue
			"void":
				hole.append_from(cube_mesh, 0, Transform3D(Basis.from_scale(Vector3(1.0, VOID_THICK, 1.0)), Vector3(cell.x, VOID_THICK * 0.5 + 0.02, cell.z)))
				continue
			"flesh":
				flesh.append_from(cube_mesh, 0, Transform3D(Basis.IDENTITY, center))
			"bone":
				bone.append_from(cube_mesh, 0, Transform3D(Basis.IDENTITY, center))
			"bile":
				bile.append_from(cube_mesh, 0, Transform3D(Basis.IDENTITY, center))
				hazard_blocks.append(center)
		if not mouth:
			var cs := CollisionShape3D.new()
			cs.shape = shared
			cs.position = center
			body.add_child(cs)

	_commit(root, flesh, flesh_material, "Flesh")
	_commit(root, bone, bone_material, "Ribs")
	_commit(root, bile, bile_material, "Bile")
	_commit(root, hole, void_material, "Mouth")

	if not mouth:
		root.add_child(body)
	else:
		body.free()
	var hazard := Node3D.new()
	hazard.name = "BileHazard"
	hazard.set_script(NestHazard)
	hazard.blocks = hazard_blocks
	hazard.pools = hazard_pools
	root.add_child(hazard)
	return root
