extends RefCounted

const TileArt = preload("res://scripts/tile_art.gd")

const HALF := 300.0
const CELL := 3.0
const GRID := 200
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

static var origin := Vector3.ZERO

var n_hills: FastNoiseLite
var n_ridge: FastNoiseLite
var n_veins: FastNoiseLite
var n_detail: FastNoiseLite
var n_tint: FastNoiseLite


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


func height(x: float, z: float) -> float:
	var w: float = pad_weight(x, z)
	var h: float = lerpf(raw(x, z), PAD_H + n_detail.get_noise_2d(x, z) * 0.2, w)
	var rim: float = smoothstep(RIM_START, HALF, maxf(absf(x), absf(z)))
	return h + rim * RIM_HEIGHT


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


func build(parent: Node3D) -> StaticBody3D:
	var n := GRID + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for iz in n:
		for ix in n:
			heights[iz * n + ix] = height(-HALF + ix * CELL, -HALF + iz * CELL)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
	for iz in n:
		for ix in n:
			var idx := iz * n + ix
			var x := -HALF + ix * CELL
			var z := -HALF + iz * CELL
			var h: float = heights[idx]
			var hl: float = heights[iz * n + maxi(ix - 1, 0)]
			var hr: float = heights[iz * n + mini(ix + 1, GRID)]
			var hd: float = heights[maxi(iz - 1, 0) * n + ix]
			var hu: float = heights[mini(iz + 1, GRID) * n + ix]
			var normal := Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized()
			verts[idx] = Vector3(x, h, z)
			norms[idx] = normal
			cols[idx] = color_at(x, z, h, 1.0 - normal.y)
	var indices := PackedInt32Array()
	indices.resize(GRID * GRID * 6)
	var k := 0
	for iz in GRID:
		for ix in GRID:
			var a := iz * n + ix
			var b := a + 1
			var c := a + n
			var d := c + 1
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = c
			indices[k + 3] = b
			indices[k + 4] = d
			indices[k + 5] = c
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, ground_material())

	var body := StaticBody3D.new()
	body.name = "Ground"
	parent.add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var shape := mesh.create_trimesh_shape() as ConcavePolygonShape3D
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)

	var pool := PlaneMesh.new()
	pool.size = Vector2(HALF * 2.0, HALF * 2.0)
	var pool_mat := StandardMaterial3D.new()
	pool_mat.albedo_color = Color(0.32, 0.015, 0.04, 0.88)
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
	var base := TileArt.block_material("stone", Color(0.44, 0.44, 0.47))
	var m := base.duplicate() as StandardMaterial3D
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1)
	return m


static func detail_material(tile: String) -> StandardMaterial3D:
	var base := TileArt.block_material(tile, Color(0.44, 0.44, 0.47))
	var m := base.duplicate() as StandardMaterial3D
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1)
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
		if d < r:
			inside += 1
	return inside
