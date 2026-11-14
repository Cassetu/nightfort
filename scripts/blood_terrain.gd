extends RefCounted

const TileArt = preload("res://scripts/tile_art.gd")

const HALF := 300.0
const CELL := 3.0
const CH := 32
const CMIN := -10
const CMAX := 9
const FINE_R := 2
const COARSE := 4
const SKIRT := 8
const OUTSIDE := -20
const START := Vector2(0.0, -165.0)
const PAD_COLLIDER_INSET := 3.0
const PAD_H := 4.0
const HEART := Vector2(0.0, 0.0)
const ARMY := Vector2(0.0, -185.0)
const HEART_FLAT := 135.0
const HEART_BLEND := 190.0
const ARMY_FLAT := 36.0
const ARMY_BLEND := 72.0
const POOL_LEVEL := -1.5
const RIM_START := 245.0
const RIM_HEIGHT := 48.0
const RINGS := [100.0, 68.0, 40.0]
const WALL_DEPTH := 2.5

static var origin := Vector3.ZERO

class MeshBuf:
	extends RefCounted

	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, normal: Vector3, color: Color, uw: float, uh: float) -> void:
		var pts: Array = [a, b, d, e]
		var uvs: Array = [Vector2(0.0, 0.0), Vector2(uw, 0.0), Vector2(uw, uh), Vector2(0.0, uh)]
		if (b - a).cross(d - a).dot(normal) > 0.0:
			pts = [a, e, d, b]
			uvs = [uvs[0], uvs[3], uvs[2], uvs[1]]
		var base := v.size()
		for i in 4:
			v.append(pts[i])
			n.append(normal)
			c.append(color)
			uv.append(uvs[i])
		idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))

	func to_mesh(material: Material) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		if v.size() > 0:
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, material)
		return mesh

var n_hills: FastNoiseLite
var n_ridge: FastNoiseLite
var n_veins: FastNoiseLite
var n_detail: FastNoiseLite
var n_tint: FastNoiseLite
var material: StandardMaterial3D
var chunks_root: Node3D
var records: Dictionary = {}
var pending: Array = []
var last_center := Vector2i(1 << 20, 1 << 20)


func _init(seed_value: int = 7041) -> void:
	n_hills = _make(seed_value, 0.004, 4, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
	n_ridge = _make(seed_value + 1, 0.011, 3, FastNoiseLite.TYPE_SIMPLEX)
	n_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n_veins = _make(seed_value + 2, 0.016, 1, FastNoiseLite.TYPE_CELLULAR)
	n_veins.fractal_type = FastNoiseLite.FRACTAL_NONE
	n_veins.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n_detail = _make(seed_value + 3, 0.07, 2, FastNoiseLite.TYPE_SIMPLEX)
	n_tint = _make(seed_value + 4, 0.02, 2, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)


func _make(seed_value: int, freq: float, octaves: int, type: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = type
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


func raw(x: float, z: float) -> float:
	var h: float = n_hills.get_noise_2d(x, z) * 20.0
	h += (n_ridge.get_noise_2d(x, z) * 0.5 + 0.5) * 12.0
	var edge: float = clampf(n_veins.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
	h -= (1.0 - smoothstep(0.0, 0.2, edge)) * 5.0
	var stepped: float = floorf(h / 2.5) * 2.5
	h = lerpf(h, stepped, 0.3)
	h += n_detail.get_noise_2d(x, z) * 0.6
	return h


func pad_weight(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var wh: float = 1.0 - smoothstep(HEART_FLAT, HEART_BLEND, p.distance_to(HEART))
	var wa: float = 1.0 - smoothstep(ARMY_FLAT, ARMY_BLEND, p.distance_to(ARMY))
	return maxf(wh, wa)


func smooth(x: float, z: float) -> float:
	var w: float = pad_weight(x, z)
	var h: float = lerpf(raw(x, z), PAD_H + n_detail.get_noise_2d(x, z) * 0.2, w)
	var rim: float = smoothstep(RIM_START, HALF, maxf(absf(x), absf(z)))
	return h + rim * RIM_HEIGHT


func top(ix: int, iz: int) -> int:
	return roundi(smooth(float(ix) + 0.5, float(iz) + 0.5))


func height(x: float, z: float) -> float:
	return float(top(floori(x), floori(z)))


func _world_top(ix: int, iz: int) -> int:
	if ix < CMIN * CH or iz < CMIN * CH or ix >= (CMAX + 1) * CH or iz >= (CMAX + 1) * CH:
		return OUTSIDE
	return top(ix, iz)


func _coarse_top(cx: int, cz: int) -> int:
	if cx < CMIN * CH / COARSE or cz < CMIN * CH / COARSE or cx >= (CMAX + 1) * CH / COARSE or cz >= (CMAX + 1) * CH / COARSE:
		return OUTSIDE
	return roundi(smooth(float(cx * COARSE) + COARSE * 0.5, float(cz * COARSE) + COARSE * 0.5))


func color_at(x: float, z: float, h: float, slope: float) -> Color:
	var mottle: float = n_tint.get_noise_2d(x, z) * 0.5 + 0.5
	var col := Color(0.62, 0.12, 0.12).lerp(Color(0.45, 0.28, 0.42), mottle)
	if h < POOL_LEVEL + 0.7:
		col = Color(0.8, 0.06, 0.1)
	elif h > 18.0:
		col = col.lerp(Color(1.0, 0.95, 0.88), clampf((h - 18.0) / 10.0, 0.0, 1.0))
	if slope > 0.5:
		col = col.lerp(Color(0.28, 0.24, 0.3), clampf((slope - 0.5) * 2.5, 0.0, 1.0))
	return col


func _hash(x: int, z: int) -> float:
	var h: int = (x * 73856093) ^ (z * 19349663)
	return float(h & 1023) / 1023.0


func _fine_mesh(cx: int, cz: int) -> ArrayMesh:
	var x0 := cx * CH
	var z0 := cz * CH
	var w := CH + 2
	var hs := PackedInt32Array()
	hs.resize(w * w)
	for j in w:
		for i in w:
			hs[j * w + i] = _world_top(x0 + i - 1, z0 + j - 1)
	var buf := MeshBuf.new()
	for j in CH:
		for i in CH:
			var h: int = hs[(j + 1) * w + i + 1]
			var hl: int = hs[(j + 1) * w + i]
			var hr: int = hs[(j + 1) * w + i + 2]
			var hb: int = hs[j * w + i + 1]
			var hf: int = hs[(j + 2) * w + i + 1]
			var wx := float(x0 + i)
			var wz := float(z0 + j)
			var hy := float(h)
			var steep := maxi(maxi(absi(h - hl), absi(h - hr)), maxi(absi(h - hb), absi(h - hf)))
			var col := color_at(wx + 0.5, wz + 0.5, hy, clampf(float(steep) * 0.25, 0.0, 1.0))
			var taller := int(hl > h) + int(hr > h) + int(hb > h) + int(hf > h)
			var shade := (0.94 + 0.12 * _hash(x0 + i, z0 + j)) * (1.0 - 0.07 * float(taller))
			var lit := Color(col.r * shade, col.g * shade, col.b * shade)
			buf.quad(Vector3(wx, hy, wz), Vector3(wx + 1.0, hy, wz), Vector3(wx + 1.0, hy, wz + 1.0), Vector3(wx, hy, wz + 1.0), Vector3.UP, lit, 1.0, 1.0)
			var dark := Color(lit.r * 0.72, lit.g * 0.72, lit.b * 0.72)
			if hl < h:
				var y2 := float(hl)
				buf.quad(Vector3(wx, hy, wz), Vector3(wx, hy, wz + 1.0), Vector3(wx, y2, wz + 1.0), Vector3(wx, y2, wz), Vector3.LEFT, dark, 1.0, hy - y2)
			if hr < h:
				var y3 := float(hr)
				buf.quad(Vector3(wx + 1.0, hy, wz), Vector3(wx + 1.0, hy, wz + 1.0), Vector3(wx + 1.0, y3, wz + 1.0), Vector3(wx + 1.0, y3, wz), Vector3.RIGHT, dark, 1.0, hy - y3)
			if hb < h:
				var y4 := float(hb)
				buf.quad(Vector3(wx, hy, wz), Vector3(wx + 1.0, hy, wz), Vector3(wx + 1.0, y4, wz), Vector3(wx, y4, wz), Vector3.FORWARD, dark, 1.0, hy - y4)
			if hf < h:
				var y5 := float(hf)
				buf.quad(Vector3(wx, hy, wz + 1.0), Vector3(wx + 1.0, hy, wz + 1.0), Vector3(wx + 1.0, y5, wz + 1.0), Vector3(wx, y5, wz + 1.0), Vector3.BACK, dark, 1.0, hy - y5)
	return buf.to_mesh(material)


func _coarse_mesh(cx: int, cz: int) -> ArrayMesh:
	var n := CH / COARSE
	var x0 := cx * n
	var z0 := cz * n
	var w := n + 2
	var hs := PackedInt32Array()
	hs.resize(w * w)
	for j in w:
		for i in w:
			hs[j * w + i] = _coarse_top(x0 + i - 1, z0 + j - 1)
	var buf := MeshBuf.new()
	var s := float(COARSE)
	for j in n:
		for i in n:
			var h: int = hs[(j + 1) * w + i + 1]
			var hl: int = hs[(j + 1) * w + i]
			var hr: int = hs[(j + 1) * w + i + 2]
			var hb: int = hs[j * w + i + 1]
			var hf: int = hs[(j + 2) * w + i + 1]
			var wx := float((x0 + i) * COARSE)
			var wz := float((z0 + j) * COARSE)
			var hy := float(h)
			var steep := maxi(maxi(absi(h - hl), absi(h - hr)), maxi(absi(h - hb), absi(h - hf)))
			var col := color_at(wx + s * 0.5, wz + s * 0.5, hy, clampf(float(steep) * 0.08, 0.0, 1.0))
			var shade := 0.94 + 0.12 * _hash(x0 + i, z0 + j)
			var lit := Color(col.r * shade, col.g * shade, col.b * shade)
			buf.quad(Vector3(wx, hy, wz), Vector3(wx + s, hy, wz), Vector3(wx + s, hy, wz + s), Vector3(wx, hy, wz + s), Vector3.UP, lit, s, s)
			var dark := Color(lit.r * 0.72, lit.g * 0.72, lit.b * 0.72)
			var drop_l := float(maxi(h - hl, SKIRT if i == 0 else 0))
			if drop_l > 0.0:
				buf.quad(Vector3(wx, hy, wz), Vector3(wx, hy, wz + s), Vector3(wx, hy - drop_l, wz + s), Vector3(wx, hy - drop_l, wz), Vector3.LEFT, dark, s, drop_l)
			var drop_r := float(maxi(h - hr, SKIRT if i == n - 1 else 0))
			if drop_r > 0.0:
				buf.quad(Vector3(wx + s, hy, wz), Vector3(wx + s, hy, wz + s), Vector3(wx + s, hy - drop_r, wz + s), Vector3(wx + s, hy - drop_r, wz), Vector3.RIGHT, dark, s, drop_r)
			var drop_b := float(maxi(h - hb, SKIRT if j == 0 else 0))
			if drop_b > 0.0:
				buf.quad(Vector3(wx, hy, wz), Vector3(wx + s, hy, wz), Vector3(wx + s, hy - drop_b, wz), Vector3(wx, hy - drop_b, wz), Vector3.FORWARD, dark, s, drop_b)
			var drop_f := float(maxi(h - hf, SKIRT if j == n - 1 else 0))
			if drop_f > 0.0:
				buf.quad(Vector3(wx, hy, wz + s), Vector3(wx + s, hy, wz + s), Vector3(wx + s, hy - drop_f, wz + s), Vector3(wx, hy - drop_f, wz + s), Vector3.BACK, dark, s, drop_f)
	return buf.to_mesh(material)


func _is_fine(coord: Vector2i, center: Vector2i) -> bool:
	return maxi(absi(coord.x - center.x), absi(coord.y - center.y)) <= FINE_R


func _set_chunk(coord: Vector2i, fine: bool) -> void:
	var rec: Dictionary = records.get(coord, {})
	if rec.is_empty():
		var holder := Node3D.new()
		holder.name = "Chunk_%d_%d" % [coord.x, coord.y]
		chunks_root.add_child(holder)
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		holder.add_child(mi)
		rec = {"holder": holder, "mi": mi, "body": null, "fine": null}
		records[coord] = rec
	if rec["fine"] == fine:
		return
	rec["fine"] = fine
	var mesh: ArrayMesh = _fine_mesh(coord.x, coord.y) if fine else _coarse_mesh(coord.x, coord.y)
	(rec["mi"] as MeshInstance3D).mesh = mesh
	var old = rec["body"]
	if old != null and is_instance_valid(old):
		old.queue_free()
		rec["body"] = null
	if fine and mesh.get_surface_count() > 0:
		var body := StaticBody3D.new()
		body.name = "Body"
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		(rec["holder"] as Node3D).add_child(body)
		rec["body"] = body


func update(local: Vector3, budget: int = 1) -> void:
	if absf(local.x) > HALF + 100.0 or absf(local.z) > HALF + 100.0:
		return
	var c := Vector2i(floori(local.x / float(CH)), floori(local.z / float(CH)))
	if c != last_center:
		var jump := maxi(absi(c.x - last_center.x), absi(c.y - last_center.y)) > FINE_R * 2
		last_center = c
		pending.clear()
		for coord: Vector2i in records:
			var rec: Dictionary = records[coord]
			if rec["fine"] != _is_fine(coord, c):
				pending.append(coord)
		pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - c).length_squared() < (b - c).length_squared())
		if jump:
			budget = pending.size()
	for i in budget:
		if pending.is_empty():
			return
		var coord: Vector2i = pending.pop_front()
		_set_chunk(coord, _is_fine(coord, last_center))


func _add_pad_collider(parent: Node3D, at: Vector2, radius: float) -> void:
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 2.0
	cs.shape = cyl
	cs.position = Vector3(at.x, PAD_H - 1.0, at.y)
	parent.add_child(cs)


func build(parent: Node3D) -> StaticBody3D:
	material = ground_material()
	var body := StaticBody3D.new()
	body.name = "Ground"
	parent.add_child(body)
	_add_pad_collider(body, HEART, HEART_FLAT - PAD_COLLIDER_INSET)
	_add_pad_collider(body, ARMY, ARMY_FLAT - PAD_COLLIDER_INSET)
	chunks_root = Node3D.new()
	chunks_root.name = "Chunks"
	parent.add_child(chunks_root)
	var start := Vector2i(floori(START.x / float(CH)), floori(START.y / float(CH)))
	last_center = start
	for cz in range(CMIN, CMAX + 1):
		for cx in range(CMIN, CMAX + 1):
			var coord := Vector2i(cx, cz)
			_set_chunk(coord, _is_fine(coord, start))

	var pool := PlaneMesh.new()
	pool.size = Vector2(HALF * 2.0, HALF * 2.0)
	var pool_mat := StandardMaterial3D.new()
	pool_mat.albedo_color = Color(0.7, 0.45, 0.5, 0.9)
	pool_mat.albedo_texture = TileArt.mip_texture("blood", Color(0.32, 0.015, 0.04))
	pool_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	pool_mat.uv1_scale = Vector3(HALF / 3.0, HALF / 3.0, 1.0)
	pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_mat.roughness = 0.1
	pool_mat.metallic = 0.3
	pool_mat.emission_enabled = true
	pool_mat.emission = Color(0.18, 0.0, 0.02)
	pool.material = pool_mat
	var pool_node := MeshInstance3D.new()
	pool_node.mesh = pool
	pool_node.position = Vector3(0.0, POOL_LEVEL, 0.0)
	pool_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(pool_node)
	return body


static func ground_material() -> StandardMaterial3D:
	return TileArt.uv_material("stone", Color(0.44, 0.44, 0.47), Vector3.ONE, true)


static func detail_material(tile: String) -> StandardMaterial3D:
	var base := TileArt.block_material(tile, Color(0.44, 0.44, 0.47))
	var m := base.duplicate() as StandardMaterial3D
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1)
	return m


static func glow_material(tile: String, fallback: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var m := detail_material(tile)
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	m.roughness = 0.45
	return m


static func append_box(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array, center: Vector3, half: Vector3, basis: Basis, color: Color) -> void:
	for normal: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var u := Vector3.UP if absf(normal.y) < 0.5 else Vector3.RIGHT
		var w := (-normal).cross(u)
		var hu := absf(u.x) * half.x + absf(u.y) * half.y + absf(u.z) * half.z
		var hw := absf(w.x) * half.x + absf(w.y) * half.y + absf(w.z) * half.z
		var o := Vector3(normal.x * half.x, normal.y * half.y, normal.z * half.z)
		var base := v.size()
		v.append(center + basis * (o - u * hu - w * hw))
		v.append(center + basis * (o + u * hu - w * hw))
		v.append(center + basis * (o + u * hu + w * hw))
		v.append(center + basis * (o - u * hu + w * hw))
		var rotated := basis * normal
		for i in 4:
			n.append(rotated)
			c.append(color)
		idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


static func to_mesh(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array, material: Material) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


static func band(world_pos: Vector3) -> int:
	var d := Vector2(world_pos.x - origin.x, world_pos.z - origin.z).length()
	var inside := 0
	for r: float in RINGS:
		if d < r - WALL_DEPTH:
			inside += 1
	return inside
