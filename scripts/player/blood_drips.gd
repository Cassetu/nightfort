extends Node

const LOW_FRACTION := 0.4
const MAX_DRIPS := 40
const MAX_DECALS := 60
const GRAVITY := 14.0
const DECAL_LIFE := 5.0
const DECAL_FADE := 2.0
const BLOOD := Color(0.5, 0.03, 0.05)

static var splat_texture: ImageTexture

var player
var timer: float = 0.0
var drips: Array = []
var decals: Array = []
var drip_mesh: SphereMesh
var drip_material: StandardMaterial3D
var quad: QuadMesh


func _ready() -> void:
	player = get_parent()
	drip_mesh = SphereMesh.new()
	drip_mesh.radius = 0.035
	drip_mesh.height = 0.08
	drip_mesh.radial_segments = 6
	drip_mesh.rings = 3
	drip_material = StandardMaterial3D.new()
	drip_material.albedo_color = BLOOD
	drip_material.roughness = 0.2
	drip_mesh.material = drip_material
	quad = QuadMesh.new()
	quad.size = Vector2.ONE


func _physics_process(delta: float) -> void:
	_step_drips(delta)
	_step_decals(delta)
	if player == null or player.dead:
		return
	var fraction: float = float(player.health) / float(maxi(player.max_health, 1))
	if fraction > LOW_FRACTION:
		return
	timer -= delta
	if timer > 0.0 or drips.size() >= MAX_DRIPS:
		return
	var severity: float = 1.0 - fraction / LOW_FRACTION
	timer = lerpf(0.5, 0.12, severity) * randf_range(0.6, 1.4)
	_spawn_drip()


func _spawn_drip() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var node := MeshInstance3D.new()
	node.mesh = drip_mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	node.global_position = player.global_position + Vector3(randf_range(-0.25, 0.25), randf_range(0.3, 1.5), randf_range(-0.25, 0.25))
	drips.append({"node": node, "vel": Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.8), randf_range(-0.4, 0.4))})


func _step_drips(delta: float) -> void:
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for i in range(drips.size() - 1, -1, -1):
		var drip: Dictionary = drips[i]
		var node: MeshInstance3D = drip["node"]
		if not is_instance_valid(node):
			drips.remove_at(i)
			continue
		var vel: Vector3 = drip["vel"]
		vel.y -= GRAVITY * delta
		drip["vel"] = vel
		var from := node.global_position
		var to := from + vel * delta
		var query := PhysicsRayQueryParameters3D.create(from, to, 1)
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			node.global_position = to
			if to.y < player.global_position.y - 60.0:
				node.queue_free()
				drips.remove_at(i)
			continue
		_splat(hit["position"], hit["normal"])
		node.queue_free()
		drips.remove_at(i)


func _splat(pos: Vector3, normal: Vector3) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	if decals.size() >= MAX_DECALS:
		var oldest: Dictionary = decals.pop_front()
		if is_instance_valid(oldest["node"]):
			oldest["node"].queue_free()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _texture()
	mat.albedo_color = Color(1, 1, 1, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.25
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
	var n := normal.normalized()
	var basis := Basis(Quaternion(Vector3.BACK, n))
	basis = basis.rotated(n, randf() * TAU)
	var size := randf_range(0.25, 0.55)
	node.global_transform = Transform3D(basis.scaled(Vector3.ONE * size), pos + n * 0.02)
	decals.append({"node": node, "mat": mat, "age": 0.0})


func _step_decals(delta: float) -> void:
	for i in range(decals.size() - 1, -1, -1):
		var decal: Dictionary = decals[i]
		if not is_instance_valid(decal["node"]):
			decals.remove_at(i)
			continue
		decal["age"] = float(decal["age"]) + delta
		var left: float = DECAL_LIFE - float(decal["age"])
		if left <= 0.0:
			decal["node"].queue_free()
			decals.remove_at(i)
			continue
		var mat: StandardMaterial3D = decal["mat"]
		mat.albedo_color.a = 0.9 * clampf(left / DECAL_FADE, 0.0, 1.0)


func _exit_tree() -> void:
	for drip in drips:
		if is_instance_valid(drip["node"]):
			drip["node"].queue_free()
	for decal in decals:
		if is_instance_valid(decal["node"]):
			decal["node"].queue_free()


static func _texture() -> ImageTexture:
	if splat_texture != null:
		return splat_texture
	var size := 32
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var lobes: Array = []
	for i in 5:
		lobes.append(Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25), rng.randf_range(0.14, 0.26)))
	lobes.append(Vector3(0.0, 0.0, 0.3))
	for y in size:
		for x in size:
			var p := Vector2((float(x) + 0.5) / size - 0.5, (float(y) + 0.5) / size - 0.5)
			var cover := 0.0
			for lobe: Vector3 in lobes:
				cover = maxf(cover, 1.0 - p.distance_to(Vector2(lobe.x, lobe.y)) / lobe.z)
			var edge := cover + rng.randf_range(-0.1, 0.1)
			if edge > 0.0:
				var shade := 0.7 + rng.randf_range(-0.12, 0.12) + clampf(edge, 0.0, 1.0) * 0.2
				img.set_pixel(x, y, Color(BLOOD.r * shade, BLOOD.g * shade, BLOOD.b * shade, 1.0))
	splat_texture = ImageTexture.create_from_image(img)
	return splat_texture
