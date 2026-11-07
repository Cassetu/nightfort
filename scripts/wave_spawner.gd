extends Node

signal status_changed(text: String)

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
@export var night_fraction: float = 0.4888
@export var first_delay: float = 3.0
@export var warn_elevation: float = 0.12
@export_range(0.0, 1.0) var focus_share: float = 0.8
@export var focus_spread_degrees: float = 18.0
@export var two_front_night: int = 4
@export var retry_interval: float = 0.4
@export var min_player_distance: float = 14.0
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
	return mini(base_count + (real - 1) * count_growth, max_count)


func export_state() -> Dictionary:
	return {"night": night, "active": night_active, "spawned": spawned, "elapsed": night_time, "dirs": attack_dirs}


func import_state(d: Dictionary) -> void:
	night = int(d.get("night", 0))
	night_active = bool(d.get("active", false))
	attack_dirs = []
	for a in d.get("dirs", []):
		attack_dirs.append(float(a))
	if night_active:
		total = wave_size(night)
		spawned = mini(int(d.get("spawned", 0)), total)
		night_time = float(d.get("elapsed", 0.0))
		spawn_timer = first_delay
		if attack_dirs.is_empty():
			_choose_directions(night)


func _process(delta: float) -> void:
	if sun == null:
		return

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
			var cap := swarm_max_alive if swarming else max_alive
			if get_tree().get_nodes_in_group("enemy").size() < cap and _spawn_one():
				spawned += 1

	_update_status()


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
	elif night_active:
		text = "Gloom attacking: %d/%d" % [get_tree().get_nodes_in_group("enemy").size(), maxi(total - spawned, 0)]
	else:
		text = "Day  -  Night %d approaches" % (night + 1)
	if text != last_status:
		last_status = text
		status_changed.emit(text)
