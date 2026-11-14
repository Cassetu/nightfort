extends RefCounted

const BloodTerrain = preload("res://scripts/blood_terrain.gd")

const BUCKET := 48.0
const VIEW_RANGE := 72.0
const VIEW_MARGIN := 8.0
const HALF_MAP := 235.0
const HEART_CLEAR := 14.0
const WALL_CLEAR := 7.0
const ARMY_CLEAR := 20.0
const WATER_MARGIN := 0.4
const BILE := Color(0.36, 0.2, 0.46)

const KINDS := [
	{"id": "tuft_a", "count": 1500, "smin": 0.8, "smax": 1.5, "tone": 0.2, "view": true},
	{"id": "tuft_b", "count": 1300, "smin": 0.8, "smax": 1.6, "tone": 0.2, "view": true},
	{"id": "bloom", "count": 280, "smin": 0.8, "smax": 1.4, "tone": 0.15, "view": true},
	{"id": "bush", "count": 200, "smin": 0.8, "smax": 1.5, "tone": 0.2, "view": true},
	{"id": "pustule", "count": 220, "smin": 0.7, "smax": 1.7, "tone": 0.15, "view": true},
	{"id": "arch", "count": 24, "smin": 0.8, "smax": 1.7, "tone": 0.1, "view": false},
]


static func scatter(host: Node3D, gen) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for kind: Dictionary in KINDS:
		var mesh: ArrayMesh = _mesh_for(kind["id"])
		var buckets: Dictionary = {}
		for i in int(kind["count"]):
			var p := _spot(gen, rng)
			if not p.is_finite():
				continue
			var s := rng.randf_range(kind["smin"], kind["smax"])
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
			var key := Vector2i(floori(p.x / BUCKET), floori(p.z / BUCKET))
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append([Transform3D(basis, p - Vector3(0.0, 0.05, 0.0)), rng.randf_range(1.0 - float(kind["tone"]), 1.0 + float(kind["tone"]) * 0.4)])
		for key in buckets:
			var list: Array = buckets[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = mesh
			mm.instance_count = list.size()
			for i in list.size():
				var entry: Array = list[i]
				mm.set_instance_transform(i, entry[0])
				var tone: float = entry[1]
				mm.set_instance_color(i, Color(tone, tone * rng.randf_range(0.9, 1.05), tone))
			var node := MultiMeshInstance3D.new()
			node.multimesh = mm
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if kind["view"]:
				node.visibility_range_end = VIEW_RANGE
				node.visibility_range_end_margin = VIEW_MARGIN
			host.add_child(node)


static func _spot(gen, rng: RandomNumberGenerator) -> Vector3:
	for attempt in 14:
		var x: float = rng.randf_range(-HALF_MAP, HALF_MAP)
		var z: float = rng.randf_range(-HALF_MAP, HALF_MAP)
		var d := Vector2(x, z).length()
		if d < HEART_CLEAR:
			continue
		var blocked := false
		for r: float in BloodTerrain.RINGS:
			if absf(d - r) < WALL_CLEAR:
				blocked = true
		if blocked or Vector2(x, z).distance_to(BloodTerrain.ARMY) < ARMY_CLEAR:
			continue
		var h: float = gen.height(x, z)
		if h < BloodTerrain.POOL_LEVEL + WATER_MARGIN:
			continue
		return Vector3(x, h, z)
	return Vector3(INF, INF, INF)


static func _mesh_for(id: String) -> ArrayMesh:
	match id:
		"tuft_a":
			return _tuft(0)
		"tuft_b":
			return _tuft(1)
		"bloom":
			return _bloom()
		"bush":
			return _bush()
		"pustule":
			return _pustule()
	return _arch()


static func _glow_material() -> StandardMaterial3D:
	return BloodTerrain.glow_material("bile", Color(0.3, 0.16, 0.4), BILE, 1.8)


class Buf:
	extends RefCounted

	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()

	func box(center: Vector3, half: Vector3, basis: Basis, color: Color) -> void:
		BloodTerrain.append_box(v, n, c, idx, center, half, basis, color)

	func commit(mesh: ArrayMesh, material: Material) -> void:
		if v.is_empty():
			return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)


static func _chain(buf: Buf, base: Vector3, yaw: float, lean: float, bend: float, length: float, width: float, segs: int, col_a: Color, col_b: Color) -> Vector3:
	var pos := base
	var seg_len := length / float(segs)
	for k in segs:
		var t := float(k) / float(maxi(segs - 1, 1))
		var angle := lean + bend * float(k)
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, -angle)
		var dir := basis * Vector3.UP
		var w := width * (1.0 - 0.55 * t)
		buf.box(pos + dir * seg_len * 0.5, Vector3(w, seg_len * 0.5 + 0.01, w), basis, col_a.lerp(col_b, t))
		pos += dir * seg_len
	return pos


static func _tuft(variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + variant
	var buf := Buf.new()
	var tip := Color(0.78, 0.45, 0.55) if variant == 0 else Color(0.52, 0.3, 0.66)
	for i in 6:
		var a := TAU * float(i) / 6.0 + rng.randf_range(-0.3, 0.3)
		var base := Vector3(cos(a), 0.0, -sin(a)) * rng.randf_range(0.04, 0.12)
		_chain(buf, base, a, rng.randf_range(0.15, 0.55), rng.randf_range(0.18, 0.36), rng.randf_range(0.35, 0.85), 0.03, 3, Color(0.34, 0.06, 0.1), tip)
	var mesh := ArrayMesh.new()
	buf.commit(mesh, BloodTerrain.detail_material("blood"))
	return mesh


static func _bloom() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 210
	var flesh := Buf.new()
	var glow := Buf.new()
	var top := _chain(flesh, Vector3.ZERO, 0.0, 0.12, 0.07, 1.0, 0.06, 4, Color(0.3, 0.06, 0.1), Color(0.5, 0.12, 0.16))
	flesh.box(top + Vector3(0.0, 0.12, 0.0), Vector3(0.2, 0.16, 0.2), Basis.from_euler(Vector3(0.1, 0.4, 0.15)), Color(0.72, 0.22, 0.3))
	for i in 4:
		var a := TAU * float(i) / 4.0
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.BACK, -0.9)
		flesh.box(top + Vector3(cos(a), 0.02, -sin(a)) * 0.17, Vector3(0.12, 0.02, 0.07), basis, Color(0.6, 0.16, 0.22))
	glow.box(top + Vector3(0.0, 0.3, 0.0), Vector3(0.09, 0.05, 0.09), Basis.from_euler(Vector3(0.1, 0.4, 0.15)), Color(0.62, 0.4, 0.85))
	var mesh := ArrayMesh.new()
	flesh.commit(mesh, BloodTerrain.detail_material("blood"))
	glow.commit(mesh, _glow_material())
	return mesh


static func _bush() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 320
	var bone := Buf.new()
	var flesh := Buf.new()
	for i in 6:
		var a := TAU * float(i) / 6.0 + rng.randf_range(-0.25, 0.25)
		var base := Vector3(cos(a), 0.0, -sin(a)) * 0.15
		_chain(bone, base, a, rng.randf_range(0.35, 0.9), rng.randf_range(0.12, 0.3), rng.randf_range(0.9, 1.4), 0.05, 4, Color(0.82, 0.76, 0.66), Color(0.92, 0.88, 0.78))
	for i in 3:
		var a2 := TAU * float(i) / 3.0 + 0.5
		var basis := Basis(Vector3.UP, a2) * Basis(Vector3.BACK, -0.35)
		flesh.box(Vector3(cos(a2), 0.0, -sin(a2)) * 0.2 + Vector3(0.0, 0.55, 0.0), Vector3(0.32, 0.012, 0.22), basis, Color(0.55, 0.12, 0.18))
	var mesh := ArrayMesh.new()
	bone.commit(mesh, BloodTerrain.detail_material("bone"))
	flesh.commit(mesh, BloodTerrain.detail_material("blood"))
	return mesh


static func _pustule() -> ArrayMesh:
	var flesh := Buf.new()
	var glow := Buf.new()
	var sacs := [
		[Vector3(0.0, 0.15, 0.0), Vector3(0.3, 0.2, 0.3), 0.3],
		[Vector3(0.38, 0.1, 0.12), Vector3(0.2, 0.14, 0.2), 0.9],
		[Vector3(-0.28, 0.08, 0.22), Vector3(0.16, 0.12, 0.16), 1.6],
	]
	for sac: Array in sacs:
		var center: Vector3 = sac[0]
		var half: Vector3 = sac[1]
		var basis := Basis(Vector3.UP, float(sac[2]))
		flesh.box(center, half, basis, Color(0.62, 0.2, 0.26))
		glow.box(center + Vector3(0.0, half.y, 0.0), Vector3(half.x * 0.45, 0.04, half.z * 0.45), basis, Color(0.6, 0.38, 0.82))
	var mesh := ArrayMesh.new()
	flesh.commit(mesh, BloodTerrain.detail_material("blood"))
	glow.commit(mesh, _glow_material())
	return mesh


static func _arch() -> ArrayMesh:
	var bone := Buf.new()
	var radius := 2.8
	var steps := 8
	for side in [-0.7, 0.7]:
		for k in steps:
			var a0 := PI * float(k) / float(steps)
			var a1 := PI * float(k + 1) / float(steps)
			var p0 := Vector3(cos(a0) * radius, sin(a0) * radius - 0.3, side)
			var p1 := Vector3(cos(a1) * radius, sin(a1) * radius - 0.3, side)
			var tangent := (p1 - p0).normalized()
			var basis := Basis(Vector3.BACK, atan2(-tangent.x, tangent.y))
			var taper := 0.17 - 0.07 * absf(float(k) / float(steps) - 0.5) * 2.0 * 0.5
			bone.box((p0 + p1) * 0.5, Vector3(taper, p0.distance_to(p1) * 0.5 + 0.03, 0.13), basis, Color(0.86, 0.81, 0.7))
	for k in [2, 4, 6]:
		var a := PI * float(k) / float(steps)
		bone.box(Vector3(cos(a) * radius, sin(a) * radius - 0.3, 0.0), Vector3(0.05, 0.05, 0.72), Basis.IDENTITY, Color(0.8, 0.74, 0.64))
	var mesh := ArrayMesh.new()
	bone.commit(mesh, BloodTerrain.detail_material("bone"))
	return mesh
