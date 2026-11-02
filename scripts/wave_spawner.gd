extends Node

signal status_changed(text: String)

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 38.0
@export var spawn_jitter: float = 5.0
@export var base_count: int = 4
@export var count_growth: int = 3
@export var max_count: int = 60
@export var max_alive: int = 20
@export var spawn_interval: float = 1.6
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
var to_spawn: int = 0
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
	return mini(base_count + (n - 1) * count_growth, max_count)


func export_state() -> Dictionary:
	return {"night": night, "active": night_active}


func import_state(d: Dictionary) -> void:
	night = int(d.get("night", 0))
	night_active = bool(d.get("active", false))
	if night_active:
		to_spawn = wave_size(night)
		spawn_timer = 3.0


func _process(delta: float) -> void:
	if sun == null:
		return

	var e: float = sun.elevation
	if not night_active and e < night_start_elevation:
		_begin_night()
	elif night_active and e > dawn_elevation:
		_end_night()

	if night_active and to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = spawn_interval
			if get_tree().get_nodes_in_group("enemy").size() < max_alive and _spawn_one():
				to_spawn -= 1

	_update_status()


func _begin_night() -> void:
	night += 1
	night_active = true
	to_spawn = wave_size(night)
	spawn_timer = 3.0


func _end_night() -> void:
	night_active = false
	to_spawn = 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.dissolve()


func _spawn_one() -> bool:
	if enemy_scene == null or not is_instance_valid(core) or terrain == null:
		return false
	var angle := randf() * TAU
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
	if night_active:
		var left: int = to_spawn + get_tree().get_nodes_in_group("enemy").size()
		text = "NIGHT %d  -  Gloom left: %d" % [night, left]
	else:
		text = "Day  -  Night %d approaches" % (night + 1)
	if text != last_status:
		last_status = text
		status_changed.emit(text)
