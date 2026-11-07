extends Node3D

const HALF := 12
const STEP := 3
const SHOW_DISTANCE := 11.0
const FULL_DISTANCE := 7.0
const REFRESH := 0.4
const POST_SIZE := Vector3(0.12, 1.1, 0.12)
const CAP_SIZE := Vector3(0.2, 0.12, 0.2)

var terrain
var center := Vector3.ZERO
var center_cell := Vector2i.ZERO
var posts: Array = []
var refresh_timer: float = 0.0


func _ready() -> void:
	add_to_group("territory")


func setup(t, c) -> void:
	terrain = t
	center = c.global_position
	center_cell = Vector2i(floori(center.x), floori(center.z))
	_build()


func contains(p: Vector3) -> bool:
	return absf(p.x - (center_cell.x + 0.5)) <= HALF + 0.5 and absf(p.z - (center_cell.y + 0.5)) <= HALF + 0.5


func _build() -> void:
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.3, 0.27, 0.24)
	post_mat.roughness = 1.0
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.45, 0.8, 0.78)
	cap_mat.emission_enabled = true
	cap_mat.emission = Color(0.4, 0.95, 0.9)
	cap_mat.emission_energy_multiplier = 1.4
	var post_mesh := BoxMesh.new()
	post_mesh.size = POST_SIZE
	post_mesh.material = post_mat
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = CAP_SIZE
	cap_mesh.material = cap_mat

	var seen: Dictionary = {}
	for i in range(-HALF, HALF + 1, STEP):
		for cell in [Vector2i(i, -HALF), Vector2i(i, HALF), Vector2i(-HALF, i), Vector2i(HALF, i)]:
			if seen.has(cell):
				continue
			seen[cell] = true
			var post := Node3D.new()
			var body := MeshInstance3D.new()
			body.mesh = post_mesh
			body.position = Vector3(0.0, POST_SIZE.y * 0.5, 0.0)
			post.add_child(body)
			var cap := MeshInstance3D.new()
			cap.mesh = cap_mesh
			cap.position = Vector3(0.0, POST_SIZE.y + CAP_SIZE.y * 0.5, 0.0)
			cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			post.add_child(cap)
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
