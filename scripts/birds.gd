extends Node3D

const MIN_INTERVAL := 30.0
const MAX_INTERVAL := 85.0
const FIRST_DELAY := 20.0
const SPAWN_DISTANCE := 75.0
const ALTITUDE_MIN := 16.0
const ALTITUDE_MAX := 30.0
const SPEED_MIN := 7.5
const SPEED_MAX := 10.5
const FLOCK_MIN := 1
const FLOCK_MAX := 6
const MAX_AGE := 45.0
const MIN_SUN := 0.12
const MAX_RAIN := 0.1
const BIRD_SCALE := 1.7
const CHIRP_MAX := 3
const CHIRP_RANGE := 58.0
const CHIRP_DB := -11.0
const Sfx = preload("res://scripts/sfx.gd")

var player
var sun
var weather
var timer: float = FIRST_DELAY
var flocks: Array = []
var body_mesh: BoxMesh
var wing_mesh: BoxMesh


func setup(p, s, w) -> void:
	player = p
	sun = s
	weather = w
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.09, 0.11)
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(0.14, 0.1, 0.34)
	body_mesh.material = mat
	wing_mesh = BoxMesh.new()
	wing_mesh.size = Vector3(0.5, 0.02, 0.18)
	wing_mesh.material = mat


func _process(delta: float) -> void:
	if player == null:
		return
	timer -= delta
	if timer <= 0.0:
		timer = randf_range(MIN_INTERVAL, MAX_INTERVAL)
		if _conditions_ok():
			_spawn_flock()
	_update_flocks(delta)


func _conditions_ok() -> bool:
	if sun != null and sun.elevation < MIN_SUN:
		return false
	if weather != null and weather.rain > MAX_RAIN:
		return false
	return not player.dead


func _spawn_flock() -> void:
	var ppos: Vector3 = player.global_position
	var angle := randf() * TAU
	var start := Vector3(ppos.x + cos(angle) * SPAWN_DISTANCE, ppos.y + randf_range(ALTITUDE_MIN, ALTITUDE_MAX), ppos.z + sin(angle) * SPAWN_DISTANCE)
	var lateral := Vector3(-sin(angle), 0.0, cos(angle)) * randf_range(-25.0, 25.0)
	var aim := Vector3(ppos.x, start.y, ppos.z) + lateral
	var dir := (aim - start).normalized()
	var root := Node3D.new()
	add_child(root)
	root.global_position = start
	root.rotation.y = atan2(-dir.x, -dir.z)
	var count := randi_range(FLOCK_MIN, FLOCK_MAX)
	var members: Array = []
	for i in count:
		var bird := _make_bird()
		root.add_child(bird["node"])
		var rank := (i + 1) / 2
		var side := 0.0 if i == 0 else (1.0 if i % 2 == 1 else -1.0)
		bird["node"].position = Vector3(side * rank * 1.7 + randf_range(-0.3, 0.3), randf_range(-0.4, 0.4), rank * 1.5 + randf_range(-0.3, 0.3))
		members.append(bird)
	var chirps := clampi(int(ceil(float(count) / 2.0)), 1, CHIRP_MAX)
	flocks.append({"root": root, "dir": dir, "speed": randf_range(SPEED_MIN, SPEED_MAX), "age": 0.0, "birds": members, "chirps": chirps, "chirp_at": randf_range(0.5, 3.0), "size": count})


func _make_bird() -> Dictionary:
	var node := Node3D.new()
	node.scale = Vector3.ONE * BIRD_SCALE
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(body)
	var wings: Array = []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.07, 0.0, 0.0)
		node.add_child(pivot)
		var wing := MeshInstance3D.new()
		wing.mesh = wing_mesh
		wing.position = Vector3(side * 0.25, 0.0, 0.0)
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(wing)
		wings.append(pivot)
	return {"node": node, "wings": wings, "phase": randf() * TAU, "rate": randf_range(9.0, 12.0)}


func _update_flocks(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var ppos: Vector3 = player.global_position
	for i in range(flocks.size() - 1, -1, -1):
		var flock: Dictionary = flocks[i]
		var root: Node3D = flock["root"]
		flock["age"] = float(flock["age"]) + delta
		root.global_position += flock["dir"] * float(flock["speed"]) * delta
		var away := Vector2(root.global_position.x - ppos.x, root.global_position.z - ppos.z).length()
		if float(flock["age"]) > MAX_AGE or (float(flock["age"]) > 6.0 and away > SPAWN_DISTANCE * 1.3):
			root.queue_free()
			flocks.remove_at(i)
			continue
		if int(flock["chirps"]) > 0:
			flock["chirp_at"] = float(flock["chirp_at"]) - delta
			if float(flock["chirp_at"]) <= 0.0 and away < CHIRP_RANGE:
				flock["chirps"] = int(flock["chirps"]) - 1
				flock["chirp_at"] = randf_range(3.0, 8.0)
				var size_db := float(int(flock["size"]) - 1) * 0.6
				Sfx.play(self, "bird_chirp", root.global_position, CHIRP_DB + size_db + randf_range(-2.0, 1.0))
		for bird in flock["birds"]:
			var phase: float = bird["phase"]
			var glide := smoothstep(-0.2, 0.4, sin(t * 0.4 + phase))
			var amp := lerpf(0.75, 0.12, glide)
			var angle := sin(t * float(bird["rate"]) + phase) * amp
			bird["wings"][0].rotation.z = -angle
			bird["wings"][1].rotation.z = angle
			bird["node"].position.y += sin(t * 1.3 + phase) * 0.002
