extends RefCounted

const BloodTerrain = preload("res://scripts/blood_terrain.gd")

const GATE_OUT := 3.45
const GATE_HALF_DEPTH := 2.25
const GATE_PASSAGE := 4.0
const TOWER_HALF_WIDTH := 2.4
const TOWER_HEIGHT := 10.0
const LINTEL_Y := 8.4
const LINTEL_HALF := 0.9
const TOOTH_COUNT := 7
const SPIKE_COUNT := 4
const STATION_EVERY := 11.0
const ARCH_EVERY := 3
const GROWTH_EVERY := 4
const GATE_KEEP_BEHIND := 4.0
const GATE_KEEP_AHEAD := 9.0
const SPINE_SIDE := 1.7
const GROWTH_SIDE := 4.6
const ARCH_SCALE := 1.45
const ARCH_RADIUS := 2.8
const ARCH_STEPS := 9
const FLESH_TINT := Color(0.72, 0.5, 0.56)
const BONE_TINT := Color(0.86, 0.81, 0.7)
const GLOW_TINT := Color(0.6, 0.38, 0.82)
const BILE := Color(0.36, 0.2, 0.46)


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


static func _shade(color: Color, tone: float) -> Color:
	return Color(color.r * tone, color.g * tone, color.b * tone)


static func _gate_frame(d: Vector2) -> Basis:
	var d3 := Vector3(d.x, 0.0, d.y)
	return Basis(Vector3.UP.cross(d3), Vector3.UP, d3)


static func _in_gate_zone(s: float) -> bool:
	for r: float in BloodTerrain.RINGS:
		if s > r - GATE_KEEP_BEHIND and s < r + GATE_KEEP_AHEAD:
			return true
	return false


static func _add_collider(body: StaticBody3D, xform: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.transform = xform
	body.add_child(cs)


static func _gatehouse(flesh: Buf, bone: Buf, glow: Buf, body: StaticBody3D, d: Vector2, r: float, floor_y: float, rng: RandomNumberGenerator) -> void:
	var basis := _gate_frame(d)
	var base := Vector3(d.x * (r + GATE_OUT), floor_y, d.y * (r + GATE_OUT))
	var xf := Transform3D(basis, base)
	for side: float in [-1.0, 1.0]:
		var cx: float = side * (GATE_PASSAGE + TOWER_HALF_WIDTH)
		var tone: float = rng.randf_range(0.85, 1.1)
		flesh.box(xf * Vector3(cx, TOWER_HEIGHT * 0.5, 0.0), Vector3(TOWER_HALF_WIDTH, TOWER_HEIGHT * 0.5, GATE_HALF_DEPTH), basis, _shade(FLESH_TINT, tone))
		flesh.box(xf * Vector3(cx, TOWER_HEIGHT + 0.4, 0.0), Vector3(TOWER_HALF_WIDTH + 0.4, 0.4, GATE_HALF_DEPTH + 0.4), basis, _shade(FLESH_TINT, tone * 0.82))
		flesh.box(xf * Vector3(cx, TOWER_HEIGHT * 0.45, 0.0), Vector3(TOWER_HALF_WIDTH + 0.2, 0.35, GATE_HALF_DEPTH + 0.2), basis, _shade(FLESH_TINT, tone * 0.9))
		for k in SPIKE_COUNT:
			var sx: float = cx + lerpf(-1.5, 1.5, float(k) / float(SPIKE_COUNT - 1))
			var sz: float = rng.randf_range(-1.2, 1.2)
			var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25)))
			var len: float = rng.randf_range(1.0, 1.7)
			bone.box(xf * Vector3(sx, TOWER_HEIGHT + 0.8 + len, sz), Vector3(0.14, len, 0.14), basis * tilt, _shade(BONE_TINT, rng.randf_range(0.9, 1.05)))
		glow.box(xf * Vector3(cx, 6.4, GATE_HALF_DEPTH + 0.06), Vector3(0.5, 0.7, 0.12), basis, GLOW_TINT)
		glow.box(xf * Vector3(cx, 3.2, GATE_HALF_DEPTH + 0.06), Vector3(0.35, 0.45, 0.12), basis, GLOW_TINT)
		_add_collider(body, Transform3D(basis, xf * Vector3(cx, TOWER_HEIGHT * 0.5, 0.0)), Vector3(TOWER_HALF_WIDTH * 2.0, TOWER_HEIGHT, GATE_HALF_DEPTH * 2.0))
	flesh.box(xf * Vector3(0.0, LINTEL_Y, 0.0), Vector3(GATE_PASSAGE + 0.3, LINTEL_HALF, GATE_HALF_DEPTH - 0.1), basis, _shade(FLESH_TINT, 0.95))
	_add_collider(body, Transform3D(basis, xf * Vector3(0.0, LINTEL_Y, 0.0)), Vector3((GATE_PASSAGE + 0.3) * 2.0, LINTEL_HALF * 2.0, (GATE_HALF_DEPTH - 0.1) * 2.0))
	for k in TOOTH_COUNT:
		var tx: float = lerpf(-GATE_PASSAGE + 0.6, GATE_PASSAGE - 0.6, float(k) / float(TOOTH_COUNT - 1))
		var len2: float = rng.randf_range(0.8, 1.5)
		bone.box(xf * Vector3(tx, LINTEL_Y - LINTEL_HALF - len2 * 0.5 + 0.1, rng.randf_range(-0.6, 0.6)), Vector3(0.1, len2 * 0.5, 0.1), basis, _shade(BONE_TINT, rng.randf_range(0.9, 1.05)))


static func _spine_mesh() -> ArrayMesh:
	var bone := Buf.new()
	bone.box(Vector3(0.0, 1.2, 0.0), Vector3(0.2, 1.2, 0.2), Basis.from_euler(Vector3(0.08, 0.0, 0.1)), BONE_TINT)
	bone.box(Vector3(0.0, 2.5, 0.0), Vector3(0.1, 0.8, 0.1), Basis.from_euler(Vector3(0.1, 0.0, 0.2)), _shade(BONE_TINT, 1.06))
	bone.box(Vector3(0.0, 0.25, 0.0), Vector3(0.38, 0.25, 0.38), Basis.IDENTITY, Color(0.55, 0.16, 0.2))
	var mesh := ArrayMesh.new()
	bone.commit(mesh, BloodTerrain.detail_material("bone"))
	return mesh


static func _growth_mesh() -> ArrayMesh:
	var flesh := Buf.new()
	var glow := Buf.new()
	var lumps := [
		[Vector3(0.0, 0.45, 0.0), Vector3(1.1, 0.5, 0.95), 0.2],
		[Vector3(0.7, 0.35, 0.5), Vector3(0.6, 0.38, 0.55), 0.9],
		[Vector3(-0.6, 0.3, 0.5), Vector3(0.5, 0.32, 0.45), 1.6],
		[Vector3(0.1, 1.0, -0.1), Vector3(0.6, 0.45, 0.55), 0.5],
	]
	for lump: Array in lumps:
		var center: Vector3 = lump[0]
		var half: Vector3 = lump[1]
		var basis := Basis(Vector3.UP, float(lump[2]))
		flesh.box(center, half, basis, Color(0.6, 0.18, 0.24))
		glow.box(center + Vector3(0.0, half.y, 0.0), Vector3(half.x * 0.4, 0.05, half.z * 0.4), basis, GLOW_TINT)
	var mesh := ArrayMesh.new()
	flesh.commit(mesh, BloodTerrain.detail_material("blood"))
	glow.commit(mesh, BloodTerrain.glow_material("bile", Color(0.3, 0.16, 0.4), BILE, 1.8))
	return mesh


static func _arch_mesh() -> ArrayMesh:
	var bone := Buf.new()
	for side: float in [-0.7, 0.7]:
		for k in ARCH_STEPS:
			var a0: float = PI * float(k) / float(ARCH_STEPS)
			var a1: float = PI * float(k + 1) / float(ARCH_STEPS)
			var p0 := Vector3(cos(a0) * ARCH_RADIUS, sin(a0) * ARCH_RADIUS - 0.3, side)
			var p1 := Vector3(cos(a1) * ARCH_RADIUS, sin(a1) * ARCH_RADIUS - 0.3, side)
			var tangent := (p1 - p0).normalized()
			var basis := Basis(Vector3.BACK, atan2(-tangent.x, tangent.y))
			var taper: float = 0.2 - 0.08 * absf(float(k) / float(ARCH_STEPS) - 0.5) * 2.0 * 0.5
			bone.box((p0 + p1) * 0.5, Vector3(taper, p0.distance_to(p1) * 0.5 + 0.03, 0.15), basis, BONE_TINT)
	for k in [2, 4, 5, 7]:
		var a: float = PI * float(k) / float(ARCH_STEPS)
		bone.box(Vector3(cos(a) * ARCH_RADIUS, sin(a) * ARCH_RADIUS - 0.3, 0.0), Vector3(0.06, 0.06, 0.72), Basis.IDENTITY, _shade(BONE_TINT, 0.94))
	var mesh := ArrayMesh.new()
	bone.commit(mesh, BloodTerrain.detail_material("bone"))
	return mesh


static func _multi(mesh: ArrayMesh, transforms: Array, tones: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		var tone: float = tones[i]
		mm.set_instance_color(i, Color(tone, tone, tone))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _ground(gen, at: Vector2) -> Vector3:
	return Vector3(at.x, gen.height(at.x, at.y), at.y)


static func _dress(host: Node3D, gen, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var spines: Array = []
	var spine_tones: Array = []
	var growths: Array = []
	var growth_tones: Array = []
	var arches: Array = []
	var arch_tones: Array = []
	for k in 4:
		var s: float = BloodTerrain.ROAD_FROM + 12.0
		var station := 0
		while s < BloodTerrain.ROAD_TO - 6.0:
			station += 1
			var here: float = s
			s += STATION_EVERY + rng.randf_range(-1.5, 1.5)
			if _in_gate_zone(here):
				continue
			var center: Vector2 = BloodTerrain.road_center(k, here)
			var ahead: Vector2 = BloodTerrain.road_center(k, here + 1.0)
			var heading: Vector2 = (ahead - center).normalized()
			var side_dir := Vector2(-heading.y, heading.x)
			if station % ARCH_EVERY == 0:
				var yaw: float = atan2(-side_dir.y, side_dir.x)
				var spot := _ground(gen, center)
				var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * ARCH_SCALE)
				arches.append(Transform3D(basis, spot - Vector3(0.0, 0.1, 0.0)))
				arch_tones.append(rng.randf_range(0.9, 1.05))
				var flat := Basis(Vector3.UP, yaw)
				for side: float in [-1.0, 1.0]:
					var foot := spot + Vector3(side_dir.x, 0.0, side_dir.y) * side * ARCH_RADIUS * ARCH_SCALE
					_add_collider(body, Transform3D(flat, foot + Vector3(0.0, 1.5, 0.0)), Vector3(0.8, 3.0, 2.2))
				continue
			var face: float = 1.0 if station % 2 == 0 else -1.0
			for side: float in [-1.0, 1.0]:
				var off: float = BloodTerrain.ROAD_HALF + SPINE_SIDE + rng.randf_range(-0.3, 0.5)
				var pos2: Vector2 = center + side_dir * side * off + heading * rng.randf_range(-1.5, 1.5)
				var spot2 := _ground(gen, pos2)
				var scale: float = rng.randf_range(0.8, 1.4)
				var lean := Basis.from_euler(Vector3(rng.randf_range(-0.08, 0.08), rng.randf() * TAU, rng.randf_range(-0.08, 0.08)))
				spines.append(Transform3D(lean.scaled(Vector3.ONE * scale), spot2 - Vector3(0.0, 0.1, 0.0)))
				spine_tones.append(rng.randf_range(0.88, 1.06))
			if station % GROWTH_EVERY == 0:
				var gpos: Vector2 = center + side_dir * face * (BloodTerrain.ROAD_HALF + GROWTH_SIDE + rng.randf_range(0.0, 1.5))
				var gspot := _ground(gen, gpos)
				var gscale: float = rng.randf_range(0.9, 1.5)
				var gbasis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * gscale)
				growths.append(Transform3D(gbasis, gspot - Vector3(0.0, 0.2, 0.0)))
				growth_tones.append(rng.randf_range(0.85, 1.1))
	if not spines.is_empty():
		var spine_node := _multi(_spine_mesh(), spines, spine_tones)
		spine_node.name = "RoadSpines"
		host.add_child(spine_node)
	if not growths.is_empty():
		var growth_node := _multi(_growth_mesh(), growths, growth_tones)
		growth_node.name = "RoadGrowths"
		host.add_child(growth_node)
	if not arches.is_empty():
		var arch_node := _multi(_arch_mesh(), arches, arch_tones)
		arch_node.name = "RoadArches"
		host.add_child(arch_node)


static func build(host: Node3D, gen) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161
	var body := StaticBody3D.new()
	body.name = "RoadBody"
	body.collision_layer = 1
	body.collision_mask = 0
	host.add_child(body)
	var flesh := Buf.new()
	var bone := Buf.new()
	var glow := Buf.new()
	for k in 4:
		var d: Vector2 = BloodTerrain.ROAD_DIRS[k]
		for r: float in BloodTerrain.RINGS:
			_gatehouse(flesh, bone, glow, body, d, r, BloodTerrain.PAD_H, rng)
	var mesh := ArrayMesh.new()
	flesh.commit(mesh, BloodTerrain.detail_material("gloom_flesh"))
	bone.commit(mesh, BloodTerrain.detail_material("bone"))
	glow.commit(mesh, BloodTerrain.glow_material("bile", Color(0.3, 0.16, 0.4), BILE, 1.8))
	var gates := MeshInstance3D.new()
	gates.name = "Gatehouses"
	gates.mesh = mesh
	host.add_child(gates)
	_dress(host, gen, body, rng)
