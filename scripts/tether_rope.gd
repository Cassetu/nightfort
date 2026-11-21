extends MeshInstance3D

const SHADER_PATH := "res://resources/tether_rope.gdshader"
const WIDTH := 0.11
const KNOT := 0.15

static var _material: ShaderMaterial

var pole
var canvas: ImmediateMesh


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	canvas = ImmediateMesh.new()
	mesh = canvas
	material_override = _get_material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 4096.0


static func _get_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load(SHADER_PATH)
	return _material


func _process(_delta: float) -> void:
	canvas.clear_surfaces()
	if not is_instance_valid(pole) or not pole.hooked:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var points: PackedVector3Array = pole.rope_points()
	if points.size() < 2:
		return
	var eye: Vector3 = camera.global_position
	var quads: Array = []
	var travelled: float = 0.0
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var length: float = a.distance_to(b)
		if length > 0.001:
			var side: Vector3 = (b - a).cross(eye - (a + b) * 0.5)
			if side.length_squared() > 0.000001:
				side = side.normalized() * WIDTH * 0.5
				quads.append([a - side, a + side, b + side, b - side, Vector2(travelled, 0.0), Vector2(travelled, 1.0), Vector2(travelled + length, 1.0), Vector2(travelled + length, 0.0), 0.0])
		travelled += length
	var right: Vector3 = camera.global_transform.basis.x * KNOT * 0.5
	var up: Vector3 = camera.global_transform.basis.y * KNOT * 0.5
	for i in range(1, points.size() - 1):
		var c: Vector3 = points[i]
		quads.append([c - right - up, c + right - up, c + right + up, c - right + up, Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0), 1.0])
	if quads.is_empty():
		return
	canvas.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in quads:
		_quad(q[0], q[1], q[2], q[3], q[4], q[5], q[6], q[7], q[8])
	canvas.surface_end()


func _quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2, uv3: Vector2, bead: float) -> void:
	var tint := Color(1.0, 1.0, 1.0, bead)
	for v in [[p0, uv0], [p1, uv1], [p2, uv2], [p0, uv0], [p2, uv2], [p3, uv3]]:
		canvas.surface_set_color(tint)
		canvas.surface_set_uv(v[1])
		canvas.surface_add_vertex(v[0])
