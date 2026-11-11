extends RefCounted

const GloomAnims = preload("res://scripts/enemies/gloom_anims.gd")

const BONE := Color(0.78, 0.72, 0.58)
const BONE_DARK := Color(0.32, 0.27, 0.22)
const VISCERA := Color(0.42, 0.05, 0.07)
const RAW := Color(0.62, 0.12, 0.14)
const BRUISE := Color(0.32, 0.18, 0.34)
const VOID := Color(0.03, 0.0, 0.02)

static var meshes: Dictionary = {}
static var detail_material: StandardMaterial3D


static func dress(gloom: Node3D) -> void:
	var torso: MeshInstance3D = gloom.get_node("Body/Torso")
	var head: MeshInstance3D = gloom.get_node("Body/Head")
	var flesh: Material = (torso.mesh as PrimitiveMesh).material
	if meshes.is_empty():
		_build(flesh)
	torso.mesh = meshes["torso"]
	torso.position = Vector3(0.0, 0.05, -0.04)
	torso.rotation = Vector3(0.32, 0.0, 0.05)
	head.mesh = meshes["head"]
	head.position = Vector3(0.0, 0.7, -0.22)
	head.rotation = Vector3(0.42, 0.0, 0.2)
	(gloom.get_node("Body/ArmL/Mesh") as MeshInstance3D).mesh = meshes["arm_l"]
	(gloom.get_node("Body/ArmR/Mesh") as MeshInstance3D).mesh = meshes["arm_r"]
	(gloom.get_node("Body/LegL/Mesh") as MeshInstance3D).mesh = meshes["leg_l"]
	(gloom.get_node("Body/LegR/Mesh") as MeshInstance3D).mesh = meshes["leg_r"]
	var player_anim: AnimationPlayer = gloom.get_node("Anim")
	player_anim.remove_animation_library("")
	player_anim.add_animation_library("", GloomAnims.library())
	var eye_l: Node3D = gloom.get_node("Body/Head/EyeL")
	var eye_r: Node3D = gloom.get_node("Body/Head/EyeR")
	eye_l.scale = Vector3(1.7, 1.9, 1.0)
	eye_l.position = Vector3(-0.13, 0.07, -0.27)
	eye_r.scale = Vector3(0.9, 0.7, 1.0)
	eye_r.position = Vector3(0.12, 0.04, -0.27)


static func _build(flesh: Material) -> void:
	detail_material = StandardMaterial3D.new()
	detail_material.vertex_color_use_as_albedo = true
	detail_material.roughness = 0.4
	detail_material.metallic_specular = 0.7
	meshes["torso"] = _torso(flesh)
	meshes["head"] = _head(flesh)
	meshes["arm_l"] = _arm_l(flesh)
	meshes["arm_r"] = _arm_r(flesh)
	meshes["leg_l"] = _leg_l(flesh)
	meshes["leg_r"] = _leg_r(flesh)


static func _new_tools() -> Array:
	var a := SurfaceTool.new()
	a.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b := SurfaceTool.new()
	b.begin(Mesh.PRIMITIVE_TRIANGLES)
	return [a, b]


static func _finish(tools: Array, flesh: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	(tools[0] as SurfaceTool).commit(mesh)
	(tools[1] as SurfaceTool).commit(mesh)
	mesh.surface_set_material(0, flesh)
	mesh.surface_set_material(1, detail_material)
	return mesh


static func _rot(x: float = 0.0, y: float = 0.0, z: float = 0.0) -> Basis:
	return Basis.from_euler(Vector3(x, y, z))


static func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color = Color.WHITE, basis: Basis = Basis.IDENTITY) -> void:
	var normals: Array = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for n: Vector3 in normals:
		var u: Vector3 = n.cross(Vector3.UP)
		if absf(n.y) > 0.9:
			u = Vector3.RIGHT
		u = u.normalized()
		var v: Vector3 = n.cross(u)
		var corners: Array = []
		for k in 4:
			var su := -1.0 if (k == 0 or k == 3) else 1.0
			var sv := -1.0 if (k == 0 or k == 1) else 1.0
			var local: Vector3 = (n * 0.5 + u * 0.5 * su + v * 0.5 * sv) * size
			corners.append(center + basis * local)
		var world_n: Vector3 = (basis * n).normalized()
		var uvs: Array = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_color(color)
			st.set_normal(world_n)
			st.set_uv(uvs[idx])
			st.add_vertex(corners[idx])


static func _torso(flesh: Material) -> ArrayMesh:
	var t := _new_tools()
	var f: SurfaceTool = t[0]
	var d: SurfaceTool = t[1]
	_box(f, Vector3.ZERO, Vector3(0.72, 0.9, 0.4))
	_box(f, Vector3(-0.4, 0.44, 0.02), Vector3(0.24, 0.24, 0.26), Color.WHITE, _rot(0.2, 0.3, 0.4))
	_box(d, Vector3(0.0, 0.1, -0.205), Vector3(0.42, 0.52, 0.03), VISCERA)
	for i in 4:
		_box(d, Vector3(0.0, 0.3 - 0.13 * float(i), -0.225), Vector3(0.48 - 0.03 * float(i), 0.045, 0.07), BONE)
	_box(d, Vector3(0.0, 0.08, -0.225), Vector3(0.05, 0.56, 0.06), BONE_DARK)
	_box(d, Vector3(-0.1, -0.5, -0.2), Vector3(0.07, 0.3, 0.07), RAW, _rot(0.1, 0.0, 0.08))
	_box(d, Vector3(-0.12, -0.7, -0.2), Vector3(0.06, 0.18, 0.06), VISCERA, _rot(0.2, 0.0, -0.2))
	_box(d, Vector3(0.1, -0.48, -0.2), Vector3(0.06, 0.26, 0.06), VISCERA, _rot(0.0, 0.0, -0.1))
	for i in 5:
		var y := 0.34 - 0.17 * float(i)
		_box(d, Vector3(0.0, y, 0.22), Vector3(0.08, 0.09, 0.12), BONE, _rot(0.0, 0.0, 0.3 * float(i % 2)))
	_box(d, Vector3(0.26, 0.2, -0.2), Vector3(0.18, 0.16, 0.03), BRUISE, _rot(0.0, 0.0, 0.3))
	_box(d, Vector3(-0.4, 0.44, -0.12), Vector3(0.12, 0.12, 0.03), RAW, _rot(0.2, 0.3, 0.4))
	return _finish(t, flesh)


static func _head(flesh: Material) -> ArrayMesh:
	var t := _new_tools()
	var f: SurfaceTool = t[0]
	var d: SurfaceTool = t[1]
	_box(f, Vector3(0.0, 0.07, 0.0), Vector3(0.5, 0.36, 0.5))
	_box(f, Vector3(0.0, -0.2, -0.06), Vector3(0.4, 0.1, 0.38), Color.WHITE, _rot(0.5, 0.0, 0.0))
	_box(f, Vector3(-0.2, 0.22, 0.12), Vector3(0.22, 0.22, 0.22), Color.WHITE, _rot(0.3, 0.4, 0.2))
	_box(d, Vector3(0.0, -0.1, -0.24), Vector3(0.34, 0.1, 0.06), VOID)
	for i in 5:
		var x := -0.14 + 0.07 * float(i)
		_box(d, Vector3(x, -0.07, -0.265), Vector3(0.045, 0.09 + 0.03 * float(i % 2), 0.04), BONE)
		_box(d, Vector3(x * 0.9, -0.22, -0.2), Vector3(0.04, 0.07, 0.04), BONE, _rot(0.5, 0.0, 0.0))
	_box(d, Vector3(-0.13, 0.07, -0.255), Vector3(0.22, 0.2, 0.04), VOID)
	_box(d, Vector3(0.12, 0.04, -0.255), Vector3(0.16, 0.12, 0.04), VOID)
	_box(d, Vector3(0.15, 0.3, 0.0), Vector3(0.05, 0.28, 0.05), BONE, _rot(0.0, 0.0, -0.4))
	_box(d, Vector3(-0.2, 0.3, 0.12), Vector3(0.1, 0.1, 0.1), RAW, _rot(0.3, 0.4, 0.2))
	_box(d, Vector3(0.0, 0.2, -0.255), Vector3(0.3, 0.05, 0.03), VISCERA, _rot(0.0, 0.0, 0.12))
	return _finish(t, flesh)


static func _claws(d: SurfaceTool, base_y: float, count: int, spread: float, length: float) -> void:
	for i in count:
		var x := (float(i) - float(count - 1) * 0.5) * spread
		_box(d, Vector3(x, base_y - length * 0.5, 0.0), Vector3(0.035, length, 0.035), BONE_DARK, _rot(0.0, 0.0, x * 1.6))


static func _arm_l(flesh: Material) -> ArrayMesh:
	var t := _new_tools()
	var f: SurfaceTool = t[0]
	var d: SurfaceTool = t[1]
	_box(f, Vector3(0.0, -0.1, 0.0), Vector3(0.14, 1.0, 0.14))
	_box(f, Vector3(0.0, 0.1, 0.0), Vector3(0.2, 0.2, 0.2), Color.WHITE, _rot(0.0, 0.4, 0.0))
	_box(d, Vector3(0.0, -0.2, -0.075), Vector3(0.1, 0.24, 0.03), RAW)
	_claws(d, -0.6, 4, 0.05, 0.3)
	return _finish(t, flesh)


static func _arm_r(flesh: Material) -> ArrayMesh:
	var t := _new_tools()
	var f: SurfaceTool = t[0]
	var d: SurfaceTool = t[1]
	_box(f, Vector3(0.0, -0.05, 0.0), Vector3(0.3, 0.7, 0.28))
	_box(f, Vector3(0.0, -0.42, 0.0), Vector3(0.36, 0.2, 0.32))
	_box(d, Vector3(0.18, -0.05, 0.0), Vector3(0.05, 0.34, 0.05), BONE, _rot(0.0, 0.0, -0.35))
	_box(d, Vector3(0.0, 0.1, -0.145), Vector3(0.22, 0.2, 0.03), VISCERA)
	_claws(d, -0.52, 3, 0.1, 0.34)
	return _finish(t, flesh)


static func _leg_l(flesh: Material) -> ArrayMesh:
	var t := _new_tools()
	var f: SurfaceTool = t[0]
	var d: SurfaceTool = t[1]
	_box(f, Vector3.ZERO, Vector3(0.27, 0.7, 0.27))
	_box(d, Vector3(0.0, 0.05, -0.14), Vector3(0.19, 0.24, 0.03), RAW)
	_box(d, Vector3(0.0, -0.28, -0.14), Vector3(0.22, 0.08, 0.03), BRUISE)
	return _finish(t, flesh)


static func _leg_r(flesh: Material) -> ArrayMesh:
	var t := _new_tools()
	var f: SurfaceTool = t[0]
	var d: SurfaceTool = t[1]
	_box(f, Vector3(0.0, 0.0, 0.0), Vector3(0.22, 0.7, 0.22))
	_box(d, Vector3(0.0, -0.05, -0.115), Vector3(0.09, 0.3, 0.03), BONE)
	_box(d, Vector3(0.0, 0.2, -0.115), Vector3(0.16, 0.12, 0.03), VISCERA)
	return _finish(t, flesh)
