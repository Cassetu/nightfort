extends Node

signal status_changed(text: String)

const BirdScript = preload("res://scripts/gloom_bird.gd")
const GloomNest = preload("res://scripts/gloom_nest.gd")
const NEST_INTERVAL := 0.5

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 38.0
@export var spawn_jitter: float = 5.0
@export var calm_nights: int = 1
@export var base_count: int = 4
@export var count_growth: int = 3
@export var max_count: int = 60
@export var max_alive: int = 20
@export_range(0.0, 1.0) var swarm_share: float = 0.65
@export_range(0.02, 0.3) var swarm_width: float = 0.07
@export var swarm_max_alive: int = 45
@export var swarm_interval: float = 0.12
@export var night_fraction: float = 0.25
@export var first_delay: float = 3.0
@export var warn_elevation: float = 0.12
@export_range(0.0, 1.0) var focus_share: float = 0.8
@export var focus_spread_degrees: float = 18.0
@export var two_front_night: int = 4
@export var retry_interval: float = 0.4
@export var min_player_distance: float = 14.0
@export var bird_start_night: int = 3
@export var bird_cap: int = 6
@export var bird_interval_min: float = 12.0
@export var bird_interval_max: float = 26.0
@export var bird_distance: float = 72.0
@export var bird_altitude_min: float = 20.0
@export var bird_altitude_max: float = 28.0
@export var night_start_elevation: float = -0.1
@export var dawn_elevation: float = 0.03

var terrain
var flow
var core
var player
var sun
var enemies_root: Node3D
var night: int = 0
var night_active: bool = false
var total: int = 0
var spawned: int = 0
var night_time: float = 0.0
var attack_dirs: Array = []
var last_elevation: float = 1.0
var spawn_timer: float = 0.0
var last_status: String = ""
var nests: Dictionary = {}
var birds_total: int = 0
var birds_spawned: int = 0
var bird_timer: float = 0.0
var nest_timer: float = 0.0


func setup(t, f, c, p, s, root: Node3D) -> void:
	terrain = t
	flow = f
	core = c
	player = p
	sun = s
	enemies_root = root


func wave_size(n: int) -> int:
	var real := n - calm_nights
	if real <= 0:
		return 0
	var raw := base_count + (real - 1) * count_growth
	return maxi(roundi(float(mini(raw, max_count)) * Game.spawn_scale()), 1)


func export_state() -> Dictionary:
	return {"night": night, "active": night_active, "spawned": spawned, "elapsed": night_time, "dirs": attack_dirs}


func import_state(d: Dictionary) -> void:
	night = int(d.get("night", 0))
	night_active = bool(d.get("active", false))
	attack_dirs = []
	for a in d.get("dirs", []):
		attack_dirs.append(float(a))
	if night_active:
		birds_total = _bird_count(night)
		bird_timer = randf_range(bird_interval_min * 0.5, bird_interval_max)
		total = wave_size(night)
		spawned = mini(int(d.get("spawned", 0)), total)
		night_time = float(d.get("elapsed", 0.0))
		spawn_timer = first_delay
		if attack_dirs.is_empty():
			_choose_directions(night)


func _process(delta: float) -> void:
	if sun == null:
		return

	_sync_nests(delta)
	var e: float = sun.elevation
	if not night_active and attack_dirs.is_empty() and e < last_elevation and e < warn_elevation and wave_size(night + 1) > 0:
		_choose_directions(night + 1)
	last_elevation = e
	if not night_active and e < night_start_elevation:
		_begin_night()
	elif night_active and e > dawn_elevation:
		_end_night()

	if night_active and spawned < total:
		night_time += delta
		spawn_timer -= delta
		var p := clampf(night_time / maxf(sun.day_length_seconds * night_fraction, 1.0), 0.0, 1.0)
		var swarming := absf(p - 0.5) <= swarm_width
		var target := ceili(total * _spawn_curve(p))
		if spawn_timer <= 0.0 and spawned < target:
			spawn_timer = swarm_interval if swarming else retry_interval
			var cap := roundi(float(swarm_max_alive if swarming else max_alive) * Game.spawn_scale())
			if get_tree().get_nodes_in_group("enemy").size() < cap and _spawn_one():
				spawned += 1

	if night_active and birds_spawned < birds_total and not _is_calmed():
		bird_timer -= delta
		if bird_timer <= 0.0:
			bird_timer = randf_range(bird_interval_min, bird_interval_max)
			if _spawn_bird():
				birds_spawned += 1

	if _is_calmed() and not attack_dirs.is_empty():
		attack_dirs.clear()
	_update_status()


func _sync_nests(delta: float) -> void:
	nest_timer -= delta
	if nest_timer > 0.0:
		return
	nest_timer = NEST_INTERVAL
	var wanted: Dictionary = {}
	if not _is_calmed() and is_instance_valid(core) and terrain != null:
		for a: float in attack_dirs:
			wanted[str(snappedf(a, 0.001))] = a
	for key: String in nests.keys():
		if not wanted.has(key):
			var old = nests[key]
			if is_instance_valid(old):
				old.sink()
			nests.erase(key)
	for key: String in wanted.keys():
		if nests.has(key):
			continue
		var a: float = wanted[key]
		var c: Vector3 = core.global_position
		var pos := Vector3(c.x + cos(a) * spawn_radius, 0.0, c.z + sin(a) * spawn_radius)
		if not terrain.collision_ready(pos):
			continue
		pos.y = float(terrain.surface_y(floori(pos.x), floori(pos.z))) + 1.0
		var nest := Node3D.new()
		nest.set_script(GloomNest)
		nest.set_meta("ground_y", pos.y)
		nest.set_meta("seed", int(absf(a) * 1000.0))
		enemies_root.add_child(nest)
		nest.global_position = Vector3(pos.x, nest.global_position.y, pos.z)
		nests[key] = nest


func _is_calmed() -> bool:
	return night_active and total > 0 and spawned >= total and get_tree().get_nodes_in_group("enemy").is_empty()


func _spawn_curve(p: float) -> float:
	var burst := smoothstep(0.5 - swarm_width, 0.5 + swarm_width, p)
	return (1.0 - swarm_share) * p + swarm_share * burst


func _choose_directions(for_night: int) -> void:
	attack_dirs.clear()
	var first := randf() * TAU
	attack_dirs.append(first)
	if for_night >= two_front_night:
		attack_dirs.append(first + randf_range(deg_to_rad(100.0), deg_to_rad(260.0)))


func _begin_night() -> void:
	night += 1
	night_active = true
	total = wave_size(night)
	if attack_dirs.is_empty() and total > 0:
		_choose_directions(night)
	spawned = 0
	night_time = 0.0
	spawn_timer = first_delay
	birds_total = _bird_count(night)
	birds_spawned = 0
	bird_timer = randf_range(bird_interval_min * 0.5, bird_interval_max * 0.7)


func _end_night() -> void:
	if is_instance_valid(core):
		var amount = core.get("night_heal")
		core.heal(int(amount) if amount != null else 5)
	night_active = false
	total = 0
	spawned = 0
	attack_dirs.clear()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.dissolve()
	for bird in get_tree().get_nodes_in_group("gloom_bird"):
		bird.dissolve()
	birds_total = 0


func _bird_count(n: int) -> int:
	var real := n - bird_start_night + 1
	if real <= 0:
		return 0
	return maxi(roundi(float(mini(real, bird_cap)) * Game.spawn_scale()), 1)


func _spawn_bird() -> bool:
	if not is_instance_valid(core) or enemies_root == null:
		return false
	var angle := randf() * TAU
	if not attack_dirs.is_empty() and randf() < focus_share:
		var base: float = attack_dirs[randi() % attack_dirs.size()]
		angle = base + randf_range(-1.0, 1.0) * deg_to_rad(focus_spread_degrees)
	var c: Vector3 = core.global_position
	var bird := StaticBody3D.new()
	bird.set_script(BirdScript)
	enemies_root.add_child(bird)
	bird.global_position = Vector3(c.x + cos(angle) * bird_distance, c.y + randf_range(bird_altitude_min, bird_altitude_max), c.z + sin(angle) * bird_distance)
	bird.setup(core)
	return true


func _spawn_one() -> bool:
	if enemy_scene == null or not is_instance_valid(core) or terrain == null:
		return false
	var angle := randf() * TAU
	if not attack_dirs.is_empty() and randf() < focus_share:
		var base: float = attack_dirs[randi() % attack_dirs.size()]
		angle = base + randf_range(-1.0, 1.0) * deg_to_rad(focus_spread_degrees)
	var radius := spawn_radius + randf_range(-spawn_jitter, spawn_jitter)
	var c: Vector3 = core.global_position
	var pos := Vector3(c.x + cos(angle) * radius, 0.0, c.z + sin(angle) * radius)
	if not terrain.collision_ready(pos):
		return false
	if is_instance_valid(player):
		var p: Vector3 = player.global_position
		if Vector2(p.x - pos.x, p.z - pos.z).length() < min_player_distance:
			return false
	pos.y = float(terrain.surface_y(floori(pos.x), floori(pos.z))) + 1.2

	var enemy = enemy_scene.instantiate()
	enemies_root.add_child(enemy)
	enemy.global_position = pos
	enemy.setup(flow, core, player, night)
	return true


func _update_status() -> void:
	var text: String
	if night_active and night <= calm_nights:
		text = "NIGHT %d  -  Calm" % night
	elif _is_calmed():
		text = "The night has calmed."
	elif night_active:
		text = "Gloom attacking: %d/%d" % [get_tree().get_nodes_in_group("enemy").size(), maxi(total - spawned, 0)]
	else:
		text = "Day  -  Night %d approaches" % (night + 1)
	if text != last_status:
		last_status = text
		status_changed.emit(text)
