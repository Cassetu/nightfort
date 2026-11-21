extends Node3D

const BASE_HALF := 9
const LEVEL_STEP := 10
const STEP := 3
const SHOW_DISTANCE := 11.0
const FULL_DISTANCE := 7.0
const REFRESH := 0.4
const TileArt = preload("res://scripts/tile_art.gd")
const PLINTH_SIZE := Vector3(0.56, 0.16, 0.56)
const SHAFT_BOTTOM := 0.38
const SHAFT_TOP := 0.26
const SHAFT_H := 1.05
const CAP_SIZE := Vector3(0.42, 0.1, 0.42)
const RUNE_SIZE := Vector3(0.08, 0.22, 0.05)
const GEM_SIZE := Vector3(0.1, 0.1, 0.1)

var terrain
var core_ref
var half: int = BASE_HALF
var built_level: int = 0
var center := Vector3.ZERO
var center_cell := Vector2i.ZERO
var posts: Array = []
var refresh_timer: float = 0.0


func _ready() -> void:
	add_to_group("territory")


func setup(t, c) -> void:
	terrain = t
	core_ref = c
	center = c.global_position
	center_cell = Vector2i(floori(center.x), floori(center.z))
	_build()


func contains(p: Vector3) -> bool:
	return absf(p.x - (center_cell.x + 0.5)) <= half + 0.5 and absf(p.z - (center_cell.y + 0.5)) <= half + 0.5


func _tapered(bottom: float, top: float, height: float, material: Material) -> ArrayMesh:
	var hb := bottom * 0.5
	var ht := top * 0.5
	var corners_b: Array = [Vector3(-hb, 0.0, hb), Vector3(hb, 0.0, hb), Vector3(hb, 0.0, -hb), Vector3(-hb, 0.0, -hb)]
	var corners_t: Array = [Vector3(-ht, height, ht), Vector3(ht, height, ht), Vector3(ht, height, -ht), Vector3(-ht, height, -ht)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var n := (i + 1) % 4
		var quad: Array = [corners_t[i], corners_t[n], corners_b[n], corners_b[i]]
		var uv: Array = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[k])
			st.add_vertex(quad[k])
	for k in [0, 1, 2, 0, 2, 3]:
		var uv_top: Array = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var order: Array = [corners_t[3], corners_t[2], corners_t[1], corners_t[0]]
		st.set_uv(uv_top[k])
		st.add_vertex(order[k])
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	return mesh


func _build() -> void:
	for old: Node3D in posts:
		old.queue_free()
	posts.clear()
	built_level = int(core_ref.level) if core_ref != null and is_instance_valid(core_ref) else 1
	half = BASE_HALF + LEVEL_STEP * (built_level - 1)
	var stone_mat := TileArt.uv_material("stone_brick", Color(0.5, 0.5, 0.54), Vector3.ONE).duplicate() as StandardMaterial3D
	stone_mat.albedo_color = Color(0.66, 0.66, 0.7)
	var rune_mat := StandardMaterial3D.new()
	rune_mat.albedo_color = Color(0.45, 0.8, 0.78)
	rune_mat.emission_enabled = true
	rune_mat.emission = Color(0.4, 0.95, 0.9)
	rune_mat.emission_energy_multiplier = 1.4
	var plinth_mesh := TileArt.box_mesh(PLINTH_SIZE, stone_mat)
	var shaft_mesh := _tapered(SHAFT_BOTTOM, SHAFT_TOP, SHAFT_H, stone_mat)
	var cap_mesh := TileArt.box_mesh(CAP_SIZE, stone_mat)
	var rune_mesh := TileArt.box_mesh(RUNE_SIZE, rune_mat)
	var gem_mesh := TileArt.box_mesh(GEM_SIZE, rune_mat)

	var seen: Dictionary = {}
	for i in range(-half, half + 1, STEP):
		for cell in [Vector2i(i, -half), Vector2i(i, half), Vector2i(-half, i), Vector2i(half, i)]:
			if seen.has(cell):
				continue
			seen[cell] = true
			var post := Node3D.new()
			var plinth := MeshInstance3D.new()
			plinth.mesh = plinth_mesh
			plinth.position = Vector3(0.0, PLINTH_SIZE.y * 0.5, 0.0)
			post.add_child(plinth)
			var shaft := MeshInstance3D.new()
			shaft.mesh = shaft_mesh
			shaft.position = Vector3(0.0, PLINTH_SIZE.y, 0.0)
			post.add_child(shaft)
			var cap := MeshInstance3D.new()
			cap.mesh = cap_mesh
			cap.position = Vector3(0.0, PLINTH_SIZE.y + SHAFT_H + CAP_SIZE.y * 0.5, 0.0)
			post.add_child(cap)
			var rune := MeshInstance3D.new()
			rune.mesh = rune_mesh
			rune.position = Vector3(0.0, PLINTH_SIZE.y + SHAFT_H * 0.62, SHAFT_BOTTOM * 0.5 - 0.06)
			rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			post.add_child(rune)
			var gem := MeshInstance3D.new()
			gem.mesh = gem_mesh
			gem.position = Vector3(0.0, PLINTH_SIZE.y + SHAFT_H + CAP_SIZE.y + GEM_SIZE.y * 0.5, 0.0)
			gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			post.add_child(gem)
			var outward := Vector2(float(cell.x), float(cell.y))
			if absi(cell.x) == half and absi(cell.y) == half:
				outward = Vector2(float(cell.x), float(cell.y))
			elif absi(cell.x) == half:
				outward = Vector2(float(cell.x), 0.0)
			else:
				outward = Vector2(0.0, float(cell.y))
			post.rotation.y = atan2(outward.x, outward.y)
			post.visible = false
			add_child(post)
			post.global_position = Vector3(center_cell.x + cell.x + 0.5, 0.0, center_cell.y + cell.y + 0.5)
			posts.append(post)
	_refresh_heights()


func _refresh_heights() -> void:
	for post: Node3D in posts:
		var x := floori(post.global_position.x)
		var z := floori(post.global_position.z)
		post.global_position.y = float(terrain.surface_y(x, z))


func _process(delta: float) -> void:
	if core_ref != null and is_instance_valid(core_ref) and int(core_ref.level) != built_level:
		_build()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	refresh_timer += delta
	var refresh := refresh_timer >= REFRESH
	if refresh:
		refresh_timer = 0.0
	var cp := cam.global_position
	for post: Node3D in posts:
		var d := Vector2(post.global_position.x - cp.x, post.global_position.z - cp.z).length()
		if d > SHOW_DISTANCE:
			post.visible = false
			continue
		if refresh or not post.visible:
			post.global_position.y = float(terrain.surface_y(floori(post.global_position.x), floori(post.global_position.z)))
		var k := clampf((SHOW_DISTANCE - d) / (SHOW_DISTANCE - FULL_DISTANCE), 0.0, 1.0)
		post.scale = Vector3(1.0, k, 1.0)
		post.visible = k > 0.01
