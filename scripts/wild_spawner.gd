extends Node

const GloomScene = preload("res://scenes/gloom.tscn")

@export var tick: float = 2.5
@export var cave_max: int = 6
@export var surface_max: int = 7
@export var cave_min_radius: float = 12.0
@export var cave_max_radius: float = 38.0
@export var surface_min_radius: float = 22.0
@export var surface_max_radius: float = 50.0
@export var core_keepout: float = 55.0
@export var despawn_distance: float = 85.0
@export var cave_attempts: int = 14

var terrain
var core
var player
var sun
var root: Node3D
var timer: float = 1.0
var was_night: bool = false


func setup(t, c, p, s, r: Node3D) -> void:
	terrain = t
	core = c
	player = p
	sun = s
	root = r


func _process(delta: float) -> void:
	if terrain == null or not is_instance_valid(player) or player.dead:
		return

	var night: bool = sun != null and sun.elevation < -0.05
	if was_night and not night:
		for g in get_tree().get_nodes_in_group("wild_gloom"):
			if g.surface:
				g.dissolve()
	was_night = night

	timer -= delta
	if timer > 0.0:
		return
	timer = tick

	var cave_count := 0
	var surface_count := 0
	var p: Vector3 = player.global_position
	for g in get_tree().get_nodes_in_group("wild_gloom"):
		if g.dying:
			continue
		var far := Vector2(g.global_position.x - p.x, g.global_position.z - p.z).length()
		if far > despawn_distance:
			g.dissolve()
			continue
		if g.surface:
			surface_count += 1
		else:
			cave_count += 1

	if cave_count < cave_max:
		_spawn_cave(p)
	if night and surface_count < surface_max:
		_spawn_surface(p)


func _make(pos: Vector3, on_surface: bool) -> void:
	var g = GloomScene.instantiate()
	g.wild = true
	g.surface = on_surface
	root.add_child(g)
	g.global_position = pos
	g.setup(null, core, player, 1)


func _far_from_core(x: float, z: float) -> bool:
	if not is_instance_valid(core):
		return true
	var c: Vector3 = core.global_position
	return Vector2(x - c.x, z - c.z).length() > core_keepout


func _spawn_surface(p: Vector3) -> void:
	for _i in 6:
		var a := randf() * TAU
		var r := randf_range(surface_min_radius, surface_max_radius)
		var x := p.x + cos(a) * r
		var z := p.z + sin(a) * r
		if not _far_from_core(x, z):
			continue
		var pos := Vector3(x, 0.0, z)
		if not terrain.collision_ready(pos):
			continue
		pos.y = float(terrain.surface_y(floori(x), floori(z))) + 1.2
		_make(pos, true)
		return


func _spawn_cave(p: Vector3) -> void:
	for _i in cave_attempts:
		var a := randf() * TAU
		var r := randf_range(cave_min_radius, cave_max_radius)
		var x := p.x + cos(a) * r
		var z := p.z + sin(a) * r
		var ix := floori(x)
		var iz := floori(z)
		var top: int = terrain.surface_y(ix, iz)
		var low: int = terrain.Y_MIN + 3
		var high: int = top - terrain.cave_cover - 1
		if high <= low:
			continue
		var iy := randi_range(low, high)
		if terrain.block_at(ix, iy, iz) != 0 or terrain.block_at(ix, iy + 1, iz) != 0:
			continue
		if terrain.block_at(ix, iy - 1, iz) == 0:
			continue
		var pos := Vector3(ix + 0.5, iy + 1.2, iz + 0.5)
		if not terrain.collision_ready(pos):
			continue
		_make(pos, false)
		return
