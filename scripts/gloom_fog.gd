extends Node3D

const FogShader = preload("res://resources/gloom_fog.gdshader")

const LAYER_RADII := [1.0, 0.78, 0.56, 0.34]
const CENTER_LIFT := 3.0
const SLOW_MIN := 0.45
const FADE_IN := 0.25
const FADE_OUT := 0.4
const EDGE_DEPTH := 4.0
const TICK := 1.0
const TICK_DAMAGE := 5
const OVERLAY_IN := 2.2
const OVERLAY_OUT := 1.0

var spawner
var core
var player
var terrain
var overlay
var patches: Array = []
var radius: float = 14.0
var tick_timer: float = 0.0
var overlay_level: float = 0.0


func setup(s, c, p, t, o) -> void:
	spawner = s
	core = c
	player = p
	terrain = t
	overlay = o
	radius = spawner.spawn_radius * sin(deg_to_rad(spawner.focus_spread_degrees)) * 1.05 + spawner.spawn_jitter + 3.0


func _process(delta: float) -> void:
	if spawner == null or not is_instance_valid(core):
		return
	_sync_patches()
	var inside := 0.0
	for i in range(patches.size() - 1, -1, -1):
		var patch: Dictionary = patches[i]
		var rate: float = FADE_IN if patch["wanted"] else FADE_OUT
		patch["level"] = move_toward(float(patch["level"]), 1.0 if patch["wanted"] else 0.0, rate * delta)
		for mat: ShaderMaterial in patch["mats"]:
			mat.set_shader_parameter("level", patch["level"])
		if not patch["wanted"] and float(patch["level"]) <= 0.0:
			patch["node"].queue_free()
			patches.remove_at(i)
			continue
		inside = maxf(inside, _depth_inside(patch) * float(patch["level"]))
	if is_instance_valid(player):
		player.slow = lerpf(1.0, SLOW_MIN, inside)
	var rising := inside > overlay_level
	overlay_level = move_toward(overlay_level, inside, delta / (OVERLAY_IN if rising else OVERLAY_OUT))
	if overlay != null:
		overlay.set_intensity(overlay_level)
	_damage(delta, inside)


func _depth_inside(patch: Dictionary) -> float:
	if not is_instance_valid(player) or player.dead:
		return 0.0
	var center: Vector3 = patch["center"]
	var p: Vector3 = player.global_position
	var dist := (p + Vector3(0.0, 0.9, 0.0)).distance_to(center)
	return clampf((radius - dist) / EDGE_DEPTH, 0.0, 1.0)


func _damage(delta: float, inside: float) -> void:
	if inside <= 0.05 or not is_instance_valid(player) or player.dead:
		tick_timer = 0.0
		return
	tick_timer += delta
	if tick_timer >= TICK:
		tick_timer = 0.0
		player.take_damage(TICK_DAMAGE)


func _sync_patches() -> void:
	var dirs: Array = spawner.attack_dirs
	for patch: Dictionary in patches:
		var keep := false
		for a in dirs:
			if absf(angle_difference(float(a), float(patch["angle"]))) < 0.001:
				keep = true
				break
		patch["wanted"] = keep
	for a in dirs:
		var exists := false
		for patch: Dictionary in patches:
			if patch["wanted"] and absf(angle_difference(float(a), float(patch["angle"]))) < 0.001:
				exists = true
				break
		if not exists:
			patches.append(_make_patch(float(a)))


func _make_patch(angle: float) -> Dictionary:
	var c: Vector3 = core.global_position
	var x: float = c.x + cos(angle) * spawner.spawn_radius
	var z: float = c.z + sin(angle) * spawner.spawn_radius
	var base := float(terrain.surface_y(floori(x), floori(z))) + CENTER_LIFT
	var root := Node3D.new()
	root.position = Vector3(x, base, z)
	add_child(root)
	var mats: Array = []
	for i in LAYER_RADII.size():
		var mat := ShaderMaterial.new()
		mat.shader = FogShader
		mat.set_shader_parameter("level", 0.0)
		mat.set_shader_parameter("fog_radius", radius * float(LAYER_RADII[i]))
		mat.set_shader_parameter("seed_offset", float(i) * 17.3 + angle * 3.1)
		var mesh := SphereMesh.new()
		mesh.radius = radius * float(LAYER_RADII[i])
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 32
		mesh.rings = 16
		mesh.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mats.append(mat)
	return {"node": root, "mats": mats, "angle": angle, "level": 0.0, "wanted": true, "center": Vector3(x, base, z)}
