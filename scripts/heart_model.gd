extends RefCounted

const TileArt = preload("res://scripts/tile_art.gd")

const TOWER_HEIGHT := 18
const TOWER_BURY := 2
const HEART_LIFT := 5.2
const RINGS := 44
const SEGMENTS := 60
const GRID_EPS := 0.004
const COLLIDER_STEP := 3
const ROOT_COUNT := 9
const CABLE_COUNT := 5
const ARC_COUNT := 7
const TENDRIL_COUNT := 6
const CYST_COUNT := 26
const NORMAL_SIZE := 256
const HEART_TILT := Vector3(0.12, 0.5, 0.22)
const BLOOD := Color(0.95, 0.72, 0.72)
const VEIN_TINT := Color(0.62, 0.5, 0.78)
const FLESH_TINT := Color(0.78, 0.55, 0.58)
const MEAT_TINT := Color(0.85, 0.5, 0.5)

const ORGANS := [
	{"pos": Vector3(0.0, 0.0, 0.0), "radii": Vector3(4.4, 5.4, 3.9), "taper": 0.62, "lump": 0.38, "freq": 0.22, "fine": 0.1, "seed": 11, "tilt": Vector3(0.12, 0.0, 0.3)},
	{"pos": Vector3(2.6, -0.8, 1.5), "radii": Vector3(3.0, 4.2, 2.8), "taper": 0.55, "lump": 0.32, "freq": 0.26, "fine": 0.1, "seed": 12, "tilt": Vector3(0.08, 0.0, 0.18)},
	{"pos": Vector3(-2.7, 3.5, -0.6), "radii": Vector3(1.8, 1.5, 1.7), "taper": 0.0, "lump": 0.5, "freq": 0.55, "fine": 0.16, "seed": 13, "tilt": Vector3(0.0, 0.0, 0.6)},
	{"pos": Vector3(3.1, 3.3, 0.9), "radii": Vector3(2.3, 1.9, 2.0), "taper": 0.0, "lump": 0.5, "freq": 0.5, "fine": 0.16, "seed": 14, "tilt": Vector3(0.0, 0.0, -0.5)},
]

static var materials: Dictionary = {}
static var normal_texture: NoiseTexture2D


class Buf:
	extends RefCounted

	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	func vertex(p: Vector3, normal: Vector3, coord: Vector2) -> int:
		v.append(p)
		n.append(normal)
		uv.append(coord)
		return v.size() - 1

	func tri(a: int, b: int, c: int) -> void:
		var geo := (v[b] - v[a]).cross(v[c] - v[a])
		var avg := n[a] + n[b] + n[c]
		if geo.dot(avg) > 0.0:
			idx.append_array(PackedInt32Array([a, c, b]))
		else:
			idx.append_array(PackedInt32Array([a, b, c]))

	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c)
		tri(a, c, d)

	func box(center: Vector3, half: Vector3, basis: Basis) -> void:
		var faces := [
			[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
			[Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
			[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
			[Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
			[Vector3.BACK, Vector3.UP, Vector3.LEFT],
			[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
		]
		for face: Array in faces:
			var normal: Vector3 = face[0]
			var up: Vector3 = face[1]
			var side: Vector3 = face[2]
			var wn := (basis * normal).normalized()
			var corners := [
				(normal + up + side) * half,
				(normal + up - side) * half,
				(normal - up - side) * half,
				(normal - up + side) * half,
			]
			var ids: Array = []
			var coords := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
			for i in 4:
				ids.append(vertex(center + basis * (corners[i] as Vector3), wn, coords[i]))
			quad(ids[0], ids[1], ids[2], ids[3])

	func to_mesh(material: Material) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		if v.size() > 0:
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, material)
		return mesh


static func _normal_map() -> NoiseTexture2D:
	if normal_texture == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.035
		noise.fractal_octaves = 4
		normal_texture = NoiseTexture2D.new()
		normal_texture.noise = noise
		normal_texture.width = NORMAL_SIZE
		normal_texture.height = NORMAL_SIZE
		normal_texture.seamless = true
		normal_texture.as_normal_map = true
		normal_texture.bump_strength = 7.0
	return normal_texture


static func _material(key: String, tile: String, fallback: Color, tint: Color, wet: bool, glow: Color, energy: float) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var m := (TileArt.block_material(tile, fallback) as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.albedo_color = tint
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if wet:
		m.roughness = 0.28
		m.clearcoat_enabled = true
		m.clearcoat = 0.7
		m.clearcoat_roughness = 0.12
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.55
		m.rim_enabled = true
		m.rim = 0.45
		m.rim_tint = 0.6
		m.normal_enabled = true
		m.normal_texture = _normal_map()
		m.normal_scale = 0.9
	else:
		m.roughness = 0.82
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = energy
	materials[key] = m
	return m


static func heart_material() -> StandardMaterial3D:
	return _material("heart", "blood", Color(0.5, 0.05, 0.1), BLOOD, true, Color(0.55, 0.04, 0.08), 0.55)


static func artery_material() -> StandardMaterial3D:
	return _material("artery", "blood", Color(0.5, 0.05, 0.1), Color(1.0, 0.6, 0.6), true, Color(0.6, 0.05, 0.08), 0.5)


static func vein_material() -> StandardMaterial3D:
	return _material("vein", "bile", Color(0.36, 0.2, 0.46), VEIN_TINT, true, Color(0.42, 0.2, 0.58), 0.8)


static func flesh_material() -> StandardMaterial3D:
	return _material("flesh", "gloom_flesh", Color(0.45, 0.14, 0.2), FLESH_TINT, false, Color.BLACK, 0.0)


static func meat_material() -> StandardMaterial3D:
	return _material("meat", "blood", Color(0.5, 0.05, 0.1), MEAT_TINT, true, Color(0.4, 0.03, 0.06), 0.35)


static func tower_vein_material() -> StandardMaterial3D:
	return _material("tower_vein", "bile", Color(0.36, 0.2, 0.46), Color(0.55, 0.42, 0.7), false, Color(0.38, 0.18, 0.5), 0.9)


static func _organ_point(cfg: Dictionary, noise: FastNoiseLite, u: float, v: float) -> Vector3:
	var theta := u * TAU
	var phi := v * PI
	var dir := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
	var radii: Vector3 = cfg["radii"]
	var p := dir * radii
	if dir.y < 0.0:
		var k := pow(-dir.y, 1.4)
		var squeeze := 1.0 - float(cfg["taper"]) * k
		p.x *= squeeze
		p.z *= squeeze
		p.y *= 1.0 + 0.12 * k
	var freq: float = cfg["freq"]
	var d: float = noise.get_noise_3d(p.x * freq, p.y * freq, p.z * freq) * float(cfg["lump"])
	d += noise.get_noise_3d(p.x * 3.1 + 40.0, p.y * 3.1, p.z * 3.1) * float(cfg["fine"])
	var groove := Vector3(0.35, 0.8, 0.25).normalized()
	var g := exp(-pow(dir.dot(groove) / 0.16, 2.0))
	d -= g * 0.32 * float(cfg["taper"] + 0.2)
	return p + dir * d


static func _organ_transform(cfg: Dictionary) -> Transform3D:
	var tilt: Vector3 = cfg["tilt"]
	return Transform3D(Basis.from_euler(tilt), cfg["pos"])


static func _organ_buf(cfg: Dictionary) -> Buf:
	var noise := FastNoiseLite.new()
	noise.seed = int(cfg["seed"])
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0
	var xf := _organ_transform(cfg)
	var buf := Buf.new()
	var cols := SEGMENTS + 1
	for j in RINGS + 1:
		var vv := float(j) / float(RINGS)
		for i in cols:
			var uu := float(i) / float(SEGMENTS)
			var p := _organ_point(cfg, noise, uu, vv)
			var vc := clampf(vv, 0.01, 0.99)
			var du := _organ_point(cfg, noise, uu + GRID_EPS, vc) - _organ_point(cfg, noise, uu - GRID_EPS, vc)
			var dv := _organ_point(cfg, noise, uu, minf(vc + GRID_EPS, 1.0)) - _organ_point(cfg, noise, uu, maxf(vc - GRID_EPS, 0.0))
			var nrm := du.cross(dv).normalized()
			if nrm.dot(p) < 0.0:
				nrm = -nrm
			buf.vertex(xf * p, (xf.basis * nrm).normalized(), Vector2(uu * 4.0, vv * 3.0))
	for j in RINGS:
		for i in SEGMENTS:
			var a := j * cols + i
			buf.quad(a, a + 1, a + cols + 1, a + cols)
	return buf


static func _spline(ctrl: PackedVector3Array, per: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var count := ctrl.size()
	for s in count - 1:
		var p0 := ctrl[maxi(s - 1, 0)]
		var p1 := ctrl[s]
		var p2 := ctrl[s + 1]
		var p3 := ctrl[mini(s + 2, count - 1)]
		for k in per:
			var t := float(k) / float(per)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(ctrl[count - 1])
	return out


static func _tube(buf: Buf, points: PackedVector3Array, r0: float, r1: float, sides: int, wobble: float = 0.0, phase: float = 0.0) -> void:
	var count := points.size()
	if count < 2:
		return
	var start := buf.v.size()
	var normal_ref := Vector3.UP
	var tangent := (points[1] - points[0]).normalized()
	if absf(tangent.dot(normal_ref)) > 0.9:
		normal_ref = Vector3.RIGHT
	var nrm := (normal_ref - tangent * normal_ref.dot(tangent)).normalized()
	for i in count:
		var t := float(i) / float(count - 1)
		if i > 0:
			var next := points[mini(i + 1, count - 1)]
			tangent = (next - points[i - 1]).normalized()
			nrm = (nrm - tangent * nrm.dot(tangent)).normalized()
		var bin := tangent.cross(nrm)
		var radius := lerpf(r0, r1, t) * (1.0 + wobble * sin(t * TAU * 3.0 + phase))
		for j in sides + 1:
			var a := TAU * float(j) / float(sides)
			var dir := nrm * cos(a) + bin * sin(a)
			buf.vertex(points[i] + dir * radius, dir, Vector2(float(j) / float(sides) * 2.0, t * 6.0))
	var cols := sides + 1
	for i in count - 1:
		for j in sides:
			var a2 := start + i * cols + j
			buf.quad(a2, a2 + 1, a2 + cols + 1, a2 + cols)


static func _add_mesh(parent: Node3D, buf: Buf, material: Material, name_text: String) -> ArrayMesh:
	var mesh := buf.to_mesh(material)
	if mesh.get_surface_count() == 0:
		return null
	var mi := MeshInstance3D.new()
	mi.name = name_text
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mesh


static func _collide(body: CollisionObject3D, mesh: ArrayMesh, xf: Transform3D = Transform3D.IDENTITY) -> void:
	if mesh == null:
		return
	var shape := mesh.create_trimesh_shape()
	if shape == null:
		return
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)


static func _surface_path(cfg: Dictionary, u0: float, v0: float, v1: float, wiggle: float, seed: int) -> PackedVector3Array:
	var noise := FastNoiseLite.new()
	noise.seed = int(cfg["seed"])
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var xf := _organ_transform(cfg)
	var out := PackedVector3Array()
	var steps := 18
	var phase := r.randf() * TAU
	for s in steps + 1:
		var t := float(s) / float(steps)
		var u := u0 + sin(t * 5.0 + phase) * wiggle
		var v := lerpf(v0, v1, t)
		var p := _organ_point(cfg, noise, u, v)
		var vc := clampf(v, 0.01, 0.99)
		var du := _organ_point(cfg, noise, u + GRID_EPS, vc) - _organ_point(cfg, noise, u - GRID_EPS, vc)
		var dv := _organ_point(cfg, noise, u, minf(vc + GRID_EPS, 1.0)) - _organ_point(cfg, noise, u, maxf(vc - GRID_EPS, 0.0))
		var nrm := du.cross(dv).normalized()
		if nrm.dot(p) < 0.0:
			nrm = -nrm
		out.append(xf * (p + nrm * 0.06))
	return out


static func build_heart(body: Node3D) -> OmniLight3D:
	var organs := Node3D.new()
	organs.name = "Organs"
	organs.basis = Basis.from_euler(HEART_TILT)
	body.add_child(organs)
	var heart_mat := heart_material()
	for i in ORGANS.size():
		var cfg: Dictionary = ORGANS[i]
		_collide(body as CollisionObject3D, _add_mesh(organs, _organ_buf(cfg), heart_mat, "Organ%d" % i), organs.transform)
	var arteries := Buf.new()
	var veins := Buf.new()
	var main_cfg: Dictionary = ORGANS[0]
	var rv_cfg: Dictionary = ORGANS[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for k in 9:
		var path := _surface_path(main_cfg, rng.randf(), rng.randf_range(0.12, 0.3), rng.randf_range(0.8, 0.96), rng.randf_range(0.01, 0.05), 100 + k)
		_tube(arteries if k % 2 == 0 else veins, path, 0.2, 0.07, 6)
	for k in 5:
		var path2 := _surface_path(rv_cfg, rng.randf(), rng.randf_range(0.15, 0.3), rng.randf_range(0.8, 0.95), rng.randf_range(0.01, 0.05), 200 + k)
		_tube(veins if k % 2 == 0 else arteries, path2, 0.16, 0.06, 6)
	_collide(body as CollisionObject3D, _add_mesh(organs, arteries, artery_material(), "CoronaryArteries"), organs.transform)
	_collide(body as CollisionObject3D, _add_mesh(organs, veins, vein_material(), "CoronaryVeins"), organs.transform)
	var drip := CPUParticles3D.new()
	var bead := SphereMesh.new()
	bead.radius = 0.1
	bead.height = 0.2
	bead.radial_segments = 6
	bead.rings = 3
	bead.material = artery_material()
	drip.mesh = bead
	drip.amount = 16
	drip.lifetime = 2.4
	drip.direction = Vector3.DOWN
	drip.spread = 12.0
	drip.gravity = Vector3(0.0, -9.0, 0.0)
	drip.initial_velocity_min = 0.2
	drip.initial_velocity_max = 0.8
	drip.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	drip.emission_sphere_radius = 1.0
	drip.position = Vector3(-1.2, -5.2, 0.4)
	body.add_child(drip)
	var cs := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 5.4
	cs.shape = ball
	body.add_child(cs)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.15, 0.22)
	light.light_energy = 3.0
	light.omni_range = 70.0
	body.add_child(light)
	return light


static func build_vessels(parent: Node3D, heart_y: float, ground_y: float) -> void:
	var root := Node3D.new()
	root.name = "Vessels"
	root.position = Vector3(0.0, heart_y, 0.0)
	parent.add_child(root)
	var drop := ground_y - heart_y
	var arteries := Buf.new()
	var veins := Buf.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for i in ARC_COUNT:
		var a := TAU * (float(i) + rng.randf_range(-0.2, 0.2)) / float(ARC_COUNT)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var peak := rng.randf_range(7.5, 10.5)
		var ctrl := PackedVector3Array([
			dir * 1.6 + Vector3(0.0, 2.8, 0.0),
			dir * 2.2 + Vector3(0.0, peak - 2.5, 0.0),
			dir * rng.randf_range(4.5, 6.0) + Vector3(0.0, peak, 0.0),
			dir * rng.randf_range(9.0, 11.0) + Vector3(0.0, peak * 0.2, 0.0),
			dir * rng.randf_range(12.5, 15.0) + Vector3(0.0, drop * 0.45, 0.0),
			dir * rng.randf_range(15.0, 18.0) + Vector3(0.0, drop * 0.8, 0.0),
			dir * rng.randf_range(16.5, 20.0) + Vector3(0.0, drop - 1.4, 0.0),
		])
		var path := _spline(ctrl, 8)
		_tube(arteries if i % 2 == 0 else veins, path, rng.randf_range(1.0, 1.25), rng.randf_range(0.65, 0.85), 12, 0.1, rng.randf() * TAU)
	for i in TENDRIL_COUNT:
		var a2 := TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / float(TENDRIL_COUNT) + 0.4
		var dir2 := Vector3(cos(a2), 0.0, sin(a2))
		var y0 := rng.randf_range(-3.0, 1.0)
		var ctrl2 := PackedVector3Array([
			dir2 * 3.4 + Vector3(0.0, y0, 0.0),
			dir2 * 6.5 + Vector3(0.0, y0 - 1.5, 0.0),
			dir2 * rng.randf_range(8.5, 11.0) + Vector3(0.0, drop * 0.4, 0.0),
			dir2 * rng.randf_range(9.0, 13.0) + Vector3(0.0, drop - 1.2, 0.0),
		])
		_tube(veins if i % 2 == 0 else arteries, _spline(ctrl2, 8), 0.36, 0.2, 8, 0.15, rng.randf() * TAU)
	var solid := StaticBody3D.new()
	solid.collision_layer = 1
	solid.collision_mask = 0
	root.add_child(solid)
	_collide(solid, _add_mesh(root, arteries, artery_material(), "Arteries"))
	_collide(solid, _add_mesh(root, veins, vein_material(), "Veins"))


static func tower_radius(y: float) -> float:
	var t := clampf(y / float(TOWER_HEIGHT), 0.0, 1.0)
	return lerpf(6.4, 3.0, pow(t, 0.75)) + 4.2 * exp(-maxf(y, 0.0) * 0.42) + 0.45 * sin(y * 0.9)


static func build_tower(parent: Node3D, ground_y: float) -> void:
	var root := Node3D.new()
	root.name = "HeartTower"
	root.position = Vector3(0.0, ground_y, 0.0)
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2718
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0
	var cells: Dictionary = {}
	for level in range(-TOWER_BURY, TOWER_HEIGHT):
		var r := tower_radius(float(level) + 0.5)
		var reach := int(ceil(r)) + 1
		for ix in range(-reach, reach + 1):
			for iz in range(-reach, reach + 1):
				var d := Vector2(float(ix) + 0.5, float(iz) + 0.5).length()
				if d > r:
					continue
				if d > r - 1.2 and rng.randf() < 0.2:
					continue
				cells[Vector3i(ix, level, iz)] = true
	var flesh := Buf.new()
	var meat := Buf.new()
	var vein := Buf.new()
	var dirs := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for key: Vector3i in cells.keys():
		var exposed := false
		for dv: Vector3i in dirs:
			if not cells.has(key + dv):
				exposed = true
				break
		if not exposed:
			continue
		var n := noise.get_noise_3d(float(key.x) * 0.35, float(key.y) * 0.35, float(key.z) * 0.35)
		var target := flesh
		if n > 0.32:
			target = vein
		elif n < -0.4:
			target = meat
		var jitter := Vector3(rng.randf_range(-0.07, 0.07), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.07, 0.07))
		var center := Vector3(float(key.x) + 0.5, float(key.y) + 0.5, float(key.z) + 0.5) + jitter
		var s := rng.randf_range(0.97, 1.06)
		var basis := Basis(Vector3.UP, rng.randf_range(-0.12, 0.12)) * Basis.from_scale(Vector3(s, s, s))
		target.box(center, Vector3(0.5, 0.5, 0.5), basis)
	for i in CYST_COUNT:
		var a := rng.randf() * TAU
		var dist := rng.randf_range(tower_radius(0.0) + 0.5, tower_radius(0.0) + 8.0)
		var size := rng.randf_range(0.7, 1.5)
		var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
		var pick := meat if i % 3 == 0 else flesh
		pick.box(Vector3(cos(a) * dist, size * 0.2, sin(a) * dist), Vector3(size, size, size) * 0.5, tilt)
	var cables := Buf.new()
	for i in CABLE_COUNT:
		var a0 := TAU * float(i) / float(CABLE_COUNT) + rng.randf_range(-0.2, 0.2)
		var turns := rng.randf_range(0.7, 1.3) * (1.0 if i % 2 == 0 else -1.0)
		var ctrl := PackedVector3Array()
		var samples := 12
		var base_r := tower_radius(0.0) + 8.0
		ctrl.append(Vector3(cos(a0) * base_r, -0.6, sin(a0) * base_r))
		ctrl.append(Vector3(cos(a0) * (base_r - 3.5), 0.3, sin(a0) * (base_r - 3.5)))
		for s in samples + 1:
			var t := float(s) / float(samples)
			var y := lerpf(1.0, float(TOWER_HEIGHT) - 0.5, t)
			var ang := a0 + t * turns * TAU
			var rad := tower_radius(y) + 0.5
			ctrl.append(Vector3(cos(ang) * rad, y, sin(ang) * rad))
		var top_ang := a0 + turns * TAU
		ctrl.append(Vector3(cos(top_ang) * 2.4, float(TOWER_HEIGHT) + 2.0, sin(top_ang) * 2.4))
		_tube(cables, _spline(ctrl, 6), 0.62, 0.42, 10, 0.12, rng.randf() * TAU)
	var roots := Buf.new()
	for i in ROOT_COUNT:
		var ar := TAU * (float(i) + rng.randf_range(-0.25, 0.25)) / float(ROOT_COUNT)
		var dir := Vector3(cos(ar), 0.0, sin(ar))
		var start := tower_radius(0.0) - 1.0
		var ctrl2 := PackedVector3Array([
			dir * start + Vector3(0.0, 1.2, 0.0),
			dir * (start + 4.0) + Vector3(0.0, 0.9, 0.0),
			dir * (start + 8.0) + Vector3(0.0, 0.5, 0.0),
			dir * (start + rng.randf_range(11.0, 16.0)) + Vector3(0.0, 0.1, 0.0),
			dir * (start + rng.randf_range(17.0, 22.0)) + Vector3(0.0, -1.6, 0.0),
		])
		_tube(roots, _spline(ctrl2, 8), rng.randf_range(0.85, 1.1), 0.3, 10, 0.2, rng.randf() * TAU)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	_collide(body, _add_mesh(root, flesh, flesh_material(), "FleshBlocks"))
	_collide(body, _add_mesh(root, meat, meat_material(), "MeatBlocks"))
	_collide(body, _add_mesh(root, vein, tower_vein_material(), "VeinBlocks"))
	_collide(body, _add_mesh(root, cables, vein_material(), "Cables"))
	_collide(body, _add_mesh(root, roots, artery_material(), "Roots"))
	for level in range(0, TOWER_HEIGHT, COLLIDER_STEP):
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = maxf(tower_radius(float(level) + COLLIDER_STEP * 0.5) - 0.8, 1.0)
		cyl.height = float(COLLIDER_STEP)
		cs.shape = cyl
		cs.position = Vector3(0.0, float(level) + COLLIDER_STEP * 0.5, 0.0)
		body.add_child(cs)
